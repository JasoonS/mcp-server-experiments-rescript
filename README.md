# HyperIndex MCP Server in ReScript

This is a Model Context Protocol (MCP) server implementation written in ReScript. It demonstrates best practices for:
- Server initialization and configuration
- Tool registration and management
- Error handling and logging
- Resource cleanup

## Prerequisites

- Node.js 18+
- pnpm, npm, or yarn

## Getting Started

1. Install dependencies:
   ```bash
   pnpm install
   # or
   npm install
   # or
   yarn install
   ```

2. Build the ReScript files:
   ```bash
   pnpm res:build
   # or
   npm run res:build
   # or
   yarn res:build
   ```

3. Start the server:
   ```bash
   pnpm start
   # or
   npm start
   # or
   yarn start
   ```

## Development

For development with automatic rebuilding and the MCP inspector:

```bash
pnpm dev
# or
npm run dev
# or
yarn dev
```

## Project Structure

- `src/MCP_SDK.res` - ReScript bindings for @modelcontextprotocol/sdk
- `src/Index.res` - Main server entry point
- `src/examples/` - Example tool implementations
  - `Calculator.res` - Simple calculator tool
  - `RestApi.res` - REST API interaction example

## Adding New Tools

To add a new tool, follow the pattern in the example files:

1. Define a schema using rescript schema
2. Implement the tool handler function
3. Register the tool with the server in `Index.res`
