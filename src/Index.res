/**
 * MCP Server Starter Template
 *
 * This is a reference implementation of a Model Context Protocol (MCP) server.
 * It demonstrates best practices for:
 * - Server initialization and configuration
 * - Tool registration and management
 * - Error handling and logging
 * - Resource cleanup
 *
 * For more information about MCP, visit:
 * https://modelcontextprotocol.io
 */
open MCP_SDK

// Import our tool implementations
open Calculator
open TextTool
open InitializeIndexer

/**
 * Create a new MCP server instance with full capabilities
 */
let server = McpServer.make({
  name: "mcp-server-starter",
  version: "0.1.0",
  capabilities: {
    tools: Dict.make(),
    resources: Dict.make(),
    prompts: Dict.make(),
    streaming: true,
  },
})

/**
 * Helper function to send log messages to the client
 */
let logMessage = (level: string, message: string) => {
  Console.error(`[${level->String.toUpperCase}] ${message}`)
}

let getErrorMessage = error => {
  switch error {
  | Exn.Error(jsExn) => jsExn->Exn.message->Option.getOr("Unknown error")
  | _ => "Unknown error"
  }
}

/**
 * Set up error handling for the server
 */
Process.process->Process.onUncaughtException(error => {
  logMessage("error", `Uncaught error: ${getErrorMessage(error)}`)
  Console.error2("Server error:", error)
})

// Register example tools
try {
  registerCalculatorTool(server)
  registerTextTools(server)
  registerInitializeIndexerTool(server)
  logMessage("info", "Successfully registered all tools")
} catch {
| error => {
    logMessage("error", `Failed to register tools: ${getErrorMessage(error)}`)
    Process.exit(1)
  }
}

/**
 * Set up proper cleanup on process termination
 */
let cleanup = async () => {
  try {
    await server->McpServer.close
    logMessage("info", "Server shutdown completed")
  } catch {
  | error => logMessage("error", `Error during shutdown: ${getErrorMessage(error)}`)
  }
  Process.exit(0)
}

// Handle termination signals
Process.process->Process.onSIGTERM(cleanup)
Process.process->Process.onSIGINT(cleanup)

/**
 * Main server startup function
 */
let main = async () => {
  try {
    // Set up communication with the MCP host using stdio transport
    let transport = StdioServerTransport.make()
    await server->McpServer.connect(transport)

    logMessage("info", "MCP Server started successfully")
    Console.error("MCP Server running on stdio transport")
  } catch {
  | error => {
      logMessage("error", `Failed to start server: ${getErrorMessage(error)}`)
      Process.exit(1)
    }
  }
}

// Start the server
main()
->Promise.catch(error => {
  Console.error2("Fatal error in main():", error)
  Process.exit(1)
  Promise.resolve()
})
->ignore
