typedef void EventCallback(dynamic arg);

class EventBus {
  EventBus();

  final _emap = Map<String, List<EventCallback>>();

  void on(String eventName, EventCallback f) {
    _emap[eventName] ??= <EventCallback>[];
    _emap[eventName].add(f);
  }

  void off(String eventName, [EventCallback f]) {
    var list = _emap[eventName];
    if (eventName == null || list == null) return;
    if (f == null) {
      _emap[eventName] = <EventCallback>[];
    } else {
      list.remove(f);
    }
  }

  void emit(String eventName, [arg]) {
    var list = _emap[eventName];
    if (list == null) return;

    int len = list.length - 1;
    for (var i = len; i > -1; --i) {
      list[i]?.call(arg);
    }
  }
}
