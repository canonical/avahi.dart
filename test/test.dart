import 'dart:async';
import 'dart:io';

import 'package:avahi/avahi.dart';
import 'package:dbus/dbus.dart';
import 'package:test/test.dart';

class MockAvahiHostNameResolver extends DBusObject {
  final MockAvahiServer server;
  final int interface;
  final int protocol;
  final String name;
  final int addressProtocol;
  final int flags;

  MockAvahiHostNameResolver(this.server, int index,
      {required this.interface,
      required this.protocol,
      required this.name,
      required this.addressProtocol,
      required this.flags})
      : super(DBusObjectPath('/Client/HostNameResolver$index'));

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {
    if (methodCall.interface != 'org.freedesktop.Avahi.HostNameResolver') {
      return DBusMethodErrorResponse.unknownInterface();
    }

    switch (methodCall.name) {
      case 'Free':
        await server.unregisterObject(this);
        return DBusMethodSuccessResponse();
      case 'Start':
        Timer.run(() {
          for (var host in server.hosts) {
            if (host.name != name ||
                (interface != -1 && host.interface != interface) ||
                (protocol != -1 && host.protocol != protocol) ||
                (addressProtocol != -1 &&
                    host.addressProtocol != addressProtocol) ||
                ((flags & 0x1) != 0 && !host.isWideArea)) {
              continue;
            }
            emitFound(host.interface, host.protocol, host.name,
                host.addressProtocol, host.address, host.flags);
          }
        });
        return DBusMethodSuccessResponse();
      default:
        return DBusMethodErrorResponse.unknownMethod();
    }
  }

  void emitFound(int interface, int protocol, String name, int addressProtocol,
      String address, int flags) {
    emitSignal('org.freedesktop.Avahi.HostNameResolver', 'Found', [
      DBusInt32(interface),
      DBusInt32(protocol),
      DBusString(name),
      DBusInt32(addressProtocol),
      DBusString(address),
      DBusUint32(flags)
    ]);
  }

  void emitFailure(String error) {
    emitSignal('org.freedesktop.Avahi.HostNameResolver', 'Failure',
        [DBusString(error)]);
  }
}

class MockAvahiRoot extends DBusObject {
  final MockAvahiServer server;

  MockAvahiRoot(this.server) : super(DBusObjectPath('/'));

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {
    if (methodCall.interface != 'org.freedesktop.Avahi.Server2') {
      return DBusMethodErrorResponse.unknownInterface();
    }

    switch (methodCall.name) {
      case 'GetAlternativeHostName':
        var name = (methodCall.values[0] as DBusString).value;
        return DBusMethodSuccessResponse([DBusString('$name-2')]);
      case 'GetAlternativeServiceName':
        var name = (methodCall.values[0] as DBusString).value;
        return DBusMethodSuccessResponse([DBusString('$name #2')]);
      case 'GetAPIVersion':
        return DBusMethodSuccessResponse([DBusUint32(server.apiVersion)]);
      case 'GetDomainName':
        return DBusMethodSuccessResponse([DBusString(server.domainName)]);
      case 'GetHostName':
        return DBusMethodSuccessResponse([DBusString(server.hostName)]);
      case 'GetHostNameFqdn':
        return DBusMethodSuccessResponse([DBusString(server.hostNameFqdn)]);
      case 'GetNetworkInterfaceIndexByName':
        var name = (methodCall.values[0] as DBusString).value;
        var index = server.networkInterfaces.indexOf(name);
        if (index < 0) {
          return DBusMethodErrorResponse('org.freedesktop.Avahi.OSError');
        }
        return DBusMethodSuccessResponse([DBusInt32(index + 1)]);
      case 'GetNetworkInterfaceNameByIndex':
        var index = (methodCall.values[0] as DBusInt32).value;
        var name = server.networkInterfaces[index - 1];
        return DBusMethodSuccessResponse([DBusString(name)]);
      case 'GetVersionString':
        return DBusMethodSuccessResponse([DBusString(server.versionString)]);
      case 'HostNameResolverPrepare':
        var interface = (methodCall.values[0] as DBusInt32).value;
        var protocol = (methodCall.values[1] as DBusInt32).value;
        var name = (methodCall.values[2] as DBusString).value;
        var addressProtocol = (methodCall.values[3] as DBusInt32).value;
        var flags = (methodCall.values[4] as DBusUint32).value;
        var resolver = MockAvahiHostNameResolver(
            server, server.nextHostNameResolverIndex,
            interface: interface,
            protocol: protocol,
            name: name,
            addressProtocol: addressProtocol,
            flags: flags);
        server.nextHostNameResolverIndex++;
        await server.registerObject(resolver);
        return DBusMethodSuccessResponse([resolver.path]);
      case 'SetHostName':
        server.hostName = (methodCall.values[0] as DBusString).value;
        return DBusMethodSuccessResponse();
      default:
        return DBusMethodErrorResponse.unknownMethod();
    }
  }
}

class MockAvahiHost {
  final int protocol;
  final String address;
  final int addressProtocol;
  final String name;
  final int interface;
  final int flags;
  final bool isWideArea;

  const MockAvahiHost(
      {required this.address,
      required this.name,
      this.protocol = -1,
      this.addressProtocol = -1,
      this.interface = -1,
      this.flags = 0,
      this.isWideArea = false});
}

class MockAvahiServer extends DBusClient {
  late final MockAvahiRoot _root;

  int apiVersion;
  String domainName;
  String hostName;
  String hostNameFqdn;
  List<MockAvahiHost> hosts;
  List<String> networkInterfaces;
  final String versionString;

  int nextHostNameResolverIndex = 1;

  MockAvahiServer(DBusAddress clientAddress,
      {this.apiVersion = 0,
      this.domainName = '',
      this.hostName = '',
      this.hostNameFqdn = '',
      this.hosts = const [],
      this.networkInterfaces = const [],
      this.versionString = ''})
      : super(clientAddress);

  Future<void> start() async {
    await requestName('org.freedesktop.Avahi');
    _root = MockAvahiRoot(this);
    await registerObject(_root);
  }
}

void main() {
  test('daemon version', () async {
    var server = DBusServer();
    var clientAddress =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));

    var avahi = MockAvahiServer(clientAddress, versionString: '1.2.3');
    await avahi.start();

    var client = AvahiClient(bus: DBusClient(clientAddress));
    await client.connect();

    expect(await client.getVersionString(), equals('1.2.3'));

    await client.close();
  });

  test('api version', () async {
    var server = DBusServer();
    var clientAddress =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));

    var avahi = MockAvahiServer(clientAddress, apiVersion: 512);
    await avahi.start();

    var client = AvahiClient(bus: DBusClient(clientAddress));
    await client.connect();

    expect(await client.getAPIVersion(), equals(512));

    await client.close();
  });

  test('get hostname', () async {
    var server = DBusServer();
    var clientAddress =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));

    var avahi = MockAvahiServer(clientAddress, hostName: 'foo');
    await avahi.start();

    var client = AvahiClient(bus: DBusClient(clientAddress));
    await client.connect();

    expect(await client.getHostName(), equals('foo'));

    await client.close();
  });

  test('set hostname', () async {
    var server = DBusServer();
    var clientAddress =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));

    var avahi = MockAvahiServer(clientAddress, hostName: 'foo');
    await avahi.start();

    var client = AvahiClient(bus: DBusClient(clientAddress));
    await client.connect();

    await client.setHostName('bar');
    expect(avahi.hostName, equals('bar'));

    await client.close();
  });

  test('get domain name', () async {
    var server = DBusServer();
    var clientAddress =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));

    var avahi = MockAvahiServer(clientAddress, domainName: 'local');
    await avahi.start();

    var client = AvahiClient(bus: DBusClient(clientAddress));
    await client.connect();

    expect(await client.getDomainName(), equals('local'));

    await client.close();
  });

  test('get hostname fqdn', () async {
    var server = DBusServer();
    var clientAddress =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));

    var avahi = MockAvahiServer(clientAddress, hostNameFqdn: 'foo.local');
    await avahi.start();

    var client = AvahiClient(bus: DBusClient(clientAddress));
    await client.connect();

    expect(await client.getHostNameFqdn(), equals('foo.local'));

    await client.close();
  });

  test('get alternative hostname', () async {
    var server = DBusServer();
    var clientAddress =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));

    var avahi = MockAvahiServer(clientAddress);
    await avahi.start();

    var client = AvahiClient(bus: DBusClient(clientAddress));
    await client.connect();

    expect(await client.getAlternativeHostName('foo'), equals('foo-2'));

    await client.close();
  });

  test('get alternative service name', () async {
    var server = DBusServer();
    var clientAddress =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));

    var avahi = MockAvahiServer(clientAddress);
    await avahi.start();

    var client = AvahiClient(bus: DBusClient(clientAddress));
    await client.connect();

    expect(await client.getAlternativeServiceName('foo'), equals('foo #2'));

    await client.close();
  });

  test('get network interface index by name', () async {
    var server = DBusServer();
    var clientAddress =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));

    var avahi = MockAvahiServer(clientAddress,
        networkInterfaces: ['lo', 'eth0', 'eth1']);
    await avahi.start();

    var client = AvahiClient(bus: DBusClient(clientAddress));
    await client.connect();

    expect(await client.getNetworkInterfaceIndexByName('eth0'), equals(2));

    await client.close();
  });

  test('get network interface name by index', () async {
    var server = DBusServer();
    var clientAddress =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));

    var avahi = MockAvahiServer(clientAddress,
        networkInterfaces: ['lo', 'eth0', 'eth1']);
    await avahi.start();

    var client = AvahiClient(bus: DBusClient(clientAddress));
    await client.connect();

    expect(await client.getNetworkInterfaceNameByIndex(2), equals('eth0'));

    await client.close();
  });

  test('resolve host name', () async {
    var server = DBusServer();
    var clientAddress =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));

    var avahi = MockAvahiServer(clientAddress, hosts: [
      MockAvahiHost(
          address: '192.168.1.1',
          addressProtocol: 0,
          name: 'foo.local',
          protocol: 0,
          interface: 1,
          flags: 0x00),
      MockAvahiHost(
          address: '2001:0db8:85a3:0000:0000:8a2e:0370:7334',
          addressProtocol: 1,
          name: 'foo.local',
          protocol: 1,
          interface: 2,
          flags: 0x3f)
    ]);
    await avahi.start();

    var client = AvahiClient(bus: DBusClient(clientAddress));
    await client.connect();

    var results = client.resolveHostName('foo.local');
    expect(
        results,
        emitsInOrder([
          AvahiResolveHostNameResult(
              name: AvahiHostName('foo.local', protocol: AvahiProtocol.inet),
              address:
                  AvahiAddress('192.168.1.1', protocol: AvahiProtocol.inet),
              interface: 1),
          AvahiResolveHostNameResult(
              name: AvahiHostName('foo.local', protocol: AvahiProtocol.inet6),
              address: AvahiAddress('2001:0db8:85a3:0000:0000:8a2e:0370:7334',
                  protocol: AvahiProtocol.inet6),
              interface: 2,
              flags: {
                AvahiLookupResultFlag.cached,
                AvahiLookupResultFlag.wideArea,
                AvahiLookupResultFlag.multicast,
                AvahiLookupResultFlag.local,
                AvahiLookupResultFlag.ourOwn,
                AvahiLookupResultFlag.static
              })
        ]));
  });

  test('resolve host name - protocol', () async {
    var server = DBusServer();
    var clientAddress =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));

    var avahi = MockAvahiServer(clientAddress, hosts: [
      MockAvahiHost(address: '192.168.1.1', protocol: 0, name: 'foo.local'),
      MockAvahiHost(
          address: '2001:0db8:85a3:0000:0000:8a2e:0370:7334',
          protocol: 1,
          name: 'foo.local'),
    ]);
    await avahi.start();

    var client = AvahiClient(bus: DBusClient(clientAddress));
    await client.connect();

    var results =
        client.resolveHostName('foo.local', protocol: AvahiProtocol.inet6);
    expect(
        results,
        emitsInOrder([
          AvahiResolveHostNameResult(
              name: AvahiHostName('foo.local', protocol: AvahiProtocol.inet6),
              address: AvahiAddress('2001:0db8:85a3:0000:0000:8a2e:0370:7334'))
        ]));
  });

  test('resolve host name - address protocol', () async {
    var server = DBusServer();
    var clientAddress =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));

    var avahi = MockAvahiServer(clientAddress, hosts: [
      MockAvahiHost(
          address: '192.168.1.1', addressProtocol: 0, name: 'foo.local'),
      MockAvahiHost(
          address: '2001:0db8:85a3:0000:0000:8a2e:0370:7334',
          addressProtocol: 1,
          name: 'foo.local'),
    ]);
    await avahi.start();

    var client = AvahiClient(bus: DBusClient(clientAddress));
    await client.connect();

    var results = client.resolveHostName('foo.local',
        addressProtocol: AvahiProtocol.inet6);
    expect(
        results,
        emitsInOrder([
          AvahiResolveHostNameResult(
              name: AvahiHostName('foo.local'),
              address: AvahiAddress('2001:0db8:85a3:0000:0000:8a2e:0370:7334',
                  protocol: AvahiProtocol.inet6))
        ]));
  });

  test('resolve host name - interface', () async {
    var server = DBusServer();
    var clientAddress =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));

    var avahi = MockAvahiServer(clientAddress, hosts: [
      MockAvahiHost(address: '192.168.1.1', name: 'foo.local', interface: 1),
      MockAvahiHost(address: '192.168.2.1', name: 'foo.local', interface: 2),
    ]);
    await avahi.start();

    var client = AvahiClient(bus: DBusClient(clientAddress));
    await client.connect();

    var results = client.resolveHostName('foo.local', interface: 2);
    expect(
        results,
        emitsInOrder([
          AvahiResolveHostNameResult(
              name: AvahiHostName('foo.local'),
              address: AvahiAddress('192.168.2.1'),
              interface: 2)
        ]));
  });

  test('resolve host name - flags', () async {
    var server = DBusServer();
    var clientAddress =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));

    var avahi = MockAvahiServer(clientAddress, hosts: [
      MockAvahiHost(
          address: '192.168.1.1', name: 'foo.local', isWideArea: false),
      MockAvahiHost(
          address: '192.168.2.1', name: 'foo.local', isWideArea: true),
    ]);
    await avahi.start();

    var client = AvahiClient(bus: DBusClient(clientAddress));
    await client.connect();

    var results = client
        .resolveHostName('foo.local', flags: {AvahiLookupFlag.useWideArea});
    expect(
        results,
        emitsInOrder([
          AvahiResolveHostNameResult(
              name: AvahiHostName('foo.local'),
              address: AvahiAddress('192.168.2.1'))
        ]));
  });
}
