unit module Blocklet::Pipewire;
use UnixDomainSocketTimer;
use Pipewire;

our sub run(
  Str :$socketName="microphone", #= The stream unix domain socket will be at $XDG_RUNTIME_DIR/i3blocks/$socketName
  Callable:D :$runningStatusFn, #= This function is passed whether pipewire is running. Print status in it.
  Callable:D :$socketFn, #= This function is called with each command to the socket.
) {
  my Bool $running = Pipewire::running;

  UnixDomainSocketTimer::run(socketName => $socketName, socketFn => {
    my Bool $newRunning = Pipewire::running;
    if !$newRunning {
      if $running {
        $runningStatusFn(False)
      }
    } else {
      $socketFn($_)
    }
    $running=$newRunning;
  }, timerFn => {
    my Bool $newRunning = Pipewire::running;
    if $newRunning {
      $runningStatusFn(True)
    } elsif $running {
      $runningStatusFn(False)
    }
    $running = $newRunning;
  });
}
