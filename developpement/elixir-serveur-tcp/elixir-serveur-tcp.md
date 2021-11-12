---
title: "Serveur TCP avec Elixir et GenServer"
date: "2021-06-12T19:53:11-04:00"
updated: "2021-12-12T18:04:11-05:00"
author: "C. Boyer"
license: "Creative Commons BY-SA-NC 4.0"
website: "https://cboyer.github.io"
category: "Développement"
keywords: [Elixir,TCP,GenServer,iex]
abstract: "Serveur TCP avec Elixir et GenServer"
---


Erlang, Elixir et BEAM sont des technologies particulièrement adaptées pour des problématiques impliquant des connexions (sockets).
Voici deux implémentations d'un serveur TCP avec Elixir et GenServer.

La première utilise le système de message interne (mailbox) de façon élégante. En cas de charge importante, l'utilisation de ce système peut amener à une congestion car BEAM gère ces messages très rapidemment, possiblement plus que la logique d'affaire chargée de les traiter.
Pour utiliser `handle_info/2` pour la réception de ces messages, il est nécessaire de définir l'option `:active` à `true` dans `:gen_tcp.listen`.

```Elixir
defmodule TcpServer do
    use GenServer

    def start_link() do
        ip = Application.get_env :tcp_server, :ip, {127,0,0,1}
        port = Application.get_env :tcp_server, :port, 1234
        GenServer.start_link(__MODULE__, [ip, port], [])
    end

    def init [ip, port] do
        {:ok, listen_socket} = :gen_tcp.listen(port, [:binary, ip: ip, packet: :line, active: true, reuseaddr: true])
        spawn_link(__MODULE__, :accept_loop, [listen_socket, self()])
        {:ok, %{ip: ip, port: port, socket: listen_socket}}
    end

    def handle_info({:tcp, socket, packet}, state) do
        IO.inspect packet, label: "Incoming packet"
        :gen_tcp.send socket, "Received: #{packet}\n"
        {:noreply, state}
    end

    def handle_info({:tcp_closed, _socket}, state) do
        IO.puts "Client disconnected"
        {:noreply, state}
    end

    def handle_info({:tcp_error, socket, reason}, state) do
        IO.inspect socket, label: "Connection closed: #{reason}"
        {:noreply, state}
    end

    def accept_loop(socket, ctrl_pid) do
        with {:ok, client_socket} <- :gen_tcp.accept(socket) do
            #Défini le processus identifié par `ctrl_pid` pour la réception des messages avec handle_info/2
            :ok = :gen_tcp.controlling_process(client_socket, ctrl_pid)
        end

        accept_loop(socket, ctrl_pid)
    end
end
```

L'utilisation de `:gen_tcp.controlling_process/2` est très importante car elle permet au processus principal de réceptionner les messages au lieu du processus issu de `spawn_link/3` qui exécute `accept_loop/2` (plus précisément `:gen_tcp.accept/1`).

La seconde implémentation n'utilise pas `handle_info/2` mais `recv_loop/1` avec l'option `:active` à `false` dans `:gen_tcp.listen`.

```Elixir
defmodule TcpServer do
    use GenServer

    def start_link() do
        ip = Application.get_env :tcp_server, :ip, {127,0,0,1}
        port = Application.get_env :tcp_server, :port, 1234
        GenServer.start_link(__MODULE__, [ip, port], [])
    end

    def init [ip, port] do
        {:ok, listen_socket} = :gen_tcp.listen(port, [:binary, ip: ip, packet: :line, active: false, reuseaddr: true])
        spawn_link(__MODULE__, :accept_loop, [listen_socket])
        {:ok, %{ip: ip, port: port, socket: listen_socket}}
    end

    def recv_loop(socket) do
        case :gen_tcp.recv(socket, 0) do
            {:ok, line} ->
                IO.inspect line, label: "Incoming packet"
                :gen_tcp.send socket, "Received: #{line}\n"
                recv_loop(socket)

            {:error, :closed} -> IO.puts "Client disconnected"
            {:error, reason} -> IO.inspect socket, label: "Connection closed: #{reason}"
        end
    end

    def accept_loop(socket) do
        with {:ok, client_socket} <- :gen_tcp.accept(socket) do
            #Défini l'exécution de `recv_loop/1` comme processus qui reçoit les messages
            recv_pid = spawn(__MODULE__, :recv_loop, [client_socket])
            :ok = :gen_tcp.controlling_process(client_socket, recv_pid)
        end

        accept_loop(socket)
    end
end
```

Il est possible d'utiliser un module dédié `Worker` (à implémenter) au lieu d'une fonction pour traiter les données reçues:
```Elixir
def accept_loop(socket) do
    with {:ok, client_socket} <- :gen_tcp.accept(socket) do
        {:ok, pid} = GenServer.start(Worker, socket: client_socket)
        :ok = :gen_tcp.controlling_process(client_socket, pid)
    end

    accept_loop(socket)
end
```

Également il est possible d'utiliser `Task.start/1`:
```Elixir
def accept_loop(socket) do
    with {:ok, client_socket} <- :gen_tcp.accept(socket) do
        {:ok, pid} = Task.start(fn -> recv_loop(client_socket) end)
        :ok = :gen_tcp.controlling_process(client_socket, pid)
    end

    accept_loop(socket)
end
```


## Compilation et exécution

Pour compiler le module `TcpServer`:
```Console
elixirc tcpserver.ex
```

Pour l'exécuter avec iEX, depuis le dossier où s'est effectuée la compilation (afin de disposer du fichier compilé `Elixir.TcpServer.beam`):
```Console
iex
TcpServer.start_link()
```

Envoyer des données sur `localhost:1234`:
```Console
while true ; do  dd if=/dev/zero bs=4M count=1 status=progress > /dev/tcp/localhost/1234  ; done
```

Également avec telnet (interactif):
```Console
telnet localhost 1234
```

## Liens complémentaires

- [Elegant TCP with Elixir](https://openmymind.net/Elegant-TCP-with-Elixir-Part-1-TCP-as-Messages/)
- [Build an Elixir Redis Server that's 100x faster than HTTP](https://docs.statetrace.com/blog/redis-server/)
