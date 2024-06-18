// lib/screens/full_screen_image_page.dart
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

class FullScreenImagePage extends StatefulWidget {
  final String imagePath;

  FullScreenImagePage({required this.imagePath});

  @override
  _FullScreenImagePageState createState() => _FullScreenImagePageState();
}

class _FullScreenImagePageState extends State<FullScreenImagePage> {
  bool isEditing = false;
  Offset? startPoint;
  Offset? endPoint;
  late TransformationController _transformationController;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void postData(String imageName, List<List<int>> contour) async {
    var datas = {
      "imageName": imageName,
      "contour": contour
    };

    var serverUrl = 'http://8.138.119.19:8000/feedback/';
    var response = await http.post(Uri.parse(serverUrl),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(datas));

    print(response.body);
    print(response.statusCode);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Thank you for your feedback!'),
          content: Text('The model will be improved based on this.'),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              transformationController: _transformationController,
              panEnabled: !isEditing, // 允许平移
              scaleEnabled: !isEditing, // 允许缩放
              minScale: 1.0,
              maxScale: 5.0,
              child: GestureDetector(
                onPanStart: isEditing ? (details) {
                  setState(() {
                    startPoint = details.localPosition;
                    endPoint = null;
                  });
                } : null,
                onPanUpdate: isEditing ? (details) {
                  setState(() {
                    endPoint = details.localPosition;
                  });
                } : null,
                onPanEnd: isEditing ? (details) {
                  setState(() {
                    // 编辑完成，矩形框选已确定
                  });
                } : null,
                child: CustomPaint(
                  foregroundPainter: RectanglePainter(startPoint, endPoint),
                  child: Image.file(
                    File(widget.imagePath),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton(
              onPressed: () {
                if (isEditing) {
                  // 返回矩形的左上角和右下角的坐标
                  if (startPoint != null && endPoint != null) {
                    final topLeft = _transformationController.toScene(startPoint!);
                    final bottomRight = _transformationController.toScene(endPoint!);

                    final contour = [
                      [topLeft.dx.toInt(), topLeft.dy.toInt()],
                      [bottomRight.dx.toInt(), bottomRight.dy.toInt()]
                    ];

                    postData(widget.imagePath.split('/').last, contour);
                  }
                  setState(() {
                    isEditing = false;
                  });
                } else {
                  setState(() {
                    isEditing = true;
                  });
                }
              },
              child: Icon(isEditing ? Icons.check : Icons.edit),
              mini: true,
              backgroundColor: Colors.white.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class RectanglePainter extends CustomPainter {
  final Offset? startPoint;
  final Offset? endPoint;

  RectanglePainter(this.startPoint, this.endPoint);

  @override
  void paint(Canvas canvas, Size size) {
    if (startPoint != null && endPoint != null) {
      final paint = Paint()
        ..color = Colors.blue.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      final rect = Rect.fromPoints(startPoint!, endPoint!);
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
