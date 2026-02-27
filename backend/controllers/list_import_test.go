package controllers

import (
	"archive/zip"
	"bytes"
	"fmt"
	"movder-backend/services"
	"strings"
	"testing"
	"time"
)

func TestParseSingleCSVPayload_MetadataAndItems(t *testing.T) {
	csvText := strings.Join([]string{
		"Date,Name,Tags,URL,Description",
		"2024-11-25,Top Sci-Fi,,,Harika liste",
		"",
		"Position,Name,Year,URL,Description",
		"1,Interstellar,2014,https://letterboxd.com/film/interstellar/,",
		"2,Inception,2010,https://letterboxd.com/film/inception/,",
	}, "\n")

	list, warnings, err := parseSingleCSVPayload([]byte(csvText), "list.csv")
	if err != nil {
		t.Fatalf("unexpected parse error: %v", err)
	}
	if len(warnings) != 0 {
		t.Fatalf("expected no warnings, got: %v", warnings)
	}
	if list.Name != "Top Sci-Fi" {
		t.Fatalf("unexpected list name: %s", list.Name)
	}
	if list.Description != "Harika liste" {
		t.Fatalf("unexpected description: %s", list.Description)
	}
	if len(list.Items) != 2 {
		t.Fatalf("expected 2 items, got %d", len(list.Items))
	}
	if list.Items[0].Position != 1 {
		t.Fatalf("expected first position=1, got %d", list.Items[0].Position)
	}
}

func TestParseSingleCSVPayload_MissingMetadata(t *testing.T) {
	csvText := "Position,Name,Year,URL\n1,Interstellar,2014,https://letterboxd.com/film/interstellar/"

	_, _, err := parseSingleCSVPayload([]byte(csvText), "broken.csv")
	if err == nil {
		t.Fatal("expected metadata error")
	}
}

func TestParseLetterboxdDate_Fallback(t *testing.T) {
	before := time.Now().Add(-2 * time.Second)
	parsed := parseLetterboxdDate("not-a-date")
	after := time.Now().Add(2 * time.Second)

	if parsed.Before(before) || parsed.After(after) {
		t.Fatalf("fallback date should be near now, got %v", parsed)
	}
}

func TestParseZipPayload_ZipSlipIgnoredAndListsPriority(t *testing.T) {
	goodCSV := strings.Join([]string{
		"Date,Name,Tags,URL,Description",
		"2024-11-25,Good List,,,ok",
		"",
		"Position,Name,Year,URL,Description",
		"1,Interstellar,2014,https://letterboxd.com/film/interstellar/,",
	}, "\n")
	otherCSV := strings.Join([]string{
		"Date,Name,Tags,URL,Description",
		"2024-11-25,Other List,,,ok",
	}, "\n")

	zipBytes := makeZip(t, map[string]string{
		"../evil.csv":        goodCSV,
		"lists/selected.csv": goodCSV,
		"backup/ignored.csv": otherCSV,
		"notes/readme.txt":   "x",
	})

	lists, _, err := parseZipPayload(zipBytes)
	if err != nil {
		t.Fatalf("unexpected zip parse error: %v", err)
	}
	if len(lists) != 1 {
		t.Fatalf("expected only lists/*.csv to be prioritized, got %d", len(lists))
	}
	if lists[0].Name != "Good List" {
		t.Fatalf("unexpected parsed list name: %s", lists[0].Name)
	}
}

func TestParseZipPayload_MaxCSVFileCount(t *testing.T) {
	files := map[string]string{}
	for i := 0; i < maxZipCSVFiles+1; i++ {
		files[fmt.Sprintf("lists/%d.csv", i)] = "Date,Name,Tags,URL,Description\n2024-11-25,L,,,"
	}

	zipBytes := makeZip(t, files)
	_, _, err := parseZipPayload(zipBytes)
	if err == nil {
		t.Fatal("expected CSV file count limit error")
	}
}

func TestMatchTMDBMovie_ConfidenceClassification(t *testing.T) {
	orig := searchMoviesFn
	defer func() { searchMoviesFn = orig }()

	searchMoviesFn = func(query string) (*services.TMDBSearchResponse, error) {
		switch {
		case strings.Contains(strings.ToLower(query), "inception"):
			return &services.TMDBSearchResponse{Results: []services.TMDBMovie{{
				ID:          10,
				Title:       "Inception",
				ReleaseDate: "2010-07-16",
			}}}, nil
		default:
			return &services.TMDBSearchResponse{Results: []services.TMDBMovie{{
				ID:          20,
				Title:       "Unknown Film",
				ReleaseDate: "1991-01-01",
			}}}, nil
		}
	}

	exact := parsedListItem{Name: "Inception", Year: 2010}
	matchTMDBMovie(&exact)
	if exact.Confidence != "exact" || exact.TmdbID == 0 {
		t.Fatalf("expected exact match, got confidence=%s tmdb=%d", exact.Confidence, exact.TmdbID)
	}

	unresolved := parsedListItem{Name: "Totally Different", Year: 2025}
	matchTMDBMovie(&unresolved)
	if unresolved.Confidence != "unresolved" || unresolved.TmdbID != 0 {
		t.Fatalf("expected unresolved, got confidence=%s tmdb=%d", unresolved.Confidence, unresolved.TmdbID)
	}
}

func makeZip(t *testing.T, files map[string]string) []byte {
	t.Helper()
	var buf bytes.Buffer
	zw := zip.NewWriter(&buf)
	for name, content := range files {
		w, err := zw.Create(name)
		if err != nil {
			t.Fatalf("zip create failed for %s: %v", name, err)
		}
		if _, err := w.Write([]byte(content)); err != nil {
			t.Fatalf("zip write failed for %s: %v", name, err)
		}
	}
	if err := zw.Close(); err != nil {
		t.Fatalf("zip close failed: %v", err)
	}
	return buf.Bytes()
}
