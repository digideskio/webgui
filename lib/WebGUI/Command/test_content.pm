package WebGUI::Command::test_content;

use WebGUI::Command -command;
use strict;
use warnings;
use Try::Tiny;
use File::Spec::Functions qw(catfile);
use JSON;

use WebGUI::Paths;
use WebGUI::Session;
use WebGUI::Macro;
use WebGUI::DateTime;

our $LAYOUT_CLASS = 'WebGUI::Asset::Wobject::Layout';
our $FOLDER_CLASS = 'WebGUI::Asset::Wobject::Folder';
our %ASSETS;

sub opt_spec {
    return (
        [ 'F|config:s',     'The config file for the site' ],
        [ 'style:s',        'The URL or ID of a style template to use' ],
        [ 'root=s',         'The URL or ID of the asset to put this content.', { default => "/root" } ],
    );
}

sub run {
    my ( $self, $opt, $args ) = @_;

    if ( !$opt->{style} ) {
        die "style is required\n";
    }

    my $session = WebGUI::Session->open( $opt->{f} );
    $self->{_session} = $session;
    my $root    = $self->getAsset( $opt->{root} );
    my $style   = $self->getAsset( $opt->{style} );

    # Create a single page to hold all the content pages
    my $top = $root->addChild({
            className       => $FOLDER_CLASS,
            title           => 'Test Content',
            styleTemplateId => $style->getId,
        });
    $top->indexContent;

    # Create category pages for all asset categories
    my %categories = ();
    for my $cat ( keys %{$session->config->get( 'assetCategories' )} ) {
        my $title   = $session->config->get( "assetCategories/$cat/title" );
        WebGUI::Macro::process( $session, \$title );
        $categories{ $cat } = $top->addChild({
            className       => $FOLDER_CLASS,
            title           => $title,
            styleTemplateId => $style->getId,
        });
        $categories{ $cat }->indexContent;
    }

    # Add individual asset pages to their category pages
    for my $class ( keys %ASSETS ) {
        my @sets    = @{ $self->getPropertySets( $class ) };
        next unless @sets > 0;

        # Set the default style template
        $sets[0]->{styleTemplateId} ||= $style->getId;

        # Put the first one on the given page
        my $cat     = $session->config->get( "assets/$class/category" ) || "utilities";
        my $page    = $categories{ $cat }->addChild({
                className       => $LAYOUT_CLASS,
                styleTemplateId => $style->getId,
                title           => $sets[0]->{title},
            });
        $page->indexContent;

        my $asset   = $self->buildAsset( $class, $page, $sets[0] );

        # Make subpages for the other ones
        for my $set ( @sets[1..$#sets] ) {
            my $merged_set = {
                %{ $sets[0] },
                %{ $set },
            };
            my $subpage = $page->addChild({
                url             => $asset->url . '/' . $set->{title},
                className       => $LAYOUT_CLASS,
                title           => $set->{title},
                styleTemplateId => $style->getId,
            });
            $self->buildAsset( $class, $subpage, $merged_set );
        }
    }

    print "Done!\nURL: " . $top->getUrl . "\n";
}

=head2 getAsset ( id )

Get an asset based on the given ID or URL.

=cut

sub getAsset {
    my ( $self, $id ) = @_;
    my $session = $self->{_session};
    my $asset;
    try {
        $asset   = WebGUI::Asset->newByUrl( $session, $id );
    }
    catch {
        try {
            $asset   = WebGUI::Asset->newById( $session, $id );
        }
        catch {
            die "Could not find asset '$id'\n";
        };
    };
    return $asset;
}

=head2 buildAsset( class, page, props )

Build one asset on the page, recursing into any _children.

=cut

sub buildAsset {
    my ( $self, $class, $page, $rawprops ) = @_;
    my $session = $self->{_session};

    my $files       = $rawprops->{_files}       || [];
    my $children    = $rawprops->{_children}    || [];
    my $props       = { map { $_ => $rawprops->{$_} } grep { !/^_/ } keys %$rawprops };
    $props->{ styleTemplateId } ||= $page->can( 'styleTemplateId' ) ? $page->styleTemplateId : '';

    my $asset = $page->addChild({
            className   => $class,
            %$props,
        });
    if ( !$asset ) {
        print "Could not create " . $class . " inside of " . $page->className . ' (' . $page->getUrl . ")\n";
        return;
    }

    # Add files to storage locations
    my %storage = ();
    for my $file ( @$files ) {
        my $storage;
        next unless -f $file->{file};
        if ( !($storage = $storage{ $file->{property} }) ) {
            $storage = $storage{ $file->{property} } = WebGUI::Storage->create( $session );
            $asset->update({ $file->{property} => $storage->getId });
        }
        my $filename = $storage->addFileFromFilesystem( $file->{file} );
        $storage->generateThumbnail( $filename );
    }

    # Add children
    my $first_child  = $children->[0];
    for my $child ( @$children ) {
        my $merged_set = {
            %$first_child,
            %$child,
        };
        $self->buildAsset( $merged_set->{className}, $asset, $merged_set );
    }

    # Index the content
    $asset->indexContent;

    return $asset;
}

=head2 getPropertySets( class )

Returns an array of hashref of property sets for the given asset class

This is hardcoded for now, but should eventually become a config file of some kind

=cut

my $DT_NOW = DateTime->now;
my @numbers = ( 1..10 );

# The first set is the default properties, every other set will combine the
# default properties with the set properties
# A special property _children allows for child assets
#   again, the first item will set defaults for the next items
# A special property _files allows for files
%ASSETS = (
    'WebGUI::Asset::Wobject::Article' => [
        {
            title       => 'Article with Image',
            templateId  => 'PBtmpl0000000000000103',
            description => lorem(),
            isHidden    => 1,
            displayTitle=> 1,
            linkURL     => 'http://webgui.org',
            linkTitle   => 'WebGUI Content Management System',
            _files      => [
                {
                    property    => 'storageId',
                    file        => catfile( WebGUI::Paths->extras, 'wg.png' ),
                },
            ],
        },
        {
            title       => 'Article with Pagination',
            templateId  => 'XdlKhCDvArs40uqBhvzR3w',
            description => lorem(0,1,2) . '<p>^-;</p>' . lorem(3,4,5),
        },
        {
            title       => 'Item',
            templateId  => 'PBtmpl0000000000000123',
            description => lorem(),

        },
        {
            title       => 'Linked Image with Caption',
            templateId  => 'PBtmpl0000000000000115',
            description => lorem(),
            _files      => [
                {
                    property    => 'storageId',
                    file        => catfile( WebGUI::Paths->extras, 'wg.png' ),
                },
            ],
        },
    ],
    'WebGUI::Asset::Wobject::Calendar' => [
        {
            title           => 'Calendar',
            description     => lorem(0,1,2),
            isHidden        => 1,
            displayTitle    => 1,
            _children       => [
                {
                    className   => 'WebGUI::Asset::Event',
                    title       => 'Today',
                    startDate   => $DT_NOW->ymd,
                    endDate     => $DT_NOW->ymd,
                },
                {
                    title       => 'Tomorrow',
                    startDate   => $DT_NOW->clone->add( days => 1 )->ymd,
                    endDate     => $DT_NOW->clone->add( days => 1 )->ymd,
                },
                {
                    title       => 'Tomorrow Noon',
                    startDate   => $DT_NOW->clone->add( days => 1 )->ymd,
                    endDate     => $DT_NOW->clone->add( days => 1 )->ymd,
                    startTime   => '12:00:00',
                    endTime     => '12:00:00',
                    timeZone    => 'CST',
                },
                {
                    title       => 'This weekend',
                    startDate   => $DT_NOW->clone->add( days => 6 - $DT_NOW->dow )->ymd,
                    endDate     => $DT_NOW->clone->add( days => 7 - $DT_NOW->dow )->ymd,
                },
            ],
        },
    ],
    'WebGUI::Asset::Wobject::DataForm' => [
        {
            title       => 'Data Form',
            description => lorem(0,1,2),
            isHidden    => 1,
            defaultView => 0,
            useCaptcha  => 1,
            templateId  => 'PBtmpl0000000000000141', # Default dataform
            fieldConfiguration  => JSON->new->encode( [
                {
                    name        => "from",
                    label       => 'From',
                    status      => "required",
                    type        => "email",
                },
                {
                    name        => 'subject',
                    label       => 'Subject',
                    status      => 'required',
                    type        => 'text',
                },
                {
                    name        => 'date',
                    label       => 'Date',
                    status      => 'editable',
                    type        => 'date',
                },
                {
                    name        => 'body',
                    label       => 'Body',
                    status      => 'editable',
                    type        => 'textarea',
                },
            ] ),
        },
        {
            title       => 'Data Form (list)',
            defaultView => 1,
        },
        {
            title       => 'Data Form (tabbed)',
            defaultView => 0,
            templateId  => 'PBtmpl0000000000000116', # Tab form
            fieldConfiguration  => JSON->new->encode( [
                {
                    name        => "from",
                    label       => 'From',
                    status      => "required",
                    type        => "email",
                    tabId       => 0,
                },
                {
                    name        => 'subject',
                    label       => 'Subject',
                    status      => 'required',
                    type        => 'text',
                    tabId       => 'one',
                },
                {
                    name        => 'date',
                    label       => 'Date',
                    status      => 'editable',
                    type        => 'date',
                    tabId       => 'one',
                },
                {
                    name        => 'body',
                    label       => 'Body',
                    status      => 'editable',
                    type        => 'textarea',
                    tabId       => 'two',
                },
            ] ),
            tabConfiguration    => JSON->new->encode( [
                {
                    tabId   => 'one',
                    label   => "One",
                    subtext => "The oneth page",
                },
                {
                    tabId   => 'two',
                    label   => 'Two',
                    subtext => 'The twoth page',
                },
            ] ),
        },
    ],
    'WebGUI::Asset::Wobject::DataTable' => [
        {
            title       => 'DataTable (YUI)',
            description => lorem(0,1,2),
            isHidden    => 1,
            templateId  => '3rjnBVJRO6ZSkxlFkYh_ug',
            data        => JSON->new->encode( {
                columns => [
                    {
                        key         => 'ID',
                        formatter   => 'text',
                    },
                    {
                        key         => 'Name',
                        formatter   => 'text',
                    },
                    {
                        key         => 'URL',
                        formatter   => 'link',
                    },
                ],
                rows    => [
                    {
                        ID      => '1',
                        Name    => 'WebGUI',
                        URL     => 'http://webgui.org',
                    },
                    {
                        ID      => '2',
                        Name    => 'Plain Black Corp.',
                        URL     => 'http://plainblack.com',
                    },
                ],
            } ),
        },
        {
            title       => 'DataTable (HTML)',
            templateId  => 'TuYPpHx7TUyk08639Pc8Bg',
        },
    ],
    'WebGUI::Asset::Wobject::Map' => [
        {
            title       => 'Map',
            description => lorem(0,1,2),
            mapApiKey   => 'ABQIAAAAxadBCYjK6rRsw7rJkBgiEBT7g5bZECU_gqoByQmzcFSTeCxKshSKEU-GQYssxXNgQ1qkA3XtjOGYog',
            # Key only works for "localhost:5000"
            startLatitude => '43.068888',
            startLongitude => '-89.384251',
            startZoom   => '6',
            _children   => [
                {
                    className   => 'WebGUI::Asset::MapPoint',
                    title       => 'Lake Poygan',
                    latitude    => '44.166445',
                    longitude   => '-88.791504',
                    description => lorem(0),
                },
                {
                    className   => 'WebGUI::Asset::MapPoint',
                    title       => 'Chicago',
                    latitude    => '41.885921',
                    longitude   => '-87.670898',
                    description => lorem(1),
                },
                {
                    className   => 'WebGUI::Asset::MapPoint',
                    title       => 'Dubuque',
                    latitude    => '42.569264',
                    longitude   => '-90.725098',
                    description => lorem(2),
                },
            ],
        },
    ],
    'WebGUI::Asset::Wobject::Poll' => [
        {
            title       => 'Poll',
            description => 'What is the air-speed velocity of an unladen swallow?',
            a1          => 'Blue',
            a2          => 'No wait, Yellow',
            a3          => 'African or European',
            a4          => 'Your father was a hamster',
        },
    ],
    'WebGUI::Asset::Wobject::Search' => [
        {
            title       => 'Search',
            isHidden    => 1,
            searchRoot  => 'PBasset000000000000001',
            description => lorem(0,1,2),
        },
    ],
    'WebGUI::Asset::Snippet' => [
        {
            title       => 'Snippet',
            isHidden    => 1,
            snippet     => '<div style="color: red">Red room!</div>',
        },
    ],
    'WebGUI::Asset::Wobject::Collaboration' => [
        {
            title => 'Collaboration (Forum)',
            isHidden    => 1,
            postFormTemplateId => 'PBtmpl0000000000000029',
            threadTemplateId => 'PBtmpl0000000000000032',
            collaborationTemplateId => 'PBtmpl0000000000000026',
            _children   => [
                {
                    className   => 'WebGUI::Asset::Post::Thread',
                    title       => 'Thread',
                    content     => lorem(0,1,2),
                    synopsis    => lorem(0),
                    _children   => [
                        {
                            className   => 'WebGUI::Asset::Post',
                            title       => "Post",
                            content     => lorem(3,4,5),
                            _files      => [
                                {
                                    property    => 'storageId',
                                    file        => catfile( WebGUI::Paths->extras, 'plainblack.gif' ),
                                },
                            ],
                        },
                    ],
                    _files  => [
                        {
                            property    => 'storageId',
                            file        => catfile( WebGUI::Paths->extras, 'wg.png' ),
                        },
                    ],
                },
            ],
        },
        {
            title   => 'Collaboration (FAQ)',
            postFormTemplateId => 'PBtmpl0000000000000099',
            threadTemplateId => 'PBtmpl0000000000000032',
            collaborationTemplateId => 'PBtmpl0000000000000080',
            _children   => [
                {
                    className   => 'WebGUI::Asset::Post::Thread',
                    title       => "Question 1?",
                    content     => '<p>Answer!</p>' . lorem(0),
                },
                {
                    className   => 'WebGUI::Asset::Post::Thread',
                    title       => "Question 2?",
                    content     => '<p>Answer!</p>' . lorem(1),
                    _files      => [
                        {
                            property    => 'storageId',
                            file        => catfile( WebGUI::Paths->extras, 'plainblack.gif' ),
                        },
                    ],
                },
                {
                    className   => 'WebGUI::Asset::Post::Thread',
                    title       => "Question 3?",
                    content     => '<p>Answer!</p>' . lorem(2),
                },
            ],
        },
        {
            title   => 'Collaboration (Job)',
            postFormTemplateId => 'PBtmpl0000000000000122',
            threadTemplateId => 'PBtmpl0000000000000098',
            collaborationTemplateId => 'PBtmpl0000000000000077',
        },
        {
            title   => 'Collaboration (Link List)',
            postFormTemplateId => 'PBtmpl0000000000000114',
            threadTemplateId => 'PBtmpl0000000000000113',
            collaborationTemplateId => 'PBtmpl0000000000000083',
        },
        {
            title   => 'Collaboration (Request Tracker)',
            postFormTemplateId => 'PBtmpl0000000000000210',
            threadTemplateId => 'PBtmpl0000000000000209',
            collaborationTemplateId => 'PBtmpl0000000000000208',
        },
        {
            title   => 'Collaboration (Blog)',
            postFormTemplateId => 'PBtmpl0000000000000029',
            threadTemplateId => 'PBtmpl0000000000000032',
            collaborationTemplateId => 'PBtmpl0000000000000112',
        },
        {
            title   => 'Collaboration (Classifieds)',
            postFormTemplateId => 'PBtmpl0000000000000029',
            threadTemplateId => 'PBtmpl0000000000000032',
            collaborationTemplateId => 'PBtmpl0000000000000128',
        },
        {
            title   => 'Collaboration (Guest Book)',
            postFormTemplateId => 'PBtmpl0000000000000029',
            threadTemplateId => 'PBtmpl0000000000000032',
            collaborationTemplateId => 'PBtmpl0000000000000133',
        },
        {
            title   => 'Collaboration (Ordered List)',
            postFormTemplateId => 'PBtmpl0000000000000029',
            threadTemplateId => 'PBtmpl0000000000000032',
            collaborationTemplateId => 'PBtmpl0000000000000101',
        },
        {
            title   => 'Collaboration (Photo Gallery)',
            postFormTemplateId => 'PBtmpl0000000000000029',
            threadTemplateId => 'PBtmpl0000000000000032',
            collaborationTemplateId => 'PBtmpl0000000000000121',
        },
        {
            title   => 'Collaboration (Topics)',
            postFormTemplateId => 'PBtmpl0000000000000029',
            threadTemplateId => 'PBtmpl0000000000000032',
            collaborationTemplateId => 'PBtmpl0000000000000079',
        },
        {
            title   => 'Collaboration (Traditional with Thumbnails)',
            postFormTemplateId => 'PBtmpl0000000000000029',
            threadTemplateId => 'PBtmpl0000000000000032',
            collaborationTemplateId => 'PBtmpl0000000000000097',
        },
    ],
    'WebGUI::Asset::Wobject::Gallery' => [
        {
            title       => 'Gallery',
            isHidden    => 1,
            _children   => [
                {
                    className   => 'WebGUI::Asset::Wobject::GalleryAlbum',
                    title       => 'Album 1',
                    _children   => [
                        {
                            className   => 'WebGUI::Asset::File::GalleryFile::Photo',
                            title       => 'WebGUI Logo',
                            filename    => 'wg.png',
                            _files      => [
                                {
                                    property        => 'storageId',
                                    file            => catfile( WebGUI::Paths->extras, 'wg.png' ),
                                },
                            ],
                        },
                        {
                            className   => 'WebGUI::Asset::File::GalleryFile::Photo',
                            title       => 'Plainblack logo',
                            filename    => 'plainblack.gif',
                            _files      => [
                                {
                                    property        => 'storageId',
                                    file            => catfile( WebGUI::Paths->extras, 'plainblack.gif' ),
                                },
                            ],
                        },
                    ],
                },
                {
                    className   => 'WebGUI::Asset::Wobject::GalleryAlbum',
                    title       => 'Icons',
                    _children   => [ 
                        map { {
                            className   => 'WebGUI::Asset::File::GalleryFile::Photo',
                            title       => ucfirst $_,
                            filename    => $_,
                            _files      => [
                                {
                                    property    => 'storageId',
                                    file        => catfile( WebGUI::Paths->extras, 'icon', $_ ),
                                },
                            ],
                        } } qw( 
                            application.png keyboard.png layers.png layout.png anchor.png lightbulb.png
                            lightning.png link.png maginifier.png map.png attach.png money.png basket.png
                            monitor.png mouse.png bell.png bin.png bomb.png book.png note.png new.png music.png
                            page.png brick.png briefcase.png bug.png building.png cake.png calculator.png 
                            calendar.png car.png camera.png cart.png cd.png pencil.png phone.png chart_bar.png
                            photo.png picture.png clock.png printer.png rainbow.png report.png plugin.png 
                            cog.png coins.png comment.png resultset_first.png resultset_next.png
                            contrast.png script.png controller.png server.png cross.png css.png shading.png
                            shield.png date.png database.png sound.png disk.png door.png star.png stop.png
                            dvd.png email.png table.png error.png feed.png television.png folder.png font.png 
                            group.png user.png world.png xhtml.png image.png key.png zoom.png wrench.png
                        )
                    ],
                },
            ],
        }
    ],
    'WebGUI::Asset::Wobject::MessageBoard' => [
        {
            title       => 'Message Board',
            isHidden    => 1,
            _children   => [
                {
                    className   => 'WebGUI::Asset::Wobject::Collaboration',
                    title => 'Logos',
                    isHidden    => 1,
                    postFormTemplateId => 'PBtmpl0000000000000029',
                    threadTemplateId => 'PBtmpl0000000000000032',
                    collaborationTemplateId => 'PBtmpl0000000000000026',
                    _children   => [
                        {
                            className   => 'WebGUI::Asset::Post::Thread',
                            title       => 'Thread',
                            content     => lorem(0,1,2),
                            synopsis    => lorem(0),
                            _children   => [
                                {
                                    className   => 'WebGUI::Asset::Post',
                                    title       => "Post",
                                    content     => lorem(3,4,5),
                                    _files      => [
                                        {
                                            property    => 'storageId',
                                            file        => catfile( WebGUI::Paths->extras, 'plainblack.gif' ),
                                        },
                                    ],
                                },
                            ],
                            _files  => [
                                {
                                    property    => 'storageId',
                                    file        => catfile( WebGUI::Paths->extras, 'wg.png' ),
                                },
                            ],
                        },
                    ],
                },
                {
                    title => 'Icons',
                    _children   => [
                        {
                            className   => 'WebGUI::Asset::Post::Thread',
                            title       => 'Clock',
                            content     => lorem(0,1,2),
                            synopsis    => lorem(0),
                            _children   => [
                                {
                                    className   => 'WebGUI::Asset::Post',
                                    title       => "Camera",
                                    content     => lorem(3,4,5),
                                    _files      => [
                                        {
                                            property    => 'storageId',
                                            file        => catfile( WebGUI::Paths->extras, 'icon', 'camera.png' ),
                                        },
                                    ],
                                },
                            ],
                            _files  => [
                                {
                                    property    => 'storageId',
                                    file        => catfile( WebGUI::Paths->extras, 'icon', 'clock.png' ),
                                },
                            ],
                        },
                        {
                            className   => 'WebGUI::Asset::Post::Thread',
                            title       => 'Brick',
                            content     => lorem(0,1,2),
                            synopsis    => lorem(0),
                            _files  => [
                                {
                                    property    => 'storageId',
                                    file        => catfile( WebGUI::Paths->extras, 'icon', 'brick.png' ),
                                },
                            ],
                        },
                        {
                            className   => 'WebGUI::Asset::Post::Thread',
                            title       => 'Cog',
                            content     => lorem(0,1,2),
                            synopsis    => lorem(0),
                            _files  => [
                                {
                                    property    => 'storageId',
                                    file        => catfile( WebGUI::Paths->extras, 'icon', 'cog.png' ),
                                },
                            ],
                        },
                        {
                            className   => 'WebGUI::Asset::Post::Thread',
                            title       => 'Bug',
                            content     => lorem(0,1,2),
                            synopsis    => lorem(0),
                            _files  => [
                                {
                                    property    => 'storageId',
                                    file        => catfile( WebGUI::Paths->extras, 'icon', 'bug.png' ),
                                },
                            ],
                        },
                    ],
                },
            ],
        },
    ],
    'WebGUI::Asset::Wobject::Collaboration::Newsletter' => [
        {
            title => 'Newsletter',
            isHidden    => 1,
            _children   => [
                {
                    className   => 'WebGUI::Asset::Post::Thread',
                    title       => 'Thread',
                    content     => lorem(0,1,2),
                    synopsis    => lorem(0),
                    _children   => [
                        {
                            className   => 'WebGUI::Asset::Post',
                            title       => "Post",
                            content     => lorem(3,4,5),
                            _files      => [
                                {
                                    property    => 'storageId',
                                    file        => catfile( WebGUI::Paths->extras, 'plainblack.gif' ),
                                },
                            ],
                        },
                    ],
                    _files  => [
                        {
                            property    => 'storageId',
                            file        => catfile( WebGUI::Paths->extras, 'wg.png' ),
                        },
                    ],
                },
            ],
        },
    ],
    'WebGUI::Asset::Wobject::StoryArchive' => [
        {
            title       => 'Story Archive',
            isHidden    => 1,
            _children   => [
                {
                    className       => 'WebGUI::Asset::Story',
                    title           => 'Story 1',
                    byline          => 'Gooey',
                    keywords        => 'webgui',
                    highlights      => lorem(0),
                    story           => lorem(1,2,3,4),
                },
                {
                    className       => 'WebGUI::Asset::Story',
                    title           => 'Story 2',
                    byline          => 'TEH INTARWEBS',
                    keywords        => 'webgui,lorem',
                    highlights      => lorem(2),
                    story           => lorem(1,0,3,4),
                },
                {
                    className       => 'WebGUI::Asset::Story',
                    title           => 'Story 3',
                    byline          => 'Lorem',
                    keywords        => 'lorem',
                    highlights      => lorem(1),
                    story           => lorem(0,2,3,4),
                },
            ],
        },
    ],
    'WebGUI::Asset::Wobject::StoryTopic' => [
        {
            title       => 'StoryTopic (lorem)',
            keywords    => 'lorem',
        },
        {
            title       => 'StoryTopic (webgui)',
            keywords    => 'webgui',
        },
    ],
    'WebGUI::Asset::Wobject::Survey' => [
        {
            title       => 'Survey',
            surveyJSON  => JSON->new->encode(
                {
                    "mold" => {
                        "question" => {
                            "commentCols" => "10",
                            "variable" => "",
                            "gotoExpression" => "",
                            "verticalDisplay" => "0",
                            "required" => "0",
                            "text" => "",
                            "commentRows" => "5",
                            "goto" => "",
                            "answers" => [],
                            "maxAnswers" => "1",
                            "value" => "1",
                            "randomWords" => "",
                            "randomizeAnswers" => "0",
                            "questionType" => "Multiple Choice",
                            "allowComment" => "0",
                            "textInButton" => "0",
                            "type" => "question",
                        },
                        "answer" => {
                            "verbatim" => "0",
                            "value" => "1",
                            "min" => "1",
                            "gotoExpression" => "",
                            "textCols" => "10",
                            "max" => "10",
                            "step" => "1",
                            "terminal" => "0",
                            "textRows" => "5",
                            "text" => "",
                            "recordedAnswer" => "",
                            "type" => "answer",
                            "terminalUrl" => "",
                            "goto" => "",
                            "isCorrect" => "1"
                        },
                        "section" => {
                            "variable"=>"",
                            "gotoExpression" => "",
                            "questionsPerPage" => "5",
                            "terminal" => "0",
                            "text" => "",
                            "goto" => "",
                            "terminalUrl" => "",
                            "everyPageText" => "1",
                            "logical" => "0",
                            "questions" => [],
                            "everyPageTitle" => "1",
                            "timeLimit" => "0",
                            "randomizeQuestions" => "0",
                            "questionsOnSectionPage" => "1",
                            "title" => "NEW SECTION",
                            "type" => "section"
                        }
                    },
                    "sections" => [
                        {
                            "text"=>"Who would cross the Bridge of Death must answer me these questions three, 'ere the other side he see.",
                            "title"=>"The Questions Three",
                            "questions" => [
                                {
                                    "text"=>"What is your name?",
                                    "answers" => [
                                        {
                                            "recordedAnswer"=>"Sir Launcelot",
                                            "text"=>"Sir Launcelot"
                                        },
                                        {
                                            "text"=>"Sir Galahad",
                                            "recordedAnswer"=>"Sir Galahad"
                                        },
                                        {
                                            "recordedAnswer"=>"Sir Robin",
                                            "text"=>"Sir Robin"
                                        },
                                        {
                                            "text"=>"Arthur, King of the Britons",
                                            "recordedAnswer"=>"Arthur, King of the Britons"
                                        }
                                    ]
                                },
                                {
                                    "text"=>"What is your Quest?",
                                    "answers"=>[
                                        {
                                            "text"=>"The Holy Grail",
                                            "recordedAnswer" => "The Holy Grail"
                                        },
                                    ],
                                },
                                {
                                    "text"=>"What is your favorite color?",
                                    "answers"=>[
                                        {
                                            "recordedAnswer"=>"Blue",
                                            "text" => "Blue"
                                        },
                                        {
                                            "text"=>"Blue, no yel--!","recordedAnswer"=>"ARGGGGHHH"
                                        },
                                    ],
                                },
                            ],
                        },
                    ],
                }),
        },
    ],
    'WebGUI::Asset::Wobject::WikiMaster' => [
        {
            title       => 'Wiki',
            isHidden    => 1,
            _children   => [
                {
                    className   => 'WebGUI::Asset::WikiPage',
                    content     => lorem(0,1,2),
                    keywords    => 'lorem, ipsum',
                },
                {
                    className   => 'WebGUI::Asset::WikiPage',
                    content     => lorem(3,4,5),
                    keywords    => 'lorem',
                },
                {
                    className   => 'WebGUI::Asset::WikiPage',
                    content     => lorem( 1, 3, 5 ),
                    keywords    => 'lorem',
                },
            ],
        },
    ],
    'WebGUI::Asset::Wobject::Dashboard' => [
        {
            title       => 'Dashboard',
            isHidden    => 1,
            _children   => [
                {
                    className       => 'WebGUI::Asset::Wobject::StockData',
                    title           => 'Stock Data',
                },
                {
                    className       => 'WebGUI::Asset::Wobject::WeatherData',
                    title           => 'Weather Data',

                },
            ],
        },
    ],
    'WebGUI::Asset::Wobject::Thingy' => [
        {
            title       => 'Thingy',
            isHidden    => 1,
        },
    ],
    'WebGUI::Asset::Wobject::UserList' => [
        {
            title       => 'UserList',
            isHidden    => 1,
        },
    ],
    'WebGUI::Asset::Sku::Donation' => [
        {
            title           => 'Donation',
            isHidden        => 1,
            defaultPrice    => '20.00',
        },
    ],
    'WebGUI::Asset::Sku::FlatDiscount' => [
        {
            title           => 'Flat Discount',
            isHidden        => 1,
            priceDiscount   => '5.00',
        },
    ],
    'WebGUI::Asset::Sku::Product' => [
        {
            title       => 'Product',
            isHidden    => 1,
            keywords    => 'adminSubscription',
            relatedJSON => JSON->new->encode([]),
            specificationJSON => JSON->new->encode([]),
            featureJSON => JSON->new->encode([]),
            benefitJSON => JSON->new->encode([]),
            accessoryJSON => JSON->new->encode([]),
            variantsJSON => JSON->new->encode([]),
            _files  => [
                {
                    property    => 'image1',
                    file        => catfile( WebGUI::Paths->extras, 'wg.png' ),
                },
                {
                    property    => 'image2',
                    file        => catfile( WebGUI::Paths->extras, 'plainblack.gif' ),
                },
            ],
        },
    ],
    'WebGUI::Asset::Wobject::Shelf' => [
        {
            title       => 'Shelf',
            isHidden    => 1,
            keywords    => 'adminSubscription',
            _children   => [
                {
                    className   => 'WebGUI::Asset::Sku::Product',
                    title       => 'Product',
                    price       => '5.00',
                    _files      => [
                        {
                            property    => 'image1',
                            file        => catfile( WebGUI::Paths->extras, 'plainblack.gif' ),
                        },
                    ],
                },
                {
                    className   => 'WebGUI::Asset::Sku::Product',
                    title       => 'Product x10',
                    price       => '50.00',
                    _files      => [
                        {
                            property    => 'image1',
                            file        => catfile( WebGUI::Paths->extras, 'wg.png' ),
                        },
                    ],
                },
            ],
        },
    ],
    'WebGUI::Asset::Sku::Subscription' => [
        {
            title       => 'Subscription',
            isHidden    => 1,
            subscriptionGroupId => '12',
            price       => '5.00',
            keywords    => 'adminSubscription',
        },
    ],
    'WebGUI::Asset::Wobject::AssetReport' => [
        {
            title       => 'AssetReport',
            isHidden    => 1,
            settings    => JSON->new->encode({
                className       => 'WebGUI::Asset::Wobject::Layout',
            }),
        },
    ],
    'WebGUI::Asset::Wobject::Carousel' => [
        {
            title       => 'Carousel',
            isHidden    => 1,
            items       => JSON->new->encode({
                items   => [
                    {
                        sequenceNumber  => 1,
                        text        => lorem(0),
                        itemId      => 1,
                    },
                    {
                        sequenceNumber => 2,
                        text        => lorem(1),
                        itemId      => 2,
                    },
                    {
                        sequenceNumber => 3,
                        text        => lorem(2),
                        itemId      => 3,
                    },
                    {
                        sequenceNumber  => 4,
                        text        => lorem(3),
                        itemId      => 4,
                    },
                ],
            }),
        },
    ],
    'WebGUI::Asset::File' => [
        {
            title       => 'File',
            isHidden    => 1,
            filename    => 'wg.png',
            _files  => [
                {
                    property    => 'storageId',
                    file        => catfile( WebGUI::Paths->extras, 'wg.png' ),
                },
            ],
        },
    ],
    'WebGUI::Asset::File::Image' => [
        {
            title       => 'Image',
            isHidden    => 1,
            filename    => 'wg.png',
            _files  => [
                {
                    property    => 'storageId',
                    file        => catfile( WebGUI::Paths->extras, 'wg.png' ),
                },
            ],
        },
    ],
    'WebGUI::Asset::Wobject::Navigation' => [
        {
            title       => 'Navigation',
            isHidden    => 1,
        },
    ],
    'WebGUI::Asset::Redirect' => [
        {
            title       => 'Redirect',
            menuTitle   => 'Redirect to WebGUI.org',
            redirectUrl => 'http://webgui.org',
        },
    ],
    'WebGUI::Asset::Wobject::SQLReport' => [
        {
            title       => 'SQLReport',
            isHidden    => 1,
            dbQuery1    => 'SELECT userId, username FROM users',
        },
    ],
    'WebGUI::Asset::Wobject::SyndicatedContent' => [
        {
            title       => 'Syndicated Content',
            isHidden    => 1,
            rssUrl      => 'http://www.webgui.org/download/advisories.rss',
        },
    ],
    'WebGUI::Asset::Template' => [
        {
            title       => 'Template',
            isHidden    => 1,
            namespace   => 'style',
            template    => '[% head_tags %][% body_content %]',
        },
    ],
);

sub getPropertySets {
    my ( $self, $class ) = @_;
    return $ASSETS{ $class };
}

=head2 lorem ( indexes )

Return generated lorem ipsum text. C<indexes> is an array of paragraph indexes
to pull from __DATA__

=cut

our @LOREM;
sub lorem {
    my ( @indexes ) = @_;
    return join "", map { "<p>$_</p>" } split "\n\n", lorem_text( @indexes );
}

sub lorem_text {
    my ( @indexes ) = @_;
    if ( !@LOREM ) {
        @LOREM = <DATA>;
    }
    if ( scalar @indexes == 0 ) {
        @indexes = ( 0..3 );
    }
    return join "\n\n", @LOREM[ @indexes ];
}

1;

__DATA__
Lorem ipsum dolor sit amet, consectetur adipiscing elit. Quisque a velit eget mauris imperdiet auctor. Sed libero massa, laoreet a dapibus sed, scelerisque malesuada eros. Mauris suscipit, nisl nec rhoncus lacinia, libero felis adipiscing neque, eu ultrices ipsum turpis id dui. In tincidunt ipsum eget eros molestie porta. Maecenas in dui augue. Suspendisse eu pretium mauris. Mauris dignissim facilisis ligula aliquet iaculis. Class aptent taciti sociosqu ad litora torquent per conubia nostra, per inceptos himenaeos. Ut eget diam vitae quam sollicitudin luctus. Morbi a tortor orci, ut vulputate velit. Mauris malesuada lorem dui, non scelerisque lectus. Ut interdum ligula at neque vehicula aliquet. Mauris venenatis dapibus neque, vitae hendrerit ipsum consectetur sed. Fusce hendrerit, nisl et convallis cursus, ligula augue pharetra lorem, ornare fringilla elit mi id nisl. Nullam et sem ut tellus suscipit eleifend.
Maecenas quis est et sapien condimentum porttitor ut in arcu. Ut nec erat lacus. Cras a ante neque, ac lobortis libero. Maecenas aliquet ullamcorper tellus, et fermentum neque porttitor nec. Aenean mollis porttitor nibh et sollicitudin. Aliquam at congue ligula. Aenean vitae dui non urna scelerisque blandit. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Vivamus at enim cursus leo venenatis faucibus eu sed dui. Nam id sem ac risus molestie iaculis sed quis sapien. Vivamus sed blandit erat. Nullam placerat imperdiet sem ac ornare. Duis sem erat, euismod eget blandit dapibus, hendrerit imperdiet massa. Mauris quis tincidunt risus. Aliquam luctus vulputate turpis, non facilisis sapien rhoncus sed.
Nulla facilisi. Nam a purus a odio porta hendrerit ut et tellus. Sed hendrerit gravida sapien, et dapibus turpis ornare id. Aliquam mattis, eros sed egestas dignissim, turpis leo sollicitudin ante, nec pulvinar odio lorem id mi. Pellentesque neque lacus, faucibus vitae egestas in, placerat eu neque. Nulla libero est, fringilla id tristique sit amet, aliquam tincidunt nulla. Morbi posuere bibendum ipsum, a cursus tellus tempus quis. Etiam eu nisl eget purus consectetur fringilla sed id neque. Maecenas lacinia dolor sed dui vestibulum non interdum urna placerat. Quisque porta condimentum velit, non lobortis sapien feugiat vel. Ut ut fringilla neque.
Vestibulum dignissim sollicitudin sem aliquet condimentum. Donec egestas felis tempus nunc commodo vel fermentum enim porttitor. Curabitur tristique justo et augue elementum mattis. Phasellus rhoncus convallis augue sed viverra. Nam faucibus adipiscing dolor sagittis convallis. Fusce consectetur pretium nunc, sed rhoncus lacus dignissim eu. Quisque non felis non erat auctor adipiscing et vitae neque. Phasellus adipiscing convallis nisi eget sodales. Donec tincidunt nisl eget tellus laoreet faucibus. Vivamus facilisis eros risus, quis tristique orci. In convallis lacus et nisl venenatis id elementum nunc cursus. Cras pellentesque, mi in iaculis venenatis, sem nisl laoreet quam, ac malesuada dui diam sed enim. Phasellus eleifend posuere sagittis.
Integer ipsum dui, facilisis et adipiscing vitae, lacinia vitae arcu. Cras ac sapien eget ipsum faucibus condimentum at et sapien. Sed id nisi ante, non pharetra velit. Sed faucibus tincidunt nisl sed malesuada. Duis pharetra tempor felis vitae tristique. Vestibulum eget lacus eget ipsum interdum feugiat. Sed quis libero sit amet nisi pharetra posuere. Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia Curae; Suspendisse pharetra pharetra erat, et lacinia lectus fringilla eget. Nunc sem mi, blandit ut aliquet ut, ultricies vitae arcu. Quisque quis diam nibh. Proin nec vehicula sapien. Proin varius turpis a ante venenatis accumsan. Vivamus ornare porttitor lacus eget lacinia.
Quisque aliquam malesuada dolor vehicula aliquet. In in mauris nunc, ac pellentesque tortor. Suspendisse tincidunt nunc vel mauris auctor posuere. Nullam ante nibh, lacinia vitae pulvinar elementum, blandit ut leo. Aliquam erat volutpat. Nam quis risus orci. Sed augue nisl, imperdiet non auctor vitae, blandit in turpis. Duis mauris enim, fermentum eget tempor id, tempor ac tortor. In in justo ut urna scelerisque ultrices nec molestie lectus. In dolor arcu, interdum vitae feugiat eget, sagittis quis tortor. Nunc et metus urna, et sollicitudin augue.
Vivamus vel justo ligula. Nulla feugiat, velit sollicitudin lacinia accumsan, tellus diam rutrum quam, venenatis porta mauris leo quis lorem. Ut quis enim et quam dapibus molestie at nec ipsum. Integer ut purus vitae nibh commodo mollis. Quisque laoreet tellus sit amet ipsum tincidunt posuere. Maecenas diam nisi, dictum et sollicitudin vel, consequat a diam. Phasellus eu lacus sit amet mauris interdum aliquet ac luctus nisl. Nam vel justo nec diam viverra suscipit. Quisque et purus et ipsum vehicula pulvinar eu quis leo. Donec et quam at ante ullamcorper hendrerit nec eu arcu. Quisque a lectus quis felis fermentum malesuada sit amet ut eros. Curabitur facilisis semper aliquet. Vivamus lectus quam, pulvinar sed pellentesque vitae, rhoncus nec ipsum. Sed porttitor, quam vitae bibendum auctor, tellus ipsum condimentum risus, ut dictum neque justo sed nunc. Nunc bibendum, sapien ac egestas malesuada, nulla mauris ultricies lectus, ut congue eros nisl ac lacus. Etiam hendrerit, nunc in vestibulum consectetur, felis libero dignissim lectus, luctus tempus ipsum lectus eu tellus. Mauris rhoncus nisi id tortor condimentum adipiscing.
Quisque vel dapibus odio. Fusce porta pellentesque ligula, vel porttitor diam pharetra imperdiet. Aliquam viverra lacus eleifend sapien imperdiet id varius eros pretium. In condimentum lacinia leo non ornare. Suspendisse mollis elementum volutpat. Duis gravida metus id ligula consequat dapibus. Vestibulum laoreet vehicula metus, at aliquam sapien porttitor ac. Nunc non eros sapien, sed semper odio. Fusce tincidunt, massa ultricies fermentum dignissim, nunc dui interdum felis, quis interdum nisl diam et nunc. Donec sed magna eros. Fusce dignissim dictum tristique. Aenean molestie, nulla placerat faucibus aliquet, mauris ipsum tristique lectus, quis mollis mauris urna et ipsum. Etiam condimentum sapien at nisi convallis in tincidunt augue pellentesque. Donec tincidunt viverra fermentum. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Fusce at consectetur erat. Vestibulum massa orci, bibendum quis cursus nec, commodo sed mauris. Etiam nec condimentum tortor. Fusce eget congue justo. Proin posuere mauris a sem facilisis egestas.
Maecenas mattis porttitor fringilla. Fusce imperdiet mollis tristique. In non lectus vel risus laoreet ultricies. Mauris sit amet ipsum nunc. Mauris a risus nec ligula adipiscing ullamcorper non eget risus. Maecenas sapien nisi, pellentesque ut ornare in, cursus et metus. Praesent nec ligula purus. In hac habitasse platea dictumst. Praesent feugiat aliquet felis, vitae tempus neque imperdiet ut. Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia Curae; Mauris eleifend, libero quis mollis consequat, orci nibh tempus tortor, ac cursus magna turpis tempus ligula. Suspendisse non blandit dui. Sed vel ultricies sem. Vivamus mauris tortor, feugiat non facilisis vel, egestas vitae massa. Vivamus volutpat, quam eu fringilla aliquam, magna est suscipit nulla, quis pulvinar ipsum odio quis lectus. Etiam est lectus, ultrices in tempor nec, scelerisque eu lacus. Quisque a felis mauris, a pellentesque ligula. Nunc pharetra luctus fermentum. Fusce et velit mauris, eget iaculis ante.
Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas. Nullam fringilla lacus at augue pretium sed consectetur tellus vulputate. Sed gravida augue at nibh congue tristique. Praesent ac orci sit amet sem suscipit facilisis eget ut ligula. Fusce magna odio, scelerisque sed pharetra quis, sollicitudin ut massa. Sed nunc metus, lacinia sed ullamcorper at, congue non neque. Cras eu dui quis massa pretium posuere. Morbi purus augue, convallis tempus consectetur ut, ultricies non tortor. Quisque in leo lacus. Nulla sem turpis, tincidunt in congue pulvinar, placerat pharetra velit. Mauris at purus urna. Maecenas interdum velit vitae diam ultrices tempus. Curabitur molestie aliquet odio. Etiam tempus mauris ut dui tincidunt sodales auctor dolor vestibulum. Donec tincidunt, arcu quis ultrices accumsan, nisl dui aliquam arcu, a tempor elit nulla vitae velit. Quisque sed velit lectus, sit amet sodales risus.
