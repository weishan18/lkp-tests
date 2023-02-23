#!/usr/bin/env ruby

LKP_SRC ||= ENV['LKP_SRC'] || File.dirname(__dir__)

require 'yaml'
require 'ostruct'
require "#{LKP_SRC}/lib/kernel_tag"
require "#{LKP_SRC}/lib/log"

def load_kernel_context
  context_file = File.expand_path '../context.yaml', kernel
  raise Job::ParamError, "context.yaml doesn't exist: #{context_file}" unless File.exist?(context_file)

  YAML.load(File.read(context_file))
end

def read_kernel_kconfigs
  kernel_kconfigs = File.expand_path '../.config', kernel
  raise Job::ParamError, ".config doesn't exist: #{kernel_kconfigs}" unless File.exist?(kernel_kconfigs)

  File.read kernel_kconfigs
end

def kernel_match_arch?(kernel_arch, expected_archs)
  expected_archs.include? kernel_arch
end

def kernel_match_kconfig?(kernel_kconfigs, expected_kernel_kconfig)
  case expected_kernel_kconfig
  when /^([A-Za-z0-9_]+)=n$/
    # add a-z for "FONT_8x16"
    config_name = $1
    config_name = "CONFIG_#{config_name}" unless config_name =~ /^CONFIG_/

    kernel_kconfigs =~ /# #{config_name} is not set/ || kernel_kconfigs !~ /^#{config_name}=[ym]$/
  when /^([A-Za-z0-9_]+=[ym])$/, /^([A-Za-z0-9_]+=[0-9]+)$/
    config_name = $1
    config_name = "CONFIG_#{config_name}" unless config_name =~ /^CONFIG_/

    kernel_kconfigs =~ /^#{config_name}$/
  when /^([A-Za-z0-9_]+=0[xX][A-Fa-f0-9]+)$/
    config_name = $1
    config_name = "CONFIG_#{config_name}" unless config_name =~ /^CONFIG_/

    kernel_kconfigs =~ /^#{config_name}$/
  when /^([A-Za-z0-9_]+)$/, /^([A-Za-z0-9_]+)=$/
    # /^([A-Z0-9_]+)$/ is for "CRYPTO_HMAC"
    # /^([A-Z0-9_]+)=$/ is for "DEBUG_INFO_BTF: v5.2"
    config_name = $1
    config_name = "CONFIG_#{config_name}" unless config_name =~ /^CONFIG_/

    kernel_kconfigs =~ /^#{config_name}=(y|m)$/
  else
    raise Job::SyntaxError, "Wrong syntax of kconfig: #{expected_kernel_kconfig}"
  end
end

def split_constraints(constraints)
  # to_s is for "CMA_SIZE_MBYTES: 200"
  constraints = constraints.to_s.split(',').map(&:strip)

  kernel_versions, constraints = constraints.partition { |constraint| constraint =~ /v\d+\.\d+/ }
  archs, constraints = constraints.partition { |constraint| constraint =~ /^(i386|x86_64)$/ }

  # \d+ is for "CMA_SIZE_MBYTES: 200"
  types, constraints = constraints.partition { |constraint| constraint =~ /^(y|m|n|\d+|0[xX][A-Fa-f0-9]+)$/ }
  raise Job::SyntaxError, "Wrong syntax of kconfig setting: #{constraints}" if types.size > 1

  raise Job::SyntaxError, "Wrong syntax of kconfig setting: #{constraints}" unless constraints.empty?

  OpenStruct.new(kernel_versions: kernel_versions, archs: archs, types: types)
end

def check_all(kernel_kconfigs, needed_kconfigs)
  uncompiled_kconfigs = []

  context = load_kernel_context
  kernel_version = context['rc_tag']
  kernel_arch = context['kconfig'].split('-').first

  kconfigs_yaml = KernelTag.kconfigs_yaml
  if File.exist? kconfigs_yaml
    kconfig_constraints = YAML.load_file kconfigs_yaml
    kconfig_constraints = kconfig_constraints.transform_values { |constraints| split_constraints(constraints) }
  end

  needed_kconfigs.each do |e|
    if e.instance_of? Hashugar
      config_name, config_options = e.to_hash.first
      config_options = split_constraints(config_options)

      # global arch constraint that means the kconfig is only supported on the specific arch
      expected_archs = kconfig_constraints[config_name].archs if kconfig_constraints && kconfig_constraints[config_name]
      next unless expected_archs.nil? || expected_archs.empty? || kernel_match_arch?(kernel_arch, expected_archs)

      # test arch constraint that means the kconfig is only enabled on the specific arch as required by test
      next unless config_options.archs.empty? || kernel_match_arch?(kernel_arch, config_options.archs)

      expected_kernel_versions = kconfig_constraints[config_name].kernel_versions if kconfig_constraints && kconfig_constraints[config_name]
      # ignore the check of kconfig type if kernel is not within the valid range
      next if expected_kernel_versions && !kernel_match_version?(kernel_version, expected_kernel_versions)

      expected_kernel_kconfig = "#{config_name}=#{config_options.types.first}"
    else
      expected_kernel_kconfig = e
    end

    next if kernel_match_kconfig?(kernel_kconfigs, expected_kernel_kconfig)

    uncompiled_kconfig = expected_kernel_kconfig
    uncompiled_kconfig += " (#{expected_kernel_versions.join(', ').gsub('"', '')})" if expected_kernel_versions
    uncompiled_kconfigs.push uncompiled_kconfig
  end

  return nil if uncompiled_kconfigs.empty?

  uncompiled_kconfigs = uncompiled_kconfigs.sort.uniq

  kconfigs_error_message = "#{File.basename __FILE__}: #{uncompiled_kconfigs} has not been compiled by this kernel (#{kernel_version} based)"
  raise Job::ParamError, kconfigs_error_message.to_s unless __FILE__ =~ /suggest_kconfig/

  puts "suggest kconfigs: #{uncompiled_kconfigs}"
end

def arch_constraints
  model = self['model']
  rootfs = self['rootfs']
  kconfig = self['kconfig']

  case model
  when /^qemu-system-x86_64/
    case rootfs
    when /-x86_64/
      # Check kconfig to find mismatches earlier, in cases
      # when the exact kernel is still not available:
      # - commit=BASE|HEAD|CYCLIC_BASE|CYCLIC_HEAD late binding
      # - know exact commit, however yet to compile the kernel
      raise Job::ParamError, "32bit kernel cannot run 64bit rootfs: '#{kconfig}' '#{rootfs}'" if kconfig =~ /^i386-/

      'X86_64=y'
    when /-i386/
      'IA32_EMULATION=y' if kconfig =~ /^x86_64-/
    end
  when /^qemu-system-i386/
    case rootfs
    when /-x86_64/
      raise Job::ParamError, "32bit QEMU cannot run 64bit rootfs: '#{model}' '#{rootfs}'"
    when /-i386/
      raise Job::ParamError, "32bit QEMU cannot run 64bit kernel: '#{model}' '#{kconfig}'" if kconfig =~ /^x86_64-/

      'X86_32=y'
    end
  end
end

if self['kernel']
  needed_kconfigs = Array(___)

  needed_kconfigs << arch_constraints

  check_all(read_kernel_kconfigs, needed_kconfigs.compact)
end
