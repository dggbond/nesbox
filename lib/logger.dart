import "package:logger/logger.dart";

class NesLogger {
  NesLogger(bool debugMode) {
    if (debugMode) {
      _logger = Logger(
        printer: PrettyPrinter(
          lineLength: 120,
          colors: true,
          printEmojis: true,
          printTime: true,
        ),
      );
    }
  }

  Logger _logger;

  void w(dynamic message, [dynamic error, StackTrace stackTrace]) {
    if (_logger != null) {
      _logger.w(message, error, stackTrace);
    }
  }

  void i(dynamic message, [dynamic error, StackTrace stackTrace]) {
    if (_logger != null) {
      _logger.i(message, error, stackTrace);
    }
  }

  void v(dynamic message, [dynamic error, StackTrace stackTrace]) {
    if (_logger != null) {
      _logger.v(message, error, stackTrace);
    }
  }
}
