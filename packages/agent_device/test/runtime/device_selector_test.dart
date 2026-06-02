import 'package:agent_device/agent_device.dart';
import 'package:test/test.dart';

void main() {
  group('DeviceSelector.matches', () {
    BackendDeviceInfo dev({
      String id = 'udid-1',
      String name = 'iPhone 17',
      AgentDeviceBackendPlatform platform = AgentDeviceBackendPlatform.ios,
    }) => BackendDeviceInfo(id: id, name: name, platform: platform);

    test('empty selector matches anything', () {
      expect(const DeviceSelector().matches(dev()), isTrue);
    });

    test('serial matches the device id, not its name', () {
      expect(const DeviceSelector(serial: 'udid-1').matches(dev()), isTrue);
      // A udid passed where a name is expected (the classic --device vs
      // --serial confusion) must NOT match by serial against the name.
      expect(const DeviceSelector(serial: 'iPhone 17').matches(dev()), isFalse);
    });

    test('name matches the device name, not its id', () {
      expect(const DeviceSelector(name: 'iPhone 17').matches(dev()), isTrue);
      expect(const DeviceSelector(name: 'udid-1').matches(dev()), isFalse);
    });

    test('serial and name must both match when both are set', () {
      expect(
        const DeviceSelector(serial: 'udid-1', name: 'iPhone 17').matches(dev()),
        isTrue,
      );
      expect(
        const DeviceSelector(serial: 'udid-1', name: 'Wrong').matches(dev()),
        isFalse,
      );
    });
  });
}
