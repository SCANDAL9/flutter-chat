class EntityDescriptor {
  final String entityName;
  final String pluralRoute;
  final List<FieldDescriptor> fields;
  final Set<String> requiredFields;

  EntityDescriptor({
    required this.entityName,
    required this.pluralRoute,
    required this.fields,
    required this.requiredFields,
  });

  FieldDescriptor? findField(String fieldName) {
    final lower = fieldName.toLowerCase();
    for (final f in fields) {
      if (f.name.toLowerCase() == lower) return f;
    }
    return null;
  }
}

class FieldDescriptor {
  final String name;
  final String type; // string, integer, number, boolean
  final String? format; // int32, int64, double, date
  final bool isRequired;
  final List<String>? enumValues;

  FieldDescriptor({
    required this.name,
    required this.type,
    this.format,
    required this.isRequired,
    this.enumValues,
  });
}
