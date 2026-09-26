# mfg-dist

The controller installer for mfg, a ComputerCraft: Tweaked factory system. One
file, built from the source repository by `tools/publish.sh`; do not edit it here.

On the controller computer:

    wget run https://raw.githubusercontent.com/kreutzerrudy/mfg-dist/main/install.lua
    reboot

It installs the whole controller, keeping `/net`, `/mfg/state` and `/boot/signer`.
Every other node is minted from the controller. Re-run it to update; GitHub's raw
cache can serve the previous build for about five minutes after a push.

The commit message names the source build (`mfg-<sha> netstack-<sha>`).
Third-party code: see NOTICE.
