#!/usr/bin/env perl
=head1 NAME

smilparser

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 OPTIONS

=cut

use strict;
use warnings;
use v5.16.0;
use Carp;
use Data::Dumper;
use XML::LibXML::Simple   qw(XMLin);
use File::Slurp;
use JSON;

#my $arg = $ARGV[0];
#if ( $arg ) {
  #parse_and_dump( $arg );
  #exit;
#}

my $book = {
  ###### Stuff not yet parsed ....... :-(
  id => $ARGV[0] || 1234,
  author =>  $ARGV[1] || "Unknown Author",
  cover => "nota_logo.jpg", # "18716/18716_h512",
  duration => 22899,
  ##################################
  parts => [],
  navigation => []
};

parse_master();

say "--------------- Book ------------";
say Dumper $book;

generate_swift();
generate_json();


sub parse_master
{
  my $master = parse( 'master.smil');

  my $body = $master->{'body'};
  my $refs = $body->{'ref'};
  my $meta = $master->{'head'}->{meta};

  $book->{title} = $meta->{'dc:title'}->{content};
  $book->{identifier} = $meta->{'dc:identifier'}->{content};

  #say Dumper $refs;

  foreach my $ref ( @$refs ) {
    my $nav = {
      title => $ref->{title},
      partId => $ref->{src} .'#'. $ref->{id}
    };
    push ( $book->{navigation}, $nav );
    parse_smil( $ref->{src} );
  }
}

#        {
#          "id":"hbdw0003.smil#pmsu00009",
#          "text":"18716.htm#pmsu00009",
#          "duration":"117.534s",
#          "audio": [
#                    "src":"MEM_003.mp3", "begin":"npt=0.000s", "end":"npt=2.965s" "id":"qwrt_0001",
#                    "src":"MEM_003.mp3" "begin":"npt=2.965s" , "end":"npt=65.289s" "id":"qwrt_0002",
#                    "src":"MEM_003.mp3" "begin":"npt=65.289s" , "end":"npt=117.534s" "id":"qwrt_0003",
#          ]
#        }
sub parse_smil
{
  my $smilfile = shift;
  say "PARSING: $smilfile.................";
  my $smil     = parse( $smilfile );

  my $body = $smil->{'body'};
  my $seqs = $body->{'seq'};
  my $meta = $smil->{'head'}->{meta};
  my $smil_title => $meta->{title}->{content}; # TODO: Doesn work yet...

  foreach my $seq ( @$seqs ) {
    foreach my $par ( @{ $seq->{par} } ) {
      my ( $text_file, $text_id ) = split('#', $par->{text}->{src});
      my $part = {
        id => $smilfile .'#'.$par->{text}->{id},
        textFile => $text_file,
        textId => $text_id,
      };

      foreach my $subseq ( @{ $par->{seq} } ) {
        foreach my $audioseq ( @{ $subseq->{audio} } ) {
          $part->{audio} = $audioseq->{src};
          $part->{begin} = strip_non_num( $audioseq->{'clip-begin'} );
          $part->{end} = strip_non_num( $audioseq->{'clip-end'} );

          # TODO: For now we generate a new part per audio segment. Need to fix this.

          my %new_part = %$part; # TODO: Should use clone, only works because is not nested.
          push ( $book->{parts}, \%new_part );
        }
      }
    }
  }
}

#let memoBook = Book(
#    id: 18716,
#    author: "Oddbjørn By",
#    title: "Memo - studiehåndbogen",
#    cover: "18716/18716_h512",
#    duration: 22899,
#    parts: [
#BookPart(file: "18716/MEM_001", begin: 0.0, end: 9.195, id: "hbdw0001.smil#pmsu00005", textFile: "18716.htm", textId:"pmsu00005" ),
#BookPart(file: "18716/MEM_002", begin: 0.000, end: 39.431, id: "hbdw0002.smil#pmsu00007", textFile: "18716.htm", textId:"pmsu00007"),
#])
sub generate_swift
{
  my $id = $book->{id};
    #identifier: '$book->{identifier}'',
  my $swift = qq|
  let book$book->{id} = Book(
    id: $book->{id},
    author: "$book->{author}" ,
    title: "$book->{title}" ,
    cover: "$book->{cover}" ,
    duration: $book->{duration},
    parts: [
    |;

  foreach my $bookpart ( @{ $book->{parts} }) {
    my $file_no_ext = "$id/$bookpart->{audio}";
    $file_no_ext =~ s/\.mp3//;

    $swift .= qq|
      BookPart(
        file: "$file_no_ext",
        begin: $bookpart->{begin},
        end: $bookpart->{end},
        id: "$bookpart->{id}",
        textFile: "$bookpart->{textFile}",
        textId: "$bookpart->{textId}"
        ),
    |;
  }


  $swift .= "
  ]
  )
  ";

say "--------- SWIFT ------------";
say $swift;
write_file( "Book$id.swift", $swift);


}

sub generate_json
{
  my $id = $book->{id};
  write_file( "Book$id.json", JSON->new->pretty->encode($book));
}


sub strip_non_num
{
  my $str = shift;
  $str =~ s/[^0-9\.]//g; # Quick and dirty impl.
  return $str;
}
sub parse {
  my $file = shift;
  return XMLin($file, ForceArray => [ 'seq', 'audio', 'par' ], KeyAttr => [ 'name' ] );
}

#say "-----------------------------";
#foreach my $elem (   $data->{body}  ) {
#  say "Element: " . $elem;
#  say Dumper( $elem);
#}

sub parse_and_dump
{
  my $file = shift;
  my $xml = read_file( $file );
  my $data = parse( $file);

  say $xml;
  say Dumper($data);
}



1;
__END__
=head1 EXIT STATUS

=head1 AUTHOR


=head1 HISTORY

  See the Git log

=head1 REMARKS

=cut
