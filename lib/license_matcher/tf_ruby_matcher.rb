require 'narray'
require 'tf-idf-similarity'
require 'json'

module LicenseMatcher

  class TFRubyMatcher
    include Preprocess

    attr_reader :corpus, :licenses, :model, :spdx_ids, :custom_ids, :id_spdx_idx

    DEFAULT_CORPUS_FILES_PATH = 'data/spdx_licenses/plain'
    CUSTOM_CORPUS_FILES_PATH  = 'data/custom_licenses' # Where to look up non SPDX licenses
    LICENSE_JSON_FILE         = 'data/spdx_licenses/licenses.json'


    def initialize(files_path = DEFAULT_CORPUS_FILES_PATH, license_json_file = LICENSE_JSON_FILE)
      spdx_ids, spdx_docs = read_corpus(files_path)
      custom_ids, custom_docs = read_corpus(CUSTOM_CORPUS_FILES_PATH)

      @licenses = spdx_ids + custom_ids
      @spdx_ids = spdx_ids
      @custom_ids = custom_ids
      @corpus = spdx_docs + custom_docs

      licenses_json_doc = read_json_file license_json_file
      raise("Failed to read licenses.json") if licenses_json_doc.nil?

      @model = TfIdfSimilarity::BM25Model.new(@corpus, :library => :narray)

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

    # converts downcases spdxID to case-sensitive SPDX-ID as it's in licenses.json
    def to_spdx_id(lic_id)
      @id_spdx_idx.fetch(lic_id.to_s.downcase, lic_id.upcase)
    end

    def match_text(text, n = 3, is_processed_text = false)
      return [] if text.to_s.empty?

      text = preprocess_text(text) if is_processed_text == false
      test_doc   = TfIdfSimilarity::Document.new(text, {:id => "test"})

      mat1 = @model.instance_variable_get(:@matrix)
      mat2 = doc_tfidf_matrix(test_doc)

      n_docs = @model.documents.size
      dists = []
      n_docs.times do |i|
        dists << [i, cos_sim(mat1[i, true], mat2)]
      end

      top_matches = dists.sort {|a,b| b[1] <=> a[1]}.take(n)

      # Translate doc numbers to id
      top_matches.reduce([]) do |acc, doc_id_and_score|
        doc_id, score = doc_id_and_score
        acc << [ @model.documents[doc_id].id.downcase, score ]
        acc
      end
    end

    def match_html(html_text, n = 3)
      match_text(preprocess_html(html_text), n)
    end

  #-- helpers


    # Transforms document into TF-IDF matrix used for comparition
    def doc_tfidf_matrix(doc)
      arr = Array.new(@model.terms.size) do |i|
        the_term = @model.terms[i]
        if doc.term_count(the_term) > 0
          #calc score only for words that exists in the test doc and the corpus of licenses
          model.idf(the_term) * model.tf(doc, the_term)
        else
          0.0
        end
      end

      NArray[*arr]
    end


    # Calculates cosine similarity between 2 TF-IDF vector
    def cos_sim(mat1, mat2)
      length = (mat1 * mat2).sum
      norm   = Math::sqrt((mat1 ** 2).sum) * Math::sqrt((mat2 ** 2).sum)

      ( norm > 0 ? length / norm : 0.0)
    end


    def read_json_file(file_path)
      JSON.parse(File.read(file_path), {symbolize_names: true})
    rescue
      log.info "Failed to read json file `#{file_path}`"
      nil
    end


    # Reads licenses content from the files_path and returns list of texts
    def read_corpus(files_path)
      file_names = get_license_names(files_path)

      docs = file_names.reduce([]) do |acc, file_name|
        content = File.read("#{files_path}/#{file_name}")
        txt = preprocess_text content
        if txt
          acc << TfIdfSimilarity::Document.new(txt, :id => file_name)
        else
          p "read_corpus: failed to encode content of corpus #{files_path}/#{file_name}"
        end

        acc
      end

      [file_names, docs]
    end


    def get_license_names(files_path)
      Dir.entries(files_path).to_a.delete_if {|name| ( name == '.' or name == '..' or name =~ /\w+\.py/i or name =~ /.DS_Store/i )}
    end

  end
end
