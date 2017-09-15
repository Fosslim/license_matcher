require 'spec_helper'

describe UrlMatcher do
  let(:lm){ LicenseMatcher::UrlMatcher.new }
  let(:licenses_json_path){ LicenseMatcher::UrlMatcher::DEFAULT_LICENSE_JSON }

  let(:aal_url){ "https://opensource.org/licenses/AAL"  }
  let(:apache1){ "https://opensource.org/licenses/Apache-1.1" }
  let(:apache2){ "https://www.apache.org/licenses/LICENSE-2.0" }
  let(:bsd2){ "https://opensource.org/licenses/BSD-2-Clause" }
  let(:bsd3){ "https://opensource.org/licenses/BSD-3-Clause" }
	let(:gpl3){ "https://www.gnu.org/licenses/gpl-3.0.txt" }

  it "build license url index from license.json file" do
    url_doc = lm.read_json_file licenses_json_path
    expect( url_doc ).not_to be_nil

    url_index = lm.read_license_url_index url_doc
    expect( url_index ).not_to be_nil
    expect( url_index[aal_url] ).to eq('aal')
		expect( url_index[apache1] ).to eq('apache-1.1')
		expect( url_index[apache2] ).to eq('apache-2.0')
    expect( url_index[bsd2] ).to eq('bsd-2-clause')
		expect( url_index[bsd3] ).to eq('bsd-3-clause')
		expect( url_index[gpl3] ).to eq('gpl-3.0')
  end

	it "matches saved URL with SPDX url" do
		expect( lm.match_url(aal_url).first ).to eq('aal')
		expect( lm.match_url(apache1).first ).to eq('apache-1.1')
		expect( lm.match_url(apache2).first ).to eq('apache-2.0')
		expect( lm.match_url(bsd2).first).to eq('bsd-2-clause')
		expect( lm.match_url(bsd3).first).to eq('bsd-3-clause')
		expect( lm.match_url(gpl3).first ).to eq('gpl-3.0')
	end

  it "matches chooselicense urls to spdx_Id" do
    expect(lm.match_url('https://www.choosealicense.com/licenses/apache-2.0/')[0]).to eq('apache-2.0')
    expect(lm.match_url('http://choosealicense.com/licenses/agpl-3.0/')[0]).to eq('agpl-3.0')
    expect(lm.match_url('https://choosealicense.com/licenses/cc0-1.0')[0]).to eq('cc0-1.0')
    expect(lm.match_url('https://choosealicense.com/licenses/mit/')[0]).to eq('mit')
  end

  it "matches cc-commons urls to spdx-id" do
    expect(lm.match_url('https://creativecommons.org/licenses/by/4.0')[0]).to eq('cc-by-4.0')
    expect(lm.match_url('https://creativecommons.org/licenses/by/4.0/')[0]).to eq('cc-by-4.0')
    expect(lm.match_url('https://creativecommons.org/licenses/by-sa/4.0/')[0]).to eq('cc-by-sa-4.0')
    expect(lm.match_url('https://creativecommons.org/licenses/by-nc/4.0/')[0]).to eq('cc-by-nc-4.0')
    expect(lm.match_url('https://creativecommons.org/licenses/by-nd/4.0/')[0]).to eq('cc-by-nd-4.0')
  end

end
