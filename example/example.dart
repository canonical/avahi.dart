import 'package:avahi/avahi.dart';

void main() async {
  var client = AvahiClient();
  await client.connect();
  print('Server version: ${await client.getVersionString()}');
  print('Hostname: ${await client.getHostName()}');
  await client.close();
}
