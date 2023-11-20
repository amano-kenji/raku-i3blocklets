unit module Blocklet::PipewireUsbMicrophone;
use Blocklet::Pipewire;
use Pango;
use Pipewire;
use UnixDomainSocketTimer;
use UsbGuard;


our sub run(
  Str $node, #= Pipewire node name for the USB microphone
  UsbGuard::DeviceSpec :$devSpec, #= A partial UsbGuard device spec that describes the USB microphone
  Str :$icon="mic", #= The icon shown when microphone is active or pipewire is not running.
  Str :$missing="no-mic", #= The text shown when microphone is missing while pipewire is running.
  Str :$warnColor="#00FF00", #= The color to be used when pipewire is not running.
  Str :$socketName="microphone", #= The stream unix domain socket will be at $XDG_RUNTIME_DIR/i3blocks/$socketName
) {
  sub dump() { Pipewire::dump($node) }
  sub printStatus(Str $dump) {
    if $dump.chars > 0 {
      say $icon, " ", Int(Pipewire::getCubicVolume(Pipewire::hashFromDump($dump)) * 100), "%";
    } else {
      say $missing
    }
  }

  Blocklet::Pipewire::run(:$socketName, runningStatusFn => {
    if $_ {
      printStatus(dump);
    } else {
      say Pango::text($icon, :fgcolor($warnColor))
    }
  }, socketFn => {
    if !UsbGuard::find($devSpec) {
      printStatus("")
    } elsif $_ eq "toggle" {
      my $dump = dump;
      UsbGuard::toggle($devSpec);
      # Try 20 times, and give up
      for ^20 {
        my $newDump = dump;
        if ($dump.chars > 0) !== ($newDump.chars > 0) {
          printStatus($newDump);
          last;
        }
      }
    }
  });
}
