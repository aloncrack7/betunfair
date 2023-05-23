defmodule BetunfairTest do
  use ExUnit.Case
  import Bet

  test "user_create_deposit_get" do
    assert {:ok,_} = Betunfair.clean("testdb")
    assert  {:ok,_} = Betunfair.start_link("testdb")
    assert {:ok,u1} = Betunfair.user_create("u1","Francisco Gonzalez")
    assert is_error(Betunfair.user_create("u1","Francisco Gonzalez"))
    assert is_ok(Betunfair.user_deposit(u1,2000))
    assert is_error(Betunfair.user_deposit(u1,-1))
    assert is_error(Betunfair.user_deposit(u1,0))
    assert is_error(Betunfair.user_deposit("u11",0))
    assert {:ok,%{balance: 2000}} = Betunfair.user_get(u1)
  end

  test "user_bet1" do
    assert {:ok,_} = Betunfair.clean("testdb")
    assert  {:ok,_} = Betunfair.start_link("testdb")
    assert {:ok,u1} = Betunfair.user_create("u1","Francisco Gonzalez")
    assert is_ok(Betunfair.user_deposit(u1,2000))
    assert {:ok,%{balance: 2000}} = Betunfair.user_get(u1)
    assert {:ok,m1} = Betunfair.market_create("rmw","Real Madrid wins")
    assert {:ok,b} = Betunfair.bet_back(u1,m1,1000,150)
    assert {:ok,%{id: ^b, bet_type: :back, stake: 1000, odds: 150, status: :active}} = Betunfair.bet_get(b)
    assert {:ok,markets} = Betunfair.market_list()
    assert 1 = length(markets)
    assert {:ok,markets} = Betunfair.market_list_active()
    assert 1 = length(markets)
  end

  test "user_persist" do
    assert {:ok,_} = Betunfair.clean("testdb")
    assert  {:ok,_} = Betunfair.start_link("testdb")
    assert {:ok,u1} = Betunfair.user_create("u1","Francisco Gonzalez")
    assert is_ok(Betunfair.user_deposit(u1,2000))
    assert {:ok,%{balance: 2000}} = Betunfair.user_get(u1)
    assert {:ok,m1} = Betunfair.market_create("rmw","Real Madrid wins")
    assert {:ok,b} = Betunfair.bet_back(u1,m1,1000,150)
    assert {:ok,%{id: ^b, bet_type: :back, stake: 1000, odds: 150, status: :active}} = Betunfair.bet_get(b)
    assert is_ok(Betunfair.stop())
    assert  {:ok,_} = Betunfair.start_link("testdb")
    assert {:ok,%{balance: 1000}} = Betunfair.user_get(u1)
    assert {:ok,markets} = Betunfair.market_list()
    assert 1 = length(markets)
    assert {:ok,markets} = Betunfair.market_list_active()
    assert 1 = length(markets)
  end

  test "match_bets1" do
    assert {:ok,_} = Betunfair.clean("testdb")
    assert  {:ok,_} = Betunfair.start_link("testdb")
    assert {:ok,u1} = Betunfair.user_create("u1","Francisco Gonzalez")
    assert {:ok,u2} = Betunfair.user_create("u2","Maria Fernandez")
    assert is_ok(Betunfair.user_deposit(u1,2000))
    assert is_ok(Betunfair.user_deposit(u2,2000))
    assert {:ok,%{balance: 2000}} = Betunfair.user_get(u1)
    assert {:ok,m1} = Betunfair.market_create("rmw","Real Madrid wins")
    assert {:ok,bb1} = Betunfair.bet_back(u1,m1,1000,150)
    assert {:ok,bb2} = Betunfair.bet_back(u1,m1,1000,153)
    assert {:ok,%{balance: 0}} = Betunfair.user_get(u1)
    assert true = (bb1 != bb2)
    assert {:ok,bl1} = Betunfair.bet_lay(u2,m1,500,140)
    assert {:ok,bl2} = Betunfair.bet_lay(u2,m1,500,150)
    assert {:ok,%{balance: 1000}} = Betunfair.user_get(u2)
    assert {:ok, backs} = Betunfair.market_pending_backs(m1)
    assert [^bb1,^bb2] = Enum.to_list(backs) |> Enum.map(fn (e) -> elem(e,1) end)
    assert {:ok,lays} = Betunfair.market_pending_lays(m1)
    assert [^bl2,^bl1] = Enum.to_list(lays) |> Enum.map(fn (e) -> elem(e,1) end)
    assert is_ok(Betunfair.market_match(m1))
    assert {:ok,%{stake: 0}} = Betunfair.bet_get(bb1)
    assert {:ok,%{stake: 0}} = Betunfair.bet_get(bl2)
  end

  test "match_bets2" do
    assert {:ok,_} = Betunfair.clean("testdb")
    assert  {:ok,_} = Betunfair.start_link("testdb")
    assert {:ok,u1} = Betunfair.user_create("u1","Francisco Gonzalez")
    assert {:ok,u2} = Betunfair.user_create("u2","Maria Fernandez")
    assert is_ok(Betunfair.user_deposit(u1,2000))
    assert is_ok(Betunfair.user_deposit(u2,2000))
    assert {:ok,%{balance: 2000}} = Betunfair.user_get(u1)
    assert {:ok,m1} = Betunfair.market_create("rmw","Real Madrid wins")
    assert {:ok,bb1} = Betunfair.bet_back(u1,m1,1000,150)
    assert {:ok,bb2} = Betunfair.bet_back(u1,m1,1000,153)
    assert {:ok,%{balance: 0}} = Betunfair.user_get(u1)
    assert true = (bb1 != bb2)
    assert {:ok,_bl1} = Betunfair.bet_lay(u2,m1,1000,140)
    assert {:ok,bl2} = Betunfair.bet_lay(u2,m1,1000,150)
    assert {:ok,%{balance: 0}} = Betunfair.user_get(u2)
    assert is_ok(Betunfair.market_match(m1))
    assert {:ok,%{stake: 0}} = Betunfair.bet_get(bb1)
    assert {:ok,%{stake: 500}} = Betunfair.bet_get(bl2)
  end

  test "match_bets3" do
    assert {:ok,_} = Betunfair.clean("testdb")
    assert  {:ok,_} = Betunfair.start_link("testdb")
    assert {:ok,u1} = Betunfair.user_create("u1","Francisco Gonzalez")
    assert {:ok,u2} = Betunfair.user_create("u2","Maria Fernandez")
    assert is_ok(Betunfair.user_deposit(u1,2000))
    assert is_ok(Betunfair.user_deposit(u2,2000))
    assert {:ok,%{balance: 2000}} = Betunfair.user_get(u1)
    assert {:ok,m1} = Betunfair.market_create("rmw","Real Madrid wins")
    assert {:ok,bb1} = Betunfair.bet_back(u1,m1,1000,150)
    assert {:ok,bb2} = Betunfair.bet_back(u1,m1,1000,153)
    assert {:ok,%{balance: 0}} = Betunfair.user_get(u1)
    assert true = (bb1 != bb2)
    assert {:ok,_bl1} = Betunfair.bet_lay(u2,m1,100,140)
    assert {:ok,bl2} = Betunfair.bet_lay(u2,m1,100,150)
    assert {:ok,%{balance: 1800}} = Betunfair.user_get(u2)
    assert is_ok(Betunfair.market_match(m1))
    assert {:ok,%{stake: 800}} = Betunfair.bet_get(bb1)
    assert {:ok,%{stake: 0}} = Betunfair.bet_get(bl2)
    assert {:ok,user_bets} = Betunfair.user_bets(u1)
    assert 2 = length(user_bets)
  end

  test "match_bets4" do
    assert {:ok,_} = Betunfair.clean("testdb")
    assert  {:ok,_} = Betunfair.start_link("testdb")
    assert {:ok,u1} = Betunfair.user_create("u1","Francisco Gonzalez")
    assert {:ok,u2} = Betunfair.user_create("u2","Maria Fernandez")
    assert is_ok(Betunfair.user_deposit(u1,2000))
    assert is_ok(Betunfair.user_deposit(u2,2000))
    assert {:ok,%{balance: 2000}} = Betunfair.user_get(u1)
    assert {:ok,m1} = Betunfair.market_create("rmw","Real Madrid wins")
    assert {:ok,bb1} = Betunfair.bet_back(u1,m1,1000,150)
    assert {:ok,bb2} = Betunfair.bet_back(u1,m1,1000,153)
    assert {:ok,%{balance: 0}} = Betunfair.user_get(u1)
    assert true = (bb1 != bb2)
    assert {:ok,_bl1} = Betunfair.bet_lay(u2,m1,100,140)
    assert {:ok,_bl2} = Betunfair.bet_lay(u2,m1,100,150)
    assert {:ok,%{balance: 1800}} = Betunfair.user_get(u2)
    assert is_ok(Betunfair.market_match(m1))
    assert is_ok(Betunfair.market_cancel(m1))
    assert {:ok,%{balance: 2000}} = Betunfair.user_get(u1)
    assert {:ok,%{balance: 2000}} = Betunfair.user_get(u2)
  end

  test "match_bets5" do
    assert {:ok,_} = Betunfair.clean("testdb")
    assert  {:ok,_} = Betunfair.start_link("testdb")
    assert {:ok,u1} = Betunfair.user_create("u1","Francisco Gonzalez")
    assert {:ok,u2} = Betunfair.user_create("u2","Maria Fernandez")
    assert is_ok(Betunfair.user_deposit(u1,2000))
    assert is_ok(Betunfair.user_deposit(u2,2000))
    assert {:ok,%{balance: 2000}} = Betunfair.user_get(u1)
    assert {:ok,m1} = Betunfair.market_create("rmw","Real Madrid wins")
    assert {:ok,bb1} = Betunfair.bet_back(u1,m1,1000,150)
    assert {:ok,bb2} = Betunfair.bet_back(u1,m1,1000,153)
    assert {:ok,%{balance: 0}} = Betunfair.user_get(u1)
    assert true = (bb1 != bb2)
    assert {:ok,_bl1} = Betunfair.bet_lay(u2,m1,100,140)
    assert {:ok,_bl2} = Betunfair.bet_lay(u2,m1,100,150)
    assert {:ok,%{balance: 1800}} = Betunfair.user_get(u2)
    assert is_ok(Betunfair.market_match(m1))
    assert is_ok(Betunfair.market_settle(m1,true))
    assert {:ok,%{balance: 2100}} = Betunfair.user_get(u1)
    assert {:ok,%{balance: 1900}} = Betunfair.user_get(u2)
  end

  test "match_bets6" do
    assert {:ok,_} = Betunfair.clean("testdb")
    assert  {:ok,_} = Betunfair.start_link("testdb")
    assert {:ok,u1} = Betunfair.user_create("u1","Francisco Gonzalez")
    assert {:ok,u2} = Betunfair.user_create("u2","Maria Fernandez")
    assert is_ok(Betunfair.user_deposit(u1,2000))
    assert is_ok(Betunfair.user_deposit(u2,2000))
    assert {:ok,%{balance: 2000}} = Betunfair.user_get(u1)
    assert {:ok,m1} = Betunfair.market_create("rmw","Real Madrid wins")
    assert {:ok,bb1} = Betunfair.bet_back(u1,m1,1000,150)
    assert {:ok,bb2} = Betunfair.bet_back(u1,m1,1000,153)
    assert {:ok,%{balance: 0}} = Betunfair.user_get(u1)
    assert true = (bb1 != bb2)
    assert {:ok,_bl1} = Betunfair.bet_lay(u2,m1,100,140)
    assert {:ok,_bl2} = Betunfair.bet_lay(u2,m1,100,150)
    assert {:ok,%{balance: 1800}} = Betunfair.user_get(u2)
    assert is_ok(Betunfair.market_match(m1))
    assert is_ok(Betunfair.market_settle(m1,false))
    assert {:ok,%{balance: 1800}} = Betunfair.user_get(u1)
    assert {:ok,%{balance: 2200}} = Betunfair.user_get(u2)
  end

  test "match_bets7" do
    assert {:ok,_} = Betunfair.clean("testdb")
    assert  {:ok,_} = Betunfair.start_link("testdb")
    assert {:ok,u1} = Betunfair.user_create("u1","Francisco Gonzalez")
    assert {:ok,u2} = Betunfair.user_create("u2","Maria Fernandez")
    assert is_ok(Betunfair.user_deposit(u1,2000))
    assert is_ok(Betunfair.user_deposit(u2,2000))
    assert {:ok,%{balance: 2000}} = Betunfair.user_get(u1)
    assert {:ok,m1} = Betunfair.market_create("rmw","Real Madrid wins")
    assert {:ok,bb1} = Betunfair.bet_back(u1,m1,1000,150)
    assert {:ok,bb2} = Betunfair.bet_back(u1,m1,1000,153)
    assert {:ok,%{balance: 0}} = Betunfair.user_get(u1)
    assert true = (bb1 != bb2)
    assert {:ok,_bl1} = Betunfair.bet_lay(u2,m1,100,140)
    assert {:ok,_bl2} = Betunfair.bet_lay(u2,m1,100,150)
    assert {:ok,%{balance: 1800}} = Betunfair.user_get(u2)
    assert is_ok(Betunfair.market_match(m1))
    assert is_ok(Betunfair.market_freeze(m1))
    assert is_error(Betunfair.bet_lay(u2,m1,100,150))
    assert is_ok(Betunfair.market_settle(m1,false))
    assert {:ok,%{balance: 1800}} = Betunfair.user_get(u1)
    assert {:ok,%{balance: 2200}} = Betunfair.user_get(u2)
  end

  test "match_bets8" do
    assert {:ok,_} = Betunfair.clean("testdb")
    assert  {:ok,_} = Betunfair.start_link("testdb")
    assert {:ok,u1} = Betunfair.user_create("u1","Francisco Gonzalez")
    assert {:ok,u2} = Betunfair.user_create("u2","Maria Fernandez")
    assert is_ok(Betunfair.user_deposit(u1,2000))
    assert is_ok(Betunfair.user_deposit(u2,2000))
    assert {:ok,%{balance: 2000}} = Betunfair.user_get(u1)
    assert {:ok,m1} = Betunfair.market_create("rmw","Real Madrid wins")
    assert {:ok,bb1} = Betunfair.bet_back(u1,m1,200,150)
    assert {:ok,bb2} = Betunfair.bet_back(u1,m1,200,153)
    assert {:ok,%{balance: 1600}} = Betunfair.user_get(u1)
    assert true = (bb1 != bb2)
    assert {:ok,_bl1} = Betunfair.bet_lay(u2,m1,100,140)
    assert {:ok,_bl2} = Betunfair.bet_lay(u2,m1,100,150)
    assert {:ok,%{balance: 1800}} = Betunfair.user_get(u2)
    assert is_ok(Betunfair.market_match(m1))
    assert is_ok(Betunfair.market_settle(m1,true))
    assert {:ok,%{balance: 2100}} = Betunfair.user_get(u1)
    assert {:ok,%{balance: 1900}} = Betunfair.user_get(u2)
  end

  test "match_bets9" do
    assert {:ok,_} = Betunfair.clean("testdb")
    assert  {:ok,_} = Betunfair.start_link("testdb")
    assert {:ok,u1} = Betunfair.user_create("u1","Francisco Gonzalez")
    assert {:ok,u2} = Betunfair.user_create("u2","Maria Fernandez")
    assert is_ok(Betunfair.user_deposit(u1,2000))
    assert is_ok(Betunfair.user_deposit(u2,2000))
    assert {:ok,%{balance: 2000}} = Betunfair.user_get(u1)
    assert {:ok,m1} = Betunfair.market_create("rmw","Real Madrid wins")
    assert {:ok,bb1} = Betunfair.bet_back(u1,m1,200,150)
    assert {:ok,bb2} = Betunfair.bet_back(u1,m1,200,153)
    assert {:ok,%{balance: 1600}} = Betunfair.user_get(u1)
    assert true = (bb1 != bb2)
    assert {:ok,_bl1} = Betunfair.bet_lay(u2,m1,100,140)
    assert {:ok,_bl2} = Betunfair.bet_lay(u2,m1,100,150)
    assert {:ok,%{balance: 1800}} = Betunfair.user_get(u2)
    assert is_ok(Betunfair.market_match(m1))
    assert is_ok(Betunfair.market_settle(m1,false))
    assert {:ok,%{balance: 1800}} = Betunfair.user_get(u1)
    assert {:ok,%{balance: 2200}} = Betunfair.user_get(u2)
  end

  test "match_bets10" do
    assert {:ok,_} = Betunfair.clean("testdb")
    assert  {:ok,_} = Betunfair.start_link("testdb")
    assert {:ok,u1} = Betunfair.user_create("u1","Francisco Gonzalez")
    assert {:ok,u2} = Betunfair.user_create("u2","Maria Fernandez")
    assert is_ok(Betunfair.user_deposit(u1,2000))
    assert is_ok(Betunfair.user_deposit(u2,2000))
    assert {:ok,%{balance: 2000}} = Betunfair.user_get(u1)
    assert {:ok,m1} = Betunfair.market_create("rmw","Real Madrid wins")
    assert {:ok,bb1} = Betunfair.bet_back(u1,m1,800,150)
    assert {:ok,bb2} = Betunfair.bet_back(u1,m1,800,153)
    assert {:ok,%{balance: 400}} = Betunfair.user_get(u1)
    assert true = (bb1 != bb2)
    assert {:ok,_bl1} = Betunfair.bet_lay(u2,m1,100,150)
    assert {:ok,_bl2} = Betunfair.bet_lay(u2,m1,100,150)
    assert {:ok,%{balance: 1800}} = Betunfair.user_get(u2)
    assert is_ok(Betunfair.market_match(m1))
    assert is_ok(Betunfair.market_settle(m1,true))
    assert {:ok,%{balance: 2200}} = Betunfair.user_get(u1)
    assert {:ok,%{balance: 1800}} = Betunfair.user_get(u2)
  end

  test "match_bets11" do
    assert {:ok,_} = Betunfair.clean("testdb")
    assert  {:ok,_} = Betunfair.start_link("testdb")
    assert {:ok,u1} = Betunfair.user_create("u1","Francisco Gonzalez")
    assert {:ok,u2} = Betunfair.user_create("u2","Maria Fernandez")
    assert is_ok(Betunfair.user_deposit(u1,2000))
    assert is_ok(Betunfair.user_deposit(u2,2000))
    assert {:ok,%{balance: 2000}} = Betunfair.user_get(u1)
    assert {:ok,m1} = Betunfair.market_create("rmw","Real Madrid wins")
    assert {:ok,bb1} = Betunfair.bet_back(u1,m1,200,150)
    assert {:ok,bb2} = Betunfair.bet_back(u1,m1,200,150)
    assert {:ok,%{balance: 1600}} = Betunfair.user_get(u1)
    assert true = (bb1 != bb2)
    assert {:ok,_bl1} = Betunfair.bet_lay(u2,m1,100,140)
    assert {:ok,_bl2} = Betunfair.bet_lay(u2,m1,800,150)
    assert {:ok,%{balance: 1100}} = Betunfair.user_get(u2)
    assert is_ok(Betunfair.market_match(m1))
    assert is_ok(Betunfair.market_settle(m1,false))
    assert {:ok,%{balance: 1600}} = Betunfair.user_get(u1)
    assert {:ok,%{balance: 2400}} = Betunfair.user_get(u2)
  end

  test "bet_cancel1" do
    assert {:ok,_} = Betunfair.clean("testdb")
    assert  {:ok,_} = Betunfair.start_link("testdb")
    assert {:ok,u1} = Betunfair.user_create("u1","Francisco Gonzalez")
    assert {:ok,u2} = Betunfair.user_create("u2","Maria Fernandez")
    assert is_ok(Betunfair.user_deposit(u1,2000))
    assert is_ok(Betunfair.user_deposit(u2,2000))
    assert {:ok,%{balance: 2000}} = Betunfair.user_get(u1)
    assert {:ok,m1} = Betunfair.market_create("rmw","Real Madrid wins")
    assert {:ok,bb1} = Betunfair.bet_back(u1,m1,1000,150)
    assert {:ok,bb2} = Betunfair.bet_back(u1,m1,1000,153)
    assert {:ok,%{balance: 0}} = Betunfair.user_get(u1)
    assert true = (bb1 != bb2)
    assert {:ok,bl1} = Betunfair.bet_lay(u2,m1,100,140)
    assert {:ok,bl2} = Betunfair.bet_lay(u2,m1,100,150)
    assert {:ok,%{balance: 1800}} = Betunfair.user_get(u2)
    assert is_ok(Betunfair.market_match(m1))
    assert is_ok(Betunfair.bet_cancel(bl1))
    assert is_ok(Betunfair.bet_cancel(bb2))
    assert {:ok,%{balance: 1000}} = Betunfair.user_get(u1)
    assert {:ok,%{balance: 1900}} = Betunfair.user_get(u2)
    assert is_ok(Betunfair.bet_cancel(bl2))
    assert is_ok(Betunfair.bet_cancel(bb1))
    assert {:ok,%{balance: 1800}} = Betunfair.user_get(u1)
    assert {:ok,%{balance: 1900}} = Betunfair.user_get(u2)
    assert is_ok(Betunfair.market_settle(m1,false))
    assert {:ok,%{balance: 1800}} = Betunfair.user_get(u1)
    assert {:ok,%{balance: 2200}} = Betunfair.user_get(u2)
  end

  test "insertIntoPlace" do
    assert Bet.insertInPlace([{"a", 1, 2}, {"b", 1, 3}], {"c", 1, 4},
    fn({_, _, odds_old}, {_, _, odds_new}) ->
      odds_old<=odds_new
    end)==[{"a", 1, 2}, {"b", 1, 3}, {"c", 1, 4}]

    assert Bet.insertInPlace([{"a", 1, 2}, {"b", 1, 3}], {"c", 1, 2},
    fn({_, _, odds_old}, {_, _, odds_new}) ->
      odds_old<=odds_new
    end)==[{"a", 1, 2}, {"c", 1, 2}, {"b", 1, 3}]

    assert Bet.insertInPlace(user_lookup,, {"c", 1, 4},
    fn({_, _, odds_old}, {_, _, odds_new}) ->
      odds_old>=odds_new
    end)==[{"c", 1, 4}, {"b", 1, 3}, {"a", 1, 2}]

    assert Bet.insertInPlace([{"b", 1, 3}, {"a", 1, 2}], {"c", 1, 2},
    fn({_, _, odds_old}, {_, _, odds_new}) ->
      odds_old>=odds_new
    end)==[{"b", 1, 3}, {"a", 1, 2}, {"c", 1, 2}]
  end

  defp is_error(:error),do: true
  defp is_error({:error,_}), do: true
  defp is_error(_), do: false

  defp is_ok(:ok), do: true
  defp is_ok({:ok,_}), do: true
  defp is_ok(_), do: false
end
