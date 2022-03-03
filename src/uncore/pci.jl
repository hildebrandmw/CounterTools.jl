# Tools for dealing with PCI
const DRV_IS_PCI_VENDOR_ID_INTEL = 0x8086
const VENDOR_ID_MASK = 0x0000_FFFF
const DEVICE_ID_MASK = 0xFFFF_0000
const DEVICE_ID_BITSHIFT = 16
const PCI_ENABLE = 0x8000_0000

# These are found in uncore performance monitoring guide
# Under: "Uncore Performance Monitoring State in PCICFG space"
# Device and Function IDS for Skylake based IMCs
const SKYLAKE_IMC_REGISTERS = (
    # IMC 0 - Channels 0, 1, 2
    ((device = 10, fn = 2), (device = 10, fn = 6), (device = 11, fn = 2)),
    # IMC 1 - Channels 0, 1, 2
    ((device = 12, fn = 2), (device = 12, fn = 6), (device = 13, fn = 2)),
)

const IMC_DEVICE_IDS = (0x2042, 0x2046, 0x204A)

# This is taken from the PCM code
#
# TODO: Dynamically find number of sockets
#
# The general idea is that we know the device and function numbers of IMC devices
# Furthermore, we know the device IDS
#
# So, we enumerate all of the PCI busses until
#   1. We find a valid path
#   2. We read the vendor ID and device ID from the device
#       - Vendor ID must match Intel (0x8086)
#       - Device ID must match one of the iMC device IDS
#
# When we've found this, we've found the bus for the socket.
#
# NOTE: I'm assuming that lower bus numbers correspond to lower sockets.
# This appears consistent with what's happening in PCM.
#
# NOTE: There's a lot of business with PCI group numbers.
# I'm ignoring that for now because we only have group 0 on our system.
#
# TODO: We can abstract this for different architectures using dispatch, but I'm not
# too worried about that at the moment.
function findbusses(;
    device = first(first(SKYLAKE_IMC_REGISTERS)).device,
    fn = first(first(SKYLAKE_IMC_REGISTERS)).fn,
    device_ids = IMC_DEVICE_IDS,
)
    socket_to_bus = UInt[]
    bus_numbers = 0:255
    for bus in bus_numbers
        # Check to see if the path exists
        path = pcipath(bus, device, fn)
        ispath(path) || continue
        pci = Handle(path)

        # Read the first value from the bus - compare against vendor
        value = read(pci, UInt32, IndexZero(0))
        vendor_id = value & VENDOR_ID_MASK
        device_id = (value & DEVICE_ID_MASK) >> DEVICE_ID_BITSHIFT

        # Check if this is run by Intel
        vendor_id == DRV_IS_PCI_VENDOR_ID_INTEL || continue
        in(device_id, device_ids) || continue
        push!(socket_to_bus, bus)

        close(pci)
    end

    return socket_to_bus
end

#####
##### Ice Lake Stuff
#####

# # MMIO_BASE found at Bus U0, Device 0, Function 1, offset D0h.
# const ICX_IMC_MMIO_BASE_OFFSET = 0xd0
# const ICX_IMC_MMIO_BASE_MASK = 0x1FFFFFFF
#
# # MEM0_BAR found at Bus U0, Device 0, Function 1, offset D8h.
# const ICX_IMC_MMIO_MEM0_OFFSET = 0xd8
# const ICX_IMC_MMIO_MEM_STRIDE = 0xd04
# const ICX_IMC_MMIO_MEM_MASK = 0x7FF
#
# # Each IMC has two channels. But there is addressing for three. Need to
# # determine which two channels are active on the system.
# # The offset starts from 0x22800 with stride 0x4000
# #
# const ICX_IMC_MMIO_CHN_OFFSET = 0x22800
# const ICX_IMC_MMIO_CHN_STRIDE = 0x4000
# # /* IMC MMIO size*/
# const ICX_IMC_MMIO_SIZE = 0x4000
#
# const SERVER_UBOX0_REGISTER_DEV_ADDR = 0
# const SERVER_UBOX0_REGISTER_FUNC_ADDR = 1
#
# function map_imc_pmon(package_id::Integer, imc_index::Integer, channel_index::Integer; kw...)
#     return map_imc_pmon(convert(UInt, package_id), convert(UInt, imc_index), convert(UInt, channel_index), kw...)
# end
#
# function map_imc_pmon(package_id::UInt64, imc_index::UInt64, channel_index::UInt64; device_ids = (0x3451,))
#     bus_numbers = 0:255
#     device = SERVER_UBOX0_REGISTER_DEV_ADDR
#     fn = SERVER_UBOX0_REGISTER_FUNC_ADDR
#
#     socket_to_bus = UInt[]
#
#     for bus in bus_numbers
#         path = pcipath(bus, device, fn)
#         ispath(path) || continue
#         pci = Handle(path)
#         #seek(pci, IndexZero(0))
#         #value = read(pci, UInt32)
#         value = read(pci, UInt32, IndexZero(0))
#
#         vendor_id = value & VENDOR_ID_MASK
#         device_id = (value & DEVICE_ID_MASK) >> DEVICE_ID_BITSHIFT
#
#         vendor_id == DRV_IS_PCI_VENDOR_ID_INTEL || continue
#         in(device_id, device_ids) || continue
#         push!(socket_to_bus, bus)
#
#         # # Do some things
#         # # Read MEMn addr (51:23) from MMIO_BASE register
#         # seek(pci, IndexZero(ICX_IMC_MMIO_BASE_OFFSET))
#         # pci_uint32 = read(pci, UInt32, IndexZero(ICX_IMC_MMIO_MEM0_OFFSET)
#         # address = (pci_uint32 & ICX_IMC_MMIO_BASE_MASK) << 23
#
#         # # read MEMn addr (22:12) from MEMn_BAR register
#         # mem_offset = ICX_IMC_MMIO_MEM0_OFFSET + imc_index * ICX_IMC_MMIO_MEM_STRIDE;
#         # seek(pci, IndexZero(mem_offset))
#         # pci_uint32 = read(pci, UInt32)
#         # address |= (pci_uint32 & ICX_IMC_MMIO_MEM_MASK) << 12;
#
#         # # IMC PMON registers start from PMONUNITCTRL */
#         # address += ICX_IMC_MMIO_CHN_OFFSET + channel_index * ICX_IMC_MMIO_CHN_STRIDE;
#         # @show address
#         close(pci)
#     end
#     return socket_to_bus
# end
#
# # /*
# # * pkg_id: Socket id
# # * imc_idx: The IMC index
# # * channel_idx: The channel index
# # */
# # Void *map_imc_pmon(int pkg_id, int imc_idx, int channel_idx)
# # {
# #   struct pci_dev *pdev = NULL;
# #   resource_size_t addr;
# #   u32 pci_dword;
# #   void *io_addr;
# #   int mem_offset;
# #   /*
# #   * Device ID of Bus U0, Device 0, Function 1 is 0x3451 */
# #   * Get its pdev on the specific socket.
# #   */
# #   while(1){
# #       pdev = pci_get_device(PCI_VENDOR_ID_INTEL, 0x3451, pdev);
# #       if ((!pdev) || (pdev->bus == UNC_UBOX_package_to_bus_map[pkg_id]))
# #           break;
# #   }
# #   if (!pdev)
# #       return NULL;
# #
# #   /* read MEMn addr (51:23) from MMIO_BASE register */
# #   pci_read_config_dword(pdev, ICX_IMC_MMIO_BASE_OFFSET, &pci_dword);
# #   addr = (pci_dword & ICX_IMC_MMIO_BASE_MASK) << 23;
# #
# #   /* read MEMn addr (22:12) from MEMn_BAR register */
# #   mem_offset = ICX_IMC_MMIO_MEM0_OFFSET + mem_idx * ICX_IMC_MMIO_MEM_STRIDE;
# #   pci_read_config_dword(pdev, mem_offset, &pci_dword);
# #   addr |= (pci_dword & ICX_IMC_MMIO_MEM_MASK) << 12;
#
#   /* IMC PMON registers start from PMONUNITCTRL */
#   addr += ICX_IMC_MMIO_CHN_OFFSET + channel_idx * ICX_IMC_MMIO_CHN_STRIDE;
#   /* map the IMC PMON registers */
#   io_addr = ioremap(addr, ICX_IMC_MMIO_SIZE);
#   return io_addr;
# }
