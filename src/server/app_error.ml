type t =
  | Bad_request of string
  | Unauthorized of string
  | Forbidden of string
  | Not_found of string
  | Conflict of string
  | Too_many_requests of string
  | Internal of string

let message = function
  | Bad_request value
  | Unauthorized value
  | Forbidden value
  | Not_found value
  | Conflict value
  | Too_many_requests value
  | Internal value ->
      value

let status = function
  | Bad_request _ -> 400
  | Unauthorized _ -> 401
  | Forbidden _ -> 403
  | Not_found _ -> 404
  | Conflict _ -> 409
  | Too_many_requests _ -> 429
  | Internal _ -> 500

