import 'package:flutter/services.dart';
import 'package:unique_identifier/unique_identifier.dart';

class imeiService{

static Future<String> getImeiCode() async {
    String identifier = "";

    try {
      identifier = (await UniqueIdentifier.serial)!;
      print("Unique Code");
      print(identifier);
    

      return identifier;
    } on PlatformException {
      identifier = 'Failed to get Unique Identifier';
      return identifier;
    }
 
  }


}