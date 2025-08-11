import 'dart:async';
import 'package:dio/dio.dart';
import 'package:treasure/toy_model.dart';

const bool developMode = false;
const String urlBase = developMode ? 'http://172.20.10.13:4000/' : 'https://nextsticker.cn/';

const loginUrl = '${urlBase}api/treasure/login';
const registerUrl = '${urlBase}api/treasure/register';
const tokenUrl = '${urlBase}api/trip/getUploadToken';
const poMicroURL = '${urlBase}api/treasure/newItem';
const allToies = '${urlBase}api/treasure/getAllTreasures?page=';
const totalPriceAndCount = '${urlBase}api/treasure/getTotalPriceAndCount?uid=';
const search = '${urlBase}api/treasure/search?keyword=';
const modifyURL = '${urlBase}api/treasure/modify';
const deleteURL = '${urlBase}api/treasure/delete';

class TreasureDao{
  static Future register(data) async{
    final response = await Dio().post(registerUrl, data:data);
    if (response.statusCode == 200) {
      if(response.data == '此用户名已经注册！'){
        return '此用户名已经注册！';
      }if(response.data == '未授权！'){
        return '未授权！';
      }else {
        return OwnerModel.fromJson(response.data);
      } 
    } else if(response.statusCode == 401){
      //print(401);
      return '授权码错误！';
    } else {
      throw Exception('Failed to load data!');
    }
  }

  static Future login(data) async{
    final response = await Dio().post(loginUrl, data:data);
    if(response.data == ''){
      return OwnerModel();
    }else {
      return OwnerModel.fromJson(response.data);
    } 
  }

  static Future getToken(string) async{
    final token = await Dio().get('$tokenUrl?type=$string');
    return token.data;
  }

  static Future poMicro(data)async {
    final response = await Dio().post(poMicroURL, data:data);
    if(response.data != null){
      return response.data;
    }else {
      throw Exception('NetWork Error!');
    }
  }

  static Future<AllToysModel> searchToies(string, uid)async {
    final response = await Dio().get('$search$string&uid=$uid');
    if(response.data != null){
      return AllToysModel.fromJson(response.data);
    }else {
      throw Exception('NetWork Error!');
    }
  }

  static Future<AllToysModel> getAllToies(index, uid)async {
    final response = await Dio().get('$allToies$index&uid=$uid');
    if(response.data != null){
      return AllToysModel.fromJson(response.data);
    }else {
      throw Exception('NetWork Error!');
    }
  }

  static Future getTotalPriceAndCount(uid)async {
    final response = await Dio().get('$totalPriceAndCount$uid');
    if(response.data != null){
      return PriceCountModel.fromJson(response.data);
    }else {
      throw Exception('NetWork Error!');
    }
  }

  static Future modifyToy(data) async {
    final response = await Dio().post(modifyURL, data:data);
    if(response.data != null){
      return response.data;
    }else {
      throw Exception('NetWork Error!');
    }
  }

  static Future deleteToy(id, key) async {
    final response = await Dio().post(deleteURL, data:{ 'id': id,  'key': key});
    if(response.data != null){
      return ResultModel.fromJson(response.data);
    }else {
      throw Exception('NetWork Error!');
    }
  }
}