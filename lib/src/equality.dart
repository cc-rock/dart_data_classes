import 'dart:async';

import 'package:collection/collection.dart';
import 'package:dart_data_classes/src/common.dart';
import 'package:macros/macros.dart';

mixin EqualityImpl {
  FutureOr<void> declareEquals(
    ClassDeclaration clazz,
    MemberDeclarationBuilder builder,
    Identifier override,
  ) async {
    builder.declareInType(DeclarationCode.fromParts([
      '\n  @',
      override,
      '\n  ',
      await builder.resolveIdentifier(dartCoreUri, 'bool'),
      ' operator ==(',
      await builder.resolveIdentifier(dartCoreUri, 'dynamic'),
      ' other);'
    ]));
  }

  FutureOr<void> declareHashCode(
    ClassDeclaration clazz,
    MemberDeclarationBuilder builder,
    Identifier override,
  ) async {
    builder.declareInType(DeclarationCode.fromParts([
      '\n  @',
      override,
      '\n  ',
      await builder.resolveIdentifier(dartCoreUri, 'int'),
      ' get hashCode;\n',
    ]));
  }

  FutureOr<void> buildEquals(
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
              'DataClass internal error, == not found in definition phase',
              target: clazz.asDiagnosticTarget),
          Severity.error));
    }
    final identical = await builder.resolveIdentifier(dartCoreUri, 'identical');
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
      for (final field in fields)
        ..._getEqualsPartsForField(field, builder, identical),
      '    );\n  }\n',
    ]);
    methodBuilder.augment(methodBody);
  }

  List<Object> _getEqualsPartsForField(
    FieldDeclaration field,
    TypeDefinitionBuilder builder,
    Identifier identical,
  ) {
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

  FutureOr<void> buildHashCode(
    ClassDeclaration clazz,
    List<FieldDeclaration> fields,
    TypeDefinitionBuilder builder, {
    required bool hasSuper,
  }) async {
    final methods = await builder.methodsOf(clazz);
    final hashCode =
        methods.firstWhereOrNull((m) => m.identifier.name == 'hashCode');
    if (hashCode == null) {
      throw DiagnosticException(Diagnostic(
          DiagnosticMessage(
              'DataClass internal error, hashCode not found in definition phase',
              target: clazz.asDiagnosticTarget),
          Severity.error));
    }
    final methodBuilder = await builder.buildMethod(hashCode.identifier);
    final toBeHashed = [
      if (hasSuper) 'super.hashCode',
      for (final field in fields) field.identifier.name,
    ];
    final toBeHashedParts = [
      for (final name in toBeHashed) ...['      ', name, ',\n']
    ];
    final objIdentifier =
        await builder.resolveIdentifier(dartCoreUri, 'Object');
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
