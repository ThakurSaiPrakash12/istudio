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
    this.categories = const [],
    this.logoUrl = '',
    this.paymentQrUrl = '',
    this.googleId = '',
    this.needsPasswordSetup = false,
    this.latitude,
    this.longitude,
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
  final List<String> categories;
  final String logoUrl;
  final String paymentQrUrl;
  final String googleId;
  final bool needsPasswordSetup;
  final double? latitude;
  final double? longitude;

  bool get hasCategories => categories.isNotEmpty;

  String get displayStudioName =>
      studioName.isNotEmpty ? studioName : 'Your studio';

  String get displayOwner => ownerName.isNotEmpty ? ownerName : username;

  bool get isGoogleUser => googleId.isNotEmpty;

  /// Socials (instagram, youtube, website) and the logo are optional.
  bool get isProfileIncomplete => [
        studioName,
        ownerName,
        phone,
        email,
        city,
        address,
        specialties,
        about,
      ].any((value) => value.trim().isEmpty);

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
      categories: (json['categories'] as List<dynamic>?)
              ?.map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList() ??
          ((json['specialties'] is String && (json['specialties'] as String).trim().isNotEmpty)
              ? (json['specialties'] as String)
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList()
              : const []),
      logoUrl: json['logoUrl'] as String? ?? '',
      paymentQrUrl: json['paymentQrUrl'] as String? ?? '',
      googleId: json['googleId'] as String? ?? '',
      needsPasswordSetup: json['needsPasswordSetup'] as bool? ?? false,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
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
      'categories': categories,
      'logoUrl': logoUrl,
      'paymentQrUrl': paymentQrUrl,
      'googleId': googleId,
      'needsPasswordSetup': needsPasswordSetup,
      'latitude': latitude,
      'longitude': longitude,
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
    List<String>? categories,
    String? logoUrl,
    String? paymentQrUrl,
    String? googleId,
    bool? needsPasswordSetup,
    double? latitude,
    double? longitude,
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
      categories: categories ?? this.categories,
      logoUrl: logoUrl ?? this.logoUrl,
      paymentQrUrl: paymentQrUrl ?? this.paymentQrUrl,
      googleId: googleId ?? this.googleId,
      needsPasswordSetup: needsPasswordSetup ?? this.needsPasswordSetup,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}
