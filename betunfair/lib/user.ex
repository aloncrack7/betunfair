defmodule User do
  import CubDB
  use GenServer

  def init(state) do
    {:ok, state}
  end

  def start_link(state) do
    GenServer.start_link(User, state, name: :users_server)
  end



  def handle_call({:user_create, id, name}, _, {users, bets}) do
    # We check if the given name is a string
    if is_binary(name) == true do
      # The id of the new user will consist of an "u" and the corresponding user number
      size = CubDB.size(users) + 1
      user_id = "u" <> Integer.to_string(size)
      allusers = CubDB.select(users)
      # We iterate over all users to see if there is already one with the given id
      case Enum.to_list(Stream.filter(allusers, fn {_, %{id: x, name: _, balance: _}} -> x == id end)) do
        [] ->
          # If the given id is a new one, the new user is created
          CubDB.put(users, user_id, %{id: id, name: name, balance: 0})
          {:reply, {:ok, user_id}, {users, bets}}
        _ -> {:reply, {:error, "Given id already exists"}, {users, bets}}
      end
    else
      {:reply, {:error, "Given name must be a string"}, {users, bets}}
    end
  end


  def handle_call({:user_deposit, id, amount}, _, {users, bets}) do
    # We check if the given id corresponds to an existing one in the system
    case CubDB.has_key?(users, id) do
      true ->
        # We check if the given amount is a positive integer
          case is_integer(amount) and amount > 0 do
            true ->
              # We check if the given amount is > 100, to avoid using decimals
              if amount < 100 do
                {:reply, {:error, "The amount is not greater than 100"}, {users, bets}}
              else
                # The given amount is added to the current user balance
                %{id: userid, name: name, balance: balance} = CubDB.get(users, id, :default)
                CubDB.put(users, id, %{id: userid, name: name, balance: balance + amount})
                {:reply, :ok, {users, bets}}
              end
            false -> {:reply, {:error, "Given amount must be a positive integer"}, {users, bets}}
          end
      false -> {:reply, {:error, "Given id doesn't exist"}, {users, bets}}
    end
  end


  def handle_call({:user_withdraw, id, amount}, _,{users, bets}) do
    # We check if the given id corresponds to an existing one in the system
    case CubDB.has_key?(users, id) do
      true ->
        # We check if the given amount is a positive integer
          case is_integer(amount) and amount > 0 do
            true ->
              # We check if the given amount is > 100, to avoid using decimals
              if amount < 100 do
                {:reply, {:error, "The amount is not greater than 100"}, {users, bets}}
              else
                # We check if there is enough balance in the account to withdraw the given amount
                %{id: userid, name: name, balance: balance} = CubDB.get(users, id, :default)
                case balance >= amount do
                  true ->
                    # The given amount is withdrawed from the user balance
                    CubDB.put(users, id, %{id: userid, name: name, balance: balance - amount})
                    {:reply, :ok, {users, bets}}
                  false -> {:reply, {:error, "Not enough balance in account"}, {users, bets}}
                end
              end
            false -> {:reply, {:error, "Given amount must be a positive integer"}, {users, bets}}
          end
      false -> {:reply, {:error, "Given id doesn't exist"}, {users, bets}}
    end
  end


  def handle_call({:user_get, id}, _, {users, bets}) do
    # We check if the given id corresponds to an existing one in the system
    case CubDB.has_key?(users, id) do
      true ->
        # We obtain the info of the given user
        userinfo = CubDB.get(users, id, :default)
        {:reply, {:ok, userinfo}, {users, bets}}
      false -> {:reply, {:error, "Given id doesn't exist"}, {users, bets}}
    end
  end


  def handle_call({:user_bets, id}, _, {users, bets}) do
    # We check if the given id corresponds to an existing one in the system
    case CubDB.has_key?(users, id) do
      true ->
        # We check if the given user has associated bets
        allbets = CubDB.select(bets)
        filteredbets = Stream.filter(allbets, fn {_, map} -> map[:user_id] == id end)
        case Enum.take(filteredbets, 1) == [] do
          true -> {:reply, {:error, "No bets for given id"}, {users, bets}}
          false ->
            # We obtain the info of the bets associated with the user
            userbets = Enum.to_list(Stream.map(filteredbets, fn {_, map} -> map[:bet_id] end))
            {:reply, userbets, {users, bets}}
        end
      false -> {:reply, {:error, "Given id doesn't exist"}, {users, bets}}
    end
  end

end
