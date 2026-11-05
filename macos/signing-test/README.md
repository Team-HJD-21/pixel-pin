# Fixed self-signing identity experiment

This is an opt-in experiment for the update-to-update Screen Recording permission problem. It does not change the stable/beta release workflows or their feeds, does not change the app's functionality, and does not claim Developer ID signing, notarization, or proven TCC permission retention.

The manual `Test fixed macOS signing identity` workflow authenticates the released v1.2.2 archive and repackages it as v1.2.3 and v1.2.4. Both use the same `com.teamhjd.pixelpin` identifier, one certificate created for this pair, and an explicit designated requirement that pins the leaf certificate fingerprint. The requirement does not depend on a user-installed trusted root and is not merely an identifier-only requirement. CI checks both apps' signatures, tests requirement compatibility in both directions, and confirms that the original ad-hoc app fails this new requirement.

The private identity is generated inside the ephemeral CI runner, used for both apps, and destroyed afterward. No private signing key is uploaded from a user's machine, stored in repository secrets, or included in logs, source, release files or artifacts. Only the ephemeral CI account temporarily trusts the public certificate to apply signatures. Public `certificate.pem` and the verification report are included for inspection. Each later workflow run gets a new identity; permanent signing-key custody must be settled separately after the device test succeeds.

Sparkle uses its existing update key, but these apps point exclusively to a dedicated `macos-signing-test-<run>-<attempt>-feed`. Later experiments cannot change an earlier test's update feed. Published prereleases use unique run IDs and are excluded from the stable website downloads. No native app compilation is required.

On your Mac, quit the existing app with Command-Q, install the **baseline v1.2.3** in Applications, register permission once for the changed identity, and confirm live sampling works. Use Check for Updates to install **v1.2.4**. Check sampling immediately and again after quitting and reopening, without deleting or re-granting the permission. Ensure automatic screen sampling is enabled so the system picker does not confound the test. CI verifies code identity, not the user's TCC database or permission behavior.

After the experiment, manually reinstall the official app from the website to return to its production feed. The test build numbers are intentionally separate; do not infer production update compatibility from these opt-in packages.
