### RAS::PortMaster.pm
### PERL 5 module for accessing a Livingston PortMaster
#########################################################

package RAS::PortMaster;
$VERSION = "1.11";

# The new method, of course
sub new {
   my $class = shift ;
   my $confarray = {} ;
   %$confarray = @_ ;
   bless $confarray ;
}


sub printenv {
   my($confarray) = $_[0];
   while (($key,$value) = each(%$confarray)) { print "$key = $value\n"; }
}


sub run_command {
   my($confarray) = shift;
   use Net::Telnet ;
   my($session, @output,$command);

   while ($command = shift) {
      $session = new Net::Telnet;
      $session->open($confarray->{hostname});
      $session->login($confarray->{login},$confarray->{password});
      $session->print($command);

      local($afterprompt = 0);
      while (1) { # The $afterprompt workaround sucks. The PM sticks random
                  # newlines after pressing Enter at a prompt.
         local($line); $session->print(""); $line = $session->getline ;
         if ($line =~ /^\w+\>\s+/) { $session->print("quit"); $session->close; last; }
         if ($line =~ /^-- Press Return for More --/) { $afterprompt = 1; next; }
         if ($afterprompt && ($line =~ /^\s*$/)) { next; }
         $afterprompt = 0;
         push(@output, $line);
      }

      # Net::Telnet to the PM leaves the echoed command and a line
      shift(@output); shift(@output);
      push(@returnlist, \@output);
   } # end of shifting commands

   # We're returning a list of references to lists.
   # Each ref points to an array containing the returned text
   # from the command, and the list of refs corresponds
   # to the list of commands we were given
   return(@returnlist);
} # end of run_command


sub usergrep {
   my($confarray) = $_[0];
   my($username) = $_[1]; return unless $username;
   my(@foo) = &run_command($confarray,'sho ses');
   my($output) = shift(@foo);
   my(@ports);

   foreach (@$output) {
      next unless /^(S\d+)\s+$username\s+/;
      push(@ports, $1);
   }
   return(@ports);
}


sub portusage {
   my($confarray) = $_[0];
   my(@foo) = &run_command($confarray,'sho ses');
   my($output) = shift(@foo);
   my(@users);
   my($totalports); $totalports = 0;

   foreach (@$output) {
      next unless /^S\d+\s+(\S+)\s+/;
      $totalports++;
      next if ($1 =~ /^PPP|\-$/);
      push(@users, $1);
   }
   return($totalports,@users);
}


sub userkill {
   my($confarray) = $_[0];
   my($username); $username = $_[1]; return unless $username;
   my(@foo) = &usergrep($confarray,$username);
   my($ports) = shift(@foo);
   foreach (@$ports) { &run_command($confarray,"reset $_"); }
   return(@ports);
}


#############################################################
1;#So PERL knows we're cool
__END__;

=head1 NAME

RAS::PortMaster.pm - PERL Interface to Livingston PortMaster 2

Version 1.11, November 25, 1999

Gregor Mosheh (stigmata@blackangel.net)

=head1 SYNOPSIS

B<RAS::PortMaster> is a PERL 5 module for interfacing with a Livingston 
PortMaster remote access server. Using this module, one can very easily 
construct programs to find a particular user in a bank of PMs, disconnect 
users, get usage statistics, or execute arbitrary commands on a PM.


=head1 PREREQUISITES AND INSTALLATION

This module uses Jay Rogers' B<Net::Telnet module>. If you don't have 
B<Net::Telnet>, get it from CPAN or this module won't do much for you.

Installation is easy, thanks to MakeMaker:

=over 4

=item 1.

"perl Makefile.PL && make && make install"

=item 2.

Check out the Example directory for examples on how you'd want to use this module.

=back

=head1 DESCRIPTION

At this time, the following methods are implemented:

=over 4

=item creating an object with new

Call the new method while supplying the  "hostname", "login", and "password" hash, and you'll get an object reference returned.

   Example:
      use RAS::PortMaster;
      $foo = new PortMaster(
         hostname => 'dialup1.example.com',
         login => '!root',
         password => 'mysecret'
      );


=item printenv

This is for debugging only. It prints to STDOUT a list of its configuration hash, e.g. the hostname, login, and password. The printenv method does not return a value.

   Example:
      $foo->printenv;


=item run_command

This takes a list of commands to be executed on the PortMaster, connects to the PM and executes the commands, and returns a list of references to arrays containg the text of each command's output. 

Repeat: It doesn't return an array, it returns an array of references to arrays. Each array contains the text output of each command. Think of it as an array-enhanced version of PERL's `backtick` operator.

   Example:
      # Execute a command and print the output
      $command = 'sho ses';
      ($x) = $foo->run_command($command);
      print "Output of command \'$command\':\n", @$x ;

   Example:
      # Execute a string of commands
      # and show the output from one of them
      (@output) = $foo->run_command('reset S15','sho ses');
      print @$output[1] ;


=item usergrep

Supply a username as an argument, and usergrep will return an array of ports on which that user was found. Internally, this does a run_command("sho ses") and parses the output.

   Example:
      @ports = $foo->usergrep('gregor');
      print "User gregor was found on ports @ports\n";


=item userkill

This does a usergrep, but with a twist: it disconnects the user by resetting the modem on which they're connected. Like usergrep, it returns an array of ports to which the user was connected before they were reset.  This is safe to use if the specified user is not logged in.  Also, you can userkill a username of "-" to reset all idle modems or "PPP" all users who are still negotiating a connection.

   Examples:
      @foo = $foo->userkill('gregor');
      print "Gregor was on ports @foo - HA HA!\n" if @ports ;

      @duh = $foo->userkill('-');
      print "There were ", scalar(@duh), " ports open.\n";


=item portusage

This returns an array consisting of 2 items: The 1st element is the number of ports. The rest is a list of users who are currently online.

   Examples:
      ($ports,@people) = $foo->portusage;
      print "There are $ports total ports.\n";
      print "There are ", scalar(@people), "people online.\n";
      print "They are: @people\n";

      ($ports,@people) = $foo->portusage;
      print "Ports free: ", $ports - scalar(@people), "\n";
      print "Ports used: ", scalar(@people), "\n";
      print "Ports total: ", $ports, "\n";


=head1 EXAMPLE PROGRAMS

portusage.pl - Summarizes port usage on a bank of PMs

use RAS::PortMaster;
$used = $total = 0;
foreach ('pm1.example.com','pm2.example.com','pm3.example.com') {
   $foo = new RAS::PortMaster(
      hostname => $_,
      login => '!root',
      password => 'mysecret'
   );

   local(@ports,$ports);
   ($ports,@ports) = $foo->portusage;
   $total += $ports;
   $used += scalar(@ports);
}

print "$used out of $total ports are in use.\n";

#####

usergrep.pl - Locate a user on a bank of PMs

($username) = @ARGV;
die "Usage: $0 <username>\nFinds the specified user.\n" unless $username ;

use RAS::PortMaster;

foreach ('pm1.example.com','pm2.example.com','pm3.example.com') {
   $foo = new PortMaster(
      hostname => $_,
      login => '!root',
      password => 'mysecret'
   );

   @ports = $foo->usergrep($username);
   (@ports) && print "Found user $username on $_ ports @ports\n";
}

#####

userkill.pl - Kick a user off a bank of PMs

($username) = @ARGV;
die "Usage: $0 <username>\nDisconnects the specified user.\n" unless $username ;

use RAS::PortMaster;

foreach ('pm1.example.com','pm2.example.com','pm3.example.com') {
   $foo = new PortMaster(
      hostname => $_,
      login => '!root',
      password => 'mysecret'
   );

   @ports = $foo->userkill($username);
   (@ports) && print "$_ : Killed ports @ports\n";
}


=head1 CHANGES IN THIS VERSION

1.11     The package name got mangled when I zipped everything up, and was thus useless. This has been fixed. Sorry. Also moved the example programs into this document for easy availability. Also fixed an intermittent problem with PERL not liking my use of shift(&routine)

1.00     First release, November 1999.

=head1 BUGS

This is my first try at doing PERL 5 stuff, having been satisfied for so many years with using only the PERL 4 features. Though this module seems to work without any problems, the code is probably kinda weak in places and could stand optimization. Any suggestions will be appreciated and credit will be given.

I work for an ISP where all user management is done via RADIUS. As such, we have no use for the user management functions of the PM. If you need such code, I may work on it in my spare time. Alternately, you can write it yourself and send it in and I'll gladly incorporate it and give credit. And there's always the run_command method.


=head1 LICENSE AND WARRANTY

Where would we be if Larry Wall were tight-fisted with PERL itself? For God's sake, it's PERL code. It's free!

This software is hereby released into the Public Domain, where it may be freely distributed, modified, plagiarized, used, abused, and deleted without regard for the original author.

Bug reports and feature requests will be handled ASAP, but without guarantee. The warranty is the same as for most freeware:
   It Works For Me, Your Mileage May Vary.

=cut

