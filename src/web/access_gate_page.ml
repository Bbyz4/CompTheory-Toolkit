let replace_all ~pattern ~with_ value =
  let pattern_length = String.length pattern in
  if pattern_length = 0 then
    value
  else
    let buffer = Buffer.create (String.length value + 32) in
    let rec loop offset =
      if offset >= String.length value then
        ()
      else
        match String.index_from_opt value offset pattern.[0] with
        | None ->
            Buffer.add_substring buffer value offset (String.length value - offset)
        | Some index ->
            if
              index + pattern_length <= String.length value
              && String.sub value index pattern_length = pattern
            then (
              Buffer.add_substring buffer value offset (index - offset);
              Buffer.add_string buffer with_;
              loop (index + pattern_length))
            else (
              Buffer.add_substring buffer value offset (index - offset + 1);
              loop (index + 1))
    in
    loop 0;
    Buffer.contents buffer

let escape_html value =
  value
  |> replace_all ~pattern:"&" ~with_:"&amp;"
  |> replace_all ~pattern:"<" ~with_:"&lt;"
  |> replace_all ~pattern:">" ~with_:"&gt;"
  |> replace_all ~pattern:"\"" ~with_:"&quot;"
  |> replace_all ~pattern:"'" ~with_:"&#39;"

let template =
  {|
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>__SITE_NAME__ Access</title>
    <style>
      :root {
        --ink: #1f2a30;
        --muted: #5e6a71;
        --accent: #b56c3f;
        --paper: #f7f1e8;
        --line: rgba(31, 42, 48, 0.12);
        --error: #a64840;
        --shadow: 0 24px 60px rgba(24, 31, 36, 0.14);
      }

      * {
        box-sizing: border-box;
      }

      body {
        margin: 0;
        min-height: 100vh;
        display: grid;
        place-items: center;
        padding: 24px;
        font-family: "Avenir Next", "Segoe UI", sans-serif;
        color: var(--ink);
        background:
          radial-gradient(circle at top left, rgba(181, 108, 63, 0.15), transparent 30%),
          linear-gradient(180deg, #f8f2eb 0%, #f1e8de 100%);
      }

      .gate {
        width: min(440px, 100%);
        padding: 30px;
        border-radius: 28px;
        border: 1px solid var(--line);
        background: rgba(255, 250, 244, 0.92);
        box-shadow: var(--shadow);
      }

      .eyebrow {
        color: var(--muted);
        font-size: 0.84rem;
        letter-spacing: 0.08em;
        text-transform: uppercase;
      }

      h1 {
        margin: 10px 0 12px;
        font-family: "Iowan Old Style", "Palatino Linotype", Georgia, serif;
        font-size: clamp(2rem, 7vw, 3rem);
        line-height: 1;
      }

      p {
        margin: 0 0 22px;
        color: var(--muted);
        line-height: 1.7;
      }

      form {
        display: grid;
        gap: 14px;
      }

      label {
        display: grid;
        gap: 8px;
        color: var(--ink);
        font-weight: 600;
      }

      input {
        width: 100%;
        border: 1px solid rgba(31, 42, 48, 0.12);
        border-radius: 16px;
        padding: 15px 16px;
        background: #fffdf9;
        font: inherit;
        font-size: 1rem;
      }

      button {
        border: 0;
        border-radius: 16px;
        padding: 14px 18px;
        background: var(--ink);
        color: white;
        font: inherit;
        font-weight: 600;
        cursor: pointer;
      }

      .message {
        min-height: 22px;
        color: var(--error);
        font-size: 0.95rem;
      }
    </style>
  </head>
  <body>
    <main class="gate">
      <div class="eyebrow">Private entrance</div>
      <h1>Recognita</h1>
      <p>Access is intentionally gated.</p>
      <form method="post" action="/access">
        <input type="hidden" name="return_to" value="__RETURN_TO__" />
        <label>
          Enter the super secret recognita codeword
          <input name="code" type="password" autocomplete="off" autofocus required />
        </label>
        <button type="submit">Enter</button>
      </form>
      <div class="message">__MESSAGE__</div>
    </main>
  </body>
</html>
|}

let render ?(message = "") ~site_name ~return_to () =
  template
  |> replace_all ~pattern:"__SITE_NAME__" ~with_:(escape_html site_name)
  |> replace_all ~pattern:"__RETURN_TO__" ~with_:(escape_html return_to)
  |> replace_all ~pattern:"__MESSAGE__" ~with_:(escape_html message)
