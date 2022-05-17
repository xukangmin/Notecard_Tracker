import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'firebase_options.dart';
import 'package:intl/intl.dart'; // for date format
import 'package:intl/date_symbol_data_local.dart'; // for other locales
import 'dart:convert' as convert;

import 'package:http/http.dart' as http;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    name: "Test_APP",
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

double distance(lat1, lat2, lon1, lon2) {
  // The math module contains a function
  // named toRadians which converts from
  // degrees to radians.
  lon1 = lon1 * pi / 180.0;
  lon2 = lon2 * pi / 180.0;
  lat1 = lat1 * pi / 180.0;
  lat2 = lat2 * pi / 180.0;

  // Haversine formula
  var dlon = lon2 - lon1;
  var dlat = lat2 - lat1;
  var a =
      pow(sin(dlat / 2.0), 2) + cos(lat1) * cos(lat2) * pow(sin(dlon / 2), 2);

  var c = 2 * asin(sqrt(a));

  // Radius of earth in kilometers. Use 3956
  // for miles
  var r = 6371;

  // calculate the result
  return (c * r) * 1000;
}

class MapWidget extends StatefulWidget {
  const MapWidget({Key? key}) : super(key: key);

  @override
  _MapWidgetState createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  late GoogleMapController mapController;

  final LatLng _center = const LatLng(42.15830250000001, -87.96626171875);

  Map<MarkerId, Marker> markers = <MarkerId, Marker>{};
  Map<PolylineId, Polyline> polylines = <PolylineId, Polyline>{};
  int _markerIdCounter = 1;

  int _polylineIdCounter = 0;
  PolylineId? selectedPolyline;

  int colorsIndex = 0;
  List<Color> colors = <Color>[
    Colors.purple,
    Colors.red,
    Colors.green,
    Colors.pink,
  ];

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  void _add_poly_line(LatLng curPoint, LatLng prePoint) {
    final int polylineCount = polylines.length;

    final List<LatLng> points = <LatLng>[];

    points.add(prePoint);
    points.add(curPoint);

    // print('add poly_line');

    final String polylineIdVal = 'polyline_id_$_polylineIdCounter';
    _polylineIdCounter++;
    final PolylineId polylineId = PolylineId(polylineIdVal);

    final Polyline polyline = Polyline(
        polylineId: polylineId,
        consumeTapEvents: true,
        color: Colors.orange,
        width: 5,
        points: points);

    polylines[polylineId] = polyline;
  }

  void _add(lat, lng, markerNote) {
    final String markerIdVal = 'marker_id_$_markerIdCounter';
    _markerIdCounter++;
    final MarkerId markerId = MarkerId(markerIdVal);
    final Marker marker = Marker(
        markerId: markerId,
        position: LatLng(lat, lng),
        infoWindow: InfoWindow(title: markerNote, snippet: '*'));

    markers[markerId] = marker;
  }

  final Stream<QuerySnapshot> _locStream =
      FirebaseFirestore.instance.collection('location_data').snapshots();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _locStream,
      builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.hasError) {
          return const Text("Something went wrong");
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Text("Loading");
        }

        markers.clear();

        print(snapshot.connectionState);

        print(snapshot.data!.docs.length);

        // get latest point

        var timestamp = 0;

        var latestLat = 0.0, latestLng = 0.0;

        List latlngList = [];

        for (var element in snapshot.data!.docs) {
          var fileName = element['file'];

          print(fileName);
          if (fileName == '_track.qo') {
            var lat = element['where_lat'];
            var lng = element['where_lon'];
            var when = element['when'];
            var id = element['event'];

            var tempDict = {
              'id': element['event'],
              'lat': element['where_lat'],
              'lng': element['where_lon'],
              'timestamp': element['when']
            };

            latlngList.add(tempDict);

            if (when >= timestamp) {
              latestLat = lat;
              latestLng = lng;
              timestamp = when;
            }
          }
        }

        if (latlngList.isNotEmpty) {
          latlngList.sort((a, b) => a['timestamp'].compareTo(b['timestamp']));
        }

        // Add Polylines
        for (var i = 0; i < latlngList.length - 1; i++) {
          var curPos = latlngList[i];
          var nextPos = latlngList[i + 1];

          var dis = distance(
              curPos['lat'], nextPos['lat'], curPos['lng'], nextPos['lng']);

          print('distance=' + dis.toString());

          if (dis > 100.0) {
            _add_poly_line(LatLng(curPos['lat'], curPos['lng']),
                LatLng(nextPos['lat'], nextPos['lng']));
          }
        }

        if (latestLat != 0.0 && latestLng != 0.0) {
          var date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);

          _add(latestLat, latestLng, DateFormat().format(date));
          print('latest_lat=' + latestLat.toString());
          print('latest_Lng=' + latestLng.toString());
          print(timestamp);
        }

        return GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: LatLng(latestLat, latestLng),
              zoom: 11.0,
            ),
            markers: Set<Marker>.of(markers.values),
            polylines: Set<Polyline>.of(polylines.values));
      },
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Map<String, String> get headers => {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-SESSION-TOKEN": "JQ6NU3ZsIc7pQGEzg5ax9be7Zeb0kk7S"
      };

  void _sendRequest(mode) async {
    if (mode == 1) {
      var url = Uri.https('api.notefile.net',
          '/req?product=product:xxx:lovertracker&device=xxx');

      // Await the http get response, then decode the json-formatted response.
      var response = await http.post(
          Uri.parse(
              "https://api.notefile.net/req?product=product:xxx&device=xxx"),
          body: jsonEncode({
            "req": "note.add",
            "file": "remote-command.qi",
            "body": {"set-mode": "LIVE"}
          }),
          headers: headers);

      if (response.statusCode == 200) {
        // var jsonResponse =
        //     convert.jsonDecode(response.body) as Map<String, dynamic>;
        // var itemCount = jsonResponse['totalItems'];
        print(response.body);
      } else {
        print('Request failed with status: ${response.statusCode}.');
      }
    } else {
      print('Live mode');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Love Tracker'),
          backgroundColor: Colors.purple[700],
          actions: [
            PopupMenuButton(
              icon: const Icon(Icons.more_vert),
              itemBuilder: (BuildContext context) => <PopupMenuEntry>[
                PopupMenuItem(
                  child: const ListTile(
                    leading: Icon(Icons.fiber_manual_record),
                    title: Text('Live Mode'),
                  ),
                  onTap: () {
                    _sendRequest(0);
                  },
                ),
                PopupMenuItem(
                  child: const ListTile(
                    leading: Icon(Icons.watch_later_outlined),
                    title: Text('Normal Mode'),
                  ),
                  onTap: () {
                    _sendRequest(1);
                  },
                )
              ],
            ),
          ],
        ),
        body: const MapWidget(),
      ),
    );
  }
}
