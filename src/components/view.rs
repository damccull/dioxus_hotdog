use dioxus::prelude::*;
use reqwest::Client;

use crate::{backend::save_dog, DogApi};

#[component]
pub fn DogView() -> Element {
    let mut img_src = use_resource(|| async move {
        let client = Client::builder().use_rustls_tls().build().unwrap();

        let url = client
            .get("https://dog.ceo/api/breeds/image/random")
            .send()
            .await
            .unwrap()
            .json::<DogApi>()
            .await
            .unwrap()
            .message;

        url
    });

    rsx! {
        div {
            id: "dogview",
            img { src: img_src.cloned().unwrap_or_default() }
        }
        div {
            id: "buttons",
            button { onclick: move |_| img_src.restart(), id:"skip", "skip"}
            button { onclick: move |_| async move {
                let current = img_src.cloned().unwrap();

                img_src.restart();

                save_dog(current).await;
            }, id:"save", "save"}
        }
    }
}
