import '../l10n/gen/app_localizations.dart';

/// 语音计数失败的原因。
///
/// 控制器只上报原因（[VoiceFailure]）与细节文本，具体措辞由界面按当前语言
/// 翻译，避免把某一种语言的提示写死在语音层里。
enum VoiceFailure {
  /// 语音识别不可用（缺少麦克风或系统语音服务）。
  unavailable,

  /// 启动语音识别时抛错。
  startFailed,

  /// 聆听过程中被中断。
  interrupted,

  /// 没有麦克风或语音识别权限。
  permission,

  /// 识别器被其它应用占用。
  busy,

  /// 需要网络。
  network,

  /// 其它错误，[VoiceFailure] 之外的 [String] 细节为系统错误码。
  unknown,
}

/// 把失败原因翻译成当前语言的提示文案。
///
/// [detail] 为可选的细节：启动失败/中断时是异常信息，其它错误时是系统错误码。
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
  VoiceFailure.network => l10n.voiceErrorNetwork,
  VoiceFailure.unknown => l10n.voiceErrorUnknown(detail ?? ''),
};
