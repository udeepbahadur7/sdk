// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// This is a regression test for http://dartbug.com/39817.

foo() {
  Null _null;
  for(var i in _null) {};
}

main() {}
