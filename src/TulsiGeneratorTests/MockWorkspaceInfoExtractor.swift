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

import Foundation
@testable import TulsiGenerator


class MockWorkspaceInfoExtractor: BazelWorkspaceInfoExtractorProtocol {

  var labelToRuleEntry = [BuildLabel: RuleEntry]()
  /// The set of labels passed to ruleEntriesForLabels that could not be found in the
  /// labelToRuleEntry dictionary.
  var invalidLabels = Set<BuildLabel>()

  var bazelURL = URL(fileURLWithPath: "")
  var bazelBinPath = "bazel-bin"
  var bazelExecutionRoot = "/private/var/tmp/_bazel_localhost/1234567890abcdef1234567890abcdef/execroot/workspace_dir"

  func extractRuleInfoFromProject(_ project: TulsiProject) -> [RuleInfo] {
    return []
  }

  func ruleEntriesForLabels(_ labels: [BuildLabel],
                            startupOptions: TulsiOption,
                            buildOptions: TulsiOption,
                            useAspectForTestSuitesOption: TulsiOption) throws -> RuleEntryMap {
    invalidLabels.removeAll(keepingCapacity: true)
    let ret = RuleEntryMap()
    for label in labels {
      guard let entry = labelToRuleEntry[label] else {
        invalidLabels.insert(label)
        continue
      }
      ret.insert(ruleEntry: entry)
    }
    return ret
  }

  func extractBuildfiles<T:Collection>(_ forTargets: T) -> Set<BuildLabel> where T.Iterator.Element == BuildLabel {
    return Set()
  }

  func logQueuedInfoMessages() {}

  func hasQueuedInfoMessages() -> Bool { return false }
}
