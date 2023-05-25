defmodule Market do
  import CubDB
  use GenServer

  def init(pid) do
    {:ok, pid}
  end

  # @spec market_create(name :: string(), description :: string()) :: {:ok, market_id}
  def handle_call({:market_create, name, description}, _, state) do
    market = %{name: name, description: description, status: :active, bets: %{back: [%{user_id: "u1", original_stake: 10, status: :active}], lay: [%{user_id: "u1", original_stake: 5, status: :active}], cancel: [%{"user_id": "u2", original_stake: 3, status: :active}]}}
    {_, markets, _} = state
    size = CubDB.size(markets) + 1
    num = Integer.to_string(size)
    id = "m" <> num

    entries = CubDB.select(markets)

    result = Enum.all?(entries, fn {_, value} -> value[:name] != name end)

    if not result do
      {:reply, {:error, "El nombre del mercado ya existe"}, state}
    else
      CubDB.put_new(markets, id, market)
      {:reply, {:ok, id}, state}
    end
  end

  # @spec market_list():: {:ok, [market_id()]}
  def handle_call(:market_list, _, state) do
    {_, markets, _} = state

    entries = CubDB.select(markets)
    results = Enum.map(entries, fn entry -> elem(entry, 0) end)

    {:reply, {:ok, results}, state}
  end

  # @spec market_list_active():: {:ok, [market_id()]}
  def handle_call(:market_list_active, _, state) do
    {_, markets, _} = state

    entries = CubDB.select(markets)

    results = Enum.map(entries, fn {id, value} -> if value[:status] == :active do id end end)

    {:reply, {:ok, results}, state}
  end

  # @spec market_cancel(id :: market_id()):: :ok
  def handle_call({:market_cancel, id}, _, state) do
    # {users, markets, _} = state

    # market = CubDB.get(markets, id)
    # bets = markets[:bets]
    # back = bets[:back]
    # lay = bets[:lay]
    # cancel = bets[:cancel]

    # back = Enum.map(back, fn map -> %{map | status: :market_cancelled} end)

    # user = CubDB.get(users, x[:user_id])
    # user[:balance] = user[:balance] + x[:original_stake]
    # CubDB.put(users, x[:user_id], user)

    # {:reply, back, state}

    # lay = Enum.map(lay, fn x ->
    #   x[:status] = :market_cancelled
    #   user = CubDB.get(users, x[:user_id])
    #   user[:balance] = user[:balance] + x[:original_stake]
    #   CubDB.put(users, x[:user_id], user)
    # end
    # )

    # cancel = Enum.map(cancel, fn x ->
    #   x[:status] = :market_cancelled
    #   user = CubDB.get(users, x[:user_id])
    #   user[:balance] = user[:balance] + x[:original_stake]
    #   CubDB.put(users, x[:user_id], user)
    # end
    # )

  end

  # @spec market_freeze(id :: market_id()):: :ok
  def handle_call({:market_freeze, id}, _, state) do
  end

  # @spec market_settle(id :: market_id(), result :: boolean()) :: :ok
  def handle_call({:market_settle, id, result}, _, state) do
  end

  # @spec market_bets(id :: market_id()) :: {:ok, Enumerable.t(bet_id())}
  def handle_call({:market_bets, id}, _, state) do

  end

  # @spec market_pending_backs(id :: market_id()) :: {:ok, Enumerable.t({integer(), bet_id()})}
  def handle_call({:market_pending_backs, id}, _, state) do
  end

  # @spec market_pending_lays(id :: market_id()) :: {:ok, Enumerable.t({integer(), bet_id()})}
  def handle_call({:market_pending_lays, id}, _, state) do

  end

  # @spec market_get(id :: market_id()()) :: {:ok, %{name: string(), description: string(), status: :active | :frozen | :cancelled | {:settled, result::bool()}}}
  def handle_call({:market_get, id}, _, state) do
    {:ok, :dets.select(:market, id)}
  end

  # @spec market_match(id :: market_id()):: :ok
  def handle_call({:market_match, id}, _, state) do

  end
end
