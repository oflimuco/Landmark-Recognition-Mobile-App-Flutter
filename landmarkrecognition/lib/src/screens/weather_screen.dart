import 'package:flutter/material.dart';
import 'package:landmarkrecognition/screens/weather.dart';
import 'package:landmarkrecognition/src/api/weather_api_client.dart';
import 'package:landmarkrecognition/src/bloc/weather_bloc.dart';
import 'package:landmarkrecognition/src/bloc/weather_event.dart';
import 'package:landmarkrecognition/src/bloc/weather_state.dart';
import 'package:landmarkrecognition/src/repository/weather_repository.dart';
import 'package:landmarkrecognition/src/api/api_keys.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:landmarkrecognition/src/widgets/weather_widget.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

enum OptionsMenu { changeCity, settings }

// ignore: must_be_immutable
class WeatherScreen extends StatefulWidget {
  String cityName;
  bool flag = false;
  WeatherScreen({this.cityName,this.flag}) : assert(cityName != null);
  final WeatherRepository weatherRepository = WeatherRepository(weatherApiClient: WeatherApiClient(
          httpClient: http.Client(), apiKey: ApiKey.OPEN_WEATHER_MAP));
  @override
  _WeatherScreenState createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> with TickerProviderStateMixin {
  WeatherBloc _weatherBloc;
  //String cityName = "bengaluru";
  AnimationController _fadeController;
  Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _weatherBloc = WeatherBloc(weatherRepository: widget.weatherRepository);
    _fetchWeatherWithCity();
    /*
    _fetchWeatherWithLocation().catchError((error) {
      print("initstate");
      _fetchWeatherWithCity();
      print("initstate");
    });

     */
    _fadeController = AnimationController(
        duration: const Duration(milliseconds: 1000), vsync: this);
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
  }

  Widget sliderWeather(){
    return Material(
      child: Container(
        constraints: BoxConstraints.expand(),
        decoration: BoxDecoration(
            color: AppStateContainer.of(context).theme.primaryColor),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: BlocBuilder(
              bloc: _weatherBloc,
              // ignore: missing_return
              builder: (_, WeatherState weatherState) {
                if (weatherState is WeatherLoaded) {
                  widget.cityName = weatherState.weather.cityName;
                  _fadeController.reset();
                  _fadeController.forward();
                  return WeatherWidget(
                    weather: weatherState.weather,
                    flag: widget.flag,
                  );
                } else if (weatherState is WeatherError ||
                    weatherState is WeatherEmpty) {
                  String errorText =
                      'There was an error fetching weather data';
                  if (weatherState is WeatherError) {
                    if (weatherState.errorCode == 404) {
                      errorText =
                      'We have trouble fetching weather for $widget.cityName';
                    }
                  }
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(
                        Icons.error_outline,
                        color: Colors.redAccent,
                        size: 24,
                      ),
                      SizedBox(
                        height: 10,
                      ),
                      Text(
                        errorText,
                        style: TextStyle(
                            color: AppStateContainer.of(context)
                                .theme
                                .accentColor),
                      ),
                      FlatButton(
                        child: Text(
                          "Try Again",
                          style: TextStyle(
                              color: AppStateContainer.of(context)
                                  .theme
                                  .accentColor),
                        ),
                        onPressed: _fetchWeatherWithCity,
                      )
                    ],
                  );
                } else if (weatherState is WeatherLoading) {
                  return Center(
                    child: CircularProgressIndicator(
                      backgroundColor:
                      AppStateContainer.of(context).theme.primaryColor,
                    ),
                  );
                }
              }),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if(widget.flag){
      return sliderWeather();
    }
    return Scaffold(
        appBar: AppBar(
          backgroundColor: AppStateContainer.of(context).theme.primaryColor,
          elevation: 0,
          title: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
                style: TextStyle(
                    color: AppStateContainer.of(context)
                        .theme
                        .accentColor
                        .withAlpha(80),
                    fontSize: 14),
              )
            ],
          ),
          actions: <Widget>[
            PopupMenuButton<OptionsMenu>(
                child: Icon(
                  Icons.more_vert,
                  color: AppStateContainer.of(context).theme.accentColor,
                ),
                onSelected: this._onOptionMenuItemSelected,
                itemBuilder: (context) => <PopupMenuEntry<OptionsMenu>>[
                      PopupMenuItem<OptionsMenu>(
                        value: OptionsMenu.changeCity,
                        child: Text("change city"),
                      ),
                      PopupMenuItem<OptionsMenu>(
                        value: OptionsMenu.settings,
                        child: Text("settings"),
                      ),
                    ])
          ],
        ),
        backgroundColor: Colors.white,
        body: sliderWeather());
  }

  void _showCityChangeDialog() {
    showDialog(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: Colors.white,
            title: Text('Change city', style: TextStyle(color: Colors.black)),
            actions: <Widget>[
              FlatButton(
                child: Text(
                  'ok',
                  style: TextStyle(color: Colors.black, fontSize: 16),
                ),
                onPressed: () {
                  _fetchWeatherWithCity();
                  Navigator.of(context).pop();
                },
              ),
            ],
            content: TextField(
              autofocus: true,
              onChanged: (text) {
                widget.cityName = text;
              },
              decoration: InputDecoration(
                  hintText: 'Name of your city',
                  hintStyle: TextStyle(color: Colors.black),
                  suffixIcon: GestureDetector(
                    onTap: () {
                      _fetchWeatherWithLocation().catchError((error) {
                        _fetchWeatherWithCity();
                      });
                      Navigator.of(context).pop();
                    },
                    child: Icon(
                      Icons.my_location,
                      color: Colors.black,
                      size: 16,
                    ),
                  )),
              style: TextStyle(color: Colors.black),
              cursorColor: Colors.black,
            ),
          );
        });
  }

  _onOptionMenuItemSelected(OptionsMenu item) {
    switch (item) {
      case OptionsMenu.changeCity:
        this._showCityChangeDialog();
        break;
      case OptionsMenu.settings:
        Navigator.of(context).pushNamed("/settings");
        break;
    }
  }

  _fetchWeatherWithCity() {
    print("fetch");
    _weatherBloc.dispatch(FetchWeather(cityName: widget.cityName));
    print("fetch");
  }

  _fetchWeatherWithLocation() async {
    var permissionHandler = PermissionHandler();
    var permissionResult = await permissionHandler
        .requestPermissions([PermissionGroup.locationWhenInUse]);

    switch (permissionResult[PermissionGroup.locationWhenInUse]) {
      case PermissionStatus.denied:
      case PermissionStatus.unknown:
        print('location permission denied');
        _showLocationDeniedDialog(permissionHandler);
        throw Error();
    }

    Position position = await Geolocator()
        .getCurrentPosition(desiredAccuracy: LocationAccuracy.low);
    _weatherBloc.dispatch(FetchWeather(
        longitude: position.longitude, latitude: position.latitude));
  }

  void _showLocationDeniedDialog(PermissionHandler permissionHandler) {
    showDialog(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: Colors.white,
            title: Text('Location is disabled :(',
                style: TextStyle(color: Colors.black)),
            actions: <Widget>[
              FlatButton(
                child: Text(
                  'Enable!',
                  style: TextStyle(color: Colors.green, fontSize: 16),
                ),
                onPressed: () {
                  permissionHandler.openAppSettings();
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        });
  }
}
