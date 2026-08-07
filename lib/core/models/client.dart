import 'package:flutter/material.dart';
import 'commun.dart';

// ── Client ──────────────────────────────────────────────
/// Le chiffre d'affaires d'un client N'EST PAS un champ de cette classe :
/// c'est une somme sur `Engagement.regle` (voir `AppState.chiffreAffairesClient`),
/// jamais un total stocké. Un champ `totalFacture` a existé ici — écrit une
/// seule fois par le seed de démonstration et jamais recalculé, il restait
/// à 0 pour tout client créé depuis l'écran quelle que soit son activité
/// réelle (défaut 3, revue Lot B). Ne pas le réintroduire.
class Client {
  final int id;
  final String initials;
  final Color color;
  final String name;
  final String contact;
  final String email;
  final String phone;
  final String address;

  const Client({
    required this.id, required this.initials, required this.color,
    required this.name, required this.contact, required this.email,
    required this.phone,
    this.address = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'initials': initials, 'color': colorToInt(color), 'name': name,
    'contact': contact, 'email': email, 'phone': phone,
    'address': address,
  };

  factory Client.fromJson(Map<String, dynamic> j) => Client(
    id: j['id'], initials: j['initials'], color: colorFromInt(j['color']),
    name: j['name'], contact: j['contact'], email: j['email'], phone: j['phone'],
    address: j['address'] ?? '',
  );
}
