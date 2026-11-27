# Release Process

Releases are cut directly on `main` and follow [Semantic Versioning](https://semver.org/):

- **MAJOR**: breaking change for parent repositories (removed/renamed targets or
  variables, changed S3 path or stamp conventions, changed defaults that alter outputs)
- **MINOR**: new targets, variables, pipelines or helpers; backwards-compatible
- **PATCH**: bug fixes only

Rule: the release notes are written and committed **before** tagging, so the tag,
the repository and the GitHub release describe the same snapshot.

Use GNU Make 4+ (`gmake` on macOS). Below, `X.Y.Z` is the new version and `PREV`
the last tag (`git describe --tags --abbrev=0`).

## 1. Prepare

```bash
git switch main && git pull
git log PREV..HEAD --oneline              # what goes into the release
```

- Decide the version. Check the `[Unreleased]` section of `CHANGELOG.md` for
  anything that breaks parent repositories; if so, it is a MAJOR release.
- Move `[Unreleased]` in `CHANGELOG.md` to `## [X.Y.Z] - YYYY-MM-DD` and leave an
  empty `[Unreleased]` section above it.
- Set `version = "X.Y.Z"` in `lib/pyproject.toml`.
- Write `RELEASE_NOTES_vX.Y.Z.md`: a short overview, then the changelog content
  regrouped for readers, plus a **Breaking changes / Migration** section that
  tells parent repositories exactly what to change (omit it if there is nothing).

## 2. Test

```bash
gmake update-pip-requirements-file        # refresh requirements.txt from Pipfile
.venv/bin/python -m pytest -q tests       # needs pytest in the venv (uv pip install pytest)
```

Then check a fresh install in a throwaway clone of the branch:

```bash
D=$(mktemp -d) && git clone -q . "$D" && cd "$D"
gmake setup-venv-uv && gmake check-python-env && gmake help
```

If credentials are available, also run `gmake test-aws` and a small
`gmake newspaper NEWSPAPER=<small-title>` in a parent repository.

Note: `requirements.txt` pins `impresso-cookbook` to the `main` commit that existed
when it was regenerated, i.e. the commit *before* the release commit. That is
expected; parent repositories should pin the cookbook by tag (see step 4).

## 3. Commit, tag, publish

```bash
git add CHANGELOG.md lib/pyproject.toml requirements.txt RELEASE_NOTES_vX.Y.Z.md
git commit -m "chore(release): vX.Y.Z"
git push

git tag -a vX.Y.Z -m "Release vX.Y.Z: <one-line summary>"
git push origin vX.Y.Z

gh release create vX.Y.Z --title "vX.Y.Z: <one-line summary>" \
  --notes-file RELEASE_NOTES_vX.Y.Z.md
```

Use the same descriptive title for the tag and the GitHub release (not
"April release"). To fix notes afterwards, commit the corrected file to `main` and
run `gh release edit vX.Y.Z --notes-file RELEASE_NOTES_vX.Y.Z.md`; never move a tag.

## 4. Update parent repositories

Most users consume the cookbook as a git submodule, so a release is only done once
they can pick it up:

```bash
# in each parent repository
git -C cookbook fetch --tags && git -C cookbook checkout vX.Y.Z
git add cookbook && git commit -m "chore: bump cookbook to vX.Y.Z"
```

Parent repositories that install the Python package pin it by tag:
`impresso-cookbook = {git = "https://github.com/impresso/impresso-make-cookbook.git", ref = "vX.Y.Z", subdirectory = "lib"}`.

Tell the maintainers of the parent repositories about the release, and point
them to the migration section if there is one.

## Hotfix (PATCH) releases

Fix on `main` as usual, then follow steps 1–4 with a PATCH version and short
release notes. If `main` already contains unreleased features that must not ship,
branch from the tag instead (`git switch -c hotfix/X.Y.Z vPREV`), release from that
branch the same way (release notes committed before tagging), then merge it back
into `main`.
