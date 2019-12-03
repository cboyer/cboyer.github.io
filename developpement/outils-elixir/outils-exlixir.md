---
title: "Les outils Elixir"
date: "2019-11-16T13:24:27-05:00"
updated: "2019-11-16T13:24:27-05:00"
author: "C. Boyer"
license: "Creative Commons BY-SA-NC 4.0"
website: "https://cboyer.github.io"
category: "Développement"
keywords: [Elixir, mix, iex, développement]
abstract: |
  Aide mémoire Elixir: les outils.
---

## Mix

Mix est l'outil de gestion pour les applications Elixir.

|Commande                                   | Description                                                                                                   |
|-------------------------------------------|---------------------------------------------------------------------------------------------------------------|
|mix new `myapp`                            | Créer une nouvelle application `myapp`                                                                        |
|mix new --sup `myapp`                      | Créer une nouvelle application `myapp` avec superviseur                                                       |
|mix deps.get                               | Télécharger les dépendances listées dans mix.exs depuis les dépôts Hex                                        |
|mix deps.update                            | Mettre à jour les dépendances listées dans mix.exs                                                            |
|mix deps.clean `circuits_uart`             | Supprimer une dépendance (ici `circuits_uart`)                                                                |
|mix deps.clean --all                       | Supprimer toutes les dépendances téléchargées/compilées                                                       |
|mix deps.compile `input_event`             | Compiler une dépendance particulière (ici `input_event`)                                                      |
|mix compile                                | Compile l'application (les dépendances doivent être téléchargées avec `mix deps.get`                          |
|MIX_ENV=prod mix release                   | Générer une release (disponible à partir de la version 1.9 d'Elixir)                                          |
|mix run                                    | Exécuter l'application en mode non interactif                                                                 |
|iex -S mix                                 | Exécuter l'application en mode interactif avec IEx                                                            |
|mix clean --deps                           | Nettoyage de tous ce qui a été compilé                                                                        |



## Gestion des releases

Les releases sont générées dans `_build/prod` ou `_build/dev` dépendamment de la variable MIX_ENV.

| Commande                                                          | Description                                                                         |
|-------------------------------------------------------------------|-------------------------------------------------------------------------------------|
| MIX_ENV=prod mix release --path ../my_app_release                 | Créer une release de production dans un dossier spécifique                          |
| MIX_ENV=prod mix release `name` --overwrite --force               | Créer une release de production avec les paramètres défini dans `mix.exs` pour `name` en écrasant l'existante et en forçant la recompilation         |
| _build/prod/rel/my_app/bin/my_app start_iex                       | Exécuter une release de production avec IEx                                         |
| bin/RELEASE_NAME eval `"IO.puts(:hello)"`                         | Exécuter un module/fonction de la release sur une nouvelle instance de l'application            |
| bin/RELEASE_NAME rpc `"IO.puts(:hello)"`                          | Exécuter un module/fonction de la release sur une instance en fonction de l'applications        |
| bin/my_app remote                                                 | Se connecter à l'application via un shell distant                                   |
| bin/RELEASE_NAME daemon                                           | Exécuter une release en mode démon (UNIX)                                           |
| bin/RELEASE_NAME install                                          | Installer un service Windows pour exécuter la release                               |



## Le fichier mix.exs

Le fichier `mix.exs` contient la configuration de l'application, des dépendances et des releases.

```Elixir
defmodule Serial.MixProject do
  use Mix.Project

  def project do
    [
      app: :serial,
      version: "1.0.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: [
        # Configuration de la release "serial_prod"
        serial_prod: [
          include_executables_for: [:unix],
          applications: [runtime_tools: :permanent]
        ]
      ]
    ]
  end

  # Configuration de l'application (plus d'options avec "mix help compile.app").
  def application do
    [
      extra_applications: [:logger],
      mod: {Serial.Application, []}
    ]
  end

  # Dépendances (plus d'option avec "mix help deps").
  defp deps do
    [
      {:circuits_uart, "~> 1.3"}
    ]
  end
end
```


## Observer

Pour visualiser les toutes les caractéristiques de notre application (dans `iex`, en ayant au préalable installé le package `erlang-observer`):
```elixir
:observer.start
```


## Compilation manuelle de fichiers source sans Mix

Pour le compiler manuellement et obtenir un binaire (bytecode pour la machine virtuelle BEAM):
```Console
elixirc elixir_app/lib/elixir_app/application.ex
elixirc elixir_app/lib/elixir_app/worker.ex
```

On obtient alors les fichiers `Elixir.ElixirApp.Application.beam` et `Elixir.ElixirApp.Worker.beam`

Pour l'exécuter depuis le shell (en se plaçant dans le même dossier que `Elixir.ElixirApp.Application.beam`):
```Console
elixir -e "ElixirApp.Application.start(:ok, [])"
```

### Sources

- [Gestion des Releases](https://hexdocs.pm/mix/Mix.Tasks.Release.html)
- [Les helpers IEx](https://hexdocs.pm/iex/IEx.Helpers.html)
