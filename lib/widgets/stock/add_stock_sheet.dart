import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/app_colors.dart';
import '../../config/app_config.dart';
import '../../services/exchange_rate_service.dart';
import '../../utils/center_toast.dart';
import '../common/app_number_field.dart';
import '../common/app_ui.dart';

enum AddStockMethod { search, custom }

class CustomStockDraft {
  final String companyName;
  final String stockCode;
  final double shares;
  final double currentPrice;
  final String currency;
  final Uint8List? imageBytes;

  const CustomStockDraft({
    required this.companyName,
    required this.stockCode,
    required this.shares,
    required this.currentPrice,
    required this.currency,
    this.imageBytes,
  });
}

Future<AddStockMethod?> showAddStockMethodSheet(BuildContext context) {
  return showModalBottomSheet<AddStockMethod>(
    context: context,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _BottomSheetFrame(
      title: StockConfig.addStockMethodTitle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MethodTile(
            icon: Icons.search,
            color: AppColors.accent,
            title: StockConfig.addStockBySearch,
            onTap: () => Navigator.pop(context, AddStockMethod.search),
          ),
          Divider(height: 1, color: AppColors.border),
          _MethodTile(
            icon: Icons.edit_note,
            color: AppColors.warning,
            title: StockConfig.addCustomStock,
            onTap: () => Navigator.pop(context, AddStockMethod.custom),
          ),
        ],
      ),
    ),
  );
}

Future<CustomStockDraft?> showCustomStockSheet(
  BuildContext context, {
  required String initialCurrency,
  required Set<String> existingSymbols,
}) {
  return showModalBottomSheet<CustomStockDraft>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CustomStockSheet(
      initialCurrency: initialCurrency,
      existingSymbols: existingSymbols,
    ),
  );
}

class _BottomSheetFrame extends StatelessWidget {
  final String title;
  final Widget child;

  const _BottomSheetFrame({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.separator,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              Text(title, style: TextStyles.sectionTitle),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border, width: 0.5),
                  borderRadius: BorderRadius.circular(14),
                ),
                clipBehavior: Clip.antiAlias,
                child: Material(color: Colors.transparent, child: child),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final VoidCallback onTap;

  const _MethodTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: TextStyles.bodyMedium),
      trailing: Icon(Icons.chevron_right, color: AppColors.textSecondary),
    );
  }
}

class _CustomStockSheet extends StatefulWidget {
  final String initialCurrency;
  final Set<String> existingSymbols;

  const _CustomStockSheet({
    required this.initialCurrency,
    required this.existingSymbols,
  });

  @override
  State<_CustomStockSheet> createState() => _CustomStockSheetState();
}

class _CustomStockSheetState extends State<_CustomStockSheet> {
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _sharesController = TextEditingController();
  final _priceController = TextEditingController();
  final _imagePicker = ImagePicker();
  late String _currency;
  Uint8List? _imageBytes;
  bool _pickingImage = false;

  @override
  void initState() {
    super.initState();
    _currency = widget.initialCurrency;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _sharesController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickFromPhotos() async {
    await _pickImage(() async {
      final file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      return file?.readAsBytes();
    });
  }

  Future<void> _pickFromFiles() async {
    await _pickImage(() async {
      final files = await FilePicker.pickFiles(type: FileType.image);
      final file = files.firstOrNull;
      return file?.readAsBytes();
    });
  }

  Future<void> _pickImage(Future<Uint8List?> Function() pick) async {
    if (_pickingImage) return;
    setState(() => _pickingImage = true);
    try {
      final bytes = await pick();
      if (bytes != null && mounted) setState(() => _imageBytes = bytes);
    } catch (_) {
      if (mounted)
        CenterToast.error(context, StockConfig.customStockImageFailed);
    } finally {
      if (mounted) setState(() => _pickingImage = false);
    }
  }

  void _submit() {
    final name = _nameController.text.trim();
    final code = _codeController.text.trim().toUpperCase();
    final shares = double.tryParse(_sharesController.text);
    final price = double.tryParse(_priceController.text);
    if (name.isEmpty) {
      CenterToast.warning(context, StockConfig.customStockNameRequired);
      return;
    }
    if (code.isEmpty) {
      CenterToast.warning(context, StockConfig.customStockCodeRequired);
      return;
    }
    final hasConflict = widget.existingSymbols.any(
      (symbol) => symbol.trim().toUpperCase() == code,
    );
    if (hasConflict) {
      CenterToast.warning(
        context,
        StockConfig.customStockCodeConflict.replaceAll('{code}', code),
      );
      return;
    }
    if (shares == null || shares <= 0) {
      CenterToast.warning(context, StockConfig.customStockInvalidShares);
      return;
    }
    if (price == null || price <= 0) {
      CenterToast.warning(context, StockConfig.customStockInvalidPrice);
      return;
    }
    Navigator.pop(
      context,
      CustomStockDraft(
        companyName: name,
        stockCode: code,
        shares: shares,
        currentPrice: price,
        currency: _currency,
        imageBytes: _imageBytes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: FractionallySizedBox(
        heightFactor: 0.9,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
                  child: Column(
                    children: [
                      Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.separator,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(
                              Icons.close,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              StockConfig.addCustomStock,
                              textAlign: TextAlign.center,
                              style: TextStyles.sectionTitle,
                            ),
                          ),
                          TextButton(
                            onPressed: _submit,
                            child: Text(AppConfig.btnAdd),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: AppColors.border),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildImagePicker(),
                        const SizedBox(height: 20),
                        _buildIdentityFields(),
                        const SizedBox(height: 16),
                        AppNumberField(
                          controller: _sharesController,
                          label: StockConfig.customStockShares,
                          hintText: StockConfig.customStockSharesHint,
                        ),
                        const SizedBox(height: 16),
                        AppNumberField(
                          controller: _priceController,
                          label: StockConfig.customStockPrice,
                          hintText: StockConfig.customStockPriceHint,
                        ),
                        const SizedBox(height: 16),
                        _buildCurrencyField(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(StockConfig.customStockImage, style: TextStyles.body13Bold),
        const SizedBox(height: 10),
        Row(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: _imageBytes == null
                  ? Icon(Icons.image_outlined, color: AppColors.textTertiary)
                  : Image.memory(_imageBytes!, fit: BoxFit.cover),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickingImage ? null : _pickFromPhotos,
                    style: _imagePickerButtonStyle(),
                    icon: Icon(
                      Icons.photo_library_outlined,
                      size: 18,
                      color: AppColors.accent,
                    ),
                    label: Text(StockConfig.customStockChooseAlbum),
                  ),
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    onPressed: _pickingImage ? null : _pickFromFiles,
                    style: _imagePickerButtonStyle(),
                    icon: Icon(
                      Icons.folder_open_outlined,
                      size: 18,
                      color: AppColors.accent,
                    ),
                    label: Text(StockConfig.customStockChooseFile),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  ButtonStyle _imagePickerButtonStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: AppColors.accent,
      backgroundColor: AppColors.imagePickerBackground,
      side: BorderSide(color: AppColors.imagePickerBorder, width: 0.7),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _buildIdentityFields() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildTextField(
            label: StockConfig.customStockName,
            hint: StockConfig.customStockNameHint,
            controller: _nameController,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildTextField(
            label: StockConfig.customStockCode,
            hint: StockConfig.customStockCodeHint,
            controller: _codeController,
            capitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9._-]')),
              _UpperCaseTextFormatter(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    TextCapitalization capitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyles.body13Bold),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          textInputAction: TextInputAction.next,
          textCapitalization: capitalization,
          inputFormatters: inputFormatters,
          style: TextStyles.inputText,
          decoration: _inputDecoration(hint),
        ),
      ],
    );
  }

  Widget _buildCurrencyField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(StockConfig.customStockCurrency, style: TextStyles.body13Bold),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _currency,
              isExpanded: true,
              dropdownColor: AppColors.surfaceElevated,
              style: TextStyles.inputText,
              items: ExchangeRateService.supportedCurrencies
                  .map(
                    (currency) => DropdownMenuItem(
                      value: currency,
                      child: Text(currency),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _currency = value);
              },
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: AppColors.border),
    );
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyles.hintText,
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.accent),
      ),
    );
  }
}

class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
