# mfg-dist

Installers for mfg, a ComputerCraft: Tweaked factory system. Each is one file,
built from the source repository by `tools/publish.sh`; do not edit them here.

On the controller computer:

    wget run https://raw.githubusercontent.com/kreutzerrudy/mfg-dist/main/install.lua
    reboot

On an HMI computer (one minted before a fix, which has no other way to get it yet):

    wget run https://raw.githubusercontent.com/kreutzerrudy/mfg-dist/main/install-hmi.lua
    reboot

Each installs the whole role, keeping `/net`, `/mfg/state` and `/boot/signer`, so
a node keeps its identity and enrolment. Every other node is minted from the
controller. Re-run to update; GitHub's raw cache can serve the previous build for
about five minutes after a push.

The commit message names the source build (`mfg-<sha> netstack-<sha>`).
Third-party code: see NOTICE.
