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

$LANG{library} = $parser->name;

foreach (@attrs) {
    try {
        my @at2a;
        my $at2 = $parser2->attr($_->name);
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
            my $cell_group_attr2;

            # Default group attr
            $cell_group_attr2 = $cell_group2->attr($cell_group_attr->name);
            $LANG{subgroup_name} = $cell_group_attr->name;
            $LANG{subgroup_value} = $cell_group_attr->value;

            if ($cell_group->type eq "leakage_power") {
                my @temp = $parser2->get_groups('cell', $LANG{cell})->get_groups('leakage_power');
                if ($LANG{subgroup_name} eq 'value' and defined $LANG{when}) {
                    foreach (@temp) {
                        my $when = $_->attr('when');
                        if ($LANG{when} eq $when) {
                            $cell_group_attr2 = $_->attr('value');
                            undef $LANG{when};
                            last;
                        }
                        $cell_group_attr2 = '-';
                    }
                } else {
                    foreach (@temp) {
                        my $when = $_->attr('when');
                        if ($when eq $cell_group_attr->value) {
                            $cell_group_attr2 = $when;
                            $LANG{when} = $when;
                            last;
                        }
                        undef $LANG{when};
                    }
                }
                print "";
            }



            $ats = colored("[X]", 'bright_red on_black');
            if (defined $cell_group_attr2) {
                if (looks_like_number($cell_group_attr->value) and looks_like_number($cell_group_attr2)) {
                    if ($LANG{group_type} eq 'leakage_power') {
                        print "";
                        my $a = $cell_group_attr2;
                        #die;
                    }
                    #die;
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

        #die;
        # Cell subgroups
        my @groups = $cell_group->get_groups();
        # Pins groups
        # VSCODE
    }
    print "END \n";
}