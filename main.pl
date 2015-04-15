#!/usr/bin/env perl
# pget, a Gtk2 threaded file downloader
# License : GPLv3
# Written by Ricky thomson

use strict;
use warnings;
use FindBin qw($Bin);
use threads;
use LWP::Simple;

use Gtk2 qw(-threads-init -init);
use Glib qw(TRUE FALSE);
Glib::Object->set_threadsafe (TRUE);

$|++;
my $VERSION = "0.1";

my $data = $Bin . "/data/";
my $xml = $data . "pget.xml";

my @threads;

# check libglade xml exists
if ( ! -e $xml ) { die "Interface: '$xml' $!"; }

my $builder = Gtk2::Builder->new();
	$builder->add_from_file( $xml );
	$builder->connect_signals( undef );
	
my $window = $builder->get_object( 'window' );
	$window->show();

Gtk2->main(); 
gtk_main_quit();


#### subroutines ####

sub pget_file($$) {
	print "[ !] thread #". (scalar(@threads)+1) ." started\n";
	
	my ($remotefile, $localfile) = @_;
	my $label = $builder->get_object( 'label_status' );
	my $spinner = $builder->get_object( 'spinner' );
	
	my $thread = threads->create(
		sub {
			open my $fh, ">", $localfile;

			my $total = 0;	
				
			Gtk2::Gdk::Threads->enter();
			$spinner->visible(1);
			$spinner->start;
			$label->set_text( "Connecting..." ); 
			Gtk2::Gdk::Threads->leave();
				
			getstore $remotefile, sub {
				my($chunk) = @_;
				$total += length $chunk;
				
				Gtk2::Gdk::Threads->enter();
				$label->set_text( bytes2mb($total) ."MB" ); 
				Gtk2::Gdk::Threads->leave();
				
				print $fh $chunk;
			};
			
			Gtk2::Gdk::Threads->enter();
			$spinner->visible(0);
			$spinner->stop;
			$label->set_text( "Finished!" ); #
			Gtk2::Gdk::Threads->leave();
			
			
		}
		
	);
	
	push (@threads, $thread);
	my $tid = $thread->tid;
	
	while ($thread->is_running) {
		Gtk2->main_iteration while (Gtk2->events_pending);
	}
	
	print "[ !] thread #" .$tid ." finished\n";
}

sub on_button_get_clicked {
	my $entry = $builder->get_object( 'entry_url' )->get_text;
	print $entry . "\n";
	pget_file($entry, "test/out");
}


sub bytes2mb($) {
	my $bytes = shift;
	return sprintf "%.0f",($bytes / (1024 * 1024));
}


sub gtk_main_quit {
	# cleanup and exit
	
	$_->detach for threads->list;
	
	Gtk2->main_quit();	
	exit(0);
}
