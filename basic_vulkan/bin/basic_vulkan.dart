import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:vulkan/vulkan.dart';

void main() {
  final ai = calloc<VkApplicationInfo>();
  ai.ref
    ..sType = VK_STRUCTURE_TYPE_APPLICATION_INFO
    ..pNext = nullptr
    ..pApplicationName = 'Application'.toNativeUtf8()
    ..applicationVersion = makeVersion(1, 0, 0)
    ..pEngineName = 'Engine'.toNativeUtf8()
    ..engineVersion = 0
    ..apiVersion = makeVersion(1, 0, 0);

  final ici = calloc<VkInstanceCreateInfo>();
  ici.ref
    ..sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO
    ..pNext = nullptr
    ..flags = 0
    ..pApplicationInfo = ai
    ..enabledExtensionCount = 0
    ..ppEnabledExtensionNames = nullptr
    ..enabledLayerCount = 0
    ..ppEnabledLayerNames = nullptr;

  final instance = calloc<Pointer<VkInstance>>();
  final result = vkCreateInstance(ici, nullptr, instance);
  print(result == VK_SUCCESS
      ? 'Vulkan instance succesfully created'
      : 'Failed to create Vulkan insatnce');

  vkDestroyInstance(instance.value, nullptr);
}

int makeVersion(int major, int minor, int patch) =>
    ((major) << 22) | ((minor) << 12) | (patch);
