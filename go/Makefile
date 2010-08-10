include $(GOROOT)/src/Make.$(GOARCH)

TARG=fig
GOFILES=\
	plan.go\
	cycles.go\
	node.go\
	sort.go\
	file.go\
	mem.go\
	repos.go\
	parser.go\
	unparser.go\
	backtrace.go\
	builder.go\
	config.go\
	descriptor.go\
	modifiers.go\
	package.go\

fig: main.$(O) _obj/fig.a
	$(LD) -L _obj main.$(O)

main.$(O): main.go _obj/fig.a
	$(GC) -I _obj main.go

include $(GOROOT)/src/Make.pkg
