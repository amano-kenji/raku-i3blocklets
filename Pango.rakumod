unit module Pango;

our sub text($text, Str :$font_desc, Str :$fgcolor, Str :$bgcolor) {
  my $attributes=(
    do if $font_desc { 'font_desc="' ~ $font_desc ~ '"' },
    do if $fgcolor { 'fgcolor="' ~ $fgcolor ~ '"' },
    do if $bgcolor { 'bgcolor="' ~ $bgcolor ~ '"' },
  ).grep({ so $_ });

  if $attributes.elems > 0 {
    '<span ' ~ $attributes.join(" ") ~ '>' ~ $text ~ '</span>'
  } else {
    $text
  }
}
