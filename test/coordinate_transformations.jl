# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2022, Institute of Automatic Control - RWTH Aachen University
# All rights reserved. 

using CoordinateTransformations
using SciGL
using StaticArrays
using Test

x = SVector(1, 1)
t = Translation(1, 1)
R = [0 -1; 1 0]
r = LinearMap(R)
a = AffineMap(R, t.translation)
s = Scale(1, 2)

@test s(x) == SVector(1, 2)
@test (t ∘ s)(x) == t(s(x))
@test (s ∘ t)(x) == s(t(x))
@test (t ∘ s)(x) != (s ∘ t)(x)

@test (r ∘ s)(x) == r(s(x))
@test (s ∘ r)(x) == s(r(x))
@test (r ∘ s)(x) != (s ∘ r)(x)

@test (a ∘ s)(x) == a(s(x))
@test (s ∘ a)(x) == s(a(x))
@test (a ∘ s)(x) != (s ∘ a)(x)

@test inv(s) == Scale(1, 0.5)
s2 = Scale(0.5, 2)
@test (s ∘ s2)(x) == s(s2(x))
@test (s ∘ s2)(x) == (s2 ∘ s)(x)
@test transform_deriv(s, x) == [1 0; 0 2]
@test isapprox(s, Scale(1 + eps(), 2))