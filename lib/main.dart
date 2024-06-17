import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:image/image.dart' as img;
import 'full_screen_image_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with AutomaticKeepAliveClientMixin {
  int _currentIndex = 0;

  final List<Widget> _children = [
    ImagePickerDemo(),
    BatchProcessingScreen(),
    HistoryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    super.build(context); // Ensure to call super.build

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _children,
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 10.0),
        child: GNav(
          gap: 8,
          activeColor: Colors.white,
          color: Colors.black,
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          tabBackgroundColor: Colors.purple.shade100,
          selectedIndex: _currentIndex,
          onTabChange: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          tabs: [
            GButton(
              icon: Icons.home,
              text: 'Main',
            ),
            GButton(
              icon: Icons.batch_prediction,
              text: 'Batch Processing',
            ),
            GButton(
              icon: Icons.history,
              text: 'History',
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class ImagePickerDemo extends StatefulWidget {
  @override
  _ImagePickerDemoState createState() => _ImagePickerDemoState();
}

class _ImagePickerDemoState extends State<ImagePickerDemo> {
  File? _image;
  Uint8List? _blendedImage;
  final picker = ImagePicker();
  double _sliderValue = 0.5;
  final String defaultUrl = 'http://8.138.119.19:8000/upload/';
  Timer? _debounce;
  String? _currentImageDir;

  Future<void> _pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    setState(() {
      if (pickedFile != null) {
        _image = File(pickedFile.path);
        _blendedImage = null; // 选择新图片时清除混合图片
        _blendedImages.clear(); // 清除之前的混合图片
      }
    });
  }

  Future<void> _uploadImage() async {
    if (_image == null) {
      _showSnackBar('请先选择图片');
      return;
    }

    var url = Uri.parse(defaultUrl);
    var request = http.MultipartRequest('POST', url);
    request.headers['accept'] = 'application/json';
    request.headers['Content-Type'] = 'multipart/form-data';

    request.files.add(await http.MultipartFile.fromPath(
      'file',
      _image!.path,
    ));

    request.fields['sliderValue'] = _sliderValue.toString();

    try {
      var response = await request.send();
      if (response.statusCode == 200) {
        http.Response res = await http.Response.fromStream(response);
        Uint8List responseData = res.bodyBytes;
        _generateBlendedImages(responseData); // 生成混合图片
        await _saveToHistory(responseData);
        if (mounted) {
          _showSnackBar('图片上传和混合成功');
        }
      } else {
        if (mounted) {
          _showSnackBar('图片上传失败. 错误代码: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('图片上传过程中发生错误: $e');
      }
    }
  }

  List<Uint8List> _blendedImages = [];

  Future<void> _generateBlendedImages(Uint8List responseData) async {
    if (_image == null) {
      return;
    }

    _blendedImages.clear(); // 清除之前的混合图片

    try {
      final image1 = img.decodeImage(_image!.readAsBytesSync())!;
      final image2 = img.decodeImage(responseData)!;

      final resizedImage2 = img.copyResize(image2, width: image1.width, height: image1.height);

      for (int i = 0; i <= 10; i++) {
        final double blendRatio = i / 10.0;
        final blendedImage = img.Image(image1.width, image1.height);

        for (int y = 0; y < image1.height; y++) {
          for (int x = 0; x < image1.width; x++) {
            final pixel1 = image1.getPixel(x, y);
            final pixel2 = resizedImage2.getPixel(x, y);
            final r = (img.getRed(pixel1) * blendRatio + img.getRed(pixel2) * (1 - blendRatio)).toInt();
            final g = (img.getGreen(pixel1) * blendRatio + img.getGreen(pixel2) * (1 - blendRatio)).toInt();
            final b = (img.getBlue(pixel1) * blendRatio + img.getBlue(pixel2) * (1 - blendRatio)).toInt();
            final a = (img.getAlpha(pixel1) * blendRatio + img.getAlpha(pixel2) * (1 - blendRatio)).toInt();
            blendedImage.setPixel(x, y, img.getColor(r, g, b, a));
          }
        }
        _blendedImages.add(Uint8List.fromList(img.encodePng(blendedImage)));
      }

      setState(() {
        _blendedImage = _blendedImages[(10 * _sliderValue).round()]; // 设置初始显示的混合图片
      });

    } catch (e) {
      _showSnackBar('图像处理过程中发生错误: $e');
    }
  }

  Future<void> _saveToHistory(Uint8List responseData) async {
    if (_image == null) {
      return;
    }

    try {
      final directory = await getTemporaryDirectory();
      final historyDir = Directory('${directory.path}/history');
      if (!await historyDir.exists()) {
        await historyDir.create();
      }
      final timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
      final imageDir = Directory('${historyDir.path}/$timestamp');
      await imageDir.create();

      final originalImageFile = File('${imageDir.path}/original.png');
      final blendedImageFile = File('${imageDir.path}/blended.png');

      await originalImageFile.writeAsBytes(_image!.readAsBytesSync());
      await blendedImageFile.writeAsBytes(responseData);

      _currentImageDir = imageDir.path;

      print('图片已保存到: ${imageDir.path}');
    } catch (e) {
      print('保存图片过程中发生错误: $e');
    }
  }

  Future<void> _saveCurrentBlendedImage() async {
    if (_currentImageDir == null || _blendedImage == null) {
      _showSnackBar('没有图片可保存');
      return;
    }

    try {
      final blendedImageFile = File('$_currentImageDir/blended_${(_sliderValue * 10).round()}.png');
      await blendedImageFile.writeAsBytes(_blendedImage!);

      print('混合图片已保存到: ${blendedImageFile.path}');
      _showSnackBar('混合图片保存成功');
    } catch (e) {
      print('保存混合图片过程中发生错误: $e');
      _showSnackBar('保存混合图片失败');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showFullScreenImage(String imagePath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenImagePage(imagePath: imagePath),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'ClearShot',
          style: GoogleFonts.lobster(
            fontSize: 28,
            fontWeight: FontWeight.w300,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              SizedBox(height: 20),
              Container(
                width: MediaQuery.of(context).size.width * 0.9,
                height: MediaQuery.of(context).size.height * 0.5,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey, width: 2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _buildImageView(),
              ),
              SizedBox(height: 20),
              Slider(
                value: _sliderValue,
                min: 0,
                max: 1,
                divisions: 10,
                label: _sliderValue.toStringAsFixed(1),
                onChanged: (double value) {
                  setState(() {
                    _sliderValue = value;
                    _blendedImage = _blendedImages[(value * 10).round()]; // 更新显示的混合图片
                  });
                },
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _pickImage,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    ),
                    child: Text('选择图片'),
                  ),
                  SizedBox(width: 20),
                  ElevatedButton(
                    onPressed: _uploadImage,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    ),
                    child: Text('上传图片'),
                  ),
                  SizedBox(width: 20),
                  ElevatedButton(
                    onPressed: _saveCurrentBlendedImage,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    ),
                    child: Text('保存图片'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageView() {
    if (_blendedImages.isNotEmpty) {
      return GestureDetector(
        onTap: () {
          // 显示全屏图片
        },
        child: Image.memory(_blendedImage!, fit: BoxFit.cover),
      );
    } else if (_image != null) {
      return GestureDetector(
        onTap: () {
          // 显示全屏图片
        },
        child: Image.file(_image!, fit: BoxFit.cover),
      );
    } else {
      return GestureDetector(
        onTap: () {
          // 加载默认图片
        },
        child: Image.asset('images/default1.jpg', fit: BoxFit.cover),
      );
    }
  }

  Future<Uint8List?> _loadAssetImage(String assetPath) async {
    try {
      final byteData = await rootBundle.load(assetPath);
      return byteData.buffer.asUint8List();
    } catch (e) {
      print('加载资产图片时发生错误: $e');
      return null;
    }
  }

  Future<String?> _saveTempImage(Uint8List imageBytes) async {
    try {
      final directory = await getTemporaryDirectory();
      final imagePath = '${directory.path}/temp_image.png';
      final imageFile = File(imagePath);
      await imageFile.writeAsBytes(imageBytes);
      return imagePath;
    } catch (e) {
      print('保存临时图像时发生错误: $e');
      return null;
    }
  }

  @override
  bool get wantKeepAlive => true;
}

class BatchProcessingScreen extends StatefulWidget {
  @override
  _BatchProcessingScreenState createState() => _BatchProcessingScreenState();
}

class _BatchProcessingScreenState extends State<BatchProcessingScreen> {
  List<XFile>? _imageFiles;
  final picker = ImagePicker();
  double _sliderValue = 0.5;

  // Pick multiple images
  Future<void> _pickMultipleImages() async {
    final pickedFiles = await picker.pickMultiImage();
    setState(() {
      if (pickedFiles != null && pickedFiles.length <= 9) {
        _imageFiles = pickedFiles;
      } else if (pickedFiles != null && pickedFiles.length > 9) {
        _imageFiles = pickedFiles.sublist(0, 9); // Only select the first 9 images
      } else {
        _imageFiles = null;
      }
    });
  }

  // Upload images
  Future<void> _uploadImages() async {
    if (_imageFiles == null || _imageFiles!.isEmpty) {
      _showSnackBar('Please select images first');
      return;
    }

    for (int i = 0; i < _imageFiles!.length; i++) {
      await _uploadImage(File(_imageFiles![i].path), i);
    }
    _showSnackBar('All images uploaded successfully');
  }

  // Upload a single image
  Future<void> _uploadImage(File image, int index) async {
    final String defaultUrl = 'http://8.138.119.19:8000/upload/';
    var url = Uri.parse(defaultUrl);
    var request = http.MultipartRequest('POST', url);
    request.headers['accept'] = 'application/json';
    request.headers['Content-Type'] = 'multipart/form-data';

    request.files.add(await http.MultipartFile.fromPath(
      'file',
      image.path,
    ));

    request.fields['sliderValue'] = _sliderValue.toString();

    try {
      var response = await request.send();
      if (response.statusCode == 200) {
        http.Response res = await http.Response.fromStream(response);
        Uint8List responseData = res.bodyBytes;
        String tempPath = await _saveToHistory(image, responseData);
        setState(() {
          _imageFiles![index] = XFile(tempPath);
        });
      } else {
        _showSnackBar('Image upload failed. Error code: ${response.statusCode}');
      }
    } catch (e) {
      _showSnackBar('Error during image upload: $e');
    }
  }

  // Save original and response images to history
  Future<String> _saveToHistory(File originalImage, Uint8List responseData) async {
    try {
      final directory = await getTemporaryDirectory();
      final historyDir = Directory('${directory.path}/history');
      if (!await historyDir.exists()) {
        await historyDir.create();
      }
      final timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
      final imageDir = Directory('${historyDir.path}/$timestamp');
      await imageDir.create();

      final originalImageFile = File('${imageDir.path}/original.png');
      final blendedImageFile = File('${imageDir.path}/blended.png');

      await originalImageFile.writeAsBytes(await originalImage.readAsBytes());
      await blendedImageFile.writeAsBytes(responseData);

      // 返回 blendedImageFile 的路径以便显示
      return blendedImageFile.path;
    } catch (e) {
      print('保存图片过程中发生错误: $e');
      return '';
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _viewImageFullScreen(String imagePath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenImagePage(imagePath: imagePath),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Batch Processing'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              onPressed: _pickMultipleImages,
              child: Text('Pick Images'),
            ),
            SizedBox(height: 20),
            _imageFiles == null
                ? Text('No images selected.')
                : Expanded(
              child: Container(
                padding: EdgeInsets.all(8),
                child: GridView.builder(
                  shrinkWrap: true,
                  itemCount: _imageFiles!.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () {
                        _viewImageFullScreen(_imageFiles![index].path);
                      },
                      child: Image.file(
                        File(_imageFiles![index].path),
                        fit: BoxFit.cover,
                      ),
                    );
                  },
                ),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _uploadImages,
              child: Text('Upload Images'),
            ),
          ],
        ),
      ),
    );
  }
}

class HistoryScreen extends StatefulWidget {
  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  Future<List<Directory>> _loadHistory() async {
    try {
      final directory = await getTemporaryDirectory();
      final historyDir = Directory('${directory.path}/history');
      if (await historyDir.exists()) {
        final directories = historyDir
            .listSync()
            .where((entity) => entity is Directory)
            .map((entity) => entity as Directory)
            .toList()
          ..sort((a, b) => b.path.compareTo(a.path));
        return directories;
      }
    } catch (e) {
      print('加载历史记录过程中发生错误: $e');
    }
    return [];
  }

  void _openDetailScreen(Directory directory) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetailScreen(directory: directory),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('History'),
      ),
      body: FutureBuilder<List<Directory>>(
        future: _loadHistory(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('加载历史记录过程中发生错误'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No history available.'));
          } else {
            final directories = snapshot.data!;
            return ListView.builder(
              itemCount: directories.length,
              itemBuilder: (context, index) {
                final directory = directories[index];
                final originalImageFile = File('${directory.path}/original.png');

                return FutureBuilder<Uint8List>(
                  future: originalImageFile.readAsBytes(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.done) {
                      if (snapshot.hasData) {
                        return Container(
                          margin: EdgeInsets.symmetric(vertical: 4),
                          height: 120,
                          child: ListTile(
                            contentPadding: EdgeInsets.all(8),
                            leading: Container(
                              width: 100,
                              height: 100,
                              child: Image.memory(
                                snapshot.data!,
                                gaplessPlayback: true,
                                fit: BoxFit.cover,
                              ),
                            ),
                            title: Text(
                              directory.path.split('/').last,
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            onTap: () => _openDetailScreen(directory),
                          ),
                        );
                      } else {
                        return Container(
                          margin: EdgeInsets.symmetric(vertical: 4),
                          height: 150,
                          child: ListTile(
                            contentPadding: EdgeInsets.all(8),
                            leading: Container(
                              width: 50,
                              height: 50,
                              child: Icon(Icons.broken_image, size: 50),
                            ),
                            title: Text(
                              'Failed to load image',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ),
                        );
                      }
                    } else {
                      return Container(
                        margin: EdgeInsets.symmetric(vertical: 4),
                        height: 100,
                        child: ListTile(
                          contentPadding: EdgeInsets.all(8),
                          leading: Container(
                            width: 100,
                            height: 100,
                            child: CircularProgressIndicator(),
                          ),
                          title: Text(
                            'Loading...',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                    }
                  },
                );
              },
            );
          }
        },
      ),
    );
  }
}

class DetailScreen extends StatefulWidget {
  final Directory directory;

  DetailScreen({required this.directory});

  @override
  _DetailScreenState createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  List<String> _imagePaths = [];

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    final originalImageFile = File('${widget.directory.path}/original.png');
    final blendedImageFile = File('${widget.directory.path}/blended.png');

    List<String> imagePaths = [originalImageFile.path, blendedImageFile.path];

    final directoryList = widget.directory.listSync();
    for (var file in directoryList) {
      if (file is File && file.path.endsWith('.png') && !imagePaths.contains(file.path)) {
        imagePaths.add(file.path);
      }
    }

    setState(() {
      _imagePaths = imagePaths;
    });
  }

  void _viewImageFullScreen(String imagePath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenImagePage(imagePath: imagePath),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Detail'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: _imagePaths.isEmpty
          ? Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(8.0),
        child: GridView.builder(
          itemCount: _imagePaths.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap: () {
                _viewImageFullScreen(_imagePaths[index]);
              },
              child: Image.file(
                File(_imagePaths[index]),
                fit: BoxFit.cover,
              ),
            );
          },
        ),
      ),
    );
  }
}