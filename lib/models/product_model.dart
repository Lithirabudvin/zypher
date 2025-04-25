class Product {
  final String id; // Firebase push key
  String name;
  double price;
  String unit; // e.g., 'kg', 'g', 'L'
  double quantity;
  DateTime? timestamp;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.unit,
    required this.quantity,
    this.timestamp,
  });

  // Convert a Product object into a Map for Firebase
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price': price,
      'unit': unit,
      'quantity': quantity,
      'timestamp': timestamp?.toIso8601String(),
    };
  }

  // Create a Product object from a Firebase Map
  factory Product.fromMap(String id, Map<dynamic, dynamic> map) {
    return Product(
      id: id,
      name: map['name']?.toString() ?? 'Unnamed Product',
      price: double.tryParse(map['price']?.toString() ?? '0.0') ?? 0.0,
      unit: map['unit']?.toString() ?? '',
      quantity: double.tryParse(map['quantity']?.toString() ?? '0.0') ?? 0.0,
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'].toString())
          : null,
    );
  }
}
