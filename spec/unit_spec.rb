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
