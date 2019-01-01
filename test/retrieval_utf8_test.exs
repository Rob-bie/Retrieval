defmodule RetrievalUTF8Test do
  use ExUnit.Case
  doctest Retrieval

  require Logger

  @test_data ~w/аппле аппли апе бет бетвеен бетраи кат колд хот
                варм винтер мазе смасш срусш ундер абове пеопле
                негативе поисон пласе оут дивиде зебра ехтендед extended/

  @test_trie Retrieval.new(@test_data)

  test "empty trie" do
    assert Retrieval.new == %Retrieval.Trie{}
  end

  test "contains?" do
    assert Retrieval.contains?(@test_trie, "аппле") == true
    assert Retrieval.contains?(@test_trie, "смасш") == true
    assert Retrieval.contains?(@test_trie, "абсде") == false
    assert Retrieval.contains?(@test_trie, "апп")   == false
  end

  test "prefix" do
    assert Retrieval.prefix(@test_trie, "апп") == ["аппле", "аппли"]
    assert Retrieval.prefix(@test_trie, "н")   == ["негативе"]
    assert Retrieval.prefix(@test_trie, "абц") == []
  end

  test "pattern errors" do
    assert match?({:error, _}, Retrieval.pattern(@test_trie, "аб*[^зсд"))
    assert match?({:error, _}, Retrieval.pattern(@test_trie, "аб*[^зсд]{}"))
    assert match?({:error, _}, Retrieval.pattern(@test_trie, "аб*[^зсд]{1[^абц]а}"))
    assert match?({:error, _}, Retrieval.pattern(@test_trie, "аб*[^зсд]{1[^абц]"))
    assert match?({:error, _}, Retrieval.pattern(@test_trie, "аб*[^зсд]{1[^аб*ц]а}{1}"))
  end

  test "pattern" do
    assert Retrieval.pattern(@test_trie, "*{1}{1}**") == ["аппле", "аппли"]
    assert Retrieval.pattern(@test_trie, "[^абц]{1}{1}**") == []
    assert Retrieval.pattern(@test_trie, "[ко]**") == ["кат", "оут"]
    assert Retrieval.pattern(@test_trie, "{1[^окйш]}х[тнм]{1}*{2}{1}{2}") == ["ехтендед"]
    assert Retrieval.pattern(@test_trie, "{1[^okjh]}x[tnm]{1}*{2}{1}{2}") == ["extended"]
  end

  test "flat" do
    tree = Retrieval.new(~w/apple apply ape ample/)
    result = Retrieval.flat(tree)

    assert "apple" in result
    assert "apply" in result
    assert "ape"   in result
    assert "ample" in result
  end

end
