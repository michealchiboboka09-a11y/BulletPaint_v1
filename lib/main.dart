import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';

void main() {
  runApp(const BulletPaintApp());
}

class DrawingPoint {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;
  final bool isEraser;
  DrawingPoint({required this.points, required this.color, required this.strokeWidth, this.isEraser = false});
}

class BulletPaintApp extends StatelessWidget {
  const BulletPaintApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BulletPaint v1',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.grey[900],
        appBarTheme: AppBarTheme(backgroundColor: Colors.grey[850]),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey<RenderRepaintBoundary> _globalKey = GlobalKey<RenderRepaintBoundary>();
  List<DrawingPoint> _points = [];
  Color _selectedColor = Colors.white;
  double _strokeWidth = 5.0;
  bool _isEraser = false;

  void _undo() {
    if (_points.isNotEmpty) {
      setState(() {
        _points.removeLast();
      });
    }
  }

  Future<void> _saveImage() async {
    try {
      RenderRepaintBoundary boundary = _globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData!= null) {
        final hasAccess = await Gal.requestAccess();
        if (hasAccess) {
          await Gal.putImageBytes(byteData.buffer.asUint8List());
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved to Gallery!')));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BulletPaint v1'), actions: [
        IconButton(icon: const Icon(Icons.undo), onPressed: _undo),
        IconButton(icon: const Icon(Icons.save), onPressed: _saveImage),
      ]),
      body: LayoutBuilder(builder: (context, constraints) {
        bool isLandscape = constraints.maxWidth > constraints.maxHeight;
        return Flex(
          direction: isLandscape? Axis.horizontal : Axis.vertical,
          children: [
            if (isLandscape) _buildToolbar(true),
            Expanded(
              child: GestureDetector(
                onPanStart: (details) {
                  setState(() {
                    _points.add(DrawingPoint(
                      points: [details.localPosition],
                      color: _selectedColor,
                      strokeWidth: _strokeWidth,
                      isEraser: _isEraser,
                    ));
                  });
                },
                onPanUpdate: (details) {
                  setState(() {
                    _points.last.points.add(details.localPosition);
                  });
                },
                child: RepaintBoundary(
                  key: _globalKey,
                  child: Container(
                    color: Colors.grey[900],
                    child: CustomPaint(painter: CanvasPainter(_points), size: Size.infinite),
                  ),
                ),
              ),
            ),
            if (!isLandscape) _buildToolbar(false),
          ],
        );
      }),
    );
  }

  Widget _buildToolbar(bool vertical) {
    return Container(
      color: Colors.grey[850],
      padding: const EdgeInsets.all(8),
      child: Flex(
        direction: vertical? Axis.vertical : Axis.horizontal,
        children: [
          IconButton(icon: Icon(Icons.brush, color: _isEraser? Colors.white : Colors.blue), onPressed: () => setState(() => _isEraser = false)),
          IconButton(icon: Icon(Icons.cleaning_services, color: _isEraser? Colors.blue : Colors.white), onPressed: () => setState(() => _isEraser = true)),
          Slider(value: _strokeWidth, min: 1, max: 50, onChanged: (v) => setState(() => _strokeWidth = v)),
        ],
      ),
    );
  }
}

class CanvasPainter extends CustomPainter {
  final List<DrawingPoint> points;
  CanvasPainter(this.points);
  @override
  void paint(Canvas canvas, Size size) {
    for (var d in points) {
      Paint paint = Paint()
       ..color = d.isEraser? Colors.grey[900]! : d.color
       ..strokeCap = StrokeCap.round
       ..strokeWidth = d.strokeWidth;
      for (int i = 0; i < d.points.length - 1; i++) {
        canvas.drawLine(d.points[i], d.points[i + 1], paint);
      }
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
