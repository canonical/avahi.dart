[![Pub Package](https://img.shields.io/pub/v/avahi.svg)](https://pub.dev/packages/avahi)

Provides a client to connect to [Avahi](https://www.avahi.org/) - the service that implements mDNS/DNS-SD on Linux.

```dart
import 'package:avahi/avahi.dart';

var client = avahiClient();
await client.connect();
print('Server version: ${await client.getVersionString()}');
await client.close();
```

## Contributing to avahi.dart

We welcome contributions! See the [contribution guide](CONTRIBUTING.md) for more details.
