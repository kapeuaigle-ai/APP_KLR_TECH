import 'package:flutter/material.dart';
import 'commun.dart';

// ── Client ──────────────────────────────────────────────
class Client {
  final int id;
  final String initials;
  final Color color;
  final String name;
  final String contact;
  final String email;
  final String phone;
  final double totalFacture;
  final String address;

  const Client({
    required this.id, required this.initials, required this.color,
    required this.name, required this.contact, required this.email,
    required this.phone, required this.totalFacture,
    this.address = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'initials': initials, 'color': colorToInt(color), 'name': name,
    'contact': contact, 'email': email, 'phone': phone,
    'totalFacture': totalFacture, 'address': address,
  };

  factory Client.fromJson(Map<String, dynamic> j) => Client(
    id: j['id'], initials: j['initials'], color: colorFromInt(j['color']),
    name: j['name'], contact: j['contact'], email: j['email'], phone: j['phone'],
    totalFacture: (j['totalFacture'] as num).toDouble(), address: j['address'] ?? '',
  );
}
