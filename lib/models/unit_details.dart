class UnitDetails {
  final int unitId;
  final String propertyName;
  final String houseNo;
  final int rentAmount;
  final String tenantName;
  final String tenantEmail;

  UnitDetails({
    required this.unitId,
    required this.propertyName,
    required this.houseNo,
    required this.rentAmount,
    required this.tenantName,
    required this.tenantEmail,
  });

  factory UnitDetails.fromJson(Map<String, dynamic> json) {
    return UnitDetails(
      unitId: int.parse(json['unit_id'].toString()),

      propertyName: json['property_name'] ?? '',

      houseNo: json['house_no'] ?? '',

      // API sends "35000.00" as String → convert safely to int
      rentAmount: double.parse(json['rent_amount'].toString()).toInt(),

      tenantName: json['tenant_name'] ?? '',
      tenantEmail: json['tenant_email'] ?? '',
    );
  }
}
