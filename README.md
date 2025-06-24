# Sutra

** Offchain transaction builder framework for cardano using Elixr.**

> [!WARNING]  
> SDK is under heavy development and API might change until we have stable version.



## Installation


If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `sutra_offchain` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:sutra_offchain, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/sutra_offchain>.

## Running examples with Yaci Provider

Here's how you can run the `send_ada.exs` example via Yaci Provider.

1- Start Yaci-Devkit separately.  
2- Generate and topup addresses using yaci-cli.  
3- Update `examples/simple/send_ada.exs` with mnemonic and destination address.  
4- Build docker image with `docker build -t sutra-cardano .`  
5- Run docker with `./examples/run-via-docker.sh`. This should take you to `iex` with the mix project loaded.  
6- From the prompt, run `Code.eval_file("examples/simple/send_ada.exs")` to run the example.  
7- Check the balance of the destination address and you should see the balance increased.