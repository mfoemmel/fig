package fig

import "io"
import "os"

type DepsCommand struct {
	descriptor Descriptor
}

func parseDepsArgs(iter *ArgIterator) (Command, os.Error) {
        if !iter.Next() {
                return nil, os.NewError("Please specify a descriptor (e.g. foo/1.2.3)")
        }
	desc, err := NewParser("<arg>",[]byte(iter.Get())).descriptor()
	if err != nil {
		return nil, err
	}
        return &DepsCommand{desc}, nil
}

func (cmd *DepsCommand) Execute(repo Repository, out io.Writer) {
	pkg, err := ReadPackage(repo, cmd.descriptor.PackageName, cmd.descriptor.VersionName)
	if err != nil {
		panic(err)
	}
	config := pkg.FindConfig("default")
	if config == nil {
		panic("config not found")
	}
	for _, desc := range config.FindIncludeDescriptors() {
		out.Write([]byte(desc.String() + "\n"))
	}
}
