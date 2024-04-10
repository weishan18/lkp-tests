#!/bin/bash

. $LKP_SRC/lib/debug.sh
. $LKP_SRC/lib/env.sh
. $LKP_SRC/lib/reproduce-log.sh

prepare_tests()
{
	cd $linux_selftests_dir/tools/testing/selftests || die

	prepare_test_env || die "prepare test env failed"

	prepare_for_selftest

	[ -n "$selftest_mfs" ] || die "empty selftest_mfs"
}

run_tests()
{
	local selftest_mfs=$@

	# kselftest introduced runner.sh since kernel commit 42d46e57ec97 "selftests: Extract single-test shell logic from lib.mk"
	[[ -e kselftest/runner.sh ]] && log_cmd sed -i 's/default_timeout=45/default_timeout=300/' kselftest/runner.sh

	for mf in $selftest_mfs; do
		local group=${mf%/Makefile}

		check_test_group_kconfig $group

		(
		fixup_test_group $group || die "fixup_$group failed"

		if grep -E -q -m 1 "^TARGETS \+?=  ?$group" Makefile; then
			log_cmd make -j${nr_cpu} -C $group 2>&1
		else
			log_cmd make -j${nr_cpu} TARGETS=$group 2>&1
		fi

		# vmalloc performance and stress, can not use 'make run_tests' to run
		if [[ $test =~ ^vmalloc\-(performance|stress)$ ]]; then
			log_cmd mm/test_vmalloc.sh ${test##vmalloc-} 2>&1
			log_cmd dmesg | grep -E '(Summary|All test took)' 2>&1
		elif [[ $test =~ ^protection_keys ]]; then
			echo "# selftests: mm: $test"
			log_cmd mm/$test 2>&1
		elif [[ $group = resctrl ]]; then
			log_cmd resctrl/resctrl_tests 2>&1
		elif [[ $group = bpf ]]; then
			# Order correspond to 'make run_tests' order
			# TEST_GEN_PROGS = test_verifier test_tag test_maps test_lru_map test_lpm_map test_progs \
			# 		test_verifier_log test_dev_cgroup \
			# 		test_sock test_sockmap get_cgroup_id_user \
			# 		test_cgroup_storage \
			# 		test_tcpnotify_user test_sysctl \
			# 		test_progs-no_alu32

			# remove test_progs and test_progs-no_alu32 from Makefile and run them separately
			if grep -q "test_progs-no_alu32 \\\\" bpf/Makefile; then
				sed -i 's/test_progs //' bpf/Makefile
				sed -i 's/test_progs-no_alu32 //' bpf/Makefile
			else
				sed -i 's/test_lpm_map test_progs //' bpf/Makefile
				sed -i 's/test_progs-no_alu32/test_lpm_map/' bpf/Makefile
			fi

			log_cmd make quicktest=1 run_tests -C $group 2>&1

			if [[ -f bpf/test_progs && -f bpf/test_progs-no_alu32 ]]; then
				cd bpf
				echo "# selftests: bpf: test_progs"
				log_cmd ./test_progs -b sk_assign -b xdp_bonding -b get_branch_snapshot -b perf_branches -b perf_event_stackmap -b snprintf_btf
				log_cmd ./test_progs -a get_branch_snapshot -a perf_branches -a perf_event_stackmap -a snprintf_btf
				echo "# selftests: bpf: test_progs-no_alu32"
				log_cmd ./test_progs-no_alu32 -b sk_assign -b xdp_bonding -b get_branch_snapshot -b perf_branches -b perf_event_stackmap -b snprintf_btf
				log_cmd ./test_progs-no_alu32 -a perf_branches -a perf_event_stackmap -a snprintf_btf
				cd ..
			else
				echo "build bpf/test_progs or bpf/test_progs-no_alu32 failed" >&2
			fi
		elif [[ $category = "functional" ]]; then
			log_cmd make quicktest=1 run_tests -C $group 2>&1
		else
			log_cmd make run_tests -C $group 2>&1
		fi

		cleanup_test_group $group
		)
	done
}
