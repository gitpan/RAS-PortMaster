### RAS::PortMaster.pm
### PERL 5 module for accessing a Livingston PortMaster
#########################################################

package RAS::PortMaster;
$VERSION = "1.14";

# The new method, of course
sub new {
   my $class = shift ;
   my $confarray = {} ;
   %$confarray = @_ ;
   bless $confarray ;
}


sub printenv {
   my($confarray) = $_[0];
   print "VERSION = $VERSION\n";
   while (($key,$value) = each(%$confarray)) { print "$key = $value\n"; }
}


sub run_command {
   my($confarray) = shift;
   use Net::Telnet ;
   my($session,@returnlist,$command);

   while ($command = shift) {
      my(@output);
      $session = new Net::Telnet;
      $session->errmode("return");
      $session->open($confarray->{hostname});
      $session->login($confarray->{login},$confarray->{password});
      if ($session->errmsg) {
         warn "RAS::PortMaster ERROR: ", $session->errmsg, "\n"; return();
      }
      $session->print($command);


      local($afterprompt = 0);
      while (1) { # The $afterprompt workaround sucks. The PM sticks random
                  # newlines after pressing Enter at a prompt.
         local($line); $session->print(""); $line = $session->getline ;
         if ($session->errmsg) {
            warn "RAS::PortMaster ERROR: ", $session->errmsg; return();
         }
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
   my(@ports) = &usergrep($confarray,$username);
   return() unless @ports;

   foreach (@ports) { push(@resetcmd,"reset $_"); }
   &run_command($confarray,@resetcmd);

   return(@ports);
}


#############################################################
1;#So PERL knows we're cool
__END__;

=head1 NAME

RAS::PortMaster.pm - PERL Interface to Livingston PortMaster 2

Version 1.14, December 21, 1999

Gregor Mosheh (stigmata@blackangel.net)

=head1 SYNOPSIS

B<RAS::PortMaster> is a PERL 5 module for interfacing with a Livingston PortMaster remote access server. Using this module, one can very easily construct programs to find a particular user in a bank of PMs, disconnect users, get usage statistics, or execute arbitrary commands on a PM.


=head1 PREREQUISITES AND INSTALLATION

This module uses Jay Rogers' B<Net::Telnet module>. If you don't have B<Net::Telnet>, get it from CPAN or this module won't do much for you.

Installation is easy, thanks to MakeMaker:

=over 4

=item 1.

"perl Makefile.PL && make && make test"

=item 2.

If the tests went well, do a "make install"

=item 3.

Check out the EXAMPLES section of this document for examples on how you'd want to use this module.

=back

=head1 DESCRIPTION

At this time, the following methods are implemented:

=over 4

=item creating an object with new

Call the new method while supplying the  "hostname", "login", and "password" hash, and you'll get an object reference returned.

   Example:
      use RAS::PortMaster;
      $foo = new RAS::PortMaster(
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

This does a usergrep, but with a twist: it disconnects the user by resetting the modem on which they're connected. Like usergrep, it returns an array of ports to which the user was connected before they were reset.  This is safe to use if the specified user is not logged in.

Because the PortMaster shows even ports that are not in use, you can userkill a username of "-" to reset all idle modems or "PPP" all users who are still negotiating a connection.

   Examples:
      @foo = $foo->userkill('gregor');
      print "Gregor was on ports @foo - HA HA!\n" if @ports ;

      @duh = $foo->userkill('-');
      print "There were ", scalar(@duh), " ports open.\n";


=item portusage

This returns an array consisting of 2 parts: The 1st element is the number of ports. The rest is a list of users who are currently online.

   Examples:
      @people = $foo->portusage;
      print "There are ", shift(@people), " total ports.\n";
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
   $foo = new RAS::PortMaster(
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
   $foo = new RAS::PortMaster(
      hostname => $_,
      login => '!root',
      password => 'mysecret'
   );

   @ports = $foo->userkill($username);
   (@ports) && print "$_ : Killed ports @ports\n";
}


=head1 CHANGES IN THIS VERSION

1.14     Fixed a leak in run_command  I swear I test this stuff before I upload it, really!

1.13     Added a test suite. Fixed some documentation errors. Added some error handling.

1.12     Bug fixes. Optimized userkill() for better performance.

1.11     The package name got mangled when I zipped everything up, and was thus useless. This has been fixed. Sorry. Also moved the example programs into this document for easy availability. Also fixed an intermittent problem with PERL not liking my use of shift(&routine)

1.00     First release, November 1999.

=head1 BUGS

Since we use this for port usage monitoring, new functions will be added slowly on an as-needed basis. If you need some specific functionality let me know and I'll see what I can do. If you write an addition for this, please send it in and I'll incororate it and give credit.

I make some assumptions about router prompts based on what I have on hand for experimentation. If I make an assumption that doesn't apply to you (e.g. all prompts are /^[a-zA-Z0-9]+\>\s+$/) then it can cause two problems: pattern match timed out or a hang when any functions are used. A pattern match timeout can occur because of a bad password or a bad prompt. A hang is likely caused by a bad prompt. Check the regexps in the loop within run_command, and make sure your prompt fits this regex. If not, either fix the regex and/or (even better) PLEASE send me some details on your prompt and what commands you used to set your prompt. If you have several routers with the same login/password, make sure you're pointing to the right one. A Livingston PM, for example, has a different prompt than a HiPerARC - if you accidentally point to a ARC using RAS::PortMaster, you'll likely be able to log in, but run_command will never exit, resulting in a hang.


=head1 LICENSE AND WARRANTY

Where would we be if Larry Wall were tight-fisted with PERL itself? For God's sake, it's PERL code. It's free!

This software is hereby released into the Public Domain, where it may be freely distributed, modified, plagiarized, used, abused, and deleted without regard for the original author.

Bug reports and feature requests will be handled ASAP, but without guarantee. The warranty is the same as for most freeware:
   It Works For Me, Your Mileage May Vary.

=cut

