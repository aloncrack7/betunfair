defmodule BetUnfairTest do
  use ExUnit.Case

  # Tests the creation of users, the deposit and withdraw of money and the obtaining of user info
  test "user_create_deposit_withdraw_get" do
    assert {:ok,_} = BetUnfair.clean("testdb")
    assert {:ok,_} = BetUnfair.start_link("testdb")
    assert {:ok,u1} = BetUnfair.user_create("11","Tristan")
    assert {:ok,u2} = BetUnfair.user_create("22","Manuel")
    assert {:ok,u3} = BetUnfair.user_create("33","Alonso")
    assert is_ok(BetUnfair.user_deposit(u1,2000))
    assert is_ok(BetUnfair.user_deposit(u2,2000))
    assert is_ok(BetUnfair.user_deposit(u3,2000))
    assert {:ok, %{balance: 2000, id: "33", name: "Alonso"}} = BetUnfair.user_get("u3")
    assert is_ok(BetUnfair.user_withdraw(u3,1000))
    assert {:ok, %{balance: 1000, id: "33", name: "Alonso"}} = BetUnfair.user_get("u3")
  end

  # Tests the correct generation of errors while using the users operations
  test "user_errors" do
    assert {:ok,_} = BetUnfair.clean("testdb")
    assert {:ok,_} = BetUnfair.start_link("testdb")
    assert {:ok,u1} = BetUnfair.user_create("11","Tristan")
    assert is_error(BetUnfair.user_create("11","Paco"))
    assert is_error(BetUnfair.user_create("22",12345))
    assert is_error(BetUnfair.user_deposit("u2",500))
    assert is_error(BetUnfair.user_deposit(u1,"abc"))
    assert is_error(BetUnfair.user_deposit(u1,-1000))
    assert is_error(BetUnfair.user_deposit(u1,99))
    assert is_ok(BetUnfair.user_deposit(u1,500))
    assert is_error(BetUnfair.user_withdraw(u1,777))
    assert is_error(BetUnfair.user_withdraw("u2",300))
    assert is_error(BetUnfair.user_withdraw(u1,"abc"))
    assert is_error(BetUnfair.user_withdraw(u1,-200))
    assert is_error(BetUnfair.user_withdraw(u1,99))
    assert is_error(BetUnfair.user_get("u2"))
    assert is_error(BetUnfair.user_bets("u2"))
    assert is_error(BetUnfair.user_bets(u1))
  end

  # Tests the correct generation of a market and a back bet, and the correct obtaining of the market list and the active market list
  test "bet_back" do
    assert {:ok,_} = BetUnfair.clean("testdb")
    assert {:ok,_} = BetUnfair.start_link("testdb")
    assert {:ok,u1} = BetUnfair.user_create("u1","Tristan")
    assert {:ok,u2} = BetUnfair.user_create("u2","Manuel")
    assert {:ok,u3} = BetUnfair.user_create("u3","Alonso")
    assert is_ok(BetUnfair.user_deposit(u1,2000))
    assert is_ok(BetUnfair.user_deposit(u2,2000))
    assert is_ok(BetUnfair.user_deposit(u3,2000))
    assert {:ok,m1} = BetUnfair.market_create("rmw","Real Madrid wins")
    assert {:ok,b} = BetUnfair.bet_back(u1,m1,1000,150)
    assert {:ok, %{bet_id: b, bet_type: :back, market_id: m1, user_id: u1, odds: 150, original_stake: 1000, remaining_stake: 1000, matched_bets: [], status: :active}} = BetUnfair.bet_get(b)
    assert {:ok,markets} = BetUnfair.market_list()
    assert 1 = length(markets)
    assert {:ok, markets} = BetUnfair.market_list_active()
    assert 1 = length(markets)
  end

  # Tests the correct generation of a market and some back and lay bets, and the correct obtaining of the user bets for each user
  test "bets_lay_back" do
    assert {:ok,_} = BetUnfair.clean("testdb")
    assert {:ok,_} = BetUnfair.start_link("testdb")
    assert {:ok,u1} = BetUnfair.user_create("11","Tristan")
    assert {:ok,u2} = BetUnfair.user_create("22","Manuel")
    assert {:ok,u3} = BetUnfair.user_create("33","Alonso")
    assert is_ok(BetUnfair.user_deposit(u1,2000))
    assert is_ok(BetUnfair.user_deposit(u2,2000))
    assert is_ok(BetUnfair.user_deposit(u3,2000))
    assert {:ok,m1} = BetUnfair.market_create("rmm","Real Madrid misses")
    assert {:ok,b1} = BetUnfair.bet_lay(u3,m1,1000,150)
    assert {:ok, %{bet_id: b1, bet_type: :lay, market_id: m1, user_id: u3, odds: 150, original_stake: 1000, remaining_stake: 1000, matched_bets: [], status: :active}} = BetUnfair.bet_get(b1)
    assert {:ok,b2} = BetUnfair.bet_back(u1,m1,500,150)
    assert {:ok,b3} = BetUnfair.bet_back(u2,m1,500,120)
    assert {:ok, %{bet_id: b3, bet_type: :back, market_id: m1, user_id: u2, odds: 120, original_stake: 500, remaining_stake: 500, matched_bets: [], status: :active}} = BetUnfair.bet_get(b3)
    assert ["bb2"] = BetUnfair.user_bets(u1)
    assert ["bb3"] = BetUnfair.user_bets(u2)
    assert ["bb1"] = BetUnfair.user_bets(u3)
  end

  # Tests the generation of errors while using the markets operations
  test "market_errors" do
    assert {:ok,_} = BetUnfair.clean("testdb")
    assert {:ok,_} = BetUnfair.start_link("testdb")
    assert {:ok,u1} = BetUnfair.user_create("11","Tristan")
    assert {:ok,u2} = BetUnfair.user_create("22","Manuel")
    assert {:ok,u3} = BetUnfair.user_create("33","Alonso")
    assert is_ok(BetUnfair.user_deposit(u1,2000))
    assert is_ok(BetUnfair.user_deposit(u2,2000))
    assert is_ok(BetUnfair.user_deposit(u3,2000))
    assert is_error(BetUnfair.market_get("m1"))
    assert is_error(BetUnfair.market_cancel("m1"))
    assert is_error(BetUnfair.market_freeze("m1"))
    assert is_error(BetUnfair.market_settle("m1", true))
    assert {:ok,m1} = BetUnfair.market_create("rmm","Barcelona wins")
    assert is_error(BetUnfair.market_settle("m1", 12345))
    assert is_error(BetUnfair.market_bets("m2"))
    assert is_error(BetUnfair.market_pending_backs("m2"))
    assert is_error(BetUnfair.market_pending_lays("m2"))
    assert is_error(BetUnfair.market_match("m2"))
  end

  # Tests the correct matching between the created bets and the correct freezing of the market
  test "bet_match" do
    assert {:ok,_} = BetUnfair.clean("testdb")
    assert {:ok,_} = BetUnfair.start_link("testdb")
    assert {:ok,u1} = BetUnfair.user_create("u1","Tristan")
    assert {:ok,u2} = BetUnfair.user_create("u2","Manuel")
    assert {:ok,u3} = BetUnfair.user_create("u3","Alonso")
    assert is_ok(BetUnfair.user_deposit(u1,2000))
    assert is_ok(BetUnfair.user_deposit(u2,2000))
    assert is_ok(BetUnfair.user_deposit(u3,2000))
    assert {:ok,m1} = BetUnfair.market_create("rmw","Real Madrid wins")
    assert {:ok,b1} = BetUnfair.bet_back(u1,m1,200,150)
    assert {:ok,b2} = BetUnfair.bet_lay(u2,m1,100,150)
    assert {:ok,b3} = BetUnfair.bet_lay(u3,m1,100,150)
    assert :ok = BetUnfair.market_match(m1)
    assert {:ok, %{bet_id: b1, bet_type: :back, market_id: m1, user_id: u1, odds: 150, original_stake: 200, remaining_stake: 0, matched_bets: [b2], status: :active}} = BetUnfair.bet_get(b1)
    assert {:ok, %{bet_id: b2, bet_type: :lay, market_id: m1, user_id: u2, odds: 150, original_stake: 100, remaining_stake: 0, matched_bets: [b1], status: :active}} = BetUnfair.bet_get(b2)
    assert {:ok, %{bet_id: b3, bet_type: :lay, market_id: m1, user_id: u3, odds: 150, original_stake: 100, remaining_stake: 100, matched_bets: [], status: :active}} = BetUnfair.bet_get(b3)
    assert is_ok(BetUnfair.market_freeze(m1))
    assert {:ok, markets} = BetUnfair.market_list_active()
    assert 0 = length(markets)
  end

  # Tests the generation of errors while using the bets operations
  test "bets_errors" do
    assert {:ok,_} = BetUnfair.clean("testdb")
    assert {:ok,_} = BetUnfair.start_link("testdb")
    assert {:ok,u1} = BetUnfair.user_create("u1","Tristan")
    assert {:ok,m1} = BetUnfair.market_create("rmw","Real Madrid wins")
    assert is_error(BetUnfair.bet_back("u2",m1,1000,150))
    assert is_error(BetUnfair.bet_back(u1,"m2",1000,150))
    assert is_error(BetUnfair.bet_back(u1,m1,99,150))
    assert is_error(BetUnfair.bet_back(u1,m1,1000,99))
    assert is_error(BetUnfair.bet_cancel("bb1"))
    assert is_error(BetUnfair.bet_get("bb1"))
  end

  # Tests the the correct no matching between no matching bets, as well as the correct freezing of the market and the errors produced when trying to operate with the freezed market.
  # Also, the market is settled and all the money is given back to users
  test "market_no_match" do
    assert {:ok,_} = BetUnfair.clean("testdb")
    assert {:ok,_} = BetUnfair.start_link("testdb")
    assert {:ok,u1} = BetUnfair.user_create("u1","Tristan")
    assert {:ok,u2} = BetUnfair.user_create("u2","Manuel")
    assert {:ok,u3} = BetUnfair.user_create("u3","Alonso")
    assert is_ok(BetUnfair.user_deposit(u1,2000))
    assert is_ok(BetUnfair.user_deposit(u2,2000))
    assert is_ok(BetUnfair.user_deposit(u3,2000))
    assert {:ok,m1} = BetUnfair.market_create("rmw","Real Madrid wins")
    assert {:ok,b1} = BetUnfair.bet_back(u1,m1,200,200)
    assert {:ok,b2} = BetUnfair.bet_lay(u2,m1,100,150)
    assert {:ok,b3} = BetUnfair.bet_lay(u3,m1,100,150)
    assert {:ok, %{balance: 1800, id: "u1", name: "Tristan"}} = BetUnfair.user_get(u1)
    assert {:ok, %{balance: 1900, id: "u2", name: "Manuel"}} = BetUnfair.user_get(u2)
    assert {:ok, %{balance: 1900, id: "u3", name: "Alonso"}} = BetUnfair.user_get(u3)
    assert is_ok(BetUnfair.market_match(m1))
    assert {:ok, %{bet_id: b1, bet_type: :back, market_id: m1, user_id: u1, odds: 200, original_stake: 200, remaining_stake: 200, matched_bets: [], status: :active}} = BetUnfair.bet_get(b1)
    assert {:ok, %{bet_id: b2, bet_type: :lay, market_id: m1, user_id: u2, odds: 150, original_stake: 100, remaining_stake: 100, matched_bets: [], status: :active}} = BetUnfair.bet_get(b2)
    assert {:ok, %{bet_id: b3, bet_type: :lay, market_id: m1, user_id: u3, odds: 150, original_stake: 100, remaining_stake: 100, matched_bets: [], status: :active}} = BetUnfair.bet_get(b3)
    assert is_ok(BetUnfair.market_freeze(m1))
    assert is_error(BetUnfair.bet_back(u1,m1,200,200))
    assert is_error(BetUnfair.bet_cancel(b1))
    assert is_error(BetUnfair.market_freeze(m1))
    assert is_ok(BetUnfair.market_settle(m1, true))
    assert {:ok, %{balance: 2000, id: "u1", name: "Tristan"}} = BetUnfair.user_get(u1)
    assert {:ok, %{balance: 2000, id: "u2", name: "Manuel"}} = BetUnfair.user_get(u2)
    assert {:ok, %{balance: 2000, id: "u3", name: "Alonso"}} = BetUnfair.user_get(u3)
  end

  # Tests the correct cancellation of the market, as well as the errors produced when trying to operate with the cancelled market
  test "market_cancel" do
    assert {:ok,_} = BetUnfair.clean("testdb")
    assert {:ok,_} = BetUnfair.start_link("testdb")
    assert {:ok,u1} = BetUnfair.user_create("u1","Tristan")
    assert {:ok,u2} = BetUnfair.user_create("u2","Manuel")
    assert {:ok,u3} = BetUnfair.user_create("u3","Alonso")
    assert is_ok(BetUnfair.user_deposit(u1,2000))
    assert is_ok(BetUnfair.user_deposit(u2,2000))
    assert is_ok(BetUnfair.user_deposit(u3,2000))
    assert {:ok,m1} = BetUnfair.market_create("rmw","Real Madrid wins")
    assert {:ok,b1} = BetUnfair.bet_back(u1,m1,200,200)
    assert {:ok,b2} = BetUnfair.bet_lay(u2,m1,100,150)
    assert {:ok,b3} = BetUnfair.bet_lay(u3,m1,100,150)
    assert {:ok, %{balance: 1800, id: "u1", name: "Tristan"}} = BetUnfair.user_get(u1)
    assert {:ok, %{balance: 1900, id: "u2", name: "Manuel"}} = BetUnfair.user_get(u2)
    assert {:ok, %{balance: 1900, id: "u3", name: "Alonso"}} = BetUnfair.user_get(u3)
    assert is_ok(BetUnfair.bet_cancel(b3))
    assert {:ok, %{bet_id: b1, bet_type: :back, market_id: m1, user_id: u1, odds: 200, original_stake: 200, remaining_stake: 200, matched_bets: [], status: :active}} = BetUnfair.bet_get(b1)
    assert {:ok, %{bet_id: b2, bet_type: :lay, market_id: m1, user_id: u2, odds: 150, original_stake: 100, remaining_stake: 100, matched_bets: [], status: :active}} = BetUnfair.bet_get(b2)
    assert {:ok, %{bet_id: b3, bet_type: :lay, market_id: m1, user_id: u3, odds: 150, original_stake: 100, remaining_stake: 100, matched_bets: [], status: :cancelled}} = BetUnfair.bet_get(b3)
    assert is_ok(BetUnfair.market_cancel(m1))
    assert is_error(BetUnfair.market_cancel(m1))
    assert is_error(BetUnfair.bet_lay(u1,m1,200,200))
    assert is_error(BetUnfair.bet_cancel(b1))
    assert is_error(BetUnfair.market_settle(m1, true))
    assert is_error(BetUnfair.market_freeze(m1))
    assert {:ok, %{balance: 2000, id: "u1", name: "Tristan"}} = BetUnfair.user_get(u1)
    assert {:ok, %{balance: 2000, id: "u2", name: "Manuel"}} = BetUnfair.user_get(u2)
    assert {:ok, %{balance: 2000, id: "u3", name: "Alonso"}} = BetUnfair.user_get(u3)
  end

  # Tests the correct cancellation of a bet after having matched with others
  test "settle_with_cancelled_bets" do
    assert {:ok,_} = BetUnfair.clean("testdb")
    assert {:ok,_} = BetUnfair.start_link("testdb")
    assert {:ok,u1} = BetUnfair.user_create("u1","Tristan")
    assert {:ok,u2} = BetUnfair.user_create("u2","Manuel")
    assert {:ok,u3} = BetUnfair.user_create("u3","Alonso")
    assert is_ok(BetUnfair.user_deposit(u1,2000))
    assert is_ok(BetUnfair.user_deposit(u2,2000))
    assert is_ok(BetUnfair.user_deposit(u3,2000))
    assert {:ok,m1} = BetUnfair.market_create("rmw","Real Madrid wins")
    assert {:ok,b1} = BetUnfair.bet_back(u1,m1,200,150)
    assert {:ok,b2} = BetUnfair.bet_lay(u2,m1,100,150)
    assert {:ok,b3} = BetUnfair.bet_lay(u3,m1,100,150)
    assert {:ok, %{balance: 1800, id: "u1", name: "Tristan"}} = BetUnfair.user_get(u1)
    assert {:ok, %{balance: 1900, id: "u2", name: "Manuel"}} = BetUnfair.user_get(u2)
    assert {:ok, %{balance: 1900, id: "u3", name: "Alonso"}} = BetUnfair.user_get(u3)
    assert is_ok(BetUnfair.market_match(m1))
    assert {:ok, %{bet_id: b1, bet_type: :back, market_id: m1, user_id: u1, odds: 150, original_stake: 200, remaining_stake: 0, matched_bets: [b2], status: :active}} = BetUnfair.bet_get(b1)
    assert {:ok, %{bet_id: b2, bet_type: :lay, market_id: m1, user_id: u2, odds: 150, original_stake: 100, remaining_stake: 0, matched_bets: [b1], status: :active}} = BetUnfair.bet_get(b2)
    assert {:ok, %{bet_id: b3, bet_type: :lay, market_id: m1, user_id: u3, odds: 150, original_stake: 100, remaining_stake: 100, matched_bets: [], status: :active}} = BetUnfair.bet_get(b3)
    assert is_ok(BetUnfair.bet_cancel(b1))
    assert {:ok, %{balance: 1800, id: "u1", name: "Tristan"}} = BetUnfair.user_get(u1)
    assert {:ok, %{balance: 1900, id: "u2", name: "Manuel"}} = BetUnfair.user_get(u2)
    assert {:ok, %{bet_id: b1, bet_type: :back, market_id: m1, user_id: u1, odds: 150, original_stake: 200, remaining_stake: 0, matched_bets: [b2], status: :cancelled}} = BetUnfair.bet_get(b1)
    assert {:ok, %{bet_id: b2, bet_type: :lay, market_id: m1, user_id: u2, odds: 150, original_stake: 100, remaining_stake: 100, matched_bets: [], status: :active}} = BetUnfair.bet_get(b2)
    assert is_ok(BetUnfair.market_freeze(m1))
    assert is_ok(BetUnfair.market_settle(m1, true))
    assert {:ok, %{balance: 2000, id: "u1", name: "Tristan"}} = BetUnfair.user_get(u1)
    assert {:ok, %{balance: 2000, id: "u2", name: "Manuel"}} = BetUnfair.user_get(u2)
  end

  # Tests the correct freezing of a market and the error obtained when trying to create a new bet in afreezing market
  test "market_freeze" do
    assert {:ok,_} = BetUnfair.clean("testdb")
    assert {:ok,_} = BetUnfair.start_link("testdb")
    assert {:ok,u1} = BetUnfair.user_create("u1","Tristan")
    assert is_ok(BetUnfair.user_deposit(u1,2000))
    assert {:ok,m1} = BetUnfair.market_create("rmw","Real Madrid wins")
    assert is_ok(BetUnfair.market_freeze(m1))
    assert is_error(BetUnfair.bet_back(u1,m1,200,200))
    assert {:ok, %{balance: 2000, id: "u1", name: "Tristan"}} = BetUnfair.user_get(u1)
  end

  # Tests the correct matching between the created bets
  test "bet_match_2" do
    assert {:ok,_} = BetUnfair.clean("testdb")
    assert {:ok,_} = BetUnfair.start_link("testdb")
    assert {:ok,u1} = BetUnfair.user_create("u1","Tristan")
    assert {:ok,u2} = BetUnfair.user_create("u2","Manuel")
    assert is_ok(BetUnfair.user_deposit(u1,4700))
    assert is_ok(BetUnfair.user_deposit(u2,40500))
    assert {:ok,m1} = BetUnfair.market_create("rmw","Real Madrid wins")
    assert {:ok,b} = BetUnfair.bet_back(u1,m1,1400,200)
    assert {:ok,a} = BetUnfair.bet_back(u1,m1,2000,300)
    assert {:ok,c} = BetUnfair.bet_back(u1,m1,500,153)
    assert {:ok,e} = BetUnfair.bet_lay(u2,m1,40000,110)
    assert {:ok,f} = BetUnfair.bet_back(u1,m1,800,150)
    assert {:ok,g} = BetUnfair.bet_lay(u2,m1,500,153)
    assert is_ok(BetUnfair.market_match(m1))
    assert {:ok, %{bet_id: a, bet_type: :back, market_id: m1, user_id: u1, odds: 300, original_stake: 2000, remaining_stake: 2000, matched_bets: [], status: :active}} = BetUnfair.bet_get(a)
    assert {:ok, %{bet_id: b, bet_type: :back, market_id: m1, user_id: u1, odds: 200, original_stake: 1400, remaining_stake: 1400, matched_bets: [], status: :active}} = BetUnfair.bet_get(b)
    assert {:ok, %{bet_id: c, bet_type: :back, market_id: m1, user_id: u1, odds: 153, original_stake: 500, remaining_stake: 311, matched_bets: [g], status: :active}} = BetUnfair.bet_get(c)
    assert {:ok, %{bet_id: f, bet_type: :back, market_id: m1, user_id: u1, odds: 150, original_stake: 800, remaining_stake: 0, matched_bets: [g], status: :active}} = BetUnfair.bet_get(f)
    assert {:ok, %{bet_id: e, bet_type: :lay, market_id: m1, user_id: u2, odds: 110, original_stake: 40000, remaining_stake: 40000, matched_bets: [], status: :active}} = BetUnfair.bet_get(e)
    assert {:ok, %{bet_id: g, bet_type: :lay, market_id: m1, user_id: u2, odds: 153, original_stake: 500, remaining_stake: 0, matched_bets: [c,f], status: :active}} = BetUnfair.bet_get(g)
  end

  # Tests the correct matching between the created bets and the correct distribution of the money after settle the market with true
  test "bet_match_settle_true" do
    assert {:ok,_} = BetUnfair.clean("testdb")
    assert {:ok,_} = BetUnfair.start_link("testdb")
    assert {:ok,u1} = BetUnfair.user_create("u1","Tristan")
    assert {:ok,u2} = BetUnfair.user_create("u2","Manuel")
    assert is_ok(BetUnfair.user_deposit(u1,4700))
    assert is_ok(BetUnfair.user_deposit(u2,40500))
    assert {:ok,m1} = BetUnfair.market_create("rmw","Real Madrid wins")
    assert {:ok,b} = BetUnfair.bet_back(u1,m1,1400,200)
    assert {:ok,a} = BetUnfair.bet_back(u1,m1,2000,300)
    assert {:ok,c} = BetUnfair.bet_back(u1,m1,500,153)
    assert {:ok,e} = BetUnfair.bet_lay(u2,m1,40000,110)
    assert {:ok,f} = BetUnfair.bet_back(u1,m1,800,150)
    assert {:ok,g} = BetUnfair.bet_lay(u2,m1,500,153)
    assert is_ok(BetUnfair.market_match(m1))
    assert {:ok, %{bet_id: a, bet_type: :back, market_id: m1, user_id: u1, odds: 300, original_stake: 2000, remaining_stake: 2000, matched_bets: [], status: :active}} = BetUnfair.bet_get(a)
    assert {:ok, %{bet_id: b, bet_type: :back, market_id: m1, user_id: u1, odds: 200, original_stake: 1400, remaining_stake: 1400, matched_bets: [], status: :active}} = BetUnfair.bet_get(b)
    assert {:ok, %{bet_id: c, bet_type: :back, market_id: m1, user_id: u1, odds: 153, original_stake: 500, remaining_stake: 311, matched_bets: [g], status: :active}} = BetUnfair.bet_get(c)
    assert {:ok, %{bet_id: f, bet_type: :back, market_id: m1, user_id: u1, odds: 150, original_stake: 800, remaining_stake: 0, matched_bets: [g], status: :active}} = BetUnfair.bet_get(f)
    assert {:ok, %{bet_id: e, bet_type: :lay, market_id: m1, user_id: u2, odds: 110, original_stake: 40000, remaining_stake: 40000, matched_bets: [], status: :active}} = BetUnfair.bet_get(e)
    assert {:ok, %{bet_id: g, bet_type: :lay, market_id: m1, user_id: u2, odds: 153, original_stake: 500, remaining_stake: 0, matched_bets: [c,f], status: :active}} = BetUnfair.bet_get(g)
    assert is_ok(BetUnfair.market_settle(m1, true))
    assert {:ok, %{balance: 5200, id: "u1", name: "Tristan"}} = BetUnfair.user_get(u1)
    assert {:ok, %{balance: 40000, id: "u2", name: "Manuel"}} = BetUnfair.user_get(u2)
  end

  # Tests the correct matching between the created bets and the correct distribution of the money after settle the market with false
  test "bet_match_settle_false" do
    assert {:ok,_} = BetUnfair.clean("testdb")
    assert {:ok,_} = BetUnfair.start_link("testdb")
    assert {:ok,u1} = BetUnfair.user_create("u1","Tristan")
    assert {:ok,u2} = BetUnfair.user_create("u2","Manuel")
    assert is_ok(BetUnfair.user_deposit(u1,4700))
    assert is_ok(BetUnfair.user_deposit(u2,40500))
    assert {:ok,m1} = BetUnfair.market_create("rmw","Real Madrid wins")
    assert {:ok,b} = BetUnfair.bet_back(u1,m1,1400,200)
    assert {:ok,a} = BetUnfair.bet_back(u1,m1,2000,300)
    assert {:ok,c} = BetUnfair.bet_back(u1,m1,500,153)
    assert {:ok,e} = BetUnfair.bet_lay(u2,m1,40000,110)
    assert {:ok,f} = BetUnfair.bet_back(u1,m1,800,150)
    assert {:ok,g} = BetUnfair.bet_lay(u2,m1,500,153)
    assert is_ok(BetUnfair.market_match(m1))
    assert {:ok, %{bet_id: a, bet_type: :back, market_id: m1, user_id: u1, odds: 300, original_stake: 2000, remaining_stake: 2000, matched_bets: [], status: :active}} = BetUnfair.bet_get(a)
    assert {:ok, %{bet_id: b, bet_type: :back, market_id: m1, user_id: u1, odds: 200, original_stake: 1400, remaining_stake: 1400, matched_bets: [], status: :active}} = BetUnfair.bet_get(b)
    assert {:ok, %{bet_id: c, bet_type: :back, market_id: m1, user_id: u1, odds: 153, original_stake: 500, remaining_stake: 311, matched_bets: [g], status: :active}} = BetUnfair.bet_get(c)
    assert {:ok, %{bet_id: f, bet_type: :back, market_id: m1, user_id: u1, odds: 150, original_stake: 800, remaining_stake: 0, matched_bets: [g], status: :active}} = BetUnfair.bet_get(f)
    assert {:ok, %{bet_id: e, bet_type: :lay, market_id: m1, user_id: u2, odds: 110, original_stake: 40000, remaining_stake: 40000, matched_bets: [], status: :active}} = BetUnfair.bet_get(e)
    assert {:ok, %{bet_id: g, bet_type: :lay, market_id: m1, user_id: u2, odds: 153, original_stake: 500, remaining_stake: 0, matched_bets: [c,f], status: :active}} = BetUnfair.bet_get(g)
    assert is_ok(BetUnfair.market_settle(m1, false))
    assert {:ok, %{balance: 3711, id: "u1", name: "Tristan"}} = BetUnfair.user_get(u1)
    assert {:ok, %{balance: 40988, id: "u2", name: "Manuel"}} = BetUnfair.user_get(u2)
  end

  # Tests the correct matching between the created bets
  test "bet_match_3" do
    assert {:ok,_} = BetUnfair.clean("testdb")
    assert {:ok,_} = BetUnfair.start_link("testdb")
    assert {:ok,u1} = BetUnfair.user_create("u1","Tristan")
    assert {:ok,u2} = BetUnfair.user_create("u2","Manuel")
    assert {:ok,u3} = BetUnfair.user_create("u3","Alonso")
    assert is_ok(BetUnfair.user_deposit(u1,1000))
    assert is_ok(BetUnfair.user_deposit(u2,500))
    assert is_ok(BetUnfair.user_deposit(u3,500))
    assert {:ok,m1} = BetUnfair.market_create("rmw","Real Madrid wins")
    assert {:ok,a} = BetUnfair.bet_back(u1,m1,1000,150)
    assert {:ok,b} = BetUnfair.bet_lay(u2,m1,500,150)
    assert {:ok,c} = BetUnfair.bet_lay(u3,m1,500,150)
    assert is_ok(BetUnfair.market_match(m1))
    assert {:ok, %{bet_id: a, bet_type: :back, market_id: m1, user_id: u1, odds: 150, original_stake: 1000, remaining_stake: 0, matched_bets: ["bb2"], status: :active}} = BetUnfair.bet_get(a)
    assert {:ok, %{bet_id: b, bet_type: :lay, market_id: m1, user_id: u2, odds: 150, original_stake: 500, remaining_stake: 0, matched_bets: ["bb1"], status: :active}} = BetUnfair.bet_get(b)
    assert {:ok, %{bet_id: c, bet_type: :lay, market_id: m1, user_id: u3, odds: 150, original_stake: 500, remaining_stake: 500, matched_bets: [], status: :active}} = BetUnfair.bet_get(c)
  end

  # Tests the correct docuble matching of the created bets and the correct freezing and distribution of the money
  test "bet_match_freeze_settle" do
    assert {:ok,_} = BetUnfair.clean("testdb")
    assert {:ok,_} = BetUnfair.start_link("testdb")
    assert {:ok,u1} = BetUnfair.user_create("u1","Tristan")
    assert {:ok,u2} = BetUnfair.user_create("u2","Manuel")
    assert is_ok(BetUnfair.user_deposit(u1,8900))
    assert is_ok(BetUnfair.user_deposit(u2,42600))
    assert {:ok,m1} = BetUnfair.market_create("rmw","Real Madrid wins")
    assert {:ok,a} = BetUnfair.bet_back(u1,m1,2000,300)
    assert {:ok,b} = BetUnfair.bet_back(u1,m1,1400,200)
    assert {:ok,c} = BetUnfair.bet_back(u1,m1,500,153)
    assert {:ok,d} = BetUnfair.bet_lay(u2,m1,2100,150)
    assert {:ok,e} = BetUnfair.bet_lay(u2,m1,40000,110)
    assert {:ok,f} = BetUnfair.bet_back(u1,m1,5000,150)
    assert is_ok(BetUnfair.market_match(m1))
    assert {:ok,g} = BetUnfair.bet_lay(u2,m1,500,153)
    assert is_ok(BetUnfair.market_match(m1))
    assert is_ok(BetUnfair.market_freeze(m1))
    assert {:ok, %{bet_id: a, bet_type: :back, market_id: m1, user_id: u1, odds: 300, original_stake: 2000, remaining_stake: 2000, matched_bets: [], status: :active}} = BetUnfair.bet_get(a)
    assert {:ok, %{bet_id: b, bet_type: :back, market_id: m1, user_id: u1, odds: 200, original_stake: 1400, remaining_stake: 1400, matched_bets: [], status: :active}} = BetUnfair.bet_get(b)
    assert {:ok, %{bet_id: c, bet_type: :back, market_id: m1, user_id: u1, odds: 153, original_stake: 500, remaining_stake: 311, matched_bets: [g], status: :active}} = BetUnfair.bet_get(c)
    assert {:ok, %{bet_id: d, bet_type: :lay, market_id: m1, user_id: u2, odds: 150, original_stake: 2100, remaining_stake: 0, matched_bets: [f], status: :active}} = BetUnfair.bet_get(d)
    assert {:ok, %{bet_id: e, bet_type: :lay, market_id: m1, user_id: u2, odds: 110, original_stake: 40000, remaining_stake: 40000, matched_bets: [], status: :active}} = BetUnfair.bet_get(e)
    assert {:ok, %{bet_id: f, bet_type: :back, market_id: m1, user_id: u1, odds: 150, original_stake: 5000, remaining_stake: 0, matched_bets: [g,d], status: :active}} = BetUnfair.bet_get(f)
    assert {:ok, %{bet_id: g, bet_type: :lay, market_id: m1, user_id: u2, odds: 153, original_stake: 500, remaining_stake: 0, matched_bets: [c,f], status: :active}} = BetUnfair.bet_get(g)
    assert is_ok(BetUnfair.market_settle(m1, true))
    assert {:ok, %{balance: 11500, id: "u1", name: "Tristan"}} = BetUnfair.user_get(u1)
    assert {:ok, %{balance: 40000, id: "u2", name: "Manuel"}} = BetUnfair.user_get(u2)
  end


  defp is_error(:error),do: true
  defp is_error({:error,_}), do: true
  defp is_error(_), do: false

  defp is_ok(:ok), do: true
  defp is_ok({:ok,_}), do: true
  defp is_ok(_), do: false
end
