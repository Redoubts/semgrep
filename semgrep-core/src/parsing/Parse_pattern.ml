(* Yoann Padioleau
 *
 * Copyright (C) 2019-2022 r2c
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public License
 * version 2.1 as published by the Free Software Foundation, with the
 * special exception on linking described in file LICENSE.
 *
 * This library is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the file
 * LICENSE for more details.
 *)
open Common
module G = AST_generic

let logger = Logging.get_logger [ __MODULE__ ]

(*****************************************************************************)
(* Prelude *)
(*****************************************************************************)
(* Mostly a wrapper around pfff Parse_generic.
*)

(*****************************************************************************)
(* Helpers *)
(*****************************************************************************)

let dump_and_print_errors dumper (res : 'a Tree_sitter_run.Parsing_result.t) =
  (match res.program with
  | Some cst -> dumper cst
  | None -> failwith "unknown error from tree-sitter parser");
  res.errors
  |> List.iter (fun err ->
         pr2 (Tree_sitter_run.Tree_sitter_error.to_string ~color:true err))

let extract_pattern_from_tree_sitter_result
    (res : 'a Tree_sitter_run.Parsing_result.t) (print_errors : bool) =
  match (res.Tree_sitter_run.Parsing_result.program, res.errors) with
  | None, _ -> failwith "no pattern found"
  | Some x, [] -> x
  | Some _, _ :: _ ->
      if print_errors then
        res.errors
        |> List.iter (fun err ->
               pr2 (Tree_sitter_run.Tree_sitter_error.to_string ~color:true err));
      failwith "error parsing the pattern"

type 'ast parser =
  | Pfff of (string -> 'ast)
  | TreeSitter of (string -> 'ast Tree_sitter_run.Parsing_result.t)

let run_parser ~print_errors p str =
  let parse () =
    match p with
    | Pfff f ->
        logger#trace "trying to parse with Pfff parser the pattern";
        f str
    | TreeSitter f ->
        logger#trace "trying to parse with Tree-sitter parser the pattern";
        let res = f str in
        extract_pattern_from_tree_sitter_result res print_errors
  in
  try Ok (parse ()) with
  | Timeout _ as e -> Exception.catch_and_reraise e
  | exn -> Error (Exception.catch exn)

(* This is a simplified version of run_either in Parse_target.ml. We don't need
 * most of the logic there when we're parsing patterns, so it doesn't make sense
 * to reuse it. *)
let run_either ~print_errors parsers program =
  let rec f parsers =
    match parsers with
    | [] ->
        Error
          (Exception.trace
             (Failure "internal error: No pattern parser available"))
    | p :: xs -> (
        match run_parser ~print_errors p program with
        | Ok res -> Ok res
        | Error e -> (
            match f xs with
            | Ok res -> Ok res
            | Error _ ->
                (* Return the error from the first parser. *)
                Error e))
  in
  match f parsers with
  | Ok res -> res
  | Error e -> Exception.reraise e

(* We used to do this normalization in each
 * Parse_xxx_tree_sitter.parse_pattern or xxx_to_generic.any but it's
 * better to factorize it here.
 *)
let rec normalize_any (lang : Lang.t) (any : G.any) : G.any =
  match any with
  | G.Pr xs -> normalize_any lang (G.Ss xs)
  | G.Ss [ x ] -> normalize_any lang (G.S x)
  | G.S { G.s = G.ExprStmt (e, sc); _ }
    when Parse_info.is_fake sc || Parse_info.str_of_info sc = "" ->
      normalize_any lang (G.E e)
  (* TODO: generalizing to other languages generate many regressions *)
  | G.E { e = G.N name; _ } when lang = Lang.Rust ->
      normalize_any lang (G.Name name)
  (* TODO: taken from ml_to_generic.ml:
   * | G.E {e = G.StmtExpr s; _} -> G.S s?
   *)
  (* TODO? depending on the shape of Ss xs, we should sometimes return
   * a Flds instead of Ss? For example in terraform,
   * With a = "foo" ... b = "bar", we should return a Flds, but
   * with variable "foo" { } ... variable "bar" { } we should
   * probably return an Ss?
   * Or maybe we should require the user to use curly braces
   * to disambiguate with '{ a = "foo" ... b = "bar" }'?
   * Or maybe we should get rid of F and have field = stmt in AST_generic.
   *)
  | _else_ -> any

(*****************************************************************************)
(* Entry point *)
(*****************************************************************************)
let parse_pattern lang ?(print_errors = false) str =
  let any =
    match lang with
    (* directly to generic AST any using tree-sitter only *)
    | Lang.Apex ->
        let res = Parsing_plugin.Apex.parse_pattern str in
        extract_pattern_from_tree_sitter_result res print_errors
    | Lang.Csharp ->
        let res = Parse_csharp_tree_sitter.parse_pattern str in
        extract_pattern_from_tree_sitter_result res print_errors
    | Lang.Lua ->
        let res = Parse_lua_tree_sitter.parse_pattern str in
        extract_pattern_from_tree_sitter_result res print_errors
    | Lang.Bash ->
        let res = Parse_bash_tree_sitter.parse_pattern str in
        extract_pattern_from_tree_sitter_result res print_errors
    | Lang.Dockerfile ->
        let res = Parse_dockerfile_tree_sitter.parse_pattern str in
        extract_pattern_from_tree_sitter_result res print_errors
    | Lang.Rust ->
        let res = Parse_rust_tree_sitter.parse_pattern str in
        extract_pattern_from_tree_sitter_result res print_errors
    | Lang.Kotlin ->
        let res = Parse_kotlin_tree_sitter.parse_pattern str in
        extract_pattern_from_tree_sitter_result res print_errors
    | Lang.Elixir ->
        let res = Parse_elixir_tree_sitter.parse_pattern str in
        extract_pattern_from_tree_sitter_result res print_errors
    | Lang.Julia ->
        let res = Parse_julia_tree_sitter.parse_pattern str in
        extract_pattern_from_tree_sitter_result res print_errors
    | Lang.Solidity ->
        let res = Parse_solidity_tree_sitter.parse_pattern str in
        extract_pattern_from_tree_sitter_result res print_errors
    | Lang.Swift ->
        let res = Parse_swift_tree_sitter.parse_pattern str in
        extract_pattern_from_tree_sitter_result res print_errors
    | Lang.Html ->
        let res = Parse_html_tree_sitter.parse_pattern str in
        extract_pattern_from_tree_sitter_result res print_errors
    | Lang.Hcl ->
        let res = Parse_hcl_tree_sitter.parse_pattern str in
        extract_pattern_from_tree_sitter_result res print_errors
    (* use pfff *)
    | Lang.Python
    | Lang.Python2
    | Lang.Python3 ->
        let parsing_mode = Parse_target.lang_to_python_parsing_mode lang in
        let any = Parse_python.any_of_string ~parsing_mode str in
        Python_to_generic.any any
    (* abusing JS parser so no need extend tree-sitter grammar*)
    | Lang.Ts
    | Lang.Js
    | Lang.Vue ->
        let js_ast =
          str
          |> run_either ~print_errors
               [
                 Pfff Parse_js.any_of_string;
                 TreeSitter Parse_typescript_tree_sitter.parse_pattern;
               ]
        in
        Js_to_generic.any js_ast
    | Lang.Json ->
        let any = Parse_json.any_of_string str in
        Json_to_generic.any any
    | Lang.Jsonnet -> failwith "Jsonnet is not supported yet"
    | Lang.Clojure -> failwith "clojure is not supported yet"
    | Lang.Lisp -> failwith "Lisp is not supported yet"
    | Lang.Scheme -> failwith "Scheme is not supported yet"
    | Lang.C ->
        let any = Parse_c.any_of_string str in
        C_to_generic.any any
    | Lang.Cpp ->
        let any =
          str
          |> run_either ~print_errors
               [
                 Pfff
                   (fun x ->
                     Parse_cpp.any_of_string Flag_parsing_cpp.Cplusplus x);
                 TreeSitter Parse_cpp_tree_sitter.parse_pattern;
               ]
        in
        Cpp_to_generic.any any
    | Lang.Java ->
        let any =
          str
          |> run_either ~print_errors
               [
                 Pfff Parse_java.any_of_string;
                 TreeSitter Parse_java_tree_sitter.parse_pattern;
               ]
        in
        Java_to_generic.any any
    | Lang.Go ->
        let any = Parse_go.any_of_string str in
        Go_to_generic.any any
    | Lang.Ocaml ->
        let any = Parse_ml.any_of_string str in
        Ml_to_generic.any any
    | Lang.Scala ->
        let any = Parse_scala.any_of_string str in
        Scala_to_generic.any any
    | Lang.Ruby ->
        let any = Parse_ruby.any_of_string str in
        Ruby_to_generic.any any
    | Lang.Php ->
        let any_cst = Parse_php.any_of_string str in
        let any = Ast_php_build.any any_cst in
        Php_to_generic.any any
    | Lang.Hack ->
        let res = Parse_hack_tree_sitter.parse_pattern str in
        extract_pattern_from_tree_sitter_result res print_errors
    (* use adhoc parser (neither pfff nor tree-sitter) *)
    | Lang.Yaml -> Yaml_to_generic.any str
    | Lang.R ->
        let res = Parse_r_tree_sitter.parse_pattern str in
        extract_pattern_from_tree_sitter_result res print_errors
        (* not yet handled ?? *)
        (* Lang.Xxx failwith "No Xxx generic parser yet" *)
    | Lang.Dart -> failwith "Dart patterns not supported yet"
  in
  let any = normalize_any lang any in

  Caching.prepare_pattern any;
  Check_pattern.check lang any;
  any

let dump_tree_sitter_pattern_cst lang file =
  match lang with
  | Lang.Csharp ->
      Tree_sitter_c_sharp.Parse.file file
      |> dump_and_print_errors Tree_sitter_c_sharp.CST.dump_tree
  | Lang.Lua ->
      Tree_sitter_lua.Parse.file file
      |> dump_and_print_errors Tree_sitter_lua.CST.dump_tree
  | Lang.Rust ->
      Tree_sitter_rust.Parse.file file
      |> dump_and_print_errors Tree_sitter_rust.CST.dump_tree
  | Lang.Kotlin ->
      Tree_sitter_kotlin.Parse.file file
      |> dump_and_print_errors Tree_sitter_kotlin.CST.dump_tree
  | __else__ -> ()
