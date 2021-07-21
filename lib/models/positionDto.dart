class PositionDto {
 
  late double latitude;
  late double longitude;
  late int timeStamp;
  late int speed;

  PositionDto(this.latitude, this.longitude, this.speed, this.timeStamp);

  factory PositionDto.fromJson(dynamic json) {
    return PositionDto(
      json['latitude'] as double,
      json['longitude'] as double,
      json['speed'] as int,
      json['timeStamp'] as int,

    );
  }

  Map toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'speed': speed,
        'timeStamp': timeStamp,

      };
}

