package fig

import "archive/tar"
import "compress/gzip"
//import "io"
import "io/ioutil"
import "os"

type PublishCommand struct {
}

func parsePublishArgs(iter *ArgIterator) (Command, os.Error) {
	// todo check for extra args
        return &PublishCommand{}, nil
}

func (cmd *PublishCommand) Execute(ctx *Context) int {
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

	// Set up archive stream
	out/*, err*/ := w.OpenArchive()
	defer out.Close()

	zout, err := gzip.NewWriter(out)
	if err != nil {
		panic(err)
	}
	defer zout.Close()

	archive := tar.NewWriter(zout)
	if err != nil {
		panic(err)
	}
	defer archive.Close()
	for _, stmt := range pkg.Statements {
		if res, ok := stmt.(*ResourceStatement); ok {
			size, err := ctx.fs.Size(res.Path)
			in, err := ctx.fs.OpenReader(res.Path)
			if err != nil {
				panic(err)
			}

			tmp, _ := ioutil.ReadAll(in)

			header := &tar.Header{}
			header.Name = res.Path
			header.Size = size
			archive.WriteHeader(header)
			if err != nil {
				panic(err)
			}
			archive.Write(tmp)
//			archive.Flush()
//			io.Copy(archive, in)
		}
	}
//	NewParser("package.fig", ctx.localPackage)
//	w := ctx.repo.NewPackageWriter()
	return 0
}
