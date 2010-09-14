include $(GOROOT)/src/Make.inc

TARG=fig
GOFILES=\
	cmd.go\
	cmd_deps.go\
	cmd_help.go\
	cmd_install.go\
	cmd_list.go\
	cmd_publish.go\
	cmd_show.go\
	cmd_tree.go\
	fs.go\
	fs_mem.go\
	graph_cycles.go\
	graph_node.go\
	graph_sort.go\
	repos.go\
	repos_file.go\
	repos_mem.go\
	parser.go\
	unparser.go\
	plan.go\
	workspace.go\
	workspace_file.go\
	workspace_mem.go\
	backtrace.go\
	builder.go\
	config.go\
	descriptor.go\
	modifiers.go\
	package.go\

fig: main.$(O) _obj/fig.a
	$(LD) -o fig -L _obj main.$(O) 

main.$(O): main.go _obj/fig.a
	$(GC) -I _obj main.go

func_test: fig func_test.go
	$(GC) func_test.go
	$(LD) func_test.$(O) 
	./6.out
	
include $(GOROOT)/src/Make.pkg
