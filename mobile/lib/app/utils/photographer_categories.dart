/// Photographer categories and role specializations.
class PhotographerCategory {
  const PhotographerCategory({
    required this.id,
    required this.name,
    this.isOperator = false,
  });

  final String id;
  final String name;
  final bool isOperator;

  @override
  String toString() => name;
}

class PhotographerCategories {
  PhotographerCategories._();

  static const String otherCategory = 'Others';

  static const List<String> primaryRoles = [
    'Traditional photographer',
    'Traditional Vidiographer',
    'Candid photographer',
    'Cinematic Vidiographer',
    'Led screens',
    'Drones',
    'Internet Live',
    'Traditional photographer taker',
  ];

  static const List<String> operatorRoles = [
    'Photographer',
    'Vidiography',
    'candid photographer',
    'Candid Vidiographer',
  ];

  /// Normalized operator role labels for display and selection
  static const List<String> formattedOperatorRoles = [
    'Photographer',
    'Vidiography',
    'Candid photographer',
    'Candid Vidiographer',
    'Video Editor',
    'Album Designer',  
  ];

  /// Master list of all predefined categories
  static const List<String> allPredefined = [
    ...primaryRoles,
    ...formattedOperatorRoles,
    otherCategory,
  ];

  /// Canonical check whether a category belongs to operators
  static bool isOperatorRole(String category) {
    final lower = category.toLowerCase();
    return lower.startsWith('operator') ||
        operatorRoles.any((r) => r.toLowerCase() == lower);
  }
}
