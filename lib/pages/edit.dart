import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:treasure/tools.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qiniu_flutter_sdk/qiniu_flutter_sdk.dart';
import 'package:treasure/toy_model.dart';
import 'package:treasure/dao.dart';

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
}

class EditMicroState extends State<EditMicro> with AutomaticKeepAliveClientMixin{
  @override
  bool get wantKeepAlive => true;
  final storage = Storage();
  late PutController putController;
  final TextEditingController _controller1 = TextEditingController();
  final TextEditingController _controller2 = TextEditingController();
  final TextEditingController _controller3 = TextEditingController();
  final List<String> chipLabels = [
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
  double progress = 0.0;
  int _selectedChipIndex = -1;

  @override
  void dispose() {
    super.dispose();
    _controller1.dispose();
    _controller2.dispose();
    _controller3.dispose();
  }

  void upToServer(body) async{
    List picArr = [];
    for (var i = 0; i < body.length; i++) {
      picArr.add(body[i].toJson());
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
        setState(() {
          uploading = false;
          Navigator.of(context).pop();
          CommonUtils.showSnackBar(context, '发布成功！');
        });
        await widget.initData(1);
      }
    }catch(err){
      debugPrint(err.toString());
      setState(() {
        uploading = false;
        CommonUtils.showSnackBar(context, '发布失败，请稍后再试！');
      });
    }
  }

  Future startUploadToQiniu(token, path, flag) async{
    debugPrint('创建 PutController');
    putController = PutController();
    debugPrint('添加实际发送进度订阅');
    putController.addSendProgressListener((double percent) {
      debugPrint('已上传进度变化：已发送：$percent');
    });
    debugPrint('添加任务进度订阅');
    putController.addProgressListener((double percent) {
      debugPrint('任务进度变化：已发送：$percent');
      setState(() {
        progress = percent;
      });
    });
    debugPrint('添加状态订阅');
    putController.addStatusListener((StorageStatus status) {
      debugPrint('状态变化: 当前任务状态：$status');
    });
    debugPrint('开始上传文件');
    final putOptions = PutOptions(
      controller: putController
    );
    Future<PutResponse> upload;
    if(flag){
      upload = storage.putBytes(
        path,
        token,
        options: putOptions,
      );
    }else{
      upload = storage.putFile(
        File(path),
        token,
        options: putOptions,
      );
    }
    try{
      PutResponse response = await upload;
      debugPrint('上传已完成: 原始响应数据: ${response.rawData}');
      debugPrint('------------------------');
      ReturnBody body = ReturnBody.fromJson(response.rawData);
      return body;
    } catch(error){
      if (error is StorageError) {
        switch (error.type) {
          case StorageErrorType.CONNECT_TIMEOUT:
            debugPrint('发生错误: 连接超时');
            break;
          case StorageErrorType.SEND_TIMEOUT:
            debugPrint('发生错误: 发送数据超时');
            break;
          case StorageErrorType.RECEIVE_TIMEOUT:
            debugPrint('发生错误: 响应数据超时');
            break;
          case StorageErrorType.RESPONSE:
            debugPrint('发生错误: ${error.message}');
            break;
          case StorageErrorType.CANCEL:
            debugPrint('发生错误: 请求取消');
            break;
          case StorageErrorType.UNKNOWN:
            debugPrint('发生错误: 未知错误');
            break;
          case StorageErrorType.NO_AVAILABLE_HOST:
            debugPrint('发生错误: 无可用 Host');
            break;
          case StorageErrorType.IN_PROGRESS:
            debugPrint('发生错误: 已在队列中');
            break;
        }
      } else {
        debugPrint('发生错误: ${error.toString()}');
      }
      debugPrint('------------------------');
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
      
      if (source == ImageSource.gallery) {
        // 从相册选择多张照片
        pickedFiles = await picker.pickMultiImage(
          maxWidth: 1000,
          maxHeight: 1000,
          imageQuality: 80,
        );
      } else {
        // 拍照
        final XFile? photo = await picker.pickImage(
          source: source,
          maxWidth: 1000,
          maxHeight: 1000,
          imageQuality: 80,
        );
        if (photo != null) {
          pickedFiles = [photo];
        }
      }

      if (pickedFiles != null && pickedFiles.isNotEmpty) {
        setState(() {
          medias = pickedFiles!.map((file) => File(file.path)).toList();
        });
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
    String token = await TreasureDao.getToken('string');
    setState(() {
      uploading = true;
    });
    tasks.add(startUploadToQiniu(token, medias[0].path, false));
    List body = await Future.wait(tasks);
    upToServer(body);
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
                      onSelected: (bool selected) {
                        setState(() {
                          _selectedChipIndex = selected ? index : -1;
                        });
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
          uploading == true
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