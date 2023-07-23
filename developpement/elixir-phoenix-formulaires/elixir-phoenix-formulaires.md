---
title: "Elixir et framework Phoenix: formulaires et base de données"
date: "2020-11-06T18:03:11-05:00"
updated: "2020-11-06T18:03:11-05:00"
author: "C. Boyer"
license: "Creative Commons BY-SA-NC 4.0"
website: "https://cboyer.github.io"
category: "Développement"
keywords: [Elixir,Phoenix,Ecto,crud, mix, iex]
abstract: "Le web avec Elixir et son framework Phoenix: formulaires et base de données."
---

- [Installation de PostgreSQL](#installation)
- [Mise à jour de Phoenix](#upgradephoenix)
- [Création d'un projet Phoenix](#projetecto)
- [Création du schéma et des ressources Phoenix](#schema)
- [Ajouter la sélection du type de profile lors de la création d'un utilisateur](#selecttype)
- [Ajuster les relations pour afficher le nom du profil au lieu de son ID](#relation)


## <a name="installation"></a>Installation de PostgreSQL

Pour installer et initialiser PostgreSQL sous Fedora:
```Console
dnf install postgresql-server
/usr/bin/postgresql-setup --initdb
```

Configurer le chiffrement des mots de passe dans `/var/lib/pgsql/data/postgresql.conf`:
```Console
password_encryption = scram-sha-256
```

Définir l'utilisation de mots de passe pour une connexion via localhost dans `/var/lib/pgsql/data/pg_hba.conf`:
```Console
host    all             all             127.0.0.1/32            scram-sha-256
```

Démarrer PostgreSQL et définir un mot de passe pour l'utilisateur `postgres`:
```Console
systemctl restart postgresql
su - postgres
psql
ALTER USER postgres PASSWORD 'postgres';
\q
exit
```

Installer PGAdmin4 peut être intéressant pour explorer la base de données:
[https://www.pgadmin.org/download/pgadmin-4-rpm](https://www.pgadmin.org/download/pgadmin-4-rpm/).


## <a name="upgradephoenix"></a>Mise à jour de Phoenix

Pour mettre à jour Phoenix et/ou un projet déjà existant:
```Console
#Mettre à jour la librairie
mix local.phx

#Changer la version requise de Phoenix dans un projet existant
vi mix.exs

#Nettoyage
mix deps.clean --all
mix clean --deps
rm -rf _build/ deps/ mix.lock

#Mise à jour
mix deps.get
mix compile

#Mettre à jour les assets JS (Webpack)
rm -rf assets/node_modules
npm install --prefix assets/
```


## <a name="projetecto"></a>Création d'un projet Phoenix (incluant Ecto pour la gestion de bases de donnée)

L'exclusion de Webpack posera des problèmes: les requêtes `delete` seront sans effets, la vérification de champs `unique_constraint` dans un changeset également.
Également les messages `put_flash` et `message:` dans les vérification de changeset seront moins élégants.
```Elixir
mix local.phx
mix phx.new test_bd
```

Configuration des accès à la base de données (environnement de développement) dans `config/dev.exs`:
```Elixir
# Configure your database
config :test_bd, TestBd.Repo,
  username: "postgres",
  password: "postgres",
  database: "test_bd_dev",
  hostname: "localhost",
  show_sensitive_data_on_connection_error: true,
  pool_size: 10
```


## <a name="schema"></a>Création du schéma et des ressources Phoenix

Phoenix permet d'initialiser la base de données ainsi que tous les éléments nécessaires (controleurs, templates, vues, modèles) pour interragir avec des données (actions CRUD).

```
  ┌────────────┐      ┌──────────┐
  │   users    │      │ profiles │
  │------------│      │----------│
  │     id     │ ┌────┼───►id    │
  │    name    │ │    │  profile │
  │ profile_id─┼─┘    │          │
  │            │      │          │
  └────────────┘      └──────────┘

```

### Générer le schéma et les ressources:
Utiliser des contextes pour regrouper les fonctions générées selon une fonctionnalité de l'application (autentification, etc.) au lieu d'avoir un seul fichier très dense.

```Elixir
#Générer les controleurs, vues, et contextes pour les ressources HTML.
#mix phx.gen.html [module contexte] [module schéma] [Schéma au pluriel (nom de la table)] [colonne1:type] [colonne2:type] ...
mix phx.gen.html ContextProfile Profile profiles profile:string
mix phx.gen.html ContextUser User users name:string profile_id:references:profiles

#Initialisation d'Ecto et de la base de données avec la création des tables dans PostgreSQL
mix ecto.create
mix ecto.migrate
```

Les fichiers suivants seront crées:
```Console
lib/test_bd/
├── context_profile
│   └── profile.ex          Schéma TestBd.ContextProfile.Profile
├── context_profile.ex      Contexte TestBd.ContextProfile
├── context_user
│   └── user.ex             Schéma TestBd.ContextUser.User
└── context_user.ex         Contexte TestBd.ContextUser


lib/test_bd_web/
├── controllers
│   ├── profile_controller.ex
│   └── user_controller.ex
├── templates
│   ├── profile
│   │   ├── edit.html.eex
│   │   ├── form.html.eex
│   │   ├── index.html.eex
│   │   ├── new.html.eex
│   │   └── show.html.eex
│   └── user
│       ├── edit.html.eex
│       ├── form.html.eex
│       ├── index.html.eex
│       ├── new.html.eex
│       └── show.html.eex
└── views
    ├── profile_view.ex
    └── user_view.ex

```

Par chaque contexte les fonctions générées par défaut correspondent à chaque action CRUD, par exemple pour le contexte `Profile`:

- `list_profiles/0`
- `get_profile/1`
- `create_profile/1`
- `update_profile/2`
- `delete_profile/1`


Ajouter les ressources crées précédemment dans `lib/test_bd_web/router.ex`:
```Elixir
scope "/", TestBdWeb do
    pipe_through :browser

    get "/", PageController, :index
	resources "/profiles", ProfileController
	resources "/users", UserController
end
```

Les routes/URL suivantes sont désormais disponibles pour interragir avec la base de données:
```Console
mix phx.routes
Compiling 1 file (.ex)
          page_path  GET     /                                      TestBdWeb.PageController :index
       profile_path  GET     /profiles                              TestBdWeb.ProfileController :index
       profile_path  GET     /profiles/:id/edit                     TestBdWeb.ProfileController :edit
       profile_path  GET     /profiles/new                          TestBdWeb.ProfileController :new
       profile_path  GET     /profiles/:id                          TestBdWeb.ProfileController :show
       profile_path  POST    /profiles                              TestBdWeb.ProfileController :create
       profile_path  PATCH   /profiles/:id                          TestBdWeb.ProfileController :update
                     PUT     /profiles/:id                          TestBdWeb.ProfileController :update
       profile_path  DELETE  /profiles/:id                          TestBdWeb.ProfileController :delete
          user_path  GET     /users                                 TestBdWeb.UserController :index
          user_path  GET     /users/:id/edit                        TestBdWeb.UserController :edit
          user_path  GET     /users/new                             TestBdWeb.UserController :new
          user_path  GET     /users/:id                             TestBdWeb.UserController :show
          user_path  POST    /users                                 TestBdWeb.UserController :create
          user_path  PATCH   /users/:id                             TestBdWeb.UserController :update
                     PUT     /users/:id                             TestBdWeb.UserController :update
          user_path  DELETE  /users/:id                             TestBdWeb.UserController :delete
live_dashboard_path  GET     /dashboard                             Phoenix.LiveView.Plug :home
live_dashboard_path  GET     /dashboard/:node/:page                 Phoenix.LiveView.Plug :page
          websocket  WS      /live/websocket                        Phoenix.LiveView.Socket
           longpoll  GET     /live/longpoll                         Phoenix.LiveView.Socket
           longpoll  POST    /live/longpoll                         Phoenix.LiveView.Socket
          websocket  WS      /socket/websocket                      TestBdWeb.UserSocket
```

Notons qu'il est possible d'exclure certains type de requêtes:
```Elixir
scope "/", TestBdWeb do
    pipe_through :browser

    get "/", PageController, :index
	resources "/profiles", ProfileController, only: [:show] #except: [:update]
	resources "/users", UserController
end
```

Également supprimer les références aux opérations rendues indisponibles dans les templates, par exemple supprimer `Routes.profile_path(@conn, :delete, profile)`.


## <a name="selecttype"></a>Ajouter la sélection du type de profil lors de la création d'un utilisateur

Ne pas oublier de créer quelques profils [http://localhost:4000/profiles](http://localhost:4000/profiles).
Le paramètre `:profile_id` doit être ajouté au changeset avec `:name` afin d'être conservé dans la table.
Modifier `lib/test_bd/context_user/user.ex`:
```Elixir
defmodule TestBd.ContextUser.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :name, :string
    field :profile_id, :id

    timestamps()
  end

  @doc false
  def changeset(user, attrs) do
    user
    #|> cast(attrs, [:name])
    #|> validate_required([:name])
    |> cast(attrs, [:name, :profile_id])
    |> validate_required([:name, :profile_id], message: "Champ obligatoire.")
    |> validate_format(:name, ~r/^[a-z]+$/, message: "Seules les lettres minuscules sont autorisées.")
    |> unique_constraint(:name, message: "Nom existe déjà")
  end
end

```

Pour être en mesure d'avoir un paramètre `:profile`, il faut rendre sélectionnable ce paramètre dans le formulaire.
Modifier le template `lib/test_bd_web/templates/user/form.html.eex`:
```Elixir
<%= form_for @changeset, @action, fn f -> %>
  <%= if @changeset.action do %>
    <div class="alert alert-danger">
      <p>Oops, something went wrong! Please check the errors below.</p>
    </div>
  <% end %>

  <%= label f, :name %>
  <%= text_input f, :name %>
  <%= error_tag f, :name %>
  
  <!-- Ajout du select ici, @profiles sera définie dans lib/test_bd_web/controllers/user_controller.ex
  En utilisant la fonction TestBd.ContextProfile.list_profiles (lib/test_bd/context_profile.ex) -->
  <%= label f, :profile_id %>
  <%= select f, :profile_id, Enum.map(@profiles, &{&1.profile, &1.id}) %>
  <%= error_tag f, :profile_id %>

  <div>
    <%= submit "Save" %>
  </div>
<% end %>
```

Il faut transmettre `@profiles` aux templates `edit.html` et `new.html` devant permettre la sélection du paramètre `:profile`.
Modifier le controleur `lib/test_bd_web/controllers/user_controller.ex`:
```Elixir
  def new(conn, _params) do
    changeset = ContextUser.change_user(%User{})
    
    #Définition de @profiles en utilisant TestBd.ContextProfile.list_profiles (lib/test_bd/context_profile.ex)
    profiles = TestBd.ContextProfile.list_profiles
    render(conn, "new.html", changeset: changeset, profiles: profiles)
  end

  def edit(conn, %{"id" => id}) do
    user = ContextUser.get_user!(id)
    changeset = ContextUser.change_user(user)

    #Définition de @profiles en utilisant TestBd.ContextProfile.list_profiles (lib/test_bd/context_profile.ex)
    profiles = TestBd.ContextProfile.list_profiles
    render(conn, "edit.html", user: user, changeset: changeset, profiles: profiles)
  end
  
  def create(conn, %{"user" => user_params}) do
    case ContextUser.create_user(user_params) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "User created successfully.")
        |> redirect(to: Routes.user_path(conn, :show, user))

      {:error, %Ecto.Changeset{} = changeset} ->
        #Définition de @profiles en utilisant TestBd.ContextProfile.list_profiles (lib/test_bd/context_profile.ex)
        profiles = TestBd.ContextProfile.list_profiles
        render(conn, "new.html", changeset: changeset, profiles: profiles)
    end
  end
```


## <a name="relation"></a>Ajuster les relations pour afficher le nom du profil au lieu de son ID

Par défaut `list_users/0` du contexte *ContextUser* `lib/test_bd/context_user.ex` retourne seulement le contenu de la table `users` (colonnes *name* et *profile_id*). Pour afficher le type de profile au lieu de son ID (*profile_id*), il faut retourner la colonne *profile* de la table `profiles` après une jointure entre les tables `users` et `profiles`.

Commençons par ajouter les relations dans les schémas Ecto: un utilisateur possède un seul profil et un profil est possédé par un ou plusieurs utilisateurs.
Modifier le schéma `lib/test_bd/context_user/user.ex`:
```Elixir
schema "users" do
    field :name, :string
    #field :profile_id, :id

    #Relation 1 utilisateur possède 1 profile
    belongs_to :profile, TestBd.ContextProfile.Profile

    timestamps()
end
```

Modifier le schéma `lib/test_bd/context_user/profile.ex`:
```Elixir
schema "profiles" do
    field :profile, :string

    #Relation 1 profil est possédé par plusieurs utilisateurs
    has_many :user, TestBd.ContextUser.User

    timestamps()
end
```

Nous pouvons maintenant utliser le Preloader Ecto pour effectuer la jointure entre la table `users` et `profiles` (toutes les colonnes des deux tables seront retournées). 

La solution la plus convenable est d'écrire deux nouvelles fonctions dans le contexte ContextUser `lib/test_bd/context_user.ex`
Les fonctions `list_users/0` et `get_user/1` déjà existantes peuvent servir de base pour ces fonctions.
    
```Elixir
def list_users_with_profile do
    User
    |> Repo.all()
    |> Repo.preload(:profile)
end

def get_user_with_profile!(id) do
    User
    |> Repo.get!(id)
    |> Repo.preload(:profile)
end
```

Utiliser nos fonctions dans le controleur User `lib/test_bd_web/controllers/user_controller.ex` afin de passer les données aux templates `index` et `show`:

```Elixir
def index(conn, _params) do
    users = list_users_with_profile
    render(conn, "index.html", users: users)
end

def show(conn, %{"id" => id}) do
    user = ContextUser.get_user_with_profile!(id)
    render(conn, "show.html", user: user)
end
```

Pour afficher la colonne profile, modifier le template `lib/test_bd_web/templates/user/index.html.eex`:
```Elixir
<h1>Listing Users</h1>

<table>
  <thead>
    <tr>
      <th>Name</th>
      <th>Profile</th>

      <th></th>
    </tr>
  </thead>
  <tbody>

  <%= for user <- @users do %>
    <tr>
      <td><%= user.name %></td>
      <td><%= user.profile.profile %></td>
      <td>
        <span><%= link "Show", to: Routes.user_path(@conn, :show, user) %></span>
        <span><%= link "Edit", to: Routes.user_path(@conn, :edit, user) %></span>
        <span><%= link "Delete", to: Routes.user_path(@conn, :delete, user), method: :delete, data: [confirm: "Are you sure?"] %></span>
      </td>
    </tr>
  <% end %>
  </tbody>
</table>

<span><%= link "New User", to: Routes.user_path(@conn, :new) %></span>
```

Ainsi que le template `lib/test_bd_web/templates/user/show.html.eex`:
```Elixir
<h1>Show User</h1>

<ul>
  <li>
    <strong>Name:</strong>
    <%= @user.name %>
  </li>
  <li>
    <strong>Profile:</strong>
    <%= @user.profile.profile %>
  </li>
</ul>

<span><%= link "Edit", to: Routes.user_path(@conn, :edit, @user) %></span>
<span><%= link "Back", to: Routes.user_path(@conn, :index) %></span>
```


## Ajouter un filtre sur le type de profil

Passer la listes des profils au template `lib/test_bd_web/templates/user/index.html.eex` depuis le controleur `lib/test_bd_web/controllers/user_controller.ex` dans la fonction `index/2`:
```Elixir
def index(conn, params) do
    users = case Map.fetch(params, "profile") do
        {:ok, ""} ->
            ContextUser.list_users_with_profile

        {:ok, user_type_filter} ->
            ContextUser.list_users_with_profile(user_type_filter)

        :error ->
            ContextUser.list_users_with_profile
    end

    profiles = TestBd.ContextProfile.list_profiles
    render(conn, "index.html", users: users, profiles: profiles)
end
```

Ajouter un formulaire avec un menu déroulant `select` dans le template `lib/test_bd_web/templates/user/index.html.eex` qui va recevoir la liste des profils `@profiles` et transmettre au controleur `params` via une requête GET:

```Elixir
<%= form_for @conn, Routes.user_path(@conn, :index), [method: :get], fn f -> %>
  <%= select f, :profile, Enum.map(@profiles, &{&1.profile, &1.profile}), prompt: "Filtrer par profil", onchange: "this.form.submit();", class: "form-control" %>
<% end %>
```

Ajouter une fonction `list_users_with_profile/1` chargée de récupérer les données dans le contexte ContextUser `/test_bd/context_user.ex`:
```Elixir
def list_users_with_profile(profile) do
    User
    |> join(:inner, [u], p in TestBd.ContextProfile.Profile, on: u.profile_id == p.id)
    |> where([u, p], p.profile == ^profile)
    |> select([u, p], %User{id: u.id, name: u.name, profile: %{profile: p.profile, profile_id: p.id}})
    |> order_by([u], [asc: u.name])
    |> Repo.all()
end
```

Nous effectuons le filtre depuis les types de profil mais leurs ID auraient pu être utilisés. L'opérateur `^` sert à l'interpolation de la variable `profile`.
Plusieurs variantes de la même requête sont possibles avec Ecto:
```Elixir
#Avec Preload
query = from u in User,
        join: p in TestBd.ContextProfile.Profile, on: u.profile_id == p.id,
        where: p.profile == ^profile,
        preload: [profile: p],
        order_by: [asc: :name]
        
#Avec Preload
query = from u in User,
        join: p in assoc(u, :profile),
        where: p.profile == ^profile,
        preload: [profile: p],
        order_by: [asc: :name]

#Sans Preload
query = from u in User,
        join: p in TestBd.ContextProfile.Profile, on: u.profile_id == p.id,
        where: p.profile == ^profile,
        order_by: [asc: :name],
        select: %{id: u.id, name: u.name, profile: %{profile: p.profile, profile_id: p.id}}
        
        #Alternatives pour récupérer une structure %User{}:
        #select: %User{id: u.id, name: u.name, profile: %{profile: p.profile, profile_id: p.id}}
        #select: [:id, :name, p: [:id, :profile]]
        
```

> Note: en utilisant la structure `%User{}` dans le `select` nous obtenons tous ses champs. Ceux non précisés dans le `select` seront présents avec la valeur `nil`. En revanche une clé inconnue (désignant une colonne ne figurant pas dans la table) provoquera une erreur car la structure ne peut être étendue directement.
> Une autre façon de faire est d'utiliser une `map` avec les clés souhaitées.
> Un `preload` effectué sans `join` préalable entrainera une requête supplémentaire puis l'assemblage les données (moins performant).



## Liens complémentaires

- [https://hexdocs.pm/phoenix/Mix.Tasks.Phx.Gen.Schema.html](https://hexdocs.pm/phoenix/Mix.Tasks.Phx.Gen.Schema.html)
- [https://hexdocs.pm/phoenix/Mix.Tasks.Phx.Gen.Html.html](https://hexdocs.pm/phoenix/Mix.Tasks.Phx.Gen.Html.html)
- [https://hexdocs.pm/ecto/Ecto.Changeset.html](https://hexdocs.pm/ecto/Ecto.Changeset.html)
- [https://hexdocs.pm/ecto/Ecto.Query.html](https://hexdocs.pm/ecto/Ecto.Query.html)
- [https://hexdocs.pm/ecto/2.2.11/associations.html#one-to-one](https://hexdocs.pm/ecto/2.2.11/associations.html#one-to-one)
- [https://hexdocs.pm/phoenix/contexts.html](https://hexdocs.pm/phoenix/contexts.html)
- [https://hexdocs.pm/ecto/Ecto.Repo.html#c:preload/3](https://hexdocs.pm/ecto/Ecto.Repo.html#c:preload/3)
- [https://dueacaso.it/tech/crud_app_with_phoenix/](https://dueacaso.it/tech/crud_app_with_phoenix/)
- [https://whatdidilearn.info/2018/02/04/implementing-crud-in-phoenix.html](https://whatdidilearn.info/2018/02/04/implementing-crud-in-phoenix.html)
- [https://michael.minton.io/2018/12/creating-a-form-for-a-non-persisted-ecto-schema-in-phoenix.html](https://michael.minton.io/2018/12/creating-a-form-for-a-non-persisted-ecto-schema-in-phoenix.html)
- [https://www.alanvardy.com/post/associations-phoenix](https://www.alanvardy.com/post/associations-phoenix)
- [https://www.sitepoint.com/understanding-elixirs-ecto-querying-dsl-the-basics/](https://www.sitepoint.com/understanding-elixirs-ecto-querying-dsl-the-basics/)
- [https://blog.appsignal.com/2020/11/10/understanding-associations-in-elixir-ecto.html](https://blog.appsignal.com/2020/11/10/understanding-associations-in-elixir-ecto.html)
- [https://dev.to/arrowsmith/activerecord-vs-ecto-querying-the-database-4o9g](https://dev.to/arrowsmith/activerecord-vs-ecto-querying-the-database-4o9g)
