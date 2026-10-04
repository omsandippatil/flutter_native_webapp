#!/usr/bin/env bash
set -u

if [ -n "$(git status --porcelain)" ]; then
  echo "Working tree is dirty. Commit or stash first."; exit 1
fi

git switch -c assets/rename 2>/dev/null || git switch assets/rename

echo "== 1. Delete unused and duplicate assets =="
git rm -rq --ignore-unmatch \
  assets/animations/tap_buddy_loader.html \
  assets/animations/tap_buddy_loader.mp4 \
  assets/animations/tap_buddy_loader.webm \
  assets/data/constants \
  assets/data/content \
  assets/data/district \
  assets/data/states \
  assets/data/courses/hi \
  assets/data/courses/kn \
  assets/data/courses/mr \
  assets/data/courses/pa \
  assets/icons \
  assets/images/celebration/success_celebrate_onboarding.png
rm -rf assets/data/content assets/data/constants assets/data/district assets/data/states assets/icons
git commit -qm "chore(assets): remove unused and duplicate assets" || true

echo "== 2. Create target folders =="
mkdir -p assets/logos assets/onboarding assets/class-screen \
         assets/home-screen assets/reveal assets/splash-screen \
         assets/error-screen-assets

echo "== 3. Move files with git mv =="
MOVES=(
  "assets/images/branding/gov_logo.png|assets/logos/gov-logo.png"
  "assets/images/branding/tap_logo.png|assets/logos/tap_logo.png"
  "assets/images/branding/tap_logo_alt.png|assets/logos/tap-otherLogo.png"
  "assets/images/onboarding/tap_bot.png|assets/onboarding/TAP-bot.png"
  "assets/images/onboarding/hello_welcome.png|assets/onboarding/hello_welcome.png"
  "assets/images/onboarding/skill_passport.png|assets/onboarding/Skill Passport.png"
  "assets/images/celebration/success_celebrate.png|assets/onboarding/sussess_celebrate.png"
  "assets/images/classroom/lets_begin.png|assets/class-screen/lets_begin.png"
  "assets/images/classroom/points_10.png|assets/class-screen/10Points.png"
  "assets/images/classroom/skill_passport_card.png|assets/class-screen/Skill Passport 1.png"
  "assets/images/classroom/tap_buddy_ai.png|assets/class-screen/tap_buddy_ai.png"
  "assets/images/classroom/won_champ.png|assets/class-screen/won-champ.png"
  "assets/images/classroom/you_won.png|assets/class-screen/you-won.png"
  "assets/images/home/home_page_img1.png|assets/home-screen/home_page_img1.png"
  "assets/images/home/home_page_img2.png|assets/home-screen/home_page_img2.png"
  "assets/images/reveal/1.webp|assets/reveal/1.webp"
  "assets/images/error/sad_girl_error.png|assets/error-screen-assets/sad_girl_error.png"
  "assets/animations/tap_buddy_loader.gif|assets/splash-screen/tap-buddy-loader.gif"
)
for pair in "${MOVES[@]}"; do
  src="${pair%%|*}"; dst="${pair##*|}"
  if [ -f "$src" ]; then
    git mv -f "$src" "$dst" && echo "moved: $src -> $dst"
  else
    echo "MISSING SOURCE: $src"
  fi
done
git commit -qm "refactor(assets): move images into feature folders" || true

echo "== 4. Rename course thumbnails folder =="
if [ -d assets/data/courses/thumbnails ]; then
  git mv assets/data/courses/thumbnails assets/data/courses/thumbnail
  git commit -qm "refactor(assets): rename thumbnails folder to thumbnail" || true
fi

echo "== 5. Rewrite Dart references =="
python3 - <<'PY'
import pathlib, re, sys

RENAMES = {
    "assets/images/branding/gov_logo.png": "assets/logos/gov-logo.png",
    "assets/images/branding/tap_logo.png": "assets/logos/tap_logo.png",
    "assets/images/branding/tap_logo_alt.png": "assets/logos/tap-otherLogo.png",
    "assets/logos/gov_logo.png": "assets/logos/gov-logo.png",
    "assets/logos/tap_logo_alt.png": "assets/logos/tap-otherLogo.png",
    "assets/images/onboarding/tap_bot.png": "assets/onboarding/TAP-bot.png",
    "assets/images/onboarding/skill_passport.png": "assets/onboarding/Skill Passport.png",
    "assets/images/celebration/success_celebrate.png": "assets/onboarding/sussess_celebrate.png",
    "assets/images/classroom/lets_begin.png": "assets/class-screen/lets_begin.png",
    "assets/images/classroom/points_10.png": "assets/class-screen/10Points.png",
    "assets/images/classroom/skill_passport_card.png": "assets/class-screen/Skill Passport 1.png",
    "assets/images/classroom/tap_buddy_ai.png": "assets/class-screen/tap_buddy_ai.png",
    "assets/images/classroom/won_champ.png": "assets/class-screen/won-champ.png",
    "assets/images/classroom/you_won.png": "assets/class-screen/you-won.png",
    "assets/images/home/home_page_img1.png": "assets/home-screen/home_page_img1.png",
    "assets/images/home/home_page_img2.png": "assets/home-screen/home_page_img2.png",
    "assets/images/reveal/1.webp": "assets/reveal/1.webp",
    "assets/images/error/sad_girl_error.png": "assets/error-screen-assets/sad_girl_error.png",
    "assets/animations/tap_buddy_loader.gif": "assets/splash-screen/tap-buddy-loader.gif",
    "assets/data/courses/thumbnails/": "assets/data/courses/thumbnail/",
    "assets/class-screen/Skill Passport 1.png": "assets/class-screen/Skill Passport 1.png",
    "assets/onboarding/Skill Passport.png": "assets/onboarding/Skill Passport.png",
    "assets/onboarding/sussess_celebrate.png": "assets/onboarding/sussess_celebrate.png",
    "assets/home-screen/sussess_celebrate.png": "assets/onboarding/sussess_celebrate.png",
    "assets/class-screen/won-champ.png": "assets/class-screen/won-champ.png",
    "assets/class-screen/you-won.png": "assets/class-screen/you-won.png",
    "assets/class-screen/10Points.png": "assets/class-screen/10Points.png",
    "assets/class-screen/Skill Passport 1.png": "assets/class-screen/Skill Passport 1.png",
    "assets/onboarding/TAP-bot.png": "assets/onboarding/TAP-bot.png",
    "assets/logos/tap-otherLogo.png": "assets/logos/tap-otherLogo.png",
}
RENAMES = {k: v for k, v in RENAMES.items() if k != v}

touched, missing = [], []
for path in pathlib.Path("lib").rglob("*.dart"):
    src = path.read_text(encoding="utf-8")
    out = src
    for old, new in RENAMES.items():
        for q in ("'", '"'):
            out = out.replace(f"{q}{old}{q}", f"{q}{new}{q}")
    if out != src:
        path.write_text(out, encoding="utf-8")
        touched.append(str(path))

for p in pathlib.Path("lib").rglob("*.dart"):
    for ref in re.findall(r"""['"](assets/[^'"]+)['"]""", p.read_text(encoding="utf-8")):
        if not pathlib.Path(ref).is_file() and not ref.endswith("/"):
            missing.append(f"{p}: {ref}")

print("Touched files:")
for t in touched: print("  ", t)
print("Still-missing references:")
for m in sorted(set(missing)): print("  ", m)
sys.exit(1 if missing else 0)
PY
REF_STATUS=$?
git add -A lib && git commit -qm "fix(assets): update image paths in dart code" || true

echo "== 6. Update pubspec.yaml assets =="
python3 - <<'PY'
import pathlib, re
p = pathlib.Path("pubspec.yaml")
s = p.read_text(encoding="utf-8")
folders = [
    "assets/logos/", "assets/onboarding/", "assets/class-screen/",
    "assets/home-screen/", "assets/reveal/", "assets/splash-screen/",
    "assets/error-screen-assets/", "assets/data/courses/",
    "assets/data/courses/thumbnail/", "assets/flows/",
    "assets/flows/en/activity/", "assets/flows/en/onboarding/",
]
block = "  assets:\n" + "".join(f"    - {f}\n" for f in folders)
s2, n = re.subn(r"^  assets:\n(    - .*\n)+", block, s, flags=re.M)
if n == 0:
    s2 = s.replace("flutter:\n", "flutter:\n" + block, 1)
p.write_text(s2, encoding="utf-8")
print("pubspec.yaml updated")
PY
git add pubspec.yaml && git commit -qm "chore(assets): update pubspec asset folders" || true

echo "== 7. Verify =="
grep -rhoE "'assets/[^']+'" lib | tr -d "'" | sort -u | while read -r p; do
  [ -e "$p" ] || echo "MISSING: $p"
done
flutter clean >/dev/null 2>&1 && flutter pub get >/dev/null 2>&1 && flutter analyze

echo "Done. Review with: git log --oneline -6 && git diff main --stat"