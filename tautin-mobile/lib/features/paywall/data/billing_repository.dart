import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../core/storage/storage_provider.dart';
import '../../../shared/models/user_model.dart';

abstract interface class BillingRepository {
  Future<UserModel> verifyPurchase({
    required String productId,
    required String purchaseToken,
    String? orderId,
  });

  Future<UserModel> restorePurchases();
}

class TautinBillingRepository implements BillingRepository {
  TautinBillingRepository({
    required Dio dio,
    required LocalStorage storage,
  })  : _dio = dio,
        _storage = storage;

  final Dio _dio;
  final LocalStorage _storage;

  @override
  Future<UserModel> verifyPurchase({
    required String productId,
    required String purchaseToken,
    String? orderId,
  }) async {
    final Response<dynamic> response = await _dio.post<Object?>(
      '/billing/verify-purchase',
      data: <String, dynamic>{
        'product_id': productId,
        'purchase_token': purchaseToken,
        if (orderId != null) 'order_id': orderId,
      },
    );

    final ApiEnvelope envelope = ApiEnvelope.requireSuccess(response);
    final Map<String, dynamic> data =
        (envelope.data as Map? ?? <Object?, Object?>{}).cast<String, dynamic>();

    final UserModel updatedUser = UserModel.fromJson(
      (data['user'] as Map? ?? <Object?, Object?>{}).cast<String, dynamic>(),
    );

    _storage.saveUser(updatedUser);
    return updatedUser;
  }

  @override
  Future<UserModel> restorePurchases() async {
    final Response<dynamic> response =
        await _dio.post<Object?>('/billing/restore');

    final ApiEnvelope envelope = ApiEnvelope.requireSuccess(response);
    final Map<String, dynamic> data =
        (envelope.data as Map? ?? <Object?, Object?>{}).cast<String, dynamic>();

    final UserModel updatedUser = UserModel.fromJson(
      (data['user'] as Map? ?? <Object?, Object?>{}).cast<String, dynamic>(),
    );

    _storage.saveUser(updatedUser);
    return updatedUser;
  }
}

final Provider<BillingRepository> billingRepositoryProvider =
    Provider<BillingRepository>(
  (Ref ref) => TautinBillingRepository(
    dio: ref.watch(dioProvider),
    storage: ref.watch(localStorageProvider),
  ),
);
