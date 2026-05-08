open Yojson.Basic.Util

let parse body =
  try Ok (Yojson.Basic.from_string body)
  with Yojson.Json_error message ->
    Error (App_error.Bad_request ("Invalid JSON body: " ^ message))

let string_field json name =
  match json |> member name with
  | `String value -> Ok value
  | _ -> Error (App_error.Bad_request ("Field \"" ^ name ^ "\" must be a string"))

let optional_string_field json name =
  match json |> member name with
  | `String value -> Ok (Some value)
  | `Null -> Ok None
  | `Assoc [] -> Ok None
  | _ ->
      Error
        (App_error.Bad_request
           ("Field \"" ^ name ^ "\" must be a string or null"))

let int_field json name =
  match json |> member name with
  | `Int value -> Ok value
  | _ -> Error (App_error.Bad_request ("Field \"" ^ name ^ "\" must be an int"))

let json_field json name =
  match json |> member name with
  | `Null ->
      Error (App_error.Bad_request ("Field \"" ^ name ^ "\" is required"))
  | value -> Ok value

let object_field json name =
  match json |> member name with
  | `Assoc _ as value -> Ok value
  | _ ->
      Error (App_error.Bad_request ("Field \"" ^ name ^ "\" must be an object"))

let assoc_list json =
  match json with
  | `Assoc _ -> Ok json
  | _ -> Error (App_error.Bad_request "JSON body must be an object")
