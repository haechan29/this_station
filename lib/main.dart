import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'dart:async';
import 'StationDistance.dart';
import 'SubwayStation.dart';
import 'colors.dart';

final _fln = FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initLocalNotifications();
  runApp(const MyApp());
}

Future<void> _initLocalNotifications() async {
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const ios = DarwinInitializationSettings();
  const initSettings = InitializationSettings(android: android, iOS: ios);
  await _fln.initialize(initSettings);
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

  static const double _arrivalThresholdMeters = 20000000.0;

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
                    transitionBuilder: (child, anim) =>
                        FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position:
                            Tween(
                                begin: const Offset(0, -.05), end: Offset.zero)
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
                        final entry = _nearestStationsByLine!.entries.elementAt(
                            index);
                        final line = entry.key;
                        final station = entry.value.station;
                        final dist = entry.value.distance;

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16),
                          title: Text('${station.name}'),
                          subtitle: Text('$line • ${_formatDistance(dist)}'),
                          leading: const Icon(Icons.train),
                          trailing: IconButton(
                            icon: const Icon(Icons.notifications_none),
                            color: AppColors.green,
                            tooltip: '알림 설정',
                            onPressed: () async {
                              try {
                                await _enableSubwayStationNotification(station);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(
                                      '${station.name} 알림이 설정되었습니다')),
                                );
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );
                              }
                            },
                          ),
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 30),
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

  Future<void> _enableSubwayStationNotification(SubwayStation station) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw '위치 서비스가 꺼져 있습니다.';
    }
    LocationPermission locPerm = await Geolocator.checkPermission();
    if (locPerm == LocationPermission.denied ||
        locPerm == LocationPermission.deniedForever) {
      locPerm = await Geolocator.requestPermission();
      if (locPerm == LocationPermission.denied ||
          locPerm == LocationPermission.deniedForever) {
        throw '위치 권한을 허용해야 알림을 받을 수 있습니다.';
      }
    }

    PermissionStatus ntfStatus = await Permission.notification.status;
    if (!ntfStatus.isGranted) {
      ntfStatus = await Permission.notification.request();
      if (!ntfStatus.isGranted) {
        throw '알림 권한이 거부되었습니다.';
      }
    }

    _startSubwayStationNotification(station);
  }

  void _startSubwayStationNotification(SubwayStation selectedStation) async {
    final stations = await _loadStations();
    final sameLineStations = stations
        .where((s) => s.lineNumber == selectedStation.lineNumber)
        .toList();

    Timer.periodic(const Duration(seconds: 10), (timer) async {
      try {
        final pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high);

        SubwayStation? nearest;
        double minDist = double.infinity;

        for (final s in sameLineStations) {
          final dist = Geolocator.distanceBetween(
            pos.latitude,
            pos.longitude,
            s.latitude,
            s.longitude,
          );
          if (dist < minDist) {
            minDist = dist;
            nearest = s;
          }
        }

        if (nearest != null && minDist <= _arrivalThresholdMeters) {
          await _fln.show(
            0,
            '가장 가까운 역 알림',
            '현재 ${nearest.name}으로부터 ${_formatDistance(minDist)} 떨어져 있습니다',
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'arrival_channel',
                '도착 알림',
                importance: Importance.high,
                priority: Priority.high,
                icon: '@mipmap/ic_launcher',
              ),
              iOS: DarwinNotificationDetails(),
            ),
          );
          timer.cancel(); // 1회 알림 후 중지 (필요에 따라 반복 가능)
        }
      } catch (_) {
        // 오류 무시 또는 로깅
      }
    });
  }
}
