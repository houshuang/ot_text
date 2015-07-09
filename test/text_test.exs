defmodule TextTest do
  use ExUnit.Case
  use Amrita.Sweet
  import Text

  test "checkOps only let's valid operations through" do
    catch_error checkOp("hello")
    catch_error checkOp([1, 2])
    catch_error checkOp([-2])
    catch_error checkOp([%{p: 1}])
    catch_error checkOp([%{d: -2}])
  end

  test "checkOps will not fail on valid operations" do
    assert checkOp(["hello"]) == nil
    assert checkOp([1]) == nil
    assert checkOp(["hello", 2, %{d: 3}]) == nil
  end
end
