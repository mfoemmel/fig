package fig

import "os"

type DepsCommand struct {
	descriptor Descriptor
}

func parseDepsArgs(iter *ArgIterator) (Command, os.Error) {
	if !iter.Next() {
		return nil, os.NewError("Please specify a descriptor (e.g. foo/1.2.3)")
	}
	// todo - parser shouldn't print line/column if "source" arg is empty
	desc, err := NewParser("<arg>", []byte(iter.Get())).descriptor()
	if err != nil {
		return nil, err
	}
	return &DepsCommand{desc}, nil
}

func (cmd *DepsCommand) Execute(ctx *Context) int {
	pkg, err := ReadPackage(ctx.repo, cmd.descriptor.PackageName, cmd.descriptor.VersionName)
	if err != nil {
		panic(err)
	}
	configName := cmd.descriptor.ConfigName
	if configName == "" {
		configName = "default"
	}
	config := pkg.FindConfig(configName)
	if config == nil {
		panic("config not found")
	}
	for _, desc := range config.FindIncludeDescriptors() {
		ctx.out.Write([]byte(desc.String() + "\n"))
	}
	return 0
}
