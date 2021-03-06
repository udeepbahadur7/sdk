// Copyright (c) 2020, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// TODO(jcollins-g): finish port away from io
import 'dart:io' show Directory;

import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:nnbd_migration/src/fantasyland/fantasy_repo.dart';
import 'package:nnbd_migration/src/fantasyland/fantasy_sub_package.dart';
import 'package:nnbd_migration/src/fantasyland/fantasy_workspace.dart';
import 'package:nnbd_migration/src/utilities/subprocess_launcher.dart';
import 'package:path/path.dart' as path;

// TODO(jcollins-g): consider refactor that makes resourceProvider required.
class FantasyWorkspaceDependencies {
  final Future<FantasyRepo> Function(FantasyRepoSettings, String)
      buildGitRepoFrom;
  final ResourceProvider resourceProvider;
  final SubprocessLauncher launcher;

  FantasyWorkspaceDependencies(
      {ResourceProvider resourceProvider,
      SubprocessLauncher launcher,
      Future<FantasyRepo> Function(FantasyRepoSettings, String)
          buildGitRepoFrom})
      : resourceProvider =
            resourceProvider ?? PhysicalResourceProvider.INSTANCE,
        launcher = launcher, // Pass through to FantasyRepoDependencies.
        buildGitRepoFrom = buildGitRepoFrom ?? FantasyRepo.buildGitRepoFrom;
}

abstract class FantasyWorkspaceImpl extends FantasyWorkspace {
  @override
  final Directory workspaceRoot;

  // TODO(jcollins-g): inject FantasyWorkspaceDependencies here.
  FantasyWorkspaceImpl._(this.workspaceRoot);

  /// Repositories on which [addRepoToWorkspace] has been called.
  Map<String, Future<FantasyRepo>> _repos = {};

  /// Sub-packages on which [addPackageNameToWorkspace] has been called.
  Map<String, Future<List<String>>> _packageDependencies = {};

  /// Fully initialized subpackages.
  ///
  /// This is complete once all [addPackageNameToWorkspace] futures are complete.
  /// futures are complete.
  Map<String, FantasySubPackage> subPackages = {};

  /// Implementation-dependent part of addPackageToWorkspace.
  ///
  /// The returned future should complete only when this package's repository
  /// is:
  ///
  ///  cloned
  ///  up to date
  ///  added to the global .packages
  ///  symlinked into the workspace
  ///  has a [FantasySubPackage] assigned to its key in [subPackages].
  ///
  /// Returns a list of packageNames that needed to be added as dependencies.
  ///
  /// Which dependencies are automatically added is implementation dependent.
  Future<List<String>> addPackageNameToWorkspaceInternal(String packageName);

  Future<void> addPackageNameToWorkspace(String packageName) async {
    if (_packageDependencies.containsKey(packageName)) return;
    _packageDependencies[packageName] =
        addPackageNameToWorkspaceInternal(packageName);
    return Future.wait([
      for (var n in await _packageDependencies[packageName])
        addPackageNameToWorkspace(n)
    ]);
  }

  static const _repoSubDir = '_repo';

  /// Asynchronously add one repository to the workspace.
  ///
  /// Completes when the repository is synced and cloned.
  /// Completes immediately if the [name] is already added.
  Future<FantasyRepo> addRepoToWorkspace(FantasyRepoSettings repoSettings) {
    if (_repos.containsKey(repoSettings.name)) return _repos[repoSettings.name];
    Directory repoRoot = Directory(path.canonicalize(
        path.join(workspaceRoot.path, _repoSubDir, repoSettings.name)));
    _repos[repoSettings.name] =
        FantasyRepo.buildGitRepoFrom(repoSettings, repoRoot.path);
    return _repos[repoSettings.name];
  }
}

/// Represents a [FantasyWorkspaceImpl] that only fetches dev_dependencies
/// for the top level package.
class FantasyWorkspaceTopLevelDevDepsImpl extends FantasyWorkspaceImpl {
  final String topLevelPackage;

  FantasyWorkspaceTopLevelDevDepsImpl._(
      this.topLevelPackage, Directory workspaceRoot)
      : super._(workspaceRoot);

  static Future<FantasyWorkspace> buildFor(String topLevelPackage,
      List<String> extraPackageNames, String workspaceRoot) async {
    // TODO(jcollins-g): finish port
    Directory workspaceRootDir = Directory(workspaceRoot);
    await workspaceRootDir.create(recursive: true);

    var workspace = FantasyWorkspaceTopLevelDevDepsImpl._(
        topLevelPackage, workspaceRootDir);
    await Future.wait([
      for (var n in [topLevelPackage, ...extraPackageNames])
        workspace.addPackageNameToWorkspace(n)
    ]);
    return workspace;
  }

  Future<List<String>> addPackageNameToWorkspaceInternal(
      String packageName) async {
    FantasySubPackageSettings packageSettings =
        FantasySubPackageSettings.fromName(packageName);
    FantasyRepo containingRepo =
        await addRepoToWorkspace(packageSettings.repoSettings);
    FantasySubPackage fantasySubPackage =
        FantasySubPackage(packageSettings, containingRepo);
    subPackages[fantasySubPackage.name] = fantasySubPackage;

    // TODO(jcollins-g): Add to .packages / package_config.json
    if (packageName == topLevelPackage) {
      throw UnimplementedError();
      // TODO(jcollins-g): implement some dependency calculations inside FantasySubPackage.
    }
    return [];
  }
}
