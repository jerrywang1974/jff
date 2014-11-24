#!/usr/bin/perl
use JSON;
use strict;
use warnings;

local $/;
print to_json(decode_json(<>), { utf8 => 1, pretty => 1, canonical => 1});

