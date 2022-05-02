# Balancero

Internal load balancer.

It is designed to help developers keep track of the number of persistent connections towards external services.
Current version only supports least-connection strategy.

## Installation

```elixir
def deps do
  [
    {:balancero, github: "stefanzvkvc/balancero"}
  ]
end
```

In config file add server list that needs to be monitored.

```elixir
config :balancero,
  servers: [
    %{
      host: "127.0.0.1",
      port: 1234,
      # for extra options when connecting visit: https://www.erlang.org/doc/man/gen_tcp.html#type-option_name
      opts: []
    },
    ...
  ]
```

## Example

The example assumes you have external cluster running.

To get available host you would like to get connected to, run:

```elixir
Balancero.get()
{:ok, "127.0.0.1"}
```

Once connected, you can track this connection by running:

```elixir
Balancero.track("127.0.0.1")
{:ok, "1WpAofWYIAA="}
```

On disconnect you can untrack the connection by runnung:

```elixir
Balancero.untrack()
:ok
```
