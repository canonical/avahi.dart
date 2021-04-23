import 'package:avahi/avahi.dart';

void main() async {
  var client = AvahiClient();
  await client.connect();
  print('Running Avahi ${await client.getVersionString()}');
  await client.close();
}
