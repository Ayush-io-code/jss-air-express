// lib/models/entry.dart

class Entry {
  final String id;
  String date;
  String awb;
  String kg;
  String mode;
  String destination;
  String clientName;
  String price;

  Entry({
    required this.id,
    this.date = '',
    this.awb = '',
    this.kg = '',
    this.mode = 'AIR',
    this.destination = '',
    this.clientName = '',
    this.price = '',
  });

  Entry copyWith({
    String? date,
    String? awb,
    String? kg,
    String? mode,
    String? destination,
    String? clientName,
    String? price,
  }) {
    return Entry(
      id: id,
      date: date ?? this.date,
      awb: awb ?? this.awb,
      kg: kg ?? this.kg,
      mode: mode ?? this.mode,
      destination: destination ?? this.destination,
      clientName: clientName ?? this.clientName,
      price: price ?? this.price,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'awb': awb,
        'kg': kg,
        'mode': mode,
        'destination': destination,
        'clientName': clientName,
        'price': price,
      };

  factory Entry.fromJson(Map<String, dynamic> j) => Entry(
        id: j['id'] as String,
        date: j['date'] as String? ?? '',
        awb: j['awb'] as String? ?? '',
        kg: j['kg'] as String? ?? '',
        mode: j['mode'] as String? ?? 'AIR',
        destination: j['destination'] as String? ?? '',
        clientName: j['clientName'] as String? ?? '',
        price: j['price'] as String? ?? '',
      );

  static const List<String> modes = ['AIR', 'OTC', 'F/T', 'S/P'];
}
