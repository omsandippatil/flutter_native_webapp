#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-.}"
cd "$ROOT"

if [ ! -f "pubspec.yaml" ]; then
  echo "pubspec.yaml not found in $ROOT" >&2
  exit 1
fi

ASSET_LOADER="lib/data/local/asset_loader.dart"
if [ -f "$ASSET_LOADER" ]; then
  if ! grep -q "loadJsonAny" "$ASSET_LOADER"; then
    python3 - "$ASSET_LOADER" <<'EOF'
import sys
path = sys.argv[1]
with open(path) as f:
    content = f.read()

anchor = "  Future<String> loadRawString(String path) async {"
insertion = """  Future<dynamic> loadJsonAny(String path) async {
    try {
      final raw = await rootBundle.loadString(path);
      return jsonDecode(raw);
    } catch (e) {
      throw AssetLoadException(path, e);
    }
  }

"""
if anchor in content and "loadJsonAny" not in content:
    content = content.replace(anchor, insertion + anchor)

with open(path, 'w') as f:
    f.write(content)
EOF
  fi
fi

ONBOARDING_REPO="lib/data/repositories/onboarding_data_repository.dart"
if [ -f "$ONBOARDING_REPO" ]; then
  python3 - "$ONBOARDING_REPO" <<'EOF'
import re
import sys
path = sys.argv[1]
with open(path) as f:
    content = f.read()

content = content.replace(
    "      final json = await _assetLoader.loadJson(_statesAssetPath);\n"
    "      listRaw = (json is List) ? json : ((json as Map<String, dynamic>)['states'] as List<dynamic>? ?? <dynamic>[]);",
    "      final json = await _assetLoader.loadJsonAny(_statesAssetPath);\n"
    "      listRaw = (json is List) ? json : ((json as Map)['states'] as List<dynamic>? ?? <dynamic>[]);",
)
content = content.replace(
    "      final json = await _assetLoader.loadJson(_districtAssetPath(stateId));\n"
    "      listRaw = (json is List) ? json : ((json as Map<String, dynamic>)['districts'] as List<dynamic>? ?? <dynamic>[]);",
    "      final json = await _assetLoader.loadJsonAny(_districtAssetPath(stateId));\n"
    "      listRaw = (json is List) ? json : ((json as Map)['districts'] as List<dynamic>? ?? <dynamic>[]);",
)
content = content.replace(
    "      final json = await _assetLoader.loadJson(_languagesAssetPath);\n"
    "      listRaw = (json is List) ? json : ((json as Map<String, dynamic>)['languages'] as List<dynamic>? ?? <dynamic>[]);",
    "      final json = await _assetLoader.loadJsonAny(_languagesAssetPath);\n"
    "      listRaw = (json is List) ? json : ((json as Map)['languages'] as List<dynamic>? ?? <dynamic>[]);",
)

with open(path, 'w') as f:
    f.write(content)
EOF
fi

echo "Done."