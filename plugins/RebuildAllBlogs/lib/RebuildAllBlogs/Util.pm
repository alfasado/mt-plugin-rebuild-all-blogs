package RebuildAllBlogs::Util;
use Exporter;
@RebuildAllBlogs::Util::ISA = qw( Exporter );
use vars qw( @EXPORT_OK );
@EXPORT_OK = qw( str2array );

use strict;

sub str2array {
    my ( $str, $separator, $remove_space ) = @_;
    return unless $str;
    $separator ||= ',';
    my @items = split( $separator, $str );
    if ( $remove_space ) {
        @items = map { $_ =~ s/\s+//g; $_ } @items;
    }
    if ( wantarray ) {
        return @items;
    }
    return \@items;
}

1;