use warnings;
use strict;
use Data::Dumper;

use Parse::Liberty::Simple;
my $parser = new Parse::Liberty::Simple("3input.lib");

print "Library: ${\$parser->name}\n"; # library name

print "\nLibrary Attributes\n";
my @attrs = $parser->attrs;
print $_->name.': '.$_->value."\n" for @attrs;


print "\nCells\n";
my @cells = $parser->cells;
foreach my $cell (@cells) {
    print "${\$cell->name}\n";
    my @cell_attrs = $cell->get_attributes;
    print "\t".$_->name.': '.$_->value."\n" for @cell_attrs;

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