/* Bind Home at the compositor, including while a game owns keyboard focus. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>
#include <sys/types.h>
#include <unistd.h>
#include <wayland-client.h>
#include "gamescope-action-binding-client-protocol.h"

static struct gamescope_action_binding_manager *manager;
static char **command;

static void global(void *data, struct wl_registry *registry, uint32_t name,
                   const char *interface, uint32_t version) {
    (void)data;
    (void)version;
    if (strcmp(interface, "gamescope_action_binding_manager") == 0)
        manager = wl_registry_bind(registry, name,
                                  &gamescope_action_binding_manager_interface, 1);
}

static void removed(void *data, struct wl_registry *registry, uint32_t name) {
    (void)data;
    (void)registry;
    (void)name;
}

static void triggered(void *data, struct gamescope_action_binding *binding,
                      uint32_t sequence, uint32_t time_lo, uint32_t time_hi,
                      uint32_t flags) {
    (void)data;
    (void)binding;
    (void)sequence;
    (void)time_lo;
    (void)time_hi;
    (void)flags;
    pid_t child = fork();
    if (child == 0) {
        execvp(command[0], command);
        _exit(127);
    }
    if (child < 0) perror("Home shortcut fork");
}

int main(int argc, char **argv) {
    if (argc < 2) return 2;
    command = &argv[1];
    signal(SIGCHLD, SIG_IGN);
    struct wl_display *display = wl_display_connect(getenv("GAMESCOPE_WAYLAND_DISPLAY"));
    if (!display) { perror("Gamescope shortcut connection"); return 1; }
    struct wl_registry *registry = wl_display_get_registry(display);
    static const struct wl_registry_listener globals = {global, removed};
    wl_registry_add_listener(registry, &globals, NULL);
    if (wl_display_roundtrip(display) < 0 || !manager) {
        fprintf(stderr, "Gamescope has no action binding protocol\n");
        return 1;
    }
    struct gamescope_action_binding *binding =
        gamescope_action_binding_manager_create_action_binding(manager);
    static const struct gamescope_action_binding_listener events = {triggered};
    gamescope_action_binding_add_listener(binding, &events, NULL);
    struct wl_array keys;
    wl_array_init(&keys);
    uint32_t *key = wl_array_add(&keys, sizeof(uint32_t));
    if (!key) return 1;
    *key = 0xffca; /* XKB_KEY_F13: InputPlumber maps the controller's Home here. */
    gamescope_action_binding_add_keyboard_trigger(binding, &keys);
    wl_array_release(&keys);
    gamescope_action_binding_set_description(binding, "Theatre Home");
    gamescope_action_binding_arm(binding, 0);
    wl_display_flush(display);
    while (wl_display_dispatch(display) >= 0) {}
    wl_display_disconnect(display);
    return 1;
}
