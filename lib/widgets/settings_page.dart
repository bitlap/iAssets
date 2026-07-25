import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/currency_util.dart';
import '../services/exchange_rate_service.dart';
import '../utils/center_toast.dart';
import '../services/settings_service.dart';
import '../config/app_config.dart';
import '../config/app_colors.dart';
import '../config/sort_options.dart';
import '../widgets/common/app_ui.dart';
import '../models/settings/open_source_lib.dart';
import 'common/app_number_field.dart';
import 'common/settings_expansion_card.dart';
import 'common/dialog_utils.dart';

/// 全屏设置页面
class SettingsPage extends StatefulWidget {
  final String currentCurrency;
  final ValueChanged<String> onCurrencyChanged;
  final ValueChanged<String> onSortChanged;
  final ValueChanged<bool> onSortDirectionChanged;
  final VoidCallback? onSyncToggled;
  final ValueChanged<bool>? onKeepStockChanged;
  final VoidCallback? onSettingsChanged;

  const SettingsPage({
    super.key,
    required this.currentCurrency,
    required this.onCurrencyChanged,
    required this.onSortChanged,
    required this.onSortDirectionChanged,
    this.onSyncToggled,
    this.onKeepStockChanged,
    this.onSettingsChanged,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late String _selectedCurrency;
  bool _isCurrencyExpanded = false;
  bool _isSortExpanded = false;
  bool _keepStockAfterClose = true;
  String _selectedSortColumn = 'profit';
  bool _isSortAscending = false;
  bool _syncSettings = true;
  bool _isFeeExpanded = false;
  String _selectedFeeType = SettingsService.feeTypePercentage;
  late TextEditingController _feeValueController;

  @override
  void initState() {
    super.initState();
    _selectedCurrency = widget.currentCurrency;
    _feeValueController = TextEditingController();
    _feeValueController.addListener(_onFeeValueChanged);
    _loadSettings();
  }

  @override
  void dispose() {
    _saveFeeValue();
    _feeValueController.removeListener(_onFeeValueChanged);
    _feeValueController.dispose();
    super.dispose();
  }

  Future<void> _onFeeValueChanged() async {
    await _saveFeeValue();
  }

  Future<void> _saveFeeValue() async {
    final text = _feeValueController.text;
    if (text.isEmpty) return;
    final value = double.tryParse(text);
    if (value == null) return;
    await SettingsService.setDefaultFeeValue(value);
    widget.onSettingsChanged?.call();
  }

  void _loadSettings() async {
    final keepStock = await SettingsService.getKeepStockAfterClose();
    final sortColumn = await SettingsService.getSortColumn();
    final sortAscending = await SettingsService.getSortAscending();
    final syncSettings = await SettingsService.getSyncSettings();
    final feeType = await SettingsService.getDefaultFeeType();
    final feeValue = await SettingsService.getDefaultFeeValue();
    if (mounted) {
      setState(() {
        _keepStockAfterClose = keepStock;
        _selectedSortColumn = sortColumn;
        _isSortAscending = sortAscending;
        _syncSettings = syncSettings;
        _selectedFeeType = feeType;
        _feeValueController.text = feeValue > 0
            ? CurrencyUtil.formatRate(feeValue)
            : '';
      });
    }
  }

  void _onSortChanged(String column) {
    setState(() => _selectedSortColumn = column);
    widget.onSortChanged(column);
    widget.onSortDirectionChanged(_isSortAscending);
    widget.onSettingsChanged?.call();
  }

  void _toggleSortDirection() {
    final newAscending = !_isSortAscending;
    setState(() => _isSortAscending = newAscending);
    widget.onSortDirectionChanged(newAscending);
    widget.onSettingsChanged?.call();
  }

  void _onKeepStockChanged(bool value) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value
                  ? SettingsConfig.keepStockOnLabel
                  : SettingsConfig.keepStockOffLabel,
              style: TextStyles.sectionTitle,
            ),
            const SizedBox(height: 8),
            Text(
              value
                  ? SettingsConfig.keepStockOnDesc
                  : SettingsConfig.keepStockOffDesc,
              style: TextStyles.body13.copyWith(
                color: Colors.grey[400],
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              AppConfig.btnCancel,
              style: TextStyles.body13.copyWith(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _keepStockAfterClose = value);
              widget.onKeepStockChanged?.call(value);
              widget.onSettingsChanged?.call();
            },
            child: const Text(
              AppConfig.btnClose,
              style: TextStyle(color: AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }

  void _onCurrencySelected(String currency) {
    setState(() => _selectedCurrency = currency);
    widget.onCurrencyChanged(currency);
    widget.onSettingsChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        toolbarHeight: 44,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          SettingsConfig.settingsTitle,
          style: TextStyles.sectionTitle.copyWith(fontSize: 17),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          _buildSectionHeader(
            Icons.currency_exchange,
            SettingsConfig.sectionCurrency,
          ),
          const SizedBox(height: 8),
          _buildCurrencySection(),
          const SizedBox(height: 24),
          _buildSectionHeader(Icons.trending_up, SettingsConfig.sectionStock),
          const SizedBox(height: 8),
          _buildStockSettingsGroup(),
          const SizedBox(height: 24),
          _buildSectionHeader(Icons.sync, SettingsConfig.sectionSync),
          const SizedBox(height: 8),
          _buildSyncGroup(),
          const SizedBox(height: 24),
          _buildSectionHeader(Icons.more_horiz, SettingsConfig.sectionOther),
          const SizedBox(height: 8),
          _buildOtherGroup(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.accent),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyles.smallBold.copyWith(
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencySection() {
    final effectiveRates = ExchangeRateService().effectiveRates;
    return SettingsExpansionCard(
      initiallyExpanded: _isCurrencyExpanded,
      onExpansionChanged: (expanded) =>
          setState(() => _isCurrencyExpanded = expanded),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                _selectedCurrency.substring(0, 1),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _selectedCurrency,
            style: TextStyles.bodyMedium.copyWith(height: 1.2),
          ),
          const SizedBox(width: 8),
          Text(
            '${CurrencyUtil.getSymbol(_selectedCurrency)} ${CurrencyUtil.formatRate(effectiveRates[_selectedCurrency] ?? 1.0)}',
            style: TextStyles.bodySmall,
          ),
        ],
      ),
      trailing: Icon(
        _isCurrencyExpanded ? Icons.expand_less : Icons.expand_more,
        color: Colors.grey[500],
        size: 22,
      ),
      children: ExchangeRateService.supportedCurrencies.map((currency) {
        final isSelected = currency == _selectedCurrency;
        final rate = effectiveRates[currency]!;
        final symbol = CurrencyUtil.getSymbol(currency);
        final isLast = currency == ExchangeRateService.supportedCurrencies.last;
        return SettingsSelectableItem(
          label: currency,
          trailingText: '$symbol ${CurrencyUtil.formatRate(rate)}',
          isSelected: isSelected,
          isLast: isLast,
          onTap: () => _onCurrencySelected(currency),
        );
      }).toList(),
    );
  }

  Widget _buildStockSettingsGroup() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            _buildKeepStockTile(),
            _buildGroupDivider(),
            _buildFeeTile(),
            _buildGroupDivider(),
            _buildSortTile(),
          ],
        ),
      ),
    );
  }

  Widget _buildFeeTile() {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: _isFeeExpanded,
        onExpansionChanged: (expanded) =>
            setState(() => _isFeeExpanded = expanded),
        tilePadding: const EdgeInsets.fromLTRB(14, 0, 12, 0),
        childrenPadding: EdgeInsets.zero,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.receipt_long,
                size: 18,
                color: Colors.teal,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Row(
                children: [
                  const Text(
                    SettingsConfig.sectionFee,
                    style: TextStyles.bodyMedium,
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: _showFeeHelp,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.help_outline,
                        size: 16,
                        color: Colors.teal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        trailing: Icon(
          _isFeeExpanded ? Icons.expand_less : Icons.expand_more,
          size: 22,
          color: Colors.grey[500],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 类型选择
                Row(
                  children: [
                    _buildFeeTypeChip(
                      SettingsConfig.feeTypePercentage,
                      SettingsService.feeTypePercentage,
                    ),
                    const SizedBox(width: 8),
                    _buildFeeTypeChip(
                      SettingsConfig.feeTypeFixed,
                      SettingsService.feeTypeFixed,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // 值输入（费率或固定金额）
                AppNumberField(
                  controller: _feeValueController,
                  label: _selectedFeeType == SettingsService.feeTypePercentage
                      ? SettingsConfig.feeValueLabel
                      : SettingsConfig.feeAmountLabel,
                  hintText:
                      _selectedFeeType == SettingsService.feeTypePercentage
                      ? SettingsConfig.feeValueHint
                      : SettingsConfig.feeAmountHint,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeeTypeChip(String label, String type) {
    final isSelected = _selectedFeeType == type;
    return GestureDetector(
      onTap: () async {
        setState(() => _selectedFeeType = type);
        await SettingsService.setDefaultFeeType(type);
        widget.onSettingsChanged?.call();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.teal.withValues(alpha: 0.2)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? Colors.teal.withValues(alpha: 0.5)
                : AppColors.border,
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isSelected ? Colors.teal : Colors.grey[300],
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  void _showFeeHelp() {
    showHelpDialog(
      context,
      title: SettingsConfig.feeHelpTitle,
      icon: Icons.info_outline,
      iconColor: Colors.teal,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HintRow(
            color: Colors.greenAccent,
            label: SettingsConfig.feeTypePercentage,
            desc: SettingsConfig.feeHelpRate,
          ),
          const SizedBox(height: 12),
          const HintRow(
            color: Colors.orangeAccent,
            label: SettingsConfig.feeTypeFixed,
            desc: SettingsConfig.feeHelpFixed,
          ),
        ],
      ),
    );
  }

  void _showKeepStockHint() {
    showHelpDialog(
      context,
      title: SettingsConfig.keepStockLabel,
      icon: Icons.info_outline,
      iconColor: Colors.orange,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HintRow(
            color: Colors.greenAccent,
            label: SettingsConfig.keepStockOnLabel,
            desc: SettingsConfig.keepStockOnDesc,
          ),
          const SizedBox(height: 12),
          const HintRow(
            color: Colors.redAccent,
            label: SettingsConfig.keepStockOffLabel,
            desc: SettingsConfig.keepStockOffDesc,
          ),
        ],
      ),
    );
  }

  Widget _buildGroupDivider() {
    return const Padding(
      padding: EdgeInsets.only(left: 48),
      child: Divider(height: 1, color: AppColors.border, thickness: 0.5),
    );
  }

  Widget _buildKeepStockTile() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.swap_horiz, size: 18, color: Colors.orange),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    SettingsConfig.keepStockLabel,
                    style: TextStyles.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: _showKeepStockHint,
                  child: Icon(
                    Icons.help_outline,
                    size: 16,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _keepStockAfterClose,
            onChanged: _onKeepStockChanged,
            activeTrackColor: AppColors.accent.withValues(alpha: 0.6),
            activeThumbColor: AppColors.accent,
            inactiveThumbColor: Colors.grey[600],
            inactiveTrackColor: Colors.grey[800],
          ),
        ],
      ),
    );
  }

  Widget _buildSortTile() {
    final sortLabel = sortOptions.firstWhere(
      (o) => o['key'] == _selectedSortColumn,
      orElse: () => sortOptions.first,
    )['label']!;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: _isSortExpanded,
        onExpansionChanged: (expanded) =>
            setState(() => _isSortExpanded = expanded),
        tilePadding: const EdgeInsets.fromLTRB(14, 0, 12, 0),
        childrenPadding: EdgeInsets.zero,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.sort,
                size: 18,
                color: Colors.purpleAccent,
              ),
            ),
            const SizedBox(width: 10),
            const Text(SettingsConfig.sortLabel, style: TextStyles.bodyMedium),
            const SizedBox(width: 8),
            Text(
              sortLabel,
              style: TextStyles.body13.copyWith(color: Colors.grey[500]),
            ),
          ],
        ),
        trailing: Icon(
          _isSortExpanded ? Icons.expand_less : Icons.expand_more,
          color: Colors.grey[500],
          size: 22,
        ),
        children: [
          ...sortOptions.map((option) {
            final key = option['key']!;
            final label = option['label']!;
            final isSelected = _selectedSortColumn == key;
            return InkWell(
              onTap: () => _onSortChanged(key),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.accent.withValues(alpha: 0.08)
                      : null,
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 42),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          color: isSelected
                              ? AppColors.accent
                              : Colors.grey[300],
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (isSelected)
                      const Icon(
                        Icons.check,
                        size: 18,
                        color: AppColors.accent,
                      ),
                  ],
                ),
              ),
            );
          }),
          // 排序方向切换
          const Padding(
            padding: EdgeInsets.only(left: 56),
            child: Divider(height: 1, color: AppColors.border, thickness: 0.5),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
            child: Row(
              children: [
                const SizedBox(width: 42),
                Text(
                  SettingsConfig.sortDirectionLabel,
                  style: TextStyles.subtitleRegular.copyWith(
                    color: Colors.grey,
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    GestureDetector(
                      onTap: _isSortAscending ? null : _toggleSortDirection,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: _isSortAscending
                              ? AppColors.accent.withValues(alpha: 0.25)
                              : AppColors.surface,
                          borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(8),
                          ),
                          border: Border.all(
                            color: _isSortAscending
                                ? AppColors.accent.withValues(alpha: 0.5)
                                : AppColors.border,
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.arrow_upward,
                              size: 14,
                              color: _isSortAscending
                                  ? AppColors.accent
                                  : Colors.grey[400],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              SettingsConfig.sortAscending,
                              style: TextStyle(
                                fontSize: 13,
                                color: _isSortAscending
                                    ? AppColors.accent
                                    : Colors.grey[300],
                                fontWeight: _isSortAscending
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _isSortAscending ? _toggleSortDirection : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: !_isSortAscending
                              ? AppColors.accent.withValues(alpha: 0.25)
                              : AppColors.surface,
                          borderRadius: const BorderRadius.horizontal(
                            right: Radius.circular(8),
                          ),
                          border: Border.all(
                            color: !_isSortAscending
                                ? AppColors.accent.withValues(alpha: 0.5)
                                : AppColors.border,
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.arrow_downward,
                              size: 14,
                              color: !_isSortAscending
                                  ? AppColors.accent
                                  : Colors.grey[400],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              SettingsConfig.sortDescending,
                              style: TextStyle(
                                fontSize: 13,
                                color: !_isSortAscending
                                    ? AppColors.accent
                                    : Colors.grey[300],
                                fontWeight: !_isSortAscending
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncGroup() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          _buildSyncTile(
            Icons.cloud_outlined,
            Colors.blueAccent,
            SettingsConfig.syncSettingsLabel,
            _syncSettings,
            (v) => setState(() {
              _syncSettings = v;
              SettingsService.setSyncSettings(v);
              if (v) {
                widget.onSyncToggled?.call();
              }
            }),
            onHelp: _showSyncHelp,
          ),
        ],
      ),
    );
  }

  void _showSyncHelp() {
    showHelpDialog(
      context,
      title: SettingsConfig.syncSettingsLabel,
      icon: Icons.info_outline,
      iconColor: Colors.blueAccent,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HintRow(
            color: Colors.blueAccent,
            label: SettingsConfig.syncItemSettings,
            desc: SettingsConfig.syncHelpSettingsDesc,
          ),
          const SizedBox(height: 12),
          const HintRow(
            color: AppColors.greenAccent,
            label: SettingsConfig.syncItemStocks,
            desc: SettingsConfig.syncHelpStocksDesc,
          ),
          const SizedBox(height: 12),
          const HintRow(
            color: Colors.orangeAccent,
            label: SettingsConfig.syncItemRecords,
            desc: SettingsConfig.syncHelpRecordsDesc,
          ),
          const SizedBox(height: 16),
          Text(
            SettingsConfig.syncPrivacyNote,
            style: TextStyles.bodySmall.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncTile(
    IconData icon,
    Color iconColor,
    String label,
    bool value,
    ValueChanged<bool> onChanged, {
    VoidCallback? onHelp,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    label,
                    style: TextStyles.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onHelp != null) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: onHelp,
                    child: Icon(Icons.help_outline, size: 16, color: iconColor),
                  ),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.accent.withValues(alpha: 0.6),
            activeThumbColor: AppColors.accent,
            inactiveThumbColor: Colors.grey[600],
            inactiveTrackColor: Colors.grey[800],
          ),
        ],
      ),
    );
  }

  static const List<_FormulaItem> _formulas = [
    _FormulaItem(
      StockConfig.assetTotalAssets,
      StockConfig.assetTotalAssetsHelp,
    ),
    _FormulaItem(StockConfig.assetTotalCost, StockConfig.assetTotalCostHelp),
    _FormulaItem(
      StockConfig.assetTotalProfit,
      StockConfig.assetTotalProfitHelp,
    ),
    _FormulaItem(
      StockConfig.assetDividendRateLabel,
      StockConfig.assetTotalDividendsHelp,
    ),
    _FormulaItem(
      StockConfig.assetPositionRatioLabel,
      StockConfig.assetPositionRatioHelp,
    ),
  ];

  void _showFormulaDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 420),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                SettingsConfig.sectionFormula,
                style: TextStyles.dialogTitle.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                SettingsConfig.formulaDialogSubtitle,
                style: TextStyles.bodySmall,
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: _formulas.map((f) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border, width: 0.5),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(f.label, style: TextStyles.subtitle),
                          const SizedBox(height: 2),
                          Text(f.formula, style: TextStyles.bodySmall),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.blueDark,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    AppConfig.btnClose,
                    style: TextStyles.body13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOtherGroup() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            _buildGroupItem(
              icon: Icons.rate_review_outlined,
              iconColor: Colors.amber,
              label: SettingsConfig.feedbackLabel,
              onTap: _showFeedbackDialog,
            ),
            _buildGroupDivider(),
            _buildGroupItem(
              icon: Icons.calculate_outlined,
              iconColor: Colors.teal,
              label: SettingsConfig.sectionFormula,
              onTap: _showFormulaDialog,
            ),
            _buildGroupDivider(),
            _buildGroupItem(
              icon: Icons.code,
              iconColor: AppColors.lightBlue,
              label: SettingsConfig.openSourceLabel,
              onTap: _showOpenSourceDialog,
            ),
            _buildGroupDivider(),
            _buildGroupItem(
              icon: Icons.info_outline,
              iconColor: Colors.grey,
              label: SettingsConfig.versionLabel,
              trailing: AppConfig.appVersion,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    String? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: TextStyles.bodyMedium)),
            if (trailing != null)
              Text(trailing, style: TextStyles.caption.copyWith(fontSize: 14))
            else if (onTap != null)
              Icon(Icons.chevron_right, size: 18, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }

  void _showFeedbackDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          SettingsConfig.feedbackTitle,
          style: TextStyles.sectionTitle,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              SettingsConfig.feedbackHint,
              style: TextStyles.body13.copyWith(
                color: Colors.grey[400],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            _buildContactRow(
              Icons.email_outlined,
              SettingsConfig.contactEmail,
              AppConfig.developerEmail,
              onTap: () => _launchEmail(AppConfig.developerEmail),
            ),
            const SizedBox(height: 12),
            _buildContactRow(
              Icons.chat_bubble_outline,
              SettingsConfig.contactWechat,
              AppConfig.developerWechat,
              onTap: () => _copyToClipboard(
                AppConfig.developerWechat,
                AppConfig.toastWechatCopied,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(AppConfig.btnClose, style: TextStyles.body13),
          ),
        ],
      ),
    );
  }

  Widget _buildContactRow(
    IconData icon,
    String label,
    String value, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[500]),
          const SizedBox(width: 8),
          Text(
            '$label：',
            style: TextStyles.body13.copyWith(color: Colors.grey[400]),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: onTap != null ? AppColors.accent : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchEmail(String email) async {
    final uri = Uri(scheme: 'mailto', path: email);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return;
      }
    } catch (_) {}
    _copyToClipboard(email, AppConfig.toastEmailCopied);
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      CenterToast.success(context, '$label${AppConfig.toastClipboardSuffix}');
    }
  }

  void _showOpenSourceDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 560),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                SettingsConfig.openSourceTitle,
                style: TextStyles.dialogTitle.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(SettingsConfig.openSourceDesc, style: TextStyles.bodySmall),
              const SizedBox(height: 16),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    _buildLicenseSection(
                      SettingsConfig.licenseSectionLibs,
                      openSourceLibs,
                    ),
                    const SizedBox(height: 12),
                    _buildLicenseSection(
                      SettingsConfig.licenseSectionData,
                      dataSources,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.blueDark,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    AppConfig.btnClose,
                    style: TextStyles.body13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLicenseSection(String title, List<OpenSourceLib> libs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyles.body13.copyWith(
            color: Colors.grey[500],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Column(
            children: libs.map((lib) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(lib.name, style: TextStyles.subtitle),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            lib.license,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${lib.author} · ${lib.description}',
                      style: TextStyles.caption.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _FormulaItem {
  final String label;
  final String formula;
  const _FormulaItem(this.label, this.formula);
}
