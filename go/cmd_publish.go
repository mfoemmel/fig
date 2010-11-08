package fig

import "archive/tar"
import "compress/gzip"
//import "io"
import "io/ioutil"
import "os"

type PublishCommand struct{}

func parsePublishArgs(iter *ArgIterator) (Command, os.Error) {
	// todo check for extra args
	return &PublishCommand{}, nil
}

func (cmd *PublishCommand) Execute(ctx *Context) int {
	path := "package.fig"

	if !ctx.fs.Exists(path) {
		ctx.err.Write([]byte("File not found: " + path + "\n"))
		return 1
	}

	localPackage, err := ReadFile(ctx.fs, path)
	if err != nil {
		panic(err)
	}

	pkg, err2 := NewParser(path, localPackage).ParsePackage("", "")
	if err2 != nil {
		ctx.err.Write([]byte(err2.String()))
		return 1
	}

	if pkg.PackageName == "" {
		ctx.err.Write([]byte("missing 'package' statement"))
		return 1
	}

	w, err := ctx.repo.NewPackageWriter(pkg.PackageName, pkg.VersionName)
	if err != nil {
		ctx.err.Write([]byte(err.String() + "\n"))
		return 1
	}
	w.WriteStatements(pkg.Statements)

	// Set up archive stream
	out /*, err*/ := w.OpenArchive()
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
			//archive.Flush()
			//io.Copy(archive, in)
		}
		if config, ok := stmt.(*ConfigBlock); ok {
			for _, configStmt := range config.Config.Statements {
				if modStmt, ok := configStmt.(*ModifierStatement); ok {
					if pathStmt, ok := modStmt.Modifier.(*PathModifier); ok {
						size, err := ctx.fs.Size(pathStmt.Value)
						in, err := ctx.fs.OpenReader(pathStmt.Value)
						if err != nil {
							panic(err)
						}

						tmp, _ := ioutil.ReadAll(in)

						header := &tar.Header{}
						header.Name = pathStmt.Value
						header.Size = size
						archive.WriteHeader(header)
						if err != nil {
							panic(err)
						}
						archive.Write(tmp)
						//archive.Flush()
						//io.Copy(archive, in)
					}
				}
			}
		}
	}
	//NewParser("package.fig", ctx.localPackage)
	//w := ctx.repo.NewPackageWriter()
	return 0
}
