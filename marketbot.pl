#https://www.playinitium.com/messager?markers=
use LWP::UserAgent::Determined;
use login;
use Time::HiRes qw { gettimeofday };
use strict;
use warnings;
use Storable;
$SIG{INT} = sub { die(); };
local $| = 1;
#EMAIL AND PASSWORD NEEDED
my $email = '';
my $password = "";
sub processMarkers($);
loginInit($email, $password);

sub constructReply($)
{
my %marketDB = %{retrieve('market.db')};
my $input = shift;
$input =~ s/\\//g;
print "Received input: $input\n";
my @searchResults = ();
if($input !~ m/;/)
{
    my $query = $input;
    my $maxDex = 99;
    my $minMaxDamage = 999;
    my $maxPrice = 9999999;
    my $itemName;

    if($query =~ m/item:"(.*?)"/)
    {
        $itemName = $1;
    }
    if($query =~ m/dex:([ ]?)(\d{1,2})/)
    {
        $maxDex = $2;
    }
    if($query =~ m/mindmg:([ ]?)(\d{1,4})/)
    {
        $minMaxDamage = $2;
    }
    if($query =~ m/maxprice:([ ]?)(\d{1,10})/)
    {
        $maxPrice = $2;
    }

    foreach my $key (keys %marketDB)
    {
        if($key =~ m/$itemName/i)
        {
            $itemName = $key;
            foreach my $dexKey (keys %{$marketDB{$itemName}})
            {
                if($dexKey <= $maxDex || !$dexKey)
                {
                    foreach my $itemIdKey (keys %{$marketDB{$itemName}{$dexKey}})
                    {
                        if($minMaxDamage >= $marketDB{$itemName}{$dexKey}{$itemIdKey}{"maxDmg"} || !$marketDB{$itemName}{$dexKey}{$itemIdKey}{"maxDmg"})
                        {
                            my $itemPrice = $marketDB{$itemName}{$dexKey}{$itemIdKey}{"itemPrice"};
                            $itemPrice =~ s/,//;
                            if($itemPrice <= $maxPrice)
                            {
				my $reply;
                                my $itemPrice = $marketDB{$itemName}{$dexKey}{$itemIdKey}{"itemPrice"};
                                my $characterName = $marketDB{$itemName}{$dexKey}{$itemIdKey}{"characterName"};
                                $reply = "Item\($itemIdKey\) @ $characterName\'s shop || $itemPrice gold";
                                if($marketDB{$itemName}{$dexKey}{$itemIdKey}{"maxDmg"})
                                {
                                    my $maxDmg = $marketDB{$itemName}{$dexKey}{$itemIdKey}{"maxDmg"};
                                    $reply = $reply . " || maxdmg: $maxDmg";
                                }
                                else
                                {
                                }
				return $reply;
                            }
                        }
                    }
                }
            }
        }
    }
}
}

my @repliedMarkers = ();

my %Users;

my $cookie_jar = HTTP::Cookies->new(
    file => "initium-cookie.dat",
    autosave => 1,
    ignore_discard=> 1,
    ) or die "Unable to access cookie file: $!";
my $browser = LWP::UserAgent::Determined->new( requests_redirectable => [ 'GET', 'HEAD', 'POST' ] );
$browser->cookie_jar($cookie_jar);
$browser->timing("15,30,90");
$browser->agent("Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/52.0.2743.116 Safari/537.36");
my $epochLastChecked = int ( (gettimeofday * 1000) - 10000 ); 
while(1)
{
    my $url = "http://playinitium.com/messager?markers=";
    my $response = $browser->get($url);
    if($response->is_success)
    {
        my $content = $response->decoded_content;
        while($content =~ m/\{"mode":null,"code":"LocationChat","nickname":"(.*?)","nickNameStyled":"(.*?)","characterId":(\d{14,18}?),"message":"(.*?)","marker":(\d{8,16}?),"createdDate":(\d{8,16}?)\}/gi)
        {
            my $marker = $5;
            my $message = $4;
            my $nickname = $1;
            if($message =~ m/;/)
            {
                next;
            }
            if($marker > $epochLastChecked)
            {
                my $received = 0;
                foreach(@repliedMarkers)
                {
                    if($_ eq $marker)
                    {
                        $received = 1;
                    }
                }
                if($received == 0)
                {
                    print "$nickname: $message\n";
                    push(@repliedMarkers, $marker);
                    if($message =~ m/^\.search (.*)/ && ($Users{"$nickname"}{"LastReplied"} <= ($epochLastChecked - 50000)))
                    {
                        $Users{"$nickname"}{"LastReplied"} = $epochLastChecked;
		    	print "Setting last reply to ".$Users{"$nickname"}{"LastReplied"}."\n";
                        my $postMarkers = '"'."$epochLastChecked,$epochLastChecked,null,$epochLastChecked,$epochLastChecked,null,".'"';
                        my $query = $1;
			my $messageReply = constructReply($query);
                        print "\t- Replying";
                        my $replyurl = "http://playinitium.com/messager";
                        my $reply = $browser->post($url,
                        [
                        "channel" => "LocationChat",
                        "markers" => $postMarkers,
                        "message" => "$messageReply"
                        ]);
                        if($reply->is_success)
                        {
                            print "\tPosted reply ";
                        }
                        else
                        {
                            print "\tReply failed: ".$response->content.$response->status_line."\n";
                        }
                    }
                }
            }
        }
    } else { print $response->decoded_content.$response->status_line; }
    sleep(3);
    $epochLastChecked = int ( ( gettimeofday * 1000) - 10000 );
}

