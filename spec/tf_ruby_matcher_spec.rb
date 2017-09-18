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
    expect( lm.match_text(mit_txt) ).to eq("MIT")
    expect( lm.match_text(pg_txt) ).to eq('PostgreSQL')
    expect( lm.match_text(lgpl_txt) ).to eq('LGPL-2.0')
    expect( lm.match_text(pg_txt) ).to eq('PostgreSQL')
    expect( lm.match_text(bsd3_txt) ).to eq('BSD-3-Clause')
    expect( lm.match_text(dotnet_txt) ).to eq('MS_DOTNET')
  end

  it "matches MIT license so it could fix the issue#11" do
    expect( lm.match_text(mit_issue11) ).to eq('MIT')
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

    expect( lm.match_html(mit_html, 0.5) ).to eq('MIT')
    expect( lm.match_html(apache_html) ).to eq('Apache-2.0')
    expect( lm.match_html(dotnet_html).downcase ).to eq('ms_dotnet')
    expect( lm.match_html(bsd3_html, 0.0).downcase ).to eq('bsd-3-clear')

    #how it handles noisy pages
    spdx_id = lm.match_html(apache_aws, 0.5)
    expect( spdx_id ).to eq('Apache-2.0')

    spdx_id = lm.match_html(apache_plex, 0.0)
    expect( spdx_id ).to eq('Apache-2.0')

    spdx_id = lm.match_html(bsd_fparsec, 0.0)
    expect( spdx_id ).to eq('BSD-3-Clear')

    spdx_id = lm.match_html(mit_ooi, 0.0)
    expect( spdx_id ).to eq('MIT')

    spdx_id = lm.match_html(mit_bb, 0.0)
    expect( spdx_id ).to eq('MIT')

    expect( lm.match_html(mspl_ooi, 0.0) ).to eq('MS-PL')

    spdx_id = lm.match_html(cpol, 0.0)
    expect( spdx_id ).to eq('CPOL-1.02')
  end

  it "matches all the license files in the corpus" do

    filenames.each do |lic_name|
      lic_id = lic_name.downcase
      next if lic_id == 'ms_dotnet' or lic_id == 'cpol-1.02'


      lic_txt = File.read "#{corpus_path}/#{lic_name}"

      res = lm.match_text(lic_txt)
      p "#{lic_name} => #{res}"
      expect(res).not_to be_nil
      expect(res.empty? ).to be_falsey
      expect(res.downcase).to eq(lic_id.downcase)
    end
  end
end
