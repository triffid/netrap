package Netrap;

=blah
sub list_printer {
	my ($sock, $request) = @_;
	for my $printer (@printers) {
		push @{$sock->{replies}}, $printer->{name};
	}
	$WriteSelector->add($sock->{sock});
}

sub list_socket {
	my ($sock, $request) = @_;
	for my $socket (keys %ErrorSockets) {
		push @{$sock->{replies}}, $ErrorSockets{$socket}->{name};
	}
	$WriteSelector->add($sock->{sock});
}

our %targets = {
	printer => {
		add => undef,
		list => list_printer,
		query => undef,
	},
	file => {
		upload => undef,
		download => undef,
		prepare => undef,
		prepared => undef,
	},
	socket => {
		list => list_socket,
		close => undef,
	},
	print => {
		pause => undef,
		resume => undef,
		restart => undef,
		status => undef,
	},
};

# This is called once as soon as a request is received, and then every time new data becomes available.
# called functions should set $request->{complete} = 1 when they're finished.
sub handleRequest {
	my ($sock, $request) = (shift, shift);
	my $query = $request->{query};
	if ($query =~ /^(\w+)\W(\w+)$/) {
		my ($action, $target) = ($1, $2);
		if (defined $targets{$target}->{$action}) {
			$targets{$target}->{$action}($sock, $request);
		}
	}
}
=cut

1;
