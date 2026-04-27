import 'dart:typed_data';

import 'base_frame_sampler.dart';

import 'frame_sampler_factory_stub.dart'
    if (dart.library.io) 'frame_sampler_factory_io.dart'
    if (dart.library.html) 'frame_sampler_factory_web.dart' as impl;

/// Creates the live frame sampler for the current platform.
BaseFrameSampler createLiveFrameSampler({Duration interval = const Duration(seconds: 5)}) {
  return impl.createLiveFrameSampler(interval: interval);
}

/// Creates the static/mock frame sampler for the current platform.
BaseFrameSampler createMockFrameSampler({Duration interval = const Duration(seconds: 5)}) {
  return impl.createMockFrameSampler(interval: interval);
}

/// Convenience: returns either mock or live based on [useMock].
BaseFrameSampler createFrameSampler({
  required bool useMock,
  Duration interval = const Duration(seconds: 5),
}) {
  return useMock
      ? createMockFrameSampler(interval: interval)
      : createLiveFrameSampler(interval: interval);
}

/// Small type helper used by providers; avoids importing IO-only libs.
typedef FrameStream = Stream<Uint8List>;
