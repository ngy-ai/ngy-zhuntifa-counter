import '../l10n/gen/app_localizations.dart';

/// 语音计数失败的原因。
///
/// 控制器只上报原因（[VoiceFailure]）与细节文本，具体措辞由界面按当前语言
/// 翻译，避免把某一种语言的提示写死在语音层里。
enum VoiceFailure {
  /// 识别不可用：模型缺失或加载失败（见 CONTEXT.md 的「识别不可用」）。
  unavailable,

  /// 启动识别时抛错。
  startFailed,

  /// 聆听过程中被中断。
  interrupted,

  /// 没有麦克风权限。
  permission,

  /// 麦克风被其它应用占用。
  busy,

  /// 其它错误，细节文本是底层异常信息。
  unknown,
}

/// 把失败原因翻译成当前语言的提示文案。
///
/// [detail] 为可选的细节：启动失败/中断时是异常信息。
String voiceFailureMessage(
  AppLocalizations l10n,
  VoiceFailure failure,
  String? detail,
) => switch (failure) {
  VoiceFailure.unavailable => l10n.voiceErrorUnavailable,
  VoiceFailure.startFailed => l10n.voiceErrorStartFailed(detail ?? ''),
  VoiceFailure.interrupted => l10n.voiceErrorInterrupted(detail ?? ''),
  VoiceFailure.permission => l10n.voiceErrorPermission,
  VoiceFailure.busy => l10n.voiceErrorBusy,
  VoiceFailure.unknown => l10n.voiceErrorUnknown(detail ?? ''),
};
