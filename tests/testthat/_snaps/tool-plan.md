# validate_plan_steps errors with empty plan

    Code
      validate_plan_steps(list())
    Condition
      Error:
      ! Plan must contain at least one step.

# validate_plan_steps errors with missing description

    Code
      validate_plan_steps(steps)
    Condition
      Error:
      ! Step 1 must have 'description' and 'status' fields.

# validate_plan_steps errors with missing status

    Code
      validate_plan_steps(steps)
    Condition
      Error:
      ! Step 1 must have 'description' and 'status' fields.

# validate_plan_steps errors with invalid status

    Code
      validate_plan_steps(steps)
    Condition
      Error:
      ! Step 1 has invalid status "invalid". Must be one of "pending", "in_progress", and "completed".

# validate_plan_steps errors with multiple in_progress

    Code
      validate_plan_steps(steps)
    Condition
      Error:
      ! Plan must have exactly one 'in_progress' step (unless all steps are 'completed' or 'pending').

# validate_plan_steps errors with no in_progress in mixed plan

    Code
      validate_plan_steps(steps)
    Condition
      Error:
      ! Plan must have exactly one 'in_progress' step (unless all steps are 'completed' or 'pending').

