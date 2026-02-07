import 'dart:io' show Platform, File; // Minimal import
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:sajda/models/prayer_time_model.dart';
import 'package:sajda/services/api_service.dart';
import 'package:sajda/services/database_helper.dart';
import 'package:sajda/widgets/glass_container.dart';
import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  PrayerTimings? _prayerTimings;
  bool _isLoading = true;
  String _errorMessage = '';
  String? _userName;
  String _locationName = 'Mecca, Saudi Arabia';
  String? _userImagePath;
  Map<DateTime, int> _heatmapDatasets = {};
  Map<String, bool> _prayerCompletion = {
    'Fajr': false,
    'Dhuhr': false,
    'Asr': false,
    'Maghrib': false,
    'Isha': false,
  };

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final databaseHelper = DatabaseHelper();
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // Fetch user profile
      final userProfile = await databaseHelper.getUserProfile();

      String? cityName;
      String? countryName;

      // Check Location Permission
      bool serviceEnabled;
      LocationPermission permission;

      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _errorMessage =
            'Location services are disabled. Using default location.';
      } else {
        permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            _errorMessage =
                'Location permissions are denied. Using default location.';
          }
        }

        if (permission == LocationPermission.deniedForever) {
          _errorMessage =
              'Location permissions are permanently denied. Using default location.';
        } else if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          try {
            Position position = await Geolocator.getCurrentPosition();

            // Fetch Prayer Timings immediately with coordinates
            final timings = await ApiService().getPrayerTimingsByLocation(
              latitude: position.latitude,
              longitude: position.longitude,
            );

            // Attempt to get City Name
            if (kIsWeb) {
              // Web Geocoding (OSM)
              try {
                final url = Uri.parse(
                  'https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&zoom=10',
                );
                final response = await http.get(
                  url,
                  headers: {'User-Agent': 'SajdaApp'},
                );
                if (response.statusCode == 200) {
                  final data = json.decode(response.body);
                  final address = data['address'];
                  cityName =
                      address['city'] ??
                      address['town'] ??
                      address['village'] ??
                      address['state'];
                  countryName = address['country'];
                }
              } catch (e) {
                debugPrint("Web geocoding failed: $e");
              }
            } else {
              // Mobile/Desktop Geocoding
              try {
                List<Placemark> placemarks = await placemarkFromCoordinates(
                  position.latitude,
                  position.longitude,
                );
                if (placemarks.isNotEmpty) {
                  cityName =
                      placemarks.first.locality ??
                      placemarks.first.subAdministrativeArea ??
                      'Unknown City';
                  countryName = placemarks.first.country ?? 'Unknown Country';
                }
              } catch (e) {
                debugPrint("Native geocoding failed: $e");
              }
            }

            setState(() {
              _prayerTimings = timings;
              if (cityName != null) {
                _locationName =
                    "$cityName${countryName != null ? ', $countryName' : ''}";
              } else {
                _locationName =
                    "Current Location"; // Fallback if geocoding fails but loc found
              }
            });
          } catch (e) {
            debugPrint("Location/API Error: $e");
          }
        }
      }

      if (_prayerTimings == null) {
        // Fallback to default if location failed or timings not set yet
        final timings = await ApiService().getPrayerTimings(
          city: 'Mecca',
          country: 'SA',
        );
        setState(() {
          _prayerTimings = timings;
          _locationName = "Mecca, Saudi Arabia";
        });
      }

      // Fetch completion status from DB
      final record = await databaseHelper.getDailyRecord(today);

      // Fetch all records for heatmap
      final allRecords = await databaseHelper.getAllRecords();
      Map<DateTime, int> datasets = {};

      // Ensure today is in the dataset
      final now = DateTime.now();
      final todayNormalized = DateTime(now.year, now.month, now.day);
      datasets[todayNormalized] = 0;

      for (var row in allRecords) {
        final date = DateTime.parse(row['date']);
        int completed = 0;
        if (row['fajr'] == 1) completed++;
        if (row['dhuhr'] == 1) completed++;
        if (row['asr'] == 1) completed++;
        if (row['maghrib'] == 1) completed++;
        if (row['isha'] == 1) completed++;

        // Normalize date to remove time component for heatmap
        final normalizedDate = DateTime(date.year, date.month, date.day);
        datasets[normalizedDate] = completed;
      }

      // If we already have today's record from getDailyRecord, use that count
      if (record != null) {
        int todayCompleted = 0;
        if (record['fajr'] == 1) todayCompleted++;
        if (record['dhuhr'] == 1) todayCompleted++;
        if (record['asr'] == 1) todayCompleted++;
        if (record['maghrib'] == 1) todayCompleted++;
        if (record['isha'] == 1) todayCompleted++;
        datasets[todayNormalized] = todayCompleted;
      }

      setState(() {
        _heatmapDatasets = datasets;
        if (record != null) {
          _prayerCompletion = {
            'Fajr': record['fajr'] == 1,
            'Dhuhr': record['dhuhr'] == 1,
            'Asr': record['asr'] == 1,
            'Maghrib': record['maghrib'] == 1,
            'Isha': record['isha'] == 1,
          };
        }
        if (userProfile != null) {
          _userName = userProfile['name'];
          _userImagePath = userProfile['image_path'];
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  MapEntry<String, int>? _getNextEvent(HijriDate date) {
    final events = [
      {'name': 'Islamic New Year', 'month': 1, 'day': 1},
      {'name': 'Ashura', 'month': 1, 'day': 10},
      {'name': 'Mawlid al-Nabi', 'month': 3, 'day': 12},
      {'name': 'Isra and Mi\'raj', 'month': 7, 'day': 27},
      {'name': 'Mid-Sha\'ban', 'month': 8, 'day': 15},
      {'name': 'Ramadan Start', 'month': 9, 'day': 1},
      {'name': 'Eid al-Fitr', 'month': 10, 'day': 1},
      {'name': 'Arafah', 'month': 12, 'day': 9},
      {'name': 'Eid al-Adha', 'month': 12, 'day': 10},
    ];

    for (var event in events) {
      int eMonth = event['month'] as int;
      int eDay = event['day'] as int;

      if (eMonth > date.month || (eMonth == date.month && eDay > date.day)) {
        int days = (eMonth - date.month) * 30 + (eDay - date.day);
        return MapEntry(event['name'] as String, days);
      }
    }

    var firstEvent = events.first;
    int days =
        (12 - date.month) * 30 + (30 - date.day) + (firstEvent['day'] as int);
    return MapEntry(firstEvent['name'] as String, days);
  }

  Future<void> _togglePrayerStatus(String prayerName) async {
    final databaseHelper = DatabaseHelper();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final newValue = !(_prayerCompletion[prayerName] ?? false);

    await databaseHelper.insertOrUpdatePrayer(
      today,
      prayerName.toLowerCase(),
      newValue,
    );

    setState(() {
      _prayerCompletion[prayerName] = newValue;

      // Update heatmap locally
      final date = DateTime.now();
      final normalizedDate = DateTime(date.year, date.month, date.day);
      int currentCount = _heatmapDatasets[normalizedDate] ?? 0;
      if (newValue) {
        currentCount++;
      } else {
        currentCount--;
      }
      _heatmapDatasets[normalizedDate] = currentCount;
    });
  }

  Color _getRingColor() {
    int completedCount = _prayerCompletion.values.where((v) => v).length;
    if (completedCount == 5) {
      return const Color(0xFFFFD700); // Gold
    } else if (completedCount >= 3) {
      return const Color(0xFFC0C0C0); // Silver
    } else {
      return const Color(0xFFA52A2A); // Brown
    }
  }

  @override
  Widget build(BuildContext context) {
    // Define a nice gradient background based on the primary color
    // final primaryColor = Theme.of(context).colorScheme.primary; // Unused now

    return Scaffold(
      extendBodyBehindAppBar:
          true, // If we had an app bar, this would be needed
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage.isNotEmpty
            ? Center(
                child: Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.red),
                ),
              )
            : ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 20.0,
                ),
                children: [
                  // Header
                  GlassContainer(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _getRingColor(),
                              width: 3,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 25,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.surface.withOpacity(0.5),
                            backgroundImage: _userImagePath != null
                                ? FileImage(File(_userImagePath!))
                                : null,
                            child: _userImagePath == null
                                ? const Icon(Icons.person)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Salam, ${_userName ?? 'User'}",
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat(
                                  'EEEE, d MMMM',
                                ).format(DateTime.now()),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(Icons.location_on, size: 12),
                                  const SizedBox(width: 4),
                                  Text(
                                    _locationName,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  if (_prayerTimings != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20.0),
                      child: GlassContainer(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "${_prayerTimings!.hijriDate.day} ${_prayerTimings!.hijriDate.monthName}",
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                    ),
                                    Text(
                                      "${_prayerTimings!.hijriDate.year} AH",
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(color: Colors.white70),
                                    ),
                                  ],
                                ),
                                if (_prayerTimings!
                                    .hijriDate
                                    .holidays
                                    .isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.green),
                                    ),
                                    child: Text(
                                      _prayerTimings!
                                          .hijriDate
                                          .holidays
                                          .first, // Show first holiday
                                      style: const TextStyle(
                                        color: Colors.greenAccent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Builder(
                              builder: (context) {
                                final nextEvent = _getNextEvent(
                                  _prayerTimings!.hijriDate,
                                );
                                if (nextEvent != null) {
                                  return Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.event,
                                          color: Colors.white70,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            "Next: ${nextEvent.key}",
                                            style: const TextStyle(
                                              color: Colors.white70,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          "${nextEvent.value} days",
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20.0),
                    child: GlassContainer(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          HeatMapCalendar(
                            datasets: _heatmapDatasets,
                            colorMode: ColorMode.color,
                            defaultColor: Colors.white.withOpacity(
                              0.1,
                            ), // Glass shade
                            textColor:
                                Colors.transparent, // Hide numbers inside boxes
                            showColorTip: false,
                            flexible: true,
                            weekTextColor: Colors.transparent, // Hide labels
                            colorsets: {
                              1: const Color(0xFF9BE9A8),
                              2: const Color(0xFF40C463),
                              3: const Color(0xFF30A14E),
                              4: const Color(0xFF216E39),
                              5: const Color(0xFF0E4429),
                            },
                            onClick: (value) {
                              _showGlassDialog(
                                DateFormat('EEEE, d MMMM yyyy').format(value),
                              );
                            },
                            initDate: DateTime.now(),
                            size: 30,
                            margin: const EdgeInsets.all(4),
                          ),
                        ],
                      ),
                    ),
                  ),

                  Text(
                    "Today's Prayers",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.color, // Ensure correct color for M3
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 15),

                  // Prayer List
                  if (_prayerTimings != null) ...[
                    _buildPrayerItem("Fajr", _prayerTimings!.fajr.readable),
                    _buildPrayerItem("Dhuhr", _prayerTimings!.dhuhr.readable),
                    _buildPrayerItem("Asr", _prayerTimings!.asr.readable),
                    _buildPrayerItem(
                      "Maghrib",
                      _prayerTimings!.maghrib.readable,
                    ),
                    _buildPrayerItem("Isha", _prayerTimings!.isha.readable),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
      ),
    );
  }

  void _showGlassDialog(String message) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.2),
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: GlassContainer(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            borderRadius: 20,
            opacity: 0.2, // Stronger glass for popup
            borderColor: Colors.white.withOpacity(0.3),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.calendar_today,
                  color: Colors.white70,
                  size: 30,
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 5),
                Text(
                  "Activity recorded", // Or fetch activity details if needed
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatTime(String time) {
    try {
      final cleanTime = time.split(' ')[0];
      final dateTime = DateFormat("HH:mm").parse(cleanTime);
      return DateFormat("h:mm a").format(dateTime);
    } catch (e) {
      return time;
    }
  }

  Widget _buildPrayerItem(String name, String time) {
    final isCompleted = _prayerCompletion[name] ?? false;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Dismissible(
        key: Key(name),
        direction: DismissDirection.startToEnd,
        background: Container(
          decoration: BoxDecoration(
            color: Colors.green,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 20),
          child: const Icon(Icons.check, color: Colors.white),
        ),
        confirmDismiss: (direction) async {
          _togglePrayerStatus(name);
          return false; // Don't remove the item
        },
        child: GlassContainer(
          opacity: isCompleted ? 0.3 : 0.15,
          borderColor: isCompleted
              ? Colors.green
              : Colors.white.withOpacity(0.5),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Text(
                name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isCompleted ? Colors.greenAccent : Colors.white,
                ),
              ),
              if (isCompleted) ...[
                const SizedBox(width: 8),
                const Icon(
                  Icons.check_circle,
                  size: 16,
                  color: Colors.greenAccent,
                ),
              ],
              const Spacer(),
              Text(
                _formatTime(time),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isCompleted ? Colors.greenAccent : Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
