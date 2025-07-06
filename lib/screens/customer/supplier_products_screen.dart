import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/product_model.dart';
import '../../models/buy_request_model.dart';

class SupplierProduct {
  final String userId;
  final String userName;
  final String? userAddress;
  final String? userPhone;
  final Product product;

  SupplierProduct({
    required this.userId,
    required this.userName,
    this.userAddress,
    this.userPhone,
    required this.product,
  });
}

class SupplierProductsScreen extends StatefulWidget {
  final String supplierId;
  final String supplierName;

  const SupplierProductsScreen({
    Key? key,
    required this.supplierId,
    required this.supplierName,
  }) : super(key: key);

  @override
  _SupplierProductsScreenState createState() => _SupplierProductsScreenState();
}

class _SupplierProductsScreenState extends State<SupplierProductsScreen> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  List<SupplierProduct> _supplierProducts = [];
  List<BuyRequest> _buyRequests = [];
  bool _isLoading = true;
  StreamSubscription<DatabaseEvent>? _productsListener;
  StreamSubscription<DatabaseEvent>? _buyRequestsListener;

  @override
  void initState() {
    super.initState();
    _setupProductsListener();
    _setupBuyRequestsListener();
  }

  void _setupProductsListener() {
    _productsListener =
        _database.child('users/${widget.supplierId}').onValue.listen((event) {
      if (!mounted) return;

      final Map<dynamic, dynamic>? userData = event.snapshot.value as Map?;
      final List<SupplierProduct> products = [];

      if (userData != null) {
        final Map<String, dynamic> userMap =
            Map<String, dynamic>.from(userData);
        final userName = userMap['name']?.toString() ?? 'Unknown Supplier';
        final userAddress = userMap['address']?.toString();
        final userPhone = userMap['phone']?.toString();
        final userProducts = userMap['products'];

        if (userProducts != null) {
          final Map<String, dynamic> productsMap =
              Map<String, dynamic>.from(userProducts as Map);
          productsMap.forEach((productId, productData) {
            final Map<String, dynamic> productMap =
                Map<String, dynamic>.from(productData as Map);
            final product = Product.fromMap(productId, productMap);
            products.add(SupplierProduct(
              userId: widget.supplierId,
              userName: userName,
              userAddress: userAddress,
              userPhone: userPhone,
              product: product,
            ));
          });
        }
      }

      setState(() {
        _supplierProducts = products;
        _isLoading = false;
      });
    }, onError: (error) {
      debugPrint("Error listening to products: $error");
      if (mounted) setState(() => _isLoading = false);
    });
  }

  void _setupBuyRequestsListener() {
    if (_currentUserId == null) return;

    final buyRequestsRef = _database.child('buyRequests');
    _buyRequestsListener = buyRequestsRef
        .orderByChild('buyerId')
        .equalTo(_currentUserId)
        .onValue
        .listen((event) {
      if (!mounted) return;

      final Map<dynamic, dynamic>? requestsMap = event.snapshot.value as Map?;
      final List<BuyRequest> requests = [];

      if (requestsMap != null) {
        requestsMap.forEach((key, value) {
          requests.add(BuyRequest.fromMap(key.toString(), value as Map));
        });
      }

      setState(() => _buyRequests = requests);
    });
  }

  bool _hasActiveRequest(SupplierProduct supplierProduct) {
    return _buyRequests.any((request) =>
        request.productId == supplierProduct.product.id &&
        request.supplierId == supplierProduct.userId &&
        (request.status == 'pending' || request.status == 'accepted'));
  }

  Future<void> _createBuyRequest(SupplierProduct supplierProduct) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Please login to buy products'),
            backgroundColor: Colors.red),
      );
      return;
    }

    // Get current user's details from database
    final userSnapshot =
        await _database.child('users/${currentUser.uid}').get();
    final userData = userSnapshot.value as Map?;
    final buyerName = userData?['name']?.toString() ?? 'Unknown Buyer';
    final buyerAddress =
        userData?['address']?.toString() ?? 'No address provided';
    final buyerPhone = userData?['phone']?.toString() ?? 'No phone provided';

    // Get supplier's details from database
    final supplierSnapshot =
        await _database.child('users/${supplierProduct.userId}').get();
    final supplierData = supplierSnapshot.value as Map?;
    final supplierAddress =
        supplierData?['address']?.toString() ?? 'No address provided';
    final supplierPhone =
        supplierData?['phone']?.toString() ?? 'No phone provided';

    // Show quantity input dialog
    final TextEditingController quantityController = TextEditingController(
      text: supplierProduct.product.quantity.toString(),
    );

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Enter Quantity'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  'Available: ${supplierProduct.product.quantity} ${supplierProduct.product.unit}'),
              SizedBox(height: 8),
              Text('Supplier: ${supplierProduct.userName}'),
              Text('Address: $supplierAddress'),
              Text('Phone: $supplierPhone'),
              SizedBox(height: 16),
              TextField(
                controller: quantityController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Quantity',
                  suffixText: supplierProduct.product.unit,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: Text('Buy'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final double? requestedQuantity = double.tryParse(quantityController.text);
    if (requestedQuantity == null || requestedQuantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Please enter a valid quantity'),
            backgroundColor: Colors.red),
      );
      return;
    }

    if (requestedQuantity > supplierProduct.product.quantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Requested quantity exceeds available quantity'),
            backgroundColor: Colors.red),
      );
      return;
    }

    // Create buy request
    final buyRequestRef = _database.child('buyRequests').push();
    final buyRequest = BuyRequest(
      id: buyRequestRef.key!,
      buyerId: currentUser.uid,
      buyerName: buyerName,
      buyerAddress: buyerAddress,
      buyerPhone: buyerPhone,
      supplierId: supplierProduct.userId,
      supplierName: supplierProduct.userName,
      supplierAddress: supplierAddress,
      supplierPhone: supplierPhone,
      productId: supplierProduct.product.id,
      productName: supplierProduct.product.name,
      quantity: requestedQuantity,
      unit: supplierProduct.product.unit,
      price: supplierProduct.product.price,
      timestamp: DateTime.now(),
    );

    try {
      await buyRequestRef.set(buyRequest.toMap());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Buy request sent!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to send buy request: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    _productsListener?.cancel();
    _buyRequestsListener?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${widget.supplierName}\'s Products'),
          backgroundColor: Colors.blueAccent,
          bottom: TabBar(
            tabs: [
              Tab(text: 'Products'),
              Tab(text: 'My Buy Requests'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Products Tab
            _isLoading
                ? Center(child: CircularProgressIndicator())
                : _supplierProducts.isEmpty
                    ? Center(child: Text('No products available'))
                    : ListView.builder(
                        itemCount: _supplierProducts.length,
                        itemBuilder: (context, index) {
                          final supplierProduct = _supplierProducts[index];
                          return Card(
                            margin: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: ListTile(
                              title: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Product: ${supplierProduct.product.name}',
                                    style: TextStyle(
                                      color: Colors.blue[700],
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                '${supplierProduct.product.quantity} ${supplierProduct.product.unit} • \LKR${supplierProduct.product.price.toStringAsFixed(2)}',
                              ),
                              trailing: ElevatedButton(
                                onPressed: _hasActiveRequest(supplierProduct)
                                    ? null
                                    : () => _createBuyRequest(supplierProduct),
                                child: Text(_hasActiveRequest(supplierProduct)
                                    ? 'Pending'
                                    : 'Buy'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      _hasActiveRequest(supplierProduct)
                                          ? Colors.grey
                                          : Colors.blueAccent,
                                  foregroundColor:
                                      _hasActiveRequest(supplierProduct)
                                          ? Colors.white.withOpacity(0.7)
                                          : Colors.white,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
            // Buy Requests Tab
            _buyRequests.isEmpty
                ? Center(child: Text('No buy requests'))
                : ListView.builder(
                    itemCount: _buyRequests.length,
                    itemBuilder: (context, index) {
                      final request = _buyRequests[index];
                      return Card(
                        margin:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ListTile(
                          title: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Supplier: ${request.supplierName}'),
                              Text('Address: ${request.supplierAddress}'),
                              Text('Phone: ${request.supplierPhone}'),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Product: ${request.productName}'),
                              Text(
                                '${request.quantity} ${request.unit} • \LKR${request.price.toStringAsFixed(2)}',
                              ),
                              Text(
                                'Status: ${request.status}',
                                style: TextStyle(
                                  color: request.status == 'pending'
                                      ? Colors.orange
                                      : request.status == 'accepted'
                                          ? Colors.green
                                          : Colors.red,
                                ),
                              ),
                              Text(
                                'Request Date: ${request.timestamp.toString().split('.')[0]}',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
