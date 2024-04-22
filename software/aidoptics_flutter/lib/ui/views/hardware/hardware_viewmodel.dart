import 'dart:async';
import 'dart:io';

import 'package:aidoptics_flutter/services/ble_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
//main.dart
// import "dart:async";

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:perfect_volume_control/perfect_volume_control.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

// import 'package:vision/ui/setup_snackbar_ui.dart';

import '../../../app/app.locator.dart';
import '../../../app/app.logger.dart';
import '../../../services/imageprocessing_service.dart';
import '../../../services/regula_service.dart';
import '../../../services/tts_service.dart';

// import 'package:html/parser.dart' as parser;
// import 'package:html/dom.dart' as dom;

class HardwareViewModel extends ReactiveViewModel {
  final log = getLogger('HardwareViewModel');

  // final _bleService = locator<BleService>();
  final _snackBarService = locator<SnackbarService>();
  final TTSService _ttsService = locator<TTSService>();
  final ImageProcessingService _imageProcessingService =
      locator<ImageProcessingService>();

  // final _navigationService = locator<NavigationService>();
  final _ragulaService = locator<RegulaService>();

  // bool get isConnected => _bleService.isBleOn;
  // String get name => _bleService.deviceName;
  // String get status => _bleService.status;
  // BluetoothDevice? get device => _bleService.device;
  // String? get data => _bleService.data;
  // Future sendCommand(String command) async {
  //   log.i(command);
  //   // _bleService.writeCharacteristic("red_led");
  //   _bleService.writeCharacteristic(command);
  //   try {} catch (e) {
  //     log.e(e);
  //   }
  // }
  // @override
  // List<ListenableServiceMixin> get listenableServices => [_bleService];
  Timer? periodicTimer;

  bool _isTimer= false;
  bool get isTimer=>_isTimer;
  void startPeriodicTimer() {
    _isTimer = true;
    notifyListeners();
    periodicTimer =
        Timer.periodic(const Duration(milliseconds: 1000), (timer) async {
          if(!isTrigger) {
            getTrigger();
          }
        });
  }

  bool isTrigger = false;
  void getTrigger() async {
    // if(!isConnected || device == null) return;
    // sendCommand("getTrigger");
    // if (data != null && data!.isNotEmpty) {
    //   int isTrigger = int.parse(data!);
    //   log.i("isTrigger: $isTrigger");
    //   notifyListeners();
    //   // logger.i(distance);
    //   if (isTrigger==1) {
    //     workLabel();
    //   }
    // }

    log.i("Calling..");
    // _isCalled = true;

    Uri uri = Uri(scheme: 'http', host: ip!, path: 'trigger');

    try {
      http.Response response = await http.get(uri);
      log.i("Status Code: ${response.statusCode}");
      log.i("Content Length: ${response.contentLength}");
      log.i("Content Response: ${response.body}");
      int trigger = 0;

      if (response.statusCode == 200) {
        final data = response.body;
          log.i(data);
          trigger = int.parse(data);
          notifyListeners();
          if(trigger == 1){
            isTrigger = true;
            workLabel();
          }
      } else {
      }

      log.i("Triggfer data: $trigger");
    } catch (e) {
      log.e("Error: $e");
    }
  }

  void stopPeriodicTimer() {
    _isTimer = false;
    notifyListeners();
    periodicTimer?.cancel();
    periodicTimer = null;
  }

  File? _image;

  File? get imageSelected => _image;

  List<String> _labels = <String>[];

  List<String> get labels => _labels;

  String? _ip;

  String? get ip => _ip;

  void onModelReady() async {
    setBusy(true);
    log.i("Model ready");

    _ip = "192.168.29.224";
    setBusy(false);

    _subscription = PerfectVolumeControl.stream.listen((value) {
      if (_image != null && !isBusy) {
        log.i("Volume button got!");
        workLabel();
      }
    });
  }

  late StreamSubscription<double> _subscription;

  @override
  void dispose() {
    // call your function here
    stopPeriodicTimer();
    _subscription.cancel();
    super.dispose();
  }

  void workLabel() async {
    setBusy(true);
    await getImageFromHardware();
    // await getImageFromHardware();
    // await getImageFromHardware();

    if (_image != null) await getLabel();
  }


  void setIp(String ipIn){
    _ip = ipIn;
    log.i("set Ip called $ipIn");
    notifyListeners();
  }

  
  // getting labels 
  Future getLabel() async {
    log.i("Getting label");
    _labels = <String>[];

    _labels = await _imageProcessingService.getLabelFromImage(_image!);

    setBusy(false);

    String text = _imageProcessingService.processLabels(_labels);
    await _ttsService.speak(text);
    isTrigger = false;
    if (text == "Person detected") {
      await Future.delayed(const Duration(milliseconds: 2000));
      return processFace();
    }
  }

  void processFace() async {
    _ttsService.speak("Identifying person");
    setBusy(true);
    String? person = await _ragulaService.checkMatch(_image!.path);
    setBusy(false);
    if (person != null) {
      _labels.clear();
      _labels.add(person);
      notifyListeners();
      await _ttsService.speak(person);
      await Future.delayed(const Duration(milliseconds: 1500));
    } else {
      await _ttsService.speak("Not identified!");
      await Future.delayed(const Duration(milliseconds: 1500));
    }
    log.i("Person: $person");
  }
  //

  
  //*******Getting Texts*******

  // Future captureImageAndText() async {
  //   _image = await _camService.takePicture();
  //   getText();
  // }

  Future workText() async {
    setBusy(true);
    await getImageFromHardware();
    // await getImageFromHardware();
    // await getImageFromHardware();
    if (_image != null)  getText();
  }

   String? _text;

  String get text => _text.toString();

  void getText() async {
    setBusy(true);
    log.i("Getting Text");

   

    _text = await _imageProcessingService.getTextFromImage(_image!);
    isTrigger = false;
    setBusy(false);

    // _image != await _ttsService.speak(_texts);

    if (_image != null) {
      await _ttsService.speak(_text.toString());
    } else {
      await _ttsService.speak('Not Detected');
    }
  }

  //********//

  Uint8List? _img;

  Uint8List? get img => _img;

  // bool _isCalled = false;

  Future getImageFromHardware() async {
    log.i("Calling..");
    // _isCalled = true;

    Uri uri = Uri(scheme: 'http', host: ip!, path: 'image');

    try {
      http.Response response = await http.get(uri);
      log.i("Status Code: ${response.statusCode}");
      log.i("Content Length: ${response.contentLength}");
      // log.i("Content Length: ${response.body}");
      //;------------
      _img = response.bodyBytes;
      // log.i(_img);
      //
      if (_image != null) {
        _image!.delete();
      } else {
        final directory = await getApplicationDocumentsDirectory();
        _image = await File('${directory.path}/image.png').create();
      }
      return _image!.writeAsBytes(_img!);
    } catch (e) {
      log.i("Error: $e");
    }
  }

  double _distanceLeft = 0;
  double get distanceLeft => _distanceLeft;
  double _distanceRight = 0;
  double get distanceRight => _distanceRight;
  Future getUltrasonicDistanceFromHardware() async {
    // isTrigger = true;
    log.i("Calling..");
    // _isCalled = true;

    Uri uri = Uri(scheme: 'http', host: ip!, path: 'ultrasonic');

    try {
      http.Response response = await http.get(uri);
      log.i("Status Code: ${response.statusCode}");
      log.i("Content Length: ${response.contentLength}");
      // log.i("Content Length: ${response.body}");
      double distance1 = 0.0;
      double distance2 = 0.0;
      bool dataLoaded = false;

      if (response.statusCode == 200) {
        final data = response.body.split('\n');
        if (data.length >= 2) {
          log.i(data);
          distance1 = double.parse(data[0]);
          distance2 = double.parse(data[1]);
          dataLoaded = true;
          _distanceLeft = distance2;
          _distanceRight = distance1;
          notifyListeners();
        }
      } else {
        distance1 = 0.0;
        distance2 = 0.0;
        dataLoaded = false;
      }

      log.i("Distance data: $distance1 $distance2");
      // isTrigger = false;
    } catch (e) {
      log.e("Error: $e");
    }
  }

  bool _isDistanceTimer = false;
  bool get isDistanceTimer => _isDistanceTimer;
  bool _isLeftObstacle = false;
  bool get isLeftObstacle => _isLeftObstacle;
  bool _isRightObstacle = false;
  bool get isRightObstacle => _isRightObstacle;
  void getObstacles() async {
    // _isDistanceTimer = !_isDistanceTimer;
    notifyListeners();
    await getUltrasonicDistanceFromHardware();
    if (distanceLeft < 50) {
      await _ttsService.speak("Obstacle from left side");
      _isLeftObstacle = true;
    } else {
      _isLeftObstacle = false;
    }
    if (distanceRight < 50) {
      await _ttsService.speak("Obstacle from right side");
      _isRightObstacle = true;
    } else {
      _isRightObstacle = false;
    }
    notifyListeners();
  }
}
