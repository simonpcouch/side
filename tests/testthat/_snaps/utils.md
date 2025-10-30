# check_inherits errors informatively with wrong class

    Code
      check_inherits("a string", "myclass")
    Condition
      Error:
      ! `"a string"` must be a <myclass>, not a string.

