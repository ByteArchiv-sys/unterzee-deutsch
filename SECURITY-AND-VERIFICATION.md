# Security and verification

This document describes the executable and file-changing parts of
Unterzee Deutsch 0.99.0 for independent review. The project-specific code is
PowerShell and CMD source; the project does not ship a project-specific EXE.

## Release identity

Release archive: `Unterzee-Deutsch-0.99.0-Windows.zip`

- Size: `2,142,866` bytes
- SHA-256: `26A2F0FC149EFD3EA7B85EF2C1D2DF15F2D64CC6D4754801118FEF8CD4A684BB`
- GitHub release: <https://github.com/ByteArchiv-sys/unterzee-deutsch/releases/tag/latest>
- Nexus Mods page: <https://www.nexusmods.com/sunlesssea/mods/70>

Matching SHA-256 values prove that two downloaded archives are byte-for-byte
identical. A hash proves identity, not safety; the readable sources and the
behaviour described below are provided for the actual security review.

## Public source mirror

The directory [`source/archive-root`](source/archive-root) mirrors the
project-specific CMD/PowerShell scripts and patch manifests contained in the
0.99.0 archive. No original or prepatched Sunless Sea DLL, resource archive or
other original game file is included in this repository.

The release also contains `Mono.Cecil.dll` 0.11.5. This is a third-party
open-source library, not a project-specific executable. Upstream source and
build information: <https://github.com/jbevain/cecil>. Its MIT notice is
retained in [`THIRD-PARTY-NOTICES.txt`](THIRD-PARTY-NOTICES.txt).

## Network and privacy behaviour

The installer, patchers and uninstaller:

- contain no download, upload, telemetry, advertising or automatic-update code;
- do not contact GitHub, Nexus Mods, Failbetter Games or any other server;
- do not create services, scheduled tasks, startup entries or user accounts;
- do not write registry values;
- do not read, copy or delete Sunless Sea save games.

For game discovery, `Install.ps1` reads the normal Steam and Windows uninstall
registry locations, Steam library configuration and common installation
folders. It may enumerate filesystem drive roots to check conventional Steam
or GOG paths. These checks are read-only.

The CMD launchers use `-ExecutionPolicy Bypass` for the single PowerShell
process that runs the local script. They do not change the machine or user
PowerShell execution policy.

## Filesystem behaviour

The installer can write only within these functional areas:

1. the Sunless Sea user addon directory under
   `%USERPROFILE%\AppData\LocalLow\Failbetter Games\Sunless Sea\addon`;
2. the mod state and backup directory under
   `%LOCALAPPDATA%\Unterzee-Deutsch-Mod`;
3. a discovered or explicitly selected Sunless Sea installation, and only for
   the optional UI/Core/resource translation after the supported original
   file hashes have matched.

The installer records the locally resolved paths and hashes in
`install-state.json` under the local state directory so that the uninstaller
can restore the matching backups. This record is created on the user's PC and
is not part of the distributed archive.

## Installation modes

### JSON-only addon mode

`1a - Nur Addon installieren (ohne Spieldateien).cmd` calls `Install.ps1`
with `-NoUI`. It copies ten JSON data files to the user addon directory. It
does not change a game DLL or `resources.assets`.

The JSON files are data interpreted by Sunless Sea. They do not contain or
launch Windows commands. They can affect the translated in-game content that
Sunless Sea loads from the addon.

### Full mode

`1 - Sprachmod installieren.cmd` calls the same installer without `-NoUI`.
In addition to the JSON addon, it can translate fixed interface strings in the
supported Windows/Steam game version 3.0.0.31:

- `Sunless.Game.dll` and `FailBetter.Core.dll`: `Patch-UI.ps1` uses Mono.Cecil
  to replace only the manifest-listed `ldstr` string operands. It verifies the
  complete source hash, method/instruction location and expected English text.
  Its equivalence check rejects changed opcodes, method/type structure,
  assembly references, exception boundaries and embedded resources. The
  complete output hash must match the manifest.
- `resources.assets`: `Patch-Resources.ps1` accepts only the exact supported
  source hash and length. It changes six declared ASCII text ranges at fixed,
  non-overlapping offsets without changing file length. The complete output
  hash must match the specification.

Before an original game file is replaced, the installer creates a backup and
verifies its SHA-256. Unknown game versions or unexpected files are left
unchanged. The uninstaller restores an original only when both the current
patched file and stored backup match their recorded hashes.

## Reviewer checklist

1. Download the GitHub release asset and calculate SHA-256.
2. Compare it with the hash above and the Nexus/VirusTotal file hash.
3. Confirm that the archive is an ordinary, non-password-protected ZIP with no
   nested archive.
4. Review the mirrored CMD and PowerShell files under `source/archive-root`.
5. Search the scripts for network APIs and verify that no network function is
   present.
6. Review `package-manifest.json`, `ui-manifest.json`,
   `core-manifest.json` and `resource-patch-spec.json` for the exact supported
   hashes and declared text replacements.
7. If desired, test first with the JSON-only mode in an isolated Windows user
   profile, then test full install and uninstall against an unmodified Steam
   copy of Sunless Sea: Zubmariner 3.0.0.31.

## Script hashes in release 0.99.0

| Archive path | SHA-256 |
|---|---|
| `Install.ps1` | `FFB7A15A2DB3CC9BAA08E8230F2472DA67E32240D16E613961996A190A218BDF` |
| `Uninstall.ps1` | `EB2EF288FD2DCA9301F71E7611E06CF65B422D91D9A55BA42994055835248099` |
| `Install.cmd` | `C0FE7569878DA1C113625AE7FE26FBF3983CBA9EC1F01FB96C3DD6661433C604` |
| `Uninstall.cmd` | `0C17EF294F1795DD5B0E1C7A250CC071A65AABA3502A1721F5A59C6D63436A01` |
| `1 - Sprachmod installieren.cmd` | `9320B66E616168C20E3759B09EB6A3E5E51990C7E14007EF33430D1EC947B671` |
| `1a - Nur Addon installieren (ohne Spieldateien).cmd` | `514F0F4BC1EE22B1720525087917C1538C1749C728F1A108A6F5724E08D09AFA` |
| `2 - Sprachmod entfernen.cmd` | `E5ADD25572E0DFFC797AC4C37213567863FBD671A1974D4D12940F688F148622` |
| `Patch-UI.ps1` | `E4ECD3D168647217F95ADB0073C48642A1D4D4043AD13E1E08BABF707CCD2FE7` |
| `Patch-Resources.ps1` | `BBB1A8B73215D7840DFC6BF7F3288B306AE44AB3A500E124F75579057AEA900A` |
| `package/package-manifest.json` | `A899F237ADAEEEE36979A973D99DF9F6E031EEF5DD05E6E67044A899A54FCD67` |
| `package/ui/Patch-UI.ps1` | `825B847115BD8AA5A5D030E8683E8A62D52F643D9B93A86A4C8ED4CA44D43E91` |
| `package/ui/ui-manifest.json` | `38CEC21F5CC230DC36015580F5B751569E2D6CCFAF46BB3F8F32D76533C5C1D6` |
| `package/core/core-manifest.json` | `C40D4F1C1A5903763226B0139F9921DE59B0D2A33DC5939F990CE26EB7FE9691` |
| `package/resources/Patch-Resources.ps1` | `1F1228417B39BF93EFD00C195B0312F4FD69BE4EFFAA9BA0CD34EF91B2950FFF` |
| `package/resources/resource-patch-spec.json` | `BFC6850726C0F73B8873C380E22E9467C3915A9507E51440458CB161F1689A44` |
| `Mono.Cecil.dll` | `C8D6A557BC7C827657D030FA5953B503C3143993B51F7700967145A7305309F4` |

Security reports should include the release version, affected file, observed
hash and a reproducible description. Do not include private paths, account
data or save games.
