package fig

import "os"

type PublishCommand struct {
}

func parsePublishArgs(iter *ArgIterator) (Command, os.Error) {
	// todo check for extra args
        return &PublishCommand{}, nil
}

func (cmd *PublishCommand) Execute(ctx *Context) {
	path := "package.fig"
	localPackage, err := ReadFile(ctx.fs, path)
	if err != nil {
		panic(err)
	}
	pkg, err2 := NewParser(path, localPackage).ParsePackage("","")
	if err2 != nil {
		panic(err2)
	}
	WritePackage(ctx.repo, pkg)
//	NewParser("package.fig", ctx.localPackage)
//	w := ctx.repo.NewPackageWriter()
}
