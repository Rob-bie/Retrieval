defmodule RetrievalCountTest do
  use ExUnit.Case

  test "Count" do
    assert 3 == Retrieval.new(~w/apple apply ape ample/, with_counter: true)
                |> Retrieval.prefix_count("ap")

    assert 1 == Retrieval.new(~w/apple apply ape ample/, with_counter: true)
                |> Retrieval.prefix_count("am")

    assert 4 == Retrieval.new(~w/apple apply ape ample/, with_counter: true)
                |> Retrieval.prefix_count("")
    assert 0 == Retrieval.new(~w/apple apply ape ample/, with_counter: true)
                |> Retrieval.prefix_count("xxx")
  end

end
