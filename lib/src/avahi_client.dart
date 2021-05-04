import 'dart:async';

import 'package:dbus/dbus.dart';

/// D-Bus interface names.
const _serverInterfaceName = 'org.freedesktop.Avahi.Server2';

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
    var result =
        await _root.callMethod(_serverInterfaceName, 'GetVersionString', []);
    if (result.signature != DBusSignature('s')) {
      throw '$_serverInterfaceName.GetVersionString returned invalid result: ${result.returnValues}';
    }
    return (result.returnValues[0] as DBusString).value;
  }

  /// Gets the API version.
  Future<int> getAPIVersion() async {
    var result =
        await _root.callMethod(_serverInterfaceName, 'GetAPIVersion', []);
    if (result.signature != DBusSignature('u')) {
      throw '$_serverInterfaceName.GetAPIVersion returned invalid result: ${result.returnValues}';
    }
    return (result.returnValues[0] as DBusUint32).value;
  }

  /// Gets the hostname.
  Future<String> getHostName() async {
    var result =
        await _root.callMethod(_serverInterfaceName, 'GetHostName', []);
    if (result.signature != DBusSignature('s')) {
      throw '$_serverInterfaceName.GetHostName returned invalid result: ${result.returnValues}';
    }
    return (result.returnValues[0] as DBusString).value;
  }

  /// Sets the hostname.
  Future<void> setHostName(String hostName) async {
    var result = await _root.callMethod(
        _serverInterfaceName, 'SetHostName', [DBusString(hostName)]);
    if (result.signature != DBusSignature('')) {
      throw '$_serverInterfaceName.SetHostName returned invalid result: ${result.returnValues}';
    }
  }

  /// Gets the domain name.
  Future<String> getDomainName() async {
    var result =
        await _root.callMethod(_serverInterfaceName, 'GetDomainName', []);
    if (result.signature != DBusSignature('s')) {
      throw '$_serverInterfaceName.GetDomainName returned invalid result: ${result.returnValues}';
    }
    return (result.returnValues[0] as DBusString).value;
  }

  /// Gets the hostname in fully qualified domain name form.
  Future<String> getHostNameFqdn() async {
    var result =
        await _root.callMethod(_serverInterfaceName, 'GetHostNameFqdn', []);
    if (result.signature != DBusSignature('s')) {
      throw '$_serverInterfaceName.GetHostNameFqdn returned invalid result: ${result.returnValues}';
    }
    return (result.returnValues[0] as DBusString).value;
  }

  /// Gets an alternative hostname for [name].
  Future<String> getAlternativeHostName(String name) async {
    var result = await _root.callMethod(
        _serverInterfaceName, 'GetAlternativeHostName', [DBusString(name)]);
    if (result.signature != DBusSignature('s')) {
      throw '$_serverInterfaceName.GetAlternativeHostName returned invalid result: ${result.returnValues}';
    }
    return (result.returnValues[0] as DBusString).value;
  }

  /// Gets an alternative service name for [name].
  Future<String> getAlternativeServiceName(String name) async {
    var result = await _root.callMethod(
        _serverInterfaceName, 'GetAlternativeServiceName', [DBusString(name)]);
    if (result.signature != DBusSignature('s')) {
      throw '$_serverInterfaceName.GetAlternativeServiceName returned invalid result: ${result.returnValues}';
    }
    return (result.returnValues[0] as DBusString).value;
  }

  /// Gets the index of the network interface with [name].
  Future<int> getNetworkInterfaceIndexByName(String name) async {
    var result = await _root.callMethod(_serverInterfaceName,
        'GetNetworkInterfaceIndexByName', [DBusString(name)]);
    if (result.signature != DBusSignature('i')) {
      throw '$_serverInterfaceName.GetNetworkInterfaceIndexByName returned invalid result: ${result.returnValues}';
    }
    return (result.returnValues[0] as DBusInt32).value;
  }

  /// Gets the name of the network interface with [index].
  Future<String> getNetworkInterfaceNameByIndex(int index) async {
    var result = await _root.callMethod(_serverInterfaceName,
        'GetNetworkInterfaceNameByIndex', [DBusInt32(index)]);
    if (result.signature != DBusSignature('s')) {
      throw '$_serverInterfaceName.GetNetworkInterfaceNameByIndex returned invalid result: ${result.returnValues}';
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
