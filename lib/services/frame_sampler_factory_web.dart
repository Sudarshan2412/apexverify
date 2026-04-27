import 'base_frame_sampler.dart';
import 'frame_sampler_web.dart';

BaseFrameSampler createLiveFrameSampler({Duration interval = const Duration(seconds: 5)}) {
  return WebFrameSampler(interval: interval);
}

BaseFrameSampler createMockFrameSampler({Duration interval = const Duration(seconds: 5)}) {
  return RealMockFrameSamplerWeb(interval: interval);
}
