import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../models/product_model.dart';
import '../../models/buy_request_model.dart';

class ProductCategory {
  final String name;
  final String unit;

  const ProductCategory(this.name, this.unit);
}

class SellProductsScreen extends StatefulWidget {
  const SellProductsScreen({Key? key}) : super(key: key);

  @override
  _SellProductsScreenState createState() => _SellProductsScreenState();
}

class _SellProductsScreenState extends State<SellProductsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController();
  final _customNameController = TextEditingController();

  static const List<ProductCategory> predefinedProducts = [
    ProductCategory('Eggs', 'g'),
    ProductCategory('Chicken Feed', 'kg'),
    ProductCategory('Fish Feed', 'kg'),
    ProductCategory('Compost', 'kg'),
    ProductCategory('Oil', 'L'),
    ProductCategory('Fertilizer', 'L'),
    ProductCategory('Other Items', 'units'),
  ];

  static const List<String> customUnits = [
    'g',
    'kg',
    'L',
    'ml',
    'units',
    'pieces',
    'boxes',
    'bags',
  ];

  List<Product> _products = [];
  bool _isLoading = true;
  DatabaseReference? _productsRef;
  StreamSubscription<DatabaseEvent>? _productsListener;
  String? _userId;

  // Selected product from dropdown
  ProductCategory? _selectedProduct;
  bool _isCustomProduct = false;
  String _selectedCustomUnit = 'units';

  List<BuyRequest> _buyRequests = [];
  StreamSubscription<DatabaseEvent>? _buyRequestsListener;

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid;
    if (_userId != null) {
      _productsRef = FirebaseDatabase.instance.ref('users/$_userId/products');
      _setupProductListener();
      _setupBuyRequestsListener();
    } else {
      // Handle case where user is somehow not logged in
      setState(() => _isLoading = false);
    }
  }

  void _setupProductListener() {
    _productsListener = _productsRef?.onValue.listen((event) {
      if (!mounted) return; // Check if widget is still active
      final Map<dynamic, dynamic>? productsMap = event.snapshot.value as Map?;
      final List<Product> loadedProducts = [];
      if (productsMap != null) {
        productsMap.forEach((key, value) {
          loadedProducts.add(Product.fromMap(key, value as Map));
        });
      }
      setState(() {
        _products = loadedProducts;
        _isLoading = false;
      });
    }, onError: (error) {
      debugPrint("Error listening to products: $error");
      if (mounted) setState(() => _isLoading = false);
    });
  }

  void _setupBuyRequestsListener() {
    if (_userId == null) return;

    _buyRequestsListener = FirebaseDatabase.instance
        .ref('buyRequests')
        .orderByChild('supplierId')
        .equalTo(_userId)
        .onValue
        .listen((event) {
      if (!mounted) return;

      final Map<dynamic, dynamic>? requestsMap = event.snapshot.value as Map?;
      final List<BuyRequest> requests = [];

      if (requestsMap != null) {
        requestsMap.forEach((key, value) {
          requests.add(BuyRequest.fromMap(key, value as Map));
        });
      }

      setState(() => _buyRequests = requests);
    });
  }

  Future<void> _addProduct() async {
    if (_formKey.currentState!.validate()) {
      if (!_isCustomProduct && _selectedProduct == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Please select a product'),
            backgroundColor: Colors.red));
        return;
      }

      final String name = _isCustomProduct
          ? _customNameController.text.trim()
          : _selectedProduct!.name;
      final String unit = _isCustomProduct
          ? _getUnitForCustomProduct()
          : _selectedProduct!.unit;
      final double? price = double.tryParse(_priceController.text.trim());
      final double? quantity = double.tryParse(_quantityController.text.trim());

      if (price == null || quantity == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Please enter valid price and quantity'),
            backgroundColor: Colors.red));
        return;
      }

      // Don't add "Other Items" as a product
      if (name == 'Other Items') {
        setState(() => _isCustomProduct = true);
        return;
      }

      // Check if product already exists
      final existingProduct = _products.firstWhere(
        (product) => product.name.toLowerCase() == name.toLowerCase(),
        orElse: () => Product(
          id: '',
          name: '',
          price: 0,
          unit: '',
          quantity: 0,
        ),
      );

      // Always create a new product listing, even if the product name exists
      final newProductRef = _productsRef?.push();
      if (newProductRef != null) {
        try {
          await newProductRef.set({
            'name': name,
            'price': price,
            'unit': unit,
            'quantity': quantity,
            'timestamp': DateTime.now().toIso8601String(),
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Product added!'), backgroundColor: Colors.green));
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Failed to add product: $e'),
              backgroundColor: Colors.red));
        }
      }
      _clearForm();
    }
  }

  String _getUnitForCustomProduct() {
    return _selectedCustomUnit;
  }

  void _clearForm() {
    _priceController.clear();
    _quantityController.clear();
    _customNameController.clear();
    setState(() {
      _selectedProduct = null;
      _isCustomProduct = false;
      _selectedCustomUnit = 'units';
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> _updateProduct(Product product) async {
    if (_productsRef == null) return;
    try {
      await _productsRef!.child(product.id).update(product.toMap());
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Product updated!'), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to update product: $e'),
          backgroundColor: Colors.red));
    }
  }

  Future<void> _deleteProduct(String productId) async {
    if (_productsRef == null) return;
    try {
      await _productsRef!.child(productId).remove();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Product deleted!'), backgroundColor: Colors.orange));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to delete product: $e'),
          backgroundColor: Colors.red));
    }
  }

  void _showEditDialog(Product product) {
    final editPriceController =
        TextEditingController(text: product.price.toString());
    final editQuantityController =
        TextEditingController(text: product.quantity.toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add New Listing for ${product.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Unit: ${product.unit}'),
              TextField(
                controller: editQuantityController,
                decoration:
                    InputDecoration(labelText: 'Quantity (${product.unit})'),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
              TextField(
                controller: editPriceController,
                decoration: InputDecoration(labelText: 'Price'),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('Add New Listing'),
              onPressed: () {
                final double? newPrice =
                    double.tryParse(editPriceController.text.trim());
                final double? newQuantity =
                    double.tryParse(editQuantityController.text.trim());
                if (newPrice != null && newQuantity != null) {
                  // Create a new product listing instead of updating
                  final newProductRef = _productsRef?.push();
                  if (newProductRef != null) {
                    newProductRef.set({
                      'name': product.name,
                      'price': newPrice,
                      'unit': product.unit,
                      'quantity': newQuantity,
                      'timestamp': DateTime.now().toIso8601String(),
                    });
                    Navigator.of(context).pop();
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Invalid quantity or price.'),
                      backgroundColor: Colors.red));
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateBuyRequestStatus(
      BuyRequest request, String status) async {
    try {
      await FirebaseDatabase.instance
          .ref('buyRequests/${request.id}')
          .update({'status': status});

      // Send notification to buyer when request is accepted
      if (status == 'accepted') {
        await FirebaseDatabase.instance
            .ref('users/${request.buyerId}/notifications')
            .push()
            .set({
          'type': 'buy_request_accepted',
          'message':
              'Your request to buy ${request.quantity} ${request.unit} of ${request.productName} has been accepted!',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'read': false,
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Request $status'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to update request: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    _productsListener?.cancel();
    _buyRequestsListener?.cancel();
    _priceController.dispose();
    _quantityController.dispose();
    _customNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sell Products'),
        backgroundColor: Colors.blueAccent,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Product Selection Row
                  Row(
                    children: [
                      Expanded(
                        child: _isCustomProduct
                            ? Column(
                                children: [
                                  TextFormField(
                                    controller: _customNameController,
                                    decoration: InputDecoration(
                                      labelText: 'Custom Product Name',
                                      suffixIcon: IconButton(
                                        icon: Icon(Icons.close),
                                        onPressed: () => setState(
                                            () => _isCustomProduct = false),
                                      ),
                                    ),
                                    validator: (value) => value?.isEmpty ?? true
                                        ? 'Enter product name'
                                        : null,
                                  ),
                                  SizedBox(height: 8),
                                  DropdownButtonFormField<String>(
                                    value: _selectedCustomUnit,
                                    decoration: InputDecoration(
                                      labelText: 'Select Unit',
                                    ),
                                    items: customUnits.map((unit) {
                                      return DropdownMenuItem(
                                        value: unit,
                                        child: Text(unit),
                                      );
                                    }).toList(),
                                    onChanged: (String? value) {
                                      if (value != null) {
                                        setState(
                                            () => _selectedCustomUnit = value);
                                      }
                                    },
                                  ),
                                ],
                              )
                            : DropdownButtonFormField<ProductCategory>(
                                value: _selectedProduct,
                                decoration: InputDecoration(
                                    labelText: 'Select Product'),
                                items: predefinedProducts.map((product) {
                                  return DropdownMenuItem(
                                    value: product,
                                    child: Text(
                                      product.name == 'Other Items'
                                          ? '➕ Add Other Items'
                                          : product.name,
                                      style: TextStyle(
                                        color: product.name == 'Other Items'
                                            ? Colors.blue
                                            : null,
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (ProductCategory? value) {
                                  if (value?.name == 'Other Items') {
                                    setState(() => _isCustomProduct = true);
                                  } else {
                                    setState(() => _selectedProduct = value);
                                  }
                                },
                              ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  // Quantity and Price Row
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _quantityController,
                          decoration: InputDecoration(
                            labelText: 'Quantity',
                            suffixText: _isCustomProduct
                                ? _selectedCustomUnit
                                : _selectedProduct?.unit ?? '',
                          ),
                          keyboardType:
                              TextInputType.numberWithOptions(decimal: true),
                          validator: (value) =>
                              value?.isEmpty ?? true ? 'Enter quantity' : null,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _priceController,
                          decoration: InputDecoration(
                            labelText: 'Price',
                            prefixText: '\$',
                          ),
                          keyboardType:
                              TextInputType.numberWithOptions(decimal: true),
                          validator: (value) =>
                              value?.isEmpty ?? true ? 'Enter price' : null,
                        ),
                      ),
                      SizedBox(width: 16),
                      ElevatedButton.icon(
                        icon: Icon(Icons.add),
                        label: Text('Add'),
                        onPressed: _addProduct,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Divider(),
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  TabBar(
                    tabs: [
                      Tab(text: 'My Products'),
                      Tab(text: 'Buy Requests'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        // Products Tab
                        _isLoading
                            ? Center(child: CircularProgressIndicator())
                            : _products.isEmpty
                                ? Center(child: Text('No products added yet.'))
                                : ListView.builder(
                                    itemCount: _products.length,
                                    itemBuilder: (context, index) {
                                      final product = _products[index];
                                      return ListTile(
                                        title: Text(product.name),
                                        subtitle: Text(
                                          '${product.quantity} ${product.unit} • \$${product.price.toStringAsFixed(2)}',
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: Icon(Icons.edit,
                                                  color: Colors.blue),
                                              tooltip: 'Edit',
                                              onPressed: () =>
                                                  _showEditDialog(product),
                                            ),
                                            IconButton(
                                              icon: Icon(Icons.delete,
                                                  color: Colors.red),
                                              tooltip: 'Delete',
                                              onPressed: () =>
                                                  _deleteProduct(product.id),
                                            ),
                                          ],
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
                                    margin: EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    child: ListTile(
                                      title: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('Buyer: ${request.buyerName}'),
                                          Text(
                                              'Address: ${request.buyerAddress}'),
                                          Text('Phone: ${request.buyerPhone}'),
                                        ],
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                              'Product: ${request.productName}'),
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
                                      trailing: request.status == 'pending'
                                          ? Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: Icon(Icons.check,
                                                      color: Colors.green),
                                                  onPressed: () =>
                                                      _updateBuyRequestStatus(
                                                          request, 'accepted'),
                                                ),
                                                IconButton(
                                                  icon: Icon(Icons.close,
                                                      color: Colors.red),
                                                  onPressed: () =>
                                                      _updateBuyRequestStatus(
                                                          request, 'rejected'),
                                                ),
                                              ],
                                            )
                                          : null,
                                    ),
                                  );
                                },
                              ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
