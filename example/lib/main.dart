import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:thinking_orb/thinking_orb.dart';


void main() => runApp(const DemoApp());

const Map<String, ThinkingOrbColors> kPalettes = {
  'Original mono': ThinkingOrbColors.standard,
  'Indigo': ThinkingOrbColors(
    darkestInk: Color(0xFF1E1B4B),
    lightestInk: Color(0xFFC7D2FE),
  ),
  'Ember': ThinkingOrbColors(
    darkestInk: Color(0xFF7C2D12),
    lightestInk: Color(0xFFFED7AA),
  ),
  'Forest': ThinkingOrbColors(
    darkestInk: Color(0xFF052E16),
    lightestInk: Color(0xFFBBF7D0),
  ),
};

const Map<String, List<Color>?> kBeamColors = {
  'Theme ink': null,
  'Violet → Cyan': [Color(0xFF7C5CFF), Color(0xFF22D3EE)],
  'Sunset': [Color(0xFFFF5F6D), Color(0xFFFFC371)],
  'Mint → Blue': [Color(0xFF34D399), Color(0xFF3B82F6)],
};

class DemoApp extends StatefulWidget {
  const DemoApp({super.key});

  @override
  State<DemoApp> createState() => _DemoAppState();
}

class _DemoAppState extends State<DemoApp> {
  ThemeMode mode = ThemeMode.dark;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Thinking Orbs',
      debugShowCheckedModeBanner: false,
      themeMode: mode,
      theme: ThemeData(
        brightness: Brightness.light,
        colorSchemeSeed: Colors.indigo,
        scaffoldBackgroundColor: const Color(0xFFF6F6F8),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.indigo,
        scaffoldBackgroundColor: const Color(0xFF0E0E10),
      ),
      home: Showcase(mode: mode, onMode: (m) => setState(() => mode = m)),
    );
  }
}

class Showcase extends StatelessWidget {
  const Showcase({super.key, required this.mode, required this.onMode});
  final ThemeMode mode;
  final ValueChanged<ThemeMode> onMode;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Thinking Orbs'),
          actions: [
            // One button that cycles auto → light → dark (fits narrow phones).
            IconButton(
              tooltip: 'Theme: ${mode.name} (tap to change)',
              icon: Icon(switch (mode) {
                ThemeMode.system => Icons.brightness_auto,
                ThemeMode.light => Icons.light_mode,
                ThemeMode.dark => Icons.dark_mode,
              }),
              onPressed: () => onMode(ThemeMode.values[(mode.index + 1) % 3]),
            ),
            const SizedBox(width: 12),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'ThinkingOrb'),
              Tab(text: 'Image Generation'),
              Tab(text: 'Voice Glow'),
              Tab(text: 'Border Beam'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [OrbTab(), ImageTab(), VoiceTab(), BeamTab()],
        ),
      ),
    );
  }
}

class Stage extends StatelessWidget {
  const Stage({
    super.key,
    required this.theme,
    required this.child,
    this.height = 220,
  });
  final ThinkingOrbTheme theme;
  final Widget child;
  final double height;

  @override
  Widget build(BuildContext context) {
    final dark = theme.resolveDarkFor(context);
    // `height` is a minimum: the stage grows to fit its content (wrapped rows
    // of orbs, labels, glow bloom) instead of letting it spill over the
    // widgets below.
    return Container(
      constraints: BoxConstraints(minHeight: height),
      width: double.infinity,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF111111) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: child,
    );
  }
}

extension on ThinkingOrbTheme {
  bool resolveDarkFor(BuildContext c) =>
      this == ThinkingOrbTheme.dark ||
      (this == ThinkingOrbTheme.auto &&
          Theme.of(c).brightness == Brightness.dark);
}

class Panel extends StatelessWidget {
  const Panel({super.key, required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(top: 20),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

class Num extends StatelessWidget {
  const Num(
    this.label,
    this.value,
    this.min,
    this.max,
    this.onChanged, {
    super.key,
    this.digits = 2,
    this.unit = '',
  });
  final String label;
  final double value, min, max;
  final ValueChanged<double> onChanged;
  final int digits;
  final String unit;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(width: 118, child: Text(label)),
      Expanded(
        child: Slider(value: value, min: min, max: max, onChanged: onChanged),
      ),
      SizedBox(
        width: 64,
        child: Text(
          '${value.toStringAsFixed(digits)}$unit',
          textAlign: TextAlign.end,
        ),
      ),
    ],
  );
}

class Choice<T> extends StatelessWidget {
  const Choice(
    this.label,
    this.values,
    this.value,
    this.onChanged, {
    super.key,
    this.name,
  });
  final String label;
  final List<T> values;
  final T value;
  final ValueChanged<T> onChanged;
  final String Function(T)? name;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final v in values)
              ChoiceChip(
                label: Text(name != null ? name!(v) : (v as Enum).name),
                selected: v == value,
                onSelected: (_) => onChanged(v),
              ),
          ],
        ),
      ],
    ),
  );
}

Widget toggle(String label, bool v, ValueChanged<bool> on) => SwitchListTile(
  dense: true,
  contentPadding: EdgeInsets.zero,
  title: Text(label),
  value: v,
  onChanged: on,
);

Widget tabBody(Widget stage, List<Widget> panels) => Builder(
  builder: (context) => ListView(
    padding: EdgeInsets.fromLTRB(
      16,
      20,
      16,
      48 + MediaQuery.of(context).padding.bottom,
    ),
    children: [stage, ...panels],
  ),
);

class OrbTab extends StatefulWidget {
  const OrbTab({super.key});
  @override
  State<OrbTab> createState() => _OrbTabState();
}

class _OrbTabState extends State<OrbTab> with AutomaticKeepAliveClientMixin {
  ThinkingOrbState state = ThinkingOrbState.working;
  ThinkingOrbShape shape = ThinkingOrbShape.cycle;
  ThinkingOrbTheme theme = ThinkingOrbTheme.auto;
  double size = 64, speed = 1;
  bool paused = false, reduced = false, customLabel = false;
  String palette = 'Original mono';

  @override
  bool get wantKeepAlive => true;

  ThinkingOrb orb(ThinkingOrbState s, [double? sz]) => ThinkingOrb(
    state: s,
    shape: shape,
    size: sz ?? size,
    theme: theme,
    speed: speed,
    paused: paused,
    reducedMotion: reduced ? true : null,
    colors: kPalettes[palette]!,
    semanticLabel: customLabel ? 'Custom: ${s.name}' : null,
  );

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return tabBody(Stage(theme: theme, height: 260, child: orb(state)), [
      Panel(
        title: 'Properties',
        children: [
          Choice(
            'state',
            ThinkingOrbState.values,
            state,
            (v) => setState(() => state = v),
          ),
          if (state == ThinkingOrbState.shaping)
            Choice(
              'shape (cycle = original morph)',
              ThinkingOrbShape.values,
              shape,
              (v) => setState(() => shape = v),
            ),
          Choice(
            'theme',
            ThinkingOrbTheme.values,
            theme,
            (v) => setState(() => theme = v),
          ),
          Choice<String>(
            'colors (ThinkingOrbColors)',
            kPalettes.keys.toList(),
            palette,
            (v) => setState(() => palette = v),
            name: (s) => s,
          ),
          Num(
            'size',
            size,
            12,
            160,
            (v) => setState(() => size = v),
            digits: 0,
            unit: 'px',
          ),
          Num(
            'speed',
            speed,
            0.1,
            3,
            (v) => setState(() => speed = v),
            unit: '×',
          ),
          toggle('paused', paused, (v) => setState(() => paused = v)),
          toggle(
            'reducedMotion (static frame)',
            reduced,
            (v) => setState(() => reduced = v),
          ),
          toggle(
            'custom semanticLabel',
            customLabel,
            (v) => setState(() => customLabel = v),
          ),
          Wrap(
            spacing: 8,
            children: [
              ActionChip(
                label: const Text('size 20 (compact tuning)'),
                onPressed: () => setState(() => size = 20),
              ),
              ActionChip(
                label: const Text('size 64 (standard tuning)'),
                onPressed: () => setState(() => size = 64),
              ),
            ],
          ),
        ],
      ),
      Panel(
        title: 'All states (same properties)',
        children: [
          Stage(
            theme: theme,
            height: 420,
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 24,
              runSpacing: 24,
              children: [
                for (final s in ThinkingOrbState.values)
                  SizedBox(
                    width: 100,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(height: 100, child: Center(child: orb(s))),
                        Text(
                          s.name,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.resolveDarkFor(context)
                                ? Colors.white70
                                : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      Panel(
        title: 'Shaping — every shape',
        children: [
          Stage(
            theme: theme,
            height: 140,
            child: Wrap(
              alignment: WrapAlignment.spaceEvenly,
              spacing: 20,
              runSpacing: 20,
              children: [
                for (final sh in ThinkingOrbShape.values)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ThinkingOrb(
                        state: ThinkingOrbState.shaping,
                        shape: sh,
                        size: 64,
                        theme: theme,
                        speed: speed,
                        paused: paused,
                        colors: kPalettes[palette]!,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        sh.name,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.resolveDarkFor(context)
                              ? Colors.white70
                              : Colors.black54,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
      Panel(
        title: 'Two tuned sizes — 20 vs 64 (not a scale factor)',
        children: [
          Stage(
            theme: theme,
            height: 110,
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 20,
              runSpacing: 12,
              children: [
                for (final s in ThinkingOrbState.values)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      orb(s, 64),
                      const SizedBox(height: 6),
                      orb(s, 20),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    ]);
  }
}

// ───────────────────────── Image reveal ─────────────────────────

class ImageTab extends StatefulWidget {
  const ImageTab({super.key});
  @override
  State<ImageTab> createState() => _ImageTabState();
}

class _ImageTabState extends State<ImageTab> with AutomaticKeepAliveClientMixin {
  final controller = ThinkingImageRevealController();
  ThinkingRevealPreset preset = ThinkingRevealPreset.pixelsOrganic;
  ThinkingOrbTheme theme = ThinkingOrbTheme.auto;
  double speed = 1, width = 300, height = 300, radius = 20;
  bool autoReveal = true, paused = false;

  // Bundled artwork, so the demo works offline.
  static const sets = <String, List<ImageProvider>>{
    'Dusk + Lagoon + Meadow': [
      AssetImage('assets/dusk.png'),
      AssetImage('assets/lagoon.png'),
      AssetImage('assets/meadow.png'),
    ],
    'Dusk only': [AssetImage('assets/dusk.png')],
    'Broken URL': [NetworkImage('https://invalid.example/none.png')],
  };
  String set = 'Dusk + Lagoon + Meadow';

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final dark = theme.resolveDarkFor(context);
    final images = sets[set]!;
    return tabBody(
      Stage(
        theme: theme,
        height: 380,
        child: ThinkingImageReveal(
          controller: controller,
          images: images,
          preset: preset,
          autoReveal: autoReveal,
          width: width,
          height: height,
          borderRadius: BorderRadius.circular(radius),
          theme: theme,
          speed: speed,
          paused: paused,
        ),
      ),
      [
        Panel(title: 'Properties', children: [
          Choice<ThinkingRevealPreset>('preset', ThinkingRevealPreset.values, preset,
              (v) => setState(() => preset = v),
              name: (p) => p.label),
          Choice<String>('images', sets.keys.toList(), set, (v) => setState(() => set = v),
              name: (s) => s),
          Choice('theme', ThinkingOrbTheme.values, theme, (v) => setState(() => theme = v)),
          toggle('autoReveal (loop through the images)', autoReveal,
              (v) => setState(() => autoReveal = v)),
          toggle('paused', paused, (v) => setState(() => paused = v)),
          Wrap(spacing: 8, children: [
            FilledButton.tonalIcon(
              onPressed: controller.replay,
              icon: const Icon(Icons.replay, size: 18),
              label: const Text('Replay'),
            ),
            FilledButton.tonalIcon(
              onPressed: controller.next,
              icon: const Icon(Icons.skip_next, size: 18),
              label: const Text('Next image'),
            ),
          ]),
          const SizedBox(height: 8),
          Num('width', width, 120, 340, (v) => setState(() => width = v), digits: 0, unit: 'px'),
          Num('height', height, 120, 340, (v) => setState(() => height = v), digits: 0, unit: 'px'),
          Num('borderRadius', radius, 0, 60, (v) => setState(() => radius = v),
              digits: 0, unit: 'px'),
          Num('speed', speed, 0.25, 3, (v) => setState(() => speed = v), unit: '×'),
        ]),
        Panel(title: 'All three presets', children: [
          Stage(
            theme: theme,
            height: 460,
            child: Wrap(alignment: WrapAlignment.center, spacing: 16, runSpacing: 20, children: [
              for (final p in ThinkingRevealPreset.values)
                Column(mainAxisSize: MainAxisSize.min, children: [
                  ThinkingImageReveal(
                    images: images,
                    preset: p,
                    width: 120,
                    height: 120,
                    borderRadius: BorderRadius.circular(16),
                    theme: theme,
                    speed: speed,
                    paused: paused,
                  ),
                  const SizedBox(height: 8),
                  Text(p.label,
                      style: TextStyle(fontSize: 12, color: dark ? Colors.white70 : Colors.black54)),
                ]),
            ]),
          ),
        ]),
      ],
    );
  }
}

// ───────────────────────── Voice glow ─────────────────────────

class VoiceTab extends StatefulWidget {
  const VoiceTab({super.key});
  @override
  State<VoiceTab> createState() => _VoiceTabState();
}

class _VoiceTabState extends State<VoiceTab>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  ThinkingVoiceGlowType type = ThinkingVoiceGlowType.standard;
  ThinkingGlowVariant variant = ThinkingGlowVariant.colorful;
  ThinkingOrbTheme theme = ThinkingOrbTheme.auto;
  double level = 0.6, strength = 1, reach = 1, spread = 1, flow = 1, idle = 0.12, speed = 1;
  double sensitivity = 1, threshold = 0.04, attack = 0.06, release = 0.35;
  bool paused = false, processing = false, simulate = true;
  late final AnimationController _sim =
      AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _sim.dispose();
    super.dispose();
  }

  /// Stand-in for a microphone meter: a few sines that never quite repeat,
  /// with brief gaps like pauses between words.
  double _level(double t) {
    final x = t * 2 * math.pi;
    final v = 0.5 + 0.3 * math.sin(x * 2) + 0.2 * math.sin(x * 5 + 1);
    final gap = (math.sin(x * 1) * 3).clamp(-1.0, 1.0) * 0.5 + 0.5;
    return (v * (0.25 + 0.75 * gap)).clamp(0.0, 1.0);
  }

  BorderRadius _radius(ThinkingVoiceGlowType g) => switch (g) {
        ThinkingVoiceGlowType.standard => BorderRadius.circular(28),
        ThinkingVoiceGlowType.pill => BorderRadius.circular(22),
        ThinkingVoiceGlowType.mobile =>
          const BorderRadius.vertical(bottom: Radius.circular(36)),
      };

  Widget _host(ThinkingVoiceGlowType g, bool dark) {
    final fill = dark ? const Color(0xFF1C1C1F) : Colors.white;
    final fg = dark ? Colors.white54 : Colors.black45;
    final decoration = BoxDecoration(
      color: fill,
      borderRadius: _radius(g),
      border: Border.all(color: dark ? Colors.white12 : Colors.black12),
    );
    return switch (g) {
      ThinkingVoiceGlowType.standard => Container(
          width: 350,
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: decoration,
          child: Row(children: [
            Expanded(child: Text('Message…', style: TextStyle(color: fg, fontSize: 16))),
            Icon(Icons.mic_none, color: fg),
          ]),
        ),
      ThinkingVoiceGlowType.pill => Container(
          width: 150,
          height: 44,
          alignment: Alignment.center,
          decoration: decoration,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.fiber_manual_record, size: 12, color: Colors.redAccent.shade200),
            const SizedBox(width: 8),
            Text('Recording', style: TextStyle(color: fg)),
          ]),
        ),
      ThinkingVoiceGlowType.mobile => Container(
          width: 250,
          height: 150,
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: 18),
          decoration: decoration,
          child: Text('Listening…', style: TextStyle(color: fg, fontSize: 16)),
        ),
    };
  }

  Widget _glow(ThinkingVoiceGlowType g, bool dark, double lvl) => ThinkingVoiceGlow(
        type: g,
        level: lvl,
        processing: processing,
        colorVariant: variant,
        borderRadius: _radius(g),
        theme: theme,
        strength: strength,
        sensitivity: sensitivity,
        threshold: threshold,
        attack: attack,
        release: release,
        reach: reach,
        spread: spread,
        flow: flow,
        idle: idle,
        speed: speed,
        paused: paused,
        child: _host(g, dark),
      );

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final dark = theme.resolveDarkFor(context);
    return tabBody(
      Stage(
        theme: theme,
        height: 280,
        child: AnimatedBuilder(
          animation: _sim,
          builder: (context, _) => _glow(type, dark, simulate ? _level(_sim.value) : level),
        ),
      ),
      [
        Panel(title: 'Properties', children: [
          Choice<ThinkingVoiceGlowType>('type', ThinkingVoiceGlowType.values, type,
              (v) => setState(() => type = v),
              name: (g) => g.name),
          Choice<ThinkingGlowVariant>('colorVariant', ThinkingGlowVariant.values, variant,
              (v) => setState(() => variant = v)),
          Choice('theme', ThinkingOrbTheme.values, theme, (v) => setState(() => theme = v)),
          toggle('processing (gather into a travelling beam)', processing,
              (v) => setState(() => processing = v)),
          toggle('simulate a live mic level', simulate, (v) => setState(() => simulate = v)),
          if (!simulate) Num('level', level, 0, 1, (v) => setState(() => level = v)),
          toggle('paused', paused, (v) => setState(() => paused = v)),
          Num('strength', strength, 0, 1, (v) => setState(() => strength = v)),
          Num('speed', speed, 0.2, 3, (v) => setState(() => speed = v), unit: '×'),
        ]),
        Panel(title: 'Input chain', children: [
          Num('sensitivity', sensitivity, 0.2, 3, (v) => setState(() => sensitivity = v), unit: '×'),
          Num('threshold', threshold, 0, 0.5, (v) => setState(() => threshold = v)),
          Num('attack', attack, 0.01, 0.5, (v) => setState(() => attack = v), unit: ' s'),
          Num('release', release, 0.05, 1.5, (v) => setState(() => release = v), unit: ' s'),
        ]),
        Panel(title: 'Shape', children: [
          Num('reach', reach, 0.4, 2, (v) => setState(() => reach = v), unit: '×'),
          Num('spread', spread, 0.5, 2, (v) => setState(() => spread = v), unit: '×'),
          Num('flow', flow, 0, 3, (v) => setState(() => flow = v), unit: '×'),
          Num('idle', idle, 0, 0.5, (v) => setState(() => idle = v)),
        ]),
        Panel(title: 'All three types', children: [
          Stage(
            theme: theme,
            height: 440,
            child: AnimatedBuilder(
              animation: _sim,
              builder: (context, _) => Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 36,
                children: [
                  for (final g in ThinkingVoiceGlowType.values)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: _glow(g, dark, simulate ? _level(_sim.value) : level),
                    ),
                ],
              ),
            ),
          ),
        ]),
      ],
    );
  }
}

// ───────────────────────── Beam ─────────────────────────

class BeamTab extends StatefulWidget {
  const BeamTab({super.key});
  @override
  State<BeamTab> createState() => _BeamTabState();
}

class _BeamTabState extends State<BeamTab> with AutomaticKeepAliveClientMixin {
  ThinkingOrbTheme theme = ThinkingOrbTheme.auto;
  ThinkingBeamSize size = ThinkingBeamSize.md;
  ThinkingGlowVariant variant = ThinkingGlowVariant.colorful;
  double strength = 0.85, speed = 1, radius = 20, boxW = 260, boxH = 120, lap = 3.2;
  bool paused = false;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final dark = theme.resolveDarkFor(context);
    final fg = dark ? Colors.white70 : Colors.black54;

    Widget card({
      required ThinkingBeamSize sz,
      double? w,
      double? h,
      double r = 20,
      String label = 'Any widget can be framed',
      Widget? content,
    }) =>
        ThinkingBeam(
          size: sz,
          colorVariant: variant,
          strength: strength,
          theme: theme,
          paused: paused,
          speed: speed,
          duration: Duration(milliseconds: (lap * 1000).round()),
          borderRadius: BorderRadius.circular(r),
          child: Container(
            width: w,
            height: h,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: dark ? const Color(0xFF1A1A1E) : Colors.white,
              borderRadius: BorderRadius.circular(r),
            ),
            child: content ?? Text(label, textAlign: TextAlign.center, style: TextStyle(color: fg)),
          ),
        );

    return tabBody(
      Stage(theme: theme, height: 280, child: card(sz: size, w: boxW, h: boxH, r: radius)),
      [
        Panel(title: 'Properties', children: [
          Choice<ThinkingBeamSize>('size', ThinkingBeamSize.values, size,
              (v) => setState(() => size = v),
              name: (b) => b.label),
          Choice<ThinkingGlowVariant>('colorVariant', ThinkingGlowVariant.values, variant,
              (v) => setState(() => variant = v)),
          Choice('theme', ThinkingOrbTheme.values, theme, (v) => setState(() => theme = v)),
          toggle('paused', paused, (v) => setState(() => paused = v)),
          Num('strength', strength, 0, 1, (v) => setState(() => strength = v)),
          Num('speed', speed, 0.2, 3, (v) => setState(() => speed = v), unit: '×'),
          Num('lap time', lap, 0.8, 10, (v) => setState(() => lap = v), digits: 1, unit: ' s'),
          Num('borderRadius', radius, 0, 60, (v) => setState(() => radius = v),
              digits: 0, unit: 'px'),
          Num('child width', boxW, 120, 340, (v) => setState(() => boxW = v), digits: 0, unit: 'px'),
          Num('child height', boxH, 50, 200, (v) => setState(() => boxH = v), digits: 0, unit: 'px'),
        ]),
        Panel(title: 'All five sizes', children: [
          Stage(
            theme: theme,
            height: 520,
            child: Wrap(alignment: WrapAlignment.center, spacing: 28, runSpacing: 32, children: [
              for (final b in ThinkingBeamSize.values)
                card(sz: b, w: 130, h: 80, r: 16, label: b.label),
            ]),
          ),
        ]),
        Panel(title: 'In context', children: [
          Stage(
            theme: theme,
            height: 200,
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 24,
              runSpacing: 24,
              children: [
                card(
                  sz: ThinkingBeamSize.md,
                  r: 28,
                  h: 56,
                  content: Row(mainAxisSize: MainAxisSize.min, children: [
                    ThinkingOrb(size: 20, state: ThinkingOrbState.searching, theme: theme),
                    const SizedBox(width: 10),
                    Text('Searching…', style: TextStyle(color: fg)),
                  ]),
                ),
                card(
                  sz: ThinkingBeamSize.sm,
                  r: 16,
                  w: 220,
                  h: 56,
                  content: Row(children: [
                    Expanded(child: Text('Ask anything…', style: TextStyle(color: fg))),
                    Icon(Icons.arrow_upward, size: 18, color: fg),
                  ]),
                ),
              ],
            ),
          ),
        ]),
      ],
    );
  }
}
