#![recursion_limit="256"]

#[macro_use]
extern crate helix;
extern crate fosslim;

use fosslim::index;
use fosslim::naive_tf;
use fosslim::finger_ngram;
use fosslim::document::Document;


ruby!{
    class IndexBuilder {
        def build_index(source_folder: String, target_path: String) -> Result<bool, String> {
            index::build_from_path(&source_folder)
                .and_then(|idx| index::save(&idx, &target_path))
                .map_err(|e| e.message.to_string())
        }
    }

    class Match {
        struct {
            label: String,
            score: f64
        }

        def initialize(helix, label: String, score: f64) {
            Match { helix, label, score }
        }

        def label(&self) -> &str {
            &self.label
        }

        def score(&self) -> f64 {
            self.score
        }
    }

    class TFRustMatcher {
        struct {
            model: fosslim::naive_tf::NaiveTFModel
        }

        def initialize(helix, index_path: String) {
            let index = index::load(&index_path).expect("Failed to load the index");
            let model = naive_tf::from_index(&index);

            TFRustMatcher { helix, model }
        }

        def match_text(&self, lic_txt: String, min_score: f64) -> Option<Match> {
            let doc = Document::new(0, "orig".to_string(), lic_txt);

            self.model.match_document(&doc).and_then(|score| {
                let the_score = score.score as f64;

                if min_score <= the_score {
                    Some(Match::new(score.label.unwrap_or("".to_string()), the_score))
                } else {
                    None
                }
            })
        }
    }

    class FingerprintMatcher {
        struct {
            model: fosslim::finger_ngram::FingerNgram
        }

        def initialize(helix, index_path: String) {
            let index = index::load(&index_path).expect("Failed to load the index");
            let model = finger_ngram::from_index(&index);

            FingerprintMatcher { helix, model }
        }

        def match_text(&self, lic_txt: String, min_score: f64) -> Option<Match> {
            let doc = Document::new(0, "orig".to_string(), lic_txt);

            self.model.match_document(&doc).and_then(|score| {
                let the_score = score.score as f64;

                if min_score <= the_score {
                    Some(Match::new(score.label.unwrap_or("".to_string()), the_score))
                } else {
                    None
                }
            })
        }
    }

}
