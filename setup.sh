#!/usr/bin/env bash
set -euo pipefail

TARGET="lib/screens/class/widgets/youtube_embed_web.dart"
BACKUP="${TARGET}.bak"
DRY_RUN=false
USE_LEGACY=false

for arg in "$@"; do
  if [ "$arg" = "--dry-run" ]; then
    DRY_RUN=true
  fi
  if [ "$arg" = "--legacy" ]; then
    USE_LEGACY=true
  fi
done

if [ ! -d "lib/screens/class/widgets" ]; then
  echo "Error: lib/screens/class/widgets not found. Run this script from the Flutter project root." >&2
  exit 1
fi

if [ -f "$TARGET" ]; then
  if [ -f "$BACKUP" ]; then
    echo "Warning: backup already exists at $BACKUP, not overwriting."
  else
    cp "$TARGET" "$BACKUP"
    echo "Backup created at $BACKUP"
  fi
else
  echo "No existing file at $TARGET, will create new."
fi

if [ "$USE_LEGACY" = true ]; then
  CONTENT='import '"'"'dart:html'"'"' as html;
import '"'"'dart:ui'"'"' as ui;
import '"'"'package:flutter/widgets.dart'"'"';

Widget buildYoutubeEmbed(String youtubeId) {
  final viewType = '"'"'youtube-iframe-$youtubeId'"'"';

  // ignore: undefined_prefixed_name
  ui.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
    final iframe = html.IFrameElement()
      ..src = '"'"'https://www.youtube.com/embed/$youtubeId'"'"'
      ..style.border = '"'"'none'"'"'
      ..style.width = '"'"'100%'"'"'
      ..style.height = '"'"'100%'"'"'
      ..allow = '"'"'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture'"'"'
      ..allowFullscreen = true;
    return iframe;
  });

  return HtmlElementView(viewType: viewType);
}
'
else
  CONTENT='import '"'"'dart:ui_web'"'"' as ui_web;
import '"'"'package:flutter/widgets.dart'"'"';
import '"'"'package:web/web.dart'"'"' as web;

Widget buildYoutubeEmbed(String youtubeId) {
  final viewType = '"'"'youtube-iframe-$youtubeId'"'"';

  ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
    final iframe = web.HTMLIFrameElement()
      ..src = '"'"'https://www.youtube.com/embed/$youtubeId'"'"'
      ..style.border = '"'"'none'"'"'
      ..style.width = '"'"'100%'"'"'
      ..style.height = '"'"'100%'"'"'
      ..allow = '"'"'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture'"'"'
      ..allowFullscreen = true;
    return iframe;
  });

  return HtmlElementView(viewType: viewType);
}
'
fi

if [ "$DRY_RUN" = true ]; then
  echo "Dry run, would write the following content to $TARGET:"
  echo "-----------------------------------------------------"
  echo "$CONTENT"
  echo "-----------------------------------------------------"
  if [ -f "$TARGET" ]; then
    TMP_FILE=$(mktemp)
    echo "$CONTENT" > "$TMP_FILE"
    echo "Diff against existing file:"
    diff -u "$TARGET" "$TMP_FILE" || true
    rm -f "$TMP_FILE"
  fi
  echo "Dry run complete, no changes applied."
  exit 0
fi

echo "$CONTENT" > "$TARGET" || {
  echo "Error: failed to write $TARGET." >&2
  if [ -f "$BACKUP" ]; then
    echo "Restoring backup." >&2
    cp "$BACKUP" "$TARGET"
  fi
  exit 1
}

echo "Wrote $TARGET"

if command -v flutter >/dev/null 2>&1; then
  echo "Running flutter analyze on $TARGET..."
  flutter analyze "$TARGET" || echo "flutter analyze reported issues, please review."
elif command -v dart >/dev/null 2>&1; then
  echo "Running dart analyze on $TARGET..."
  dart analyze "$TARGET" || echo "dart analyze reported issues, please review."
else
  echo "Warning: neither flutter nor dart CLI found on PATH, skipping analyze step."
fi

echo ""
echo "Summary:"
echo "  - Created/updated $TARGET with a web YouTube iframe embed"
echo "  - Use --legacy flag if your SDK lacks dart:ui_web or package:web"
echo "  - Run 'flutter pub get' if using the non-legacy version (needs package:web)"
echo "  - Then rerun 'flutter run -d chrome'"