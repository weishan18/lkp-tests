#!/usr/bin/env ruby

LKP_SRC ||= ENV['LKP_SRC'] || File.dirname(__dir__)

require 'yaml'
require "#{LKP_SRC}/lib/programs"

def adapt_packages(distro, generic_packages)
  distro_file = "#{LKP_SRC}/distro/adaptation/#{distro}"
  return generic_packages unless File.exist? distro_file

  distro_packages = YAML.load_file(distro_file)

  generic_packages.map do |pkg|
    if distro_packages.include? pkg
      distro_packages[pkg].to_s.split
    else
      pkg
    end
  end
end

def dependency_packages(distro, script)
  base_file = LKP::Programs.depends_file(script)
  return [] unless base_file

  generic_packages = []
  File.read(base_file).each_line do |line|
    line = line.sub(/#.*/, '')
    generic_packages.concat line.split
  end

  packages = adapt_packages(distro, generic_packages)

  packages.flatten.compact.uniq
end
