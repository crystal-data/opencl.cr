require "./libcl"

module ClWrapper
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

  def buffer(context : LibCL::ClContext, size : UInt64, flags : LibCL::ClMemFlags = LibCL::ClMemFlags::READ_WRITE, dtype : U.class = Float64) : LibCL::ClMem forall U
    buffer = LibCL.cl_create_buffer(context, flags, size * sizeof(U), nil, out status)
    check status
    buffer
  end

  def release_buffer(buffer : LibCL::ClMem)
    check LibCL.cl_release_mem_object(buffer)
  end
end
