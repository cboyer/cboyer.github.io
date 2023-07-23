---
title: "Elixir et framework Phoenix: page simple"
date: "2020-10-28T17:13:11-04:00"
updated: "2020-10-28T17:13:11-04:00"
author: "C. Boyer"
license: "Creative Commons BY-SA-NC 4.0"
website: "https://cboyer.github.io"
category: "Développement"
keywords: [Elixir,Phoenix,Liveview,mix,iex]
abstract: "Le web avec Elixir et son framework Phoenix."
---

- [Installation de Phoenix](#installation)
- [Création d'un projet Phoenix élémentaire](#projetsimple)
- [Création d'une page "Test"](#pagetest)
- [Passer un paramètre](#parametre)
- [LiveView: actualiser les éléments d'une page sans la refaraîchir](#liveview)
- [LiveView et PubSub: communication entre differents clients](#pubsub)


## <a name="installation"></a>Installation de Phoenix
```Console
mix archive.install hex phx_new 1.5.4

Resolving Hex dependencies...
Dependency resolution completed:
New:
  phx_new 1.5.4
* Getting phx_new (Hex package)
All dependencies are up to date
Compiling 10 files (.ex)
Generated phx_new app
Generated archive "phx_new-1.5.4.ez" with MIX_ENV=prod
Are you sure you want to install "phx_new-1.5.4.ez"? [Yn] y
* creating /home/user/.mix/archives/phx_new-1.5.4
```

Dépendances systèmes à installer:
`inotify-tools` permet de bénéficier de la fonctionalité live-reload de Phoenix.
`erlang-parsetools` pour compiler l'application (lié à gettext).

```Console
sudo dnf install erlang-parsetools inotify-tools
```

## <a name="projetsimple"></a>Création d'un projet Phoenix élémentaire

Pour créer un nouveau projet Phoenix minimaliste sans base de données (Ecto) ni NodeJS (Webpack):
```Console
mix phx.new test_phoenix --no-webpack --no-ecto

* creating test_phoenix/config/config.exs
* creating test_phoenix/config/dev.exs
* creating test_phoenix/config/prod.exs
* creating test_phoenix/config/prod.secret.exs
* creating test_phoenix/config/test.exs
* creating test_phoenix/lib/test_phoenix/application.ex
* creating test_phoenix/lib/test_phoenix.ex
* creating test_phoenix/lib/test_phoenix_web/channels/user_socket.ex
* creating test_phoenix/lib/test_phoenix_web/views/error_helpers.ex
* creating test_phoenix/lib/test_phoenix_web/views/error_view.ex
* creating test_phoenix/lib/test_phoenix_web/endpoint.ex
* creating test_phoenix/lib/test_phoenix_web/router.ex
* creating test_phoenix/lib/test_phoenix_web/telemetry.ex
* creating test_phoenix/lib/test_phoenix_web.ex
* creating test_phoenix/mix.exs
* creating test_phoenix/README.md
* creating test_phoenix/.formatter.exs
* creating test_phoenix/.gitignore
* creating test_phoenix/test/support/channel_case.ex
* creating test_phoenix/test/support/conn_case.ex
* creating test_phoenix/test/test_helper.exs
* creating test_phoenix/test/test_phoenix_web/views/error_view_test.exs
* creating test_phoenix/lib/test_phoenix_web/controllers/page_controller.ex
* creating test_phoenix/lib/test_phoenix_web/templates/layout/app.html.eex
* creating test_phoenix/lib/test_phoenix_web/templates/page/index.html.eex
* creating test_phoenix/lib/test_phoenix_web/views/layout_view.ex
* creating test_phoenix/lib/test_phoenix_web/views/page_view.ex
* creating test_phoenix/test/test_phoenix_web/controllers/page_controller_test.exs
* creating test_phoenix/test/test_phoenix_web/views/layout_view_test.exs
* creating test_phoenix/test/test_phoenix_web/views/page_view_test.exs
* creating test_phoenix/lib/test_phoenix_web/gettext.ex
* creating test_phoenix/priv/gettext/en/LC_MESSAGES/errors.po
* creating test_phoenix/priv/gettext/errors.pot
* creating test_phoenix/priv/static/js/app.js
* creating test_phoenix/priv/static/css/app.css
* creating test_phoenix/priv/static/css/phoenix.css
* creating test_phoenix/priv/static/robots.txt
* creating test_phoenix/priv/static/js/phoenix.js
* creating test_phoenix/priv/static/images/phoenix.png
* creating test_phoenix/priv/static/favicon.ico

Fetch and install dependencies? [Yn] y
* running mix deps.get

We are almost there! The following steps are missing:
    $ cd test_phoenix

Start your Phoenix app with:
    $ mix phx.server

You can also run your app inside IEx (Interactive Elixir) as:
    $ iex -S mix phx.server
```


## <a name="pagetest"></a>Création d'une page "Test"

Organisation des éléments d'une page "Test" (la partie modèle est volontairement omise car nous n'utilisons pas de base de données):
```Text
Routeur        🠞 lib/test_phoenix_web/router.ex                      🠞 get "/test", TestController, :index
|> Controleur  🠞 lib/test_phoenix_web/controllers/test_controller.ex 🠞 TestPhoenixWeb.TestController
|> Vue         🠞 lib/test_phoenix_web/views/test_view.ex             🠞 TestPhoenixWeb.TestView
|> Template    🠞 lib/test_phoenix_web/templates/test/test.html.eex
```


Ajouter une nouvelle route dans `lib/test_phoenix_web/router.ex`:
```Elixir
defmodule TestPhoenixWeb.Router do
    use TestPhoenixWeb, :router

    pipeline :browser do
        plug :accepts, ["html"]
        plug :fetch_session
        plug :fetch_flash
        plug :protect_from_forgery
        plug :put_secure_browser_headers
    end

    pipeline :api do
        plug :accepts, ["json"]
    end

    scope "/", TestPhoenixWeb do
        pipe_through :browser

        get "/", PageController, :index

        #Page Test
        get "/test", TestController, :index
    end

    if Mix.env() in [:dev, :test] do
        import Phoenix.LiveDashboard.Router

        scope "/" do
        pipe_through :browser
        live_dashboard "/dashboard", metrics: TestPhoenixWeb.Telemetry
        end
    end
end
```

Créer un nouveau controleur dans `lib/test_phoenix_web/controllers/test_controller.ex`:
```Elixir
defmodule TestPhoenixWeb.TestController do
    use TestPhoenixWeb, :controller

    def index(conn, _params) do
        render(conn, "test.html")
    end
end
```

Créer la vue dans `lib/test_phoenix_web/views/test_view.ex`:
```Elixir
defmodule TestPhoenixWeb.TestView do
    use TestPhoenixWeb, :view
end
```

Puis le template `lib/test_phoenix_web/templates/test/test.html.eex`:
```HTML
<section class="phx-hero">
  <h1><%= gettext "Bienvenu sur %{name}!", name: "Phoenix" %></h1>
  <p>Page de test</p>
</section>
```

À noter que le template est inséré dans le layout `lib/test_phoenix_web/templates/layout/app.html.eex` grâce à la ligne `<%= @inner_content %>`.


## <a name="parametre"></a>Passer un paramètre à une page

Ajouter `get "/test/:message", TestController, :show` dans `lib/test_phoenix_web/router.ex`:
```Elixir
defmodule TestPhoenixWeb.Router do
    use TestPhoenixWeb, :router

    pipeline :browser do
        plug :accepts, ["html"]
        plug :fetch_session
        plug :fetch_flash
        plug :protect_from_forgery
        plug :put_secure_browser_headers
    end

    pipeline :api do
        plug :accepts, ["json"]
    end

    scope "/", TestPhoenixWeb do
        pipe_through :browser

        get "/", PageController, :index
        get "/test", TestController, :index
        
        #Gestion du paramètre
        get "/test/:message", TestController, :show
    end

    if Mix.env() in [:dev, :test] do
        import Phoenix.LiveDashboard.Router

        scope "/" do
        pipe_through :browser
        live_dashboard "/dashboard", metrics: TestPhoenixWeb.Telemetry
        end
    end
end
```

Définir la fonction `show` dans `lib/test_phoenix_web/controllers/test_controller.ex`:
```Elixir
defmodule TestPhoenixWeb.TestController do
    use TestPhoenixWeb, :controller

    def index(conn, _params) do
        render(conn, "test.html")
    end

    #Gestion du paramètre
    def show(conn, %{"message" => message}) do
        render(conn, "show.html", message: message)
    end
    
    #Autre possibilité avec pattern matching
    def show(conn, %{"message" => message} = params) do
        render(conn, "show.html", message: message)
    end
    
    #Avec plusieurs paramètres
    def show(conn, %{"message" => message}) do
        conn
        |> Plug.Conn.assign(:message, message)
        |> Plug.Conn.assign(:other, "other")
        |> render("show.html")
    end
    
    #Pour ne pas utiliser de vue/template:
    #def show(conn, %{"message" => message}) do
    #    html(conn, """
    #    <html>
    #        <head>
    #            <title>Paramètre</title>
    #        </head>
    #        <body>
    #        <p>Message: #{Plug.HTML.html_escape(message)}</p>
    #        </body>
    #    </html>
    #    """)
    #end
end
```

Créer le template `lib/test_phoenix_web/templates/test/show.html.eex`:
```HTML
<section class="phx-hero">
  <h2>Bienvenu sur <%= @message %>!</h2>
  <p><%= gettext "Bienvenu sur %{message}!", message: @message %></p>
</section>
```

Après avoir accédé à l'URL `http://localhost:4000/test/bonjour`on peut voir le paramètre affiché.
Dans la console IEx on peut observer les détails suivants:

```Console
[info] GET /test/bonjour
[debug] Processing with TestPhoenixWeb.TestController.show/2
  Parameters: %{"message" => "bonjour"}
  Pipelines: [:browser]
[info] Sent 200 in 450µs
```




## <a name="liveview"></a>LiveView: actualiser les éléments d'une page sans la refaraîchir

LiveView nécessite JetPack (dépendances NodeJS à ne pas exclure):
```Console
mix phx.new live_test --no-ecto --live
```

S'assurer de la présence de LiveView comme dépendance dans `mix.exs` (puis installer avec `mix deps.get`):
```Elixir
{:phoenix_live_view, "~> 0.14.7"}
```

Créer une entrée dans `live_test/lib/live_test_web/router.ex`:
```Elixir
live "/counter", CounterLive
```

Créer un module `CounterLive` dans `live_test/lib/live_test_web/live/counter_live.ex`:
```Elixir
defmodule LiveTestWeb.CounterLive do
    use LiveTestWeb, :live_view
    #use Phoenix.LiveView

    #Pour utiliser directement CounterView.render au lieu de LiveTestWeb.CounterView.render dans render/1:
    #alias LiveViewCounterWeb.CounterView 

    def render(assigns) do
        LiveTestWeb.CounterView.render("index.html", assigns)
    end
    
    #Pour ne pas utiliser de vue/template:
    #def render(assigns) do
    #~L"""
    #<div>
    #    <h1>The count is: <%= @val %></h1>
    #    <button phx-click="dec">-</button>
    #    <button phx-click="inc">+</button>
    #    <button phx-click="reset">Reset</button>
    #</div>
    #"""
    #end

    #Exécuté au chargement de la page, intialise la valeur à 0
    def mount(_params, _session, socket) do
        {:ok, assign(socket, :val, 0)}
    end

    #Exécuté sur l'évènement "inc": incrémente la valeur actuelle
    def handle_event("inc", _value, socket) do
        {:noreply, update(socket, :val, &(&1 + 1))}
    end

    #Exécuté sur l'évènement "dec": décrémente la valeur actuelle
    def handle_event("dec", _value, socket) do
        {:noreply, update(socket, :val, &(&1 - 1))}
    end
    
    #Exécuté sur l'évènement "reset": passe la valeur actuelle à 0
    def handle_event("reset", _value, socket) do
        {:noreply, update(socket, :val, &(&1 - &1))}
    end
end
```

Créer un template dans `live_test/lib/live_test_web/templates/counter/index.html.leex`:
```HTML
<div>
  <h1 phx-click="reset">The count is: <%= @val %></h1>
  <button phx-click="dec">-</button>
  <button phx-click="inc">+</button>
  <button phx-click="reset">Reset</button>
</div>
```

Créer une vue dans `live_test/lib/live_test_web/views/counter_view.ex`:
```Elixir
defmodule LiveTestWeb.CounterView do
    use LiveTestWeb, :view
end
```
![Rendu de la vue (inclue dans le layout)](liveview_counter.jpg "Rendu de la vue (inclue dans le layout)")



## <a name="pubsub"></a>LiveView et PubSub: communication entre differents clients

Pour qu'une valeur soit synchronisée entre tous les clients, nous allons utiliser le système PubSub.
Dès qu'un client modifie la valeur, elle sera transmise à tous les clients qui l'afficheront.

Ajouter la dépendance `phoenix_pubsub` dans `mix.exs` puis exécuter `mix deps.get`:
```Elixir
{:phoenix_pubsub, "~> 2.0"}
```

Ajouter le système PubSub dans l'arbre de supervision `live_test/lib/live_test/application.ex`:
```Elixir
def start(_type, _args) do
    children = [
        # Start the Telemetry supervisor
        LiveTestWeb.Telemetry,

        # Start the PubSub system
        {Phoenix.PubSub, name: LiveTest.PubSub},
        
        # Start the Endpoint (http/https)
        LiveTestWeb.Endpoint
        # Start a worker by calling: LiveTest.Worker.start_link(arg)
        # {LiveTest.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: LiveTest.Supervisor]
    Supervisor.start_link(children, opts)
end
```

Modification du controleur `CounterLive` dans `live_test/lib/live_test_web/live/counter_live.ex`:

```Elixir
defmodule LiveTestWeb.CounterLive do
    use LiveTestWeb, :live_view
    #use Phoenix.LiveView
    
    #Pour utiliser directement CounterView.render au lieu de LiveTestWeb.CounterView.render dans render/1:
    #alias LiveViewCounterWeb.CounterView 

    def render(assigns) do
        LiveTestWeb.CounterView.render("index.html", assigns)
    end

    #Inscription au topic "val_changes" et initialisation de la valeur à 0
    def mount(_params, _session, socket) do
        Phoenix.PubSub.subscribe(LiveTest.PubSub, "val_changes")
        {:ok, assign(socket, :val, 0)}
    end

    #Diffuse sur le topic "val_changes" la valeur incrémentée
    def handle_event("inc", _value, socket) do
        Phoenix.PubSub.broadcast(LiveTest.PubSub, "val_changes", socket.assigns[:val] + 1)
        {:noreply, socket}
    end

    #Diffuse sur le topic "val_changes" la valeur décrémentée
    def handle_event("dec", _value, socket) do
        Phoenix.PubSub.broadcast(LiveTest.PubSub, "val_changes", socket.assigns[:val] - 1)
        {:noreply, socket}
    end

    #Diffuse sur le topic "val_changes" la valeur décrémentée
    def handle_event("reset", _value, socket) do
        Phoenix.PubSub.broadcast(LiveTest.PubSub, "val_changes", 0)
        {:noreply, socket}
    end

    #Réception en provenance du topic "val_changes": Met à jour la valeur affichée avec celle reçue
    def handle_info(msg, socket) do
        #IO.inspect(msg)
        {:noreply, update(socket, :val, fn (_) -> msg end )}
    end
end
```



## Liens complémentaires

- [Installation de Phoenix](https://hexdocs.pm/phoenix/installation.html#phoenix)
- [Transite d'une requête à travers Phoenix](https://hexdocs.pm/phoenix/request_lifecycle.html#content)
- [Les contrôleurs](https://hexdocs.pm/phoenix/controllers.html#content)
- [LiveView](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html)
- [LiveView et LiveComponents](http://blog.pthompson.org/liveview-livecomponents-introduction)
- [Create a counter with Phoenix LiveView](https://dennisbeatty.com/how-to-create-a-counter-with-phoenix-live-view.html)
- [Phoenix PubSub](https://hexdocs.pm/phoenix_pubsub/Phoenix.PubSub.html)
