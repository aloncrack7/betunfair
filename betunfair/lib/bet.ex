defmodule Bet do
  import CubDB
  use GenServer

  # The bet managing server is initialize
  def init(state) do
    {:ok, state}
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

  def insert_bet(bet_type, user_id, market_id, stake, odds, state) do
    user=CubDB.get(state[:users], user_id)

    if user==nil do
      {:reply, {:error, "There is no user #{user_id}"}, state}
    else
      market=CubDB.get(state[:markets], market_id)
      marketStatus=market[:status]
      case marketStatus do
        :active ->
          balance=user[:balance]
          case balance >= stake do
            true ->
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

              case bet_type do
                :back ->
                  new_back_bets=
                    insertInPlace(market[:bets][:back], bet,
                      fn(old, new) ->
                        old[:odds]<=new[:odds]
                      end)
                  market = Map.put(market, :bets, Map.put(market[:bets], :back, new_back_bets))
                  CubDB.put(state[:markets], market_id, market)
                :lay ->
                  new_lay_bets=insertInPlace(market[:bets][:lay], bet,
                    fn(old, new) ->
                      old[:odds]>=new[:odds]
                    end)
                  market = Map.put(market, :bets, Map.put(market[:bets], :lay, new_lay_bets))
                  CubDB.put(state[:markets], market_id, market)
              end

              user=Map.put(user, :balance, balance-stake)
              CubDB.put(state[:users], user_id, user)

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

  def insert_bet(bet_type, user_id, market_id, stake, odds, state) when is_integer(stake) or stake<100 do
    {:reply, {:error, "The stake is not an integer greater than 100"}, state}
  end

  def insert_bet(bet_type, user_id, market_id, stake, odds, state) when is_integer(odds) or odds<100 do
    {:reply, {:error, "The odds are not an integer greater than 100"}, state}
  end

  def handle_call({:bet_back, user_id, market_id, stake, odds}, _, state) do
    insert_bet(:back, user_id, market_id, stake, odds, state)
  end

  def handle_call({:bet_lay, user_id, market_id, stake, odds}, _, state) do
    insert_bet(:lay, user_id, market_id, stake, odds, state)
  end

  def handle_call({:bet_cancel, bet_id}, _, state) do
    if CubDB.has_key?(state[:bets], bet_id) == false do
      {:reply, {:error, "No bet for given id"}, state}
    else
      bet=CubDB.get(state[:bets], bet_id)
      market=CubDB.get(state[:markets], bet[:market_id])

      marketState=market[:status]
      case marketState do
        :active ->
          bet = Map.put(bet, :status, :cancelled)
          Enum.map(bet[:matched_bets], fn {m_bet_id, value} ->
            matched_bet = CubDB.get(state[:bets], m_bet_id)

            matched_bet = Map.put(matched_bet, :remaining_stake, matched_bet[:remaining_stake] + value)

            matched_bets_new = Enum.filter(matched_bet[:matched_bets], fn {id, _} -> id != bet_id end)
            matched_bet = Map.put(matched_bet, :matched_bets, matched_bets_new)
            CubDB.put(state[:bets], matched_bet[:bet_id], matched_bet)
          end)
          CubDB.put(state[:bets], bet_id, bet)

          back_list = Enum.map(market[:bets][:back], fn bet ->
            CubDB.get(state[:bets], bet[:bet_id])
          end)

          lay_list = Enum.map(market[:bets][:lay], fn bet ->
            CubDB.get(state[:bets], bet[:bet_id])
          end)

          bet_map=%{back: back_list, lay: lay_list}
          market=Map.put(market, :bets, bet_map)
          CubDB.put(state[:markets], bet[:market_id], market)

          {:reply, :ok, state}
        _ ->
          {:reply, {:error, "The market #{bet_id} is not open"}, state}
      end
    end
  end

  def handle_call({:bet_get, bet_id}, _, state) do
    if CubDB.has_key?(state[:bets], bet_id) == true do
      bet = CubDB.get(state[:bets], bet_id)

      matched_bets = Enum.map(bet[:matched_bets], fn {bet_id, value} ->
        bet_id
      end)
       bet = Map.put(bet, :matched_bets, matched_bets)
      {:reply, {:ok, bet}, state}
    else
      {:reply, {:error, "No bet for given id"}, state}
    end
  end
end
