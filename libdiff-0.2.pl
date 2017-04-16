use warnings;
use strict;
use Data::Dumper;
use Term::ANSIColor;
use Parse::Liberty::Simple;
use Try::Tiny;
use Scalar::Util qw(looks_like_number);

sub parse {
    my $libpath = shift;

    my %lib1;
    my $parser = new Parse::Liberty::Simple($libpath);


    $lib1{library}{name} = $parser->name;
    my @attrs = $parser->attrs;
    foreach (@attrs) {
        $lib1{library}{$_->name} = $_->value;
    }

    my @cells = $parser->cells;
    foreach my $cell (@cells) {
        my @cell_attrs = $cell->get_attributes;
        foreach (@cell_attrs) {
            $lib1{cells}{$cell->name}{$_->name} = $_->value;
        }

        my @cell_groups = $cell->get_groups();

        foreach my $cell_group (@cell_groups) {
            # Cell attrb
            my @cell_group_attrs = $cell_group->get_attributes();
            foreach (@cell_group_attrs) {
                # Leakage power fix
                if ($cell_group->type eq 'leakage_power') {
                    my $temp = $cell_group->attr('when');
                    $temp =~ s/"//g;
                    $lib1{cells}{$cell->name}{$cell_group->type}{$temp}{$_->name} = $_->value;
                } else {
                    $lib1{cells}{$cell->name}{$cell_group->type}{$cell_group->name}{$_->name} = $_->value;
                }

            }

            # Cell groups
            my @groups = $cell_group->get_groups();

            # Pins groups
            if (scalar @groups gt 0) {
                my @subgroups = ();
                my $level = 0;
                my @lastgrouptype;

                push @{$subgroups[$level]}, @groups;

                do {
                    my $group = shift @{$subgroups[$level]};
                    do next if (!defined $group);

                    my @attrs = $group->get_attributes();
                    foreach (@attrs) {
                        my @nested_values = ('index_1', 'index_2', 'values');
                        my $tval = $_->name;
                        my $value = $_->value;
                        if (grep /^$tval/i, @nested_values) {
                            my $left = $_->value =~ s/\"//gr;
                            my @aleft = split /,/, $left;
                            s{^\s+|\s+$}{}g foreach @aleft;
                            $value = \@aleft;
                        }



                        if ($level eq 0) {
                            if ($group->type eq 'internal_power') {
                                my $temp = $group->attr('when');
                                $temp =~ s/"//g;
                                $lib1{cells}{$cell->name}{$cell_group->type}{$cell_group->name}{$group->type}{$temp}{$_->name} = $value;
                            } elsif ($group->type eq 'timing') {
                                my $temp = $group->attr('related_pin');
                                $temp =~ s/"//g;
                                $lib1{cells}{$cell->name}{$cell_group->type}{$cell_group->name}{$group->type}{$temp}{$_->name} = $value;
                            }
                            else {
                                $lib1{cells}{$cell->name}{$cell_group->type}{$cell_group->name}{$group->type}{$_->name} = $value;
                            }
                        } else {
                            my $lastgroup = $lastgrouptype[-1];
                            if ($lastgroup->type eq 'internal_power') {
                                my $temp = $lastgroup->attr('when');
                                $temp =~ s/"//g;
                                $lib1{cells}{$cell->name}{$cell_group->type}{$cell_group->name}{$lastgroup->type}{$temp}{$group->type}{$group->name}{$_->name} = $value;
                            } elsif ($lastgroup->type eq 'timing') {
                                my $temp = $lastgroup->attr('related_pin');
                                $temp =~ s/"//g;
                                if (ref($value) eq 'ARRAY') {
                                    push @{$lib1{cells}{$cell->name}{$cell_group->type}{$cell_group->name}{$lastgroup->type}{$temp}{$group->type}{$group->name}{$_->name}}, @{$value};
                                } else {
                                    $lib1{cells}{$cell->name}{$cell_group->type}{$cell_group->name}{$lastgroup->type}{$temp}{$group->type}{$group->name}{$_->name} = $value;
                                }
                            }
                            else {
                                $lib1{cells}{$cell->name}{$cell_group->type}{$cell_group->name}{$lastgroup->type}{$group->type}{$group->name}{$_->name} = $value;
                            }
                        }

                    }

                    my @tgroups = $group->get_groups();
                    if (scalar @tgroups gt 0) {
                        $level = $level + 1;
                        push @{$subgroups[$level]}, @tgroups;
                        push @lastgrouptype, $group;
                    } else {
                        if (scalar @{$subgroups[$level]} eq 0) {
                            $level = $level - 1;
                            pop @subgroups;
                            pop @lastgrouptype;
                        }
                    }
                } while (scalar @subgroups > 0);
            }
        }
    }

    return %lib1;
}

print "\nlibdiff 0.2 - Diff tool for Liberty library files\n(C) 2017 Ijat.my\n\n";

my %lib1 = parse("3input.lib"); #left
my %lib2 = parse("ncx-3input.lib"); #right

my $ok = colored("[/]", 'bright_green');
my $no = colored("[X]", 'bright_red');

# Compare library attributes
print colored("[Library Attributes]\n", 'bright_cyan');
foreach my $attr (sort keys %{$lib1{library}}) {

    if (defined $lib2{library}{$attr}) {
        my $ats = "";

        if (looks_like_number($lib1{library}{$attr}) and looks_like_number($lib2{library}{$attr})) {
            my $vdiff = (($lib2{library}{$attr} - $lib1{library}{$attr}) / abs($lib1{library}{$attr})) * 100;
            $ats = "[" . sprintf("%.04g", $vdiff) . "% changes]";
            $lib1{library}{$attr} = sprintf("%.04g", $lib1{library}{$attr});
        }

        if ($lib1{library}{$attr} eq $lib2{library}{$attr}) {
            print $ok . " " . $attr . ": " . $lib1{library}{$attr} . " $ats\n";
        } else {
            print $no . " " . $attr . ": " . $lib1{library}{$attr} . " | $lib2{library}{$attr} $ats\n";
        }
    } else {
        print $no . " " . $attr . ": " . $lib1{library}{$attr} . " | - \n";
    }

}
print "\n";

print colored("[Cells]\n", 'bright_cyan');
my $index = 1;
foreach my $cell (sort keys %{$lib1{cells}}) {
    print colored($index . ". " . $cell . "\n", 'bright_yellow');

    foreach my $cell_attrb (sort keys %{$lib1{cells}{$cell}}) {

        if (ref($lib1{cells}{$cell}{$cell_attrb}) eq '') {

            # Process for normal attributes
            if (defined $lib2{cells}{$cell}{$cell_attrb}) {
                my $ats = "";

                if (looks_like_number($lib1{cells}{$cell}{$cell_attrb}) and looks_like_number($lib2{cells}{$cell}{$cell_attrb})) {
                    my $vdiff = (($lib2{cells}{$cell}{$cell_attrb} - $lib1{cells}{$cell}{$cell_attrb}) / abs($lib1{cells}{$cell}{$cell_attrb})) * 100;
                    $ats = "[".sprintf("%.04f", $vdiff)."% changes]";
                    #$lib1{cells}{$cell}{$cell_attrb} = sprintf("%.04f", $lib1{cells}{$cell}{$cell_attrb});
                }

                if ($lib1{cells}{$cell}{$cell_attrb} eq $lib2{cells}{$cell}{$cell_attrb}) {
                    print $ok." ".$cell_attrb.": ".$lib1{cells}{$cell}{$cell_attrb}." | $lib2{cells}{$cell}{$cell_attrb} $ats\n";
                } else {
                    print $ok." ".$cell_attrb.": ".$lib1{cells}{$cell}{$cell_attrb} ." | $lib2{cells}{$cell}{$cell_attrb} $ats\n";
                }

            } else {
                print $no." ".$cell_attrb.": ".$lib1{cells}{$cell}{$cell_attrb}." | - \n";
            }

        } else {
            # Process for hashes

            # Leakage power
            if ($cell_attrb eq 'leakage_power') {
                my $ats;
                print colored(" *  Leakage Power" . "\n", 'bright_magenta');
                foreach my $when (sort keys %{$lib1{cells}{$cell}{$cell_attrb}}) {
                    if (defined $lib2{cells}{$cell}{$cell_attrb}{$when}) {
                        if (looks_like_number($lib1{cells}{$cell}{$cell_attrb}{$when}{value})
                            and looks_like_number($lib2{cells}{$cell}{$cell_attrb}{$when}{value})) {
                            my $vdiff = (($lib2{cells}{$cell}{$cell_attrb}{$when}{value} - $lib1{cells}{$cell}{$cell_attrb}{$when}{value}) / abs($lib1{cells}{$cell}{$cell_attrb}{$when}{value})) * 100;
                            $ats = "[".sprintf("%.04f", $vdiff)."% changes]";
                            #$lib1{cells}{$cell}{$cell_attrb}{$when}{value} = sprintf("%.04f", $lib1{cells}{$cell}{$cell_attrb}{$when}{value});
                        }
                        print "    " . $ok . " " . $when . ": $lib1{cells}{$cell}{$cell_attrb}{$when}{value} | $lib2{cells}{$cell}{$cell_attrb}{$when}{value} $ats\n";
                    } else {
                        print "    " . $no . " " . $when . ": $lib1{cells}{$cell}{$cell_attrb}{$when}{value} | - \n";
                    }
                }
            }

            # Pins
            if ($cell_attrb eq 'pin') {
                foreach my $pin (sort keys %{$lib1{cells}{$cell}{$cell_attrb}}) {
                    print colored(" *  Pin $pin" . "\n", 'bright_magenta');

                    foreach my $key (sort keys %{$lib1{cells}{$cell}{$cell_attrb}{$pin}}) {
                        if (ref($lib1{cells}{$cell}{$cell_attrb}{$pin}{$key}) eq '') {

                            if (defined $lib2{cells}{$cell}{$cell_attrb}{$pin}{$key}) {
                                my $ats = "";
                                if (looks_like_number($lib1{cells}{$cell}{$cell_attrb}{$pin}{$key})
                                    and looks_like_number($lib2{cells}{$cell}{$cell_attrb}{$pin}{$key})) {
                                    my $vdiff = (($lib2{cells}{$cell}{$cell_attrb}{$pin}{$key} - $lib1{cells}{$cell}{$cell_attrb}{$pin}{$key}) / abs($lib1{cells}{$cell}{$cell_attrb}{$pin}{$key})) * 100;
                                    $ats = "[".sprintf("%.04f", $vdiff)."% changes]";
                                }
                                print "    " . $ok . " " . $key . ": $lib1{cells}{$cell}{$cell_attrb}{$pin}{$key} | $lib2{cells}{$cell}{$cell_attrb}{$pin}{$key} $ats\n";
                            } else {
                                print "    " . $no . " " . $key . ": $lib1{cells}{$cell}{$cell_attrb}{$pin}{$key} | - \n";
                            }

                        } else {


                            if ($key eq 'internal_power') {

                                print colored("     *  Internal Power\n", 'bright_green');

                                foreach my $when (sort keys %{$lib1{cells}{$cell}{$cell_attrb}{$pin}{$key}}) {
                                    if (defined $lib2{cells}{$cell}{$cell_attrb}{$pin}{$key}{$when}) {

                                        print "        WHEN: " . colored($when, 'yellow') . "\n";

                                        foreach my $subgroup (sort keys %{$lib2{cells}{$cell}{$cell_attrb}{$pin}{$key}{$when}}) {
                                            #my %ref = \$lib2{cells}{$cell}{$cell_attrb}{$pin}{$key}{$when};

                                            if (ref($lib2{cells}{$cell}{$cell_attrb}{$pin}{$key}{$when}{$subgroup}) ne '') {
                                                my $subgroup_name1 = "";
                                                my $subgroup_name2 = "";

                                                # Get any subgroup name
                                                foreach (keys %{$lib2{cells}{$cell}{$cell_attrb}{$pin}{$key}{$when}{$subgroup}}) {
                                                    $subgroup_name2 = $_;
                                                    last;
                                                }

                                                foreach (keys %{$lib1{cells}{$cell}{$cell_attrb}{$pin}{$key}{$when}{$subgroup}}) {
                                                    $subgroup_name1 = $_;
                                                    last;
                                                }

                                                print "        ├─ " . $subgroup . "\n";

                                                foreach (sort keys %{$lib1{cells}{$cell}{$cell_attrb}{$pin}{$key}{$when}{$subgroup}{$subgroup_name1}}) {
                                                    print "        │    " . $_ . ":\n";

                                                    for (my $index=0; $index < scalar @{ $lib1{cells}{$cell}{$cell_attrb}{$pin}{$key}{$when}{$subgroup}{$subgroup_name1}{$_}}; $index = $index + 1) {

                                                        if (defined $lib2{cells}{$cell}{$cell_attrb}{$pin}{$key}{$when}{$subgroup}{$subgroup_name2}{$_}[$index]) {
                                                            my $ats = "";

                                                            my $vdiff = (($lib2{cells}{$cell}{$cell_attrb}{$pin}{$key}{$when}{$subgroup}{$subgroup_name2}{$_}[$index] - $lib1{cells}{$cell}{$cell_attrb}{$pin}{$key}{$when}{$subgroup}{$subgroup_name1}{$_}[$index]) / abs($lib1{cells}{$cell}{$cell_attrb}{$pin}{$key}{$when}{$subgroup}{$subgroup_name1}{$_}[$index])) * 100;
                                                            $ats = "[".sprintf("%.04f", $vdiff)."% changes]";

                                                            print "        │    " . $ok . " " . $lib1{cells}{$cell}{$cell_attrb}{$pin}{$key}{$when}{$subgroup}{$subgroup_name1}{$_}[$index] . " | " . $lib2{cells}{$cell}{$cell_attrb}{$pin}{$key}{$when}{$subgroup}{$subgroup_name2}{$_}[$index] . " $ats \n";

                                                        } else {
                                                            print "        │    " .$no . " " . $lib1{cells}{$cell}{$cell_attrb}{$pin}{$key}{$when}{$subgroup}{$subgroup_name1}{$_}[$index] . " | -\n";
                                                        }
                                                    }

                                                }

                                            }

                                        }

                                        #print "        " . $ok . " " . $when . ": " . $lib1{cells}{$cell}{$cell_attrb}{$pin}{$key}{$when}{when} . " | " . $lib2{cells}{$cell}{$cell_attrb}{$pin}{$key}{$when}{when} . "\n";
                                    } else {
                                        print "        " . $no . " " . $when . ": " . $lib1{cells}{$cell}{$cell_attrb}{$pin}{$key}{$when}{when} . " | - \n";
                                    }
                                }

                            } elsif ($key eq 'timing') {
                                print colored("     *  Timing\n", 'bright_green');

                                foreach my $relpin (sort keys %{$lib1{cells}{$cell}{$cell_attrb}{$pin}{$key}}) {
                                    print "        ├─ Related Pin: " . colored($relpin, 'bright_yellow') . "\n";

                                    foreach my $subgroup (sort keys %{$lib1{cells}{$cell}{$cell_attrb}{$pin}{$key}{$relpin}}) {

                                        # HASH
                                        if (ref($lib1{cells}{$cell}{$cell_attrb}{$pin}{$key}{$relpin}{$subgroup}) ne '') {

                                            if (defined $lib2{cells}{$cell}{$cell_attrb}{$pin}{$key}{$relpin}{$subgroup}) {

                                                my $subgroup_name1 = "";
                                                my $subgroup_name2 = "";

                                                # Get any subgroup name
                                                foreach (keys %{$lib2{cells}{$cell}{$cell_attrb}{$pin}{$key}{$relpin}{$subgroup}}) {
                                                    $subgroup_name2 = $_;
                                                    last;
                                                }

                                                foreach (keys %{$lib1{cells}{$cell}{$cell_attrb}{$pin}{$key}{$relpin}{$subgroup}}) {
                                                    $subgroup_name1 = $_;
                                                    last;
                                                }

                                                print "        ├─ " . $subgroup . "\n";

                                                foreach (sort keys %{$lib1{cells}{$cell}{$cell_attrb}{$pin}{$key}{$relpin}{$subgroup}{$subgroup_name1}}) {
                                                    print "        │    " . $_ . ":\n";

                                                    for (my $index=0; $index < scalar @{ $lib1{cells}{$cell}{$cell_attrb}{$pin}{$key}{$relpin}{$subgroup}{$subgroup_name1}{$_}}; $index = $index + 1) {

                                                        if (defined $lib2{cells}{$cell}{$cell_attrb}{$pin}{$key}{$relpin}{$subgroup}{$subgroup_name2}{$_}[$index]) {
                                                            my $ats = "";

                                                            my $vdiff = (($lib2{cells}{$cell}{$cell_attrb}{$pin}{$key}{$relpin}{$subgroup}{$subgroup_name2}{$_}[$index] - $lib1{cells}{$cell}{$cell_attrb}{$pin}{$key}{$relpin}{$subgroup}{$subgroup_name1}{$_}[$index]) / abs($lib1{cells}{$cell}{$cell_attrb}{$pin}{$key}{$relpin}{$subgroup}{$subgroup_name1}{$_}[$index])) * 100;
                                                            $ats = "[".sprintf("%.04f", $vdiff)."% changes]";

                                                            print "        │    " . $ok . " " . $lib1{cells}{$cell}{$cell_attrb}{$pin}{$key}{$relpin}{$subgroup}{$subgroup_name1}{$_}[$index] . " | " . $lib2{cells}{$cell}{$cell_attrb}{$pin}{$key}{$relpin}{$subgroup}{$subgroup_name2}{$_}[$index] . " $ats \n";

                                                        } else {
                                                            print "        │    " .$no . " " . $lib1{cells}{$cell}{$cell_attrb}{$pin}{$key}{$relpin}{$subgroup}{$subgroup_name1}{$_}[$index] . " | -\n";
                                                        }
                                                    }

                                                }

                                            }

                                        } else {
                                            if ($subgroup eq 'related_pin') {
                                                next;
                                            }
                                            if (defined $lib2{cells}{$cell}{$cell_attrb}{$pin}{$key}{$relpin}{$subgroup}) {
                                                if ($lib1{cells}{$cell}{$cell_attrb}{$pin}{$key}{$relpin}{$subgroup} eq $lib2{cells}{$cell}{$cell_attrb}{$pin}{$key}{$relpin}{$subgroup}) {

                                                    print "        " . $ok . " " . $subgroup . ": " . $lib1{cells}{$cell}{$cell_attrb}{$pin}{$key}{$relpin}{$subgroup} . " | $lib2{cells}{$cell}{$cell_attrb}{$pin}{$key}{$relpin}{$subgroup} \n";
                                                } else {
                                                    print "        " . $no . " " . $subgroup . ": " . $lib1{cells}{$cell}{$cell_attrb}{$pin}{$key}{$relpin}{$subgroup} . " | - \n";
                                                }
                                            }
                                        }

                                    }
                                    
                                }

                            }

                            #foreach my $when (sort keys %{$lib1{cells}{$cell}{$cell_attrb}{$pin}{$key}}) {

                            #    foreach my $subkey (sort keys %{$lib1{cells}{$cell}{$cell_attrb}{$pin}{$key}{$when}}) {

                                    #print $subkey;

                                    #if (ref($lib1{cells}{$cell}{$cell_attrb}{$pin}{$key}{$when}{$subkey}) eq '') {

                                    #    if (defined $lib2{cells}{$cell}{$cell_attrb}{$pin}{$key}{$when}{$subkey}) {
                                    #        my $ats = "";
                                    #        if (looks_like_number($lib1{cells}{$cell}{$cell_attrb}{$pin}{$key}{$when}{$subkey})
                                    #            and looks_like_number($lib2{cells}{$cell}{$cell_attrb}{$pin}{$key}{$when}{$subkey})) {
                                    #            my $vdiff = (($lib2{cells}{$cell}{$cell_attrb}{$pin}{$key}{$when}{$subkey} - $lib1{cells}{$cell}{$cell_attrb}{$pin}{$key}{$when}{$subkey}) / abs($lib1{cells}{$cell}{$cell_attrb}{$pin}{$key}{$when}{$subkey})) * 100;
                                    #            $ats = "[".sprintf("%.04f", $vdiff)."% changes]";
                                    #        }
                                    #        print "       " . $ok . " " . $subkey . ": " . $lib1{cells}{$cell}{$cell_attrb}{$pin}{$key}{$when}{$subkey} . " | $lib2{cells}{$cell}{$cell_attrb}{$pin}{$key}{$when}{$subkey} $ats\n";
                                    #    } else {
                                    #        print "       " . $no . " " . $subkey . ": " . $lib1{cells}{$cell}{$cell_attrb}{$pin}{$key}{$when}{$subkey} . " | - \n";
                                    #    }

                                    #} else {
                                        #print $subkey . "Hash \n";
                                    #}



                             #   }

                            #}

                        }
                    }

                }
            }

        }

    }



    $index = $index + 1;
}


print "\n";