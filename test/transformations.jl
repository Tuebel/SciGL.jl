# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2022, Institute of Automatic Control - RWTH Aachen University
# All rights reserved. 

x = SVector(1, 1, 1)
t = Translation(3, 2, 1)
R = RotZ(π / 2)
r = LinearMap(R)
s = Scale(1, 2, 3)

p = Pose(t, R)
ap = @inferred AffineMap(p)
aps = @inferred AffineMap(p, s)

@test ap(s(x)) == aps(x)

M_ap = @inferred SMatrix(ap)
M_aps = @inferred SMatrix(p, s)
M_aps2 = @inferred SMatrix(aps)
@test M_ap != M_aps
@test M_aps == M_aps2

aug_x = SVector(1, 1, 1, 1)
@test ap(x) == (M_ap*aug_x)[1:3]
@test aps(x) == (M_aps*aug_x)[1:3]

# This is unstable
p = Pose([3, 2, 1], R)
# In favor for this being stable
@inferred SMatrix(p)
