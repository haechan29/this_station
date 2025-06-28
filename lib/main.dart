import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

import 'StationDistance.dart';
import 'SubwayStation.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.white),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.white,
        child: Center(
            child: SizedBox(
              height: 60,
              child: ElevatedButton(
                onPressed: () async {
                  final map = await getNearestStationsByLine();
                  print(map);
                },
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  )
                ),
                child: const Text('현재 위치를 이용해 가까운 지하철역 찾기'),
              )
            )
        ),
      )
    );
  }

  Future<Map<String, StationDistance>> getNearestStationsByLine() async {
    final Position current = await _getPosition();
    final List<SubwayStation> stations = await _loadStations();

    final Map<String, StationDistance> result = {};
    final Map<String, double> minDistances = {};

    for (final s in stations) {
      final dist = Geolocator.distanceBetween(
        current.latitude,
        current.longitude,
        s.latitude,
        s.longitude,
      );

      final line = s.lineNumber;

      if (!result.containsKey(line) || dist < minDistances[line]!) {
        result[line] = StationDistance(s, dist);
        minDistances[line] = dist;
      }
    }
    return result;
  }

  Future<Position> _getPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('위치 서비스가 꺼져 있습니다.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('위치 권한이 거부되었습니다.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('위치 권한이 영구적으로 거부되어 설정에서 직접 변경해야 합니다.');
    }

    return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
  }

  Future<List<SubwayStation>> _loadStations() async {
    final jsonString = await rootBundle.loadString('assets/stations.json');
    final List<dynamic> jsonList = json.decode(jsonString);
    return jsonList.map((e) => SubwayStation.fromJson(e)).toList();
  }
}
