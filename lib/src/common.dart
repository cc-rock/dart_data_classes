import 'dart:async';

import 'package:macros/macros.dart';

final dartCoreUri = Uri.parse('dart:core');
final dataClassUri = Uri.parse('package:dart_data_classes/src/data_class.dart');

extension IsExactly on TypeDeclaration {
  /// Cheaper than checking types using a [StaticType].
  bool isExactly(String name, Uri library) =>
      identifier.name == name && this.library.uri == library;
}

extension ResolveIdentifierExtension on DeclarationPhaseIntrospector {
  /// Temporary wrapper method around resolveIdentifier to avoid deprecation
  /// reporting until a proper api is available
  Future<Identifier> resolveIdentifierWrapper(Uri library, String name) {
    // ignore: deprecated_member_use
    return resolveIdentifier(library, name);
  }
}

/// Gets all superclasses of clazz, in walking-up order
/// (from the closest to the farthest) and excluding [Object]
FutureOr<List<ClassDeclaration>> getSuperClasses(
  ClassDeclaration clazz,
  DeclarationPhaseIntrospector builder,
) async {
  final superClasses = <ClassDeclaration>[];
  var superClass = clazz.superclass;
  while (superClass != null) {
    final superClassDecl =
        await builder.typeDeclarationOf(superClass.identifier);
    if (superClassDecl.isExactly('Object', dartCoreUri)) {
      break;
    }
    superClasses.add(superClassDecl as ClassDeclaration);
    superClass = superClassDecl.superclass;
  }
  return superClasses;
}

/// Gets all fields of all superclasses in a single list, in the order they are declared.
/// The list of superclasses is visited in reverse.
FutureOr<List<FieldDeclaration>> getOrderedSuperFields(
  List<ClassDeclaration> superclasses,
  DeclarationPhaseIntrospector builder,
) async {
  final List<FieldDeclaration> superFields = [];
  for (final sc in superclasses.reversed) {
    superFields.addAll((await builder.fieldsOf(sc)));
  }
  return superFields;
}

Future<bool> _isDataClass(
  ClassDeclaration clazz,
  DeclarationPhaseIntrospector builder,
) async {
  for (final annotation in clazz.metadata) {
    if (annotation is ConstructorMetadataAnnotation) {
      final annotationType = annotation.type;
      final typeDecl =
          await builder.typeDeclarationOf(annotationType.identifier);
      if (typeDecl.isExactly('DataClass', dataClassUri)) {
        return true;
      }
    }
  }
  return false;
}

FutureOr<void> checkSuperClasses(
  ClassDeclaration clazz,
  List<ClassDeclaration> superClasses,
  DeclarationPhaseIntrospector builder,
) async {
  for (final superClass in superClasses) {
    final isDataClass = await _isDataClass(superClass, builder);
    if (!isDataClass) {
      throw DiagnosticException(
        Diagnostic(
          DiagnosticMessage(
            'A data class can only have data class superclasses',
            target: clazz.asDiagnosticTarget,
          ),
          Severity.error,
        ),
      );
    }
  }
}
