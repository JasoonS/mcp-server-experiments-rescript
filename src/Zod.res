// Zod bindings (for schema definition)

///// NOTE: these bindings don't work, just use 'raw' for now to create zod schemas.

type schemaShape

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
@send external optional: schema<'a> => schema<option<'a>> = "optional"
@send external nullish: schema<'a> => schema<option<'a>> = "nullish"

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
