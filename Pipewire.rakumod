unit module Pipewire;

use JSON::Fast;

our Bool sub running() {
  if %*ENV<XDG_RUNTIME_DIR> -> $configDir {
    "{$configDir}/pipewire-0".IO.e
  } else {
    False
  }
}

our Hash sub dumpHash(Str $node) {
  try {
    my $json = from-json run("pw-dump", $node, :out, :!err).out.slurp(:close);
    return $json[0];
    CATCH {
      when X::AdHoc { return %{} }
    }
  }
}

our Hash sub hashFromDump(Str $dump) {
  try {
    return from-json($dump)[0];
    CATCH {
      when X::AdHoc { return %{} }
    }
  }
}

our Str sub dump(Str $node) {
  run("pw-dump", $node, :out, :!err).out.slurp(:close)
}

my grammar metadataTargetGrammar {
  token value { <-['\ ]>+ }
  token TOP {
    "Found \"default\" metadata " \d+ "\n"
    "update: id:" \d+ " key:'target.object' value:'" <value> "' type:'" <.value> "'\n"
  }
}

our sub getTarget(Hash $dump) {
  if $dump<id> -> $id {
    my $metadata = run("pw-metadata", "-n", "default", $id, "target.object", :out, :!err).out.slurp(:close);
    my $propTarget = $dump<info><props><target.object>;
    if $metadata.chars > 0 {
      if metadataTargetGrammar.parse($metadata)<value> -> $match {
        $match.Str
      } else {
        $propTarget
      }
    } else {
      $propTarget
    }
  } else {
    Nil
  }
}

our sub setTarget(Hash $dump, Str $target) {
  if $dump<id> -> $id {
    run "pw-metadata", $id, "target.object", $target, "Spa:String", :!out, :!err
  }
}

our Numeric sub getCubicVolume(Hash $dump) {
  if $dump<info><params><Props>[0]<channelVolumes>[0] -> $linearVol {
    $linearVol ** (1 / 3)
  } else {
    Nil
  }
}

our sub isMuted(Hash $dump) {
  $dump<info><params><Props>[0]<mute>;
}

our sub setLinearVolume(Hash $dump, Rat $linearVol) {
  if $dump<id> -> $id {
    run "pw-cli", "set-param", $id, "Props", "\{ channelVolumes = [ {$linearVol} {$linearVol} ] \}", :!out, :!err
  }
}
