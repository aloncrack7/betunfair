defmodule Bet do
  def insertInPlace([], bet, _) do
    [bet]
  end

  def insertInPlace([h|t], bet, order) do
    case order.(h, bet) do
      true -> [h|insertInPlace(t, bet, order)]
      _ -> [bet, h | t]
    end
  end

  # @spec bet_back(user_id :: user_id, market_id :: market_id, stake :: integer(), odds :: integer()) :: {:ok, bet_id()}
  def handle_call({:bet_back, user_id, market_id, stake, odds}, _, state) do
    {back_bets, _}=:dets.select(:bets, market_id)
    new_back_bets=insertInPlace(back_bets, {user_id, stake, odds},
      fn({_, _, odds_old}, {_, _, odds_new}) ->
        odds_old<=odds_new
      end)

    :dets.insert(:bets, market_id)
  end

  # @spec bet_lay(user_id :: user_id(), market_id :: market_id(), stake :: integer(), odds :: integer()) :: {:ok, bet_id()}
  def handle_call({:bet_lay, user_id, market_id, stake, odds}, _, state) do
    {_, lay_bets}=:dets.select(:bets, market_id)
    new_back_bets=insertInPlace(lay_bets, {user_id, stake, odds},
      fn({_, _, odds_old}, {_, _, odds_new}) ->
        odds_old>=odds_new
      end)

    :dets.insert(:bets, market_id)
  end

  # @spec bet_cancel(id :: bet_id()):: :ok
  def handle_call({:bet_cancel, bet_id}, _, state) do

  end

  # @spec bet_get(id :: bet_id()) :: {:ok, %{bet_type: :back | :lay, market_id: market_id(), user_id: user_id(), odds: integer(), original_stake: integer(), remaining_stake: integer(), matched_bets: [bet_id()], status: :active | :cancelled | :market_cancelled | {:market_settled, boolean()}}}
  def handle_call({:bet_get, id}, _, state) do

  end
end
