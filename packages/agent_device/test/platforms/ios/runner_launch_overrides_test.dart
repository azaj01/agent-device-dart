import 'package:agent_device/src/platforms/ios/runner_client.dart';
import 'package:test/test.dart';

void main() {
  group('IosRunnerLaunchOverrides', () {
    tearDown(() {
      IosRunnerLaunchOverrides.xctestrunFile = null;
      IosRunnerLaunchOverrides.derivedDataPath = null;
      IosRunnerLaunchOverrides.envDir = null;
    });

    test('hasExternalArtifact is false when no xctestrun file is set', () {
      expect(IosRunnerLaunchOverrides.hasExternalArtifact, isFalse);
    });

    test('hasExternalArtifact is false for blank/whitespace paths', () {
      IosRunnerLaunchOverrides.xctestrunFile = '   ';
      expect(IosRunnerLaunchOverrides.hasExternalArtifact, isFalse);
    });

    test('hasExternalArtifact is true once an artifact path is set', () {
      IosRunnerLaunchOverrides.xctestrunFile = '/tmp/Runner.xctestrun';
      expect(IosRunnerLaunchOverrides.hasExternalArtifact, isTrue);
    });
  });
}
