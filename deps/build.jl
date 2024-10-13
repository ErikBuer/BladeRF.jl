using Pkg
using Libdl

# Path to the bash script
bash_script = joinpath(@__DIR__, "install_bladerf.sh")

# Function to find the library in standard locations
function find_libbladeRF()
    possible_paths = [
        "/usr/local/lib/libbladeRF.so",
        "/usr/lib/libbladeRF.so",
        "/usr/local/lib64/libbladeRF.so",
        "/usr/lib64/libbladeRF.so",
        "/opt/local/lib/libbladeRF.so",
        "/opt/lib/libbladeRF.so"
    ]
    for path in possible_paths
        if isfile(path)
            return path
        end
    end
    return nothing
end

# Check if the library is already installed
lib_path = find_libbladeRF()

if lib_path !== nothing
    println("Found BladeRF C library at: $lib_path")
    println("Skipping BladeRF C library installation.")
else
    println("Installing the BladeRF C library...")
    run(`bash $bash_script`)
    lib_path = find_libbladeRF()
    if lib_path === nothing
        error("The BladeRF C library was not installed correctly.")
    else
        println("BladeRF C library installed successfully at: $lib_path")
    end
end

# Inform Julia about the library location
push!(Libdl.DL_LOAD_PATH, dirname(lib_path))

# Write the path to deps.jl for use in the package
open(joinpath(@__DIR__, "deps.jl"), "w") do f
    println(f, "const libbladeRF = \"$(lib_path)\"")
end