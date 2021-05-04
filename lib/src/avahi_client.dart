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

  /// Gets the API version.
  Future<int> getAPIVersion() async {
    var result = await _root
        .callMethod('org.freedesktop.Avahi.Server2', 'GetAPIVersion', []);
    if (result.signature != DBusSignature('u')) {
      throw 'org.freedesktop.Avahi.Server2.GetAPIVersion returned invalid result: ${result.returnValues}';
    }
    return (result.returnValues[0] as DBusUint32).value;
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

  /// Gets the domain name.
  Future<String> getDomainName() async {
    var result = await _root
        .callMethod('org.freedesktop.Avahi.Server2', 'GetDomainName', []);
    if (result.signature != DBusSignature('s')) {
      throw 'org.freedesktop.Avahi.Server2.GetDomainName returned invalid result: ${result.returnValues}';
    }
    return (result.returnValues[0] as DBusString).value;
  }

  /// Gets the hostname in fully qualified domain name form.
  Future<String> getHostNameFqdn() async {
    var result = await _root
        .callMethod('org.freedesktop.Avahi.Server2', 'GetHostNameFqdn', []);
    if (result.signature != DBusSignature('s')) {
      throw 'org.freedesktop.Avahi.Server2.GetHostNameFqdn returned invalid result: ${result.returnValues}';
    }
    return (result.returnValues[0] as DBusString).value;
  }

  /// Gets an alternative hostname for [name].
  Future<String> getAlternativeHostName(String name) async {
    var result = await _root.callMethod('org.freedesktop.Avahi.Server2',
        'GetAlternativeHostName', [DBusString(name)]);
    if (result.signature != DBusSignature('s')) {
      throw 'org.freedesktop.Avahi.Server2.GetAlternativeHostName returned invalid result: ${result.returnValues}';
    }
    return (result.returnValues[0] as DBusString).value;
  }

  /// Gets an alternative service name for [name].
  Future<String> getAlternativeServiceName(String name) async {
    var result = await _root.callMethod('org.freedesktop.Avahi.Server2',
        'GetAlternativeServiceName', [DBusString(name)]);
    if (result.signature != DBusSignature('s')) {
      throw 'org.freedesktop.Avahi.Server2.GetAlternativeServiceName returned invalid result: ${result.returnValues}';
    }
    return (result.returnValues[0] as DBusString).value;
  }

  /// Gets the index of the network interface with [name].
  Future<int> getNetworkInterfaceIndexByName(String name) async {
    var result = await _root.callMethod('org.freedesktop.Avahi.Server2',
        'GetNetworkInterfaceIndexByName', [DBusString(name)]);
    if (result.signature != DBusSignature('i')) {
      throw 'org.freedesktop.Avahi.Server2.GetNetworkInterfaceIndexByName returned invalid result: ${result.returnValues}';
    }
    return (result.returnValues[0] as DBusInt32).value;
  }

  /// Gets the name of the network interface with [index].
  Future<String> getNetworkInterfaceNameByIndex(int index) async {
    var result = await _root.callMethod('org.freedesktop.Avahi.Server2',
        'GetNetworkInterfaceNameByIndex', [DBusInt32(index)]);
    if (result.signature != DBusSignature('s')) {
      throw 'org.freedesktop.Avahi.Server2.GetNetworkInterfaceNameByIndex returned invalid result: ${result.returnValues}';
    }
    return (result.returnValues[0] as DBusString).value;
  }

  /// Terminates the connection to the Avahi daemon. If a client remains unclosed, the Dart process may not terminate.
  Future<void> close() async {
    if (_closeBus) {
      await _bus.close();
    }
  }
}
