import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:treasure/tools.dart';
import 'package:treasure/store.dart';
import 'package:provider/provider.dart';
import 'package:treasure/components/common_image.dart';
import 'package:treasure/dao.dart';
import 'package:treasure/toy_model.dart';
import 'dart:io';

class HomePage extends StatefulWidget {
  final List toies;
  final List searchToyList;
  final Function getMore;
  final Function initData;
  final Function search;
  final Function clearSearch;
  const HomePage({Key? key, 
    required this.toies,
    required this.searchToyList,
    required this.getMore,
    required this.initData,
    required this.search,
    required this.clearSearch,
  }
) : super(key: key);
  
  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> with AutomaticKeepAliveClientMixin, TickerProviderStateMixin{
  @override
  bool get wantKeepAlive => true;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _controller = ScrollController();
  bool showBtn = false;
  bool uploading = false;
  //动画
  late AnimationController _searchResultsController;
  late Animation<double> _searchResultsAnimation;
  late AnimationController _contentController;
  late Animation<double> _contentAnimation;

  @override
  void initState() {
    super.initState();
    // Animation controller for search results
    _searchResultsController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _searchResultsAnimation = CurvedAnimation(
      parent: _searchResultsController,
      curve: Curves.easeInOut,
    );
    
    // Animation controller for main content
    _contentController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _contentAnimation = CurvedAnimation(
      parent: _contentController,
      curve: Curves.easeInOut,
    );
    
    // Start with content visible
    _contentController.forward();

    _controller.addListener(() {
      if (_controller.offset < 1000 && showBtn) {
        setState(() {
          showBtn = false;
        });
      } else if (_controller.offset >= 1000 && showBtn == false) {
        setState(() {
          showBtn = true;
        });
      }
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

  @override
  void dispose() {
    _searchController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _refresh(){
    widget.initData(1);
  }

  Future<void> _onRefresh() async{
    await widget.initData(1);
    if (!context.mounted) return;
    Provider.of<UserData>(context, listen: false).setPage(2);
    Provider.of<UserData>(context, listen: false).setPre(0);
  }

  void _search(String value) {
    Provider.of<UserData>(context, listen: false).setLoading(true);
    if(_searchController.text != ''){
      widget.search(_searchController.text);
      // Animate when search results appear
      _searchResultsController.forward();
      _contentController.reverse();
    }
  }

  void clear() {
    _searchController.clear();
    widget.clearSearch();
    _searchResultsController.reverse().then((_) {
      if (mounted) {
        widget.clearSearch();
        _contentController.forward();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final double statusBarHeight = MediaQuery.of(context).padding.top;

    return Scaffold(
      body: widget.toies.isNotEmpty
      ?Column(
        children: [
          Container(
            color: Colors.white,
            padding: EdgeInsets.only(top: statusBarHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
              child: TextField(
                onSubmitted: _search,
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: '搜索...',
                  hintStyle: TextStyle(
                    color: Colors.grey[600],
                  ),
                  contentPadding: const EdgeInsets.fromLTRB(16.0, 12.0, 12.0, 12.0),
                  suffixIcon: widget.searchToyList.isNotEmpty
                  ? IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: clear
                  )
                  :IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () => _search(_searchController.text),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  filled: true,
                  fillColor: Colors.grey[200],
                ),
              ),
            ),
          ),
          widget.searchToyList.isNotEmpty
          ?Center(
            //padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            //alignment: Alignment.centerLeft,
            child: Text(
              '找到 ${widget.searchToyList.length} 个相关结果',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          )
          :const SizedBox.shrink(),
          SizeTransition(
            sizeFactor: _searchResultsAnimation,
            child: FadeTransition(
              opacity: _searchResultsAnimation,
              child: widget.searchToyList.isNotEmpty
              ? Container(
                  padding: const EdgeInsets.all(8),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final rowCount = (widget.searchToyList.length / 2).ceil();
                      final itemHeight = (MediaQuery.of(context).size.width / 2); // childAspectRatio=1 时，高≈宽
                      final gridHeight = rowCount * itemHeight + (rowCount - 1) * 8;
                      return ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.6, // 限制最大高度
                        ),
                        child: GridView.builder(
                          shrinkWrap: gridHeight < MediaQuery.of(context).size.height * 0.6, 
                          padding: EdgeInsets.zero,
                          physics: gridHeight < MediaQuery.of(context).size.height * 0.6
                            ? const NeverScrollableScrollPhysics()
                            : const AlwaysScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 1,
                          ),
                          itemCount: widget.searchToyList.length,
                          itemBuilder: (context, index) {
                            final toy = widget.searchToyList[index];
                            return GestureDetector(
                              onTap: () => CommonUtils.showDetail(context, index, widget.searchToyList, widget.getMore),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: Colors.grey[200],
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: ImageWithFallback(
                                        toy: toy,
                                        width: MediaQuery.of(context).size.width / 2,
                                      ),    
                                    ),
                                    Positioned(
                                      bottom: 10,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.6),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          toy.toyName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    }
                  )
                )
              : const SizedBox.shrink()
            )
          ),
          widget.searchToyList.isNotEmpty
          ?const Divider()
          :const SizedBox.shrink(),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Stack(
                children: [
                  RefreshIndicator(
                    onRefresh: _onRefresh,
                    child: MasonryGridView.count(
                      controller: _controller,
                      padding: EdgeInsets.zero,
                      crossAxisCount: 2,
                      mainAxisSpacing: 1,
                      crossAxisSpacing: 1,
                      itemCount: widget.toies.length,
                      itemBuilder: (context, index) {
                        return _Item(
                          index: index, 
                          toies: widget.toies,
                          getMore: widget.initData
                        );
                      },
                    )
                  ),
                  Provider.of<UserData>(context, listen: false).loading == true
                  ?const Center(
                    child: CircularProgressIndicator(),
                  )
                  :Container()
                ]
              )     
            ),
          ),
        ],
      )
      :Center(
        child: Provider.of<UserData>(context, listen: false).netWorkStatus && Provider.of<UserData>(context, listen: false).loading
        ? const CircularProgressIndicator() 
        : Provider.of<UserData>(context, listen: false).netWorkStatus
        ? const Text('暂无数据', style: TextStyle(fontSize: 16, color: Colors.grey))
        :ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
          icon: const Icon(Icons.refresh, color: Colors.white,),
          label: const Text("点击刷新",style: TextStyle(color: Colors.white),),
          onPressed: _refresh,
        )
      ),
      floatingActionButton: showBtn
      ? FloatingActionButton(
        onPressed: (){
          _controller.animateTo(.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.ease
          );
        },
        backgroundColor: Colors.black,
        heroTag: 3,
        child: const Icon(Icons.arrow_upward, color: Colors.white, size: 40),
      ): null
    );
  }
}

class _Item extends StatelessWidget {
  final int index;
  final List toies;
  final Function getMore;

  const _Item({
    Key? key,
    required this.index,
    required this.toies,
    required this.getMore,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {

    return GestureDetector(
      onTap: () => CommonUtils.showDetail(context, index, toies, getMore),
      onLongPress: () => {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('删除宝贝'),
              content:  const Text('请谨慎操作'),
              actionsAlignment: MainAxisAlignment.spaceBetween,
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    // 第一个按钮的操作
                    Navigator.of(context).pop();
                  },
                  child: const Text('不删了'),
                ),
                TextButton(
                  onPressed: () async{
                    // 第二个按钮的操作
                    ResultModel result = await TreasureDao.deleteToy(toies[index].id, toies[index].toyPicUrl.substring('http://nextsticker.xyz/'.length));
                    
                    if(result.deletedCount == 1){
                      try {
                        final file = File(toies[index].localUrl);
                        final exists = await file.exists();
                        if (exists) {
                          await file.delete();
                          debugPrint('文件已删除: $toies[index].localUrl');
                        } else {
                          debugPrint('文件不存在: $toies[index].localUrl');
                        }
                      } catch (e) {
                        debugPrint('删除文件时出错: $e');
                      }
                      if (!context.mounted) return;
                      await getMore(Provider.of<UserData>(context, listen: false).page);
                      if (!context.mounted) return;
                      CommonUtils.show(context, '删除成功');
                      Navigator.of(context).pop();
                    } else {
                      if (!context.mounted) return;
                      CommonUtils.show(context, '删除失败，请稍后再试');
                    }
                  },
                  child: const Text('删除'),
                ),
              ],
            );
          },
        )
      },
      child: Card(
        child: PhysicalModel(
          color: Colors.transparent,
          clipBehavior: Clip.antiAlias,
          borderRadius: BorderRadius.circular(2),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ImageWithFallback(
                    toy: toies[index],
                    width: MediaQuery.of(context).size.width / 2,
                  ),
                  Container(
                    padding: const EdgeInsets.all(7),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${toies[index].toyName}', style: const TextStyle(fontSize: 15)),
                        toies[index].isSelled
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'SOLD',
                              style: TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          )
                        : Container()
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}