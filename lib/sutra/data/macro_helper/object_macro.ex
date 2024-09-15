defmodule Sutra.Data.MacroHelper.ObjectMacro do
  @moduledoc """
    Macro Helper for Object Macros
  """

  alias __MODULE__, as: ObjectMacro
  alias Sutra.Data.MacroHelper
  alias Sutra.Data.Option
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

      alias Sutra.Data

      unquote(block)
      @enforce_keys @__required
      defstruct @__fields

      quote do
        unquote(
          def __fields__ do
            unquote(Enum.reverse(@__fields))
          end
        )
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

              case {field_info[:field_kind], plutus_field} do
                {%Option{}, %Constr{index: 1}} ->
                  {:ok, nil}

                {%Option{}, %Constr{index: 0, fields: [option_field]}} ->
                  field_info[:decode_with].(option_field)

                {%Option{}, %Constr{index: 0, fields: option_fields}} ->
                  field_info[:decode_with].(option_fields)

                {%Option{}, _} ->
                  {:error,
                   %{
                     reason: :invalid_data_for_option_type,
                     message:
                       "Could not parse data for field: #{name}. \n Expected Constr with index 0 or 1 but got: #{inspect(plutus_field)}",
                     field: name,
                     from: __MODULE__
                   }}

                _ ->
                  field_info[:decode_with].(plutus_field)
              end
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

            case {field_info[:field_kind], value} do
              {%Option{}, nil} ->
                [%Constr{index: 1, fields: []} | acc]

              {%Option{}, _} ->
                [%Constr{index: 1, fields: [field_info[:encode_with]]} | acc]

              _ ->
                [field_info[:encode_with].(value) | acc]
            end
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
      mod = __ENV__.module
      fields = Module.get_attribute(mod, :__fields) || []

      if Enum.member?(fields, name),
        do: raise(ArgumentError, "The Field #{inspect(name)} already defined")

      Module.put_attribute(mod, :__fields, name)

      if !MacroHelper.nullable?(type),
        do: Module.put_attribute(mod, :__required_fields, name)

      with_encoded_decoded_info =
        MacroHelper.with_encoder_decoder(type, opts) |> Keyword.put(:field_kind, type)

      quote do
        unquote(
          def unquote(:__field_info__)(unquote(name)) do
            unquote(Macro.escape(with_encoded_decoded_info))
          end
        )
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
