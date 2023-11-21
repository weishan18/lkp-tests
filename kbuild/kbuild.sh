#!/bin/bash

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
