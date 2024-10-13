module BladeRF

using CEnum

using Printf
using Libdl

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

# Function to install the BladeRF library
function install_bladeRF()
    println("Installing the BladeRF C library...")
    # Path to the bash script
    bash_script = joinpath(@__DIR__, "..", "deps", "install_bladerf.sh")

    if !isfile(bash_script)
        error("Installation script not found at expected location: $bash_script")
    end

    # Run the bash script to install the library
    run(`bash $bash_script`)

    # Verify installation
    lib_path = find_libbladeRF()
    if lib_path === nothing
        error("The BladeRF C library was not installed correctly. Consider installing manually.")
    else
        println("BladeRF C library installed successfully at: $lib_path")
        # Add the library path to DL_LOAD_PATH
        push!(Libdl.DL_LOAD_PATH, dirname(lib_path))
    end
end

# Initialization function
function __init__()
    println("Loading BladeRF library...")
    global libbladeRF = find_libbladeRF()
    if libbladeRF !== nothing
        Libdl.dlopen(libbladeRF)
        println("BladeRF library loaded successfully.")
    else
        @warn "BladeRF C library not found. Run `BladeRF.install_bladeRF()` to install it."
    end
end

# Define BladeRFError with specific error codes
struct BladeRFError <: Exception
    code::Cint
    msg::String
end

function Base.showerror(io::IO, e::BladeRFError)
    @printf(io, "BladeRF Error %d: %s", e.code, e.msg)
end

# Define ReturnCode enum
const ReturnCode = Dict(
    0 => "BladeRFError",
    -1 => "UnexpectedError",
    -2 => "RangeError",
    -3 => "InvalError",
    -4 => "MemError",
    -5 => "IOError",
    -6 => "TimeoutError",
    -7 => "NoDevError",
    -8 => "UnsupportedError",
    -9 => "MisalignedError",
    -10 => "ChecksumError",
    -11 => "NoFileError",
    -12 => "UpdateFPGAError",
    -13 => "UpdateFWError",
    -14 => "TimePastError",
    -15 => "QueueFullError",
    -16 => "FPGAOpError",
    -17 => "PermissionError",
    -18 => "WouldBlockError",
    -19 => "NotInitError"
)

# Utility function to check errors
function check_error(code::Cint)
    if code < 0
        error_name = get(ReturnCode, code, "UnknownError")
        msg = unsafe_string(ccall((:bladerf_strerror, libbladeRF), Ptr{Cchar}, (Cint,), code))
        throw(BladeRFError(code, "$error_name: $msg"))
    end
end

# Define the bladerf_version struct
struct bladerf_version
    major::Cint
    minor::Cint
    patch::Cint
    describe::Ptr{UInt8}
end

# Version struct for easier usage
struct Version
    major::Int
    minor::Int
    patch::Int
    describe::String
end

function version()
    version_ptr = Ref{bladerf_version}()
    ccall((:bladerf_version, libbladeRF), Cvoid, (Ptr{bladerf_version},), version_ptr)
    v = version_ptr[]
    Version(v.major, v.minor, v.patch, unsafe_string(v.describe))
end

# DevInfo struct
struct DevInfo
    backend::Int
    serial::String
    usb_bus::Int
    usb_addr::Int
    instance::Int
end

# Ensure DevInfo struct is correctly initialized
mutable struct bladerf_devinfo
    backend::Cint
    serial::NTuple{33,UInt8}
    usb_bus::Cint
    usb_addr::Cint
    instance::Cint
end

# Initialize bladerf_devinfo with default values
function bladerf_devinfo()
    bladerf_devinfo(
        0,
        ntuple(_ -> UInt8(0), 33),
        0,
        0,
        0
    )
end

function get_devinfo(dev::Ptr{Cvoid})
    devinfo = Ref(bladerf_devinfo())
    check_error(ccall((:bladerf_get_devinfo, libbladeRF), Cint, (Ptr{Cvoid}, Ptr{bladerf_devinfo}), dev, devinfo))
    info = devinfo[]
    serial_array = collect(info.serial)  # Convert NTuple to array
    DevInfo(info.backend, unsafe_string(pointer(serial_array)), info.usb_bus, info.usb_addr, info.instance)
end

struct BladeRFRange
    min::Int64
    max::Int64
    step::Int64
    scale::Cfloat
end

@enum BladerfGainMode begin
    BLADERF_GAIN_DEFAULT = 0
    BLADERF_GAIN_MGC = 1
    BLADERF_GAIN_FASTATTACK_AGC = 2
    BLADERF_GAIN_SLOWATTACK_AGC = 3
    BLADERF_GAIN_HYBRID_AGC = 4
end

struct BladerfGainModes
    name::Cstring
    mode::Cint
end

CHANNEL_RX(ch) = (ch << 1) | 0x0
CHANNEL_TX(ch) = (ch << 1) | 0x1

@enum BladerfChannelLayout begin
    BLADERF_RX_X1 = 0
    BLADERF_TX_X1
    BLADERF_RX_X2
    BLADERF_TX_X2
end

@enum BladeRFLoopback begin
    BLADERF_LB_NONE = 0
    BLADERF_LB_FIRMWARE
    BLADERF_LB_BB_TXLPF_RXVGA2
    BLADERF_LB_BB_TXVGA1_RXVGA2
    BLADERF_LB_BB_TXLPF_RXLPF
    BLADERF_LB_BB_TXVGA1_RXLPF
    BLADERF_LB_RF_LNA1
    BLADERF_LB_RF_LNA2
    BLADERF_LB_RF_LNA3
    BLADERF_LB_RFIC_BIST
end

struct BladeRFLoopbackModes
    name::Cstring
    mode::Cint
end

@enum BladerfFormat begin
    BLADERF_FORMAT_SC16_Q11 = 0
    BLADERF_FORMAT_SC16_Q11_META
    BLADERF_FORMAT_PACKET_META
    BLADERF_FORMAT_SC8_Q7
    BLADERF_FORMAT_SC8_Q7_META
end


@cenum BladerfStatusFlags::UInt32 begin
    BLADERF_META_STATUS_OVERRUN = 1 << 0
    BLADERF_META_STATUS_UNDERRUN = 1 << 1
end

@cenum BladerfMetaFlags::UInt32 begin
    BLADERF_META_FLAG_TX_BURST_START = 1 << 0
    BLADERF_META_FLAG_TX_BURST_END = 1 << 1
    BLADERF_META_FLAG_TX_NOW = 1 << 2
    BLADERF_META_FLAG_TX_UPDATE_TIMESTAMP = 1 << 3
    BLADERF_META_FLAG_RX_NOW = 1 << 31
    BLADERF_META_FLAG_RX_HW_UNDERFLOW = 1 << 0
    BLADERF_META_FLAG_RX_HW_MINIEXP1 = 1 << 16
    BLADERF_META_FLAG_RX_HW_MINIEXP2 = 1 << 17
end

mutable struct BladerfMetadata
    timestamp::UInt64
    flags::UInt32 #BladerfMetaFlags
    status::UInt32 #BladerfStatusFlags
    actual_count::UInt32
    reserved::NTuple{32,UInt8}
end

function init_metadata()::BladerfMetadata
    return BladerfMetadata(0, 0, 0, 0, ntuple(_ -> 0x00, 32))
end

# BladeRFDevice struct
struct BladeRFDevice
    dev::Ptr{Cvoid}
    devinfo::DevInfo
end

function BladeRFDevice(device_identifier::String="")
    dev = Ref{Ptr{Cvoid}}()
    result = ccall((:bladerf_open, libbladeRF), Cint, (Ptr{Ptr{Cvoid}}, Cstring), dev, device_identifier)

    check_error(result)

    if dev[] == C_NULL
        error("Failed to initialize BladeRF device.")
    end

    devinfo = get_devinfo(dev[])
    BladeRFDevice(dev[], devinfo)
end

function close(dev::BladeRFDevice)
    ccall((:bladerf_close, libbladeRF), Cvoid, (Ptr{Cvoid},), dev.dev)
end

function get_serial(dev::BladeRFDevice)
    serial = Vector{UInt8}(undef, 33)
    check_error(ccall((:bladerf_get_serial, libbladeRF), Cint, (Ptr{Cvoid}, Ptr{UInt8}), dev.dev, serial))
    String(serial)
end

#******************************************************************************
# Frequency
#******************************************************************************

# Get set frequency
function set_frequency(dev::BladeRFDevice, channel::Integer, frequency::Int64)
    check_error(ccall((:bladerf_set_frequency, libbladeRF), Cint, (Ptr{Cvoid}, Cint, Int64), dev.dev, Int32(channel), frequency))
end

function get_frequency(dev::BladeRFDevice, channel::Integer)
    frequency = Ref{Int64}()
    check_error(ccall((:bladerf_get_frequency, libbladeRF), Cint, (Ptr{Cvoid}, Cint, Ptr{Int64}), dev.dev, Int32(channel), frequency))
    frequency[]
end

# Get frequency range
function get_frequency_range(dev::BladeRFDevice, channel::Integer)
    range_ptr = Ref{Ptr{BladeRFRange}}()  # Pointer to pointer to BladeRFRange
    result = ccall((:bladerf_get_frequency_range, libbladeRF), Cint, (Ptr{Cvoid}, Cint, Ref{Ptr{BladeRFRange}}), dev.dev, Int32(channel), range_ptr)
    check_error(result)

    range = unsafe_load(range_ptr[])  # Dereference the pointer to get the BladeRFRange struct
    return (range.min, range.max, range.step, range.scale)
end

#******************************************************************************
# Sample Rate
#******************************************************************************

# Get and set sample rate
function set_sample_rate(dev::BladeRFDevice, channel::Integer, rate::Integer)
    actual = Ref{Cuint}()
    check_error(ccall((:bladerf_set_sample_rate, libbladeRF), Cint,
        (Ptr{Cvoid}, Cint, Cuint, Ptr{Cuint}),
        dev.dev, Int32(channel), UInt32(rate), actual))
    Int(actual[])
end

function get_sample_rate(dev::BladeRFDevice, channel::Integer)
    rate = Ref{Cuint}()
    check_error(ccall((:bladerf_get_sample_rate, libbladeRF), Cint,
        (Ptr{Cvoid}, Cint, Ptr{Cuint}),
        dev.dev, Int32(channel), rate))
    Int(rate[])
end

function get_sample_rate_range(dev::BladeRFDevice, channel::Integer)
    range_ptr = Ref{Ptr{BladeRFRange}}()  # Pointer to pointer to BladeRFRange
    result = ccall((:bladerf_get_sample_rate_range, libbladeRF), Cint,
        (Ptr{Cvoid}, Cint, Ref{Ptr{BladeRFRange}}),
        dev.dev, Int32(channel), range_ptr)
    check_error(result)

    range = unsafe_load(range_ptr[])  # Dereference to access the struct
    return (range.min, range.max, range.step, range.scale)
end

#******************************************************************************
# Gain
#******************************************************************************

# Get and set gain
function set_gain(dev::BladeRFDevice, channel::Integer, gain::Integer)
    check_error(ccall((:bladerf_set_gain, libbladeRF), Cint, (Ptr{Cvoid}, Cint, Cint), dev.dev, Int32(channel), Int32(gain)))
end

function get_gain(dev::BladeRFDevice, channel::Integer)
    gain = Ref{Cint}()
    check_error(ccall((:bladerf_get_gain, libbladeRF), Cint, (Ptr{Cvoid}, Cint, Ptr{Cint}), dev.dev, Int32(channel), gain))
    gain[]
end

function get_gain_range(dev::BladeRFDevice, channel::Integer)
    range_ptr = Ref{Ptr{BladeRFRange}}()  # Pointer to pointer to BladeRFRange
    result = ccall((:bladerf_get_gain_range, libbladeRF), Cint,
        (Ptr{Cvoid}, Cint, Ref{Ptr{BladeRFRange}}),
        dev.dev, Int32(channel), range_ptr)
    check_error(result)

    range = unsafe_load(range_ptr[])  # Dereference to access the struct
    return (range.min, range.max, range.step, range.scale)
end

function set_gain_mode(dev::BladeRFDevice, channel::Integer, mode::BladerfGainMode)
    check_error(ccall((:bladerf_set_gain_mode, libbladeRF), Cint,
        (Ptr{Cvoid}, Cint, Cint),
        dev.dev, Int32(channel), mode))
end

function get_gain_mode(dev::BladeRFDevice, channel::Integer)
    mode = Ref{Cint}()
    check_error(ccall((:bladerf_get_gain_mode, libbladeRF), Cint,
        (Ptr{Cvoid}, Cint, Ptr{Cint}),
        dev.dev, Int32(channel), mode))
    BladerfGainMode(mode[])
end


function get_gain_modes(dev::BladeRFDevice, channel::Integer)
    modes_ptr = Ref{Ptr{BladerfGainModes}}()
    num_modes = ccall((:bladerf_get_gain_modes, libbladeRF), Cint,
        (Ptr{Cvoid}, Cint, Ref{Ptr{BladerfGainModes}}),
        dev.dev, Int32(channel), modes_ptr)
    check_error(num_modes)  # Assuming it returns the number of gain modes

    if num_modes > 0
        modes_array = unsafe_wrap(Array, modes_ptr[], num_modes)
        return [(unsafe_string(m.name), BladerfGainMode(m.mode)) for m in modes_array]
    else
        return []
    end
end

#******************************************************************************
# Bandwidth
#******************************************************************************

function set_bandwidth(dev::BladeRFDevice, channel::Integer, bandwidth::Integer)
    actual = Ref{Cuint}()  # This will store the actual bandwidth set by the device
    check_error(ccall((:bladerf_set_bandwidth, libbladeRF), Cint,
        (Ptr{Cvoid}, Cint, Cuint, Ptr{Cuint}),
        dev.dev, Int32(channel), UInt32(bandwidth), actual))
    actual[]  # Return the actual bandwidth set
end

function get_bandwidth(dev::BladeRFDevice, channel::Integer)
    bandwidth = Ref{Cuint}()
    check_error(ccall((:bladerf_get_bandwidth, libbladeRF), Cint,
        (Ptr{Cvoid}, Cint, Ptr{Cuint}),
        dev.dev, Int32(channel), bandwidth))
    bandwidth[]  # Return the current bandwidth setting
end

function get_bandwidth_range(dev::BladeRFDevice, channel::Integer)
    range_ptr = Ref{Ptr{BladeRFRange}}()  # Pointer to pointer to BladeRFRange
    result = ccall((:bladerf_get_bandwidth_range, libbladeRF), Cint,
        (Ptr{Cvoid}, Cint, Ref{Ptr{BladeRFRange}}),
        dev.dev, Int32(channel), range_ptr)
    check_error(result)

    range = unsafe_load(range_ptr[])  # Dereference to access the struct
    return (range.min, range.max, range.step, range.scale)  # Return tuple
end

#******************************************************************************
# Loopback
#******************************************************************************

function set_loopback(dev::BladeRFDevice, lb::BladeRFLoopback)
    check_error(ccall((:bladerf_set_loopback, libbladeRF), Cint,
        (Ptr{Cvoid}, Cint),
        dev.dev, lb))
end

function get_loopback(dev::BladeRFDevice)
    lb = Ref{Cint}()
    check_error(ccall((:bladerf_get_loopback, libbladeRF), Cint,
        (Ptr{Cvoid}, Ptr{Cint}),
        dev.dev, lb))
    BladeRFLoopback(lb[])
end

function get_loopback_modes(dev::BladeRFDevice)
    modes_ptr = Ref{Ptr{BladeRFLoopbackModes}}()
    num_modes = ccall((:bladerf_get_loopback_modes, libbladeRF), Cint,
        (Ptr{Cvoid}, Ref{Ptr{BladeRFLoopbackModes}}),
        dev.dev, modes_ptr)
    check_error(num_modes)  # Assuming it returns the number of modes or an error code

    modes_array = unsafe_wrap(Array, modes_ptr[], num_modes)
    [(unsafe_string(m.name), BladeRFLoopback(m.mode)) for m in modes_array]
end

#******************************************************************************
# Streaming
#******************************************************************************

function init_stream(dev::BladeRFDevice, callback::Function, num_buffers::UInt, format::BladerfFormat, samples_per_buffer::UInt, num_transfers::UInt)
    buffers = Vector{Ptr{Cvoid}}(undef, num_buffers)
    stream_ptr = Ref{Ptr{Cvoid}}()

    status = ccall((:bladerf_init_stream, libbladeRF), Cint,
        (Ref{Ptr{Cvoid}}, Ptr{Cvoid}, Ptr{Cvoid}, Ref{Vector{Ptr{Cvoid}}}, UInt, BladerfFormat, UInt, UInt, Ptr{Cvoid}),
        stream_ptr, dev.dev, callback, buffers, num_buffers, format, samples_per_buffer, num_transfers, C_NULL)

    check_error(status)
    return (stream_ptr[], buffers)
end


function stream(stream_ptr::Ptr{Cvoid}, layout::BladerfChannelLayout)
    status = ccall((:bladerf_stream, libbladeRF), Cint, (Ptr{Cvoid}, BladerfChannelLayout), stream_ptr, layout)
    check_error(status)
end

function deinit_stream(stream_ptr::Ptr{Cvoid})
    ccall((:bladerf_deinit_stream, libbladeRF), Cvoid, (Ptr{Cvoid},), stream_ptr)
end

function submit_stream_buffer(stream_ptr::Ptr{Cvoid}, buffer::Ptr{Cvoid}, timeout_ms::UInt)
    status = ccall((:bladerf_submit_stream_buffer, libbladeRF), Cint,
        (Ptr{Cvoid}, Ptr{Cvoid}, UInt, Bool), stream_ptr, buffer, timeout_ms, false)
    check_error(status)
end

function submit_stream_buffer_nonblocking(stream_ptr::Ptr{Cvoid}, buffer::Ptr{Cvoid})
    status = ccall((:bladerf_submit_stream_buffer_nb, libbladeRF), Cint,
        (Ptr{Cvoid}, Ptr{Cvoid}), stream_ptr, buffer)
    check_error(status)
end

function sync_config(dev::BladeRFDevice, layout::BladerfChannelLayout, format::BladerfFormat, num_buffers::UInt, buffer_size::UInt, num_transfers::UInt, stream_timeout::UInt)
    status = ccall((:bladerf_sync_config, libbladeRF), Cint,
        (Ptr{Cvoid}, BladerfChannelLayout, BladerfFormat, UInt, UInt, UInt, UInt),
        dev.dev, layout, format, num_buffers, buffer_size, num_transfers, stream_timeout)
    check_error(status)
end

function sync_tx(dev::BladeRFDevice, samples::Ptr{Cvoid}, num_samples::UInt, metadata::Ptr{BladerfMetadata}, timeout_ms::UInt)
    status = ccall((:bladerf_sync_tx, libbladeRF), Cint,
        (Ptr{Cvoid}, Ptr{Cvoid}, UInt, Ptr{BladerfMetadata}, UInt), dev.dev, samples, Cuint(num_samples), metadata, timeout_ms)
    check_error(status)
end

function sync_rx(dev::BladeRFDevice, samples::Ptr{Cvoid}, num_samples::UInt, metadata::Ptr{BladerfMetadata}, timeout_ms::UInt)
    status = ccall((:bladerf_sync_rx, libbladeRF), Cint,
        (Ptr{Cvoid}, Ptr{Cvoid}, UInt, Ptr{BladerfMetadata}, UInt), dev.dev, samples, Cuint(num_samples), metadata, timeout_ms)
    check_error(status)
end

function enable_module(device::BladeRFDevice, channel::Integer, enable::Bool)
    ret = ccall((:bladerf_enable_module, libbladeRF), Cint, (Ptr{Cvoid}, Cint, Bool), device.dev, channel, enable)
    check_error(ret)
end

end # module BladeRF
