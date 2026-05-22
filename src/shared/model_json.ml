open Model_json_support

let template_json = function
  | Domain.Nfa -> Model_json_nfa.template_json ()
  | Domain.Cfg -> Model_json_cfg.template_json ()
  | Domain.Pda -> model_object_placeholder Domain.Pda
  | Domain.Lba -> model_object_placeholder Domain.Lba
  | Domain.Tm -> model_object_placeholder Domain.Tm

let example_json = function
  | Domain.Nfa -> Model_json_nfa.example_json ()
  | Domain.Cfg -> Model_json_cfg.example_json ()
  | Domain.Pda -> model_object_placeholder Domain.Pda
  | Domain.Lba -> model_object_placeholder Domain.Lba
  | Domain.Tm -> model_object_placeholder Domain.Tm

let parse_model_type = parse_model_type

let validate_generic_model model_type json =
  let* model =
    let* model_json = require_member "model" "model" json in
    require_object "model" model_json
  in
  Ok
    (`Assoc
      [
        ("type", `String (Domain.model_type_to_string model_type));
        ("model", model);
      ])

let validate ?required_type json =
  let* top = require_object "submission.data" json in
  let* parsed_type = require_member "submission.data.type" "type" top in
  let* parsed_type = parse_model_type "submission.data.type" parsed_type in
  let* () =
    match required_type with
    | Some expected when expected <> parsed_type ->
        Error
          (error "submission.data.type"
             (Printf.sprintf "must be equal to %s"
                (Domain.model_type_to_string expected)))
    | _ -> Ok ()
  in
  match parsed_type with
  | Domain.Nfa -> Model_json_nfa.validate top
  | Domain.Cfg -> Model_json_cfg.validate top
  | Domain.Pda -> validate_generic_model Domain.Pda top
  | Domain.Lba -> validate_generic_model Domain.Lba top
  | Domain.Tm -> validate_generic_model Domain.Tm top
