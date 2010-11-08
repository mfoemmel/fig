package fig

import "bytes"
import "strings"

type Settings struct {
	repos []RepoEntry
}

type RepoEntry struct {
	alias    string
	location string
}

func NewSettings() *Settings {
	return &Settings{make([]RepoEntry, 0, 100)}
}

func (s *Settings) Load(fs FileSystem) {
	if !fs.Exists(".figsettings") {
		return
	}
	contents, err := ReadFile(fs, ".figsettings")
	if err != nil {
		panic(err)
	}
	lines := strings.Split(string(contents), "\n", -1)
	for _, line := range lines {
		parts := strings.Split(line, "=", 2)
		if len(parts) < 2 {
			continue
		}
		pos := len(s.repos)
		s.repos = s.repos[0 : pos+1]
		s.repos[pos] = RepoEntry{parts[0], parts[1]}
	}
}

func (s *Settings) Save(fs FileSystem) {
	buf := bytes.NewBuffer(nil)
	for _, repo := range s.repos {
		buf.Write([]byte(repo.alias))
		buf.Write([]byte("="))
		buf.Write([]byte(repo.location))
		buf.Write([]byte("\n"))
	}
	WriteFile(fs, ".figsettings", buf.Bytes())
}

func (s *Settings) AddRepository(alias string, location string) {
	pos := len(s.repos)
	s.repos = s.repos[0 : pos+1]
	s.repos[pos] = RepoEntry{alias, location}
}
