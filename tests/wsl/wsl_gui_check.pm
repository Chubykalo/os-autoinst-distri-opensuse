# SUSE's openQA tests
#
# Copyright 2012-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: edit this here!
# Maintainer: qa-c <qa-c@suse.de>

use Mojo::Base qw(windowsbasetest);
use testapi;
use version_utils qw(is_sle is_opensuse);

# install pattern wsl_gui
# install mousepad
# check that mousepad works

sub run {
    my ($self) = @_;

    assert_screen(['windows-desktop', 'powershell-as-admin-window']);
}

1;
