// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io' show Directory, Platform;
import 'package:_fe_analyzer_shared/src/testing/id.dart';
import 'package:_fe_analyzer_shared/src/testing/id_testing.dart'
    show DataInterpreter, runTests;
import 'package:_fe_analyzer_shared/src/testing/id_testing.dart';
import 'package:front_end/src/fasta/kernel/kernel_api.dart';
import 'package:front_end/src/testing/id_testing_helper.dart';
import 'package:front_end/src/testing/id_testing_utils.dart';
import 'package:kernel/ast.dart';
import 'package:kernel/type_environment.dart';

main(List<String> args) async {
  Directory dataDir = new Directory.fromUri(Platform.script.resolve('data'));
  await runTests<String>(dataDir,
      args: args,
      supportedMarkers: cfeMarkersWithNnbd,
      createUriForFileName: createUriForFileName,
      onFailure: onFailure,
      runTest: runTestFor(const StaticTypeDataComputer(),
          [defaultCfeConfig, cfeNonNullableConfig]),
      skipMap: {
        defaultCfeConfig.marker: [
          // NNBD-only tests.
          'from_opt_in',
          'from_opt_out',
          'if_null.dart',
          'null_check.dart',
        ]
      });
}

class StaticTypeDataComputer extends DataComputer<String> {
  const StaticTypeDataComputer();

  /// Function that computes a data mapping for [library].
  ///
  /// Fills [actualMap] with the data.
  void computeLibraryData(
      TestConfig config,
      InternalCompilerResult compilerResult,
      Library library,
      Map<Id, ActualData<String>> actualMap,
      {bool verbose}) {
    new StaticTypeDataExtractor(compilerResult, actualMap)
        .computeForLibrary(library);
  }

  @override
  void computeMemberData(
      TestConfig config,
      InternalCompilerResult compilerResult,
      Member member,
      Map<Id, ActualData<String>> actualMap,
      {bool verbose}) {
    member.accept(new StaticTypeDataExtractor(compilerResult, actualMap));
  }

  @override
  DataInterpreter<String> get dataValidator => const StringDataInterpreter();
}

class StaticTypeDataExtractor extends CfeDataExtractor<String> {
  final TypeEnvironment _environment;
  StaticTypeContext _staticTypeContext;

  StaticTypeDataExtractor(InternalCompilerResult compilerResult,
      Map<Id, ActualData<String>> actualMap)
      : _environment = new TypeEnvironment(
            compilerResult.coreTypes, compilerResult.classHierarchy),
        super(compilerResult, actualMap);

  @override
  visitField(Field node) {
    _staticTypeContext = new StaticTypeContext(node, _environment);
    super.visitField(node);
    _staticTypeContext = null;
  }

  @override
  visitConstructor(Constructor node) {
    _staticTypeContext = new StaticTypeContext(node, _environment);
    super.visitConstructor(node);
    _staticTypeContext = null;
  }

  @override
  visitProcedure(Procedure node) {
    _staticTypeContext = new StaticTypeContext(node, _environment);
    super.visitProcedure(node);
    _staticTypeContext = null;
  }

  @override
  String computeLibraryValue(Id id, Library node) {
    return 'nnbd=${node.isNonNullableByDefault}';
  }

  @override
  String computeNodeValue(Id id, TreeNode node) {
    if (node is Expression) {
      DartType type = node.getStaticType(_staticTypeContext);
      return typeToText(type);
    } else if (node is Arguments) {
      if (node.types.isNotEmpty) {
        return '<${node.types.map(typeToText).join(',')}>';
      }
    } else if (node is ForInStatement) {
      if (id.kind == IdKind.current) {
        DartType type = _staticTypeContext.typeEnvironment.forInElementType(
            node, node.iterable.getStaticType(_staticTypeContext));
        return typeToText(type);
      }
    }
    return null;
  }

  ActualData<String> mergeData(
      ActualData<String> value1, ActualData<String> value2) {
    if (value1.object is NullLiteral && value2.object is! NullLiteral) {
      // Skip `null` literals from null-aware operations.
      return value2;
    } else if (value1.object is! NullLiteral && value2.object is NullLiteral) {
      // Skip `null` literals from null-aware operations.
      return value1;
    }
    return new ActualData<String>(value1.id, '${value1.value}|${value2.value}',
        value1.uri, value1.offset, value1.object);
  }
}
