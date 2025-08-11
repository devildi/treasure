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
      name: json["name"],
      uid: json["_id"],
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
}

class PriceCountModel {
  final double totalPrice;
  final int count;

  PriceCountModel({
    this.totalPrice = 0.0,
    this.count = 0,
  });

  factory PriceCountModel.fromJson(Map<String, dynamic> json) {
    return PriceCountModel(
      totalPrice: json["totalPrice"],
      count: json["count"],
    );
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
    return ResultModel(
      ok: json["ok"],
      n: json["n"],
      deletedCount: json["deletedCount"],
    );
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
    
    return ToyModel(
      id: json['_id'] ?? '',
      toyName : json['toyName'],
      toyPicUrl : json['toyPicUrl'] ?? '',
      localUrl : json['localUrl'] ?? '',
      picWidth : json['picWidth'] ?? '',
      picHeight : json['picHeight'] ?? '',
      description : json['description']?? '',
      labels : json['labels'] ?? '',
      owner : json['owner'] != null ? OwnerModel.fromJson(json['owner']) : OwnerModel(),
      price : json['price'] ?? 0,
      sellPrice : json['sellPrice'] ?? 0,
      isSelled: json["isSelled"] ?? false,
      createAt: json["createAt"] ?? '',
      sellAt: json["sellAt"] ?? '',
    );
  }

  Map<String, dynamic> toJson() =>
    {  
      'id': id,
      'toyName': toyName,
      'toyPicUrl': toyPicUrl,
      'localUrl': localUrl,
      'picWidth': picWidth,
      'picHeight': picHeight,
      'description': description,
      'labels': labels,
      'owner': owner,
      'price': price,
      'sellPrice': sellPrice,
      'isSelled': isSelled,
      'sellAt': sellAt,
      "createAt": createAt
    };
}

class AllToysModel {
  final List<ToyModel> toyList;
  AllToysModel({
    required this.toyList
  });
  factory AllToysModel.fromJson(List json){
    return AllToysModel(
      toyList: json.map((i) => ToyModel.fromJson(i)).toList()
    );
  }
}

class ReturnBody {
  final String width;
  final String height;
  final String key;

  ReturnBody({
    required this.width,
    required this.height,
    required this.key,
  });

  factory ReturnBody.fromJson(Map<String, dynamic> json) {
    return ReturnBody(
      width: json["width"],
      height: json["height"],
      key: json["key"]
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "width": width,
      "height": height,
      "key": key
    };
  }
}