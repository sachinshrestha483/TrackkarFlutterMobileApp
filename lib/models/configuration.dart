class Configuration {
  late int id;
  late String name;
  late int interval;
  late int slotSize;

  Configuration(this.id, this.interval, this.name, this.slotSize);

  factory Configuration.fromJson(dynamic json) {
    return Configuration(
      json['id'] as int,
      json['interval'] as int,
      json['name'] as String,
      json['slotSize'] as int,
    );
  }
  Map toJson() => {
        'id': id,
        'interval': interval,
        'name': name,
        'slotsize': slotSize,
      };
}
