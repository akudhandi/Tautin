import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../domain/gamification_summary.dart';

abstract interface class GamificationRepository {
  Future<GamificationSummary> fetchSummary();
}

class HttpGamificationRepository implements GamificationRepository {
  HttpGamificationRepository(this._dio);

  final Dio _dio;

  @override
  Future<GamificationSummary> fetchSummary() async {
    final Response<dynamic> res =
        await _dio.get<dynamic>('/api/v1/gamification/summary');

    final Map<String, dynamic> body =
        res.data is Map<String, dynamic> ? res.data as Map<String, dynamic> : <String, dynamic>{};

    final Map<String, dynamic> data =
        body['data'] is Map<String, dynamic> ? body['data'] as Map<String, dynamic> : <String, dynamic>{};

    return GamificationSummary.fromJson(data);
  }
}

final Provider<GamificationRepository> gamificationRepositoryProvider =
    Provider<GamificationRepository>((Ref ref) {
  final Dio dio = ref.watch(dioProvider);
  return HttpGamificationRepository(dio);
});
