# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2022, Institute of Automatic Control - RWTH Aachen University
# All rights reserved. 

x = SVector(1, 1)
t = Translation(1, 1)
R = [0 -1; 1 0]
r = LinearMap(R)
a = AffineMap(R, t.translation)
s = Scale(1, 2)

@testset "Composition: Scale & Translation" begin
    @test s(x) == SVector(1, 2)
    @test (t ∘ s)(x) == t(s(x))
    @test (s ∘ t)(x) == s(t(x))
    @test (t ∘ s)(x) != (s ∘ t)(x)
end

@testset "Composition: Scale & Rotation" begin
    @test (r ∘ s)(x) == r(s(x))
    @test (s ∘ r)(x) == s(r(x))
    @test (r ∘ s)(x) != (s ∘ r)(x)
end

@testset "Composition: Scale & AffineMap" begin
    @test (a ∘ s)(x) == a(s(x))
    @test (s ∘ a)(x) == s(a(x))
    @test (a ∘ s)(x) != (s ∘ a)(x)
end

@testset "Composition: Scale & Scale" begin
    s2 = Scale(0.5, 2)
    @test (s ∘ s2)(x) == s(s2(x))
    @test (s ∘ s2)(x) == (s2 ∘ s)(x)
end

@testset "Inverse & derivatives" begin
    @test inv(s) == Scale(1, 0.5)
    @test transform_deriv(s, x) == [1 0; 0 2]
    @test isapprox(s, Scale(1 + eps(), 2))
end

s = Scale(2)
@test s.scale isa Int

@testset "Composition: Scalar Scale & Translation" begin
    @test s(x) == SVector(2, 2)
    @test (t ∘ s)(x) == t(s(x))
    @test (s ∘ t)(x) == s(t(x))
    @test (t ∘ s)(x) != (s ∘ t)(x)
end

@testset "Composition: Scalar Scale & Rotation" begin
    @test (r ∘ s)(x) == r(s(x))
    @test (s ∘ r)(x) == s(r(x))
    @test (r ∘ s)(x) == (s ∘ r)(x)
end

@testset "Composition: Scalar Scale & AffineMap" begin
    @test (a ∘ s)(x) == a(s(x))
    @test (s ∘ a)(x) == s(a(x))
    @test (a ∘ s)(x) != (s ∘ a)(x)
end

@testset "Composition: Scalar Scale & Scale" begin
    s2 = Scale(0.5, 2)
    @test (s ∘ s2)(x) == s(s2(x))
    @test (s ∘ s2)(x) == (s2 ∘ s)(x)
end

@testset "Inverse & derivatives" begin
    @test inv(s) == Scale(0.5)
    @test transform_deriv(s, x) == 2
    @test isapprox(s, Scale(2 + eps()))
end

x = SVector(1, 1, 1)
t = Translation(3, 2, 1)
R = RotZ(π / 2)
r = LinearMap(R)
s = Scale(1, 2, 3)
p = @inferred Pose(t, R)
ap = @inferred AffineMap(p)
aps = @inferred AffineMap(p, s)
@testset "Pose to AffineMap to augmented matrix" begin
    @test ap(s(x)) == aps(x)

    M_ap = @inferred SMatrix(ap)
    M_aps = @inferred SMatrix(p, s)
    M_aps2 = @inferred SMatrix(aps)
    @test M_ap != M_aps
    @test M_aps == M_aps2

    aug_x = SVector(1, 1, 1, 1)
    @test ap(x) == (M_ap*aug_x)[1:3]
    @test aps(x) == (M_aps*aug_x)[1:3]
end

# This is unstable
p = Pose([3, 2, 1], R)
# In favor for this being stable
@inferred SMatrix(p)
