open Yojson.Basic.Util

type result =
  | Accepted
  | Rejected of { index : int; word : string }
  | Invalid_format of string
  | Internal_error of string

type transition = int * int * string option

external judge_nfa_explicit_raw :
  int -> int array -> int array -> transition array -> string array -> int
  = "recognita_judge_nfa_explicit"

let ( let* ) result next = Result.bind result next

let error field message = Error (Printf.sprintf "%s %s" field message)

let require_object field = function
  | `Assoc _ as json -> Ok json
  | _ -> error field "must be a JSON object"

let require_string field = function
  | `String value -> Ok value
  | _ -> error field "must be a string"

let require_list field = function
  | `List values -> Ok values
  | _ -> error field "must be a JSON array"

let require_member field name json =
  match json |> member name with
  | `Null -> error field "is required"
  | value -> Ok value

let string_list field json =
  let* values = require_list field json in
  let rec loop index acc = function
    | [] -> Ok (List.rev acc)
    | value :: rest ->
        let* parsed =
          require_string (Printf.sprintf "%s[%d]" field index) value
        in
        loop (index + 1) (parsed :: acc) rest
  in
  loop 0 [] values

let state_index_map states =
  let table = Hashtbl.create (List.length states) in
  List.iteri (fun index state -> Hashtbl.replace table state index) states;
  table

let state_index table field state =
  match Hashtbl.find_opt table state with
  | Some index -> Ok index
  | None -> error field "must reference a declared state"

let state_indices table field json =
  let* states = string_list field json in
  let rec loop index acc = function
    | [] -> Ok (Array.of_list (List.rev acc))
    | state :: rest ->
        let* parsed =
          state_index table (Printf.sprintf "%s[%d]" field index) state
        in
        loop (index + 1) (parsed :: acc) rest
  in
  loop 0 [] states

let parse_symbol field transition =
  match transition |> member "symbol" with
  | `Null -> Ok None
  | `String value -> Ok (Some value)
  | _ -> error field "must be a string or null"

let parse_transition table index json =
  let field = Printf.sprintf "model.transitions[%d]" index in
  let* transition = require_object field json in
  let* from_state =
    let* value = require_member (field ^ ".from") "from" transition in
    require_string (field ^ ".from") value
  in
  let* to_state =
    let* value = require_member (field ^ ".to") "to" transition in
    require_string (field ^ ".to") value
  in
  let* from_index = state_index table (field ^ ".from") from_state in
  let* to_index = state_index table (field ^ ".to") to_state in
  let* symbol = parse_symbol (field ^ ".symbol") transition in
  Ok (from_index, to_index, symbol)

let transitions table json =
  let* values = require_list "model.transitions" json in
  let rec loop index acc = function
    | [] -> Ok (Array.of_list (List.rev acc))
    | value :: rest ->
        let* transition = parse_transition table index value in
        loop (index + 1) (transition :: acc) rest
  in
  loop 0 [] values

let parsed_nfa submission_data =
  let* top = require_object "submission.data" submission_data in
  let* model_json = require_member "model" "model" top in
  let* model = require_object "model" model_json in
  let* states_json = require_member "model.states" "states" model in
  let* states = string_list "model.states" states_json in
  let table = state_index_map states in
  let* start_states_json =
    require_member "model.startStates" "startStates" model
  in
  let* start_states = state_indices table "model.startStates" start_states_json in
  let* accept_states_json =
    require_member "model.acceptStates" "acceptStates" model
  in
  let* accept_states = state_indices table "model.acceptStates" accept_states_json in
  let* transitions_json = require_member "model.transitions" "transitions" model in
  let* transitions = transitions table transitions_json in
  Ok (List.length states, start_states, accept_states, transitions)

let result_of_code tests code =
  if code = -1 then
    Accepted
  else if code = -2 then
    Invalid_format "NFA bridge input is invalid"
  else if code = -3 then
    Internal_error "NFA bridge failed"
  else if code >= 0 && code < Array.length tests then
    Rejected { index = code; word = tests.(code) }
  else
    Internal_error
      (Printf.sprintf "NFA bridge returned unexpected result code %d" code)

let judge_nfa_explicit_tests ~submission_data ~tests =
  match parsed_nfa submission_data with
  | Error message -> Invalid_format message
  | Ok (state_count, start_states, accept_states, transitions) ->
      let tests = Array.of_list tests in
      judge_nfa_explicit_raw state_count start_states accept_states transitions
        tests
      |> result_of_code tests
