defmodule Bet do
  import CubDB
  use GenServer

  # The bet managing server is initialize
  def init(state) do
    {:ok, state}
  end

  def start_link(state) do
    GenServer.start_link(Bet, state, name: :bets_server)
  end


  # Insert a bet in order, the order is defined by fuction
  # If the list is empty the bet goes there
  def insertInPlace([], bet, _) do
    [bet]
  end

  # Insert a bet in order, the order is defined by fuction
  # If the list is condition is for the inserting behind is not met,
  # the new bet will be set into place. In other cases the bet will
  # be inserted recursively calling this function
  def insertInPlace([h|t], bet, order) do
    case order.(h, bet) do
      true -> [h|insertInPlace(t, bet, order)]
      _ -> [bet, h | t]
    end
  end

  # Insert into the database a new bet, whether is a back bet or a lay bet
  def insert_bet(bet_type, user_id, market_id, stake, odds, state) do
    user=CubDB.get(state[:users], user_id)

    # Check if the user exists
    if user==nil do
      {:reply, {:error, "There is no user #{user_id}"}, state}
    else
      market=CubDB.get(state[:markets], market_id)
      marketStatus=market[:status]

      # Check if the market exists and is active
      case marketStatus do
        :active ->
          balance=user[:balance]

          # Checks if the user has enough balance to make the bet
          case balance >= stake do
            true ->
              # Creates the bets and its ID
              bet_id="bb#{CubDB.size(state[:bets])+1}"
              bet=%{bet_id: bet_id,
                bet_type: bet_type,
                market_id: market_id,
                user_id: user_id,
                odds: odds,
                original_stake: stake,
                remaining_stake: stake,
                matched_bets: [],
                status: :active}

              # Inserts the bet into the place, defining the order function,
              case bet_type do
                :back ->
                  new_back_bets=
                    insertInPlace(market[:bets][:back], bet,
                      # Ascending order for back bets
                      fn(old, new) ->
                        old[:odds]<=new[:odds]
                      end)
                  market = Map.put(market, :bets, Map.put(market[:bets], :back, new_back_bets))
                  CubDB.put(state[:markets], market_id, market)
                :lay ->
                  new_lay_bets=insertInPlace(market[:bets][:lay], bet,
                    # Descending order for lay bets
                    fn(old, new) ->
                      old[:odds]>=new[:odds]
                    end)
                  # The bet is inserted to the market database
                  market = Map.put(market, :bets, Map.put(market[:bets], :lay, new_lay_bets))
                  CubDB.put(state[:markets], market_id, market)
              end

              # The stake is taken form the user
              user=Map.put(user, :balance, balance-stake)
              CubDB.put(state[:users], user_id, user)

              # The is inserted into the bet database
              CubDB.put(state[:bets], bet_id, bet)
              {:reply, {:ok, bet_id}, state}
            false ->
              {:reply, {:error, "There is not enough money to make the bet"}, state}
          end

        nil ->
          {:reply, {:error, "There is no market #{market_id}"}, state}
        _ ->
          {:reply, {:error, "The market is not open"}, state}
      end
    end
  end

  # The stake is not a integer, error
  def insert_bet(bet_type, user_id, market_id, stake, odds, state) when is_integer(stake) or stake<100 do
    {:reply, {:error, "The stake is not an integer greater than 100"}, state}
  end

  # The odds are not a integer, error
  def insert_bet(bet_type, user_id, market_id, stake, odds, state) when is_integer(odds) or odds<100 do
    {:reply, {:error, "The odds are not an integer greater than 100"}, state}
  end

  # Inserts back bet, uses insert bet, error
  def handle_call({:bet_back, user_id, market_id, stake, odds}, _, state) do
    insert_bet(:back, user_id, market_id, stake, odds, state)
  end

  # Inserts lay bet, uses insert bet, error
  def handle_call({:bet_lay, user_id, market_id, stake, odds}, _, state) do
    insert_bet(:lay, user_id, market_id, stake, odds, state)
  end

  # Cancels a bet
  def handle_call({:bet_cancel, bet_id}, _, state) do
    # In the case the bet exists
    if CubDB.has_key?(state[:bets], bet_id) == false do
      {:reply, {:error, "No bet for given id"}, state}
    else
      # Get the bet and the market in which is contain
      bet=CubDB.get(state[:bets], bet_id)
      market=CubDB.get(state[:markets], bet[:market_id])

      # If the market is active
      marketState=market[:status]
      case marketState do
        :active ->
          # The bet status is updated
          bet = Map.put(bet, :status, :cancelled)
          CubDB.put(state[:bets], bet_id, bet)

          if bet[:bet_type] == :back do
            back_list = Enum.map(market[:bets][:back], fn bet_back ->
              bet_back = if bet_back[:bet_id] == bet_id do
                bet_back = Map.put(bet_back, :status, :cancelled)
              else
                bet_back
              end
            end)
            bets = Map.put(market[:bets], :back, back_list)
            market = Map.put(market, :bets, bets)
            CubDB.put(state[:markets], bet[:market_id], market)
          else
            lay_list = Enum.map(market[:bets][:lay], fn bet_lay ->
              bet_lay = if bet_lay[:bet_id] == bet_id do
                bet_lay = Map.put(bet_lay, :status, :cancelled)
              else
                bet_lay
              end
            end)
            bets = Map.put(market[:bets], :lay, lay_list)
            market = Map.put(market, :bets, bets)
            CubDB.put(state[:markets], bet[:market_id], market)
          end

          {:reply, :ok, state}
        _ ->
          {:reply, {:error, "The market #{bet_id} is not open"}, state}
      end
    end
  end

  # Get the information from a bet
  def handle_call({:bet_get, bet_id}, _, state) do
    # If the bet exists
    if CubDB.has_key?(state[:bets], bet_id) == true do
      bet = CubDB.get(state[:bets], bet_id)

      # Get rid of the cuantity mactched to display the bet
      matched_bets = Enum.map(bet[:matched_bets], fn {bet_id, value} ->
        bet_id
      end)

      # Return the bet
      bet = Map.put(bet, :matched_bets, matched_bets)
      {:reply, {:ok, bet}, state}
    else
      {:reply, {:error, "No bet for given id"}, state}
    end
  end
end
