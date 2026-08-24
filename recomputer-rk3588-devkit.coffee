deviceTypesCommon = require '@resin.io/device-types/common'
{ networkOptions, commonImg, instructions } = deviceTypesCommon

module.exports =
	version: 1
	slug: 'recomputer-rk3588-devkit'
	name: 'Seeed reComputer RK3588 DevKit'
	arch: 'aarch64'
	state: 'new'

	instructions: [
		instructions.ETCHER_SD
		instructions.EJECT_SD
		instructions.FLASHER_WARNING
		instructions.BOARD_REPOWER
	]

	gettingStartedLink:
		windows: 'https://www.balena.io/docs/learn/getting-started/recomputer-rk3588-devkit/nodejs/'
		osx: 'https://www.balena.io/docs/learn/getting-started/recomputer-rk3588-devkit/nodejs/'
		linux: 'https://www.balena.io/docs/learn/getting-started/recomputer-rk3588-devkit/nodejs/'

	supportsBlink: false

	options: [ networkOptions.group ]

	yocto:
		machine: 'recomputer-rk3588-devkit'
		image: 'balena-image-flasher'
		fstype: 'balenaos-img'
		version: 'yocto-scarthgap'
		deployArtifact: 'balena-image-flasher-recomputer-rk3588-devkit.balenaos-img'
		compressed: true

	configuration:
		config:
			partition: 3
			path: '/config.json'

	initialization: commonImg.initialization
