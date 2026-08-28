#!/bin/bash -e

cd "$TARGET_DIR"

rm -rfv sha256sum*

if [ "$RK_DEBIAN_USER" != linaro ]; then
	message "Changing default user to $RK_DEBIAN_USER..."

	if [ ! -d home/$RK_DEBIAN_USER ]; then
		mv -v home/linaro home/$RK_DEBIAN_USER || true
	fi
	grep -rwl "linaro" rockchip-test/ etc/ boot/ 2>/dev/null | \
		xargs sed -i "s/\<linaro\>/$RK_DEBIAN_USER/g" 2>/dev/null || true
fi

if [ "$RK_DEBIAN_PASSWORD" != linaro ]; then
	message "Changing default user's password..."
	echo "$RK_DEBIAN_USER:$RK_DEBIAN_PASSWORD" | chroot . chpasswd -m || true
fi

if ! [ "$RK_DEBIAN_UNIFIED_IMAGE" ]; then
	case "$RK_CHIP_FAMILY-$RK_CHIP" in
		rk312*|rk3036-*)
			LIBMALI=utgard-400
			CAMERA_ENGINE=rkisp
			;;
		*-rk3288)
			LIBMALI=midgard-t76x-*-r0p0
			CAMERA_ENGINE=rkisp
			;;
		*-rk3288w)
			LIBMALI=midgard-t76x-*-r1p0
			CAMERA_ENGINE=rkisp
			;;
		rk3399*)
			LIBMALI=midgard-t86x
			CAMERA_ENGINE=rkisp
			;;
		px30-*|rk3326-*|rk3328-*|rk3528-*)
			LIBMALI=bifrost-g31
			CAMERA_ENGINE=rkisp
			;;
		rk3566_rk3568-*)
			LIBMALI=bifrost-g52
			CAMERA_ENGINE=rkaiq_rk3568
			RKNPU=1
			;;
		rk3562-*)
			LIBMALI=bifrost-g52
			CAMERA_ENGINE=rkaiq_rk3562
			RKNPU=1
			;;
		rk3576-*)
			LIBMALI=bifrost-g52
			CAMERA_ENGINE=rkaiq_rk3576
			RKNPU=1
			;;
		rk3588-*)
			LIBMALI=valhall-g610
			CAMERA_ENGINE=rkaiq_rk3588
			RKNPU=1
			;;
		rv1126b-*)
			RKNPU=1
			;;
	esac

	if [ "$RKNPU" ]; then
		message "Extracting NPU2 tarball..."
		tar xvf rknpu2.tar || true
	fi

	PKGS=
	if [ "$CAMERA_ENGINE" ]; then
		PKGS="$(ls ./* | grep "camera_engine_${CAMERA_ENGINE}_.*.deb")"
	fi
	if [ "$LIBMALI" ]; then
		PKGS="$PKGS $(ls ./* | grep "libmali-$LIBMALI-.*.deb")"
	fi
	if [ "$PKGS" ]; then
		message "Installing chip related packages..."

		mkdir -pv var/cache/apt/archives/partial
		PKGS="$(echo $PKGS | xargs)"
		chroot . bash -c "apt install -fy --allow-downgrades $PKGS" \
			|| true

		"$RK_TOOLS_DIR/x86_64/ldconfig" -r "$TARGET_DIR/" || true
	fi

	rm -rfv *.deb *.tar
	touch usr/local/first_boot_flag
fi
