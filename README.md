# DartVulkan
The vulkan projects are for doing Compute Shaders.


# Create new project
You can create a new project via Flutter. Using *dart*

```sh
dart create basic_template
```

You can also copy an existing basic project by:
- Copy and rename project
- Update yaml *name:* attribute to match project name
- In *main.dart* update glfwCreateWindow name to match yaml
- Update any dependent shader loading names
- Update *launch.json* and modify the **DartRunner** "program" entry key to point to the new path. See below **Json launch entry** section.
- Restart vscode because it will be out of sync

# Json launch entry
Note: you need to update the "program" to reference the appropriate target.
```json
{
    "name": "DartRunner",
    "cwd": "/home/iposthuman/Documents/dart/DartOpenGL/",
    "program": "basic_template/bin/main.dart",
    "request": "launch",
    "type": "dart"
},
```

