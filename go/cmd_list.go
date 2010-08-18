package fig

import "fmt"
import "io"
import "os"

type ListCommand struct {
}

func parseListArgs(iter *ArgIterator) (Command, os.Error) {
        if iter.Next() {
                return nil, os.NewError(fmt.Sprintf("Unexpected argument: %s", iter.Get()))
        }
        return &ListCommand{}, nil
}

func (cmd *ListCommand) Execute(repo Repository, out io.Writer) {
	for pkg := range repo.ListPackages() {
		line := fmt.Sprintf("%s/%s\n", pkg.PackageName, pkg.VersionName)
		out.Write([]byte(line))
	}
}
