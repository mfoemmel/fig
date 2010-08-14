include $(GOROOT)/src/Make.$(GOARCH)

TARG=fig
GOFILES=\
	cmd.go\
	cmd_help.go\
	cmd_show.go\
	graph_cycles.go\
	graph_node.go\
	graph_sort.go\
	repos.go\
	repos_file.go\
	repos_mem.go\
	parser.go\
	unparser.go\
	plan.go\
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
