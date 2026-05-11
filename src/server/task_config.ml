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
        ("requiredModelType", `String "NFA");
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
    let required_model_type =
      match json |> member "requiredModelType" with
      | `Null -> Ok Domain.Nfa
      | value -> Model_json.parse_model_type "config.requiredModelType" value
    in
    match version, grader_kind, required_model_type with
    | Error message, _, _ | _, Error message, _ | _, _, Error message ->
        Error message
    | Ok parsed_version, Ok parsed_kind, Ok parsed_required_model_type ->
        Ok
          (`Assoc
             [
               ("version", `Int parsed_version);
               ("grader", `Assoc [ ("kind", `String parsed_kind) ]);
               ( "requiredModelType",
                 `String
                   (Domain.model_type_to_string parsed_required_model_type) );
             ])

  let required_model_type config =
    match config |> member "requiredModelType" with
    | `String value -> Domain.model_type_of_string value
    | _ -> None

  let submission_template config =
    match required_model_type config with
    | Some model_type -> Model_json.template_json model_type
    | None -> Model_json.template_json Domain.Nfa

  let submission_example config =
    match required_model_type config with
    | Some model_type -> Model_json.example_json model_type
    | None -> Model_json.example_json Domain.Nfa

  let validate_submission_data config json =
    let required_type =
      match required_model_type config with
      | Some model_type -> model_type
      | None -> Domain.Nfa
    in
    Model_json.validate ~required_type json
end

let config_template_json = function
  | Domain.Model_construction -> Model_construction.config_template

let submission_template_json ~task_type ~config =
  match task_type with
  | Domain.Model_construction -> Model_construction.submission_template config

let submission_example_json ~task_type ~config =
  match task_type with
  | Domain.Model_construction -> Model_construction.submission_example config

let validate_task_config ~task_type json =
  match task_type with
  | Domain.Model_construction -> Model_construction.validate_config json

let validate_submission_data ~task_type ~config json =
  match task_type with
  | Domain.Model_construction ->
      Model_construction.validate_submission_data config json
