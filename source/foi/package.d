/**
 * Fiber Oblivious Invocation
 *
 * This library allows calling code that is unaware of fibers in such a way that it will yield the CPU to other fibers, either
 * native or FOC, when blocking IO is performed.
 */
module foi;

import std.traits;

import mecca.log;
import mecca.lib.exception;
import mecca.lib.typedid;
import mecca.reactor.fls;

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
        FoiFiberState* state = &fiberState();
        ASSERT!"foiCall called on an already foi fiber"( !state.foiFiber );


        state.foiFiber = true;
        scope(exit) state.foiFiber = false;
        state.taskId = taskAllocator.getNext();
        scope(exit) state.taskId = TaskId.invalid;

        DEBUG!("Started FOI " ~ fullyQualifiedName!F ~" %s")(state.taskId);
        scope(success) DEBUG!"Finished FOI %s"(state.taskId);

        return F(args);
    }
}

package:
alias TaskId = TypedIdentifier!("TaskId", uint, uint.max, uint.max);

struct FoiFiberState {
    bool foiFiber;
    bool inHandler;
    TaskId taskId;
}

alias fiberState = FiberLocal!(FoiFiberState, "foiFiberState");

private TaskId.Allocator taskAllocator;
