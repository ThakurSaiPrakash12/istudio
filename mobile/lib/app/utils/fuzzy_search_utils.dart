import 'dart:math';
import '../models/photographer_profile.dart';

/// Client-side fuzzy search and typo-tolerance utility for Discover.
///
/// Mirrors the design of the JS fuzzySearch.js engine:
///   • Case-insensitive, whitespace- and punctuation-normalised matching
///   • Short-token guard: query tokens ≤ 2 chars are excluded from scoring
///   • Length-aware Levenshtein edit-distance thresholds
///   • Phonetic normalisation for common Indian transliteration variants
///   • Configurable synonym and alias tables — not hardcoded neighbourhoods
///   • Multi-token coverage requirements
///       1-2 tokens → both/all must match
///       3+  tokens → at least ⌈N × 0.60⌉ tokens must match
///   • Relevance ordering: exact phrase ≥ normalised exact ≥ squashed ≥ fuzzy
class FuzzySearchUtils {
  FuzzySearchUtils._();

  // ─── Levenshtein ─────────────────────────────────────────────────────────

  static int levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final aLen = a.length;
    final bLen = b.length;

    List<int> prev = List<int>.generate(bLen + 1, (i) => i);
    List<int> curr = List<int>.filled(bLen + 1, 0);

    for (int i = 1; i <= aLen; i++) {
      curr[0] = i;
      final aC = a.codeUnitAt(i - 1);
      for (int j = 1; j <= bLen; j++) {
        final cost = aC == b.codeUnitAt(j - 1) ? 0 : 1;
        curr[j] = min(curr[j - 1] + 1, min(prev[j] + 1, prev[j - 1] + cost));
      }
      final tmp = prev;
      prev = curr;
      curr = tmp;
    }
    return prev[bLen];
  }

  static double similarity(String a, String b) {
    if (a.isEmpty && b.isEmpty) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;
    if (a == b) return 1.0;
    final maxLen = max(a.length, b.length);
    return (maxLen - levenshtein(a, b)) / maxLen;
  }

  // ─── Text normalisation ───────────────────────────────────────────────────

  /// Lowercase, strip non-word characters to spaces, collapse whitespace.
  static String normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Squash spaces so "thilaknagar" and "thilak nagar" compare equal.
  static String squash(String text) {
    return normalize(text).replaceAll(' ', '');
  }

  /// Phonetic reduction for common Indian transliteration variants and typo patterns.
  /// Applied only for comparison — does not modify stored data.
  static String phoneticNormalize(String text) {
    var s = normalize(text);
    s = s.replaceAll('th', 't');
    s = s.replaceAll('ph', 'f');
    s = s.replaceAll('ee', 'i');
    s = s.replaceAll('oo', 'u');
    s = s.replaceAll('sh', 's');
    s = s.replaceAll('ck', 'k');
    s = s.replaceAll('kh', 'k');
    s = s.replaceAll('dh', 'd');
    s = s.replaceAll('bh', 'b');
    s = s.replaceAll('gh', 'g');
    s = s.replaceAll('ch', 'c');
    s = s.replaceAll('w', 'v');
    s = s.replaceAll('z', 'j');
    // Collapse duplicate letters: 'chennai' -> 'chenai', 'kapoor' -> 'kapor', 'wedding' -> 'weding'
    s = s.replaceAll(RegExp(r'([a-z])\1+'), r'$1');
    return s;
  }

  /// Damerau-Levenshtein edit distance: counts insertions, deletions, substitutions,
  /// and transpositions of adjacent characters as a single edit.
  static int damerauLevenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final aLen = a.length;
    final bLen = b.length;
    final d = List.generate(aLen + 1, (_) => List.filled(bLen + 1, 0));

    for (int i = 0; i <= aLen; i++) {
      d[i][0] = i;
    }
    for (int j = 0; j <= bLen; j++) {
      d[0][j] = j;
    }

    for (int i = 1; i <= aLen; i++) {
      for (int j = 1; j <= bLen; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        d[i][j] = min(
          d[i - 1][j] + 1,
          min(
            d[i][j - 1] + 1,
            d[i - 1][j - 1] + cost,
          ),
        );
        if (i > 1 &&
            j > 1 &&
            a.codeUnitAt(i - 1) == b.codeUnitAt(j - 2) &&
            a.codeUnitAt(i - 2) == b.codeUnitAt(j - 1)) {
          d[i][j] = min(d[i][j], d[i - 2][j - 2] + 1);
        }
      }
    }
    return d[aLen][bLen];
  }

  // ─── Configurable alias / synonym tables ─────────────────────────────────

  /// Well-known Indian city colloquial aliases. Both key and value are lowercase.
  static const Map<String, String> cityAliases = {
    'vizag':              'visakhapatnam',
    'visakha':            'visakhapatnam',
    'visakhapatnam':      'vizag',
    'bangalore':          'bengaluru',
    'bengaluru':          'bangalore',
    'banglore':           'bengaluru',
    'bombay':             'mumbai',
    'mumbai':             'bombay',
    'madras':             'chennai',
    'chennai':            'madras',
    'calcutta':           'kolkata',
    'kolkata':            'calcutta',
    'baroda':             'vadodara',
    'vadodara':           'baroda',
    'cochin':             'kochi',
    'kochi':              'cochin',
    'trivandrum':         'thiruvananthapuram',
    'thiruvananthapuram': 'trivandrum',
    'hyd':                'hyderabad',
    'secbad':             'secunderabad',
    'secunderabad':       'hyderabad',
  };

  /// Mapping of plain-English search terms to photographer category names.
  static const Map<String, List<String>> categorySynonyms = {
    'wedding':        ['Traditional Photographer', 'Candid Photographer', 'Traditional Videographer', 'Cinematic Videographer'],
    'weddings':       ['Traditional Photographer', 'Candid Photographer', 'Traditional Videographer', 'Cinematic Videographer'],
    'marriage':       ['Traditional Photographer', 'Candid Photographer', 'Traditional Videographer', 'Cinematic Videographer'],
    'shaadi':         ['Traditional Photographer', 'Candid Photographer', 'Traditional Videographer', 'Cinematic Videographer'],
    'reception':      ['Traditional Photographer', 'Candid Photographer', 'Traditional Videographer', 'Cinematic Videographer'],
    'engagement':     ['Traditional Photographer', 'Candid Photographer', 'Traditional Videographer', 'Cinematic Videographer'],
    'pelli':          ['Traditional Photographer', 'Candid Photographer', 'Traditional Videographer', 'Cinematic Videographer'],
    'candid':         ['Candid Photographer', 'Candid Videographer', 'Candid Photo Operator', 'Candid Video Operator'],
    'candids':        ['Candid Photographer', 'Candid Videographer', 'Candid Photo Operator', 'Candid Video Operator'],
    'portrait':       ['Candid Photographer'],
    'portraits':      ['Candid Photographer'],
    'traditional':    ['Traditional Photographer', 'Traditional Videographer', 'Traditional Photo Operator', 'Traditional Video Operator'],
    'drone':          ['Drones'],
    'drones':         ['Drones'],
    'aerial':         ['Drones'],
    'flycam':         ['Drones'],
    'mavic':          ['Drones'],
    'cinematic':      ['Cinematic Videographer'],
    'cinematography': ['Cinematic Videographer'],
    'cinematographer':['Cinematic Videographer'],
    'cinema':         ['Cinematic Videographer'],
    'film':           ['Cinematic Videographer'],
    'reels':          ['Reels', 'Cinematic Videographer', 'Candid Video Operator'],
    'reel':           ['Reels'],
    'shorts':         ['Reels'],
    'instagram':      ['Reels'],
    'album':          ['Album Designer'],
    'albums':         ['Album Designer'],
    'design':         ['Album Designer'],
    'designer':       ['Album Designer'],
    'designing':      ['Album Designer'],
    'album designer': ['Album Designer'],
    'album design':   ['Album Designer'],
    'editor':         ['Video Editor'],
    'editer':         ['Video Editor'],
    'editing':        ['Video Editor'],
    'edit':           ['Video Editor'],
    'video editor':   ['Video Editor'],
    'video editer':   ['Video Editor'],
    'operator':       ['Traditional Photo Operator', 'Traditional Video Operator', 'Candid Photo Operator', 'Candid Video Operator'],
    'operators':      ['Traditional Photo Operator', 'Traditional Video Operator', 'Candid Photo Operator', 'Candid Video Operator'],
    'photo operator': ['Traditional Photo Operator', 'Candid Photo Operator'],
    'video operator': ['Traditional Video Operator', 'Candid Video Operator'],
    'traditional photo operator': ['Traditional Photo Operator', 'Traditional Photographer'],
    'traditional video operator': ['Traditional Video Operator', 'Traditional Videographer'],
    'candid video operator':      ['Candid Video Operator', 'Cinematic Videographer'],
    'candid photo operator':      ['Candid Photo Operator', 'Candid Photographer'],
    'video':          ['Traditional Videographer', 'Cinematic Videographer', 'Videography', 'Video Editor', 'Traditional Video Operator', 'Candid Video Operator'],
    'videographer':   ['Traditional Videographer', 'Cinematic Videographer', 'Videography', 'Traditional Video Operator', 'Candid Video Operator'],
    'videography':    ['Traditional Videographer', 'Cinematic Videographer', 'Videography', 'Traditional Video Operator', 'Candid Video Operator'],
    'vidiographer':   ['Traditional Videographer', 'Cinematic Videographer', 'Videography', 'Traditional Video Operator', 'Candid Video Operator'],
    'photo':          ['Traditional Photographer', 'Candid Photographer', 'Photographer', 'Traditional Photo Operator', 'Candid Photo Operator'],
    'photographer':   ['Traditional Photographer', 'Candid Photographer', 'Photographer', 'Traditional Photo Operator', 'Candid Photo Operator'],
    'photography':    ['Traditional Photographer', 'Candid Photographer', 'Photographer', 'Traditional Photo Operator', 'Candid Photo Operator'],
    'fotographer':    ['Traditional Photographer', 'Candid Photographer', 'Photographer', 'Traditional Photo Operator', 'Candid Photo Operator'],
    'led':            ['LED Screens'],
    'screen':         ['LED Screens'],
    'screens':        ['LED Screens'],
    'display':        ['LED Screens'],
    'live':           ['Internet Live Streaming'],
    'stream':         ['Internet Live Streaming'],
    'streaming':      ['Internet Live Streaming'],
    'webcast':        ['Internet Live Streaming'],
    'broadcast':      ['Internet Live Streaming'],
    // Common typo variants
    'vedio':          ['Traditional Videographer', 'Cinematic Videographer', 'Videography', 'Video Editor'],
    'drne':           ['Drones'],
    'weding':         ['Traditional Photographer', 'Candid Photographer'],
    'wedin':          ['Traditional Photographer', 'Candid Photographer'],
    'canid':          ['Candid Photographer'],
    'potrait':        ['Candid Photographer', 'Traditional Photographer'],
    'potraits':       ['Candid Photographer', 'Traditional Photographer'],
    'preweding':      ['Traditional Photographer', 'Candid Photographer'],
    'livestrem':      ['Internet Live Streaming'],
  };

  /// Return consonant skeleton by stripping vowels and non-alphabetic chars.
  /// Useful for Indian transliterations and abbreviation typos (e.g. "hydrbd" -> "hdrbd").
  static String consonantSkeleton(String text) {
    if (text.isEmpty) return '';
    return text.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '').replaceAll(RegExp(r'[aeiouy]'), '');
  }

  // ─── Token-level fuzzy match ──────────────────────────────────────────────

  /// Returns true when qToken and tToken are considered equivalent.
  /// Handles spelling mistakes across studio name, owner name, category, and location.
  static bool tokenFuzzyMatch(String qToken, String tToken) {
    if (qToken.isEmpty || tToken.isEmpty) return false;
    if (qToken == tToken) return true;

    // Short-token guard: allow exact or prefix
    if (qToken.length <= 2 || tToken.length <= 2) {
      return qToken == tToken || tToken.startsWith(qToken);
    }

    final shorter = min(qToken.length, tToken.length);

    // Substring containment — only meaningful if the common part is ≥ 3 chars
    if (shorter >= 3 && (tToken.contains(qToken) || qToken.contains(tToken))) return true;

    // City alias equivalence (including typo on alias, e.g. "vzag" for "vizag" -> "visakhapatnam")
    final qAlias = cityAliases[qToken];
    if (qAlias != null) {
      if (qAlias == tToken || tToken.contains(qAlias) || levenshtein(qAlias, tToken) <= 1) return true;
    }
    final tAlias = cityAliases[tToken];
    if (tAlias != null) {
      if (tAlias == qToken || qToken.contains(tAlias) || levenshtein(tAlias, qToken) <= 1) return true;
    }

    // Phonetic equivalence (handles single/double letters and Indian transliterations)
    final qP = phoneticNormalize(qToken);
    final tP = phoneticNormalize(tToken);
    if (qP == tP) return true;
    if (qP.length >= 3 && tP.length >= 3 && (tP.contains(qP) || qP.contains(tP))) return true;

    // Length-aware Levenshtein / Damerau thresholds (tolerant to spelling mistakes)
    final maxLen = max(qToken.length, tToken.length);
    final dDist  = damerauLevenshtein(qToken, tToken);
    if (maxLen <= 4 && dDist <= 1) return true;
    if (maxLen <= 7 && dDist <= 2) return true; // e.g. "annd" vs "anand", "balji" vs "balaji", "vedio" vs "video", "wedin" vs "wedding"
    if (maxLen <= 11 && dDist <= 2) return true; // e.g. "hydrabad" vs "hyderabad", "potrait" vs "portrait", "chenai" vs "chennai"
    if (maxLen >= 12 && dDist <= 3) return true;

    // Transpositions & 2-char typo for medium words
    if (qToken.length >= 5 && tToken.length >= 5 && (qToken.length - tToken.length).abs() <= 1 && dDist <= 2) {
      if (similarity(qToken, tToken) >= 0.60) return true;
    }

    // Phonetic Levenshtein
    if (levenshtein(qP, tP) <= 1) return true;

    // Prefix typo matching: user is typing a word with a typo in real time (length >= 5)
    if (tToken.length >= 6 && qToken.length >= 5 && qToken.length <= tToken.length) {
      final tPrefix = tToken.substring(0, qToken.length);
      if (damerauLevenshtein(qToken, tPrefix) <= 1) return true;
    }

    // Consonant skeleton (vowels omitted by user, e.g. "hydrbd" vs "hyderabad")
    final qSkel = consonantSkeleton(qToken);
    final tSkel = consonantSkeleton(tToken);
    if (qSkel.length >= 4 && tSkel.length >= 4) {
      if (qSkel == tSkel || tSkel.startsWith(qSkel)) return true;
    }

    return false;
  }

  // ─── Per-token score helper ───────────────────────────────────────────────

  /// Scores a single query token against all target tokens.
  /// Returns 0.0 if no match is found.
  static double _scoreToken(String qToken, List<String> targetTokens, String squashedSearchable) {
    if (qToken.isEmpty) return 0.0;
    if (qToken.length <= 2) {
      if (targetTokens.contains(qToken)) return 1.0;
      if (targetTokens.any((t) => t.startsWith(qToken))) return 0.85;
      return 0.0;
    }

    double best = 0.0;

    for (final tToken in targetTokens) {
      if (tToken.isEmpty) continue;

      if (qToken == tToken) return 1.0; // Perfect — early exit

      final shorter = min(qToken.length, tToken.length);
      if (shorter >= 3 && (tToken.contains(qToken) || qToken.contains(tToken))) {
        final longer = max(qToken.length, tToken.length);
        final ratio  = shorter / longer;
        best = max(best, 0.80 + 0.10 * ratio);
      } else if (tokenFuzzyMatch(qToken, tToken)) {
        final sim = similarity(qToken, tToken);
        best = max(best, max(sim, 0.78));
      }
    }

    // Squashed fallback
    if (best < 0.70) {
      final sq = squash(qToken);
      if (sq.length >= 3 && squashedSearchable.contains(sq)) {
        best = max(best, 0.75);
      }
    }

    return best;
  }

  // ─── Category synonym expansion ───────────────────────────────────────────

  static List<String> _relatedCategories(String query) {
    final norm  = normalize(query);
    final result = <String>{};

    // Check full query phrase
    if (categorySynonyms.containsKey(norm)) {
      result.addAll(categorySynonyms[norm]!);
    }

    final words = norm.split(' ').where((w) => w.length >= 3).toList();
    for (final w in words) {
      // Exact key
      final exact = categorySynonyms[w];
      if (exact != null) result.addAll(exact);

      // Near-match keys
      for (final entry in categorySynonyms.entries) {
        if (entry.key == w) continue;
        final k = entry.key;
        if (k.length >= 4 && (k.contains(w) || w.contains(k))) {
          result.addAll(entry.value);
        } else if (k.length >= 5 && w.length >= 5 && similarity(w, k) >= 0.75) {
          result.addAll(entry.value);
        }
      }
    }
    return result.toList();
  }

  // ─── Profile scorer — public API ─────────────────────────────────────────

  /// Score a [PhotographerProfile] against a free-text [query].
  /// Returns a value in [0.0, 1.0].
  ///
  /// Coverage requirements (after filtering tokens ≤ 2 chars):
  ///   • 0 meaningful tokens → 1.0 (trivially short query matches all)
  ///   • 1-2 meaningful tokens → all must match
  ///   • 3+ meaningful tokens → at least ⌈N × 0.60⌉ must match
  static double scorePhotographer(PhotographerProfile profile, String query) {
    final normQuery = normalize(query);
    if (normQuery.isEmpty) return 1.0;

    final squashedQuery = squash(query);

    // Split and filter short tokens
    final allTokens        = normQuery.split(' ').where((s) => s.isNotEmpty).toList();
    final meaningfulTokens = allTokens.where((t) => t.length > 2).toList();

    final normStudio = normalize(profile.studioName);
    final normOwner = normalize(profile.ownerName);
    final normUser = normalize(profile.username);
    final normCity = normalize(profile.city);
    final normDistrict = normalize(profile.district);
    final normState = normalize(profile.state);
    final normSpecialties = normalize(profile.specialties);
    final normAbout = normalize(profile.about);
    final normAddress = normalize(profile.address);
    final normCats = profile.categories.map(normalize).toList();

    final combinedSearchable = [
      normCity,
      normDistrict,
      normState,
      normAddress,
      normStudio,
      normOwner,
      normUser,
      normSpecialties,
      normAbout,
      ...normCats,
    ].join(' ');

    final squashedSearchable = squash(combinedSearchable);

    // Short queries (1 or 2 characters, e.g. "m" or "mu"):
    // Prioritize word-prefix matches across studio name, owner name, username, city, categories, etc.
    if (meaningfulTokens.isEmpty) {
      final q = normQuery;
      bool wordsStartsWith(String str) {
        if (str.isEmpty) return false;
        final words = str.split(' ').where((w) => w.isNotEmpty);
        return words.any((w) => w.startsWith(q));
      }

      if (normStudio.startsWith(q)) return 1.0;
      if (wordsStartsWith(normStudio)) return 0.95;
      if (normOwner.startsWith(q) || wordsStartsWith(normOwner)) return 0.93;
      if (normUser.startsWith(q)) return 0.92;
      if (normCity.startsWith(q) || wordsStartsWith(normCity)) return 0.90;
      if (normDistrict.startsWith(q) || wordsStartsWith(normDistrict)) return 0.89;
      if (normState.startsWith(q) || wordsStartsWith(normState)) return 0.88;
      if (normCats.any((c) => wordsStartsWith(c))) return 0.87;
      if (wordsStartsWith(normSpecialties)) return 0.85;
      if (wordsStartsWith(normAbout)) return 0.83;
      if (wordsStartsWith(combinedSearchable)) return 0.80;

      // Substring match for short queries
      if (q.length >= 2 && combinedSearchable.contains(q)) return 0.70;
      if (q.length == 1 && (normStudio.contains(q) || normOwner.contains(q) || normCity.contains(q))) return 0.60;

      return 0.0;
    }

    // ── Tier 1: exact phrase ────────────────────────────────────────────────
    if (combinedSearchable.contains(normQuery)) return 1.0;
    if (squashedSearchable.contains(squashedQuery)) return 0.95;

    // ── Tier 2: category synonym ────────────────────────────────────────────
    final related = _relatedCategories(query);
    double categoryScore = 0.0;
    if (related.isNotEmpty) {
      final hasCatMatch = profile.categories.any((userCat) {
        final nc = normalize(userCat);
        return related.any((r) {
          final nr = normalize(r);
          return nc.contains(nr) || nr.contains(nc) || tokenFuzzyMatch(nr, nc);
        });
      });
      final hasSpecMatch = related.any(
        (r) => normalize(profile.specialties).contains(normalize(r)),
      );
      if (hasCatMatch || hasSpecMatch) categoryScore = 0.85;
    }

    // ── Tier 3: token-level scoring ─────────────────────────────────────────
    final targetTokens = combinedSearchable.split(' ').where((s) => s.isNotEmpty).toList();

    int    matchedCount = 0;
    double totalScore   = 0.0;

    for (final qToken in meaningfulTokens) {
      final ts = _scoreToken(qToken, targetTokens, squashedSearchable);
      if (ts >= 0.65) {
        matchedCount++;
        totalScore += ts;
      }
    }

    // ── Coverage gate ───────────────────────────────────────────────────────
    final n = meaningfulTokens.length;
    final requiredMatches = n <= 2 ? n : (n * 0.60).ceil();

    if (matchedCount < requiredMatches) {
      return categoryScore > 0.0 ? categoryScore : 0.0;
    }

    final avgTokenScore = totalScore / matchedCount;
    final coverage      = matchedCount / n;
    final tokenContrib  = avgTokenScore * (0.70 + 0.30 * coverage);

    return max(tokenContrib, categoryScore);
  }

  // ─── Location picker helper ───────────────────────────────────────────────

  /// Fuzzy-matches a query against a district or state name (for the India
  /// location picker). Returns true if any token of the query fuzzy-matches
  /// any token in the location name.
  static bool matchesLocation(String locationName, String query) {
    final normQuery  = normalize(query);
    if (normQuery.isEmpty) return true;

    final normTarget = normalize(locationName);
    if (normTarget.contains(normQuery) || normQuery.contains(normTarget)) return true;

    final squashedTarget = squash(locationName);
    final squashedQuery  = squash(query);
    if (squashedTarget.contains(squashedQuery)) return true;

    final qTokens = normQuery.split(' ').where((s) => s.isNotEmpty).toList();
    final tTokens = normTarget.split(' ').where((s) => s.isNotEmpty).toList();

    for (final q in qTokens) {
      for (final t in tTokens) {
        if (tokenFuzzyMatch(q, t)) return true;
      }
    }

    return false;
  }
}
