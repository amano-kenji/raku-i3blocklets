unit module UsbGuard;

my grammar DevicesGrammar {
  token interface {
    <.xdigit> ** 2 ":" <.xdigit> ** 2 ":" <.xdigit> ** 2
  }
  token with-interface {
    <.interface> || \{ [ \h+ <interface> ]+ \h+ \}
  }
  token device {
    \d+ ":" \h+ ("allow" || "block")
    \h+ "id" \h+ (\S+)
    \h+ "serial" \h+ "\"" (<-["\s]>*) "\""
    \h+ "name" \h+ "\"" (<-["\v]>*) "\""
    \h+ "hash" \h+ "\"" (<-["\s]>+) "\""
    \h+ "parent-hash" \h+ "\"" (<-["\s]>+) "\""
    \h+ "via-port" \h+ "\"" (<-["\s]>+) "\""
    \h+ "with-interface" \h+ <with-interface>
    \h+ "with-connect-type" \h+ "\"" (<-["\s]>*) "\""
    "\n"
  }
  token TOP {
    <device>+
  }
}

class DeviceSpec {
  has Str $.status;
  has Str $.id;
  has Str $.serial;
  has Str $.name;
  has Str $.hash;
  has Str $.parent-hash;
  has Str $.via-port;
  has Str @.with-interface;
  has Str $.with-connect-type;
}

my class DevicesAction {
  method with-interface($/) {
    if $<interface> {
      make map({.Str}, $<interface>)
    } else {
      make List.new($/.Str)
    }
  }
  method device($/) {
    make DeviceSpec.new(
      status => $0.Str,
      id => $1.Str,
      serial => $2.Str,
      name => $3.Str,
      hash => $4.Str,
      parent-hash => $5.Str,
      via-port => $6.Str,
      with-interface => $<with-interface>.made,
      with-connect-type => $7.Str);
  }
  method TOP($/) {
    make map({.made}, $<device>)
  }
}

#| Return usbguard device specs
sub devices() of Seq {
  my $devices = run("usbguard", "list-devices", :out).out.slurp(:close);
  DevicesGrammar.parse($devices, actions => DevicesAction).made;
}

sub encodeRuleAttributes(DeviceSpec:D $d) of Str {
  join " ", (
    do if $d.id { "id " ~ $d.id },
    do if $d.serial { 'serial "' ~ $d.serial ~ '"' },
    do if $d.name { 'name "' ~ $d.name ~ '"' },
    do if $d.hash { 'hash "' ~ $d.hash ~ '"' },
    do if $d.parent-hash { 'parent-hash "' ~ $d.parent-hash ~ '"' },
    do if $d.via-port { 'via-port "' ~ $d.via-port ~ '"' },
    do if $d.with-interface { "with-interface all-of \{ " ~ join(" ", $d.with-interface) ~ " \}" },
    do if $d.with-connect-type.defined { 'with-connect-type "' ~ $d.with-connect-type ~ '"' },
  ).grep({ so $_ });
}

#| Return True if device is available and allowed. Otherwise, return False.
our sub find(DeviceSpec:D $devspec) of DeviceSpec {
  my $devices = devices;
  return False unless $devices.defined;

  my $criteria = (
    do if $devspec.id { -> DeviceSpec $d { $d.id eq $devspec.id } },
    do if $devspec.serial { -> DeviceSpec $d { $d.serial eq $devspec.serial } },
    do if $devspec.name { -> DeviceSpec $d { $d.name eq $devspec.name } },
    do if $devspec.hash { -> DeviceSpec $d { $d.hash eq $devspec.hash } },
    do if $devspec.parent-hash { -> DeviceSpec $d { $d.parent-hash eq $devspec.parent-hash } },
    do if $devspec.via-port { -> DeviceSpec $d { $d.via-port eq $devspec.via-port } },
    do if $devspec.with-interface { -> DeviceSpec $d {
      if $d.with-interface -> $given-ifs {
        so: map({ so $_ eq $given-ifs.any }, $devspec.with-interface).all;
      }
    } },
    do if $devspec.with-connect-type { -> DeviceSpec $d { $d.with-connect-type eq $devspec.with-connect-type } },
  ).grep({ so $_ });

  first(-> $dev { so map({ $_($dev) }, $criteria.cache).all }, $devices);
}

sub allowed(DeviceSpec:D $devspec) of Bool {
  my $matchedDev = find($devspec);
  return False unless $matchedDev.defined;
  if $matchedDev.status eq "allow" {
    return True
  } else {
    return False
  }
}

sub allow(DeviceSpec:D $d) {
  run("usbguard", "allow-device", encodeRuleAttributes($d))
}

sub block(DeviceSpec:D $d) {
  run("usbguard", "block-device", encodeRuleAttributes($d))
}

our sub toggle(DeviceSpec:D $d) {
  if allowed($d) {
    block($d)
  } else {
    allow($d)
  }
}
