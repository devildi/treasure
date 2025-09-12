class ApiResponse<T> {
  final T? data;
  final int statusCode;
  final String message;
  final bool success;

  const ApiResponse._({
    this.data,
    required this.statusCode,
    required this.message,
    required this.success,
  });

  factory ApiResponse.success({
    required T? data,
    required int statusCode,
    required String message,
  }) {
    return ApiResponse._(
      data: data,
      statusCode: statusCode,
      message: message,
      success: true,
    );
  }

  factory ApiResponse.error({
    required int statusCode,
    required String message,
    T? data,
  }) {
    return ApiResponse._(
      data: data,
      statusCode: statusCode,
      message: message,
      success: false,
    );
  }

  bool get isSuccess => success;
  bool get isError => !success;

  @override
  String toString() {
    return 'ApiResponse(data: $data, statusCode: $statusCode, message: $message, success: $success)';
  }
}