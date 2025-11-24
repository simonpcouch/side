# fetch_skill_impl errors informatively when skill not found

    Code
      fetch_skill_impl("nonexistent-skill")
    Condition
      Error:
      ! Skill "nonexistent-skill" not found.
      i Available skills: "write-unit-tests"

