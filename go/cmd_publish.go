package fig

import "io"
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
	
	w := ctx.repo.NewPackageWriter(pkg.PackageName, pkg.VersionName)
	w.WriteStatements(pkg.Statements)
	for _, stmt := range pkg.Statements {
		if res, ok := stmt.(*ResourceStatement); ok {
			out/*, err*/ := w.OpenArchive()
			in, err := ctx.fs.OpenReader(res.Path)
			if err != nil {
				panic(err)
			}
			io.Copy(out, in)
		}
	}
//	NewParser("package.fig", ctx.localPackage)
//	w := ctx.repo.NewPackageWriter()
}
