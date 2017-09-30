module LicenseMatcher
  class UrlMatcher
    attr_reader :url_index

    DEFAULT_LICENSE_JSON = 'data/licenses.json'

    def initialize(license_json_file = DEFAULT_LICENSE_JSON)
      licenses_json_doc = read_json_file license_json_file
      raise("Failed to read licenses.json") if licenses_json_doc.nil?

      @url_index =  read_license_url_index(licenses_json_doc)
    end

    def match_text(url_txt, min_confidence = 0.0)
      spdx_id, score = match_url url_txt.to_s.strip
      if spdx_id
        Match.new(spdx_id.to_s, score.to_f)
      else
        Match.new("", 0.0)
      end
    end

    # Matches License.url with urls in Licenses.json and returns tuple [spdx_id, score]
    def match_url(the_url)
      the_url = the_url.to_s.strip
      spdx_id = nil

      case the_url
      when /jquery\.org\/license/i
        return ['mit', 1.0] #Jquery license page doesnt include any license text
      when /mozilla\.org\/en-US\/MPL/i
        return ['mpl-2.0', 1.0]
      when /fairlicense\.org/i
        return ['fair', 1.0]
      when /aforgenet\.com\/framework\/license/i
        return ['lgpl-3.0', 1.0]
      when /apache\.org\/licenses/i
        return ['apache-2.0', 1.0]
      when /aws\.amazon\.com\/apache2\.0/i
        return ['apache-2.0', 1.0]
      when /aws\.amazon\.com\/asl/i
        return ['amazon', 1.0]
      when /choosealicense\.com\/no-license/i
        return ['no-license', 1.0]
      when /gzip\.org\/zlib\/zlib?license/i
        return ['zlib', 1.0]
      when /zlib\.net\/zlib?license/i
        return ['zlib', 1.0]
      when /wtfpl\.net\/about/i
        return ['wtfpl', 1.0]
      end

      #does url match with choosealicense.com
      match = the_url.match(/\bhttps?:\/\/(www\.)?choosealicense\.com\/licenses\/([\S|^\/]+)[\/]?\b/i)
      if match
        return [match[2].to_s.downcase, 1.0]
      end

      match = the_url.match(/\bhttps?:\/\/(www\.)?creativecommons\.org\/licenses\/([\S|^\/]+)[\/]?\b/i)
      if match
        return ["cc-#{match[2].to_s.gsub(/\//, '-')}", 1.0]
      end

      #check through SPDX urls
      @url_index.each do |lic_url, lic_id|
        lic_url = lic_url.to_s.strip.gsub(/https?:\/\//i, '').gsub(/www\./, '') #normalizes urls in the file
        matcher = Regexp.new("https?:\/\/(www\.)?#{lic_url}", Regexp::IGNORECASE)

        if matcher.match(the_url)
          spdx_id = lic_id.to_s.downcase
          break
        end
      end

      return [] if spdx_id.nil?

      [spdx_id, 1.0]
    end

    # Reads license urls from the license.json and builds a map {url : spdx_id}
    def read_license_url_index(spdx_licenses)
      url_index = {}
      spdx_licenses.each {|lic| url_index.merge! process_spdx_item(lic) }
      url_index
    end


    def process_spdx_item(lic)
      url_index = {}
      lic_id = lic[:id].to_s.strip.downcase

      return url_index if lic_id.empty?

      lic[:links].to_a.each {|x| url_index[x[:url]] = lic_id }
      lic[:text].to_a.each {|x| url_index[x[:url]] = lic_id }

      url_index
    end

    def read_json_file(file_path)
      JSON.parse(File.read(file_path), {symbolize_names: true})
    rescue
      log.info "Failed to read json file `#{file_path}`"
      nil
    end


  end
end
