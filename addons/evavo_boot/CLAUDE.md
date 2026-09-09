# Generated EVAVO Boot Package — Claude Rule

This directory is canonical only inside `EVAVO-STUDIO/evavo-game-runtime`.

Inside an individual game repository, `addons/evavo_boot` is generated/vendor state. Do not edit, fork, delete or locally patch it. Make shared changes in `EVAVO-STUDIO/evavo-game-runtime/addons/evavo_boot`, run the runtime validation gate, then propagate the exact validated commit with `EVAVO-STUDIO/GodotGameFoundationKit/tools/bootstrap_evavo_boot_portfolio.ps1`.

Use F6/scene-specific launch or `--evavo-skip-splash` / `EVAVO_AGENT_QUICK_TEST=1` for focused tests. Use `--evavo-full-boot` in a non-headless graphical run for startup/release/splash/audio validation.

Never bypass the contract by removing the boot entrypoint, hand-editing `evavo-boot.lock.json`, force-pushing or rewriting repository history.
