import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'dart:async';

const String API_KEY = '00894a8de77f756b2d25184d8b484512';

void main() {
  runApp(const MyApp());
}

Future<http.Response> fetchPlaceData(String placeName) async {
  final response = await http.get(Uri.parse(
      'http://api.openweathermap.org/geo/1.0/direct?q=$placeName&appid=$API_KEY'));

  if (response.statusCode == 200)
    return response;
  else
    return Future.error("Failed to fetch coordinates of the place: " +
        response.statusCode.toString());
}

Future<http.Response?> fetchWeatherData() async {
  Position? pos = await fetchCurrentPosition();

  if (pos?.latitude == null || pos?.longitude == null) {
    return Future.error("Failed to fetch current coordinates");
  }

  return await fetchWeatherDataFromCoords(
      pos?.latitude as double, pos?.longitude as double);
}

Future<http.Response?> fetchFutureData() async {
  Position? pos = await fetchCurrentPosition();

  if (pos?.latitude == null || pos?.longitude == null) {
    return Future.error("Failed to fetch current coordinates");
  }

  return await fetchFutureDataFromCoords(
      pos?.latitude as double, pos?.longitude as double);
}

Future<Position?> fetchCurrentPosition() async {
  bool serviceEnabled;
  LocationPermission permission;

  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    return Future.error('Location services are disabled.');
  }

  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      return Future.error('Location permissions are denied');
    }
  }

  if (permission == LocationPermission.deniedForever) {
    return Future.error(
        'Location permissions are permanently denied, we cannot request permissions.');
  }

  return await Geolocator.getLastKnownPosition();
}

Future<http.Response> fetchFutureDataFromCoords(double lat, double long) async {
//  return http.get(Uri.parse('http://api.openweathermap.org/data/2.5/forecast?id=524901&appid=$API_KEY'));
  final response = await http.get(Uri.parse(
      'http://api.openweathermap.org/data/2.5/forecast?lat=$lat&lon=$long&units=metric&appid=$API_KEY'));

  if (response.statusCode == 200)
    return response;
  else
    return Future.error(
        "Failed to fetch weather info: " + response.statusCode.toString());
}

Future<http.Response> fetchWeatherDataFromCoords(
    double lat, double long) async {
//  return http.get(Uri.parse('http://api.openweathermap.org/data/2.5/forecast?id=524901&appid=$API_KEY'));
  final response = await http.get(Uri.parse(
      'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$long&units=metric&appid=$API_KEY'));

  if (response.statusCode == 200)
    return response;
  else
    return Future.error(
        "Failed to fetch weather info: " + response.statusCode.toString());
}

Future<http.Response?> fetchFutureDataFromName(String locationName) async {
  final locationResponse = await fetchPlaceData(locationName);

  final data = jsonDecode(locationResponse.body);

  if (locationResponse.statusCode != 200) return null;

  if (data.length == 0) return Future.error("No place with the name found");

  double lat = (data[0]['lat']).toDouble();
  double long = (data[0]['lon']).toDouble();

  return fetchFutureDataFromCoords(lat, long);
}

Future<http.Response?> fetchWeatherDataFromName(String locationName) async {
  final locationResponse = await fetchPlaceData(locationName);

  final data = jsonDecode(locationResponse.body);

  if (locationResponse.statusCode != 200) return null;

  if (data.length == 0) return Future.error("No place with the name found");

  double lat = (data[0]['lat']).toDouble();
  double long = (data[0]['lon']).toDouble();

  return fetchWeatherDataFromCoords(lat, long);
}

DateTime ToLocalTime(dynamic unixTime) {
  DateTime currentUtcTime =
      DateTime.fromMillisecondsSinceEpoch(unixTime * 1000, isUtc: true);
  return currentUtcTime.toLocal();
}

String GetIconURL(String id, int size) {
  if (size == 1) return 'http://openweathermap.org/img/wn/$id.png';

  return 'http://openweathermap.org/img/wn/$id@' + size.toString() + 'x.png';
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Search for a different place',
        theme: ThemeData(
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.lightBlue,
            foregroundColor: Colors.black,
          ),
        ),
        home: HomePageWidget());
  }
}

enum HomePageState { Normal, SearchButtonPressed, Busy }

class _HomePageWidgetState extends State<HomePageWidget> {
  bool startingForTheFirstTime = true;

  IconData leadingAppBarIcon = Icons.search;
  HomePageState state = HomePageState.Normal;
  Widget appBarTitle = Text("Search");

  Timer? timer;

  String date = "";
  String time = "";

  String description = "Failed to retrive weather data!";
  String temp = "";
  String feelsLikeTemp = "";
  String humidity = "";

  String visibility = "";
  String windSpeed = "";

  double showingLat = 37.3861;
  double showingLon = 122.0839;

  double currentLat = 37.3861;
  double currentLon = 122.0839;

  String currentPlaceName = "Search";
  String iconURL = "http://openweathermap.org/img/wn/10d@4x.png";
  http.Response? currentData = null;

  dynamic futureJSON;
  dynamic currentJSON;

  http.Response? futureData = null;

  double horizontalDivThickness = 4;
  double verticalDivThickness = 4;

  static const int TRACK_COUNT = 4;

  var weatherInfo = [];

  void ResetSearchBar() {
    state = HomePageState.Normal;
    leadingAppBarIcon = Icons.search;
  }

  void changeFutureData(http.Response? response) {
    setState(() {
      if (response != null) {
        futureJSON = jsonDecode(response.body);

        bool haveCurrentData = !weatherInfo.isEmpty;
        // Check for different weathers.
        // If not different then check for next and next to next days.
        // If not avaliable then leave null.

        int count = futureJSON["cnt"];

        if (!haveCurrentData) weatherInfo.add(futureJSON["list"][0]);

        while (weatherInfo.length > 1) weatherInfo.removeLast();

        print("start: " + weatherInfo.length.toString());
        int lastIndex = haveCurrentData ? -1 : 0;
        int c = 1;
        for (int i = haveCurrentData ? 0 : 1; i < count; i++) {
          if (futureJSON["list"][i]["weather"][0]["id"] !=
              futureJSON["list"][c - 1]["weather"][0]["id"]) {
            weatherInfo.add(futureJSON["list"][i]);
            lastIndex = c;
            c++;

            if (c >= TRACK_COUNT) break;
          }
        }

        for (int i = lastIndex + 1; i < count && c < TRACK_COUNT; i++)
          weatherInfo.add(futureJSON["list"][i]);

        print("end: " + weatherInfo.length.toString());
      } else {}
    });
  }

  void changeCurrentData(http.Response? response) {
    setState(() {
      if (response != null) {
        currentJSON = jsonDecode(response.body);

        if (weatherInfo.isEmpty) {
          weatherInfo.add(currentJSON);
        } else {
          weatherInfo[0] = currentJSON;
        }

        currentData = response;
        description = response.body;

        currentPlaceName = currentJSON["name"];

        temp = weatherInfo[0]["main"]["temp"].toStringAsFixed(0) + '°C';
        feelsLikeTemp =
            weatherInfo[0]["main"]["feels_like"].toStringAsFixed(0) + '°C';
        humidity = 'Humidity: ' + weatherInfo[0]["main"]["humidity"].toString();
        visibility = 'Visibility: ' + weatherInfo[0]["visibility"].toString();
        windSpeed = 'Wind Speed: ' + weatherInfo[0]["wind"]["speed"].toString();
        description = weatherInfo[0]["weather"][0]["description"];

        String iconCode = weatherInfo[0]["weather"][0]["icon"];
        iconURL = 'http://openweathermap.org/img/wn/$iconCode@4x.png';
      } else {
        currentData = null;
        description = "Failed to retrive weather data!";
        iconURL = "";
        currentPlaceName = "Search";
        currentJSON = null;
      }
    });
  }

  void onSearchSubmit(String textfieldValue) {
    setState(() {
      Future<http.Response?> response =
          fetchWeatherDataFromName(textfieldValue);

      fetchFutureDataFromName(textfieldValue).then(changeFutureData);

//      print(textfieldValue);

      response.then(((value) {
        changeCurrentData(value);
        if (value != null)
          print(value.body);
        else
          print("Value was null");
      }));
      response.catchError((x) => print("ERROR!!: " + x.toString()));

      ResetSearchBar();
    });
  }

  void onSearchButtonPress() {
    setState(() {
      if (state == HomePageState.Normal) {
        state = HomePageState.SearchButtonPressed;
        leadingAppBarIcon = Icons.close;
      } else if (state == HomePageState.SearchButtonPressed) {
        ResetSearchBar();
      }
    });
  }

  void setDateAndTime() {
    setState(() {
      date = DateTime.now().toString().substring(0, 10);
      time = DateTime.now().toString().substring(11, 16);
    });
  }

  void init() async {
    if (!startingForTheFirstTime) return;

    startingForTheFirstTime = false;

    description = "Fetching weather data...";
    await fetchWeatherData().then(changeCurrentData);

    await fetchFutureData().then(changeFutureData);
    timer = Timer.periodic(
        Duration(minutes: 1),
        (Timer t) => setState(() {
              setDateAndTime();
            }));
  }

  @override
  void dispose() {
    if (timer != null) timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    init();
    setDateAndTime();
    return Scaffold(
        backgroundColor: Color.fromARGB(255, 255, 255, 255),
        appBar: AppBar(
            centerTitle: true,
            leading: IconButton(
                onPressed: onSearchButtonPress, icon: Icon(leadingAppBarIcon)),
            title: state == HomePageState.SearchButtonPressed
                ? TextField(
                    onSubmitted: onSearchSubmit,
                    style: TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                        prefixIcon: Icon(Icons.search, color: Colors.black),
                        hintText: "Search (may take a while)",
                        hintStyle: TextStyle(color: Colors.black)))
                : Text(currentPlaceName)),
        body: Container(decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/background.png"),
            fit: BoxFit.cover,
          ),
        ),child:Column(children: [
          Padding(
            padding: EdgeInsets.fromLTRB(0, 10, 0, 0),
            child: Column(children: [
              Padding(padding: EdgeInsets.all(7), child:Text(
                date,
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
              )),
              Padding(padding: EdgeInsets.all(2), child:Text(
                time,
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
              )),
            ]),
          ),

//          Image.network(iconURL),
          Padding(
              padding: EdgeInsets.all(16),
              child: Row(children: [
                Container(
                  height: 250,
                  width: 250,
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color:
                            Color.fromARGB(255, 0, 195, 255).withOpacity(0.6),
                        spreadRadius: 0,
                        blurRadius: 2,
                        offset: Offset(0, 0), // changes position of shadow
                      ),
                    ],
                    color: Color.fromARGB(255, 0, 114, 236).withOpacity(0.7),
                    image: DecorationImage(
                      image: NetworkImage(iconURL),
                      fit: BoxFit.cover,
                    ),
                    border: Border.all(
                        width: 5,
                        color:
                            Color.fromARGB(255, 45, 45, 45).withOpacity(0.3)),
                    borderRadius: BorderRadius.all(Radius.elliptical(25, 25)),
                  ),
                ),
                Padding(
                    padding: EdgeInsets.fromLTRB(10, 0, 0, 0),
                    child: Column(
                      children: [
                        Text(
                          "Temp:",
                          style: TextStyle(
                            fontSize: 25,
                          ),
                        ),
                        Text(
                          temp,
                          style: TextStyle(
                              fontSize: 45, fontWeight: FontWeight.bold),
                        ),
                        Container(
                            width: 100,
                            child: Divider(
                              thickness: verticalDivThickness,
                            )),
                        Text("Feels Like:",
                            style: TextStyle(
                              fontSize: 25,
                            )),
                        Text(
                          feelsLikeTemp,
                          style: TextStyle(
                              fontSize: 45, fontWeight: FontWeight.bold),
                        )
                      ],
                    ))
              ])),
          Padding(
            padding: EdgeInsets.all(3),
            child: Padding(padding:EdgeInsets.fromLTRB(15, 10, 0, 10), child:Align(alignment: Alignment.centerLeft, child:Text(
              description,
              style: TextStyle(fontSize: 27),
            ))),
          ),

          Divider(
            thickness: horizontalDivThickness,
          ),
          IntrinsicHeight(
              child: Row(children: [
            Padding(padding: EdgeInsets.all(5), child: Text(humidity, style:TextStyle(fontSize: 15))),
            VerticalDivider(
              thickness: verticalDivThickness,
            ),
            Padding(padding: EdgeInsets.all(5), child: Text(windSpeed, style:TextStyle(fontSize: 15))),
            VerticalDivider(
              thickness: verticalDivThickness,
            ),
            Padding(padding: EdgeInsets.all(5), child: Text(visibility, style:TextStyle(fontSize: 15),)),
          ])),
          Divider(
            thickness: horizontalDivThickness,
          ),
          Align(alignment: Alignment.centerLeft, child:Padding(padding: EdgeInsets.all(12), child:Text("Predictions: ", style:TextStyle(fontSize: 25)))),
          Row(
            children: [
              for (int i = 1; i < (weatherInfo.length < 4 ? weatherInfo.length : 4); i++)
                WeatherWidget(weatherInfo: weatherInfo[i]),
            ],
          ),
//          Text(description)
        ])));
  }
}
//Align(alignment: Alignment.topLeft, child: Text(description))

class HomePageWidget extends StatefulWidget {
  const HomePageWidget({Key? key}) : super(key: key);

  @override
  State<HomePageWidget> createState() => _HomePageWidgetState();
}

class WeatherWidget extends StatelessWidget {
  dynamic weatherInfo;

  WeatherWidget({Key? key, @required this.weatherInfo}) : super(key: key);

  @override
  Widget build(BuildContext context) {

    print(weatherInfo.toString());

    String rawTime = ToLocalTime(weatherInfo["dt"]).toString();

    String date = rawTime.substring(0, 10);
    String time = rawTime.substring(11, 16);

    String rawTemp = weatherInfo["main"]["temp"].toString();

    String temp = rawTemp.substring(0, rawTemp.indexOf('.')) + "°C";

    return Padding(
        padding: EdgeInsets.all(8.5),
        child: Container(
          height: 145,
          width: 122,
          padding: EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Color.fromARGB(255, 0, 195, 255).withOpacity(0.8),
                spreadRadius: 0,
                blurRadius: 2,
                offset: Offset(0, 0), // changes position of shadow
              ),
            ],
            border: Border.all(
                width: 5,
                color: Color.fromARGB(255, 45, 45, 45).withOpacity(0.3)),
            borderRadius: BorderRadius.all(Radius.elliptical(25, 25)),
          ),
          child: Column(children: [
            Text(date,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black.withOpacity(0.6))),
            Text(time,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black.withOpacity(0.6))),
            Image.network(GetIconURL(weatherInfo["weather"][0]["icon"], 1)),
            Text(temp,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black.withOpacity(0.6)))
          ]),
        ));
  }
}
