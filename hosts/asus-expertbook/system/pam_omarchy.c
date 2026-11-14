/*
 * Thin PAM bridge for omarchy-pam-auth.
 *
 * pam_exec always reports PAM_SYSTEM_ERR for a non-zero helper, so it cannot
 * distinguish "no graphical session" (fall through to the terminal stack)
 * from "the user cancelled the dialog" (deny immediately). This module maps
 * the helper's exit code itself:
 *
 *   0  -> PAM_SUCCESS
 *   1  -> PAM_IGNORE  (no socket; use the normal fprintd/unix stack)
 *   5  -> PAM_AUTH_ERR (Cancel; do not fall back)
 *   *  -> PAM_SYSTEM_ERR
 */

#include <errno.h>
#include <security/pam_appl.h>
#include <security/pam_modules.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

PAM_EXTERN int
pam_sm_authenticate(pam_handle_t *pamh, int flags, int argc, const char **argv)
{
    const void *user = NULL;
    const void *service = NULL;
    int status;
    pid_t pid;

    (void)flags;

    if (argc < 1)
        return PAM_SERVICE_ERR;

    pam_get_item(pamh, PAM_USER, &user);
    pam_get_item(pamh, PAM_SERVICE, &service);

    pid = fork();
    if (pid < 0)
        return PAM_SYSTEM_ERR;

    if (pid == 0) {
        if (user)
            setenv("PAM_USER", (const char *)user, 1);
        if (service)
            setenv("PAM_SERVICE", (const char *)service, 1);
        execv(argv[0], (char *const *)argv);
        _exit(127);
    }

    while (waitpid(pid, &status, 0) < 0) {
        if (errno != EINTR)
            return PAM_SYSTEM_ERR;
    }

    if (WIFEXITED(status)) {
        switch (WEXITSTATUS(status)) {
        case 0:
            return PAM_SUCCESS;
        case 1:
            return PAM_IGNORE;
        case 5:
            return PAM_AUTH_ERR;
        default:
            return PAM_SYSTEM_ERR;
        }
    }

    return PAM_SYSTEM_ERR;
}

PAM_EXTERN int
pam_sm_setcred(pam_handle_t *pamh, int flags, int argc, const char **argv)
{
    (void)pamh;
    (void)flags;
    (void)argc;
    (void)argv;
    return PAM_SUCCESS;
}
