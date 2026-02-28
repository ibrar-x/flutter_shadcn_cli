typedef CommandRunner = Future<int> Function();

class CommandDispatcher {
  final Map<String, CommandRunner> _handlers;

  const CommandDispatcher(this._handlers);

  Future<int> dispatch(String commandName) async {
    final handler = _handlers[commandName];
    if (handler == null) {
      return 64;
    }
    return handler();
  }
}
