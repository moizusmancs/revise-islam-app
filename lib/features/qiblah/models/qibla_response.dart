class QiblaResponse {
  final double latitude;
  final double longitude;
  final double direction;

  const QiblaResponse({
    required this.latitude,
    required this.longitude,
    required this.direction,
  });

  factory QiblaResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return QiblaResponse(
      latitude: (data['latitude'] as num).toDouble(),
      longitude: (data['longitude'] as num).toDouble(),
      direction: (data['direction'] as num).toDouble(),
    );
  }
}
