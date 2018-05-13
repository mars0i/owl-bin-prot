
(* Other things to try: memory-mapped files? *)

(* TODO: replace ocamldoc with Owl-style annotations *)

(* TODO: Consider hiding
   the ppx_bin_prot-generated functions.  (If it's possible to
   embed some data structure here in a larger structure, maybe
   those functions need to visible??) *)

open Bin_prot.Std    (* for @@deriving bin_prot *)
open Bin_prot.Common (* for @@deriving bin_prot *)

let time f =
    let cpu_time, wall_time = Sys.time(), Unix.gettimeofday() in
    let result = f () in
    Printf.printf "cpu: %fs, wall: %fs\n%!" (Sys.time() -. cpu_time) (Unix.gettimeofday() -. wall_time);
    result

let multiply_array_elts ra = Array.fold_left ( * ) 1 ra

type flattened = {dims : int array ; data : vec} [@@deriving bin_io]

let ndarray_to_flattened x =
  let dims = Owl.Dense.Ndarray.Generic.shape x in
  let len = multiply_array_elts dims in
  let x' = Bigarray.Genarray.change_layout x Bigarray.fortran_layout in
  let data = Bigarray.reshape_1 x' len in  (* Bigarray.Array1 with float64 and fortran_layout is compatible with Bin_prot's vec *)
  {dims; data}

let serialize x =
  let flat = ndarray_to_flattened x in
  let buf = create_buf (bin_size_flattened flat) in
  ignore (bin_write_flattened buf 0 flat);(* TODO maybe store return bytes read and compare with size and throw exception *)
  buf

let save_serialized buf filename =
  let size = buf_len buf in
  let write_file fd = Core.Bigstring.write fd ~pos:0 ~len:size buf in
  ignore(Core.Unix.with_file filename ~mode:[O_WRONLY; O_CREAT; O_TRUNC] ~f:write_file) (* O_TRUNC ... What should be done if the file exists? *)

let serialize_to_file x filename =
  save_serialized (serialize x) filename


let load_serialized filename =
  let read_file fd =
    let stats = Core.Unix.fstat fd in  (* Will this work correctly on symbolic links? If not use stat on the filename. *)
    let size = Int64.to_int (stats.st_size) in
    let buf = Bin_prot.Common.create_buf size in
    ignore(Core.Bigstring.read ~pos:0 ~len:size fd buf); (* TODO maybe store return bytes read and compare with size and throw exception *)
    buf
  in Core.Unix.(with_file filename ~mode:[O_RDONLY] ~f:read_file)

let flattened_to_ndarray flat =
  let {dims; data} = flat in
  let still_flat = Bigarray.Array1.change_layout data Bigarray.c_layout in
  Bigarray.reshape (Bigarray.genarray_of_array1 still_flat) dims

let unserialize buf =
  let posref = ref 0 in
  let flat = bin_read_flattened buf posref in
  flattened_to_ndarray flat

let unserialize_from_file filename =
  unserialize (load_serialized filename)


let test_serialize ?(size=1) () =
  let xdim, ydim, zdim = 10, 20, 30*size in
  let nd = Owl.Arr.uniform [| xdim ; ydim ; zdim |] in
  Printf.printf "The test ndarray has size %dx%dx%d = %d\n%!" xdim ydim zdim (xdim * ydim * zdim);
  let filename = Core.Filename.temp_file "owl_bin_prot_test" "" in
  print_endline "serializing:";
  time (fun () -> serialize_to_file nd filename);
  print_endline "unserializing:";
  let nd' = time (fun () -> unserialize_from_file filename) in
  Core.Unix.unlink filename;
  nd = nd'


(* TODO move next example somewhere else, and use new flattened to/from
   ndarray functions to do it with matrices. *)

(** Note that it's also possible to embed the flattened type in a more
    complex type, defining [bin_prot] access functions using [@@deriving],
    and then serialize data to a file form using the new functions along
    with [save_serialized] and [load_serialized].  For example:

{[
    # #require "ppx_bin_prot";;
    # open Bin_prot.Std;;
    # #load "owl_bin_prot.cma";;
    # type flatlist = Owl_bin_prot.flattened list [@@deriving bin_io];;
    type flatlist = Owl_bin_prot.flattened list
    val bin_shape_flatlist : Bin_prot.Shape.t = <abstr>
    val bin_size_flatlist : Owl_bin_prot.flattened list -> int = <fun>
    val bin_write_flatlist : Bin_prot.Common.buf -> pos:int -> Owl_bin_prot.flattened list -> int = <fun>
    val bin_writer_flatlist : Owl_bin_prot.flattened list Bin_prot.Type_class.writer0 = {Bin_prot.Type_class.size = <fun>; write = <fun>}
    val bin_read_flatlist : Bin_prot.Common.buf -> pos_ref:Bin_prot.Common.pos_ref -> Owl_bin_prot.flattened list = <fun>
    val bin_reader_flatlist : Owl_bin_prot.flattened list Bin_prot.Type_class.reader0 = {Bin_prot.Type_class.read = <fun>; vtag_read = <fun>}
    val bin_flatlist : Owl_bin_prot.flattened list Bin_prot.Type_class.t0 =
      {Bin_prot.Type_class.shape = <abstr>; writer = {Bin_prot.Type_class.size = <fun>; write = <fun>}; reader = {Bin_prot.Type_class.read = <fun>; vtag_read = <fun>}}
    
    (* Convert some ndarrays in to 1D fortran_layout at this point.  Here we'll 
       just make sample data that's already in that form: *)
    # let v1 = Bigarray.Array1.create Bigarray.float64 Bigarray.fortran_layout 20;;
    # for i = 1 to 20 do Bigarray.Array1.set v1 i ((float i)**(0.5)) done;;
    # let v2 = Bigarray.Array1.create Bigarray.float64 Bigarray.fortran_layout 20;;
    # for i = 1 to 20 do (Bigarray.Array1.set v2 i (float i)) done;;
    
    # let flats = [{dims=[|4;5|]; data=v1}; {dims=[|4;5|]; data=v2}];;
    
    # let buf = create_buf (bin_size_flattened flats);;
    # bin_write_flatlist buf 0 flats;;
    # Owl_bin_prot.save_serialized buf "flats.bin";;
    
    # let buf' = Owl_bin_prot.load_serialized "flats.bin";;
    # let posref = ref 0;;
    # let flats' = bin_read_flatlist buf' posref;;
    # flats = flats';;
    - : bool = true
]}
*)
