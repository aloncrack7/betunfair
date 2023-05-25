defmodule BetUnfair do
  use GenServer
  import User
  import Market
  import Bet

  def init(pid) do
    {:ok, users} = CubDB.start_link("databases/usersDB")
    {:ok, markets} = CubDB.start_link("databases/marketsDB")
    {:ok, bets} = CubDB.start_link("databases/betsDB")


    GenServer.start_link(User, {users, bets}, name: :users_server)
    GenServer.start_link(Market, {users, markets, bets}, name: :markets_server)
    GenServer.start_link(Bet, {bets}, name: :bets_server)

    {:ok, pid}
  end


  # @spec start_link(name :: string()) :: {:ok, _}
  def start_link(name) do
    Process.put(:server, name)
    GenServer.start_link(BetUnfair, {}, name: name)
  end

  # @spec stop():: :ok
  def stop() do
    Supervisor.stop(GenServer.server(), :normal)
  end

  # @spec clean(name :: string()):: :ok
  def clean(name) do
    CubDB.clear(GenServer.server())
    Supervisor.stop(GenServer.server(), :normal)
  end

  # @spec user_create(id :: string(), name :: string()) :: {:ok, user_id()}
  def user_create(id, name) do
    GenServer.call(:users_server, {:user_create, id, name})
  end

  # @spec user_deposit(id :: user_id(), amount :: integer()):: :ok
  def user_deposit(id, amount) do
    GenServer.call(:users_server, {:user_deposit, id, amount})
  end

  # @spec user_withdraw(id :: user_id(), amount :: integer()):: :ok
  def user_withdraw(id, amount) do
    GenServer.call(:users_server, {:user_withdraw, id, amount})
  end

  # @spec user_get(id :: user_id()) :: {:ok, %{name: string(), id: user_id(), balance: integer()}}
  def user_get(id) do
    GenServer.call(:users_server, {:user_get, id})
  end

  # @spec user_bets(id :: user_id()) :: Enumerable.t(bet_id())
  def user_bets(id) do
    GenServer.call(:users_server, {:user_bets, id})
  end


  # @spec market_create(name :: string(), description :: string()) :: {:ok, market_id()}
  def market_create(name, description) do
    GenServer.call(:markets_server, {:market_create, name, description})
  end

  # @spec market_list() :: {:ok, [market_id()]}
  def market_list() do
    GenServer.call(:markets_server, {:market_list})
  end

  # @spec market_list_active() :: {:ok, [market_id()]}
  def market_list_active() do
    GenServer.call(:markets_server, {:market_list_active})
  end

  # @spec market_cancel(id :: market_id()) :: :ok
  def market_cancel(id) do
    GenServer.call(:markets_server, {:market_cancel, id})
  end

  # @spec market_freeze(id :: market_id()) :: :ok
  def market_freeze(id) do
    GenServer.call(:markets_server, {:market_freeze, id})
  end

  # @spec market_settle(id :: market_id(), result :: boolean()) :: :ok
  def market_settle(id, result) do
    GenServer.call(:markets_server, {:market_settle, id, result})
  end

  # @spec market_bets(id :: market_id()) :: {:ok, Enumerable.t(bet_id())}
  def market_bets(id) do
    GenServer.call(:markets_server, {:market_bets, id})
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
    GenServer.call(:marke, {:market_get, id})
  end

  # @spec market_match(id :: market_id()) :: :ok
  def market_match(id) do
    GenServer.call(:markets_server, {:market_match, id})
  end


  # @spec bet_back(user_id :: user_id(), market_id :: market_id(), stake :: integer(), odds :: integer()) :: {:ok, bet_id()}
  def bet_back(user_id, market_id, stake, odds) do
    GenServer.call(:bets_server, {:bet_back, user_id, market_id, stake, odds})
  end

  # @spec bet_lay(user_id :: user_id(), market_id :: market_id(), stake :: integer(), odds :: integer()) :: {:ok, bet_id()}
  def bet_lay(user_id, market_id, stake, odds) do
    GenServer.call(:bets_server, {:bet_lay, user_id, market_id, stake, odds})
  end

  # @spec bet_get(id :: bet_id()) :: {:ok, %{bet_type: :back | :lay, market_id: market_id(), user_id: user_id(), odds: integer(), original_stake: integer(), remaining_stake: integer(), matched_bets: [bet_id()], status: :active | :cancelled | :market_cancelled | {:market_settled, boolean()}}}
  def bet_get(id) do
    GenServer.call(:bets_server, {:bet_get, id})
  end
end
