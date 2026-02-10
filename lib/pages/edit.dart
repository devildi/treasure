import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:treasure/tools.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qiniu_flutter_sdk/qiniu_flutter_sdk.dart';
import 'package:treasure/toy_model.dart';
import 'package:treasure/dao.dart';
import 'package:treasure/pages/toy.dart';
import 'package:treasure/pages/batch_upload_page.dart';

class EditMicro extends StatefulWidget {
  final OwnerModel user;
  final Function initData;
  const EditMicro({
    required this.user,
    required this.initData,
    Key? key,
  }): super(key: key);
  @override
  EditMicroState createState() => EditMicroState();

  // 静态方法用于后台刷新，避免依赖实例状态
  static Future<void> _performBackgroundRefresh(Function initData) async {
    try {
      debugPrint('🔄 Edit: 开始后台数据刷新...');

      // 给服务器一点处理时间，但不阻塞用户界面
      await Future.delayed(const Duration(milliseconds: 200));

      // 并行执行刷新操作以提高效率
      await Future.wait([
        HomePageHelper.refreshHomePage(), // 刷新HomePage
        Future.delayed(const Duration(milliseconds: 100))
            .then((_) => initData(1)), // 稍微延迟刷新主页面统计
      ]);

      debugPrint('✅ Edit: 后台数据刷新完成');
    } catch (e) {
      debugPrint('❌ Edit: 后台刷新失败，但不影响用户体验 - $e');
    }
  }
}

class EditMicroState extends State<EditMicro> with AutomaticKeepAliveClientMixin{
  @override
  bool get wantKeepAlive => true;
  final storage = Storage();
  late PutController putController;
  final TextEditingController _controller1 = TextEditingController();
  final TextEditingController _controller2 = TextEditingController();
  final TextEditingController _controller3 = TextEditingController();
  List<String> chipLabels = [
    '泡泡玛特', '盲盒', '手办', 
    '三丽鸥', 'JellyCat', '乐高',
    '游戏机', '游戏', '周边', '迪士尼', '环球影城', '其他'
  ];
  List medias = [];
  List<Future>tasks = [];
  String toyName = '';
  num price = 0;
  String description = '';
  bool uploading = false;
  bool isProcessingImages = false; // 新增：专门用于图片处理（压缩）的loading状态
  double progress = 0.0;
  int _selectedChipIndex = -1;
  bool isBatchMode = true;

  @override
  void dispose() {
    super.dispose();
    _controller1.dispose();
    _controller2.dispose();
    _controller3.dispose();
  }

  // 检查网络连接状态
  Future<bool> _checkNetworkConnection() async {
    try {
      final result = await InternetAddress.lookup('baidu.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      debugPrint('网络检查失败: $e');
      return false;
    }
  }

  void upToServer(body) async{
    // 检查 body 是否为空或包含空元素
    if (body == null || body.isEmpty) {
      if (mounted) {
        setState(() {
          uploading = false;
        });
        CommonUtils.showSnackBar(context, '上传失败，请重试！');
      }
      return;
    }

    // 检查第一个元素是否为空（主要用于获取关键信息）
    if (body[0] == null) {
      if (mounted) {
        setState(() {
          uploading = false;
        });
        CommonUtils.showSnackBar(context, '图片上传失败，请重试！');
      }
      return;
    }

    List picArr = [];
    for (var i = 0; i < body.length; i++) {
      // 添加空值检查
      if (body[i] != null) {
        picArr.add(body[i].toJson());
      } else {
        debugPrint('Warning: body[$i] is null, skipping...');
      }
    }

    try{
      dynamic res = await TreasureDao.poMicro({
        'toyName': toyName,
        'description': description,
        'toyPicUrl': body[0].key,
        'picWidth': body[0].width,
        'picHeight': body[0].height,
        'labels': chipLabels[_selectedChipIndex],
        'owner': widget.user.uid,
        'price': price,
      });
      if(res != null){
        debugPrint('✅ Edit: 发布成功，开始执行刷新...');
        if (mounted) {
          // 1. 停止loading状态
          setState(() {
            uploading = false;
          });

          // 2. 立即返回页面提供即时反馈
          Navigator.of(context).pop();
          CommonUtils.showSnackBar(context, '发布成功！');
          debugPrint('✅ Edit: 立即返回页面，提供即时反馈');

          // 3. 在后台异步执行数据刷新（不阻塞用户界面）
          unawaited(EditMicro._performBackgroundRefresh(widget.initData));
        }
      } else {
        debugPrint('❌ Edit: 发布失败，res为null');
      }
    }catch(err){
      debugPrint(err.toString());
      if (mounted) {
        setState(() {
          uploading = false;
        });
        CommonUtils.showSnackBar(context, '发布失败，请稍后再试！');
      }
    }
  }

  Future startUploadToQiniu(token, path, flag) async{
    try {
      debugPrint('=== 开始七牛云上传 ===');
      debugPrint('Token: ${token?.substring(0, 50) ?? 'null'}...');
      debugPrint('文件路径: $path');
      debugPrint('上传方式: ${flag ? 'Bytes' : 'File'}');

      // 验证token不为空
      if (token == null || token.isEmpty) {
        debugPrint('错误: Token为空或null');
        return null;
      }

      // 验证文件路径
      if (!flag) {
        final file = File(path);
        if (!await file.exists()) {
          debugPrint('错误: 文件不存在 - $path');
          return null;
        }
        debugPrint('文件大小: ${await file.length()} bytes');
      }

      debugPrint('创建 PutController');
      putController = PutController();

      debugPrint('添加进度监听器');
      putController.addSendProgressListener((double percent) {
        debugPrint('发送进度: ${(percent * 100).toStringAsFixed(1)}%');
      });

      putController.addProgressListener((double percent) {
        debugPrint('总进度: ${(percent * 100).toStringAsFixed(1)}%');
        if (mounted) {
          setState(() {
            progress = percent;
          });
        }
      });

      putController.addStatusListener((StorageStatus status) {
        debugPrint('状态变化: $status');
      });

      final putOptions = PutOptions(controller: putController);
      Future<PutResponse> upload;

      debugPrint('开始上传文件...');
      if(flag){
        upload = storage.putBytes(path, token, options: putOptions);
      } else {
        upload = storage.putFile(File(path), token, options: putOptions);
      }

      PutResponse response = await upload;
      debugPrint('✅ 上传成功！');
      debugPrint('响应数据: ${response.rawData}');

      // 验证响应数据
      if (response.rawData.isEmpty) {
        debugPrint('错误: 响应数据为空');
        return null;
      }

      ReturnBody body = ReturnBody.fromJson(response.rawData);
      debugPrint('解析后的数据(服务端): key=${body.key}, width=${body.width}, height=${body.height}');

      // 强行使用本地计算的宽高覆盖服务端的返回
      if (!flag) {
        try {
          File imageFile = File(path);
          var bytes = await imageFile.readAsBytes();
          var codec = await ui.instantiateImageCodec(bytes);
          var frameInfo = await codec.getNextFrame();
          
          double localWidth = frameInfo.image.width.toDouble();
          double localHeight = frameInfo.image.height.toDouble();
          
          debugPrint('📏 本地计算纠正: ${localWidth}x$localHeight');
          
          body = ReturnBody(
            key: body.key,
            width: localWidth,
            height: localHeight
          );
        } catch (e) {
          debugPrint('⚠️ 本地计算宽高失败: $e');
          // 失败则保留服务端数据
        }
      }

      debugPrint('=== 上传完成 ===');

      return body;

    } catch(error) {
      debugPrint('=== 上传失败 ===');
      debugPrint('错误类型: ${error.runtimeType}');

      if (error is StorageError) {
        switch (error.type) {
          case StorageErrorType.CONNECT_TIMEOUT:
            debugPrint('❌ 错误: 连接超时 - 请检查网络连接');
            break;
          case StorageErrorType.SEND_TIMEOUT:
            debugPrint('❌ 错误: 发送数据超时 - 文件可能过大或网络不稳定');
            break;
          case StorageErrorType.RECEIVE_TIMEOUT:
            debugPrint('❌ 错误: 响应数据超时 - 服务器响应慢');
            break;
          case StorageErrorType.RESPONSE:
            debugPrint('❌ 错误: 服务器响应错误 - ${error.message}');
            break;
          case StorageErrorType.CANCEL:
            debugPrint('❌ 错误: 请求取消');
            break;
          case StorageErrorType.UNKNOWN:
            debugPrint('❌ 错误: 未知错误 - ${error.message}');
            break;
          case StorageErrorType.NO_AVAILABLE_HOST:
            debugPrint('❌ 错误: 无可用主机 - 请检查网络配置');
            break;
          case StorageErrorType.IN_PROGRESS:
            debugPrint('❌ 错误: 任务已在进行中');
            break;
          case StorageErrorType.NO_AVAILABLE_REGION:
            debugPrint('❌ 错误: 无可用区域');
            break;
        }
      } else {
        debugPrint('❌ 其他错误: ${error.toString()}');
      }

      debugPrint('=== 错误处理完成 ===');
      return null;
    }
  }

  Future _add() async {
    try {
      final ImagePicker picker = ImagePicker();
      
      // 显示选择对话框
      final source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('选择图片来源'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('从相册选择'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('拍照'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        ),
      );

      if (source == null) return; // 用户取消了选择

      List<XFile>? pickedFiles;

      if (source == ImageSource.gallery && isBatchMode) {
        // 批量模式且从相册选择
        setState(() {
          isProcessingImages = true;
        });
        
        try {
          pickedFiles = await picker.pickMultiImage(
            maxWidth: 1000,
            maxHeight: 1000,
            imageQuality: 80,
          );
        } finally {
          setState(() {
            isProcessingImages = false;
          });
        }
      } else {
        // 单张模式或拍照
        setState(() {
          isProcessingImages = true;
        });

        try {
          final XFile? photo = await picker.pickImage(
            source: source,
            maxWidth: 1000,
            maxHeight: 1000,
            imageQuality: 80,
          );
           if (photo != null) {
            pickedFiles = [photo];
          }
        } finally {
           setState(() {
            isProcessingImages = false;
          });
        }
      }

      if (pickedFiles != null && pickedFiles.isNotEmpty) {
        if (isBatchMode) {
          final images = pickedFiles.map((file) => File(file.path)).toList();
          if (mounted) {
             Navigator.push(
               context,
               MaterialPageRoute(
                 builder: (context) => BatchUploadPage(
                   images: images,
                   toyName: toyName,
                   price: price,
                   description: description,
                   label: _selectedChipIndex != -1 ? chipLabels[_selectedChipIndex] : '',
                   uid: widget.user.uid,
                 ),
               ),
             );
          }
        } else {
          setState(() {
            medias = pickedFiles!.map((file) => File(file.path)).toList();
          });
        }
      }
    } catch (e) {
      if (!context.mounted) return;
      CommonUtils.show(context, '获取图片失败: ${e.toString()}');
      debugPrint('Error picking images: $e');
    }
  }

  List listPics(){
    List pics = [];
    if(medias.isNotEmpty){
      for(var i = 0; i < medias.length ; i++){
        pics.add(picContainer(medias[i].path, i));
      }
    }
    return pics;
  }

  void delete(index){
    setState(() {
      medias.removeAt(index);
      medias = medias;
    });
  }

  Widget picContainer(path, index){
    return 
      Stack(
        children: [
          Container(
            width: 150, 
            height: 150,
            margin: const EdgeInsets.fromLTRB(0, 0, 5, 0),
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              borderRadius:const BorderRadius.all(Radius.circular(20)),
              color: CommonUtils.randomColor(),
            ),
            child: Image.file(
              File(path),
              width: 150,
              height: 150,
              fit: BoxFit.cover,
            )
          ),
          Positioned(
            top: 0,
            right: 5,
            child: IconButton(
              onPressed: () => delete(index),
              icon: const Icon(Icons.clear, color: Colors.white, size: 30,)
            ),
          )
        ],
      );
  }

  void _submit()async{
    if(medias.isEmpty || toyName == '' || price == 0 || _selectedChipIndex == -1){
      CommonUtils.showSnackBar(context, '请填写完整信息！');
      return;
    }
    FocusScope.of(context).unfocus();

    try {
      // 首先检查网络连接
      debugPrint('检查网络连接...');
      final hasNetwork = await _checkNetworkConnection();
      if (!hasNetwork) {
        if (mounted) {
          setState(() {
            uploading = false;
          });
          CommonUtils.showSnackBar(context, '网络连接失败，请检查网络设置后重试！');
        }
        return;
      }

      debugPrint('开始获取上传token...');
      String token = await TreasureDao.getToken('upload'); // 修改为正确的token类型
      debugPrint('Token获取成功: $token');

      setState(() {
        uploading = true;
      });

      // 验证文件是否存在
      final file = File(medias[0].path);
      if (!await file.exists()) {
        debugPrint('文件不存在: ${medias[0].path}');
        if (mounted) {
          setState(() {
            uploading = false;
          });
          CommonUtils.showSnackBar(context, '选择的图片文件不存在，请重新选择！');
        }
        return;
      }

      debugPrint('开始上传图片: ${medias[0].path}');
      debugPrint('文件大小: ${await file.length()} bytes');

      // 清空之前的任务
      tasks.clear();
      tasks.add(startUploadToQiniu(token, medias[0].path, false));
      List body = await Future.wait(tasks);

      debugPrint('上传完成，结果数量: ${body.length}');
      for (int i = 0; i < body.length; i++) {
        debugPrint('body[$i]: ${body[i]}');
      }

      // 检查上传结果
      if (body.isEmpty || body.every((element) => element == null)) {
        debugPrint('上传结果为空或全部为null');
        if (mounted) {
          setState(() {
            uploading = false;
          });
          CommonUtils.showSnackBar(context, '图片上传失败，请检查网络连接后重试！');
        }
        return;
      }

      debugPrint('上传成功，开始提交到服务器...');
      upToServer(body);
    } catch (e) {
      debugPrint('Submit error: $e');
      debugPrint('Error type: ${e.runtimeType}');
      String errorMessage = '提交失败，请重试！';

      if (e.toString().contains('Failed to get token')) {
        errorMessage = '获取上传凭证失败，请检查网络连接！';
      } else if (e.toString().contains('Network Error')) {
        errorMessage = '网络连接失败，请检查网络设置！';
      }

      if (mounted) {
        setState(() {
          uploading = false;
        });
        CommonUtils.showSnackBar(context, errorMessage);
      }
    }
  }

  void _nameChanged(String str){
    setState((){
      toyName = str;
    });
  }

  void _priceChanged(String str){
    setState((){
      price = num.parse(str);
    });
  }

  void _desChanged(String str){
    setState((){
      description = str;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
  
    return Scaffold(
      appBar: AppBar(
        title: const Text('发布宝贝'),
        centerTitle:true,
        leading: GestureDetector(child: const Icon(Icons.arrow_back_ios),onTap: (){Navigator.maybePop(context);},),
        actions:<Widget>[
          TextButton(
            onPressed: _submit,
            child: Text('发布', style: TextStyle(color: (medias.isEmpty || toyName == '' || price == 0  || _selectedChipIndex == -1 ?Colors.grey: Colors.black))),
          )
        ]
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Container(
              width: MediaQuery.of(context).size.width,
              margin: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              decoration: const BoxDecoration(
                //color: Color.fromARGB(255, 218, 208, 208), 
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                SizedBox(
                  height: 150,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      ...listPics(),
                      Container(
                        width: 150, 
                        height: 150,
                        margin: const EdgeInsets.fromLTRB(0, 0, 5, 0),
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.all(Radius.circular(20)),
                          color: Colors.orange[100],
                        ),
                        child: Center(
                          child: IconButton(
                            onPressed: _add,
                            icon: const Icon(Icons.add_circle_outline, color: Colors.black, size: 30,),
                            color: theme.colorScheme.onSecondary,
                          )
                        ),
                      ),
                    ],
                  ),
                ),
                TextField(
                  onChanged: _nameChanged,
                  controller: _controller1,
                  decoration:const InputDecoration(
                    hintText: '宝贝名字：',
                    border:InputBorder.none
                  )
                ),
                const Divider(),
                TextField(
                  onChanged: _priceChanged,
                  controller: _controller2,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration:const InputDecoration(
                    hintText: '购入价格：',
                    border:InputBorder.none
                  ),
                ),
                const Divider(),
                TextField(
                  onChanged: _desChanged,
                  controller: _controller3,
                  decoration:const InputDecoration(
                    hintText: '填写对娃娃的描述：如系列等',
                    border:InputBorder.none
                  ),
                ),
                const Divider(),
                Wrap(
                  spacing: 8.0, // 芯片之间的间距
                  children: List.generate(chipLabels.length, (index) {
                    return ChoiceChip(
                      label: Text(chipLabels[index]),
                      selected: _selectedChipIndex == index,
                      onSelected: (bool selected) async {
                        if (chipLabels[index] == '其他' && selected) {
                          // 显示输入对话框
                          final String? newLabel = await showDialog<String>(
                            context: context,
                            builder: (BuildContext context) {
                              String inputValue = '';
                              return AlertDialog(
                                title: const Text('添加新标签'),
                                content: TextField(
                                  autofocus: true,
                                  decoration: const InputDecoration(
                                    hintText: '请输入标签名称',
                                  ),
                                  onChanged: (value) {
                                    inputValue = value;
                                  },
                                ),
                                actions: <Widget>[
                                  TextButton(
                                    child: const Text('取消'),
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                  ),
                                  TextButton(
                                    child: const Text('确定'),
                                    onPressed: () {
                                      Navigator.of(context).pop(inputValue);
                                    },
                                  ),
                                ],
                              );
                            },
                          );

                          if (newLabel != null && newLabel.isNotEmpty) {
                            setState(() {
                              // 将新标签插入到"其他"之前
                              chipLabels.insert(chipLabels.length - 1, newLabel);
                              // 选中新插入的标签
                              _selectedChipIndex = chipLabels.length - 2;
                            });
                          }
                        } else {
                          setState(() {
                            _selectedChipIndex = selected ? index : -1;
                          });
                        }
                      },
                      selectedColor: Colors.blue[200],
                      backgroundColor: Colors.grey[200],
                      labelStyle: TextStyle(
                        color: _selectedChipIndex == index ? Colors.white : Colors.black,
                      ),
                    );
                  }),
                ),
              ]),
            ),
          ),
          (uploading == true || isProcessingImages == true)
          ?const Center(
            child: CircularProgressIndicator(),
          )
          :Container(),
          uploading == true
          ?Center(
            child: Text('${(progress * 100).round()}%', style: const TextStyle(color: Colors.grey),)
          )
          :Container(),
          uploading == true
          ?LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            backgroundColor: Colors.grey,
            valueColor: const AlwaysStoppedAnimation(Colors.blue)
          )
          :Container(),
        ],
      )
    );
  }
}