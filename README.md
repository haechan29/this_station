### This station is
현재 가장 가까운 지하철역을 알려주는 서비스<br/><br/>
<img src="https://github.com/user-attachments/assets/3ac72775-30ca-464b-b943-ec2a2e4e258b" style="width:300px"></img><br/><br/>

### 개발 환경
| 개발 인원 | 기술 스택 | 개발 기간  |
|:-----------:|:-----------:|:------------:|
| 1인       | Flutter   | 2025.06.28 |

### 작업 동기
- **지하철 탑승 중에 현재 지하철 역 위치를 파악하기 어려운 경우**가 있음
- 핸드폰 알림을 통해 현재 위치를 알려줌으로써 쉽게 위치 파악

### 애니메이션 적용
- `AnimatedSwitcher`을 통해 지하철역 리스트 Fade In 애니메이션
- `AnimatedAlign`을 통해 지하철역 찾기 버튼 아래로 자연스럽게 이동
  - 지하철역 리스트 뷰(빨간 영역)가 버튼 영역(파란색)을 침범하지 않도록 절대 위치에 기반하는 Stack 뷰 사용
  - 하단의 높이 120 영역을 버튼 영역으로 둠
  - <img src="https://github.com/user-attachments/assets/e0cb44e5-e361-4a19-89f9-5d7c3b59be2b"  width="250" height="600"/>
    
### 사용자와 가장 가까운 지하철역 찾기 알고리즘
- `Geolocator`을 통해 현재 위치 확인
- 로컬 파일로부터 지하철 정보 읽고, 현재 위치로부터 거리 계산
- 지하철 호선 별로 가장 가까운 지하철역 찾기

<details>
  <summary>코드 확인하기</summary>
  
```dart
  
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
  ```
</details>

### 주기적으로 위치 알림
- `FlutterLocalNotificationsPlugin`와 `Timer` 사용
<details>
  <summary>코드 확인하기</summary>

```dart

  void _startSubwayStationNotification(SubwayStation selectedStation) async {
    final id = selectedStation.frCode;
    if (_timers.containsKey(id)) return;

    final stations = await _loadStations();
    final sameLineStations = stations
        .where((s) => s.lineNumber == selectedStation.lineNumber)
        .toList();

    final timer = Timer.periodic(const Duration(seconds: 10), (timer) async {
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
          timer.cancel(); // 1회 알림 후 중지 (필요에 따라 반복 가능)
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
```
</details>
