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

  test "checkSelection works well" do
    catch_error checkSelection([1])
    catch_error checkSelection(["hello", 2])
    assert checkSelection([1, 2]) == nil
    assert checkSelection([1, 2, 3]) == nil
    assert checkSelection(3) == nil
  end

  test "append works well" do
    assert append 1, [] == [1]
    assert append 1, [2] == [3]
    assert append "stian", ["peter"] == "peterstian"
    assert append %{d: 1}, [%{d: 2}, 3] == [%{d: 3}, 3]
    assert append nil, [1, 2] == [1, 2]
    assert append 1, [2, 3] == [1, 2, 3]
  end

  test "componentlength" do
    assert componentLength(5) == 5
    assert componentLength("stian") == 5
    assert componentLength([5, 2]) == 2
  end

  test "trim" do
    assert trim([1, 2]) == [2]
    assert trim(1) == 1
  end

  test "exportsNormalize" do
    assert exportsNormalize(["sitan"]) == ["sitan"]
    assert exportsNormalize(["sitan", 1]) == ["sitan"]
    assert exportsNormalize(["sitan", nil, 1]) == ["sitan"]
    assert exportsNormalize([4, "stian", %{d: 0}, 3]) == [4, "stian"] 
    assert exportsNormalize([4, "peter", %{d: 4}, %{d: 3}, 4]) == [4, "peter", %{d: 7}]
    assert exportsNormalize([3, 4, 5, "stian"]) == [12, "stian"]
    assert exportsNormalize([3, 4, 5, "stian", "peter"]) == [12, "stianpeter"]
  end

  test "exportsApply" do
    assert exportsApply("hello", [2, "hi", %{d: 1}, 2]) == "hehilo"
    assert exportsApply("Stian Haklev", [%{d: 3}, %{d: 2}, "Peter", 3, "Vadim", 4]) == "Peter HaVadimklev"
  end
end
