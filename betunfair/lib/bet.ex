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

  def insert_bet(bet_type, user_id, market_id, stake, odds, {users, markets, bets}) do
    case CubDB.get(users, user_id) do
      user ->
        case CubDB.get(markets, market_id) do
          # TODO check market state
          market ->
            bet_id={user_id, market_id, bet_type, "#{DateTime.utc_now()}"}
            betsMap=CubDB.get(bets, market_id)
            case bet_type do
              :back ->
                new_back_bets=
                  insertInPlace(betsMap[:back],
                  %{bet_id: bet_id,
                  bet_type: bet_type,
                  market_id: market_id,
                  user_id: user_id,
                  odds: odds,
                  original_stake: stake,
                  remaining_stake: stake,
                  matched_bets: [],
                  status: :active},
                  fn(old, new) ->
                    old[odds]<=new[odds]
                  end)
                CubDB.put(bets, market_id, Map.put(betsMap, :back, new_back_bets))
              :lay ->
                new_lay_bets=insertInPlace(betsMap[:lay],
                %{bet_id: bet_id,
                bet_type: bet_type,
                market_id: market_id,
                user_id: user_id,
                odds: odds,
                original_stake: stake,
                remaining_stake: stake,
                matched_bets: [],
                status: :active},
                  fn(old, new) ->
                    old[odds]>=new[odds]
                  end)
                CubDB.put(bets, market_id, Map.put(betsMap, :lay, new_lay_bets))
            end
            {:reply, bet_id, {users, markets, bets}}
          _ ->
            {:reply, {:error, "There is no market #{market_id}"}, {users, markets, bets}}
        end
      _ ->
        {:reply, {:error, "There is no user #{user_id}"}, {users, markets, bets}}
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
  def handle_call({:bet_cancel, {user_id, market_id, type, time}}, _, {users, markets, bets}) when type!=:cancel do
    # TODO Return money to user
    bet_id={user_id, market_id, type, time}

    bet_map=CubDB.get(bets, market_id)

    elem=Enum.filter(bet_map[type], fn (x) -> x[:bet_id]==bet_id end)
    |>Enum.at(0)
    |>Map.put(:bet_type, :cancel)

    elem=Map.put(elem, :bet_id, {user_id, market_id, :cancel, time})

    cancel_list=bet_map[:cancel]++elem
    bet_map=Map.put(bet_map, :cancel, cancel_list)

    bet_list=List.delete(bet_list, fn (x) -> x[:bet_id]==bet_id end)
    bet_map=Map.put(bet_map, type, bet_list)

    CubDB.put(bets, market_id, bet_map)
    {:reply, :ok, {users, markets, bets}}
  end

  def handle_call({:bet_cancel, {user_id, market_id, type, time}}, _, {users, markets, bets}) do
    {:reply, {:error, "The bet is already canceled"}, {users, markets, bets}}
  end

  # @spec bet_get(id :: bet_id()) :: {:ok, %{bet_type: :back | :lay, market_id: market_id(), user_id: user_id(), odds: integer(), original_stake: integer(), remaining_stake: integer(), matched_bets: [bet_id()], status: :active | :cancelled | :market_cancelled | {:market_settled, boolean()}}}
  def handle_call({:bet_get, id}, _, {users, markets, bets}) do
    {_, market_id, type, _}=id

    elem=Enum.filter(CubDB.get(bets, market_id)[type], fn (x) -> x[:bet_id]==id end)
    |>Enum.at(0)
    |>Map.delete(:bet_id)
    {:reply, {:ok, elem}, {users, markets, bets}}
  end
end
