import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/product_model.dart';
import '../../models/buy_request_model.dart';

class SupplierEgg {
  final String userId;
  final String userName;
  final Product egg;

  SupplierEgg({
    required this.userId,
    required this.userName,
    required this.egg,
  });
}

class BuyEggsScreen extends StatefulWidget {
  const BuyEggsScreen({Key? key}) : super(key: key);

  @override
  _BuyEggsScreenState createState() => _BuyEggsScreenState();
}

class _BuyEggsScreenState extends State<BuyEggsScreen> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  List<SupplierEgg> _supplierEggs = [];
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
    _productsListener = _database.child('users').onValue.listen((event) async {
      if (!mounted) return;

      final Map<dynamic, dynamic>? usersMap = event.snapshot.value as Map?;
      final List<SupplierEgg> eggs = [];

      if (usersMap != null) {
        // Get all accepted buy requests
        final buyRequestsSnapshot = await _database.child('buyRequests').get();
        final Map<dynamic, dynamic>? buyRequestsMap =
            buyRequestsSnapshot.value as Map?;
        final Map<String, double> acceptedQuantities = {};

        if (buyRequestsMap != null) {
          buyRequestsMap.forEach((requestId, requestData) {
            final Map<String, dynamic> request =
                Map<String, dynamic>.from(requestData as Map);
            if (request['status'] == 'accepted') {
              final String productId = request['productId'].toString();
              final double quantity =
                  double.parse(request['quantity'].toString());
              acceptedQuantities[productId] =
                  (acceptedQuantities[productId] ?? 0) + quantity;
            }
          });
        }

        usersMap.forEach((userId, userData) {
          // Skip if this is the current user's products
          if (userId.toString() == _currentUserId) return;

          final Map<String, dynamic> userMap =
              Map<String, dynamic>.from(userData as Map);
          final userName = userMap['name']?.toString() ?? 'Unknown Supplier';
          final userProducts = userMap['products'];

          if (userProducts != null) {
            final Map<String, dynamic> productsMap =
                Map<String, dynamic>.from(userProducts as Map);
            productsMap.forEach((productId, productData) {
              final Map<String, dynamic> productMap =
                  Map<String, dynamic>.from(productData as Map);
              final product = Product.fromMap(productId, productMap);

              // Only show egg products
              if (product.name.toLowerCase().contains('egg')) {
                // Calculate remaining quantity after accepted requests
                final double acceptedQuantity =
                    acceptedQuantities[productId] ?? 0;
                final double remainingQuantity =
                    product.quantity - acceptedQuantity;

                // Only show product if there's remaining quantity
                if (remainingQuantity > 0) {
                  eggs.add(SupplierEgg(
                    userId: userId.toString(),
                    userName: userName,
                    egg: Product(
                      id: product.id,
                      name: product.name,
                      quantity: remainingQuantity,
                      unit: product.unit,
                      price: product.price,
                      timestamp: product.timestamp,
                    ),
                  ));
                }
              }
            });
          }
        });
      }

      setState(() {
        _supplierEggs = eggs;
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

  bool _hasActiveRequest(SupplierEgg supplierEgg) {
    return _buyRequests.any((request) =>
        request.productId == supplierEgg.egg.id &&
        request.supplierId == supplierEgg.userId &&
        request.status == 'pending');
  }

  Future<void> _createBuyRequest(SupplierEgg supplierEgg) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Please login to buy eggs'),
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
        await _database.child('users/${supplierEgg.userId}').get();
    final supplierData = supplierSnapshot.value as Map?;
    final supplierAddress =
        supplierData?['address']?.toString() ?? 'No address provided';
    final supplierPhone =
        supplierData?['phone']?.toString() ?? 'No phone provided';

    // Show quantity input dialog
    final TextEditingController quantityController = TextEditingController(
      text: supplierEgg.egg.quantity.toString(),
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
                  'Available: ${supplierEgg.egg.quantity} ${supplierEgg.egg.unit}'),
              SizedBox(height: 8),
              Text('Supplier: ${supplierEgg.userName}'),
              Text('Address: $supplierAddress'),
              Text('Phone: $supplierPhone'),
              SizedBox(height: 16),
              TextField(
                controller: quantityController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Quantity',
                  suffixText: supplierEgg.egg.unit,
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

    if (requestedQuantity > supplierEgg.egg.quantity) {
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
      supplierId: supplierEgg.userId,
      supplierName: supplierEgg.userName,
      supplierAddress: supplierAddress,
      supplierPhone: supplierPhone,
      productId: supplierEgg.egg.id,
      productName: supplierEgg.egg.name,
      quantity: requestedQuantity,
      unit: supplierEgg.egg.unit,
      price: supplierEgg.egg.price,
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
          title: Text('Buy Eggs'),
          backgroundColor: Colors.blueAccent,
          bottom: TabBar(
            tabs: [
              Tab(text: 'Available Eggs'),
              Tab(text: 'My Buy Requests'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Available Eggs Tab
            _isLoading
                ? Center(child: CircularProgressIndicator())
                : _supplierEggs.isEmpty
                    ? Center(child: Text('No eggs available'))
                    : ListView.builder(
                        itemCount: _supplierEggs.length,
                        itemBuilder: (context, index) {
                          final supplierEgg = _supplierEggs[index];
                          return Card(
                            margin: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: ListTile(
                              title: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Supplier: ${supplierEgg.userName}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Posted: ${supplierEgg.egg.timestamp?.toLocal().toString().split('.')[0] ?? 'Unknown'}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                '${supplierEgg.egg.quantity} ${supplierEgg.egg.unit} • \LKR${supplierEgg.egg.price.toStringAsFixed(2)}',
                              ),
                              trailing: ElevatedButton(
                                onPressed: _hasActiveRequest(supplierEgg)
                                    ? null
                                    : () => _createBuyRequest(supplierEgg),
                                child: Text(_hasActiveRequest(supplierEgg)
                                    ? 'Pending'
                                    : 'Buy'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      _hasActiveRequest(supplierEgg)
                                          ? Colors.grey
                                          : Colors.blueAccent,
                                  foregroundColor:
                                      _hasActiveRequest(supplierEgg)
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
