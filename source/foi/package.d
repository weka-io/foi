/**
 * Fiber Oblivious Invocation
 *
 * This library allows calling code that is unaware of fibers in such a way that it will yield the CPU to other fibers, either
 * native or FOC, when blocking IO is performed.
 */
module foi;

import core.stdc.errno;
import std.traits;

import mecca.lib.exception;
import mecca.platform.linux;
import mecca.reactor;
import mecca.reactor.fls;
import mecca.reactor.io.fd;

/**
  Call oblivious function `F`.

  Returns:
  F's return value
 */
template foiCall(alias F) {
    static assert( isCallable!F, "Alias " ~ F.stringof ~ " is not a callable function");

    alias Ret = ReturnType!F;
    alias Args = Parameters!F;

    Ret foiCall( Args args ) {
        ASSERT!"foiCall called on an already foi fiber"( !foiFiber );

        foiFiber = true;
        scope(exit) foiFiber = false;

        return F(args);
    }
}

private:
alias foiFiber = FiberLocal!(bool, "foiFiber", false);

struct FdState {
    ReactorFD fd;
}

FdState[int] obliviousFds;

void registerFd(int fdNumber) {
    ASSERT!"fd %s registered twice"(fdNumber !in obliviousFds, fdNumber);
    auto fdState = &obliviousFds[fdNumber];
    fdState.fd = ReactorFD(fdNumber);
}

bool deregisterFd(int fdNumber) {
    auto fdState = fdNumber in obliviousFds;
    if( fdState is null )
        return false;

    fdState.fd.close();
    obliviousFds.remove(fdNumber);
    return true;
}

extern(C) int socket(int domain, int type, int protocol) {
    import std.stdio;
    int ret = next_socket(domain, type, protocol);

    if( isReactorThread && foiFiber && ret>=0 ) {
        auto savedErrno = errno;
        registerFd(ret);
        errno = savedErrno;
    }

    return ret;
}
mixin InterceptCall!socket;

extern(C) int close(int fd) {
    if( !isReactorThread || !foiFiber ) {
        return next_close(fd);
    }

    try {
        if( !deregisterFd(fd) ) {
            return next_close(fd);
        }

        return 0;
    } catch(ErrnoException ex) {
        errno = ex.errno;
        return -1;
    }
}
mixin InterceptCall!close;
