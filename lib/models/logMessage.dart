class LogMessage {

  late String messagetype;
  late DateTime datetimeStamp;
  late String message;

  LogMessage(this.messagetype, this.datetimeStamp, this.message);

  factory LogMessage.fromJson(dynamic json) {
    return LogMessage(
      json['messagetype'] as String,
      json['dateTimestamp'] as DateTime,
      json['message'] as String
    );
  }
  Map toJson() => {
        'messagetype': messagetype,
        'dateTimestamp': datetimeStamp,
        'message': message
      };
}
