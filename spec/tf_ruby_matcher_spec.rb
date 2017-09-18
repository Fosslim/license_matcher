require 'spec_helper'

describe LicenseMatcher::TFRubyMatcher do
  lm = LicenseMatcher::TFRubyMatcher.new
  let(:licenses_json_path){ 'data/spdx_licenses/licenses.json' }
  let(:corpus_path){ 'data/spdx_licenses/plain' }
  let(:spec_path){ 'spec/fixtures/licenses' }
  let(:filenames){
    Dir.entries('data/spdx_licenses/plain').to_a.delete_if {|f| /\A\.+/.match(f) }
  }

  let(:mit_txt){ File.read("#{corpus_path}/MIT") }
  let(:pg_txt){ File.read("#{corpus_path}/PostgreSQL") }
  let(:lgpl_txt){ File.read("#{corpus_path}/LGPL-2.0") }
  let(:bsd3_txt){ File.read("#{corpus_path}/BSD-3-Clause") }
  let(:dotnet_txt){ File.read('data/custom_licenses/ms_dotnet') }
  let(:mit_issue11){ File.read("#{spec_path}/mit_issue11.txt")}

  it "finds correct matches for text files" do
    expect( lm.match_text(mit_txt).first.first ).to eq("mit")
    expect( lm.match_text(pg_txt).first.first ).to eq('postgresql')
    expect( lm.match_text(lgpl_txt).first.first ).to eq('lgpl-2.0')
    expect( lm.match_text(pg_txt).first.first ).to eq('postgresql')
    expect( lm.match_text(bsd3_txt).first.first ).to eq('bsd-3-clause')
    expect( lm.match_text(dotnet_txt).first.first ).to eq('ms_dotnet')
  end

  it "matches MIT license so it could fix the issue#11" do
    res = lm.match_text(mit_issue11)
    expect( res.size ).to eq(3)

    spdx_id, score = res.first
    expect( spdx_id ).to eq("mit")
    expect( score ).to be > 0.9
  end

  let(:min_score){ 0.5 }
  let(:mit_html){ File.read "#{spec_path}/mit.htm" }
  let(:apache_html){File.read "#{spec_path}/apache2.html" }
  let(:dotnet_html){ File.read "#{spec_path}/ms.htm" }
  let(:bsd3_html){ File.read "#{spec_path}/bsd3.html" }
  let(:apache_aws){File.read "#{spec_path}/apache_aws.html"}
  let(:apache_plex){ File.read "#{spec_path}/apache_plex.html"}
  let(:bsd_fparsec){ File.read "#{spec_path}/bsd_fparsec.html"}
  let(:mit_ooi){ File.read "#{spec_path}/mit_ooi.html" }
  let(:mit_bb){ File.read "#{spec_path}/mit_bb.html" }
  let(:mspl_ooi){ File.read "#{spec_path}/mspl_ooi.html" }
  let(:cpol){File.read "#{spec_path}/cpol.html"}

  it "finds correct matches for html files" do

    expect( lm.match_html(mit_html).first.first ).to eq('mit')
    expect( lm.match_html(apache_html).first.first ).to eq('apache-2.0')
    expect( lm.match_html(dotnet_html).first.first ).to eq('ms_dotnet')
    expect( lm.match_html(bsd3_html).first.first ).to eq('bsd-3-clear')

    #how it handles noisy pages
    spdx_id, score = lm.match_html(apache_aws).first
    expect( spdx_id ).to eq('apache-2.0')
    expect( score ).to be > min_score

    spdx_id, score = lm.match_html(apache_plex).first
    expect( spdx_id ).to eq('apache-2.0')
    expect( score ).to be > min_score

    spdx_id, score = lm.match_html(bsd_fparsec).first
    expect( spdx_id ).to eq('bsd-3-clear')
    expect( score ).to be > min_score

    spdx_id, score = lm.match_html(mit_ooi).first
    expect( spdx_id ).to eq('mit')
    expect( score ).to be > min_score

    spdx_id, score = lm.match_html(mit_bb).first
    expect( spdx_id ).to eq('mit')
    expect( score ).to be > min_score

    expect( lm.match_html(mspl_ooi).first.first ).to eq('ms-pl')

    spdx_id, score = lm.match_html(cpol).first
    expect( spdx_id ).to eq('cpol-1.02')
    expect( score ).to be > min_score
  end

  it "matches all the license files in the corpuse correctly" do

    filenames.each do |lic_name|
      lic_id = lic_name.downcase
      next if lic_id == 'ms_dotnet' or lic_id == 'cpol-1.02'


      lic_txt = File.read "#{corpus_path}/#{lic_name}"

      res = lm.match_text(lic_txt)
      p "#{lic_name} => #{res} "
      expect(res).not_to be_nil
      expect(res.empty? ).to be_falsey
      expect(res.first.first).to eq(lic_id)
    end
  end
end
