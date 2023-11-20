unit module UnixDomainSocketTimer;

#|( Given a supply, return a new channel and a function that unblocks the new channel.
    The new channel emits one line of text from stream unix domain sockets emitted by the supply.
    Once the channel receives an item, the channel emits it and is blocked until the function is called.
  )
sub throttledMsgFromStreamUnixDomainSocket(Supply:D $supply) {
  my $ready = Channel.new;
  my $newChan = Channel.new;

  my $channelReady = { $ready.send("") };
  my Bool $running = False;

  start {
    react {
      whenever $ready {
        $running = False
      }

      whenever $supply.Channel {
        my $msg = .Supply.lines.Channel.receive;
        .close;
        if !$running {
          $running = True;
          $newChan.send($msg);
        }
        LAST { done }
      }
    }
  }

  $newChan, $channelReady;
}

#|( A connecting socket can send only one command followed by "\n" to the stream unix domain socket created by this
    function.

    If a command reaches the socket, the timer is reset.

    While $socketFn is processing a command, new commands are dropped.)
our sub run(
  Str :$socketName, #= A stream unix domain socket is created at $*ENV<XDG_RUNTIME_DIR>/i3blocks/$socketName
  Callable:D :$socketFn, #= This is called with a command that reached the socket
  Int :$interval=3, #= Every $interval seconds, $timerFn is called.
  Callable:D :$timerFn, #= This function is called with no argument.
) {
  die "\$XDG_RUNTIME_DIR environment variable is not set" unless %*ENV<XDG_RUNTIME_DIR>;
  my $socketDir = "{%*ENV<XDG_RUNTIME_DIR>}/i3blocks";
  mkdir $socketDir;
  my $socketPath = "{$socketDir}/{$socketName}";
  my $socket = IO::Socket::Async.listen-path($socketPath);
  my ($throttledSocketMsg, $socketReady) = throttledMsgFromStreamUnixDomainSocket($socket);
  my $timerSupplier = Supplier.new;
  my $newTimer = Supply.interval($interval, $interval);

  unlink $socketPath;
  react {
    whenever $timerSupplier.Supply.migrate.Channel {
      $timerFn();
    }
    $timerSupplier.emit(Supply.interval($interval));

    whenever $throttledSocketMsg {
      $socketFn($_);
      $socketReady();
      # Restart the timer
      $timerSupplier.emit($newTimer);
    }
  }
}
