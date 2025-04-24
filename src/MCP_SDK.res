// MCP_SDK.res - Bindings for @modelcontextprotocol/sdk

// Content type for responses
type rec contentItem = {
  @as("type") type_: string,
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
type schemaShape = Zod.schemaShape

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
