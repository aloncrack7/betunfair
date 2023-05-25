defmodule Bet do
  import CubDB
  use GenServer

  def init(pid) do
    {:ok, pid}
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

  def insert_bet(bet_type, user_id, market_id, stake, odds, bets) do
    case CubDB.get(users, user_id) do
      user ->
        market=CubDB.get(markets, market_id)
        case market[:state] do
          :open ->
            bet_id=%{user_id: user_id, market_id: market_id, time: "#{DateTime.utc_now()}"}
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
                  insertInPlace(market[:state][:back], bet,
                  fn(old, new) ->
                    old[odds]<=new[odds]
                  end)
                CubDB.put(bets, market_id, Map.put(market[:state], :back, new_back_bets))
              :lay ->
                new_lay_bets=insertInPlace(market[:state][:lay], bet,
                  fn(old, new) ->
                    old[odds]>=new[odds]
                  end)
                CubDB.put(bets, market_id, Map.put(market[:state], :lay, new_lay_bets))
            end

            {:reply, bet_id, bets}
          nil ->
            {:reply, {:error, "There is no market #{market_id}"}, bets}
          _ ->
            {:reply, {:error, "The market is not open"}, bets}
        end
      _ ->
        {:reply, {:error, "There is no user #{user_id}"}, bets}
    end
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
  def handle_call({:bet_cancel, bet_id}, _, bets) do
    market=CubDB.get(markets, bet_id[:market_id])

    case market[:state] do
      :open ->
        elem=Enum.filter(market[:bets][:back]++market[:bets][:lay], fn (x) -> x[:bet_id]==bet_id end)
        |>Enum.at(0)
        |>Map.put(:bet_type, :cancel)

        cancel_list=elem++market[:bets][:cancel]

        back_list=List.delete(market[:bets][:back], fn (x) -> x[:bet_id]==bet_id end)
        lay_list=List.delete(market[:bets][:lay], fn (x) -> x[:bet_id]==bet_id end)

        bet_map=%{back: back_list, lay: lay_list, cancel: cancel_list}

        market=Map.put(market, :bets, bet_map)
        CubDB.put(markets, bet_id[:market_id], market)

        {:reply, :ok, bets}
      _ ->
        {:reply, {:error, "The market #{bet_id} is not open"}, bets}
    end
  end

  # @spec bet_get(id :: bet_id()) :: {:ok, %{bet_type: :back | :lay, market_id: market_id(), user_id: user_id(), odds: integer(), original_stake: integer(), remaining_stake: integer(), matched_bets: [bet_id()], status: :active | :cancelled | :market_cancelled | {:market_settled, boolean()}}}
  def handle_call({:bet_get, bet_id}, _, bets) do
    market=CubDB.get(markets, bet_id[:market_id])

    elem=Enum.filter(market[:bets][:back]++market[:bets][:lay]++market[:bets][:cancel],
    fn (x) -> x[:bet_id]==bet_id end)
    |>Enum.at(0)
    |>Map.delete(:bet_id)
    {:reply, {:ok, elem}, bets}
  end
end
