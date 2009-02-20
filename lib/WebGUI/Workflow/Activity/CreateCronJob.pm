package WebGUI::Workflow::Activity::CreateCronJob;


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

=cut

use strict;
use base 'WebGUI::Workflow::Activity';
use WebGUI::Workflow::Cron;


=head1 NAME

Package WebGUI::Workflow::Activity::CreateCronJob

=head1 DESCRIPTION

Creates a new cron job passing the object that is current running to the new workflow instance created by the cron job.

=head1 SYNOPSIS

See WebGUI::Workflow::Activity for details on how to use any activity.

=head1 METHODS

These methods are available from this class:

=cut

#-------------------------------------------------------------------

=head2 definition ( session, definition )

See WebGUI::Workflow::Activity::defintion() for details.

=cut 

sub definition {
	my $class = shift;
	my $session = shift;
	my $definition = shift;
	my $i18n = WebGUI::International->new($session, "Workflow_Cron");
	my %priorities = ();
	tie %priorities, 'Tie::IxHash';
	%priorities = (1=>$i18n->get("high"), 2=>$i18n->get("medium"), 3=>$i18n->get("low"));
	my %properties = ();
	tie %properties, 'Tie::IxHash';
	%properties =		( 
			enabled=>{
				fieldType=>"yesNo",
				defaultValue=>0,
				label=>$i18n->get("is enabled"),
				hoverHelp=>$i18n->get("is enabled help")
				},
			runOnce=>{
				fieldType=>"yesNo",
				defaultValue=>1,
				label=>$i18n->get("run once"),
				hoverHelp=>$i18n->get("run once help")
				},
			workflowIdToRun=>{
				fieldType=>"workflow",
				defaultValue=>undef,
				label=>$i18n->get("workflow"),
                		hoverHelp=>$i18n->get("workflow help")
				},
			priority=>{
				fieldType=>"radioList",
				vertical=>1,
				defaultValue=>2,
				options=>\%priorities,
				label=>$i18n->get("priority"),
				hoverHelp=>$i18n->get("priority help")
				},
			minuteOfHour=>{
				fieldType=>"text",
				defaultValue=>0,
				label=>$i18n->get("minute of hour"),
				hoverHelp=>$i18n->get("minute of hour help")
				},
			hourOfDay=>{
				fieldType=>"text",
				defaultValue=>"*",
				label=>$i18n->get("hour of day"),
				hoverHelp=>$i18n->get("hour of day help")
				},
			dayOfMonth=>{
				fieldType=>"text",
				defaultValue=>"*",
				label=>$i18n->get("day of month"),
				hoverHelp=>$i18n->get("day of month help")
				},
			monthOfYear=>{
				fieldType=>"text",
				defaultValue=>"*",
				label=>$i18n->get("month of year"),
				hoverHelp=>$i18n->get("month of year")
				},
			dayOfWeek=>{
				fieldType=>"text",
				defaultValue=>"*",
				label=>$i18n->get("day of week"),
				hoverHelp=>$i18n->get("day of week help")
				}
			);
	push(@{$definition}, {
		name=>$i18n->get("create cron job"),
		properties=> \%properties
		});
	return $class->SUPER::definition($session,$definition);
}

#-------------------------------------------------------------------

=head2 execute (  )

See WebGUI::Workflow::Activity::execute() for details.

=cut

sub execute {
	my $self = shift;
	my $object = shift;
	my $instance = shift;
	my $cron = WebGUI::Workflow::Cron->create($self->session, {
		title=>"Generated by workflow instance ".$instance->getId." (".$self->get("title").")",
		enabled=>$self->get("enabled"),
		runOnce=>$self->get("runOnce"),
		workflowId=>$self->get("workflowIdToRun"),
		priority=>$self->get("priority"),
		minuteOfHour=>$self->get("minuteOfHour"),
		hourOfDay=>$self->get("hourOfDay"),
		dayOfMonth=>$self->get("dayOfMonth"),
		monthOfYear=>$self->get("monthOfYear"),
		dayOfWeek=>$self->get("dayOfWeek"),
		className=>$instance->get("className"),
		methodName=>$instance->get("methodName"),
		parameters=>$instance->get("parameters")
		});
	return defined $cron ? $self->COMPLETE : $self->ERROR;
}




1;


