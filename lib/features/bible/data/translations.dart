class Translation {
  const Translation({
    required this.id,
    required this.abbreviation,
    required this.name,
    required this.license,
    required this.attribution,
  });

  final String id;
  final String abbreviation;
  final String name;
  final String license;
  final String attribution;
}

/// Only translations whose license is verified in LICENSES.md may be listed.
const List<Translation> kTranslations = [
  Translation(
    id: 'web',
    abbreviation: 'WEB',
    name: 'World English Bible',
    license: 'Public domain',
    attribution: 'World English Bible (WEB), public domain. '
        '"World English Bible" is a trademark of eBible.org.',
  ),
];

Translation translationById(String id) {
  return kTranslations.firstWhere(
    (t) => t.id == id,
    orElse: () => kTranslations.first,
  );
}
