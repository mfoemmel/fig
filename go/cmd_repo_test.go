package fig

import "testing"

func TestRepoArgs(t *testing.T) {
	checkArgs(t, "fig repo add local /home/foo/fig", repoadd("local","/home/foo/fig"))
	checkArgs(t, "fig repo list", repolist())
}

func TestRepoAdd(t *testing.T) {
	ctx, out, _ := NewTestContext()
	repoadd("local", "/home/foo/fig").Execute(ctx)
	repolist().Execute(ctx)
	expected := "local\t/home/foo/fig\n"
	actual := string(out.Bytes())
	if actual != expected {
		t.Fatalf("expected: %s, got: %s", expected, actual)
	}
}

func repoadd(alias string, location string) Command {
	return &RepoAddCommand{alias, location}
}

func repolist() Command {
	return &RepoListCommand{}
}
