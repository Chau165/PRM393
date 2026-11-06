class SessionWarehouse {
  const SessionWarehouse({
    required this.id,
    required this.code,
    required this.name,
  });
  final int id;
  final String code;
  final String name;
  factory SessionWarehouse.fromJson(Map<String, dynamic> json) =>
      SessionWarehouse(
        id: json['id'] as int,
        code: json['code'] as String,
        name: json['name'] as String,
      );
}

class SessionUser {
  const SessionUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
    required this.warehouses,
    this.version = '',
  });
  final int id;
  final String username;
  final String fullName;
  final String role;
  final List<SessionWarehouse> warehouses;
  final String version;
  List<int> get warehouseIds =>
      warehouses.map((w) => w.id).toList(growable: false);
  factory SessionUser.fromJson(Map<String, dynamic> json) => SessionUser(
    id: json['id'] as int,
    username: json['username'] as String,
    fullName: json['fullName'] as String,
    role: json['role'] as String,
    version: json['version'] as String? ?? '',
    warehouses: (json['warehouses'] as List)
        .map((w) => SessionWarehouse.fromJson(w as Map<String, dynamic>))
        .toList(),
  );
}
