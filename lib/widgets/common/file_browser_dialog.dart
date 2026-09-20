import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../config/app_config.dart';
import '../../config/app_colors.dart';
import 'app_ui.dart';
import 'dialog_utils.dart';

/// 自定义文件浏览器对话框 - 固定宽度，支持目录导航，筛选 .json 文件
///
/// [isSaveMode] 为 true 时用于保存文件（输入文件名 + 保存按钮），
/// 否则用于选取文件（点击 .json 文件返回路径）。
class FileBrowserDialog extends StatefulWidget {
  /// 文件过滤器，返回 true 表示该文件可以被选中
  final bool Function(File file)? fileFilter;

  /// 保存模式：true = 输入文件名保存文件；false = 选取已有文件
  final bool isSaveMode;

  /// 保存模式下预填的文件名
  final String? defaultFileName;

  const FileBrowserDialog({
    super.key,
    this.fileFilter,
    this.isSaveMode = false,
    this.defaultFileName,
  });

  /// 显示文件浏览器对话框，返回选中的文件路径
  ///
  /// 保存模式下返回目标保存路径（目录 + 文件名），选取模式下返回选中文件路径。
  static Future<String?> show(
    BuildContext context, {
    bool Function(File file)? fileFilter,
    bool isSaveMode = false,
    String? defaultFileName,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => FileBrowserDialog(
        fileFilter: fileFilter,
        isSaveMode: isSaveMode,
        defaultFileName: defaultFileName,
      ),
    );
  }

  @override
  State<FileBrowserDialog> createState() => _FileBrowserDialogState();
}

class _FileBrowserDialogState extends State<FileBrowserDialog> {
  Directory? _currentDir;
  late Future<List<FileSystemEntity>> _entitiesFuture;
  late final TextEditingController _fileNameController;
  String? _selectedPath;

  @override
  void initState() {
    super.initState();
    _fileNameController = TextEditingController(
      text: widget.defaultFileName ?? '',
    );
    _fileNameController.addListener(_onFileNameChanged);
    _entitiesFuture = _initAndList();
  }

  @override
  void dispose() {
    _fileNameController.removeListener(_onFileNameChanged);
    _fileNameController.dispose();
    super.dispose();
  }

  void _onFileNameChanged() {
    setState(() {});
  }

  Future<List<FileSystemEntity>> _initAndList() async {
    Directory dir;
    try {
      dir = await getApplicationDocumentsDirectory();
    } catch (e) {
      debugPrint('[FileBrowser] get documents dir failed: $e');
      return [];
    }
    if (mounted) {
      setState(() => _currentDir = dir);
    }
    return _listEntities(dir);
  }

  /// 提取文件/目录名。
  ///
  /// 不能用 [FileSystemEntity.uri] 的 pathSegments 取 last：
  /// 目录 uri 以 `/` 结尾，最后一段是空字符串，会导致目录名显示为空白。
  String _nameOf(FileSystemEntity entity) =>
      entity.path.split(Platform.pathSeparator).last;

  Future<List<FileSystemEntity>> _listEntities(Directory dir) async {
    try {
      final entities = await dir.list().toList();
      entities.sort((a, b) {
        final aDir = a is Directory;
        final bDir = b is Directory;
        if (aDir && !bDir) return -1;
        if (!aDir && bDir) return 1;
        return _nameOf(a).compareTo(_nameOf(b));
      });
      return entities;
    } catch (e) {
      debugPrint('[FileBrowser] list directory failed: $e');
      return [];
    }
  }

  void _navigateTo(Directory dir) {
    setState(() {
      _currentDir = dir;
      _entitiesFuture = _listEntities(dir);
    });
  }

  void _navigateUp() {
    final parent = _currentDir!.parent;
    if (parent.path != _currentDir!.path) {
      _navigateTo(parent);
    }
  }

  void _handleSave() {
    final dir = _currentDir;
    final fileName = _fileNameController.text.trim();
    if (dir == null || fileName.isEmpty) return;
    var name = fileName;
    if (!name.endsWith('.json')) {
      name = '$name.json';
    }
    final sep = dir.path.endsWith(Platform.pathSeparator)
        ? ''
        : Platform.pathSeparator;
    Navigator.pop(context, '${dir.path}$sep$name');
  }

  /// 确认选择当前高亮的文件并返回其路径
  void _handleConfirmSelect() {
    final path = _selectedPath;
    if (path == null) return;
    Navigator.pop(context, path);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: SizedBox(
        width: MediaQuery.of(context).size.width * AppConfig.dialogWidthRatio,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final dir = _currentDir;
    if (dir == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.isSaveMode
              ? StockConfig.fileBrowserExportTitle
              : StockConfig.fileBrowserTitle,
          style: TextStyles.sectionTitle.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        // Current path
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            dir.path,
            style: TextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 8),
        // Go up button
        if (dir.parent.path != dir.path)
          ListTile(
            leading: Icon(Icons.chevron_left, size: 20),
            title: Text(
              StockConfig.fileBrowserGoUp,
              style: TextStyles.listTileTitle,
            ),
            onTap: _navigateUp,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          ),
        const SizedBox(height: 8),
        // File list
        SizedBox(
          height: 200,
          child: FutureBuilder<List<FileSystemEntity>>(
            future: _entitiesFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final entities = snapshot.data!;
              if (entities.isEmpty) {
                return Center(
                  child: Text(
                    StockConfig.fileBrowserEmpty,
                    style: TextStyles.bodySmall,
                  ),
                );
              }
              return Scrollbar(
                child: ListView.builder(
                  itemCount: entities.length,
                  itemBuilder: (context, index) {
                    final entity = entities[index];
                    final name = _nameOf(entity);
                    if (entity is Directory) {
                      return ListTile(
                        leading: Icon(Icons.folder, color: AppColors.warning),
                        title: Text(name, style: TextStyles.listTileTitle),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                        ),
                        onTap: () => _navigateTo(entity),
                      );
                    } else if (entity is File) {
                      final isJson = entity.path.endsWith('.json');
                      if (widget.isSaveMode) {
                        // 保存模式下文件不可选，点击仅用于快速填入文件名
                        return ListTile(
                          leading: Icon(
                            Icons.insert_drive_file,
                            color: isJson
                                ? AppColors.accent
                                : AppColors.textSecondary,
                          ),
                          title: Text(
                            name,
                            style: TextStyles.listTileTitle.copyWith(
                              color: isJson ? null : AppColors.textSecondary,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                          onTap: isJson
                              ? () => _fileNameController.text = name
                              : null,
                        );
                      }
                      final canSelect =
                          widget.fileFilter == null ||
                          widget.fileFilter!(entity);
                      final selected = _selectedPath == entity.path;
                      return ListTile(
                        leading: Icon(
                          Icons.insert_drive_file,
                          color: isJson
                              ? AppColors.accent
                              : AppColors.textSecondary,
                        ),
                        title: Text(
                          name,
                          style: TextStyles.listTileTitle.copyWith(
                            color: isJson && canSelect
                                ? (selected ? AppColors.accent : null)
                                : AppColors.textSecondary,
                          ),
                        ),
                        trailing: isJson && canSelect
                            ? Icon(
                                selected
                                    ? Icons.check_circle
                                    : Icons.check_circle_outline,
                                color: selected
                                    ? AppColors.accent
                                    : AppColors.textSecondary,
                                size: 20,
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                        ),
                        onTap: isJson && canSelect
                            ? () {
                                setState(() {
                                  _selectedPath = selected ? null : entity.path;
                                });
                              }
                            : null,
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              );
            },
          ),
        ),
        if (!widget.isSaveMode) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: Opacity(
              opacity: _selectedPath == null ? 0.4 : 1.0,
              child: confirmButton(
                onTap: _selectedPath == null ? () {} : _handleConfirmSelect,
                text: StockConfig.fileBrowserImportConfirm,
                gradient: const LinearGradient(
                  colors: [AppColors.blueDark, AppColors.blueAccent],
                ),
              ),
            ),
          ),
        ],
        if (widget.isSaveMode) ...[
          const SizedBox(height: 12),
          // File name input
          TextField(
            controller: _fileNameController,
            style: TextStyles.inputText,
            decoration: InputDecoration(
              labelText: StockConfig.fileBrowserFileName,
              labelStyle: TextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.border, width: 0.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.accent, width: 1),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Save button
          SizedBox(
            width: double.infinity,
            child: Opacity(
              opacity: _fileNameController.text.trim().isEmpty ? 0.4 : 1.0,
              child: confirmButton(
                onTap: _fileNameController.text.trim().isEmpty
                    ? () {}
                    : _handleSave,
                text: StockConfig.fileBrowserSave,
                gradient: const LinearGradient(
                  colors: [AppColors.blueDark, AppColors.blueAccent],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
