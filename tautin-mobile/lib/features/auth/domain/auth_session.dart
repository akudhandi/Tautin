import '../../../shared/models/collection_model.dart';
import '../../../shared/models/user_model.dart';

/// Value object returned by the auth repository after a successful login.
class AuthSession {
  const AuthSession({
    required this.token,
    required this.user,
    required this.collections,
    this.isNewUser = false,
    this.message = '',
  });

  final String token;
  final UserModel user;
  final List<CollectionModel> collections;
  final bool isNewUser;
  final String message;
}
