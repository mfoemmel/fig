package fig

import "bytes"
import "io"
import "os"

type TreeCommand struct {
	descriptor Descriptor
}

func parseTreeArgs(iter *ArgIterator) (Command, os.Error) {
	if !iter.Next() {
		return nil, os.NewError("Please specify a descriptor (e.g. foo/1.2.3)")
	}
	// todo - parser shouldn't print line/column if "source" arg is empty
	desc, err := NewParser("<arg>", []byte(iter.Get())).descriptor()
	if err != nil {
		return nil, err
	}
	return &TreeCommand{desc}, nil
}

func (cmd *TreeCommand) Execute(ctx *Context) int {
	cmd.visit(ctx.repo, ctx.out, 0, Descriptor{}, cmd.descriptor)
	return 0
}

// todo we should run this through the cycle detector to avoid infinite loops
func (cmd *TreeCommand) visit(repo Repository, out io.Writer, indent int, parent Descriptor, descriptor Descriptor) {
	buf := bytes.NewBuffer(nil)
	for i := 0; i < indent; i++ {
		buf.Write([]byte("  "))
	}
	buf.Write([]byte(descriptor.String()))
	descriptor = descriptor.RelativeTo(parent)
	if descriptor.VersionName == "" {
		buf.Write([]byte("..."))
	}
	buf.Write([]byte("\n"))
	out.Write(buf.Bytes())
	//	os.Stdout.Write(buf.Bytes())
	if descriptor.VersionName == "" {
		return
	}

	pkg, err := ReadPackage(repo, descriptor.PackageName, descriptor.VersionName)
	if err != nil {
		panic(err)
	}
	configName := descriptor.ConfigName
	if configName == "" {
		configName = "default"
	}
	config := pkg.FindConfig(configName)
	if config == nil {
		panic("config not found: " + string(configName) + " " + descriptor.String())
	}
	for _, child := range config.FindIncludeDescriptors() {
		cmd.visit(repo, out, indent+1, descriptor, child)
	}
}
