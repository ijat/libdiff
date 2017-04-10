use warnings;
use strict;
use Data::Dumper;
use Try::Tiny;
use Term::ANSIColor;
use Scalar::Util qw(looks_like_number);

use Parse::Liberty::Simple;
my $parser = new Parse::Liberty::Simple("3input.lib");
my $parser2 = new Parse::Liberty::Simple("ncx-3input.lib");

my %LANG = ();
# Static language definitions
$LANG{version} = 0.1;
$LANG{title} = "Libdiff";

print "\n$LANG{title} $LANG{version}\n";
print "> Running diff for ${\$parser->name} (primary) and ${\$parser2->name}\n";
do print "> [Warning] You are comparing different library\n" if ($parser->name ne $parser2->name);
print "\n";

print "[Library Attributes]\n";
my @attrs = $parser->attrs;
foreach (@attrs) {
    try {
        my @at2a;
        my $at2 = $parser2->attr($_->name);
        $LANG{library} = $at2;
        if ($_->name eq "voltage_map") {
            my @at2b = $parser2->attrs($_->name);
            foreach my $val (@at2b) {
                push @at2a,$val->value;
            }
            undef @at2b;
        }
        my $ats = colored("[X]", 'bright_red on_black');
        my $t = $_->value;
        if (defined $at2 or @at2a) {
            if ($_->value eq $at2 || grep( /^$t$/, @at2a )) {
                $ats = colored("[/]", 'bright_green on_black');
                if (@at2a) {
                    $at2 = $_->value;
                }
            }
            undef $t;
        } else {
            $at2 = "-";
        }
        print $_->name.': '.$_->value." | ${\$at2} " . $ats . "\n";
    } catch {
        print $_->name." not available in both libs";
    }
}
print "\n";

print "[Cells]\n";
my @cells = $parser->cells;

foreach my $cell (@cells) {
    my $cell2 = $parser2->get_groups('cell', ${\$cell->name});
    $LANG{cell} = $cell->name;
    if (not defined $cell2) {
        print "> ${\$cell->name} is not available on both libs\n";
        next;
    } else {
        print "${\$cell->name}\n";
    }

    # Cell attributes
    my @cell_attrs = $cell->get_attributes;
    foreach my $cell_attr (@cell_attrs) {
        my $cell_attr2 = $cell2->attr($cell_attr->name);
        my $ats;

        if (looks_like_number($cell_attr2) and looks_like_number($cell_attr->value)) {
            my $vdiff = (($cell_attr2 - $cell_attr->value) / abs($cell_attr->value)) * 100;
            $ats = "[" . sprintf("%.04g", $vdiff) . "% changes]";
        } else {
            $ats = colored("[X]", 'bright_red on_black');
            if (defined $cell_attr2) {
                if ($cell_attr->value eq $cell_attr2) {
                    $ats = colored("[/]", 'bright_green on_black');
                }
            } else {
                $cell_attr2 = "-";
            }
        }
        print $cell_attr->name.': '.$cell_attr->value." | ${\$cell_attr2} " . $ats . "\n";
    }

    # Cell nested groups and attributes
    my @cell_groups = $cell->get_groups();
    foreach my $cell_group (@cell_groups) {
        my $cell_group2;

        $LANG{group_type} = $cell_group->type;
        $LANG{group_name} = $cell_group->name;

        if (length $cell_group->name > 0) {
            $cell_group2 = $cell2->get_groups($cell_group->type, $cell_group->name);
        } else {
            $cell_group2 = $cell2->get_groups($cell_group->type);
        }

        my @ggroup2 = $cell_group2->get_groups();
        do print $_->type for @ggroup2;

        if (defined $cell_group2) {
            my $tname = "";
            if (defined $cell_group2->name) {
                $tname = $cell_group2->name;
            }
            print "*" . $cell_group2->type. " (" . $tname . ")\n";
        } else {
            print "*" . $cell_group->type . " (". $cell_group->name .") is not available in both libs\n";
            next;
        }

        # Cell attrb
        my @cell_group_attrs = $cell_group->get_attributes();
        foreach my $cell_group_attr (@cell_group_attrs){
            #print $cell_group_attr->name . ": ". $cell_group_attr->value ."\n";
            my $ats;
            my $cell_group_attr2 = $cell_group2->attr($cell_group_attr->name);

            $ats = colored("[X]", 'bright_red on_black');
            if (defined $cell_group_attr2) {
                if (looks_like_number($cell_group_attr->value) and looks_like_number($cell_group_attr2)) {
                    my $vdiff = (($cell_group_attr2 - $cell_group_attr->value) / abs($cell_group_attr->value)) * 100;
                    $ats = "[" . sprintf("%.04g", $vdiff) . "% changes]";
                } else {
                    if ($cell_group_attr->value eq $cell_group_attr2) {
                        $ats = colored("[/]", 'bright_green on_black');
                    }
                }
            } else {
                $cell_group_attr2 = "-";
            }

            print $cell_group_attr->name.': '.$cell_group_attr->value." | ${\$cell_group_attr2} " . $ats . "\n";
        }

        # Cell groups
        my @groups = $cell_group->get_groups();

        # Pins groups
        if (scalar @groups gt 0) {
            my @subgroups = ();
            my $level = 0;
            my $group2;

            push @{$subgroups[$level]}, @groups;

            do {
                my $group = shift @{$subgroups[$level]};
                #my $xx = $group->type;
                try {
                    $LANG{group_types}{$level} = $group->type;
                }
                do next if (!defined $group);

                if (length $group->name > 0) {
                    my $xx = $group->type;
                    my $xxx = $group->name;

                    for (my $i=0; $i < (scalar keys %{$LANG{group_types}}); $i = $i + 1){
                        if ($i eq 0) {
                            $group2 = $cell_group2->get_groups($LANG{group_types}{$i});
                        } else {
                            $group2 = $group2->get_groups($LANG{group_types}{$i});
                        }
                    }
                } else {
                    $group2 = $cell_group2->get_groups($group->type);
                }

                # indentation
                my $in1 = " " x (2+$level);
                my $in2 = " " x (3+$level);

                print "${\$in1}\[".$group->type.'] ('.$group->name.")\n";

                # Handling values
                my @attrs = $group->get_attributes();
                foreach my $attr (@attrs) {
                    my $ats = colored("[X]", 'bright_red on_black');
                    my $aa = $attr->name;
                    my $cc = $attr->value;
                    my $bb = $attr->type;
                    my $attr2;
                    if ($attr->type ne 'complex') {
                        $attr2 = $group2->attr($attr->name);
                    } else{
                        my @aattr2 = $group2->get_attributes();
                        do print $_->type for @aattr2;
                    }
                    if (defined $attr2) {
                        if (looks_like_number($attr->value) and looks_like_number($attr2)) {
                            my $vdiff = (($attr2 - $attr->value) / abs($attr->value)) * 100;
                            $ats = "[" . sprintf("%.04g", $vdiff) . "% changes]";
                        } else {
                            if ($attr->value eq $attr2) {
                                $ats = colored("[/]", 'bright_green on_black');
                            }
                        }
                    } else {
                        $attr2 = "-";
                    }

                    print $attr->name.': '.$attr->value." | ${\$attr2} " . $ats . "\n";
                }
                #die;
                #print "${\$in2}".$_->name.': '.$_->value."\n" for @attrs;

                my @tgroups = $group->get_groups();
                if (scalar @tgroups gt 0) {
                    $level = $level + 1;
                    push @{$subgroups[$level]}, @tgroups;
                } else {
                    if (scalar @{$subgroups[$level]} eq 0) {
                        undef $LANG{group_types}{$level};
                        $level = $level - 1;
                        pop @subgroups;
                    }
                }
            } while (scalar @subgroups > 0);
        }

    }
    print "END \n";
}