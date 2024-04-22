import 'dart:io';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

import '../app/app.dialogs.dart';
import '../app/app.locator.dart';
import '../app/app.logger.dart';

class BleService with ListenableServiceMixin {
  final log = getLogger('BleService');
  final _dialogService = locator<DialogService>();

  String _status = "";
  String get status => _status;

  Future<bool> isBluetoothSupported() async {
    return await FlutterBluePlus.isSupported;
  }

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  bool _isBleOn = false;
  bool get isBleOn => _isBleOn;
  late var adapterStatusSubscription;
  String deviceName = "";
  void init({required String name}) async {
    deviceName = name;
    await _checkIsBluetoothOn();
    adapterStatusSubscription =
        FlutterBluePlus.adapterState.listen((BluetoothAdapterState state) {
          log.i(state);
          if (state == BluetoothAdapterState.on) {
            _isBleOn = true;
            _status = "Bluetooth is on";
            notifyListeners();
          } else {
            _isBleOn = false;
            _status = "Bluetooth is off";
            notifyListeners();
          }
        });

    //device status
    deviceConnectionStatusListen();
  }

  void deviceConnectionStatusListen() {
    // listen to *any device* connection state changes
    FlutterBluePlus.events.onConnectionStateChanged.listen((event) async {
      log.i('${event.device} ${event.connectionState}');
      if (event.connectionState == BluetoothConnectionState.connected) {
        if (event.device.advName == deviceName) {
          _status = "Device connection established";
          log.i("Device connection established");
          _device = event.device;
          log.i(_device!.mtuNow);
          discoverServices();
          notifyListeners();
          await Future.delayed(const Duration(seconds: 2));
        }
      } else if (event.connectionState ==
          BluetoothConnectionState.disconnected) {
        if (event.device.advName == deviceName) {
          _status = "Disconnected from $deviceName";
          log.i("Disconnected from $deviceName");
          _device = null;
          notifyListeners();
          notifyListeners();
        }
      }
    });
  }

  void dispose() {
    log.i("Dispose");
    adapterStatusSubscription.cancel();
  }

  Future<bool> _checkIsBluetoothOn() async {
    final state = await FlutterBluePlus.adapterState.first;
    _isBleOn = state == BluetoothAdapterState.on;
    log.i("Bluetooth on: $_isBleOn");
    if (!_isBleOn) await turnOnBluetooth();
    if (_isBleOn) scanForDevices();
    return _isBleOn;
  }

  Future turnOnBluetooth() async {
    if (Platform.isAndroid) {
      await FlutterBluePlus.turnOn();
    }
  }

  BluetoothDevice? _deviceFound;
  BluetoothDevice? get deviceFound => _deviceFound;
  Future scanForDevices() async {
    if (FlutterBluePlus.isScanningNow) {
      log.e("already scanning");
      _status = "Already scanning..";
      notifyListeners();
      return;
    }

    _status = "Scanning..";
    var subscription = FlutterBluePlus.onScanResults.listen(
          (results) async {
        if (results.isNotEmpty) {
          ScanResult r = results.last; // the most recently found device
          log.i(
              '${r.device.remoteId}: "${r.advertisementData.advName}" found!');
          if (r.advertisementData.advName == deviceName) {
            _deviceFound = r.device;
            _status = "$deviceName found!, Connecting..";
            notifyListeners();
            // DialogResponse? re = await _dialogService.showCustomDialog(
            //   variant: DialogType.infoAlert,
            //   title: "Device found",
            //   description: '$deviceName is found click ok to connect to your Robot',
            // );
            // if(re!=null && re.confirmed){
            //   log.i("Connecting to device");
            // }
            connectToDevice();
          } else {
            _status = "$deviceName not found! Please turn on device";
            notifyListeners();
          }
        } else {
          _status = "No BLE device found";
          notifyListeners();
        }
      },
      onError: (e) {
        _status = "Error scanning.";
        notifyListeners();
        log.e(e);
      },
    );

    // cleanup: cancel subscription when scanning stops
    FlutterBluePlus.cancelWhenScanComplete(subscription);

    await FlutterBluePlus.startScan(
      withNames: [deviceName],
      timeout: const Duration(seconds: 15),
    );

    bool isScanningFinish =
    await FlutterBluePlus.isScanning.where((val) => val == false).first;
    if (isScanningFinish) {
      _status = "Scanning finished";
      notifyListeners();
    }
  }

  BluetoothDevice? _device;
  BluetoothDevice? get device => _device;
  Future connectToDevice() async {
    if (_deviceFound != null || !_deviceFound!.isConnected) {
      _status = "Connecting to $deviceName..";
      notifyListeners();
      // You can also manually change the mtu yourself.
      await _deviceFound!.connect(autoConnect: true, mtu: null);
    }
  }

  String? _data;
  String? get data => _data;
  BluetoothCharacteristic? _writeCharacteristic;
  Future<List<BluetoothService>> discoverServices() async {
    log.i("Getting services..");
    _status = "Discovering services..";
    notifyListeners();
    // Note: You must call discoverServices after every re-connection!
    List<BluetoothService> services = await device!.discoverServices();
    services.forEach((service) async {
      if (service.serviceUuid.toString() ==
          "6e400001-b5a3-f393-e0a9-e50e24dcca9e") {
        log.i(service.serviceUuid);
        var characteristics = service.characteristics;
        for (BluetoothCharacteristic c in characteristics) {
          log.i(c.characteristicUuid);
          if (c.properties.write) {
            _writeCharacteristic = c;
            if (_writeCharacteristic != null) {
              _status = "Data write setup done";
              notifyListeners();
              await Future.delayed(const Duration(seconds: 1));
            }
          }
          if (c.properties.notify) {
            characteristicListening(c);
          }
        }
      }
    });
    return services;
  }

  void characteristicListening(BluetoothCharacteristic characteristic) async {
    log.i("Characteristic  subscription");
    final subscription = characteristic.onValueReceived.listen((value) {
      // log.i("CHARA NOT VALUE ", value);
      _data = String.fromCharCodes(value);
      log.i("Data received: $_data");
      _status = "Data received: $_data";
      notifyListeners();
    });

    // cleanup: cancel subscription when disconnected
    device!.cancelWhenDisconnected(subscription);

    //notify
    bool isNotify = await characteristic.setNotifyValue(true);
    log.i("Notification enabled: $isNotify");
    if (isNotify) {
      _status = "Data read setup done";
      notifyListeners();

      //Just for show the status
      await Future.delayed(const Duration(seconds: 2));
      if (_writeCharacteristic != null) {
        _status = "Trigger ready to use";
        notifyListeners();
      }
    } else {
      _status = "Data read setup error";
      notifyListeners();
    }
  }

  Future<void> writeCharacteristic(String value) async {
    if (_device != null && _writeCharacteristic != null) {
      List<int> data = value.codeUnits;
      log.i("Writing: $value");
      _status = "Data write: $value";
      notifyListeners();
      await _writeCharacteristic!.write(data);
    } else {
      _dialogService.showCustomDialog(
        variant: DialogType.infoAlert,
        title: "Device not connected",
        description: 'Go to home page and connect to your device',
      );
    }
  }
}