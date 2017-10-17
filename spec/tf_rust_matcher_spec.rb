require "spec_helper"
require "msgpack"

describe LicenseMatcher::TFRustMatcher do
  let(:corpus_path){ 'data/spdx_licenses/plain' }
  let(:test_folder){ 'spec/fixtures/training' }
  let(:test_index_path){ 'spec/fixtures/test.msgpack' }
  let(:test_file_path){ 'spec/fixtures/files/0BSD.txt'}
  let(:filenames){
    Dir.entries('data/spdx_licenses/plain').to_a.delete_if {|f| /\A\.+/.match(f) }
  }

  it 'raises when passed it fails to build the index' do
    expect {
      LicenseMatcher::IndexBuilder.build_index('not', 'found')
    }.to raise_error('target path doesnt exists or is not accessible')
  end

  it 'builds an correct index from test licenses' do
    res = LicenseMatcher::IndexBuilder.build_index(test_folder, test_index_path)
    expect(res).to be_truthy

    idx = MessagePack.unpack File.read test_index_path
    expect(idx[0]).to eq(648) #number of terms
    expect(idx[1]).to eq(2)   #number of docs

    lm = LicenseMatcher::TFRustMatcher.new(test_index_path)

    test_txt = File.read test_file_path
    expect(test_txt.to_s.empty?).to be_falsey

    res = lm.match_text(test_txt, 0.9)

    expect(res.label).to eq('0BSD')
    expect(res.score).to be > 0.9

    expect(lm.match_text('', 0.9)).to be_nil
    expect(lm.match_text('not a real license', 0.9)).to be_nil
  end

  it "matches all the license files in the corpus" do
    lm = LicenseMatcher::TFRustMatcher.new('data/index.msgpack')

    p "#-- TFRustMatcher ---------------------------------------"
    filenames.each do |lic_name|
      lic_id = lic_name.downcase

      lic_txt = File.read "#{corpus_path}/#{lic_name}"

      res = lm.match_text(lic_txt, 0.0)
      p "#{lic_name} => #{res.label}:#{res.score}"

      expect(res).not_to be_nil
      expect(res.label.downcase).to eq(lic_id.downcase)
    end
  end

end
