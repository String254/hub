class PropertyOccupancyResponse {
  final int propertyId;
  final String propertyName;
  final String occupancyRate;
  final String collectionRate;
  final int totalUnits;
  final int occupiedUnits;
  final int vacantUnits;
  final int expectedRent;
  final int collectedRent;

  PropertyOccupancyResponse({
    required this.propertyId,
    required this.propertyName,
    required this.occupancyRate,
    required this.collectionRate,
    required this.totalUnits,
    required this.occupiedUnits,
    required this.vacantUnits,
    required this.expectedRent,
    required this.collectedRent,
  });

  factory PropertyOccupancyResponse.fromJson(Map<String, dynamic> json) {
    return PropertyOccupancyResponse(
      propertyId: json['property_id'] ?? 0,
      propertyName: json['property_name'] ?? '',
      occupancyRate: json['occupancy_rate'] ?? '0%',
      collectionRate: json['collection_rate'] ?? '0%',
      totalUnits: json['total_units'] ?? 0,
      occupiedUnits: json['occupied_units'] ?? 0,
      vacantUnits: json['vacant_units'] ?? 0,
      expectedRent: (json['expected_rent'] as num?)?.toInt() ?? 0,
      collectedRent: (json['collected_rent'] as num?)?.toInt() ?? 0,
    );
  }

  // Utility to extract percentage value as int
  int get occupancyPercent =>
      int.tryParse(occupancyRate.replaceAll('%', '')) ?? 0;

  int get collectionPercent =>
      int.tryParse(collectionRate.replaceAll('%', '')) ?? 0;


}
