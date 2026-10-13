import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/practice_scope.dart';
import '../data/practice_stats.dart';
import '../data/practice_store.dart';
import '../theme/app_skin.dart';
import '../voice/mantra_voice_counter.dart';
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
      _toast('第 ${count ~/ beadCount} 串圆满 · 继续精进');
    }
  }

  Future<void> _toggleVoice(PracticeStore store, bool enabled) async {
    if (_voiceBusy || enabled == _voice.isActive) return;
    setState(() => _voiceBusy = true);

    if (enabled) {
      _voice.onRecitation = () => _registerRecitation(store, fromVoice: true);
      await _voice.start();
      if (!mounted) return;
      final error = _voice.error;
      _toast(error ?? '语音计数已开启，念完一遍会自动记数');
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
    _toast('本次功课 $count 遍已记入');
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
    final store = PracticeScope.of(context);
    final stats = store.stats();
    final sessionCount = store.currentCount;
    final beadCount = store.settings.beadCount;
    final hasSession = sessionCount > 0;

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
              error: _voice.error,
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
                    label: const Text('撤销一次'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: hasSession ? () => _finish(store) : null,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('结束本次'),
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
    required this.error,
    required this.busy,
    required this.onChanged,
  });

  final bool listening;
  final String lastHeard;
  final String? error;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    final scheme = Theme.of(context).colorScheme;
    final message = error;

    final String title;
    final String subtitle;
    if (message != null) {
      title = '语音计数不可用';
      subtitle = message;
    } else if (listening) {
      title = '正在聆听';
      subtitle = lastHeard.isEmpty
          ? '念完一遍准提咒会自动记数，念诵时留意上方的遍数变化'
          : '听到：$lastHeard';
    } else {
      title = '语音计数';
      subtitle = '点按钮计数，开启后可语音自动记数';
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
    return Row(
      children: <Widget>[
        Expanded(
          child: _SummaryItem(
            label: '今日持咒',
            value: '${stats.todayCount}',
            unit: '遍',
          ),
        ),
        const _SummaryDivider(),
        Expanded(
          child: _SummaryItem(
            label: '今日圆满',
            value: '${stats.todayBeads}',
            unit: '串',
          ),
        ),
        const _SummaryDivider(),
        Expanded(
          child: _SummaryItem(
            label: '连续持咒',
            value: '${stats.streakDays}',
            unit: '天',
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
