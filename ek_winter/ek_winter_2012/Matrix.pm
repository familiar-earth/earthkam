#!/usr/bin/perl -w

# TODO fix up this file's documentation

# Contains Matrix data type, for use in linear regressions 
package Matrix;

use Storable qw(dclone);
use overload '""' => 'to_string', 
       '+' => 'matrixAdd',
        '-' => 'matrixSub',
         '*' => 'matrixMultiply';

sub new 
{
  my $invocant = shift;
  my $class = ref($invocant) || $invocant;
  my @self = @_;
  # Check to ensure that data set has equal number of elements in each row:
  foreach $row (@self)
  {
    ($#{$row} == $#{$self[0]}) or die "Data set is not a matrix";
  }
  return bless \@self, $class;
}

sub identity
{
  my $self = shift;
  return $self;
}

sub to_string
{
  my $self = shift;
  my $output = "";
  foreach $row (@{$self})
  {
    foreach $element (@{$row})
    {
      $output .= "$element ";
    }
    $output .= "\n";
  }
  return $output;
}

sub matrixAdd
{
  my ($mat1, $mat2) = @_;
  @final = ();
  ($#{$mat1} == $#{$mat2}) or die "Error: Matrices must have same dimensions to add.";
  for(my $i = 0; $i <= $#{$mat1}; $i++)
  {
    push @final, [];
    ($#{$mat1->[$i]} == $#{$mat2->[$i]}) or die "Error: Matrices must have the same dimensions to add.";
    for(my $j = 0; $j <= $#{$mat1->[$i]}; $j++)
    {
      push @{$final[$i]}, ($mat1->[$i][$j] + $mat2->[$i][$j]);
    }
  }
  return new Matrix @final;
}

sub matrixSub
{
  my ($mat1, $mat2) = @_;
  @final = ();
  ($#{$mat1} == $#{$mat2}) or die "Error: Matrices must have same dimensions to add.";
  for(my $i = 0; $i <= $#{$mat1}; $i++)
  {
    push @final, [];
    ($#{$mat1->[$i]} == $#{$mat2->[$i]}) or die "Error: Matrices must have the same dimensions to add.";
    for(my $j = 0; $j <= $#{$mat1->[$i]}; $j++)
    {
      push @{$final[$i]}, ($mat1->[$i][$j] - $mat2->[$i][$j]);
    }
  }
  return new Matrix @final;
}

sub matrixMultiply
{
  my ($mat1, $mat2) = @_;
  # Check to ensure that matrix multiplication is defined for args:
  ($#{$mat1->[0]} == $#{$mat2}) or die "Matrix multiplication undefined for given arguments.";
  @answer = ();
  for(my $i = 0; $i <= $#{$mat1}; $i++)
  {
    push @answer, [];
    for (my $j = 0; $j <= $#{$mat2->[0]}; $j++)
    {
      my $sum = 0;
      for (my $k = 0; $k <= $#{$mat1->[0]}; $k++)
      {
        $sum += ($mat1->[$i][$k] * $mat2->[$k][$j]);
      }
      push @{$answer[$i]}, $sum;  
    } 
  }
  return new Matrix @answer;
}

sub transpose
{
  my $self = shift;
  my @answer = ();

  foreach $x (@{$self->[0]})
  {
    push @answer, [];
  }

  for (my $i = 0; $i <= $#{$self}; $i++)
  {
    for (my $j = 0; $j <= $#{$self->[0]}; $j++)
    {
      push @{$answer[$j]}, $self->[$i][$j]
    }
  }
  return new Matrix @answer;
}


sub gauss_jordan
{
  # Algorithm adopted from a public domain algorithm in Python
  my $original = shift;
  my $self = dclone($original);
  my $eps = 1.0 / (10**10);
  my $h = scalar(@{$self});
  my $w = scalar(@{$self->[0]});
  for(my $y = 0; $y < $h; $y++)
  {
    my $maxrow = $y;
    for(my $y2 = $y + 1; $y2 < $h; $y2++)
    {
      if (abs($self->[$y2][$y]) > abs($self->[$maxrow][$y]))
      {
        $maxrow = $y2;
      }
    }
    my $temp = $self->[$y];
    $self->[$y] = $self->[$maxrow];
    $self->[$maxrow] = $temp;

    #Check to see if matrix is singular:
    if (abs($self->[$y][$y]) <= $eps)
    {
      #print $self->[$y][$y] . "\n";
      die "Error: Matrix is singular.";
    }

    for (my $y2 = $y + 1; $y2 < $h; $y2++)
    {
      my $c = $self->[$y2][$y] / $self->[$y][$y];
      for (my $x = $y; $x < $w; $x++)
      {
        $self->[$y2][$x] -= $self->[$y][$x] * $c;
      }
    }
    
  }
  for (my $y = $h - 1; $y >= 0; $y--)
  {
    my $c = $self->[$y][$y];
    for (my $y2 = 0; $y2 < $y; $y2++)
    {
      for (my $x = $w - 1; $x > $y - 1; $x--)
      {
        $self->[$y2][$x] -= $self->[$y][$x] * $self->[$y2][$y] / $c;

      }
    }
    $self->[$y][$y] /= $c;
    for (my $x = $h; $x < $w; $x++)
    {
      $self->[$y][$x] /= $c;
    }
  }
  return $self;
}

sub inverse
{
  my $original = shift;
  my $self = dclone($original);
  #Check to see that matrix is square:
  unless ($#{$self->[0]} == $#{$self})
  {
    die "Error: Matrix must be square.";
  }
  # Append the identity matrix to the given matrix.
  for (my $i = 0; $i <= $#{$self}; $i++)
  {
    for (my $j = 0; $j <= $#{$self}; $j++)
    {
      my $val = 0;
      if ($i == $j)
      {
        $val = 1;
      }
      push @{$self->[$i]}, $val;
    }
  }
  $self = $self->gauss_jordan();  
  my @final = ();
  for (my $i = 0; $i <= $#{$self}; $i++)
  {
    push @final, [];
    for (my $j = $#{$self} + 1; $j <= $#{$self->[0]}; $j++)
    {
      push @{$final[$i]}, $self->[$i][$j];
    }
  }
  return new Matrix @final;
}

sub size
{
  my $self = shift;
  return ($#{$self} + 1)." x ".($#{$self->[0]} + 1)
}

1;
