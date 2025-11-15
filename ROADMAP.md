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
**Status:** ✅ Complete
**Files:** `lib/envious/parser.ex`, `lib/envious.ex`

Currently, the parser creates a flat list `["KEY", "value"]` that gets chunked by 2 in the main module. This is fragile and error-prone.

**Completed:** Parser now returns structured tuples `[{key, value}]` instead of flat list. The main module uses `Map.new/1` directly, eliminating fragile chunking logic. Added comprehensive documentation to both modules.

**Changes made:**
- Parser returns structured tuples: `[{"KEY", "value"}]`
- Equals sign is part of key-value structure (not globally ignored)
- Main module simplified to use `Map.new/1` instead of chunking
- Added `to_tuple` post-traverse callback with proper handling of NimbleParsec's reverse accumulator order

### 3. Fix Export Handling
**Status:** ✅ Complete (fixed in items #1 and #2)
**File:** `lib/envious/parser.ex:131-137`

The current `var_name` parser has confusing logic with the bare `repeat()` on line 47, and export handling needs to be truly optional.

**Completed:** Export handling is now clean and optional via `optional(ignore(export))` in the key_value combinator. The confusing `repeat()` has been removed. Both `export KEY=value` and `KEY=value` work correctly.

**Changes made:**
- Export prefix is now optional via `optional(ignore(export))`
- Removed confusing `repeat()` combinator
- Both syntaxes work correctly (verified by tests)

### 4. Support Quoted Values
**Status:** ✅ Complete
**File:** `lib/envious/parser.ex:93-169`

.env files commonly use quotes to preserve spaces and special characters.

**Completed:** Added support for both double-quoted and single-quoted values. Values can now contain spaces and special characters when wrapped in quotes. Empty quoted values are also supported.

**Changes made:**
- Added `double_quoted_value` parser for `"value with spaces"`
- Added `single_quoted_value` parser for `'value with spaces'`
- Updated `val` to choose between quoted and unquoted values
- Preserved backward compatibility - unquoted values still work
- Inline comments still work with unquoted values

**Example cases supported:**
```
MESSAGE="Hello World"           # Works!
PATH='/usr/local/bin:/usr/bin'  # Works!
EMPTY=""                        # Works!
PORT=3000                       # Still works!
FOO=bar # comment               # Still works!
```

**Note:** Escape sequences (like `\"` inside quotes) will be handled in item #8.

### 5. Better Error Handling
**Status:** ✅ Complete
**File:** `lib/envious.ex:41-58`

Currently returns raw NimbleParsec tuple. Should provide user-friendly error messages.

**Completed:** Added comprehensive error handling that detects unparsed input and returns helpful error messages with line/column information.

**Changes made:**
- Success with all input consumed: returns `{:ok, map}`
- Unparsed input remaining: returns `{:error, "Parse error at line X, column Y: could not parse..."}`
- Includes preview of problematic input in error message
- Added 6 test cases for error scenarios

**Example error messages:**
```elixir
Envious.parse("KEY=\"unclosed")
# => {:error, "Parse error at line 1, column 0: could not parse remaining input starting with: \"KEY=\\\"unclosed\""}

Envious.parse("KEY=value\nINVALID")
# => {:error, "Parse error at line 2, column 10: could not parse remaining input starting with: \"INVALID\""}
```

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
