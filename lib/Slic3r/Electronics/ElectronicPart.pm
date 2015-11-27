package Slic3r::Electronics::ElectronicPart;
use strict;
use warnings;
use utf8;

use Slic3r::Electronics::Geometrics;
use Slic3r::Geometry qw(X Y Z deg2rad);
use List::Util qw[min max];

#######################################################################
# Purpose    : Generates new Part
# Parameters : Name, library, deviceset, device and package of new part
# Returns    : Reference to new Part
# Commet     :
#######################################################################
sub new {
    my $class = shift;
    my $self = {};
    bless ($self, $class);
    my ($name,$library,$deviceset,$device,$package) = @_;
    $self->{name} = $name;
    $self->{library} = $library;
    $self->{deviceset} = $deviceset;
    $self->{device} = $device;
    $self->{package} = $package;
    $self->{height} = undef;
    $self->{volume} = undef;
    $self->{chipVolume} = undef;
    $self->{shown} = 0;
    
    my @position = @{$self->{position}} = (undef,undef,undef);
    my @rotation = @{$self->{rotation}} = (0,0,0);
    
    my @padlist = @{$self->{padlist}} = ();
    
    my @componentpos = @{$self->{componentpos}} = (0,0,0);
    
    my @componentsize = @{$self->{componentsize}} = (0,0,0);

    return $self;
}

#######################################################################
# Purpose    : Removes the position of the part
# Parameters : none
# Returns    : none
# Commet     : Doesnt removes the part itself
#######################################################################
sub removePart {
    my $self = shift;
    $self->{volume} = undef; 
    $self->{chipVolume} = undef; 
    @{$self->{position}} = (undef,undef,undef);
    @{$self->{rotation}} = (0,0,0);
}

#######################################################################
# Purpose    : Sets the position of the part
# Parameters : x, y, z coordinates of the part
# Returns    : none
# Commet     : coordinates have to be valid
#######################################################################
sub setPosition {
    my $self = shift;
    my ($x,$y,$z) = @_;
    $self->{position} = [$x,$y,$z];
}

#######################################################################
# Purpose    : Sets the rotation angles of the part
# Parameters : x, y, z rotation angles
# Returns    : none
# Commet     : rotation angles have to be in degree and valid
#######################################################################
sub setRotation {
    my $self = shift;
    my ($x,$y,$z) = @_;
    $self->{rotation} = [$x,$y,$z];
}

#######################################################################
# Purpose    : Sets the componentsize of the part itself
# Parameters : x, y, z dimensions of the part
# Returns    : none
# Commet     : values have to be valid
#######################################################################
sub setPartsize {
    my $self = shift;
    my ($x,$y,$z) = @_;
    $self->{componentsize} = [$x,$y,$z];
}

#######################################################################
# Purpose    : returns the componentsize of the part
# Parameters : none
# Returns    : (x, y, z) dimensions of the part
# Commet     : when the dimensions are not set,
#            : they are calculated by the footprint
#######################################################################
sub getPartsize {
    my $self = shift;
    my ($config) = @_;
    if (!(defined($self->{componentsize}[0]) && defined($self->{componentsize}[0]) && defined($self->{componentsize}[0]))) {
        my $xmin = 0;
        my $ymin = 0;
        my $xmax = 0;
        my $ymax = 0;
        for my $pad (@{$self->{padlist}}) {
            if ($pad->{type} eq 'smd') {
                $xmin = min($xmin, $pad->{position}[0]-$pad->{size}[0]/2);
                $xmax = max($xmax, $pad->{position}[0]+$pad->{size}[0]/2);
                $ymin = min($ymin, $pad->{position}[1]-$pad->{size}[1]/2);
                $ymax = max($ymax, $pad->{position}[1]+$pad->{size}[1]/2);
            }
            if ($pad->{type} eq 'pad') {
                $xmin = min($xmin, $pad->{position}[0]-($pad->{drill}/2+0.25));
                $xmax = max($xmax, $pad->{position}[0]+($pad->{drill}/2+0.25));
                $ymin = min($ymin, $pad->{position}[1]-($pad->{drill}/2+0.25));
                $ymax = max($ymax, $pad->{position}[1]+($pad->{drill}/2+0.25));
            }
        }
        my $x = $xmax-$xmin+$config->{offset}{chip_x_offset};
        my $y = $ymax-$ymin+$config->{offset}{chip_y_offset};
        my $z = $self->getPartheight($config)+$config->{offset}{chip_z_offset};
        @{$self->{componentsize}} = ($x,$y,$z);
        @{$self->{componentpos}} = (($xmax-abs($xmin))/2,($ymax-abs($ymin))/2,0);
    }
    
    return @{$self->{componentsize}};
}

#######################################################################
# Purpose    : returns the height of the chip
# Parameters : none
# Returns    : height of chip
# Commet     : 
#######################################################################
sub getPartheight {
    my $self = shift;
    my ($config) = @_;
    if ($config->{chip_height}{$self->{package}}) {
        return $config->{chip_height}{$self->{package}};
    } else {
        return $config->{chip_height}{default};
    }
}

#######################################################################
# Purpose    : Sets the Partposition of the part itself
# Parameters : x, y, z coordinates of the part
# Returns    : none
# Commet     : values have to be valid
#######################################################################
sub setPartpos {
    my $self = shift;
    my ($x,$y,$z) = @_;
    $self->{componentpos} = [$x,$y,$z];
}

#######################################################################
# Purpose    : adds a pad to the footprint of the part
# Parameters : see Slic3r::Electronics::ElectronicPad->new
# Returns    : none
# Commet     :
#######################################################################
sub addPad {
    my $self = shift;
    my $pad = Slic3r::Electronics::ElectronicPad->new(@_);
    push @{$self->{padlist}}, $pad;
}

#######################################################################
# Purpose    : Gives a model of the parts footprint
# Parameters : none
# Returns    : Footprint model
# Commet     : The model is translated and rotated
#######################################################################
sub getFootprintModel {
    my $self = shift;
    my @triangles = ();
    for my $pad (@{$self->{padlist}}) {
        if ($pad->{type} eq 'smd') {
            push @triangles, Slic3r::Electronics::Geometrics->getCube(@{$pad->{position}}, ($pad->{size}[0], $pad->{size}[1], $self->{height}*(-1)));
        }
        if ($pad->{type} eq 'pad') {
            push @triangles, Slic3r::Electronics::Geometrics->getCylinder(@{$pad->{position}}, $pad->{drill}/2+0.25, $self->{height}*(-1));
        }
    }
    my $model = $self->getTriangleMesh(@triangles);
    return $model;
}

#######################################################################
# Purpose    : Gives a model of the parts
# Parameters : none
# Returns    : Part model
# Commet     : The model is translated and rotated
#######################################################################
sub getPartModel {
    my $self = shift;
    my ($config) = @_;
    my @triangles = ();
    push @triangles, Slic3r::Electronics::Geometrics->getCube(@{$self->{componentpos}}, $self->getPartsize($config));
    my $model = $self->getTriangleMesh(@triangles);
    return $model;
}

#######################################################################
# Purpose    : Converts triagles to a triaglesMesh
# Parameters : Triagles to convert
# Returns    : a Model
# Commet     : Translates and rotates the model
#######################################################################
sub getTriangleMesh {
    my $self = shift;
    my (@triangles) = @_;
    my $vertices = $self->{vertices} = [];
    my $facets = $self->{facets} = [];
    for my $triangle (@triangles) {
        my @newTriangle = ();
        for my $point (@$triangle) {
            push @newTriangle, $self->getVertexID(@$point);
        }
        push @{$self->{facets}}, [@newTriangle];
    }
    
    my $mesh = Slic3r::TriangleMesh->new;
    $mesh->ReadFromPerl($self->{vertices}, $self->{facets});
    $mesh->repair;
    $mesh->rotate_x(deg2rad($self->{rotation}[0])) if ($self->{rotation}[0] != 0);
    $mesh->rotate_y(deg2rad($self->{rotation}[1])) if ($self->{rotation}[1] != 0);
    $mesh->rotate_z(deg2rad($self->{rotation}[2])) if ($self->{rotation}[2] != 0);
    $mesh->translate(@{$self->{position}});
    
    
    my $model = Slic3r::Model->new;
    
    my $object = $model->add_object(name => $self->{name});
    my $volume = $object->add_volume(mesh => $mesh, name => $self->{name});
    
    return $model;
}

#######################################################################
# Purpose    : Gives a vertex id for a given vertex
# Parameters : The vertex
# Returns    : An id
# Commet     : If the vertex doesnt exists it will be created
#######################################################################
sub getVertexID {
    my $self = shift;
    my @vertex = @_;
    my $id = 0;
    while ($id < scalar @{$self->{vertices}}) {
        if ( ${$self->{vertices}}[$id][0] == $vertex[0] && ${$self->{vertices}}[$id][1] == $vertex[1] && ${$self->{vertices}}[$id][2] == $vertex[2]) {;
            return $id;
        }
        $id += 1;
    }
    push (@{$self->{vertices}}, [@vertex]);
    return $id;
}

package Slic3r::Electronics::ElectronicPad;
use strict;
use warnings;
use utf8;

#######################################################################
# Purpose    : Creates a new pad
# Parameters : type, pin, pad, gate, x, y, r, dx, dy, drill, shape of the pad
# Returns    : A new Pad
# Commet     : 
#######################################################################
sub new {
    my $class = shift;
    my $self = {};
    bless ($self, $class);
    my ($type,$pad,$pin,$gate,$x,$y,$r,$dx,$dy,$drill,$shape) = @_;
    $self->{type} = $type;
    $self->{pad} = $pad;
    $self->{pin} = $pin;
    $self->{gate} = $gate;
    $self->{drill} = $drill;
    $self->{shape} = $shape;
    
    my @position = @{$self->{position}} = ($x,$y,0);
    my @size = @{$self->{size}} = ($dx,$dy,0);
    my @rotation = @{$self->{rotation}} = (0,0,$r);
    
    return $self
}

1;