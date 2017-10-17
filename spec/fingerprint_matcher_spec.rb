require "spec_helper"

describe LicenseMatcher::FingerprintMatcher do
  let(:corpus_path){ 'data/spdx_licenses/plain' }
  let(:test_folder){ 'spec/fixtures/training' }
  let(:test_index_path){ 'data/index.msgpack' }
  let(:test_file_path){ 'spec/fixtures/files/0BSD.txt'}
  let(:filenames){
    Dir.entries('data/spdx_licenses/plain').to_a.delete_if {|f| /\A\.+/.match(f) }
  }

  let(:lm){ LicenseMatcher::FingerprintMatcher.new(test_index_path) }

  it "matches correctly test file" do
    test_content = File.read test_file_path
    res = lm.match_text test_content, 0.9

    expect(res).not_to be_nil
    expect(res.label).to eq('0BSD')
    expect(res.score).to be > 0.9
  end

  it "matches all the license files in the corpus" do

    p  "#-- FingerprintMatcher ------------------------------"
    filenames.each do |lic_name|
      lic_id = lic_name.downcase

      lic_txt = File.read "#{corpus_path}/#{lic_name}"

      res = lm.match_text(lic_txt, 0.0)
      p "#{lic_name} => #{res.label}:#{res.score}"

      expect(res).not_to be_nil
      expect(res.label.empty?).to be_falsey
      expect(res.label.downcase).to eq(lic_id.downcase)
    end
  end


end
