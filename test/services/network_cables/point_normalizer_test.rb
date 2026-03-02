require "test_helper"

class NetworkCables::PointNormalizerTest < ActiveSupport::TestCase
  test "normalizes lat lng into x y" do
    normalized = NetworkCables::PointNormalizer.normalize({ position: 2, lat: -23.5, lng: -46.6 })

    assert_equal 2, normalized[:position]
    assert_equal(-23.5, normalized[:x])
    assert_equal(-46.6, normalized[:y])
  end

  test "keeps x y when present" do
    normalized = NetworkCables::PointNormalizer.normalize({ position: 1, x: 10, y: 20, lat: -23.5, lng: -46.6 })

    assert_equal 10, normalized[:x]
    assert_equal 20, normalized[:y]
  end
end
