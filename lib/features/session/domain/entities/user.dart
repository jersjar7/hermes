// lib/features/session/domain/entities/user.dart

import 'package:equatable/equatable.dart';

/// Represents a user entity in the domain layer
class User extends Equatable {
  /// Unique identifier for the user
  final String id;

  /// Display name for the user (optional)
  final String? name;

  /// User's role in the system
  final UserRole role;

  /// User's preferred language for translation
  final String preferredLanguage;

  /// When the user was created
  final DateTime createdAt;

  /// Creates a new [User] instance
  const User({
    required this.id,
    this.name,
    required this.role,
    required this.preferredLanguage,
    required this.createdAt,
  });

  /// Creates a copy of this user with the given fields replaced
  User copyWith({
    String? id,
    String? name,
    UserRole? role,
    String? preferredLanguage,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [id, name, role, preferredLanguage, createdAt];
}

/// Possible roles for a user
enum UserRole {
  /// Speaker role
  speaker,

  /// Audience role
  audience,
}

/// Extensions for [UserRole] enum
extension UserRoleX on UserRole {
  /// Convert [UserRole] to string
  String toValue() {
    switch (this) {
      case UserRole.speaker:
        return 'speaker';
      case UserRole.audience:
        return 'audience';
    }
  }

  /// Create [UserRole] from string
  static UserRole fromString(String value) {
    switch (value) {
      case 'speaker':
        return UserRole.speaker;
      case 'audience':
        return UserRole.audience;
      default:
        return UserRole.audience;
    }
  }
}
