#-------------------------------------------------------------------
# WebGUI is Copyright 2001-2012 Plain Black Corporation.
#-------------------------------------------------------------------
# Please read the legal notices (docs/legal.txt) and the license
# (docs/license.txt) that came with this distribution before using
# this software.
#-------------------------------------------------------------------
# http://www.plainblack.com                     info@plainblack.com
#-------------------------------------------------------------------

use strict;

## The goal of this test is to test the creation and deletion of album assets

use WebGUI::Test;
use WebGUI::Session;
use Test::More; 

#----------------------------------------------------------------------------
# Init
my $session         = WebGUI::Test->session;
my $node            = WebGUI::Test->asset;

# Create gallery and a single album
my $tag = WebGUI::VersionTag->getWorking($session);
my $gallery
    = $node->addChild({
        className           => "WebGUI::Asset::Wobject::Gallery",
    });
my $album
    = $gallery->addChild({
        className           => "WebGUI::Asset::Wobject::GalleryAlbum",
    });
    
# Create 5 photos inside the gallery
my @photo;
for (my $i = 0; $i < 5; $i++)
{
    $photo[$i]
        = $album->addChild({
            className           => "WebGUI::Asset::File::GalleryFile::Photo",
        }, undef, undef, { skipNotifications => 1, skipAutoCommitWorkflows => 1, });
}

$tag->commit;
foreach my $asset ($gallery, $album, @photo) {
    $asset = $asset->cloneFromDb;
}

#----------------------------------------------------------------------------
# Test getPreviousFileId

note 'getPreviousFileId';
is( $album->getPreviousFileId($photo[2]->getId), $photo[1]->getId, 'Id of photo previous of photo no. 3 equals id of photo no. 2' );
is( $album->getPreviousFileId($photo[1]->getId), $photo[0]->getId, 'Id of photo previous of photo no. 2 equals id of photo no. 1' );
is( $album->getPreviousFileId($photo[0]->getId), undef, 'Id of photo previous of photo no. 3 is undef' );

is( $album->getPreviousFileId(undef), undef, 'Return undef if undef specified');
is( $album->getPreviousFileId(''), undef, 'Return undef if empty string specified');
is( $album->getPreviousFileId('123456'), undef, 'Return undef if non-existing id specified');
is( $album->getPreviousFileId($album->getId), undef, 'Return undef if non-child id specified');

#----------------------------------------------------------------------------
# Test getNextFileId

note 'getNextFileId';
is( $album->getNextFileId($photo[2]->getId), $photo[3]->getId, 'Id of photo next of photo no. 3 equals id of photo no. 4' );
is( $album->getNextFileId($photo[3]->getId), $photo[4]->getId, 'Id of photo next of photo no. 4 equals id of photo no. 5' );
is( $album->getNextFileId($photo[4]->getId), undef, 'Id of photo next of photo no. 5 is undef' );

is( $album->getNextFileId(undef), undef, 'Return undef if undef specified');
is( $album->getNextFileId(''), undef, 'Return undef if empty string specified');
is( $album->getNextFileId('123456'), undef, 'Return undef if non-existing id specified');
is( $album->getNextFileId($album->getId), undef, 'Return undef if non-child id specified');

done_testing;

#vim:ft=perl
