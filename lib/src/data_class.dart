// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:dart_data_classes/src/common.dart';
import 'package:dart_data_classes/src/equality.dart';
import 'package:macros/macros.dart';

class DefaultValue<T> {
  const DefaultValue(this.value);

  final T value;
}

macro class DataClass
    with EqualityImpl
    implements ClassDeclarationsMacro, ClassDefinitionMacro {
  const DataClass();

  @override
  FutureOr<void> buildDeclarationsForClass(
    ClassDeclaration clazz,
    MemberDeclarationBuilder builder,
  ) async {
    await _checkNoUnnamedConstructor(clazz, builder);
    final superClasses = await getSuperClasses(clazz, builder);
    await checkSuperClasses(clazz, superClasses, builder);
    final superFields = await getOrderedSuperFields(superClasses, builder);
    final fields = await builder.fieldsOf(clazz);
    final override = await builder.resolveIdentifier(dartCoreUri, 'override');
    await _declareConstructor(clazz, builder, fields, superFields);
    await declareEquals(clazz, builder, override);
    await declareHashCode(clazz, builder, override);
  }

  @override
  FutureOr<void> buildDefinitionForClass(
    ClassDeclaration clazz,
    TypeDefinitionBuilder builder,
  ) async {
    final superClasses = await getSuperClasses(clazz, builder);
    await checkSuperClasses(clazz, superClasses, builder);
    final fields = await builder.fieldsOf(clazz);
    await buildEquals(clazz, fields, builder,
        hasSuper: superClasses.isNotEmpty);
    await buildHashCode(clazz, fields, builder,
        hasSuper: superClasses.isNotEmpty);
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
      '  }): ',
      ...fields.mapIndexed((index, field) {
        return RawCode.fromParts([
          if (index != 0) ',\n      ',
          'this.',
          field.identifier.name,
          ' = ',
          field.identifier.name,
        ]);
      }),
      if (superFields.isNotEmpty) ...[
        ',\n      super(\n      ',
        for (final field in superFields) ...[
          '  ',
          field.identifier.name,
          ': ',
          field.identifier.name,
          ',\n      '
        ],
        ')',
      ],
      ';',
    ]));
  }

  Future<List<Object>> _getConstructorDeclarationPartsForField(
      MemberDeclarationBuilder builder, FieldDeclaration field) async {
    Object? defaultValue;
    for (final md in field.metadata) {
      if (md is ConstructorMetadataAnnotation) {
        final typeDecl = await builder.typeDeclarationOf(md.type.identifier);
        if (typeDecl.isExactly('DefaultValue', dataClassUri)) {
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
}

/*

 - Liste / mappe / set immutabili

 - deep equals

 - copyWith
   - per data class, tutti i fields tranne i super init
   - per generica class, tutti i parametri del costruttore che hanno un field o super field (gli altri saranno required?)

 - generics

*/
