class BuyRequest {
  final String id;
  final String buyerId;
  final String buyerName;
  final String buyerAddress;
  final String buyerPhone;
  final String supplierId;
  final String supplierName;
  final String supplierAddress;
  final String supplierPhone;
  final String productId;
  final String productName;
  final double quantity;
  final String unit;
  final double price;
  final DateTime timestamp;
  final String status; // 'pending', 'accepted', 'rejected'

  BuyRequest({
    required this.id,
    required this.buyerId,
    required this.buyerName,
    required this.buyerAddress,
    required this.buyerPhone,
    required this.supplierId,
    required this.supplierName,
    required this.supplierAddress,
    required this.supplierPhone,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unit,
    required this.price,
    required this.timestamp,
    this.status = 'pending',
  });

  Map<String, dynamic> toMap() {
    return {
      'buyerId': buyerId,
      'buyerName': buyerName,
      'buyerAddress': buyerAddress,
      'buyerPhone': buyerPhone,
      'supplierId': supplierId,
      'supplierName': supplierName,
      'supplierAddress': supplierAddress,
      'supplierPhone': supplierPhone,
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'unit': unit,
      'price': price,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'status': status,
    };
  }

  factory BuyRequest.fromMap(String id, Map<dynamic, dynamic> map) {
    return BuyRequest(
      id: id,
      buyerId: map['buyerId']?.toString() ?? '',
      buyerName: map['buyerName']?.toString() ?? 'Unknown Buyer',
      buyerAddress: map['buyerAddress']?.toString() ?? 'No address provided',
      buyerPhone: map['buyerPhone']?.toString() ?? 'No phone provided',
      supplierId: map['supplierId']?.toString() ?? '',
      supplierName: map['supplierName']?.toString() ?? 'Unknown Supplier',
      supplierAddress:
          map['supplierAddress']?.toString() ?? 'No address provided',
      supplierPhone: map['supplierPhone']?.toString() ?? 'No phone provided',
      productId: map['productId']?.toString() ?? '',
      productName: map['productName']?.toString() ?? '',
      quantity: double.tryParse(map['quantity']?.toString() ?? '0') ?? 0,
      unit: map['unit']?.toString() ?? '',
      price: double.tryParse(map['price']?.toString() ?? '0') ?? 0,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        int.tryParse(map['timestamp']?.toString() ?? '0') ?? 0,
      ),
      status: map['status']?.toString() ?? 'pending',
    );
  }
}
