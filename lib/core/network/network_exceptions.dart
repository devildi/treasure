abstract class NetworkException implements Exception {
  final String message;
  final int? statusCode;

  const NetworkException({
    required this.message,
    this.statusCode,
  });

  @override
  String toString() {
    return '$runtimeType: $message${statusCode != null ? ' (Status: $statusCode)' : ''}';
  }
}

class ConnectionTimeoutException extends NetworkException {
  ConnectionTimeoutException() : super(message: '连接超时，请检查网络连接');
}

class SendTimeoutException extends NetworkException {
  SendTimeoutException() : super(message: '发送超时，请重试');
}

class ReceiveTimeoutException extends NetworkException {
  ReceiveTimeoutException() : super(message: '接收超时，请重试');
}

class NoInternetException extends NetworkException {
  NoInternetException() : super(message: '网络连接不可用，请检查网络设置');
}

class ServerException extends NetworkException {
  ServerException({
    int? statusCode,
    String? message,
  }) : super(
    statusCode: statusCode,
    message: message ?? '服务器错误',
  );
}

class RequestCancelledException extends NetworkException {
  RequestCancelledException() : super(message: '请求已取消');
}

class UnauthorizedException extends NetworkException {
  UnauthorizedException() : super(
    message: '未授权访问，请重新登录',
    statusCode: 401,
  );
}

class ForbiddenException extends NetworkException {
  ForbiddenException() : super(
    message: '禁止访问',
    statusCode: 403,
  );
}

class NotFoundException extends NetworkException {
  NotFoundException() : super(
    message: '请求的资源不存在',
    statusCode: 404,
  );
}

class BadRequestException extends NetworkException {
  BadRequestException({String? message}) : super(
    message: message ?? '请求参数错误',
    statusCode: 400,
  );
}

class UnknownNetworkException extends NetworkException {
  UnknownNetworkException({required String message}) : super(message: message);
}