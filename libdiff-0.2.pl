use warnings;
use strict;
use Data::Dumper;
use Parse::Liberty::Simple;

#our %lib1;



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

my %lib1 = parse("3input.lib");
my %lib2 = parse("ncx-3input.lib");
print Dumper %lib1;
#print "@attrs\n";
#print "Library Name: $lib_name\n";
#print $parser->get_attr_with_value($library_group,"nom_temperature");