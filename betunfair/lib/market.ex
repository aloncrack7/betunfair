defmodule Market do
  import CubDB
  use GenServer

  def init(state) do
    {:ok, state}
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
    {users, markets, betsDB} = state

    market = CubDB.get(markets, id)
    bets = market[:bets]
    back = bets[:back]
    lay = bets[:lay]
    cancel = bets[:cancel]

    # modify the status bets from the back list and returning all the money to the users
    back = Enum.map(back, fn bet ->
      user = CubDB.get(users, bet[:user_id])
      user = Map.put(user, :balance, user[:balance] + bet[:original_stake])
      CubDB.put(users, bet[:user_id], user)
      bet = Map.put(bet, :status, :market_cancelled)
      CubDB.put(betsDB, bet[:bet_id], bet)
      bet
    end)
    bets = Map.put(bets, :back, back)

    # modify the status bets from the lay list and returning all the money to the users
    lay = Enum.map(lay, fn bet ->
      user = CubDB.get(users, bet[:user_id])
      user = Map.put(user, :balance, user[:balance] + bet[:original_stake])
      CubDB.put(users, bet[:user_id], user)
      bet = Map.put(bet, :status, :market_cancelled)
      CubDB.put(betsDB, bet[:bet_id], bet)
      bet
    end)
    bets = Map.put(bets, :lay, lay)

    # modify the status bets from the cancel list and returning all the money to the users
    cancel = Enum.map(cancel, fn bet ->
      user = CubDB.get(users, bet[:user_id])
      user = Map.put(user, :balance, user[:balance] + bet[:original_stake])
      CubDB.put(users, bet[:user_id], user)
      bet = Map.put(bet, :status, :market_cancelled)
      CubDB.put(betsDB, bet[:bet_id], bet)
      bet
    end)
    bets = Map.put(bets, :cancel, cancel)

    market = Map.put(market, :bets, bets)
    market = Map.put(market, :status, :cancelled)
    CubDB.put(markets, id, market)

    {:reply, {:ok, "market_cancel"}, state}
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
    Enum.map(back, fn bet ->
      matched_bets = bet[:matched_bets]
      if Enum.empty?(matched_bets) do
        user = CubDB.get(users, bet[:user_id])
        user = Map.put(user, :balance, user[:balance] + bet[:original_stake])
        CubDB.put(users, bet[:user_id], user)
      end
    end)

    # returning all the lay bets money to the users who didnt match a bet
    Enum.map(lay, fn bet ->
      matched_bets = bet[:matched_bets]
      if Enum.empty?(matched_bets) do
        user = CubDB.get(users, bet[:user_id])
        user = Map.put(user, :balance, user[:balance] + bet[:original_stake])
        CubDB.put(users, bet[:user_id], user)
      end
    end)

    # returning all the cancelled bets money to the users who didnt match a bet
    Enum.map(cancel, fn bet ->
      user = CubDB.get(users, bet[:user_id])
      user = Map.put(user, :balance, user[:balance] + bet[:original_stake])
      CubDB.put(users, bet[:user_id], user)
    end)

    market = Map.put(market, :status, :frozen)
    CubDB.put(markets, id, market)

    {:reply, {:ok, "freeze"}, state}
  end

  # @spec market_settle(id :: market_id(), result :: boolean()) :: :ok
  def handle_call({:market_settle, id, result}, _, state) do
    {users, markets, betsDB} = state

    market = CubDB.get(markets, id)
    bets = market[:bets]
    back = bets[:back]
    lay = bets[:lay]
    cancel = bets[:cancel]

    if result == true do # back wins
      # ------------------- BACK RETURNS (WINNING)------------------- #
      back = Enum.map(back, fn bet ->
        user = CubDB.get(users, bet[:user_id])
        user = Map.put(user, :balance, user[:balance] + ((bet[:original_stake]-bet[:remaining_stake])*bet[:odds]))
        CubDB.put(users, bet[:user_id], user)

        Enum.map(bet[:matched_bets], fn bet_id ->
          matched_bet = CubDB.get(bets, bet_id)
          user = Map.put(user, :balance, user[:balance] + (matched_bet[:original_stake]*bet[:odds]))
          CubDB.put(users, bet[:user_id], user)
        end)

        bet = Map.put(bet, :status, {:market_settled, result})
        CubDB.put(betsDB, bet[:bet_id], bet)
        bet
      end)
      bets = Map.put(bets, :back, back)

      # ------------------- LAY RETURNS (LOOSING)------------------- #
      lay = Enum.map(lay, fn bet ->
        bet = Map.put(bet, :status, {:market_settled, result})
        CubDB.put(betsDB, bet[:bet_id], bet)
        bet
      end)
      bets = Map.put(bets, :lay, lay)
    else # lay wins
      # ------------------- LAY RETURNS (WINNING)------------------- #
      lay = Enum.map(lay, fn bet ->
        user = CubDB.get(users, bet[:user_id])
        user = Map.put(user, :balance, user[:balance] + ((bet[:original_stake]-bet[:remaining_stake])*bet[:odds]))
        CubDB.put(users, bet[:user_id], user)

        Enum.map(bet[:matched_bets], fn bet_id ->
          matched_bet = CubDB.get(bets, bet_id)
          user = Map.put(user, :balance, user[:balance] + (matched_bet[:original_stake]*bet[:odds]))
          CubDB.put(users, bet[:user_id], user)
        end)

        bet = Map.put(bet, :status, {:market_settled, result})
        CubDB.put(betsDB, bet[:bet_id], bet)
        bet
      end)
      bets = Map.put(bets, :lay, lay)

      # ------------------- BACK RETURNS (LOOSING)------------------- #
      back = Enum.map(back, fn bet ->
        bet = Map.put(bet, :status, {:market_settled, result})
        CubDB.put(betsDB, bet[:bet_id], bet)
        bet
      end)
      bets = Map.put(bets, :back, back)
    end

    market = Map.put(market, :bets, bets)
    CubDB.put(markets, id, market)

    {:reply, {:ok, "settle"}, state}
  end

  # @spec market_bets(id :: market_id()) :: {:ok, Enumerable.t(bet_id())}
  def handle_call({:market_bets, id}, _, state) do
    {_, markets, _} = state

    market = CubDB.get(markets, id)
    bets = market[:bets]
    back = bets[:back]
    lay = bets[:lay]
    cancel = bets[:cancel]

    back_list = List.foldl(back, [], fn (x, acc) -> [x[:bet_id]]++acc end)
    lay_list = List.foldl(lay, [], fn (x, acc) -> [x[:bet_id]]++acc end)
    cancel_list = List.foldl(cancel, [], fn (x, acc) -> [x[:bet_id]]++acc end)

    result_list = back_list ++ lay_list ++ cancel_list
    {:reply, {:ok, result_list}, state}
  end

  # @spec market_pending_backs(id :: market_id()) :: {:ok, Enumerable.t({integer(), bet_id()})}
  def handle_call({:market_pending_backs, id}, _, state) do
    {_, markets, _} = state

    market = CubDB.get(markets, id)
    bets = market[:bets]
    back = bets[:back]
    lay = bets[:lay]
    cancel = bets[:cancel]

    back_results = Enum.filter(back, fn bet ->
      Enum.empty?(bet[:matched_bets]) == true
    end)
    back_results = Enum.map(back_results, fn bet ->
      {bet[:odds], bet[:bet_id]}
    end)

    {:reply, {:ok, back_results}, state}
  end

  # @spec market_pending_lays(id :: market_id()) :: {:ok, Enumerable.t({integer(), bet_id()})}
  def handle_call({:market_pending_lays, id}, _, state) do
    {_, markets, _} = state

    market = CubDB.get(markets, id)
    bets = market[:bets]
    back = bets[:back]
    lay = bets[:lay]
    cancel = bets[:cancel]

    lay_results = Enum.filter(lay, fn bet ->
      Enum.empty?(bet[:matched_bets]) == true
    end)
    lay_results = Enum.map(lay_results, fn bet ->
      {bet[:odds], bet[:bet_id]}
    end)

    {:reply, {:ok, lay_results}, state}
  end

  # @spec market_get(id :: market_id()()) :: {:ok, %{name: string(), description: string(), status: :active | :frozen | :cancelled | {:settled, result::bool()}}}
  def handle_call({:market_get, id}, _, state) do
    {_, markets, _} = state

    market = CubDB.get(markets, id)

    market = Map.delete(market, :bets)

    {:reply, {:ok, market}, state}
  end

  # @spec market_match(id :: market_id()):: :ok
  def handle_call({:market_match, id}, _, state) do
    {_, markets, betsDB} = state

    market = CubDB.get(markets, id)
    bets = market[:bets]
    back = bets[:back]
    lay = bets[:lay]

    if market==nil do
      {:reply, {:error, "Market doesn't exist"}, state}
    end
    if market[:state] == :frozen or market[:state] == :market_cancelled or market[:state] == {:market_settled, false} or market[:state] == {:market_settled, true} do
      {:reply, {:error, "Market not available: frozen, cancelled or already settled"}, state}
    else
      back = Enum.map(back, fn back_bet ->
          lay = Enum.map(lay, fn lay_bet ->
            if back_bet[:remaining_stake] >= 0 and lay_bet[:remaining_stake] >= 0 do
              expected_back = (back_bet[:remaining_stake] * lay_bet[:odds]) - back_bet[:remaining_stake]
              expected_lay = (lay_bet[:remaining_stake] * lay_bet[:odds]) - lay_bet[:remaining_stake]

              if lay_bet[:remaining_stake] >= expected_back and back_bet[:remaining_stake] >= expected_lay do
                back_bet = Map.put(back_bet, :matched_bets, [lay_bet[:bet_id]|back_bet[:matched_bets]])
                lay_bet = Map.put(lay_bet, :matched_bets, [back_bet[:bet_id]|lay_bet[:matched_bets]])

                back_bet = Map.put(back_bet, :remaining_stake, back_bet[:remaining_stake] - expected_lay)
                lay_bet = Map.put(lay_bet, :remaining_stake, lay_bet[:remaining_stake] - expected_back)
              end
            end
            CubDB.put(betsDB, lay_bet[:bet_id], lay_bet)
            lay_bet
          end)
          CubDB.put(betsDB, back_bet[:bet_id], back_bet)
          back_bet
      end)
      bets = Map.put(bets, :back, back)
      bets = Map.put(bets, :lay, lay)
      Map.put(market, :bets, bets)
      CubDB.put(markets, id, market)
    end
  end
end
