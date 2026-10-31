# Build and package notes

Unterzee Deutsch 0.99.0 contains no project-specific compiled executable.
Its project code consists of readable PowerShell and CMD files. The only
bundled third-party binary used by the patcher is Mono.Cecil 0.11.5.

## Package composition

The Windows release ZIP is assembled from:

- ten translated Sunless Sea addon JSON files;
- the CMD launchers and PowerShell installer/uninstaller;
- the PowerShell DLL and resource patchers;
- JSON manifests containing supported original hashes, expected output hashes
  and the declared text replacements;
- documentation and notices;
- `Mono.Cecil.dll` 0.11.5 with its MIT notice.

No Sunless Sea DLL, `resources.assets`, executable or other original game file
is copied into the release.

The review copy of every project-specific script and patch manifest is under
[`source/archive-root`](source/archive-root). The translation JSON data is in
the downloadable release archive because it is the mod content itself.

## Assembly procedure

1. Start with the reviewed addon JSON directory.
2. Calculate SHA-256 for every addon file and store the values in
   `package/package-manifest.json`.
3. Add the reviewed installer, uninstaller and launcher scripts.
4. Add `Patch-UI.ps1`, `Patch-Resources.ps1` and their manifests/specification.
5. Add Mono.Cecil 0.11.5 and retain `THIRD-PARTY-NOTICES.txt`.
6. Add the user documentation and compatibility notes.
7. Create an ordinary, non-password-protected ZIP without nested archives.
8. Reopen the ZIP, enumerate its contents and calculate the final SHA-256.
9. Test JSON-only installation, full installation, reinstall and uninstall
   against a clean supported game copy.

The published archive hash covers ZIP metadata as well as file bytes. Creating
a new ZIP from the same files may therefore produce a different archive hash
because entry timestamps or compression metadata differ. Reviewers should use
the individual source hashes in `SECURITY-AND-VERIFICATION.md` when comparing
mirrored source files with the release entries.

## Mono.Cecil provenance

Mono.Cecil is maintained separately at <https://github.com/jbevain/cecil>.
Its upstream repository contains the library source and build instructions.
Unterzee Deutsch does not modify Mono.Cecil and does not claim authorship of
it. The binary shipped in 0.99.0 has SHA-256:

`C8D6A557BC7C827657D030FA5953B503C3143993B51F7700967145A7305309F4`

## Validation boundary

The published scripts and manifests make the installer and patch process
reviewable. They do not reproduce Failbetter Games' original files and do not
grant rights to the game, its text or its assets. A lawful installed copy of
Sunless Sea is required for the optional local patch process.
