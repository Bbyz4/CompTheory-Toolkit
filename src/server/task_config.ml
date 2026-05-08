open Yojson.Basic.Util

type validation_error = string

let ( let* ) result next = Result.bind result next

let error field message =
  Printf.sprintf "%s %s" field message

let require_object field = function
  | `Assoc _ as json -> Ok json
  | _ -> Error (error field "must be a JSON object")

module Model_construction = struct
  let config_template =
    `Assoc
      [
        ("version", `Int 1);
        ("grader", `Assoc [ ("kind", `String "mock") ]);
      ]

  let validate_config json =
    let* _object = require_object "config" json in
    let version =
      match json |> member "version" with
      | `Null -> Ok 1
      | `Int value when value = 1 -> Ok value
      | `Int _ -> Error (error "config.version" "must currently be equal to 1")
      | _ -> Error (error "config.version" "must be an integer")
    in
    let grader_kind =
      match json |> member "grader" |> member "kind" with
      | `Null -> Ok "mock"
      | `String "mock" -> Ok "mock"
      | `String _ ->
          Error (error "config.grader.kind" "must currently be equal to \"mock\"")
      | _ -> Error (error "config.grader.kind" "must be a string")
    in
    match version, grader_kind with
    | Error message, _ | _, Error message -> Error message
    | Ok parsed_version, Ok parsed_kind ->
        Ok
          (`Assoc
             [
               ("version", `Int parsed_version);
               ("grader", `Assoc [ ("kind", `String parsed_kind) ]);
             ])

  let validate_submission_data _config json =
    let* _object = require_object "submission.data" json in
    Ok json
end

let config_template_json = function
  | Domain.Model_construction -> Model_construction.config_template

let validate_task_config ~task_type json =
  match task_type with
  | Domain.Model_construction -> Model_construction.validate_config json

let validate_submission_data ~task_type ~config json =
  match task_type with
  | Domain.Model_construction ->
      Model_construction.validate_submission_data config json
