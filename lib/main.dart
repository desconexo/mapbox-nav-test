import 'package:flutter/material.dart';
import 'package:flutter_mapbox_navigation/library.dart';
import 'package:get/get.dart';
import 'package:location/location.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final MapController controller = Get.put(MapController());
  late final MapBoxNavigationViewController _controller;
  final Location _location = Location();

  late MapBoxNavigation _directions;

  // final cityHall =
  //     WayPoint(name: "City Hall", latitude: 42.886448, longitude: -78.878372);
  // final downtown = WayPoint(
  //     name: "Downtown Buffalo", latitude: 42.8866177, longitude: -78.8814924);

  var wayPoints = <WayPoint>[];

  late final _options;

  @override
  void initState() {
    beginLocation();
    super.initState();
  }

  beginLocation() async {
    await assertLocationEnabled();
    await assertLocationPermission();

    final currentLocation = await _location.getLocation();

    _options = MapBoxOptions(
        initialLatitude: currentLocation.latitude, //36.1175275,
        initialLongitude: currentLocation.longitude, //-115.1839524,
        zoom: 13.0,
        tilt: 0.0,
        bearing: 0.0,
        enableRefresh: false,
        alternatives: true,
        voiceInstructionsEnabled: true,
        bannerInstructionsEnabled: true,
        allowsUTurnAtWayPoints: true,
        mode: MapBoxNavigationMode.drivingWithTraffic,
        units: VoiceUnits.imperial,
        simulateRoute: true,
        language: "en");

    _directions = MapBoxNavigation(onRouteEvent: _onRouteEvent);

    controller.changeLoading();
  }

  final _denyPermision = [
    PermissionStatus.denied,
    PermissionStatus.deniedForever
  ];

  assertLocationEnabled() async {
    var enabled = await _location.serviceEnabled();

    if (!enabled) {
      enabled = await _location.requestService();
      if (!enabled) throw ("Location not enabled");
    }
  }

  assertLocationPermission() async {
    var permission = await _location.hasPermission();

    if (_denyPermision.contains(permission)) {
      permission = await _location.requestPermission();
      if (_denyPermision.contains(permission)) assertLocationPermission();
    }
  }

  Future<void> _onRouteEvent(e) async {
    controller.distanceRemaining = await _directions.distanceRemaining;
    controller.durationRemaining = await _directions.durationRemaining;

    switch (e.eventType) {
      case MapBoxEvent.progress_change:
        var progressEvent = e.data as RouteProgressEvent;
        controller.arrived = progressEvent.arrived;
        if (progressEvent.currentStepInstruction != null)
          controller.instruction = progressEvent.currentStepInstruction;
        break;
      case MapBoxEvent.route_building:
      case MapBoxEvent.route_built:
        controller.routeBuilt = true;
        break;
      case MapBoxEvent.route_build_failed:
        controller.routeBuilt = false;
        break;
      case MapBoxEvent.navigation_running:
        controller.isNavigating = true;
        break;
      case MapBoxEvent.on_arrival:
        controller.arrived = true;
        if (!controller.isMultipleStop) {
          await Future.delayed(Duration(seconds: 3));
          await _controller.finishNavigation();
        }
        break;
      case MapBoxEvent.navigation_finished:
      case MapBoxEvent.navigation_cancelled:
        controller.routeBuilt = false;
        controller.isNavigating = false;
        break;
      default:
        break;
    }

    //refresh UI
    controller.changeLoading();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: StreamBuilder<bool>(
        stream: controller.stream,
        initialData: controller.value,
        builder: (_, loadingSnapshot) {
          if (!loadingSnapshot.hasData || loadingSnapshot.data!)
            return Center(child: CircularProgressIndicator());
          return Container(
            color: Colors.grey,
            child: MapBoxNavigationView(
                options: _options,
                onRouteEvent: _onRouteEvent,
                onCreated: (MapBoxNavigationViewController c) async {
                  _controller = c;
                }),
          );
        },
      ),
    );
  }
}

class MapController extends GetxController {
  late double distanceRemaining;
  late double durationRemaining;
  bool? arrived;
  String? instruction;
  late bool routeBuilt;
  late bool isNavigating;
  late bool isMultipleStop;

  RxBool _isLoading = true.obs;

  Stream<bool> get stream => this._isLoading.stream;
  bool get value => this._isLoading.value;

  changeLoading() => this._isLoading.value = !value;
}
