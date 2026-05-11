open Yojson.Basic.Util

let generate_for_model_type = function
  | Domain.Nfa -> Ok (Mock_model_nfa.generate ())
  | Domain.Cfg -> Ok (Mock_model_cfg.generate ())
  | Domain.Pda | Domain.Lba | Domain.Tm ->
      Error "mock model generation is not implemented for this model type yet"

let generate_for_task ~task_type ~config =
  match task_type with
  | "MODEL_CONSTRUCTION" -> (
      match config |> member "requiredModelType" with
      | `String value -> (
          match Domain.model_type_of_string value with
          | Some model_type -> generate_for_model_type model_type
          | None -> Error "task config has an unsupported requiredModelType")
      | _ -> Error "task config is missing requiredModelType")
  | _ -> Error "mock model generation is not implemented for this task type"
