class Message {
  const Message(this.message, {this.isError = false});

  factory Message.fromJson(Map<dynamic, dynamic> json) {
    return Message(
      switch (json['message']) {
        final String message => message,
        _ => '',
      },
      isError: switch (json['isError']) {
        final bool isError => isError,
        _ => false,
      },
    );
  }

  final String message;
  final bool isError;

  Map<String, dynamic> toJson() {
    return {'message': message, 'isError': isError};
  }
}
