class User {
  final String id;
  final String name;
  final String email;
  final String role;
  final List<String> parkIds;
  final bool passwordChangeRequired;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.parkIds,
    this.passwordChangeRequired = false,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? '',
      parkIds: json['parkIds'] != null ? List<String>.from(json['parkIds']) : [],
      passwordChangeRequired: json['passwordChangeRequired'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'parkIds': parkIds,
      'passwordChangeRequired': passwordChangeRequired,
    };
  }
}
