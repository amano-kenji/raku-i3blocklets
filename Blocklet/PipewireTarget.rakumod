unit module Blocklet::PipewireTarget;
use Blocklet::Pipewire;
use Pipewire;
use Pango;

my $run = &CORE::run;

our sub run(
  Str:D $playbackStream, #= name of the pipewire playback stream that has target.object and contains mute status
  Map:D :$targetIcons, #= targets are keys. Their icons are values.
  Str:D :$muteColor="#000000", #= The foreground text color used when $playbackStream is muted.
  Str:D :$warn="node missing", #= The text shown when pipewire is not running or when $playbackStream is missing.
  Str:D :$socketName="pipewire-target", #= A stream unix domain socket is created at $XDG_RUNTIME_DIR/i3blocks/$sockName
) {
  sub dump() { Pipewire::dump($playbackStream) }
  sub target(Hash $dump) { Pipewire::getTarget($dump) }
  sub printStatus(Str $dump = dump) {
    if $dump.chars > 0 {
      printTarget(Pipewire::hashFromDump($dump))
    } else {
      say $warn
    }
  }
  sub printTarget(Hash $dump, $target = target($dump)) {
    if $target.defined {
      my $targetIcon = $targetIcons{$target};
      if Pipewire::isMuted($dump) {
        say Pango::text($targetIcon, :fgcolor($muteColor))
      } else {
        say $targetIcon
      }
    } else {
      say $warn;
    }
  }
  my $targets = $targetIcons.keys.list;

  Blocklet::Pipewire::run(:$socketName, runningStatusFn => {
    if $_ {
      printStatus()
    } else {
      printStatus("")
    }
  }, socketFn => {
    my Str $dump = dump;
    if $dump.chars > 0 {
      my Hash $dumpHash = Pipewire::hashFromDump($dump);
      if $_ eq "toggle" {
        my $target = target($dumpHash);
        my $nextTarget = do if $target {
          my $targetIdx = $targets.first(* eq $target, :k);
          if $targetIdx.defined {
            $targets[($targetIdx + 1) % $targets.elems]
          } else {
            $targets[0]
          }
        } else {
          $targets[0]
        }
        Pipewire::setTarget($dumpHash, $nextTarget);
        printTarget($dumpHash, $nextTarget);
      } elsif $_ eq "toggleMute" {
        $run("wpctl", "set-mute", $dumpHash<id>, "toggle", :!out, :!err);
        printStatus();
      }
    } else {
      printStatus("");
    }
  });
}
