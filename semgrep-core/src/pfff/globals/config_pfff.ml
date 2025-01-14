let version = "0.42"

(* This assumes the PWD of the Test.exe program is pfff/tests *)
let tests_path f = f

(* deprecated *)
let path_pfff_home =
  try Sys.getenv "PFFF_HOME" with
  | Not_found -> "/usr/local/share/pfff"

let regression_data_dir = Filename.concat path_pfff_home "tmp"
let std_xxx = ref (Filename.concat path_pfff_home "xxx.yyy")

let logger =
  try Some (Sys.getenv "PFFF_LOGGER") with
  | Not_found -> None
