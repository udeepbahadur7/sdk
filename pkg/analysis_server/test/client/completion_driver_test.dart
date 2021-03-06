// Copyright (c) 2020, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:meta/meta.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'package:analyzer/src/test_utilities/resource_provider_mixin.dart';

import '../services/completion/dart/completion_contributor_util.dart';
import 'impl/completion_driver.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(BasicCompletionTest);
  });
}

abstract class AbstractCompletionDriverTest with ResourceProviderMixin {
  CompletionDriver driver;

  Map<String, String> packageRoots;

  List<CompletionSuggestion> suggestions;

  bool get supportsAvailableDeclarations;

  String addTestFile(String content, {int offset}) =>
      driver.addTestFile(content, offset: offset);

  Future<List<CompletionSuggestion>> getSuggestions() async {
    suggestions = await driver.getSuggestions();
    return suggestions;
  }

  @mustCallSuper
  void setUp() {
    driver = CompletionDriver(
        supportsAvailableDeclarations: supportsAvailableDeclarations,
        resourceProvider: resourceProvider);
    driver.createProject(packageRoots: packageRoots);
  }

  SuggestionMatcher suggestionHas(
          {@required String completion,
          ElementKind element,
          CompletionSuggestionKind kind}) =>
      (CompletionSuggestion s) {
        if (s.completion == completion) {
          if (element != null && s.element?.kind != element) {
            return false;
          }
          if (kind != null && s.kind != kind) {
            return false;
          }
          return true;
        }
        return false;
      };

  CompletionSuggestion suggestionWith(
      {@required String completion,
      ElementKind element,
      CompletionSuggestionKind kind}) {
    final matches = suggestions.where(
        suggestionHas(completion: completion, element: element, kind: kind));
    expect(matches, hasLength(1));
    return matches.first;
  }
}

@reflectiveTest
class BasicCompletionTest extends AbstractCompletionDriverTest {
  @override
  bool get supportsAvailableDeclarations => false;

  /// Duplicates (and potentially replaces DeprecatedMemberRelevanceTest.
  Future<void> test_deprecated_member_relevance() async {
    addTestFile('''
class A {
  void a1() { }
  @deprecated
  void a2() { }
}

void main() {
  var a = A();
  a.^
}
''');

    await getSuggestions();
    expect(
        suggestionWith(
                completion: 'a2',
                element: ElementKind.METHOD,
                kind: CompletionSuggestionKind.INVOCATION)
            .relevance,
        lessThan(suggestionWith(
                completion: 'a1',
                element: ElementKind.METHOD,
                kind: CompletionSuggestionKind.INVOCATION)
            .relevance));
  }
}
