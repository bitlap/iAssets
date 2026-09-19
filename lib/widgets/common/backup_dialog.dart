import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../config/app_colors.dart';
import '../../utils/center_toast.dart';
import '../common/app_ui.dart';
import '../common/confirm_delete_dialog.dart';
import '../common/file_browser_dialog.dart';
import '../../services/backup_service.dart';

class BackupDialog extends StatefulWidget {
  final VoidCallback? onDataChanged;
  final BuildContext? rootContext;

  const BackupDialog({super.key, this.onDataChanged, this.rootContext});

  @override
  State<BackupDialog> createState() => _BackupDialogState();
}

class _BackupDialogState extends State<BackupDialog> {
  bool _hasBackup = false;

  @override
  void initState() {
    super.initState();
    _checkBackup();
  }

  Future<void> _checkBackup() async {
    final has = await BackupService.hasRollbackBackup();
    if (mounted) {
      setState(() => _hasBackup = has);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: SizedBox(
        width: MediaQuery.of(context).size.width * AppConfig.dialogWidthRatio,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Material(
            color: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    StockConfig.backupTitle,
                    style: TextStyles.sectionTitle.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Divider(thickness: 0.5, color: AppColors.border),
                ListTile(
                  leading: Icon(Icons.upload_file, color: AppColors.accent),
                  title: Text(
                    StockConfig.backupExport,
                    style: TextStyles.listTileTitle,
                  ),
                  subtitle: Text(
                    StockConfig.backupExportDesc,
                    style: TextStyles.bodySmall,
                  ),
                  onTap: _handleExport,
                ),
                Divider(thickness: 0.5, color: AppColors.border),
                ListTile(
                  leading: Icon(Icons.download, color: AppColors.warning),
                  title: Text(
                    StockConfig.backupImport,
                    style: TextStyles.listTileTitle,
                  ),
                  subtitle: Text(
                    StockConfig.backupImportDesc,
                    style: TextStyles.bodySmall,
                  ),
                  onTap: _handleImport,
                ),
                if (_hasBackup) ...[
                  Divider(thickness: 0.5, color: AppColors.border),
                  ListTile(
                    leading: Icon(Icons.restore, color: AppColors.danger),
                    title: Text(
                      StockConfig.backupRollback,
                      style: TextStyles.listTileTitle.copyWith(
                        color: AppColors.danger,
                      ),
                    ),
                    subtitle: Text(
                      StockConfig.backupRollbackDesc,
                      style: TextStyles.bodySmall,
                    ),
                    onTap: _handleRollback,
                  ),
                ],
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleExport() async {
    final parentCtx = widget.rootContext;
    if (parentCtx == null || !mounted) return;

    final now = DateTime.now();
    final defaultName =
        'iassets_backup_${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}.json';

    // 文件浏览器展示在备份弹窗上方，关闭备份弹窗在其返回后进行
    final targetPath = await FileBrowserDialog.show(
      parentCtx,
      isSaveMode: true,
      defaultFileName: defaultName,
    );
    if (mounted) Navigator.pop(context);
    if (targetPath == null) return;

    final ok = await BackupService.exportToFile(targetPath);
    if (ok) {
      // ignore: use_build_context_synchronously
      CenterToast.success(parentCtx, StockConfig.backupExportSuccess);
    } else {
      // ignore: use_build_context_synchronously
      CenterToast.error(parentCtx, StockConfig.backupExportFail);
    }
  }

  Future<void> _handleImport() async {
    final parentCtx = widget.rootContext;
    if (parentCtx == null || !mounted) return;

    // 文件浏览器展示在备份弹窗上方，关闭备份弹窗在其返回后进行
    final selectedPath = await FileBrowserDialog.show(
      parentCtx,
      fileFilter: (file) => file.path.endsWith('.json'),
    );
    if (mounted) Navigator.pop(context);
    if (selectedPath == null) return;

    String jsonText;
    try {
      jsonText = await File(selectedPath).readAsString();
    } catch (e) {
      // ignore: use_build_context_synchronously
      CenterToast.error(parentCtx, StockConfig.backupImportFail);
      return;
    }

    Map<String, dynamic> data;
    try {
      data = jsonDecode(jsonText) as Map<String, dynamic>;
    } catch (e) {
      // ignore: use_build_context_synchronously
      CenterToast.error(parentCtx, StockConfig.backupImportFail);
      return;
    }

    if (!BackupService.validateImportData(data)) {
      // ignore: use_build_context_synchronously
      CenterToast.error(parentCtx, StockConfig.backupImportFail);
      return;
    }

    try {
      final ok = await BackupService.importAll(data);
      if (ok) {
        // ignore: use_build_context_synchronously
        CenterToast.success(parentCtx, StockConfig.backupImportSuccess);
        widget.onDataChanged?.call();
      } else {
        // ignore: use_build_context_synchronously
        CenterToast.error(parentCtx, StockConfig.backupImportFail);
      }
    } catch (e) {
      // ignore: use_build_context_synchronously
      CenterToast.error(parentCtx, StockConfig.backupImportFail);
    }
  }

  Future<void> _handleRollback() async {
    final parentCtx = widget.rootContext;
    if (parentCtx == null || !mounted) return;
    final confirmed = await ConfirmDeleteDialog.show(
      context,
      title: StockConfig.backupRollback,
      content: StockConfig.backupRollbackConfirm,
      confirmText: StockConfig.btnConfirmRollback,
      icon: Icons.restore,
    );
    if (!confirmed || !mounted) return;

    // 确认后关闭备份弹窗，再用页面级 context 提示结果
    if (mounted) Navigator.pop(context);

    try {
      final ok = await BackupService.rollbackFromBackup();
      if (ok) {
        // ignore: use_build_context_synchronously
        CenterToast.success(parentCtx, StockConfig.backupRollbackSuccess);
        widget.onDataChanged?.call();
      } else {
        // ignore: use_build_context_synchronously
        CenterToast.error(parentCtx, StockConfig.backupRollbackFail);
      }
    } catch (e) {
      // ignore: use_build_context_synchronously
      CenterToast.error(parentCtx, StockConfig.backupRollbackFail);
    }
  }
}
