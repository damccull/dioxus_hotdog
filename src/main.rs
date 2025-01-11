pub mod backend;
pub mod components;

use crate::components::*;

use dioxus::prelude::*;

static CSS: Asset = asset!("/assets/main.css");

fn main() {
    dioxus::launch(App);
}

#[derive(Clone, PartialEq, Routable)]
enum Route {
    #[layout(NavBar)]
    #[route("/")]
    DogView,
    #[route("/favorites")]
    Favorites,
    #[route("/:..segments")]
    PageNotFound { segments: Vec<String> },
}

#[component]
fn App() -> Element {
    rsx! {
        document::Stylesheet {href: CSS}
        Router::<Route>{}
    }
}

#[component]
fn PageNotFound(segments: Vec<String>) -> Element {
    let segments = format!("{:?}", segments);
    rsx! {
        p { "Page Not Found"}
        p {"{segments}"}
    }
}

#[derive(Debug, serde::Deserialize)]
struct DogApi {
    message: String,
}
