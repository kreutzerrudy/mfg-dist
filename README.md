# mfg-dist

Installers for mfg, a ComputerCraft: Tweaked factory system. Each is one file,
built from the source repository by `tools/publish.sh`; do not edit them here.

On the controller computer:

    wget run https://raw.githubusercontent.com/kreutzerrudy/mfg-dist/main/install.lua
    reboot

On any other node, its role's installer -- the controller no longer carries other
roles' files, so it cannot mint or update them:

    wget run https://raw.githubusercontent.com/kreutzerrudy/mfg-dist/main/install-hmi.lua
    wget run https://raw.githubusercontent.com/kreutzerrudy/mfg-dist/main/install-station.lua
    wget run https://raw.githubusercontent.com/kreutzerrudy/mfg-dist/main/install-turtle.lua        (a crafting turtle)
    wget run https://raw.githubusercontent.com/kreutzerrudy/mfg-dist/main/install-builder.lua
    reboot

Each installs the whole role, keeping `/net`, `/mfg/state` and `/boot/signer`, so
a node keeps its identity and enrolment. Re-run to update; GitHub's raw cache can
serve the previous build for about five minutes after a push.

The commit message names the source build (`mfg-<sha> netstack-<sha>`).
Third-party code: see NOTICE.
