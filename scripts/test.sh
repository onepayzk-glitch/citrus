#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
MIN_MACOS="${MACOSX_DEPLOYMENT_TARGET:-15.0}"
mkdir -p .build/module-cache .build/test-sources
# Fail early on duplicate localization keys: a duplicate crashes at runtime.
python3 - <<'LINT'
import collections, pathlib, re, sys
text = pathlib.Path("NativeApp/Sources/Core/L10n.swift").read_text()
block = text[text.find("private static let zh"):]
keys = re.findall(r'^        "((?:[^"\\]|\\.)*)":', block, re.M)
dupes = sorted(k for k, v in collections.Counter(keys).items() if v > 1)
if dupes:
    sys.exit("duplicate L10n keys: " + ", ".join(dupes))
LINT

# Compile the app once; run each suite in a fresh process so state cannot leak.
python3 - <<'PY'
from pathlib import Path
suites = ['SatsumaTests', 'IntegrationTests', 'InteractionTests', 'ImageConversionTests', 'DocumentTests', 'BatchTests', 'ImageToolsTests', 'MediaIntegrationTests', 'OfficeEngineTests', 'DependencyTests', 'AppInfoTests', 'MatrixCoverageTests', 'PersonalizationTests']
for name in suites:
    source = Path('NativeApp/Tests', name + '.swift').read_text().replace('@main ', '').replace('@main\n', '')
    Path('.build/test-sources', name + '.swift').write_text(source)
driver = 'import Foundation\n@main struct AllTests {\n@MainActor static func main() async throws {\nswitch CommandLine.arguments.last {\n'
for name in suites:
    call = 'OpenTangerineTests.main()' if name == 'SatsumaTests' else 'try await ' + name + '.main()'
    driver += 'case "' + name + '": ' + call + '\n'
driver += 'default: fatalError("Choose a test suite")\n}\n}\n}\n'
Path('.build/test-sources/AllTests.swift').write_text(driver)
PY
find NativeApp/Sources .build/test-sources -name '*.swift' ! -path '*/Sources/App.swift' -print0 | xargs -0 xcrun swiftc -swift-version 5 -parse-as-library -target "$(uname -m)-apple-macosx$MIN_MACOS" -module-cache-path "$PWD/.build/module-cache" -o .build/all-tests
for suite in SatsumaTests IntegrationTests InteractionTests ImageConversionTests DocumentTests BatchTests ImageToolsTests MediaIntegrationTests OfficeEngineTests DependencyTests AppInfoTests MatrixCoverageTests PersonalizationTests; do
  echo "Running $suite"
  .build/all-tests "$suite"
done
