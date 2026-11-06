import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.statusCode,
    this.code,
    this.existingBatchId,
  });
  final String message;
  final int? statusCode;
  final String? code;
  final int? existingBatchId;
  @override
  String toString() => message;
}

class ApiResponse {
  const ApiResponse(this.data, this.statusCode, this.headers);
  final Map<String, dynamic> data;
  final int statusCode;
  final Map<String, String> headers;
  String? get etag => headers['etag'];
}

class ApiClient {
  ApiClient({required String baseUrl, http.Client? client})
    : _base = Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}/'),
      _client = client ?? http.Client();
  final Uri _base;
  final http.Client _client;
  String? token;
  void Function(String rejectedToken)? onUnauthorized;

  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, Object?>? body,
    bool authenticated = true,
    Map<String, String>? query,
    String? ifMatch,
  }) async => (await requestWithResponse(
    method,
    path,
    body: body,
    authenticated: authenticated,
    query: query,
    ifMatch: ifMatch,
  )).data;

  Future<ApiResponse> requestWithResponse(
    String method,
    String path, {
    Map<String, Object?>? body,
    bool authenticated = true,
    Map<String, String>? query,
    String? ifMatch,
  }) async {
    final sentToken = authenticated ? token : null;
    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (sentToken != null) 'Authorization': 'Bearer $sentToken',
      'If-Match': ?ifMatch,
    };
    try {
      final uri = _base.resolve(path);
      final request = http.Request(
        method,
        query == null ? uri : uri.replace(queryParameters: query),
      );
      request.headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);
      final response = await (() async {
        final stream = await _client.send(request);
        return http.Response.fromStream(stream);
      })().timeout(const Duration(seconds: 15));
      Map<String, dynamic> json = {};
      try {
        if (response.body.isNotEmpty) {
          json = jsonDecode(response.body) as Map<String, dynamic>;
        }
      } on FormatException {
        /* A proxy may return HTML; never display it. */
      } on TypeError {
        /* Treat an unexpected payload as a protocol error. */
      }
      if (response.statusCode >= 400) {
        if (response.statusCode == 401 && sentToken != null) {
          onUnauthorized?.call(sentToken);
        }
        throw ApiException(
          json['detail'] as String? ??
              json['title'] as String? ??
              (response.statusCode == 401
                  ? 'Vui lòng đăng nhập lại.'
                  : 'Không thể xử lý yêu cầu.'),
          statusCode: response.statusCode,
          code: json['code'] as String?,
          existingBatchId: json['existingBatchId'] as int?,
        );
      }
      if (response.statusCode != 204 && json.isEmpty) {
        throw const ApiException('Phản hồi máy chủ không hợp lệ.');
      }
      return ApiResponse(json, response.statusCode, response.headers);
    } on TimeoutException {
      throw const ApiException('Kết nối quá thời gian. Vui lòng thử lại.');
    } on http.ClientException {
      throw const ApiException(
        'Không kết nối được máy chủ. Kiểm tra mạng và địa chỉ API.',
      );
    }
  }

  void close() => _client.close();
}
