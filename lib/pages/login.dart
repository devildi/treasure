import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:treasure/pages/register.dart';
import 'package:treasure/dao.dart';
import 'package:treasure/tools.dart';
import 'package:treasure/toy_model.dart';
import 'package:treasure/core/state/state_manager.dart';
import 'package:treasure/core/navigation/page_transitions.dart';

class Login extends StatefulWidget {
  const Login({
    Key? key,
  }): super(key: key);
  @override
  LoginState createState() => LoginState();
}

class LoginState extends State<Login> with AutomaticKeepAliveClientMixin{
  @override
  bool get wantKeepAlive => true;
  late VideoPlayerController _controller;
  final TextEditingController _controller1 = TextEditingController();
  final TextEditingController _controller2= TextEditingController();

  String name = '';
  String password = '';

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
  }

  bool validate(input){
    return input?.isNotEmpty ?? false;
  }

  void _submit()async {
    try{
      OwnerModel res = await TreasureDao.login({
        "name": name,
        "password": password,
      });
      if(res.name == ''){
        if (!context.mounted) return;
        CommonUtils.show(context, '用户名或密码错误！');
        return;
      } else {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth', json.encode(res));
        if (!context.mounted) return;
        // 使用新的状态管理系统设置用户数据
        final userState = StateManager.userState(context);
        await userState.login(res);
        _controller.dispose();
        if (mounted) {
          CommonUtils.showSnackBar(context, '登录成功！', backgroundColor: Colors.green);
        }
      }
    } catch(err){
      debugPrint(err.toString());
      if (!context.mounted) return;
      CommonUtils.show(context, '网络异常，请稍后再试！');
    }
  }

  void _userNameChanged(String str){
    setState((){
      name = str;
    });
  }

  void _passWordChanged(String str){
    setState((){
      password = str;
    });
  }

  void jump2register(){
    AppNavigator.pushReplacement(
      context,
      const Register(),
      type: PageTransitionType.slideScale,
      direction: SlideDirection.fromRight,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
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
          //   child: GestureDetector(onTap: _back, child: const Icon(Icons.close, color: Colors.white), )
          // ),
          Positioned(
            top: MediaQuery.of(context).padding.top,
            right: 20,
            child: GestureDetector(
              onTap: jump2register, 
              child: const Text('去注册', style: TextStyle(color: Colors.white)), 
            )
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
                decoration: const InputDecoration(
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
            bottom: 15,
            child: SizedBox(
              height: 50,
              child: ClipRRect(
                borderRadius:BorderRadius.circular(10),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  onPressed: (name == '' || password == '' ? null : _submit),
                  child: const Text('登录', style: TextStyle(color: Colors.white,fontSize: 20), textDirection: TextDirection.ltr,),
                ),
              )
            )
          ),
        ],
      ),
    );
  }
}