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

let template =
  {|
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>__SITE_NAME__</title>
    <style>
      :root {
        --paper: #f5efe7;
        --paper-strong: #fffaf4;
        --ink: #1f2a30;
        --muted: #5e6a71;
        --line: rgba(31, 42, 48, 0.12);
        --accent: #b56c3f;
        --accent-soft: rgba(181, 108, 63, 0.14);
        --mist: #dfe8e2;
        --success: #3f7a58;
        --danger: #a64840;
        --shadow: 0 24px 60px rgba(24, 31, 36, 0.14);
      }

      * {
        box-sizing: border-box;
      }

      body {
        margin: 0;
        min-height: 100vh;
        font-family: "Avenir Next", "Segoe UI", sans-serif;
        color: var(--ink);
        background:
          radial-gradient(circle at top left, rgba(181, 108, 63, 0.15), transparent 32%),
          radial-gradient(circle at bottom right, rgba(101, 132, 118, 0.18), transparent 26%),
          linear-gradient(180deg, #f8f2eb 0%, #f3ede6 100%);
      }

      .shell {
        min-height: 100vh;
        display: flex;
        align-items: center;
        justify-content: center;
        padding: 40px 20px;
      }

      .frame {
        width: min(1120px, 100%);
        min-height: 720px;
        display: grid;
        grid-template-columns: 1.1fr 0.9fr;
        border: 1px solid var(--line);
        border-radius: 32px;
        overflow: hidden;
        background: rgba(255, 250, 244, 0.85);
        backdrop-filter: blur(16px);
        box-shadow: var(--shadow);
      }

      .hero {
        position: relative;
        padding: 54px 56px;
        display: flex;
        flex-direction: column;
        justify-content: space-between;
        background:
          linear-gradient(155deg, rgba(255, 250, 244, 0.95), rgba(236, 230, 220, 0.8)),
          linear-gradient(45deg, rgba(181, 108, 63, 0.06), rgba(67, 122, 88, 0.08));
      }

      .hero::after {
        content: "";
        position: absolute;
        inset: auto -90px -120px auto;
        width: 300px;
        height: 300px;
        border-radius: 999px;
        background: rgba(181, 108, 63, 0.08);
        filter: blur(8px);
      }

      .badge {
        display: inline-flex;
        align-items: center;
        gap: 10px;
        width: fit-content;
        padding: 10px 14px;
        border-radius: 999px;
        border: 1px solid rgba(31, 42, 48, 0.08);
        background: rgba(255, 255, 255, 0.55);
        color: var(--muted);
        font-size: 13px;
        letter-spacing: 0.08em;
        text-transform: uppercase;
      }

      .dot {
        width: 8px;
        height: 8px;
        border-radius: 999px;
        background: var(--success);
        box-shadow: 0 0 0 6px rgba(63, 122, 88, 0.12);
      }

      h1 {
        margin: 0 0 20px;
        font-family: "Iowan Old Style", "Palatino Linotype", "Book Antiqua", Georgia, serif;
        font-size: clamp(3rem, 6vw, 5.2rem);
        line-height: 0.95;
        font-weight: 600;
        letter-spacing: -0.04em;
      }

      .lead {
        max-width: 460px;
        font-size: 1.08rem;
        line-height: 1.75;
        color: var(--muted);
      }

      .hero-foot {
        display: grid;
        gap: 18px;
      }

      .metric {
        width: fit-content;
        padding: 16px 18px;
        border-radius: 20px;
        background: rgba(255, 255, 255, 0.58);
        border: 1px solid rgba(31, 42, 48, 0.08);
      }

      .metric-label {
        color: var(--muted);
        font-size: 13px;
        letter-spacing: 0.08em;
        text-transform: uppercase;
      }

      .metric-value {
        margin-top: 6px;
        font-size: 1.3rem;
        font-weight: 600;
      }

      .panel {
        padding: 34px;
        display: flex;
        align-items: stretch;
        justify-content: center;
        background: linear-gradient(180deg, rgba(249, 245, 239, 0.9), rgba(255, 255, 255, 0.96));
      }

      .card {
        width: min(460px, 100%);
        height: 100%;
        display: flex;
        flex-direction: column;
        border-radius: 28px;
        border: 1px solid rgba(31, 42, 48, 0.08);
        background: rgba(255, 255, 255, 0.86);
        box-shadow: 0 18px 40px rgba(24, 31, 36, 0.08);
        overflow: hidden;
      }

      .card-head {
        display: flex;
        gap: 10px;
        padding: 16px;
        background: rgba(245, 239, 231, 0.72);
        border-bottom: 1px solid var(--line);
      }

      .tab {
        flex: 1;
        border: 0;
        border-radius: 16px;
        padding: 13px 16px;
        font: inherit;
        font-size: 0.95rem;
        font-weight: 600;
        color: var(--muted);
        background: transparent;
        cursor: pointer;
        transition: 180ms ease;
      }

      .tab.active {
        color: var(--ink);
        background: white;
        box-shadow: 0 8px 20px rgba(24, 31, 36, 0.08);
      }

      .pane {
        display: none;
        padding: 26px 26px 30px;
      }

      .pane.active {
        display: block;
      }

      .eyebrow {
        color: var(--muted);
        font-size: 0.9rem;
        letter-spacing: 0.06em;
        text-transform: uppercase;
      }

      h2 {
        margin: 8px 0 10px;
        font-family: "Iowan Old Style", "Palatino Linotype", "Book Antiqua", Georgia, serif;
        font-size: 2rem;
        line-height: 1.05;
        font-weight: 600;
      }

      .subtle {
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
        color: var(--muted);
        font-size: 0.95rem;
      }

      input {
        width: 100%;
        border: 1px solid rgba(31, 42, 48, 0.1);
        border-radius: 16px;
        background: rgba(255, 251, 247, 0.9);
        padding: 15px 16px;
        font: inherit;
        font-size: 1rem;
        color: var(--ink);
        outline: none;
        transition: border-color 160ms ease, box-shadow 160ms ease, transform 160ms ease;
      }

      input:focus {
        border-color: rgba(181, 108, 63, 0.6);
        box-shadow: 0 0 0 4px rgba(181, 108, 63, 0.12);
        transform: translateY(-1px);
      }

      .primary,
      .ghost,
      .danger {
        border: 0;
        border-radius: 16px;
        padding: 14px 18px;
        font: inherit;
        font-weight: 600;
        cursor: pointer;
        transition: transform 160ms ease, box-shadow 160ms ease, opacity 160ms ease;
      }

      .primary {
        background: var(--ink);
        color: white;
        box-shadow: 0 14px 24px rgba(31, 42, 48, 0.18);
      }

      .ghost {
        background: transparent;
        color: var(--ink);
        border: 1px solid rgba(31, 42, 48, 0.12);
      }

      .danger {
        background: rgba(166, 72, 64, 0.09);
        color: var(--danger);
      }

      .primary:hover,
      .ghost:hover,
      .danger:hover {
        transform: translateY(-1px);
      }

      .message {
        min-height: 24px;
        margin-top: 10px;
        color: var(--muted);
        font-size: 0.95rem;
      }

      .message.error {
        color: var(--danger);
      }

      .message.success {
        color: var(--success);
      }

      .dashboard {
        display: none;
        min-height: 100vh;
        padding: 28px 20px 56px;
      }

      .dashboard.active {
        display: block;
      }

      .topbar {
        width: min(1080px, 100%);
        margin: 0 auto 24px;
        padding: 18px 22px;
        border-radius: 24px;
        border: 1px solid var(--line);
        background: rgba(255, 251, 247, 0.84);
        backdrop-filter: blur(14px);
        display: flex;
        align-items: center;
        justify-content: space-between;
        gap: 14px;
        box-shadow: 0 18px 40px rgba(24, 31, 36, 0.08);
      }

      .brand {
        font-family: "Iowan Old Style", "Palatino Linotype", "Book Antiqua", Georgia, serif;
        font-size: 1.8rem;
        letter-spacing: -0.03em;
      }

      .role-pill {
        display: inline-flex;
        align-items: center;
        gap: 8px;
        padding: 8px 12px;
        border-radius: 999px;
        background: var(--accent-soft);
        color: var(--accent);
        font-size: 0.84rem;
        font-weight: 700;
        letter-spacing: 0.06em;
        text-transform: uppercase;
      }

      .dashboard-body {
        width: min(1080px, 100%);
        margin: 0 auto;
      }

      .panel-card {
        border-radius: 28px;
        border: 1px solid var(--line);
        background: rgba(255, 251, 247, 0.88);
        box-shadow: 0 20px 44px rgba(24, 31, 36, 0.08);
        padding: 28px;
      }

      .panel-card h3 {
        margin: 0;
        font-family: "Iowan Old Style", "Palatino Linotype", "Book Antiqua", Georgia, serif;
        font-size: 2rem;
        font-weight: 600;
      }

      .panel-card p {
        color: var(--muted);
        line-height: 1.75;
      }

      .quote {
        margin-top: 28px;
        padding: 28px;
        border-radius: 24px;
        background: linear-gradient(180deg, rgba(250, 247, 242, 1), rgba(244, 237, 227, 0.82));
        border: 1px solid rgba(31, 42, 48, 0.08);
        font-family: "Iowan Old Style", "Palatino Linotype", "Book Antiqua", Georgia, serif;
        font-style: italic;
        font-size: clamp(1.6rem, 4vw, 2.5rem);
        line-height: 1.35;
        color: #3b312c;
      }

      .quote small {
        display: block;
        margin-top: 16px;
        font-size: 1rem;
        color: var(--muted);
        font-style: normal;
      }

      .users {
        display: grid;
        gap: 14px;
        margin-top: 22px;
      }

      .user-row {
        display: grid;
        grid-template-columns: 1fr auto;
        gap: 16px;
        align-items: center;
        padding: 18px 20px;
        border-radius: 22px;
        border: 1px solid rgba(31, 42, 48, 0.08);
        background: rgba(255, 255, 255, 0.78);
      }

      .user-meta {
        display: grid;
        gap: 6px;
      }

      .user-name {
        font-weight: 700;
        font-size: 1.04rem;
      }

      .user-subline {
        display: flex;
        flex-wrap: wrap;
        gap: 8px;
        color: var(--muted);
        font-size: 0.92rem;
      }

      .tag {
        width: fit-content;
        padding: 6px 10px;
        border-radius: 999px;
        background: rgba(31, 42, 48, 0.06);
      }

      .tag.admin {
        background: rgba(181, 108, 63, 0.12);
        color: var(--accent);
      }

      .tag.banned {
        background: rgba(166, 72, 64, 0.12);
        color: var(--danger);
      }

      .empty {
        color: var(--muted);
        padding: 22px 0 6px;
      }

      .loading {
        opacity: 0.65;
        pointer-events: none;
      }

      @media (max-width: 920px) {
        .frame {
          grid-template-columns: 1fr;
        }

        .hero {
          min-height: 420px;
          padding: 36px 28px;
        }

        .panel {
          padding: 20px;
        }

        .topbar {
          flex-direction: column;
          align-items: flex-start;
        }
      }

      @media (max-width: 640px) {
        .shell {
          padding: 18px;
        }

        .panel-card,
        .card {
          border-radius: 24px;
        }

        .hero {
          min-height: auto;
        }

        .user-row {
          grid-template-columns: 1fr;
        }
      }
    </style>
  </head>
  <body>
    <main id="auth-shell" class="shell">
      <section class="frame">
        <div class="hero">
          <div>
            <div class="badge"><span class="dot"></span> recognita.xyz</div>
            <div style="height: 34px"></div>
            <h1>__SITE_NAME__</h1>
            <p class="lead">Sign in or create an account.</p>
          </div>
        </div>

        <div class="panel">
          <div class="card">
            <div class="card-head">
              <button id="tab-signin" class="tab active" type="button">Sign in</button>
              <button id="tab-register" class="tab" type="button">Register</button>
            </div>

            <section id="pane-signin" class="pane active">
              <div class="eyebrow">Welcome back</div>
              <h2>Sign in to __SITE_NAME__</h2>
              <form id="signin-form">
                <label>
                  Username
                  <input id="signin-username" autocomplete="username" required />
                </label>
                <label>
                  Password
                  <input id="signin-password" type="password" autocomplete="current-password" required />
                </label>
                <button class="primary" type="submit">Sign in</button>
              </form>
              <div id="signin-message" class="message"></div>
            </section>

            <section id="pane-register" class="pane">
              <div class="eyebrow">Fresh start</div>
              <h2>Create your account</h2>
              <form id="register-form">
                <label>
                  Username
                  <input id="register-username" autocomplete="username" required />
                </label>
                <label>
                  Email
                  <input id="register-email" type="email" autocomplete="email" required />
                </label>
                <label>
                  Password
                  <input id="register-password" type="password" autocomplete="new-password" required />
                </label>
                <button class="primary" type="submit">Register</button>
              </form>
              <div id="register-message" class="message"></div>
            </section>

            <section id="pane-verify" class="pane">
              <div class="eyebrow">Email verification</div>
              <h2>Verify your email</h2>
              <p id="verify-copy" class="subtle">Confirm your email address.</p>
              <form id="verify-form">
                <button class="primary" type="submit">Verify email</button>
                <button id="verify-back" class="ghost" type="button">Back home</button>
              </form>
              <div id="verify-message" class="message"></div>
            </section>
          </div>
        </div>
      </section>
    </main>

    <section id="dashboard" class="dashboard">
      <div class="topbar">
        <div>
          <div class="brand">__SITE_NAME__</div>
          <div id="welcome-line" class="subtle" style="margin: 8px 0 0;">Signed out</div>
        </div>
        <div style="display:flex; gap:12px; align-items:center; flex-wrap:wrap;">
          <span id="role-pill" class="role-pill">Guest</span>
          <button id="logout-button" class="ghost" type="button">Sign out</button>
        </div>
      </div>

      <div class="dashboard-body">
        <article id="user-panel" class="panel-card" style="display:none;">
          <h3>"Jeszcze nie działa, ale może będzie" — Paulo Coelho</h3>
        </article>

        <article id="admin-panel" class="panel-card" style="display:none;">
          <div style="display:flex; gap:16px; justify-content:space-between; align-items:flex-start; flex-wrap:wrap;">
            <div>
              <h3>Admin control panel</h3>
              <p>
                For now this demo only wires one moderation action: fetch users and ban them directly through the backend API.
              </p>
            </div>
            <button id="refresh-users" class="ghost" type="button">Refresh users</button>
          </div>
          <div id="admin-message" class="message"></div>
          <div id="users-list" class="users"></div>
        </article>
      </div>
    </section>

    <script>
      const state = {
        accessToken: localStorage.getItem("recognita.access_token"),
        refreshToken: localStorage.getItem("recognita.refresh_token"),
        user: null,
      };

      const nodes = {
        authShell: document.getElementById("auth-shell"),
        dashboard: document.getElementById("dashboard"),
        signInTab: document.getElementById("tab-signin"),
        registerTab: document.getElementById("tab-register"),
        cardHead: document.querySelector(".card-head"),
        signInPane: document.getElementById("pane-signin"),
        registerPane: document.getElementById("pane-register"),
        verifyPane: document.getElementById("pane-verify"),
        signInForm: document.getElementById("signin-form"),
        registerForm: document.getElementById("register-form"),
        verifyForm: document.getElementById("verify-form"),
        signInMessage: document.getElementById("signin-message"),
        registerMessage: document.getElementById("register-message"),
        verifyMessage: document.getElementById("verify-message"),
        verifyCopy: document.getElementById("verify-copy"),
        verifyBack: document.getElementById("verify-back"),
        welcomeLine: document.getElementById("welcome-line"),
        rolePill: document.getElementById("role-pill"),
        logoutButton: document.getElementById("logout-button"),
        userPanel: document.getElementById("user-panel"),
        adminPanel: document.getElementById("admin-panel"),
        adminMessage: document.getElementById("admin-message"),
        usersList: document.getElementById("users-list"),
        refreshUsers: document.getElementById("refresh-users"),
      };

      function saveTokens(tokens) {
        state.accessToken = tokens.access_token;
        state.refreshToken = tokens.refresh_token;
        localStorage.setItem("recognita.access_token", tokens.access_token);
        localStorage.setItem("recognita.refresh_token", tokens.refresh_token);
      }

      function clearSession() {
        state.accessToken = null;
        state.refreshToken = null;
        state.user = null;
        localStorage.removeItem("recognita.access_token");
        localStorage.removeItem("recognita.refresh_token");
      }

      function setMessage(node, text, type = "") {
        node.textContent = text || "";
        node.className = "message" + (type ? " " + type : "");
      }

      function setTab(mode) {
        const isSignIn = mode === "signin";
        nodes.signInTab.classList.toggle("active", isSignIn);
        nodes.registerTab.classList.toggle("active", !isSignIn);
        nodes.signInPane.classList.toggle("active", isSignIn);
        nodes.registerPane.classList.toggle("active", !isSignIn);
        nodes.verifyPane.classList.remove("active");
        nodes.cardHead.style.display = "flex";
      }

      function showVerifyPane() {
        nodes.signInTab.classList.remove("active");
        nodes.registerTab.classList.remove("active");
        nodes.signInPane.classList.remove("active");
        nodes.registerPane.classList.remove("active");
        nodes.verifyPane.classList.add("active");
        nodes.cardHead.style.display = "none";
      }

      async function parseJsonSafe(response) {
        const text = await response.text();
        try {
          return text ? JSON.parse(text) : {};
        } catch (_error) {
          return { raw: text };
        }
      }

      function errorMessage(payload, fallback) {
        return payload?.error?.message || payload?.message || fallback;
      }

      async function api(path, options = {}, retry = true) {
        const headers = new Headers(options.headers || {});
        if (!headers.has("Content-Type") && options.body) {
          headers.set("Content-Type", "application/json");
        }
        if (state.accessToken) {
          headers.set("Authorization", "Bearer " + state.accessToken);
        }

        const response = await fetch(path, {
          method: options.method || "GET",
          headers,
          body: options.body,
        });

        if (response.status === 401 && retry && state.refreshToken && path !== "/proxy/auth/refresh") {
          const refreshed = await refreshSession();
          if (refreshed) {
            return api(path, options, false);
          }
        }

        return response;
      }

      async function refreshSession() {
        if (!state.refreshToken) return false;
        const response = await fetch("/proxy/auth/refresh", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ refresh_token: state.refreshToken }),
        });
        const payload = await parseJsonSafe(response);
        if (!response.ok) {
          clearSession();
          return false;
        }
        saveTokens(payload.tokens);
        return true;
      }

      function renderLoggedOut() {
        nodes.authShell.style.display = "";
        nodes.dashboard.classList.remove("active");
        nodes.userPanel.style.display = "none";
        nodes.adminPanel.style.display = "none";
        if (window.location.pathname === "/verify") {
          showVerifyPane();
        } else {
          setTab("signin");
        }
      }

      function renderLoggedIn(user) {
        state.user = user;
        nodes.authShell.style.display = "none";
        nodes.dashboard.classList.add("active");
        nodes.welcomeLine.textContent = "Signed in as " + user.username;
        nodes.rolePill.textContent = user.role === "admin" ? "Admin" : "User";
        nodes.rolePill.style.background = user.role === "admin"
          ? "rgba(181, 108, 63, 0.12)"
          : "rgba(31, 42, 48, 0.08)";
        nodes.rolePill.style.color = user.role === "admin" ? "var(--accent)" : "var(--ink)";

        if (user.role === "admin") {
          nodes.userPanel.style.display = "none";
          nodes.adminPanel.style.display = "block";
          loadUsers();
        } else {
          nodes.adminPanel.style.display = "none";
          nodes.userPanel.style.display = "block";
        }
      }

      function userRow(user) {
        const wrapper = document.createElement("div");
        wrapper.className = "user-row";

        const meta = document.createElement("div");
        meta.className = "user-meta";

        const name = document.createElement("div");
        name.className = "user-name";
        name.textContent = user.username;

        const subline = document.createElement("div");
        subline.className = "user-subline";

        const role = document.createElement("span");
        role.className = "tag" + (user.role === "admin" ? " admin" : "");
        role.textContent = user.role;
        subline.appendChild(role);

        if (user.email) {
          const email = document.createElement("span");
          email.className = "tag";
          email.textContent = user.email;
          subline.appendChild(email);
        }

        if (user.is_banned) {
          const banned = document.createElement("span");
          banned.className = "tag banned";
          banned.textContent = user.ban_reason ? "banned: " + user.ban_reason : "banned";
          subline.appendChild(banned);
        }

        meta.appendChild(name);
        meta.appendChild(subline);

        const controls = document.createElement("div");
        if (user.role !== "admin") {
          const button = document.createElement("button");
          button.className = user.is_banned ? "ghost" : "danger";
          button.type = "button";
          button.textContent = user.is_banned ? "Banned" : "Ban";
          button.disabled = user.is_banned;
          button.addEventListener("click", async () => {
            const reason = prompt("Ban reason", "moderated via demo panel") || "moderated via demo panel";
            button.disabled = true;
            try {
              const response = await api("/proxy/users/" + user.id + "/ban", {
                method: "POST",
                body: JSON.stringify({ reason }),
              });
              const payload = await parseJsonSafe(response);
              if (!response.ok) {
                setMessage(nodes.adminMessage, errorMessage(payload, "Could not ban user"), "error");
              } else {
                setMessage(nodes.adminMessage, "User banned successfully.", "success");
                await loadUsers();
              }
            } catch (_error) {
              setMessage(nodes.adminMessage, "Network error while banning user.", "error");
            } finally {
              button.disabled = false;
            }
          });
          controls.appendChild(button);
        }

        wrapper.appendChild(meta);
        wrapper.appendChild(controls);
        return wrapper;
      }

      async function loadUsers() {
        nodes.usersList.innerHTML = "";
        nodes.adminPanel.classList.add("loading");
        setMessage(nodes.adminMessage, "Loading users...");

        try {
          const response = await api("/proxy/users");
          const payload = await parseJsonSafe(response);
          if (!response.ok) {
            setMessage(nodes.adminMessage, errorMessage(payload, "Could not load users"), "error");
            return;
          }

          const users = payload.users || [];
          setMessage(nodes.adminMessage, "");

          if (!users.length) {
            const empty = document.createElement("div");
            empty.className = "empty";
            empty.textContent = "No users available yet.";
            nodes.usersList.appendChild(empty);
            return;
          }

          users.forEach((user) => nodes.usersList.appendChild(userRow(user)));
        } catch (_error) {
          setMessage(nodes.adminMessage, "Network error while loading users.", "error");
        } finally {
          nodes.adminPanel.classList.remove("loading");
        }
      }

      async function hydrateSession() {
        if (window.location.pathname === "/verify") {
          renderLoggedOut();
          const token = new URLSearchParams(window.location.search).get("token");
          if (!token) {
            setMessage(nodes.verifyMessage, "Missing verification token.", "error");
            nodes.verifyCopy.textContent = "This verification link is incomplete.";
          } else {
            setMessage(nodes.verifyMessage, "");
            nodes.verifyCopy.textContent = "Confirm your email address.";
          }
          return;
        }

        if (!state.accessToken) {
          renderLoggedOut();
          return;
        }

        try {
          const response = await api("/proxy/me");
          const payload = await parseJsonSafe(response);
          if (!response.ok) {
            clearSession();
            renderLoggedOut();
            return;
          }
          renderLoggedIn(payload.user);
        } catch (_error) {
          clearSession();
          renderLoggedOut();
        }
      }

      nodes.signInTab.addEventListener("click", () => setTab("signin"));
      nodes.registerTab.addEventListener("click", () => setTab("register"));

      nodes.signInForm.addEventListener("submit", async (event) => {
        event.preventDefault();
        setMessage(nodes.signInMessage, "Signing in...");
        const body = JSON.stringify({
          username: document.getElementById("signin-username").value.trim(),
          password: document.getElementById("signin-password").value,
        });

        try {
          const response = await fetch("/proxy/auth/login", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body,
          });
          const payload = await parseJsonSafe(response);
          if (!response.ok) {
            setMessage(nodes.signInMessage, errorMessage(payload, "Sign in failed"), "error");
            return;
          }

          saveTokens(payload.tokens);
          setMessage(nodes.signInMessage, "Signed in.", "success");
          renderLoggedIn(payload.user);
        } catch (_error) {
          setMessage(nodes.signInMessage, "Network error while signing in.", "error");
        }
      });

      nodes.registerForm.addEventListener("submit", async (event) => {
        event.preventDefault();
        setMessage(nodes.registerMessage, "Creating account...");
        const body = JSON.stringify({
          username: document.getElementById("register-username").value.trim(),
          email: document.getElementById("register-email").value.trim(),
          password: document.getElementById("register-password").value,
        });

        try {
          const response = await fetch("/proxy/auth/register", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body,
          });
          const payload = await parseJsonSafe(response);
          if (!response.ok) {
            setMessage(nodes.registerMessage, errorMessage(payload, "Registration failed"), "error");
            return;
          }

          saveTokens(payload.tokens);
          setMessage(nodes.registerMessage, "Account created. Check your email for the verification link.", "success");
          renderLoggedIn(payload.user);
        } catch (_error) {
          setMessage(nodes.registerMessage, "Network error while registering.", "error");
        }
      });

      nodes.verifyForm.addEventListener("submit", async (event) => {
        event.preventDefault();
        const token = new URLSearchParams(window.location.search).get("token");
        if (!token) {
          setMessage(nodes.verifyMessage, "Missing verification token.", "error");
          return;
        }

        setMessage(nodes.verifyMessage, "Verifying email...");

        try {
          const response = await fetch("/proxy/auth/verify-email", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ token }),
          });
          const payload = await parseJsonSafe(response);
          if (!response.ok) {
            setMessage(nodes.verifyMessage, errorMessage(payload, "Verification failed"), "error");
            return;
          }

          setMessage(nodes.verifyMessage, "Email verified.", "success");
        } catch (_error) {
          setMessage(nodes.verifyMessage, "Network error while verifying email.", "error");
        }
      });

      nodes.verifyBack.addEventListener("click", () => {
        window.location.href = "/";
      });

      nodes.logoutButton.addEventListener("click", async () => {
        try {
          if (state.accessToken) {
            await fetch("/proxy/auth/logout", {
              method: "POST",
              headers: { "Authorization": "Bearer " + state.accessToken },
            });
          }
        } finally {
          clearSession();
          renderLoggedOut();
          setMessage(nodes.signInMessage, "");
          setMessage(nodes.registerMessage, "");
        }
      });

      nodes.refreshUsers.addEventListener("click", () => {
        loadUsers();
      });

      hydrateSession();
    </script>
  </body>
</html>
|}

let render ~site_name = replace_all ~pattern:"__SITE_NAME__" ~with_:site_name template
