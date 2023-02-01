# OffscreenContext
Simple entrypoint for rendering and transferring to CPU / CUDA.

```@autodocs
Modules = [SciGL]
Pages   = ["OffscreenContext.jl"]
```

# Context Creation
Manually create and destroy standalone contexts.
Compared to the `OffscreenContext` batteries are not included, i.e. no textures to render to.

```@autodocs
Modules = [SciGL]
Pages   = ["RenderContexts.jl"]
```

# Layered Rendering
Low level interface to switch layers.

```@autodocs
Modules = [SciGL]
Pages   = ["Layers.jl"]
```
