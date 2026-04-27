import 'base_frame_sampler.dart';
import 'frame_sampler.dart';

BaseFrameSampler createLiveFrameSampler({Duration interval = const Duration(seconds: 5)}) {
  return FrameSampler(interval: interval);
}

BaseFrameSampler createMockFrameSampler({Duration interval = const Duration(seconds: 5)}) {
  return RealMockFrameSampler(interval: interval);
}
