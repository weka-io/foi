/**
 * Fiber Oblivious Invocation
 *
 * This library allows calling code that is unaware of fibers in such a way that it will yield the CPU to other fibers, either
 * native or FOC, when blocking IO is performed.
 */
module foi;

import mecca.reactor;
import mecca.fls;

/**
  Call oblivious function `F`.

  Returns:
  F's return value
 */
template foiCall(alias F) if( isCallable!F ) {

}
