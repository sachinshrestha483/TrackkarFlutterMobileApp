class SlotResponseDto {
  late bool updateconfig;

  SlotResponseDto(this.updateconfig);

  factory SlotResponseDto.fromJson(dynamic json) {
    return SlotResponseDto(
      json['updateconfig'] as bool,
    );
  }

  Map toJson() => {
        'updateconfig': updateconfig,
      };
}
