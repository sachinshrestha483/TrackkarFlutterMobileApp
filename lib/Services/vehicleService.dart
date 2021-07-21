import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:hive/hive.dart';
import "package:http/http.dart" as http;
import 'package:logger/logger.dart';

import 'package:trackar/models/otpSubmitDto.dart';
import 'package:trackar/models/utility.dart';



class VehicleService {
  static Future<bool> linkVehicle(






      OtpSubmitDto otpSubmit, Logger logger, Box vehicleBox) async {
    try {
      var body2 = json.encode(otpSubmit);
      logger.i("Otp Submit Dto " + body2);
      var res = await http.post(
        Uri.parse(Utility.baseUrl + "User/Vehicle/VerifyOTP"),
        headers: <String, String>{
          'Content-type': 'application/json',
          'Accept': 'application/json'
        },
        body: body2,
      );

      print(res.statusCode);
logger.i("Status Code:"+res.statusCode.toString());
      if (res.statusCode == 200) {
        logger.i("Vehicle Linked");
        logger.i(res.body);
        vehicleBox.put(Utility.vehicle, res.body);
        vehicleBox.put(Utility.vehicleId, otpSubmit.vehicleId);
        return true;
      } else {
        logger.e("Cant Link Vehicle");
        return false;
      }
    } catch (e) {
      print("Error Happen cant Link Vehicle");
      print(e);
        logger.e("Cant Link Vehicle");
      
      return false;
    }
  }
}
