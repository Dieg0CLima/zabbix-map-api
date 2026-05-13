require "test_helper"

class NetworkCables::PointNormalizerTest < ActiveSupport::TestCase
  test "normalizes x y when provided" do
    normalized = NetworkCables::PointNormalizer.normalize([ { position: 1, x: 10, y: 20 } ])

    assert_equal 1, normalized.first[:position]
    assert_equal 10, normalized.first[:x]
    assert_equal 20, normalized.first[:y]
  end

  test "normalizes lat lng aliases into x y" do
    normalized = NetworkCables::PointNormalizer.normalize([ { position: 2, lat: -23.5, lng: -46.6 } ])

    assert_equal 2, normalized.first[:position]
    assert_equal(-23.5, normalized.first[:x])
    assert_equal(-46.6, normalized.first[:y])
  end

  test "assigns position when missing" do
    normalized = NetworkCables::PointNormalizer.normalize([ { x: 10, y: 20 }, { x: 30, y: 40 } ])

    assert_equal 0, normalized[0][:position]
    assert_equal 1, normalized[1][:position]
  end

  test "raises argument error for invalid point coordinates" do
    error = assert_raises(ArgumentError) do
      NetworkCables::PointNormalizer.normalize([ { position: 0, lat: nil, lng: nil } ])
    end

    assert_equal "point coordinates are required", error.message
  end
end
