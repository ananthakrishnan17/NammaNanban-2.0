enum SaleType { wholesale, retail }

extension SaleTypeExt on SaleType {
  String get value => name; // 'wholesale' | 'retail'
  String get label => name == 'wholesale' ? 'Wholesale' : 'Retail';
  String get emoji => name == 'wholesale' ? '📦' : '🛒';
}
