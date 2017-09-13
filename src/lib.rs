#[macro_use]
extern crate helix;

ruby!{
    class LicenseMatcher {

        def match_text(lic_txt: String) -> String {
            println!("In near future i can do better than just printing: {}", lic_txt);

            return "Unknown".to_string();
        }

    }
}
