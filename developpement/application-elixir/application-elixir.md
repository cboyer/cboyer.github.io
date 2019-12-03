---
title: "Exemple d'application Elixir"
date: "2019-06-19T19:04:11-04:00"
updated: "2019-11-14T21:40:11-05:00"
author: "C. Boyer"
license: "Creative Commons BY-SA-NC 4.0"
website: "https://cboyer.github.io"
category: "Développement"
keywords: [Elixir, mix, iex, Supervisor, GenServer, développement]
abstract: |
  Exemple d'application Elixir.
---


## Création d'un projet

Une application Elixir très simple en deux modules: un principal`ElixirApp.Application` chargé de superviser le second `ElixirApp.Worker` qui permet de manipuler (lire/écrire) une valeur en mémoire.

Créer un projet avec un superviseur (`--sup`):

```Console
mix new --sup elixir_app
```

Le code de l'application se trouve alors dans `elixir_app/lib/elixir_app/application.ex`

Fichier `application.ex`:
```Elixir
defmodule ElixirApp.Application do
  use Supervisor

  # Supervisor nécessite une fonction init/1 (évite un warning)
  def init(_arg) do
        IO.puts "ElixirApp.Application.init()"
  end

  def start(_type, _args) do
    IO.puts "Application starting worker..."
    children = [
      {ElixirApp.Worker, []}        # Correct si ElixirApp.Worker.start_link prend un argument
      #worker(ElixirApp.Worker, []) # Correct si ElixirApp.Worker.start_link ne prend pas d'argument
    ]

    opts = [strategy: :one_for_one, name: ElixirApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

```

Fichier `worker.ex`:
```Elixir
defmodule ElixirApp.Worker do
  use GenServer

  # Supervisor nécessite une fonction init/1 (évite un warning)
  def init(arg) do
    IO.puts "ElixirApp.Worker.init()"
    {:ok, arg}
  end

  def start_link(_arg) do
    # Map avec la clé "number"
    state = %{
      number: 3
    }

    # Crée le processus avec le nom "counter"
    GenServer.start_link(__MODULE__, state, [name: :counter])
  end

  def put(value) do
      GenServer.cast(:counter, {:put, value})
  end

  # Un cast ne retourne rien (:noreply), il sert à modifier
  def handle_cast({:put, value}, state) do
    IO.puts "Cast: put"
    # Crée une map avec une clé "number" ayant la valeur contenu dans value
    new_value = Map.put(state, :number, value)
    {:noreply, new_value}
  end

  def get_number() do
    GenServer.call(:counter, :get)
  end

  # Un call retourne une valeur (:reply), il sert à lire
  def handle_call(:get, _from, state) do
    IO.puts "Call: get"
    {:reply, state.number, state}
  end

end
```

## Gestion des dépendances avec Mix

Pour ajouter une dépendance depuis les dépôts Hex (https://hex.pm), il faut passer par le fichier `mix.exs` en modifiant le bloc suivant:

```Elixir
defp deps do
  [
    {:input_event, git: "https://github.com/LeToteTeam/input_event.git", tag: "master"}
  ]
end
```

Pour la suite depuis le shell:

```Console
mix deps.get
```

Compiler une dépendance: `mix deps.compile input_event`
Mettre à jour une dépendance: `mix deps.update input_event`
Pour la supprimer: `mix deps.clean input_event`

## Lancement de l'application

Il est possible d'exécuter l'application de façon interactive depuis `iex` (toujours depuis le dossier racine `elixir_app`) ce qui permet d'appeler n'importe quelle fonction ou d'utiliser l'Observer avec `:observer.start` :
```Console
iex -S mix
```

Nous pouvons appeler les fonctions depuis `iex`

```Console
iex(8)> ElixirApp.Worker.get_number()
Call: get
3

iex(9)> ElixirApp.Worker.put(1354)
Cast: put
:ok

iex(10)> ElixirApp.Worker.get_number()
Call: get
1354
```

Il est possible de recharger le module après modification sans perdre l'état actuelle de `state` :

```Console
iex(11)> r ElixirApp.Worker
warning: redefining module ElixirApp.Worker (current version loaded from _build/dev/lib/elixir_app/ebin/ElixirApp.Worker.beam)
  lib/elixir_app/worker.ex:1

{:reloaded, ElixirApp.Worker, [ElixirApp.Worker]}

iex(12)> ElixirApp.Worker.get_number()
Call: get
1354
```

Pour l'exécuter de façon non interactive (depuis le dossier racine `elixir_app`):

```Console
mix run
```



## Observer

Pour visualiser les toutes les caractéristiques de notre application (dans `iex`, en ayant au préalable installé le package `erlang-observer`):

```elixir
:observer.start
```


### Sources

- [elixir-lang.org: Supervisor and application](https://elixir-lang.org/getting-started/mix-otp/supervisor-and-application.html)
- [elixir-lang.org: GenServer](https://elixir-lang.org/getting-started/mix-otp/genserver.html)
- [Découverte du langage Elixir](https://www.youtube.com/watch?v=1hl_z9-QO9c)
- [Learn elixir in Y Minutes](https://learnxinyminutes.com/docs/elixir/)
