 defmodule Market do
  import CubDB
  use GenServer

  def init(state) do
    {:ok, state}
  end

  # @spec market_create(name :: string(), description :: string()) :: {:ok, market_id}
  def handle_call({:market_create, name, description}, _, state) do
    market = %{name: name, description: description, status: :active, bets: %{back: [], lay: []}}
    {_, markets, _} = state
    size = CubDB.size(markets) + 1
    num = Integer.to_string(size)
    id = "m" <> num

    entries = CubDB.select(markets)

    result = Enum.all?(entries, fn {_, value} -> value[:name] != name end)

    if not result do
      {:reply, {:error, "Market with given name already exists"}, state}
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

    if CubDB.has_key?(markets, id) == false do
      {:reply, {:error, "No market for given id"}, state}
    else
      market = CubDB.get(markets, id)

      if market[:status] == :active or market[:status] == :frozen do
        bets = market[:bets]
        back = bets[:back]
        lay = bets[:lay]

        # modify the status bets from the back list and returning all the money to the users
        back = Enum.map(back, fn bet ->
          user = CubDB.get(users, bet[:user_id])
          user = if market[:status] == :frozen do
            Map.put(user, :balance, user[:balance])
          else
            Map.put(user, :balance, user[:balance] + bet[:original_stake])
          end
          CubDB.put(users, bet[:user_id], user)
          bet = Map.put(bet, :status, :market_cancelled)
          CubDB.put(betsDB, bet[:bet_id], bet)
          bet
        end)
        bets = Map.put(bets, :back, back)

        # modify the status bets from the lay list and returning all the money to the users
        lay = Enum.map(lay, fn bet ->
          user = CubDB.get(users, bet[:user_id])
          user = if market[:status] == :frozen do
            Map.put(user, :balance, user[:balance])
          else
            Map.put(user, :balance, user[:balance] + bet[:original_stake])
          end
          CubDB.put(users, bet[:user_id], user)
          bet = Map.put(bet, :status, :market_cancelled)
          CubDB.put(betsDB, bet[:bet_id], bet)
          bet
        end)
        bets = Map.put(bets, :lay, lay)

        market = Map.put(market, :bets, bets)
        market = Map.put(market, :status, :cancelled)
        CubDB.put(markets, id, market)

        {:reply, :ok, state}
      else
        {:reply, {:error, "Market status is not active or frozen"}, state}
      end
    end
  end

  # @spec market_freeze(id :: market_id()):: :ok
  def handle_call({:market_freeze, id}, _, state) do
    {users, markets, _} = state

    if CubDB.has_key?(markets, id) == false do
      {:reply, {:error, "No market for given id"}, state}
    else
      market = CubDB.get(markets, id)

      if market[:status] == :active do
        bets = market[:bets]
        back = bets[:back]
        lay = bets[:lay]

        # returning all the back bets money to the users who didnt match a bet
        Enum.map(back, fn bet ->
          matched_bets = bet[:matched_bets]
          if Enum.empty?(matched_bets) or bet[:status] == :cancelled do
            user = CubDB.get(users, bet[:user_id])
            user = Map.put(user, :balance, user[:balance] + bet[:original_stake])
            CubDB.put(users, bet[:user_id], user)
          end
        end)

        # returning all the lay bets money to the users who didnt match a bet
        Enum.map(lay, fn bet ->
          matched_bets = bet[:matched_bets]
          if Enum.empty?(matched_bets) or bet[:status] == :cancelled do
            user = CubDB.get(users, bet[:user_id])
            user = Map.put(user, :balance, user[:balance] + bet[:original_stake])
            CubDB.put(users, bet[:user_id], user)
          end
        end)

        market = Map.put(market, :status, :frozen)
        CubDB.put(markets, id, market)

        {:reply, :ok, state}
      else
        {:reply, {:error, "Market needs to be active"}, state}
      end
    end
  end

  # @spec market_settle(id :: market_id(), result :: boolean()) :: :ok
  def handle_call({:market_settle, id, result}, _, state) do
    {users, markets, betsDB} = state

    if CubDB.has_key?(markets, id) == false do
      {:reply, {:error, "No market for given id"}, state}
    else
      if is_boolean(result) == false do
        {:reply, {:error, "Given result must be boolean"}, state}
      else
        market = CubDB.get(markets, id)

        if market[:status] == :active or market[:status] == :frozen do
          bets = market[:bets]
          back = bets[:back]
          lay = bets[:lay]

          bets = if result == true do # back wins
            # ------------------- BACK RETURNS (WINNING)------------------- #
            back = Enum.map(back, fn bet ->
              bet = if bet[:status] != :cancelled do
                user = CubDB.get(users, bet[:user_id])
                user = if market[:status] == :frozen do
                  Map.put(user, :balance, user[:balance] + trunc((bet[:original_stake]-bet[:remaining_stake])*(bet[:odds]/100)))
                else
                  Map.put(user, :balance, user[:balance] + trunc((bet[:original_stake]-bet[:remaining_stake])*(bet[:odds]/100)) + bet[:remaining_stake])
                end
                CubDB.put(users, bet[:user_id], user)

                bet = Map.put(bet, :status, {:market_settled, result})
                CubDB.put(betsDB, bet[:bet_id], bet)
                bet
              else
                user = CubDB.get(users, bet[:user_id])
                user = if market[:status] != :frozen do
                  Map.put(user, :balance, user[:balance] + bet[:original_stake])
                end
                bet
              end
            end)
            bets = Map.put(bets, :back, back)

            # ------------------- LAY RETURNS (LOOSING)------------------- #
            lay = Enum.map(lay, fn bet ->
              bet = if bet[:status] != :cancelled do
                user = CubDB.get(users, bet[:user_id])
                user = if market[:status] == :frozen do
                  Map.put(user, :balance, user[:balance])
                else
                  Map.put(user, :balance, user[:balance] + bet[:remaining_stake])
                end
                CubDB.put(users, bet[:user_id], user)

                bet = Map.put(bet, :status, {:market_settled, result})
                CubDB.put(betsDB, bet[:bet_id], bet)
                bet
              else
                user = CubDB.get(users, bet[:user_id])
                user = if market[:status] != :frozen do
                  Map.put(user, :balance, user[:balance] + bet[:original_stake])
                end
                bet
              end
            end)
            bets = Map.put(bets, :lay, lay)
          else # lay wins
            # ------------------- LAY RETURNS (WINNING)------------------- #
            lay = Enum.map(lay, fn bet ->
              bet = if bet[:status] != :cancelled do
                user = CubDB.get(users, bet[:user_id])
                # user = Map.put(user, :balance, user[:balance] + ((bet[:original_stake]-bet[:remaining_stake])*bet[:odds]) + bet[:remaining_stake])
                balance = Enum.reduce(bet[:matched_bets], user[:balance], fn {back_bet_id, value}, acc ->
                  acc = acc + value
                end)
                user = if market[:status] == :frozen do
                  Map.put(user, :balance, trunc(balance))
                else
                  Map.put(user, :balance, trunc(balance) + bet[:remaining_stake])
                end
                CubDB.put(users, bet[:user_id], user)

                bet = Map.put(bet, :status, {:market_settled, result})
                CubDB.put(betsDB, bet[:bet_id], bet)
                bet
              else
                user = CubDB.get(users, bet[:user_id])
                user = if market[:status] != :frozen do
                  Map.put(user, :balance, user[:balance] + bet[:original_stake])
                end
                bet
              end
            end)
            bets = Map.put(bets, :lay, lay)

            # ------------------- BACK RETURNS (LOOSING)------------------- #
            back = Enum.map(back, fn bet ->
              bet = if bet[:status] != :cancelled do
                user = CubDB.get(users, bet[:user_id])
                user = if market[:status] == :frozen do
                  Map.put(user, :balance, user[:balance])
                else
                  Map.put(user, :balance, user[:balance] + bet[:remaining_stake])
                end
                CubDB.put(users, bet[:user_id], user)

                bet = Map.put(bet, :status, {:market_settled, result})
                CubDB.put(betsDB, bet[:bet_id], bet)
                bet
              else
                user = CubDB.get(users, bet[:user_id])
                if market[:status] != :frozen do
                  Map.put(user, :balance, user[:balance] + bet[:original_stake])
                end
                bet
              end
            end)
            bets = Map.put(bets, :back, back)
          end

          market = Map.put(market, :bets, bets)
          market = Map.put(market, :status, {:market_settled, result})
          CubDB.put(markets, id, market)

          {:reply, :ok, state}
        else
          {:reply, {:error, "Market status is not active or frozen"}, state}
        end
      end
    end
  end

  # @spec market_bets(id :: market_id()) :: {:ok, Enumerable.t(bet_id())}
  def handle_call({:market_bets, id}, _, state) do
    {_, markets, _} = state

    if CubDB.has_key?(markets, id) == true do
      market = CubDB.get(markets, id)
      bets = market[:bets]
      back = bets[:back]
      lay = bets[:lay]

      back_list = List.foldl(back, [], fn (x, acc) -> [x[:bet_id]]++acc end)
      lay_list = List.foldl(lay, [], fn (x, acc) -> [x[:bet_id]]++acc end)

      result_list = back_list ++ lay_list
      {:reply, {:ok, result_list}, state}
    else
      {:reply, {:error, "No market for given id"}, state}
    end
  end

  # @spec market_pending_backs(id :: market_id()) :: {:ok, Enumerable.t({integer(), bet_id()})}
  def handle_call({:market_pending_backs, id}, _, state) do
    {_, markets, _} = state

    if CubDB.has_key?(markets, id) == true do
      market = CubDB.get(markets, id)
      bets = market[:bets]
      back = bets[:back]
      lay = bets[:lay]

      back_results = Enum.filter(back, fn bet ->
        Enum.empty?(bet[:matched_bets]) == true
      end)
      back_results = Enum.map(back_results, fn bet ->
        {bet[:odds], bet[:bet_id]}
      end)

      {:reply, {:ok, back_results}, state}
    else
      {:reply, {:error, "No market for given id"}, state}
    end
  end

  # @spec market_pending_lays(id :: market_id()) :: {:ok, Enumerable.t({integer(), bet_id()})}
  def handle_call({:market_pending_lays, id}, _, state) do
    {_, markets, _} = state

    if CubDB.has_key?(markets, id) == true do
      market = CubDB.get(markets, id)
      bets = market[:bets]
      back = bets[:back]
      lay = bets[:lay]

      lay_results = Enum.filter(lay, fn bet ->
        Enum.empty?(bet[:matched_bets]) == true
      end)
      lay_results = Enum.map(lay_results, fn bet ->
        {bet[:odds], bet[:bet_id]}
      end)

      {:reply, {:ok, lay_results}, state}
    else
      {:reply, {:error, "No market for given id"}, state}
    end
  end

  # @spec market_get(id :: market_id()()) :: {:ok, %{name: string(), description: string(), status: :active | :frozen | :cancelled | {:settled, result::bool()}}}
  def handle_call({:market_get, id}, _, state) do
    {_, markets, _} = state

    if CubDB.has_key?(markets, id) == true do
      market = CubDB.get(markets, id)
      market = Map.delete(market, :bets)
      {:reply, {:ok, market}, state}
    else
      {:reply, {:error, "No market for given id"}, state}
    end
  end

  # @spec market_match(id :: market_id()):: :ok
  # def handle_call({:market_match, id}, _, state) do
  #   {_, markets, betsDB} = state

  #   market = CubDB.get(markets, id)
  #   bets = market[:bets]
  #   back = bets[:back]
  #   lay = bets[:lay]

  #   if market==nil do
  #     {:reply, {:error, "No market for given id"}, state}
  #   else
  #     if market[:state] == :frozen or market[:state] == :market_cancelled or market[:state] == {:market_settled, false} or market[:state] == {:market_settled, true} do
  #       {:reply, {:error, "Market not available: frozen, cancelled or already settled"}, state}
  #     else
  #       back = Enum.map(back, fn back_bet ->
  #         if back_bet[:status] != :cancelled do
  #           lay = Enum.map(lay, fn lay_bet ->
  #             if back_bet[:odds] <= lay_bet[:odds] and back_bet[:remaining_stake] >= 0 and lay_bet[:remaining_stake] >= 0 and lay_bet[:status] != :cancelled do
  #               expected_back = (back_bet[:remaining_stake] * trunc(lay_bet[:odds] / 100)) - back_bet[:remaining_stake]
  #               expected_lay = (lay_bet[:remaining_stake] * trunc(lay_bet[:odds] / 100)) - lay_bet[:remaining_stake]

  #               back_bet = Map.put(back_bet, :matched_bets, [lay_bet[:bet_id]|back_bet[:matched_bets]])
  #               lay_bet = Map.put(lay_bet, :matched_bets, [back_bet[:bet_id]|lay_bet[:matched_bets]])

  #               # if lay_bet[:remaining_stake] >= expected_back and back_bet[:remaining_stake] >= expected_lay do
  #               #   back_bet = Map.put(back_bet, :remaining_stake, back_bet[:remaining_stake] - expected_lay)
  #               #   lay_bet = Map.put(lay_bet, :remaining_stake, lay_bet[:remaining_stake] - expected_back)
  #               # end

  #               # if lay_bet[:remaining_stake] >= expected_back and back_bet[:remaining_stake] < expected_lay do
  #               #   back_bet = Map.put(back_bet, :remaining_stake, 0)
  #               #   lay_bet = Map.put(lay_bet, :remaining_stake, lay_bet[:remaining_stake] - expected_back)
  #               # end

  #               # if back_bet[:remaining_stake] >= expected_lay and lay_bet[:remaining_stake] < expected_back do
  #               #   back_bet = Map.put(back_bet, :remaining_stake, back_bet[:remaining_stake] - expected_lay)
  #               #   lay_bet = Map.put(lay_bet, :remaining_stake, 0)
  #               # end

  #               # if lay_bet[:remaining_stake] < expected_back and back_bet[:remaining_stake] < expected_lay do
  #               #   expected_back_stake = lay_bet[:remaining_stake]/(lay_bet[:odds]-1)

  #               #   expected_lay_stake = back_bet[:remaining_stake]/(back_bet[:odds]-1)

  #               #   back_bet = Map.put(back_bet, :remaining_stake, back_bet[:remaining_stake] - expected_lay)
  #               #   lay_bet = Map.put(lay_bet, :remaining_stake, lay_bet[:remaining_stake] - expected_back)
  #               # end

  #               if expected_lay <= back_bet[:remaining_stake] do
  #                 Map.put(back_bet, :remaining_stake, back_bet[:remaining_stake] - expected_lay)
  #                 Map.put(lay_bet, :remaining_stake, 0)
  #               else
  #                 expected_lay_stake = back_bet[:remaining_stake]/(lay_bet[:odds]-1)
  #                 Map.put(back_bet, :remaining_stake, 0)
  #                 Map.put(lay_bet, :remaining_stake, lay_bet[:remaining_stake]-expected_lay_stake)
  #               end


  #               if expected_back >= lay_bet[:remaining_stake] do
  #                 lay_bet = Map.put(lay_bet, :remaining_stake, 0)

  #                 if expected_lay >= back_bet[:remaining_stake] do
  #                   back_bet = Map.put(back_bet, :remaining_stake, 0)
  #                 else
  #                   back_bet = Map.put(back_bet, :remaining_stake, back_bet[:remaining_stake] - expected_lay)
  #                 end
  #               else
  #                 back_bet = Map.put(back_bet, :remaining_stake, 0)

  #                 if expected_back >= lay_bet[:remaining_stake] do
  #                   lay_bet = Map.put(lay_bet, :remaining_stake, 0)
  #                 else
  #                   lay_bet = Map.put(lay_bet, :remaining_stake, lay_bet[:remaining_stake] - expected_back)
  #                 end
  #               end












  #             end
  #             CubDB.put(betsDB, lay_bet[:bet_id], lay_bet)
  #             lay_bet
  #           end)
  #           CubDB.put(betsDB, back_bet[:bet_id], back_bet)
  #           back_bet
  #         end
  #       end)
  #       bets = Map.put(bets, :back, back)
  #       bets = Map.put(bets, :lay, lay)
  #       Map.put(market, :bets, bets)
  #       CubDB.put(markets, id, market)
  #     end
  #     {:reply, :ok, state}
  #   end
  # end

  def handle_call({:market_match, id}, _, state) do
    {_, markets, betsDB} = state

    market = CubDB.get(markets, id)
    bets = market[:bets]
    back = bets[:back]
    lay = bets[:lay]

    if market == nil do
      {:reply, {:error, "No market for given id"}, state}
    else
      if market[:state] == :frozen or market[:state] == :market_cancelled or market[:state] == {:market_settled, false} or market[:state] == {:market_settled, true} do
        {:reply, {:error, "Market not available: frozen, cancelled or already settled"}, state}
      else
        lay = Enum.map(lay, fn lay_bet ->
          lay_bet = CubDB.get(betsDB, lay_bet[:bet_id])
          if lay_bet[:status] != :cancelled do
            back = Enum.map(back, fn back_bet ->
              back_bet = CubDB.get(betsDB, back_bet[:bet_id])
              lay_bet = CubDB.get(betsDB, lay_bet[:bet_id])
              {back_bet, lay_bet} = if back_bet[:odds] <= lay_bet[:odds] and back_bet[:remaining_stake] > 0 and lay_bet[:remaining_stake] > 0 and back_bet[:status] != :cancelled do
                # back_bet = Map.put(back_bet, :matched_bets, [lay_bet[:bet_id]|back_bet[:matched_bets]])
                # lay_bet = Map.put(lay_bet, :matched_bets, [back_bet[:bet_id]|lay_bet[:matched_bets]])

                # expected_back = trunc((back_bet[:remaining_stake] * back_bet[:odds] / 100) - back_bet[:remaining_stake])
                # #expected_lay = trunc((lay_bet[:remaining_stake] * lay_bet[:odds] / 100) - lay_bet[:remaining_stake])
                # expected_lay = lay_bet[:remaining_stake]/((back_bet[:odds]/100)-1)

                # {back_bet, lay_bet} = if expected_back >= lay_bet[:remaining_stake] do
                #                 lay_bet = Map.put(lay_bet, :remaining_stake, 0)

                #                 back_bet = if expected_lay >= back_bet[:remaining_stake] do
                #                     back_bet = Map.put(back_bet, :remaining_stake, 0)
                #                   else
                #                     back_bet = Map.put(back_bet, :remaining_stake, trunc(back_bet[:remaining_stake] - expected_lay))
                #                   end
                #                   {back_bet, lay_bet}
                #                 else
                #                   back_bet = Map.put(back_bet, :remaining_stake, 0)

                #                   lay_bet = if expected_back >= lay_bet[:remaining_stake] do
                #                     lay_bet = Map.put(lay_bet, :remaining_stake, 0)
                #                   else
                #                     lay_bet = Map.put(lay_bet, :remaining_stake, trunc(lay_bet[:remaining_stake] - expected_back))
                #                   end
                #                   {back_bet, lay_bet}
                #                 end
                # Tristán
                possible_back_stake = lay_bet[:remaining_stake]/((back_bet[:odds]/100)-1)

                {back_bet, lay_bet} = if possible_back_stake <= back_bet[:remaining_stake] do
                  back_bet = Map.put(back_bet, :matched_bets, [{lay_bet[:bet_id], lay_bet[:remaining_stake]}|back_bet[:matched_bets]])
                  lay_bet = Map.put(lay_bet, :remaining_stake, 0)
                  back_bet = Map.put(back_bet, :remaining_stake, trunc(back_bet[:remaining_stake]-possible_back_stake))
                  lay_bet = Map.put(lay_bet, :matched_bets, [{back_bet[:bet_id], possible_back_stake}|lay_bet[:matched_bets]])
                  {back_bet, lay_bet}
                else
                  expected_back = (back_bet[:remaining_stake] * back_bet[:odds] / 100) - back_bet[:remaining_stake]
                  lay_bet = Map.put(lay_bet, :matched_bets, [{back_bet[:bet_id], back_bet[:remaining_stake]}|lay_bet[:matched_bets]])
                  back_bet = Map.put(back_bet, :matched_bets, [{lay_bet[:bet_id], back_bet[:remaining_stake]}|back_bet[:matched_bets]])
                  back_bet = Map.put(back_bet, :remaining_stake, 0)
                  lay_bet = Map.put(lay_bet, :remaining_stake, trunc(lay_bet[:remaining_stake] - expected_back))
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


  # def handle_call({:market_match, id}, _, state) do
  #   {_, markets, betsDB} = state

  #   market = CubDB.get(markets, id)
  #   bets = market[:bets]
  #   back = bets[:back]
  #   lay = bets[:lay]

  #   if market == nil do
  #     {:reply, {:error, "No market for given id"}, state}
  #   else
  #     if market[:state] == :frozen or market[:state] == :market_cancelled or market[:state] == {:market_settled, false} or market[:state] == {:market_settled, true} do
  #       {:reply, {:error, "Market not available: frozen, cancelled or already settled"}, state}
  #     else
  #       lay = Enum.map(lay, fn lay_bet ->
  #         lay_bet = if lay_bet[:status] != :cancelled do
  #           IO.puts(lay_bet[:bet_id])
  #           back = Enum.map(back, fn back_bet ->
  #             {back_bet, lay_bet} = if back_bet[:odds] <= lay_bet[:odds] and back_bet[:remaining_stake] >= 0 and lay_bet[:remaining_stake] >= 0 and back_bet[:status] != :cancelled do
  #                                     IO.puts(back_bet[:bet_id])
  #                                     expected_back = trunc((back_bet[:remaining_stake] * back_bet[:odds] / 100) - back_bet[:remaining_stake])
  #                                     expected_lay = trunc((lay_bet[:remaining_stake] * lay_bet[:odds] / 100) - lay_bet[:remaining_stake])

  #                                     back_bet = Map.put(back_bet, :matched_bets, [lay_bet[:bet_id]|back_bet[:matched_bets]])
  #                                     lay_bet = Map.put(lay_bet, :matched_bets, [back_bet[:bet_id]|lay_bet[:matched_bets]])
  #                                     IO.puts("#{inspect lay_bet}")

  #                                     {back_bet, lay_bet} = if expected_back >= lay_bet[:remaining_stake] do
  #                                                             lay_bet = Map.put(lay_bet, :remaining_stake, 0)

  #                                                             back_bet = if expected_lay >= back_bet[:remaining_stake] do
  #                                                                           back_bet = Map.put(back_bet, :remaining_stake, 0)
  #                                                                         else
  #                                                                           back_bet = Map.put(back_bet, :remaining_stake, back_bet[:remaining_stake] - expected_lay)
  #                                                                         end
  #                                                             {back_bet, lay_bet}
  #                                                           else
  #                                                             back_bet = Map.put(back_bet, :remaining_stake, 0)

  #                                                             lay_bet = if expected_back >= lay_bet[:remaining_stake] do
  #                                                                         lay_bet = Map.put(lay_bet, :remaining_stake, 0)
  #                                                                       else
  #                                                                         lay_bet = Map.put(lay_bet, :remaining_stake, lay_bet[:remaining_stake] - expected_back)
  #                                                                       end
  #                                                             {back_bet, lay_bet}
  #                                                           end
  #                                     IO.puts("#{inspect lay_bet}")
  #                                     IO.puts("#{inspect back_bet}")
  #                                     {back_bet, lay_bet}
  #                                   else
  #                                     {back_bet, lay_bet}
  #                                   end
  #             IO.puts("#{inspect lay_bet}")
  #             CubDB.put(betsDB, lay_bet[:bet_id], lay_bet)
  #             CubDB.put(betsDB, back_bet[:bet_id], back_bet)
  #             back_bet
  #           end)
  #           #IO.puts("#{inspect lay_bet}")
  #           bets = Map.put(bets, :back, back)
  #           market = Map.put(market, :bets, bets)
  #           CubDB.put(markets, id, market)
  #           CubDB.put(betsDB, lay_bet[:bet_id], lay_bet)
  #           lay_bet
  #         end
  #       end)
  #       bets = Map.put(bets, :lay, lay)
  #       market = Map.put(market, :bets, bets)
  #       CubDB.put(markets, id, market)
  #     end
  #     {:reply, :ok, state}
  #   end
  # end
end
