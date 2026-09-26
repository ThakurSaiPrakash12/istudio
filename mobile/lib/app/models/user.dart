class User {
  const User({
    required this.id,
    required this.username,
    required this.phone,
    this.studioName = '',
    this.ownerName = '',
    this.email = '',
    this.city = '',
    this.address = '',
    this.about = '',
    this.instagram = '',
    this.youtube = '',
    this.website = '',
    this.specialties = '',
    this.logoUrl = '',
    this.googleId = '',
  });

  final String id;
  final String username;
  final String phone;
  final String studioName;
  final String ownerName;
  final String email;
  final String city;
  final String address;
  final String about;
  final String instagram;
  final String youtube;
  final String website;
  final String specialties;
  final String logoUrl;
  final String googleId;

  String get displayStudioName =>
      studioName.isNotEmpty ? studioName : 'Your studio';

  String get displayOwner => ownerName.isNotEmpty ? ownerName : username;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      studioName: json['studioName'] as String? ?? '',
      ownerName: json['ownerName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      city: json['city'] as String? ?? '',
      address: json['address'] as String? ?? '',
      about: json['about'] as String? ?? '',
      instagram: json['instagram'] as String? ?? '',
      youtube: json['youtube'] as String? ?? '',
      website: json['website'] as String? ?? '',
      specialties: json['specialties'] as String? ?? '',
      logoUrl: json['logoUrl'] as String? ?? '',
      googleId: json['googleId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'phone': phone,
      'studioName': studioName,
      'ownerName': ownerName,
      'email': email,
      'city': city,
      'address': address,
      'about': about,
      'instagram': instagram,
      'youtube': youtube,
      'website': website,
      'specialties': specialties,
      'logoUrl': logoUrl,
      'googleId': googleId,
    };
  }

  User copyWith({
    String? studioName,
    String? ownerName,
    String? phone,
    String? email,
    String? city,
    String? address,
    String? about,
    String? instagram,
    String? youtube,
    String? website,
    String? specialties,
    String? logoUrl,
    String? googleId,
  }) {
    return User(
      id: id,
      username: username,
      phone: phone ?? this.phone,
      studioName: studioName ?? this.studioName,
      ownerName: ownerName ?? this.ownerName,
      email: email ?? this.email,
      city: city ?? this.city,
      address: address ?? this.address,
      about: about ?? this.about,
      instagram: instagram ?? this.instagram,
      youtube: youtube ?? this.youtube,
      website: website ?? this.website,
      specialties: specialties ?? this.specialties,
      logoUrl: logoUrl ?? this.logoUrl,
      googleId: googleId ?? this.googleId,
    );
  }
}
