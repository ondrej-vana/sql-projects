# Debugging and Rewriting a Faulty Error Logger in PL/pgSQL

## Context

During a PL/pgSQL course, I encountered a common but subtle mistake in a helper function designed to run a SQL statement and, on failure, log the error details. The original implementation inadvertently executed the statement **twice** when an error occurred, leading to duplicated side effects and loss of the original error context.

## The Problem

The original code consisted of two parts:

1. A function <code>debug_statement(sql_stmt TEXT)</code> that took a string, executed it as a SQL statement, and if an error occurred, caught it, logged it, and returned <code>True</code>, otherwise returned <code>False</code>.

2. A <code>DO</code> block that used the function:

```sql
DO $$
DECLARE
  stmt VARCHAR(100) := 'UPDATE inventory SET cost = 35.0 WHERE name = ''Macaron'' ';
BEGIN
  EXECUTE stmt;
EXCEPTION WHEN others THEN
  PERFORM debug_statement(stmt);
END;
$$ language plpgsql;
```

Here was the issue: The <code>DO</code> block executed the statement first itself. If that first execution failed, the exception handler called <code>debug_statement</code>, which executed the same statement a second time. This caused the following:

- Double execution, which is risky for operations with varying results.
- The original error was not logged.
- If the second execution did not fail, the error went entirely unrecorded.

## The Solution

I rewrote the code to execute the statement exactly once and record the error context immediately, using PostgreSQL's <code>GET STACKED DIAGNOSTICS</code> inside the same block where the error occurred.

```sql
DO $$
DECLARE
  stmt VARCHAR(100) := 'UPDATE inventory SET cost = 35.0 WHERE name = ''Macaron'' ';
  had_error BOOLEAN;
BEGIN
  had_error := debug_statement(stmt);
  IF had_error THEN
    RAISE NOTICE 'Statement failed, error logged.'
  END IF;
END;
$$ language plpgsql;
```

---

<details>
<summary>The <code>debug_statement</code> function code for context.</summary>

```sql
CREATE OR REPLACE FUNCTION debug_statement(sql_stmt TEXT)
RETURNS BOOLEAN AS $$
DECLARE
  v_state    TEXT;
  v_msg      TEXT;
  v_detail   TEXT;
  v_context  TEXT;
BEGIN
  BEGIN
    EXECUTE sql_stmt;
  EXCEPTION WHEN others THEN -- others → catching all violation types
    GET STACKED DIAGNOSTICS
      v_state    = RETURNED_SQLSTATE,     -- the SQLSTATE error code
      v_msg      = MESSAGE_TEXT,          -- text of the exception's primary message
      v_detail   = PG_EXCEPTION_DETAIL    -- text of the exception's detail message
      v_context  = PG_EXCEPTION_CONTEXT;  -- location in the stack at which the error was detected
    INSERT INTO errors (state, msg, detail, context)
      VALUES (v_state, v_msg, v_detail, v_context);
    RETURN True;
  END;
  RETURN FALSE;
END;
$$ LANGUAGE plpgsql;
```

</details>

→ [Return to my SQL Portfolio.](/../../)
