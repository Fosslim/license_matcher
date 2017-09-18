#[macro_use]
extern crate helix;
extern crate fosslim;

use fosslim::index;
use fosslim::naive_tf;
use fosslim::document::Document;

ruby!{
    class TFRustMatcher {
        struct {
            index: fosslim::index::Index,
            model: fosslim::naive_tf::NaiveTFModel
        }

        def initialize(helix, index_path: String) {
            let idx = index::load(&index_path).expect("Failed to read index");
            let mdl = naive_tf::from_index(&idx);

            TFRustMatcher { helix, index: idx, model: mdl }
        }

        def match_text(&self, lic_txt: String, min_score: f64) -> String {
            let no_match = "".to_string();
            let doc = Document::new(0, "orig".to_string(), lic_txt);

            match self.model.match_document(&doc) {
                Some(score) => {
                    if ( min_score > 0.0 ) & ( min_score <= score.score as f64 ) {
                        score.label.unwrap()
                    } else {
                        no_match
                    }
                },
                None        => no_match
            }
        }

        def build_index(source_folder: String, target_path: String) -> bool {
            match index::build_from_path(&source_folder) {
                Ok(idx) => index::save(&idx, &target_path).is_ok(),
                Err(_)  => false
            }
        }

    }
}
