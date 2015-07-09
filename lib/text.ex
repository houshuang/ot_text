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

  # from makeTake which returns a function
  # Take up to length n from the front of op. If n is -1, take the entire next
  # op component. If indivisableField == 'd', delete components won't be separated.
  # If indivisableField == 'i', insert components won't be separated.
  # idx (index into next component to take) and offset into component,
  # all start out at 0
  #-------------------------------------------------------------------------------- 
  # def take(n, indivisableField, op) do
  #   ì
  # end

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

  # c1, c2
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
    [ sel0, sel1 | _ ]                       -> [ transformPosition(sel0), transformPosition(sel1), op ]
  end

  def transformPosition(cursor, op) do
  end
end
