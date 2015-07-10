defmodule Text do
  import MultiDef

  # Ops are lists of components which iterate over the document.
  # Components are either:
  #   A number N: Skip N characters in the original document
  #   "str"     : Insert "str" at the current position in the document
  #   {d:N}     : Delete N characters at the current position in the document

  # The operation does not have to skip the last characters in the document.
  #
  # Snapshots are strings.
  #
  # Cursors are either a single number (which is the cursor position) or a pair of
  # [anchor, focus] (aka [start, end]). Be aware that end can be before start.

  def exportsCreate(initial) when is_binary(initial), do: initial

  # Check the operation is valid. Throws if not valid.
  #--------------------------------------------------------------------------------  
  mdef checkOp do
    [] -> nil

    [ %{d: x} | rest ] when is_integer(x) ->
      if !(x > 0), do: raise "Object components must be deletes of size > 0"
      checkOp rest

    [ x | rest ] when is_binary(x) ->
      if !(String.length(x) > 0), do: raise "Inserts cannot be empty" 
      checkOp rest

    [ x, y | rest ] when is_integer(x) and is_integer(y) ->
      raise "Adjacent skip components should be combined"
      checkOp rest

    [ x | rest ] when is_integer(x) ->
      if !(x > 0), do: raise "Skip components must be >0"
      checkOp rest
  end
  #--------------------------------------------------------------------------------  

  mdef checkSelection do
    [ selection1, selection2 | _ ] 
      when is_integer(selection1) and is_integer(selection2) -> nil

    x when is_integer(x) -> nil
  end 

  # from makeAppend which returns a function
  mdef append do
    component, []                                        -> [ component ]
    nil, acc                                             -> acc
    %{d: 0}, acc                                         -> acc
    %{d: x}, [ %{d: y} | rest ]                          -> [ %{d: x + y} | rest ]
    x, [ y | rest ] when is_integer(x) and is_integer(y) -> [ y + x | rest ]
    x, [ y | rest ] when is_binary(x) and is_binary(y)   -> [ y <> x | rest ]
    component, acc                                       -> [ component | acc ]
  end

  #-------------------------------------------------------------------------------- 
  def exportsTransform(op, otherOp, side) do
    if side != "left" && side != "right", do: raise "Side must be left or right"

    checkOp(op)
    checkOp(otherOp)

    state = {op, 0, 0, side} # { op, idx, offset, side }
    { acc, state } = Enum.reduce(otherOp, {[], state}, &exportsTransformApply/2)
    
    acc = takeFinal(state, acc)
    trim(acc)
  end

  #-------------------------------------------------------------------------------- 
  def takeFinal(state = {op, idx, offset, side}, acc) do
    { result, idx, offset } = take(state, -1)
    if is_nil(result) do
      acc
    else
      acc = append(acc, result)
      takeFinal({op, idx, offset, side}, acc)
    end
  end

  mdef exportsTransformApply do
    x, {acc, state = {op, idx, offset, side}} when is_integer(x) ->
      {{ result, idx, offset }, acc } = takeInteger(state, acc, x)
      {acc, {op, idx, offset, side}}
      
    x, {acc, state = {op, idx, offset, side}} when is_binary(x) ->
      if side == "left" do
        if is_binary(peek(state)) do
          { result, idx, offset } = take(state, -1)
          acc = append(result, acc)
        end
      else
        acc = append(String.length(x), acc)
      end
      {acc, {op, idx, offset, side}}
        
    %{d: d}, {acc, state = {op, idx, offset, side}} ->
      {{ result, idx, offset }, acc } = takeInteger(state, acc, d)
      {acc, {op, idx, offset, side}}
  end

  mdef takeDelete do
    state = {op, idx, offset, side}, acc, x when x > 0 ->
      { result, idx, offset } = take(state, x, "i")
      case result do
        y when is_integer(y) -> x = x - y
        y when is_binary(y) -> acc = append(y, acc)
        %{d: y} -> x = x - y
      end
      takeDelete {op, idx, offset, side}, acc, x

    state, acc, x -> {state, acc}
  end

  mdef takeInteger do
    state = {op, idx, offset, side}, acc, x when x > 0 ->
      { result, idx, offset } = take(state, x, "i")
      acc = append(result, acc)
      if is_binary(result), do: x = x - componentLength(result)
      takeInteger {op, idx, offset, side}, acc, x

    state, acc, x -> {state, acc}
  end
  
  #-------------------------------------------------------------------------------- 
  def take({op, idx, offset, side}, n, indivisableField \\ nil) do
    if idx == length(op) do
      if n = -1, do: nil, else: n
    else
      takeApply({Enum.at(op, idx), idx, offset}, n, indivisableField)
    end
  end

  mdef takeApply do
    state = {c, idx, offset}, n, indivisableField when is_integer(c) ->
      if n == -1 || c - offset <= n do
        {c - offset, idx + 1, 0}
      else
        {n, idx, offset + n}
      end
    state = {c, idx, offset}, n, indivisableField when is_binary(c) ->
      if n == -1 || indivisableField == "i" || String.length(c) - offset <= n do
        { String.slice(c, offset, 9999999), idx + 1, 0 }
      else
        { String.slice(c, offset, offset + n), idx, offset + n }
      end
    state = {%{d: d}, idx, offset}, n, indivisableField -> 
      if n == 1 || indivisableField == "d" || d - offset <= n do
        { %{d: d - offset }, idx + 1, 0 }
      else
        { %{d: n}, idx, offset + n }
      end
  end

  def peek({op, idx, offset, side}), do: Enum.at(op, idx)
  
  #-------------------------------------------------------------------------------- 
  def exportsCompose(op1, op2) do
    checkOp(op1)
    checkOp(op2)

    state = { Enum.at(op1, 0), 0, 0, "" }
    { acc, state } = Enum.reduce(op2, {[], state}, &exportsComposeApply/2)
    
    acc = takeFinal(state, acc)
    trim(acc)
  end

  mdef exportsComposeApply do
    x, {acc, state = {op, idx, offset, side}} when is_integer(x) ->
      {{ result, idx, offset }, acc } = takeInteger(state, acc, x)
      {acc, {op, idx, offset, side}}
    x, {acc, state = {op, idx, offset, side}} when is_binary(x) ->
      acc = append(x, acc)
      {acc, {op, idx, offset, side}}
    %{d: x}, {acc, state = {op, idx, offset, side}} ->
      {{ result, idx, offset }, acc } = takeComposeDelete(state, acc, x)
      {acc, {op, idx, offset, side}}
  end


  mdef takeComposeDelete do
    state = {op, idx, offset, side}, acc, x when x > 0 ->
      { result, idx, offset } = take(state, x, "d")
      case result do
        y when is_integer(y) -> 
          x = x - y
          acc = append(%{d: result}, acc)
        y when is_binary(y) -> x = x - String.length(y)
        %{d: y} -> acc = append(result, acc)
      end
      takeComposeDelete {op, idx, offset, side}, acc, x

    state, acc, x -> {state, acc}
  end

  mdef takeComposeInteger do
    state = {op, idx, offset, side}, acc, x when x > 0 ->
      { result, idx, offset } = take(state, x, "d")
      acc = append(result, acc)
      if is_map(result), do: x = x - componentLength(result)
      takeComposeInteger {op, idx, offset, side}, acc, x

    state, acc, x -> {state, acc}
  end
  #-------------------------------------------------------------------------------- 
  mdef componentLength do
    c when is_integer(c) -> c
    c when is_binary(c)  -> String.length(c)
    c when is_list(c)    -> length(c)
  end

  # Trim any excess skips from the end of an operation.
  # There should only be at most one, because the operation was made with append.
  mdef trim do
    [ x | rest ] when is_integer(x) -> rest
    x                               -> x
  end

  def exportsNormalize(op) do
    Enum.reduce(op, [], &append/2)
    |> trim
    |> Enum.reverse
  end

  #-------------------------------------------------------------------------------- 
  def exportsApply(str, op) when is_binary(str) do
    checkOp op
    Enum.reduce(op, {str, []}, &applyOp/2)
    |> elem(1)
    |> Enum.reverse
    |> IO.iodata_to_binary
  end

  mdef applyOp do
    %{d: d}, {str, acc}                -> { String.slice(str, d, 999999), acc }
    op, {str, acc} when is_binary(op)  -> { str, [ op | acc ] }
    op, {str, acc} when is_integer(op) ->
      if op > String.length(str), do: raise "The op is too long for this document"
      { String.slice(str, op, 999999),  [ String.slice(str, 0, op) | acc ] }
  end
  #-------------------------------------------------------------------------------- 

  def transformPosition(cursor, op), do: transformPositionPrime(cursor, op, 0)

  mdef transformPositionPrime do
    cursor, [], _ -> cursor
    cursor, _, pos when cursor <= pos -> cursor

    cursor, [op | rest], pos when is_integer(op) ->
      if cursor <= (pos + op), do: cursor, else: transformPositionPrime(cursor, rest, pos + op)

    cursor, [op | rest], pos when is_binary(op) ->
      cl = String.length(op)
      transformPositionPrime(cursor + cl, rest, pos + cl)

    cursor, [%{d: d} | rest], pos ->
      transformPositionPrime(cursor - min(d, cursor - pos), rest, pos)
  end
  #-------------------------------------------------------------------------------- 

  def exportsTransformSelection(selection, op, isOwnOp) do
    if isOwnOp do
    # Just track the position. We'll teleport the cursor to the end anyway.
    # This works because text ops don't have any trailing skips at the end - so the last
    # component is the last thing.
      Enum.reduce(op, 0, &applyOwnSelection/2)
    else
      applySelection(selection, op)
    end
  end
  
  mdef applyOwnSelection do
    c, acc when is_integer(c) -> acc + c
    c, acc when is_binary(c)  -> acc + Enum.length(c)
  end

  mdef applySelection do
    selection, op when is_integer(selection) -> transformPosition(selection, op)
    [ sel0, sel1 | _ ], op                   -> [ transformPosition(sel0, op), transformPosition(sel1, op) ]
  end
  #-------------------------------------------------------------------------------- 

  
  # TODO: Hope I got the logic right, defintively could use some tests, if I knew
  # what the desired result was
  def exportsSelectionEq(c1, c2) do
    c1 = take_first c1
    c2 = take_first c2
    [ c1_0, c1_1 | _ ] = c1
    [ c2_0, c2_1 | _ ] = c2
    c1 == c2 || ( !is_nil(c1_0) && !is_nil(c2_0) && c1_0 == c2_0 && c1_1 == c2_1 )
  end

  mdef take_first do
    [x, y | _], _ when not is_nil(x) and x == y -> x
    c -> c
  end

end
