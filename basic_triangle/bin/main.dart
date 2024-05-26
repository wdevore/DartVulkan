import 'dart:ffi';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:glfw3/glfw3.dart';
import 'package:path/path.dart' as p;
import 'dart:io' as io;

import 'package:vulkan/vulkan.dart';
// import 'package:ffi_utils/ffi_utils.dart';

late Pointer<GLFWwindow> window;
late Pointer<VkSurfaceKHR> surface;

late Pointer<Int32> extensionsCount;
late Pointer<Pointer> extensions;

late Pointer<VkInstance> instance;
Pointer<VkPhysicalDevice> physicalDevice = nullptr;
int physicalDeviceCount = 0;
int familyCount = 0;
int graphicsFamily = -1;
int presentFamily = -1;

late Pointer<VkDevice> device;
late Pointer<VkQueue> graphicsQueue;
late Pointer<VkQueue> presentQueue;

late Pointer<Pointer<VkSwapchainKHR>> swapChain;
late List<Pointer<VkImage>> swapChainImages;
late int swapChainImagesCount;
late int swapChainImageFormat;
late VkExtent2D swapChainExtent;
late List<Pointer<Pointer<VkImageView>>> swapChainImageViews;
late List<Pointer<VkFramebuffer>> swapChainFramebuffers;

late Pointer<VkRenderPass> renderPass;
late Pointer<VkPipelineLayout> pipelineLayout;
late Pointer<VkPipeline> graphicsPipeline;

late Pointer<VkCommandPool> commandPool;
late Pointer<Pointer<VkCommandBuffer>> commandBuffers;
late int commandBuffersCount;

late Pointer<Pointer<VkSemaphore>> imageAvailableSemaphores;
late Pointer<Pointer<VkSemaphore>> renderFinishedSemaphores;
late List<Pointer<Pointer<VkFence>>> inFlightFences;
late List<Pointer<Pointer<VkFence>>> imagesInFlight;
int currentFrame = 0;

const int windowWidth = 800;
const int windowHeight = 600;
const int maxFrames = 2;
const int uint64Max = 2 ^ 64;

void main() {
  initWindow();
  init();
  loop();
  cleanup();
}

void initWindow() {
  glfwInit();
  glfwVulkanSupported();

  final title = 'Dart FFI + GLFW + Vulkan';
  glfwWindowHint(GLFW_RESIZABLE, GLFW_FALSE);
  glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);
  window = glfwCreateWindow(windowWidth, windowHeight, title, nullptr, nullptr);
}

void init() {
  getInstanceExtensions();
  createInstance();
  createSurface();
  getPhysicalDevice();
  createLogicalDevice();
  getQueues();
  createSwapChain();
  createImageViews();
  createRenderPass();
  createGraphicsPipeline();
  createFramebuffers();
  createCommandPool();
  createCommandBuffers();
  createSyncObjects();
}

void loop() {
  while (glfwWindowShouldClose(window) != GLFW_TRUE) {
    glfwPollEvents();
    draw();
  }

  vkDeviceWaitIdle(device);
}

void cleanup() {
  vkDestroyDevice(device, nullptr);
  vkDestroyInstance(instance, nullptr);

  glfwDestroyWindow(window);
  glfwTerminate();
}

void getInstanceExtensions() {
  vkEnumerateInstanceExtensionProperties = Pointer<
              NativeFunction<
                  VkEnumerateInstanceExtensionPropertiesNative>>.fromAddress(
          vkGetInstanceProcAddr(nullptr,
                  'vkEnumerateInstanceExtensionProperties'.toNativeUtf8())
              .address)
      .asFunction<VkEnumerateInstanceExtensionProperties>();

  extensionsCount = calloc<Int32>();
  vkEnumerateInstanceExtensionProperties(nullptr, extensionsCount, nullptr);
  final props = calloc<VkExtensionProperties>(extensionsCount.value);
  vkEnumerateInstanceExtensionProperties(nullptr, extensionsCount, props);

  final names = List<String>.generate(extensionsCount.value,
      (i) => (props + i).ref.extensionName.toDartString(256));

  // late Pointer<Pointer> extensions;
  // extensions = NativeStringArray.fromList(names).cast();

  // fromList(List<String> strings) → Pointer<IntPtr>
  //   final myStrings = ['asdf', 'fsda'];
  // final List<Pointer<Utf8>> myPointers = names.map((element) => element.toNativeUtf8());

  //Pointer<Pointer<NativeString>> _ptrToPtr = allocate();
  // Pointer<Pointer<VkCommandBuffer>> commandBuffers = calloc<Pointer<VkCommandBuffer>>(swapChainImagesCount);
  // We want Pointer<Pointer<String>> Pointer<Pointer<NativeType>>
  // var x = names.map((element) => element.toNativeUtf8()).toList();

  // So is the representation in C just char** then? You can use the
  // (officially supported and up-to-date) package:ffi to copy Dart strings
  // as char* via Utf8. Then you allocate a char** via  something like

  // @audit-info extensions
  extensions = malloc<Pointer<Utf8>>(names.length);
  for (final (i, name) in names.indexed) {
    extensions[i] = name.toNativeUtf8();
    // Pointer<Uint8> nameP = malloc<Uint8>(name.length);
    // extensions[i] = nameP;
  }

  //   Pointer ptrToCopy; // i will assume that you have this already...
  // Pointer<Pointer<NativeType>> _ptrToPtr = allocate();
  // _ptrToPtr.value = Pointer.fromAddress(ptrToCopy.adress);
}

void createInstance() {
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
    ..enabledExtensionCount = extensionsCount.value
    ..ppEnabledExtensionNames = extensions
    ..enabledLayerCount = 0
    ..ppEnabledLayerNames = nullptr;

  final pinstance = calloc<Pointer<VkInstance>>();
  vkCreateInstance(ici, nullptr, pinstance);
  instance = pinstance.value;
}

void getPhysicalDevice() {
  final count = calloc<Int32>();
  vkEnumeratePhysicalDevices(instance, count, nullptr);

  physicalDeviceCount = count.value;
  print('physical devices count $physicalDeviceCount');

  final pphysicalDevices =
      calloc<Pointer<VkPhysicalDevice>>(physicalDeviceCount);
  vkEnumeratePhysicalDevices(instance, count, pphysicalDevices);

  for (var i = 0; i < physicalDeviceCount; i++) {
    final device = (pphysicalDevices + i).value;
    final physicalDeviceProperties = calloc<VkPhysicalDeviceProperties>();
    vkGetPhysicalDeviceProperties(device, physicalDeviceProperties);
    var deviceName = physicalDeviceProperties.ref.deviceName.toDartString(256);
    var deviceType = deviceTypeString(physicalDeviceProperties.ref.deviceType);
    var version = versionString(physicalDeviceProperties.ref.apiVersion);
    print('check [$deviceName] $deviceType $version');
    if (physicalDevice == nullptr && isDeviceSuitable(device)) {
      physicalDevice = device;
      print('pick [$deviceName]');
    }
  }
}

void createSurface() {
  final psurface = calloc<Pointer<VkSurfaceKHR>>();
  glfwCreateWindowSurface(instance.cast(), window, nullptr, psurface.cast());
  surface = psurface.value;
}

bool isDeviceSuitable(Pointer<VkPhysicalDevice> physicalDevice) {
  final count = calloc<Int32>();
  vkGetPhysicalDeviceQueueFamilyProperties(physicalDevice, count, nullptr);
  familyCount = count.value;

  final queueFamilyProps = calloc<VkQueueFamilyProperties>(familyCount);
  vkGetPhysicalDeviceQueueFamilyProperties(
      physicalDevice, count, queueFamilyProps);

  for (var i = 0; i < familyCount; i++) {
    final queueFamily = (queueFamilyProps + i).ref;
    if (queueFamily.queueFlags & VK_QUEUE_GRAPHICS_BIT > 0) {
      graphicsFamily = i;
    }

    final presentSupport = calloc<Uint32>();
    vkGetPhysicalDeviceSurfaceSupportKHR(
        physicalDevice, i, surface, presentSupport);
    if (presentSupport.value == VK_TRUE) {
      presentFamily = i;
    }

    if (graphicsFamily >= 0 && presentFamily >= 0) {
      break;
    }
  }

  return graphicsFamily >= 0 && presentFamily >= 0;
}

void createLogicalDevice() {
  final familyIndex = graphicsFamily;
  final queuePriorities = calloc<Float>();
  queuePriorities.value = 1.0;

  final requiredFeatures = calloc<VkPhysicalDeviceFeatures>();

  final queueCreateInfo = calloc<VkDeviceQueueCreateInfo>();
  queueCreateInfo.ref
    ..sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO
    ..flags = 0
    ..pNext = nullptr
    ..queueFamilyIndex = familyIndex
    ..queueCount = 1
    ..pQueuePriorities = queuePriorities;

  List<String> enabledExtNames = ['VK_KHR_swapchain'];

  // @audit-info enabled ext names
  Pointer<Pointer<Utf8>> enabledExtNameP =
      malloc<Pointer<Utf8>>(enabledExtNames.length);
  for (final (i, name) in enabledExtNames.indexed) {
    enabledExtNameP[i] = name.toNativeUtf8();
  }

  final createInfo = calloc<VkDeviceCreateInfo>();
  createInfo.ref
    ..sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO
    ..flags = 0
    ..queueCreateInfoCount = 1
    ..pQueueCreateInfos = queueCreateInfo
    ..enabledLayerCount = 0
    ..ppEnabledLayerNames = nullptr
    ..enabledExtensionCount = 1
    ..ppEnabledExtensionNames = enabledExtNameP
    ..pEnabledFeatures = requiredFeatures;

  final pdevice = calloc<Pointer<VkDevice>>();
  vkCreateDevice(physicalDevice, createInfo, nullptr, pdevice);
  device = pdevice.value;
}

void getQueues() {
  final pgraphicsQueue = calloc<Pointer<VkQueue>>();
  vkGetDeviceQueue(device, graphicsFamily, 0, pgraphicsQueue);
  graphicsQueue = pgraphicsQueue.value;

  final ppresentQueue = calloc<Pointer<VkQueue>>();
  vkGetDeviceQueue(device, presentFamily, 0, ppresentQueue);
  presentQueue = ppresentQueue.value;
}

void createSwapChain() {
  final swapChainSupport = querySwapChainSupport(physicalDevice);
  final surfaceFormat = chooseSwapSurfaceFormat(
      swapChainSupport.formats, swapChainSupport.formatCount);
  final presentMode = chooseSwapPresentMode(
      swapChainSupport.presentModes, swapChainSupport.presentModeCount);
  final extent = chooseSwapExtent(swapChainSupport.capabilities.ref);

  var minImageCount = swapChainSupport.capabilities.ref.minImageCount + 1;
  if (swapChainSupport.capabilities.ref.maxImageCount > 0 &&
      minImageCount > swapChainSupport.capabilities.ref.maxImageCount) {
    minImageCount = swapChainSupport.capabilities.ref.maxImageCount;
  }

  final createInfo = calloc<VkSwapchainCreateInfoKHR>();
  createInfo.ref
    ..sType = VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR
    ..surface = surface
    ..minImageCount = minImageCount
    ..imageFormat = surfaceFormat.format
    ..imageColorSpace = surfaceFormat.colorSpace
    ..imageExtent.width = extent.width
    ..imageExtent.height = extent.height
    ..imageArrayLayers = 1
    ..imageUsage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT
    ..imageSharingMode = VK_SHARING_MODE_EXCLUSIVE
    ..preTransform = swapChainSupport.capabilities.ref.currentTransform
    ..compositeAlpha = VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR
    ..presentMode = presentMode
    ..clipped = VK_TRUE
    ..oldSwapchain = nullptr;

  swapChain = calloc<Pointer<VkSwapchainKHR>>();
  vkCreateSwapchainKHR(device, createInfo, nullptr, swapChain);

  final imageCount = calloc<Uint32>();
  vkGetSwapchainImagesKHR(device, swapChain.value, imageCount, nullptr);
  swapChainImagesCount = imageCount.value;

  final pswapChainImage = calloc<Pointer<VkImage>>(swapChainImagesCount);
  vkGetSwapchainImagesKHR(device, swapChain.value, imageCount, pswapChainImage);
  swapChainImages = List<Pointer<VkImage>>.generate(
      swapChainImagesCount, (i) => (pswapChainImage + i).value);

  swapChainImageFormat = surfaceFormat.format;
  swapChainExtent = extent;
}

void createImageViews() {
  swapChainImageViews = List.filled(swapChainImagesCount, nullptr);

  for (var i = 0; i < swapChainImagesCount; i++) {
    final createInfo = calloc<VkImageViewCreateInfo>();
    createInfo.ref
      ..sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO
      ..image = swapChainImages[i]
      ..viewType = VK_IMAGE_VIEW_TYPE_2D
      ..format = swapChainImageFormat
      ..components.r = VK_COMPONENT_SWIZZLE_IDENTITY
      ..components.g = VK_COMPONENT_SWIZZLE_IDENTITY
      ..components.b = VK_COMPONENT_SWIZZLE_IDENTITY
      ..components.a = VK_COMPONENT_SWIZZLE_IDENTITY
      ..subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT
      ..subresourceRange.baseMipLevel = 0
      ..subresourceRange.levelCount = 1
      ..subresourceRange.baseArrayLayer = 0
      ..subresourceRange.layerCount = 1;

    swapChainImageViews[i] = calloc<Pointer<VkImageView>>();
    vkCreateImageView(device, createInfo, nullptr, swapChainImageViews[i]);
  }
}

void createRenderPass() {
  final colorAttachment = calloc<VkAttachmentDescription>();
  colorAttachment.ref
    ..format = swapChainImageFormat
    ..samples = VK_SAMPLE_COUNT_1_BIT
    ..loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR
    ..storeOp = VK_ATTACHMENT_STORE_OP_STORE
    ..stencilLoadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE
    ..stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE
    ..initialLayout = VK_IMAGE_LAYOUT_UNDEFINED
    ..finalLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;

  final colorAttachmentRef = calloc<VkAttachmentReference>();
  colorAttachmentRef.ref
    ..attachment = 0
    ..layout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;

  final subpass = calloc<VkSubpassDescription>();
  subpass.ref
    ..pipelineBindPoint = VK_PIPELINE_BIND_POINT_GRAPHICS
    ..colorAttachmentCount = 1
    ..pColorAttachments = colorAttachmentRef;

  final dependency = calloc<VkSubpassDependency>();
  dependency.ref
    ..srcSubpass = VK_SUBPASS_EXTERNAL
    ..dstSubpass = 0
    ..srcStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT
    ..srcAccessMask = 0
    ..dstStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT
    ..dstAccessMask = VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;

  final renderPassInfo = calloc<VkRenderPassCreateInfo>();
  renderPassInfo.ref
    ..sType = VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO
    ..pNext = nullptr
    ..flags = 0
    ..attachmentCount = 1
    ..pAttachments = colorAttachment
    ..subpassCount = 1
    ..pSubpasses = subpass
    ..dependencyCount = 1
    ..pDependencies = dependency;

  final prenderPass = calloc<Pointer<VkRenderPass>>();
  vkCreateRenderPass(device, renderPassInfo, nullptr, prenderPass);
  renderPass = prenderPass.value;
}

void createGraphicsPipeline() {
  var relativePath = 'basic_triangle/bin';
  var filePath =
      p.join(io.Directory.current.path, relativePath, 'main.vert.sprv');
  final vertShaderCode = File(filePath).readAsBytesSync();
  filePath = p.join(io.Directory.current.path, relativePath, 'main.frag.sprv');
  final fragShaderCode = File(filePath).readAsBytesSync();

  final vertShaderModule = calloc<Pointer<VkShaderModule>>();
  final fragShaderModule = calloc<Pointer<VkShaderModule>>();

  createShaderModule(vertShaderModule, vertShaderCode);
  createShaderModule(fragShaderModule, fragShaderCode);

  final shaderStages = calloc<VkPipelineShaderStageCreateInfo>(2);

  final vertShaderStageInfo = shaderStages;
  vertShaderStageInfo.ref
    ..sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO
    ..stage = VK_SHADER_STAGE_VERTEX_BIT
    ..module = vertShaderModule.value
    ..pName = 'main'.toNativeUtf8();

  final fragShaderStageInfo = shaderStages + 1;
  fragShaderStageInfo.ref
    ..sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO
    ..stage = VK_SHADER_STAGE_FRAGMENT_BIT
    ..module = fragShaderModule.value
    ..pName = 'main'.toNativeUtf8();

  final vertexInputInfo = calloc<VkPipelineVertexInputStateCreateInfo>();
  vertexInputInfo.ref
    ..sType = VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO
    ..vertexBindingDescriptionCount = 0
    ..vertexAttributeDescriptionCount = 0;

  final inputAssembly = calloc<VkPipelineInputAssemblyStateCreateInfo>();
  inputAssembly.ref
    ..sType = VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO
    ..topology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST
    ..primitiveRestartEnable = VK_FALSE;

  final viewport = calloc<VkViewport>();
  viewport.ref
    ..x = 0.0
    ..y = 0.0
    ..width = swapChainExtent.width + 0.0
    ..height = swapChainExtent.height + 0.0
    ..minDepth = 0.0
    ..maxDepth = 1.0;

  final scissor = calloc<VkRect2D>();
  scissor.ref
    ..offset.x = 0
    ..offset.y = 0
    ..extent.width = swapChainExtent.width
    ..extent.height = swapChainExtent.height;

  final viewportState = calloc<VkPipelineViewportStateCreateInfo>();
  viewportState.ref
    ..sType = VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO
    ..viewportCount = 1
    ..pViewports = viewport
    ..scissorCount = 1
    ..pScissors = scissor;

  final rasterizer = calloc<VkPipelineRasterizationStateCreateInfo>();
  rasterizer.ref
    ..sType = VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO
    ..depthClampEnable = VK_FALSE
    ..rasterizerDiscardEnable = VK_FALSE
    ..polygonMode = VK_POLYGON_MODE_FILL
    ..lineWidth = 1.0
    ..cullMode = VK_CULL_MODE_BACK_BIT
    ..frontFace = VK_FRONT_FACE_CLOCKWISE
    ..depthBiasEnable = VK_FALSE;

  final multisampling = calloc<VkPipelineMultisampleStateCreateInfo>();
  multisampling.ref
    ..sType = VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO
    ..sampleShadingEnable = VK_FALSE
    ..rasterizationSamples = VK_SAMPLE_COUNT_1_BIT;

  final colorBlendAttachment = calloc<VkPipelineColorBlendAttachmentState>();
  colorBlendAttachment.ref
    ..colorWriteMask = VK_COLOR_COMPONENT_R_BIT |
        VK_COLOR_COMPONENT_G_BIT |
        VK_COLOR_COMPONENT_B_BIT |
        VK_COLOR_COMPONENT_A_BIT
    ..blendEnable = VK_FALSE;

  final colorBlending = calloc<VkPipelineColorBlendStateCreateInfo>();
  colorBlending.ref
    ..sType = VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO
    ..logicOpEnable = VK_FALSE
    ..logicOp = VK_LOGIC_OP_COPY
    ..attachmentCount = 1
    ..pAttachments = colorBlendAttachment
    ..blendConstants[0] = 0.0
    ..blendConstants[1] = 0.0
    ..blendConstants[2] = 0.0
    ..blendConstants[3] = 0.0;

  final pipelineLayoutInfo = calloc<VkPipelineLayoutCreateInfo>();
  pipelineLayoutInfo.ref
    ..sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO
    ..setLayoutCount = 0
    ..pushConstantRangeCount = 0;

  final ppipelineLayout = calloc<Pointer<VkPipelineLayout>>();
  vkCreatePipelineLayout(device, pipelineLayoutInfo, nullptr, ppipelineLayout);
  pipelineLayout = ppipelineLayout.value;

  final pipelineInfo = calloc<VkGraphicsPipelineCreateInfo>();
  pipelineInfo.ref
    ..sType = VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO
    ..stageCount = 2
    ..pStages = shaderStages
    ..pVertexInputState = vertexInputInfo
    ..pInputAssemblyState = inputAssembly
    ..pViewportState = viewportState
    ..pRasterizationState = rasterizer
    ..pMultisampleState = multisampling
    ..pColorBlendState = colorBlending
    ..layout = pipelineLayout
    ..renderPass = renderPass
    ..subpass = 0
    ..basePipelineHandle = nullptr;

  final pgraphicsPipeline = calloc<Pointer<VkPipeline>>();
  vkCreateGraphicsPipelines(
      device, nullptr, 1, pipelineInfo, nullptr, pgraphicsPipeline);
  graphicsPipeline = pgraphicsPipeline.value;

  vkDestroyShaderModule(device, fragShaderModule.value, nullptr);
  vkDestroyShaderModule(device, vertShaderModule.value, nullptr);
}

void createFramebuffers() {
  swapChainFramebuffers = List.filled(swapChainImagesCount, nullptr);

  for (var i = 0; i < swapChainImagesCount; i++) {
    final framebufferInfo = calloc<VkFramebufferCreateInfo>();
    framebufferInfo.ref
      ..sType = VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO
      ..renderPass = renderPass
      ..attachmentCount = 1
      ..pAttachments = swapChainImageViews[i]
      ..width = swapChainExtent.width
      ..height = swapChainExtent.height
      ..layers = 1;

    final pframeBuffer = calloc<Pointer<VkFramebuffer>>();
    vkCreateFramebuffer(device, framebufferInfo, nullptr, pframeBuffer);
    swapChainFramebuffers[i] = pframeBuffer.value;
  }
}

void createCommandPool() {
  final poolInfo = calloc<VkCommandPoolCreateInfo>();
  poolInfo.ref
    ..sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO
    ..queueFamilyIndex = graphicsFamily;

  final pcommandPool = calloc<Pointer<VkCommandPool>>();
  vkCreateCommandPool(device, poolInfo, nullptr, pcommandPool);
  commandPool = pcommandPool.value;
}

void createCommandBuffers() {
  final allocInfo = calloc<VkCommandBufferAllocateInfo>();
  allocInfo.ref
    ..sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO
    ..commandPool = commandPool
    ..level = VK_COMMAND_BUFFER_LEVEL_PRIMARY
    ..commandBufferCount = swapChainImagesCount;

  commandBuffers = calloc<Pointer<VkCommandBuffer>>(swapChainImagesCount);
  vkAllocateCommandBuffers(device, allocInfo, commandBuffers);

  for (var i = 0; i < swapChainImagesCount; i++) {
    final beginInfo = calloc<VkCommandBufferBeginInfo>();
    beginInfo.ref.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;

    vkBeginCommandBuffer((commandBuffers + i).value, beginInfo);

    final renderPassInfo = calloc<VkRenderPassBeginInfo>();
    renderPassInfo.ref
      ..sType = VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO
      ..renderPass = renderPass
      ..framebuffer = swapChainFramebuffers[i]
      ..renderArea.offset.x = 0
      ..renderArea.offset.y = 0
      ..renderArea.extent.width = swapChainExtent.width
      ..renderArea.extent.height = swapChainExtent.height
      ..clearValueCount = 1
      ..pClearValues = (calloc<VkClearColorValue>()
            ..ref.float32.fromList([0.0, 0.0, 0.0, 1.0]))
          .cast();

    vkCmdBeginRenderPass(
        (commandBuffers + i).value, renderPassInfo, VK_SUBPASS_CONTENTS_INLINE);
    vkCmdBindPipeline((commandBuffers + i).value,
        VK_PIPELINE_BIND_POINT_GRAPHICS, graphicsPipeline);
    vkCmdDraw((commandBuffers + i).value, 3, 1, 0, 0);
    vkCmdEndRenderPass((commandBuffers + i).value);

    vkEndCommandBuffer((commandBuffers + i).value);
  }
}

void createSyncObjects() {
  imageAvailableSemaphores = calloc<Pointer<VkSemaphore>>(maxFrames);
  renderFinishedSemaphores = calloc<Pointer<VkSemaphore>>(maxFrames);
  inFlightFences = List<Pointer<Pointer<VkFence>>>.filled(maxFrames, nullptr);
  imagesInFlight =
      List<Pointer<Pointer<VkFence>>>.filled(swapChainImagesCount, nullptr);

  final semaphoreInfo = calloc<VkSemaphoreCreateInfo>();
  semaphoreInfo.ref.sType = VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO;

  final fenceInfo = calloc<VkFenceCreateInfo>();
  fenceInfo.ref
    ..sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO
    ..flags = VK_FENCE_CREATE_SIGNALED_BIT;

  for (var i = 0; i < maxFrames; i++) {
    vkCreateSemaphore(
        device, semaphoreInfo, nullptr, imageAvailableSemaphores + i);
    vkCreateSemaphore(
        device, semaphoreInfo, nullptr, renderFinishedSemaphores + i);

    final pfence = calloc<Pointer<VkFence>>();
    vkCreateFence(device, fenceInfo, nullptr, pfence);
    inFlightFences[i] = pfence;
  }
}

void draw() {
  vkWaitForFences(device, 1, inFlightFences[currentFrame], VK_TRUE, uint64Max);

  final imageIndex = calloc<Int32>();
  vkAcquireNextImageKHR(device, swapChain.value, uint64Max,
      (imageAvailableSemaphores + currentFrame).value, nullptr, imageIndex);

  if (imagesInFlight[imageIndex.value] != nullptr) {
    vkWaitForFences(
        device, 1, imagesInFlight[imageIndex.value], VK_TRUE, uint64Max);
  }
  imagesInFlight[imageIndex.value] = inFlightFences[currentFrame];

  final submitInfo = calloc<VkSubmitInfo>();
  submitInfo.ref.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO;

  final waitStages = calloc<Uint32>();
  waitStages.value = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
  submitInfo.ref
    ..waitSemaphoreCount = 1
    ..pWaitSemaphores = (imageAvailableSemaphores + currentFrame)
    ..pWaitDstStageMask = waitStages
    ..commandBufferCount = 1
    ..pCommandBuffers = (commandBuffers + imageIndex.value);
  final signalSemaphores = (renderFinishedSemaphores + currentFrame);
  submitInfo.ref
    ..signalSemaphoreCount = 1
    ..pSignalSemaphores = signalSemaphores;

  vkResetFences(device, 1, inFlightFences[currentFrame]);

  vkQueueSubmit(
      graphicsQueue, 1, submitInfo, inFlightFences[currentFrame].value);

  final presentInfo = calloc<VkPresentInfoKHR>();
  presentInfo.ref
    ..sType = VK_STRUCTURE_TYPE_PRESENT_INFO_KHR
    ..waitSemaphoreCount = 1
    ..pWaitSemaphores = signalSemaphores
    ..swapchainCount = 1
    ..pSwapchains = swapChain
    ..pImageIndices = imageIndex;

  vkQueuePresentKHR(presentQueue, presentInfo);

  currentFrame = (currentFrame + 1) % maxFrames;
}

class SwapChainSupportDetails {
  late Pointer<VkSurfaceCapabilitiesKHR> capabilities;
  late Pointer<VkSurfaceFormatKHR> formats;
  late int formatCount;
  late Pointer<Int32> presentModes;
  late int presentModeCount;
}

SwapChainSupportDetails querySwapChainSupport(
    Pointer<VkPhysicalDevice> physicalDevice) {
  final details = SwapChainSupportDetails();
  details.capabilities = calloc<VkSurfaceCapabilitiesKHR>();

  vkGetPhysicalDeviceSurfaceCapabilitiesKHR(
      physicalDevice, surface, details.capabilities);

  final formatCount = calloc<Uint32>();
  vkGetPhysicalDeviceSurfaceFormatsKHR(
      physicalDevice, surface, formatCount, nullptr);
  details.formatCount = formatCount.value;

  if (formatCount.value != 0) {
    details.formats = calloc<VkSurfaceFormatKHR>(formatCount.value);
    vkGetPhysicalDeviceSurfaceFormatsKHR(
        physicalDevice, surface, formatCount, details.formats);
  }

  final presentModeCount = calloc<Uint32>();
  vkGetPhysicalDeviceSurfacePresentModesKHR(
      physicalDevice, surface, presentModeCount, nullptr);
  details.presentModeCount = presentModeCount.value;

  if (presentModeCount.value != 0) {
    details.presentModes = calloc<Int32>(presentModeCount.value);
    vkGetPhysicalDeviceSurfacePresentModesKHR(
        physicalDevice, surface, presentModeCount, details.presentModes);
  }

  return details;
}

VkSurfaceFormatKHR chooseSwapSurfaceFormat(
    Pointer<VkSurfaceFormatKHR> availableFormats, int count) {
  for (var i = 0; i < count; i++) {
    final availableFormat = (availableFormats + i).ref;
    if (availableFormat.format == VK_FORMAT_B8G8R8A8_SRGB &&
        availableFormat.colorSpace == VK_COLOR_SPACE_SRGB_NONLINEAR_KHR) {
      return availableFormat;
    }
  }

  return availableFormats[0];
}

int chooseSwapPresentMode(Pointer<Int32> availablePresentModes, int count) {
  for (var i = 0; i < count; i++) {
    final availablePresentMode = (availablePresentModes + i).value;
    if (availablePresentMode == VK_PRESENT_MODE_MAILBOX_KHR) {
      return availablePresentMode;
    }
  }

  return VK_PRESENT_MODE_FIFO_KHR;
}

VkExtent2D chooseSwapExtent(VkSurfaceCapabilitiesKHR capabilities) {
  if (capabilities.currentExtent.width != 2 ^ 32) {
    final currentExtent = calloc<VkExtent2D>().ref;
    currentExtent.width = capabilities.currentExtent.width;
    currentExtent.height = capabilities.currentExtent.height;
    return currentExtent;
  } else {
    final actualExtent = calloc<VkExtent2D>().ref;
    actualExtent.width = windowWidth;
    actualExtent.height = windowHeight;

    actualExtent.width = max(capabilities.minImageExtent.width,
        min(capabilities.maxImageExtent.width, actualExtent.width));
    actualExtent.height = max(capabilities.minImageExtent.height,
        min(capabilities.maxImageExtent.height, actualExtent.height));

    return actualExtent;
  }
}

void createShaderModule(
    Pointer<Pointer<VkShaderModule>> shaderModule, List<int> codes) {
  // ByteBuffer buffer = Uint8List(codes.length).buffer;
  // ByteData bdata = ByteData.view(buffer);

  // Pointer<Pointer<Uint8>> codesP = calloc<Pointer<Uint8>>(codes.length);
  Pointer<Uint8> codesP = calloc<Uint8>(codes.length);

  // @audit-info creatShaderModule
  for (final (i, code) in codes.indexed) {
    // bdata.setUint8(i, code);
    // codesP[i] = Uint8List.fromList(codes);

    codesP[i] = code;
  }

  final createInfo = calloc<VkShaderModuleCreateInfo>();
  createInfo.ref
    ..sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO
    ..codeSize = codes.length
    ..pCode = codesP;
  //NativeBuffer.fromBytes(codes);

  vkCreateShaderModule(device, createInfo, nullptr, shaderModule);
  calloc.free(codesP);
}

int errorCallback(int error, Pointer<Uint8> description) {
  print('GLFW $error ${description.cast<Utf8>().toDartString()}');
  return 0;
}

int makeVersion(int major, int minor, int patch) {
  return (((major) << 22) | ((minor) << 12) | (patch));
}

String versionString(int version) {
  return '${version >> 22}.${(version >> 12) & 0x3ff}.${version & 0xfff}';
}

String deviceTypeString(int deviceType) {
  switch (deviceType) {
    case VK_PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU:
      return 'INTEGRATED_GPU';
    case VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU:
      return 'DISCRETE_GPU';
    case VK_PHYSICAL_DEVICE_TYPE_VIRTUAL_GPU:
      return 'VIRTUAL_GPU';
    case VK_PHYSICAL_DEVICE_TYPE_CPU:
      return 'CPU';
    default:
      return 'OTHER';
  }
}

extension ArrayToString on Array<Uint8> {
  String toDartString(int length) {
    final bytes = List.filled(length, 0);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = this[i];
    }
    final name = String.fromCharCodes(bytes, 0, bytes.indexOf(0));
    return name;
  }
}

extension ArrayFloatFromList on Array<Float> {
  Array<Float> fromList(List<double> list) {
    for (var i = 0; i < list.length; i++) {
      this[i] = list[i];
    }
    return this;
  }
}
