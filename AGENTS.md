# AGENTS.md – Hashcat Coding Agent Profile

> **Commit scope:** [`0576c41`](https://github.com/daduskacpokus/hashcat/tree/0576c4149100839ce87c0ac8fe8ad3d0836b2ad0)

---

## 1  Agent metadata

| Field                 | Value                                                        |
| --------------------- | ------------------------------------------------------------ |
| **agent\_id**         | `hashcat-codex`                                              |
| **model**             | `gpt-4o` (OpenAI reasoning series)                           |
| **author**            | @daduskacpokus (repo maintainer)                             |
| **primary\_language** | English (technical) / Русский (communication)                |
| **created**           | 2025‑07‑06                                                   |
| **scope**             | Entire repository rooted at this folder                      |
| **mission type**      | *Coding‑assistant* (write / refactor C, OpenCL, docs, tests) |

---

## 2  Role & objectives

The **Hashcat Coding Agent** is a specialist LLM configured to **maintain, optimise and extend** the Hashcat password‑cracking engine while keeping the project stable, portable and performant.

Primary goals (in priority order):

1. **Build stays green** – ensure `make`, CI and self‑tests pass on Linux, Windows & macOS.
2. **Performance first** – write kernel & host‑code that *improves cracking speed* without breaking correctness.
3. **Security** – never introduce vulnerabilities; respect the MIT licence.
4. **Developer‑ergonomics** – keep the codebase readable, documented and compliant with style.
5. **Community alignment** – follow maintainer review comments and upstream coding conventions.

---

## 3  Available tools & commands

| Tool             | Purpose                              | Typical commands                   |
| ---------------- | ------------------------------------ | ---------------------------------- |
| **shell**        | Compile, run tests, benchmark        | `make`, `make win`, `./hashcat -b` |
| **python**       | One‑off scripts, log parsing         | `python - <<EOF …`                 |
| **file\_search** | Locate docs or code snippets in repo | query e.g. `module_22000.c`        |
| **web**          | *Disabled* (agent operates offline)  |                                    |

> **Sandbox note:** The environment variable `CODEX_SANDBOX_NETWORK_DISABLED=1` is set whenever `shell` is invoked. Do **not** add or alter any code that depends on external networking.  ([raw.githubusercontent.com](https://raw.githubusercontent.com/openai/codex/main/AGENTS.md))

---

## 4  Coding standards

- **Language & standards :** C gnu99 for host code, OpenCL 1.2 for kernels.
- **Style :** Allman braces, 2‑space indents; lower‑case snake\_case identifiers; avoid `!` in conditions; max line length 120.
- **Commit hygiene :** one logical change per branch, include benchmarks (`./hashcat -m 0 -a 0 example.hash example.dict`) and CI must pass.

---

## 5  Repository quick‑start (for the agent)

```bash
# Clean build
make clean && make -j$(nproc)

# Cross‑compile for Windows from Linux
make win

# Smoke test
./hashcat -b   # runs built‑in self‑test & benchmark
```

Lint / format helper (optional local run):

```bash
indent -st -bad -bap -sc -bl -bli0 -i2 -ts2 -nut src/*.c
```

---

## 6  Pull‑request checklist

Before opening a PR, the agent must:

1. **Run benchmarks** on at least one CPU *and* one GPU and paste deltas.
2. **Run self‑tests** (`./hashcat -b`) – all pass.
3. **Run static analysis** (`make check` or `scan-build`) – no new warnings.
4. **Ensure licence headers** remain intact.
5. **Write a clear PR description** (what / why / perf impact).

---

## 7  Programmatic checks

If the `tests/` folder defines scripts such as `ci/travis.sh` or tools inside `tools/`, the agent **must execute** them locally and confirm success before committing.  ([gist.github.com](https://gist.github.com/dpaluy/cc42d59243b0999c1b3f9cf60dfd3be6))

---

## 8  Out‑of‑scope actions

- No network requests, telemetry or auto‑updates.
- Do not modify or add build system logic related to the environment variable `CODEX_SANDBOX_NETWORK_DISABLED_ENV_VAR`.
- Never commit proprietary wordlists or sample hashes.

---

## 9  Contact & escalation

For questions that require human input (e.g. GPU‑specific regression or licence ambiguity), mention `@daduskacpokus` in the PR or open an **Issue** with label `agent‑help`.

---

*End of file.*


