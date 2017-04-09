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

    my @cell_groups = $cell->get_groups();
    foreach my $cell_group (@cell_groups) {
        print "\t\t[".$cell_group->type . "] (" . $cell_group->name . ")\n";
        my $cgn = "\t\t[".$cell_group->type . "] (" . $cell_group->name . ")\n";
        # Cell attrb
        my @cell_group_attrs = $cell_group->get_attributes();
        print "\t\t\t".$_->name.': '.$_->value."\n" for @cell_group_attrs;

        # Cell groups
        my @groups = $cell_group->get_groups();
        #push @{$subgroups[$level]}, @groups;
        #print $_->type . "\nlalalala" for @groups;

        # Pins groups
        if (scalar @groups gt 0) {
            my @subgroups = ();
            my $level = 0;

            push @{$subgroups[$level]}, @groups;

            do {
                my $group = shift @{$subgroups[$level]};
                do next if (!defined $group);

                # indentation
                my $in1 = "\t" x (3+$level);
                my $in2 = "\t" x (4+$level);

                print "${\$in1}\[".$group->type.'] ('.$group->name.")\n";

                my @attrs = $group->get_attributes();
                print "${\$in2}".$_->name.': '.$_->value."\n" for @attrs;

                my @tgroups = $group->get_groups();
                if (scalar @tgroups gt 0) {
                    $level = $level + 1;
                    push @{$subgroups[$level]}, @tgroups;
                } else {
                    if (scalar @{$subgroups[$level]} eq 0) {
                        $level = $level - 1;
                        pop @subgroups;
                    }
                }
            } while (scalar @subgroups > 0);
        }
    }

    print "END \n";
}

#print "@attrs\n";
#print "Library Name: $lib_name\n";
#print $parser->get_attr_with_value($library_group,"nom_temperature");