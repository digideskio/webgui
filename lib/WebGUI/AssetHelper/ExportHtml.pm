package WebGUI::AssetHelper::ExportHtml;

use strict;
use Class::C3;
use base qw/WebGUI::AssetHelper/;
use WebGUI::User;
use WebGUI::HTML;

=head1 LEGAL

 -------------------------------------------------------------------
  WebGUI is Copyright 2001-2009 Plain Black Corporation.
 -------------------------------------------------------------------
  Please read the legal notices (docs/legal.txt) and the license
  (docs/license.txt) that came with this distribution before using
  this software.
 -------------------------------------------------------------------
  http://www.plainblack.com                     info@plainblack.com
 -------------------------------------------------------------------

=head1 NAME

Package WebGUI::AssetHelper::ExportHtml

=head1 DESCRIPTION

Export this assets, and all children as HTML.

=head1 METHODS

These methods are available from this class:

=cut

#-------------------------------------------------------------------

=head2 process ( $class, $asset )

Opens a new tab for displaying the form and the output for exporting a branch.

=cut

sub process {
    my ($class, $asset) = @_;
    my $session = $asset->session;
    my $i18n = WebGUI::International->new($session, "Asset");
    if (! $asset->canEdit) {
        return {
            error => $i18n->get('38', 'WebGUI'),
        }
    }

    return {
        openDialog => '?op=assetHelper;className=' . $class . ';method=export;assetId=' . $asset->getId,
    };
}

#-------------------------------------------------------------------

=head2 www_export

Displays the export page administrative interface

=cut

sub www_export {
    my ($class, $asset) = @_;
    my $session = $asset->session;
    return $session->privilege->insufficient() unless ($session->user->isInGroup(13));
    my ( $style, $url ) = $session->quick(qw{ style url });
    $style->setLink( $url->extras('hoverhelp.css'), { rel => "stylesheet", type => "text/css" } );
    $style->setScript( $url->extras('yui/build/yahoo-dom-event/yahoo-dom-event.js') );
    $style->setScript( $url->extras('yui/build/container/container-min.js') );
    $style->setScript( $url->extras('hoverhelp.js') );
    $style->setRawHeadTags( <<'ENDHTML' );
<style type="text/css">
    label.formDescription { display: block; margin-top: 1em; font-weight: bold }
</style>
ENDHTML

    my $i18n    = WebGUI::International->new($session, "Asset");
    my $f       = WebGUI::HTMLForm->new($session, -action => $asset->getUrl);
    $f->hidden( name => 'op', value => 'assetHelper' );
    $f->hidden( name => 'className', value => $class );
    $f->hidden( name => 'assetId', value => $asset->getId );
    $f->hidden(
        name           => "method",
        value          => "exportStatus"
    );
    $f->integer(
        label          => $i18n->get('Depth'),
        hoverHelp      => $i18n->get('Depth description'),
        name           => "depth",
        value          => 99,
    );
    $f->selectBox(
        label          => $i18n->get('Export as user'),
        hoverHelp      => $i18n->get('Export as user description'),
        name           => "userId",
        options        => $session->db->buildHashRef("select userId, username from users"),
        value          => [1],
    );
    $f->text(
        label          => $i18n->get("directory index"),
        hoverHelp      => $i18n->get("directory index description"),
        name           => "index",
        value          => "index.html"
    );

    $f->text(
        label          => $i18n->get("Export site root URL"),
        name           => 'exportUrl',
        value          => '',
        hoverHelp      => $i18n->get("Export site root URL description"),
    );

    # TODO: maybe add copy options to these boxes alongside symlink
    $f->selectBox(
        label          => $i18n->get('extrasUploads form label'),
        hoverHelp      => $i18n->get('extrasUploads form hoverHelp'),
        name           => "extrasUploadsAction",
        options        => { 
            'symlink'  => $i18n->get('extrasUploads form option symlink'),
            'none'     => $i18n->get('extrasUploads form option none') },
        value          => ['none'],
    );
    $f->selectBox(
        label          => $i18n->get('rootUrl form label'),
        hoverHelp      => $i18n->get('rootUrl form hoverHelp'),
        name           => "rootUrlAction",
        options        => {
            'symlink'  => $i18n->get('rootUrl form option symlinkDefault'),
            'none'     => $i18n->get('rootUrl form option none') },
        value          => ['none'],
    );
    $f->submit;
    my $message;
    eval { $asset->exportCheckPath };
    if($@) {
        $message = $@;
    }
    return $session->style->process( 
        $message . $f->print,
        "PBtmpl0000000000000137"
    );
}


#-------------------------------------------------------------------

=head2 www_exportStatus

Displays the export status page

=cut

sub www_exportStatus {
    my ($class, $asset) = @_;
    my $session = $asset->session;
    return $session->privilege->insufficient() unless ($session->user->isInGroup(13));
    my $i18n        = WebGUI::International->new($session, "Asset");
    my $pb  = WebGUI::ProgressBar->new( $session );

    my $args = {
        quiet               => 1, # We'll wrap subs to update the ProgressBar
        userId              => $session->form->process('userId'),
        indexFileName       => $session->form->process('index'),
        extrasUploadAction  => $session->form->process('extrasUploadsAction'),
        rootUrlAction       => $session->form->process('rootUrlAction'),
        depth               => $session->form->process('depth'),
        exportUrl           => $session->form->process('exportUrl'),
    };

    return $session->response->stream( sub {
        my ( $session ) = @_;
        return $pb->run(
            admin => 1,
            title => $i18n->get('edit branch'),
            icon  => $session->url->extras('adminConsole/assets.gif'),
            code  => sub {
                my ( $bar ) = @_;
                $bar->update( 'Preparing...' );
                $bar->total( $asset->getDescendantCount );
                $bar->update( 'Asset ID ' . $asset->getId );

                my $message;
                eval {
                    $message = $asset->exportAsHtml( $args );
                };
                if ( $@ ) {
                    return { error => "$@" };
                }
                return { message => $message || "Export successful!" };
            },
            wrap => {
                'WebGUI::Asset::exportWriteFile' => sub {
                    my ($bar, $original, $asset, @args) = @_;
                    $bar->update( "Exporting " . $asset->getTitle );
                    return $asset->$original(@args);
                },
            },
        );
    } );
}

1;