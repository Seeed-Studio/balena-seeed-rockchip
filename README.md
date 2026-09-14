## Clone/Initialize the repository

There are two ways of initializing this repository:
* Clone this repository with "git clone --recursive".

or

* Run "git clone" and then "git submodule update --init --recursive". This will
bring in all the needed dependencies.

## Build information

balenaOS currently only builds with cgroups v1. If your distribution defaults
to using cgroups v2, please boot with the following kernel command line
argument:
`systemd.unified_cgroup_hierarchy=0`

### Containerized build

* If you have a working docker installation, you can build in a containerized
  environment as follows:
  `./balena-yocto-scripts/build/balena-build.sh -d <device type> -s <shared directory>`

  Where:
    * Device type is one of the supported devices with a valid `<device type name>.coffee` description file.
    * Shared directory is the absolute path to the build folder

### Native build

To build all supported device types natively, please make sure your Linux
distribution is [supported](https://docs.yoctoproject.org/singleindex.html#supported-linux-distributions) by Yocto Project.

Additional host tools need to be installed for native builds to work.

* Run the barys build script:
  `./balena-yocto-scripts/build/barys`

* You can also run barys with the -h switch to inspect the available options

### Custom build using this repository

* Run the barys build script in dry run mode to setup an empty `build` directory
    `./balena-yocto-scripts/build/barys --remove-build --dry-run`

* Edit the `local.conf` in the `build/conf` directory

* Prepare the Wrynose build shell environment with the matching BitBake 2.18
  checkout
  `source layers/openembedded-core/oe-init-build-env build-wrynose layers/bitbake`

* Run bitbake (see message outputted when you sourced above for examples)

### Direct Yocto build

The barys flow above is the upstream default. This repository is also built
directly with the standard Yocto environment, which is the validated flow for
these machines (Wrynose uses the OE-Core + BitBake submodule layout; barys
selects it automatically through the layer's LAYERSERIES_COMPAT).

For each machine (`recomputer-rk3576-devkit` or `recomputer-rk3588-devkit`),
using rk3588 as the example:

```bash
# One-time per clone: initialize the pinned submodules
git submodule update --init --recursive

# First time only (creates build-recomputer-rk3588-devkit/conf from the
# layer template); re-run in every new shell afterwards:
export TEMPLATECONF=$PWD/layers/meta-balena-rockchip/conf/templates/default
MACHINE=recomputer-rk3588-devkit source layers/openembedded-core/oe-init-build-env \
    build-recomputer-rk3588-devkit layers/bitbake

# Build the flasher image (production by default)
MACHINE=recomputer-rk3588-devkit bitbake balena-image-flasher
```

Notes:

* TEMPLATECONF only matters when the build directory is first created; it is
  ignored once `conf/` exists.
* The build defaults to a production image. For a development (debug) image,
  either put `OS_DEVELOPMENT = "1"` in local.conf, or pass it per build:
  `bitbake -R /tmp/dev.conf balena-image-flasher` with
  `echo 'OS_DEVELOPMENT = "1"' > /tmp/dev.conf` (postread files override
  local.conf), or whitelist and export it:
  `export BB_ENV_PASSTHROUGH_ADDITIONS="$BB_ENV_PASSTHROUGH_ADDITIONS OS_DEVELOPMENT"`
  then prefix the build with `OS_DEVELOPMENT=1`.
* Useful switches: `-k` continues past task failures; `bitbake -C compile
  u-boot` forces a loader rebuild when only deploy artifacts are wanted.
* Artifacts land in
  `build-recomputer-rk3588-devkit/tmp/deploy/images/recomputer-rk3588-devkit/`:
  the flasher and runtime `*.balenaos-img` images and the OTA
  `*.docker` hostapp bundle are unversioned symlinks (use `cp -L` to
  materialize them), while `rkspi_loader.img` and `spl_loader_maskrom.bin`
  (maskrom flashing) are plain files.

### Build flags

* Consult layers/meta-balena/README.md for info on various build flags (setting
up serial console support for example) and build prerequisites. Build flags can
be set by using the build scripts (barys or balena-build) or by manually
modifying `local.conf`.

## Contributing

### Issues

For issues we use an aggregated github repository available [here](https://github.com/balena-os/balena/issues). When you create issue make sure you select the right labels.
For issues please use this section: https://github.com/balena-os/balena-rockpi/issues

### Pull requests

To contribute send github pull requests targeting this repository.

Please refer to: [Yocto Contribution Guidelines](https://wiki.yoctoproject.org/wiki/Contribution_Guidelines#General_Information) and try to use the commit log format as stated there. Example:
```
<component>: Short description

I'm going to explain here what my commit does in a way that history
would be useful.

Changelog-entry: User facing description of the issue
Signed-off-by: Joe Developer <joe.developer@example.com>
```

The header of each commit must not exceed 72 characters in length and must be in 1 line only.

The header and the subject of each commit must be separated by an empty line.

The subject of each commit must not exceed 72 characters per line and can be wrapped to several lines.

The subject and the footer of each commit must be separated by an empty line.

Every pull request must contain at least one commit annotated with the `Changelog-entry` footer. The messages contained in these footers will be used to automatically fill the changelog on every new version.

Also, every update to `meta-balena` should be separated into its own commit, if the body of that commit contains the following line `Updated meta-balena from X to Y` the generated changelog will include a button to show all the updates in `meta-balena` from the version after `X` to `Y`.

An example of a valid commit updating `meta-balena` is:

```
layers/meta-balena: Update to v2.73.0

Update meta-balena from 2.72.0 to 2.73.0

Changelog-entry: Update the meta-balena submodule from v2.72.0 to v2.73.0
```

Make sure you mention the issue addressed by a PR. See:
* https://help.github.com/articles/autolinked-references-and-urls/#issues-and-pull-requests
* https://help.github.com/articles/closing-issues-via-commit-messages/#closing-an-issue-in-a-different-repository
