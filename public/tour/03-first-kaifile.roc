# This project's Kai configuration. Every setting has an example in
# https://github.com/thebrandonlucas/kai/tree/master/examples
app [kaifile] {
	pf: platform "https://github.com/thebrandonlucas/kai/releases/download/v0.0.11/65bk6qdahqxn1mm6LR6Hkyw8dSdoeRZGwjNSuiPfvguP.tar.zst",
	std: "https://github.com/thebrandonlucas/kai/releases/download/v0.0.11/std-6Jw5GxNCFkpnvBbnFmQg4KAVEn5bAfEveSZfDSzTDs42.tar.zst",
}

import std.Std

kaifile = Std.kaifile([
	Name("cow"),
	Systems(["x86_64-linux", "aarch64-linux", "aarch64-darwin"]),
	Environment("cow", [Tools(["cowsay", "fortune"])]),
	Shell("default", [Use("cow")]),
	Task("wisdom", [Use("cow"), Run(["sh", "-c", "fortune | cowsay"])]),
])
