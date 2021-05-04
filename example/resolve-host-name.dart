import 'package:avahi/avahi.dart';

void main(List<String> args) async {
  if (args.isEmpty) {
    print('Missing host name to lookup');
    return;
  }
  var name = args[0];

  var client = AvahiClient();
  await client.connect();

  var result = await client.resolveHostName(name).first;
  print('${result.name.name}\t${result.address.address}');

  await client.close();
}
