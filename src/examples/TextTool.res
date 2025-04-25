/**
 * Text Tool Example
 *
 * This module demonstrates simple MCP tools for text manipulation.
 * It implements word counting and character counting functions.
 */
open MCP_SDK

// Define the parameter types to match the schemas
type wordCountParams = {text: string}

type charCountParams = {
  text: string,
  includeWhitespace: bool,
}

// Define possible errors
type textError = EmptyText | ProcessingError(string)
exception TextError(textError)

/**
 * Counts words in a text string
 */
let countWords = (text: string): int => {
  if text->String.trim === "" {
    0
  } else {
    text->String.trim->String.split(" ")->Array.filter(word => word !== "")->Array.length
  }
}

/**
 * Counts characters in a text string
 */
let countChars = (text: string, includeWhitespace: bool): int => {
  if includeWhitespace {
    text->String.length
  } else {
    text->String.replaceRegExp(/\s/g, "")->String.length
  }
}

/**
 * Registers the text tools with the MCP server
 */
let registerTextTools = (server: McpServer.t) => {
  {
    // Word Count Tool

    let wordCountSchema = {
      let props = {
        "text": Zod.z->Zod.string->Zod.describe("Text to count words in"),
      }
      Zod.z->Zod.object(props->Obj.magic)
    }

    server->McpServer.tool(
      "word_count",
      "Count the number of words in a text",
      wordCountSchema->Zod.shape,
      async params => {
        try {
          // Cast params to our defined type using Obj.magic
          let typedParams: wordCountParams = params->Obj.magic
          let count = countWords(typedParams.text)

          {
            content: [
              {
                type_: "text",
                text: count->Int.toString,
              },
            ],
          }
        } catch {
        | TextError(EmptyText) => {
            content: [
              {
                type_: "text",
                text: "0", // Empty text has 0 words
              },
            ],
          }
        | TextError(ProcessingError(msg)) => {
            content: [
              {
                type_: "text",
                text: `Error processing text: ${msg}`,
              },
            ],
            isError: true,
          }
        | exn => {
            content: [
              {
                type_: "text",
                text: `Unexpected error: ${exn
                  ->Exn.asJsExn
                  ->Option.flatMap(e => e->Exn.message)
                  ->Option.getOr("Unknown error")}`,
              },
            ],
            isError: true,
          }
        }
      },
    )
  }

  // Character Count Tool

  let charCountSchema = {
    let props = {
      "text": Zod.z->Zod.string->Zod.describe("Text to count characters in"),
      "includeWhitespace": Zod.z
      ->Zod.boolean
      ->Zod.describe("Whether to include whitespace in the count (default: false)")
      ->Obj.magic,
    }
    Zod.z->Zod.object(props->Obj.magic)
  }

  server->McpServer.tool(
    "char_count",
    "Count the number of characters in a text",
    charCountSchema->Zod.shape,
    async params => {
      try {
        // Cast params to our defined type using Obj.magic
        let typedParams: charCountParams = params->Obj.magic
        let count = countChars(typedParams.text, typedParams.includeWhitespace)

        {
          content: [
            {
              type_: "text",
              text: count->Int.toString,
            },
          ],
        }
      } catch {
      | TextError(EmptyText) => {
          content: [
            {
              type_: "text",
              text: "0", // Empty text has 0 characters
            },
          ],
        }
      | TextError(ProcessingError(msg)) => {
          content: [
            {
              type_: "text",
              text: `Error processing text: ${msg}`,
            },
          ],
          isError: true,
        }
      | exn => {
          content: [
            {
              type_: "text",
              text: `Unexpected error: ${exn
                ->Exn.asJsExn
                ->Option.flatMap(e => e->Exn.message)
                ->Option.getOr("Unknown error")}`,
            },
          ],
          isError: true,
        }
      }
    },
  )
}
