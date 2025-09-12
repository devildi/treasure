import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/core/pagination/pagination_controller.dart';

void main() {
  group('Cumulative Pagination Tests', () {
    late PaginationController<String> controller;

    setUp(() {
      controller = PaginationController<String>(
        pageSize: 5,
        loadData: (page) async {
          // 模拟累积型分页：服务器返回累积的数据
          await Future.delayed(const Duration(milliseconds: 50));
          
          switch (page) {
            case 1:
              return ['item1', 'item2', 'item3', 'item4', 'item5']; // 5 items
            case 2:
              return ['item1', 'item2', 'item3', 'item4', 'item5', 'item6', 'item7', 'item8']; // 8 items (增加了3个)
            case 3:
              return ['item1', 'item2', 'item3', 'item4', 'item5', 'item6', 'item7', 'item8', 'item9']; // 9 items (增加了1个，< pageSize)
            default:
              // 返回相同数据表示没有更多数据
              return ['item1', 'item2', 'item3', 'item4', 'item5', 'item6', 'item7', 'item8', 'item9']; 
          }
        },
      );
    });

    tearDown(() {
      controller.dispose();
    });

    test('should handle cumulative pagination correctly', () async {
      // 加载第一页
      await controller.loadInitialData();
      expect(controller.items.length, 5);
      expect(controller.hasReachedEnd, false); // 满页，应该还有更多

      // 加载第二页
      await controller.loadMore();
      expect(controller.items.length, 8); // 服务器返回累积的8项
      expect(controller.hasReachedEnd, false); // 增长了3个，还可能有更多

      // 加载第三页  
      await controller.loadMore();
      expect(controller.items.length, 9); // 服务器返回累积的9项
      expect(controller.hasReachedEnd, false); // 增长了1个，仍可能有更多
      
      // 加载第四页（无新增数据）
      await controller.loadMore();
      expect(controller.items.length, 9); // 服务器返回相同的9项
      expect(controller.hasReachedEnd, true); // 增长了0个，到达终点
    });

    test('should stop loading when no incremental data', () async {
      await controller.loadInitialData();
      await controller.loadMore(); 
      await controller.loadMore(); 
      await controller.loadMore(); // 到达终点
      
      expect(controller.hasReachedEnd, true);
      
      final itemCountBefore = controller.items.length;
      await controller.loadMore(); // 应该不执行任何操作
      
      expect(controller.items.length, itemCountBefore);
      expect(controller.hasReachedEnd, true);
    });

    test('should handle small dataset on first load', () async {
      final smallController = PaginationController<String>(
        pageSize: 10,
        loadData: (page) async {
          return ['item1', 'item2']; // 只有2项，< pageSize
        },
      );

      await smallController.loadInitialData();
      
      expect(smallController.items.length, 2);
      expect(smallController.hasReachedEnd, true); // 第一页就少于pageSize
      
      smallController.dispose();
    });
  });
}