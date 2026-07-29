class Failure {
  final String message;
  final int? statusCode;

  const Failure({required this.message, this.statusCode});
  @override
  String toString() =>
      'Failure :$message ${statusCode != null ? "($statusCode)" : ""}';
}

class NetworkFailure extends Failure {
  const NetworkFailure({super.message = "No Internet Connection"});
}

class ServerFailure extends Failure {
  const ServerFailure({
    super.message = "Something Wrong On Server",
    super.statusCode,
  });
}

class AuthFailure extends Failure {
  const AuthFailure({
    super.message = "Authentication Failed",
    super.statusCode = 401,
  });
}

class NotFoundFailure extends Failure {
  const NotFoundFailure({
    super.message = "Data Not Found",
    super.statusCode = 404,
  });
}
