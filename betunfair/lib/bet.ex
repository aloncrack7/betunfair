defmodule Bet do
  # @spec bet_back(user_id :: user_id, market_id :: market_id, stake :: integer(), odds :: integer()) :: {:ok, bet_id()}
  def handle_call({:bet_back, user_id, market_id, stake, odds}, _, state) do

  end


  # @spec bet_lay(user_id :: user_id(), market_id :: market_id(), stake :: integer(), odds :: integer()) :: {:ok, bet_id()}
  def handle_call({:bet_lay, user_id, market_id, stake, odds}, _, state) do

  end

  # @spec bet_cancel(id :: bet_id()):: :ok
  def handle_call({:bet_cancel, bet_id}, _, state) do

  end

  # @spec bet_get(id :: bet_id()) :: {:ok, %{bet_type: :back | :lay, market_id: market_id(), user_id: user_id(), odds: integer(), original_stake: integer(), remaining_stake: integer(), matched_bets: [bet_id()], status: :active | :cancelled | :market_cancelled | {:market_settled, boolean()}}}
  def handle_call({:bet_get, id}, _, state) do

  end
end
