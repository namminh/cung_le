class CeremonySuggestion {
  final List<Map<String, dynamic>>
  menu; // Thay List<String> bằng List<Map> để chứa món + giá
  final List<String> items;
  final List<String> rituals;
  final String prayer;
  final String budgetEstimate;
  final String advice;

  CeremonySuggestion({
    required this.menu,
    required this.items,
    required this.rituals,
    required this.prayer,
    required this.budgetEstimate,
    this.advice = '',
  });

  factory CeremonySuggestion.fromJson(Map<String, dynamic> json) {
    return CeremonySuggestion(
      menu:
          json['menu'] != null
              ? List<Map<String, dynamic>>.from(
                json['menu'].map(
                  (item) => {
                    'name': item['name'] ?? '',
                    'price': item['price'] ?? '0 VNĐ',
                  },
                ),
              )
              : [],
      items: json['items'] != null ? List<String>.from(json['items']) : [],
      rituals:
          json['rituals'] != null ? List<String>.from(json['rituals']) : [],
      prayer: json['prayer'] ?? 'Không có văn khấn mặc định',
      budgetEstimate: json['budgetEstimate'] ?? 'Chưa ước tính',
      advice: json['advice'] ?? '',
    );
  }
}
