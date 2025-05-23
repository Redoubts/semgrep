type module_ = string

(** lexical shapes that describe the environment **)
type shape =
  | LiteralShape
  | ArrayShape
  | ObjectShape of (int * shape Common.smap * shape list) ref
  (*
  | FunctionShape of shape
  | FunctionShape of shape * shape
*)
  | FunctionShape of shape Common.smap ref * shape
  | RequireShape of module_
  | UnknownShape of string
  (*
  | ClassShape of shape Common.smap ref * shape
*)
  | ClassShape of shape * shape
  | NewShape of shape
  | MixinShape of shape
  | ClassWithMixinShape of shape * shape
  | PropertyShape of shape * string
  | ApplyShape of shape
  | ElementShape of shape

val rootclass : shape
(** constant shape representing the empty class **)

val new_object : shape Common.smap -> shape
(** generates an object shape containing a given property map **)

val new_class : unit -> shape
(** generates a class object shape containing a new prototype object **)

val fresh_id : unit -> int
(** generates a fresh id **)

val string_of_shape : int -> shape -> string
(** Example: string_of_shape indent shape **)

type parseinfo = Ast_js.a_program * Parser_js.token list
(** parse info for JS files, containing an AST and a token list with comments **)

type parseinfo_map = parseinfo Common.smap
(** map of file names to parse info cached after parsing **)

type moduleinfo = {
  module_ : module_;
  local_requires : module_ list;
  local_bindings : shape Common.smap;
}
(** local info computed per module, containing exports and local shapes **)

type moduleinfo_map = moduleinfo Common.smap
(** map of module names to module info cached after analysis **)
