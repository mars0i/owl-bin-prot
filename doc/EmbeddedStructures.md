Serializing embedded matrices/ndarrays
==

What if you want to serialize a complex type that contains Owl dense
matrices or ndarrays?

You can create a corresponding type in which the `flattened` type is
embedded.  This is the type that's used as an intermediate storage
format for Owl matrices/ndarrays.  It's actually instances of
`flattened` that are serialized.

The idea is that you define the type containing `flattened`s using
`[@@deriving bin_io], and that will generate special purpose
serialization functions, as long as `bin_prot` knows about the
structures you use to embed the Owl matrices or ndarrays.

Then you can serialize data to a file form using the new functions along
with [save_serialized] and [load_serialized] from `Owl_bin_prot`.

Here is an example in `utop`.  Doing it in `utop` allows you to see what
functions are created by `[@@deriving bin_io]`.  (The first `#` on each
line is `utop`'s.  See `src/jbuild` as an illustration of what you need
to use `ppx_bin_prot` with `dune/jbuilder`.)

```OCaml
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
```
