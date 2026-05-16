import 'dart:developer' as dev;

void log(String message, {String name = 'Langualio', Object? error}) {
  dev.log(message, name: name, error: error);
}
