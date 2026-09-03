# Project Context & Rules for Qwen Code

## Existing Repository Structure
- `hosts/asus-expertbook/` — Host-specific system configuration (`configuration.nix`, `hardware.nix`, `disko-config.nix`, `custom-edid.nix`).
- `home-manager/` — User environment configuration entry point (`home.nix`).
- `home-manager/modules/` — Home Manager components:
  - `desktop.nix`, `shell.nix`, `editors.nix`, `apps.nix`, `games.nix`, `core.nix`.
  - Subdirectories: `dms/` (desktop management script/config) and `niri/` (`config.kdl`, `hm.kdl`).

## Key Refactoring Guidelines
1. **Modularity**:
   - Keep system-level modules under `hosts/asus-expertbook/` or a global `modules/` directory if shared.
   - Keep user-level modules under `home-manager/modules/`.
   - Always connect new sub-modules via `imports = [ ... ];` in parent files.

2. **Immutable Elements**:
   - Never remove or modify filesystem mounts (`fileSystems`), `swapDevices`, or `virtualisation.vmVariant` settings in `configuration.nix`.
   - Preserve existing Btrfs and Disko integration.

3. **Code Style**:
   - Standard Nix syntax with 2-space indentation.
   - Prefer modular, easily swappable files (e.g., separating compositor/shell configs from monoliths).

   # Qwen Code CLI Agent Rules

## Token Efficiency & Economy (CRITICAL)
1. **Minimize Context Overhead**: Do NOT read whole files if only a few lines are relevant. Use line ranges or targeted searches.
2. **No Auto-Chaining Tools**: NEVER execute more than 2 tool calls in a single turn without stopping to give a progress update.
3. **Concise Responses**: Be extremely brief. Avoid decorative introductions, summaries, and repeating the user's prompt. 
4. **No Unsolicited File Inspection**: Do not inspect repository files unless explicitly requested or strictly required to complete the exact command.
5. **Command Output Restraint**: Limit terminal outputs or pipe through `head -n 20` when inspecting status/diffs to prevent huge outputs from entering the prompt context.
6. **Prefer Shell One-Liners**: When doing minor cleanups (e.g., git fixes, file moves), suggest or run a clean one-liner shell command instead of multi-step Read/Write cycles.

# Project & Token Efficiency Rules

## 1. Project Tech Stack & Conventions
* **Environment**: NixOS on ASUS ExpertBook (Niri WM, Flakes, Home Manager).
* **Tooling**: Use `nh os switch` for rebuilds, `disko` for partitioning, `sops-nix` for secrets.
* **Security**: Zero plaintext passwords or unencrypted keys in Git.

## 2. Token & Context Economy (STRICT)
* **Single Tool Execution**: Execute maximum 1 tool call per turn. Stop and wait for user confirmation before chaining another action.
* **No Autonomous Loops**: Do NOT attempt auto-fix cycles (Read -> Edit -> Error -> Retry). Output a shell command or git patch for the user to run manually instead.
* **Targeted Context Only**: Do NOT read entire files when inspecting config blocks. Specify narrow line ranges or search via `grep`.
* **Output Truncation**: Always cap shell output logs using `head -n 20` or filters to keep big logs out of the prompt context.
* **Zero Fluff**: Skip conversational introductions, setups, and post-task summaries. Provide straight answers and code.
