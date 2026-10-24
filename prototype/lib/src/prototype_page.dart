import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pastello_engine/pastello_engine.dart';

import 'perf_stats.dart';
import 'sheet_view.dart';
import 'tokens.dart';

/// Tools available in the prototype: the drawing tools plus the eraser.
enum ProtoTool {
  pencil('✏️', 'Matita', StrokeTool.pencil, WidthPreset.thin),
  marker('🖊️', 'Pennarello', StrokeTool.marker, WidthPreset.medium),
  brush('🖌️', 'Pennello', StrokeTool.brush, WidthPreset.thick),
  crayon('🖍️', 'Pastello', StrokeTool.crayon, WidthPreset.medium),
  rainbow('🌈', 'Arcobaleno', StrokeTool.rainbow, WidthPreset.medium),
  eraser('🧽', 'Gomma', null, WidthPreset.thick);

  const ProtoTool(this.emoji, this.label, this.strokeTool, this.defaultWidth);

  final String emoji;
  final String label;

  /// `null` for the eraser.
  final StrokeTool? strokeTool;

  /// Initial width (F-06); each tool then remembers its own.
  final WidthPreset defaultWidth;
}

class PrototypePage extends StatefulWidget {
  const PrototypePage({super.key});

  @override
  State<PrototypePage> createState() => _PrototypePageState();
}

class _PrototypePageState extends State<PrototypePage>
    with SingleTickerProviderStateMixin {
  final PaperGrain _grain = PaperGrain.generate();
  late final DrawingRenderer _renderer = DrawingRenderer(grain: _grain);
  final LiveStroke _live = LiveStroke();
  late final PerfStats _perf = PerfStats(this);

  CommandStack? _stack;
  ProtoTool _tool = ProtoTool.crayon;
  Color _color = Tokens.drawingColors.first;
  final Map<ProtoTool, WidthPreset> _widths = {
    for (final t in ProtoTool.values) t: t.defaultWidth,
  };
  bool _showPerf = true;
  bool _rotationLocked = false;
  String? _lastStressResult;

  @override
  void dispose() {
    _perf.dispose();
    _live.dispose();
    _renderer.dispose();
    _grain.dispose();
    super.dispose();
  }

  /// The sheet takes the shape of the available space when it is created
  /// and keeps it afterwards (D-05).
  CommandStack _stackFor(Size available) {
    return _stack ??= () {
      final stack = CommandStack(Drawing(sheetSize: available));
      _renderer.show(stack.drawing);
      return stack;
    }();
  }

  void _execute(DrawingCommand command) {
    setState(() => _stack!.execute(command));
    _renderer.show(_stack!.drawing);
  }

  void _onStrokeStart() {
    _live.begin(
      tool: _tool.strokeTool,
      color: _color,
      width: _widths[_tool]!.width,
    );
  }

  void _onStrokeEnd() {
    final stack = _stack!;
    final points = simplify(_live.points, 0.35);
    final tool = _tool.strokeTool;
    if (tool == null) {
      final command = EraseCommand.forDrawing(
        stack.drawing,
        points,
        _live.width,
      );
      if (command != null) {
        setState(() => stack.execute(command));
        _renderer.showErased(stack.drawing, command.erasure);
      }
    } else {
      _execute(
        AddStrokeCommand(
          StrokeElement(
            id: newElementId(),
            tool: tool,
            color: _color,
            width: _live.width,
            points: points,
          ),
        ),
      );
    }
    _live.clear();
  }

  void _undo() {
    if (_stack!.undo()) {
      setState(() {});
      _renderer.show(_stack!.drawing);
    }
  }

  void _redo() {
    if (_stack!.redo()) {
      setState(() {});
      _renderer.show(_stack!.drawing);
    }
  }

  void _clear() {
    if (_stack!.drawing.isEmpty) return;
    _execute(ClearCommand(_stack!.drawing.elements));
  }

  void _toggleRotationLock() {
    setState(() => _rotationLocked = !_rotationLocked);
    final orientation = MediaQuery.orientationOf(context);
    SystemChrome.setPreferredOrientations(
      !_rotationLocked
          ? const []
          : orientation == Orientation.landscape
          ? const [
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]
          : const [DeviceOrientation.portraitUp],
    );
  }

  /// Adds [count] random strokes to measure the engine under load.
  void _stress(int count) {
    final stack = _stack!;
    final size = stack.drawing.sheetSize;
    final random = math.Random(count);
    final watch = Stopwatch()..start();
    var drawing = stack.drawing;
    final tools = StrokeTool.values;
    for (var i = 0; i < count; i++) {
      var x = random.nextDouble() * size.width;
      var y = random.nextDouble() * size.height;
      var angle = random.nextDouble() * math.pi * 2;
      final points = <SheetPoint>[];
      final length = 30 + random.nextInt(90);
      for (var j = 0; j < length; j++) {
        angle += (random.nextDouble() - 0.5) * 0.6;
        x = (x + math.cos(angle) * 6).clamp(0, size.width);
        y = (y + math.sin(angle) * 6).clamp(0, size.height);
        points.add(SheetPoint(x, y, time: j * (4 + random.nextInt(20))));
      }
      drawing = AddStrokeCommand(
        StrokeElement(
          id: newElementId(),
          tool: tools[random.nextInt(tools.length)],
          color: Tokens.drawingColors[random.nextInt(11)],
          width: WidthPreset.values[random.nextInt(3)].width,
          points: points,
        ),
      ).apply(drawing);
    }
    final generated = watch.elapsedMilliseconds;
    setState(() {
      // Recorded as a single undoable step.
      stack.execute(_ReplaceCommand(stack.drawing, drawing));
    });
    _renderer.show(stack.drawing);
    _lastStressResult =
        '+$count tratti: generati in $generated ms, cache ricostruita in '
        '${_renderer.lastCacheUpdate.inMilliseconds} ms';
  }

  @override
  Widget build(BuildContext context) {
    final landscape =
        MediaQuery.sizeOf(context).width >= MediaQuery.sizeOf(context).height;
    final sheet = Padding(
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stack = _stackFor(constraints.biggest);
          return Stack(
            children: [
              Positioned.fill(
                child: SheetView(
                  sheetSize: stack.drawing.sheetSize,
                  renderer: _renderer,
                  live: _live,
                  onStrokeStart: _onStrokeStart,
                  onStrokeEnd: _onStrokeEnd,
                ),
              ),
              if (_showPerf)
                Positioned(left: 8, top: 8, child: _perfPanel(stack)),
            ],
          );
        },
      ),
    );

    final tools = [
      for (final t in ProtoTool.values)
        _ToolButton(
          tool: t,
          selected: t == _tool,
          onTap: () => setState(() => _tool = t),
        ),
    ];
    final colors = [
      for (final c in Tokens.drawingColors)
        _ColorDot(
          color: c,
          selected: c == _color,
          onTap: () => setState(() => _color = c),
        ),
    ];
    final widths = [
      for (final w in WidthPreset.values)
        _WidthDot(
          preset: w,
          color: _tool == ProtoTool.eraser ? Tokens.graphite : _color,
          selected: _widths[_tool] == w,
          onTap: () => setState(() => _widths[_tool] = w),
        ),
    ];

    return Scaffold(
      backgroundColor: Tokens.paper,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            const Divider(height: 1.5, thickness: 1.5, color: Tokens.border),
            Expanded(
              child: landscape
                  ? Row(
                      children: [
                        _scrollColumn(tools),
                        Expanded(child: sheet),
                        _scrollColumn([
                          Wrap(children: colors),
                          const SizedBox(height: 8),
                          ...widths,
                        ], width: 124),
                      ],
                    )
                  : Column(
                      children: [
                        Expanded(child: sheet),
                        _scrollRow([...colors, ...widths]),
                        _scrollRow(tools),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    final stack = _stack;
    return SizedBox(
      height: 64,
      child: Row(
        children: [
          const SizedBox(width: 12),
          _ActionButton(
            icon: Icons.undo_rounded,
            tooltip: 'Annulla',
            onTap: stack?.canUndo ?? false ? _undo : null,
          ),
          _ActionButton(
            icon: Icons.redo_rounded,
            tooltip: 'Ripeti',
            onTap: stack?.canRedo ?? false ? _redo : null,
          ),
          _ActionButton(
            icon: Icons.layers_clear_rounded,
            tooltip: 'Pulisci foglio',
            onTap: _clear,
          ),
          const Spacer(),
          _ActionButton(
            icon: Icons.add_chart_rounded,
            tooltip: 'Genera 100 tratti',
            label: '+100',
            onTap: () => _stress(100),
          ),
          _ActionButton(
            icon: Icons.add_chart_rounded,
            tooltip: 'Genera 500 tratti',
            label: '+500',
            onTap: () => _stress(500),
          ),
          _ActionButton(
            icon: _renderer.cacheEnabled
                ? Icons.flash_on_rounded
                : Icons.flash_off_rounded,
            tooltip: 'Immagine pronta (cache) sì/no',
            label: _renderer.cacheEnabled ? 'cache' : 'no cache',
            active: _renderer.cacheEnabled,
            onTap: () => setState(
              () => _renderer.cacheEnabled = !_renderer.cacheEnabled,
            ),
          ),
          _ActionButton(
            icon: Icons.speed_rounded,
            tooltip: 'Pannello misure',
            active: _showPerf,
            onTap: () => setState(() => _showPerf = !_showPerf),
          ),
          _ActionButton(
            icon: _rotationLocked
                ? Icons.screen_lock_rotation_rounded
                : Icons.screen_rotation_rounded,
            tooltip: 'Blocca rotazione',
            active: _rotationLocked,
            onTap: _toggleRotationLock,
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }

  Widget _perfPanel(CommandStack stack) {
    final drawing = stack.drawing;
    final points = drawing.elements.fold<int>(
      0,
      (sum, e) => sum + e.points.length,
    );
    return IgnorePointer(
      child: ListenableBuilder(
        listenable: Listenable.merge([_perf, _renderer]),
        builder: (context, _) {
          final lines = [
            'FPS ${_perf.fps.toStringAsFixed(0)} · '
                'frame peggiore ${_perf.worstInterval.toStringAsFixed(1)} ms',
            if (_perf.hasEngineTimings) ...[
              'build ${_perf.build.avg.toStringAsFixed(1)} ms '
                  '(max ${_perf.build.max.toStringAsFixed(1)})',
              'raster ${_perf.raster.avg.toStringAsFixed(1)} ms '
                  '(max ${_perf.raster.max.toStringAsFixed(1)})',
            ],
            'tratti ${drawing.elements.length} · punti $points',
            'cache ${_renderer.cacheEnabled ? 'sì' : 'no'} · ultimo '
                '${_renderer.lastUpdateWasRebuild ? 'rebuild' : 'aggiornamento'} '
                '${(_renderer.lastCacheUpdate.inMicroseconds / 1000).toStringAsFixed(1)} ms',
            ?_lastStressResult,
          ];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Tokens.ink.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              lines.join('\n'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                height: 1.35,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _scrollColumn(List<Widget> children, {double width = 84}) => SizedBox(
    width: width,
    child: SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(children: children),
    ),
  );

  Widget _scrollRow(List<Widget> children) => SizedBox(
    height: 72,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(children: children),
    ),
  );
}

/// Replaces the whole drawing (used by the stress test).
class _ReplaceCommand implements DrawingCommand {
  _ReplaceCommand(this.before, this.after);

  final Drawing before;
  final Drawing after;

  @override
  Drawing apply(Drawing drawing) => after;

  @override
  Drawing revert(Drawing drawing) => before;
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.tool,
    required this.selected,
    required this.onTap,
  });

  final ProtoTool tool;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Tooltip(
        message: tool.label,
        child: Material(
          color: selected ? Tokens.coralLight : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: selected ? Tokens.coral : Colors.transparent,
              width: 3,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: SizedBox(
              width: 64,
              height: 64,
              child: Center(
                child: Text(tool.emoji, style: const TextStyle(fontSize: 32)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 58,
        height: 56,
        alignment: Alignment.center,
        child: Container(
          width: selected ? 36 : 42,
          height: selected ? 36 : 42,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Tokens.ink.withValues(alpha: 0.12)),
            boxShadow: selected
                ? const [
                    BoxShadow(color: Tokens.paper, spreadRadius: 3),
                    BoxShadow(color: Tokens.ink, spreadRadius: 6),
                  ]
                : null,
          ),
        ),
      ),
    );
  }
}

class _WidthDot extends StatelessWidget {
  const _WidthDot({
    required this.preset,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final WidthPreset preset;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final size = 6.0 + preset.index * 9;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 112,
        height: 48,
        margin: const EdgeInsets.all(2),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? Tokens.skyLight : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Tokens.sky : Colors.transparent,
            width: 2,
          ),
        ),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Tokens.ink.withValues(alpha: 0.2)),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.label,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final String? label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: active ? Tokens.sunLight : Tokens.sheet,
          elevation: 1,
          shadowColor: Tokens.ink.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: active ? Tokens.sun : Colors.transparent,
              width: 2,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Container(
              height: 48,
              constraints: const BoxConstraints(minWidth: 48),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    color: enabled ? Tokens.ink : Tokens.border,
                    size: 26,
                  ),
                  if (label != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      label!,
                      style: const TextStyle(
                        color: Tokens.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
