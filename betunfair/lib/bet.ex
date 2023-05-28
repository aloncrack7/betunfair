defmodule Bet do
  import CubDB
  use GenServer

  def init(state) do
    {:ok, state}
  end

  def insertInPlace([], bet, _) do
    [bet]
  end

  def insertInPlace([h|t], bet, order) do
    case order.(h, bet) do
      true -> [h|insertInPlace(t, bet, order)]
      _ -> [bet, h | t]
    end
  end

  def insert_bet(bet_type, user_id, market_id, stake, odds, state) when odds>=100 do
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
                      old[odds]<=new[odds]
                    end)
                  market = Map.put(market, :bets, Map.put(market[:bets], :back, new_back_bets))
                  CubDB.put(state[:markets], market_id, market)
                :lay ->
                  new_lay_bets=insertInPlace(market[:bets][:lay], bet,
                    fn(old, new) ->
                      old[odds]>=new[odds]
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

  def insert_bet(bet_type, user_id, market_id, stake, odds, state) when odds<100 do
    {:reply, {:error, "The odds are not greater than 100"}, state}
  end

  # @spec bet_back(user_id :: user_id, market_id :: market_id, stake :: integer(), odds :: integer()) :: {:ok, bet_id()}
  def handle_call({:bet_back, user_id, market_id, stake, odds}, _, state) do
    insert_bet(:back, user_id, market_id, stake, odds, state)
  end

  # @spec bet_lay(user_id :: user_id(), market_id :: market_id(), stake :: integer(), odds :: integer()) :: {:ok, bet_id()}
  def handle_call({:bet_lay, user_id, market_id, stake, odds}, _, state) do
    insert_bet(:lay, user_id, market_id, stake, odds, state)
  end

  # @spec bet_cancel(id :: bet_id()):: :ok
  def handle_call({:bet_cancel, bet_id}, _, state) do
    bet=CubDB.get(state[:bets], bet_id)
    market=CubDB.get(state[:markets], bet[:market_id])

    marketState=market[:status]
    case marketState do
      :active ->
        elem=Enum.filter(market[:bets][:back]++market[:bets][:lay], fn (x) -> x[:bet_id]==bet_id end)
        |>Enum.at(0)
        |>Map.put(:status, :cancel)

        cancel_list=[elem]++market[:bets][:cancel]

        back_list=Enum.filter(market[:bets][:back], fn x -> x[:bet_id]!=bet_id end)
        lay_list=Enum.filter(market[:bets][:lay], fn x -> x[:bet_id]!=bet_id end)

        bet_map=%{back: back_list, lay: lay_list, cancel: cancel_list}

        market=Map.put(market, :bets, bet_map)
        CubDB.put(state[:markets], bet[:market_id], market)

        CubDB.put(state[:bets], bet_id, elem)

        {:reply, :ok, state}
      _ ->
        {:reply, {:error, "The market #{bet_id} is not open"}, state}
    end
  end

  # @spec bet_get(id :: bet_id()) :: {:ok, %{bet_type: :back | :lay, market_id: market_id(), user_id: user_id(), odds: integer(), original_stake: integer(), remaining_stake: integer(), matched_bets: [bet_id()], status: :active | :cancelled | :market_cancelled | {:market_settled, boolean()}}}
  def handle_call({:bet_get, bet_id}, _, state) do
    {:reply, {:ok, CubDB.get(state[:bets], bet_id)}, state}
  end
end
