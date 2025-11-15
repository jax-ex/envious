# Envious Roadmap

This document outlines planned improvements for the Envious .env file parser.

## High Priority

### 1. Fix Value Parser
**Status:** ✅ Complete
**File:** `lib/envious/parser.ex:50-67`

Currently, the value parser only accepts lowercase letters `[?a..?z]`. This is too restrictive for real-world .env files.

**Completed:** Value parser now accepts all printable ASCII characters except newline, carriage return, and hash (#). Parser properly handles KEY=VALUE structure and multi-line files.

**Changes needed:**
- Accept alphanumeric characters (A-Z, a-z, 0-9)
- Accept common special characters (., _, -, /, :, etc.)
- Support empty values (`KEY=`)
- Handle values without breaking on whitespace

**Example cases to support:**
```
PORT=3000
DATABASE_URL=postgres://localhost:5432/mydb
API_KEY=abc123XYZ
EMPTY_VALUE=
```

### 2. Create Proper Key-Value Pair Structure
**Status:** Pending
**Files:** `lib/envious/parser.ex`, `lib/envious.ex:7-10`

Currently, the parser creates a flat list `["KEY", "value"]` that gets chunked by 2 in the main module. This is fragile and error-prone.

**Changes needed:**
- Parse equals sign as part of the key-value structure (not globally ignored)
- Return structured data: `[{"KEY", "value"}]` or similar
- Make the parser enforce proper `KEY=value` syntax

### 3. Fix Export Handling
**Status:** Pending
**File:** `lib/envious/parser.ex:44-48`

The current `var_name` parser has confusing logic with the bare `repeat()` on line 47, and export handling needs to be truly optional.

**Changes needed:**
- Make `export` prefix optional for all variable declarations
- Clean up the confusing `repeat()` combinator
- Ensure both `export KEY=value` and `KEY=value` work correctly

### 4. Support Quoted Values
**Status:** Pending
**File:** `lib/envious/parser.ex`

.env files commonly use quotes to preserve spaces and special characters.

**Changes needed:**
- Support double-quoted values: `KEY="value with spaces"`
- Support single-quoted values: `KEY='value with spaces'`
- Handle escaped quotes within quoted strings

**Example cases to support:**
```
MESSAGE="Hello World"
PATH='/usr/local/bin:/usr/bin'
QUOTE="She said \"hello\""
```

### 5. Better Error Handling
**Status:** Pending
**File:** `lib/envious.ex`

Currently returns raw NimbleParsec tuple. Should provide user-friendly error messages.

**Changes needed:**
- Parse successful returns: `{:ok, map}`
- Parse failures return: `{:error, "descriptive message"}`
- Include line/column information in error messages

## Medium Priority

### 6. Support for Empty Values
**Status:** Pending
**File:** `lib/envious/parser.ex`

Allow variables to be set to empty strings: `KEY=`

**Note:** This overlaps with item #1 but deserves explicit testing and handling.

### 7. Variable Expansion
**Status:** Pending
**File:** New module or parser extension

Support shell-style variable expansion.

**Example cases to support:**
```
HOME=/home/user
PATH=${HOME}/bin:${PATH}
DATABASE_URL=${DB_PROTOCOL}://${DB_HOST}:${DB_PORT}/${DB_NAME}
```

**Changes needed:**
- Parse `${VAR}` syntax
- Implement expansion logic (may need to be in main module, not parser)
- Handle undefined variable references (error or leave as-is?)

### 8. Escape Sequences
**Status:** Pending
**File:** `lib/envious/parser.ex`

Handle common escape sequences within quoted strings.

**Example cases to support:**
```
MESSAGE="Line 1\nLine 2"
TAB_SEPARATED="Column1\tColumn2"
ESCAPED_BACKSLASH="C:\\Users\\path"
```

**Changes needed:**
- Parse `\n`, `\t`, `\r`, `\\`, `\"`, `\'`
- Apply escape processing during parsing or post-processing

### 9. Multi-line Values
**Status:** Pending
**File:** `lib/envious/parser.ex`

Support multi-line values using backslash continuation or quoted multi-line strings.

**Example cases to support:**
```
LONG_VALUE="This is a \
multi-line \
value"

CERT="-----BEGIN CERTIFICATE-----
MIIBkTCB+wIJAKHHCgVZU...
-----END CERTIFICATE-----"
```

## Code Quality

### 10. Add Tags/Labels to Parser Combinators
**Status:** Pending
**File:** `lib/envious/parser.ex`

Use NimbleParsec's `tag/2` and `unwrap_and_tag/2` functions for better debugging and structured output.

**Example:**
```elixir
var_name =
  utf8_string([?A..?Z, ?a..?z, ?_], min: 1)
  |> unwrap_and_tag(:key)
```

### 11. Post-processing Functions
**Status:** Pending
**File:** `lib/envious/parser.ex`

Use NimbleParsec's post-processing capabilities (`:map`, custom reducer functions) to clean up data transformation.

### 12. More Comprehensive Tests
**Status:** Pending
**File:** `test/envious_test.exs`, `test/envious/parser_test.exs`

Add test cases for:
- Edge cases (empty files, only comments, whitespace variations)
- Error conditions (malformed syntax)
- All new features as they're implemented
- Property-based testing with StreamData?

## Notes

- Items should be tackled in order within each priority level
- Each item should include tests before being considered complete
- Breaking changes should be versioned appropriately
- Consider backwards compatibility when making changes
