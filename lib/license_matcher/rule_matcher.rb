require 'json'

module LicenseMatcher

  class RuleMatcher
    attr_reader :licenses, :rules, :id_spdx_idx

    DEFAULT_LICENSE_JSON      = 'data/licenses.json'

    def initialize(license_json_file = DEFAULT_LICENSE_JSON)

      licenses_json_doc = read_json_file license_json_file
      raise("Failed to read licenses.json") if licenses_json_doc.nil?

      @rules = init_rules(licenses_json_doc)
      @id_spdx_idx = init_id_idx(licenses_json_doc) #reverse index from downcased licenseID to case sensitive spdx id
      true

    end

    def init_id_idx(licenses_json_doc)
      idx = {}
      licenses_json_doc.to_a.each do |spdx_item|
        lic_id = spdx_item[:id].to_s.downcase
        idx[lic_id] = spdx_item[:id]
      end

      idx
    end

    def match_text(text, min_confidence = 0.0)
      res = match_rules(text, true)
      if res.empty?
        Match.new("", 0.0)
      else
        spdx_id, score = res.first
        Match.new(spdx_id.to_s, score.to_f)
      end
    end

    # finds matching regex rules in the text and sorts matches by length of match
    # ps: not very efficient, but good enough to handle special cases;
    # @args:
    #   text - string, a name of license,
    # @returns:
    #   [[spdx_id, score, matching_rule, matching_length],...]
    def match_rules(text, early_exit = false)
      matches = []
      text = LicenseMatcher::Preprocess.preprocess_text(text)

      #if text is already spdx_id, then shortcut matching
      if @rules.has_key?(text.downcase)
        return [[text.downcase, 1.0]]
      end

      text += ' ' # required to make wordborder matcher to work with 1word texts
      @rules.each do |spdx_id, rules|
        match_res = matches_any_rule?(rules, text)
        unless match_res.nil?
          matches << ([spdx_id, 1.0] + match_res)
          break if early_exit == true
        end
      end

      matches.sort do |a, b|
        if (a.size == b.size and a.size == 4)
          -1 * (a[3] <=> b[3])
        else
          0
        end
      end
    end

    # if testable license text is in the ignore set return true
    def ignore?(lic_text)
      ignore_rules = get_ignore_rules
      m = matches_any_rule?(ignore_rules, lic_text.to_s)
      not m.nil?
    end

    def matches_any_rule?(rules, license_name)
      res = nil
      rules.each do |rule|
        m = rule.match(license_name.to_s)
        if m
          res = [rule, m[0].size]
          break
        end
      end

      res
    end


  #-- helpers

    def read_json_file(file_path)
      JSON.parse(File.read(file_path), {symbolize_names: true})
    rescue
      nil
    end

    # combines SPDX rules with custom handwritten rules
    def init_rules(license_json_doc)
      rules = {}
      rules = build_rules_from_spdx_json(license_json_doc)

      get_custom_rules.each do |spdx_id, custom_rules_array|
        spdx_id = spdx_id.to_s.strip.downcase

        if rules.has_key?(spdx_id)
          rules[spdx_id].concat custom_rules_array
        else
          rules[spdx_id] = custom_rules_array
        end
      end

      rules
    end


    # builds regex rules based on the LicenseJSON file
    # rules are using urls, IDS, names and alternative names to build full string matching regexes
    def build_rules_from_spdx_json(spdx_json)
      spdx_rules = {}

      sorted_spdx_json = spdx_json.sort_by {|x|  x[:id]}
      sorted_spdx_json.each do |spdx_item|
        spdx_id = spdx_item[:id].to_s.downcase.strip
        spdx_rules[spdx_id] = build_spdx_item_rules(spdx_item)
      end

      spdx_rules
    end

    def build_spdx_item_rules(spdx_item)
      rules = []

      #links are first, because it has highest confidence that they are talking about the license
      spdx_item[:links].to_a.each do |link|
        lic_url = link[:url].to_s.strip.gsub(/https?:\/\//i, '').gsub(/www\./, '').gsub(/\./, '\\.') #normalizes urls in the file

        rules << Regexp.new("\\b[\\(]?https?:\/\/(www\.)?#{lic_url}[\/]?[\\)]?\\b".gsub(/\s+/, ''), Regexp::IGNORECASE)
      end

      #include also links to license texts
      spdx_item[:text].to_a.each do |link|
        lic_url = link[:url].to_s.strip.gsub(/https?:\/\//i, '').gsub(/www\./, '').gsub(/\./, '\\.') #normalizes urls in the file
        rules << Regexp.new("\\b[\\(]?https?:\/\/(www\.)?#{lic_url}[\/]?[\\)]?\\b".gsub(/\s+/, ''), Regexp::IGNORECASE)
      end


      spdx_name = LicenseMatcher::Preprocess.preprocess_text(spdx_item[:name])
      spdx_name.gsub!(/\(.+?\)/, '')       #remove SPDX ids in the license names
      spdx_name.gsub!(/\./, '\\.')         #mark version dots as not regex selector
      spdx_name.gsub!(/[\*|\?|\+]/, '.')   #replace regex selector with whatever mark ~> WTFPL name
      spdx_name.gsub!(/\,/, '[\\,]?')      #make comma optional
      spdx_name.strip!
      spdx_name.gsub!(/\s+/, '\\s\\+')     #replace spaces with space selector

      rules << Regexp.new("\\b#{spdx_name}\\b", Regexp::IGNORECASE)

      #use spdx_id in full-text match if it's uniq and doest ambiquity like MIT, Fair, Glide
      spdx_id = spdx_item[:id].to_s.strip.downcase
      if spdx_id.match /[\d|-]|ware\z/
        rules << Regexp.new("\\b[\\(]?#{spdx_id}[\\)]?\\b".gsub(/\s+/, '\\s').gsub(/\./, '\\.'), Regexp::IGNORECASE)
      else
        rules << Regexp.new("\\A[\\(]?#{spdx_id}[\\)]?\\b", Regexp::IGNORECASE)
      end

      spdx_item[:identifiers].to_a.each do |id|
        rules << Regexp.new("\\b#{id[:identifier]}\\s".gsub(/\s+/, '\\s').gsub(/\./, '\\.'), Regexp::IGNORECASE)
      end

      spdx_item[:other_names].to_a.each do |alt|
        rules << Regexp.new("\\b#{alt[:name]}\\b".gsub(/\s+/, '\\s'), Regexp::IGNORECASE)
      end

      rules
    end


    def get_ignore_rules
      [
        /\bProprietary\b/i, /\bOther\/Proprietary\b/i, /\ALICEN[C|S]E\.\w{2,8}\b/i,
        /^LICEN[C|S]ING\.\w{2,8}\b/i, /^COPYING\.\w{2,8}/i,
        /\ADFSG\s+APPROVED\b/i, /\ASee\slicense\sin\spackage\b/i,
        /\ASee LICENSE\b/i,
        /\AFree\s+for\s+non[-]?commercial\b/i, /\AFree\s+To\s+Use\b/i,
        /\AFree\sFor\sHome\sUse\b/i, /\AFree\s+For\s+Educational\b/i,
        /^Freely\s+Distributable\s*$/i, /^COPYRIGHT\s+\d{2,4}/i,
        /^Copyright\s+\(c\)\s+\d{2,4}\b/i, /^COPYRIGHT\s*$/i, /^COPYRIGHT\.\w{2,8}\b/i,
        /^\(c\)\s+\d{2,4}\d/,
        /^LICENSE\s*$/i, /^FREE\s*$/i, /\ASee\sLicense\s*\b/i, /^TODO\s*$/i, /^FREEWARE\s*$/i,
        /^All\srights\sreserved\s*$/i, /^COPYING\s*$/i, /^OTHER\s*$/i, /^NONE\s*$/i, /^DUAL\s*$/i,
        /^KEEP\s+IT\s+REAL\s*\b/i, /\ABE\s+REAL\s*\z/i, /\APrivate\s*\z/i, /\ACommercial\s*\z/i,
        /\ASee\s+LICENSE\s+file\b/i, /\ASee\sthe\sLICENSE\b/i, /\ALICEN[C|S]E\s*\z/i,
        /^PUBLIC\s*$/i, /^see file LICENSE\s*$/i, /^__license__\s*$/i,
        /\bLIEULA\b/i, /\AEULA\s*\z/i, /^qQuickLicen[c|s]e\b/i, /^For\sfun\b/i, /\AVarious\s*\z/i,
        /^GNU\s*$/i, /^GNU[-|\s]?v3\s*$/i, /^OSI\s+Approved\s*$/i, /^OSI\s*$/i,
        /\AOPEN\sSOURCE\sLICENSE\s?\z/i, /\AOPEN\s*\z/i, /\Aunknown\s*\z/i,
        /^https?:\/\/github.com/i, /^https?:\/\/gitlab\.com/i
      ]
    end


    def get_custom_rules
      {
        "AAL"           => [/\bAAL\b/i, /\bAAL\s+License\b/i,
                            /\bAttribution\s+Assurance\s+License\b/i],
        "AFL-1.1"       => [/\bAFL[-|v]?1[^\.]\b/i, /\bafl[-|v]?1\.1\b/i],
        "AFL-1.2"       => [/\bAFL[-|v]?1\.2\b/i],
        "AFL-2.0"       => [/\bAFL[-|v]?2[^\.]\b/i, /\bAFL[-|v]?2\.0\b/i],
        "AFL-2.1"       => [/\bAFL[-|v]?2\.1\b/i],
        "AFL-3.0"       => [
                            /\bAFL[-|\s|\_]?v?3\.0\b/i, /\bAFL[-|\s|\_]?v?3/i,
                            /\AAcademic\s+Free\s+License\s*\z/i, /^AFL\s?\z/i,
                            /\bhttps?:\/\/opensource\.org\/licenses\/academic\.php\b/i,
                            /\AAcademic[-|\s]Free[-|\s]License[-]?\s*\z/i,
                            /\bAcademic.Free.License.\(AFL\)/i
                            ],
        "AGPL-1.0"      => [
                            /\bAGPL[-|v|_|\s]?1\.0\b/i,
                            /\bAGPL[-|v|_|\s]1\b/i , /\bAGPL[_|-|v]?2\b/i,
                            /\bAffero\s+General\s+Public\s+License\s+[v]?1\b/i,
                            /\bAGPL\s(?!(v|\d))/i #Matches only AGPL, but not AGPL v1, AGPL 1.0 etc
                            ],
        "AGPL-3.0"      => [
                            /\bAGPL[-|_|\s]?v?3\.0\b/i, /\bAGPL[-|\s|_]?v?3[\+]?\b/i,
                            /\bAPGLv?3[\+]?\b/i, #some packages has typos
                            /\bGNU\s+Affero\s+General\s+Public\s+License\s+[v]?3/i,
                            /\bAFFERO\sGNU\sPUBLIC\sLICENSE\sv3\b/i,
                            /\bGnu\sAffero\sPublic\sLicense\sv3+?\b/i,
                            /\bAffero\sGeneral\sPublic\sLicen[s|c]e[\,]?\sversion\s+3[\.0]?\b/i,
                            /\bAffero\sGeneral\sPublic\sLicense\sv?3\b/i,
                            /\bAGPL\sversion\s3[\.]?\b/i,
                            /\bGNU\sAGPL\sv?3[\.0]?\b/i,
                            /\bGNU\sAFFERO\sv?3\b/i,
                            /\bhttps?:\/\/gnu\.org\/licenses\/agpl\.html\b/i,
                            /\AAFFERO\sGENERAL\sPUBLIC\sLICENSE\s*\z/i,
                            /^AFFERO\s*\z/i
                           ],
        "Aladdin"       => [/\b[\(]?AFPL[\)]?\b/i, /\bAladdin\sFree\sPublic\sLicense\b/i],
        "Amazon"        => [/\bAmazon\sSoftware\sLicense\b/i],
        "Apache-1.0"    => [/\bAPACHE[-|_|\s]?v?1[^\.]/i, /\bAPACHE[-|\s]?v?1\.0\b/i],
        "Apache-1.1"    => [/\bAPACHE[-|_|\s]?v?1\.1\b/i],
        "Apache-2.0"    => [
                            /\bAPACHE\s+2\.0\b/i, /\bAPACHE[-|_|\s]?v?2\b/i,
                            /\bApache\sOpen\sSource\sLicense\s2\.0\b/i,
                            /\bAPACH[A|E]\s+Licen[c|s]e\s+[\(]?v?2\.0[\)]?\b/i,
                            /\bAPACHE\s+LICENSE\,?\s+VERSION\s+2\.0\b/i,
                            /\bApache\s+License\s+v?2\b/i,
                            /\bApache\s+Software\sLicense\b/i,
                            /\bApapche[-|\s|\_]?v?2\.0\b/i, /\bAL[-|\s|\_]2\.0\b/i,
                            /\bAPL\s+2\.0\b/i, /\bAPL[\.|-|v]?2\b/i, /\bASL\s+2\.0\b/i,
                            /\bASL[-|v|\s]?2\b/i, /\bALv2\b/i, /\bASF[-|\s]?2\.0\b/i,
                            /\AAPACHE\s*\z/i, /\AASL\s*\z/i, /\bASL\s+v?\.2\.0\b/i, /\AASF\s*\z/i,
                            /\AApache\s+license\s*\z/i,
                           ],
        "APL-1.0"       => [/\bapl[-|_|\s]?v?1\b/i, /\bAPL[-|_|\s]?v?1\.0\b/i, /^APL$/i],
        "APSL-1.0"      => [/\bAPSL[-|_|\s]?v?1\.0\b/i, /\bAPSL[-|_|\s]?v?1(?!\.)\b/i, /\AAPPLE\s+PUBLIC\s+SOURCE\s*\z/i],
        "APSL-1.1"      => [/\bAPSL[-|_|\s]?v?1\.1\b/i],
        "APSL-1.2"      => [/\bAPSL[-|_|\s]?v?1\.2\b/i],
        "APSL-2.0"      => [/\bAPSL[-|_|\s]?v?2\.0\b/i, /\bAPSL[-|_|\s]?v?2\b/i],

        "Artistic-1.0-Perl" => [/\bArtistic[-|_|\s]?v?1\.0\-Perl\b/i, /\bPerlArtistic\b/i],
        "Artistic-1.0"  => [/\bartistic[-|_|\s]?v?1\.0(?!\-)\b/i, /\bartistic[-|_|\s]?v?1(?!\.)\b/i],
        "Artistic-2.0"  => [/\bARTISTIC[-|_|\s]?v?2\.0\b/i, /\bartistic[-|_|\s]?v?2\b/i,
                            /\bArtistic.2.0\b/i,
                            /\bARTISTIC\s+LICENSE\b/i, /\AARTISTIC\s*\z/i],
        "Beerware"      => [
                            /\bBEERWARE\b/i, /\bBEER\s+LICEN[c|s]E\b/i,
                            /\bBEER[-|\s]WARE\b/i, /^BEER\b/i,
                            /\bBuy\ssnare\sa\sbeer\b/i,
                            /\bFree\sas\sin\sbeer\b/i
                           ],
        'BitTorrent-1.1' => [/\bBitTorrent\sOpen\sSource\sLicense\b/i],
        "0BSD"          => [/\A0BSD\s*\z/i],
        "BSD-2-CLAUSE"  => [
                            /\bBSD[-|_|\s]?v?2\b/i, /^FREEBSD\b/i, /^OPENBSD\b/i,
                            /\bBSDLv2\b/i
                           ],
        "BSD-3-CLAUSE"  => [/\bBSD[-|_|\s]?v?3\b/i, /\bBSD[-|\s]3[-\s]CLAUSE\b/i,
                            /\bBDS[-|_|\s]3[-|\s]CLAUSE\b/i,
                            /\bthree-clause\sBSD\slicen[s|c]e\b/i,
                            /\ABDS\s*\z/i, /^various\/BSDish\s*$/],
        "BSD-4-CLAUSE"  => [
                            /\bBSD[-|_|\s]?v?4/i, /\ABSD\s*\z/i, /\ABSD\s+LI[s|c]EN[S|C]E\s*\z/i,
                            /\bBSD-4-CLAUSE\b/i,
                            /\bhttps?:\/\/en\.wikipedia\.org\/wiki\/BSD_licenses\b/i
                           ],
        "BSL-1.0"       => [
                            /\bBSL[-|_|\s]?v?1\.0\b/i, /\bbsl[-|_|\s]?v?1\b/i, /^BOOST\b/i,
                            /\bBOOST\s+SOFTWARE\s+LICENSE\b/i,
                            /\bBoost\sLicense\s1\.0\b/i
                           ],
        "CC0-1.0"       => [
                            /\bCC0[-|_|\s]?v?1\.0\b/i, /\bCC0[-|_|\s]?v?1\b/i,
                            /\bCC[-|\s]?[0|o]\b/i, /\bCreative\s+Commons\s+0\b/i,
                            /\bhttps?:\/\/creativecommons\.org\/publicdomain\/zero\/1\.0[\/]?\b/i,
                            /\bcc[-|\_]zero\b/i
                           ],
        "CC-BY-1.0"     => [/\bCC.BY.v?1\.0\b/i, /\bCC.BY.v?1\b/i, /^CC[-|_|\s]?BY$/i],
        "CC-BY-2.0"     => [/\bCC.BY.v?2\.0\b/i, /\bCC.BY.v?2(?!\.)\b/i],
        "CC-BY-2.5"     => [/\bCC.BY.v?2\.5\b/i],
        "CC-BY-3.0"     => [
                            /\bCC.BY.v?3\.0\b/i, /\b[\(]?CC.BY[\)]?.v?3\b/i,
                            /\bCreative\sCommons\sBY\s3\.0\b/i,
                            /\bhttps?:\/\/.+\/licenses\/by\/3\.0[\/]?/i
                           ],
        "CC-BY-4.0"     => [
                            /^CC[-|\s]?BY[-|\s]?v?4\.0$/i, /\bCC.BY.v?4\b/i, /\bCC.BY.4\.0\b/i,
                            /\bCREATIVE\s+COMMONS\s+ATTRIBUTION\s+[v]?4\.0\b/i,
                            /\ACREATIVE\s+COMMONS\s+ATTRIBUTION\s*\z\b/i
                           ],
        "CC-BY-SA-1.0"  => [/\bCC[-|\s]BY.SA.v?1\.0\b/i, /\bCC[-|\s]BY.SA.v?1\b/i],
        "CC-BY-SA-2.0"  => [/\bCC[-|\s]BY.SA.v?2\.0\b/i, /\bCC[-|\s]BY.SA.v?2(?!\.)\b/i],
        "CC-BY-SA-2.5"  => [/\bCC[-|\s]BY.SA.v?2\.5\b/i],
        "CC-BY-SA-3.0"  => [/\bCC[-|\s]BY.SA.v?3\.0\b/i, /\bCC[-|\s]BY.SA.v?3\b/i,
                            /\bCC3\.0[-|_|\s]BY.SA\b/i,
                            /\bhttps?:\/\/(www\.)?.+\/by.sa\/3\.0[\/]?/i],
        "CC-BY-SA-4.0"  => [
                            /CC[-|\s]BY.SA.v?4\.0$/i, /\bCC[-|\s]BY.SA.v?4\b/i,
                            /CCSA-4\.0/i
                           ],
        "CC-BY-NC-1.0"  => [/\bCC[-|\s]BY.NC[-|\s]?v?1\.0\b/i, /\bCC[-|\s]BY.NC[-|\s]?v?1\b/i],
        "CC-BY-NC-2.0"  => [/\bCC[-|\s]BY.NC[-|\s]?v?2\.0\b/i],
        "CC-BY-NC-2.5"  => [/\bCC[-|\s]BY.NC[-|\s]?v?2\.5\b/i],
        "CC-BY-NC-3.0"  => [/\bCC[-|\s]BY.NC[-|\s]?v?3\.0\b/i, /\bCC.BY.NC[-|\s]?v?3\b/i,
                            /\bCreative\s+Commons\s+Non[-]?Commercial[,]?\s+3\.0\b/i],
        "CC-BY-NC-4.0"  => [
                            /\bCC[-|\s]BY.NC[-|\s|_]?v?4\.0\b/i, /\bCC.BY.NC[-|\s|_]?v?4\b/i,
                            /\bhttps?:\/\/creativecommons\.org\/licenses\/by-nc\/3\.0[\/]?\b/i
                           ],
        "CC-BY-NC-SA-1.0" => [ /\bCC[-|\s+]BY.NC.SA[-|\s+]v?1\.0\b/i,
                               /\bCC[-|\s+]BY.NC.SA[-|\s+]v?1\b/i
                             ],
        "CC-BY-NC-SA-2.0" =>  [/\bCC[-|\s]?BY.NC.SA[-|\s]?v?2\.0\b/i],
        "CC-BY-NC-SA-2.5" =>  [/\bCC[-|\s]?BY.NC.SA[-|\s]?v?2\.5\b/i],
        "CC-BY-NC-SA-3.0" =>  [
                                /\bCC[-|\s]?BY.NC.SA[-|\s]?v?3\.0\b/i,
                                /\bCC[-|\s]?BY.NC.SA[-|\s]?v?3(?!\.)\b/i,
                                /\bBY[-|\s]NC[-|\s]SA\sv?3\.0\b/i,
                                /\bhttp:\/\/creativecommons.org\/licenses\/by-nc-sa\/3.0\/us[\/]?\b/i
                              ],
        "CC-BY-NC-SA-4.0" => [/\bCC[-|\s]?BY.NC.SA[-|\s]?v?4\.0\b/i,
                              /\bCC[-|_|\s]BY.NC.SA[-|\s]?v?4(?!\.)\b/i,
                              /\bBY.NC.SA[-|\s|\_]v?4\.0\b/i],

        "CC-BY-ND-1.0"  => [/\bCC[-|\s]BY.ND[-|\s]?v?1\.0\b/i],
        "CC-BY-ND-2.0"  => [/\bCC[-|\s]BY.ND[-|\s]?v?2\.0\b/i],
        "CC-BY-ND-2.5"  => [/\bCC[-|\s]BY.ND[-|\s]?v?2\.5\b/i],
        "CC-BY-ND-3.0"  => [/\bCC[-|\s]BY.ND[-|\s]?v?3\.0\b/i],
        "CC-BY-ND-4.0"  => [
                             /\bCC[-|\s]BY.ND[-|\s]?v?4\.0\b/i,
                             /\bCC\sBY.NC.ND\s4\.0/i
                            ],

        "CC-BY-NC-ND-3.0" => [/\bCC.BY.NC.ND.3\.0\b/i],
        "CC-BY-NC-ND-4.0" => [/\bCC.BY.NC.ND.4\.0\b/i],
        "CDDL-1.0"      => [/\bCDDL[-|_|\s]?v?1\.0\b/i, /\bCDDL[-|_|\s]?v?1\b/i, /^CDDL$/i,
                            /\bCDDL\s+LICEN[C|S]E\b/i,
                            /\bCOMMON\sDEVELOPMENT\sAND\sDISTRIBUTION\sLICENSE\b/i
                           ],
        "CECILL-B"      => [/\bCECILL[-|_|\s]?B\b/i],
        "CECILL-C"      => [/\bCECILL[-|_|\s]?C\b/i],
        "CECILL-1.0"    => [
                            /\bCECILL[-|\s|_]?v?1\.0\b/i,  /\bCECILL[-|\s|_]?v?1\b/i,
                            /\ACECILL\s?\z/i, /\bCECILL\s+v?1\.2\b/i,
                            /^http:\/\/www\.cecill\.info\/licences\/Licence_CeCILL-C_V1-en.html$/i,
                            /\bhttp:\/\/www\.cecill\.info\b/i
                           ],
        "CECILL-2.1"    => [
                            /\bCECILL[-|_|\s]?2\.1\b/i, /\bCECILL[\s|_|-]?v?2\b/i,
                            /\bCECILL\sVERSION\s2\.1\b/i
                           ],
        "CPL-1.0"       => [
                              /\bCPL[-|\s|_]?v?1\.0\b/i, /\bCPL[-|\s|_]?v?1\b/i,
                              /\bCommon\s+Public\s+License\b/i, /\ACPL\s*\z/i
                            ],
        "CPAL-1.0"      => [
                              /\bCommon\sPublic\sAttribution\sLicense\s1\.0\b/i,
                              /[\(]?\bCPAL\b[\)]?/i
                            ],
        "CUSTOM"        => [ /\bCUSTOM\s+LICENSE\b/i ],
        "DBAD"          => [
                            /\bDONT\sBE\sA\sDICK\b/i, /\ADBAD\s*\z/i,
                            /\bdbad[-|\s|\_]license\b/i, /\ADBAD-1\s*\z/i,
                            /\ADBAP\b/i,
                            /\bhttps?:\/\/www\.dbad-license\.org[\/]?\b/i
                            ],
        "D-FSL-1.0"     => [
                              /\bD-?FSL[-|_|\s]?v?1\.0\b/i, /\bD-?FSL[-|\s|_]?v?1\b/,
                              /\bGerman\sFREE\sSOFTWARE\b/i,
                              /\bDeutsche\sFreie\sSoftware\sLizenz\b/i
                            ],
        "ECL-1.0"       => [ /\bECL[-|\s|_]?v?1\.0\b/i, /\bECL[-|\s|_]?v?1\b/i ],
        "ECL-2.0"       => [
                            /\bECL[-|\s|_]?v?2\.0\b/i, /\bECL[-|\s|_]?v?2\b/i,
                            /\bEDUCATIONAL\s+COMMUNITY\s+LICENSE[,]?\sVERSION\s2\.0\b/i
                           ],
        "EFL-1.0"       => [/\bEFL[-|\s|_]?v?1\.0\b/i, /\bEFL[-|\s|_]?v?1\b/i ],
        "EFL-2.0"       => [
                            /\bEFL[-|\s|_]?v?2\.0\b/i,  /\bEFL[-|\s|_]?v?2\b/i,
                            /\bEiffel\sForum\sLicense,?\sversion\s2/i,
                            /\bEiffel\sForum\sLicense\s2(?!\.)\b/i,
                            /\bEiffel\sForum\sLicense\b/i
                           ],
        "EPL-1.0"       => [
                            /\bEPL[-|\s|_]?v?1\.0\b/i, /\bEPL[-|\s|_]?v?1\b/i,
                            /\bECLIPSE\s+PUBLIC\s+LICENSE\s+[v]?1\.0\b/i,
                            /\bECLIPSE\s+PUBLIC\s+LICENSE\b/i,
                            /^ECLIPSE$/i, /\AEPL\s*\z/
                           ],
        "ESA-1.0"       => [
                            /\bESCL\s+[-|_]?\sType\s?1\b/,
                            /\bESA\sSOFTWARE\sCommunity\sLICENSE.+TYPE\s?1\b/i
                           ],
        "EUPL-1.0"      => [/\b[\(]?EUPL[-|\s]?v?1\.0[\)]?\b/i],
        "EUPL-1.1"      => [
                            /\b[\(]?EUPL[-|\s]?v?1\.1[\)]?\b/i,
                            /\bEUROPEAN\s+UNION\s+PUBLIC\s+LICENSE\s+1\.1\b/i,
                            /\bEuropean\sUnion\sPublic\sLicense\b/i,
                            /\bEUPL\s+V?\.?1\.1\b/i, /\AEUPL\s*\z/i
                           ],
        "Fair"          => [ /\bFAIR\s+LICENSE\b/i, /\AFair\s*\z/i],
        "FreeType"      => [ /\bFreeType\s+LICENSE\b/i],
        "GFDL-1.0"      => [
                            /\bGNU\sFree\sDocumentation\sLicense\b/i,
                            /\b[\(]?FDL[\)]?\b/
                           ],
        "GPL-1.0"       => [
                            /\bGPL[-|\s|_]?v?1\.0\b/i, /\bGPL[-|\s|_]?v?1\b/i,
                            /\bGNU\sPUBLIC\sLICEN[S|C]E\sv?1\b/i
                           ],
        "GPL-2.0"       => [
                            /\bGPL[-|\s|_]?v?2\.0/i, /\bGPL[-|\s|_]?v?2\b/i, /\bGPL\s+[v]?2\b/i,
                            /\bGNU\s+PUBLIC\s+LICENSE\s+v?2\.0\b/i,
                            /\bGNU\s+PUBLIC\s+License\sV?2\b/i,
                            /\bGNU\spublic\slicense\sversion\s2\b/i,
                            /\bGNU\sGeneral\sPublic\sLicense\sv?2\.0\b/i,
                            /\bGNU\sPublic\sLicense\s>=2\b/i,
                            /\bGNU\s+GPL\s+v2\b/i, /^GNUv?2\b/i, /^GLPv2\b/,
                            /\bWhatever\slicense\sPlone\sis\b/i
                           ],
        "GPL-3.0"       => [
                            /\bGNU\s+GENERAL\s+PUBLIC\s+License\s+[v]?3\b/i,
                            /\bGNU\s+General\s+Public\s+License[\,]?\sVersion\s3[\.0]?\b/i,
                            /\bGNU\sPublic\sLicense\sv?3\.0\b/i,
                            /\bGNU\s+PUBLIC\s+LICENSE\s+v?3\b/i,
                            /\bGnu\sPublic\sLicense\sversion\s3\b/i,
                            /\bGNU\sGeneral\sPublic\sLicense\sversion\s?3\b/i,
                            /\bGPL[-|\s|_]?v?3\.0\b/i, /\bGPL[-|\s|_]?v?[\.]?3\b/i, /\bGPL\s+3\b/i,
                            /\bGNU\s+PUBLIC\s+v3\+?\b/i,
                            /\bGNUGPL[-|\s|\_]?v?3\b/i, /\bGNU\s+PL\s+[v]?3\b/i,
                            /\bGLPv3\b/i, /\bGNU3\b/i, /GPvL3/i, /\bGNU\sGLP\sv?3\b/i,
                            /\AGNU\sGENERAL\sPUBLIC\sLICENSE\s*\z/i, /\A[\(]?GPL[\)]?\s*\z/i
                           ],

        "IDPL-1.0"      => [
                            /\bIDPL[-|\s|\_]?v?1\.0\b/,
                            /\bhttps?:\/\/www\.firebirdsql\.org\/index\.php\?op=doc\&id=idpl\b/i
                           ],
        "IPL-1.0"       => [/\bIBM\sOpen\sSource\sLicense\b/i, /\bIBM\sPublic\sLicen[s|c]e\b/i],
        "ISC"           => [/\bISC\s+LICENSE\b/i, /\b[\(]?ISCL[\)]?\b/i, /\bISC\b/i,
                            /\AICS\s*\z/i],
        "JSON"          => [/\bJSON\s+LICENSE\b/i],
        "KINDLY"        => [/\bKINDLY\s+License\b/i],
        "LGPL-2.0"      => [
                            /\bLGPL[-|\s|_]?v?2\.0\b/i, /\bLGPL[-|\s|_]?v?2(?!\.)\b/i,
                            /\bLesser\sGeneral\sPublic\sLicense\sv?2(?!\.)\b/i,
                            /\bLPGL[-|\s|\_]?v?2(?!\.)\b/i
                           ],
        "LGPL-2.1"      => [
                            /\bLGPL[-|\s|_]?v?2\.1\b/i,
                            /\bLesser\sGeneral\sPublic\sLicense\s+\(LGPL\)\s+Version\s+2\.1\b/i,
                            /\bLESSER\sGENERAL\sPUBLIC\sLICENSE[\,]?\sVersion\s2\.1[\,]?\b/i,
                            /\bLESSER\sGENERAL\sPUBLIC\sLICENSE[\,]?\sv?2\.1\b/i
                           ],
        "LGPL-3.0"      => [/\bLGPL[-|\s|_]?v?3\.0\b/i, /\bLGPL[-|\s|_]?v?3[\+]?\b/i,
                            /\bLGLP[\s|-|v]?3\.0\b/i, /^LPLv3\s*$/, /\bLPGL[-|\s|_]?v?3[\+]?\b/i,
                            /\bLESSER\s+GENERAL\s+PUBLIC\s+License\s+[v]?3\b/i,
                            /\bLesser\sGeneral\sPublic\sLicense\sv?\.?\s+3\.0\b/i,
                            /\bhttps?:\/\/www\.gnu\.org\/copyleft\/lesser.html\b/i,
                            /\bLESSER\sGENERAL\sPUBLIC\sLICENSE\sVersion\s3\b/i,
                            /\bLesser\sGeneral\sPublic\sLicense[\,]?\sversion\s3\.0\b/i,
                            /\bLESSER\sGENERAL\sPUBLIC\sLICENSE.+?version\s?3/i,
                            /\A[\(]?LGPL[\)]?\s*\z/i
                           ],
        "MirOS"         => [/\bMirOS\b/i],
        "MIT"           => [
                            /\bMIT\s+LICEN[S|C]E\b/i, /\AMITL?\s*\z/i, /\bEXPAT\b/i,
                            /\bMIT[-|\_]LICENSE\.\w{2,8}\b/i, /^MTI\b/i,
                            /\bMIT[-|\s|\_]?v?2\.0\b/i, /\AM\.I\.T[\.]?\s*\z/,
                            /\bMassachusetts-Institute-of-Technology-License/i
                           ],
        "MITNFA"        => [/\bMIT\s\+no\-false\-attribs\slicense\b/i],
        "MPL-1.0"       => [
                            /\bMPL[-|\s|\_]?v?1\.0\b/i, /\bMPL[-|\s|\_]?v?1(?!\.)\b/i,
                           /\bMozilla\sPublic\sLicense\sv?1\.0\b/i,
                           ],
        "MPL-1.1"       => [
                            /\bMozilla.Public.License\s+v?1\.1\b/i,
                            /\bMPL[-|\s|\_]?v?1\.1\b/i,
                           ],
        "MPL-2.0"       => [
                            /\bMPL[-|\s|\_]?v?2\.0\b/i, /\bMPL[-|\s|\_]?v?2\b/i,
                            /\bMOZILLA\s+PUBLIC\s+LICENSE\s+2\.0\b/i,
                            /\bMozilla\sPublic\sLicense[\,]?\s+v?[\.]?\s*2\.0\b/i,
                            /\bMOZILLA\s+PUBLIC\s+LICENSE[,]?\s+version\s+2\.0\b/i,
                            /\bMozilla\s+v?2\.0\b/i,
                            /\b[\(]?MPL\s+2\.0[\)]?\b/, /\bMPL\b/i,
                            /\AMozilla\sPublic\sLicense\s*\z/i
                           ],
        "MS-PL"         => [/\bMS-?PL\b/i],
        "MS-RL"         => [/\bMS-?RL\b/i, /\bMSR\-LA\b/i],
        "ms_dotnet"     => [/\bMICROSOFT\sSOFTWARE\sLICENSE\sTERMS\b/i],
        "NASA-1.3"      => [/\bNASA[-|\_|\s]?v?1\.3\b/i,
                            /\bNASA\sOpen\sSource\sAgreement\sversion\s1\.3\b/i],
        "NCSA"          => [/\bNCSA\s+License\b/i, /\bIllinois\/NCSA\sOpen\sSource\b/i, /\bNCSA\b/i ],
        "NGPL"          => [/\bNGPL\b/i],
        "NOKIA"         => [/\bNokia\sOpen\sSource\sLicense\b/i],
        "NPL-1.1"       => [/\bNetscape\sPublic\sLicense\b/i, /\b[(]?NPL[\)]?\b/i],

        "NPOSL-3.0"     => [/\bNPOSL[-|\s|\_]?v?3\.0\b/i, /\bNPOSL[-|\s|\_]?v?3\b/],
        "OFL-1.0"       => [/\bOFL[-|\s|\_]?v?1\.0\b/i, /\bOFL[-|\s|\_]?v?1(?!\.)\b/i,
                            /\bSIL\s+OFL\s+1\.0\b/i, /\ASIL\sOFL\s*\z/i ],
        "OFL-1.1"       => [
                            /\bOFL[-|\s|\_]?v?1\.1\b/i, /\bSIL\s+OFL\s+1\.1\b/i,
                            /\bSIL\sOpen\sFont\sLicense\b/i, /\bSIL\sOFL\s1\.1\b/i,
                            /\bOpen\sFont\sLicense\b/i                         ],

        "OSL-1.0"       => [/\bOSL[-|\s|\_]?v?1\.0\b/i, /\b\OSL[-|\s|\_]?v?1(?!\.)\b/i],
        "OSL-2.0"       => [/\bOSL[-|\s|\_]?v?2\.0\b/i, /\bOSL[-|\s|\_]?v?2(?!\.)\b/i],
        "OSL-2.1"       => [/\bOSL[-|\s|\_]?v?2\.1\b/i],
        "OSL-3.0"       => [
                            /\bOSL[-|\s|\_]?v?3\.0\b/i, /\bOSL[-|\s|\_]?v?3(?!\.)\b/i,
                            /\bOpen\sSoftware\sLicen[c|s]e\sv?3\.0\b/i,
                            /\bOSL[-|\s|\_]?v?\.?3\.[0|O]\b/i,
                            /\bOpen\sSoftware\sLicense\sversion\s3\.0\b/i,
                            /\AOSL\s*\z/i, /\bOpen-Software-License/i,
                            /\b[\(]?OSL[\)]?\s+v\s+3\.0\b/i
                           ],

        "PHP-3.0"       => [/^PHP\s?\z/i, /\bPHP\sLicense\s3\.0\b/i, /\APHP[-|\s]LICEN[S|C]E\s*\z/i],
        "PHP-3.01"      => [/\bPHP\sLicense\sversion\s3\.0\d\b/i],
        "PIL"           => [/\bStandard\sPIL\sLicense\b/i, /\APIL\s*\z/i],
        "PostgreSQL"    => [/\bPostgreSQL\b/i],
        "Public Domain" => [/\bPublic\s+Domain\b/i],
        "Python-2.0"    => [
                            /\bPython[-|\s|\_]?v?2\.0\b/i, /\bPython[-|\s|\_]?v?2(?!\.)\b/i,
                            /\bPSF[-|\s|\_]?v?2\b/i, /\bPSFL\b/i, /\bPSF\b/i,
                            /\bPython\s+Software\s+Foundation\b/i,
                            /\APython\b/i, /\bPSL\b/i, /\bSAME\sAS\spython2\.3\b/i,
                            /\bhttps?:\/\/www\.opensource\.org\/licenses\/PythonSoftFoundation\.php\b/i,
                            /\bhttps?:\/\/opensource\.org\/licenses\/PythonSoftFoundation\.php\b/i
                           ],
        "Repoze"        => [/\bRepoze\sPublic\sLicense\b/i],
        "RPL-1.1"       => [/\bRPL[-|\s|_]?v?1\.1\b/i, /\bRPL[-|\s|_]?v?1(?!\.)\b/i],
        "RPL-1.5"       => [
                            /\bRPL[-|\s|_]?v?1\.5\b/i, /\ARPL\s*\z/i,
                            /\bhttps?:\/\/www\.opensource\.org\/licenses\/rpl\.php\b/i
                           ],
        "Ruby"          => [/\bRUBY\sLICEN[S|C]E\b/i, /\ARUBY\b/i, /\bRUBY\'s\b/i],
        "QPL-1.0"       => [/\bQPL[-|\s|_]?v?1\.0\b/i,
                            /\bQT\sPublic\sLicen[c|s]e\b/i,
                            /\bPyQ\sGeneral\sLicense\b/i],
        "Sleepycat"     => [/\bSleepyCat\b/i],
        "SPL-1.0"       => [
                            /\bSPL[-|\_|\s]?v?1\.0\b/i, /\bSun\sPublic\sLicense\b/i
                           ],
        "W3C"           => [/\bW3C\b/i],
        "OpenSSL"       => [/\bOPENSSL\b/i],
        "Unicode-TOU"   => [/\AUnicode-TOU[\s|\/|-]/i],
        "UPL-1.0"       => [/\bUniversal\sPermissive\sLicense\b/i],
        "Unlicense"     => [
                            /\bUNLI[C|S]EN[S|C]E\b/i, /\AUnlicen[s|c]ed\s*\z/i, /^go\sfor\sit\b/i,
                            /^Undecided\b/i,
                            /\bNO\s+LICEN[C|S]E\b/i, /\bNON[\s|-|\_]?LICENSE\b/i
                           ],
        "Whiskeyware"   => [/\bWH?ISKEY[-|\s|\_]?WARE\b/i],
        "WTFPL"         => [
                            /\bWTF[P|G]?L\b/i, /\bWTFPL[-|v]?2\b/i, /^WTF\b/i, /\AWTFP\s*\z/i,
                            /\bDo\s+whatever\s+you\s+want\b/i, /\bDWTFYW\b/i, /\AWTPFL\s*\z/i,
                            /\bDo\s+What\s+the\s+Fuck\s+You\s+Want\b/i, /\ADWTFYWT\s*\z/i,
                            /\ADo\sWHATEVER\b/i, /\ADWYW\b/i, /\bDWTFYWTP\b/i,
                            /\ADWHTFYWTPL\s*\z/i, /\AWhatever\s*\z/i,
                            /\bDO\s(THE\s)?FUCK\sWHAT\sYOU\sWANT\b/i
                           ],
        "WXwindows"     => [/\bwxWINDOWS\s+LIBRARY\sLICEN[C|S]E\b/i, /\AWXwindows\s*\z/i],
        "X11"           => [/\bX11\b/i],
        "Zend-2.0"      => [/\bZend\sFramework\b/i],
        "ZPL-1.1"       => [/\bZPL[-|\s|\_]?v?1\.1\b/i, /\bZPL[-|\s|\_]?v?1(?!\.)\b/i,
                            /\bZPL[-|\s|\_]?1\.0\b/i],
        "ZPL-2.1"       => [
                            /\bZPL[-|\s|\/|_|]?v?2\.1\b/i, /\bZPL[-|\s|_]?v?2(?!\.)\b/i,
                            /\bZPL\s+2\.\d\b/i, /\bZOPE\s+PUBLIC\s+LICENSE\b/i,
                            /\bZPL\s?$/i
                           ],
        "zlib-acknowledgement" => [/\bZLIB[\/|-|\s]LIBPNG\b/i],
        "ZLIB"          => [/\bZLIB(?!\-|\/)\b/i]

      }
    end

  end
end
