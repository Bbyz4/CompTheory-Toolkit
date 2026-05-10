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
        --paper: #f4efe7;
        --paper-strong: #fffaf3;
        --ink: #1f2a30;
        --muted: #627078;
        --line: rgba(31, 42, 48, 0.12);
        --accent: #bb6d3f;
        --accent-soft: rgba(187, 109, 63, 0.12);
        --mist: #e6ece6;
        --success: #40785a;
        --danger: #a34842;
        --shadow: 0 24px 60px rgba(24, 31, 36, 0.12);
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
          radial-gradient(circle at top left, rgba(187, 109, 63, 0.14), transparent 28%),
          radial-gradient(circle at bottom right, rgba(64, 120, 90, 0.14), transparent 24%),
          linear-gradient(180deg, #f7f2eb 0%, #f3ede6 100%);
      }

      .landing-shell {
        width: min(1180px, calc(100% - 32px));
        margin: 22px auto 42px;
      }

      .landing-frame {
        min-height: 720px;
        display: grid;
        grid-template-columns: 1.12fr 0.88fr;
        border-radius: 32px;
        overflow: hidden;
        border: 1px solid var(--line);
        background: rgba(255, 250, 244, 0.88);
        box-shadow: var(--shadow);
        backdrop-filter: blur(18px);
      }

      .landing-hero {
        padding: 54px 56px;
        display: flex;
        flex-direction: column;
        justify-content: space-between;
        background:
          linear-gradient(155deg, rgba(255, 250, 244, 0.96), rgba(236, 230, 220, 0.78)),
          linear-gradient(45deg, rgba(187, 109, 63, 0.08), rgba(64, 120, 90, 0.08));
      }

      .landing-panel {
        padding: 30px;
        display: flex;
        align-items: center;
        justify-content: center;
        background: linear-gradient(180deg, rgba(249, 245, 239, 0.9), rgba(255, 255, 255, 0.96));
      }

      .landing-card {
        width: min(460px, 100%);
        border-radius: 28px;
        border: 1px solid rgba(31, 42, 48, 0.08);
        background: rgba(255, 255, 255, 0.86);
        box-shadow: 0 18px 40px rgba(24, 31, 36, 0.08);
        padding: 24px;
      }

      .landing-badge {
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

      .landing-dot {
        width: 8px;
        height: 8px;
        border-radius: 999px;
        background: var(--success);
        box-shadow: 0 0 0 6px rgba(64, 120, 90, 0.12);
      }

      .landing-title {
        margin: 0 0 18px;
        font-family: "Iowan Old Style", "Palatino Linotype", "Book Antiqua", Georgia, serif;
        font-size: clamp(3rem, 6vw, 5rem);
        line-height: 0.95;
        letter-spacing: -0.05em;
      }

      .landing-lead {
        max-width: 480px;
        font-size: 1.05rem;
        line-height: 1.75;
        color: var(--muted);
      }

      .quote-card {
        margin-bottom: 22px;
        padding: 28px;
        border-radius: 28px;
        border: 1px solid rgba(31, 42, 48, 0.08);
        background: linear-gradient(180deg, rgba(250, 247, 242, 1), rgba(244, 237, 227, 0.82));
      }

      .quote-text {
        font-family: "Iowan Old Style", "Palatino Linotype", "Book Antiqua", Georgia, serif;
        font-style: italic;
        font-size: clamp(1.7rem, 4vw, 2.6rem);
        line-height: 1.32;
        color: #3b312c;
      }

      .quote-author {
        margin-top: 16px;
        color: var(--muted);
      }

      a,
      button,
      input,
      select {
        font: inherit;
      }

      button {
        cursor: pointer;
      }

      .page {
        width: min(1180px, calc(100% - 32px));
        margin: 22px auto 42px;
      }

      .topbar {
        display: flex;
        align-items: center;
        justify-content: space-between;
        gap: 16px;
        margin-bottom: 18px;
        padding: 18px 22px;
        border-radius: 24px;
        border: 1px solid var(--line);
        background: rgba(255, 251, 247, 0.86);
        box-shadow: 0 18px 40px rgba(24, 31, 36, 0.08);
        backdrop-filter: blur(14px);
      }

      .brand-block {
        display: grid;
        gap: 6px;
      }

      .brand {
        margin: 0;
        font-family: "Iowan Old Style", "Palatino Linotype", "Book Antiqua", Georgia, serif;
        font-size: 2rem;
        line-height: 0.95;
        letter-spacing: -0.04em;
      }

      .brand-subtitle {
        color: var(--muted);
        font-size: 0.96rem;
      }

      .topbar-actions {
        display: flex;
        align-items: center;
        justify-content: flex-end;
        gap: 10px;
        flex-wrap: wrap;
      }

      .nav-row {
        display: flex;
        gap: 10px;
        flex-wrap: wrap;
      }

      .nav-link,
      .ghost,
      .primary,
      .danger,
      .soft {
        border: 0;
        border-radius: 16px;
        padding: 12px 16px;
        transition: transform 150ms ease, box-shadow 150ms ease, opacity 150ms ease;
      }

      .nav-link,
      .ghost,
      .soft {
        background: rgba(255, 255, 255, 0.72);
        color: var(--ink);
        border: 1px solid rgba(31, 42, 48, 0.1);
      }

      .nav-link.active {
        background: var(--ink);
        color: white;
        box-shadow: 0 12px 22px rgba(31, 42, 48, 0.18);
      }

      .primary {
        background: var(--ink);
        color: white;
        box-shadow: 0 14px 28px rgba(31, 42, 48, 0.16);
      }

      .danger {
        background: rgba(163, 72, 66, 0.12);
        color: var(--danger);
      }

      .nav-link:hover,
      .ghost:hover,
      .primary:hover,
      .danger:hover,
      .soft:hover {
        transform: translateY(-1px);
      }

      .status-row {
        display: flex;
        align-items: center;
        gap: 10px;
        flex-wrap: wrap;
      }

      .role-pill {
        display: inline-flex;
        align-items: center;
        gap: 8px;
        padding: 8px 12px;
        border-radius: 999px;
        background: rgba(31, 42, 48, 0.08);
        color: var(--ink);
        font-size: 0.84rem;
        font-weight: 700;
        letter-spacing: 0.06em;
        text-transform: uppercase;
      }

      .role-pill.admin {
        background: var(--accent-soft);
        color: var(--accent);
      }

      .shell {
        border-radius: 32px;
        border: 1px solid var(--line);
        background: rgba(255, 251, 247, 0.84);
        box-shadow: var(--shadow);
        backdrop-filter: blur(18px);
        overflow: hidden;
      }

      .flash {
        display: none;
        margin: 0;
        padding: 16px 22px;
        border-bottom: 1px solid var(--line);
        background: rgba(255, 255, 255, 0.62);
        color: var(--ink);
      }

      .flash.visible {
        display: block;
      }

      .flash.error {
        color: var(--danger);
        background: rgba(163, 72, 66, 0.08);
      }

      .flash.success {
        color: var(--success);
        background: rgba(64, 120, 90, 0.08);
      }

      .view {
        display: none;
        padding: 28px;
      }

      .view.active {
        display: block;
      }

      .home-grid {
        display: grid;
        grid-template-columns: minmax(0, 1.6fr) minmax(320px, 0.9fr);
        gap: 24px;
      }

      .card {
        border-radius: 28px;
        border: 1px solid rgba(31, 42, 48, 0.08);
        background: rgba(255, 255, 255, 0.76);
        padding: 24px;
      }

      .section-eyebrow {
        color: var(--muted);
        font-size: 0.82rem;
        letter-spacing: 0.08em;
        text-transform: uppercase;
      }

      h1,
      h2,
      h3 {
        margin: 0;
        font-family: "Iowan Old Style", "Palatino Linotype", "Book Antiqua", Georgia, serif;
        line-height: 1.02;
        letter-spacing: -0.03em;
      }

      .view h1 {
        font-size: clamp(2.2rem, 5vw, 3.4rem);
      }

      .view h2 {
        font-size: clamp(1.7rem, 3.5vw, 2.4rem);
      }

      .lead,
      .subtle,
      .meta-line {
        color: var(--muted);
        line-height: 1.7;
      }

      .filters {
        display: grid;
        grid-template-columns: minmax(0, 2fr) repeat(3, minmax(0, 1fr));
        gap: 12px;
        margin: 22px 0 18px;
      }

      label.filter {
        display: grid;
        gap: 8px;
        color: var(--muted);
        font-size: 0.92rem;
      }

      input,
      select,
      textarea {
        width: 100%;
        border: 1px solid rgba(31, 42, 48, 0.12);
        border-radius: 16px;
        background: rgba(255, 253, 249, 0.92);
        padding: 14px 15px;
        color: var(--ink);
        outline: none;
      }

      input:focus,
      select:focus,
      textarea:focus {
        border-color: rgba(187, 109, 63, 0.6);
        box-shadow: 0 0 0 4px rgba(187, 109, 63, 0.12);
      }

      .task-list,
      .submission-list,
      .users-list {
        display: grid;
        gap: 14px;
      }

      .task-item,
      .submission-item,
      .user-item {
        display: grid;
        gap: 14px;
        padding: 18px 20px;
        border-radius: 22px;
        border: 1px solid rgba(31, 42, 48, 0.08);
        background: rgba(255, 255, 255, 0.8);
      }

      .task-item {
        grid-template-columns: minmax(0, 1fr) auto;
        align-items: center;
      }

      .task-title,
      .submission-title,
      .user-name {
        font-size: 1.08rem;
        font-weight: 700;
      }

      .task-summary,
      .submission-summary,
      .user-summary {
        display: flex;
        gap: 8px;
        flex-wrap: wrap;
      }

      .tag {
        display: inline-flex;
        align-items: center;
        gap: 6px;
        width: fit-content;
        padding: 6px 10px;
        border-radius: 999px;
        background: rgba(31, 42, 48, 0.06);
        color: var(--muted);
        font-size: 0.85rem;
      }

      .tag.admin {
        background: var(--accent-soft);
        color: var(--accent);
      }

      .tag.banned {
        background: rgba(163, 72, 66, 0.12);
        color: var(--danger);
      }

      .tag.pending {
        background: rgba(31, 42, 48, 0.08);
        color: var(--ink);
      }

      .tag.accepted {
        background: rgba(64, 120, 90, 0.14);
        color: var(--success);
      }

      .tag.rejected,
      .tag.invalid-format,
      .tag.internal-error {
        background: rgba(163, 72, 66, 0.12);
        color: var(--danger);
      }

      .empty {
        padding: 26px 0 8px;
        color: var(--muted);
      }

      .message {
        min-height: 22px;
        margin-top: 14px;
        color: var(--muted);
      }

      .message.error {
        color: var(--danger);
      }

      .message.success {
        color: var(--success);
      }

      .auth-tabs {
        display: flex;
        gap: 10px;
        margin: 18px 0 18px;
      }

      .auth-pane {
        display: none;
      }

      .auth-pane.active {
        display: block;
      }

      form {
        display: grid;
        gap: 14px;
      }

      .meta-grid {
        display: flex;
        gap: 10px;
        flex-wrap: wrap;
        margin: 18px 0 22px;
      }

      .description-box,
      .json-box {
        margin-top: 20px;
        padding: 22px;
        border-radius: 24px;
        border: 1px solid rgba(31, 42, 48, 0.08);
        background: linear-gradient(180deg, rgba(255, 255, 255, 0.94), rgba(246, 240, 232, 0.84));
      }

      .description-box {
        white-space: pre-wrap;
        line-height: 1.8;
      }

      .json-box {
        overflow-x: auto;
      }

      pre {
        margin: 0;
        font-family: "SFMono-Regular", "Menlo", monospace;
        font-size: 0.92rem;
        line-height: 1.65;
      }

      .view-head {
        display: flex;
        align-items: flex-start;
        justify-content: space-between;
        gap: 16px;
        flex-wrap: wrap;
        margin-bottom: 22px;
      }

      .inline-actions {
        display: flex;
        gap: 10px;
        flex-wrap: wrap;
      }

      .sidebar-stack {
        display: grid;
        gap: 18px;
      }

      .quick-links {
        display: flex;
        gap: 10px;
        flex-wrap: wrap;
        margin-top: 18px;
      }

      .loading {
        opacity: 0.6;
        pointer-events: none;
      }

      @media (max-width: 960px) {
        .home-grid {
          grid-template-columns: 1fr;
        }

        .filters {
          grid-template-columns: 1fr 1fr;
        }
      }

      @media (max-width: 720px) {
        .page {
          width: min(100%, calc(100% - 20px));
          margin: 10px auto 24px;
        }

        .topbar {
          padding: 16px;
          flex-direction: column;
          align-items: flex-start;
        }

        .view {
          padding: 18px;
        }

        .filters {
          grid-template-columns: 1fr;
        }

        .task-item {
          grid-template-columns: 1fr;
        }
      }
    </style>
  </head>
  <body>
    <main id="landing-shell" class="landing-shell">
      <section class="landing-frame">
        <div class="landing-hero">
          <div>
            <div class="landing-badge"><span class="landing-dot"></span> recognita.xyz</div>
            <div style="height:34px;"></div>
            <h1 class="landing-title">__SITE_NAME__</h1>
            <p class="landing-lead">Sign in to enter your workspace. After login, the home screen shows your quote banner, task search, and your submission queues.</p>
          </div>
          <div class="card" style="background:rgba(255,255,255,0.58);">
            <div class="section-eyebrow">What you get</div>
            <p class="subtle" style="margin-top:14px;">
              Search tasks by title, type and difficulty, open slug-based task pages, submit mock answers, and inspect your own queue. Admin users also get the global submissions view.
            </p>
          </div>
        </div>

        <div class="landing-panel">
          <div class="landing-card">
            <div class="section-eyebrow">Account</div>
            <div class="auth-tabs">
              <button id="tab-signin" class="nav-link active" type="button">Sign in</button>
              <button id="tab-register" class="nav-link" type="button">Register</button>
            </div>

            <section id="pane-signin" class="auth-pane active">
              <h3 style="margin-bottom:10px;">Welcome back</h3>
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

            <section id="pane-register" class="auth-pane">
              <h3 style="margin-bottom:10px;">Create your account</h3>
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

            <section id="pane-verify" class="auth-pane">
              <h3 style="margin-bottom:10px;">Verify your email</h3>
              <p id="verify-copy" class="subtle">Confirm your email address.</p>
              <form id="verify-form" style="max-width:320px;">
                <button class="primary" type="submit">Verify email</button>
                <button id="verify-back" class="ghost" type="button">Back home</button>
              </form>
              <div id="verify-message" class="message"></div>
            </section>
          </div>
        </div>
      </section>
    </main>

    <div id="app-shell" class="page" style="display:none;">
      <header class="topbar">
        <div class="brand-block">
          <h1 class="brand">__SITE_NAME__</h1>
          <div class="brand-subtitle">Comp theory tasks, queues, and submissions.</div>
        </div>
        <div class="topbar-actions">
          <div class="nav-row">
            <button id="nav-home" class="nav-link active" type="button">Home</button>
            <button id="nav-submissions" class="nav-link" type="button" style="display:none;">My submissions</button>
            <button id="nav-admin-submissions" class="nav-link" type="button" style="display:none;">Admin queue</button>
          </div>
          <div class="status-row">
            <span id="role-pill" class="role-pill">User</span>
            <button id="logout-button" class="ghost" type="button">Sign out</button>
          </div>
        </div>
      </header>

      <main class="shell">
        <div id="flash" class="flash"></div>

        <section id="view-home" class="view active">
          <article class="quote-card">
            <div class="quote-text">"Jeszcze nie dziala, ale moze bedzie"</div>
            <div class="quote-author">Paulo Coelho</div>
          </article>

          <article class="card">
            <div class="section-eyebrow">Explore</div>
            <div class="view-head" style="margin-top:10px;">
              <div>
                <h2>Task explorer</h2>
                <p class="lead">This is your logged-in home. Filter tasks here, open a task by slug, and submit mock answers from the detail page.</p>
              </div>
              <button id="refresh-tasks" class="ghost" type="button">Refresh tasks</button>
            </div>

            <div class="filters">
              <label class="filter">
                Search title
                <input id="filter-query" placeholder="e.g. automata, pumping lemma" />
              </label>
              <label class="filter">
                Type
                <select id="filter-type">
                  <option value="">All types</option>
                </select>
              </label>
              <label class="filter">
                Min difficulty
                <input id="filter-min-difficulty" type="number" min="0" max="10" placeholder="0" />
              </label>
              <label class="filter">
                Max difficulty
                <input id="filter-max-difficulty" type="number" min="0" max="10" placeholder="10" />
              </label>
            </div>

            <div id="tasks-meta" class="meta-line"></div>
            <div id="tasks-list" class="task-list"></div>
          </article>

          <article id="admin-users-panel" class="card" style="display:none; margin-top:22px;">
            <div class="view-head" style="margin-top:0;">
              <div>
                <div class="section-eyebrow">Moderation</div>
                <h3 style="margin-top:10px;">Users</h3>
                <p class="subtle">The lightweight moderation panel remains available on the logged-in home page.</p>
              </div>
              <button id="refresh-users" class="ghost" type="button">Refresh users</button>
            </div>
            <div id="admin-message" class="message"></div>
            <div id="users-list" class="users-list"></div>
          </article>
        </section>

        <section id="view-task" class="view">
          <div class="card">
            <div class="view-head">
              <div>
                <div class="section-eyebrow">Task</div>
                <h2 id="task-title" style="margin-top:10px;">Loading task...</h2>
                <p id="task-subtitle" class="lead"></p>
              </div>
              <div class="inline-actions">
                <button id="task-back" class="ghost" type="button">Back to home</button>
                <button id="task-submit" class="primary" type="button">Submit</button>
              </div>
            </div>
            <div id="task-meta" class="meta-grid"></div>
            <div id="task-description" class="description-box"></div>
            <div id="task-message" class="message"></div>
          </div>
        </section>

        <section id="view-submissions" class="view">
          <div class="card">
            <div class="view-head">
              <div>
                <div class="section-eyebrow">Queue</div>
                <h2 id="submissions-title" style="margin-top:10px;">Submissions</h2>
                <p id="submissions-copy" class="lead"></p>
              </div>
              <div class="inline-actions">
                <button id="submissions-mine" class="nav-link" type="button">My submissions</button>
                <button id="submissions-all" class="nav-link" type="button" style="display:none;">All submissions</button>
                <button id="refresh-submissions" class="ghost" type="button">Refresh</button>
              </div>
            </div>
            <div id="submissions-message" class="message"></div>
            <div id="submissions-list" class="submission-list"></div>
          </div>
        </section>

        <section id="view-submission-detail" class="view">
          <div class="card">
            <div class="view-head">
              <div>
                <div class="section-eyebrow">Submission</div>
                <h2 id="submission-detail-title" style="margin-top:10px;">Submission</h2>
                <p id="submission-detail-copy" class="lead"></p>
              </div>
              <button id="submission-detail-back" class="ghost" type="button">Back to queue</button>
            </div>
            <div id="submission-detail-meta" class="meta-grid"></div>
            <div class="json-box">
              <pre id="submission-detail-json">{}</pre>
            </div>
            <div id="submission-detail-message" class="message"></div>
          </div>
        </section>
      </main>
    </div>

    <script>
      const state = {
        accessToken: localStorage.getItem("recognita.access_token"),
        refreshToken: localStorage.getItem("recognita.refresh_token"),
        user: null,
        tasks: [],
        taskById: new Map(),
        taskBySlug: new Map(),
        currentTask: null,
        currentSubmission: null,
      };

      const nodes = {
        landingShell: document.getElementById("landing-shell"),
        appShell: document.getElementById("app-shell"),
        flash: document.getElementById("flash"),
        rolePill: document.getElementById("role-pill"),
        logoutButton: document.getElementById("logout-button"),
        navHome: document.getElementById("nav-home"),
        navSubmissions: document.getElementById("nav-submissions"),
        navAdminSubmissions: document.getElementById("nav-admin-submissions"),
        viewHome: document.getElementById("view-home"),
        viewTask: document.getElementById("view-task"),
        viewSubmissions: document.getElementById("view-submissions"),
        viewSubmissionDetail: document.getElementById("view-submission-detail"),
        adminUsersPanel: document.getElementById("admin-users-panel"),
        refreshUsers: document.getElementById("refresh-users"),
        adminMessage: document.getElementById("admin-message"),
        usersList: document.getElementById("users-list"),
        tabSignin: document.getElementById("tab-signin"),
        tabRegister: document.getElementById("tab-register"),
        paneSignin: document.getElementById("pane-signin"),
        paneRegister: document.getElementById("pane-register"),
        paneVerify: document.getElementById("pane-verify"),
        signinForm: document.getElementById("signin-form"),
        registerForm: document.getElementById("register-form"),
        signinMessage: document.getElementById("signin-message"),
        registerMessage: document.getElementById("register-message"),
        verifyForm: document.getElementById("verify-form"),
        verifyMessage: document.getElementById("verify-message"),
        verifyCopy: document.getElementById("verify-copy"),
        verifyBack: document.getElementById("verify-back"),
        refreshTasks: document.getElementById("refresh-tasks"),
        filterQuery: document.getElementById("filter-query"),
        filterType: document.getElementById("filter-type"),
        filterMinDifficulty: document.getElementById("filter-min-difficulty"),
        filterMaxDifficulty: document.getElementById("filter-max-difficulty"),
        tasksMeta: document.getElementById("tasks-meta"),
        tasksList: document.getElementById("tasks-list"),
        taskTitle: document.getElementById("task-title"),
        taskSubtitle: document.getElementById("task-subtitle"),
        taskMeta: document.getElementById("task-meta"),
        taskDescription: document.getElementById("task-description"),
        taskMessage: document.getElementById("task-message"),
        taskBack: document.getElementById("task-back"),
        taskSubmit: document.getElementById("task-submit"),
        submissionsTitle: document.getElementById("submissions-title"),
        submissionsCopy: document.getElementById("submissions-copy"),
        submissionsMessage: document.getElementById("submissions-message"),
        submissionsList: document.getElementById("submissions-list"),
        submissionsMine: document.getElementById("submissions-mine"),
        submissionsAll: document.getElementById("submissions-all"),
        refreshSubmissions: document.getElementById("refresh-submissions"),
        submissionDetailTitle: document.getElementById("submission-detail-title"),
        submissionDetailCopy: document.getElementById("submission-detail-copy"),
        submissionDetailMeta: document.getElementById("submission-detail-meta"),
        submissionDetailJson: document.getElementById("submission-detail-json"),
        submissionDetailMessage: document.getElementById("submission-detail-message"),
        submissionDetailBack: document.getElementById("submission-detail-back"),
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

      function setFlash(text, type = "") {
        nodes.flash.textContent = text || "";
        nodes.flash.className = "flash" + (text ? " visible" : "") + (type ? " " + type : "");
      }

      function clearFlash() {
        setFlash("");
      }

      function parseRoute() {
        const path = window.location.pathname;
        if (path === "/verify") {
          return { name: "verify" };
        }
        if (path === "/submissions") {
          return { name: "submissions", scope: "mine" };
        }
        if (path === "/admin/submissions") {
          return { name: "submissions", scope: "all" };
        }
        if (path.startsWith("/submissions/")) {
          return { name: "submission-detail", id: path.slice("/submissions/".length) };
        }
        if (path.startsWith("/tasks/")) {
          return { name: "task", slug: decodeURIComponent(path.slice("/tasks/".length)) };
        }
        return { name: "home" };
      }

      function navigate(path) {
        if (window.location.pathname === path && !window.location.search) {
          renderRoute();
          return;
        }
        history.pushState({}, "", path);
        renderRoute();
      }

      function setActiveView(viewName) {
        const allViews = [
          ["home", nodes.viewHome],
          ["task", nodes.viewTask],
          ["submissions", nodes.viewSubmissions],
          ["submission-detail", nodes.viewSubmissionDetail],
        ];
        allViews.forEach(([name, node]) => node.classList.toggle("active", name === viewName));
      }

      function updateNav() {
        const route = parseRoute();
        nodes.navHome.classList.toggle("active", route.name === "home" || route.name === "task");
        nodes.navSubmissions.classList.toggle("active", route.name === "submissions" && route.scope === "mine");
        nodes.navAdminSubmissions.classList.toggle("active", route.name === "submissions" && route.scope === "all");

        const isAdmin = state.user?.role === "admin";
        nodes.navSubmissions.style.display = state.user ? "" : "none";
        nodes.navAdminSubmissions.style.display = isAdmin ? "" : "none";
        nodes.submissionsAll.style.display = isAdmin ? "" : "none";
      }

      function updateSessionPanels() {
        const isLoggedIn = Boolean(state.user);
        const isAdmin = state.user?.role === "admin";
        const route = parseRoute();
        const landingMode = !isLoggedIn || route.name === "verify";

        nodes.landingShell.style.display = landingMode ? "" : "none";
        nodes.appShell.style.display = isLoggedIn && route.name !== "verify" ? "" : "none";
        nodes.logoutButton.style.display = isLoggedIn ? "" : "none";
        nodes.adminUsersPanel.style.display = isAdmin ? "" : "none";
        nodes.rolePill.textContent = isAdmin ? "Admin" : "User";
        nodes.rolePill.className = "role-pill" + (isAdmin ? " admin" : "");

        updateNav();
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
          updateSessionPanels();
          renderRoute();
          return false;
        }
        saveTokens(payload.tokens);
        return true;
      }

      function setAuthTab(mode) {
        const signIn = mode === "signin";
        const register = mode === "register";
        const verify = mode === "verify";
        nodes.tabSignin.style.display = verify ? "none" : "";
        nodes.tabRegister.style.display = verify ? "none" : "";
        nodes.tabSignin.classList.toggle("active", signIn);
        nodes.tabRegister.classList.toggle("active", register);
        nodes.paneSignin.classList.toggle("active", signIn);
        nodes.paneRegister.classList.toggle("active", register);
        nodes.paneVerify.classList.toggle("active", verify);
      }

      function scrollToAuth() {
        nodes.landingShell.scrollIntoView({ behavior: "smooth", block: "start" });
      }

      function resetTaskIndex(tasks) {
        state.tasks = tasks || [];
        state.taskById = new Map();
        state.taskBySlug = new Map();
        state.tasks.forEach((task) => {
          state.taskById.set(task.id, task);
          if (task.slug) state.taskBySlug.set(task.slug, task);
        });
      }

      async function loadTasks(force = false) {
        if (!force && state.tasks.length) {
          return state.tasks;
        }
        nodes.tasksList.classList.add("loading");
        try {
          const response = await fetch("/proxy/tasks");
          const payload = await parseJsonSafe(response);
          if (!response.ok) {
            throw new Error(errorMessage(payload, "Could not load tasks"));
          }
          resetTaskIndex(payload.tasks || []);
          fillTaskTypeOptions();
          renderTaskList();
          return state.tasks;
        } finally {
          nodes.tasksList.classList.remove("loading");
        }
      }

      function fillTaskTypeOptions() {
        const current = nodes.filterType.value;
        const types = Array.from(new Set(state.tasks.map((task) => task.type))).sort();
        nodes.filterType.innerHTML = "";
        const allOption = document.createElement("option");
        allOption.value = "";
        allOption.textContent = "All types";
        nodes.filterType.appendChild(allOption);
        types.forEach((type) => {
          const option = document.createElement("option");
          option.value = type;
          option.textContent = type.replaceAll("_", " ");
          nodes.filterType.appendChild(option);
        });
        if (types.includes(current) || current === "") {
          nodes.filterType.value = current;
        }
      }

      function filterTasks() {
        const query = nodes.filterQuery.value.trim().toLowerCase();
        const type = nodes.filterType.value;
        const minDifficulty = Number(nodes.filterMinDifficulty.value);
        const maxDifficulty = Number(nodes.filterMaxDifficulty.value);

        return state.tasks.filter((task) => {
          if (query && !task.title.toLowerCase().includes(query)) return false;
          if (type && task.type !== type) return false;
          if (nodes.filterMinDifficulty.value !== "" && task.difficulty < minDifficulty) return false;
          if (nodes.filterMaxDifficulty.value !== "" && task.difficulty > maxDifficulty) return false;
          return true;
        });
      }

      function verdictClass(verdict) {
        switch (verdict) {
          case "ACCEPTED":
            return "accepted";
          case "REJECTED":
            return "rejected";
          case "INVALID_FORMAT":
            return "invalid-format";
          case "INTERNAL_ERROR":
            return "internal-error";
          default:
            return "pending";
        }
      }

      function createTag(text, className = "") {
        const tag = document.createElement("span");
        tag.className = "tag" + (className ? " " + className : "");
        tag.textContent = text;
        return tag;
      }

      function renderTaskList() {
        const tasks = filterTasks();
        nodes.tasksList.innerHTML = "";
        nodes.tasksMeta.textContent =
          tasks.length + " task(s) shown out of " + state.tasks.length + ".";

        if (!tasks.length) {
          const empty = document.createElement("div");
          empty.className = "empty";
          empty.textContent = "No tasks match the current filters.";
          nodes.tasksList.appendChild(empty);
          return;
        }

        tasks.forEach((task) => {
          const item = document.createElement("div");
          item.className = "task-item";

          const left = document.createElement("div");
          const title = document.createElement("div");
          title.className = "task-title";
          title.textContent = task.title;

          const summary = document.createElement("div");
          summary.className = "task-summary";
          summary.appendChild(createTag(task.type.replaceAll("_", " ")));
          summary.appendChild(createTag("difficulty " + task.difficulty));
          if (task.short_description) {
            summary.appendChild(createTag(task.short_description));
          }

          left.appendChild(title);
          left.appendChild(summary);

          const button = document.createElement("button");
          button.className = task.slug ? "primary" : "ghost";
          button.type = "button";
          button.textContent = task.slug ? "Open task" : "Missing slug";
          button.disabled = !task.slug;
          if (task.slug) {
            button.addEventListener("click", () => navigate("/tasks/" + encodeURIComponent(task.slug)));
          }

          item.appendChild(left);
          item.appendChild(button);
          nodes.tasksList.appendChild(item);
        });
      }

      function requireUser() {
        if (state.user) return true;
        setFlash("Sign in first to access submissions.", "error");
        setAuthTab("signin");
        navigate("/");
        setTimeout(scrollToAuth, 30);
        return false;
      }

      function requireAdmin() {
        if (state.user?.role === "admin") return true;
        setFlash("Admin privileges required for the full submission queue.", "error");
        navigate(state.user ? "/submissions" : "/");
        return false;
      }

      async function fetchTaskBySlug(slug) {
        const cached = state.taskBySlug.get(slug);
        if (cached) return cached;
        const response = await fetch("/proxy/tasks/slug/" + encodeURIComponent(slug));
        const payload = await parseJsonSafe(response);
        if (!response.ok) {
          throw new Error(errorMessage(payload, "Task not found"));
        }
        const task = payload.task;
        state.taskById.set(task.id, task);
        if (task.slug) state.taskBySlug.set(task.slug, task);
        return task;
      }

      function renderTaskMeta(task) {
        nodes.taskMeta.innerHTML = "";
        nodes.taskMeta.appendChild(createTag(task.type.replaceAll("_", " ")));
        nodes.taskMeta.appendChild(createTag("difficulty " + task.difficulty));
        nodes.taskMeta.appendChild(createTag(task.visibility.toLowerCase()));
        nodes.taskMeta.appendChild(createTag(task.status.toLowerCase()));
      }

      async function renderTaskDetail(slug) {
        if (!requireUser()) return;
        setActiveView("task");
        clearFlash();
        setMessage(nodes.taskMessage, "Loading task...");
        nodes.taskTitle.textContent = "Loading task…";
        nodes.taskSubtitle.textContent = "";
        nodes.taskDescription.textContent = "";
        try {
          const task = await fetchTaskBySlug(slug);
          state.currentTask = task;
          nodes.taskTitle.textContent = task.title;
          nodes.taskSubtitle.textContent =
            (task.short_description || "Open public task page.") +
            (task.slug ? " slug: /tasks/" + task.slug : "");
          nodes.taskDescription.textContent = task.description;
          renderTaskMeta(task);
          setMessage(nodes.taskMessage, "");
        } catch (error) {
          nodes.taskTitle.textContent = "Task not found";
          nodes.taskSubtitle.textContent = "";
          nodes.taskDescription.textContent = "";
          nodes.taskMeta.innerHTML = "";
          setMessage(nodes.taskMessage, error.message || "Could not load task.", "error");
        }
      }

      async function submitCurrentTask() {
        if (!state.currentTask) return;
        if (!requireUser()) return;

        nodes.taskSubmit.disabled = true;
        setMessage(nodes.taskMessage, "Submitting mock payload...");
        try {
          const response = await api("/proxy/tasks/" + state.currentTask.id + "/submissions", {
            method: "POST",
            body: JSON.stringify({ data: {} }),
          });
          const payload = await parseJsonSafe(response);
          if (!response.ok) {
            setMessage(nodes.taskMessage, errorMessage(payload, "Submission failed"), "error");
            return;
          }
          setMessage(nodes.taskMessage, "Submission queued.", "success");
          navigate("/submissions/" + payload.submission.id);
        } catch (_error) {
          setMessage(nodes.taskMessage, "Network error while creating submission.", "error");
        } finally {
          nodes.taskSubmit.disabled = false;
        }
      }

      function taskLabelFromId(taskId) {
        const task = state.taskById.get(taskId);
        if (!task) return "Task #" + taskId;
        return task.title;
      }

      function submissionRouteScope() {
        const route = parseRoute();
        return route.name === "submissions" ? route.scope : "mine";
      }

      async function renderSubmissions(scope) {
        if (!requireUser()) return;
        if (scope === "all" && !requireAdmin()) return;

        setActiveView("submissions");
        clearFlash();
        nodes.submissionsList.innerHTML = "";
        nodes.submissionsList.classList.add("loading");
        nodes.submissionsTitle.textContent = scope === "all" ? "All submissions" : "My submissions";
        nodes.submissionsCopy.textContent =
          scope === "all"
            ? "Admin view over the entire submissions queue."
            : "Your personal queue of mock submissions.";
        setMessage(nodes.submissionsMessage, "Loading submissions...");
        nodes.submissionsMine.classList.toggle("active", scope === "mine");
        nodes.submissionsAll.classList.toggle("active", scope === "all");

        try {
          await loadTasks();
          const response = await api("/proxy/submissions?scope=" + scope);
          const payload = await parseJsonSafe(response);
          if (!response.ok) {
            setMessage(nodes.submissionsMessage, errorMessage(payload, "Could not load submissions"), "error");
            return;
          }

          const submissions = payload.submissions || [];
          setMessage(nodes.submissionsMessage, "");
          if (!submissions.length) {
            const empty = document.createElement("div");
            empty.className = "empty";
            empty.textContent = "No submissions available yet.";
            nodes.submissionsList.appendChild(empty);
            return;
          }

          submissions.forEach((submission) => {
            const item = document.createElement("div");
            item.className = "submission-item";

            const title = document.createElement("div");
            title.className = "submission-title";
            title.textContent = "Submission #" + submission.id;

            const summary = document.createElement("div");
            summary.className = "submission-summary";
            summary.appendChild(createTag(taskLabelFromId(submission.task_id)));
            summary.appendChild(createTag(submission.verdict, verdictClass(submission.verdict)));
            summary.appendChild(createTag("user #" + submission.user_id));
            summary.appendChild(createTag(submission.created_at));

            const actions = document.createElement("div");
            actions.className = "inline-actions";
            const openButton = document.createElement("button");
            openButton.className = "primary";
            openButton.type = "button";
            openButton.textContent = "Open JSON";
            openButton.addEventListener("click", () => navigate("/submissions/" + submission.id));
            actions.appendChild(openButton);

            item.appendChild(title);
            item.appendChild(summary);
            item.appendChild(actions);
            nodes.submissionsList.appendChild(item);
          });
        } catch (_error) {
          setMessage(nodes.submissionsMessage, "Network error while loading submissions.", "error");
        } finally {
          nodes.submissionsList.classList.remove("loading");
        }
      }

      async function renderSubmissionDetail(id) {
        if (!requireUser()) return;
        setActiveView("submission-detail");
        clearFlash();
        setMessage(nodes.submissionDetailMessage, "Loading submission...");
        try {
          await loadTasks();
          const response = await api("/proxy/submissions/" + encodeURIComponent(id));
          const payload = await parseJsonSafe(response);
          if (!response.ok) {
            setMessage(nodes.submissionDetailMessage, errorMessage(payload, "Could not load submission"), "error");
            nodes.submissionDetailTitle.textContent = "Submission not found";
            nodes.submissionDetailCopy.textContent = "";
            nodes.submissionDetailMeta.innerHTML = "";
            nodes.submissionDetailJson.textContent = "{}";
            return;
          }

          const submission = payload.submission;
          state.currentSubmission = submission;
          nodes.submissionDetailTitle.textContent = "Submission #" + submission.id;
          nodes.submissionDetailCopy.textContent = taskLabelFromId(submission.task_id);
          nodes.submissionDetailMeta.innerHTML = "";
          nodes.submissionDetailMeta.appendChild(createTag(submission.verdict, verdictClass(submission.verdict)));
          nodes.submissionDetailMeta.appendChild(createTag("task #" + submission.task_id));
          nodes.submissionDetailMeta.appendChild(createTag("user #" + submission.user_id));
          nodes.submissionDetailMeta.appendChild(createTag(submission.created_at));
          if (submission.judged_at) {
            nodes.submissionDetailMeta.appendChild(createTag("judged " + submission.judged_at));
          }
          nodes.submissionDetailJson.textContent = JSON.stringify(submission.data, null, 2);
          setMessage(nodes.submissionDetailMessage, "");
        } catch (_error) {
          setMessage(nodes.submissionDetailMessage, "Network error while loading submission.", "error");
        }
      }

      function userRow(user) {
        const wrapper = document.createElement("div");
        wrapper.className = "user-item";

        const name = document.createElement("div");
        name.className = "user-name";
        name.textContent = user.username;

        const summary = document.createElement("div");
        summary.className = "user-summary";
        summary.appendChild(createTag(user.role, user.role === "admin" ? "admin" : ""));
        summary.appendChild(createTag(user.email));
        if (user.is_banned) {
          summary.appendChild(createTag(user.ban_reason ? "banned: " + user.ban_reason : "banned", "banned"));
        }

        const actions = document.createElement("div");
        actions.className = "inline-actions";
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
          actions.appendChild(button);
        }

        wrapper.appendChild(name);
        wrapper.appendChild(summary);
        wrapper.appendChild(actions);
        return wrapper;
      }

      async function loadUsers() {
        if (state.user?.role !== "admin") return;
        nodes.usersList.innerHTML = "";
        nodes.usersList.classList.add("loading");
        setMessage(nodes.adminMessage, "Loading users...");
        try {
          const response = await api("/proxy/users");
          const payload = await parseJsonSafe(response);
          if (!response.ok) {
            setMessage(nodes.adminMessage, errorMessage(payload, "Could not load users"), "error");
            return;
          }
          setMessage(nodes.adminMessage, "");
          const users = payload.users || [];
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
          nodes.usersList.classList.remove("loading");
        }
      }

      async function renderVerify() {
        setAuthTab("verify");
        clearFlash();
        const token = new URLSearchParams(window.location.search).get("token");
        if (!token) {
          nodes.verifyCopy.textContent = "This verification link is incomplete.";
          setMessage(nodes.verifyMessage, "Missing verification token.", "error");
        } else {
          nodes.verifyCopy.textContent = "Confirm your email address.";
          setMessage(nodes.verifyMessage, "");
        }
      }

      async function renderRoute() {
        const route = parseRoute();

        if (route.name === "verify") {
          updateSessionPanels();
          await renderVerify();
          return;
        }

        if (!state.user) {
          if (route.name !== "home") {
            history.replaceState({}, "", "/");
            setFlash("Sign in first to access the user workspace.", "error");
          }
          setAuthTab("signin");
          updateSessionPanels();
          return;
        }

        updateSessionPanels();

        if (route.name === "task") {
          await renderTaskDetail(route.slug);
          updateNav();
          return;
        }

        if (route.name === "submissions") {
          await renderSubmissions(route.scope);
          updateNav();
          return;
        }

        if (route.name === "submission-detail") {
          await renderSubmissionDetail(route.id);
          updateNav();
          return;
        }

        setActiveView("home");
        clearFlash();
        try {
          await loadTasks();
          renderTaskList();
        } catch (error) {
          setFlash(error.message || "Could not load tasks.", "error");
        }
        if (state.user?.role === "admin") {
          loadUsers();
        }
        updateNav();
      }

      async function hydrateSession() {
        if (!state.accessToken) {
          updateSessionPanels();
          renderRoute();
          return;
        }

        try {
          const response = await api("/proxy/me");
          const payload = await parseJsonSafe(response);
          if (!response.ok) {
            clearSession();
          } else {
            state.user = payload.user;
          }
        } catch (_error) {
          clearSession();
        }

        updateSessionPanels();
        if (state.user?.role === "admin") {
          loadUsers();
        }
        renderRoute();
      }

      nodes.tabSignin.addEventListener("click", () => setAuthTab("signin"));
      nodes.tabRegister.addEventListener("click", () => setAuthTab("register"));

      nodes.filterQuery.addEventListener("input", renderTaskList);
      nodes.filterType.addEventListener("change", renderTaskList);
      nodes.filterMinDifficulty.addEventListener("input", renderTaskList);
      nodes.filterMaxDifficulty.addEventListener("input", renderTaskList);
      nodes.refreshTasks.addEventListener("click", async () => {
        clearFlash();
        try {
          await loadTasks(true);
          renderTaskList();
        } catch (error) {
          setFlash(error.message || "Could not refresh tasks.", "error");
        }
      });

      nodes.navHome.addEventListener("click", () => navigate("/"));
      nodes.navSubmissions.addEventListener("click", () => navigate("/submissions"));
      nodes.navAdminSubmissions.addEventListener("click", () => navigate("/admin/submissions"));
      nodes.taskBack.addEventListener("click", () => navigate("/"));
      nodes.taskSubmit.addEventListener("click", () => submitCurrentTask());
      nodes.submissionsMine.addEventListener("click", () => navigate("/submissions"));
      nodes.submissionsAll.addEventListener("click", () => navigate("/admin/submissions"));
      nodes.refreshSubmissions.addEventListener("click", () => renderRoute());
      nodes.submissionDetailBack.addEventListener("click", () => {
        if (state.user?.role === "admin") {
          navigate("/admin/submissions");
        } else {
          navigate("/submissions");
        }
      });
      nodes.refreshUsers.addEventListener("click", () => loadUsers());
      nodes.verifyBack.addEventListener("click", () => navigate("/"));

      nodes.signinForm.addEventListener("submit", async (event) => {
        event.preventDefault();
        setMessage(nodes.signinMessage, "Signing in...");
        try {
          const response = await fetch("/proxy/auth/login", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
              username: document.getElementById("signin-username").value.trim(),
              password: document.getElementById("signin-password").value,
            }),
          });
          const payload = await parseJsonSafe(response);
          if (!response.ok) {
            setMessage(nodes.signinMessage, errorMessage(payload, "Sign in failed"), "error");
            return;
          }
          saveTokens(payload.tokens);
          state.user = payload.user;
          setMessage(nodes.signinMessage, "Signed in.", "success");
          updateSessionPanels();
          if (state.user.role === "admin") {
            loadUsers();
          }
          clearFlash();
          navigate("/");
        } catch (_error) {
          setMessage(nodes.signinMessage, "Network error while signing in.", "error");
        }
      });

      nodes.registerForm.addEventListener("submit", async (event) => {
        event.preventDefault();
        setMessage(nodes.registerMessage, "Creating account...");
        try {
          const response = await fetch("/proxy/auth/register", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
              username: document.getElementById("register-username").value.trim(),
              email: document.getElementById("register-email").value.trim(),
              password: document.getElementById("register-password").value,
            }),
          });
          const payload = await parseJsonSafe(response);
          if (!response.ok) {
            setMessage(nodes.registerMessage, errorMessage(payload, "Registration failed"), "error");
            return;
          }
          saveTokens(payload.tokens);
          state.user = payload.user;
          setMessage(nodes.registerMessage, "Account created. Check your email for the verification link.", "success");
          updateSessionPanels();
          clearFlash();
          navigate("/");
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
          updateSessionPanels();
          setMessage(nodes.signinMessage, "");
          setMessage(nodes.registerMessage, "");
          navigate("/");
        }
      });

      window.addEventListener("popstate", renderRoute);

      hydrateSession();
    </script>
  </body>
</html>
|}

let render ~site_name = replace_all ~pattern:"__SITE_NAME__" ~with_:site_name template
