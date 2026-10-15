import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/practice_scope.dart';
import '../data/practice_stats.dart';
import '../data/practice_store.dart';
import '../l10n/gen/app_localizations.dart';
import '../theme/app_skin.dart';
import '../voice/mantra_voice_counter.dart';
import '../voice/voice_failure.dart';
import '../widgets/practice_dial.dart';

/// 功课页面：每念一遍准提咒点一次计数，也可以开启语音自动计数。
class PracticePage extends StatefulWidget {
  const PracticePage({super.key, this.voiceCounter});

  /// 语音计数器，测试时可注入替身。
  final VoiceCounter? voiceCounter;

  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage>
    with WidgetsBindingObserver {
  /// 定时刷新，保证跨零点时「今日」统计自动归零。
  Timer? _ticker;

  late final VoiceCounter _voice;
  late final bool _ownsVoice;
  bool _voiceBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    _ownsVoice = widget.voiceCounter == null;
    _voice = widget.voiceCounter ?? MantraVoiceCounter();
    _voice.addListener(_handleVoiceChanged);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _voice.removeListener(_handleVoiceChanged);
    if (_ownsVoice) _voice.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 退到后台就停止聆听，别一直占着麦克风
    if (state != AppLifecycleState.resumed && _voice.isActive) {
      unawaited(_voice.stop());
    }
  }

  void _handleVoiceChanged() {
    if (mounted) setState(() {});
  }

  /// 记一遍。语音判定圆满与手动点击走的都是这里。
  void _registerRecitation(PracticeStore store, {bool fromVoice = false}) {
    final beadCount = store.settings.beadCount > 0
        ? store.settings.beadCount
        : 108;
    store.tap();
    final count = store.currentCount;
    final completedBead = count > 0 && count % beadCount == 0;

    if (store.settings.hapticsEnabled) {
      unawaited(
        completedBead
            ? HapticFeedback.mediumImpact()
            : HapticFeedback.selectionClick(),
      );
    }
    // 语音计数时不放提示音，免得被麦克风收进去
    if (store.settings.soundEnabled && !fromVoice) {
      unawaited(SystemSound.play(SystemSoundType.click));
    }
    if (completedBead) {
      _toast(
        AppLocalizations.of(
          context,
        ).practiceBeadRound(count ~/ beadCount),
      );
    }
  }

  Future<void> _toggleVoice(PracticeStore store, bool enabled) async {
    if (_voiceBusy || enabled == _voice.isActive) return;
    setState(() => _voiceBusy = true);

    if (enabled) {
      _voice.onRecitation = () => _registerRecitation(store, fromVoice: true);
      await _voice.start();
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      final failure = _voice.failure;
      _toast(
        failure == null
            ? l10n.practiceVoiceStarted
            : voiceFailureMessage(l10n, failure, _voice.failureDetail),
      );
    } else {
      await _voice.stop();
    }

    if (mounted) setState(() => _voiceBusy = false);
  }

  void _undo(PracticeStore store) {
    if (!store.undo()) return;
    if (store.settings.hapticsEnabled) {
      unawaited(HapticFeedback.lightImpact());
    }
  }

  void _finish(PracticeStore store) {
    final count = store.currentCount;
    final finished = store.finishCurrent();
    if (finished == null) return;
    _toast(AppLocalizations.of(context).practiceSessionSaved(count));
  }

  void _toast(String message) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(milliseconds: 1800),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final store = PracticeScope.of(context);
    final stats = store.stats();
    final sessionCount = store.currentCount;
    final beadCount = store.settings.beadCount;
    final hasSession = sessionCount > 0;
    final failure = _voice.failure;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: Column(
          children: <Widget>[
            _SummaryBar(stats: stats),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: PracticeDial(
                  sessionCount: sessionCount,
                  beadCount: beadCount,
                  onTap: () => _registerRecitation(store),
                ),
              ),
            ),
            _VoiceBar(
              listening: _voice.isActive,
              lastHeard: _voice.lastHeard,
              retryErrorCode: _voice.retryErrorCode,
              heardNothing: _voice.heardNothing,
              error: failure == null
                  ? null
                  : voiceFailureMessage(l10n, failure, _voice.failureDetail),
              busy: _voiceBusy,
              onChanged: (value) => unawaited(_toggleVoice(store, value)),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: hasSession ? () => _undo(store) : null,
                    icon: const Icon(Icons.undo_rounded, size: 18),
                    label: Text(l10n.practiceUndo),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: hasSession ? () => _finish(store) : null,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: Text(l10n.practiceFinish),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 语音计数开关与识别回显。
class _VoiceBar extends StatelessWidget {
  const _VoiceBar({
    required this.listening,
    required this.lastHeard,
    required this.retryErrorCode,
    required this.heardNothing,
    required this.error,
    required this.busy,
    required this.onChanged,
  });

  final bool listening;
  final String lastHeard;

  /// 可恢复的识别问题（如 error_network），提示用户正在自动重试。
  final String? retryErrorCode;

  /// 开启后一直没听到声音，提示用户检查麦克风与念诵距离。
  final bool heardNothing;
  final String? error;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final skin = AppSkin.of(context);
    final scheme = Theme.of(context).colorScheme;
    final message = error;

    final String title;
    final String subtitle;
    if (message != null) {
      title = l10n.voiceUnavailableTitle;
      subtitle = message;
    } else if (listening) {
      final retryCode = retryErrorCode;
      title = l10n.voiceListeningTitle;
      if (retryCode != null) {
        subtitle = l10n.voiceRetrying(retryCode);
      } else if (heardNothing) {
        subtitle = l10n.voiceNoSoundHint;
      } else {
        subtitle = lastHeard.isEmpty
            ? l10n.voiceListeningHint
            : l10n.voiceHeard(lastHeard);
      }
    } else {
      title = l10n.voiceTitle;
      subtitle = l10n.voiceIdleHint;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: skin.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: listening
              ? skin.primary.withValues(alpha: 0.55)
              : skin.outlineVariant,
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            message != null
                ? Icons.mic_off_rounded
                : (listening ? Icons.mic_rounded : Icons.mic_none_rounded),
            size: 20,
            color: message != null
                ? scheme.error
                : (listening ? skin.primary : skin.outline),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: message != null ? scheme.error : skin.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: message != null
                        ? scheme.error
                        : skin.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: listening,
            onChanged: busy ? null : onChanged,
          ),
        ],
      ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.stats});

  final PracticeStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: <Widget>[
        Expanded(
          child: _SummaryItem(
            label: l10n.practiceTodayCount,
            value: '${stats.todayCount}',
            unit: l10n.unitCount,
          ),
        ),
        const _SummaryDivider(),
        Expanded(
          child: _SummaryItem(
            label: l10n.practiceTodayRounds,
            value: '${stats.todayBeads}',
            unit: l10n.unitRound,
          ),
        ),
        const _SummaryDivider(),
        Expanded(
          child: _SummaryItem(
            label: l10n.homeStreak,
            value: '${stats.streakDays}',
            unit: l10n.unitDay,
          ),
        ),
      ],
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: <Widget>[
        Text(
          label,
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        RichText(
          text: TextSpan(
            style: DefaultTextStyle.of(context).style,
            children: <InlineSpan>[
              TextSpan(
                text: value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
              TextSpan(
                text: ' $unit',
                style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryDivider extends StatelessWidget {
  const _SummaryDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 30,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}
