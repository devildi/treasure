import 'package:flutter/material.dart';
import 'package:treasure/toy_model.dart';

class UserData with ChangeNotifier {
  UserData({
    required this.user,
    this.netWorkStatus = true,
    this.page = 2,
    this.pre = 0,
    this.loading = false,
    this.local = true,
  });
  OwnerModel user;
  bool netWorkStatus;
  int page;
  int pre;
  bool loading;
  bool local;

  void setUserData(OwnerModel dartObj){
    user = dartObj;
    notifyListeners();
  }
  void setNetWorkStatus(flag){
    netWorkStatus = flag;
    notifyListeners();
  }
  void setPage(index){
    page = index;
    notifyListeners();
  }
  void setPre(index){
    pre = index;
    notifyListeners();
  }
  void setLoading(flag){
    loading = flag;
    notifyListeners();
  }

  void setLocal(flag){
    local = flag;
    notifyListeners();
  }
}