import '../models/thinking_orb_config.dart';
import '../states/composing.dart';
import '../states/connecting.dart';
import '../states/listening.dart';
import '../states/searching.dart';
import '../states/shaping.dart';
import '../states/solving.dart';
import '../states/weaving.dart';
import '../states/working.dart';
import 'particle_system.dart';

/// A geometry builder: pure math over (size, t, opts) into a [FrameBuilder].
typedef ModeFrame = void Function(FrameBuilder fb, double size, double t, ModeOpts o);

/// Mode → geometry builder. `ring` shares ribbon's geometry (`faceOn` flag).
ModeFrame modeFrameFor(OrbMode mode) => switch (mode) {
      OrbMode.orbits => frameOrbits,
      OrbMode.globe => frameGlobe,
      OrbMode.rubik => frameRubik,
      OrbMode.wave => frameWave,
      OrbMode.web => frameWeb,
      OrbMode.braid => frameBraid,
      OrbMode.ribbon => frameRibbon,
      OrbMode.ring => frameRibbon,
      OrbMode.morph => frameMorph,
    };
