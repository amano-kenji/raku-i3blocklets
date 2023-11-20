unit module Blocklet::PipewireVolume;
use Blocklet::Pipewire;
use Pipewire;
use Pango;

my $run = &CORE::run;

our sub run(
  Str:D $node, #= name of the pipewire node that has volume
  Str:D :$icon, #= icon text
  Str:D :$deviceNode, #= If $node is a virtual device, $deviceNode is the name of the real device node.
  Str:D :$warnColor="#FFFF00", #= The color used when $node is missing or pipewire is not running
  Str:D :$inactiveColor="#000000", #= The color used when $deviceNode is missing.
  Str:D :$socketName="pipewire-volume", #= A stream unix domain socket at $XDG_RUNTIME_DIR/i3blocks/$socketName
) {
  sub dump() { Pipewire::dump($node) }
  sub printStatus(Str $dump = dump) {
    if $dump.chars > 0 {
      my Hash $dumpHash = Pipewire::hashFromDump($dump);
      my Str $volText = $icon ~ " " ~ Int(100*Pipewire::getCubicVolume($dumpHash)) ~ "%";
      if !$deviceNode.defined || Pipewire::dump($deviceNode).chars > 0 {
        say $volText;
      } else {
        say Pango::text($volText, :fgcolor($inactiveColor))
      }
    } else {
      say Pango::text($icon, :fgcolor($warnColor))
    }
  }

  Blocklet::Pipewire::run(:$socketName, runningStatusFn => {
    if $_ {
      printStatus()
    } else {
      printStatus("")
    }
  }, socketFn => {
    my Str $dump = dump;
    if $dump.chars > 0 {
      given $_ {
        when /^"wpctl-set-volume" \h+ (\S+)$/ {
          my Hash $dumpHash = Pipewire::hashFromDump($dump);
          $run("wpctl", "set-volume", $dumpHash<id>, $0.Str, :!out, :!err);
          printStatus();
        }
        when /^"set-linear-volume" \h+ (\S+)$/ {
          my Hash $dumpHash = Pipewire::hashFromDump($dump);
          Pipewire::setLinearVolume($dumpHash, $0.Rat);
          printStatus();
        }
      }
    } else {
      printStatus("");
    }
  });
}
