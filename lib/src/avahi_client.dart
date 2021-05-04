import 'dart:async';

import 'package:dbus/dbus.dart';

/// D-Bus names.
const _avahiBusName = 'org.freedesktop.Avahi';
const _serverInterfaceName = 'org.freedesktop.Avahi.Server2';
const _hostNameResolverInterfaceName = 'org.freedesktop.Avahi.HostNameResolver';

/// Address protocols.
enum AvahiProtocol { inet, inet6 }

/// Flags used when making lookups.
enum AvahiLookupFlag { useWideArea, useMulticast, noTxt, noAddress }

/// Flags returned in lookup results.
enum AvahiLookupResultFlag {
  cached,
  wideArea,
  multicast,
  local,
  ourOwn,
  static
}

int _encodeAvahiProtocol(AvahiProtocol? protocol) {
  return {AvahiProtocol.inet: 0, AvahiProtocol.inet6: 1}[protocol] ?? -1;
}

AvahiProtocol? _decodeAvahiProtocol(int protocol) {
  return {0: AvahiProtocol.inet, 1: AvahiProtocol.inet6}[protocol];
}

int _encodeAvahiLookupFlags(Set<AvahiLookupFlag> flags) {
  var value = 0;
  for (var flag in flags) {
    value |= {
          AvahiLookupFlag.useWideArea: 0x1,
          AvahiLookupFlag.useMulticast: 0x2,
          AvahiLookupFlag.noTxt: 0x4,
          AvahiLookupFlag.noAddress: 0x8
        }[flag] ??
        0;
  }
  return value;
}

Set<AvahiLookupResultFlag> _decodeAvahiLookupResultFlags(int value) {
  var flags = <AvahiLookupResultFlag>{};
  if (value & 0x01 != 0) {
    flags.add(AvahiLookupResultFlag.cached);
  }
  if (value & 0x02 != 0) {
    flags.add(AvahiLookupResultFlag.wideArea);
  }
  if (value & 0x04 != 0) {
    flags.add(AvahiLookupResultFlag.multicast);
  }
  if (value & 0x08 != 0) {
    flags.add(AvahiLookupResultFlag.local);
  }
  if (value & 0x10 != 0) {
    flags.add(AvahiLookupResultFlag.ourOwn);
  }
  if (value & 0x20 != 0) {
    flags.add(AvahiLookupResultFlag.static);
  }
  return flags;
}

/// A network address.
class AvahiAddress {
  /// The protocol [address] uses.
  final AvahiProtocol? protocol;

  /// The address in string form.
  final String address;

  const AvahiAddress(this.address, {this.protocol});

  @override
  String toString() {
    return 'AvahiAddress($address, protocol: $protocol)';
  }

  @override
  bool operator ==(other) =>
      other is AvahiAddress &&
      other.protocol == protocol &&
      other.address == address;
}

/// A host name.
class AvahiHostName {
  /// The protocol [name] uses.
  final AvahiProtocol? protocol;

  /// The host name.
  final String name;

  const AvahiHostName(this.name, {this.protocol});

  @override
  String toString() {
    return 'AvahiHostName($name, protocol: $protocol)';
  }

  @override
  bool operator ==(other) =>
      other is AvahiHostName &&
      other.protocol == protocol &&
      other.name == name;
}

/// A result to a resolve host name request.
class AvahiResolveHostNameResult {
  /// The host name that was resolved.
  final AvahiHostName name;

  /// The address that matches [name];
  final AvahiAddress address;

  /// Index of the interface this address is on.
  final int interface;

  /// Flags describing the result.
  final Set<AvahiLookupResultFlag> flags;

  const AvahiResolveHostNameResult(
      {required this.name,
      required this.address,
      this.interface = -1,
      this.flags = const {}});

  @override
  String toString() {
    return 'AvahiResolveHostNameResult(name: $name, address: $address, interface: $interface, flags: $flags)';
  }

  @override
  bool operator ==(other) =>
      other is AvahiResolveHostNameResult &&
      other.name == name &&
      other.address == address &&
      other.interface == interface &&
      other.flags.length == flags.length &&
      other.flags.containsAll(flags);
}

class _AvahiHostNameResolver {
  final AvahiClient client;
  final String name;
  final int interface;
  final AvahiProtocol? protocol;
  final AvahiProtocol? addressProtocol;
  final Set<AvahiLookupFlag> flags;
  final controller = StreamController<AvahiResolveHostNameResult>();
  DBusRemoteObject? object;
  StreamSubscription<DBusSignal>? foundSubscription;
  StreamSubscription<DBusSignal>? failureSubscription;

  Stream<AvahiResolveHostNameResult> get stream => controller.stream;

  _AvahiHostNameResolver(this.client, this.name,
      {this.interface = -1,
      this.protocol,
      this.addressProtocol,
      this.flags = const {}}) {
    controller.onListen = onListen;
    controller.onCancel = onCancel;
  }

  void onListen() {
    prepareAndStart().catchError((e) => controller.addError(e));
  }

  Future<void> onCancel() async {
    await foundSubscription?.cancel();
    await failureSubscription?.cancel();
    await free();
  }

  Future<void> prepareAndStart() async {
    var result = await client._root
        .callMethod(_serverInterfaceName, 'HostNameResolverPrepare', [
      DBusInt32(interface),
      DBusInt32(_encodeAvahiProtocol(protocol)),
      DBusString(name),
      DBusInt32(_encodeAvahiProtocol(addressProtocol)),
      DBusUint32(_encodeAvahiLookupFlags(flags))
    ]);
    if (result.signature != DBusSignature('o')) {
      throw '$_serverInterfaceName.HostNameResolverPrepare returned invalid result: ${result.returnValues}';
    }
    var path = result.returnValues[0] as DBusObjectPath;
    object = DBusRemoteObject(client._bus, _avahiBusName, path);
    var found = DBusRemoteObjectSignalStream(
        object!, _hostNameResolverInterfaceName, 'Found');
    foundSubscription = found.listen((signal) {
      if (signal.signature != DBusSignature('iisisu')) {
        controller.addError(
            '$_hostNameResolverInterfaceName.Found contains invalid values: ${signal.values}');
        return;
      }
      var interface = (signal.values[0] as DBusInt32).value;
      var protocol =
          _decodeAvahiProtocol((signal.values[1] as DBusInt32).value);
      var name = (signal.values[2] as DBusString).value;
      var addressProtocol =
          _decodeAvahiProtocol((signal.values[3] as DBusInt32).value);
      var address = (signal.values[4] as DBusString).value;
      var resultFlags =
          _decodeAvahiLookupResultFlags((signal.values[5] as DBusUint32).value);

      controller.add(AvahiResolveHostNameResult(
          name: AvahiHostName(name, protocol: protocol),
          address: AvahiAddress(address, protocol: addressProtocol),
          interface: interface,
          flags: resultFlags));
    });
    var failure = DBusRemoteObjectSignalStream(
        object!, _hostNameResolverInterfaceName, 'Failure');
    failureSubscription = failure.listen((signal) {
      if (signal.signature == DBusSignature('s')) {
        controller.addError((signal.values[0] as DBusString).value);
      } else {
        controller.addError(
            '$_hostNameResolverInterfaceName.Failure contains invalid values: ${signal.values}');
      }
    });
    result =
        await object!.callMethod(_hostNameResolverInterfaceName, 'Start', []);
    if (result.signature != DBusSignature('')) {
      throw '$_hostNameResolverInterfaceName.Start returned invalid result: ${result.returnValues}';
    }
  }

  Future<void> free() async {
    if (object == null) {
      return;
    }
    var result =
        await object!.callMethod(_hostNameResolverInterfaceName, 'Free', []);
    if (result.signature != DBusSignature('')) {
      throw '$_hostNameResolverInterfaceName.Free returned invalid result: ${result.returnValues}';
    }
  }
}

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
    _root = DBusRemoteObject(_bus, _avahiBusName, DBusObjectPath('/'));
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

  /// Gets the addresses that [name] has.
  Stream<AvahiResolveHostNameResult> resolveHostName(String name,
      {AvahiProtocol? protocol,
      AvahiProtocol? addressProtocol,
      int interface = -1,
      Set<AvahiLookupFlag> flags = const {}}) {
    var resolver = _AvahiHostNameResolver(this, name,
        interface: interface,
        protocol: protocol,
        addressProtocol: addressProtocol,
        flags: flags);
    return resolver.stream;
  }

  /// Terminates the connection to the Avahi daemon. If a client remains unclosed, the Dart process may not terminate.
  Future<void> close() async {
    if (_closeBus) {
      await _bus.close();
    }
  }
}
