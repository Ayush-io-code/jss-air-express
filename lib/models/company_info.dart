// lib/models/company_info.dart

class ExtraField {
  final String label;
  final String value;

  ExtraField({required this.label, required this.value});

  Map<String, dynamic> toJson() => {'label': label, 'value': value};

  factory ExtraField.fromJson(Map<String, dynamic> j) =>
      ExtraField(label: j['label'] as String, value: j['value'] as String);
}

class CompanyInfo {
  final String name;
  final String address;
  final String phone;
  final String email;
  final String gst;
  final String bankName;
  final String bankAcc;
  final String bankIFSC;
  final String bankBranch;
  final List<ExtraField> extraFields;

  const CompanyInfo({
    required this.name,
    required this.address,
    required this.phone,
    required this.email,
    required this.gst,
    required this.bankName,
    required this.bankAcc,
    required this.bankIFSC,
    required this.bankBranch,
    this.extraFields = const [],
  });

  static const CompanyInfo defaults = CompanyInfo(
    name: 'JSS AIR EXPRESS',
    address:
        'Franchise- JSS Air Express, Shop no.-8, Opp to Powerlink Complex, Thanisandra main road Bangalore-560077',
    phone: '7975609737, 8884261970, 8431988489',
    email: 'jssairexpress@gmail.com',
    gst: '29CTCPD9755Q1ZS',
    bankName: 'JSS AIR EXPRESS',
    bankAcc: '1048111010000065',
    bankIFSC: 'KSCB0001048',
    bankBranch: 'THANISANDRA',
  );

  Map<String, dynamic> toJson() => {
        'name': name,
        'address': address,
        'phone': phone,
        'email': email,
        'gst': gst,
        'bankName': bankName,
        'bankAcc': bankAcc,
        'bankIFSC': bankIFSC,
        'bankBranch': bankBranch,
        'extraFields': extraFields.map((e) => e.toJson()).toList(),
      };

  factory CompanyInfo.fromJson(Map<String, dynamic> j) => CompanyInfo(
        name: j['name'] as String? ?? defaults.name,
        address: j['address'] as String? ?? defaults.address,
        phone: j['phone'] as String? ?? defaults.phone,
        email: j['email'] as String? ?? defaults.email,
        gst: j['gst'] as String? ?? defaults.gst,
        bankName: j['bankName'] as String? ?? defaults.bankName,
        bankAcc: j['bankAcc'] as String? ?? defaults.bankAcc,
        bankIFSC: j['bankIFSC'] as String? ?? defaults.bankIFSC,
        bankBranch: j['bankBranch'] as String? ?? defaults.bankBranch,
        extraFields: ((j['extraFields'] as List?) ?? [])
            .map((e) => ExtraField.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  CompanyInfo copyWith({
    String? name,
    String? address,
    String? phone,
    String? email,
    String? gst,
    String? bankName,
    String? bankAcc,
    String? bankIFSC,
    String? bankBranch,
    List<ExtraField>? extraFields,
  }) =>
      CompanyInfo(
        name: name ?? this.name,
        address: address ?? this.address,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        gst: gst ?? this.gst,
        bankName: bankName ?? this.bankName,
        bankAcc: bankAcc ?? this.bankAcc,
        bankIFSC: bankIFSC ?? this.bankIFSC,
        bankBranch: bankBranch ?? this.bankBranch,
        extraFields: extraFields ?? this.extraFields,
      );
}
