require "spec_helper"
require "msgpack"

describe "LicenseMatcher" do
  let(:test_folder){ 'spec/fixtures/training' }
  let(:test_index_path){ 'spec/fixtures/test.msgpack' }
  let(:test_file_path){ 'spec/fixtures/files/0BSD.txt'}

	it 'builds an correct index from test licenses' do
	  res = LicenseMatcher.build_index(test_folder, test_index_path)
    expect(res).to be_truthy

    idx = MessagePack.unpack File.read test_index_path
    expect(idx[0]).to eq(648) #number of terms
    expect(idx[1]).to eq(2)   #number of docs

    lm = LicenseMatcher.new(test_index_path)

    test_txt = File.read test_file_path
    expect(test_txt.to_s.empty?).to be_falsey
    expect(lm.match_text(test_txt, 0.9)).to eq('0BSD')
  end
end
