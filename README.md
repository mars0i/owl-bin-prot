owl-bin-prot
====

Functions for serializing Owl matrices and NDarrays using
https://github.com/janestreet/bin_prot.

Basic usage:

For an Owl dense matrix or ndarray `x`:

```OCaml
(* Serialize x and write it into file x.bin.  If x.bin exists, it will
be truncated and overwritten. *)
Owl_bin_prot.serialize_to_file x "x.bin"

(* Read the data back in from the file: *)
let x' = Owl_bin_prot.unserialize_from_file "x.bin"

(* Check that the old and new versions are equal: *)
x = x'
```

To build: `make`.

To build docs: `make doc`.  Then open
`_build/default/_doc/_html/owl_bin_prot/Owl_bin_prot/index.html` in a
browser.

```
make




