---
title: "Elixir/Phoenix: fenêtre modale avec LiveComponent et hook JavaScript"
date: "2021-04-25T17:59:11-04:00"
updated: "2021-04-25T17:59:11-04:00"
author: "C. Boyer"
license: "Creative Commons BY-SA-NC 4.0"
website: "https://cboyer.github.io"
category: "Développement"
keywords: [Elixir,Phoenix,Liveview,LiveComponent,hooks,mix,iex]
abstract: "Utiliser un LiveComponent et un hook JavaScript pour ouvrir une fenêtre modale."
---


Notre page principale se compose d'une LiveView `window_live.ex`, d'un LiveComponent `modal_component.ex`.
L'idée est d'utiliser un LiveComponent qui affiche du contenu avec un évènement provenant de `window_live.ex` et se ferme avec un évènement provenant du client (via un hook JavaScript très simple sans eventHandler).

Ici `push_event/3` n'est pas utilisé dans le LiveView,  ni `handleEvent` et `addEventListener` dans le hook JavaScript. En effet nous utilisons `updated()` qui est exécuté lors d'un rafraîchissement d'un élément du DOM (ici notre LiveComponent qui contient la fenêtre modale). De plus il n'y a pas besoin d'utiliser la propriété CSS `display`.

Le LiveView `window_live.ex`:

```Elixir
defmodule MyAppWeb.WindowLive do
    use MyAppWeb, :live_view


    def render(assigns) do
        ~L"""
            <%= live_component @socket, MyAppWeb.ModalComponent, id: :modal %>
            <%= link "Ouvrir", to: "#", "phx-click": "openmodal", "phx-target": "#modal" %>
        """
    end

    def mount(_params, session, socket) do
        {:ok, socket
              |> assign(:modal, nil)
        }
    end

    #Évènement `closemodal` envoyé par le hook JavaScript (client) pour fermer la fenêtre modale (LiveComponent)
    def handle_event("closemodal", _params, socket) do

        #Modifie socket.assigns.modal et force MyAppWeb.ModalComponent à se rafraîchir
        send_update(MyAppWeb.ModalComponent, id: :modal, modal: nil)
        {:noreply, socket}
    end

    #Évènement `openmodal` qui permet le rafraîchissement du LiveComponent (avec un changement de valeur de `modal`)
    def handle_event("openmodal", _params, socket) do
        send_update(MyAppWeb.ModalComponent, id: :modal, modal: "test")
        {:noreply, socket}
    end

end
```

Le LiveComponent `modal_component.ex` qui affiche obligatoirement une `div` dont l'id est `modal` avec `phx-hook="ModalHook"`.
Il n'y a pas de contenu lorsque socket.assigns.modal == nil.
```Elixir
defmodule MyAppWeb.ModalComponent do
    use MyAppWeb, :live_component

    def render(assigns) do
      ~L"""
      <div id="modal" phx-hook="ModalHook">

        <%= if not is_nil(@modal) do %>

            <div id="modal-window" class="modal">
                <div class="modal-content">
                    <span class="close">&times;</span>
                    
                    Le contenu de la fenêtre modale.
                </div>
            </div>

        <% end %>
        </div>
      """
    end

    def mount(socket) do
        {:ok, socket
              |> assign(:modal, nil)
        }
    end
end
```

Le hook JavaScript dans `assets/js/app.js`:
```JavaScript
let Hooks = {};
Hooks.ModalHook = {
    //Exécuté lorsque le LiveComponent a été rafraîchi, pas besoin de handleEvent/addEventListener ni signaux.
    updated(){
        let self = this;
        var modal = document.getElementById("modal-window");

        //S'assure que la fenêtre modale possède un contenu (lorsque socket.assigns.modal != nil)
        if(modal !== null) {
            var span = document.getElementsByClassName("close")[0];

            //Un clique sur la croix: envoyer le signal `closemodal` à `window_live.ex`
            span.onclick = function() {
                self.pushEvent("closemodal", {});
            }

            //Un clique à l'extérieur de la fenêtre modale: envoyer le signal `closemodal` à `window_live.ex`
            window.onclick = function(event) {
                if (event.target == modal) {
                    self.pushEvent("closemodal", {});
                }
            }
        }
    }
}

let liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}, hooks: Hooks})
```

La partie CSS à jouter dans `priv/static/css/myapp.css` (pensez à inclure le fichier dans le layout `lib/my_app_web/templates/layout/root.html.leex`).
```CSS
.modal {
  position: fixed;
  z-index: 1;
  left: 0;
  top: 0;
  width: 100%;
  height: 100%; 
  overflow: auto;
  background-color: rgb(0,0,0);
  background-color: rgba(0,0,0,0.4);
}

.modal-content {
  background-color: #fefefe;
  margin: 15% auto;
  padding: 20px;
  border: 1px solid #888;
  width: 80%;
}

.close {
  color: #aaa;
  float: right;
  font-size: 28px;
  font-weight: bold;
  line-height:25px;
}

.close:hover,
.close:focus {
  color: black;
  text-decoration: none;
  cursor: pointer;
} 
```







## Liens complémentaires

- [Fenêtre modale avec CSS/JavaScript](https://www.w3schools.com/howto/howto_css_modals.asp)
- [LiveComponent](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveComponent.html)
- [Hooks JavaScript](https://hexdocs.pm/phoenix_live_view/js-interop.html)
