import 'package:aidoptics_flutter/services/regula_service.dart';
import 'package:stacked/stacked.dart';
import 'package:aidoptics_flutter/app/app.locator.dart';
import 'package:aidoptics_flutter/app/app.router.dart';
import 'package:stacked_services/stacked_services.dart';

import '../../../services/ble_service.dart';

class StartupViewModel extends BaseViewModel {
  final _navigationService = locator<NavigationService>();
  final _regulaService = locator<RegulaService>();
  final _bleService = locator<BleService>();

  // Place anything here that needs to happen before we get into the application
  Future runStartupLogic() async {
    // bool isBle = await _bleService.isBluetoothSupported();
    // if (!isBle) return;
    //ble init
    // _bleService.init(name: "VISION");
    _regulaService.initPlatformState();
    await Future.delayed(const Duration(seconds: 3));

    // This is where you can make decisions on where your app should navigate when
    // you have custom startup logic

    _navigationService.replaceWithHomeView();
  }
}
