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
            Match { helix, label: label, score: score}
        }

        def get_label(&self) -> &str {
            &self.label
        }

        def get_score(&self) -> f64 {
            self.score
        }
    }

    class TFRustMatcher {
        struct {
            index: fosslim::index::Index,
            model: fosslim::naive_tf::NaiveTFModel
        }

        def initialize(helix, index_path: String) {
            let idx = index::load(&index_path).expect("Failed to load the index");
            let mdl = naive_tf::from_index(&idx);

            TFRustMatcher { helix, index: idx, model: mdl }
        }

        def match_text(&self, lic_txt: String, min_score: f64) -> Match {
            let no_match = Match::new("".to_string(), 0.0) ;
            let doc = Document::new(0, "orig".to_string(), lic_txt);

            match self.model.match_document(&doc) {
                Some(score) => {
                    let the_score: f64 = score.score as f64;
                    if min_score <= the_score {
                        Match::new(score.label.unwrap_or("".to_string()), the_score)
                    } else {
                        no_match
                    }
                },
                None        => no_match
            }
        }
    }

    class FingerprintMatcher {
        struct {
            index: fosslim::index::Index,
            model: fosslim::finger_ngram::FingerNgram
        }

        def initialize(helix, index_path: String) {
            let idx = index::load(&index_path).expect("Failed to load the index");
            let mdl = finger_ngram::from_index(&idx);

            FingerprintMatcher { helix, index: idx, model: mdl}
        }

        def match_text(&self, lic_txt: String, min_score: f64) -> Match {
            let no_match = Match::new("".to_string(), 0.0);
            let doc = Document::new(0, "orig".to_string(), lic_txt);

            match self.model.match_document(&doc) {
                Some(score) => {
                    let the_score: f64 = score.score as f64;
                    if min_score <= the_score {
                        Match::new(score.label.unwrap_or("".to_string()), the_score)
                    } else {
                        no_match
                    }
                },
                None        => no_match
            }

        }
    }

}
