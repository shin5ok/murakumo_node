use strict;
use warnings;

use Murakumo_Node;

my $app = Murakumo_Node->apply_default_middlewares(Murakumo_Node->psgi_app);
$app;

