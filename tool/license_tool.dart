import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

// Dev-only tool: generate Ed25519 license keys and sign test tokens.
//
// Run from the project root (E:\flutter\mali):
//   dart run tool/license_tool.dart genkeys [--force]
//   dart run tool/license_tool.dart sign --device <id> [--user <id>]
//       [--plan <name>] [--days <n>]
//
// The private seed is written OUTSIDE the repository (../mali_dev_keys).
// Never commit it. Production keys must be generated separately on the server.
const String _keysDir = '../mali_dev_keys';
const String _seedPath = '$_keysDir/private_seed.txt';
const String _publicPath = 'assets/keys/license_public_key.txt';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    _usage();
    exit(64);
  }
  final options = _parseOptions(args.skip(1).toList());
  switch (args.first) {
    case 'genkeys':
      await _genKeys(force: options.containsKey('force'));
    case 'sign':
      await _sign(options);
    default:
      _usage();
      exit(64);
  }
}

void _usage() {
  stdout.writeln('Usage (run from project root):');
  stdout.writeln('  dart run tool/license_tool.dart genkeys [--force]');
  stdout.writeln(
    '  dart run tool/license_tool.dart sign --device <id> '
    '[--user <id>] [--plan <name>] [--days <n>]',
  );
}

Map<String, String> _parseOptions(List<String> args) {
  final result = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (!arg.startsWith('--')) {
      continue;
    }
    final key = arg.substring(2);
    final hasValue = i + 1 < args.length && !args[i + 1].startsWith('--');
    result[key] = hasValue ? args[++i] : 'true';
  }
  return result;
}

Future<void> _genKeys({required bool force}) async {
  final seedFile = File(_seedPath);
  if (seedFile.existsSync() && !force) {
    stderr.writeln('Private key already exists at $_seedPath');
    stderr.writeln('Use --force to replace it (invalidates old tokens).');
    exit(1);
  }

  final random = Random.secure();
  final seed = Uint8List.fromList(
    List<int>.generate(32, (_) => random.nextInt(256)),
  );
  final algorithm = Ed25519();
  final keyPair = await algorithm.newKeyPairFromSeed(seed);
  final publicKey = await keyPair.extractPublicKey();

  Directory(_keysDir).createSync(recursive: true);
  seedFile.writeAsStringSync(_b64(seed));
  File(_publicPath).writeAsStringSync(_b64(publicKey.bytes));

  stdout.writeln('Private seed : $_seedPath  (KEEP SECRET, outside repo)');
  stdout.writeln('Public key   : $_publicPath  (safe to commit)');
}

Future<void> _sign(Map<String, String> options) async {
  final deviceId = options['device'];
  if (deviceId == null || deviceId == 'true') {
    stderr.writeln('Missing --device <id>');
    exit(64);
  }
  final days = int.tryParse(options['days'] ?? '30');
  if (days == null || days <= 0) {
    stderr.writeln('--days must be a positive integer');
    exit(64);
  }
  final seedFile = File(_seedPath);
  if (!seedFile.existsSync()) {
    stderr.writeln('No private key found. Run genkeys first.');
    exit(1);
  }

  final algorithm = Ed25519();
  final keyPair = await algorithm.newKeyPairFromSeed(
    _unb64(seedFile.readAsStringSync()),
  );

  final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
  final payload = <String, Object>{
    'v': 1,
    'user_id': options['user'] ?? 'dev-user',
    'device_id': deviceId,
    'plan': options['plan'] ?? 'pro',
    'issued_at': now,
    'expires_at': now + days * 86400,
  };
  final payloadBytes = utf8.encode(jsonEncode(payload));
  final signature = await algorithm.sign(payloadBytes, keyPair: keyPair);

  stdout.writeln('${_b64(payloadBytes)}.${_b64(signature.bytes)}');
}

String _b64(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');

Uint8List _unb64(String text) {
  return Uint8List.fromList(base64Url.decode(base64Url.normalize(text.trim())));
}