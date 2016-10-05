use login;
use Storable;
use strict;
use warnings;
use Time::HiRes qw ( usleep );
use Data::Dumper qw(Dumper);
my %marketDB;
#EMAIL AND PASSWORD NEEDED:
loginInit('', '');
$SIG{'INT'} = sub { print Dumper \%marketDB; die(); };
my $cookie_jar = HTTP::Cookies->new(
    file => "initium-cookie.dat",
    autosave => 1,
    ignore_discard=> 1,
    ) or die "Unable to access cookie file: $!";
    my $browser = LWP::UserAgent::Determined->new( requests_redirectable => [ 'GET', 'HEAD', 'POST' ] );
    $browser->cookie_jar($cookie_jar);
    $browser->timing("1,3,6");
    $browser->agent("Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/52.0.2743.116 Safari/537.36");
    my $currentlocation;
    my $verify;

    print "[+] Checking our current location\n";
    my $url = "http://playinitium.com/main.jsp";
    my $response = $browser->get($url) or die;

    #retrieve our current location
    if($response->is_success)
    {
        if($response->decoded_content =~ m/location above-page-popup'><a href='main.jsp'>(.*)<\/a><\/div>/)
        {
            $currentlocation = $1;      
        } else { die "Couldn't get current location\n"; }
        if($response->decoded_content =~ m/window.verifyCode = "(.*)"/)
        {
            $verify = $1;
        } else { die "Couldn't get verify\n"; }
                                
    } else { die $response->status_line; }

if(!($currentlocation eq "Aera"))
{
  die("Not in Aera\n");
}


    $url = "https://www.playinitium.com/locationmerchantlist.jsp";
    $response = $browser->get($url);
    if($response->is_success)
    {
	my $content = $response->decoded_content;
	while($content =~ m/viewStore\((\d{14,18})\)'><div class='main-item'>([a-zA-Z0-9]{3,30}) -/sg)
	{
		my $characterId = $1;		
		my $characterName = $2;
		print "Match found: store id $1 nickname $2\n";
		my $url2 = "https://www.playinitium.com/odp/ajax_viewstore.jsp?characterId=".$1;
		my $response2 = $browser->get($url2);
		my $content2 = $response2->decoded_content;
		while($content2 =~ m/viewitemmini.jsp\?itemId=(\d{14,18})'><img src='(.{1,200}?)>(.{0,40}?)<\/a> - <a onclick='storeBuyItemNew\(event, "(.{0,50}?)","([\d,]{1,12})",(\d{14,18}),(\d{14,18}),/sgi)
		{
                        usleep(220000);
			my $tempItemName = $3;
			my $itemId = $1; my $itemPrice = $5; my $saleItemId = $7;
			print "Pushed $tempItemName ($itemId) @ $itemPrice to DB under $characterName ($characterId)\n";
			$url = "http://www.playinitium.com/viewitemmini.jsp?itemId=$itemId";
					my $response = $browser->get($url);
					if($response->is_success)
					{
						my $dexPen = 0;
						my $durability;
						my $blockchance;
                                                my $dmgreduc;
						my $maxdamage;
						my $avgdamage;

						my $content3 = $response->decoded_content;
						$content3 =~ s/<!--  Comparisons -->(.*)//s;
#						print "\t[ $tempItemName ] ";
#						if(length($tempItemName) < 19 ) { print "\t"; }
#						print "\tItem price: $itemPrice ";
#						$itemPrice =~ s/,//g; if($itemPrice < 100){ print "\t"; } #even it out
						if($content3 =~ m/Dexterity penalty: <div class='main-item-subnote'>([\d\-\.]{1,4})%/)
						{
                                                        $dexPen = $1;
#							print "\tDex pen: $dexPen% ";
						}
						$itemPrice =~ s/,//;
						if($content3 =~ m/Durability: <div class='main-item-subnote'>(\d{1,6})\/(\d{1,6})<\/div>/)
						{
#							print "\tDura: $1/$2\tgp/dura: "; printf("%.2f", ($itemPrice/$1)); print " ";
							$durability = $1.":".$2;
						}
						if($content3 =~ m/([\d\.]{1,4}?) max dmg, ([\d\.]{1,8}?) avg dmg/)
						{
#							print "\t$1 max dmg/$2 avg dmg";
							$maxdamage = $1;
							$avgdamage = $2;
						}
						if($content3 =~ m/Block chance: <div class='main-item-subnote'>(\d{1,3})%/)
						{
							$blockchance = $1;
							#if($1 > 30)
							#{
#								print "\tBlock chance: $blockchance% ";
							#	print "(";
							#	if($content3 =~ m/Block bludgeoning: <div class='main-item-subnote'>(Excellent|Good|Average|Poor|Minimal|None)<\/div>/s)
							#	{ print "Block bl/pi/sl: ". substr($1,0,4);
							#	}
							#	if($content3 =~ m/Block piercing: <div class='main-item-subnote'>(Excellent|Good|Average|Poor|Minimal|None)<\/div>/s)
							#	{ print "/".substr($1,0,4);
							#	}
							#	if($content3 =~ m/Block slashing: <div class='main-item-subnote'>(Excellent|Good|Average|Poor|Minimal|None)<\/div>/s)
							#	{ print "/".substr($1,0,4);
							#	}
							#	print ")";
							#}
						}
						if($content3 =~ m/Damage reduction: <div class='main-item-subnote'>(\d{1,3})<\/div>/)
							{
								$dmgreduc = $1;
								#print "\tDmg reduc: $dmgreduc";
							}
#							print "\n";
						#push @{ $marketDB->{"$characterName"} }, [ $itemName, $itemId, $itemPrice, $dexPen, $durability, $blockchance, $dmgreduc, $maxdmg, $avgdmg ];
						$marketDB{$tempItemName}{$dexPen}{$itemId} = { "itemName" => $tempItemName, "saleItemId" => $saleItemId, "itemPrice" => $itemPrice,
										       "dexPen" => $dexPen, "durability" => $durability, "blockChance" => $blockchance, "dmgReduction" => $dmgreduc,
										       "maxDmg" => $maxdamage, "avgDmg" => $avgdamage, "characterId" => $characterId, "characterName" => $characterName };
						store \%marketDB, 'market.db';
					}
		}
	}
    } else { die $response->decoded_content.$response->status_line; }
