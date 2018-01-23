# This code is part of distribution Geo-WKT.  Meta-POD processed with
# OODoc into POD and HTML manual-pages.  See README.md
# Copyright Mark Overmeer.  Licensed under the same terms as Perl itself.

package Geo::WKT;
use base 'Exporter';

use strict;
use warnings;

use Geo::Shape  ();
use Carp;

our @EXPORT = qw(
  parse_wkt
  parse_wkt_point
  parse_wkt_polygon
  parse_wkt_geomcol
  parse_wkt_linestring
  wkt_point
  wkt_multipoint
  wkt_linestring
  wkt_polygon
  wkt_linestring
  wkt_multilinestring
  wkt_multipolygon
  wkt_optimal
  wkt_geomcollection
 );

sub wkt_optimal($);

=chapter NAME

Geo::WKT - Well Known Text representation of geometry information

=chapter SYNOPSIS

  # use coordinate pairs ...
  print wkt_linestring([1,2], [2,3], [3,2], [1,2]);
    # --> LINESTRING(1 2,2 3,3 2,1 2)

  # ... or coordinatie objects
  my $gp1 = Geo::Point->xy(6,7);
  my $gp2 = Geo::Point->xy(8,9);
  my $gp3 = Geo::Point->xy(6,9);
  print wkt_linestring($gp1, $gp2, $gp3);
    # --> LINESTRING(6 7,8 9,6 9)

  # Combine with Geo::Point registration of projections
  my $p = parse_wkt_point "POINT(3.5 6.7)", 'wgs84';
  print $p->toString; # point[wgs84](6.7000 3.5000)

=chapter DESCRIPTION
GIS application often communicate geographical structures in WKT
format, defined by the OpenGIS consortium.  This module translates
M<Geo::Point> objects from and to this WKT.

=chapter FUNCTIONS

=section Parsing Well Known Text format (WKT)

=function parse_wkt_point STRING, [$projection]
Convert a WKT string into one M<Geo::Point> object.
=cut

sub parse_wkt_point($;$)
{     ($_[0] =~ m/^point\(\s*(\S+)\s+(\S+)\)$/i)
    ? Geo::Point->xy($1+0, $2+0, $_[1])
    : undef;
}

=function parse_wkt_polygon STRING, [$projection]
Convert a WKT string into one M<Geo::Surface> objects, containing
the exterior and optionally some interior polygons.
=cut

sub parse_wkt_polygon($;$)
{   my ($string, $proj) = @_;

    $string && $string =~ m/^polygon\(\((.+)\)\)$/i
        or return undef;

    my @poly;
    foreach my $poly (split m/\)\s*\,\s*\(/, $1)
    {   my @points = map +[split " ", $_, 2], split /\s*\,\s*/, $poly;
        push @poly, \@points;
    }

    Geo::Surface->new(@poly, proj => $proj);
}

=method parse_wkt_geomcol STRING, [$projection]
Convert a WKT string into M<Geo::Space> objects, containing
the exterior and optionally some interior polygons.
=cut

sub parse_wkt_geomcol($;$)
{   my ($string, $proj) = @_;

    return undef if $string !~
        s/^(multiline|multipoint|multipolygon|geometrycollection)\(//i;

    my @comp;
    while($string =~ m/\D/)
    {   $string =~ s/^([^(]*\([^)]*\))//
            or last;

        my $take  = $1;
        while(1)
        {   my @open  = $take =~ m/\(/g;
            my @close = $take =~ m/\)/g;
            last if @open==@close;
            $take .= $1 if $string =~ s/^([^\)]*\))//;
        }
        push @comp, parse_wkt($take, $proj);
        $string =~ s/^\s*\,\s*//;
    }

    Geo::Space->new(@comp, proj => $proj);
}

=function parse_wkt_linestring STRING, [$projection]
Convert a WKT string into one M<Geo::Line> object.
=cut

sub parse_wkt_linestring($;$)
{   my ($string, $proj) = @_;

    $string && $string =~ m/^linestring\((.+)\)$/i
        or return undef;

    my @points = map +[split " ", $_, 2], split /\s*\,\s*/, $1;
    @points > 1 or return;

    Geo::Line->new(proj => $proj, points => \@points, filled => 0);
}

=method parse_wkt STRING, [$projection]
Parse any STRING into the applicable M<Geo::Shape> structure.
=cut

sub parse_wkt($;$)  # dirty code to avoid copying the sometimes huge string
{
      $_[0] =~ m/^point\(/i      ? &parse_wkt_point
    : $_[0] =~ m/^polygon\(/i    ? &parse_wkt_polygon
    : $_[0] =~ m/^linestring\(/i ? &parse_wkt_linestring
    :                              &parse_wkt_geomcol;
}

=section Constructing Well Known Text (WKT)

=function wkt_point <$x,$y>|ARRAY|$geopoint
Format one point into WKT format.

=cut

sub _list_of_points(@)
{   my @points
      = @_ > 1                      ? @_
      : ref $_[0] eq 'ARRAY'        ? @{$_[0]}
      : $_[0]->isa('Math::Polygon') ? $_[0]->points
      : $_[0];

    my @s = map
      { (ref $_ ne 'ARRAY' && $_->isa('Geo::Point'))
      ? $_->x.' '.$_->y
      : $_->[0].' '.$_->[1]
      } @points;

    local $" = ',';
    "(@s)";
}

sub wkt_point($;$)
{   my ($x, $y)
       = @_==2                ? @_
       : ref $_[0] eq 'ARRAY' ? @{$_[0]}
       :                       shift->xy;

    defined $x && defined $y ? "POINT($x $y)" : ();
}

=function wkt_linestring $object|$points
A line string is a non-closed list ('string') of points.
=cut

sub wkt_linestring(@) { 'LINESTRING' . _list_of_points(@_) }

=function wkt_polygon <LIST-of-points|Geo::Line|ARRAY-of-points> |Geo::Surface
Format one polygon (exterior with optional interiors) into WKT format.
An ARRAY contains M<Geo::Point> objects or ARRAY-REFs to pairs. You
may also provide a M<Geo::Line> or M<Geo::Surface> OBJECTS.

=examples
 wkt_polygon [2,3],[4,5];   #list of points for outer
 wkt_polygon $gp1, $gp2;    #list of Geo::Points for outer
 wkt_polygon [[2,3],[4,5]]; #array of points for outer
 wkt_polygon [$gp1, $gp2];  #array with Geo::Points for outer

 my $outer = Geo::Line->new;
 wkt_polygon $outer;
 wkt_polygon $outer, $inner1, $inner2;
 wkt_polygon [$gp1,$gp2],[$gp3,$gp4,...];
=cut

sub wkt_polygon(@)
{   my @polys
      = !defined $_[0]             ? return ()
      : ref $_[0] eq 'ARRAY'       ? (ref $_[0][0] ? @_ : [@_])
      : $_[0]->isa('Geo::Line')    ? @_
      : $_[0]->isa('Geo::Surface') ? ($_[0]->outer, $_[0]->inner)
      :                              [@_];

    'POLYGON(' .join(',' ,  map _list_of_points($_), @polys). ')';
}

=function wkt_multipoint $object|$points
A set of points, which must be specified as list.  They can be stored in
a M<Geo::Space>.
=cut

sub wkt_multipoint(@) { 'MULTIPOINT(' .join(',', map wkt_point($_), @_). ')'}

=function wkt_multilinestring $objects|ARRAY-of-lines|ARRAYS-of-ARRAY-of-points
Format a list of lines into WKT.  A line contains M<Geo::Point>
objects or ARRAY-REFs to coordinate pairs. You may also provide a M<Geo::Line>
or a M<Math::Polygon>.
=cut

sub wkt_multilinestring(@)
{   return () unless @_;
    'MULTILINESTRING(' .join(',' ,  map wkt_linestring($_), @_). ')';
}

=function wkt_multipolygon $objects|ARRAY-of-lines|ARRAYs-of-ARRAY-of-points
Format a list of closed lines into WKT.  A line contains M<Geo::Point>
objects or ARRAY-REFs to coordinate pairs. You may also provide a M<Geo::Line>
or a M<Math::Polygon>.
=cut

sub wkt_multipolygon(@)
{   return () unless @_;

    my @polys = map wkt_polygon($_), @_;
    s/^POLYGON// for @polys;

    'MULTIPOLYGON(' .join(',' , @polys). ')';
}


=function wkt_optimal $object
Pass any M<Geo::Shape> object, and the easiest representation is
returned.
=cut

sub wkt_optimal($)
{   my $geom = shift;
    return wkt_point(undef) unless defined $geom;

    return wkt_point($geom)
        if $geom->isa('Geo::Point');

    return ( $geom->isRing && $geom->isFilled
           ? wkt_polygon($geom)
           : wkt_linestring($geom))
        if $geom->isa('Geo::Line');

    return wkt_multipolygon($geom)
        if $geom->isa('Geo::Surface');

    $geom->isa('Geo::Space')
        or croak "ERROR: Cannot translate object $geom into SQL";

      $geom->nrComponents==1 ? wkt_optimal($geom->component(0))
    : $geom->onlyPoints      ? wkt_multipoint($geom->points)
    :                          wkt_geomcollection($geom);
}

=function wkt_geomcollection $objects
Whole bunch of unsorted geometries. You may specify one M<Geo::Space>
or multiple things.
=cut

sub wkt_geomcollection(@)
{   @_ = $_[0]->components
       if @_==1
       && ref $_[0] ne 'ARRAY'
       && $_[0]->isa('Geo::Space');

    'GEOMETRYCOLLECTION(' .join(',', map wkt_optimal($_), @_). ')';
}

1;
