import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:test/test.dart';
import 'package:avahi/avahi.dart';

class MockAvahiRoot extends DBusObject {
  final MockAvahiServer server;

  MockAvahiRoot(this.server) : super(DBusObjectPath('/'));

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {
    if (methodCall.interface != 'org.freedesktop.Avahi.Server2') {
      return DBusMethodErrorResponse.unknownInterface();
    }

    switch (methodCall.name) {
      case 'GetVersionString':
        return DBusMethodSuccessResponse([DBusString(server.versionString)]);
      default:
        return DBusMethodErrorResponse.unknownMethod();
    }
  }
}

class MockAvahiServer extends DBusClient {
  late final MockAvahiRoot _root;

  final String versionString;

  MockAvahiServer(DBusAddress clientAddress, {this.versionString = ''})
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
}
