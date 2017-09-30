require 'spec_helper'
require 'benchmark'

describe "CorpusBenchmark" do
  let(:test_index){ 'data/index.msgpack' }
  let(:corpus_path){ 'data/spdx_licenses/plain' }
  let(:filenames){
    Dir.entries('data/spdx_licenses/plain').to_a.delete_if {|f| /\A\.+/.match(f) }
  }

  let(:n_tries){ 1000 }

  it "measure initialization of different models" do
    Benchmark.bm do |x|

      x.report("TFRubyMatcher:") do
        1.times { LicenseMatcher::TFRubyMatcher.new(test_index) }
      end

      x.report("TFRustMatcher:") do
        1.times { LicenseMatcher::TFRustMatcher.new(test_index) }
      end

      x.report("FingerprintMatcher:") do
        1.times { LicenseMatcher::FingerprintMatcher.new(test_index) }
      end


    end
  end

  let(:lm1){ LicenseMatcher::TFRubyMatcher.new(test_index) }
  let(:lm2){ LicenseMatcher::TFRustMatcher.new(test_index) }
  let(:lm3){ LicenseMatcher::FingerprintMatcher.new(test_index) }

  it "measures matching time for MIT license" do
    lic_name = 'MIT'
    lic_txt = File.read "#{corpus_path}/#{lic_name}"
    lic_txt = LicenseMatcher::Preprocess.preprocess_text(lic_txt)

    # first check correctness of the match
    res1 = lm1.match_text(lic_txt, 0.0)
    res2 = lm2.match_text(lic_txt, 0.0)
    res3 = lm3.match_text(lic_txt, 0.0)
    p %Q[
      Expected license: #{lic_name}
      TFRuby: #{res1.get_label()}:#{res1.get_score()}
      TFRust: #{res2.get_label()}:#{res2.get_score()}
      Finger: #{res3.get_label()}:#{res3.get_score()}
    ]


    expect(res1).not_to be_nil
    expect(res1.get_label().empty? ).to be_falsey
    expect(res1.get_label().downcase).to eq(lic_name.downcase)
    expect(res2.get_label().downcase).to eq(lic_name.downcase)
    expect(res3.get_label().downcase).to eq(lic_name.downcase)

    # now we are ready to run benchmarks
    Benchmark.bm do |x|
      x.report("TFRubyMatcher:") { n_tries.times do lm1.match_text(lic_txt, 0.0); end }
      x.report("TFRustMatcher:") { n_tries.times do lm2.match_text(lic_txt, 0.0); end }
      x.report("FingerMatcher:") { n_tries.times do lm3.match_text(lic_txt, 0.0); end }

    end
  end

  it "measures matching time for AGPL license" do
    lic_name = 'AGPL-3.0'
    lic_txt = File.read "#{corpus_path}/#{lic_name}"
    lic_txt = LicenseMatcher::Preprocess.preprocess_text(lic_txt)

    # first check correctness of the match
    res1 = lm1.match_text(lic_txt, 0.0)
    res2 = lm2.match_text(lic_txt, 0.0)
    res3 = lm3.match_text(lic_txt, 0.0)
    p %Q[
      Expected license: #{lic_name}
      TFRuby: #{res1.get_label()}:#{res1.get_score()}
      TFRust: #{res2.get_label()}:#{res2.get_score()}
      Finger: #{res3.get_label()}:#{res3.get_score()}
    ]


    expect(res1).not_to be_nil
    expect(res1.get_label().empty? ).to be_falsey
    expect(res1.get_label().downcase).to eq(lic_name.downcase)
    expect(res2.get_label().downcase).to eq(lic_name.downcase)
    expect(res3.get_label().downcase).to eq(lic_name.downcase)

    # now we are ready to run benchmarks
    Benchmark.bm do |x|
      x.report("TFRubyMatcher:") { n_tries.times do lm1.match_text(lic_txt, 0.0); end }
      x.report("TFRustMatcher:") { n_tries.times do lm2.match_text(lic_txt, 0.0); end }
      x.report("FingerMatcher:") { n_tries.times do lm3.match_text(lic_txt, 0.0); end }
    end
  end


end
