defmodule Sutra.Data.MacroHelper.ObjectMacro do
  @moduledoc """
    Macro Helper for Object Macros
  """

  alias __MODULE__, as: ObjectMacro
  alias Sutra.Data.MacroHelper
  alias Sutra.Data.Plutus.Constr

  def __define_object__(opts, block) do
    ast = __setup__object__(block, opts)

    case opts[:name] do
      nil ->
        quote do
          unquote(ast)
        end

      module ->
        quote do
          defmodule unquote(module) do
            unquote(ast)
          end
        end
    end
  end

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp __setup__object__(block, _opts) do
    quote do
      Module.register_attribute(__MODULE__, :__fields, accumulate: true)
      Module.register_attribute(__MODULE__, :__required, accumulate: true)
      Module.register_attribute(__MODULE__, :__encode_fields, accumulate: true)

      alias Sutra.Data

      unquote(block)
      @enforce_keys @__required
      defstruct @__fields

      quote do
        unquote(
          def __fields__ do
            unquote(Enum.reverse(@__encode_fields))
          end
        )
      end

      defimpl CBOR.Encoder do
        @impl true
        def encode_into(v, acc),
          do: v.__struct__.to_plutus(v) |> CBOR.Encoder.encode_into(acc)
      end

      def from_plutus(data) when is_binary(data) do
        with {:ok, decoded} <- Sutra.Data.decode(data) do
          from_plutus(decoded)
        end
      end

      def from_plutus(%Constr{index: indx, fields: constr_fields} = tag) do
        decoded_info =
          ObjectMacro.__decode_to_object__(
            constr_fields,
            __MODULE__.__fields__(),
            %{},
            fn plutus_field, name ->
              field_info = __MODULE__.__field_info__(name)

              MacroHelper.handle_from_plutus(field_info, name, plutus_field)
            end
          )

        with {:ok, result} <- decoded_info do
          {:ok, struct(__MODULE__, result)}
        end
      end

      def to_plutus(%__MODULE__{} = mod) do
        fields =
          Enum.reduce(__MODULE__.__fields__(), [], fn name, acc ->
            field_info = __MODULE__.__field_info__(name)
            value = Map.get(mod, name)
            [MacroHelper.handle_to_plutus(field_info, value) | acc]
          end)

        %Constr{index: 0, fields: Enum.reverse(fields)}
      end

      def __plutus_data_info__ do
        nil
      end
    end
  end

  @spec __setup_data__(atom(), any(), Keyword.t()) :: Macro.t()
  def __setup_data__(name, type, opts) do
    quote bind_quoted: [name: name, type: type, opts: opts] do
      opts = opts || []
      mod = __ENV__.module
      fields = Module.get_attribute(mod, :__fields) || []

      if Enum.member?(fields, name),
        do: raise(ArgumentError, "The Field #{inspect(name)} already defined")

      Module.put_attribute(mod, :__fields, name)

      if !MacroHelper.nullable?(type),
        do: Module.put_attribute(mod, :__required_fields, name)

      # Allow virtual field available to struct
      if not Keyword.get(opts, :virtual, false) do
        field_info =
          MacroHelper.with_encoder_decoder(type, opts) |> Keyword.put_new(:field_kind, type)

        Module.put_attribute(mod, :__encode_fields, name)

        quote do
          unquote(
            def unquote(:__field_info__)(unquote(name)) do
              unquote(Macro.escape(field_info))
            end
          )
        end
      end
    end
  end

  def __decode_to_object__(_, [], acc, _func), do: {:ok, acc}

  def __decode_to_object__([], [name | _], _acc, _func),
    do:
      {:error,
       %{
         reason: :missing_field,
         message: "Could not find information to decode for  field: #{name}",
         field: name,
         from: __MODULE__
       }}

  def __decode_to_object__([head | rest_fields], [name | rest_names], acc, func) do
    with {:ok, value} <- func.(head, name) do
      __decode_to_object__(rest_fields, rest_names, Map.put(acc, name, value), func)
    end
  end
end
