import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Map',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2196F3),
          primary: const Color(0xFF2196F3),
          secondary: const Color(0xFF4CAF50),
          error: const Color(0xFFF44336),
          surface: const Color(0xFFF5F5F5),
          background: Colors.white,
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF212121),
          ),
          titleMedium: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Color(0xFF212121),
          ),
          bodyLarge: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.normal,
            color: Color(0xFF212121),
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.normal,
            color: Color(0xFF757575),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF5F5F5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF2196F3)),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: const Color(0xFF2196F3),
            elevation: 2,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
      ),
      home: const LocationInputScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class LocationResult {
  final double latitude;
  final double longitude;

  LocationResult({required this.latitude, required this.longitude});
}

class LocationService {
  static Future<LocationResult?> searchLocation(String query) async {
    final response = await http.get(
      Uri.parse(
        'https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(query)}',
      ),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      if (data.isNotEmpty) {
        final location = data.first;
        return LocationResult(
          latitude: double.parse(location['lat']),
          longitude: double.parse(location['lon']),
        );
      }
    }
    throw Exception('Location not found');
  }
}

class WeatherInfo {
  final double temperature;
  final int humidity;
  final int weatherCode;
  final String description;

  WeatherInfo({
    required this.temperature,
    required this.humidity,
    required this.weatherCode,
    required this.description,
  });

  factory WeatherInfo.fromJson(Map<String, dynamic> json) {
    final current = json['current'];
    return WeatherInfo(
      temperature: current['temperature_2m']?.toDouble() ?? 0.0,
      humidity: current['relative_humidity_2m']?.toInt() ?? 0,
      weatherCode: current['weather_code']?.toInt() ?? 0,
      description: _getWeatherDescription(current['weather_code']?.toInt() ?? 0),
    );
  }

  static String _getWeatherDescription(int code) {
    if (code <= 3) return 'Clear';
    if (code <= 49) return 'Foggy';
    if (code <= 59) return 'Drizzle';
    if (code <= 69) return 'Rainy';
    if (code <= 79) return 'Snowy';
    if (code <= 99) return 'Thunderstorm';
    return 'Unknown';
  }
}

class WeatherService {
  static Future<WeatherInfo> getWeather(double lat, double lon) async {
    final response = await http.get(
      Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,relative_humidity_2m,weather_code&forecast_days=1',
      ),
    );

    if (response.statusCode == 200) {
      return WeatherInfo.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to fetch weather data');
    }
  }
}

class LocationInputScreen extends StatefulWidget {
  const LocationInputScreen({Key? key}) : super(key: key);

  @override
  _LocationInputScreenState createState() => _LocationInputScreenState();
}

class _LocationInputScreenState extends State<LocationInputScreen> {
  final TextEditingController _locationController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  List<String> recentSearches = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      recentSearches = prefs.getStringList('recentSearches') ?? [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Enter Location',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
              ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomSearchBar(
                controller: _locationController,
                formKey: _formKey,
                onSearch: _handleSearch,
                isLoading: isLoading,
              ),
              const SizedBox(height: 24),
              Text(
                'Recent Searches',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: RecentSearchesList(
                  searches: recentSearches,
                  onSearchSelected: (search) {
                    _locationController.text = search;
                    _handleSearch();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSearch() async {
    if (_formKey.currentState!.validate()) {
      setState(() => isLoading = true);
      try {
        final location = await LocationService.searchLocation(_locationController.text);
        if (location != null) {
          await _saveRecentSearch(_locationController.text);
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MapScreen(
                  latitude: location.latitude,
                  longitude: location.longitude,
                  locationName: _locationController.text,
                ),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => isLoading = false);
        }
      }
    }
  }

  Future<void> _saveRecentSearch(String location) async {
    if (!recentSearches.contains(location)) {
      setState(() {
        recentSearches.insert(0, location);
        if (recentSearches.length > 5) {
          recentSearches.removeLast();
        }
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('recentSearches', recentSearches);
    }
  }
}

class CustomSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final GlobalKey<FormState> formKey;
  final VoidCallback onSearch;
  final bool isLoading;

  const CustomSearchBar({
    Key? key,
    required this.controller,
    required this.formKey,
    required this.onSearch,
    required this.isLoading,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        children: [
          TextFormField(
            controller: controller,
            decoration: InputDecoration(
              labelText: 'Enter a location',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => controller.clear(),
                    )
                  : null,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a location';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: isLoading ? null : onSearch,
            child: isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Show on Map'),
          ),
        ],
      ),
    );
  }
}

class RecentSearchesList extends StatelessWidget {
  final List<String> searches;
  final Function(String) onSearchSelected;

  const RecentSearchesList({
    Key? key,
    required this.searches,
    required this.onSearchSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: searches.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        return ListTile(
          leading: const Icon(Icons.history, size: 20),
          title: Text(
            searches[index],
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          onTap: () => onSearchSelected(searches[index]),
        );
      },
    );
  }
}

class MapScreen extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String locationName;

  const MapScreen({
    Key? key,
    required this.latitude,
    required this.longitude,
    required this.locationName,
  }) : super(key: key);

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  WeatherInfo? _weatherInfo;

  @override
  void initState() {
    super.initState();
    _fetchWeather();
  }

  Future<void> _fetchWeather() async {
    try {
      final weather = await WeatherService.getWeather(
        widget.latitude,
        widget.longitude,
      );
      setState(() => _weatherInfo = weather);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching weather: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.locationName,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
              ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(widget.latitude, widget.longitude),
              initialZoom: 13.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.app',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    width: 40.0,
                    height: 40.0,
                    point: LatLng(widget.latitude, widget.longitude),
                    child: const MapMarker(),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_weatherInfo != null)
                  WeatherPanel(weatherInfo: _weatherInfo!),
                const SizedBox(height: 8),
                LocationInfoPanel(
                  latitude: widget.latitude,
                  longitude: widget.longitude,
                  locationName: widget.locationName,
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _mapController.move(
          LatLng(widget.latitude, widget.longitude),
          13.0,
        ),
        child: const Icon(Icons.my_location),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }
  }

class MapMarker extends StatelessWidget {
  const MapMarker({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, -20 * (1 - value)),
          child: Icon(
            Icons.location_pin,
            color: Theme.of(context).colorScheme.error,
            size: 40,
          ),
        );
      },
    );
  }
}

class WeatherPanel extends StatelessWidget {
  final WeatherInfo weatherInfo;

  const WeatherPanel({
    Key? key,
    required this.weatherInfo,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getWeatherIcon(weatherInfo.weatherCode),
                  size: 24,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '${weatherInfo.temperature.toStringAsFixed(1)}°C',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Text(
                  'Humidity: ${weatherInfo.humidity}%',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              weatherInfo.description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getWeatherIcon(int code) {
    if (code <= 3) return Icons.wb_sunny;
    if (code <= 49) return Icons.cloud;
    if (code <= 59) return Icons.grain;
    if (code <= 69) return Icons.water_drop;
    if (code <= 79) return Icons.ac_unit;
    return Icons.thunderstorm;
  }
}

class LocationInfoPanel extends StatelessWidget {
  final double latitude;
  final double longitude;
  final String locationName;

  const LocationInfoPanel({
    Key? key,
    required this.latitude,
    required this.longitude,
    required this.locationName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              locationName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _InfoItem(
                    label: 'Latitude',
                    value: latitude.toStringAsFixed(6),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _InfoItem(
                    label: 'Longitude',
                    value: longitude.toStringAsFixed(6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final String label;
  final String value;

  const _InfoItem({
    Key? key,
    required this.label,
    required this.value,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    );
  }
}

class AppConstants {
  static const double defaultPadding = 16.0;
  static const double cardBorderRadius = 12.0;
  static const double mapMarkerSize = 40.0;
  static const Duration animationDuration = Duration(milliseconds: 500);
  
  static const Map<String, String> weatherIcons = {
    'Clear': '☀️',
    'Foggy': '🌫️',
    'Drizzle': '🌧️',
    'Rainy': '🌧️',
    'Snowy': '🌨️',
    'Thunderstorm': '⛈️',
  };
}