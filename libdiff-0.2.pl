use warnings;
use strict;
use Data::Dumper;
use Parse::Liberty::Simple;

our %lib1;

my $parser = new Parse::Liberty::Simple("3input.lib");

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

                # indentation
                my $in1 = "\t" x (3+$level);
                my $in2 = "\t" x (4+$level);

                print "${\$in1}\[".$group->type.'] ('.$group->name.")\n";

                my @attrs = $group->get_attributes();
                foreach (@attrs) {
                    if ($level eq 0) {
                        if ($group->type eq 'internal_power') {
                            my $temp = $group->attr('when');
                            $temp =~ s/"//g;
                            $lib1{cells}{$cell->name}{$cell_group->type}{$cell_group->name}{$group->type}{$temp}{$_->name} = $_->value;
                        } elsif ($group->type eq 'timing') {
                            my $temp = $group->attr('related_pin');
                            $temp =~ s/"//g;
                            $lib1{cells}{$cell->name}{$cell_group->type}{$cell_group->name}{$group->type}{$temp}{$_->name} = $_->value;
                        }
                        else {
                            $lib1{cells}{$cell->name}{$cell_group->type}{$cell_group->name}{$group->type}{$_->name} = $_->value;
                        }
                    } else {
                        my $lastgroup = $lastgrouptype[-1];
                        if ($lastgroup->type eq 'internal_power') {
                            my $temp = $lastgroup->attr('when');
                            $temp =~ s/"//g;
                            $lib1{cells}{$cell->name}{$cell_group->type}{$cell_group->name}{$lastgroup->type}{$temp}{$group->type}{$group->name}{$_->name} = $_->value;

                        } elsif ($lastgroup->type eq 'timing') {
                            my $temp = $lastgroup->attr('related_pin');
                            $temp =~ s/"//g;
                            $lib1{cells}{$cell->name}{$cell_group->type}{$cell_group->name}{$lastgroup->type}{$temp}{$group->type}{$group->name}{$_->name} = $_->value;
                        }
                        else {
                            $lib1{cells}{$cell->name}{$cell_group->type}{$cell_group->name}{$lastgroup->type}{$group->type}{$group->name}{$_->name} = $_->value;
                        }
                    }

                    #print $group->type . "\n";
                    #$lib1{cells}{$cell->name}{$cell_group->type}{$cell_group->name}{$group->type}{$group->name}{$_->name} = $_->value;
                    #$lib1{cells}{$cell->name}{$group->type}{$group->name}{$_->name} = $_->value;
                }
                #print "${\$in2}".$_->name.': '.$_->value."\n" for @attrs;

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

    print "END \n";
}

#Replace a string without using RegExp.
sub str_replace {
    my $replace_this = shift;
    my $with_this  = shift;
    my $string   = shift;

    my $length = length($string);
    my $target = length($replace_this);

    for(my $i=0; $i<$length - $target + 1; $i++) {
        if(substr($string,$i,$target) eq $replace_this) {
            $string = substr($string,0,$i) . $with_this . substr($string,$i+$target);
            return $string; #Comment this if you what a global replace
        }
    }
    return $string;
}

print Dumper %lib1;
#print "@attrs\n";
#print "Library Name: $lib_name\n";
#print $parser->get_attr_with_value($library_group,"nom_temperature");