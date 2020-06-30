# Copyright (c) 2020 Crystal Data Contributors
#
# MIT License
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

require "./libcl"

module Cl
  extend self

  def check(errcode : Int32)
    if errcode != 0
      raise "OpenCL Raised #{errcode}"
    end
  end

  def platform_name(id : LibCL::ClPlatformId) : String
    check LibCL.cl_get_platform_info(id, LibCL::ClPlatformInfo::PLATFORM_NAME, 0, nil, out size)
    result = Slice(UInt8).new(size)
    check LibCL.cl_get_platform_info(id, LibCL::ClPlatformInfo::PLATFORM_NAME, size, result, nil)
    String.new(result)
  end

  def device_name(id : LibCL::ClDeviceId) : String
    check LibCL.cl_get_device_info(id, LibCL::ClDeviceInfo::DEVICE_NAME, 0, nil, out size)
    result = Slice(UInt8).new(size)
    check LibCL.cl_get_device_info(id, LibCL::ClDeviceInfo::DEVICE_NAME, size, result, nil)
    String.new(result)
  end

  def max_work_groups(id : LibCL::ClDeviceId) : UInt64
    result = 0_u64
    check LibCL.cl_get_device_info(id, LibCL::ClDeviceInfo::DEVICE_MAX_WORK_GROUP_SIZE, sizeof(UInt64), pointerof(result), nil)
    result
  end

  def local_memory(id : LibCL::ClDeviceId) : UInt64
    result = 0_u64
    check LibCL.cl_get_device_info(id, LibCL::ClDeviceInfo::DEVICE_LOCAL_MEM_SIZE, sizeof(UInt64), pointerof(result), nil)
    result
  end

  def global_memory(id : LibCL::ClDeviceId) : UInt64
    result = 0_u64
    check LibCL.cl_get_device_info(id, LibCL::ClDeviceInfo::DEVICE_GLOBAL_MEM_SIZE, sizeof(UInt64), pointerof(result), nil)
    result
  end

  def max_work_items(id : LibCL::ClDeviceId) : Array(UInt64)
    dims = uninitialized UInt32
    check LibCL.cl_get_device_info(id, LibCL::ClDeviceInfo::DEVICE_MAX_WORK_ITEM_DIMENSIONS, sizeof(UInt32), pointerof(dims), nil)
    result = (0...dims).to_a
    check LibCL.cl_get_device_info(id, LibCL::ClDeviceInfo::DEVICE_MAX_WORK_ITEM_SIZES, dims * sizeof(UInt64), result, nil)
    result
  end

  def version(id : LibCL::ClPlatformId) : String
    check LibCL.cl_get_platform_info(id, LibCL::ClPlatformInfo::PLATFORM_VERSION, 0, nil, out size)
    result = Slice(UInt8).new(size)
    check LibCL.cl_get_platform_info(id, LibCL::ClPlatformInfo::PLATFORM_VERSION, size, result, nil)
    String.new(result)
  end

  def get_platform_by_name(name : String)
    check LibCL.cl_get_platform_ids(0, nil, out num_platforms)
    platforms = (0...num_platforms).map { Pointer(Void).malloc(1).as(LibCL::ClPlatformId) }
    check LibCL.cl_get_platform_ids(num_platforms, platforms, nil)

    platforms.each do |platform|
      if platform_name(platform) == name + '\0'
        return platform
      end
    end

    raise "Platform not found"
  end

  def first_platform
    check LibCL.cl_get_platform_ids(0, nil, out num_platforms)
    if num_platforms == 0
      raise "No platforms found"
    end

    platforms = (0...num_platforms).map { Pointer(Void).malloc(1).as(LibCL::ClPlatformId) }
    check LibCL.cl_get_platform_ids(num_platforms, platforms, nil)
    platforms[0]
  end

  def get_devices(platform : LibCL::ClPlatformId) : Array(LibCL::ClDeviceId)
    check LibCL.cl_get_device_ids(platform, LibCL::CL_DEVICE_TYPE_ALL, 0, nil, out num_devices)
    if num_devices == 0
      raise "No devices found"
    end

    devices = (0...num_devices).map { Pointer(Void).malloc(1).as(LibCL::ClDeviceId) }
    check LibCL.cl_get_device_ids(platform, LibCL::CL_DEVICE_TYPE_ALL, num_devices, devices, nil)
    devices
  end

  def get_devices(platform : LibCL::ClPlatformId, device_type) : Array(LibCL::ClDeviceId)
    check LibCL.cl_get_device_ids(platform, device_type, 0, nil, out num_devices)
    if num_devices == 0
      raise "No devices found"
    end

    devices = (0...num_devices).map { Pointer(Void).malloc(1).as(LibCL::ClDeviceId) }
    check LibCL.cl_get_device_ids(platform, device_type, num_devices, devices, nil)
    devices
  end

  def create_context(devices : Array(LibCL::ClDeviceId)) : LibCL::ClContext
    context = LibCL.cl_create_context(nil, UInt32.new(devices.size), devices, nil, nil, out status)
    check status
    context
  end

  def command_queue_for(context : LibCL::ClContext, device : LibCL::ClDeviceId) : LibCL::ClCommandQueue
    queue = LibCL.cl_create_command_queue(context, device, 0, out status)
    check status
    queue
  end

  def opencl_defaults : {Array(LibCL::ClDeviceId), LibCL::ClContext}
    platform = first_platform
    devices = get_devices(platform)
    context = create_context(devices)
    {devices, context}
  end

  def single_device_defaults : {LibCL::ClDeviceId, LibCL::ClContext, LibCL::ClCommandQueue}
    platform = first_platform
    device = get_devices(platform)[0]
    context = create_context([device])
    queue = command_queue_for(context, device)
    {device, context, queue}
  end

  def first_gpu_defaults : {LibCL::ClDeviceId, LibCL::ClContext, LibCL::ClCommandQueue}
    platform = first_platform
    device = get_devices(platform, LibCL::CL_DEVICE_TYPE_GPU)[0]
    context = create_context([device])
    queue = command_queue_for(context, device)
    {device, context, queue}
  end

  def create_program(context : LibCL::ClContext, body : String) : LibCL::ClProgram
    lines = [body.to_unsafe]
    result = LibCL.cl_create_program_with_source(context, 1, lines, nil, out status)
    check status
    result
  end

  def create_program_binary(context : LibCL::ClContext, device : LibCL::ClDeviceId, body : String) : LibCL::ClProgram
    lines = [body.to_unsafe]
    l = body.size
    result = LibCL.cl_create_program_with_binary(context, 1, pointerof(device), pointerof(l), lines, out binary_status, out status)
    check status
    result
  end

  def build_on(program : LibCL::ClProgram, devices : Array(LibCL::ClDeviceId))
    LibCL.cl_build_program(program, UInt32.new(devices.size), devices, nil, nil, nil)
  end

  def build_on(program : LibCL::ClProgram, device : LibCL::ClDeviceId)
    build_on(program, [device])
  end

  def create_and_build(context : LibCL::ClContext, body : String, device : LibCL::ClDeviceId) : LibCL::ClProgram
    result = create_program(context, body)
    build_on(result, device)
    result
  end

  def create_and_build(context : LibCL::ClContext, body : String, devices : Array(LibCL::ClDeviceId)) : LibCL::ClProgram
    result = create_program(context, body)
    build_on(result, devices)
    result
  end

  def create_and_build_binary(context : LibCL::ClContext, body : String, device : LibCL::ClDeviceId) : LibCL::ClProgram
    result = create_program_binary(context, device, body)
    build_on(result, device)
    result
  end

  def buffer(context : LibCL::ClContext, size : UInt64, flags : LibCL::ClMemFlags = LibCL::ClMemFlags::READ_WRITE, dtype : U.class = Float64) : LibCL::ClMem forall U
    buffer = LibCL.cl_create_buffer(context, flags, size * sizeof(U), nil, out status)
    check status
    buffer
  end

  def buffer_like(context : LibCL::ClContext, xs : Array(U), flags : LibCL::ClMemFlags = LibCL::ClMemFlags::READ_WRITE) : LibCL::ClMem forall U
    buffer(context, UInt64.new(xs.size), flags, dtype: U)
  end

  def build_errors(program : LibCL::ClProgram, devices : Array(LibCL::ClDeviceId)) : String
    check LibCL.cl_get_program_build_info(program, devices[0], LibCL::ClProgramBuildInfo::PROGRAM_BUILD_LOG, 0, nil, out log_size)
    result = Bytes.new(log_size + 1)
    check LibCL.cl_get_program_build_info(program, devices[0], LibCL::ClProgramBuildInfo::PROGRAM_BUILD_LOG, log_size, result, nil)
    String.new(result)
  end

  def create_kernel(program : LibCL::ClProgram, name : String) : LibCL::ClKernel
    result = LibCL.cl_create_kernel(program, name.to_slice, out status)
    check status
    result
  end

  def set_arg(kernel : LibCL::ClKernel, item : LibCL::ClMem, index : UInt32)
    check LibCL.cl_set_kernel_arg(kernel, index, sizeof(typeof(item)), pointerof(item))
  end

  def set_arg(kernel : LibCL::ClKernel, item : Int32, index : UInt32)
    check LibCL.cl_set_kernel_arg(kernel, index, sizeof(Int32), pointerof(item))
  end

  def set_arg(kernel : LibCL::ClKernel, item : Float32, index : UInt32)
    check LibCL.cl_set_kernel_arg(kernel, index, sizeof(Float32), pointerof(item))
  end

  def set_arg(kernel : LibCL::ClKernel, item : Float64, index : UInt32)
    check LibCL.cl_set_kernel_arg(kernel, index, sizeof(Float64), pointerof(item))
  end

  def args(kernel : LibCL::ClKernel, *args)
    args.each_with_index do |arg, i|
      set_arg(kernel, arg, UInt32.new(i))
    end
  end

  def run(queue : LibCL::ClCommandQueue, kernel : LibCL::ClKernel, work : Int)
    global_work_size = [UInt64.new(work), 0_u64, 0_u64]
    check LibCL.cl_enqueue_nd_range_kernel(queue, kernel, 1, nil, global_work_size, nil, 0, nil, nil)
  end

  def run(queue : LibCL::ClCommandQueue, kernel : LibCL::ClKernel, total_work : Int, local_work : Int)
    global_work_size = [UInt64.new(total_work), 0_u64, 0_u64]
    local_work_size = [UInt64.new(local_work), 0_u64, 0_u64]
    check LibCL.cl_enqueue_nd_range_kernel(queue, kernel, 1, nil, global_work_size, local_work_size, 0, nil, nil)
  end

  def run2d(queue : LibCL::ClCommandQueue, kernel : LibCL::ClKernel, total_work : Tuple(Int, Int))
    a, b = total_work
    global_work_size = [UInt64.new(a), UInt64.new(b), 0_u64]
    check LibCL.cl_enqueue_nd_range_kernel(queue, kernel, 2, nil, global_work_size, nil, 0, nil, nil)
  end

  def run2d(queue : LibCL::ClCommandQueue, kernel : LibCL::ClKernel, total_work : Tuple(Int, Int), local_work : Tuple(Int, Int))
    a, b = total_work
    c, d = local_work
    global_work_size = [UInt64.new(a), UInt64.new(b), 0_u64]
    local_work_size = [UInt64.new(c), UInt64.new(d), 0_u64]
    check LibCL.cl_enqueue_nd_range_kernel(queue, kernel, 2, nil, global_work_size, local_work_size, 0, nil, nil)
  end

  def run3d(queue : LibCL::ClCommandQueue, kernel : LibCL::ClKernel, total_work : Tuple(Int, Int, Int))
    global_work_size = Array(UInt64).new(3) { |i| UInt64.new(total_work[i]) }
    check LibCL.cl_enqueue_nd_range_kernel(queue, kernel, 3, nil, global_work_size, nil, 0, nil, nil)
  end

  def run3d(queue : LibCL::ClCommandQueue, kernel : LibCL::ClKernel, total_work : Tuple(Int, Int, Int), local_work : Tuple(Int, Int, Int))
    global_work_size = Array(UInt64).new(3) { |i| UInt64.new(total_work[i]) }
    local_work_size = Array(UInt64).new(3) { |i| UInt64.new(local_work[i]) }
    check LibCL.cl_enqueue_nd_range_kernel(queue, kernel, 3, nil, global_work_size, local_work_size, 0, nil, nil)
  end

  def write(queue : LibCL::ClCommandQueue, src : Pointer(U), dest : LibCL::ClMem, size : UInt64) forall U
    check LibCL.cl_enqueue_write_buffer(queue, dest, LibCL::CL_FALSE, 0, size, src, 0, nil, nil)
  end

  def write(queue : LibCL::ClCommandQueue, src : Array(U), dest : LibCL::ClMem) forall U
    write(queue, src.to_unsafe, dest, UInt64.new(src.size * sizeof(U)))
  end

  def fill(queue : LibCL::ClCommandQueue, buffer : LibCL::ClMem, value : U, size : UInt64) forall U
    LibCL.cl_enqueue_fill_buffer(queue, buffer, pointerof(value), sizeof(U), 0, size * sizeof(U), 0, nil, nil)
  end

  def read(queue : LibCL::ClCommandQueue, dest : Pointer(U), src : LibCL::ClMem, size : Int) forall U
    LibCL.cl_enqueue_read_buffer(queue, src, LibCL::CL_TRUE, 0, size, dest, 0, nil, nil)
  end

  def read(queue : LibCL::ClCommandQueue, dest : Array(U), src : LibCL::ClMem) forall U
    read(queue, dest.to_unsafe, src, UInt64.new(dest.size * sizeof(U)))
  end

  def release_buffer(buffer : LibCL::ClMem)
    check LibCL.cl_release_mem_object(buffer)
  end

  def release_queue(queue : LibCL::ClCommandQueue)
    check LibCL.cl_release_queue(queue)
  end

  def release_context(context : LibCL::ClContext)
    check LibCL.cl_release_context(context)
  end

  def release_kernel(kernel : LibCL::ClKernel)
    check LibCL.cl_release_kernel(kernel)
  end

  def release_program(program : LibCL::ClProgram)
    check LibCL.cl_release_program(program)
  end
end
