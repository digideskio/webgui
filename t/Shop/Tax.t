# vim:syntax=perl
#-------------------------------------------------------------------
# WebGUI is Copyright 2001-2008 Plain Black Corporation.
#-------------------------------------------------------------------
# Please read the legal notices (docs/legal.txt) and the license
# (docs/license.txt) that came with this distribution before using
# this software.
#------------------------------------------------------------------
# http://www.plainblack.com                     info@plainblack.com
#------------------------------------------------------------------

# Write a little about what this script tests.
# 
#

use FindBin;
use strict;
use lib "$FindBin::Bin/../lib";
use Test::More;
use Test::Deep;
use Exception::Class;

use WebGUI::Test; # Must use this before any other WebGUI modules
use WebGUI::Session;
use WebGUI::Text;
use WebGUI::Shop::Cart;
use WebGUI::Shop::AddressBook;

#----------------------------------------------------------------------------
# Init
my $session         = WebGUI::Test->session;

#----------------------------------------------------------------------------
# Tests

my $tests = 68;
plan tests => 1 + $tests;

#----------------------------------------------------------------------------
# put your tests here

my $loaded = use_ok('WebGUI::Shop::Tax');

my $storage;

SKIP: {

skip 'Unable to load module WebGUI::Shop::Tax', $tests unless $loaded;

#######################################################################
#
# new
#
#######################################################################

my $taxer = WebGUI::Shop::Tax->new($session);

isa_ok($taxer, 'WebGUI::Shop::Tax');

isa_ok($taxer->session, 'WebGUI::Session', 'session method returns a session object');

is($session->getId, $taxer->session->getId, 'session method returns OUR session object');

#######################################################################
#
# getItems
#
#######################################################################

my $taxIterator = $taxer->getItems;

isa_ok($taxIterator, 'WebGUI::SQL::ResultSet');

is($taxIterator->rows, 0, 'WebGUI ships with no predefined tax data');

#######################################################################
#
# add
#
#######################################################################

my $e;

eval{$taxer->add()};

$e = Exception::Class->caught();
isa_ok($e, 'WebGUI::Error::InvalidParam', 'add: correct type of exception thrown for missing hashref');
is($e->error, 'Must pass in a hashref of params', 'add: correct message for a missing hashref');

eval{$taxer->add({})};
$e = Exception::Class->caught();
isa_ok($e, 'WebGUI::Error::InvalidParam', 'add: correct type of exception thrown for empty hashref');
is($e->error, 'Hash ref must contain a field key with a defined value', 'add: correct message for an empty hashref');

my $taxData = {
    field   => undef,
};

eval{$taxer->add($taxData)};
like($@, qr{},
    'add: error handling for undefined field key');
$e = Exception::Class->caught();
isa_ok($e, 'WebGUI::Error::InvalidParam', 'add: correct type of exception thrown for valueless hash key');
is($e->error, 'Hash ref must contain a field key with a defined value', 'add: correct message for valueless hash key');

$taxData->{field} = 'state';

eval{$taxer->add($taxData)};
$e = Exception::Class->caught();
isa_ok($e, 'WebGUI::Error::InvalidParam', 'add: correct type of exception thrown for missing field hash key');
is($e->error, 'Hash ref must contain a value key with a defined value', 'add: correct message for missing field hash key');

$taxData->{value} = undef;

eval{$taxer->add($taxData)};
$e = Exception::Class->caught();
isa_ok($e, 'WebGUI::Error::InvalidParam', 'add: correct type of exception thrown for missing hash key');
is($e->error, 'Hash ref must contain a value key with a defined value', 'add: correct message for missing field hash value');

$taxData->{value} = 'Oregon';

eval{$taxer->add($taxData)};
$e = Exception::Class->caught();
isa_ok($e, 'WebGUI::Error::InvalidParam', 'add: correct type of exception thrown for missing hash key');
is($e->error, 'Hash ref must contain a taxRate key with a defined value', 'add: correct message for missing taxRate hash key');

$taxData->{taxRate} = undef;

eval{$taxer->add($taxData)};
$e = Exception::Class->caught();
isa_ok($e, 'WebGUI::Error::InvalidParam', 'add: correct type of exception thrown for missing hash value');
is($e->error, 'Hash ref must contain a taxRate key with a defined value', 'add: correct message for missing taxRate hash value');

my $taxData = {
    field   => 'state',
    value   => 'Oregon',
    taxRate => '0',
};

my $oregonTaxId = $taxer->add($taxData);

ok($session->id->valid($oregonTaxId), 'add method returns a valid GUID');

$taxIterator = $taxer->getItems;
is($taxIterator->rows, 1, 'add added only 1 row to the tax table');

my $addedData = $taxIterator->hashRef;
$taxData->{taxId} = $oregonTaxId;

cmp_deeply($taxData, $addedData, 'add put the right data into the database for Oregon');

$taxData = {
    field   => 'state',
    value   => 'Wisconsin',
    taxRate => '5',
};

my $wisconsinTaxId = $taxer->add($taxData);

$taxIterator = $taxer->getItems;
is($taxIterator->rows, 2, 'add added another row to the tax table');

$taxData = {
    field   => 'state',
    value   => 'Oregon',
    taxRate => '0.1',
};

eval {$taxer->add($taxData)};

##This error is thrown by DBI, not us.
ok($@, 'add threw an exception to having taxes in Oregon when they were defined as 0 initially');

$taxIterator = $taxer->getItems;
is($taxIterator->rows, 2, 'add did not add another row since it would be a duplicate');

##Madison zip codes:
##53701-53709
##city rate: 0.5%
##Wisconsin rate 5.0%

#######################################################################
#
# delete
#
#######################################################################

eval{$taxer->delete()};
$e = Exception::Class->caught();
isa_ok($e, 'WebGUI::Error::InvalidParam', 'delete: error handling for missing hashref');
is($e->error, 'Must pass in a hashref of params', 'delete: error message for missing hashref');

eval{$taxer->delete({})};
$e = Exception::Class->caught();
isa_ok($e, 'WebGUI::Error::InvalidParam', 'delete: error handling for missing key in hashref');
is($e->error, 'Hash ref must contain a taxId key with a defined value', 'delete: error message for missing key in hashref');

eval{$taxer->delete({ taxId => undef })};
$e = Exception::Class->caught();
isa_ok($e, 'WebGUI::Error::InvalidParam', 'delete: error handling for an undefined taxId value');
is($e->error, 'Hash ref must contain a taxId key with a defined value', 'delete: error message for an undefined taxId value');

$taxer->delete({ taxId => $oregonTaxId });

$taxIterator = $taxer->getItems;
is($taxIterator->rows, 1, 'One row was deleted from the tax table');

$taxer->delete({ taxId => $session->id->generate });

$taxIterator = $taxer->getItems;
is($taxIterator->rows, 1, 'No rows were deleted from the table since the requested id does not exist');
is($taxIterator->hashRef->{taxId}, $wisconsinTaxId, 'The correct tax information was deleted');

#######################################################################
#
# exportTaxData
#
#######################################################################

$storage = $taxer->exportTaxData();
isa_ok($storage, 'WebGUI::Storage', 'exportTaxData returns a WebGUI::Storage object');
is($storage->{_part1}, 'temp', 'The storage object is in the temporary area');
ok(-e $storage->getPath('siteTaxData.csv'), 'siteTaxData.csv file exists in the storage object');
cmp_ok($storage->getFileSize('siteTaxData.csv'), '!=', 0, 'CSV file is not empty');
my @fileLines = split /\n+/, $storage->getFileContentsAsScalar('siteTaxData.csv');
#my @fileLines = ();
my @header = WebGUI::Text::splitCSV($fileLines[0]);
my @expectedHeader = qw/field value taxRate/;
cmp_deeply(\@header, \@expectedHeader, 'exportTaxData: header line is correct');
my @row1 = WebGUI::Text::splitCSV($fileLines[1]);
use Data::Dumper;
my $wiData = $taxer->getItems->hashRef;
##Need to ignore the taxId from the database
cmp_bag([ @{ $wiData }{ @expectedHeader } ], \@row1, 'exportTaxData: first line of data is correct');

#######################################################################
#
# import
#
#######################################################################

eval { $taxer->importTaxData(); };
$e = Exception::Class->caught();
isa_ok($e, 'WebGUI::Error::InvalidParam', 'importTaxData: error handling for an undefined taxId value');
is($e->error, 'Must provide the path to a file', 'importTaxData: error handling for an undefined taxId value');

eval { $taxer->importTaxData('/path/to/nowhere'); };
$e = Exception::Class->caught();
isa_ok($e, 'WebGUI::Error::InvalidFile', 'importTaxData: error handling for file that does not exist in the filesystem');
is($e->error, 'File could not be found', 'importTaxData: error handling for file that does not exist in the filesystem');
cmp_deeply(
    $e,
    methods(
        brokenFile => '/path/to/nowhere',
    ),
    'importTaxData: error handling for file that does not exist in the filesystem',
);

my $taxFile = WebGUI::Test->getTestCollateralPath('taxTables/goodTaxTable.csv');

SKIP: {
    skip 'Root will cause this test to fail since it does not obey file permissions', 1
        if $< == 0;

    my $originalChmod = (stat $taxFile)[2];
    chmod oct(0000), $taxFile;

    eval { $taxer->importTaxData($taxFile); };
    $e = Exception::Class->caught();
    isa_ok($e, 'WebGUI::Error::InvalidFile', 'importTaxData: error handling for file that cannot be read');
    is($e->error, 'File is not readable', 'importTaxData: error handling for file that that cannot be read');
    cmp_deeply(
        $e,
        methods(
            brokenFile => $taxFile,
        ),
        'importTaxData: error handling for file that that cannot be read',
    );

    chmod $originalChmod, $taxFile;

}

my $expectedTaxData = [
        {
            field   => 'state',
            value   => 'Wisconsin',
            taxRate => 5.0,
        },
        {
            field   => 'code',
            value   => 53701,
            taxRate => 0.5,
        },
];

ok(
    $taxer->importTaxData(
        $taxFile
    ),
    'Good tax data inserted',
);

$taxIterator = $taxer->getItems;
is($taxIterator->rows, 2, 'import: Old data deleted, new data imported');
my @goodTaxData = _grabTaxData($taxIterator);
cmp_bag(
    \@goodTaxData,
    $expectedTaxData,
    'Correct data inserted.',
);

ok(
    $taxer->importTaxData(
        WebGUI::Test->getTestCollateralPath('taxTables/orderedTaxTable.csv')
    ),
    'Reordered tax data inserted',
);

$taxIterator = $taxer->getItems;
is($taxIterator->rows, 2, 'import: Old data deleted, new data imported again');
my @orderedTaxData = _grabTaxData($taxIterator);
cmp_bag(
    \@orderedTaxData,
    $expectedTaxData,
    'Correct data inserted, with CSV in different columnar order.',
);

ok(
    $taxer->importTaxData(
        WebGUI::Test->getTestCollateralPath('taxTables/commentedTaxTable.csv')
    ),
    'Commented tax data inserted',
);

$taxIterator = $taxer->getItems;
is($taxIterator->rows, 2, 'import: Old data deleted, new data imported the third time');
my @orderedTaxData = _grabTaxData($taxIterator);
cmp_bag(
    \@orderedTaxData,
    $expectedTaxData,
    'Correct data inserted, with comments in the CSV file',
);

ok(
    ! $taxer->importTaxData(
        WebGUI::Test->getTestCollateralPath('taxTables/emptyTaxTable.csv')
    ),
    'Empty tax data not inserted',
);

my $failure;
eval {
    $failure = $taxer->importTaxData(
        WebGUI::Test->getTestCollateralPath('taxTables/badTaxTable.csv')
    );
};
ok (!$failure, 'Tax data not imported');
$e = Exception::Class->caught();
isa_ok($e, 'WebGUI::Error::InvalidFile', 'importTaxData: a file with a ');
cmp_deeply(
    $e,
    methods(
        error      => 'Error found in the CSV file',
        brokenFile => WebGUI::Test->getTestCollateralPath('taxTables/badTaxTable.csv'),
        brokenLine => 1,
    ),
    'importTaxData: error handling for file that that cannot be read',
);

#######################################################################
#
# getTaxRates
#
#######################################################################

##Set up the tax information
$taxer->importTaxData(
    WebGUI::Test->getTestCollateralPath('taxTables/largeTaxTable.csv')
),
my $book = WebGUI::Shop::AddressBook->create($session);
my $taxingAddress = $book->addAddress({
    label => 'taxing',
    city  => 'Madison',
    state => 'WI',
    code  => '53701',
    country => 'USA',
});
my $taxFreeAddress = $book->addAddress({
    label => 'no tax',
    city  => 'Portland',
    state => 'OR',
    code  => '97123',
    country => 'USA',
});

eval { $taxer->getTaxRates(); };
$e = Exception::Class->caught();
isa_ok($e, 'WebGUI::Error::InvalidObject', 'calculate: error handling for not sending a cart');
cmp_deeply(
    $e,
    methods(
        error => 'Need an address.',
        got   => '',
        expected => 'WebGUI::Shop::Address',
    ),
    'importTaxData: error handling for file that does not exist in the filesystem',
);

cmp_deeply(
    $taxer->getTaxRates($taxingAddress),
    [5, 0.5],
    'getTaxRates: return correct data for a state with tax data'
);

cmp_deeply(
    $taxer->getTaxRates($taxFreeAddress),
    [0.0],
    'getTaxRates: return correct data for a state with no tax data'
);

#######################################################################
#
# calculate
#
#######################################################################

eval { $taxer->calculate(); };
$e = Exception::Class->caught();
isa_ok($e, 'WebGUI::Error::InvalidParam', 'calculate: error handling for not sending a cart');
is($e->error, 'Must pass in a WebGUI::Shop::Cart object', 'calculate: error handling for not sending a cart');

##Build a cart, add some Donation SKUs to it.  Set one to be taxable.

my $cart = WebGUI::Shop::Cart->create($session);
$cart->update({ shippingAddressId => $taxingAddress->getId});

##Set up the tax information
$taxer->importTaxData(
    WebGUI::Test->getTestCollateralPath('taxTables/goodTaxTable.csv')
),

my $taxableDonation = WebGUI::Asset->getRoot($session)->addChild({
    className => 'WebGUI::Asset::Sku::Donation',
    title     => 'Taxable donation',
    defaultPrice => 100.00,
});

$cart->addItem($taxableDonation);

foreach my $item (@{ $cart->getItems }) {
    $item->setQuantity(1);
}

my $tax = $taxer->calculate($cart);
is($tax, 5.5, 'calculate: simple tax calculation on 1 item in the cart');

$taxableDonation->purge;
$cart->delete;
$book->delete;
}

sub _grabTaxData {
    my $tax = shift;
    my @taxData = ();
    while (my $taxRow = $tax->hashRef) {
        delete $taxRow->{'taxId'};
        push @taxData, $taxRow;
    }
    return @taxData;
}

#----------------------------------------------------------------------------
# Cleanup
END {
    $session->db->write('delete from tax');
    $session->db->write('delete from cart');
    $session->db->write('delete from addressBook');
    $session->db->write('delete from address');
    $storage->delete;
}
