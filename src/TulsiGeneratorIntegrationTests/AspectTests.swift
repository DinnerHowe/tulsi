// Copyright 2016 The Tulsi Authors. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import XCTest
@testable import TulsiGenerator


// Tests for the tulsi_sources_aspect aspect.
class TulsiSourcesAspectTests: BazelIntegrationTestCase {
  var aspectInfoExtractor: BazelAspectInfoExtractor! = nil

  override func setUp() {
    super.setUp()
    aspectInfoExtractor = BazelAspectInfoExtractor(bazelURL: bazelURL,
                                                   workspaceRootURL: workspaceRootURL!,
                                                   localizedMessageLogger: localizedMessageLogger)
  }

  func testSimple() throws {
    installBUILDFile("Simple", intoSubdirectory: "tulsi_test")
    makeTestXCDataModel("SimpleDataModelsTestv1", inSubdirectory: "tulsi_test/SimpleTest.xcdatamodeld")
    makeTestXCDataModel("SimpleDataModelsTestv2", inSubdirectory: "tulsi_test/SimpleTest.xcdatamodeld")
    var buildOptions = bazelBuildOptions
    buildOptions.append("--copt=-DA_COMMANDLINE_DEFINE")
    buildOptions.append("--copt=-DA_COMMANDLINE_DEFINE_WITH_VALUE=1")
    buildOptions.append("--copt=-DA_COMMANDLINE_DEFINE_WITH_SPACE_VALUE='this has a space'")
    let ruleEntryMap = try aspectInfoExtractor.extractRuleEntriesForLabels([BuildLabel("//tulsi_test:XCTest")],
                                                                           startupOptions: bazelStartupOptions,
                                                                           buildOptions: buildOptions)
    XCTAssertEqual(ruleEntryMap.allRuleEntries.count, 11)

    let checker = InfoChecker(ruleEntryMap: ruleEntryMap)

    checker.assertThat("//tulsi_test:Application")
        .dependsOn("//tulsi_test:Application.apple_binary")
        .hasListAttribute(.compiler_defines,
                          containing: ["A_COMMANDLINE_DEFINE",
                                       "A_COMMANDLINE_DEFINE_WITH_VALUE=1",
                                       "A_COMMANDLINE_DEFINE_WITH_SPACE_VALUE='this has a space'"])
        .hasAttribute(.launch_storyboard, value: ["is_dir": false,
                                                  "path": "tulsi_test/Application/Launch.storyboard",
                                                  "src": true] as NSDictionary)

    checker.assertThat("//tulsi_test:Application.apple_binary")
        .dependsOn("//tulsi_test:ApplicationLibrary")

    checker.assertThat("//tulsi_test:ApplicationLibrary")
        .dependsOn("//tulsi_test:Library")
        .hasSources(["tulsi_test/ApplicationLibrary/srcs/main.m"])
        .hasAttribute(.datamodels, value: [["is_dir": false,
                                            "path": "tulsi_test/SimpleTest.xcdatamodeld/SimpleDataModelsTestv1.xcdatamodel",
                                            "src": true],
                                           ["is_dir": false,
                                            "path": "tulsi_test/SimpleTest.xcdatamodeld/SimpleDataModelsTestv2.xcdatamodel",
                                            "src": true], ] as NSArray)
        .hasDefines(["LIBRARY_DEFINES_DEFINE=1",
                     "APPLIB_ADDITIONAL_DEFINE",
                     "APPLIB_ANOTHER_DEFINE=2"])
        .hasIncludes(["tulsi_test/ApplicationLibrary/includes",
                      "_tulsi-includes/x/x/tulsi_test/ApplicationLibrary/includes"])
        .hasAttribute(.supporting_files,
                      value: [["is_dir": false,
                               "path": "tulsi_test/ApplicationLibrary/Base.lproj/One.storyboard",
                               "src": true],
                              ["is_dir": false,
                               "path": "tulsi_test/ApplicationLibrary/Assets.xcassets",
                               "src": true],] as NSArray)

    checker.assertThat("//tulsi_test:Library")
        .hasSources(["tulsi_test/Library/srcs/src1.m",
                     "tulsi_test/Library/srcs/src2.m",
                     "tulsi_test/Library/srcs/src3.m",
                     "tulsi_test/Library/srcs/src4.m",
                     "tulsi_test/Library/srcs/SrcsHeader.h",
                     "tulsi_test/Library/hdrs/HdrsHeader.h",
                     "tulsi_test/Library/textual_hdrs/TextualHdrsHeader.h"])
        .hasAttribute(.copts, value: ["-DLIBRARY_COPT_DEFINE",
                                      "-I/Library/absolute/include/path",
                                      "-Irelative/Library/include/path"] as NSArray)
        .hasDefines(["LIBRARY_DEFINES_DEFINE=1"])
        .hasAttribute(.pch, value: ["is_dir": false,
                                    "path": "tulsi_test/Library/pch/PCHFile.pch",
                                    "src": true] as NSDictionary)
        .hasAttribute(.supporting_files,
                      value: [["is_dir": false,
                               "path": "tulsi_test/Library/xibs/xib.xib",
                               "src": true]] as NSArray)

    checker.assertThat("//tulsi_test:XCTest")
        .hasTestHost("//tulsi_test:Application")
        .hasDeploymentTarget(DeploymentTarget(platform: .ios, osVersion: "8.0"))
        .dependsOn("//tulsi_test:Application")
        .dependsOn("//tulsi_test:XCTest_test_bundle")

    checker.assertThat("//tulsi_test:XCTest_test_bundle")
        .dependsOn("//tulsi_test:XCTest_test_binary")
        .dependsOn("//tulsi_test:Application")

    checker.assertThat("//tulsi_test:XCTest_test_binary")
        .dependsOn("//tulsi_test:TestLibrary")
  }

  func testExceptionThrown() {
    installBUILDFile("SimpleBad", intoSubdirectory: "tulsi_test")
    do {
      let _ = try aspectInfoExtractor.extractRuleEntriesForLabels([BuildLabel("//tulsi_test:Application"),
                                                                   BuildLabel("//tulsi_test:XCTest")],
                                                                  startupOptions: bazelStartupOptions,
                                                                  buildOptions: bazelBuildOptions)
    } catch BazelAspectInfoExtractor.ExtractorError.buildFailed {
      // Expected failure on malformed BUILD file.
      XCTAssert(aspectInfoExtractor.hasQueuedInfoMessages)
      return
    } catch let e {
      XCTFail("Expected exception of type 'BazelAspectInfoExtractor.ExtractorError.buildFailed' " +
        "but instead received exception of \(e).")
    }
    XCTFail("Expected exception of type 'BazelAspectInfoExtractor.ExtractorError.buildFailed' " +
        "to be thrown for bazel aspect build error.")
  }

  func complexSingleTest_DefaultConfig() throws {
    installBUILDFile("ComplexSingle", intoSubdirectory: "tulsi_test")
    makeTestXCDataModel("DataModelsTestv1", inSubdirectory: "tulsi_test/Test.xcdatamodeld")
    makeTestXCDataModel("DataModelsTestv2", inSubdirectory: "tulsi_test/Test.xcdatamodeld")

    // iOS extension's Info.plist is generated by the Aspect after reading the infoplists listed in
    // the attribute, so we'll need to generate them otherwise extraction will fail.
    makePlistFileNamed("Plist1.plist",
                       withContent: ["NSExtension": ["NSExtensionPointIdentifier": "com.apple.extension-foo"]],
                       inSubdirectory: "(tulsi_test/TodayExtension")

    let ruleEntryMap = try aspectInfoExtractor.extractRuleEntriesForLabels([BuildLabel("//tulsi_test:XCTest")],
                                                                           startupOptions: bazelStartupOptions,
                                                                           buildOptions: bazelBuildOptions)
    XCTAssertEqual(ruleEntryMap.allRuleEntries.count, 26)

    let checker = InfoChecker(ruleEntryMap: ruleEntryMap)

    checker.assertThat("//tulsi_test:Application")
        .dependsOn("//tulsi_test:Application.apple_binary")
        .dependsOn("//tulsi_test:TodayExtension")
        .hasAttribute(.supporting_files,
                      value: [["is_dir": false,
                               "path": "tulsi_test/Application/Info.plist",
                               "src": true]] as NSArray)

    checker.assertThat("//tulsi_test:ApplicationResources")
        .hasAttribute(.supporting_files,
                      value: [["is_dir": false,
                               "path": "tulsi_test/Application/structured_resources.file1",
                               "src": true],
                              ["is_dir": false,
                               "path": "tulsi_test/Application/structured_resources.file2",
                               "src": true]] as NSArray)

    checker.assertThat("//tulsi_test:ApplicationLibrary")
        .dependsOn("//tulsi_test:Library")
        .dependsOn("//tulsi_test:NonPropagatedLibrary")
        .dependsOn("//tulsi_test:ObjCBundle")
        .hasSources(["tulsi_test/Application/srcs/main.m",
                     "blaze-genfiles/tulsi_test/SrcGenerator/outs/output.m"
                    ])
        .hasNonARCSources(["tulsi_test/Application/non_arc_srcs/NonARCFile.mm"])
        .hasDefines(["SubLibraryWithDefines=1",
                     "SubLibraryWithDefines_DEFINE=SubLibraryWithDefines",
                     "SubLibraryWithDifferentDefines=1",
                     "LIBRARY_DEFINES_DEFINE=1",
                     "LIBRARY SECOND DEFINE=2",
                     "LIBRARY_VALUE_WITH_SPACES=Value with spaces",
                     "A=BINARY_DEFINE"])
        .hasIncludes(["tulsi_test/Application/includes/first/include",
                      "tulsi-includes/x/x/tulsi_test/Application/includes/first/include",
                      "tulsi_test/Application/includes/second/include",
                      "tulsi-includes/x/x/tulsi_test/Application/includes/second/include",
                      "tulsi_test/SubLibraryWithDifferentDefines/includes",
                      "tulsi-includes/x/x/tulsi_test/SubLibraryWithDifferentDefines/includes"])
        .hasAttribute(.supporting_files,
                      value: [["is_dir": false,
                               "path": "tulsi_test/Application/Base.lproj/Localizable.strings",
                               "src": true],
                              ["is_dir": false,
                               "path": "tulsi_test/Application/Base.lproj/Localized.strings",
                               "src": true],
                              ["is_dir": false,
                               "path": "tulsi_test/Application/en.lproj/Localized.strings",
                               "src": true],
                              ["is_dir": false,
                               "path": "tulsi_test/Application/en.lproj/EN.strings",
                               "src": true],
                              ["is_dir": false,
                               "path": "tulsi_test/Application/es.lproj/Localized.strings",
                               "src": true],
                              ["is_dir": false,
                               "path": "tulsi_test/Application/NonLocalized.strings",
                               "src": true],
                              ["is_dir": false,
                               "path": "tulsi_test/Application/Base.lproj/One.storyboard",
                               "src": true],
                              ["is_dir": false,
                               "path": "tulsi_test/StoryboardGenerator/outs/Two.storyboard",
                               "root": "blaze-genfiles",
                               "src": false],
                              ["is_dir": false,
                               "path": "tulsi_test/Application/AssetsOne.xcassets",
                               "src": true],
                              ["is_dir": false,
                               "path": "tulsi_test/Application/AssetsTwo.xcassets",
                               "src": true]] as NSArray)

    checker.assertThat("//tulsi_test:ObjCBundle")
        .hasAttribute(.supporting_files,
                      value: [["is_dir": false,
                               "path": "tulsi_test/ObjCBundle.bundle",
                               "src": true]] as NSArray)

    checker.assertThat("//tulsi_test:CoreDataResources")
        .hasAttribute(.datamodels,
                      value: [["is_dir": false,
                               "path": "tulsi_test/Test.xcdatamodeld/DataModelsTestv1.xcdatamodel",
                               "src": true],
                              ["is_dir": false,
                               "path": "tulsi_test/Test.xcdatamodeld/DataModelsTestv2.xcdatamodel",
                               "src": true], ] as NSArray)

    checker.assertThat("//tulsi_test:Library")
        .hasSources(["tulsi_test/LibrarySources/srcs/src1.m",
                     "tulsi_test/LibrarySources/srcs/src2.m",
                     "tulsi_test/LibrarySources/srcs/src3.m",
                     "tulsi_test/LibrarySources/srcs/src4.m",
                     "tulsi_test/Library/srcs/src5.mm",
                     "tulsi_test/Library/srcs/SrcsHeader.h",
                     "tulsi_test/Library/hdrs/HdrsHeader.h"])
        .hasAttribute(.copts, value: ["-DLIBRARY_COPT_DEFINE"] as NSArray)
        .hasDefines(["SubLibraryWithDefines=1",
                     "SubLibraryWithDefines_DEFINE=SubLibraryWithDefines",
                     "SubLibraryWithDifferentDefines=1",
                     "LIBRARY_DEFINES_DEFINE=1",
                     "LIBRARY SECOND DEFINE=2",
                     "LIBRARY_VALUE_WITH_SPACES=Value with spaces",])
        .hasAttribute(.pch, value: ["is_dir": false,
                                    "path": "tulsi_test/PCHGenerator/outs/PCHFile.pch",
                                    "root": "blaze-genfiles",
                                    "src": false] as NSDictionary)
        .hasAttribute(.supporting_files,
                      value: [["is_dir": false, "path": "tulsi_test/Library/xib.xib", "src": true]] as NSArray)

    checker.assertThat("//tulsi_test:SubLibrary")
        .hasSources(["tulsi_test/SubLibrary/srcs/src.mm"])
        .hasAttribute(.pch, value: ["is_dir": false,
                                    "path": "tulsi_test/SubLibrary/pch/AnotherPCHFile.pch",
                                    "src": true] as NSDictionary)
        .hasAttribute(.enable_modules, value: true)

    checker.assertThat("//tulsi_test:SubLibraryWithDefines")
        .hasSources(["tulsi_test/SubLibraryWithDefines/srcs/src.mm"])
        .hasAttribute(.copts, value: ["-menable-no-nans",
                                      "-menable-no-infs",
                                      "-I/SubLibraryWithDefines/local/includes",
                                      "-Irelative/SubLibraryWithDefines/local/includes"] as NSArray)
        .hasDefines(["SubLibraryWithDefines=1",
                     "SubLibraryWithDefines_DEFINE=SubLibraryWithDefines"])

    checker.assertThat("//tulsi_test:SubLibraryWithDifferentDefines")
        .hasSources(["tulsi_test/SubLibraryWithDifferentDefines/srcs/src.mm"])
        .hasAttribute(.copts, value: ["-DSubLibraryWithDifferentDefines_LocalDefine",
                                      "-DSubLibraryWithDifferentDefines_INTEGER_DEFINE=1",
                                      "-DSubLibraryWithDifferentDefines_STRING_DEFINE=Test",
                                      "-DSubLibraryWithDifferentDefines_STRING_WITH_SPACES='String with spaces'",
                                      "-D'SubLibraryWithDifferentDefines Define with spaces'",
                                      "-D'SubLibraryWithDifferentDefines Define with spaces and value'=1"] as NSArray)
        .hasDefines(["SubLibraryWithDifferentDefines=1"])
        .hasIncludes(["tulsi_test/SubLibraryWithDifferentDefines/includes",
                      "tulsi-includes/x/x/tulsi_test/SubLibraryWithDifferentDefines/includes"])

    checker.assertThat("//tulsi_test:NonPropagatedLibrary")
        .hasSources(["tulsi_test/NonPropagatedLibrary/srcs/non_propagated.m"])

    checker.assertThat("//tulsi_test:ObjCFramework")
        .hasFrameworks(["tulsi_test/ObjCFramework/test.framework"])

    checker.assertThat("//tulsi_test:TodayExtensionLibrary")
        .hasSources(["tulsi_test/TodayExtension/srcs/today_extension_library.m"])

    checker.assertThat("//tulsi_test:TodayExtension")
        .dependsOn("//tulsi_test:TodayExtension.apple_binary")

    checker.assertThat("//tulsi_test:TodayExtension.apple_binary")
        .dependsOn("//tulsi_test:TodayExtensionLibrary")
        .dependsOn("//tulsi_test:TodayExtensionResources")

    checker.assertThat("//tulsi_test:XCTest")
        .hasTestHost("//tulsi_test:Application")
        .dependsOn("//tulsi_test:Application")
        .dependsOn("//tulsi_test:XCTest_test_bundle")

    checker.assertThat("//tulsi_test:XCTest_test_bundle")
        .dependsOn("//tulsi_test:Application")
        .dependsOn("//tulsi_test:XCTest_test_binary")

    checker.assertThat("//tulsi_test:XCTest_test_binary")
        .dependsOn("//tulsi_test:Library")
        .dependsOn("//tulsi_test:TestLibrary")
  }

  func testComplexSingle_ConfigTestEnabled() throws {
    bazelBuildOptions.append("--define=TEST=1")

    installBUILDFile("ComplexSingle", intoSubdirectory: "tulsi_test")
    // iOS extension's Info.plist is generated by the Aspect after reading the infoplists listed in
    // the attribute, so we'll need to generate them otherwise extraction will fail.
    let url = makePlistFileNamed("Plist1.plist",
                                 withContent: ["NSExtension": ["NSExtensionPointIdentifier": "com.apple.extension-foo"],
                                               "CFBundleVersion": "1.0",
                                               "CFBundleShortVersionString": "1.0"],
                                 inSubdirectory: "tulsi_test/TodayExtension")
    XCTAssertNotNil(url)

    let ruleEntryMap = try aspectInfoExtractor.extractRuleEntriesForLabels([BuildLabel("//tulsi_test:XCTest")],
                                                                           startupOptions: bazelStartupOptions,
                                                                           buildOptions: bazelBuildOptions)
    XCTAssertEqual(ruleEntryMap.allRuleEntries.count, 26)

    let checker = InfoChecker(ruleEntryMap: ruleEntryMap)

    checker.assertThat("//tulsi_test:XCTest")
        .hasTestHost("//tulsi_test:Application")
        .hasDeploymentTarget(DeploymentTarget(platform: .ios, osVersion: "8.0"))
        .dependsOn("//tulsi_test:Application")
        .dependsOn("//tulsi_test:XCTest_test_bundle")

    checker.assertThat("//tulsi_test:XCTest_test_bundle")
        .dependsOn("//tulsi_test:Application")
        .dependsOn("//tulsi_test:XCTest_test_binary")

    checker.assertThat("//tulsi_test:XCTest_test_binary")
        .dependsOn("//tulsi_test:Library")
        .dependsOn("//tulsi_test:TestLibrary")
  }

  func testPlatformDependent() throws {
    installBUILDFile("PlatformDependent", intoSubdirectory: "tulsi_test")

    // iOS extension's Info.plist if triggered to build by the Tulsi aspect, so we need to create
    // the actual file. In addition, it pulls in all asset catalogs defined on the extension, so
    // create those too.
    makePlistFileNamed("Ext-Info.plist",
                       withContent: ["NSExtension": ["NSExtensionPointIdentifier": "com.apple.extension-foo"],
                                     "CFBundleVersion": "1.0",
                                     "CFBundleShortVersionString": "1.0"],
                       inSubdirectory: "tulsi_test")
    makeFileNamed("asset.png", inSubdirectory: "tulsi_test/Stickers.xcstickers")

    let ruleEntryMap = try aspectInfoExtractor.extractRuleEntriesForLabels([BuildLabel("//tulsi_test:SkylarkApplication")],
                                                                           startupOptions: bazelStartupOptions,
                                                                           buildOptions: bazelBuildOptions)
    XCTAssertEqual(ruleEntryMap.allRuleEntries.count, 14)
    let checker = InfoChecker(ruleEntryMap: ruleEntryMap)

    checker.assertThat("//tulsi_test:SkylarkApplication")
        .dependsOn("//tulsi_test:SkylarkApplication.apple_binary")

    checker.assertThat("//tulsi_test:SkylarkApplication.apple_binary")
        .dependsOn("//tulsi_test:MainLibrary")

    checker.assertThat("//tulsi_test:MainLibrary")
        .hasSources(["tulsi_test/App/srcs/main.m"])

    checker.assertThat("//tulsi_test:J2ObjCLibrary")
        .exists()

    checker.assertThat("//tulsi_test:ObjcProtos")
        .containsNonARCSources(["_tulsi-includes/x/x/tulsi_test/_generated_protos/ObjcProtos/tulsi_test/ProtoFile.pbobjc.h"])

    checker.assertThat("//tulsi_test:Protos")
        .hasSources(["tulsi_test/ProtoFile.proto"])

    checker.assertThat("//tulsi_test:JavaLibrary")
        .hasSources(["tulsi_test/file.java"])
  }

  func testPlatformDependentXCTestWithNoTestHost() throws {
    installBUILDFile("PlatformDependent", intoSubdirectory: "tulsi_test")
    let ruleEntryMap = try aspectInfoExtractor.extractRuleEntriesForLabels([BuildLabel("//tulsi_test:XCTestWithNoTestHost")],
                                                                           startupOptions: bazelStartupOptions,
                                                                           buildOptions: bazelBuildOptions)
    let checker = InfoChecker(ruleEntryMap: ruleEntryMap)
    checker.assertThat("//tulsi_test:XCTestWithNoTestHost")
        .doesNotHaveTestHost()
        .dependsOn("//tulsi_test:XCTestWithNoTestHost_test_bundle")

    checker.assertThat("//tulsi_test:XCTestWithNoTestHost_test_bundle")
        .dependsOn("//tulsi_test:XCTestWithNoTestHost_test_binary")

    checker.assertThat("//tulsi_test:XCTestWithNoTestHost_test_binary")
        .dependsOn("//tulsi_test:XCTestCode")
        .dependsOn("//tulsi_test:XCTestCodeSwift")
  }

  func testWatch() throws {
    installBUILDFile("Watch", intoSubdirectory: "tulsi_test")
    let ruleEntryMap = try aspectInfoExtractor.extractRuleEntriesForLabels([BuildLabel("//tulsi_test:Application")],
                                                                           startupOptions: bazelStartupOptions,
                                                                           buildOptions: bazelBuildOptions)
    // TODO(b/65252498): Enable when the bug is fixed.
    // XCTAssertEqual(ruleEntries.allRuleEntries.count, 13)

    let checker = InfoChecker(ruleEntryMap: ruleEntryMap)

    checker.assertThat("//tulsi_test:Application")
      .dependsOn("//tulsi_test:Application.apple_binary")

    checker.assertThat("//tulsi_test:Application.apple_binary")
      .dependsOn("//tulsi_test:ApplicationLibrary")
      .dependsOn("//tulsi_test:ApplicationResources")

    checker.assertThat("//tulsi_test:ApplicationLibrary")
      .hasSources(["tulsi_test/Library/srcs/main.m"])
      .hasIncludes(["tulsi_test/Library/includes/one/include",
                    "_tulsi-includes/x/x/tulsi_test/Library/includes/one/include"])

    checker.assertThat("//tulsi_test:WatchApplication")
      .dependsOn("//tulsi_test:WatchExtension")
      .dependsOn("//tulsi_test:WatchApplicationResources")

    checker.assertThat("//tulsi_test:WatchExtension")
      .dependsOn("//tulsi_test:WatchExtension.apple_binary")

    checker.assertThat("//tulsi_test:WatchExtension.apple_binary")
      .dependsOn("//tulsi_test:WatchExtensionLibrary")
      .dependsOn("//tulsi_test:WatchExtensionResources")

    checker.assertThat("//tulsi_test:WatchExtensionLibrary")
      .hasSources(["tulsi_test/Watch2ExtensionBinary/srcs/watch2_extension_binary.m"])
  }

  func testSwift() throws {
    installBUILDFile("Swift", intoSubdirectory: "tulsi_test")
    let labels = [BuildLabel("//tulsi_test:Application")]
    let ruleEntryMap =
        try aspectInfoExtractor.extractRuleEntriesForLabels(labels,
                                                            startupOptions: bazelStartupOptions,
                                                            buildOptions: bazelBuildOptions)
    XCTAssertEqual(ruleEntryMap.allRuleEntries.count, 8)

    let checker = InfoChecker(ruleEntryMap: ruleEntryMap)

    checker.assertThat("//tulsi_test:Application")
        .dependsOn("//tulsi_test:Application.apple_binary")

    checker.assertThat("//tulsi_test:Application.apple_binary")
        .dependsOn("//tulsi_test:ApplicationLibrary")

    checker.assertThat("//tulsi_test:ApplicationLibrary")
        .dependsOn("//tulsi_test:SwiftLibrary")
        .dependsOn("//tulsi_test:SwiftLibraryV3")
        .dependsOn("//tulsi_test:SwiftLibraryV4")

    checker.assertThat("//tulsi_test:SwiftLibrary")
        .hasSources(["tulsi_test/SwiftLibrary/srcs/a.swift",
                     "tulsi_test/SwiftLibrary/srcs/b.swift"])
        .hasAttribute(.has_swift_dependency, value: true)

    checker.assertThat("//tulsi_test:SwiftLibraryV3")
        .hasSources(["tulsi_test/SwiftLibraryV3/srcs/a.swift",
                     "tulsi_test/SwiftLibraryV3/srcs/b.swift"])
        .hasAttribute(.swift_language_version, value: "3")

    checker.assertThat("//tulsi_test:SwiftLibraryV4")
        .hasSources(["tulsi_test/SwiftLibraryV4/srcs/a.swift",
                     "tulsi_test/SwiftLibraryV4/srcs/b.swift"])
        .hasAttribute(.swift_language_version, value: "4")
  }

}

// Tests for test_suite support.
class TulsiSourcesAspect_TestSuiteTests: BazelIntegrationTestCase {
  var aspectInfoExtractor: BazelAspectInfoExtractor! = nil
  let testDir = "TestSuite"

  override func setUp() {
    super.setUp()
    aspectInfoExtractor = BazelAspectInfoExtractor(bazelURL: bazelURL,
                                                   workspaceRootURL: workspaceRootURL!,
                                                   localizedMessageLogger: localizedMessageLogger)
    installBUILDFile("TestSuiteRoot",
                     intoSubdirectory: testDir,
                     fromResourceDirectory: "TestSuite")
    installBUILDFile("TestOne",
                     intoSubdirectory: "\(testDir)/One",
                     fromResourceDirectory: "TestSuite/One")
    installBUILDFile("TestTwo",
                     intoSubdirectory: "\(testDir)/Two",
                     fromResourceDirectory: "TestSuite/Two")
    installBUILDFile("TestThree",
                     intoSubdirectory: "\(testDir)/Three",
                     fromResourceDirectory: "TestSuite/Three")
  }

  func testTestSuite_ExplicitXCTests_Query() throws {
    let ruleEntryMap = try aspectInfoExtractor.extractRuleEntriesForLabels([BuildLabel("//\(testDir):explicit_XCTests")],
                                                                           startupOptions: bazelStartupOptions,
                                                                           buildOptions: bazelBuildOptions,
                                                                           useAspectForTestSuites: false)
    XCTAssertEqual(ruleEntryMap.allRuleEntries.count, 23)
    let checker = InfoChecker(ruleEntryMap: ruleEntryMap)

    checker.assertThat("//\(testDir)/One:XCTest")
        .hasTestHost("//\(testDir):TestApplication")
    checker.assertThat("//\(testDir)/One:LogicTest")
        .exists()
    checker.assertThat("//\(testDir)/Two:XCTest")
        .hasTestHost("//\(testDir):TestApplication")
    checker.assertThat("//\(testDir)/Three:XCTest")
        .hasTestHost("//\(testDir):TestApplication")

  }

  func testTestSuite_ExplicitXCTests_Aspect() throws {
    let ruleEntryMap = try aspectInfoExtractor.extractRuleEntriesForLabels([BuildLabel("//\(testDir):explicit_XCTests")],
                                                                           startupOptions: bazelStartupOptions,
                                                                           buildOptions: bazelBuildOptions,
                                                                           useAspectForTestSuites: true)
    XCTAssertEqual(ruleEntryMap.allRuleEntries.count, 24)
    let checker = InfoChecker(ruleEntryMap: ruleEntryMap)

    checker.assertThat("//\(testDir):explicit_XCTests")
        .hasType("test_suite")
    checker.assertThat("//\(testDir)/One:XCTest")
        .hasTestHost("//\(testDir):TestApplication")
    checker.assertThat("//\(testDir)/One:LogicTest")
        .exists()
    checker.assertThat("//\(testDir)/Two:XCTest")
        .hasTestHost("//\(testDir):TestApplication")
    checker.assertThat("//\(testDir)/Three:XCTest")
        .hasTestHost("//\(testDir):TestApplication")


  }

  func testTestSuite_TaggedTests_Query() throws {
    let ruleEntryMap = try aspectInfoExtractor.extractRuleEntriesForLabels([BuildLabel("//\(testDir):local_tagged_tests")],
                                                                           startupOptions: bazelStartupOptions,
                                                                           buildOptions: bazelBuildOptions,
                                                                           useAspectForTestSuites: false)
    XCTAssertEqual(ruleEntryMap.allRuleEntries.count, 10)
    let checker = InfoChecker(ruleEntryMap: ruleEntryMap)

    checker.assertThat("//\(testDir):TestSuiteXCTest")
        .hasTestHost("//\(testDir):TestApplication")
  }

  func testTestSuite_TaggedTests_Aspect() throws {
    let ruleEntryMap = try aspectInfoExtractor.extractRuleEntriesForLabels([BuildLabel("//\(testDir):local_tagged_tests")],
                                                                           startupOptions: bazelStartupOptions,
                                                                           buildOptions: bazelBuildOptions,
                                                                           useAspectForTestSuites: true)
    XCTAssertEqual(ruleEntryMap.allRuleEntries.count, 11)
    let checker = InfoChecker(ruleEntryMap: ruleEntryMap)

    checker.assertThat("//\(testDir):TestSuiteXCTest")
        .hasTestHost("//\(testDir):TestApplication")
  }
}


private class InfoChecker {
  let ruleEntryMap: RuleEntryMap

  init(ruleEntryMap: RuleEntryMap) {
    self.ruleEntryMap = ruleEntryMap
  }

  func assertThat(_ targetLabel: String, line: UInt = #line) -> Context {
    let ruleEntry = ruleEntryMap.anyRuleEntry(withBuildLabel: BuildLabel(targetLabel))
    XCTAssertNotNil(ruleEntry,
                    "No rule entry with the label \(targetLabel) was found",
                    line: line)

    return Context(ruleEntry: ruleEntry, ruleEntryMap: ruleEntryMap)
  }

  /// Context allowing checks against a single rule entry instance.
  class Context {
    let ruleEntry: RuleEntry?
    let ruleEntryMap: RuleEntryMap
    let resolvedSourceFiles: Set<String>
    let resolvedNonARCSourceFiles: Set<String>
    let resolvedFrameworkFiles: Set<String>

    init(ruleEntry: RuleEntry?, ruleEntryMap: RuleEntryMap) {
      self.ruleEntry = ruleEntry
      self.ruleEntryMap = ruleEntryMap

      if let ruleEntry = ruleEntry {
        resolvedSourceFiles = Set(ruleEntry.sourceFiles.map() { $0.fullPath })
        resolvedNonARCSourceFiles = Set(ruleEntry.nonARCSourceFiles.map() { $0.fullPath })
        resolvedFrameworkFiles = Set(ruleEntry.frameworkImports.map() { $0.fullPath })
      } else {
        resolvedSourceFiles = []
        resolvedNonARCSourceFiles = []
        resolvedFrameworkFiles = []
      }
    }

    // Does nothing as "assertThat" already asserted the existence of the associated ruleEntry.
    @discardableResult
    func exists() -> Context {
      return self
    }
    /// Asserts that the contextual RuleEntry has the specified type.
    @discardableResult
    func hasType(_ type: String, line: UInt = #line) -> Context {
      guard let ruleEntry = ruleEntry else { return self }
      XCTAssert(ruleEntry.type == type,
                "\(ruleEntry) does not have expected type '\(type)'",
        line: line)
      return self
    }

    /// Asserts that the contextual RuleEntry is linked to a rule identified by the given
    /// targetLabel as a dependency.
    @discardableResult
    func dependsOn(_ targetLabel: String, line: UInt = #line) -> Context {
      guard let ruleEntry = ruleEntry else { return self }
      XCTAssert(ruleEntry.dependencies.contains(BuildLabel(targetLabel)),
                "\(ruleEntry) must depend on \(targetLabel)",
                line: line)
      return self
    }

    /// Asserts that the contextual RuleEntry contains the given list of sources (but may have
    /// others as well).
    @discardableResult
    func containsSources(_ sources: [String], line: UInt = #line) -> Context {
      guard let ruleEntry = ruleEntry else { return self }
      for s in sources {
        XCTAssert(resolvedSourceFiles.contains(s),
                  "\(ruleEntry) missing expected source file '\(s)'",
                  line: line)
      }
      return self
    }

    /// Asserts that the contextual RuleEntry has exactly the given list of sources.
    @discardableResult
    func hasSources(_ sources: [String], line: UInt = #line) -> Context {
      guard let ruleEntry = ruleEntry else { return self }
      containsSources(sources, line: line)
      XCTAssertEqual(ruleEntry.sourceFiles.count,
                     sources.count,
                     "\(ruleEntry) expected to have exactly \(sources.count) source files but has \(ruleEntry.sourceFiles.count)",
                     line: line)
      return self
    }

    /// Asserts that the contextual RuleEntry contains the given list of non-ARC sources (but may
    /// have others as well).
    @discardableResult
    func containsNonARCSources(_ sources: [String], line: UInt = #line) -> Context {
      guard let ruleEntry = ruleEntry else { return self }
      for s in sources {
        XCTAssert(resolvedNonARCSourceFiles.contains(s),
                  "\(ruleEntry) missing expected non-ARC source file '\(s)'",
                  line: line)
      }
      return self
    }

    /// Asserts that the contextual RuleEntry has exactly the given list of non-ARC sources.
    func hasNonARCSources(_ sources: [String], line: UInt = #line) -> Context {
      guard let ruleEntry = ruleEntry else { return self }
      containsNonARCSources(sources, line: line)
      XCTAssertEqual(ruleEntry.nonARCSourceFiles.count,
                     sources.count,
                     "\(ruleEntry) expected to have exactly \(sources.count) non-ARC source files but has \(ruleEntry.nonARCSourceFiles.count)",
                     line: line)
      return self
    }

    /// Asserts that the contextual RuleEntry contains the given list of framework imports (but may
    /// have others as well).
    @discardableResult
    func containsFrameworks(_ frameworks: [String], line: UInt = #line) -> Context {
      guard let ruleEntry = ruleEntry else { return self }
      for s in frameworks {
        XCTAssert(resolvedFrameworkFiles.contains(s),
                  "\(ruleEntry) missing expected framework import '\(s)'",
                  line: line)
      }
      return self
    }

    /// Asserts that the contextual RuleEntry has exactly the given list of framework imports.
    @discardableResult
    func hasFrameworks(_ frameworks: [String], line: UInt = #line) -> Context {
      guard let ruleEntry = ruleEntry else { return self }
      containsFrameworks(frameworks, line: line)
      XCTAssertEqual(ruleEntry.frameworkImports.count,
                     frameworks.count,
                     "\(ruleEntry) expected to have exactly \(frameworks.count) framework imports but has \(ruleEntry.frameworkImports.count)",
                     line: line)
      return self
    }

    /// Asserts that the contextual RuleEntry is a test target with a test_host identified by the
    /// given label.
    @discardableResult
    func hasTestHost(_ targetLabel: String, line: UInt = #line) -> Context {
      guard let ruleEntry = ruleEntry else { return self }
      let hostLabelString = ruleEntry.attributes[.test_host] as? String
      XCTAssertEqual(hostLabelString,
                     targetLabel,
                     "\(ruleEntry) expected to have a test_host of \(targetLabel)",
                     line: line)
      return self
    }

    /// Asserts that the contextual RuleEntry has the given Deployment Target.
    @discardableResult
    func hasDeploymentTarget(_ deploymentTarget: DeploymentTarget, line: UInt = #line) -> Context {
      guard let ruleEntry = ruleEntry else { return self }
      XCTAssertEqual(ruleEntry.deploymentTarget,
                     deploymentTarget,
                     "\(ruleEntry) expected to have a DeploymentTarget of \(deploymentTarget)",
                     line: line)
      return self
    }

    /// Asserts that the contextual RuleEntry is a test target without a test_host.
    @discardableResult
    func doesNotHaveTestHost(line: UInt = #line) -> Context {
      guard let ruleEntry = ruleEntry else { return self }
      let hostLabelString = ruleEntry.attributes[.test_host] as? String
      XCTAssertNil(hostLabelString,
                   "\(ruleEntry) expected to not have a test host",
                   line: line)
      return self
    }

    /// Asserts that the contextual RuleEntry has an attribute with the given name and value.
    @discardableResult
    func hasIncludes(_ value: [String], line: UInt = #line) -> Context {
      guard let ruleEntry = ruleEntry else { return self }
      guard let includes = ruleEntry.includePaths else {
        XCTFail("\(ruleEntry) expected to have includes", line: line)
        return self
      }
      let paths = includes.map { (path, recursive) -> String in
        return path
      }
      XCTAssertEqual(paths, value, line: line)
      return self
    }

    /// Asserts that the contextual RuleEntry has an attribute with the given name and value.
    @discardableResult
    func hasDefines(_ value: [String], line: UInt = #line) -> Context {
      guard let ruleEntry = ruleEntry else { return self }
      guard let defines = ruleEntry.defines else {
        XCTFail("\(ruleEntry) expected to have defines", line: line)
        return self
      }
      XCTAssertEqual(defines, value, line: line)
      return self
    }

    /// Asserts that the contextual RuleEntry has an attribute with the given name and value.
    @discardableResult
    func hasAttribute<T>(_ attribute: RuleEntry.Attribute, value: T, line: UInt = #line) -> Context where T: Equatable {
      guard let ruleEntry = ruleEntry else { return self }
      if let attributeValue = ruleEntry.attributes[attribute] as? T {
        XCTAssertEqual(attributeValue, value, line: line)
      } else if let attributeValue = ruleEntry.attributes[attribute] {
        XCTFail("\(ruleEntry) expected to have an attribute named '\(attribute)' of type \(T.self) " +
                    "but it is of type \(type(of: attributeValue))",
                line: line)
      } else {
        XCTFail("\(ruleEntry) expected to have an attribute named '\(attribute)'", line: line)
      }
      return self
    }

    /// Asserts that the contextual RuleEntry has an attribute with the given name and value.
    func hasListAttribute(_ attribute: RuleEntry.Attribute,
                          containing: [String],
                          line: UInt = #line) -> Context {
      guard let ruleEntry = ruleEntry else { return self }
      if let attributeValue = ruleEntry.attributes[attribute] as? [String] {
        for item in containing {
          XCTAssert(attributeValue.contains(item), line: line)
        }
      } else if let attributeValue = ruleEntry.attributes[attribute] {
        XCTFail("\(ruleEntry) expected to have an attribute named '\(attribute)' of type " +
                    "[String] but it is of type \(type(of: attributeValue))",
                line: line)
      } else {
        XCTFail("\(ruleEntry) expected to have an attribute named '\(attribute)'", line: line)
      }
      return self
    }
  }
}
