import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/product_model.dart';
import 'supplier_products_screen.dart';

class Supplier {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String address;
  final List<Product> products;

  Supplier({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    required this.products,
  });

  factory Supplier.fromMap(String id, Map<dynamic, dynamic> data) {
    final List<Product> products = [];
    final productsMap = data['products'] as Map<dynamic, dynamic>?;

    if (productsMap != null) {
      productsMap.forEach((productId, productData) {
        if (productData is Map) {
          products.add(Product.fromMap(productId.toString(), productData));
        }
      });
    }

    return Supplier(
      id: id,
      name: data['name']?.toString() ?? 'Unknown',
      email: data['email']?.toString() ?? 'No email',
      phone: data['phone']?.toString() ?? 'No phone',
      address: data['address']?.toString() ?? 'No address',
      products: products,
    );
  }
}

class SuppliersListScreen extends StatefulWidget {
  const SuppliersListScreen({Key? key}) : super(key: key);

  @override
  _SuppliersListScreenState createState() => _SuppliersListScreenState();
}

class _SuppliersListScreenState extends State<SuppliersListScreen> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  List<Supplier> _suppliers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  Future<void> _loadSuppliers() async {
    try {
      final snapshot = await _database.child('users').get();
      if (!mounted) return;

      final Map<dynamic, dynamic>? usersMap = snapshot.value as Map?;
      final List<Supplier> suppliers = [];

      if (usersMap != null) {
        usersMap.forEach((userId, userData) {
          // Skip if this is the current user
          if (userId.toString() == _currentUserId) return;

          // Only add users with role 'supplier'
          if (userData['role']?.toString() == 'supplier') {
            suppliers.add(Supplier.fromMap(userId.toString(), userData));
          }
        });
      }

      setState(() {
        _suppliers = suppliers;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading suppliers: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Registered Suppliers'),
        backgroundColor: Colors.blueAccent,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _suppliers.isEmpty
              ? Center(child: Text('No suppliers registered yet'))
              : ListView.builder(
                  itemCount: _suppliers.length,
                  itemBuilder: (context, index) {
                    final supplier = _suppliers[index];
                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ExpansionTile(
                        title: Text(
                          supplier.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Text(
                          '${supplier.products.length} products available',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        leading: CircleAvatar(
                          backgroundColor: Colors.blueAccent,
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                        children: [
                          Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInfoRow(
                                    Icons.email, 'Email', supplier.email),
                                SizedBox(height: 8),
                                _buildInfoRow(
                                    Icons.phone, 'Phone', supplier.phone),
                                SizedBox(height: 8),
                                _buildInfoRow(Icons.location_on, 'Address',
                                    supplier.address),
                                SizedBox(height: 8),
                                _buildInfoRow(
                                    Icons.inventory,
                                    'Products',
                                    supplier.products
                                        .map((p) => p.name)
                                        .join(', ')),
                                SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            SupplierProductsScreen(
                                          supplierId: supplier.id,
                                          supplierName: supplier.name,
                                        ),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blueAccent,
                                    minimumSize: Size(double.infinity, 45),
                                  ),
                                  child: Text('View Products'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.blueAccent),
        SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
              Text(value),
            ],
          ),
        ),
      ],
    );
  }
}
