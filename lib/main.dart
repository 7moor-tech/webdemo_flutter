import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart'
    as webview_flutter_android;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'WebView Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController _urlController = TextEditingController(
    text:
        'https://test3-webchat.7moor.com/wapchat.html?accessId=9f9db6e0-e1a9-11ee-ac79-4f450bc1a897&useJsUpload=true&videoDownloadBtn=true',
  );

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: '请输入URL',
                border: OutlineInputBorder(),
                hintText: '例如: https://example.com',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                if (_urlController.text.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => WebViewPage(url: _urlController.text),
                    ),
                  );
                }
              },
              child: const Text('打开网页'),
            ),
          ],
        ),
      ),
    );
  }
}

class WebViewPage extends StatefulWidget {
  final String url;

  const WebViewPage({super.key, required this.url});

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  late WebViewController controller;

  @override
  void initState() {
    super.initState();
    controller = WebViewController(
      onPermissionRequest: (request) {
        print('onPermissionRequest:$request');
      },
    );
    controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    if (Platform.isAndroid) {
      final androidController =
          (controller.platform
              as webview_flutter_android.AndroidWebViewController);
      androidController.setOnShowFileSelector(_androidFilePicker);
    }
    _setUserAgent();
    controller.addJavaScriptChannel(
      'moorJsCallBack',
      onMessageReceived: (message) {
        print('onMessageReceived:${message.message}');
        try {
          final data = jsonDecode(message.message);
          final method = data['body'];
          if (method == 'checkPermission') {
            final type = data['type'];
            _checkPermission(type);
          } else if (method == 'onDownloadVideo') {
            final url = data['url'];
            _onDownloadVideo(url);
          } else if (method == 'onCloseEvent') {
            _onCloseEvent();
          }
        } catch (e) {}
      },
    );
    controller.loadRequest(Uri.parse(widget.url));
  }

  Future<List<String>> _androidFilePicker(
    webview_flutter_android.FileSelectorParams params,
  ) async {
    print('params.acceptTypes:${params.acceptTypes}');
    var types = <String>[];
    //处理文件类型
    if (params.acceptTypes.isNotEmpty && params.acceptTypes[0] != '') {
      types = params.acceptTypes.map((e) => e.replaceAll('.', '')).toList();
      final imageIndex = types.indexOf('image/*');
      //这个FilePicker不支持通配符
      if (imageIndex != -1) {
        types.removeAt(imageIndex);
        types.addAll(['png', 'jpg', 'jpeg', 'bmp']);
      }
    }
    print('types:$types');
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: types,
    );
    print('result:$result');
    if (result != null && result.files.isNotEmpty) {
      return result.files.map((file) => 'file://${file.path}').toList();
    }
    return [];
  }

  ///H5页面上传 图片/文件 权限检查
  ///
  ///可用于自定义权限弹窗以及说明
  ///
  ///@param type js回调传参 image 上传图片，file 上传文件
  void _checkPermission(String type) async {
    if (!kIsWeb && Platform.isAndroid) {
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      //android 13以下版本需要申请storage权限
      if (androidInfo.version.sdkInt < 33) {
        final status = await Permission.storage.status;
        if (status == PermissionStatus.granted) {
          controller.runJavaScript('initAllUpload("$type")');
        } else {
          Permission.storage.request().then((value) {
            if (value == PermissionStatus.granted) {
              controller.runJavaScript('initAllUpload("$type")');
            } else {
              print('storage permission denied');
            }
          });
        }
      } else if (type == 'image') {
        final status = await Permission.photos.status;
        if (status == PermissionStatus.granted) {
          controller.runJavaScript('initAllUpload("$type")');
        } else {
          Permission.photos.request().then((value) {
            if (value == PermissionStatus.granted) {
              controller.runJavaScript('initAllUpload("$type")');
            } else {
              print('photos permission denied');
            }
          });
        }
      } else if (type == 'file') {
        final statusList = [
          await Permission.photos.status,
          await Permission.videos.status,
          await Permission.audio.status,
        ];
        if (statusList.every(
          (element) => element == PermissionStatus.granted,
        )) {
          controller.runJavaScript('initAllUpload("$type")');
        } else {
          final statusList =
              await [
                Permission.photos,
                Permission.videos,
                Permission.audio,
              ].request();
          if (statusList.values.every(
            (element) => element == PermissionStatus.granted,
          )) {
            controller.runJavaScript('initAllUpload("$type")');
          } else {
            print('file permission denied');
          }
        }
      }
    } else if (Platform.isIOS) {
      controller.runJavaScript('initAllUpload("$type")');
    }
  }

  ///会话关闭回调
  void _onCloseEvent() {
    Navigator.pop(context);
  }

  ///文件保存js事件
  ///
  ///在url参数videoDownloadBtn=true时有效
  void _onDownloadVideo(String url) {
    print('onDownloadVideo:$url');
  }

  void _setUserAgent() async {
    var userAgent = await controller.getUserAgent();
    //重要：设置userAgent带Flutter标识
    await controller.setUserAgent('Flutter/$userAgent');
    userAgent = await controller.getUserAgent();
    print('userAgent:$userAgent');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('WebView'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              controller.reload();
            },
          ),
        ],
      ),
      body: WebViewWidget(controller: controller),
    );
  }
}
