import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

import 'StationDistance.dart';
import 'SubwayStation.dart';
import 'colors.dart';

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
  bool _loading = false;
  Map<String, StationDistance>? _nearestStationsByLine;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(color: Colors.white),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 100), // 버튼 영역 확보
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position:
                    Tween(begin: const Offset(0, -.05), end: Offset.zero)
                        .animate(anim),
                    child: child,
                  ),
                ),
                child: _nearestStationsByLine == null
                  ? const SizedBox(key: ValueKey('empty'))
                  : ListView.builder(
                      key: const ValueKey('listView'),
                      itemCount: _nearestStationsByLine!.length,
                      itemBuilder: (context, index) {
                        final entry = _nearestStationsByLine!.entries.elementAt(index);
                        final line = entry.key;
                        final station = entry.value.station;
                        final dist = entry.value.distance;

                        return ListTile(
                          title: Text('${station.name}'),
                          subtitle: Text('$line • ${_formatDistance(dist)}'),
                          leading: const Icon(Icons.train),
                        );
                      },
                    ),
              ),
            ),
          ),
          AnimatedAlign(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            alignment: _nearestStationsByLine == null
              ? Alignment.center
              : Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
              child: SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: () async {
                    _loading ? null : _initiateNearestStationsByLine();
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.lightGreen,
                      foregroundColor: AppColors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      )
                  ),
                  child: _loading
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.green,
                    ),
                  )
                      : const Text('현재 위치를 이용해 가까운 지하철역 찾기'),
                )
              )
            ),
         ),
        ]
      )
    );
  }

  Future<void> _initiateNearestStationsByLine() async {
    setState(() => _loading = true);
    try {
      final nearestStationsByLine = await _getNearestStationsByLine();
      setState(() => _nearestStationsByLine = nearestStationsByLine);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<Map<String, StationDistance>> _getNearestStationsByLine() async {
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

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(2)} km';
    } else {
      return '${meters.toStringAsFixed(0)} m';
    }
  }
}
