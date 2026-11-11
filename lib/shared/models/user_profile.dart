class UserProfile {
  final String uid;
  final String name;
  final String email;
  final String location;
  final String phone;
  final String? avatarPath;
  final String? avatarUrl;
  final int scanCount;
  final String createdAt;

  const UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    this.location = '',
    this.phone = '',
    this.avatarPath,
    this.avatarUrl,
    this.scanCount = 0,
    required this.createdAt,
  });

  factory UserProfile.fromMap(String uid, Map<String, dynamic> map) {
    return UserProfile(
      uid: uid,
      name: map['name'] as String? ?? map['displayName'] as String? ?? '',
      email: map['email'] as String? ?? '',
      location: map['location'] as String? ?? '',
      phone: map['phone']?.toString() ?? '',
      avatarPath: map['avatarPath'] as String?,
      avatarUrl: map['avatarUrl'] as String?,
      scanCount: (map['scanCount'] as int?) ?? 0,
      createdAt: map['createdAt']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'location': location,
      'phone': phone,
      if (avatarPath != null) 'avatarPath': avatarPath,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      'scanCount': scanCount,
      'createdAt': createdAt,
    };
  }

  UserProfile copyWith({
    String? name,
    String? email,
    String? location,
    String? phone,
    String? avatarPath,
    String? avatarUrl,
    int? scanCount,
  }) {
    return UserProfile(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      location: location ?? this.location,
      phone: phone ?? this.phone,
      avatarPath: avatarPath ?? this.avatarPath,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      scanCount: scanCount ?? this.scanCount,
      createdAt: createdAt,
    );
  }

  @override
  String toString() => 'UserProfile(uid: $uid, name: $name, email: $email)';
}
