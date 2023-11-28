#!/bin/bash

KBUILD_SUPPORTED_ARCHS="alpha
arc
arm
arm64
csky
hexagon
i386
loongarch
m68k
microblaze
mips
openrisc
parisc
parisc64
nios2
powerpc
powerpc64
riscv
s390
sh
sparc
sparc64
um
x86_64
xtensa
"

is_supported_compiler_option()
{
	local compiler_bin=$1
	local option=$2

	# $ gcc-7 -finvalid -Winvalid -xc /dev/null 2>&1
	# gcc-7: error: unrecognized command line option '-finvalid'; did you mean '-finline'?
	# gcc-7: error: unrecognized command line option '-Winvalid'; did you mean '-Winline'?
	#
	# $ gcc-7 -Werror=attribute-alias -xc /dev/null
	# cc1: error: -Werror=attribute-alias: no option -Wattribute-alias
	# $ gcc-7 -Wno-error=attribute-alias -xc /dev/null
	# cc1: error: -Werror=attribute-alias: no option -Wattribute-alias
	#
	# $ gcc-11 -Winvalid-option -xc /dev/null
	# gcc-11: error: unrecognized command-line option ‘-Winvalid-option’; did you mean ‘-Winvalid-pch’?
	#
	# $ clang-15 -Winvalid-option -finvalid -xc /dev/null
	# warning: unknown warning option '-Winvalid-option' [-Wunknown-warning-option]
	#
	# $ clang-15 -finvalid -xc /dev/null 2>&1
	# clang-15: error: unknown argument: '-fstrict-flex-arrays=3'

	# if an option is "-Wno-<diagnostic-type>", need to remove "no" and check the the remaining flag.
	#
	# $ gcc-7 -Wno-attribute-alias -xc /dev/null
	# /usr/bin/ld: /usr/lib/gcc/x86_64-linux-gnu/7/../../../x86_64-linux-gnu/Scrt1.o: in function `_start':
	# (.text+0x17): undefined reference to `main'
	# collect2: error: ld returned 1 exit status
	#
	# $ gcc-7 -Wattribute-alias -xc /dev/null
	# gcc-7: error: unrecognized command line option '-Wattribute-alias'; did you mean '-Wattributes'?

	# delete the "no-" prefix only for warning options
	echo $option | grep -q -e "Werror" -e "Wno-error" || option=${option//-Wno-/-W}

	$compiler_bin $option -xc /dev/null 2>&1 | grep -q \
		-e "unrecognized command.line option" \
		-e "no option" \
		-e "unknown warning option" \
		-e "unknown argument" \
		&& return 1

	return 0
}

add_kcflag()
{
	local flag=$1
	is_supported_compiler_option "$compiler_bin" "$flag" && kcflags="$kcflags $flag"
}

add_kbuild_kcflags()
{
	local kcflags_file=$1
	while read flag
	do
		add_kcflag "$flag"
	done < <(grep -v -e "^#" -e "^$" $kcflags_file)
}

is_llvm_equal_one_supported()
{
	# handle v2.6.X version, similar to is_clang_supported_arch function
	local kernel_version_major=${kernel_version_major%%.*}

	# LLVM=1 is introduced by below commit which merged into v5.7-rc1
	# irb(main):001:0> Git.open.gcommit('a0d1c951ef0').merged_by
	# => "v5.7-rc1"
	# commit a0d1c951ef08ed24f35129267e3595d86f57f5d3
	# Author: Masahiro Yamada <masahiroy@kernel.org>
	# Date:   Wed Apr 8 10:36:23 2020 +0900
	# 	kbuild: support LLVM=1 to switch the default tools to Clang/LLVM
	#
	# 	As Documentation/kbuild/llvm.rst implies, building the kernel with a
	# 	full set of LLVM tools gets very verbose and unwieldy.
	#
	# 	Provide a single switch LLVM=1 to use Clang and LLVM tools instead
	# 	of GCC and Binutils. You can pass it from the command line or as an
	# 	environment variable.
	[[ $kernel_version_major -lt 5 ]] && return 1

	[[ $kernel_version_major -eq 5 ]] && [[ $kernel_version_minor -lt 7 ]] && return 1

	if [[ $ARCH = "s390" ]]; then
		return 1
	elif [[ $ARCH =~ "powerpc" || $ARCH =~ "mips" || $ARCH =~ "riscv" ]]; then
		# https://www.kernel.org/doc/html/v5.18/kbuild/llvm.html
		# https://www.kernel.org/doc/html/v5.19/kbuild/llvm.html
		[[ $kernel_version_major -eq 5 ]] && [[ $kernel_version_minor -lt 18 ]] && return 1
	fi

	return 0
}
