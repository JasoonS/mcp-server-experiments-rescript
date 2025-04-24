// MCP_SDK.res - Bindings for @modelcontextprotocol/sdk

// Content type for responses
type rec contentItem = {
  type_: string,
  text: string,
}

// Response type
type response = {
  content: array<contentItem>,
  isError?: bool,
}

// Server configuration
type capabilities = {
  tools: Dict.t<unknown>,
  resources: Dict.t<unknown>,
  prompts: Dict.t<unknown>,
  streaming: bool,
}

type serverConfig = {
  name: string,
  version: string,
  capabilities: capabilities,
}

// Schema shape type (for compatibility)
type schemaShape

// McpServer class
module McpServer = {
  type t

  @module("@modelcontextprotocol/sdk/server/mcp.js") @new
  external make: serverConfig => t = "McpServer"

  @send
  external tool: (t, string, string, schemaShape, 'params => promise<response>) => unit = "tool"

  @send
  external connect: (t, 'transport) => promise<unit> = "connect"

  @send
  external close: t => promise<unit> = "close"
}

// StdioServerTransport
module StdioServerTransport = {
  type t

  @module("@modelcontextprotocol/sdk/server/stdio.js") @new
  external make: unit => t = "StdioServerTransport"
}

// Zod bindings (for schema definition)
module Zod = {
  type t
  type schema<'a>

  @module("zod") @val
  external z: t = "z"

  // Common schema creation methods
  @send external object: (t, Dict.t<schema<'a>>) => schema<'a> = "object"
  @send external string: t => schema<string> = "string"
  @send external number: t => schema<float> = "number"
  @send external boolean: t => schema<bool> = "boolean"
  @send external array: (t, schema<'a>) => schema<array<'a>> = "array"

  // Schema modifiers
  @send external positive: schema<float> => schema<float> = "positive"
  @send external int: schema<float> => schema<float> = "int"
  @send external min: (schema<string>, int) => schema<string> = "min"
  @send external email: schema<string> => schema<string> = "email"
  @send external url: schema<string> => schema<string> = "url"
  @send external finite: schema<float> => schema<float> = "finite"
  @send external safe: schema<float> => schema<float> = "safe"
  @send external regex: (schema<string>, Js.Re.t, string) => schema<string> = "regex"
  @send external describe: (schema<'a>, string) => schema<'a> = "describe"
  @send external strict: schema<'a> => schema<'a> = "strict"

  // Enum support
  @send external enum_: (t, array<string>) => schema<string> = "enum"

  // Access to schema shape (for tool registration)
  @get external shape: schema<'a> => schemaShape = "shape"

  // Error type
  type zodError = {errors: array<{message: string}>}

  // Type inference helper
  type infer<'schema> = 'schema
}

// Process bindings for Node.js process
module Process = {
  type t

  @val external process: t = "process"
  @val external exit: int => unit = "process.exit"

  // Event handlers with specific types
  @send external onUncaughtExceptionRaw: (t, string, exn => unit) => unit = "on"
  @send external onSignalRaw: (t, string, unit => unit) => unit = "on"

  // Helper functions for common event handlers
  let onUncaughtException = (proc, handler) => {
    proc->onUncaughtExceptionRaw("uncaughtException", handler)
  }

  let onSIGTERM = (proc, handler) => {
    proc->onSignalRaw("SIGTERM", () => {
      handler()->ignore
    })
  }

  let onSIGINT = (proc, handler) => {
    proc->onSignalRaw("SIGINT", () => {
      handler()->ignore
    })
  }
}
