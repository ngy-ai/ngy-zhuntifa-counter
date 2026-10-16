import 'dart:convert';

import 'package:file_picker/file_picker.dart';

/// 读取备份文件内容；用户在系统选择器里取消时返回 null。
///
/// 抽成函数类型是为了在测试里替换成假实现，避免真的弹出系统文件选择器。
typedef BackupFileReader = Future<String?> Function();

/// 当前使用的备份文件读取实现（默认为 [pickBackupFile]，测试里可替换）。
BackupFileReader backupFileReader = pickBackupFile;

/// 弹出系统文件选择器，读取选中的备份文件内容。
///
/// 备份文件是本应用导出的 UTF-8 JSON；选了别的文件也没关系，
/// 内容解析不出来时由导入流程按备份格式错误提示。
Future<String?> pickBackupFile() async {
  final file = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: <String>['json'],
  );
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  return utf8.decode(bytes, allowMalformed: true);
}
