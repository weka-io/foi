import std.algorithm, std.net.curl, std.string, std.datetime, std.range, std.stdio;
import std.file : remove;

import mecca.log;
import mecca.reactor;

import foi;

// try your own urls
immutable urls = [
	"https://mirror.yandex.ru/debian/doc/FAQ/debian-faq.en.html.tar.gz",
	"https://mirror.yandex.ru/debian/doc/FAQ/debian-faq.en.pdf.gz",
	"https://mirror.yandex.ru/debian/doc/FAQ/debian-faq.en.ps.gz",
	"https://mirror.yandex.ru/debian/doc/FAQ/debian-faq.en.txt.gz",
	"http://www.v6.mirror.yandex.ru/fedora/linux/development/rawhide/Everything/x86_64/os/Packages/a/accumulo-monitor-1.8.1-9.fc28.noarch.rpm",
	"http://www.v6.mirror.yandex.ru/fedora/linux/development/rawhide/Everything/x86_64/os/Packages/a/accumulo-native-1.8.1-9.fc28.x86_64.rpm",
	"http://www.v6.mirror.yandex.ru/fedora/linux/development/rawhide/Everything/x86_64/os/Packages/a/accumulo-server-base-1.8.1-9.fc28.noarch.rpm",
	"http://www.v6.mirror.yandex.ru/fedora/linux/development/rawhide/Everything/x86_64/os/Packages/a/accumulo-shell-1.8.1-9.fc28.x86_64.rpm",
	"http://www.v6.mirror.yandex.ru/fedora/linux/development/rawhide/Everything/x86_64/os/Packages/a/accumulo-tracer-1.8.1-9.fc28.noarch.rpm",
	"http://www.v6.mirror.yandex.ru/fedora/linux/development/rawhide/Everything/x86_64/os/Packages/a/accumulo-tserver-1.8.1-9.fc28.noarch.rpm",
	"http://www.v6.mirror.yandex.ru/fedora/linux/development/rawhide/Everything/x86_64/os/Packages/a/acegisecurity-1.0.7-9.fc28.noarch.rpm"
];

int main(){
    theReactor.setup();

    theReactor.spawnFiber!testMain();

    return theReactor.start();
}

void testMain() {
	StopWatch sw;
	sw.reset();
        version(later) {
        INFO!"Starting sequential test"();
	sw.start();
	foreach(url; urls) {
            // Sequential
            download(url, url.split('/').back);
	}
	sw.stop();
	writefln("Sequentially: %s ms", sw.peek.msecs);
        INFO!"Sequential test done"();
	
	foreach(url; urls) {
		remove(url.split('/').back);
	}
        }

        /+
	sw.reset();
	sw.start();
	urls
		.map!(url => threadDownload(url, url.split('/').back))
		.array
		.each!(t => t.join());
	sw.stop();
	writefln("Threads: %s ms", sw.peek.total!"msecs");
	
	foreach(url; urls) {
		remove(url.split('/').back);
	}

        +/

        INFO!"Starting reactor test"();

        import mecca.reactor.sync.barrier;
        Barrier ending;
	static void spawnDownload(Barrier* ending, string url, string file) {
            foiCall!(download!())(url, file, AutoProtocol());
            ending.markDone();
	}

	sw.reset();
	sw.start();
	foreach(url; urls) {
            theReactor.spawnFiber!spawnDownload(&ending, url, url.split('/').back);
            ending.addWaiter();
	}
        ending.waitAll();
	sw.stop();
	writefln("Concurrently: %s ms", sw.peek.msecs);

        theReactor.stop();
}
