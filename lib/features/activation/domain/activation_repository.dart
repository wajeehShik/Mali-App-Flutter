import '../../../core/errors/failure.dart';
import 'activation_state.dart';

/// نقطة التعامل الوحيدة مع التفعيل لباقي التطبيق.
///
/// كل الدوال ترجع [Result] ولا ترمي. حالة التفعيل نفسها ([ActivationState])
/// هي نتيجة "عادية" وليست فشلًا: مثلًا انتهاء التصريح حالة [ActivationExpired]
/// وليس [Err].
abstract interface class ActivationRepository {
  /// معرّف هذا التثبيت، ليُعرض للمستخدم أو المسؤول (لتوقيع تصريح يدويًا).
  Future<Result<String>> getDeviceId();

  /// يقيّم الحالة الحالية دون اتصال بالإنترنت:
  /// 1. يوجد تصريح مخزَّن ← يُتحقق من توقيعه وجهازه وصلاحيته
  ///    (صالح = Active، منتهٍ = Expired، غير صالح = يُحذف ويرجع NotActivated).
  /// 2. لا تصريح ويوجد طلب معلَّق مخزَّن ← Pending.
  /// 3. غير ذلك ← NotActivated.
  ///
  /// إن تراجعت ساعة الجهاز عن آخر وقت شوهد، يُعدّ التصريح غير موثوق
  /// ويرجع Expired بدل Active إلى أن يتحقق التطبيق عبر الإنترنت.
  Future<Result<ActivationState>> loadState();

  /// يرسل طلب تفعيل جديد للخادم ويخزّن معرّفه، ويرجع Pending.
  Future<Result<ActivationState>> submitRequest({
    required String name,
    String? phone,
  });

  /// يستعلم عن الطلب المعلَّق: ما زال Pending، أو رُفض (NotActivated مع الرسالة)،
  /// أو وُوفق عليه فيُتحقق من التصريح ويُخزَّن ويرجع Active.
  Future<Result<ActivationState>> refreshPending();

  /// تفعيل يدوي بنص تصريح (payload.signature) يلصقه المستخدم.
  /// يعمل دون إنترنت، ويُرفض إن لم يطابق التوقيع أو الجهاز أو كان منتهيًا.
  Future<Result<ActivationState>> activateWithCode(String code);

  /// عند توفر الإنترنت: يطلب تجديد التصريح الحالي ويخزّنه إن صحّ.
  /// فشل الشبكة لا يغيّر الحالة الحالية.
  Future<Result<ActivationState>> renew();

  /// يحذف التصريح والطلب المعلَّق (تسجيل خروج من التفعيل). لا يمس بيانات العمل.
  Future<Result<void>> clear();
}