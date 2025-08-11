import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:treasure/tools.dart';
import 'package:treasure/store.dart';
import 'package:treasure/toy_model.dart';

class Login extends StatefulWidget {
  const Login({
    Key? key,
  }): super(key: key);
  @override
  LoginState createState() => LoginState();
}

class LoginState extends State<Login> {
  
  late VideoPlayerController _controller;

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
  }

  void login()async{
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth', json.encode(''));
    if (!context.mounted) return;
    Provider.of<UserData>(context, listen: false).setUserData(OwnerModel());
    _controller.dispose();
    CommonUtils.showSnackBar(context, '登录成功！', backgroundColor: Colors.green);
  }

  @override
  Widget build(BuildContext context) {
    
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          ClipRect(
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
          Positioned(
            top: MediaQuery.of(context).size.height * 0.3 - 50, // Moved up by 50 pixels
            left: 0,
            right: 0,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.child_care,
                    size: 60,
                    color: Colors.pinkAccent,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  '管理你的宝贝',
                  style: TextStyle(
                    fontSize: 24,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        blurRadius: 10,
                        color: Colors.black,
                        offset: Offset(2, 2),
                  )],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 18.0,
            right: 18,
            bottom: 15,
            child: ElevatedButton(
              onPressed: login,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF07C160), // 微信绿色
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children:[
                  Icon(Icons.wechat, color: Colors.white),
                  SizedBox(width: 10),
                  Text(
                    '微信登录',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}