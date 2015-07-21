defmodule Fuzzer do
  @corpus File.read!("data/jabberwocky.txt") |> (fn x -> Regex.split(~r/\W+/, x) end).()
  @corpuslen length(@corpus)

  def main do
    :random.seed(elem(:os.timestamp, 0))
  end

  def randomInt(n), do: :random.uniform(n - 1)

  def randomWord, do: Enum.at(@corpus, randomInt(@corpuslen))

  def transformX(left, right) do
    [Text.transform(left, right, "left"), Text.transform(right, left, "right")]
  end

  def transformLists(serverOps, clientOps) do
    for s <- serverOps, c <- clientOps, do: transformX(s, c)
  end

  def composeList(ops), do: Enum.reduce(ops, [], Text.compose)

  def testRandomOp(genRandomOp, ""
end
