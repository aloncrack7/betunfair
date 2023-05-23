defmodule BetUnfair do
  use GenServer
  import User
  import Market
  import Bet

  def init(pid) do
    {:ok, pid}
  end


  # @spec start_link(name :: string()) :: {:ok, _}
  def start_link(name) do
    table = :ets.new(:usuario, [:named_table])
    Process.put(:server, name)
    GenServer.start_link(BetUnfair, {}, name: name)
  end

  # @spec stop():: :ok
  def stop() do
    GenServer.stop(GenServer.server())
  end

  # @spec clean(name :: string()):: :ok
  def clean(name) do
    :ets.delete(:usuario)
    GenServer.stop(GenServer.server())
  end

  # @spec user_create(id :: string(), name :: string()) :: {:ok, user_id()}
  def user_create(id, name) do
    User.user_create(id, name)
  end

  # @spec user_deposit(id :: user_id(), amount :: integer()):: :ok
  def user_deposit(id, amount) do
    GenServer.call(Process.get(:server, :default), {:user_deposit, id, amount})
  end

  # @spec user_withdraw(id :: user_id(), amount :: integer()):: :ok
  def user_withdraw(id, amount) do
    GenServer.call(Process.get(:server, :default), {:user_withdraw, id, amount})
  end

  # @spec user_get(id :: user_id()) :: {:ok, %{name: string(), id: user_id(), balance: integer()}}
  def user_get(id) do
    GenServer.call(Process.get(:server, :default), {:user_get, id})
  end

  # @spec user_bets(id :: user_id()) :: Enumerable.t(bet_id())
  def user_bets(id) do
    GenServer.call(Process.get(:server, :default), {:user_bets, id})
  end


  # @spec market_create(name :: string(), description :: string()) :: {:ok, market_id()}
  def market_create(name, description) do
    GenServer.call(Process.get(:server, :default), {:market_create, name, description})
  end

  # @spec market_list() :: {:ok, [market_id()]}
  def market_list() do
    GenServer.call(Process.get(:server, :default), {:market_list})
  end

  # @spec market_list_active() :: {:ok, [market_id()]}
  def market_list_active() do
    GenServer.call(Process.get(:server, :default), {:market_list_active})
  end

  # @spec market_cancel(id :: market_id()) :: :ok
  def market_cancel(id) do
    GenServer.call(Process.get(:server, :default), {:market_cancel, id})
  end

  # @spec market_freeze(id :: market_id()) :: :ok
  def market_freeze(id) do
    GenServer.call(Process.get(:server, :default), {:market_freeze, id})
  end

  # @spec market_settle(id :: market_id(), result :: boolean()) :: :ok
  def market_settle(id, result) do
    GenServer.call(Process.get(:server, :default), {:market_settle, id, result})
  end

  # @spec market_bets(id :: market_id()) :: {:ok, Enumerable.t(bet_id())}
  def market_bets(id) do
    GenServer.call(Process.get(:server, :default), {:market_bets, id})
  end

  # @spec market_pending_backs(id :: market_id()) :: {:ok, Enumerable.t({integer(), bet_id()})}
  def market_pending_backs(id) do
    GenServer.call(Process.get(:server, :default), {:market_pending_backs, id})
  end

  # @spec market_pending_lays(id :: market_id()) :: {:ok, Enumerable.t({integer(), bet_id()})}
  def market_pending_lays(id) do
    GenServer.call(Process.get(:server, :default), {:market_pending_lays, id})
  end

  # @spec market_get(id :: market_id()()) :: {:ok, %{name: string(), description: string(), status: :active | :frozen | :cancelled | {:settled, result::bool()}}}
  def market_get(id) do
    GenServer.call(Process.get(:server, :default), {:market_get, id})
  end

  # @spec market_match(id :: market_id()) :: :ok
  def market_match(id) do
    GenServer.call(Process.get(:server, :default), {:market_match, id})
  end


  # @spec bet_back(user_id :: user_id(), market_id :: market_id(), stake :: integer(), odds :: integer()) :: {:ok, bet_id()}
  def bet_back(user_id, market_id, stake, odds) do
    GenServer.call(Process.get(:server, :default), {:bet_back, user_id, market_id, stake, odds})
  end

  # @spec bet_lay(user_id :: user_id(), market_id :: market_id(), stake :: integer(), odds :: integer()) :: {:ok, bet_id()}
  def bet_lay(user_id, market_id, stake, odds) do
    GenServer.call(Process.get(:server, :default), {:bet_lay, user_id, market_id, stake, odds})
  end

  # @spec bet_get(id :: bet_id()) :: {:ok, %{bet_type: :back | :lay, market_id: market_id(), user_id: user_id(), odds: integer(), original_stake: integer(), remaining_stake: integer(), matched_bets: [bet_id()], status: :active | :cancelled | :market_cancelled | {:market_settled, boolean()}}}
  def bet_get(id) do
    GenServer.call(Process.get(:server, :default), {:bet_get, id})
  end
end
