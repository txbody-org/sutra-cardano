defmodule SampleData do
  @moduledoc false

  use Sutra.Data

  defdata do
    data(:lock_until, :integer)
    data(:owner, :string)
    data(:benificiary, :string)
  end

  def sample_info do
    %__MODULE__{
      lock_until: 1_742_290_573_275,
      owner: "177eef4b7c639bc45ab84e6363b0423d36af95866e45de11a09999e6",
      benificiary: "f7048dd91e5c18b47155f5569b03bbff05268c8634e6ee51644be0f4"
    }
  end
end
