import 'base_frame_sampler.dart';

BaseFrameSampler createLiveFrameSampler({Duration interval = const Duration(seconds: 5)}) {
  throw UnsupportedError('Live frame sampling is not supported on this platform.');
}

BaseFrameSampler createMockFrameSampler({Duration interval = const Duration(seconds: 5)}) {
  throw UnsupportedError('Mock frame sampling is not supported on this platform.');
}
