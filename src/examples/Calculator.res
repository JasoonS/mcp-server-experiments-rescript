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

type operation = Add | Subtract | Multiply | Divide

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
  // Define schema using ReScript Schema
  let calculatorSchema = {
    // Create object schema for the whole calculator parameters
    S.object(s => {
      a: s.field(
        "a",
        S.float->S.refine(schema =>
          value => {
            if !isFinite(value) {
              schema.fail("First number must be finite")
            }
          }
        ),
      ),
      b: s.field(
        "b",
        S.float->S.refine(schema =>
          value => {
            if !isFinite(value) {
              schema.fail("Second number must be finite")
            }
          }
        ),
      ),
      operation: s.field(
        "operation",
        S.union([S.literal(Add), S.literal(Subtract), S.literal(Multiply), S.literal(Divide)]),
      ),
    })
  }

  // Convert schema to shape for MCP
  let schemaShape = {
    let jsonSchema = S.toJSONSchema(calculatorSchema)
    schemaToShape(jsonSchema)
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
    schemaShape,
    async params => {
      try {
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
    },
  )
}
