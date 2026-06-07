open Yojson.Basic.Util

type validation_error = string

type model_construction_grader =
  | Mock
  | Explicit_tests of string list

let ( let* ) result next = Result.bind result next

let error field message =
  Printf.sprintf "%s %s" field message

let require_object field = function
  | `Assoc _ as json -> Ok json
  | _ -> Error (error field "must be a JSON object")

let has_whitespace value =
  String.exists
    (function ' ' | '\t' | '\n' | '\r' -> true | _ -> false)
    value

let validate_word field = function
  | `String value when has_whitespace value ->
      Error (error field "must be a single word without whitespace")
  | `String value -> Ok (`String value)
  | _ -> Error (error field "must be a string")

let rec validate_word_list field index acc = function
  | [] -> Ok (`List (List.rev acc))
  | value :: rest ->
      let* normalized =
        validate_word (Printf.sprintf "%s[%d]" field index) value
      in
      validate_word_list field (index + 1) (normalized :: acc) rest

module Model_construction = struct
  let config_template =
    `Assoc
      [
        ("grader", `Assoc [ ("kind", `String "mock") ]);
        ("requiredModelType", `String "NFA");
      ]

  let validate_config json =
    let* _object = require_object "config" json in
    let grader =
      match json |> member "grader" with
      | `Null -> Ok (`Assoc [ ("kind", `String "mock") ])
      | grader_json -> (
          let* grader_object = require_object "config.grader" grader_json in
          match grader_object |> member "kind" with
          | `Null | `String "mock" ->
              Ok (`Assoc [ ("kind", `String "mock") ])
          | `String "explicit-tests" -> (
              match grader_object |> member "tests" with
              | `Null ->
                  Ok
                    (`Assoc
                      [
                        ("kind", `String "explicit-tests");
                        ("tests", `List []);
                      ])
              | `List items ->
                  let* normalized_tests =
                    validate_word_list "config.grader.tests" 0 [] items
                  in
                  Ok
                    (`Assoc
                      [
                        ("kind", `String "explicit-tests");
                        ("tests", normalized_tests);
                      ])
              | _ -> Error (error "config.grader.tests" "must be an array"))
          | `String _ ->
              Error
                (error "config.grader.kind"
                   "must be equal to \"mock\" or \"explicit-tests\"")
          | _ -> Error (error "config.grader.kind" "must be a string"))
    in
    let required_model_type =
      match json |> member "requiredModelType" with
      | `Null -> Ok Domain.Nfa
      | value -> Model_json.parse_model_type "config.requiredModelType" value
    in
    match grader, required_model_type with
    | Error message, _ | _, Error message ->
        Error message
    | Ok parsed_grader, Ok parsed_required_model_type ->
        Ok
          (`Assoc
             [
               ("grader", parsed_grader);
               ( "requiredModelType",
                 `String
                   (Domain.model_type_to_string parsed_required_model_type) );
             ])

  let required_model_type config =
    match config |> member "requiredModelType" with
    | `String value -> Domain.model_type_of_string value
    | _ -> None

  let grader config =
    match config |> member "grader" with
    | `Assoc _ as grader_json -> (
        match grader_json |> member "kind" with
        | `String "mock" -> Ok Mock
        | `String "explicit-tests" -> (
            match grader_json |> member "tests" with
            | `List tests ->
                let rec loop index acc = function
                  | [] -> Ok (Explicit_tests (List.rev acc))
                  | `String word :: rest -> loop (index + 1) (word :: acc) rest
                  | _ :: _ ->
                      Error
                        (error
                           (Printf.sprintf "config.grader.tests[%d]" index)
                           "must be a string")
                in
                loop 0 [] tests
            | `Null -> Ok (Explicit_tests [])
            | _ -> Error (error "config.grader.tests" "must be an array"))
        | `String _ ->
            Error
              (error "config.grader.kind"
                 "must be equal to \"mock\" or \"explicit-tests\"")
        | _ -> Error (error "config.grader.kind" "must be a string"))
    | _ -> Error (error "config.grader" "must be a JSON object")

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

let model_construction_grader config = Model_construction.grader config

let validate_submission_data ~task_type ~config json =
  match task_type with
  | Domain.Model_construction ->
      Model_construction.validate_submission_data config json
