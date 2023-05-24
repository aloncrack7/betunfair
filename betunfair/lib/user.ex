defmodule User do
  import CubDB
  use GenServer

  def init(pid) do
    {:ok, pid}
  end

  #@spec user_create(id :: string(), name :: string()) :: {:ok, user_id()}
  def handle_call({:user_create, id, name}, _, state) do
  end

  #@spec user_deposit(id :: user_id(), amount :: integer()) :: :ok
  def handle_call({:user_deposit, id, amount}, _, state) do

  end

  #@spec user_withdraw(id :: user_id(), amount :: integer()):: :ok
  def handle_call({:user_withdraw, id, amount}, _,state) do

  end

  #@spec user_get(id :: user_id()) :: {:ok, %{name: string(), id: user_id(), balance: integer()}}
  def handle_call({:user_get, id}, _, state) do

  end

  #@spec user_bets(id :: user_id()) :: Enumerable.t(bet_id())
  def handle_call({:user_bets, id}, _, state) do

  end

end
