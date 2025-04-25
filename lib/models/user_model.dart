import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

enum UserRole { supplier, customer }

class UserModel {
  final String uid;
  final String name;
  final String email;
  final UserRole role;
  final String? phone;
  final String? address;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
    this.address,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.toString().split('.').last == (map['role'] ?? 'supplier'),
        orElse: () => UserRole.supplier,
      ),
      phone: map['phone'],
      address: map['address'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'role': role.toString().split('.').last,
      'phone': phone,
      'address': address,
    };
  }

  factory UserModel.fromFirebaseUser(
    User user,
    UserRole role,
    String name,
    String address,
    String phoneNumber,
  ) {
    return UserModel(
      uid: user.uid,
      email: user.email ?? '',
      name: name,
      address: address,
      phone: phoneNumber,
      role: role,
    );
  }
}
