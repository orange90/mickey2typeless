# Release checklist

1. Update `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.yml`.
2. Move relevant entries from `Unreleased` in `CHANGELOG.md` to the release version and date.
3. Run `./scripts/check_localizations.sh` and the full test suite.
4. Complete the real-device checks in `README.md`.
5. Verify the working tree contains no credentials or private receiver data.
6. Set `DEVELOPMENT_TEAM` and `NOTARY_PROFILE`, then run `./scripts/package_release.sh`.
7. Verify the DMG on a clean Mac, including both interface languages and a fresh permission flow.
8. Create a signed `vX.Y.Z` tag and a GitHub Release; attach the DMG and `.sha256` file.
9. Confirm GitHub Actions passes on the tag/commit and publish the release notes from `CHANGELOG.md`.
