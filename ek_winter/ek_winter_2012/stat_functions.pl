#!/usr/bin/perl

# use strict;

# mean calculates the numerical average of a list of numbers
# TODO add function description
sub mean {
    my @numbers = @_;
    my $sum = 0;

    foreach my $number (@numbers) {
        $sum += $number;
    }

    if(@numbers != 0) {
        return $sum / @numbers;
    } else {
        die("Trying to divide by zero in mean!");
    }
}

# std_dev calculate the standard deviation of a list of numbers

sub std_dev {
    my @numbers = @_;
    my $mean = mean(@numbers);
    my $sum_std = 0;

    foreach my $num (@numbers) {
        $sum_std += ($num - $mean)**2;
    }

    # check numbers non zero
    if(@numbers != 0) {
        return sqrt($sum_std / @numbers);
    } else {
        die("Trying to divide by zero in std_dev!");
    }
}

#finds the maximum value in an array
sub max {
	my @numbers = @_;
	my $max = $numbers[0];
	for ($i = 0; $i < scalar(@numbers); $i++)
	{
		if ($numbers[$i] > $max)
		{
			$max = $numbers[$i];
		}
	}
	return $max;
}

#finds the minimum value in an array
sub min {
	my @numbers = @_;
	my $min = $numbers[0];
	for ($i = 0; $i < scalar(@numbers); $i++)
	{
		if ($numbers[$i] < $min)
		{
			$min = $numbers[$i];
		}
	}
	return $min;
}

1;
