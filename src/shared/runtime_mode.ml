type t =
  | Local
  | Deployment

let parse value =
  match String.trim value |> String.lowercase_ascii with
  | "local" | "development" | "dev" -> Ok Local
  | "deployment" | "deploy" | "production" | "prod" -> Ok Deployment
  | _ ->
      Error
        "Invalid APP_MODE. Expected one of: local, dev, development, deployment, deploy, production, prod."

let load () =
  match Sys.getenv_opt "APP_MODE" with
  | None -> Local
  | Some value -> (
      match parse value with
      | Ok mode -> mode
      | Error message -> invalid_arg message)

let to_string = function Local -> "local" | Deployment -> "deployment"
