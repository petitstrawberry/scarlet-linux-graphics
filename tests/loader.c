#include <dlfcn.h>
#include <stdio.h>

int main(void)
{
    const struct { const char *library; const char *symbol; } checks[] = {
        {"libvulkan.so.1", "vkGetInstanceProcAddr"},
        {"libvulkan_sgfx.so", "vk_icdGetInstanceProcAddr"},
        {"libEGL_mesa.so.0", "__egl_Main"},
        {"libSDL2-2.0.so.0", "SDL_GL_CreateContext"}
    };
    for (unsigned i = 0; i < sizeof(checks) / sizeof(*checks); ++i) {
        void *library = dlopen(checks[i].library, RTLD_NOW | RTLD_LOCAL);
        if (!library) { fprintf(stderr, "%s: %s\n", checks[i].library, dlerror()); return 1; }
        if (!dlsym(library, checks[i].symbol)) {
            fprintf(stderr, "%s: missing %s\n", checks[i].library, checks[i].symbol); return 1;
        }
        printf("loaded %s (%s)\n", checks[i].library, checks[i].symbol);
        dlclose(library);
    }
    return 0;
}
