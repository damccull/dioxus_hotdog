use dioxus::prelude::*;

use crate::backend::delete_favorite;

#[component]
pub fn Favorites() -> Element {
    let mut favorites = use_resource(crate::backend::list_dogs);
    let favorites_signal = favorites.suspend()?;

    rsx!(
        div {
            id: "favorites",
            div {
                id: "favorites-container",
                for (id, url) in favorites_signal().unwrap() {
                    div {
                        key: id,
                        class: "favorite-dog",
                        img { src: url }
                        button { onclick: move |_| async move {
                            delete_favorite(id).await;
                            favorites.restart();
                        },
                        id: "delete",
                        "❌" }
                    }
                }
            }
        },
    )
}
