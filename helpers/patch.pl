#!/usr/bin/env perl
use FileHandle;
######################################################################
## script to patch strings in binary files.  see patch.pl -h
## for details.
##
## I recommend setting ts=4 in vi
##
######################################################################
$filepos = 0;
$done  = 0;
$replcnt = 0;
$action  = 'replace';
$scheme  = 'search';
$chunksize = 4096;
$occurance = 1;
@args  = ();
$READPOS = 0;
$WRITEPOS = 0;
$shellreturn = 1; # success
$overwrite = 0;
while ($_ = shift(@ARGV)) {
 if (/^-f(.*)$/) {
  $infile = $1 ? $1 : shift;
 } elsif (/^-off=?(.*)$/) {
  $offset = $1 ? $1 : shift;
  $scheme = 'offset';
  $shellreturn = 0;
 } elsif (/^-o(.*)$/) { $oldstring = $1 ? $1 : shift;
 } elsif (/^-n(.*)$/) { $newstring = $1 ? $1 : shift;
 } elsif (/^-s(.*)$/) {
  $oldstring = $1 ? $1 : shift;
  $action = 'search';
 } elsif (/^-d(.*)$/) { $debug = $1 ? $1 : 1;
 } elsif (/^-(\d+)$/) { $occurance = $1;
 } elsif (/^-all$/) { $occurance = 0;
 } elsif (/^-h/) {
  Usage();
  exit;
 } elsif (/^-O/) { $overwrite = 1;
 } elsif (/^-/) {
  print "What's that? [$_].\n";
  exit -1;
 } else { push(@args,$_);
 }
}
foreach (@args) {
 if ($scheme eq 'offset') {
  if (!$infile) {$infile = $_; next;}
  if (!$newstring) { $newstring = $_; next;}
  else {
   print "What's that? [$_].\n";
   exit -1;
  }
 } else {
  if (!$infile)    { $infile = $_; next;}
  if (!$oldstring) { $oldstring = $_; next;}
  if (!$newstring) { $newstring = $_; next;}
  print "What's that? [$_].\n";
  exit -1;
 }
}
if ($debug) {
 print "SCHEME: $scheme\n";
 print "ACTION: $action\n";
 print "INFILE: $infile\n";
 print "OLDSTR: $oldstring\n";
 print "NEWSTR: $newstring\n";
 print "OFFSET: $offset\n";
}
if (!$infile) {
 print "you must supply a file to patch\n";
 Usage();
 exit -1;
}
$outfile = $infile.'.out';
############################################################
# get the mode of the input file (minus the filetype) so I
# can set the mode on the output file, if necessary
# (dunno what this'l do on 32bit perl... probably shouldn't
# try to chmod at all...)
############################################################
#$mode = (stat('/tmp/gp'))[2] & 07777;
$mode = (stat("$infile"))[2] & 07777;
if ($action eq 'replace') {
 if ($scheme eq 'search') {
  if (!$oldstring || !$newstring) {
   print "you must supply old and new strings\n";
   Usage();
   exit -1;
  }
  if (length($oldstring) != length($newstring)) {
   print "you must supply old and new strings\n";
   Usage();
   exit -1;
  }
 } else {
  if (!$newstring) {
   print "you must supply a new string\n";
   exit -1;
  }
 }
}
if (($action eq 'search')&&!$oldstring) {
 print "parameters are missing.\n";
 Usage();
 exit -1;
}
$strlen = length($oldstring) ? length($oldstring) : length($newstring);
if ($scheme eq 'offset') {
 ##############################################################
 # open file, seek to offset, write
 ##############################################################
 $size = -s $infile;
 if ($offset+$strlen>$size) {
  print "that would overwrite the end.\n";
  exit -1;
 }
 if ($overwrite) {
  $fh = new FileHandle "$infile", O_WRONLY;
 } else {
  if (system("cp $infile $outfile")) {
   print "'cp $infile $outfile' failed.\n";
   exit -1;
  } $fh = new FileHandle "$outfile", O_WRONLY;
 }
 binmode($fh);     # for the Bill fans
 seek($fh,$offset,0) || die "seek to offset $offset failed";
 syswrite($fh,$newstring,$strlen) || die "syswrite";
 close($fh);
 exit 1;
}
open(IN,$infile) || die "open to read: $infile";
binmode(IN);     # for the Bill fans
if ($action eq 'replace') {
 print "writing to [".($overwrite ? $infile : $outfile)."]...\n";
 open(OUT,">$outfile") || die "open to write";
 binmode(OUT);    # for the Bill fans
}
$carryover = '';
######################################################################
## the trick here is:
## in order to avoid missing a string that falls right on a chunk
## border, I use index() to test a chunk for the existence of the
## string to be replaced (or searced for).  Then, as long as I'm
## still searching (i.e., I haven't found the string to be replaced),
## when I'm through with a chunk, I write the chunk MINUS a bit to
## the output file.  The length of the bit not written is the length
## of the string to be found.  Then I prefix that bit onto the next
## chunk read so and repeat my index() test.  More or less:
##
##     ========              [chunk]
##           ========        [next chunk]
##   overlap ^^    ========  [next chunk]
##   overlap       ^^
##
## This should work
## in both the single and multiple replacement cases, because in the
## multi-replacement case, assuming the string fell exactly in the bit
## that I hold over, the replacement will happen, then the bit will
## be prefixed, and the string will not match anymore (come to think
## of it, it wouldn't really matter either way).
## There is one anomaly, in the above-mentioned case, the SEARCH
## option would report an occurence of a string twice at the same
## offset. oh well.
######################################################################
TOP: while($chunklen = Read($chunk,$chunksize)) {
 if (!$done) {
  $chunk = $carryover.$chunk;
  $chunklen += length($carryover);
  $carryover = '';
  ##############################################################
  ## index doesn't seem to want to return the real offset within
  ## a scalar when the data is binary, so I must use
  ## substr to actually find the offset.
  ## however, index *does* seem to reliably *find* a substr in
  ## a binary scalar...
  ## *** your milage may vary ***
  ## (I'm using a real unix -- Digital UNIX :-))
  ##############################################################
  if (index($chunk,$oldstring) != -1) {
   #######################
   ## index() found string
   #######################
   $pos = 0;
   while($pos < $chunklen) {
    ##########################################
    ## go through chunk, one byte at a time...
    ##########################################
    $tmp = $chunklen - $pos;
    ####################################################
    ## for a single replacement, I don't have a problem,
    ## but for multiples, I must still check for the
    ## target string being chopped by a chunk boundary
    ####################################################
    if (($tmp < $strlen)&&
     (substr($chunk,$pos,$tmp) eq substr($oldstring,0,$tmp)))
    {
     ###############################################
     ## match was cut by chunk boundary
     ## this _could_ backfire if I were
     ## searching for 'foobar' and the last 3 bytes
     ## of the current chunk were 'foo' and the next
     ## chunk continued with 'foofoofoofoofoofoo...'
     ## till the end but what the hell...
     ###############################################
     if ($debug) {
      print "grabbing a few more bytes...\n";
     }
     $len = Read($smallchunk,$strlen-$tmp);
     if ($len != $strlen-$tmp) {
      print "read failed ",$strlen-$tmp," bytes, dying\n";
      exit -1;
     }
     $chunk .= $smallchunk;
     $chunklen += $len;
     redo;
    }
    if (substr($chunk,$pos,$strlen) eq $oldstring) {
     print "found at ",$filepos+$pos;
     $shellreturn = 0;
     $replcnt++;
     if (($action eq 'replace')&&
      (($occurance == 0)||
       ($replcnt == $occurance)))
     {
      substr($chunk,$pos,$strlen) = $newstring;
      print ", changed.";
      if ($occurance) {  # only one replacement
       $done = 1;
       print "\n";
       next TOP;
      }
     }
     print "\n";
     $pos += $strlen;
    } else {  $pos++;      # no match? goto next byte
    }
   }
  }
  $carryover = substr($chunk,$chunklen - $strlen,$strlen);
  $chunklen -= $strlen;
 }
} continue {
 if ($action eq 'replace') {
  Write(substr($chunk,0,$chunklen),$chunklen) || die "syswrite";
 } $filepos += $chunklen;
}
if ($carryover) {
 Write($carryover,length($carryover));
}
close(IN);
if ($action eq 'replace') {
 close(OUT);
 chmod $mode, $outfile;
 if ($overwrite) {
  rename($outfile,$infile);
 }
}
if ($chunklen < 0) {
 print "error with sysread\n";
}
exit $shellreturn;
##
## my version of sysread and syswrite
## so that I can track file offsets...
##
sub Read {
 my($ret) = sysread(IN,$_[0],$_[1]);
 if ($ret == -1) {
  print "error reading input file\n";
  exit -1;
 }
 if ($debug) {
  print "%% read from offset $READPOS, SIZE=$ret\n";
 }
 $READPOS += $ret;
 $ret;
}
sub Write {
 my($ret) = syswrite(OUT,$_[0],$_[1]);
 if ($ret == -1) {
  print "error writing output file\n";
  exit -1;
 }
 if ($debug) {
  print "%% wrote at offset $WRITEPOS, SIZE=$ret\n";
 }
 $WRITEPOS += $ret;
 $ret;
}
sub Usage {
 print <<_EOF_;
Usage:
patch.pl <filename> <OLD> <NEW>             - Replace <OLD> with <NEW>
patch.pl <filename> -off=<OFFSET> <STRING>  - REPLACE at OFFSET
patch.pl <filename> -s<STRING>              - FIND OFFSET of STRING
OPTIONS:
  -<N>            - replace the Nth occurance of the string (0=all)
                    (default is 1st occurance only)
  -all            - replace all occurances
  -f<filename>    - explicitly specify filename
  -off=<offset>   - explicitly specify offset       ('-off' is required)
  -off <offset>   - same
  -s <string>     - specify search string
  -o <string>     - explicitly specify <oldstring>
  -n <string>     - explicitly specify <newstring>
NOTE: when replacing a string, the lengths of OLD and NEW must be equal
_EOF_
}
