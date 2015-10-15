#!/usr/bin/perl
use Data::Dumper;
use XML::Simple qw(:strict);
use strict;
use warnings;

my $doc = XMLin("-",
    ForceArray => 1,
    KeyAttr => { bean => "id", property => "name" });
#print Dumper($doc);

my $beans = $doc->{bean};

while (my ($bean, $h) = each %$beans) {
    my $properties = $h->{property};
    if (defined $properties) {
        while (my ($k, $v) = each %$properties) {
            my $ref = $v->{ref};
            next unless defined $ref;

            print "\"$bean\\n",
                  $h->{class},
                  "\" -> \"$ref\\n",
                  exists $beans->{$ref} ? $beans->{$ref}{class} : "",
                  "\";\n";
        }
    }

    my $constructor_args = $h->{"constructor-arg"};
    if (defined $constructor_args) {
        for my $arg (@$constructor_args) {
            my $ref = $arg->{ref};
            next unless defined $ref;

            print "\"$bean\\n",
                  $h->{class},
                  "\" -> \"$ref\\n",
                  exists $beans->{$ref} ? $beans->{$ref}{class} : "",
                  "\";\n";
        }
    }
}

