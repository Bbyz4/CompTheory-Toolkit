let bcrypt_cost = 10

let make password =
  Bcrypt.hash ~count:bcrypt_cost password |> Bcrypt.string_of_hash

let verify ~expected password =
  try
    Bcrypt.verify password (Bcrypt.hash_of_string expected)
  with _ -> false
