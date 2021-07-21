class Vehicle {
  late int id;
  late String name;
  late String registeredNumber;
  late String photoUrl;

  Vehicle(this.id, this.name, this.registeredNumber, this.photoUrl);

  factory Vehicle.fromJson(dynamic json) {
    return Vehicle(
      json['id'] as int,
      json['name'] as String,
      json['registeredNumber'] as String,
      json['photoUrl'] as String,
    );
  }

  Map toJson() => {
        'id': id,
        'name': name,
        'registeredNumber': registeredNumber,
        'photoUrl': photoUrl
      };
}
