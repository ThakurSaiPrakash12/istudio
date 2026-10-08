import 'package:flutter/foundation.dart';

@immutable
class PhotographerProfile {
  const PhotographerProfile({
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
    this.website = '',
    this.categories = const [],
    this.specialties = '',
    this.logoUrl = '',
    this.latitude,
    this.longitude,
    this.distanceKm,
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
  final String website;
  final List<String> categories;
  final String specialties;
  final String logoUrl;
  final double? latitude;
  final double? longitude;
  final double? distanceKm;

  String? get displayDistance {
    if (distanceKm == null) return null;
    return '${distanceKm!.toStringAsFixed(1)} km away';
  }

  String get displayName =>
      studioName.trim().isNotEmpty ? studioName : (ownerName.trim().isNotEmpty ? ownerName : username);

  String get displayOwner =>
      ownerName.trim().isNotEmpty ? ownerName : username;

  String get displayLocation {
    if (city.trim().isNotEmpty && address.trim().isNotEmpty) {
      return '$city • $address';
    }
    if (city.trim().isNotEmpty) return city;
    if (address.trim().isNotEmpty) return address;
    return 'Location not specified';
  }

  factory PhotographerProfile.fromJson(Map<String, dynamic> json) {
    return PhotographerProfile(
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
      website: json['website'] as String? ?? '',
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
      specialties: json['specialties'] as String? ?? '',
      logoUrl: json['logoUrl'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
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
        'website': website,
        'categories': categories,
        'specialties': specialties,
        'logoUrl': logoUrl,
        'latitude': latitude,
        'longitude': longitude,
        'distanceKm': distanceKm,
      };
}
