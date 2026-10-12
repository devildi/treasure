import 'package:flutter/foundation.dart';

class OwnerModel {
  final String name;
  final String uid;
  final String avatar;
  final String family;

  OwnerModel({
    this.name = '',
    this.uid = '',
    this.avatar = '',
    this.family = '',
  });

  factory OwnerModel.fromJson(Map<String, dynamic> json) {
    return OwnerModel(
      name: json["name"] ?? '',
      uid: json["_id"] ?? '',
      avatar: json["avatar"] ?? '',
      family: json["family"] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "name": name,
      "_id": uid,
      "avatar": avatar,
      "family": family,
    };
  }

  OwnerModel copyWith({
    String? name,
    String? uid,
    String? avatar,
    String? family,
  }) {
    return OwnerModel(
      name: name ?? this.name,
      uid: uid ?? this.uid,
      avatar: avatar ?? this.avatar,
      family: family ?? this.family,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OwnerModel &&
        other.name == name &&
        other.uid == uid &&
        other.avatar == avatar &&
        other.family == family;
  }

  @override
  int get hashCode => Object.hash(name, uid, avatar, family);
}

class PriceCountModel {
  final double totalPrice;
  final int count;

  PriceCountModel({
    this.totalPrice = 0.0,
    this.count = 0,
  });

  factory PriceCountModel.fromJson(Map<String, dynamic> json) {
    try {
      return PriceCountModel(
        totalPrice: _safeToDouble(json["totalPrice"]),
        count: json["count"] ?? 0,
      );
    } catch (e) {
      debugPrint('❌ PriceCountModel.fromJson 解析失败: $e');
      debugPrint('📄 JSON数据: $json');
      rethrow;
    }
  }

  // 安全的数字转换方法
  static double _safeToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        debugPrint('⚠️ 无法解析数字字符串: $value');
        return 0.0;
      }
    }
    return 0.0;
  }

  Map<String, dynamic> toJson() {
    return {
      "totalPrice": totalPrice,
      "count": count,
    };
  }
}

class ResultModel {
  final int ok;
  final int n;
  final int deletedCount;

  ResultModel({
    this.ok = 0,
    this.n = 0,
    this.deletedCount = 0,
  });

  factory ResultModel.fromJson(Map<String, dynamic> json) {
    try {
      return ResultModel(
        ok: _safeToInt(json["ok"]),
        n: _safeToInt(json["n"]),
        deletedCount: _safeToInt(json["deletedCount"]),
      );
    } catch (e) {
      debugPrint('❌ ResultModel.fromJson 解析失败: $e');
      debugPrint('📄 JSON数据: $json');
      rethrow;
    }
  }

  // 安全的整数转换方法
  static int _safeToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      try {
        return int.parse(value);
      } catch (e) {
        debugPrint('⚠️ 无法解析整数字符串: $value');
        return 0;
      }
    }
    return 0;
  }

  Map<String, dynamic> toJson() {
    return {
      "deletedCount": deletedCount,
      "n": n,
      "ok": ok,
    };
  }
}

class ToyModel {
  String id;
  String toyName;
  String toyPicUrl;
  String localUrl;
  num picWidth;
  num picHeight;
  String description;
  String labels;
  OwnerModel owner;
  num price;
  num sellPrice;
  String createAt;
  String sellAt;
  bool isSelled;

  ToyModel({
    this.id = '',
    this.toyName = '',
    this.toyPicUrl = '',
    this.localUrl = '',
    this.picWidth = 0,
    this.picHeight = 0,
    this.description = '',
    this.labels = '',
    required this.owner,
    required this.price,
    required this.sellPrice,
    required this.createAt,
    required this.sellAt,
    required this.isSelled,
  });

  factory ToyModel.fromJson(Map<String, dynamic> json) {
    try {
      return ToyModel(
        id: json['_id'] ?? json['id'] ?? '',
        toyName: json['toyName'] ?? '',
        toyPicUrl: json['toyPicUrl'] ?? '',
        localUrl: json['localUrl'] ?? '',
        picWidth: _safeToDouble(json['picWidth']),
        picHeight: _safeToDouble(json['picHeight']),
        description: json['description'] ?? '',
        labels: json['labels'] ?? '',
        owner: _parseOwner(json['owner']),
        price: _safeToDouble(json['price']),
        sellPrice: _safeToDouble(json['sellPrice']),
        isSelled: json["isSelled"] ?? false,
        createAt: json["createAt"] ?? '',
        sellAt: json["sellAt"] ?? '',
      );
    } catch (e) {
      debugPrint('❌ ToyModel.fromJson 解析失败: $e');
      debugPrint('📄 JSON数据: $json');
      rethrow;
    }
  }

  // 安全的owner解析方法
  static OwnerModel _parseOwner(dynamic ownerData) {
    // 如果为null，返回默认owner
    if (ownerData == null) {
      return OwnerModel();
    }

    // 如果不是Map，返回默认owner
    if (ownerData is! Map<String, dynamic>) {
      return OwnerModel();
    }

    // 检查Map是否包含有效数据（至少有一个非空字段）
    final hasValidData = ownerData.values
        .any((value) => value != null && value.toString().trim().isNotEmpty);

    if (!hasValidData) {
      return OwnerModel();
    }

    return OwnerModel.fromJson(ownerData);
  }

  // 安全的数字转换方法
  static double _safeToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        debugPrint('⚠️ 无法解析数字字符串: $value');
        return 0.0;
      }
    }
    return 0.0;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'toyName': toyName,
        'toyPicUrl': toyPicUrl,
        'localUrl': localUrl,
        'picWidth': picWidth,
        'picHeight': picHeight,
        'description': description,
        'labels': labels,
        'owner': owner.toJson(),
        'price': price,
        'sellPrice': sellPrice,
        'isSelled': isSelled,
        'sellAt': sellAt,
        "createAt": createAt
      };
}

class AllToysModel {
  final List<ToyModel> toyList;
  AllToysModel({required this.toyList});
  factory AllToysModel.fromJson(List json) {
    return AllToysModel(
        toyList: json.map((i) => ToyModel.fromJson(i)).toList());
  }
}

class ReturnBody {
  final double width;
  final double height;
  final String key;

  ReturnBody({
    required this.width,
    required this.height,
    required this.key,
  });

  factory ReturnBody.fromJson(Map<String, dynamic> json) {
    return ReturnBody(
        width: _safeToDouble(json["width"]),
        height: _safeToDouble(json["height"]),
        key: json["key"] ?? '');
  }

  // 安全的数字转换方法
  static double _safeToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        debugPrint('⚠️ ReturnBody: 无法解析数字字符串: $value');
        return 0.0;
      }
    }
    return 0.0;
  }

  Map<String, dynamic> toJson() {
    return {"width": width, "height": height, "key": key};
  }
}
