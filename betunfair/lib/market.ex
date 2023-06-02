 defmodule Market do
  import CubDB
  use GenServer

  def init(state) do
    {:ok, state}
  end

  def start_link(state) do
    GenServer.start_link(Market, state, name: :markets_server)
  end


  def handle_call({:market_create, name, description}, _, state) do
    market = %{name: name, description: description, status: :active, bets: %{back: [], lay: []}} # data structure of a market
    {_, markets, _} = state
    size = CubDB.size(markets) + 1
    num = Integer.to_string(size)
    id = "m" <> num # generation of a unique ID the market (id = mX)

    entries = CubDB.select(markets)

    result = Enum.all?(entries, fn {_, value} -> value[:name] != name end)

    if not result do # if the name of the market exists, return an error
      {:reply, {:error, "Market with given name already exists"}, state}
    else # if the name dont exist, create the market
      CubDB.put_new(markets, id, market)
      {:reply, {:ok, id}, state}
    end
  end

  def handle_call(:market_list, _, state) do
    {_, markets, _} = state

    entries = CubDB.select(markets) # get the markets from DataBase
    results = Enum.map(entries, fn entry -> elem(entry, 0) end) # store the IDs of the markets on a list

    {:reply, {:ok, results}, state}
  end

  def handle_call(:market_list_active, _, state) do
    {_, markets, _} = state

    entries = CubDB.select(markets) # get the markets from DataBase

    results = Enum.filter(entries, fn {id, value} -> value[:status] == :active end) # obtain the markets with :active state and store them in a list
    results = Enum.map(results, fn {id, _} -> id end) # store just the ID of the markets on the list

    {:reply, {:ok, results}, state}
  end

  # Cancels a market and returns the original stake of all bets of the market to the users
  # The original stake is not returned if the bet is frozen and (the bet didnt match another bet or the bet is cancelled)
  # This is because in those cases where the market is freezed, the stake is returned to the users. With this we prevent returning the stake twice.
  # In our implementation the market can be canceled if the market state is active or freezed.
  def handle_call({:market_cancel, id}, _, state) do
    {users, markets, betsDB} = state

    if CubDB.has_key?(markets, id) == false do # check that the market exists
      {:reply, {:error, "No market for given id"}, state}
    else
      market = CubDB.get(markets, id)

      if market[:status] == :active or market[:status] == :frozen do # to cancel a market, it need to have a state of active or frozen
        bets = market[:bets]
        back = bets[:back]
        lay = bets[:lay]

        # modifying the status bets from the back list and returning all the money to the users
        back = Enum.map(back, fn bet ->
          user = CubDB.get(users, bet[:user_id])
          user = if bet[:status] == :frozen and Enum.empty?(bet[:matched_bets]) do # check if the money has already been returned in market_freeze (we prevent returning the money twice)
            Map.put(user, :balance, user[:balance]) # money stays the same because it has been returned on market_freeze
          else
            Map.put(user, :balance, user[:balance] + bet[:original_stake]) # return the money to the user
          end
          CubDB.put(users, bet[:user_id], user)
          bet = Map.put(bet, :status, :market_cancelled) # change the bet status
          CubDB.put(betsDB, bet[:bet_id], bet)
          bet
        end)
        bets = Map.put(bets, :back, back)

        # modifying the status bets from the lay list and returning all the money to the users
        lay = Enum.map(lay, fn bet ->
          user = CubDB.get(users, bet[:user_id])
          user = if bet[:status] == :frozen and Enum.empty?(bet[:matched_bets]) do # check if the money has already been returned in market_freeze (we prevent returning the money twice)
            Map.put(user, :balance, user[:balance]) # money stays the same because it has been returned on market_freeze
          else
            Map.put(user, :balance, user[:balance] + bet[:original_stake]) # return the money to the user
          end
          CubDB.put(users, bet[:user_id], user)
          bet = Map.put(bet, :status, :market_cancelled) # change the bet status
          CubDB.put(betsDB, bet[:bet_id], bet)
          bet
        end)
        bets = Map.put(bets, :lay, lay)

        market = Map.put(market, :bets, bets)
        market = Map.put(market, :status, :cancelled) # change the market status
        CubDB.put(markets, id, market)

        {:reply, :ok, state}
      else
        {:reply, {:error, "Market status is not active or frozen"}, state}
      end
    end
  end

  # Freezes a market and returns the original stake
  # to the bets that didnt match with any other bet.
  # In our implementation the market can be freezed if the market state is only active.
  def handle_call({:market_freeze, id}, _, state) do
    {users, markets, betsDB} = state

    if CubDB.has_key?(markets, id) == false do # check that the market exists
      {:reply, {:error, "No market for given id"}, state}
    else
      market = CubDB.get(markets, id)

      if market[:status] == :active do # to freeze a market, it need to have a state of active
        bets = market[:bets]
        back = bets[:back]
        lay = bets[:lay]

        # returning all the back bets money to the users who didnt match a bet
        back_list = Enum.map(back, fn bet ->
          matched_bets = bet[:matched_bets]
          bet = if Enum.empty?(matched_bets) do # check also if the bet is cancelled because we dont delete matched bets from a cancelled bet
            user = CubDB.get(users, bet[:user_id])
            user = Map.put(user, :balance, user[:balance] + bet[:remaining_stake]) # returning the remaining stake to the user
            CubDB.put(users, bet[:user_id], user)

            bet = Map.put(bet, :remaining_stake, 0)
            CubDB.put(betsDB, bet[:bet_id], bet)
            bet
          else
            bet
          end
        end)

        # returning all the lay bets money to the users who didnt match a bet
        lay_list = Enum.map(lay, fn bet ->
          matched_bets = bet[:matched_bets]
          bet = if Enum.empty?(matched_bets) do # check also if the bet is cancelled because we dont delete matched bets from a cancelled bet
            user = CubDB.get(users, bet[:user_id])
            user = Map.put(user, :balance, user[:balance] + bet[:remaining_stake]) # returning the original stake to the user
            CubDB.put(users, bet[:user_id], user)

            bet = Map.put(bet, :remaining_stake, 0)
            CubDB.put(betsDB, bet[:bet_id], bet)
            bet
          else
            bet
          end
        end)

        bets = Map.put(bets, :back, back_list)
        bets = Map.put(bets, :lay, lay_list)
        market = Map.put(market, :bets, bets)
        market = Map.put(market, :status, :frozen)
        CubDB.put(markets, id, market)

        {:reply, :ok, state}
      else
        {:reply, {:error, "Market needs to be active"}, state}
      end
    end
  end

  # Winnings are distributed to winning users according to stakes and odds.
  # It returns the remaining stake of the cancelled bets if they havent been returned on market freeze.
  # It returns the original stake of the bets that didnt match with any other bet.
  # In our implementation the market can be settled if the market state is active or frozen.
  def handle_call({:market_settle, id, result}, _, state) do
    {users, markets, betsDB} = state

    if CubDB.has_key?(markets, id) == false do # check that the market exists
      {:reply, {:error, "No market for given id"}, state}
    else
      if is_boolean(result) == false do # check that the result is a boolean
        {:reply, {:error, "Given result must be boolean"}, state}
      else
        market = CubDB.get(markets, id)

        if market[:status] == :active or market[:status] == :frozen do # to settle a market, it need to be active or frozen
          bets = market[:bets]
          back = bets[:back]
          lay = bets[:lay]

          bets = if result == true do
            # ------------------- BACK RETURNS (WINNING)------------------- #
            back = Enum.map(back, fn bet ->
              user = CubDB.get(users, bet[:user_id])
              user = if not Enum.empty?(bet[:matched_bets]) do # if the bet has matched with other bets (has winnings)
                Map.put(user, :balance, user[:balance] + trunc((bet[:original_stake]-bet[:remaining_stake])*(bet[:odds]/100)) + bet[:remaining_stake]) # the user wins the matched stake * odds + remaining stake
              else # if the bet didnt match with any other bet
                if market[:status] != :frozen do # we check if the market is frozen to see if the money has been returned
                  Map.put(user, :balance, user[:balance] + bet[:original_stake]) # if not, we return the unmatched bet stake to the user
                else
                  user
                end
              end
              CubDB.put(users, bet[:user_id], user)

              bet = Map.put(bet, :status, {:market_settled, result}) # update bet state
              CubDB.put(betsDB, bet[:bet_id], bet)
              bet
            end)
            bets = Map.put(bets, :back, back)

            # ------------------- LAY RETURNS (LOOSING)------------------- #
            lay = Enum.map(lay, fn bet ->
              user = CubDB.get(users, bet[:user_id])
              user = if not Enum.empty?(bet[:matched_bets]) do # if the loosing bet has matched with other bets
                Map.put(user, :balance, user[:balance] + bet[:remaining_stake]) # we return the remaining stake to the user (unmatched money)
              else # if the loosing bet is unmatched
                if market[:status] != :frozen do # we check if the market is frozen to see if the unmatched stake has been returned
                  Map.put(user, :balance, user[:balance] + bet[:original_stake]) # if the market is not frozen we return the original stake
                else
                  user
                end
              end
              CubDB.put(users, bet[:user_id], user)

              bet = Map.put(bet, :status, {:market_settled, result}) # change the bet status
              CubDB.put(betsDB, bet[:bet_id], bet)
              bet
            end)
            bets = Map.put(bets, :lay, lay)
          else
            # ------------------- LAY RETURNS (WINNING)------------------- #
            lay = Enum.map(lay, fn bet ->
              user = CubDB.get(users, bet[:user_id])
              # the back stake matched with the lay bet is stored in the matched bet list like this {bet_id, matched_back_stake}
              # with this implementation, we can calculate the winnings of the lay bet by the sumation of the matched back stakes
              balance = Enum.reduce(bet[:matched_bets], user[:balance] + bet[:original_stake], fn {back_bet_id, value}, acc ->
                acc = acc + value
              end)
              user = if not Enum.empty?(bet[:matched_bets]) do # if the bet has matched with other bets (has winnings)
                Map.put(user, :balance, trunc(balance)) # the user wins the matched stake with the back + remaining stake
              else # if the bet hasnt match with other bets
                if market[:status] != :frozen do # we check if the market is frozen to see if the money has been returned in market_freeze
                  Map.put(user, :balance, user[:balance] + bet[:original_stake]) # if not, we return the unmatched bet stake to the user
                else
                  user
                end
              end
              CubDB.put(users, bet[:user_id], user)

              bet = Map.put(bet, :status, {:market_settled, result}) # change the market status
              CubDB.put(betsDB, bet[:bet_id], bet)
              bet
            end)
            bets = Map.put(bets, :lay, lay)

            # ------------------- BACK RETURNS (LOOSING)------------------- #
            back = Enum.map(back, fn bet ->
              user = CubDB.get(users, bet[:user_id])
              user = if not Enum.empty?(bet[:matched_bets]) do # if the loosing bet matched with other bets
                Map.put(user, :balance, user[:balance] + bet[:remaining_stake]) # we return the remaining stake to the user
              else # if the loosing bet is unmatched
                if market[:status] != :frozen do # we check if the market is frozen to see if the money has been returned in market_freeze
                  Map.put(user, :balance, user[:balance] + bet[:original_stake]) # if not, we return the bet stake to the user
                else
                  user
                end
              end
              CubDB.put(users, bet[:user_id], user)

              bet = Map.put(bet, :status, {:market_settled, result}) # change the market status
              CubDB.put(betsDB, bet[:bet_id], bet)
              bet
            end)
            bets = Map.put(bets, :back, back)
          end

          market = Map.put(market, :bets, bets)
          market = Map.put(market, :status, {:market_settled, result}) # change the market status
          CubDB.put(markets, id, market)

          {:reply, :ok, state}
        else
          {:reply, {:error, "Market status is not active or frozen"}, state}
        end
      end
    end
  end

  def handle_call({:market_bets, id}, _, state) do
    {_, markets, _} = state

    if CubDB.has_key?(markets, id) == true do # check if the market exists
      market = CubDB.get(markets, id)
      bets = market[:bets]
      back = bets[:back]
      lay = bets[:lay]

      back_list = List.foldl(back, [], fn (x, acc) -> [x[:bet_id]]++acc end) # we store the bet ids of the back list
      lay_list = List.foldl(lay, [], fn (x, acc) -> [x[:bet_id]]++acc end) # we store the bet ids of the lay list

      result_list = back_list ++ lay_list # we concatenate the lists to get all the bets
      {:reply, {:ok, result_list}, state}
    else
      {:reply, {:error, "No market for given id"}, state}
    end
  end

  def handle_call({:market_pending_backs, id}, _, state) do
    {_, markets, _} = state

    if CubDB.has_key?(markets, id) == true do # check if the market exists
      market = CubDB.get(markets, id)
      bets = market[:bets]
      back = bets[:back]
      lay = bets[:lay]

      # we store the back bets with empty matched bets list (non matched bets)
      back_results = Enum.filter(back, fn bet ->
        Enum.empty?(bet[:matched_bets]) == true
      end)
      # we create a list with the bets in the form {odds, bet_id}
      back_results = Enum.map(back_results, fn bet ->
        {bet[:odds], bet[:bet_id]}
      end)

      {:reply, {:ok, back_results}, state}
    else
      {:reply, {:error, "No market for given id"}, state}
    end
  end

  def handle_call({:market_pending_lays, id}, _, state) do
    {_, markets, _} = state

    if CubDB.has_key?(markets, id) == true do # check if the market exists
      market = CubDB.get(markets, id)
      bets = market[:bets]
      back = bets[:back]
      lay = bets[:lay]

      # we store the lay bets with empty matched bets list (non matched bets)
      lay_results = Enum.filter(lay, fn bet ->
        Enum.empty?(bet[:matched_bets]) == true
      end)
      # we create a list with the bets in the form {odds, bet_id}
      lay_results = Enum.map(lay_results, fn bet ->
        {bet[:odds], bet[:bet_id]}
      end)

      {:reply, {:ok, lay_results}, state}
    else
      {:reply, {:error, "No market for given id"}, state}
    end
  end

  def handle_call({:market_get, id}, _, state) do
    {_, markets, _} = state

    if CubDB.has_key?(markets, id) == true do # check if the market exists
      market = CubDB.get(markets, id) # get the market from database
      market = Map.delete(market, :bets) # delete the bets map
      {:reply, {:ok, market}, state}
    else
      {:reply, {:error, "No market for given id"}, state}
    end
  end

  def handle_call({:market_match, id}, _, state) do
    {_, markets, betsDB} = state

    market = CubDB.get(markets, id)
    bets = market[:bets]
    back = bets[:back]
    lay = bets[:lay]

    if market == nil do # check if the market exists
      {:reply, {:error, "No market for given id"}, state}
    else
      if market[:state] == :frozen or market[:state] == :market_cancelled or market[:state] == {:market_settled, false} or market[:state] == {:market_settled, true} do # to match a market it needs to be in active state
        {:reply, {:error, "Market not available: frozen, cancelled or already settled"}, state}
      else
        lay = Enum.map(lay, fn lay_bet ->
          lay_bet = CubDB.get(betsDB, lay_bet[:bet_id]) # for every lay bet
          if lay_bet[:status] != :cancelled do # if the bet is not cancelled
            back = Enum.map(back, fn back_bet -> # we compare it with every back bet
              back_bet = CubDB.get(betsDB, back_bet[:bet_id])
              lay_bet = CubDB.get(betsDB, lay_bet[:bet_id])
              {back_bet, lay_bet} = if back_bet[:odds] <= lay_bet[:odds] and back_bet[:remaining_stake] > 0 and lay_bet[:remaining_stake] > 0 and back_bet[:status] != :cancelled do # if the back bet have lower odds, both bets have remaining stake and the back bet is not cancelled
                possible_back_stake = lay_bet[:remaining_stake]/((back_bet[:odds]/100)-1) # we calculate the amount of money from the lay bet that satisfies the back bet

                {back_bet, lay_bet} = if possible_back_stake <= back_bet[:remaining_stake] do # if the amount is less than the remaining stake of the back bet
                  back_bet = Map.put(back_bet, :matched_bets, [{lay_bet[:bet_id], lay_bet[:remaining_stake]}|back_bet[:matched_bets]]) # we add the lay bet to the matched bets of the back bet
                  lay_bet = Map.put(lay_bet, :remaining_stake, 0) # the lay bet is consumed
                  back_bet = Map.put(back_bet, :remaining_stake, trunc(back_bet[:remaining_stake]-possible_back_stake)) # the amount of stake matched with the lay bet is consumed from the back bet
                  lay_bet = Map.put(lay_bet, :matched_bets, [{back_bet[:bet_id], possible_back_stake}|lay_bet[:matched_bets]]) # we add the back bet to the matched bets of the lay bet
                  {back_bet, lay_bet}
                else # if the amount is greater than the remaining stake of the back bet
                  expected_back = (back_bet[:remaining_stake] * back_bet[:odds] / 100) - back_bet[:remaining_stake] # we calculate the expected money that the back bet will win
                  lay_bet = Map.put(lay_bet, :matched_bets, [{back_bet[:bet_id], back_bet[:remaining_stake]}|lay_bet[:matched_bets]]) # we add the back bet to the matched bets of the lay bet
                  back_bet = Map.put(back_bet, :matched_bets, [{lay_bet[:bet_id], back_bet[:remaining_stake]}|back_bet[:matched_bets]]) # we add the lay bet to the matched bets of the back bet
                  back_bet = Map.put(back_bet, :remaining_stake, 0) # the back bet is consumed
                  lay_bet = Map.put(lay_bet, :remaining_stake, trunc(lay_bet[:remaining_stake] - expected_back)) # the expected money that the back bet will win is consumed from the lay bet
                  {back_bet, lay_bet}
                end
                CubDB.put(betsDB, lay_bet[:bet_id], lay_bet)
                CubDB.put(betsDB, back_bet[:bet_id], back_bet)
                {back_bet, lay_bet}
              else
                {back_bet, lay_bet}
              end
              back_bet
            end)
            bets = Map.put(bets, :back, back)
            market = CubDB.get(markets, id)
            market = Map.put(market, :bets, bets)
            CubDB.put(markets, id, market)
          end
          CubDB.get(betsDB, lay_bet[:bet_id])
        end)
        market = CubDB.get(markets, id)
        bets = market[:bets]
        bets = Map.put(bets, :lay, lay)
        market = CubDB.get(markets, id)
        market = Map.put(market, :bets, bets)
        CubDB.put(markets, id, market)
      end
      {:reply, :ok, state}
    end
  end
end
