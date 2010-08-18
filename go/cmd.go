package fig

import "fmt"
import "io"
import "os"

type CommandHandler interface {
	Help()
//	List()
//	Publish(packageName PackageName, versionName VersionName)
//	Run(command []string, modifiers []Modifier)
//	Retrieve()
}

type Command interface {
	Execute(Repository, io.Writer)
}

func (cmd *HelpCommand) Accept(handler CommandHandler) {
	handler.Help()
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
	case "help":
		return &HelpCommand{}, nil
	case "list":
		return parseList(iter)
	case "show":
		return parseShow(iter)
/*	case "publish":
		return parsePublish(iter)
	case "retrieve":
		return parseRetrieve(iter)
	case "run":
		return parseRun(iter)*/
	}

	return nil, os.NewError(fmt.Sprintf("Unknown command: %s", args[1]))
}

func parseList(iter *ArgIterator) (Command, os.Error) {
        if iter.Next() {
                return nil, os.NewError(fmt.Sprintf("Unexpected argument: %s", iter.Get()))
        }
        return &ListCommand{}, nil
}

func parseShow(iter *ArgIterator) (Command, os.Error) {
        if !iter.Next() {
                return nil, os.NewError("Please specify a package and version (e.g. foo/1.2.3)")
        }
	desc, err := NewParser("<arg>",[]byte(iter.Get())).descriptor()
	if err != nil {
		return nil, err
	}
	if desc.PackageName == "" || desc.VersionName == "" {
                return nil, os.NewError("Please specify a package and version (e.g. foo/1.2.3)")
	}
        return &ShowCommand{desc.PackageName, desc.VersionName}, nil
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
