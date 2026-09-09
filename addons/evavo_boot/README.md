# EVAVO Boot Package

Canonical source: `EVAVO-STUDIO/evavo-game-runtime/addons/evavo_boot`.

This folder is the reusable publisher-ident and project boot package for EVAVO Godot games. Game repositories receive it through `EVAVO-STUDIO/GodotGameFoundationKit` sync tooling and must not fork or hand-edit the vendored copy. In an individual game, this directory is a generated/vendor copy of the canonical package.

## Integration

A migrated game uses:

```ini
[application]
run/main_scene="res://addons/evavo_boot/evavo_boot.tscn"
boot_splash/show_image=false
boot_splash/image=""
boot_splash/bg_color=Color(0.066, 0.071, 0.078, 1)
boot_splash/minimum_display_time=0

[evavo]
boot/game_main_scene="res://path/to/the/games/real/main_scene.tscn"
boot/splash_mode="auto"
boot/preload_game_scene=true
```

The dark native bridge prevents a default engine-logo splash before EVAVO. The animated ident then owns only the studio boot phase. The configured game scene still owns title/menu/game startup.

## Developer and coding-agent use

Use the launch path that matches the test:

- F6 / scene-specific run: bypasses this entrypoint naturally and is preferred for focused mechanics/UI/scene checks.
- `--evavo-skip-splash`: explicit quick project check.
- `EVAVO_AGENT_QUICK_TEST=1`: explicit ChatGPT/Codex/Claude-style agent quick check.
- `EVAVO_QUICK_TEST=1` or `EVAVO_DEV_TEST=1`: other automated development checks.
- `CI=1` / `GITHUB_ACTIONS=true`: bypass in `auto` mode.
- `--evavo-full-boot`: force the complete graphical publisher boot when checking startup/release/platform/audio/animation behavior.

`EVAVO_SPLASH_MODE=auto|full|skip`, `--evavo-splash=...` and `--evavo-splash-mode=...` are also supported.

Headless runs always bypass the visual phase because no display is available. Use a non-headless `--evavo-full-boot` run for actual visual/audio release validation.

Do not remove, comment out or locally fork this package to speed up testing. Do not hand-edit `evavo-boot.lock.json`. Shared changes belong in the canonical runtime and are propagated by the Foundation Kit.

## One-shot behavior

The publisher ident is process-start presentation only. Project boot records `evavo/boot/ident_completed_for_process`, legacy runtime splash paths honor that marker, and the runtime shell prevents `splash` from becoming a later navigation destination.

The configured game main scene is threaded-preloaded while the ident runs. A slow game load may continue on a minimal loading surface, but must not stretch the publisher ident past its watchdog.

## Platforms

The same responsive package is used for Windows/macOS/Linux and Steam, iOS/iPadOS, and Android phones/tablets. It uses Godot Control layout, standard AudioStreamPlayer nodes, width-and-height-aware sizing, and keyboard/mouse/controller/touch skip input. It has no platform SDK or network dependency.

OS-required mobile launch screens are static dark bridge surfaces only. They must not duplicate the animated EVAVO publisher ident.

## Source and rollout integrity

A generated game integration is valid only when its vendored package is an exact file/hash match for the pinned canonical runtime commit and its `evavo-boot.lock.json` records the same source commit and package fingerprint.

The default Foundation Kit bootstrap safely synchronizes clean `main`, validates and pins the canonical runtime commit, propagates it, commits/pushes eligible game integrations and re-audits. Dirty, wrong-branch, ahead/diverged, missing-scene or lock/package-drift states fail closed; destructive Git history repair is not part of the rollout.
