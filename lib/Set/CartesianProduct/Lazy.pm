use strict;
use warnings;
package Set::CartesianProduct::Lazy;

# ABSTRACT: lazily calculate the tuples of a cartesian-product

use List::Util qw( reduce );
use Scalar::Util qw( reftype );
use Data::Dumper;

=method new

Construct a new object. Takes the following arguments:

=begin :list

* options
A hashref of options that modify the way the object works.
If you don't want to specify any options, simply omit this
argument.

=begin :list

= less_lazy
Makes the get method slightly faster, at the expense
of not being able to account for any modifications made
to the original input arrays, and using more memory.
If you modify one of the arrays used to consruct the object,
the results of all the other methods are B<undefined>.
You might get the wrong answer. You might trigger an
exception, you might get mutations that give you super-powers
at the expense of never being able to touch another human
being without killing them.

=end :list

* sets
A list of arrayrefs from which to compute the cartesian product.
You can list as many as you want.

=end :list

Some examples:

  my $cpl = Set::CartesianProduct::Lazy->new(\@a, [qw(foo bar baz)], \@b);
  my $cpl = Set::CartesianProduct::Lazy->new( { less_lazy => 1 }, \@a, \@b, \@c);


=cut
sub new {
  my $class = shift;
  my %opts = map { %$_ } grep { reftype $_ eq 'HASH' } @_;
  my @sets = grep { reftype $_ eq 'ARRAY' } @_;

  my $getsub = __make_getsub(\%opts, \@sets);

  return bless { %opts, sets => \@sets, getsub => $getsub }, $class;
}

sub __make_getsub {
  my ($opts, $sets_ref) = @_;

  # TODO: eval code to produce the sub so the code isn't duplicated

  if ($opts->{less_lazy}) {

    # pre-calculate some things, so we don't have to every time.
    my @sets = @$sets_ref;
    my @info = map {
      [ $_, (scalar @{$sets[$_]}), reduce { $a * @$b } 1, @sets[$_ + 1 .. $#sets] ];
    } 0 .. $#sets;

    return sub {
      my ($n) = @_;

      my @tuple = map {
        my ($set_num, $set_size, $factor) = @$_;
        $sets[ $set_num ][ int( $n / $factor ) % $set_size ];
      } @info;

      return wantarray ? @tuple : \@tuple;
    };
  }

  return sub {
    my ($n) = @_;

    my @tuple;

    my @sets = @$sets_ref;

    for my $set_num (0 .. $#sets) {
      my $set_size = @{ $sets[$set_num] };
      my $factor   = reduce { $a * @$b } 1, @sets[$set_num + 1 .. $#sets];
      my $idx      = int( $n / $factor ) % $set_size;

      push @tuple, $sets[$set_num][$idx];
    }

    return wantarray ? @tuple : \@tuple;
  };
}


=method get

Return the tuple at the given "position" in the cartesian product.
The positions, like array indices, are based at 0.

If called in scalar context, an arrayref is returned. If called in list
context, a list is returned.

If you ask for a position that exceeds the bounds of the array defining the
cartesian product the result will be... interesting. I won't make any
guarantees, but if it's useful, let me know.

Examples:

  my @tuple  = $cpl->get(12);                # list context
  my $tuple2 = $cpl->get( $cpl->count / 2 ); # scalar context

  my $fail  = $cpl->get( $cpl->count ); # probably equal to ->get(0)
  my $fail2 = $cpl->get( -1 );          # who knows

=cut
sub get { my $self = shift; $self->{getsub}->(@_) }


=method count

Return the count of tuples that would be in the cartesian
product if it had been generated.

Example:

  my $count = $cpl->count;

=cut
{
  no warnings 'once';
  sub count { return reduce { $a * @$b } 1, @{ shift->{sets} || [] } }
}

=method last_idx

Return the index of the last tuple that would be in the cartesian
product if it had been generated. This is just for conveniece
so you don't have to write code like this:

  for my $i ( 0 .. $cpl->count - 1 ) { ... }

And you can do this instead:

  for my $i ( 0 .. $cpl->last_idx ) { ... }

Which I feel is more readable.

=cut
sub last_idx { return shift->count - 1 }


1 && q{a set in time saves nine};
__END__

=head1 SYNOPSIS

  my @a   = qw( foo bar baz bah );
  my @b   = qw( wibble wobble weeble );
  my @c   = qw( nip nop );

  my $cpl = Set::CartesianProduct::Lazy->new( \@a, \@b, \@c );

  my $tuple;

  $tuple = $cpl->get(0);   # [ qw( foo wibble nip ) ]

  $tuple = $cpl->get(21);  # [ qw( bah wobble nop ) ]

  $tuple = $cpl->get(7);   # [ qw( bar wobble nip ) ]

  $cpl->count;             # 24
  $cpl->last_idx;          # 23


=head1 DESCRIPTION

If you have some number of arrays, say like this:

  @a = qw( foo bar baz bah );
  @b = qw( wibble wobble weeble );
  @c = qw( nip nop );

And you want all the combinations of one element from each array, like this:

  @cp = (
    [qw( foo wibble nip )],
    [qw( foo wibble nop )],
    [qw( foo wobble nip )],
    [qw( foo wobble nop )],
    [qw( foo weeble nip )],
    # ...
    [qw( bah wobble nop )],
    [qw( bah weeble nip )],
    [qw( bah weeble nop )],
  )

What you want is a Cartesian Product (also called a Cross Product, but my
mathy friends insist that Cartesian is correct)

Yes, there are already a lot of other modules on the CPAN that do this.
I won't claim that this module does this calculation any better or faster,
but it does do it I<differently>, as far as I can tell.

Nothing else seemed to offer a specific feature - I needed to pick random
individual tuples from the Cartesian Product, I<without> iterating over
the whole set and I<without> calculating any tuples until they were
asked for. Bonus points for not making a copy of the original input sets.

I needed the calculation to be lazy, and I needed random-access with O(1)
(well, O(n) for the persnickety but n is so small it might as well be 1)
retrieval time, even if that meant a slower implementation overall. And
I didn't want to use RAM unnecessarily by creating copies of the original
arrays, since the data I was working with was of a significant size.

