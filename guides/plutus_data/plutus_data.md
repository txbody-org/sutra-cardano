# Plutus Data Definition

Sutra SDK provides a robust set of macros for defining Plutus Data types, including objects and enums. These definitions ensure type safety and seamless conversion to/from Plutus Core data structures (CBOR).

## Defining Objects (defdata)

The `defdata` macro allows you to define struct-like objects that map to Plutus Data.

```elixir
defmodule MyProject.Types do
  use Sutra.Data
  
  # Define a simple object
  defdata name: OutputReference do
    data :transaction_id, :string
    data :output_index, :integer
  end
end
```

### Field Types

You can use standard types or other defined schemas:

*   `:integer`
*   `:string` (ByteString)
*   `:boolean`
*   `:list`
*   `Module` (Another `defdata` or `defenum` module)

### Custom Encoding/Decoding

You can override the default encoding logic by providing custom functions:

```elixir
defdata name: Input do
  data :output_reference, MyProject.Types.OutputReference
  data :output, :output, encode_with: &MyModule.custom_encode/1, decode_with: &MyModule.custom_decode/1
end
```

## Defining Enums (defenum)

The `defenum` macro defines sum types (enums), creating constructors for each variant.

### Block Syntax (Recommended)

```elixir
defenum name: Datum do
  field :no_datum, :null
  field :datum_hash, :string
  field :inline_datum, :string
end
```

### With Explicit Indices

You can manually specify the index for each constructor if needed (e.g., to match an existing Plutus script):

```elixir
defenum name: Datum do
  field :inline_datum, :string, index: 1
  field :datum_hash, :string, index: 0
  field :no_datum, :null, index: 2
end
```

### Legacy Syntax

```elixir
defenum name: Status, variants: [:open, :closed, :disputed]
```

## Using the Data

Once defined, these modules generate structs that you can use in your Elixir code.

```elixir
# Creating an instance
out_ref = %MyProject.Types.OutputReference{
  transaction_id: "tx_hash_hex",
  output_index: 0
}

# Encoding to Plutus Data (CBOR)
cbor_hex = Sutra.Data.encode(out_ref)

# Decoding
decoded_struct = Sutra.Data.decode!(cbor_hex)
```
