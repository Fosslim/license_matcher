require 'narray'
require 'tf-idf-similarity'
require 'msgpack'

module LicenseMatcher

  class TFRubyMatcher
    include Preprocess

    attr_reader :corpus, :model, :spdx_ids

    DEFAULT_INDEX_PATH = 'data/index.msgpack'
    DEFAULT_MIN_CONFIDENCE    = 0.9
    A_DOC_ROW = 3 # a array index to find the rows of indexed documents

    def initialize(index_path = DEFAULT_INDEX_PATH)
      spdx_ids, spdx_docs = read_corpus(index_path)

      @spdx_ids = spdx_ids
      @corpus = spdx_docs
      @model = TfIdfSimilarity::BM25Model.new(@corpus, :library => :narray)

      true
    end

    # matches given text with SPDX licenses and returns Match object
    # returns:
    #   match - Match {label: String, score: float}
    def match_text(text, min_confidence = DEFAULT_MIN_CONFIDENCE, is_processed_text = false)
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

      doc_id, best_score = dists.sort {|a,b| b[1] <=> a[1]}.first
      best_match = @model.documents[doc_id].id

      if best_score.to_f > min_confidence
        Match.new(best_match, best_score)
      else
        Match.new("", 0.0)
      end
    end

    def match_html(html_text, min_confidence = DEFAULT_MIN_CONFIDENCE)
      match_text(preprocess_html(html_text), min_confidence)
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

    # Reads the content of licenses from the pre-built index
    # NB! it is sensitive to the changes in the Fosslim/Index serialization
    def read_corpus(index_path)
      idx = MessagePack.unpack File.read index_path
      spdx_ids = []
      docs = []

      idx[A_DOC_ROW].to_a.each do |doc_row|
        _, spdx_id, content, _ = doc_row
        txt = preprocess_text content
        if txt
          spdx_ids << spdx_id
          docs << TfIdfSimilarity::Document.new(txt, :id => spdx_id)
        end
      end

      [spdx_ids, docs]
    end

  end
end
