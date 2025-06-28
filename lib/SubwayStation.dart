class SubwayStation {
  final String name;
  final double latitude;
  final double longitude;
  final String lineNumber;
  final String frCode;

  SubwayStation({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.lineNumber,
    required this.frCode,
  });

  factory SubwayStation.fromJson(Map<String, dynamic> json) {
    return SubwayStation(
      name: json['name'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      lineNumber: json['lineNumber'],
      frCode: json['frCode'],
    );
  }

  @override
  String toString() {
    return 'SubwayStation{'
        'name: $name, '
        'line: $lineNumber, '
        'lat: $latitude, '
        'lon: $longitude}';
  }
}