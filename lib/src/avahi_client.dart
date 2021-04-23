import 'dart:async';

import 'package:dbus/dbus.dart';

/// A client that connects to Avahi.
class AvahiClient {
  /// The bus this client is connected to.
  final DBusClient _bus;
  final bool _closeBus;

  /// The root D-Bus Avahi object.
  late final DBusRemoteObject _root;

  /// Creates a new Avahi client connected to the system D-Bus.
  AvahiClient({DBusClient? bus})
      : _bus = bus ?? DBusClient.system(),
        _closeBus = bus == null {
    _root =
        DBusRemoteObject(_bus, 'org.freedesktop.Avahi', DBusObjectPath('/'));
  }

  /// Connects to the Avahi daemon.
  Future<void> connect() async {}

  /// Gets the server version.
  Future<String> getVersionString() async {
    var result = await _root
        .callMethod('org.freedesktop.Avahi.Server2', 'GetVersionString', []);
    if (result.signature != DBusSignature('s')) {
      throw 'org.freedesktop.Avahi.Server2.GetVersionString returned invalid result: ${result.returnValues}';
    }
    return (result.returnValues[0] as DBusString).value;
  }

  /// Gets the hostname.
  Future<String> getHostName() async {
    var result = await _root
        .callMethod('org.freedesktop.Avahi.Server2', 'GetHostName', []);
    if (result.signature != DBusSignature('s')) {
      throw 'org.freedesktop.Avahi.Server2.GetHostName returned invalid result: ${result.returnValues}';
    }
    return (result.returnValues[0] as DBusString).value;
  }

  /// Sets the hostname.
  Future<void> setHostName(String hostName) async {
    var result = await _root.callMethod(
        'org.freedesktop.Avahi.Server2', 'SetHostName', [DBusString(hostName)]);
    if (result.signature != DBusSignature('')) {
      throw 'org.freedesktop.Avahi.Server2.SetHostName returned invalid result: ${result.returnValues}';
    }
  }

  /// Terminates the connection to the Avahi daemon. If a client remains unclosed, the Dart process may not terminate.
  Future<void> close() async {
    if (_closeBus) {
      await _bus.close();
    }
  }
}
