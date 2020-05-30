---
title: "Interfacer un programme C avec Elixir grâce aux Ports"
date: "2020-05-30T14:27:04-04:00"
updated: "2020-05-30T14:27:04-04:00"
author: "C. Boyer"
license: "Creative Commons BY-SA-NC 4.0"
website: "https://cboyer.github.io"
category: "Développement"
keywords: [Elixir, C, Ports, interface, stdin, stdout]
abstract: |
  Interfacer un programme C via STDIN/STDOUT avec les Ports Elixir.
---

Il existe plusieurs méthodes d'interfacer un programme C avec Elixir. Les Ports consistent à utiliser STDIN/STDOUT pour communiquer avec un autre programme (C ou autres). 
Deux façons de les utiliser: simplement en envoyant/recevant les données, et l'autre en y ajoutant la longueur de ces données sur les premiers octets (comme certains protocoles applicatifs qui utilisent TCP/IP).


## Utilisation simple des Ports

Exemple de programme C lisant sur STDIN, ajoute "Hello " devant puis écrit le résultat sur STDOUT_FILENO.
À compiler avec `gcc test.c` pour obtenir l'exécutable `a.out`.

```C
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#define MAX_SIZE_DATA 50


int main () {
    char add[] = "Hello ";
    char in[MAX_SIZE_DATA] = "\0";
    char out[MAX_SIZE_DATA + sizeof add] = "\0";

    /* Utilisation de read() avec STDIN_FILENO fonctionne également, fgets suppose l'utilisation de '\n' comme fin de chaîne */
    while (fgets(in, sizeof in - 1, stdin) != 0) {
        strncat(out, add, strlen(add));
        strncat(out, in, strlen(in));
  
        /* fprintf(stdout, out) et printf("%s", out) ne sont pas récupérés par Elixir */
        write(STDOUT_FILENO, out, strlen(out));
        out[0] = '\0';
    }

    return 0;
}
```


Tests avec `iex`:

```Console
Interactive Elixir (1.10.3) - press Ctrl+C to exit (type h() ENTER for help)
iex(1)> port = Port.open({:spawn_executable, "./a.out"}, [:binary])
#Port<0.5>
iex(2)> flush()
:ok
iex(3)> Port.command(port, "Polo\n")
true
iex(4)> flush()                     
{#Port<0.5>, {:data, "Hello Polo\n"}}
:ok
```


Les ports peuvent également être utilisés avec GenServer:

```Elixir
defmodule PortTester do
    use GenServer
    require Logger

    def start_link(args) do
        GenServer.start_link(__MODULE__, args, [name: :echo_port])
    end

    def init(_args) do
        state = %{
            port: nil
        }

        port = Port.open({:spawn_executable, "./a.out"}, [:binary, :exit_status])
        state = Map.put(state, :port, port)
        Port.command(port, "Init\n")

        #Stream continu pour générer des messages (entier incrémenté chaque seconde)
        _pid = spawn fn -> 1000
                        |> Stream.interval()
                        |> Stream.each(&(send(:echo_port, "test " <> Integer.to_string(&1))) ) 
                        |> Stream.run()
        end

        {:ok, state}
    end

    #Réception des messages en provenance du port
    def handle_info({port, {:data, msg}}, state) do
        Logger.info "Received from port #{inspect port}: #{inspect msg}"
        {:noreply, state}
    end

    #Redémarre le port au besoin
    def handle_info({port, {:exit_status, status}}, state) do
        Logger.info "Port #{inspect port} exited with status #{inspect status}, restarting..."
        port = Port.open({:spawn_executable, "./a.out"}, [:binary, :exit_status])
        state = Map.put(state, :port, port)
        {:noreply, state}
    end
    
    #Récupère les messages en provenance du Stream pour les envoyer au port
    def handle_info(msg, state) do
        Logger.info "Send to port #{inspect state.port}: #{inspect msg}"
        Port.command(state.port, msg <> "\n")
        {:noreply, state}
    end
end
```

Compilation/exécution:
```Console
elixirc porttester.ex
iex
PortTester.start_link([])
```

## Inclure la longueur des messages

Pour s'assurer de récupérer l'intégralité d'un message (éventuellement envoyé en plusieurs parties), Elixir propose d'envoyer en premier la longueur du message attendu.
En utilisant ce mode de fonctionnement, la longueur d'un message doit être spécifiée en entrée comme en sortie du Port.
L'ensemble est géré de manière transparente avec Elixir qui nécessite uniquement l'ajout d'un paramètre à l'ouverture du Port (dans notre module `PortTester`) :

```Elixir
port = Port.open({:spawn_executable, "./a.out"}, [:binary, {:packet, 4}, :exit_status])
```

En revanche l'implémentation en C nécessitera un peu plus de travail:

```C
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <stdint.h>

#define MAX_SIZE_DATA 50


int main () {
    char add[] = "Hello ";
    char in[MAX_SIZE_DATA] = "\0";
    char buf[MAX_SIZE_DATA] = "\0";
    char out[MAX_SIZE_DATA + sizeof add] = "\0";
    char bytes[4];
    uint32_t msg_length;

    /* Récupère la longueur du message (4 premiers octets) */
    while (read(STDIN_FILENO, bytes, 4) != 0) {

        /* Conversion des 4 premiers octets en entier (big endian) */
        msg_length = ((uint32_t)bytes[0] << 24) + ((uint32_t)bytes[1] << 16) + ((uint32_t)bytes[2] << 8) + (uint32_t)bytes[3];

        /* STDERR permet d'afficher dans le terminal (non récupéré par Elixir) */
        //fprintf(stderr, "[a.out] Received length from Elixir: %d\n", msg_length);

        /* Lis le message sur la longueur spécifiée, buffer overflow si msg_length > MAX_SIZE_DATA */
        do {
            read(STDIN_FILENO, buf, msg_length);
            strncat(in, buf, strlen(buf));
        } while(strlen(in) < msg_length);

        //fprintf(stderr, "[a.out] Received data from Elixir: %s\n", in);

        /* Prépare le message réponse */
        strncat(out, add, strlen(add));
        strncat(out, in, strlen(in));

        /* Code la longueur du message (int) sur 4 octets big endian */
        msg_length = strlen(out);
        bytes[0] = (msg_length >> 24) & 0xFF;
        bytes[1] = (msg_length >> 16) & 0xFF;
        bytes[2] = (msg_length >> 8) & 0xFF;
        bytes[3] = msg_length & 0xFF;

        //fprintf(stderr, "[a.out] Sending to Elixir length=%d data=%s\n", msg_length, out);

        /* Envoi la longueur du message à Elixir */
        write(STDOUT_FILENO, bytes, 4);

        /* Envoi le message à Elixir */
        write(STDOUT_FILENO, out, msg_length);

        out[0] = '\0';
        in[0] = '\0';
    }

    return 0;
}
```


### Liens complémentaires

 - [Ports Elixir](https://hexdocs.pm/elixir/Port.html)
 - [Outside Elixir: running external programs with ports](https://www.theerlangelist.com/article/outside_elixir)
