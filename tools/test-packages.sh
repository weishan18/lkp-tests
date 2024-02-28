#!/bin/bash

[[ -n "$LKP_SRC" ]] || LKP_SRC=$(dirname $(dirname $(readlink -e -v $0)))

. $LKP_SRC/lib/install.sh
. $LKP_SRC/lib/detect-system.sh

export LKP_SRC

get_all_dependency_packages()
{
	local distro=$1
	local _system_version=$2

	local generic_packages="$(find $LKP_SRC -type f -name depends\* | xargs cat | grep -hv "^\s*#\|^\s*$" | sort | uniq)"
	parse_packages_arch

	[[ "$distro" != "debian" ]] && remove_packages_version && remove_packages_repository

	# many python2 pkgs are not available in debian 11 and higher version source anymore
	# do a general mapping from python-pkg to python3-pkg
	[[ "$distro-$_system_version" =~ debian-1[1-9] ]] && map_python2_to_python3

	# many python2 pkgs are not available in ubuntu 20.04 and higher version source anymore
	# do a general mapping from python-pkg to python3-pkg
	[[ "$distro-$_system_version" =~ ubuntu-2[0-9].* ]] && map_python2_to_python3

	adapt_packages | sort | uniq
}

detect_system
distro=$_system_name_lowercase
arch=$(get_system_arch)

echo "arch=$arch, distro=$distro, _system_version=$_system_version" 1>&2

packages=$(get_all_dependency_packages "$distro" "$_system_version")

echo "$LKP_SRC/distro/installer/$distro" 1>&2
$LKP_SRC/distro/installer/$distro $packages
