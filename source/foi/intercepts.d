module foi.intercepts;

import foi;

import core.stdc.errno;
import core.sys.linux.epoll;
import core.sys.posix.poll;
import core.sys.posix.signal;
import core.sys.posix.sys.select;
import core.sys.posix.sys.socket;
import core.sys.posix.sys.types;

import std.traits;

import mecca.log;
import mecca.lib.exception;
import mecca.lib.reflection;
import mecca.platform.linux;
import mecca.reactor;
import mecca.reactor.io.fd;

private:

struct FdState {
    ReactorFD fd;
    TaskId id;
}

FdState[int] obliviousFds;

void registerFd(int fdNumber, TaskId taskId) {
    DBG_ASSERT!"Register FD called not under a recursive lock"( fiberState.inHandler );

    ASSERT!"fd %s registered twice"(fdNumber !in obliviousFds, fdNumber);
    obliviousFds[fdNumber] = FdState( ReactorFD(fdNumber), taskId );
}

bool deregisterFd(int fdNumber) {
    DBG_ASSERT!"Deregister FD called not under a recursive lock"( fiberState.inHandler );

    auto fdState = fdNumber in obliviousFds;
    if( fdState is null )
        return false;

    ASSERT!"Task %s tried to close fd %s opened by task %s"(
            fdState.id == fiberState.taskId, fiberState.taskId, fdNumber, fdState.id);
    fdState.fd.close();
    obliviousFds.remove(fdNumber);
    return true;
}

FdState* lookupFd(int fdNumber, TaskId taskId) nothrow @nogc {
    auto fdState = fdNumber in obliviousFds;
    if( fdState !is null ) {
        ASSERT!"Task %s tried to access fd %s owned by task %s"( fdState.id == taskId, taskId, fdNumber, fdState.id);
    }

    return fdState;
}

struct FiberContext {
    FoiFiberState* state;
    alias state this;

    @disable this(this);
    @disable this();

    this(FoiFiberState* state) nothrow @safe @nogc {
        DBG_ASSERT!"Constructed while already in handler"(!state.inHandler);
        this.state = state;
        state.inHandler = true;
    }

    ~this() nothrow @safe @nogc {
        if( state !is null ) {
            DBG_ASSERT!"Context not protecting recursive invocation"(state.inHandler);
            state.inHandler = false;
        }
    }

    bool opCast(T : bool)() const pure nothrow @safe @nogc {
        return state !is null;
    }
}

FiberContext enterContext() nothrow @trusted @nogc {
    if( !isReactorThread )
        return FiberContext.init;

    FoiFiberState* state = &fiberState();
    if( !state.foiFiber || state.inHandler )
        return FiberContext.init;

    return FiberContext(state);
}

public:

extern(C) int socket(int domain, int type, int protocol) nothrow {
    auto ctx = enterContext();

    import std.stdio;
    int ret = next_socket(domain, type, protocol);

    try {
        if( ret>=0 && ctx ) {
            registerFd(ret, ctx.taskId);
        }
    } catch(ErrnoException ex) {
        next_close(ret);
        as!"nothrow"({errno = ex.errno;});
        ret = -1;
    } catch(Exception ex) {
        assert(false, "registerFd threw an exception that was not ErrnoException");
    }

    return ret;
}
mixin InterceptCall!socket;

extern(C) int close(int fd) nothrow {
    auto ctx = enterContext();
    if( !ctx ) {
        return next_close(fd);
    }

    try {
        if( !deregisterFd(fd) ) {
            int ret = next_close(fd);
            // Since this is not an FD owned by this FOI task, the close should have failed
            ASSERT!"FOI %s closed fd %s which it does not own"( ret<0, ctx.taskId, fd );
            return ret;
        }

        return 0;
    } catch(ErrnoException ex) {
        as!"nothrow"({ errno = ex.errno; });
        return -1;
    } catch(Exception ex) {
        assert(false, "registerFd threw an exception that was not ErrnoException");
    }
}
mixin InterceptCall!close;

extern(C) ssize_t read(int fd, void *buf, size_t count) nothrow {
    auto ctx = enterContext();
    if( !ctx )
        return next_read(fd, buf, count);

    assert(false, "read system call not yet supported for foi fibers");
}
mixin InterceptCall!read;

extern(C) ssize_t write(int fd, const void *buf, size_t count) nothrow {
    auto ctx = enterContext();
    if( !ctx )
        return next_write(fd, buf, count);

    assert(false, "write system call not yet supported for foi fibers");
}
mixin InterceptCall!write;

extern(C) ssize_t accept(int sockfd, sockaddr *addr, socklen_t *addrlen) nothrow {
    auto ctx = enterContext();
    if( !ctx )
        return next_accept(sockfd, addr, addrlen);

    assert(false, "accept system call not yet supported for foi fibers");
}
mixin InterceptCall!accept;

extern(C) ssize_t accept4(int sockfd, sockaddr *addr, socklen_t *addrlen, int flags) nothrow {
    auto ctx = enterContext();
    if( !ctx )
        return next_accept4(sockfd, addr, addrlen, flags);

    assert(false, "accept4 system call not yet supported for foi fibers");
}
mixin InterceptCall!accept4;

extern(C) ssize_t connect(int sockfd, const sockaddr *addr, socklen_t *addrlen) nothrow {
    auto ctx = enterContext();
    if( !ctx )
        return next_connect(sockfd, addr, addrlen);

    assert(false, "connect system call not yet supported for foi fibers");
}
mixin InterceptCall!connect;

extern(C) ssize_t sendto(int sockfd, const void *buf, size_t len, int flags, const sockaddr *dest_addr, socklen_t addrlen) nothrow
{
    auto ctx = enterContext();
    if( !ctx )
        return next_sendto(sockfd, buf, len, flags, dest_addr, addrlen);

    assert(false, "sendto system call not yet supported for foi fibers");
}
mixin InterceptCall!sendto;

extern(C) size_t recv(int sockfd, void *buf, size_t len, int flags) nothrow {
    auto ctx = enterContext();
    if( !ctx )
        return next_recv(sockfd, buf, len, flags);

    assert(false, "recv system call not yet supported for foi fibers");
}
mixin InterceptCall!recv;

extern(C) ssize_t recvfrom(int sockfd, void *buf, size_t len, int flags, sockaddr *src_addr, ssize_t* addrlen) nothrow
{
    auto ctx = enterContext();
    if( !ctx )
        return next_recvfrom(sockfd, buf, len, flags, src_addr, addrlen);

    assert(false, "recvfrom system call not yet supported for foi fibers");
}
mixin InterceptCall!recvfrom;

extern(C) ssize_t poll(pollfd *fds, nfds_t nfds, int timeout) nothrow {
    auto ctx = enterContext();
    if( !ctx )
        return next_poll(fds, nfds, timeout);

    assert(false, "poll system call not yet supported for foi fibers");
}
mixin InterceptCall!poll;

extern(C) ssize_t ppoll(pollfd *fds, nfds_t nfds, const timespec* tmo_p, const sigset_t* sigmask) nothrow {
    auto ctx = enterContext();
    if( !ctx )
        return next_ppoll(fds, nfds, tmo_p, sigmask);

    assert(false, "ppoll system call not yet supported for foi fibers");
}
mixin InterceptCall!ppoll;

extern(C) int select(int nfds, fd_set* readfds, fd_set* writefds, fd_set* exceptfds, timeval* timeout) nothrow {
    auto ctx = enterContext();
    if( !ctx )
        return next_select(nfds, readfds, writefds, exceptfds, timeout);

    assert(false, "select system call not yet supported for foi fibers");
}
mixin InterceptCall!select;

extern(C) int pselect(
        int nfds, fd_set* readfds, fd_set* writefds, fd_set* exceptfds, const timespec* timeout, const sigset_t sigmask) nothrow
{
    auto ctx = enterContext();
    if( !ctx )
        return next_pselect(nfds, readfds, writefds, exceptfds, timeout, sigmask);

    assert(false, "select system call not yet supported for foi fibers");
}
mixin InterceptCall!pselect;

extern(C) int open(const char* pathname, int flags, mode_t mode) nothrow {
    auto ctx = enterContext();
    if( !ctx )
        return next_open(pathname, flags, mode);

    assert(false, "open system call not yet supported for foi fibers");
}
mixin InterceptCall!open;

extern(C) int openat(int dirfd, const char* pathname, int flags, mode_t mode) nothrow {
    auto ctx = enterContext();
    if( !ctx )
        return next_openat(dirfd, pathname, flags, mode);

    assert(false, "openat system call not yet supported for foi fibers");
}
mixin InterceptCall!openat;

extern(C) int epoll_wait(int epfd, epoll_event* events, int maxevents, int timeout) nothrow {
    auto ctx = enterContext();
    if( !ctx )
        return next_epoll_wait(epfd, events, maxevents, timeout);

    assert(false, "epoll_wait system call not yet supported for foi fibers");
}
mixin InterceptCall!epoll_wait;

extern(C) int epoll_pwait(int epfd, epoll_event* events, int maxevents, int timeout, const sigset_t* sigmask) nothrow {
    auto ctx = enterContext();
    if( !ctx )
        return next_epoll_pwait(epfd, events, maxevents, timeout, sigmask);

    assert(false, "epoll_pwait system call not yet supported for foi fibers");
}
mixin InterceptCall!epoll_pwait;

extern(C) int dup(int oldfd) nothrow {
    auto ctx = enterContext();
    if( !ctx )
        return next_dup(oldfd);

    assert(false, "dup system call not yet supported for foi fibers");
}
mixin InterceptCall!dup;

extern(C) int dup2(int oldfd, int newfd) nothrow {
    auto ctx = enterContext();
    if( !ctx )
        return next_dup2(oldfd, newfd);

    assert(false, "dup2 system call not yet supported for foi fibers");
}
mixin InterceptCall!dup2;

extern(C) int dup3(int oldfd, int newfd, int flags) nothrow {
    auto ctx = enterContext();
    if( !ctx )
        return next_dup3(oldfd, newfd, flags);

    assert(false, "dup3 system call not yet supported for foi fibers");
}
mixin InterceptCall!dup3;

// TODO: creat(?)
