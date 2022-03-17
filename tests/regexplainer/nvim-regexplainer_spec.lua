local Utils = require'tests.helpers.util'

local t = Utils.assert_popup_text_at_row

local regexplainer = require'regexplainer'

describe("Regexplainer", function()
  before_each(function ()
    Utils.clear_test_state()
  end)

  describe('in TypeScript', function()
    before_each(function()
      assert:set_parameter('fixture_filename', 'tests/fixtures/fixture.ts')
    end)

    describe('with default options', function()
      before_each(function ()
        regexplainer.setup()
      end)

      it("explains simple regexps", function()
        t(2, Utils.dedent[[
          `hello`
        ]])
      end)

      it("explains regexps with modifiers and escape chars", function()
        t(5, Utils.dedent[[
          `hello`
          `!` (_optional_)
        ]])

        t(6, Utils.dedent[[
          `hello.`
        ]])

        t(7, Utils.dedent[[
          `hello`
          `.` (_optional_)
        ]])
      end)

      it("explains regexps with special chars and control chars", function()
        t(10, Utils.dedent[[
          **START**
          `ok`
          **ANY** (_optional_)
          **END**
        ]])

        t(11, Utils.dedent[[
          **WB**
          **WORD**
          **0-9**
          **WS**
          **TAB**
          **LF**
          **CR**
        ]])

        t(7, Utils.dedent[[
          `hello`
          `.` (_optional_)
        ]])
      end)

      it("explains regexps with ranges and quantifiers", function()
        t(14, Utils.dedent[[
          `@hello`
          One of `a-z`
        ]])

        t(15, Utils.dedent[[
          `a` (_1x_)
          `b` (_>= 2x_)
          `c` (_3-5x_)
          `d` (_>= 0x_)
          `e` (_>= 1x_)
        ]])

        t(16, Utils.dedent[[
          **WB**
          One of `a-z`, `0-9`, `.`, `\_`, `%`, `+`, or `-` (_>= 1x_)
          `@hello`
          One of `a-z`, `0-9`, `.`, or `-` (_>= 1x_)
          `.`
          One of `a-z` (_>= 2x_)
          **WB**
        ]])

        t(17, Utils.dedent[[
          One of **WB**, **WORD**, **0-9**, **WS**, **TAB**, **LF**, or **CR**
        ]])

        t(18, Utils.dedent[[
          **START**
          One of `a-z`, `A-Z`, or `0-9` (_6-12x_)
          **END**
        ]])

        t(19, Utils.dedent[[
          One of `-`, **WORD**, or `.`
        ]])

        t(20, Utils.dedent[[
          One of **WORD**, `,`, or `.`
        ]])

        t(21, Utils.dedent[[
          One of **WORD**, `-`, or `.`
        ]])

        t(22, Utils.dedent[[
          One of `.`, `-`, or **WORD**
        ]])
      end)

      it("explains regexps with negated ranges", function()
        t(25, Utils.dedent[[
          **START**
          `p`
          Any except `p`, `^`, or `a` (_>= 0x_)
          `p`
        ]])
      end)

      it("explains regexps with capture groups", function()
        t(28, Utils.dedent[[
          `@`
          capture group 1:
            `hello`
        ]])

        t(29, Utils.dedent[[
          `@`
          capture group 1:
            `hello`
          capture group 2:
            `world`
        ]])

        t(30, Utils.dedent[[
          `zero`
          capture group 1:
            `one`
            capture group 2:
              `two`
              capture group 3:
                `three`
        ]])

        t(31, Utils.dedent[[
          `@`
          capture group 1:
            **WB**
            **WORD**
            **0-9**
            **WS**
            **TAB**
            **LF**
            **CR**
        ]])

        t(32, Utils.dedent[[
          `@`
          capture group 1:
            `a1`
            **0-9**
        ]])
      end)

      it("explains regexps with named capture groups", function()
        t(35, Utils.dedent[[
          capture group 1 (_optional_):
            `hello`
          named capture group 2 `hello` (_>= 1x_):
            `world`
          non-capturing group (_2-3x_):
            `one`
        ]])

        t(36, Utils.dedent[[
          capture group 1:
            One of `a-z`, or `a-z` (_2-5x_)
          `a`
          `-` (_optional_)
          named capture group 2 `hello` (_4-5x_):
            `world`
        ]])

        t(37, Utils.dedent[[
          capture group 1:
            One of `a-z`, or `a-z` (_2-5x_)
          `-` (_optional_)
          named capture group 2 `dolly`:
            **WB**
            **WORD**
            **0-9**
            **WS**
            **TAB**
            **LF**
            **CR**
        ]])
      end)

      it("explains regexps with non-capturing groups", function()
        t(40, Utils.dedent[[
          `hello`
          non-capturing group:
            Either `world` or `dolly`
        ]])
      end)

      it("explains regexps with alternations", function()
        t(43, Utils.dedent[[
          Either **WB**, **WORD**, **0-9**, **WS**, **TAB**, **LF**, or **CR**
        ]])

        t(44, Utils.dedent[[
          Either `one` or `two`
        ]])

        t(45, Utils.dedent[[
          Either `one`, `two`, or `three`
        ]])

        t(46, "capture group 1:\n  Either `one`, `two`, or `three`")

        --TODO: get a better dedenter
        t(47, [[Either `zero`, `bupkis`, `gornisht`, or capture group 1:
  Either `one`, `two`, `three`, or capture group 2:
    Either `four` or `five`]])

        t(48, Utils.dedent[[
          `"`
          capture group 1:
            Either `http` or capture group 2:
              `cs`
            `s`
          `"`
          `;` (_optional_)
        ]])
      end)

      it("explains regexps with lookaheads", function()
        t(51, Utils.dedent[[
          `@` **followed by **:
            `u`
          `@`
        ]])

        t(52, Utils.dedent[[
          `@` **NOT followed by **:
            `u`
          `@`
        ]])

        t(53, Utils.dedent[[
          `@` **followed by ** (_2-3x_):
            Either `up` or `down`
          `@`
        ]])

        t(54, Utils.dedent[[
          `@` **NOT followed by **:
            One of **WORD**, or **WS**
          `@`
        ]])

        t(55, Utils.dedent[[
          `@` **followed by **:
            `g`
            non-capturing group (_optional_):
              `raph`
            `ql`
          `@`
        ]])
      end)

      it("explains regexps with lookbehinds", function()
        t(58, Utils.dedent[[
          ⚠️ **Lookbehinds are poorly supported**
          ⚠️ results may not be accurate
          ⚠️ See https://github.com/tree-sitter/tree-sitter-regex/issues/13

          **preceeding **:
            `it's the `
          `attack of the killer tomatos`
        ]])

        t(59, Utils.dedent[[
          ⚠️ **Lookbehinds are poorly supported**
          ⚠️ results may not be accurate
          ⚠️ See https://github.com/tree-sitter/tree-sitter-regex/issues/13

          `x`
          **NOT preceeding **:
            `u`
          `@`
        ]])
      end)

      it("explains various practical examples", function()
        t(65, Utils.dedent[[
          **START**
          `@scope/`
          capture group 1:
            **ANY** (_>= 0x_)
          `.js";;` (_optional_)
          **END**
        ]])

        t(66, Utils.dedent[[
          `@scope/`
          capture group 1:
            **ANY** (_>= 0x_)
          `.`
          named capture group 2 `extension`:
            Either `graphql` or non-capturing group:
              Either `t`, `j`, or `cs`
            `s`
          `"`
          `;` (_optional_)
        ]])

        t(67, Utils.dedent[[
          non-capturing group:
            `g`
            non-capturing group (_optional_):
              `raph`
            `ql`
          `\``
          capture group 1:
            **ANY** (_>= 0x_)
          `\``
        ]])
      end)

      it("explains regexps with errors", function()
        t(70, Utils.dedent[[
          🚨 **Regexp contains an ERROR** at
          `@scope\/(.*)\.{graphql,js,ts,css}`
                          ^
        ]])
      end)
    end)
  end)

  describe('sudoku.js', function()
    before_each(function()
      assert:set_parameter('fixture_filename', 'tests/fixtures/sudoku.js')
    end)

    describe('with default options', function()
      before_each(function ()
        regexplainer.setup()
      end)

      it("explains", function()
        t(1,  Utils.dedent[[
          **0-9** (_>= 0x_)
          capture group 1:
            **0-9**
        ]])

        -- TODO: get a better dedenter
        t(2, [[**NOT followed by **:
  non-capturing group (_>= 1x_):
    **ANY** (_>= 0x_)
    **LF**
  non-capturing group (_0x_):
    **ANY** (_10x_)
  `1`
  **WB**]])

        t(3, [[**NOT followed by **:
  **0-9** (_>= 0x_)
  ` `
  non-capturing group (_>= 0x_):
    **ANY** (_10x_)
  `1`
  **WB**]])

        t(4, [[**NOT followed by **:
  **0-9** (_>= 0x_)
  ` `
  non-capturing group (_0-1x_):
    **ANY** (_10x_)
  `1`
  **WB**]])

        t(5, [[**NOT followed by **:
  non-capturing group (_1-2x_):
    **ANY** (_>= 0x_)
    **LF**
  non-capturing group (_0x_):
    **ANY** (_30x_)
  non-capturing group (_0-2x_):
    **ANY** (_10x_)
  `1`
  **WB**]])

        t(6, [[**0-9** (_>= 0x_)
**WS** (_>= 1x_)]])
      end)

    end)
  end)
end)

