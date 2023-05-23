defmodule Market do
  # @spec market_create(name :: string(), description :: string()) :: {:ok, market_id}
  def handle_call({:market_create, name, description}, _, state) do
  end

  # @spec market_list():: {:ok, [market_id()]}
  def handle_call(:market_list, _, state) do
  end

  # @spec market_list_active():: {:ok, [market_id()]}
  def handle_call(:market_list_active, _, state) do
  end

  # @spec market_cancel(id :: market_id()):: :ok
  def handle_call({:market_cancel, id}, _, state) do
  end

  # @spec market_freeze(id :: market_id()):: :ok
  def handle_call({:market_freeze, id}, _, state) do
  end

  # @spec market_settle(id :: market_id(), result :: boolean()) :: :ok
  def handle_call({:market_settle, id, result}, _, state) do
  end

  # @spec market_bets(id :: market_id()) :: {:ok, Enumerable.t(bet_id())}
  def handle_call({:market_bets, id}, _, state) do

  end

  # @spec market_pending_backs(id :: market_id()) :: {:ok, Enumerable.t({integer(), bet_id()})}
  def handle_call({:market_pending_backs, id}, _, state) do
  end

  # @spec market_pending_lays(id :: market_id()) :: {:ok, Enumerable.t({integer(), bet_id()})}
  def handle_call({:market_pending_lays, id}, _, state) do
  end

  # @spec market_get(id :: market_id()()) :: {:ok, %{name: string(), description: string(), status: :active | :frozen | :cancelled | {:settled, result::bool()}}}
  def handle_call({:market_get, id}, _, state) do
  end
end
