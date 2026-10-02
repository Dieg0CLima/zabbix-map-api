require "test_helper"

# REQ-006 RN8: validations live in the :map_settings validation context and only run when the attribute changes.
# Ambiguous/invisible Unicode is built from code points.
class NetworkMapSettingsValidationTest < ActiveSupport::TestCase
  CTX = :map_settings

  setup do
    @org = Organization.create!(name: "Org Validation #{SecureRandom.hex(3)}")
    @map = @org.network_maps.create!(name: "Mapa #{SecureRandom.hex(3)}")
  end

  def error_types(map, attribute)
    map.errors.details[attribute].map { |d| d[:error] }
  end

  test "CA3: blank name is invalid in the map_settings context with error :blank" do
    @map.name = "   "
    assert_not @map.valid?(CTX)
    assert_includes error_types(@map, :name), :blank
  end

  test "CA4: a changed name longer than 255 is invalid (:too_long); 255 is valid" do
    @map.name = "n" * 255
    assert @map.valid?(CTX)
    @map.name = "n" * 256
    assert_not @map.valid?(CTX)
    assert_includes error_types(@map, :name), :too_long
  end

  test "CA5: a changed description longer than 2000 is invalid (:too_long); 2000 is valid" do
    @map.description = "d" * 2000
    assert @map.valid?(CTX)
    @map.description = "d" * 2001
    assert_not @map.valid?(CTX)
    assert_includes error_types(@map, :description), :too_long
  end

  test "CA4/CA5: length is NOT revalidated when the attribute did not change (legacy data)" do
    @map.update_columns(name: "L" * 300, description: "D" * 3000)
    legacy = NetworkMap.find(@map.id)

    legacy.description = "curta"
    assert legacy.valid?(CTX), "editing only the description must not revalidate a long legacy name"

    legacy = NetworkMap.find(@map.id)
    legacy.name = "Nome Novo"
    assert legacy.valid?(CTX), "editing only the name must not revalidate a long legacy description"
  end

  test "CA6: forbidden characters are invalid (:invalid_characters) in the name; allowed ones are valid" do
    forbidden = [ 7.chr, 10.chr, 9.chr, [ 0x2028 ].pack("U"), [ 0x2029 ].pack("U"), [ 0x202E ].pack("U"), [ 0x2066 ].pack("U"), [ 0x2069 ].pack("U") ]
    forbidden.each do |ch|
      @map.name = "a#{ch}b"
      assert_not @map.valid?(CTX), "codepoint #{ch.ord.to_s(16)} must be rejected in name"
      assert_includes error_types(@map, :name), :invalid_characters
    end

    [ [ 0x200D ], [ 0x200C ], [ 0x1F600 ], [ 0x1F468, 0x200D, 0x1F469 ] ].each do |cps|
      @map.name = "ok #{cps.pack('U*')}"
      assert @map.valid?(CTX), "codepoints #{cps.inspect} must be accepted"
    end
  end

  test "CA6: the description allows LF, CR and tab but rejects other controls and separators" do
    @map.description = "a#{10.chr}b#{13.chr}c#{9.chr}d"
    assert @map.valid?(CTX)

    [ 7.chr, [ 0x2028 ].pack("U"), [ 0x2029 ].pack("U"), [ 0x202A ].pack("U") ].each do |ch|
      @map.description = "a#{ch}b"
      assert_not @map.valid?(CTX)
      assert_includes error_types(@map, :description), :invalid_characters
    end
  end

  test "CA7: a changed name equal to another map of the organization is invalid (:taken); the same name in another organization is valid" do
    @org.network_maps.create!(name: "Repetido")
    @map.name = "Repetido"
    assert_not @map.valid?(CTX)
    assert_includes error_types(@map, :name), :taken

    other = Organization.create!(name: "Org Validation B #{SecureRandom.hex(3)}")
    other_map = other.network_maps.create!(name: "Outro")
    other_map.name = "Repetido"
    assert other_map.valid?(CTX)
  end

  test "CA15: without the context the new rules do not apply — creation and import keep accepting long names and descriptions (characterization)" do
    long = @org.network_maps.new(name: "c" * 300, description: "d" * 3000)
    assert long.valid?
    assert long.save
    @map.name = "x#{7.chr}y"
    assert @map.valid?, "no context: control characters are not validated"
  end

  test "CA7/CA15: uniqueness without the context stays as today (characterization)" do
    @org.network_maps.create!(name: "Unico")
    dup = @org.network_maps.new(name: "Unico")
    assert_not dup.valid?
    assert_includes error_types(dup, :name), :taken
  end
end
