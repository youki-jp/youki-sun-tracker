# Account experience preview

Date: 2026-09-27
Status: Prototype; authentication and payment are not implemented.

## Quick read

Created a standalone interactive HTML preview of the proposed account experience. It preserves the existing free feature scope and shows sign-in, account settings, lifetime Pro status, refresh cooldown, and terminal session expiry. Open the preview in a browser and use its scenario buttons; all actions are local simulations.

| Surface | Artifact |
| --- | --- |
| Interactive UI | [auth-experience-preview.html](../auth-experience-preview.html) |
| Architecture and implementation slices | [auth-and-request-protection-design.md](../auth-and-request-protection-design.md) |

## Details and verification

- The preview uses the current app's warm accent, dark surfaces, sky palette, and forecast structure. Forecast values are illustrative.
- Sign-in, sample exploration, account navigation, logout, deletion confirmation, and refresh controls operate locally. Pro represents a manual test grant; no checkout is included.
- A Node VM check passed JavaScript parsing, rendering of all five scenarios, and sign-in/settings/logout/sample/deletion interactions using a minimal DOM stub. This verifies control logic, not browser rendering.
- `git diff --check` passed. No browser was available through the connected computer-use tool, so visual layout, native dialog behavior, and the real-time countdown remain unverified in a browser.
- No application runtime, account provider, payment SDK, or deployed security configuration changed. Review the preview and confirm sign-in gating and Pro feature scope before implementation.
