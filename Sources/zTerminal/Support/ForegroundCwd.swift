import Foundation
import Darwin

/// Fallback CWD resolution when OSC 7 is unavailable.
///
/// Resolves the working directory of the PTY's *foreground* process group
/// (via `tcgetpgrp` on the master fd), rather than the shell's own pid, so it
/// reflects `cd` performed by a foreground program. Returns nil when the query
/// is denied or unavailable — callers keep the last-known CWD in that case.
enum ForegroundCwd {

    /// The foreground process-group id for a tty file descriptor, or nil.
    static func foregroundPGID(fd: Int32) -> pid_t? {
        let pg = tcgetpgrp(fd)
        return pg > 0 ? pg : nil
    }

    /// The executable/command name for a process id via proc_name, or nil.
    /// Returns just the short command name (e.g. "npm", "vim", "node").
    static func processName(pid: pid_t) -> String? {
        var buf = [CChar](repeating: 0, count: 2 * Int(MAXCOMLEN) + 1)
        let n = proc_name(pid, &buf, UInt32(buf.count))
        guard n > 0 else { return nil }
        let name = String(cString: buf)
        return name.isEmpty ? nil : name
    }

    /// The current working directory of a process id via proc_pidinfo, or nil.
    static func workingDirectory(pid: pid_t) -> String? {
        var info = proc_vnodepathinfo()
        let size = Int32(MemoryLayout<proc_vnodepathinfo>.size)
        let ret = proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &info, size)
        guard ret == size else { return nil }
        return withUnsafePointer(to: &info.pvi_cdir.vip_path) { ptr -> String? in
            ptr.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) {
                String(validatingUTF8: $0)
            }
        }
    }

    /// Best-effort CWD for the foreground of a tty; falls back to the shell pid.
    static func resolve(ttyFD: Int32, shellPID: pid_t) -> String? {
        if let pg = foregroundPGID(fd: ttyFD), let dir = workingDirectory(pid: pg) {
            return dir
        }
        return workingDirectory(pid: shellPID)
    }
}
