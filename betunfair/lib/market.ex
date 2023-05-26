defmodule Market do
  import CubDB
  use GenServer

  def init(pid) do
    {:ok, pid}
  end

  # @spec market_create(name :: string(), description :: string()) :: {:ok, market_id}
  def handle_call({:market_create, name, description}, _, state) do
    market = %{name: name, description: description, status: :active, bets: %{back: [], lay: [], cancel: []}}
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

    results = Enum.filter(entries, fn {id, value} -> value[:status] == :active end) # we obtain the markets with :active state and store them in a list
    results = Enum.map(results, fn {id, _} -> id end) # we store just the ID of the markets on the list

    {:reply, {:ok, results}, state}
  end

  # @spec market_cancel(id :: market_id()):: :ok
  def handle_call({:market_cancel, id}, _, state) do
    {users, markets, _} = state

    market = CubDB.get(markets, id)
    bets = market[:bets]
    back = bets[:back]
    lay = bets[:lay]
    cancel = bets[:cancel]

    # modify the status bets from the back list and returning all the money to the users
    back = Enum.map(back, fn map ->
      user = CubDB.get(users, map[:user_id])
      Map.put(user, :balance, user[:balance] + map[:original_stake])
      CubDB.put(users, map[:user_id], user)
      Map.put(map, :status, :market_cancelled)
    end)
    bets = Map.put(bets, :back, back)

    # modify the status bets from the lay list and returning all the money to the users
    lay = Enum.map(lay, fn map ->
      user = CubDB.get(users, map[:user_id])
      Map.put(user, :balance, user[:balance] + map[:original_stake])
      CubDB.put(users, map[:user_id], user)
      Map.put(map, :status, :market_cancelled)
    end)
    bets = Map.put(bets, :lay, lay)

    # modify the status bets from the cancel list and returning all the money to the users
    cancel = Enum.map(cancel, fn map ->
      user = CubDB.get(users, map[:user_id])
      Map.put(user, :balance, user[:balance] + map[:original_stake])
      CubDB.put(users, map[:user_id], user)
      Map.put(map, :status, :market_cancelled)
    end)
    bets = Map.put(bets, :cancel, cancel)

    market = Map.put(market, :bets, bets)
    market = Map.put(market, :status, :cancelled)
    CubDB.put(markets, id, market)

    {:reply, :ok, state}
  end

  # @spec market_freeze(id :: market_id()):: :ok
  def handle_call({:market_freeze, id}, _, state) do
    {users, markets, _} = state

    market = CubDB.get(markets, id)
    bets = market[:bets]
    back = bets[:back]
    lay = bets[:lay]
    cancel = bets[:cancel]

    # returning all the back bets money to the users who didnt match a bet
    Enum.map(back, fn map ->
      matched_bets = map[:matched_bets]
      if Enum.empty?(matched_bets) do
        user = CubDB.get(users, map[:user_id])
        Map.put(user, :balance, user[:balance] + map[:original_stake])
        CubDB.put(users, map[:user_id], user)
      end
    end)

    # returning all the lay bets money to the users who didnt match a bet
    Enum.map(lay, fn map ->
      matched_bets = map[:matched_bets]
      if Enum.empty?(matched_bets) do
        user = CubDB.get(users, map[:user_id])
        Map.put(user, :balance, user[:balance] + map[:original_stake])
        CubDB.put(users, map[:user_id], user)
      end
    end)

    # returning all the cancelled bets money to the users who didnt match a bet
    Enum.map(cancel, fn map ->
      user = CubDB.get(users, map[:user_id])
      Map.put(user, :balance, user[:balance] + map[:original_stake])
      CubDB.put(users, map[:user_id], user)
    end)

    market = Map.put(market, :status, :frozen)
    CubDB.put(markets, id, market)

    {:reply, :ok, state}
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
