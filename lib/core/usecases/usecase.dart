// lib/core/usecases/usecase.dart

import 'package:dartz/dartz.dart';
import 'package:hermes/core/errors/failure.dart';

/// Abstract class for a Use Case
abstract class UseCase<Type, Params> {
  /// Call method to execute the use case
  Future<Either<Failure, Type>> call(Params params);
}

/// Use case with no parameters
abstract class NoParamsUseCase<Type> {
  /// Call method to execute the use case
  Future<Either<Failure, Type>> call();
}

/// No parameters class
class NoParams {
  const NoParams();
}
