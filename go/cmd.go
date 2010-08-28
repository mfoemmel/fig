package fig

import "fmt"
import "io"
import "os"

type Context struct {
	repo Repository
	space Workspace
	out io.Writer
	err io.Writer
}

type Command interface {
	Execute(ctx *Context)
}

func ParseArgs(args []string) (Command, os.Error) {
	iter := &ArgIterator{args, -1}

	if !iter.Next() {
		panic("Missing executable name")
	}

	if !iter.Next() {
		return nil, os.NewError("Please specify a command to run")
	}

	switch iter.Get() {
	case "deps":
		return parseDepsArgs(iter)
	case "help":
		return &HelpCommand{}, nil
	case "install":
		return parseInstallArgs(iter)
	case "list":
		return parseListArgs(iter)
	case "show":
		return parseShowArgs(iter)
	case "tree":
		return parseTreeArgs(iter)
/*	case "publish":
		return parsePublish(iter)
	case "retrieve":
		return parseRetrieve(iter)
	case "run":
		return parseRun(iter)*/
	}

	return nil, os.NewError(fmt.Sprintf("Unknown command: %s", args[1]))
}


// Helper class for iterating thru command line args

type ArgIterator struct {
	args []string
	pos  int
}

func (iter *ArgIterator) Next() bool {
	if iter.pos == len(iter.args)-1 {
		return false
	}
	iter.pos++
	return true
}

func (iter *ArgIterator) Get() string {
	return iter.args[iter.pos]
}

func (iter *ArgIterator) Rest() []string {
	return iter.args[iter.pos:]
}
