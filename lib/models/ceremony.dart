class Ceremony {
  final String type; // Loại lễ (giỗ, cưới)
  final String region; // Vùng miền
  final List<String> menu; // Thực đơn
  final List<String> items; // Vật dụng

  Ceremony({
    required this.type,
    required this.region,
    required this.menu,
    required this.items,
  });

  // Chuyển từ JSON (Firebase) sang object
  factory Ceremony.fromJson(Map<String, dynamic> json) {
    return Ceremony(
      type: json['type'],
      region: json['region'],
      menu: List<String>.from(json['menu']),
      items: List<String>.from(json['items']),
    );
  }
}
