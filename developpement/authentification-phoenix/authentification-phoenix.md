---
title: "Authentification avec Phoenix"
date: "2021-03-13T19:04:11-05:00"
updated: "2021-03-17T10:28:23-04:00"
author: "C. Boyer"
license: "Creative Commons BY-SA-NC 4.0"
website: "https://cboyer.github.io"
category: "Développement"
keywords: [Elixir, Phoenix, Plug, authentification, session]
abstract: "Authentification avec Phoenix"
---


## Initialisation du projet

Le soin est laissé au lecteur d'avoir un environnement Elixir/PostgreSQL fonctionnel.
Il est toujours préférable d'utiliser la dernière version de Phoenix, pour une mise à jour:
```Bash
mix local.phx
```

Créer le projet
```Bash
mix phx.new app_test
cd app_test
```

Paramétrer les informations de connexion à la base de données dans `config/dev.exs`
```Elixir
config :test_bd, AppTest.Repo,
  username: "postgres",
  password: "postgres",
  database: "app_test",
  hostname: "localhost",
  show_sensitive_data_on_connection_error: true,
  pool_size: 10
```

Initialiser Ecto qui va créer la base de données si nécessaire
```Bash
mix ecto.create
```

Création du contexte `Accounts`, du module `User` et de la table `users` avec ses colonnes:
```Bash
mix phx.gen.context Accounts User users username:string:unique password:string
mix ecto.migrate
```

Ajustement de la table `users` avec une migration Ecto pour insérer automatiquement `inserted_at` et `updated_at`:
Ceci va nous permettre plus tard de faire des insertions sans nous préoccuper de ces deux colonnes qui ont une contrainte "non nulle".
```Bash
mix ecto.gen.migration alter_users_table
    * creating priv/repo/migrations/20210312192247_alter_users_table.exs
```

Contenu de la migration:
```Elixir
defmodule AppTest.Repo.Migrations.AlterUsersTable do
  use Ecto.Migration

  def change do
    alter table(:users) do
    	modify :inserted_at, :utc_datetime, default: fragment("NOW()")
    	modify :updated_at, :utc_datetime, default: fragment("NOW()")
    end
  end
end
```

Appliquer les changements (création du schéma et migrations):
```Bash
mix ecto.migrate
```

Pour ne pas stocker les mot de passe en clair nous allons utiliser une fonction de hashage.
Ajouter une fonction de hashage `hash_password/1` dans le contrôleur `Accounts`, `lib/app_test/accounts.ex`.
Également ajouter une fonction `logged?/1` pour vérifier si l'utilisateur est connecté en vérifiant la présence de son ID en session:
```Elixir
def hash_password(password) when is_nil(password), do: ""
def hash_password(password) when password == "",   do: ""
def hash_password(password) do
    :crypto.hash(:sha256, password)
    |> Base.encode16()
    |> String.downcase()
end


defp logged?(conn) do      
    case Plug.Conn.get_session(conn, :user_id) do
        nil ->
            false
        "" ->
            false
        _user_id ->
            true
    end
end
```

> Note: le choix de SHA256 pour `hash_password/1` permet de se passer de librairies externes (cas de Bcrypt). Il est également possible de combiner plusieurs méthodes de hashage (plusieurs passe) pour renforcer la sécurité.

Démarrer l'application en mode interactif avec iEX
```Bash
iex -S mix phx.server
```

Ajouter un utlisateur dans la base de données avec Ecto depuis iEX:
```Elixir
alias AppTest.Accounts.User
AppTest.Repo.insert_all(User, [[id: 0, username: "adm", password: AppTest.Accounts.hash_password("admin")]])
```

On vérifie que l'utilisateur est bien présent avec `Repo.get_by`:
```Elixir
AppTest.Repo.get_by(User, username: "adm", password: AppTest.Accounts.hash_password("admin"))


%AppTest.Accounts.User{
  __meta__: #Ecto.Schema.Metadata<:loaded, "users">,
  id: 0,
  inserted_at: ~N[2021-03-13 14:29:48],
  password: "8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918",
  updated_at: ~N[2021-03-13 14:29:48],
  username: "adm"
}
```


## Considérations de sécurité

Habituellement le mécanisme d'authentification consiste à:

1. vérifier le couple nom d'utilisateur/mot de passe en base de données pour récupérer l'identifiant unique de l'utilisateur `user_id`
2. stocker `user_id` en session.
3. vérifier la présence de `user_id` en session lors de l'accès à une page protégée
4. détruire la session lors de la déconnexion


Phoenix conserve par défaut les données de session en clair dans un cookie `_app_test_key` avec `put_session/3`. 
Définir/vérifier `secret_key_base` dans `config/config.exs` (générée aléatoirement à la création du projet).
Activer le chiffrement des cookies avec `:encryption_salt` dans `@session_options` du fichier `lib/process_doc_web/endpoint.ex`:
```Elixir
# Set :encryption_salt if you would also like to encrypt it.
@session_options [
  store: :cookie,
  key: "_app_test_key",
  signing_salt: "Eswl2Dv0",
  encryption_salt: "AjouterLeSaltIci"
]
```

### Exemple de cookie non chiffré

Si le chiffrement n'est pas activé, on s'expose au risque d'un faux cookie contenant un `user_id` qui va nous permettre d'accéder aux pages protégées sans avoir été authentifié au préalable.
Exemple de cookie généré avec `put_session/3` sans chiffrement:
```Elixir
cookie = "SFMyNTY.g3QAAAACbQAAAAtfY3NyZl90b2tlbm0AAAAYcGRUNzdBQzZJa05BOXo1QlB6V2JWMVJubQAAAAd1c2VyX2lkYQA.OOA1nbXcTc7Hj8ijSuYS4WikxRPeKQZ2y3KvywWdDKE"
```

Ce cookie peut être décodé avec la fonction suivante:
```Elixir
def decode_cookie(cookie) do
    [_, payload, _] = String.split(cookie, ".", parts: 3)
    {:ok, encoded_term } = Base.url_decode64(payload, padding: false)
    :erlang.binary_to_term(encoded_term)
end
```

Ce qui donne:
```Elixir
%{"_csrf_token" => "pdT77AC6IkNA9z5BPzWbV1Rn", "user_id" => 0}
```

> Note: une autre solution pour éviter cette problématique est d'utiliser `Phoenix.Token.sign` avant d'utiliser `put_session/3`, ou le stockage des sessions en mémoire (ETS).




## Page protégée

Créer une page se fait en quatre étapes:

1. définir les routes dans lib/app_test_web/router.ex
2. un contrôleur dans lib/app_test_web/controllers/
3. une vue dans lib/app_test_web/views/
4. un template dans lib/app_test_web/templates/NOM_VUE/


Ajouter une route `/hello` dans le routeur `lib/app_test_web/router.ex`:
```Elixir
scope "/", AppTestWeb do
    pipe_through :browser

    #Méthode    URL         Contrôleur         Fonction appelée
    get         "/hello",   HelloController,   :index
end
```

Créer un contrôleur `HelloController` dans `lib/app_test_web/controllers/hello_controller.ex`.
```Elixir
defmodule AppTestWeb.HelloController do
    use AppTestWeb, :controller

    def index(conn, _params) do

        #Si l'utilisateur est authentifié, on affiche la page
        if AppTest.Accounts.logged?(conn) do
            render(conn, "hello.html", _params)

        #Sinon on redirige vers le formulaire
        else
            conn
            |> redirect(to: Routes.authentication_path(conn, :index))
            |> halt()
        end
    end
end
```

Créer une vue `HelloView` dans `lib/app_test_web/views/hello_view.ex`
```Elixir
defmodule AppTestWeb.HelloView do
    use AppTestWeb, :view
end
```

Créer un template `hello` dans `lib/app_test_web/templates/hello/hello.html.eex`.
```HTML
<div style="text-align: center;">
    Hello! <br />
    <%= button("Se déconnecter", to: "/logout", method: :get, class: "btn") %>
</div>
```



## Page d'authentification

Ajouter les trois routes vers le contrôleur `AuthenticationController` dans le routeur `lib/app_test_web/router.ex`:
```Elixir
scope "/", AppTestWeb do
    pipe_through :browser

    #Méthode    URL         Contrôleur                  Fonction appelée
    get         "/hello",   HelloController,            :index
    get         "/login",   AuthenticationController,   :index
    get         "/logout",  AuthenticationController,   :logout
    post        "/login",   AuthenticationController,   :login
end
```

Créer un contrôleur `AuthenticationController` dans `lib/app_test_web/controllers/authentication_controller.ex`.
```Elixir
defmodule AppTestWeb.AuthenticationController do
    use AppTestWeb, :controller

    #Fonction index appelée depuis le routeur (GET sur /login)
    def index(conn, _params) do

        #Si l'utilisateur est authentifié, on redirige vers la page protégée
        if AppTest.Accounts.logged?(conn) do
            conn
            |> redirect(to: Routes.hello_path(conn, :index))
            |> halt()

        #Sinon on affiche le formulaire d'authentification
        else
            render(conn, "login.html")
        end
    end


    #Fonction login appelée lors de la soumission du formulaire (POST sur /login)
    def login(conn, params) do


        #Vérifie que chaque paramètre du formulaire est bien transmis
        with {:ok, username} <- Map.fetch(params, "username"),
             {:ok, password} <- Map.fetch(params, "password")
        do

            #Vérifie le login/mot de passe dans la base de données
            current_user = AppTest.Accounts.User
                        |> AppTest.Repo.get_by(username: username, password: AppTest.Accounts.hash_password(password))

            #Si aucun utilisateur n'a été trouvé, on affiche le message d'erreur
            if is_nil(current_user) do
                conn
                |> put_flash(:error, "Nom d'utilisateur ou mot de passe incorrect.")
                |> render("login.html")

            #Sinon on stock son ID en session et on redirige vers la page protégée
            else
                conn
                |> put_session(:user_id, current_user.id)
                |> redirect(to: Routes.hello_path(conn, :index))
                |> halt()
            end

        #Si un champ du formulaire est manquant
        else
            :error ->
                conn
                |> put_flash(:error, "Nom d'utilisateur ou mot de passe incorrect.")
                |> render("login.html")
        end
    end


    #Fonction authentication appelée lors de la déconnexion (GET sur /logout)
    def logout(conn, _params) do
        conn
        |> clear_session()
        |> put_flash(:info, "Vous êtes déconnecté.")
        |> redirect(to: Routes.authentication_path(conn, :index))
        |> halt()
    end
end
```

Créer une vue `AuthenticationView` dans `lib/app_test_web/views/authentication_view.ex`
```Elixir
defmodule AppTestWeb.AuthenticationView do
    use AppTestWeb, :view
end
```

Créer un template `login` dans `lib/app_test_web/templates/authentication/login.html.eex`:
```HTML
<div style="text-align: center;">
<%= form_for @conn, Routes.authentication_path(@conn, :index), [method: :post, name: :auth], fn f -> %>
    <%= text_input f, :username, class: "form-control", placeholder: "Login", required: true, style: "width: 300px; text-align:center;" %> <br />
    <%= password_input f, :password, class: "form-control", placeholder: "Mot de passe", required: true, style: "width: 300px; text-align:center;" %> <br />
    <%= submit "Se connecter" %>
<% end %>
</div>
```

## Standardiser l'authentification avec une Plug

La solution précédente implique de vérifier la présence de `user_id` en session dans chaque contrôleur et de rediriger le cas échéant. Cette solution devient fastidieuse si l'application contient de nombreuse pages.
Phoenix permet de standardiser le processus avec une Plug:

Créer une plug `Authentication` dans `lib/app_test_web/plugs/authentication.ex`:
```Elixir
defmodule AppTestWeb.Plugs.Authentication do
    import Plug.Conn
    import Phoenix.Controller, only: [redirect: 2, put_flash: 3]
    import Phoenix.HTML.Link, only: [link: 2]

    alias AppTestWeb.Router.Helpers, as: Routes

    def init(_params) do
    end

    def call(conn, _params) do

        #Redirige vers le formulaire si non authentifié
        if ! AppTest.Accounts.logged?(conn) do
            conn
            |> put_flash(:error, ["Vous devez être authentifié pour accéder à cette page. ", link("S'inscrire.", to: "/subscribe")])
            |> redirect(to: Routes.authentication_path(conn, :index)) #Alternative: redirect(to: "/login")
            |> halt()
        else
            conn
        end
    end
end
```

Créer un pipeline `:authenticated` qui contient la plug `Authentication` et un nouveau scope dans le routeur `lib/app_test_web/router.ex`.
Également déplacer la route `/hello` dans ce nouveau scope pour appliquer la plug. Les routes `/login` et `/logout` ne doivent pas figurer dans ce scope car elles doivent rester accessibles sans authentification.
```Elixir
pipeline :authenticated do
    plug AppTestWeb.Plugs.Authentication
end

scope "/", AppTestWeb do
    pipe_through [:browser, :authenticated]

    get     "/hello",   HelloController,            :index
end

scope "/", AppTestWeb do
    pipe_through :browser

    get     "/login",   AuthenticationController,   :index
    post    "/login",   AuthenticationController,   :login
    get     "/logout",  AuthenticationController,   :logout
end
```

Dès lors il n'est plus nécessaire de vérifier la session dans les contrôleurs des pages comme `HelloController` dans `lib/app_test_web/controllers/hello_controller.ex`:
```Elixir
defmodule AppTestWeb.HelloController do
    use AppTestWeb, :controller

    def index(conn, _params) do
        render(conn, "hello.html", _params)
    end
end
```



## Liens complémentaires

- [Phoenix.Token](https://hexdocs.pm/phoenix/Phoenix.Token.html)
- [Gestion d'autorisations avec Plug](https://whatdidilearn.info/2018/02/25/phoenix-authentication-and-authorization-using-plugs.html)
