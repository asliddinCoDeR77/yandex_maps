import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:google_places_autocomplete_text_field/google_places_autocomplete_text_field.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late YandexMapController mapController;
  static const double defaultZoom = 15.0;
  TextEditingController searchController = TextEditingController();
  final String apiKey = 'd6690544-262f-498c-9d20-395274d7365a';
  final List<PlacemarkMapObject> markers = [];

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yandex Map Example'),
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_out),
            onPressed: () async {
              mapController.moveCamera(
                CameraUpdate.zoomOut(),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.zoom_in),
            onPressed: () async {
              mapController.moveCamera(
                CameraUpdate.zoomIn(),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          YandexMap(
            onMapCreated: (YandexMapController controller) {
              mapController = controller;
              _moveToCurrentLocation();
            },
            mapType: MapType.vector,
            onMapTap: _handleMapTap,
            mapObjects: markers,
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: GooglePlacesAutoCompleteTextFormField(
                      textEditingController: searchController,
                      googleAPIKey: apiKey,
                      debounceTime: 400,
                      isLatLngRequired: true,
                      itmClick: (prediction) {
                        searchController.text = prediction.description!;
                        _performSearch(prediction.description!);
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () {
                      _performSearch(searchController.text);
                    },
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              onPressed: () async {
                await _showCurrentLocation();
              },
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _moveToCurrentLocation() async {
    Position position = await _determinePosition();
    Point point =
        Point(latitude: position.latitude, longitude: position.longitude);

    _addMarker(point, 'current_location', 'Current Location');

    mapController.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: point,
          zoom: defaultZoom,
        ),
      ),
    );
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      throw 'Location services are disabled.';
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw 'Location permissions are denied.';
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw 'Location permissions are permanently denied, we cannot request permissions.';
    }

    return await Geolocator.getCurrentPosition();
  }

  Future<void> _checkLocationPermission() async {
    await _determinePosition();
  }

  Future<void> _showCurrentLocation() async {
    Position position = await _determinePosition();
    Point point =
        Point(latitude: position.latitude, longitude: position.longitude);

    _addMarker(point, 'current_location', 'Current Location');

    mapController.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: point,
          zoom: defaultZoom,
        ),
      ),
    );
  }

  Future<void> _performSearch(String query) async {
    final String url =
        'https://geocode-maps.yandex.ru/1.x/?apikey=$apiKey&geocode=$query&format=json';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      final results = data['response']['GeoObjectCollection']['featureMember'];
      if (results.isNotEmpty) {
        final firstResult = results[0]['GeoObject']['Point']['pos'];
        final coordinates = firstResult.split(' ');
        final longitude = double.parse(coordinates[0]);
        final latitude = double.parse(coordinates[1]);

        Point point = Point(latitude: latitude, longitude: longitude);

        _addMarker(point, 'search_result', 'Search Result');

        mapController.moveCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: point,
              zoom: defaultZoom,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No results found')),
        );
      }
    } else {
      throw Exception('Failed to load location');
    }
  }

  void _handleMapTap(Point point) {
    _clearMarkers();

    _addMarker(point, 'selected_destination', 'Selected Destination');

    mapController.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: point,
          zoom: defaultZoom,
        ),
      ),
    );
  }

  void _addMarker(Point point, String mapId, String description) {
    setState(() {
      markers.add(
        PlacemarkMapObject(
          mapId: MapObjectId(mapId),
          point: point,
          icon: PlacemarkIcon.single(
            PlacemarkIconStyle(
              image: BitmapDescriptor.fromAssetImage(
                  'assets/current_location.png'),
              scale: 1,
            ),
          ),
          onTap: (PlacemarkMapObject self, Point point) {
            // Handle marker tap if needed
          },
        ),
      );
    });
  }

  void _clearMarkers() {
    setState(() {
      markers.clear();
    });
  }
}
