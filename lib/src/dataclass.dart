// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:macros/macros.dart';

final _dartCore = Uri.parse('dart:core');
final _dataClass = Uri.parse('package:dart_data_classes/src/dataclass.dart');

extension _IsExactly on TypeDeclaration {
  /// Cheaper than checking types using a [StaticType].
  bool isExactly(String name, Uri library) =>
      identifier.name == name && this.library.uri == library;
}

class DefaultValue<T> {
  const DefaultValue(this.value);

  final T value;
}

macro class DataClass implements ClassDeclarationsMacro, ClassDefinitionMacro {
  const DataClass();

  @override
  FutureOr<void> buildDeclarationsForClass(
    ClassDeclaration clazz,
    MemberDeclarationBuilder builder,
  ) async {
    await _checkNoUnnamedConstructor(clazz, builder);
    final superclasses = await _getSuperclasses(clazz, builder);
    final superFields = await _getSuperFields(superclasses, builder);
    final fields = await builder.fieldsOf(clazz);
    final override = await builder.resolveIdentifier(_dartCore, 'override');
    await _declareConstructor(clazz, builder, fields, superFields);
    await _declareEquals(clazz, builder, override);
    await _declareHashCode(clazz, builder, override);
  }

  @override
  FutureOr<void> buildDefinitionForClass(
    ClassDeclaration clazz,
    TypeDefinitionBuilder builder,
  ) async {
    final superclasses = await _getSuperclasses(clazz, builder);
    final superFields = await _getSuperFields(superclasses, builder);
    final fields = await builder.fieldsOf(clazz);
    await _buildConstructor(clazz, builder, fields, superFields);
    await _buildEquals(clazz, fields, builder, hasSuper: superclasses.isNotEmpty);
    await _buildHashCode(clazz, fields, builder, hasSuper: superclasses.isNotEmpty);
  }

  FutureOr<void> _checkNoUnnamedConstructor(
    ClassDeclaration clazz,
    DeclarationPhaseIntrospector builder,
  ) async {
    final constructors = await builder.constructorsOf(clazz);
    for (final constructor in constructors) {
      if (constructor.identifier.name == '') {
        throw DiagnosticException(
          Diagnostic(
            DiagnosticMessage(
              'A data class cannot have unnamed constructors',
              target: constructor.asDiagnosticTarget,
            ),
            Severity.error,
          ),
        );
      }
    }
  }

  FutureOr<List<ClassDeclaration>> _getSuperclasses(
    ClassDeclaration clazz,
    DeclarationPhaseIntrospector builder,
  ) async {
    final superclasses = <ClassDeclaration>[];
    await _getSuperclassesRecursively(clazz, clazz, builder, superclasses);
    return superclasses;
  }

  FutureOr<List<FieldDeclaration>> _getSuperFields(
    List<ClassDeclaration> superclasses,
    DeclarationPhaseIntrospector builder,
  ) async {
    final List<FieldDeclaration> superFields = [];
    for (final sc in superclasses.reversed) {
      superFields.addAll((await builder.fieldsOf(sc)));
    }
    return superFields;
  }

  FutureOr<void> _getSuperclassesRecursively(
    ClassDeclaration clazz,
    ClassDeclaration original,
    DeclarationPhaseIntrospector builder,
    List<ClassDeclaration> current,
  ) async {
    final superclazz = clazz.superclass;
    if (superclazz != null) {
      final superDecl = await builder.typeDeclarationOf(superclazz.identifier);
      if (superDecl.isExactly('Object', _dartCore)) {
        return;
      }
      for (final annotation in superDecl.metadata) {
        if (annotation is ConstructorMetadataAnnotation) {
          final annotationType = annotation.type;
          final typeDecl =
              await builder.typeDeclarationOf(annotationType.identifier);
          if (typeDecl.isExactly('DataClass', _dataClass)) {
            current.add(superDecl as ClassDeclaration);
            await _getSuperclassesRecursively(
                superDecl, original, builder, current);
            return;
          }
        }
      }
      throw DiagnosticException(Diagnostic(
          DiagnosticMessage(
              'A data class can only have data class superclasses',
              target: original.asDiagnosticTarget),
          Severity.error));
    }
  }

  FutureOr<void> _declareConstructor(
    ClassDeclaration clazz,
    MemberDeclarationBuilder builder,
    List<FieldDeclaration> fields,
    List<FieldDeclaration> superFields,
  ) async {
    builder.declareInType(DeclarationCode.fromParts([
      '  ',
      clazz.identifier.name,
      '({\n',
      for (final field in superFields)
        ...(await _getConstructorDeclarationPartsForField(builder, field)),
      for (final field in fields)
        ...(await _getConstructorDeclarationPartsForField(builder, field)),
      '  });'
    ]));
  }

  FutureOr<void> _declareEquals(
    ClassDeclaration clazz,
    MemberDeclarationBuilder builder,
    Identifier override,
  ) async {
    builder.declareInType(DeclarationCode.fromParts([
      '\n  @',
      override,
      '\n  ',
      await builder.resolveIdentifier(_dartCore, 'bool'),
      ' operator ==(',
      await builder.resolveIdentifier(_dartCore, 'dynamic'),
      ' other);'
    ]));
  }

  FutureOr<void> _declareHashCode(
    ClassDeclaration clazz,
    MemberDeclarationBuilder builder,
    Identifier override,
  ) async {
    builder.declareInType(DeclarationCode.fromParts([
      '\n  @',
      override,
      '\n  ',
      await builder.resolveIdentifier(_dartCore, 'int'),
      ' get hashCode;\n',
    ]));
  }

  Future<List<Object>> _getConstructorDeclarationPartsForField(
      MemberDeclarationBuilder builder, FieldDeclaration field) async {
    Object? defaultValue;
    for (final md in field.metadata) {
      if (md is ConstructorMetadataAnnotation) {
        final typeDecl = await builder.typeDeclarationOf(md.type.identifier);
        if (typeDecl.isExactly('DefaultValue', _dataClass)) {
          defaultValue = md.positionalArguments.first;
        }
      }
    }
    final isRequired = !(field.type.isNullable || defaultValue != null);
    return [
      '    ',
      if (isRequired) 'required ',
      field.type.code,
      ' ',
      field.identifier.name,
      if (defaultValue != null) ...[
        ' = ',
        defaultValue,
      ],
      ',\n',
    ];
  }

  FutureOr<void> _buildConstructor(
    ClassDeclaration clazz,
    TypeDefinitionBuilder builder,
    List<FieldDeclaration> fields,
    List<FieldDeclaration> superFields,
  ) async {
    final constructors = await builder.constructorsOf(clazz);
    final unnamed = constructors.firstWhereOrNull((c) => c.identifier.name == '');
    if (unnamed == null) {
      throw DiagnosticException(Diagnostic(
          DiagnosticMessage(
              'DataClass internal error, constructor not found in defining phase',
              target: clazz.asDiagnosticTarget),
          Severity.error));
    }
    final constructorBuilder = await builder.buildConstructor(
      unnamed.identifier,
    );
    final fieldInitializers = fields.map((field) {
      return RawCode.fromParts([
        'this.',
        field.identifier.name,
        ' = ',
        field.identifier.name,
      ]);
    });
    final superInitialzer = RawCode.fromParts([
      'super(',
      for (final field in superFields) ...[
        field.identifier.name,
        ': ',
        field.identifier.name,
        ', '
      ],
      ')'
    ]);

    constructorBuilder.augment(initializers: [
      ...fieldInitializers,
      superInitialzer,
    ]);
  }

  FutureOr<void> _buildEquals(
    ClassDeclaration clazz,
    List<FieldDeclaration> fields,
    TypeDefinitionBuilder builder, {
    required bool hasSuper,
  }) async {
    final methods = await builder.methodsOf(clazz);
    final equals = methods.firstWhereOrNull((m) => m.identifier.name == '==');
    if (equals == null) {
      throw DiagnosticException(Diagnostic(
          DiagnosticMessage(
              'DataClass internal error, == not found in defining phase',
              target: clazz.asDiagnosticTarget),
          Severity.error));
    }
    final identical = await builder.resolveIdentifier(_dartCore, 'identical');
    final methodBuilder = await builder.buildMethod(equals.identifier);
    final methodBody = FunctionBodyCode.fromParts([
      '{\n',
      '    return ',
      identical,
      '(this, other) || (\n'
      '      other.runtimeType == runtimeType\n',
      '      && other is ',
      clazz.identifier.name,
      '\n',
      if (hasSuper) '      && super == other\n',
      for (final field in fields) ..._getEqualsPartsForField(field, builder, identical),
      '    );\n  }\n',
    ]);
    methodBuilder.augment(methodBody);
  }

  List<Object> _getEqualsPartsForField(FieldDeclaration field, TypeDefinitionBuilder builder, Identifier identical,) {
    return [
      '      && (',
      identical,
      '(',
      field.identifier.name,
      ', other.',
      field.identifier.name,
      ') || ',
      field.identifier.name,
      ' == other.',
      field.identifier.name,
      ')\n'
    ];
  }

  FutureOr<void> _buildHashCode(
    ClassDeclaration clazz,
    List<FieldDeclaration> fields,
    TypeDefinitionBuilder builder, {
    required bool hasSuper,
  }) async {
    final methods = await builder.methodsOf(clazz);
    final hashCode = methods.firstWhereOrNull((m) => m.identifier.name == 'hashCode');
    if (hashCode == null) {
      throw DiagnosticException(Diagnostic(
          DiagnosticMessage(
              'DataClass internal error, hashCode not found in defining phase',
              target: clazz.asDiagnosticTarget),
          Severity.error));
    }
    final methodBuilder = await builder.buildMethod(hashCode.identifier);
    final toBeHashed = [
      if (hasSuper) 'super.hashCode',
      for (final field in fields) field.identifier.name,
    ];
    final toBeHashedParts = [
      for (final name in toBeHashed) ...[
        '      ', name, ',\n'
      ]
    ];
    final objIdentifier = await builder.resolveIdentifier(_dartCore, 'Object');
    final methodBody = FunctionBodyCode.fromParts([
      '{\n',
      '    return ',
      objIdentifier,
      '.hashAll([\n',
      ...toBeHashedParts,
      '    ]);\n  }',
    ]);
    methodBuilder.augment(methodBody);
  }
}

/*

 - Liste / mappe / set immutabili
 - copyWith

 - generics

*/
