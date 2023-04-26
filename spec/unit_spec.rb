require 'spec_helper'
require "#{LKP_SRC}/lib/unit"

expects = {
  10 => 10,
  10.0 => 10.0,
  '10y' => 315_360_000,
  '10w' => 6_048_000,
  '10d' => 864_000,
  '10h' => 36_000,
  '10m' => 600,
  '10s' => 10,
  '10x' => 10,
  '10' => 10,
  '10.0' => 10,
  '10.0x' => 10
}

describe 'to_seconds' do
  expects.each do |k, v|
    it k do
      expect(to_seconds(k)).to eq v
    end
  end
end

expects = {
  '1KB' => 1024,
  '1mb' => 1_048_576,
  '1GB' => 1_073_741_824,
  '1tb' => 1_099_511_627_776,
  '1PB' => 1_125_899_906_842_624,
  '1k' => 1024,
  '1M' => 1_048_576,
  '1g' => 1_073_741_824,
  '1T' => 1_099_511_627_776,
  '1p' => 1_125_899_906_842_624,
  '1kj' => '1kj',
  '10' => '10',
  10 => 10,
  10.0 => 10
}

describe 'to_byte' do
  expects.each do |k, v|
    it k do
      expect(to_byte(k)).to eq v
    end
  end
end
