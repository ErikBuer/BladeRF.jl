using BladeRF

using DSP
using Plots
gr();

# Initialize the device
radioBoard = BladeRF.BladeRFDevice()

# Get frequency range
(min_freq, max_freq) = BladeRF.get_frequency_range(radioBoard, 0)
println("Frequency range: $min_freq - $max_freq")

# Set frequency within the allowable range
desired_freq = round(Int64, 2.4e9)
if desired_freq >= min_freq && desired_freq <= max_freq
    BladeRF.set_frequency(radioBoard, 0, desired_freq)
    # Get frequency to verify
    freq = BladeRF.get_frequency(radioBoard, 0)
    println("Frequency: ", freq)
else
    println("Desired frequency $desired_freq is out of the allowable range: $min_freq - $max_freq")
end

# Enable module
BladeRF.enable_module(radioBoard, 0, true)

# Set sample rate
actual_rate = BladeRF.set_sample_rate(radioBoard, 0, 1000000)
println("Actual Sample Rate: ", actual_rate)

# Get sample rate
rate = BladeRF.get_sample_rate(radioBoard, 0)
println("Sample Rate: ", rate)


# Set gain mode
BladeRF.set_gain_mode(radioBoard, 0, BladeRF.BLADERF_GAIN_MGC)

# Get current gain mode
current_mode = BladeRF.get_gain_mode(radioBoard, 0)
println("Current gain mode: $(current_mode)")

(min, max, step, scale) = BladeRF.get_gain_range(radioBoard, 0)

# Set gain
BladeRF.set_gain(radioBoard, 0, 30)

# Get gain
gain = BladeRF.get_gain(radioBoard, 0)
println("Gain: ", gain)

gain_modes = BladeRF.get_gain_modes(radioBoard, 0)
for (name, mode) in gain_modes
    println(" - $name: $mode")
end


# Setting bandwidth
desired_bandwidth = 500000  # Desired bandwidth in Hz
actual_bandwidth = BladeRF.set_bandwidth(radioBoard, 0, desired_bandwidth)
println("Bandwidth set to: $(actual_bandwidth) Hz")

# Getting current bandwidth
current_bandwidth = BladeRF.get_bandwidth(radioBoard, 0)
println("Current bandwidth: $(current_bandwidth) Hz")

# Getting bandwidth range
bandwidth_range = BladeRF.get_bandwidth_range(radioBoard, 0)
println("Bandwidth range: Min=$(bandwidth_range[1]) Hz, Max=$(bandwidth_range[2]) Hz, Step=$(bandwidth_range[3]) Hz")

# Set loopback mode
desired_loopback_mode = BladeRF.BLADERF_LB_RFIC_BIST
BladeRF.set_loopback(radioBoard, desired_loopback_mode)
println("Loopback mode set to: $(desired_loopback_mode)")

# Get current loopback mode
current_loopback_mode = BladeRF.get_loopback(radioBoard)
println("Current loopback mode: $(current_loopback_mode)")

# Set loopback mode
desired_loopback_mode = BladeRF.BLADERF_LB_NONE
BladeRF.set_loopback(radioBoard, desired_loopback_mode)


#________________________________________________________________________________________________
# Test RX

sample_format = BladeRF.BLADERF_FORMAT_SC16_Q11

num_samples = 4096 * 2

bytes_per_sample = 4
buffer_size_samples = 1024
buffer_size = ceil(Int, buffer_size_samples * bytes_per_sample)
read_cycles = ceil(Int, num_samples / (buffer_size / bytes_per_sample))
total_bytes = Int(read_cycles * buffer_size)

received_bytes = Vector{UInt8}(undef, total_bytes)
buf = Vector{UInt8}(undef, buffer_size)
metadata = BladeRF.init_metadata()
timeout_ms = UInt(1000)  # Timeout in milliseconds

# Allocate memory for metadata if needed (example structure initialization)
metadata.timestamp = 0  # Example timestamp, set appropriately
metadata.flags = 0  # Metadata flags, set as needed

channel = BladeRF.BladerfChannelLayout(0)

num_buffers = UInt(32)
blade_buffer_size = UInt(8192)
num_transfers = UInt(16)
stream_timeout = UInt(1000)

BladeRF.sync_config(radioBoard, channel, sample_format, num_buffers, blade_buffer_size, num_transfers, stream_timeout)


BladeRF.enable_module(radioBoard, 0, true)

GC.@preserve buf metadata begin
    buffer_ptr = Base.unsafe_convert(Ptr{Nothing}, pointer(buf))
    metadata_ref = Ref(metadata)
    metadata_ptr = Base.unsafe_convert(Ptr{BladeRF.BladerfMetadata}, metadata_ref)

    # Receive samples
    index = 1
    for i in 1:read_cycles
        BladeRF.sync_rx(radioBoard, buffer_ptr, UInt(buffer_size_samples), metadata_ptr, timeout_ms)
        unsafe_copyto!(received_bytes, index, buf, 1, buffer_size)
        global index += buffer_size
    end
end

BladeRF.enable_module(radioBoard, 0, false)


complex_samples = reinterpret(Complex{Int16}, received_bytes)
normalized_samples = Complex{Float32}.(complex_samples) ./ 2048.0

#________________________________________________________________________________________________
# Periodogram

# Timing the periodogram for the original samples
println("Calculating periodogram for original samples:")
time_original = @elapsed pgram = periodogram(normalized_samples, onesided=false, fs=rate)
println("Time taken: $(time_original*1000) ms")
println("")


plot(pgram.freq, pow2db.(pgram.power), title="Power Spectral Density", xlabel="Frequency", ylabel="Power [dB/Hz]")
savefig("plots/periodogram.png")

#________________________________________________________________________________________________

# Close the device
BladeRF.close(radioBoard)
