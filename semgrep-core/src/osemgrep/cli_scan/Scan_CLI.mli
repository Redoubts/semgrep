(*
   'semgrep scan' (and also 'semgrep ci') command-line parsing.
*)

(*
   The result of parsing a 'semgrep scan' command.
*)
type conf = {
  (* Main configuration options *)
  (* mix of --pattern/--lang/--replacement, --config *)
  rules_source : Rule_fetching.rules_source;
  (* can be a list of files or directories *)
  target_roots : string list;
  (* Rules/targets refinements *)
  rule_filtering_conf : Rule_filtering.conf;
  targeting_conf : Find_target.conf;
  (* Other configuration options *)
  autofix : bool;
  dryrun : bool;
  error_on_findings : bool;
  strict : bool;
  (* Performance options *)
  core_runner_conf : Core_runner.conf;
  (* Display options *)
  (* mix of --json, --emacs, --vim, etc. *)
  output_format : Output_format.t;
  (* mix of --debug, --quiet, --verbose *)
  logging_level : Logs.level option;
  force_color : bool;
  time_flag : bool;
  profile : bool;
  rewrite_rule_ids : bool;
  (* Networking options *)
  metrics : Metrics.State.t;
  version_check : bool;
  (* Ugly: should be in separate subcommands *)
  version : bool;
  show_supported_languages : bool;
  dump : Dump_subcommand.conf option;
  validate : Validate_subcommand.conf option;
  test : Test_subcommand.conf option;
}
[@@deriving show]

(* Command-line defaults. *)
val default : conf

(*
   Usage: parse_argv [| "semgrep-scan"; <args> |]

   Turn argv into a conf structure.

   This function may raise an exn in case of an error parsing argv
   but this should be caught by CLI.safe_run.
*)
val parse_argv : string array -> conf

(* exported because used by Ci_CLI.ml too *)
val cmdline_term : conf Cmdliner.Term.t
