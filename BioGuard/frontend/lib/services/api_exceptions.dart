/// BioGuard — API Exceptions
/// Lets the provider layer distinguish "token is dead, log the user out"
/// from "something else went wrong, show an error."
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class UnauthorizedException extends ApiException {
  UnauthorizedException([String message = 'Session expired'])
    : super(message, statusCode: 401);
}
