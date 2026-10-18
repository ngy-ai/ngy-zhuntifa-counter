# 语音识别改用本地运行的 sherpa-onnx

## Status

accepted（2026-10-16）

## 背景与决定

语音计数原先依赖系统语音识别（`speech_to_text` 插件 → Android 的 `SpeechRecognizer` / iOS 的 `SFSpeechRecognizer`），实际识别走厂商或 Google 的云端服务：无网不可用、国内无 GMS 机型基本用不了，还必须声明 `INTERNET` 权限。

决定改为完全本机运行的 [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx)（Apache-2.0，Flutter 入口包 `sherpa_onnx`）：中文流式 zipformer 模型随应用分发，识别不联网、不依赖系统语音服务，`speech_to_text` 及其网络错误语义整体移除。

## 考虑过的替代方案

- **系统识别的离线段（`SpeechListenOptions(onDevice: true)`）**：改动最小，但要求 Android 12+ 且设备装过离线识别包，国内无 GMS 机型仍然不可用，达不到「装上就能用」。
- **Vosk**：可自包含、支持受限词表，但中文小模型质量与插件维护活跃度都不如 sherpa-onnx。
- **Whisper（whisper.cpp）**：非流式，出结果有 1–3 秒延迟，不适合「念完一遍立即计数」的连续聆听场景。
- **运行时下载模型**：包体不变，但引入下载、校验、存储与失败重试等一堆状态，与「离线开箱即用」的目标相矛盾。

## 后果

- APK 体积从约 61MB 增至约 130MB（模型 ≈69MB + 各 ABI 原生库），因此 Android 只打包 `arm64-v8a`。
- 不再需要 `INTERNET` 权限；`RECORD_AUDIO` 仍需保留，且只在用户开启语音计数时占用麦克风。
- 模型跟随应用版本更新，换模型需要发版。
- 咒文比对层（`MantraMatcher`）与识别器解耦，保持不变；识别质量靠真机验收与预置念诵录音的集成测试保障（不放进 CI）。
