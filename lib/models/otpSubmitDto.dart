class OtpSubmitDto {
  
  late int vehicleId;
  late int otp;
  late String  imeiCode;

  OtpSubmitDto( this.vehicleId, this.otp,this.imeiCode);

  factory OtpSubmitDto.fromJson(dynamic json) {
    return OtpSubmitDto(
      json['vehicleId'] as int,
      json['otp'] as int,
      json['imeiCode'] as String

    );
  }

  Map toJson() => {
        'vehicleId': vehicleId,
        'otp': otp,
        'ImeiCode': imeiCode,
      };
}

