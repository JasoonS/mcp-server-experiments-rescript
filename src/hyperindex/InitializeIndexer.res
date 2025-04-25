/**
 * Initialize Indexer Tool
 *
 * This module implements an MCP tool that initializes an Envio indexer by running
 * an external bash script that handles the interactive CLI process.
 */
open MCP_SDK

// Node.js module bindings
module Fs = {
  type stats

  module Stats = {
    @send external isDirectory: stats => bool = "isDirectory"
  }

  @module("fs") @val external statSync: string => stats = "statSync"
  @module("fs") @val external mkdirSync: (string, {"recursive": bool}) => unit = "mkdirSync"
  @module("fs") @val external writeFileSync: (string, string) => unit = "writeFileSync"
  @module("fs") @val external appendFileSync: (string, string) => unit = "appendFileSync"
}

// Debug logging utility that writes to file
let debugLog = (message: string): unit => {
  try {
    let timestamp = Js.Date.now()->Js.Float.toString
    // Fs.appendFileSync("/tmp/mcp_debug.log", `[${timestamp}] ${message}\n`)
    Fs.appendFileSync("debug.log", `[${timestamp}] ${message}\n`)
  } catch {
  | _ => () // Silently fail if we can't write to the log
  }
}

// JSON stringify binding
@val external jsonStringify: 'a => string = "JSON.stringify"

module Path = {
  @module("path") @variadic
  external join: array<string> => string = "join"
  @module("path") @val external resolve: string => string = "resolve"
}

module Os = {
  @module("os") @val external homedir: unit => string = "homedir"
}

module Buffer = {
  type t
  @send external toString: t => string = "toString"
}

module ChildProcess = {
  @module("child_process") @val
  external execSync: (string, {..}) => string = "execSync"

  @module("child_process") @val
  external spawnSync: (
    string,
    array<string>,
    {..},
  ) => {
    "status": Nullable.t<int>,
    "stdout": Buffer.t,
    "stderr": Buffer.t,
    "error": Nullable.t<exn>,
  } = "spawnSync"
}

// Define the parameter type explicitly
type paramType = {
  name: string,
  contractAddresses: array<string>,
  networks: array<string>,
  apiToken: string,
  language: string,
  outputDirectory: Nullable.t<string>,
}

// Define possible errors
type indexerError =
  | InvalidParams(string)
  | CommandExecutionError(string)
  | DirectoryCreationError(string)
  | MultipleContractsNotSupported
  | MultipleNetworksNotSupported

exception IndexerError(indexerError)

// Helper to check if a directory exists
let directoryExists = (path: string): bool => {
  try {
    let stats = Fs.statSync(path)
    stats->Fs.Stats.isDirectory
  } catch {
  | _ => false
  }
}
// Create directory recursively (similar to mkdir -p)
let createDirectoryRecursive = (path: string): unit => {
  try {
    if !directoryExists(path) {
      Fs.mkdirSync(path, {"recursive": true})
    }
  } catch {
  | exn =>
    let errorMsg =
      exn
      ->Exn.asJsExn
      ->Option.flatMap(e => e->Exn.message)
      ->Option.getOr("Unknown error")
    throw(IndexerError(DirectoryCreationError(errorMsg)))
  }
}

// Get path to the initialization script
let getScriptPath = (): string => {
  // Get the current directory of this module
  let scriptDir = Path.resolve("./src")
  Path.join([scriptDir, "initilazize.sh"])
}

/**
 * Registers the initialize indexer tool with the MCP server
 */
let registerInitializeIndexerTool = (server: McpServer.t) => {
  // Create schema for tool parameters
  let initializeIndexerSchema = {
    let props = {
      "name": Zod.z->Zod.string->Zod.min(1)->Zod.describe("The name of the indexer project"),
      "contractAddresses": Zod.z
      ->Zod.array(Zod.z->Zod.string)
      ->Zod.describe("Array of contract addresses to index (currently only supports one)"),
      "networks": Zod.z
      ->Zod.array(Zod.z->Zod.string)
      ->Zod.describe("Array of blockchain networks to index from (currently only supports one)"),
      "apiToken": Zod.z->Zod.string->Zod.min(1)->Zod.describe("Your Hypersync API token"),
      "language": Zod.z
      ->Zod.enum_(["javascript", "typescript", "rescript"])
      ->Zod.describe("Programming language for the indexer"),
      "outputDirectory": Zod.z
      ->Zod.string
      ->Zod.nullish
      ->Zod.describe(
        "Optional: Directory to create the indexer in (defaults to ~/envio/<name-of-indexer>)",
      ),
      // ->Obj.magic,
    }

    Zod.z->Zod.object(props->Obj.magic)
  }

  // Register tool with server
  server->McpServer.tool(
    "initialize_indexer",
    "Initialize an Envio indexer for a blockchain contract",
    initializeIndexerSchema->Zod.shape,
    async params => {
      try {
        let rawParams = params->Obj.magic
        debugLog("Received params: " ++ jsonStringify(rawParams))

        // Simply get the parameters directly
        let name = rawParams.name
        let contractAddresses = rawParams.contractAddresses
        let networks = rawParams.networks
        let apiToken = rawParams.apiToken
        let language = rawParams.language

        debugLog("Processing outputDirectory")
        let outputDirectory = switch rawParams.outputDirectory->Nullable.toOption {
        | Some("") =>
          debugLog("Empty string in outputDirectory")
          let homeDir = Os.homedir()
          let path = Path.join([homeDir, "envio", rawParams.name])
          debugLog("Using default path: " ++ path)
          path
        | None =>
          debugLog("No outputDirectory provided (null/undefined)")
          let homeDir = Os.homedir()
          debugLog(JSON.stringifyAny([homeDir, "envio", rawParams.name])->Option.getOr(""))
          debugLog("Using default path: " ++ Path.join([homeDir, "envio"]))
          let path = Path.join([homeDir, "envio", rawParams.name])
          debugLog("Using default path: " ++ path)
          path
        | Some(dir) =>
          debugLog("Using provided outputDirectory: " ++ dir)
          dir
        }

        // Validate inputs
        if contractAddresses->Array.length === 0 {
          throw(IndexerError(InvalidParams("At least one contract address must be provided")))
        }
        if networks->Array.length === 0 {
          throw(IndexerError(InvalidParams("At least one network must be provided")))
        }

        // For now, only support one contract and one network
        if contractAddresses->Array.length > 1 {
          throw(IndexerError(MultipleContractsNotSupported))
        }
        if networks->Array.length > 1 {
          throw(IndexerError(MultipleNetworksNotSupported))
        }

        // Get the first contract address and network
        let contractAddress = switch contractAddresses[0] {
        | Some(address) => address
        | None => throw(IndexerError(InvalidParams("No contract address provided")))
        }
        let network = switch networks[0] {
        | Some(network) => network
        | None => throw(IndexerError(InvalidParams("No network provided")))
        }

        // Get the path to the initialization script
        let scriptPath = getScriptPath()

        createDirectoryRecursive(outputDirectory)

        // Build the command to execute the bash script with parameters
        let command = `${scriptPath} --name "${name}" --language ${language} --output-dir "${outputDirectory}" --contract-address ${contractAddress} --network ${network} --api-token "${apiToken}"`
        debugLog("Executing command: " ++ command)

        // Execute the command
        try {
          // Make sure the script is executable
          let _ = ChildProcess.execSync(
            `chmod +x ${scriptPath}`,
            {"encoding": "utf8", "stdio": "pipe"},
          )

          // Execute the initialization script
          let result = ChildProcess.execSync(
            command,
            {
              "encoding": "utf8",
              "stdio": "pipe",
              "timeout": 300000, // 5 minute timeout
            },
          )

          // Process result (the bash script will output appropriate messages)
          {
            content: [
              {
                type_: "text",
                text: result->String.trim,
              },
            ],
          }
        } catch {
        | exn =>
          let errorMsg =
            exn
            ->Exn.asJsExn
            ->Option.flatMap(e => e->Exn.message)
            ->Option.getOr("Unknown error")
          debugLog("Command execution failed: " ++ errorMsg)

          // Try fallback with an alternative approach
          try {
            debugLog("Trying fallback with alternative approach")

            // Try running with 'yes' command to provide multiple delayed Enter keypresses
            let yesCommand = `yes "" | head -n 10 | (sleep 2 && cat) | ${command}`
            debugLog("Yes command: " ++ yesCommand)

            let result = ChildProcess.execSync(
              yesCommand,
              {
                "encoding": "utf8",
                "stdio": "pipe",
                "shell": true,
                "timeout": 300000, // 5 minute timeout
              },
            )

            debugLog("Fallback command output: " ++ result)
            debugLog("Command executed successfully via fallback")

            // Return success message
            {
              content: [
                {
                  type_: "text",
                  text: `Successfully initialized Envio indexer "${name}" in ${outputDirectory}`,
                },
              ],
            }
          } catch {
          | fallbackExn =>
            let fallbackErrorMsg =
              fallbackExn
              ->Exn.asJsExn
              ->Option.flatMap(e => e->Exn.message)
              ->Option.getOr("Unknown error")
            debugLog("Fallback execution also failed: " ++ fallbackErrorMsg)

            // Add detailed error information to help with debugging
            let errorDetails = `
Command attempted: ${command}
Primary error: ${errorMsg}
Fallback error: ${fallbackErrorMsg}

Possible solutions:
1. Try running the command manually to see the interactive prompts
2. Check if the envio CLI has a non-interactive mode or configuration options
3. Consider using a dedicated automation tool like 'expect' if available
`
            debugLog(errorDetails)
            throw(IndexerError(CommandExecutionError(errorDetails)))
          }
        }
      } catch {
      | IndexerError(InvalidParams(msg)) => {
          content: [
            {
              type_: "text",
              text: `Invalid parameters: ${msg}`,
            },
          ],
          isError: true,
        }
      | IndexerError(CommandExecutionError(msg)) => {
          content: [
            {
              type_: "text",
              text: `Error executing envio init command: ${msg}`,
            },
          ],
          isError: true,
        }
      | IndexerError(DirectoryCreationError(msg)) => {
          content: [
            {
              type_: "text",
              text: `Error creating directory: ${msg}`,
            },
          ],
          isError: true,
        }
      | IndexerError(MultipleContractsNotSupported) => {
          content: [
            {
              type_: "text",
              text: "Multiple contracts are not yet supported. Please provide only one contract address.",
            },
          ],
          isError: true,
        }
      | IndexerError(MultipleNetworksNotSupported) => {
          content: [
            {
              type_: "text",
              text: "Multiple networks are not yet supported. Please provide only one network.",
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
