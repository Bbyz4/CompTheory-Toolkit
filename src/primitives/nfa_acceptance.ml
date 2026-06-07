open Yojson.Basic.Util

type transition = {
  from_state : string;
  to_state : string;
  symbol : string option;
}

type t = {
  states : string list;
  input_alphabet : string list;
  transitions : transition list;
  start_states : string list;
  accept_states : string list;
}

let ( let* ) result next = Result.bind result next

let error field message = Printf.sprintf "%s %s" field message

let require_string field = function
  | `String value -> Ok value
  | _ -> Error (error field "must be a string")

let require_string_list field = function
  | `List values ->
      let rec loop index acc = function
        | [] -> Ok (List.rev acc)
        | value :: rest ->
            let* parsed =
              require_string (Printf.sprintf "%s[%d]" field index) value
            in
            loop (index + 1) (parsed :: acc) rest
      in
      loop 0 [] values
  | _ -> Error (error field "must be a JSON array")

let require_object field = function
  | `Assoc _ as json -> Ok json
  | _ -> Error (error field "must be a JSON object")

let require_member field name json =
  match json |> member name with
  | `Null -> Error (error field "is required")
  | value -> Ok value

let parse_transition index json =
  let field = Printf.sprintf "model.transitions[%d]" index in
  let* transition = require_object field json in
  let* from_state_json = require_member (field ^ ".from") "from" transition in
  let* from_state = require_string (field ^ ".from") from_state_json in
  let* to_state_json = require_member (field ^ ".to") "to" transition in
  let* to_state = require_string (field ^ ".to") to_state_json in
  let* symbol =
    match transition |> member "symbol" with
    | `Null -> Ok None
    | `String value -> Ok (Some value)
    | _ -> Error (error (field ^ ".symbol") "must be a string or null")
  in
  Ok { from_state; to_state; symbol }

let of_yojson json =
  let* normalized = Model_json.validate ~required_type:Domain.Nfa json in
  let* model_json = require_member "model" "model" normalized in
  let* model = require_object "model" model_json in
  let* states_json = require_member "model.states" "states" model in
  let* states = require_string_list "model.states" states_json in
  let* input_alphabet_json =
    require_member "model.inputAlphabet" "inputAlphabet" model
  in
  let* input_alphabet =
    require_string_list "model.inputAlphabet" input_alphabet_json
  in
  let* start_states_json =
    require_member "model.startStates" "startStates" model
  in
  let* start_states =
    require_string_list "model.startStates" start_states_json
  in
  let* accept_states_json =
    require_member "model.acceptStates" "acceptStates" model
  in
  let* accept_states =
    require_string_list "model.acceptStates" accept_states_json
  in
  let* transitions_json = require_member "model.transitions" "transitions" model in
  let* transitions =
    match transitions_json with
    | `List items ->
        let rec loop index acc = function
          | [] -> Ok (List.rev acc)
          | item :: rest ->
              let* transition = parse_transition index item in
              loop (index + 1) (transition :: acc) rest
        in
        loop 0 [] items
    | _ -> Error (error "model.transitions" "must be a JSON array")
  in
  Ok { states; input_alphabet; transitions; start_states; accept_states }

let add_unique value values =
  if List.mem value values then values else value :: values

let unique values =
  values |> List.fold_left (fun acc value -> add_unique value acc) [] |> List.rev

let epsilon_targets nfa state =
  nfa.transitions
  |> List.filter_map (fun transition ->
         if transition.from_state = state && transition.symbol = None then
           Some transition.to_state
         else
           None)

let epsilon_closure nfa states =
  let rec loop seen pending =
    match pending with
    | [] -> List.rev seen
    | state :: rest ->
        let unseen =
          epsilon_targets nfa state
          |> unique
          |> List.filter (fun target -> not (List.mem target seen))
        in
        loop (List.fold_left (fun acc value -> value :: acc) seen unseen)
          (unseen @ rest)
  in
  let initial = unique states in
  loop (List.rev initial) initial

let move nfa states symbol =
  states
  |> List.concat_map (fun state ->
         nfa.transitions
         |> List.filter_map (fun transition ->
                if
                  transition.from_state = state
                  && transition.symbol = Some symbol
                then
                  Some transition.to_state
                else
                  None))
  |> unique

let symbols_of_word word =
  let rec loop index acc =
    if index < 0 then
      acc
    else
      loop (index - 1) (String.make 1 word.[index] :: acc)
  in
  loop (String.length word - 1) []

let accepts nfa word =
  let rec consume states = function
    | [] -> List.exists (fun state -> List.mem state nfa.accept_states) states
    | symbol :: rest ->
        let states = move nfa states symbol |> epsilon_closure nfa in
        consume states rest
  in
  let initial_states = epsilon_closure nfa nfa.start_states in
  consume initial_states (symbols_of_word word)

let accepts_json json ~word =
  let* nfa = of_yojson json in
  Ok (accepts nfa word)
