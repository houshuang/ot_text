defmodule Text do

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

  def exportsCreate(initial) when is_binary(initial) do
    initial
  end

  # Check the operation is valid. Throws if not valid.
  #---------------------------------------- 
  def checkOp([]), do: nil

  def checkOp([ %{d: x} | rest ]) when is_integer(x) do
    if !(x > 0), do: raise "Object components must be deletes of size > 0"
    checkOp rest
  end

  def checkOp([ x | rest ]) when is_binary(x) do
    if !(String.length(x) > 0), do: raise "Inserts cannot be empty" 
    checkOp rest
  end

  def checkOp([ x, y | rest ]) when is_integer(x) and is_integer(y) do
    raise "Adjacent skip components should be combined"
    checkOp rest
  end

  def checkOp([ x | rest ]) when is_integer(x) do
    if !(x > 0), do: raise "Skip components must be >0"
    checkOp rest
  end

  #---------------------------------------- 


  
end
defmodule OtText do
end
