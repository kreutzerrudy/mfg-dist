# mfg-dist

Builds of mfg, a ComputerCraft: Tweaked factory system, made by `tools/publish.sh`
in the source repository; do not edit them here.

- `blobs/<sha256>`: every file of every role, named by its hash.
- `builds/<build>/<role>.manifest`: what each role's node carries in that build.
- `builds/latest`: the newest build.

Install or update a computer (it fetches only the files it does not already have,
checking each one's hash):

    wget run https://raw.githubusercontent.com/kreutzerrudy/mfg-dist/main/install.lua                 the controller
    wget run https://raw.githubusercontent.com/kreutzerrudy/mfg-dist/main/install.lua hmi             or station, turtle, builder
    reboot

(`install-hmi.lua` and the others are the same program with that role as the
default.) It keeps `/net`, `/mfg/state` and `/boot/signer`, so a node keeps its
identity and enrolment, and removes code the new build no longer ships.

Third-party code: see NOTICE.
