# Copyright 1999-2011 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/www-client/opera/Attic/opera-11.10.2092.ebuild,v 1.3 2011/05/03 19:35:45 jer dead $

EAPI="3"

inherit eutils fdo-mime gnome2-utils multilib pax-utils versionator

DESCRIPTION="A fast and secure web browser and Internet suite"
HOMEPAGE="http://www.opera.com/"

SLOT="0"
LICENSE="OPERA-11 LGPL-2 LGPL-3"
KEYWORDS="~amd64 ~x86 ~x86-fbsd"
IUSE="elibc_FreeBSD gtk kde +gstreamer"

RESTRICT="test"

# http://snapshot.opera.com/unix/minor_11.01-1160/opera-11.01-1160.i386.linux.tar.xz
O_V="$(get_version_component_range 1-2)" # Major version, i.e. 11.00
O_B="$(get_version_component_range 3)"   # Build version, i.e. 1156

O_D="${O_V/.}"
O_P="${PN}-${O_V}-${O_B}"
O_U="mirror://opera/"

SRC_URI="
	amd64? ( ${O_U}linux/${O_D}/${O_P}.x86_64.linux.tar.xz )
	x86? ( ${O_U}linux/${O_D}/${O_P}.i386.linux.tar.xz )
	x86-fbsd? ( ${O_U}unix/${O_D}/${O_P}.i386.freebsd.tar.xz )
"

OPREFIX="/usr/$(get_libdir)"

QA_DT_HASH="${OPREFIX}/${PN}/.*"
QA_PRESTRIPPED="${OPREFIX}/${PN}/.*"

O_LINGUAS="
	af az be bg cs da de el en-GB es-ES es-LA et fi fr fr-CA fy gd hi hr hu id
	it ja ka ko lt me mk ms nb nl nn pl pt pt-BR ro ru sk sr sv ta te th tl tr
	uk uz vi zh-CN zh-TW
"

for O_LINGUA in ${O_LINGUAS}; do
	IUSE="${IUSE} linguas_${O_LINGUA/-/_}"
done

DEPEND="
	>=sys-apps/sed-4
	app-arch/xz-utils
"
GTKRDEPEND="
	dev-libs/atk
	dev-libs/glib:2
	x11-libs/cairo
	x11-libs/gdk-pixbuf
	x11-libs/gtk+:2
	x11-libs/pango
	x11-libs/pixman
"
KDERDEPEND="
	kde-base/kdelibs
	x11-libs/qt-core
	x11-libs/qt-gui
"
GSTRDEPEND="
	dev-libs/glib
	dev-libs/libxml2
	media-plugins/gst-plugins-meta
	media-libs/gstreamer
"
RDEPEND="
	media-libs/fontconfig
	media-libs/freetype
	sys-apps/util-linux
	sys-libs/zlib
	virtual/opengl
	x11-libs/libICE
	x11-libs/libSM
	x11-libs/libX11
	x11-libs/libXext
	x11-libs/libXft
	x11-libs/libXrender
	gtk? ( ${GTKRDEPEND} )
	kde? ( ${KDERDEPEND} )
	gstreamer? ( ${GSTRDEPEND} )
"

pkg_setup() {
	echo -e \
		" ${GOOD}****************************************************${NORMAL}"
	elog "If you seek support, please file a bug report at"
	elog "https://bugs.gentoo.org and post the output of"
	elog " \`emerge --info =${CATEGORY}/${P}'"
	echo -e \
		" ${GOOD}****************************************************${NORMAL}"
}

src_unpack() {
	unpack ${A}
	mv -v ${PN}* "${S}" || die
}

src_prepare() {
	# Remove unwanted linguas
	LNGDIR="share/${PN}/locale"
	einfo "Keeping these locales (linguas): ${LINGUAS}."
	for LINGUA in ${O_LINGUAS}; do
		if ! use linguas_${LINGUA/-/_}; then
			LINGUA=$(find "${LNGDIR}" -maxdepth 1 -type d -iname ${LINGUA/_/-})
			rm -r "${LINGUA}"
		fi
	done

	# Remove doc directory but keep the LICENSE under another name (bug #315473)
	mv share/doc/opera/LICENSE share/opera/defaults/license.txt
	rm -rf share/doc
	for locale in share/opera/locale/*; do
		rm -f "${locale}/license.txt"
		ln -sn /usr/share/opera/defaults/license.txt "${locale}/license.txt" \
			|| die "ln -sn license.txt"
	done

	# Remove package directory
	rm -rf share/opera/package

	# Leave libopera*.so only if the user chooses
	if ! use gtk; then
		rm lib/opera/liboperagtk.so || die "rm liboperagtk.so failed"
	fi
	if ! use kde; then
		rm lib/opera/liboperakde4.so || die "rm liboperakde4.so failed"
	fi

	# Unzip the man pages before sedding
	gunzip share/man/man1/* || die "gunzip failed"

	# Replace PREFIX and SUFFIX in various files
	sed -i \
		-e "s:@@{PREFIX}:/usr:g" \
		-e "s:@@{SUFFIX}::g" \
		-e "s:@@{_SUFFIX}::g" \
		-e "s:@@{USUFFIX}::g" \
		share/mime/packages/opera-widget.xml \
		share/man/man1/* \
		share/applications/opera-browser.desktop \
		share/applications/opera-widget-manager.desktop \
		|| die "sed failed"

	# Create /usr/bin/opera wrapper
	echo '#!/bin/sh' > opera
	echo 'export OPERA_DIR=/usr/share/opera' >> opera
	echo 'exec '"${OPREFIX}"'/opera/opera "$@"' >> opera

	# Fix libdir in defaults/pluginpath.ini
	sed -i \
		share/opera/defaults/pluginpath.ini \
		-e "s|/usr/lib32|${OPREFIX}|g" \
		-e '/netscape/{s|[0-1]|2|g}' \
		|| die "sed pluginpath.ini failed"

	# Change libz.so.3 to libz.so.1 for gentoo/freebsd
	if use elibc_FreeBSD; then
		scanelf -qR -N libz.so.3 -F "#N" lib/${PN}/ | \
		while read i; do
			if [[ $(strings "$i" | fgrep -c libz.so.3) -ne 1 ]];
			then
				export SANITY_CHECK_LIBZ_FAILED=1
				break
			fi
			sed -i \
				"$i" \
				-e 's/libz\.so\.3/libz.so.1/g'
		done
		[[ "$SANITY_CHECK_LIBZ_FAILED" = "1" ]] \
			&& die "failed to change libz.so.3 to libz.so.1"
	fi
}

src_install() {
	# We install into usr instead of opt as Opera does not support the latter
	dodir /usr
	mv lib/  "${D}/${OPREFIX}" || die "mv lib/ failed"
	mv share/ "${D}/usr/" || die "mv share/ failed"

	# Install startup scripts
	dobin ${PN} ${PN}-widget-manager || die "dobin failed"

	# Stop revdep-rebuild from checking opera binaries
	dodir /etc/revdep-rebuild
	echo "SEARCH_DIRS_MASK=\"${OPREFIX}/${PN}\"" > "${D}"/etc/revdep-rebuild/90opera

	# Set PaX markings for hardened/PaX (bug #344267)
	pax-mark m \
		"${D}/${OPREFIX}/opera/opera" \
		"${D}/${OPREFIX}/opera/operaplugincleaner" \
		"${D}/${OPREFIX}/opera/operapluginwrapper"
}

pkg_preinst() {
	gnome2_icon_savelist
}

pkg_postinst() {
	elog "To change the UI language, choose [Tools] -> [Preferences], open the"
	elog "[General] tab, click on [Details...] then [Choose...] and point the"
	elog "file chooser at /usr/share/opera/locale/, then enter the"
	elog "directory for the language you want and [Open] the .lng file."

	if use elibc_FreeBSD; then
		elog
		elog "To improve shared memory usage please set:"
		elog "$ sysctl kern.ipc.shm_allow_removed=1"
	fi

	# Update desktop file database and gtk icon cache (bug #334993)
	gnome2_icon_cache_update
	fdo-mime_desktop_database_update
}

pkg_postrm() {
	# Update desktop file database and gtk icon cache (bug #334993)
	gnome2_icon_cache_update
	fdo-mime_desktop_database_update
}
