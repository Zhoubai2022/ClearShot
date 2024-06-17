import 'package:flutter/material.dart';
import 'package:multi_image_picker/multi_image_picker.dart';

class BatchProcessingScreen extends StatefulWidget {
  @override
  _BatchProcessingScreenState createState() => _BatchProcessingScreenState();
}

class _BatchProcessingScreenState extends State<BatchProcessingScreen> {
  List<Asset> _imageAssets = [];

  // 批量选择图片
  Future<void> _pickMultipleImages() async {
    List<Asset> resultList = [];

    try {
      resultList = await MultiImagePicker.pickImages(
        maxImages: 9,
        enableCamera: true,
        selectedAssets: _imageAssets,
        cupertinoOptions: CupertinoOptions(takePhotoIcon: "chat"),
        materialOptions: MaterialOptions(
          actionBarColor: "#abcdef",
          actionBarTitle: "Select Images",
          allViewTitle: "All Photos",
          useDetailsView: false,
          selectCircleStrokeColor: "#000000",
        ),
      );
    } on Exception catch (e) {
      print(e);
    }

    // If the operation is successful, set the images
    if (!mounted) return;

    setState(() {
      _imageAssets = resultList;
    });
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
              child: Text('Pick Up Images'),
            ),
            SizedBox(height: 20),
            _imageAssets.isEmpty
                ? Text('No images selected.')
                : Container(
              padding: EdgeInsets.all(8),
              child: GridView.builder(
                shrinkWrap: true,
                itemCount: _imageAssets.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                ),
                itemBuilder: (context, index) {
                  return AssetThumb(
                    asset: _imageAssets[index],
                    width: 300,
                    height: 300,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
