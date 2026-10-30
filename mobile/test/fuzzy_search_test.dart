import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_studio/app/models/photographer_profile.dart';
import 'package:lumen_studio/app/utils/fuzzy_search_utils.dart';

void main() {
  group('FuzzySearchUtils Tests', () {
    test('1. Matches uppercase studio details with lowercase search query', () {
      const profile = PhotographerProfile(
        id: 'p-1',
        username: 'lumen_studio',
        phone: '9876543210',
        studioName: 'SRI BALAJI STUDIOS',
        ownerName: 'KUMAR',
        city: 'HYDERABAD',
        state: 'TELANGANA',
        district: 'HYDERABAD',
        address: 'THILAK NAGAR, MAIN ROAD',
        categories: ['Traditional Photographer', 'Candid Photographer'],
      );

      // Lowercase location search
      final scoreLocation = FuzzySearchUtils.scorePhotographer(profile, 'thilak nagar');
      expect(scoreLocation > 0.7, isTrue, reason: 'Lowercase thilak nagar should match uppercase THILAK NAGAR');

      // Single word location
      final scoreCity = FuzzySearchUtils.scorePhotographer(profile, 'hyderabad');
      expect(scoreCity > 0.7, isTrue);

      // Studio name match
      final scoreStudio = FuzzySearchUtils.scorePhotographer(profile, 'balaji');
      expect(scoreStudio > 0.7, isTrue);
    });

    test('2. Typo tolerance: matches misspelled location names', () {
      const profile = PhotographerProfile(
        id: 'p-2',
        username: 'lens_art',
        phone: '9876543211',
        studioName: 'Lens Art Studio',
        city: 'Thilak Nagar',
        district: 'Hyderabad',
        state: 'Telangana',
        address: 'Opposite Gandhi Statue, Thilak Nagar',
        categories: ['Candid Photographer'],
      );

      // "tilak nagar" (omitted 'h')
      final scorePhonetic = FuzzySearchUtils.scorePhotographer(profile, 'tilak nagar');
      expect(scorePhonetic > 0.7, isTrue, reason: 'tilak nagar should match Thilak Nagar');

      // "thilak nager" (vowel typo)
      final scoreTypo = FuzzySearchUtils.scorePhotographer(profile, 'thilak nager');
      expect(scoreTypo > 0.7, isTrue, reason: 'thilak nager should match Thilak Nagar');

      // "thilaknagar" (no space)
      final scoreSquashed = FuzzySearchUtils.scorePhotographer(profile, 'thilaknagar');
      expect(scoreSquashed > 0.7, isTrue, reason: 'thilaknagar should match Thilak Nagar');

      // "hyderbad" typo for Hyderabad
      const profile2 = PhotographerProfile(
        id: 'p-3',
        username: 'city_lens',
        phone: '9876543212',
        studioName: 'City Lens',
        city: 'Hyderabad',
      );
      final scoreHyd = FuzzySearchUtils.scorePhotographer(profile2, 'hyderbad');
      expect(scoreHyd > 0.7, isTrue, reason: 'hyderbad should match Hyderabad');
    });

    test('3. Category search: matches photographers when query specifies related categories', () {
      const dronePhotographer = PhotographerProfile(
        id: 'p-drone',
        username: 'sky_drone',
        phone: '9876543213',
        studioName: 'Sky High Shoots',
        city: 'Visakhapatnam',
        categories: ['Drones'],
      );

      const weddingPhotographer = PhotographerProfile(
        id: 'p-wedding',
        username: 'royal_weddings',
        phone: '9876543214',
        studioName: 'Royal Weddings',
        city: 'Vijayawada',
        categories: ['Traditional Photographer', 'Candid Photographer'],
      );

      // Search "drone" matches Drones category
      final scoreDrone = FuzzySearchUtils.scorePhotographer(dronePhotographer, 'drone');
      expect(scoreDrone > 0.7, isTrue);

      // Search "wedding" matches Traditional/Candid Photographer
      final scoreWedding = FuzzySearchUtils.scorePhotographer(weddingPhotographer, 'wedding');
      expect(scoreWedding > 0.7, isTrue);
    });

    test('4. District fuzzy matching in India location picker', () {
      // Matches even with typos or colloquial aliases
      expect(FuzzySearchUtils.matchesLocation('Visakhapatnam', 'visakapatnam'), isTrue);
      expect(FuzzySearchUtils.matchesLocation('Visakhapatnam', 'vizag'), isTrue);
      expect(FuzzySearchUtils.matchesLocation('Hyderabad', 'hyderbad'), isTrue);
      expect(FuzzySearchUtils.matchesLocation('Bengaluru Urban', 'bangalore'), isTrue);
      expect(FuzzySearchUtils.matchesLocation('Thiruvananthapuram', 'trivandrum'), isTrue);
    });

    test('5. Single-letter and short prefix matching (e.g. typing "m")', () {
      const profile = PhotographerProfile(
        id: 'p-mumbai',
        username: 'mumbai_frames',
        phone: '9876543215',
        studioName: 'Modern Wedding Studio',
        ownerName: 'Mahesh Sharma',
        city: 'Mumbai',
        categories: ['Maternity Photographer'],
      );

      const profile2 = PhotographerProfile(
        id: 'p-delhi',
        username: 'delhi_clicks',
        phone: '9876543216',
        studioName: 'Delhi Lens Works',
        ownerName: 'Rajesh Gupta',
        city: 'Delhi',
        categories: ['Drones'],
      );

      // "m" should match profile with Modern, Mahesh, Mumbai, Maternity
      final scoreM = FuzzySearchUtils.scorePhotographer(profile, 'm');
      expect(scoreM > 0.7, isTrue, reason: '"m" should match studio/city/owner starting with M');

      // "m" should not match profile2 which has no words starting with or containing M
      final scoreM2 = FuzzySearchUtils.scorePhotographer(profile2, 'm');
      expect(scoreM2 < 0.5, isTrue, reason: '"m" should not match Delhi Lens Works');
    });

    test('6. User typos in live search: matches misspelled terms (vedio, drne, wedin, hydrbd, vzag, potrait)', () {
      const droneStudio = PhotographerProfile(
        id: 'p-drone',
        username: 'sky_drone',
        phone: '9876543217',
        studioName: 'Aero Aerial Works',
        city: 'Visakhapatnam',
        categories: ['Drones'],
      );

      const weddingStudio = PhotographerProfile(
        id: 'p-wedding',
        username: 'royal_frames',
        phone: '9876543218',
        studioName: 'Royal Wedding Portraits',
        ownerName: 'Rahul Kumar',
        city: 'Hyderabad',
        categories: ['Traditional Photographer', 'Candid Photographer'],
        specialties: 'Wedding Photography, Pre-wedding',
      );

      const videoStudio = PhotographerProfile(
        id: 'p-video',
        username: 'cinematic_lens',
        phone: '9876543219',
        studioName: 'Cinema Motion',
        city: 'Bengaluru',
        categories: ['Cinematic Videographer', 'Traditional Videographer'],
      );

      // 1. Categories spelling mistakes
      expect(FuzzySearchUtils.scorePhotographer(droneStudio, 'drne') > 0.7, isTrue, reason: 'drne -> Drones');
      expect(FuzzySearchUtils.scorePhotographer(videoStudio, 'vedio') > 0.7, isTrue, reason: 'vedio -> Video');
      expect(FuzzySearchUtils.scorePhotographer(weddingStudio, 'wedin') > 0.7, isTrue, reason: 'wedin -> Wedding');
      expect(FuzzySearchUtils.scorePhotographer(weddingStudio, 'weddn') > 0.7, isTrue, reason: 'weddn -> Wedding');
      expect(FuzzySearchUtils.scorePhotographer(weddingStudio, 'canid') > 0.7, isTrue, reason: 'canid -> Candid');
      expect(FuzzySearchUtils.scorePhotographer(weddingStudio, 'potrait') > 0.7, isTrue, reason: 'potrait -> Portrait');
      expect(FuzzySearchUtils.scorePhotographer(videoStudio, 'cinmatic') > 0.7, isTrue, reason: 'cinmatic -> Cinematic');

      // 2. Studio name spelling mistakes
      expect(FuzzySearchUtils.scorePhotographer(weddingStudio, 'royel') > 0.7, isTrue, reason: 'royel -> Royal');
      expect(FuzzySearchUtils.scorePhotographer(droneStudio, 'aeriel') > 0.7, isTrue, reason: 'aeriel -> Aerial');
      expect(FuzzySearchUtils.scorePhotographer(videoStudio, 'cinma') > 0.7, isTrue, reason: 'cinma -> Cinema');

      // 3. Owner name spelling mistakes
      expect(FuzzySearchUtils.scorePhotographer(weddingStudio, 'rahl') > 0.7, isTrue, reason: 'rahl -> Rahul');
      expect(FuzzySearchUtils.scorePhotographer(weddingStudio, 'kmar') > 0.7, isTrue, reason: 'kmar -> Kumar');

      // 4. Location spelling mistakes (city, district, alias)
      expect(FuzzySearchUtils.scorePhotographer(weddingStudio, 'hydrbd') > 0.7, isTrue, reason: 'hydrbd -> Hyderabad');
      expect(FuzzySearchUtils.scorePhotographer(weddingStudio, 'hydrabad') > 0.7, isTrue, reason: 'hydrabad -> Hyderabad');
      expect(FuzzySearchUtils.scorePhotographer(droneStudio, 'vzag') > 0.7, isTrue, reason: 'vzag -> Visakhapatnam (Vizag)');
      expect(FuzzySearchUtils.scorePhotographer(videoStudio, 'benglore') > 0.7, isTrue, reason: 'benglore -> Bengaluru');
    });
  });
}
