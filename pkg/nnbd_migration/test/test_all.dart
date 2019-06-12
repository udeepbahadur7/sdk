// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'api_test.dart' as api_test;
import 'migration_visitor_test.dart' as migration_visitor_test;
import 'nullability_node_test.dart' as nullability_node_test;

main() {
  defineReflectiveSuite(() {
    api_test.main();
    migration_visitor_test.main();
    nullability_node_test.main();
  });
}
