#!/usr/bin/perl

use warnings;
use strict;
use 5.010;

use HTTP::Tiny;
use Data::Dumper qw(Dumper);
use Data::Dumper::Perltidy;
use Getopt::Long qw(GetOptions);
use JSON;
use JSON::XS qw( decode_json );
use WWW::Salesforce::Simple;
use POSIX qw/strftime/;
use Digest::MD5  qw(md5 md5_hex md5_base64);
use PHP::Serialization qw(serialize unserialize);

my $debug;
my $url;
my $task;

my $user='';
my $pass='';
my $token='';

GetOptions(
        'url=s' => \$url,
        'debug' => \$debug,
        'task=s' => \$task,
) or die "Usage: $0 [--debug]  --url URL --task=updated\n";

sub GetLoggingTime {
        my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
        my $nice_timestamp = sprintf ( "%04d%02d%02d %02d:%02d:%02d",$year+1900,$mon+1,$mday,$hour,$min,$sec);
        return $nice_timestamp;
}

if (!$url) {die "Usage: $0 [--debug]  --url URL --task=updated\n";};

my $response = HTTP::Tiny->new->get($url);

if ($response->{success}) {
        # Headers
        while (my ($name, $v) = each %{$response->{headers}}) {
                for my $value (ref $v eq 'ARRAY' ? @$v : $v) {
                        #say "$name: $value";
                }
        }
        if (length $response->{content}) {
                say 'Length: ', length $response->{content};
                my $api_ver = decode_json $response->{content};
                #print $api_ver->[-1]->{version};
                delete $response->{content};
        }
        if ($debug) {
                # Debug
                print Dumper $response;
        }
} else {
        say "Failed: $response->{status} $response->{reasons}";
}

if ($debug) {
        #Debug
        print Dumper($sf);
}

if ($task eq "updated") {
        my @crc_old;
        my @crc;
        my $filename='md5.log';

        my $sforce = WWW::Salesforce::Simple->new(
                'username' => $user,
                'password' => $pass.$token
        );

        open(my $INFILE, "<", $filename) or die "Failed to open file: $!\n";
        chomp(@crc_old = <$INFILE>);
        close $INFILE;
        if ($debug) {
                #Debug
                print Dumper(@crc_old);
        }

        if ($sforce) {
                my $query = 'SELECT  Id FROM User';
                my $res = $sforce->do_query( $query );
                if($debug) {
                        #Debug
                        print Dumper($res);
                }
                $crc[0] = md5_hex(serialize($res));
                $crc[1] = GetLoggingTime();
                open (my $OUTFILE, ">", $filename) or die $!;
                print $OUTFILE $crc[0]."\n";
                close ($OUTFILE);
        }
        if ($debug) {
                #Debug
                print Dumper(@crc);
        }
        if ($crc[0] eq $crc_old[0]) {
                print "DB was not updated. Last update was on $crc_old[1].\n";
                open (my $OUTFILE, ">>", $filename) or die $!;
                print $OUTFILE $crc_old[1];
                close ($OUTFILE);
                exit 0;
        } else {
                print "DB was updated.\n";
                open (my $OUTFILE, ">>", $filename) or die $!;
                print $OUTFILE $crc[1];
                close ($OUTFILE);
                exit 1;
        };
}
