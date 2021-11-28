class Logger {
  String _now() {
    return DateTime.now().toString();
  }

  void log(String message) {
    print('[${_now()}]: ${message}');
  }
}

Logger logger = Logger();
