# Net::Icecast
#
# Copyright (c) 2000-08 Marino Andr�s <andres@erasme.org>. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

#This package represents the generic icecast object
#which be used to make sources and listeners objects
package Net::Icecast::IceObject;

sub Net::Icecast::IceObject::new
  {
    my $classname = shift;
    my $ice = {};
    bless($ice,$classname);
    my($id,$host,$mountpoint,$connect_for);
    ($id,$host,$mountpoint,$connect_for)=@_;
    $ice->{id}= $id;
    $ice->{host}=$host;
    $ice->{mountpoint}=$mountpoint;
    $ice->{connect_for}= $connect_for;
    return $ice;
  }

#You can add, if you need, other properties to this both objects
package Net::Icecast::Sources;

sub Net::Icecast::Sources::new
  {
    my $classname = shift;
    my ($id,$host,$mountpoint,$connect_for,$ip,$song);
    ($id,$ip,$host,$song,$mountpoint,$connect_for)=@_;

    my $source = Net::Icecast::IceObject->new($id,$host,$mountpoint,$connect_for);

    $source->{ip}=$ip;
    $source->{song}=$song;
    bless($source,$classname);
    return $source;
  }

package Net::Icecast::Listeners;

sub Net::Icecast::Listeners::new
  {
    my $classname = shift;
    my ($id,$host,$mountpoint,$connect_for,$source_id);
    ($host,$mountpoint,$id,$connect_for,$source_id)=@_;

    my $listen = Net::Icecast::IceObject->new($id,$host,$mountpoint,$connect_for);
    $listen->{source_id}=$source_id;
    bless($listen,$classname);
    return $listen;
  }

package Net::Icecast;

use strict;
use vars qw(@ISA @EXPORT @EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION);

use Exporter;
$VERSION = "1.00";
@ISA = qw(Exporter);

@EXPORT = qw(Net::Icecast::new DESTROY set_oper sources listeners selection
	     set modify allow deny kick);

#To be connect you must give the host and the port of the computer
#which contains the server and the password to be ADMIN, and the
#functin gives you a connection to the server ($session->{socket})
#The default proto is tcp
#The answer of the socket must be read in order to empty the socket buffer.
#Return 0 if you gave a bad password
sub Net::Icecast::new
  {
    my $classname = shift;
    my $session = {};
    bless($session,$classname);
    my ($host,$port,$pwd);
    
    unless (@_ == 3) { die "defect of parameters\n"; }
    ($host,$port,$pwd)=@_;

    use IO::Socket;

    $session->{socket} = IO::Socket::INET->new(Proto   =>"tcp",
					       PeerAddr=>$host,
					       PeerPort=>$port,
					       Type    =>SOCK_STREAM)
      or die"Connection impossible\n";
    ($session->{socket})->autoflush(1);
    my $s = $session->{socket};
    print $s "ADMIN $pwd\n\n";
    my $ans = <$s>;
    if( $ans =~ /Bad Password/ )
      {
	return 0;
      }
    return $session;
  }

#The procedure called when the programm is finished
sub DESTROY
  {
    my $session =shift;
    my $s = $session->{socket};
    print $s "quit\n";
    close($s);
  }

#Gives a hash of alls sources
sub sources
  {
    my $session =shift;
    my %hash;
    my $s =$session->{socket};
    print $s "sources\n";
    do
      {
	$_ = <$s>;
	chomp();
	chop();
	if($_ =~ /Id/)
	  {
	    my @tab = split();
	    
	    my $id =@tab[1];
	    chop($id);
	
	    my $i=0;#Be carefull I initialise $i ONCE to 0.
	    while(!($tab[$i] =~ /IP/))
	      {$i++;}
	    my $IP=$tab[++$i];
	    chop($IP);
	     
	    while(!($tab[$i] =~ /Host/))
	      {$i++;}
	    my $HostName=$tab[++$i];
	    chop($HostName);
	  
	    while(!($tab[$i] =~ /Song/))
	      {$i++;}
	    $i++; #To skip 'Title' after 'Song'
	    my $song="";
	    do
	      {
		$i++;
		$song .= $tab[$i]." ";
	      }
	    while(!($tab[$i] =~ /\]/));
	    chop($song); #To cut the last " "
	    chop($song); #To cut "]"
	    
	    while(!($tab[$i] =~ /Mountpoint/))
	      {$i++;}
	    my $mount="";
	    do
	      {
		$i++;
		$mount .= $tab[$i]." ";
	      }
	    while(!($tab[$i] =~ /\]/));
	    chop($mount);
	    chop($mount);
	    
	    while(!($tab[$i] =~ /Connected/))
	      {$i++;}
	    $i++; #To skip 'for' after 'Connected'
	    my $connect="";
	    do
	      {
		$i++;
		$connect .= $tab[$i]." ";
	      }
	    while(!($tab[$i] =~ /\]/));
	    chop($connect);
	    chop($connect);
	    
	    my $source = Net::Icecast::Sources->new($id,$IP,$HostName,$song,$mount,$connect);
	    $hash{$id}=$source;
	  }
      }
    while(!($_ =~ /End of source/));
    return %hash;
  }

#Gives a hash of alls listeners
sub listeners
  {
    my $session =shift;
    my %hash;
    my $s =$session->{socket};
    print $s "listeners\n";
    do
      {
	$_ = <$s>;
	chomp;
	chop;
	if($_ =~ /Id/)
	  {
	    my @tab = split();
	    
	    my $host =@tab[1];
	    chop($host);

	    my $i=0;
	    while(!($tab[$i] =~ /Mountpoint/))
	      {$i++;}
	    my $mount="";
	    do
	      {
		$i++;
		$mount .= $tab[$i]." ";
	      }
	    while(!($tab[$i] =~ /\]/));
	    chop($mount);
	    chop($mount);
	    
	    while(!($tab[$i] =~ /Id/))
	      {$i++;}
	    my $id = $tab[++$i];
	    chop($id);
	    
	    while(!($tab[$i] =~ /Connected/))
	      {$i++;}
	    my $connect="";
	    $i++;#To skip 'for' after 'Connected'
	    do
	      {
		$i++;
		$connect .= $tab[$i]." ";
	      }
	    while(!($tab[$i] =~ /\]/));
	    chop($connect);
	    chop($connect);
	    
	    while(!($tab[$i] =~ /Source/))
	      {$i++;}
	    $i ++;#To skip 'Id' after 'Source'
	    my $source_id ="";
	    do
	      {
		$i ++;
		$source_id .= $tab[$i]." ";
	      }
	    while(!($tab[$i] =~ /\]/));
	    chop($source_id);
	    chop($source_id);
	    
	    my $listener=Net::Icecast::Listeners->new($host,$mount,$id,$connect,$source_id);
	    $hash{$id}=$listener;
	  }
      }
    while(!($_ =~ /End of listener/));
    return %hash;    
  }

#Generic function called by the other functions
sub generic
  {   
    unless (@_ == 3) { die "defect of parameters\n"; }
    
    my $session = shift(@_);
    my $s= $session->{socket};
    my $command =shift(@_);
    my $selection =shift(@_);
    my $rep = $command." ".$selection;

    print $s "$rep\n";
    #If we read a list, we stop a the 'end'
    if($selection =~ /list/)
      {
	my $ans;
	do
	  {
	    $ans = <$s>;
	  }
	while(($ans=~/End/) || ($ans=~/end/));
      }
    else
      {
	my $ans = <$s>;
	chomp($ans);
	chop($ans);
	return $ans;
      }
  }

#Icecast set command 
#The function receives the parameters that the user
#should give to an icecast command 
#And it's the same for the other functions behind
#For more details see the exemple!
#The function "generic" returns you the answer, but only if there's
#one answer, and you can make, if you want, tests on to see if there's
#problems.For me it's not very interesting because the functions
#are very simple and the answers are differents between versions of
#icecast and between the problems the functions have.
sub set
  {   
    my $session =shift;
    unless (@_ == 1) { die "defect of parameters\n"; }
  
    unshift(@_,$session,"set");
    &generic(@_);
  }

#Give the operator_password to be operator
sub set_oper
  {
    my $session =shift;
    unless (@_ == 1) { die "Doesn't contain password\n"; }

    unshift(@_,$session,"oper");
    my $ans = &generic(@_);
    if($ans =~ /Invalid password/)
      {
	return 0;
      }
    return 1;
  }

#Icecast modify command 
sub modify
  {   
    my $session =shift;
    unless (@_ == 1) { die "defect of parameters\n"; }

    unshift(@_,$session,"modify");
    &generic(@_);
  }

#Icecast allow command 
sub allow
  {
    my $session =shift;
    unless (@_ == 1) { die "defect of parameters\n"; }

    #The problem with the command 'allow ... list' is that I can't
    #say to the function when it must stop to read the socket!
    #They should add something like "End of allow ... listing"
    if (@_ =~ /list /) { die "Operation not allowed\n"; }

    unshift(@_,$session,"allow");
    &generic(@_);
  }

#Icecast deny command 
sub deny
  {
    my $session =shift;
    unless (@_ == 1) { die "defect of parameters\n"; }

    #The same problem that we have with allow
    if (@_ =~ /list /) { die "Operation not allowed\n"; }

    unshift(@_,$session,"deny");
    &generic(@_);
  }

#Icecast kick command
sub kick
  {
    my $session =shift;
    unless (@_ == 1) { die "defect of parameters\n"; }

    unshift(@_,$session,"kick");
    &generic(@_);
  }

#Icecast select command 
sub selection
  {   
    my $session =shift;
    unless (@_ == 1) { die "defect of parameters\n"; }
    unshift(@_,$session,"select");
    &generic(@_);
  }

#Icecast alias command
sub alias
  {
    my $session =shift;
    unless (@_ == 1) { die "defect of parameters\n"; }

    unshift(@_,$session,"alias");
    &generic(@_);
  }

#Icecast dir command
sub dir
  {
    my $session =shift;
    unless (@_ == 1) { die "defect of parameters\n"; }

    unshift(@_,$session,"dir");
    &generic(@_);
  }

#Icecast touch command
sub touch
  {
    my $session =shift;
    unless (@_ == 0) { die "defect of parameters\n"; }
    
    my $s = $session->{socket};
    print $s "touch\n";
    my $ans = <$s>;
  }

#Icecast status command
sub status
  {
    my $session =shift;
    unless (@_ == 1) { die "defect of parameters\n"; }

    unshift(@_,$session,"status");
    &generic(@_);
  }

#Icecast debug command
sub debug
  {
    my $session =shift;
    unless (@_ == 1) { die "defect of parameters\n"; }

    unshift(@_,$session,"debug");
    &generic(@_);
  }


1;
__END__


=head1 NAME
  
Net::Icecast - Object oriented functions to run your icecast server.


=head1 SYNOPSIS
  
require Net::Icecast;


=head1 DESCRIPTION

WARNING!!! This module can only be use if your icecast server is older than version 1.3.7

The commands you're used to find in a icecast server are in this module (Not alls but only the ones i needed!).
They can permit you to create programs which configure your icecast server.
If you find that there are importants functions that need to be add,
as i said before, you can modify it under the same terms as Perl itself!
(If you want more details about the functions see
the icecast commands doc) 

So good fun...

=head1 OBJECTS

(be careful with the orthography of the objects, the orthography is the same that the icecast's commands)

=over 3

=item Sources object :
Properties:
id : source's id
host : source's host

=item mountpoint : source's mountpoint
connect for : time of connection of the source 
ip : source's ip
song : song sends by the source

=item Listeners object :
Properties:
id : listener's id
host : listener's host
mountpoint : listener's mountpoint
connect for : time of connection of the listener 
source_id : listener's source id.

=back

=head1 METHODS

Net::Icecast->new($host,$port,$admin_password) : to be connect to the icecast server as an admin

$my_session->sources() : returns you a hash table of alls connected sources

$my_session->listeners() :returns you a hash table of alls connected listeners

$my_session->set("bla bla") : sends "set bla bla\n" to the server

$my_session->modify("bla bla") : sends "modify bla bla\n" to the server

$my_session->allow("bla bla") : sends "allow bla bla\n" to the server, but you can't do "allow ... list"

$my_session->deny("bla bla") : sends "deny bla bla\n" to the server, but you can't do "deny ... list"

$my_session->kick("bla bla") : sends "kick bla bla\n" to the server

$my_session->selection("bla bla") : sends "select bla bla\n" to the server

$my_session->alias("bla bla") : sends "alias bla bla\n" to the server

$my_session->dir("bla bla") : sends "dir bla bla\n" to the server

$my_session->touch("bla bla") : sends "touch bla bla\n" to the server

$my_session->status("bla bla") : sends "status bla bla\n" to the server

$my_session->debus("bla bla") : sends "debug bla bla\n" to the server

=head1 EXAMPLE

First of all you have to run your icecast server, run a source encoder, and a client
(to do this take a look at the doc). Then execute, in a perl programm, this:

#Programme gives you informations about the clients and sources in your icecast server

#!/usr/bin/perl

require Icecast;

my $session = Net::Icecast->new("icecast.computer.host",$port?,"ADMIN_Password");

$session->set_oper("OPER_Password");

my %sources = $session->sources;

print "Sources:\n";

foreach $key (keys %sources)
  {
    #To print the IP address, ...
    print "Id : $key, host : $sources{$key}->{host}\n";
  }

my %clients = $session->listeners;
print "Clients:\n";

foreach $key (keys %clients)
  {
    #To print the source id, the mount point...
    print "Id : $key, host : $clients{$key}->{host}\n";
  }

#And if you want to change the admin_password 

#$session->set("admin_password my_new_password");

#or client_password:

#$session->set("client_password secret_password");

#And you can test the other functions in the same way 
#that you test this one!

#Isn't it very simple to use it :).

=head1 AUTHOR

Andr�s Marino

=cut

