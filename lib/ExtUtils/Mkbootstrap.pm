package ExtUtils::Mkbootstrap;

# There's just too much Dynaloader incest here to turn on strict vars.
use strict 'refs';

our $VERSION = '7.05_12';

require Exporter;
our @ISA = ('Exporter');
our @EXPORT = ('&Mkbootstrap');

use Config;

our $Verbose = 0;


sub Mkbootstrap {
    my($baseext, @bsloadlibs)=@_;
    @bsloadlibs = grep($_, @bsloadlibs); # strip empty libs

    print "	bsloadlibs=@bsloadlibs\n" if $Verbose;

    # We need DynaLoader here because we and/or the *_BS file may
    # call dl_findfile(). We don't say `use' here because when
    # first building perl extensions the DynaLoader will not have
    # been built when MakeMaker gets first used.
    require DynaLoader;

    rename "$baseext.bs", "$baseext.bso"
      if -s "$baseext.bs";

    if (-f "${baseext}_BS"){
	$_ = "${baseext}_BS";
	package DynaLoader; # execute code as if in DynaLoader
	local($osname, $dlsrc) = (); # avoid warnings
	($osname, $dlsrc) = @Config::Config{qw(osname dlsrc)};
	$bscode = "";
	unshift @INC, ".";
	require $_;
	shift @INC;
    }

    if ($Config{'dlsrc'} =~ /^dl_dld/){
	package DynaLoader;
	push(@dl_resolve_using, dl_findfile('-lc'));
    }

    my(@all) = (@bsloadlibs, @DynaLoader::dl_resolve_using);
    my($method) = '';
    if (@all || (defined $DynaLoader::bscode && length $DynaLoader::bscode)){
	open my $bs, ">", "$baseext.bs"
		or die "Unable to open $baseext.bs: $!";
	print "Writing $baseext.bs\n";
	print "	containing: @all" if $Verbose;
	print $bs "# $baseext DynaLoader bootstrap file for $^O architecture.\n";
	print $bs "# Do not edit this file, changes will be lost.\n";
	print $bs "# This file was automatically generated by the\n";
	print $bs "# Mkbootstrap routine in ExtUtils::Mkbootstrap (v$VERSION).\n";
	if (@all) {
	    print $bs "\@DynaLoader::dl_resolve_using = ";
	    # If @all contains names in the form -lxxx or -Lxxx then it's asking for
	    # runtime library location so we automatically add a call to dl_findfile()
	    if (" @all" =~ m/ -[lLR]/){
		print $bs "  dl_findfile(qw(\n  @all\n  ));\n";
	    } else {
		print $bs "  qw(@all);\n";
	    }
	}
	# write extra code if *_BS says so
	print $bs $DynaLoader::bscode if $DynaLoader::bscode;
	print $bs "\n1;\n";
	close $bs;
    }
}

1;

__END__

=head1 NAME

ExtUtils::Mkbootstrap - make a bootstrap file for use by DynaLoader

=head1 SYNOPSIS

C<Mkbootstrap>

=head1 DESCRIPTION

Mkbootstrap typically gets called from an extension Makefile.

There is no C<*.bs> file supplied with the extension. Instead, there may
be a C<*_BS> file which has code for the special cases, like posix for
berkeley db on the NeXT.

This file will get parsed, and produce a maybe empty
C<@DynaLoader::dl_resolve_using> array for the current architecture.
That will be extended by $BSLOADLIBS, which was computed by
ExtUtils::Liblist::ext(). If this array still is empty, we do nothing,
else we write a .bs file with an C<@DynaLoader::dl_resolve_using>
array.

The C<*_BS> file can put some code into the generated C<*.bs> file by
placing it in C<$bscode>. This is a handy 'escape' mechanism that may
prove useful in complex situations.

If @DynaLoader::dl_resolve_using contains C<-L*> or C<-l*> entries then
Mkbootstrap will automatically add a dl_findfile() call to the
generated C<*.bs> file.

=cut
