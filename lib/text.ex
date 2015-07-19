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

  # Exported functions

  # apply/2          : check     
  # normalize/1      : check          
  # transform/3             
  # compose/2            
  # selectionEq/2        
  # transformSelection/3
  # create/1         : check
  # take/3

  def create(initial) when is_binary(initial), do: initial

  # Check the operation is valid. Throws if not valid.
  #--------------------------------------------------------------------------------  
  mdefp checkOp do
    [] -> nil

    [x] when is_integer(x) -> raise "Op has a trailing skip"

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

  mdefp checkSelection do
    [ selection1, selection2 | _ ] 
      when is_integer(selection1) and is_integer(selection2) -> nil

    x when is_integer(x) -> nil
  end 

  # from makeAppend which returns a function
  mdefp append do
    component, []                                        -> [ component ]
    nil, acc                                             -> acc
    %{d: 0}, acc                                         -> acc
    %{d: x}, [ %{d: y} | rest ]                          -> [ %{d: x + y} | rest ]
    x, [ y | rest ] when is_integer(x) and is_integer(y) -> [ y + x | rest ]
    x, [ y | rest ] when is_binary(x) and is_binary(y)   -> [ y <> x | rest ]
    component, acc                                       -> [ component | acc ]
  end

  #-------------------------------------------------------------------------------- 
  def transform(op, otherOp, side) do
    if side != "left" && side != "right", do: raise "Side must be left or right"

    checkOp(op)
    checkOp(otherOp)

    state = %{ op: op, idx: 0, offset: 0, side: side} 
    { state, acc } = Enum.reduce(otherOp, {state, []}, &transformApply/2)
    
    acc = takeFinal({state, acc})
    |> Enum.reverse
    |> trim
  end


  mdefp transformApply do
    x, {state, acc} when is_integer(x) ->
      IO.inspect(state)
      takeInteger({state, acc}, x)
      
    x, {state, acc} when is_binary(x) ->
      if state.side == "left" do
        if is_binary(peek(state)) do
          { result, idx, offset } = take(state, -1)
          state = %{ state | idx: idx, offset: offset }
          acc = append(result, acc)
        end
      else
        acc = append(String.length(x), acc)
      end
      {state, acc}
        
    %{d: d}, {state, acc} ->
      takeDelete({state, acc}, d)
  end
  #-------------------------------------------------------------------------------- 

  defp takeFinal({state, acc}) do
    { result, idx, offset } =take(state, -1)
    if is_nil(result) do
      acc
    else
      acc = append(result, acc)
      takeFinal { %{ state | idx: idx, offset: offset}, acc }
    end
  end

  mdefp takeDelete do
    {state, acc}, x when x > 0 ->
      { result, idx, offset } = take(state, x, "i")
      case result do
        y when is_integer(y) -> x = x - y
        y when is_binary(y) -> acc = append(y, acc)
        %{d: y} -> x = x - y
      end
      takeDelete({ %{ state | idx: idx, offset: offset }, acc }, x)

    {state, acc}, x -> {state, acc}
  end

  mdefp takeInteger do
    {state, acc}, x when x > 0 ->
      IO.inspect(state)
      { result, idx, offset } = take(state, x, "i")
      acc = append(result, acc)
      if is_binary(result), do: x = x - componentLength(result)
      takeInteger { %{ state| idx: idx, offset: offset}, acc }, x

    {state, acc}, x -> {state, acc}
  end
  
  #-------------------------------------------------------------------------------- 
  def take(state = %{op: op, idx: idx, offset: offset}, 
    n, indivisableField \\ nil) do

    if idx == length(op) do
      res = if n == -1, do: nil, else: n
      { res, idx, offset }
    else
      takeApply(Map.put(state, :c, Enum.at(op, idx)), n, indivisableField)
    end
  end

  mdefp takeApply do
    %{c: c, idx: idx, offset: offset}, n, indivisableField when is_integer(c) ->
      if n == -1 || c - offset <= n do
        {c - offset, idx + 1, 0}
      else
        {n, idx, offset + n}
      end
    %{c: c, idx: idx, offset: offset}, n, indivisableField when is_binary(c) ->
      if n == -1 || indivisableField == "i" || String.length(c) - offset <= n do
        { String.slice(c, offset, 9999999), idx + 1, 0 }
      else
        { String.slice(c, offset, n), idx, offset + n }
      end
    %{c: %{d: d}, idx: idx, offset: offset}, n, indivisableField -> 
      if n == -1 || indivisableField == "d" || d - offset <= n do
        { %{d: d - offset }, idx + 1, 0 }
      else
        { %{d: n}, idx, offset + n }
      end
  end

  defp peek(%{ op: op, idx: idx }), do: Enum.at(op, idx)
  
  #-------------------------------------------------------------------------------- 
  def compose(op1, op2) do
    checkOp(op1)
    checkOp(op2)

    state = %{ op: op1, idx: 0, offset: 0 } 
      
    { state, acc } = Enum.reduce(op2, {state, []}, &composeApply/2)
    takeFinal({state, acc})
    |> Enum.reverse
  end

  mdefp composeApply do
    x, {state, acc} when is_integer(x) ->
      takeComposeInteger({ state, acc }, x)
    x, {state, acc} when is_binary(x) ->
      acc = append(x, acc)
      { state, acc }
    %{d: x}, {state, acc} ->
      takeComposeDelete( {state, acc }, x)
  end


  mdefp takeComposeDelete do
    { state, acc }, x when x > 0 ->
      { result, idx, offset } = take(state, x, "d")
      case result do
        y when is_integer(y) -> 
          x = x - y
          acc = append(%{d: result}, acc)
        y when is_binary(y) -> x = x - String.length(y)
        %{d: y} -> acc = append(result, acc)
      end
      takeComposeDelete { %{state | idx: idx, offset: offset }, acc }, x

    {state, acc}, x -> {state, acc}
  end

  mdefp takeComposeInteger do
    {state, acc}, x when x > 0 ->
      { result, idx, offset } = take(state, x, "d")
      acc = append(result, acc)
      if !is_map(result), do: x = x - componentLength(result)
      takeComposeInteger {%{ state | idx: idx, offset: offset}, acc}, x

    {state, acc}, x -> {state, acc}
  end
  #-------------------------------------------------------------------------------- 
  mdefp componentLength do
    c when is_integer(c)    -> c
    c when is_binary(c)     -> String.length(c)
    c when is_list(c)       -> length(c)
    %{d: c} -> c
  end

  # Trim any excess skips from the end of an operation.
  # There should only be at most one, because the operation was made with append.
  mdefp trim do
    [ x | rest ] when is_integer(x) -> rest
    x                               -> x
  end

  def normalize(op) do
    Enum.reduce(op, [], &append/2)
    |> trim
    |> Enum.reverse
  end

  #-------------------------------------------------------------------------------- 
  def apply(str, op) when is_binary(str) do
    checkOp op
    {str, acc} = Enum.reduce(op, {str, []}, &applyOp/2)
    acc = acc
    |> Enum.reverse
    |> IO.iodata_to_binary
    acc <> str
  end

  mdefp applyOp do
    %{d: d}, {str, acc}                -> { String.slice(str, d, 999999), acc }
    op, {str, acc} when is_binary(op)  -> { str, [ op | acc ] }
    op, {str, acc} when is_integer(op) ->
      if op > String.length(str), do: raise "The op is too long for this document"
      { String.slice(str, op, 999999),  [ String.slice(str, 0, op) | acc ] }
  end
  #-------------------------------------------------------------------------------- 

  defp transformPosition(cursor, op), do: transformPositionPrime(cursor, op, 0)

  mdefp transformPositionPrime do
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

  def transformSelection(selection, op, isOwnOp) do
    if isOwnOp do
    # Just track the position. We'll teleport the cursor to the end anyway.
    # This works because text ops don't have any trailing skips at the end - so the last
    # component is the last thing.
      Enum.reduce(op, 0, &applyOwnSelection/2)
    else
      applySelection(selection, op)
    end
  end
  
  mdefp applyOwnSelection do
    c, acc when is_integer(c) -> acc + c
    c, acc when is_binary(c)  -> acc + String.length(c)
  end

  mdefp applySelection do
    selection, op when is_integer(selection) -> transformPosition(selection, op)
    [ sel0, sel1 | _ ], op                   -> [ transformPosition(sel0, op), transformPosition(sel1, op) ]
  end
  #-------------------------------------------------------------------------------- 

  
  # TODO: Hope I got the logic right, defpintively could use some tests, if I knew
  # what the desired result was
  def selectionEq(c1, c2) do
    c1 = take_first c1
    c2 = take_first c2
    [ c1_0, c1_1 | _ ] = c1
    [ c2_0, c2_1 | _ ] = c2
    c1 == c2 || ( !is_nil(c1_0) && !is_nil(c2_0) && c1_0 == c2_0 && c1_1 == c2_1 )
  end

  mdefp take_first do
    [x, y | _], _ when not is_nil(x) and x == y -> x
    c -> c
  end

end
