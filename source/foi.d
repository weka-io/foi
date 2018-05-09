/**
 * Fiber Oblivious Invocation
 *
 * This library allows calling code that is unaware of fibers in such a way that it will yield the CPU to other fibers, either
 * native or FOC, when blocking IO is performed.
 */
module foi;

import mecca.lib.exception;
import mecca.reactor;
import mecca.reactor.fls;

/**
  Call oblivious function `F`.

  Returns:
  F's return value
 */
template foiCall(alias F) if( isCallable!F ) {
    alias Ret = ReturnType!F;
    alias Args = Parameters!F;

    Ret foiCall( Args args ) {
        ASSERT!"foiCall called on an already foi fiber"( !foiFiber );
    }
}

private:
alias foiFiber = FiberLocal!(bool, "foiFiber", false);
