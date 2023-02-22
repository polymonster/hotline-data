# hotline-data

This repository contains example data and tools for [hotline](https://github.com/polymonster/hotline). It is automatically cloned inside a hotline environement when running `cargo build`.

It bundles [pmbuild](https://github.com/polymonster/pmbuild) and [pmfx](https://github.com/polymonster/pmbuild) in the binary directory to build data and shaders.

And serves source data files in [src_data](https://github.com/polymonster/hotline/src) for use in hotline applications or plugins.

## Quick Commands

This repository is cloned automatically into a hotline application. You can run the following build commands to simplify the build steps and make sure plugins, data and binaries are in sync:

```text
// from in the hotline repository
cd hotline

// this will clone or update this repository and build the hotline lib and client
cargo build

// once you have that you can build just data for win32
./hotline-data/pmbuild.cmd win32-data

// or build client, data, hotline and plugins (debug)
./hotline-data/pmbuild.cmd win32-debug

// or build client, data, hotline and plugins (release)
./hotline-data/pmbuild.cmd win32-release

// launch hotline (release)
./hotline-data/pmbuild.cmd win32-release -run

// build code, data and launch (debug)
./hotline-data/pmbuild.cmd win32-release -all -run
```

## Customising

You can add you own build `profiles` and `tasks` by editing [config.jsn](https://github.com/polymonster/hotline/blob/master/config.jsn) in the hotline repository. It should be fairly self explanitory but the main [pmbuild](https://github.com/polymonster/pmbuild) repository has more documentation.
