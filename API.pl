#!/usr/bin/perl

#Modules
use warnings;
use strict;
use v5.10.1;
use Getopt::Long qw(GetOptions);
use Switch;
use Data::Dumper;
use HTTP::Tiny;
use JSON;
use Time::Format qw/%time/;
use Time::HiRes qw/gettimeofday/;
#Variables
## Input Parameters
my $debug;
my $task;
my $home_campus;
#Service
my $response;
#Constants
my $directory = '/usr/lib/zabbix/externalscripts/';
my $requiestID = 'abcdef12-3456-7890-fedc-ba0987654321';
my $transactionID = '12345678-90ab-cdef-0987-654321fedcba';


my @campus=("UCM","UCI","UCLA","UCD","UCSD","UCSC","USB","UCR","UCSB","UCSF");

GetOptions (
        "debug" => \$debug,
        "task=s" => \$task,
        "campus=s" => \$home_campus,
) or noOptions();

if ($task eq "logging") {
    #donothing
} elsif (($task eq "coursecatalog") && ($home_campus)) {
    #donothing
} elsif (($task eq "courses") && ($home_campus)) {
    #donothing
} else {
    noOptions();    
}

if ($home_campus) {
    if ($home_campus =~ /^[ \p{Uppercase}]+$/) { } else { noOptions(); }
}

sub currYear {
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
    $year = $year+1900;
    return $year;
}

sub currTerm {
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
    my $monthnum = $mon + 1;
    my $term;
    given ($monthnum) {
        when (($monthnum > 2) && ($monthnum < 6)) { $term = "Spring"; }
        when (($monthnum > 5) && ($monthnum < 9)) { $term = "Summer"; }
        when (($monthnum > 8) && ($monthnum < 12)) { $term = "Fall"; }
        default { $term = "Winter"; }
    }
    return $term;
}

sub noOptions {
    die "Usage: $0 [--debug] --task=eligibility|pii|calendar|coursecatalog|courses|logging --campus=UCM|UCI|UCLA|UCD|UCSD|UCSC|USB|UCR|UCSB|UCSF\n";
}

sub getLoggingTime {
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
    my $nice_timestamp = sprintf ( "%04d-%02d-%02dT%02d:%02d:%02d.235",
                                   $year+1900,$mon+1,$mday,$hour,$min,$sec);
    return $nice_timestamp;
}

sub getByCampus {
    my ($cmp, $url, $urlAPIv2, $client_id, $client_secret, $home_campus) = @_;
    my @campus = @{ $cmp };
    my $response;
    foreach my $camp (@campus) {
            if (($camp eq "UCM")||($camp eq "UCI")) {
                #No API on HUB
            } elsif (($camp eq $home_campus) && ($camp ne "UCB")) {
                #API1.0
                my $urlFinal = $url.$home_campus;
                $response = httpRequest($urlFinal, $client_id, $client_secret);
            } elsif (($camp eq $home_campus) && ($camp eq "UCB")) {
                #API2.0
                my $urlFinal = $urlAPIv2;
                $response = httpRequest($urlFinal, $client_id, $client_secret);
            } else {
                #API was not tested.
            }
    }
    return $response;
}

sub httpRequest {
    my ($urlFinal, $client_id, $client_secret) = @_;
    my $response;
    my $json = encode_json {};
    my $http = HTTP::Tiny->new(
            default_headers => {'client_id' => $client_id, 'client_secret' => $client_secret,
                                'transactionId' => $transactionID, 'requestId' => $requiestID, 'timestamp' => getLoggingTime()},
            agent => 'Google Chrome',
    );
    $response = $http->request('GET', $urlFinal);    
    if ($debug) {
        print Dumper($response);
    }
    if ($response->{success}) { print "API alive.\n";} else { print "API dead.\n";}
}

switch($task) {
        case "eligibility" {
                my $url='https://cces-hub-outbound-prod1.cloudhub.io/api/1.0/Eligibility?studentid=123456789&year=2018&term=Summer&home_campus=';
        }
        case "pii" {
                my $url='https://mocksvc.mulesoft.com/mocks/2d7607f7-ba58-455f-921e-21d37716de5c/PII?studentid=123456789&home_campus=';
        }
        case "calendar" {
                my $url='https://cces-hub-outbound-prod1.cloudhub.io/api/1.0/Calendar';
        }
        case "coursecatalog" {
                my $url='https://cces-hub-outbound-prod1.cloudhub.io/api/1.0/courseCatalog?term='.currTerm().'&year='.currYear().'&campus=';
                my $urlAPIv2='https://cces-hub-outbound-prod1.cloudhub.io/api/1.0/courseCatalog?term='.currTerm().'&year='.currYear().'&campus=';
                $response = getByCampus(\@campus, $url, $urlAPIv2, $client_id, $client_secret, $home_campus);             
        }
        case "courses" {
                my $url = 'https://cces-hub-outbound-prod1.cloudhub.io/api/2.0/courses/'.currYear().'/'.currTerm().'?campus='.$home_campus;
                $response = httpRequest($url, $client_id, $client_secret);
        }
        case "logging" {
                my $toDate = getLoggingTime();
                my $fromDate = getLoggingTime();
                my $url = 'https://cces-hub-outbound-prod1.cloudhub.io/api/1.0/logging?requestId='.$requiestID.'&transactionId='.$transactionID.'&toDateTime='.$toDate.'&fromDateTime='.$fromDate;
                $response = httpRequest($url, $client_id, $client_secret);
        }
}
