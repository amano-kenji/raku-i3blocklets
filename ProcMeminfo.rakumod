unit module ProcMeminfo;

my grammar meminfoGrammar {
  token entry {
    (<-[:\h]>+)
    ":"
    \h+
    (\d+)
    [ \h+ \S+ ]?
    "\n"
  }
  token TOP {
    <entry>+
  }
}

my class meminfoAction {
  method TOP($/) {
    make reduce { $^a{$^b[0].Str} = $^b[1].Int; $^a; }, %{}, |$<entry>;
  }
}

our sub get() {
  meminfoGrammar.subparse(slurp("/proc/meminfo"), actions => meminfoAction).made;
}
