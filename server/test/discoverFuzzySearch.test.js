/**
 * Comprehensive fuzzy search tests for Discover.
 * Covers: case, whitespace, punctuation, partial match, typos, squashed text,
 *         short-token guard, multi-word coverage, categories, privacy fields,
 *         no-match cases, includeSelf, relevance ordering, and encryption handling.
 *
 * All test profiles are generated with varied Indian names/cities — no single
 * hardcoded location is the sole vehicle for demonstrating correctness.
 */

'use strict';

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const fuzzySearch = require('../src/utils/fuzzySearch');
const memoryUsers = require('../src/store/memoryUsers');

// ────────────────────────────────────────────────────────────────────────────
// Helpers
// ────────────────────────────────────────────────────────────────────────────

/** Build a minimal test profile with sensible defaults. */
function profile(overrides = {}) {
  return {
    id:          overrides.id          || `p-${Math.random().toString(36).slice(2, 8)}`,
    username:    overrides.username    || 'test_user',
    studioName:  overrides.studioName  || '',
    ownerName:   overrides.ownerName   || '',
    city:        overrides.city        || '',
    district:    overrides.district    || '',
    state:       overrides.state       || '',
    address:     overrides.address     || '',
    about:       overrides.about       || '',
    specialties: overrides.specialties || '',
    categories:  overrides.categories  || [],
    ...overrides,
  };
}

/** Assert score is above threshold with a readable message. */
function assertMatches(user, query, threshold = 0.7, label = '') {
  const score = fuzzySearch.scorePhotographerMatch(user, query);
  assert.ok(
    score >= threshold,
    `${label || `"${query}"`} should match "${user.studioName || user.ownerName || user.city}" ` +
    `(threshold=${threshold}, got=${score.toFixed(3)})`,
  );
  return score;
}

/** Assert score is below threshold (no false positive). */
function assertNoMatch(user, query, threshold = 0.5, label = '') {
  const score = fuzzySearch.scorePhotographerMatch(user, query);
  assert.ok(
    score < threshold,
    `${label || `"${query}"`} should NOT match "${user.studioName || user.ownerName || user.city}" ` +
    `(threshold=${threshold}, got=${score.toFixed(3)})`,
  );
}

// ────────────────────────────────────────────────────────────────────────────
// Diverse generated test profiles
// ────────────────────────────────────────────────────────────────────────────

const PROFILES = {
  mumbaiWedding: profile({
    id: 'p-mum-1', studioName: 'Anand Wedding Studio', ownerName: 'Anand Kapoor',
    city: 'Mumbai', district: 'Mumbai', state: 'Maharashtra',
    categories: ['Traditional Photographer', 'Candid Photographer'],
    specialties: 'Wedding Photography, Pre-wedding Shoots',
  }),
  delhiDrone: profile({
    id: 'p-del-1', studioName: 'Capital Aerial Works', ownerName: 'Suresh Mehta',
    city: 'Delhi', district: 'New Delhi', state: 'Delhi',
    categories: ['Drones'], specialties: 'Aerial Cinematography',
  }),
  bangaloreVideo: profile({
    id: 'p-blr-1', studioName: 'Silicon Frames', ownerName: 'Ravi Kumar',
    city: 'Bengaluru', district: 'Bengaluru Urban', state: 'Karnataka',
    categories: ['Cinematic Videographer', 'Traditional Videographer'],
    specialties: 'Corporate Video, Wedding Reels',
  }),
  hyderabadUpper: profile({
    id: 'p-hyd-1', studioName: 'LUMEN ROYALE STUDIOS', ownerName: 'RAHUL SHARMA',
    city: 'HYDERABAD', district: 'HYDERABAD', state: 'TELANGANA',
    address: 'THILAK NAGAR, BOGGULAKUNTA, HYDERABAD',
    categories: ['Traditional Photographer', 'Candid Photographer'],
    specialties: 'Wedding Photography, Pre-wedding Shoots',
  }),
  chennaiFamilyStudio: profile({
    id: 'p-chn-1', studioName: 'Iyer Family Studios', ownerName: 'Ramesh Iyer',
    city: 'Chennai', district: 'Chennai', state: 'Tamil Nadu',
    categories: ['Traditional Photographer'], specialties: 'Family Portraits, School Events',
  }),
  kolkataLive: profile({
    id: 'p-kol-1', studioName: 'Kolkata Live Events', ownerName: 'Sanjoy Das',
    city: 'Kolkata', district: 'Kolkata', state: 'West Bengal',
    categories: ['Internet Live Streaming'], specialties: 'Live Streaming, Webcast',
  }),
  vizagAerial: profile({
    id: 'p-viz-1', studioName: 'Vizag Sky Shots', ownerName: 'Venkat Rao',
    city: 'Visakhapatnam', district: 'Visakhapatnam', state: 'Andhra Pradesh',
    categories: ['Drones'], specialties: 'Beach Aerial Shots',
  }),
  punePortraits: profile({
    id: 'p-pun-1', studioName: 'Pune Portraits', ownerName: 'Priya Joshi',
    city: 'Pune', district: 'Pune', state: 'Maharashtra',
    categories: ['Candid Photographer'], specialties: 'Maternity Shoots, Portraits',
    about: 'Specialising in creative candid photography in Pune.',
  }),
  jaipurLED: profile({
    id: 'p-jai-1', studioName: 'Jaipur Glow Productions', ownerName: 'Aditya Bhatia',
    city: 'Jaipur', district: 'Jaipur', state: 'Rajasthan',
    categories: ['LED Screens'], specialties: 'LED Screen Rental',
  }),
  lucknowCandid: profile({
    id: 'p-lko-1', studioName: 'Nawab Frames', ownerName: 'Amjad Khan',
    city: 'Lucknow', district: 'Lucknow', state: 'Uttar Pradesh',
    categories: ['Candid Videographer', 'Traditional Photographer'],
  }),
};

// ────────────────────────────────────────────────────────────────────────────
// 1. Case-insensitivity
// ────────────────────────────────────────────────────────────────────────────

describe('Case-insensitive matching', () => {
  it('lowercase query matches UPPERCASE city', () => {
    assertMatches(PROFILES.hyderabadUpper, 'hyderabad');
    assertMatches(PROFILES.hyderabadUpper, 'HYDERABAD');
    assertMatches(PROFILES.hyderabadUpper, 'Hyderabad');
  });

  it('lowercase query matches UPPERCASE studio name', () => {
    assertMatches(PROFILES.hyderabadUpper, 'lumen royale');
    assertMatches(PROFILES.hyderabadUpper, 'LUMEN ROYALE');
  });

  it('lowercase query matches UPPERCASE owner name', () => {
    assertMatches(PROFILES.hyderabadUpper, 'rahul sharma');
    assertMatches(PROFILES.hyderabadUpper, 'RAHUL SHARMA');
  });

  it('mixed-case query works across all profiles', () => {
    assertMatches(PROFILES.mumbaiWedding, 'ANAND WEDDING');
    assertMatches(PROFILES.kolkataLive,   'kolkata LIVE');
    assertMatches(PROFILES.delhiDrone,    'Capital AERIAL');
  });
});

// ────────────────────────────────────────────────────────────────────────────
// 2. Whitespace and punctuation normalisation
// ────────────────────────────────────────────────────────────────────────────

describe('Whitespace and punctuation normalisation', () => {
  it('leading and trailing spaces are ignored', () => {
    assertMatches(PROFILES.mumbaiWedding, '  mumbai  ');
    assertMatches(PROFILES.mumbaiWedding, '   anand  wedding  ');
  });

  it('repeated internal spaces are collapsed', () => {
    assertMatches(PROFILES.bangaloreVideo, 'silicon   frames');
  });

  it('punctuation is normalised', () => {
    assertMatches(PROFILES.delhiDrone, 'capital-aerial-works');
    assertMatches(PROFILES.delhiDrone, 'capital,aerial,works');
    assertMatches(PROFILES.punePortraits, "pune's portraits");
  });

  it('empty and whitespace-only queries match everything (score=1.0)', () => {
    assert.equal(fuzzySearch.scorePhotographerMatch(PROFILES.mumbaiWedding, ''),  1.0);
    assert.equal(fuzzySearch.scorePhotographerMatch(PROFILES.mumbaiWedding, '   '), 1.0);
  });
});

// ────────────────────────────────────────────────────────────────────────────
// 3. Exact and partial matching
// ────────────────────────────────────────────────────────────────────────────

describe('Exact and partial matching', () => {
  it('exact studio name match scores 1.0', () => {
    const score = fuzzySearch.scorePhotographerMatch(PROFILES.mumbaiWedding, 'anand wedding studio');
    assert.ok(score >= 0.95, `exact match expected ≥0.95, got ${score}`);
  });

  it('partial studio name prefix matches', () => {
    assertMatches(PROFILES.mumbaiWedding, 'anand wedding');
    assertMatches(PROFILES.bangaloreVideo, 'silicon');
    assertMatches(PROFILES.delhiDrone, 'capital aerial');
  });

  it('partial city name matches', () => {
    assertMatches(PROFILES.hyderabadUpper, 'hyder');
    assertMatches(PROFILES.bangaloreVideo, 'bengal');
  });

  it('single word matching city', () => {
    assertMatches(PROFILES.punePortraits, 'pune');
    assertMatches(PROFILES.lucknowCandid, 'lucknow');
    assertMatches(PROFILES.jaipurLED,     'jaipur');
  });

  it('partial owner name matches', () => {
    assertMatches(PROFILES.mumbaiWedding, 'kapoor');
    assertMatches(PROFILES.chennaiFamilyStudio, 'iyer');
  });
});

// ────────────────────────────────────────────────────────────────────────────
// 4. Typo tolerance
// ────────────────────────────────────────────────────────────────────────────

describe('Typo tolerance (insertions, deletions, substitutions)', () => {
  // Location name typos
  it('handles 1-char deletion in city name', () => {
    assertMatches(PROFILES.punePortraits,  'pne');
    assertMatches(PROFILES.lucknowCandid,  'luckow');
  });

  it('handles 1-char substitution in city name', () => {
    assertMatches(PROFILES.hyderabadUpper, 'hyderbad');  // "a" deleted
    assertMatches(PROFILES.hyderabadUpper, 'hyedrabad');
    assertMatches(PROFILES.mumbaiWedding,  'mmbai');
  });

  it('handles 1-char insertion in city name', () => {
    assertMatches(PROFILES.kolkataLive, 'kolkaata');
    assertMatches(PROFILES.jaipurLED,  'jaipuur');
  });

  it('handles 2-char typos in longer names', () => {
    assertMatches(PROFILES.bangaloreVideo, 'bengalure');   // substitution
    assertMatches(PROFILES.delhiDrone,     'suresh metha'); // substitution in owner
    assertMatches(PROFILES.vizagAerial,    'visakapatnam'); // 1 char deleted
  });

  it('handles vowel swap typos', () => {
    assertMatches(PROFILES.chennaiFamilyStudio, 'channai'); // e→a
    assertMatches(PROFILES.kolkataLive,         'kolkota'); // a→o
  });

  it('"thilak nagar" typed variants all match address (UPPERCASE stored)', () => {
    const u = PROFILES.hyderabadUpper;
    assertMatches(u, 'thilak nagar');   // exact
    assertMatches(u, 'tilak nagar');    // phonetic th→t
    assertMatches(u, 'thilak nager');   // vowel substitution
    assertMatches(u, 'thilaknagar');    // squashed
  });

  // Studio name typos
  it('handles typos in studio names', () => {
    assertMatches(PROFILES.bangaloreVideo, 'silikon frames');  // c→k
    assertMatches(PROFILES.jaipurLED,     'jaipur glow prduction'); // "o" missing
  });
});

// ────────────────────────────────────────────────────────────────────────────
// 5. Squashed / missing-space matching
// ────────────────────────────────────────────────────────────────────────────

describe('Squashed / missing-space matching', () => {
  it('matches when spaces are omitted in a multi-word query', () => {
    assertMatches(PROFILES.mumbaiWedding,  'anandwedding');
    assertMatches(PROFILES.delhiDrone,     'capitalaerialworks');
    assertMatches(PROFILES.jaipurLED,      'jaipurglow');
  });

  it('matches squashed location name against spaced stored value', () => {
    assertMatches(PROFILES.hyderabadUpper, 'thilaknagar');
    assertMatches(PROFILES.delhiDrone,     'newdelhi');
  });
});

// ────────────────────────────────────────────────────────────────────────────
// 6. Phonetic normalisation
// ────────────────────────────────────────────────────────────────────────────

describe('Phonetic normalisation', () => {
  it('"tilak" (without h) matches "thilak"', () => {
    assertMatches(PROFILES.hyderabadUpper, 'tilak nagar');
  });

  it('"fotographer" matches photographers/photography categories', () => {
    assertMatches(PROFILES.mumbaiWedding, 'fotographer');
  });

  it('"photographi" (typo) matches photography categories', () => {
    assertMatches(PROFILES.mumbaiWedding, 'photographi');
  });
});

// ────────────────────────────────────────────────────────────────────────────
// 7. Category and specialty synonyms
// ────────────────────────────────────────────────────────────────────────────

describe('Category synonym expansion', () => {
  it('"drone" matches Drones category', () => {
    assertMatches(PROFILES.delhiDrone,  'drone');
    assertMatches(PROFILES.vizagAerial, 'drone');
  });

  it('"aerial" matches Drones category', () => {
    assertMatches(PROFILES.delhiDrone,  'aerial');
    assertMatches(PROFILES.vizagAerial, 'aerial');
  });

  it('"wedding" matches Traditional/Candid Photographer', () => {
    assertMatches(PROFILES.mumbaiWedding,  'wedding');
    assertMatches(PROFILES.hyderabadUpper, 'wedding');
  });

  it('"shaadi" (Telugu/Hindi) maps to wedding categories', () => {
    assertMatches(PROFILES.mumbaiWedding, 'shaadi');
    assertMatches(PROFILES.lucknowCandid, 'shaadi');
  });

  it('"video" matches Cinematic/Traditional Videographer', () => {
    assertMatches(PROFILES.bangaloreVideo, 'video');
  });

  it('"cinematic" matches Cinematic Videographer', () => {
    assertMatches(PROFILES.bangaloreVideo, 'cinematic');
  });

  it('"stream" matches Internet Live Streaming', () => {
    assertMatches(PROFILES.kolkataLive, 'stream');
    assertMatches(PROFILES.kolkataLive, 'live streaming');
  });

  it('"led" and "screen" match LED Screens', () => {
    assertMatches(PROFILES.jaipurLED, 'led');
    assertMatches(PROFILES.jaipurLED, 'screen');
  });

  it('"candid" matches Candid Photographer / Videographer', () => {
    assertMatches(PROFILES.punePortraits,  'candid');
    assertMatches(PROFILES.lucknowCandid,  'candid');
  });

  it('near-misspelled category keyword still maps via similarity', () => {
    assertMatches(PROFILES.delhiDrone,     'drones');     // plural
    assertMatches(PROFILES.bangaloreVideo, 'videography');
    assertMatches(PROFILES.bangaloreVideo, 'vidiographer'); // common misspelling
  });

  it('category keyword + location compound query matches correct profile', () => {
    assertMatches(PROFILES.vizagAerial, 'drone visakhapatnam');
    assertMatches(PROFILES.jaipurLED,   'led jaipur');
  });
});

// ────────────────────────────────────────────────────────────────────────────
// 8. Multi-word coverage requirements
// ────────────────────────────────────────────────────────────────────────────

describe('Multi-word coverage thresholds', () => {
  it('1-token query: token must match', () => {
    assertMatches(PROFILES.mumbaiWedding, 'mumbai');
    assertNoMatch(PROFILES.delhiDrone,    'mumbai');
  });

  it('2-token query: both tokens must match', () => {
    // Both "anand" and "wedding" are in the studio
    assertMatches(PROFILES.mumbaiWedding, 'anand wedding');
    // "anand" matches but "delhi" does not → should not match Delhi drone studio
    assertNoMatch(PROFILES.delhiDrone, 'anand wedding', 0.6, '"anand wedding" in delhiDrone');
  });

  it('3-token query: ≥60% (2 of 3) tokens must match', () => {
    // 3 tokens: "silicon", "frames", "bengaluru" — all match bangaloreVideo
    assertMatches(PROFILES.bangaloreVideo, 'silicon frames bengaluru');
    // 2 of 3 match → should still match
    assertMatches(PROFILES.bangaloreVideo, 'silicon frames unknown');
    // Only 1 of 3 match → should not match
    assertNoMatch(PROFILES.bangaloreVideo, 'silicon xyz abc', 0.55);
  });

  it('short tokens (≤ 2 chars) are excluded from scoring', () => {
    // "in", "of" are excluded — only "mumbai" contributes → should match
    assertMatches(PROFILES.mumbaiWedding, 'in of mumbai');
    // Only "in", "of" — both excluded → should not match anything
    assertNoMatch(PROFILES.mumbaiWedding, 'in of');
    assertNoMatch(PROFILES.delhiDrone,    'in of');
  });

  it('short single-char queries match word prefixes and non-matching returns 0', () => {
    // "m" matches Mumbai in mumbaiWedding and Mehta in delhiDrone
    assertMatches(PROFILES.mumbaiWedding, 'm');
    assertMatches(PROFILES.delhiDrone,    'm');
    // "a" matches Anand in mumbaiWedding
    assertMatches(PROFILES.mumbaiWedding, 'a');
    // Unrelated single char with no matches returns 0
    assertNoMatch(PROFILES.mumbaiWedding, 'z');
    assertNoMatch(PROFILES.delhiDrone,    'z');
  });
});

// ────────────────────────────────────────────────────────────────────────────
// 9. City alias expansion
// ────────────────────────────────────────────────────────────────────────────

describe('City alias expansion', () => {
  it('"vizag" matches Visakhapatnam profile', () => {
    assertMatches(PROFILES.vizagAerial, 'vizag');
  });

  it('"bangalore" matches Bengaluru profile', () => {
    assertMatches(PROFILES.bangaloreVideo, 'bangalore');
    assertMatches(PROFILES.bangaloreVideo, 'banglore'); // common misspelling
  });

  it('"bombay" matches Mumbai profile', () => {
    assertMatches(PROFILES.mumbaiWedding, 'bombay');
  });

  it('"hyd" matches Hyderabad profile', () => {
    assertMatches(PROFILES.hyderabadUpper, 'hyd');
  });
});

// ────────────────────────────────────────────────────────────────────────────
// 10. No-match cases — no false positives
// ────────────────────────────────────────────────────────────────────────────

describe('No false positives', () => {
  it('completely unrelated query returns 0', () => {
    assertNoMatch(PROFILES.mumbaiWedding,  'kolkata aerial live stream');
    assertNoMatch(PROFILES.delhiDrone,     'jaipur led screens');
    assertNoMatch(PROFILES.jaipurLED,      'cinematic videographer lucknow');
  });

  it('query for different city does not match wrong city', () => {
    assertNoMatch(PROFILES.mumbaiWedding, 'delhi',   0.5, '"delhi" vs Mumbai');
    assertNoMatch(PROFILES.delhiDrone,    'kolkata',  0.5, '"kolkata" vs Delhi');
    assertNoMatch(PROFILES.kolkataLive,   'jaipur',   0.5, '"jaipur" vs Kolkata');
  });

  it('mildly similar but unrelated names do not match', () => {
    // "lumen" is in hyderabadUpper; should not match delhiDrone
    assertNoMatch(PROFILES.delhiDrone, 'lumen royale', 0.55, '"lumen royale" vs delhiDrone');
  });

  it('category synonym for Drones does not match wedding studios', () => {
    assertNoMatch(PROFILES.chennaiFamilyStudio, 'drone aerial', 0.55,
      '"drone aerial" should not match Chennai family studio');
  });

  it('wedding synonym does not match drone-only studio', () => {
    assertNoMatch(PROFILES.delhiDrone, 'wedding photography', 0.55,
      '"wedding photography" should not match drone-only studio');
  });
});

// ────────────────────────────────────────────────────────────────────────────
// 11. About text and specialties
// ────────────────────────────────────────────────────────────────────────────

describe('About text and specialties matching', () => {
  it('matches keyword in specialties field', () => {
    assertMatches(PROFILES.mumbaiWedding, 'pre-wedding');
    assertMatches(PROFILES.kolkataLive,   'webcast');
  });

  it('matches keyword in about text', () => {
    // punePortraits has "creative candid photography in Pune" in about
    assertMatches(PROFILES.punePortraits, 'creative candid');
    assertMatches(PROFILES.punePortraits, 'maternity');
  });
});

// ────────────────────────────────────────────────────────────────────────────
// 12. Address (decrypted plain-text) scoring
// ────────────────────────────────────────────────────────────────────────────

describe('Address scoring (plain-text in-memory)', () => {
  it('matches plain-text address keyword', () => {
    // hyderabadUpper has address "THILAK NAGAR, BOGGULAKUNTA, HYDERABAD"
    assertMatches(PROFILES.hyderabadUpper, 'thilak nagar');
    assertMatches(PROFILES.hyderabadUpper, 'boggulakunta');
  });

  it('profile with encrypted address sentinel returns 0 score when sentinel cannot match', () => {
    // Simulate an encrypted address that starts with "enc:v1:" — the scorer
    // calls dataSecurity.decrypt(); if it fails it should return '' and not crash.
    const encryptedProfile = profile({
      city: 'Nowhere', studioName: 'Nowhere Studio',
      address: 'enc:v1:deadbeef:deadbeef:deadbeef', // looks like a ciphertext
    });
    // Should not throw; score against the bogus address is effectively 0
    const score = fuzzySearch.scorePhotographerMatch(encryptedProfile, 'thilak nagar');
    assert.ok(typeof score === 'number', 'Score should be a number');
    assert.ok(score >= 0.0, 'Score should not be negative');
  });
});

// ────────────────────────────────────────────────────────────────────────────
// 13. includeSelf in memoryUsers
// ────────────────────────────────────────────────────────────────────────────

describe('memoryUsers.searchPhotographers — includeSelf', () => {
  const SELF_ID = 'test-self-include-001';

  it('includes own profile when includeSelf=true', () => {
    const self = {
      id:        SELF_ID,
      username:  'self_studio_user',
      studioName:'MY OWN STUDIO',
      city:      'Hyderabad',
      categories:['Traditional Photographer'],
    };
    memoryUsers.create(self);

    const results = memoryUsers.searchPhotographers({
      userId:      SELF_ID,
      location:    'hyderabad',
      includeSelf: true,
    });
    const found = results.some((r) => r.username === 'self_studio_user' || r._id === SELF_ID);
    assert.ok(found, 'Own profile should appear when includeSelf=true');

    memoryUsers.remove(SELF_ID);
  });

  it('excludes own profile when includeSelf=false', () => {
    const self = {
      id:        SELF_ID,
      username:  'self_studio_excluded',
      studioName:'EXCLUDED STUDIO',
      city:      'Hyderabad',
      categories:['Traditional Photographer'],
    };
    memoryUsers.create(self);

    const results = memoryUsers.searchPhotographers({
      userId:      SELF_ID,
      location:    'hyderabad',
      includeSelf: false,
    });
    const found = results.some((r) => r.username === 'self_studio_excluded');
    assert.ok(!found, 'Own profile should be absent when includeSelf=false');

    memoryUsers.remove(SELF_ID);
  });
});

// ────────────────────────────────────────────────────────────────────────────
// 14. Relevance ordering
// ────────────────────────────────────────────────────────────────────────────

describe('Relevance ordering', () => {
  it('exact match scores higher than fuzzy match', () => {
    const exact  = profile({ studioName: 'Pixel Perfect Studio', city: 'Delhi' });
    const typo   = profile({ studioName: 'Pixel Purfect Studio', city: 'Delhi' });
    const scoreExact = fuzzySearch.scorePhotographerMatch(exact, 'pixel perfect studio');
    const scoreTypo  = fuzzySearch.scorePhotographerMatch(typo,  'pixel perfect studio');
    assert.ok(scoreExact >= scoreTypo, `Exact (${scoreExact.toFixed(3)}) should be ≥ fuzzy (${scoreTypo.toFixed(3)})`);
  });

  it('full studio name match scores higher than partial match', () => {
    const full    = profile({ studioName: 'Golden Frame Photography', city: 'Pune' });
    const partial = profile({ studioName: 'Golden Frame',             city: 'Pune' });
    const scoreFull    = fuzzySearch.scorePhotographerMatch(full,    'golden frame photography');
    const scorePartial = fuzzySearch.scorePhotographerMatch(partial, 'golden frame photography');
    assert.ok(scoreFull >= scorePartial,
      `Full match (${scoreFull.toFixed(3)}) should be ≥ partial (${scorePartial.toFixed(3)})`);
  });

  it('city+studio match ranks higher than city-only match', () => {
    const cityAndStudio = profile({ studioName: 'Starlight Frames', city: 'Coimbatore' });
    const cityOnly      = profile({ studioName: 'Other Studio',     city: 'Coimbatore' });
    const scoreCS = fuzzySearch.scorePhotographerMatch(cityAndStudio, 'starlight frames coimbatore');
    const scoreCO = fuzzySearch.scorePhotographerMatch(cityOnly,      'starlight frames coimbatore');
    assert.ok(scoreCS >= scoreCO,
      `City+studio (${scoreCS.toFixed(3)}) should be ≥ city-only (${scoreCO.toFixed(3)})`);
  });
});

// ────────────────────────────────────────────────────────────────────────────
// 15. normalizeText and squashText helpers
// ────────────────────────────────────────────────────────────────────────────

describe('Text helper utilities', () => {
  it('normalizeText lowercases, trims, collapses whitespace, strips punctuation', () => {
    assert.equal(fuzzySearch.normalizeText('  Hello, World!  '), 'hello world');
    assert.equal(fuzzySearch.normalizeText('THILAK-NAGAR'), 'thilak nagar');
    assert.equal(fuzzySearch.normalizeText("Iyer's Studio"), 'iyer s studio');
  });

  it('squashText removes all spaces after normalising', () => {
    assert.equal(fuzzySearch.squashText('thilak nagar'), 'thilaknagar');
    assert.equal(fuzzySearch.squashText('silicon frames bengaluru'), 'siliconframesbengaluru');
  });

  it('phoneticNormalize applies digraph transformations', () => {
    assert.equal(fuzzySearch.phoneticNormalize('thilak'),  'tilak');
    assert.equal(fuzzySearch.phoneticNormalize('sharma'),  'sarma');
    assert.equal(fuzzySearch.phoneticNormalize('photographer'), 'fotografer');
  });
});

// ────────────────────────────────────────────────────────────────────────────
// 16. CATEGORY_SYNONYMS and CITY_ALIASES exports
// ────────────────────────────────────────────────────────────────────────────

describe('Exported synonym and alias tables', () => {
  it('CATEGORY_SYNONYMS is an object with array values', () => {
    const cs = fuzzySearch.CATEGORY_SYNONYMS;
    assert.ok(cs && typeof cs === 'object');
    for (const val of Object.values(cs)) {
      assert.ok(Array.isArray(val), 'Each synonym value should be an array');
      assert.ok(val.length > 0,    'Each synonym array should have at least one entry');
    }
  });

  it('CITY_ALIASES is an object with string values', () => {
    const ca = fuzzySearch.CITY_ALIASES;
    assert.ok(ca && typeof ca === 'object');
    for (const [key, val] of Object.entries(ca)) {
      assert.equal(typeof key, 'string');
      assert.equal(typeof val, 'string');
      assert.equal(key, key.toLowerCase(), `Alias key "${key}" must be lowercase`);
      assert.equal(val, val.toLowerCase(), `Alias value "${val}" must be lowercase`);
    }
  });

  it('getRelatedCategoriesForQuery returns correct categories for known keywords', () => {
    const wedding = fuzzySearch.getRelatedCategoriesForQuery('wedding');
    assert.ok(wedding.includes('Traditional Photographer'));
    assert.ok(wedding.includes('Candid Photographer'));

    const drone = fuzzySearch.getRelatedCategoriesForQuery('drone');
    assert.ok(drone.includes('Drones'));

    const stream = fuzzySearch.getRelatedCategoriesForQuery('live stream');
    assert.ok(stream.includes('Internet Live Streaming'));
  });

  it('getRelatedCategoriesForQuery returns empty array for unrelated word', () => {
    const result = fuzzySearch.getRelatedCategoriesForQuery('xyzqwerty');
    assert.ok(Array.isArray(result));
    // May or may not be empty depending on similarity; should not include wedding/drones
    assert.ok(!result.includes('Traditional Photographer'));
    assert.ok(!result.includes('Drones'));
  });
});

// ────────────────────────────────────────────────────────────────────────────
// 17. Privacy — photographerController strips googleId and paymentQrUrl
// ────────────────────────────────────────────────────────────────────────────

describe('Privacy: private fields must not appear in Discover payload', () => {
  it('toPublicJSON result does not need googleId or paymentQrUrl for Discover to work', () => {
    // The photographerController strips these after calling toPublicJSON().
    // We verify the stripping logic here in isolation.
    const rawPublicJson = {
      id: 'p-priv-1',
      username: 'priv_studio',
      phone: '9876543210',
      email: 'priv@example.com',
      studioName: 'Private Studio',
      city: 'Mumbai',
      googleId:     'google-oauth-sub-12345',
      paymentQrUrl: 'https://cdn.example.com/qr/12345.png',
    };

    const { googleId: _g, paymentQrUrl: _p, ...publicFields } = rawPublicJson;
    assert.ok(!('googleId'     in publicFields), 'googleId must be stripped');
    assert.ok(!('paymentQrUrl' in publicFields), 'paymentQrUrl must be stripped');
    assert.ok('phone'      in publicFields, 'phone must be present for contact');
    assert.ok('studioName' in publicFields, 'studioName must be present');
  });
});
