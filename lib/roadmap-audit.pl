#!/usr/bin/env perl
#
# roadmap-audit.pl — audit ROADMAP.md phase bookkeeping. Read-only.
#
# Two upstream defects make the phase checkboxes quietly wrong, and neither
# reports an error (observed in medyour-platform, 2026-08-12):
#
#   1. `gsd-sdk query phase.insert` writes the `### Phase N:` detail section
#      but NOT the top-of-file checklist row, nor the Progress-table row.
#      `phase.complete` then has nothing to tick and no-ops in silence.
#
#   2. `phase.complete` ticks the FIRST unticked line matching
#      /- \[ \].*Phase\s+<N>[:\s]/i (roadmap.cjs). That `.*` walks straight
#      past the row's own number, so a row that mentions ANOTHER phase steals
#      that phase's tick — e.g. a row ending "blocks Phase 13 (M1)" absorbs
#      Phase 13's completion.
#
# Emits one finding per line, pipe-separated, for the caller to render:
#   TICK|<phase>|<what it would actually tick>
#   NOROW|<phase>
#   NOPROG|<phase>
# Silence means clean. Exit status is always 0 — the caller counts the lines.

use strict;
use warnings;

my $path = shift or exit 0;
open my $fh, '<', $path or exit 0;
my @L = <$fh>;
close $fh;
chomp @L;

# A checklist row is the bolded form: "- [ ] **Phase 13: ...". Its OWN phase is
# the bolded number, never a number mentioned later in the prose.
sub own_phase {
    my ($line) = @_;
    return $1 if $line =~ /\*\*Phase\s+(\d+(?:\.\d+)?)\s*:/;
    return undef;
}

my (@detail_phases, %row_for, @all_boxes, %progress);
my $in_table = 0;

for my $i (0 .. $#L) {
    my $l = $L[$i];

    push @detail_phases, $1
        if $l =~ /^\#{2,4}\s*Phase\s+(\d+(?:\.\d+)?)\s*:/;

    # Every checkbox line, bolded or not — the tick regex sees them all, and a
    # bare "- [ ] TBD (run /gsd:plan-phase 29 ...)" placeholder is a real target.
    if ($l =~ /^\s*-\s*\[([ x])\]/) {
        my $tick = $1;
        my $own  = own_phase($l);
        push @all_boxes, { idx => $i, tick => $tick, own => $own, text => $l };
        $row_for{$own} //= $i if defined $own;
    }

    $in_table = 1 if $l =~ /^\|\s*Phase\s*\|/i;
    $in_table = 0 if $in_table && $l !~ /^\|/;
    $progress{$1} = 1
        if $in_table && $l =~ /^\|\s*(\d+(?:\.\d+)?)[.\s]/;
}

my %seen;
my @phases = grep { !$seen{$_}++ } @detail_phases;

for my $p (@phases) {
    # 1. No checklist row at all — phase.complete will tick nothing.
    unless (exists $row_for{$p}) {
        print "NOROW|$p\n";
    }

    # 2. Not in the Progress table.
    print "NOPROG|$p\n" unless exists $progress{$p};

    # 3. Would the tick land on the right row? Only meaningful while the
    #    phase's own row is still unticked — a completed phase never ticks again.
    my ($mine) = grep { defined $_->{own} && $_->{own} eq $p } @all_boxes;
    next if $mine && $mine->{tick} eq 'x';

    my $num = $p;
    $num =~ s/\./\\./g;
    my $re = qr/-\s*\[ \]\s*.*Phase\s+0*$num[:\s]/i;

    my ($hit) = grep { $_->{tick} eq ' ' && $_->{text} =~ $re } @all_boxes;
    next unless $hit;                       # nothing to tick; NOROW covers it
    next if defined $hit->{own} && $hit->{own} eq $p;   # correct target

    my $what = defined $hit->{own}
        ? "Phase $hit->{own}'s"
        : do {
            my $t = $hit->{text};
            $t =~ s/^\s*-\s*\[ \]\s*//;
            'a non-phase line, "' . substr($t, 0, 40) . '"';
          };
    print "TICK|$p|$what\n";
}
