import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:background_location/background_location.dart';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:hive/hive.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share/share.dart';
import 'package:signalr_core/signalr_core.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:http/http.dart' as http;
import 'package:trackar/Services/imeiServiceService.dart';
import 'package:trackar/Services/vehicleService.dart';
import 'package:trackar/models/logMessage.dart';
import 'package:trackar/models/utility.dart';
import 'models/configuration.dart';
import 'models/otpSubmitDto.dart';
import 'models/positionDto.dart';
import 'models/slotResponseDto.dart';
import 'models/vehicle.dart';

void main() => {
    HttpOverrides.global = new MyHttpOverrides(),

  runApp(MyApp())
  };

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

class _MyAppState extends State<MyApp> {
  String signalRConnected = "";
  String displayMessage = "";

  int vehicleIdInput = 0;
  int otpInput = 0;
  String formErrorMessage = "";

  bool getCsv = false;
  bool generatingCsv = false;

  int locationDbSize = 0;

  late Box vehicleDataBox;
  late Box vehicleBox;
  late Box configBox;
  late Box loggerBox;

  bool isLoggerBoxInitialized = false;

  late HubConnection hubConnection;

  bool initiallyCommunicated = false;

  bool isVehicleLinked = false;

  bool showLinkVeicleForm = false;

  //late int vehicleId;

  var logger = Logger(
    filter: null, // Use the default LogFilter (-> only log in debug mode)
    printer: PrettyPrinter(
        methodCount: 2, // number of method calls to be displayed
        errorMethodCount: 8, // number of method calls if stacktrace is provided
        lineLength: 120, // width of the output
        colors: true, // Colorful log messages
        printEmojis: true, // Print an emoji for each log message
        printTime: false // Should each log print contain a timestamp
        ), // Use the PrettyPrinter to format and print log
    output: null, // Use the default LogOutput (-> send everything to console)
  );

  @override
  void initState() {
    super.initState();
    openBox();
    check();
  }

  void check() {
    connectToSignalRServer();
  }

  DateTime lastLocation = new DateTime(2001);
  int lastTimeStamp = 0;
  bool isOnline = false;
  bool isSendingSlot = false;

  Future openBox() async {
    var directory = await path_provider.getApplicationDocumentsDirectory();

    Hive.init(directory.path);

    vehicleDataBox = await Hive.openBox(Utility.vehicleDataBox);
    vehicleBox = await Hive.openBox(Utility.vehicleBox);
    configBox = await Hive.openBox(Utility.configBox);
    loggerBox = await Hive.openBox(Utility.loggerBox);

    isLoggerBoxInitialized = true;

    addInfoLog("All Boxes Initialised App Started ");

    setData();

    return;
  }

  //late Vehicle vehicleObj;
  bool isVehicleLoaded = false;

  void setData() async {
    
    var locDbCount = GetListCount();
    print(locDbCount);
    addInfoLog("Db Count" + locDbCount.toString());

    setState(() {
      locationDbSize = locDbCount;
    });
    var vehicleString = vehicleBox.get(Utility.vehicle);

    if (vehicleString == null) {
      // logger.i("Vehicle Not Linked ");

      setState(() {
        isVehicleLinked = false;
      });
      addInfoLog("is Vehicle Linked" + isVehicleLinked.toString());
    } else {
      var vehicle =
          Vehicle.fromJson(jsonDecode(vehicleBox.get(Utility.vehicle)));

      addInfoLog(
          "Registered Vehicle" + vehicleBox.get(Utility.vehicle).toString());

      // logger.i("Vehicle Info");
      //  vehicleId = vehicle.id;
      logger.i(vehicle.id.toString() +
          " " +
          vehicle.name +
          " " +
          vehicle.photoUrl +
          " " +
          vehicle.registeredNumber);
      // vehicleObj = vehicle;

      isVehicleLinked = true;
      setState(() {
        isVehicleLinked = true;
      });

      addInfoLog("Vehicle Linked" + isVehicleLinked.toString());
    }

    addInfoLog("Checking if Config is Set");

    if (configBox.get(Utility.configInterval) == null ||
        configBox.get(Utility.configSlotSize) == null ||
        configBox.get(Utility.configVersion) == null) {
      addInfoLog("Config Not Set Setting Default Values");

      configBox.put(Utility.configVersion, Utility.defaultConfigVersion);
      configBox.put(Utility.configSlotSize, Utility.defaultSlotSize);
      configBox.put(Utility.configInterval, Utility.defaultInterval);
    }

    addInfoLog("Config  Values:" +
        "Interval: " +
        configBox.get(Utility.configInterval).toString() +
        " SlotSize: " +
        configBox.get(Utility.configSlotSize).toString() +
        " version: " +
        configBox.get(Utility.configVersion).toString());

    if (vehicleBox.get(Utility.imeiCode) == null) {
      var imeiCode = await imeiService.getImeiCode();
      vehicleBox.put(Utility.imeiCode, imeiCode);
    }

    addInfoLog("Imei Values" + vehicleBox.get(Utility.imeiCode).toString());

    if (isVehicleLinked == false) {
      setState(() {
        showLinkVeicleForm = true;
      });
    }

    setState(() {
      isVehicleLoaded = true;
    });

    addInfoLog("Vehicle Linked" + vehicleBox.get(Utility.imeiCode).toString());
  }

  void addInfoLog(String message) {
    if (isLoggerBoxInitialized == false) {
      return;
    }

    if (loggerBox.length >= 80000) {
      loggerBox.clear();
    }
    var log = LogMessage(Utility.logMessageTypeInfo, DateTime.now(), message);
    var logString = log.toJson();
    loggerBox.add(logString);
  }

  void addErrorLog(String message) {
    if (isLoggerBoxInitialized == false) {
      return;
    }

    if (loggerBox.length >= 80000) {
      loggerBox.clear();
    }
    var log = LogMessage(Utility.logMessageTypeError, DateTime.now(), message);
    //print(log.toJson());
    // print(log.datetimeStamp);
    // print(log.message);
    // print(log.messagetype);
    // var f= LogMessage.fromJson(log.toJson());
    // print("Converted object ");
    // print("csd");
    // print(f.toJson());
    var logString = log.toJson();
    loggerBox.add(logString);
  }

  //  void addLog(String messageType, String message) {
  //   var log = LogMessage(messageType, DateTime.now(), message);

  //   var logString = log.toJson();
  //   loggerBox.add(logString);
  // }

  bool isFirstEntry = true;
  late PositionDto lastPostion;

  PositionDto rectifyLocation(PositionDto positionDto, double speed) {
    addInfoLog("Rectifying Location");

    if (!isFirstEntry) {
      addInfoLog("not First Entry So Rectfying Location");
      addInfoLog("Position:" + positionDto.toString());

// Error  Prone  area  Here //
      double rectifiedLat =
          double.parse((positionDto.latitude).toStringAsFixed(4));
      double rectifiedLon =
          double.parse((positionDto.longitude).toStringAsFixed(4));
      double rectifiedLastLat =
          double.parse((positionDto.latitude).toStringAsFixed(4));
      double rectifiedLastLon =
          double.parse((positionDto.longitude).toStringAsFixed(4));

      addInfoLog("Position:" + positionDto.toString());
      addInfoLog("rectifiedLat:" +
          rectifiedLat.toString() +
          " rectifiedLon:" +
          rectifiedLon.toString() +
          " rectifiedLastLat:" +
          rectifiedLastLat.toString() +
          " rectifiedLastLon:" +
          rectifiedLastLon.toString());

      if (rectifiedLastLon == rectifiedLon &&
          rectifiedLastLat == rectifiedLat &&
          double.parse(speed.toStringAsFixed(2)) <= 0.99) {
        positionDto.latitude = lastPostion.latitude;
        positionDto.longitude = lastPostion.longitude;
      }
    }

    isFirstEntry = false;
    lastPostion = positionDto;

    addInfoLog("last Position:" + lastPostion.toString());

    return positionDto;
  }

  int getConfigVersion() {
    var configvrs = configBox.get(Utility.configVersion);

    addInfoLog("get Config Version:" + configvrs.toString());

    return configvrs;
  }

  void setConfig(Configuration config) {
    configBox.put(Utility.configVersion, config.id);
    configBox.put(Utility.configInterval, config.interval);
    configBox.put(Utility.configSlotSize, config.slotSize);

    addInfoLog("Setting Config :" +
        " version:" +
        configBox.get(Utility.configVersion).toString() +
        " interval" +
        configBox.get(Utility.configInterval).toString() +
        " slot Size:" +
        configBox.get(Utility.configSlotSize).toString());
  }

  int getInterval() {
    var interval = configBox.get(Utility.configInterval);
    addInfoLog("getting interval " + interval.toString());

    return interval;
  }

  int getSlotSize() {
    var slotSize = configBox.get(Utility.configSlotSize);
    addInfoLog("getting slot Size " + slotSize.toString());

    return slotSize;
  }

  int getVehicleId() {
    var vehicleId = vehicleBox.get(Utility.vehicleId);
    addInfoLog("getting vehicleId  " + vehicleId.toString());

    return vehicleId;
  }

  Vehicle getVehicle() {
    var vehicle = Vehicle.fromJson(jsonDecode(vehicleBox.get(Utility.vehicle)));
    addInfoLog("getting slot Size " +
        jsonDecode(vehicleBox.get(Utility.vehicle)).toString());

    return vehicle;
  }

  String getSavedImeiCode() {
    var imeiCode = vehicleBox.get(Utility.imeiCode);
    addInfoLog("getting imeiCode " + imeiCode.toString());

    logger.i("Imei Code" + imeiCode);

    return imeiCode;
  }

  void updateConfig() {
    addInfoLog("Updating Config  Sending Request");

    late Configuration configuration;

    http
        .get(Uri.parse(Utility.baseUrl +
            "User/Home/GetConfiguration?vehicleId=" +
            getVehicleId().toString()))
        .then((res) => {
              {
                addInfoLog("getted Config request Body" +
                    "res Status Code: " +
                    res.statusCode.toString() +
                    " body:" +
                    res.body.toString()),
                logger.i(res.body),
                if (res.statusCode == 200)
                  {
                    configuration =
                        Configuration.fromJson(jsonDecode(res.body)),
                    setConfig(configuration),
                  },
              }
            });
  }

  void checkConfigVersion(object) {
    addInfoLog("Checking Config Version ");

    try {
      var slotResponseDto = SlotResponseDto.fromJson(jsonDecode(object.body));

      logger.i(slotResponseDto.toString());

      if (slotResponseDto.updateconfig == true) {
        addInfoLog("Updating Config It is Required ");

        updateConfig();
      }
    } catch (e) {
      addErrorLog("Error in Checking The ConfigVersion");
    }
  }

  void checkConnectionStatus() async {
    addInfoLog("Checking Internet Status ");

    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        logger.i('connected');

        setState(() {
          isOnline = true;
        });
        addInfoLog(" Internet Status is Online");
      }
    } on SocketException catch (_) {
      logger.e('not connected');

      setState(() {
        isOnline = false;
        isSendingSlot = false;
      });

      addInfoLog(" Is Online" + isOnline.toString());
      addInfoLog(" Is Sending Slot" + isSendingSlot.toString());
    }
  }

  void sendSlotOnline() {
    addInfoLog("Sending Slot Online");

    if (isSendingSlot) {
      logger.i("Is Sending Slot:" + isSendingSlot.toString());
      setState(() {
        displayMessage = "Cant Send Slot Now";
      });
      addInfoLog(displayMessage);

      return;
    }
    logger.i("Sending Slot Online");

    addInfoLog("Sending Slot Online");

    setState(() {
      displayMessage = "Sending Slot Online";
    });

    addInfoLog(displayMessage);

    var posDtos = GetListOfPositionDto();
    // logger.i(posDtos);
    setState(() {
      locationDbSize = posDtos.length;
    });

    addInfoLog("location DbSize" + locationDbSize.toString());

    if (posDtos.length >= getSlotSize()) {
      posDtos = posDtos.sublist(0, getSlotSize() - 1);
      var body2 = json.encode(posDtos);
      // logger.i(body2);
      isSendingSlot = true;
      // logger.i("Is Sending Slot:" + isSendingSlot.toString());

      setState(() {
        isSendingSlot = true;
      });
      addInfoLog("IS Sendng Slot" + isSendingSlot.toString());

      try {
        http
            .post(
                Uri.parse(Utility.baseUrl +
                    'api/VehicleHistoryApi/AddLocationHistoryv2'),
                headers: <String, String>{
                  'Content-Type': 'application/json; charset=UTF-8',
                  'vid': getVehicleId().toString(),
                  'imeicode': getSavedImeiCode(),
                  'configid': getConfigVersion().toString()
                },
                body: body2)
            .then((res) => {
                  addInfoLog(" Slot Sendng Response" +
                      res.statusCode.toString() +
                      " " +
                      res.body.toString()),
                  logger.i("Status Code :" +
                      res.statusCode.toString() +
                      " Request Url:" +
                      res.request.toString() +
                      " Request Body :" +
                      res.body),
                  if (res.statusCode == 200)
                    {
                      logger.i(
                          "~~~~~~~~~~~~~~~~~~checking Config~~~~~~~~~~~~~~~~~~~~"),
                      addInfoLog(" Checkng if Config Update REquired"),
                      checkConfigVersion(res),
                      for (int i = 0; i < getSlotSize() - 1; i++)
                        {
                          logger.v("Deleting At" + i.toString()),
                          vehicleDataBox.deleteAt(0)
                        },
                      isSendingSlot = false,
                      logger.i("Is Sending Slot:" + isSendingSlot.toString()),
                      setState(() {
                        isSendingSlot = false;
                      }),
                      addInfoLog("IS sending Slot" + isSendingSlot.toString()),
                    }
                  else
                    {
                      logger.e("Cant Send The Location Slot Error Occured" +
                          res.toString()),
                      setState(() {
                        isSendingSlot = false;
                      }),
                      addErrorLog("Error in  Sending Slot "),
                      addInfoLog("IS sending Slot" + isSendingSlot.toString()),
                    }
                });
      } catch (e) {
        isSendingSlot = false;

        setState(() {
          isSendingSlot = false;
        });

        logger.e("Cant Send The Location Slot Error Occured");
        addInfoLog("Cant Send The Location Slot Error Occured");
      }

      //  print(uriResponse.statusCode);
    }
  }

  int GetListCount() {
    var length = vehicleDataBox.length;
    addInfoLog("Get List Count" + length.toString());
    return length;
  }

  List<PositionDto> GetListOfPositionDto() {
    addInfoLog("Get List of Positon Dto");

    var length = vehicleDataBox.length;
    //  logger.i(length);
    //final body = json.decode(box.getAt(0));
    List<PositionDto> locationDtos = <PositionDto>[];
    for (int i = 0; i < length; i++) {
      final positionDto =
          PositionDto.fromJson(jsonDecode(vehicleDataBox.getAt(i)));

      locationDtos.add(positionDto);
    }

    return locationDtos;
  }

  void CreateListofLocations() {
    addInfoLog("CreatingList of Locations");

    var length = vehicleDataBox.length;
    // logger.i("List Length" + length.toString());
    //final body = json.decode(box.getAt(0));
    List<PositionDto> locationDtos = <PositionDto>[];
    for (int i = 0; i < length; i++) {
      final positionDto =
          PositionDto.fromJson(jsonDecode(vehicleDataBox.getAt(i)));

      locationDtos.add(positionDto);
    }

    // logger.i(locationDtos);
  }

  Future<void> connectToSignalRServer() async {
    addInfoLog("Connecting TO Signal R Server ");

    checkConnectionStatus();

    if (isOnline) {
      setState(() {
        displayMessage = " Trying Connecting To Signal R Server";
      });

      addInfoLog(" online and Connecting TO Signal R Server ");

      logger.i("Connecting to Signal R Server");
      final serverUrl = Utility.baseUrl + "LiveLocation";
      final lHubConnection = HubConnectionBuilder().withUrl(serverUrl).build();
      lHubConnection.onclose((error) => logger.i("Connection Closed"));
      try {
        setState(() {
          displayMessage = "Getting Connected in Try Block";
        });
        addInfoLog(displayMessage.toString());

        await lHubConnection.start();
        setState(() {
          displayMessage =
              "Signal R Connection State" + lHubConnection.state.toString();
        });
        addInfoLog(displayMessage.toString());
      } catch (e) {
        setState(() {
          displayMessage = "Failed To Connect To Signal R Server ";
        });

        addErrorLog(displayMessage.toString());
      }
      hubConnection = lHubConnection;
      initiallyCommunicated = true;
      addInfoLog(initiallyCommunicated.toString());
    }
  }

  Future<void> saveAndShareLocation(Position position) async {
    checkConnectionStatus();

    setState(() {
      displayMessage = "Saving And Sharing LOcation";
    });
    addInfoLog(displayMessage);

    logger.i("isOnline:" + isOnline.toString());

    var locDbCount = GetListCount();
    //(locDbCount);
    setState(() {
      locationDbSize = locDbCount;
    });

    if (initiallyCommunicated) {
    } else {
      if (isOnline) {
        await connectToSignalRServer();
      }
    }

    try {
      //  logger.i("Sharing Location");
      //   box.put(position.timestamp.toString(), position.latitude);

      var timestmp =
          (position.timestamp!.millisecondsSinceEpoch.toInt() / 1000).toInt();

      if (lastTimeStamp == timestmp) {
        return;
      }

      logger.i("Time Interval" + timestmp.toString());

      addInfoLog("Time Interval" + timestmp.toString());

      addInfoLog("comparing Timestamp " +
          "timeStamp:" +
          timestmp.toString() +
          " lastTimeStamp:" +
          lastTimeStamp.toString());

      logger.i("comparing Timestamp " +
          "timeStamp:" +
          timestmp.toString() +
          " lastTimeStamp:" +
          lastTimeStamp.toString());

      if ((timestmp - lastTimeStamp) < getInterval() && lastTimeStamp != 0) {
        logger.i("rejecting it ");

        addInfoLog("Rejecting it  ");

        logger.i("last timeStamp:" +
            lastTimeStamp.toString() +
            " " +
            " timeStamp:" +
            timestmp.toString() +
            " Difference" +
            (timestmp - lastTimeStamp).toString());

        addInfoLog("last timeStamp:" +
            lastTimeStamp.toString() +
            " " +
            " timeStamp:" +
            timestmp.toString() +
            " Difference" +
            (timestmp - lastTimeStamp).toString());

        return;
      } else {
        logger.i("accepted It " +
            "last timeStamp:" +
            lastTimeStamp.toString() +
            " " +
            " timeStamp:" +
            timestmp.toString() +
            " Difference" +
            (timestmp - lastTimeStamp).toString());

        addInfoLog("accepted It " +
            "last timeStamp:" +
            lastTimeStamp.toString() +
            " " +
            " timeStamp:" +
            timestmp.toString() +
            " Difference" +
            (timestmp - lastTimeStamp).toString());
      }

      lastTimeStamp = timestmp;

      addInfoLog("last timeStamp:" + lastTimeStamp.toString());

      PositionDto positionDto = new PositionDto(position.latitude,
          position.longitude, position.speed.floor(), timestmp);

      String positionDtoString = jsonEncode(positionDto);
      logger.i("Here is The String" + positionDtoString);

      addInfoLog("adding Data To Vehicle Data Box");

      vehicleDataBox.add(positionDtoString);

      if (isOnline) {
        logger.i("Online Sharing Online Data");
        addInfoLog("Send Slot Online");

        sendSlotOnline();
        if (initiallyCommunicated == true) {
          if (hubConnection.state == HubConnectionState.disconnected) {
            connectToSignalRServer();
          }
          if (hubConnection.state == HubConnectionState.connected) {
            setState(() {
              displayMessage = "Sharing  Live Location";
            });
            addInfoLog(displayMessage);
            addInfoLog("Sharing LOcation TO Signal Server");

            hubConnection.invoke("SendLiveLocationV2", args: <Object>[
              position.latitude,
              position.longitude,
              getVehicleId(),
              position.timestamp!.millisecondsSinceEpoch,
              position.speed.floor()
            ]);
          }
        } else {
          connectToSignalRServer();
        }
      } else {
        logger.i("Offline Cant Share  Data");
      }
    } catch (e) {
      logger.e(e);
    }
  }

  void generateCsv() async {
    Directory documentDirectory = await getApplicationDocumentsDirectory();
    String documentPath = documentDirectory.path;
    File file = File("$documentPath/example.csv");

// bool getCsv=false;
// bool generatingCsv=false;
    // var f= LogMessage.fromJson(log.toJson());

    setState(() {
      getCsv = true;
      generatingCsv = true;
    });

    List<List<dynamic>> rows = <List<dynamic>>[];
    // Header
    List<dynamic> row = [];
    row.add("Log Type");
    row.add("Log TimeStamp");
    row.add("Message Message");

    rows.add(row);

    for (int i = 0; i < loggerBox.length; i++) {
      List<dynamic> row = [];

      var loggerObj = LogMessage.fromJson(loggerBox.get(i));

      row.add(loggerObj.messagetype);
      row.add(loggerObj.datetimeStamp);
      row.add(loggerObj.message);

      rows.add(row);
    }

//List<List<dynamic>> rowsAsListOfValues = const CsvToListConverter().convert("ddddw,dwdwd,wdwd,wdwd");

    String csv = const ListToCsvConverter().convert(rows);

    await file.writeAsString(csv);

    setState(() {
      getCsv = false;
      generatingCsv = false;
    });

    Share.shareFiles(
        ['${documentPath}/example.csv', '${documentPath}/example.csv']);
  }

  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        primarySwatch: Colors.blue,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: Center(child: Text("Location Tracker Client")),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Center(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(20)),
                                color: HexColor("#39A9CB"),
                              ),
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    showLinkVeicleForm = !showLinkVeicleForm;
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Row(
                                    children: [Icon(Icons.settings_rounded)],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        showLinkVeicleForm
                            ? Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Padding(
                                        padding: const EdgeInsets.all(12.0),
                                        child: Text(
                                          "Link Device",
                                          style: TextStyle(fontSize: 24),
                                        ),
                                      ),
                                      SizedBox(
                                        height: 14,
                                      ),
                                      TextFormField(
                                        keyboardType: TextInputType.number,
                                        onChanged: (val) {
                                          vehicleIdInput = int.parse(val);
                                        },
                                        textAlign: TextAlign.center,

                                        decoration: InputDecoration(
                                          filled: true,
                                          hintText: "Vehicle Id",
                                          fillColor: HexColor("#DDDDDD"),
                                          border: OutlineInputBorder(
                                              borderSide: BorderSide.none,
                                              borderRadius:
                                                  BorderRadius.circular(50)),
                                        ),
                                        // The validator receives the text that the user has entered.
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Please enter Vehicle Id';
                                          }
                                          return null;
                                        },
                                      ),
                                      SizedBox(
                                        height: 14,
                                      ),
                                      TextFormField(
                                        textAlign: TextAlign.center,
                                        keyboardType: TextInputType.number,

                                        onChanged: (val) {
                                          otpInput = int.parse(val);
                                        },
                                        decoration: InputDecoration(
                                          filled: true,
                                          hintText: "OTP",
                                          fillColor: HexColor("#DDDDDD"),
                                          border: OutlineInputBorder(
                                              borderSide: BorderSide.none,
                                              borderRadius:
                                                  BorderRadius.circular(50)),
                                        ),
                                        // The validator receives the text that the user has entered.
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Please enter Otp';
                                          }
                                          return null;
                                        },
                                      ),
                                      SizedBox(
                                        height: 14,
                                      ),
                                      Center(
                                          child: Text(
                                        formErrorMessage,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.red,
                                        ),
                                        textAlign: TextAlign.center,
                                      )),
                                      SizedBox(
                                        height: 14,
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16.0),
                                        child: Center(
                                          child: ElevatedButton(
                                            onPressed: () async {
                                              setState(() {
                                                formErrorMessage = "";
                                              });

                                              if (_formKey.currentState!
                                                  .validate()) {
                                                var otpSubmitDto =
                                                    new OtpSubmitDto(
                                                        vehicleIdInput,
                                                        otpInput,
                                                        getSavedImeiCode());

                                                var res = await VehicleService
                                                    .linkVehicle(otpSubmitDto,
                                                        logger, vehicleBox);

                                                if (!res) {
                                                  setState(() {
                                                    formErrorMessage =
                                                        "Wrong Otp Or Vehicle Id";
                                                  });

                                              addErrorLog("Wrong Otp ");

                                                } else {
                                                  setState(() {
                                                    isVehicleLinked = true;
                                                    showLinkVeicleForm = false;
                                                  });
                                                }
                                              }
                                            },
                                            child: Text('Submit'),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : SizedBox(
                                height: 8,
                              ),
                        ElevatedButton(
                            onPressed: isVehicleLoaded == true &&
                                    isVehicleLinked == true
                                ? () async {
                                    await BackgroundLocation
                                        .setAndroidNotification(
                                      title: 'Background service is running',
                                      message:
                                          'Background location in progress',
                                      icon: '@mipmap/ic_launcher',
                                    );
                                    //await BackgroundLocation.setAndroidConfiguration(1000);

                                    addInfoLog("Start BackGround Service");

                                    await BackgroundLocation
                                        .startLocationService(
                                            distanceFilter: 0.0);
                                    BackgroundLocation.getLocationUpdates(
                                        (location) {
                                      addInfoLog(" Get Location Update");

                                      double latitude =
                                          location.latitude!.toDouble();
                                      double longitude =
                                          location.longitude!.toDouble();
                                      double altitude =
                                          location.altitude!.toDouble();
                                      double accuracy =
                                          location.accuracy!.toDouble();
                                      double bearing =
                                          location.bearing!.toDouble();
                                      double speed = location.speed!.toDouble();
                                      DateTime timeStamp =
                                          DateTime.fromMillisecondsSinceEpoch(
                                              location.time!.toInt());

                                      var position = new Position(
                                          accuracy: 0,
                                          altitude: 0,
                                          heading: 0,
                                          latitude: latitude,
                                          longitude: longitude,
                                          speed: speed,
                                          speedAccuracy: 0,
                                          timestamp: timeStamp);

                                      logger.i(
                                          "timeStamp" + timeStamp.toString());

                                      addInfoLog(timeStamp.toString());

                                      var positionDto = new PositionDto(
                                          location.latitude!.toDouble(),
                                          location.longitude!.toDouble(),
                                          location.speed!.toInt(),
                                          location.time!.toInt());

                                      addInfoLog("Latitude :" +
                                          positionDto.latitude.toString() +
                                          " longitude:" +
                                          positionDto.longitude.toString() +
                                          " Speed: " +
                                          positionDto.speed.toString() +
                                          " time Stamp : " +
                                          positionDto.timeStamp.toString());

                                      var rectifiedPosition = rectifyLocation(
                                          positionDto,
                                          location.speed!.toDouble());

                                      logger.i(
                                          "----@@@@@@@@ rectified Position @@@@@@@@----" +
                                              rectifiedPosition
                                                  .toJson()
                                                  .toString());

                                      addInfoLog("Rectified Position" +
                                          rectifiedPosition
                                              .toJson()
                                              .toString());

                                      var position1 = new Position(
                                          accuracy: 0,
                                          altitude: 0,
                                          heading: 0,
                                          latitude: rectifiedPosition.latitude,
                                          longitude:
                                              rectifiedPosition.longitude,
                                          speed: speed,
                                          speedAccuracy: 0,
                                          timestamp: timeStamp);

                                      addInfoLog("Sharing Location");

                                      saveAndShareLocation(position1);
                                    });
                                  }
                                : null,
                            child: isVehicleLoaded == true
                                ? ((isVehicleLinked)
                                    ? Text("Start Service")
                                    : Text(
                                        "First Link The Vehicle To Start The Service"))
                                : Text("Loading")),
                        ElevatedButton(
                            onPressed: () {
                              //      addI(Utility.logMessageTypeInfo, "Test Log");
                              generateCsv();
                            },
                            child: Text("Temp Button")),
                        ElevatedButton(
                            onPressed: () {
                              BackgroundLocation.stopLocationService();
                            },
                            style: ButtonStyle(),
                            child: Text('Stop Location Service')),
                        Padding(
                          padding: const EdgeInsets.only(left: 12, right: 12),
                          child: Divider(
                            height: 12,
                            thickness: 2,
                            color: Colors.lightBlueAccent,
                          ),
                        ),
                        // Container(
                        //   child: Center(
                        //       child: Text(
                        //     'LocationDbSize:' + locationDbSize.toString(),
                        //     style:
                        //         TextStyle(fontSize: 24, color: Colors.black54),
                        //   )),
                        //   width: double.infinity,
                        //   color: Colors.white,
                        //   padding: EdgeInsets.all(12),
                        //   margin: EdgeInsets.all(12),
                        // ),
                        // Container(
                        //   child: Center(
                        //       child: Text(
                        //     'Message:' + displayMessage,
                        //     style:
                        //         TextStyle(fontSize: 24, color: Colors.black54),
                        //   )),
                        //   width: double.infinity,
                        //   color: Colors.white,
                        //   padding: EdgeInsets.all(12),
                        //   margin: EdgeInsets.all(12),
                        // ),
                        // Container(
                        //   child: Center(
                        //       child: Text(
                        //     'Is Sending Slot :' + isSendingSlot.toString(),
                        //     style:
                        //         TextStyle(fontSize: 24, color: Colors.black54),
                        //   )),
                        //   width: double.infinity,
                        //   color: Colors.white,
                        //   padding: EdgeInsets.all(12),
                        //   margin: EdgeInsets.all(12),
                        // ),
                        // Container(
                        //   child: Center(
                        //       child: Text(
                        //     'Is Online :' + isOnline.toString(),
                        //     style:
                        //         TextStyle(fontSize: 24, color: Colors.black54),
                        //   )),
                        //   width: double.infinity,
                        //   color: Colors.white,
                        //   padding: EdgeInsets.all(12),
                        //   margin: EdgeInsets.all(12),
                        // ),
                        // isVehicleLinked
                        //     ? Container(
                        //         child: Center(
                        //             child: Text(
                        //           'Config Version :' +
                        //               getConfigVersion().toString(),
                        //           style: TextStyle(
                        //               fontSize: 24, color: Colors.black54),
                        //         )),
                        //         width: double.infinity,
                        //         color: Colors.white,
                        //         padding: EdgeInsets.all(12),
                        //         margin: EdgeInsets.all(12),
                        //       )
                        //     : SizedBox(
                        //         height: 1,
                        //       ),
                        // isVehicleLinked
                        //     ? Container(
                        //         child: Center(
                        //             child: Text(
                        //           'Vehicle :' +
                        //               getVehicle().toJson().toString(),
                        //           style: TextStyle(
                        //               fontSize: 24, color: Colors.black54),
                        //         )),
                        //         width: double.infinity,
                        //         color: Colors.white,
                        //         padding: EdgeInsets.all(12),
                        //         margin: EdgeInsets.all(12),
                        //       )
                        //     : SizedBox(
                        //         height: 1,
                        //       ),
                        isVehicleLinked
                            ? Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(14.0),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.all(
                                            Radius.circular(20)),
                                        color: HexColor("#39A9CB"),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Column(
                                          children: [
                                            Text(
                                              "Vehicle Info",
                                              style: GoogleFonts.josefinSans(
                                                  color: Colors.white,
                                                  fontSize: 25,
                                                  fontWeight: FontWeight.bold),
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                            ),
                                            SizedBox(
                                              height: 18,
                                            ),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  "Vehicle Id: " +
                                                      getVehicle()
                                                          .id
                                                          .toString(),
                                                  style: GoogleFonts.baumans(
                                                      fontSize: 20,
                                                      color: Colors.white),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                Flexible(
                                                    child: Text(
                                                      "Name: " +
                                                          getVehicle()
                                                              .name
                                                              .toString(),
                                                      style:
                                                          GoogleFonts.baumans(
                                                              fontSize: 20,
                                                              color:
                                                                  Colors.white),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    fit: FlexFit.loose)
                                              ],
                                            ),
                                            SizedBox(
                                              height: 18,
                                            ),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Flexible(
                                                    child: Text(
                                                      "Registration Number: " +
                                                          getVehicle()
                                                              .registeredNumber
                                                              .toString(),
                                                      style:
                                                          GoogleFonts.baumans(
                                                              fontSize: 20,
                                                              color:
                                                                  Colors.white),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      softWrap: false,
                                                    ),
                                                    fit: FlexFit.loose),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      height: 18,
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(14.0),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.all(
                                            Radius.circular(20)),
                                        color: HexColor("#39A9CB"),
                                      ),
                                      child: Column(
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.all(8.0),
                                              child: Text(
                                                "Current Status",
                                                style: GoogleFonts.josefinSans(
                                                    color: Colors.white,
                                                    fontSize: 25,
                                                    fontWeight:
                                                        FontWeight.bold),
                                                overflow: TextOverflow.ellipsis,
                                                softWrap: false,
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            'Message:' + displayMessage,
                                            style: GoogleFonts.baumans(
                                                fontSize: 20,
                                                color: Colors.white),
                                            overflow: TextOverflow.ellipsis,
                                            softWrap: false,
                                            textAlign: TextAlign.center,
                                          ),
                                          Text(
                                            'Is Sending Slot :' +
                                                isSendingSlot.toString(),
                                            style: GoogleFonts.baumans(
                                                fontSize: 20,
                                                color: Colors.white),
                                            overflow: TextOverflow.ellipsis,
                                            softWrap: false,
                                            textAlign: TextAlign.center,
                                          ),
                                          Text(
                                            'LocationDbSize:' +
                                                locationDbSize.toString(),
                                            style: GoogleFonts.baumans(
                                                fontSize: 20,
                                                color: Colors.white),
                                            overflow: TextOverflow.ellipsis,
                                            softWrap: false,
                                            textAlign: TextAlign.center,
                                          ),
                                          Text(
                                            'Is Online :' + isOnline.toString(),
                                            style: GoogleFonts.baumans(
                                                fontSize: 20,
                                                color: Colors.white),
                                            overflow: TextOverflow.ellipsis,
                                            softWrap: false,
                                            textAlign: TextAlign.center,
                                          ),
                                          SizedBox(
                                            height: 14,
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(
                                      height: 18,
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(14.0),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.all(
                                            Radius.circular(20)),
                                        color: HexColor("#39A9CB"),
                                      ),
                                      child: Column(
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.all(8.0),
                                              child: Text(
                                                "App Configuration",
                                                style: GoogleFonts.josefinSans(
                                                    color: Colors.white,
                                                    fontSize: 25,
                                                    fontWeight:
                                                        FontWeight.bold),
                                                overflow: TextOverflow.ellipsis,
                                                softWrap: false,
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            'Config Version:' +
                                                getConfigVersion().toString(),
                                            style: GoogleFonts.baumans(
                                                fontSize: 20,
                                                color: Colors.white),
                                            overflow: TextOverflow.ellipsis,
                                            softWrap: false,
                                            textAlign: TextAlign.center,
                                          ),
                                          Text(
                                            'Interval:' +
                                                getInterval().toString(),
                                            style: GoogleFonts.baumans(
                                                fontSize: 20,
                                                color: Colors.white),
                                            overflow: TextOverflow.ellipsis,
                                            softWrap: false,
                                            textAlign: TextAlign.center,
                                          ),
                                          Text(
                                            'Slot Size:' +
                                                getSlotSize().toString(),
                                            style: GoogleFonts.baumans(
                                                fontSize: 20,
                                                color: Colors.white),
                                            overflow: TextOverflow.ellipsis,
                                            softWrap: false,
                                            textAlign: TextAlign.center,
                                          ),

                                          SizedBox(
                                            height: 14,
                                          ),
                                          // Text("Config Version"+getConfigVersion().toString()),
                                          // Text("Interval"+getInterval().toString()),
                                          // Text("slot Size"+getSlotSize().toString()),
                                        ],
                                      ),
                                    )
                                  ],
                                ),
                              )
                            : SizedBox(
                                height: 1,
                              ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    BackgroundLocation.stopLocationService();
    // super.dispose();
  }
}
