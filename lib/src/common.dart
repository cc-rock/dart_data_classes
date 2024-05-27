import 'dart:async';

import 'package:macros/macros.dart';

final dartCoreUri = Uri.parse('dart:core');
final dataClassUri = Uri.parse('package:dart_data_classes/src/data_class.dart');

extension IsExactly on TypeDeclaration {
  /// Cheaper than checking types using a [StaticType].
  bool isExactly(String name, Uri library) =>
      identifier.name == name && this.library.uri == library;
}

FutureOr<List<ClassDeclaration>> getSuperClasses(
  ClassDeclaration clazz,
  DeclarationPhaseIntrospector builder,
) async {
  final superclasses = <ClassDeclaration>[];
  await _getSuperClassesRecursively(clazz, clazz, builder, superclasses);
  return superclasses;
}

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

FutureOr<void> _getSuperClassesRecursively(
  ClassDeclaration clazz,
  ClassDeclaration originalClass,
  DeclarationPhaseIntrospector builder,
  List<ClassDeclaration> current,
) async {
  final superclazz = clazz.superclass;
  if (superclazz != null) {
    final superDecl = await builder.typeDeclarationOf(superclazz.identifier);
    if (superDecl.isExactly('Object', dartCoreUri)) {
      return;
    }
    for (final annotation in superDecl.metadata) {
      if (annotation is ConstructorMetadataAnnotation) {
        final annotationType = annotation.type;
        final typeDecl =
            await builder.typeDeclarationOf(annotationType.identifier);
        if (typeDecl.isExactly('DataClass', dataClassUri)) {
          current.add(superDecl as ClassDeclaration);
          await _getSuperClassesRecursively(
              superDecl, originalClass, builder, current);
          return;
        }
      }
    }
    throw DiagnosticException(
      Diagnostic(
        DiagnosticMessage(
          'A data class can only have data class superclasses',
          target: originalClass.asDiagnosticTarget,
        ),
        Severity.error,
      ),
    );
  }
}
