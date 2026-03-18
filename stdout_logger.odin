// Redirects stdout and stderr to Android logcat via pipes and reader threads.
// stdout -> LogPriority.DEBUG, stderr -> LogPriority.ERROR.
package android

@require import "core:c"
@require import "core:sys/posix"
@require import "core:c/libc"

when ODIN_PLATFORM_SUBTARGET == .Android {
	@(private="file") logger_stdout_pfd: [2]posix.FD
	@(private="file") logger_stderr_pfd: [2]posix.FD
	@(private="file") logger_stdout_thr: posix.pthread_t
	@(private="file") logger_stderr_thr: posix.pthread_t
	@(private="file") logger_tag: cstring = ODIN_BUILD_PROJECT_NAME

	@(private="file") thread_func_stdout :: proc "c" (_: rawptr) -> rawptr {
		buf: [128]byte
		for {
			rdsz := posix.read(logger_stdout_pfd[0], raw_data(buf[:]), size_of(buf) - 1)
			if rdsz <= 0 do break
			rdsz_int := int(rdsz)
			if rdsz_int > 0 && buf[rdsz_int - 1] == '\n' {
				rdsz_int -= 1
			}
			buf[rdsz_int] = 0
			__android_log_write(LogPriority.DEBUG, logger_tag, cstring(raw_data(buf[:])))
		}
		return nil
	}

	@(private="file") thread_func_stderr :: proc "c" (_: rawptr) -> rawptr {
		buf: [128]byte
		for {
			rdsz := posix.read(logger_stderr_pfd[0], raw_data(buf[:]), size_of(buf) - 1)
			if rdsz <= 0 do break
			rdsz_int := int(rdsz)
			if rdsz_int > 0 && buf[rdsz_int - 1] == '\n' {
				rdsz_int -= 1
			}
			buf[rdsz_int] = 0
			__android_log_write(LogPriority.ERROR, logger_tag, cstring(raw_data(buf[:])))
		}
		return nil
	}
}

// Starts redirecting stdout and stderr to Android logcat (stdout=DEBUG, stderr=ERROR).
// Returns 0 on success, -1 on failure (e.g. pipe or thread creation failed).
// Call once at program startup.
// No-op when not building for Android (returns 0).
start_logger :: proc "contextless" () -> c.int {
	when ODIN_PLATFORM_SUBTARGET == .Android {
		libc.setvbuf(libc.stdout, nil, libc._IOLBF, 0)
		libc.setvbuf(libc.stderr, nil, libc._IONBF, 0)

		if posix.pipe(&logger_stdout_pfd) != .OK {
			return -1
		}
		if posix.pipe(&logger_stderr_pfd) != .OK {
			return -1
		}
		posix.dup2(logger_stdout_pfd[1], posix.FD(1))
		posix.dup2(logger_stderr_pfd[1], posix.FD(2))

		if posix.pthread_create(&logger_stdout_thr, nil, thread_func_stdout, nil) != nil {
			return -1
		}
		if posix.pthread_create(&logger_stderr_thr, nil, thread_func_stderr, nil) != nil {
			return -1
		}
		posix.pthread_detach(logger_stdout_thr)
		posix.pthread_detach(logger_stderr_thr)
	}
	return 0
}
