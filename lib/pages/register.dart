import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:treasure/dao.dart';
import 'package:treasure/tools.dart';
import 'package:treasure/pages/login.dart';
import 'package:treasure/main.dart';
import 'package:treasure/toy_model.dart';
import 'package:treasure/core/state/state_manager.dart';
import 'package:treasure/core/navigation/page_transitions.dart';

class Register extends StatefulWidget {
  const Register({
    Key? key,
  }): super(key: key);
  @override
  RegisterState createState() => RegisterState();
}

class RegisterState extends State<Register> {
  
  late VideoPlayerController _controller;
  final TextEditingController _controller1 = TextEditingController();
  final TextEditingController _controller2= TextEditingController();
  final TextEditingController _controller3= TextEditingController();
  final TextEditingController _controller4= TextEditingController();

  String userName = '';
  String passWord = '';
  String repeatPassWord = '';
  String authCode = '';

  @override
  void initState() {
    super.initState();
    //_controller = VideoPlayerController.network(vedioURL)
    _controller = VideoPlayerController.asset("assets/video1.mp4")
      ..initialize().then((_) {
        // Ensure the first frame is shown after the video is initialized, even before the play button has been pressed.
        setState(() {});
        _controller.play();
        _controller.setLooping(true);
        _controller.setVolume(0.0);
      });
  }

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
    _controller1.dispose();
    _controller2.dispose();
    _controller3.dispose();
    _controller4.dispose();
  }

  bool validate(input){
    return input?.isNotEmpty ?? false;
  }

  void register() async {
    if (passWord != repeatPassWord) {
      CommonUtils.show(context, '两次密码不一致！');
      return;
    }

    try {
      dynamic res = await TreasureDao.register({
        "name": userName,
        "password": passWord,
        "auth": authCode
      });
      
      if (res != null) {
        if (res == '未授权！' || res == '此用户名已经注册！') {
          if (!context.mounted) return;
          CommonUtils.show(context, res);
          return;
        } else {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          final authData = res is OwnerModel ? res.toJson() : res;
          await prefs.setString('auth', json.encode(authData));
          if (!context.mounted) return;
          
          // 使用新的状态管理系统设置用户数据
          final userState = StateManager.userState(context);
          final ownerModel = res is OwnerModel ? res : OwnerModel.fromJson(res as Map<String, dynamic>);
          await userState.login(ownerModel);
          
          if (!context.mounted) return;
          CommonUtils.showSnackBar(context, '注册成功！', backgroundColor: Colors.green);
          
          // 延迟导航以确保状态更新完成
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => const MainPage(),
                ),
                (route) => false,
              );
            }
          });
        }
      }
    } catch (err) {
      debugPrint(err.toString());
      if (!context.mounted) return;
      CommonUtils.show(context, '网络异常，请稍后再试！');
    }
  }

  void _userNameChanged(String str){
    setState((){
      userName = str;
    });
  }

  void _passWordChanged(String str){
    setState((){
      passWord = str;
    });
  }

  void _repeatChanged(String str){
    setState((){
      repeatPassWord = str;
    });
  }

  void _authChanged(String str){
    setState((){
      authCode = str;
    });
  }

  @override
  Widget build(BuildContext context) {
    
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          ClipRect(
            //height: MediaQuery.of(context).size.height,
            //width: MediaQuery.of(context).size.width,
            child: Transform.scale(
              scale: _controller.value.aspectRatio /
                MediaQuery.of(context).size.aspectRatio,
              child: Center(
                child: AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                ),
              ),
            )
          ),
          // Positioned(
          //   top: MediaQuery.of(context).padding.top,
          //   left: 20,
          //   child: GestureDetector(onTap: _back,child: const Icon(Icons.arrow_back, color: Colors.white), )
          // ),
          Positioned(
            top: MediaQuery.of(context).padding.top,
            right: 20,
            child: GestureDetector(onTap:(){
              AppNavigator.pushReplacement(
                context,
                const Login(),
                type: PageTransitionType.slideScale,
                direction: SlideDirection.fromLeft,
              );
            }, child: const Text('去登录', style: TextStyle(color: Colors.white),), )
          ),
          Positioned(
            left: 18.0,
            right: 18,
            top: 90,
            child: SizedBox(
              height: 50,
              child: TextField(
                onChanged: _userNameChanged,
                controller: _controller1,
                style: const TextStyle(color: Colors.white),
                decoration:const  InputDecoration(
                  fillColor: Color(0x30cccccc),
                  filled: true,
                  contentPadding: EdgeInsets.fromLTRB(10, 0, 0, 0),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0x00FF0000)),
                    borderRadius: BorderRadius.all(Radius.circular(10))),
                  hintText: '用户名：',
                  hintStyle: TextStyle(color: Colors.white70),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0x00000000)),
                    borderRadius: BorderRadius.all(Radius.circular(10))),
                ),
              ),
            )
          ),
          Positioned(
            left: 18.0,
            right: 18,
            top: 150,
            child: SizedBox(
              height: 50,
              child: TextField(
                controller: _controller2,
                onChanged: _passWordChanged,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.fromLTRB(10, 0, 0, 0),
                  fillColor: Color(0x30cccccc),
                  filled: true,
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0x00FF0000)),
                    borderRadius: BorderRadius.all(Radius.circular(10))),
                  hintText: '密码：',
                  hintStyle: TextStyle(color: Colors.white70),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0x00000000)),
                    borderRadius: BorderRadius.all(Radius.circular(10))),
                ),
              ),
            )
          ),
          Positioned(
            left: 18.0,
            right: 18,
            top: 210,
            child: SizedBox(
              height: 50,
              child: TextField(
                controller: _controller3,
                onChanged: _repeatChanged,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.fromLTRB(10, 0, 0, 0),
                  fillColor: Color(0x30cccccc),
                  filled: true,
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0x00FF0000)),
                    borderRadius: BorderRadius.all(Radius.circular(10))),
                  hintText: '重复密码：',
                  hintStyle: TextStyle(color: Colors.white70),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0x00000000)),
                    borderRadius: BorderRadius.all(Radius.circular(10))),
                ),
              ),
            )
          ),
          Positioned(
            left: 18.0,
            right: 18,
            top: 270,
            child: SizedBox(
              height: 50,
              child: TextField(
                controller: _controller4,
                onChanged: _authChanged,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.fromLTRB(10, 0, 0, 0),
                  fillColor: Color(0x30cccccc),
                  filled: true,
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0x00FF0000)),
                    borderRadius: BorderRadius.all(Radius.circular(10))),
                  hintText: '授权码：',
                  hintStyle: TextStyle(color: Colors.white70),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0x00000000)),
                    borderRadius: BorderRadius.all(Radius.circular(10))),
                ),
              ),
            )
          ),
          Positioned(
            left: 18.0,
            right: 18,
            bottom: 15,
            child: SizedBox(
              height: 50,
              child: ClipRRect(
                borderRadius:BorderRadius.circular(10),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  onPressed: (userName == '' || passWord == '' || repeatPassWord == ''|| authCode == ''
                  ? null
                  : register),
                  child: const Text('注册', style: TextStyle(color: Colors.white,fontSize: 20), textDirection: TextDirection.ltr,),
                ),
              )
            )
          ),
        ],
      ),
    );
  }
}