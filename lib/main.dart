import 'package:flutter/material.dart';
import 'package:treasure/pages/toy.dart';
import 'package:treasure/pages/user.dart';
import 'package:treasure/pages/login.dart';
import 'package:treasure/pages/edit.dart';
import 'package:treasure/toy_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'store.dart';
import 'tools.dart';
import 'dao.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  Provider.debugCheckInvalidValueType = null;
  SharedPreferences prefs = await SharedPreferences.getInstance();
  //await prefs.clear();
  String userDataString = prefs.getString('auth') ?? '';
  late OwnerModel userDataConvert;
  if(userDataString != ''){
    dynamic obj = json.decode(userDataString);
    userDataConvert = OwnerModel.fromJson(obj);
  } else {
    userDataConvert = OwnerModel();
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(
          value: UserData(
            user: userDataConvert, 
          )
        ),
      ],
      child: const MyApp()
    )
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '上新了宝贝',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MainPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({Key? key}) : super(key: key);
  @override
  MainPageState createState() => MainPageState();
}

class MainPageState extends State<MainPage> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();
  List toyList = [];
  List searchToyList = [];
  int toyCount = 0;
  double totalValue = 0.0;
  @override
  void initState() {
    super.initState();
    Provider.of<UserData>(context, listen: false).setLoading(true);
    initData(1);
  }

  void initData(page) async {
    try {
      //OwnerModel owner = Provider.of<UserData>(context, listen: false).user;
      List<Future>tasks = [];
      tasks.add(TreasureDao.getAllToies(page, Provider.of<UserData>(context, listen: false).user.uid));
      tasks.add(TreasureDao.getTotalPriceAndCount(Provider.of<UserData>(context, listen: false).user.uid));
      List body = await Future.wait(tasks);
      setState(() {
        toyList = body[0].toyList;
        toyCount = body[1].count;
        totalValue = body[1].totalPrice.toDouble();
      });
      if (!mounted) return;
      Provider.of<UserData>(context, listen: false).setLoading(false);
    } catch (e) {
      if (!mounted) return;
      Provider.of<UserData>(context, listen: false).setNetWorkStatus(false);
      Provider.of<UserData>(context, listen: false).setLoading(false);
      CommonUtils.showSnackBar(context, '网络异常，请稍后再试！', backgroundColor: Colors.red);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void jump(user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditMicro(
          user: user,
          initData: initData,
        ),
      ),
    );
  }

  void search(String keyword) async{
    AllToysModel toies = await TreasureDao.searchToies(keyword, Provider.of<UserData>(context, listen: false).user.uid);
    if(toies.toyList.isEmpty) {
      if (!mounted) return;
      CommonUtils.show(context, '没有找到相关宝藏');
      Provider.of<UserData>(context, listen: false).setLoading(false);
      return;
    }
    setState(() {
      searchToyList = toies.toyList;
      Provider.of<UserData>(context, listen: false).setLoading(false);
    });
  }

  void clearSearch() {
    setState(() {
      searchToyList = [];
    });
  }

  Future<void> _addMoreData(index) async{
    try{
      AllToysModel toies = await TreasureDao.getAllToies(index, Provider.of<UserData>(context, listen: false).user.uid);
      setState(() {
        toyList = toies.toyList;
        Provider.of<UserData>(context, listen: false).setNetWorkStatus(true);
      });
    }catch(err){
      if (!mounted) return;
      CommonUtils.showSnackBar(context, '网络异常，请稍后再试！', backgroundColor: Colors.red);
      Provider.of<UserData>(context, listen: false).setNetWorkStatus(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    OwnerModel user = Provider.of<UserData>(context).user;
    if (user.uid == '') {
      return const Login();
    }
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        children: [
          HomePage(
            toies: toyList,
            searchToyList: searchToyList,
            getMore: _addMoreData,
            initData: initData,
            search: search,
            clearSearch: clearSearch,
          ),
          ProfilePage(
            user: user,
            totalValue: totalValue,
            toyCount: toyCount,
            toies: toyList,
            getMore: _addMoreData,
          ),
        ],
      ),
      floatingActionButton: Transform.translate(
        offset: const Offset(0, 10),
        child: FloatingActionButton(
          onPressed: () => jump(user),
          backgroundColor: Colors.black,
          elevation: 2,
          child: const Icon(Icons.add, size: 40, color: Colors.white),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(
              color: Colors.grey.withOpacity(0.2),
              width: 1.0,
            ),
          ),
        ),
        height: 56,
        child: Row(
          children: [
            Expanded(child: _buildNavItem(0, Icons.home, '首页')),
            Expanded(child: Container()),
            Expanded(child: _buildNavItem(1, Icons.person, '我的')),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    return Material(
      color: Colors.white,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _currentIndex = index;
            _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 300),
              curve: Curves.ease,
            );
          });
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: _currentIndex == index ? Colors.black : Colors.grey,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: _currentIndex == index ? Colors.black : Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}