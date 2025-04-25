import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../models/product_model.dart';
import '../../models/buy_request_model.dart';
import '../../services/auth_service.dart';
import 'signup_screen.dart';
import 'suppliers_list_screen.dart';

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

class CustomerDashboard extends StatefulWidget {
  final String? supplierId;

  const CustomerDashboard({Key? key, this.supplierId}) : super(key: key);

  @override
  _CustomerDashboardState createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
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
    _productsListener = _database.child('users').onValue.listen((event) async {
      if (!mounted) return;

      final Map<dynamic, dynamic>? usersMap = event.snapshot.value as Map?;
      final List<SupplierProduct> products = [];

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
          final userPhone = userMap['phone']?.toString() ?? 'No phone provided';
          final userProducts = userMap['products'];

          if (userProducts != null) {
            final Map<String, dynamic> productsMap =
                Map<String, dynamic>.from(userProducts as Map);
            productsMap.forEach((productId, productData) {
              final Map<String, dynamic> productMap =
                  Map<String, dynamic>.from(productData as Map);
              final product = Product.fromMap(productId, productMap);

              // Calculate remaining quantity after accepted requests
              final double acceptedQuantity =
                  acceptedQuantities[productId] ?? 0;
              final double remainingQuantity =
                  product.quantity - acceptedQuantity;

              // Only show product if there's remaining quantity
              if (remainingQuantity > 0) {
                products.add(SupplierProduct(
                  userId: userId.toString(),
                  userName: userName,
                  userPhone: userPhone,
                  product: Product(
                    id: product.id,
                    name: product.name,
                    quantity: remainingQuantity,
                    unit: product.unit,
                    price: product.price,
                    timestamp: product.timestamp,
                  ),
                ));
              }
            });
          }
        });
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

  Future<void> _signOut() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    try {
      await authService.signOut(context);
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.blueAccent,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, size: 35, color: Colors.blueAccent),
                ),
                SizedBox(height: 10),
                Text(
                  'Customer Dashboard',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: Icon(Icons.shopping_cart),
            title: Text('Available Products'),
            onTap: () {
              Navigator.pop(context);
              final tabController = DefaultTabController.maybeOf(context);
              if (tabController != null) {
                tabController.animateTo(0);
              }
            },
          ),
          ListTile(
            leading: Icon(Icons.people),
            title: Text('Registered Suppliers'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SuppliersListScreen(),
                ),
              );
            },
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.logout),
            title: Text('Sign Out'),
            onTap: _signOut,
          ),
        ],
      ),
    );
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
          title: Text('Available Products'),
          backgroundColor: Colors.blueAccent,
          bottom: TabBar(
            tabs: [
              Tab(text: 'Products'),
              Tab(text: 'My Buy Requests'),
            ],
          ),
        ),
        drawer: _buildDrawer(),
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
                                    'Supplier: ${supplierProduct.userName}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (supplierProduct.userPhone != null)
                                    Text('Phone: ${supplierProduct.userPhone}'),
                                  Text(
                                    'Product: ${supplierProduct.product.name}',
                                    style: TextStyle(
                                      color: Colors.blue[700],
                                    ),
                                  ),
                                  Text(
                                    'Posted: ${supplierProduct.product.timestamp?.toLocal().toString().split('.')[0] ?? 'Unknown'}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                '${supplierProduct.product.quantity} ${supplierProduct.product.unit} • \$${supplierProduct.product.price.toStringAsFixed(2)}',
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
                          title: Text('Product: ${request.productName}'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Supplier: ${request.supplierName}'),
                              Text('Address: ${request.supplierAddress}'),
                              Text('Phone: ${request.supplierPhone}'),
                              Text(
                                '${request.quantity} ${request.unit} • \$${request.price.toStringAsFixed(2)}',
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

  bool _hasActiveRequest(SupplierProduct supplierProduct) {
    return _buyRequests.any((request) =>
        request.productId == supplierProduct.product.id &&
        request.supplierId == supplierProduct.userId &&
        request.status == 'pending');
  }
}
