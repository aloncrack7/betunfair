defmodule User do
  import CubDB
  use GenServer

  def init(pid) do
    {:ok, pid}
  end

  #@spec user_create(id :: string(), name :: string()) :: {:ok, user_id()}
  def handle_call({:user_create, id, name}, _, {users, bets}) do
    size = CubDB.size(users) + 1
    user_id = "u" <> Integer.to_string(size)
    allusers = CubDB.select(users)
    case Enum.to_list(Stream.filter(allusers, fn {_, %{id: x, name: _, balance: _}} -> x == id end)) do
      [] ->
        CubDB.put(users, user_id, %{id: id, name: name, balance: 0})
        {:reply, {:ok, user_id}, {users, bets}}
      _ -> {:reply, {:error, "Given id already exists"}, {users, bets}}
    end
  end

  #@spec user_deposit(id :: user_id(), amount :: integer()) :: :ok
  def handle_call({:user_deposit, id, amount}, _, {users, bets}) do
    case CubDB.has_key?(users, id) do
      true ->
          case amount >= 0 do
            true ->
              %{id: userid, name: name, balance: balance} = CubDB.get(users, id, :default)
              CubDB.put(users, id, %{id: userid, name: name, balance: balance + amount})
              {:reply, :ok, {users, bets}}
            false -> {:reply, {:error, "Given amount must be integer"}, {users, bets}}
          end
      false -> {:reply, {:error, "Given id doesn't exist"}, {users, bets}}
    end
  end

  #@spec user_withdraw(id :: user_id(), amount :: integer()):: :ok
  def handle_call({:user_withdraw, id, amount}, _,{users, bets}) do
    case CubDB.has_key?(users, id) do
      true ->
          case amount >= 0 do
            true ->
              %{id: userid, name: name, balance: balance} = CubDB.get(users, id, :default)
              case balance >= amount do
                true ->
                  CubDB.put(users, id, %{id: userid, name: name, balance: balance - amount})
                  {:reply, :ok, {users, bets}}
                false -> {:reply, {:error, "Not enough balance in account"}, {users, bets}}
              end
            false -> {:reply, {:error, "Given amount must be integer"}, {users, bets}}
          end
      false -> {:reply, {:error, "Given id doesn't exist"}, {users, bets}}
    end
  end

  #@spec user_get(id :: user_id()) :: {:ok, %{name: string(), id: user_id(), balance: integer()}}
  def handle_call({:user_get, id}, _, {users, bets}) do
    case CubDB.has_key?(users, id) do
      true ->
        userinfo = CubDB.get(users, id, :default)
        {:reply, {:ok, userinfo}, {users, bets}}
      false -> {:reply, {:error, "Given id doesn't exist"}, {users, bets}}
    end
  end

  #@spec user_bets(id :: user_id()) :: Enumerable.t(bet_id())
  def handle_call({:user_bets, id}, _, {users, bets}) do
    case CubDB.has_key?(users, id) do
      true ->
        allbets = CubDB.select(bets)
        filteredbets = Stream.filter(allbets, fn {_, map} -> map[:user_id] == id end)
        case Enum.take(filteredbets, 1) == [] do
          true -> {:reply, {:error, "No bets for given id"}, {users, bets}}
          false ->
            userbets = Enum.to_list(Stream.map(filteredbets, fn {_, map} -> map[:bet_id] end))
            {:reply, userbets, {users, bets}}
        end
      false -> {:reply, {:error, "Given id doesn't exist"}, {users, bets}}
    end
  end

end
