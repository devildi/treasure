import 'package:flutter/material.dart';
import 'package:treasure/toy_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:treasure/store.dart';
import 'package:treasure/components/common_image.dart';

class ProfilePage extends StatefulWidget {
  final OwnerModel user;
  final List toies;
  final int toyCount;
  final double totalValue;
  final Function getMore;
  const ProfilePage({
    required this.user,
    required this.toies,
    required this.toyCount,
    required this.totalValue,
    required this.getMore,
    Key? key
    }) : super(key: key);
  @override
  ProfilePageState createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage> {

  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (_controller.position.pixels == _controller.position.maxScrollExtent) {
        if(widget.toies.length - Provider.of<UserData>(context, listen: false).pre == 20){
          _addMoreData(Provider.of<UserData>(context, listen: false).page);
        } else if(!Provider.of<UserData>(context, listen: false).netWorkStatus){
          _addMoreData(Provider.of<UserData>(context, listen: false).page);
        }
      }
    });
  }

  Future <void> _addMoreData(index) async{
    if(Provider.of<UserData>(context, listen: false).loading == false){
      Provider.of<UserData>(context, listen: false).setLoading(true);
      getMore(index);
    }
  }

  void getMore(index)async{
    if(Provider.of<UserData>(context, listen: false).loading == true){
      await widget.getMore(index);
      if (!context.mounted) return;
      if(Provider.of<UserData>(context, listen: false).netWorkStatus){
        Provider.of<UserData>(context, listen: false).setLoading(false);
        Provider.of<UserData>(context, listen: false).setPage(index + 1);
        Provider.of<UserData>(context, listen: false).setPre(widget.toies.length);
      } else {
         Provider.of<UserData>(context, listen: false).setLoading(false);
      }
    }
  }

  void logout() async{
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth');
    if (!context.mounted) return;
    Provider.of<UserData>(context, listen: false).setUserData(OwnerModel());
  }

  void _showToyDetail(toy){
    debugPrint(toy.toJson().toString());
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 图片部分
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      color: Colors.grey[200],
                      child: AspectRatio(
                        aspectRatio: toy.picWidth / toy.picHeight,
                        child: ImageWithFallback(
                          toy: toy,
                          width: MediaQuery.of(context).size.width / 2,
                        )
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // 名称和价格行
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        toy.toyName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '¥${toy.price.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // 描述
                  if (toy.description != null && toy.description!.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '描述:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          toy.description!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  // 其他信息
                  const SizedBox(height: 20),
                  // // 底部按钮
                  // Row(
                  //   mainAxisAlignment: MainAxisAlignment.end,
                  //   children: [
                  //     TextButton(
                  //       onPressed: () => Navigator.pop(context),
                  //       child: const Text('关闭'),
                  //     ),
                  //     const SizedBox(width: 10),
                  //     if (!toy.isSelled)
                  //       ElevatedButton(
                  //         onPressed: () {
                  //           // 标记为已售出的逻辑
                  //           Navigator.pop(context);
                  //         },
                  //         child: const Text('标记为已售出'),
                  //       ),
                  //   ],
                  // ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 头部信息区
            Stack(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                    )],
                  ),
                  child: Row(
                    //mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 头像
                      widget.user.avatar != ''
                      ?CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: NetworkImage(widget.user.avatar),
                      )
                      :CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: const AssetImage('assets/wechat.png'),  // 使用AssetImage
                      ),
                      const SizedBox(width: 72),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.user.name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // 简介
                          Text(
                            '玩具收藏家',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // 登出按钮
                Positioned(
                  top: 40,
                  right: 20,
                  child: IconButton(
                    icon: Icon(Icons.logout, color: Colors.grey[600]),
                    onPressed: logout,
                  ),
                ),
              ],
            ),
            // 数据卡片区
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // 玩具总数卡片
                  _buildStatCard(
                    icon: Icons.toys_sharp,
                    title: "玩具总数",
                    value: widget.toyCount.toString(),
                    unit: "件",
                    color: Colors.grey[800]!,
                  ),
                  const SizedBox(width: 16),
                  // 总价值卡片
                  _buildStatCard(
                    icon: Icons.attach_money,
                    title: "总价值",
                    value: widget.totalValue.toStringAsFixed(2),
                    unit: "元",
                    color: Colors.grey[800]!,
                  ),
                ],
              ),
            ),
            
            // 分割线
            Divider(height: 1, color: Colors.grey[200]),
            
            // 玩具列表标题
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Row(
                children: [
                  Text(
                    "我的收藏",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
            Container(
              height: 300, 
              width: MediaQuery.of(context).size.width,// 固定高度
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SingleChildScrollView(
                controller: _controller, // 添加滚动功能
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 图片网格布局
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final itemSize = (constraints.maxWidth - 24) / 4; // 计算每个图片的尺寸（减去间距）
                        return Wrap(
                          spacing: 8, // 水平间距
                          runSpacing: 8, // 垂直间距
                          children: widget.toies.map((toy) => SizedBox(
                            width: itemSize,
                            height: itemSize,
                            child: GestureDetector(
                              onTap: () => _showToyDetail(toy),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  color: Colors.grey[200],
                                  child: ImageWithFallback(
                                    toy: toy,
                                    width: MediaQuery.of(context).size.width / 2,
                                  ),
                                ),
                              )
                            ),
                          )).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),     
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required String unit,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            RichText(
              text: TextSpan(
                text: value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                children: [
                  TextSpan(
                    text: " $unit",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}