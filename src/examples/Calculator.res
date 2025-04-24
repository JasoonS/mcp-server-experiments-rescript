/**
 * Calculator Tool Example
 *
 * This module demonstrates how to implement a basic MCP tool that performs arithmetic
 * operations. It serves as a simple example of:
 * - Tool registration with proper error handling
 * - Input schema definition using ReScript Schema
 * - Parameter validation with descriptive errors
 * - Structured error responses
 * - Proper type safety
 */
open MCP_SDK

type operation =
  | @as("add") Add | @as("subtract") Subtract | @as("multiply") Multiply | @as("divide") Divide

type calculatorParams = {
  a: float,
  b: float,
  operation: operation,
}

type calculationError = DivisionByZero | InvalidOperation | OverUnderflow
exception CalculationError(calculationError)

// Bind JS's Number.isFinite to ReScript
@val @scope("Number")
external isFinite: float => bool = "isFinite"

/**
 * Registers the calculator tool with the MCP server.
 * This function demonstrates the basic pattern for adding a new tool:
 * 1. Define the tool's schema using ReScript Schema for runtime validation
 * 2. Register the tool with proper error handling
 * 3. Implement the tool's execution logic with safety checks
 * 4. Return structured responses for both success and error cases
 *
 * @param server - The MCP server instance to register the tool with
 * @throws Will not throw - all errors are handled and returned in the response
 */
let registerCalculatorTool = (server: McpServer.t) => {
  // Note need to use Zod, since it is integrated with the MCP sdk.
  let calculatorSchema = {
    // Create dictionary for object properties
    let props = {
      "a": Zod.z->Zod.number->Zod.finite->Zod.safe->Zod.describe("First number for calculation"),
      "b": Zod.z->Zod.number->Zod.finite->Zod.safe->Zod.describe("Second number for calculation"),
      "operation": Zod.z
      ->Zod.enum_(["add", "subtract", "multiply", "divide"])
      ->Zod.describe("The arithmetic operation to perform"),
    }

    // Create object schema
    Zod.z->Zod.object(props->Obj.magic)
  }

  // Function to handle calculation with strong typing
  let performCalculation = (params: calculatorParams) => {
    // Type safe calculation using ReScript's typed variants
    switch params.operation {
    | Add => params.a +. params.b
    | Subtract => params.a -. params.b
    | Multiply => params.a *. params.b
    | Divide =>
      if params.b == 0.0 {
        throw(CalculationError(DivisionByZero))
      } else {
        params.a /. params.b
      }
    }
  }

  // Register tool with server
  server->McpServer.tool(
    "calculate",
    "Perform basic arithmetic operations",
    // schemaShape,
    calculatorSchema->Zod.shape,
    async params => {
      // Console.log("here")
      let response = try {
        // The incoming params object may have runtime type differences,
        // so we cast it safely to our strongly typed version
        let typedParams = params->Obj.magic
        let result = performCalculation(typedParams)

        // Check for overflow/underflow
        if !isFinite(result) {
          throw(CalculationError(OverUnderflow))
        } else {
          {
            content: [
              {
                type_: "text",
                text: result->Float.toString,
              },
            ],
          }
        }
      } catch {
      | CalculationError(DivisionByZero) => {
          content: [
            {
              type_: "text",
              text: "Division by zero is not allowed",
            },
          ],
          isError: true,
        }
      | CalculationError(InvalidOperation) => {
          content: [
            {
              type_: "text",
              text: "Invalid operation",
            },
          ],
          isError: true,
        }
      | CalculationError(OverUnderflow) => {
          content: [
            {
              type_: "text",
              text: "Result is too large or small to represent",
            },
          ],
          isError: true,
        }
      | Exn.Error(jsExn) => {
          content: [
            {
              type_: "text",
              text: `Calculation error: ${jsExn
                ->Exn.message
                ->Option.getOr("Unknown error")}`,
            },
          ],
          isError: true,
        }
      }
      Console.error(response)
      response
    },
  )
}
