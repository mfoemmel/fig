package fig

import "testing"

func TestWildcardNoFiles(t *testing.T) {
	fs := NewMemoryFileSystem()
	files := findFiles(fs, "", "foo")
	checkFileList(t, []string{}, files)
}

func TestWildcardNoMatch(t *testing.T) {
	fs := NewMemoryFileSystem()
	WriteFile(fs, "foo", []byte("foo contents"))
	files := findFiles(fs, "", "xyzzy")
	checkFileList(t, []string{}, files)
}

func TestWildcardSimpleMatchOne(t *testing.T) {
	fs := NewMemoryFileSystem()
	WriteFile(fs, "foo", []byte("foo contents"))
	files := findFiles(fs, "", "foo")
	checkFileList(t, []string{"foo"}, files)
}

func TestWildcardQuestionMark(t *testing.T) {
	fs := NewMemoryFileSystem()
	WriteFile(fs, "foo", []byte("foo contents"))
	WriteFile(fs, "bar", []byte("bar contents"))
	WriteFile(fs, "baz", []byte("baz contents"))
	files := findFiles(fs, "", "ba?")
	checkFileList(t, []string{"bar","baz"}, files)
}

func TestWildcardStar(t *testing.T) {
	fs := NewMemoryFileSystem()
	WriteFile(fs, "foo", []byte("foo contents"))
	WriteFile(fs, "bar", []byte("bar contents"))
	WriteFile(fs, "baz", []byte("baz contents"))
	files := findFiles(fs, "", "b*")
	checkFileList(t, []string{"bar","baz"}, files)
}

func TestWildcardSubDir(t *testing.T) {
	fs := NewMemoryFileSystem()
	fs.Mkdir("src")
	WriteFile(fs, "src/foo", []byte("foo contents"))
	WriteFile(fs, "src/bar", []byte("bar contents"))
	WriteFile(fs, "src/baz", []byte("baz contents"))
	files := findFiles(fs, "", "src/b*")
	checkFileList(t, []string{"src/bar","src/baz"}, files)
}

func TestWildcardBaseDir(t *testing.T) {
	fs := NewMemoryFileSystem()
	fs.Mkdir("src")
	WriteFile(fs, "src/foo", []byte("foo contents"))
	WriteFile(fs, "src/bar", []byte("bar contents"))
	WriteFile(fs, "src/baz", []byte("baz contents"))
	files := findFiles(fs, "src/", "b*")
	checkFileList(t, []string{"bar","baz"}, files)
}

func TestWildcardDoubleStar(t *testing.T) {
	fs := NewMemoryFileSystem()
	fs.Mkdir("src")
	WriteFile(fs, "src/foo", []byte("foo contents"))
	WriteFile(fs, "src/main/bar", []byte("bar contents"))
	WriteFile(fs, "src/main/go/baz", []byte("baz contents"))
	files := findFiles(fs, "src/", "**/b*")
	checkFileList(t, []string{"src/main/bar","src/main/go/baz"}, files)
}

func checkFileList(t *testing.T, expectedList []string, actualList []string) {
	if len(expectedList) != len(actualList) {
		t.Fatalf("expected: %v, got: %v", expectedList, actualList)
	}
	for i, expected := range expectedList {
		actual := actualList[i]
		if expected != actual {
			t.Fatalf("expected: %v, got: %v", expectedList, actualList)
		}
	}
}