# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Check for any orphaned packages. There should be none in fully
#   supported systems
# Maintainer: QE Core <qe-core@suse.de>
# Tags: poo#19606

use Mojo::Base qw(consoletest);
use testapi;
use utils 'zypper_call';
use version_utils 'is_upgrade';
use Utils::Logging 'export_logs';
use serial_terminal 'select_serial_terminal';

# Performing a DVD/Offline system upgrade cannot update
# all potential packages already present on the SUT
# A subsequent 'zypper dup' is necessary to ensure
# all packages available in the repo are up-to-date
# poo#61829
sub is_offline_upgrade_or_livecd {
    return (!get_var('ONLINE_MIGRATION') && is_upgrade) || get_var('LIVECD');
}

sub to_string {
    return join ',', @_;
}

# Compare detected orphans with whitelisted if any
sub compare_orphans_lists {
    my %args = @_;

    # A trailing or leading whitespace introduced along the path has to be removed
    # Usually it can happen in ssh like consoles (e.g. tunnel-console)
    # Input array items will be modified inside grep
    my @detected_orphans = map { s/^\s+|\s+$//gr } @{$args{zypper_orphans}};
    delete $args{zypper_orphans};
    my @missed_orphans = @detected_orphans;

    my $whitelist = get_var('ZYPPER_WHITELISTED_ORPHANS');
    if ($whitelist) {
        # Remove duplicate packages from the whitelist
        my %wl = map { $_ => 1 } (split(',', $whitelist));
        @missed_orphans = grep { !$wl{$_} } @missed_orphans;
    }

    # Summary
    record_info('Detected orphans', to_string @detected_orphans);
    record_info('Allowed orphans', $whitelist // 'No orphans whitelisted within the test suite');
    record_info('Unexpected orphans', @missed_orphans ? to_string @missed_orphans : 'None', result => @missed_orphans ? 'fail' : 'ok');

    return ((scalar @missed_orphans) == 0);
}

sub run {
    select_serial_terminal;

    record_info((is_offline_upgrade_or_livecd) ? 'Upgrade/LiveCD' : 'No upgrade/LiveCD', 'Upgraded or installed from LIVECD can possibly cause orphans');

    zypper_call('in curl') if (script_run('rpm -qi curl') == 1);
    # Orphans are also expected in JeOS without SDK module (jeos-firstboot, jeos-license and live-langset-data)
    # Save the orphaned packages list to one log file and upload the log, so QA can use this log to report bug
    # Filter out zypper warning messages and release or skelcd packages
    my $orphan_pkgs = script_output(q[zypper --quiet packages --orphaned | tee -a /tmp/orphaned.log | awk -F'|' 'intable && NR>2 {print $3} /^-/ { intable=1 }' | grep -v '\(release-DVD\|release-dvd\|openSUSE-release\|skelcd\)'], timeout => 180, proceed_on_failure => 1,);
    my @orphans = split('\n', $orphan_pkgs);

    if (((scalar @orphans) > 0) && !is_offline_upgrade_or_livecd) {
        compare_orphans_lists(zypper_orphans => \@orphans)
          or die "There have been unexpected orphans detected!";
    }
}

sub post_fail_hook {
    my $self = shift;

    select_console 'log-console';
    (script_run q{test -s /tmp/orphaned.log}) ? export_logs() : upload_logs '/tmp/orphaned.log';
    upload_logs '/var/log/zypper.log';
}

1;
