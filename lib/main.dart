import 'dart:io';

import 'package:flutter/material.dart';
import 'package:foreground_service_plugin/foreground_service_plugin.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'dart:async';
import 'StationDistance.dart';
import 'SubwayLine.dart';
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

  static const double _arrivalThresholdMeters = 5000.0;

  bool _loading = false;
  Map<String, StationDistance>? _nearestStationsByLine;
  final Set<String> _enabledNotificationStations = {};
  final Map<String, Timer> _timers = {};

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

                        final id = station.frCode;
                        final bool isEnabledNotification = _enabledNotificationStations.contains(id);

                        final lineEnum = SubwayLine.values.firstWhere(
                          (e) => e.lineNumber == station.lineNumber,
                          orElse: () => SubwayLine.line1,
                        );

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                          title: Text('${station.name}'),
                          subtitle: Text('$line • ${_formatDistance(dist)}'),
                          leading: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: lineEnum.color,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.train,
                              color: Colors.white,
                              size: 20,
                            )
                          ),
                          trailing: IconButton(
                            icon: Icon(
                              isEnabledNotification
                              ? Icons.notifications_active
                              : Icons.notifications_none
                            ),
                            color: isEnabledNotification
                            ? AppColors.green
                            : Colors.grey,
                            tooltip: isEnabledNotification
                            ? '알림 중지'
                            : '알림 설정',
                            onPressed: () async {
                                if (isEnabledNotification) {
                                  setState(() {
                                    _enabledNotificationStations.remove(id);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text('${station.lineNumber} 알림이 해제되었습니다')
                                      ),
                                    );
                                  });
                                  _disableSubwayStationNotification(station);
                                } else {
                                  setState(() {
                                    _enabledNotificationStations.add(id);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text('${station.lineNumber} 알림이 설정되었습니다')
                                      ),
                                    );
                                  });
                                  await _enableSubwayStationNotification(station);
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
                        horizontal: 20, vertical: 20),
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
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('현재 위치를 이용해 가까운 지하철역 찾기'),
                              const SizedBox(width: 8),
                              if (_loading)
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.green,
                                  ),
                                )
                            ],
                          )
                        )
                    )
                ),
              ),
            ]
        )
    );
  }

  @override
  void dispose() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    super.dispose();
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

    final id = selectedStation.frCode;
    if (_timers.containsKey(id)) return;

    final timer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      try {
        final result = await _findNearestStation(selectedStation);
        if (result == null) return;

        final nearest = result.station;
        final minDist = result.distance;

        if (minDist <= _arrivalThresholdMeters) {
          if (Platform.isAndroid) {
            await ForegroundServicePlugin.startService(
              nearest.name,
              _formatDistance(minDist),
            );
          } else {
            await _fln.show(
              0,
              '가장 가까운 지하철역 알림',
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
          }
        }
      } catch (_) {
        // 오류 무시 또는 로깅
      }
    });

    _timers[id] = timer;
  }

  void _disableSubwayStationNotification(SubwayStation subwayStation) {
    final id = subwayStation.frCode;
    _timers[id]?.cancel();
    _timers.remove(id);
  }

  Future<({SubwayStation station, double distance})?> _findNearestStation(SubwayStation selectedStation) async {
    try {
      SubwayStation? nearest;
      double minDist = double.infinity;

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final stations = await _loadStations();
      final sameLineStations = stations
          .where((s) => s.lineNumber == selectedStation.lineNumber)
          .toList();

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

      if (nearest == null) return null;
      return (station: nearest, distance: minDist);
    } catch (_) {
      return null;
    }
  }
}
