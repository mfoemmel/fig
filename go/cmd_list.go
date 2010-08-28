package fig

import "fmt"
import "os"

type ListCommand struct {
}

func parseListArgs(iter *ArgIterator) (Command, os.Error) {
        if iter.Next() {
                return nil, os.NewError(fmt.Sprintf("Unexpected argument: %s", iter.Get()))
        }
        return &ListCommand{}, nil
}

func (cmd *ListCommand) Execute(ctx *Context) {
	for pkg := range ctx.repo.ListPackages() {
		line := fmt.Sprintf("%s/%s\n", pkg.PackageName, pkg.VersionName)
		ctx.out.Write([]byte(line))
	}
}
