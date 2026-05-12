// lib/models/party.dart
import 'dart:convert';

class Party {
  final String id;
  String name;
  String address;
  String gstin;
  String phone;
  double fuelPct;
  double cgstPct;
  double sgstPct;

  Party({
    required this.id,
    required this.name,
    this.address = '',
    this.gstin = '',
    this.phone = '',
    this.fuelPct = 15,
    this.cgstPct = 9,
    this.sgstPct = 9,
  });

  Party copyWith({
    String? name,
    String? address,
    String? gstin,
    String? phone,
    double? fuelPct,
    double? cgstPct,
    double? sgstPct,
  }) {
    return Party(
      id: id,
      name: name ?? this.name,
      address: address ?? this.address,
      gstin: gstin ?? this.gstin,
      phone: phone ?? this.phone,
      fuelPct: fuelPct ?? this.fuelPct,
      cgstPct: cgstPct ?? this.cgstPct,
      sgstPct: sgstPct ?? this.sgstPct,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'address': address,
        'gstin': gstin,
        'phone': phone,
        'fuelPct': fuelPct,
        'cgstPct': cgstPct,
        'sgstPct': sgstPct,
      };

  factory Party.fromJson(Map<String, dynamic> j) => Party(
        id: j['id'] as String,
        name: j['name'] as String,
        address: j['address'] as String? ?? '',
        gstin: j['gstin'] as String? ?? '',
        phone: j['phone'] as String? ?? '',
        fuelPct: (j['fuelPct'] as num?)?.toDouble() ?? 15,
        cgstPct: (j['cgstPct'] as num?)?.toDouble() ?? 9,
        sgstPct: (j['sgstPct'] as num?)?.toDouble() ?? 9,
      );

  static List<Party> get defaults => [
        Party(id: 'p1', name: 'RJ Lumen'),
        Party(id: 'p2', name: 'Southern Surgicals'),
        Party(id: 'p3', name: 'Bookita'),
      ];
}
