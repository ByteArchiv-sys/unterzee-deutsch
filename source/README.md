# Review source for release 0.99.0

`archive-root` mirrors the project-specific scripts and patch manifests from
`Unterzee-Deutsch-0.99.0-Windows.zip` for security and moderation review.

The directory intentionally excludes:

- original or patched Sunless Sea DLLs and resources;
- translated addon JSON data, which remains in the release archive as the mod
  content;
- the third-party `Mono.Cecil.dll` binary, whose upstream source is available
  at <https://github.com/jbevain/cecil>.

The source files here are review copies, not a separate installer download.
Users should obtain the complete tested package from the project release.
Hashes and a description of every file-changing operation are in
[`../SECURITY-AND-VERIFICATION.md`](../SECURITY-AND-VERIFICATION.md).
