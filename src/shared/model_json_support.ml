open Yojson.Basic.Util

type validation_error = string

let ( let* ) result next = Result.bind result next

let error field message = Printf.sprintf "%s %s" field message

let require_object field = function
  | `Assoc _ as json -> Ok json
  | _ -> Error (error field "must be a JSON object")

let require_nonempty_string field = function
  | `String value ->
      let trimmed = String.trim value in
      if trimmed = "" then
        Error (error field "must not be empty")
      else
        Ok trimmed
  | _ -> Error (error field "must be a string")

let require_string_list field json =
  match json with
  | `List values ->
      let rec loop index seen acc = function
        | [] -> Ok (List.rev acc)
        | value :: rest ->
            let* parsed =
              require_nonempty_string
                (Printf.sprintf "%s[%d]" field index)
                value
            in
            if List.mem parsed seen then
              Error
                (error
                   (Printf.sprintf "%s[%d]" field index)
                   "must not contain duplicates")
            else
              loop (index + 1) (parsed :: seen) (parsed :: acc) rest
      in
      loop 0 [] [] values
  | _ -> Error (error field "must be a JSON array")

let model_object_placeholder model_type =
  `Assoc
    [
      ("type", `String (Domain.model_type_to_string model_type));
      ("model", `Assoc []);
    ]

let parse_model_type field json =
  match json with
  | `String value -> (
      match Domain.model_type_of_string value with
      | Some model_type -> Ok model_type
      | None ->
          Error
            (error field "must be one of: NFA, CFG, PDA, LBA, TM"))
  | _ -> Error (error field "must be a string")

let require_member field name json =
  match json |> member name with
  | `Null -> Error (error field "is required")
  | value -> Ok value

let validate_subset ~field ~superset values =
  let rec loop index = function
    | [] -> Ok values
    | value :: rest ->
        if List.mem value superset then
          loop (index + 1) rest
        else
          Error
            (error
               (Printf.sprintf "%s[%d]" field index)
               "must reference a declared symbol")
  in
  loop 0 values
