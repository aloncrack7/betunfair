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

  def insert_bet(bet_type, user_id, market_id, stake, odds) do
    case :dets.lookup(:users, user_id) do
      [_] ->
        case :dets.lookup(:markets, market_id) do
          [_] ->
            bet_id={"#{user_id}", "#{market_id}", "#{bet_type}", "#{DateTime.utc_now()}"}
            {back_bets, lay_bets}=:dets.lookup(:bets, market_id)[market_id]
            case bet_type do
              :back ->
                new_back_bets=insertInPlace(back_bets, {bet_id, user_id, stake, odds},
                  fn({_, _, _, odds_old}, {_, _, _, odds_new}) ->
                    odds_old<=odds_new
                  end)
                :dets.insert(:bets, {market_id, {new_back_bets, lay_bets}})
              :lay ->
                new_lay_bets=insertInPlace(lay_bets, {bet_id, user_id, stake, odds},
                  fn({_, _, _, odds_old}, {_, _, _, odds_new}) ->
                    odds_old>=odds_new
                  end)
                :dets.insert(:bets, {market_id, {back_bets, new_lay_bets}})
            end
            {:reply, bet_id}
          _ ->
            {:reply, {:error, "There is no market #{market_id}"}}
        end
      _ ->
        {:reply, {:error, "There is no user #{user_id}"}}
    end
  end

  def deleteFrom([], _) do
    []
  end

  def deleteFrom([{key, _, _, _}|t], {key, _, _, _}) do
    [t]
  end

  def deleteFrom([h|t], x) do
    [h|deleteFrom(t, x)]
  end

  # @spec bet_back(user_id :: user_id, market_id :: market_id, stake :: integer(), odds :: integer()) :: {:ok, bet_id()}
  def handle_call({:bet_back, user_id, market_id, stake, odds}, _, state) do
    insert_bet(:back, user_id, market_id, stake, odds)
  end

  # @spec bet_lay(user_id :: user_id(), market_id :: market_id(), stake :: integer(), odds :: integer()) :: {:ok, bet_id()}
  def handle_call({:bet_lay, user_id, market_id, stake, odds}, _, state) do
    insert_bet(:lay, user_id, market_id, stake, odds)
  end

  # @spec bet_cancel(id :: bet_id()):: :ok
  def handle_call({:bet_cancel, bet_id}, _, state) do
    {user_id, market_id, bet_type, _}=bet_id
    {back_bets, lay_bets}=:dets.lookup(:bets, market_id)[market_id]

    case bet_type do
      "back_bet" ->
        :dets.insert(:bets, {market_id, {deletFrom(back_bets, bet_id), lay_bets}})
      "lay_bet" ->
        :dets.insert(:bets, {market_id, {back_bets, deleteFrom(lay_bets, bet_id)}})
    end

    {:reply, :ok, state}
  end

  # @spec bet_get(id :: bet_id()) :: {:ok, %{bet_type: :back | :lay, market_id: market_id(), user_id: user_id(), odds: integer(), original_stake: integer(), remaining_stake: integer(), matched_bets: [bet_id()], status: :active | :cancelled | :market_cancelled | {:market_settled, boolean()}}}
  def handle_call({:bet_get, id}, _, state) do

  end
end
