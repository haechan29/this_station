import 'SubwayStation.dart';

class StationDistance {
  final SubwayStation station;
  final double distance; // 미터 단위

  StationDistance(this.station, this.distance);

  @override
  String toString() =>
      '(${station.lineNumber} ${station.name}) - ${distance.toStringAsFixed(0)}m';
}