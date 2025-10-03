package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"path/filepath"

	"xingzuo/internal/contractgen"
	"xingzuo/internal/registry"
)

func main() {
	out := flag.String("o", "", "output file path for OpenAPI JSON")
	pretty := flag.Bool("pretty", true, "write pretty formatted JSON")
	prompt := flag.String("prompt", "", "structured prompt JSON file to generate OpenAPI/JSON Schema")
	jsonschemaOut := flag.String("jsonschema", "", "optional output file path for JSON Schema extracted from prompt")
	flag.Parse()

	if *out == "" {
		fmt.Fprintln(os.Stderr, "usage: go run ./cmd/openapi -o <output.json> [--pretty=true] [-prompt prompt.json] [-jsonschema schema.json]")
		os.Exit(2)
	}

	var spec map[string]interface{}

	// If prompt is provided, generate from prompt; otherwise use registry builder
	if *prompt != "" {
		pm := map[string]interface{}{}
		pb, err := os.ReadFile(*prompt)
		if err != nil {
			fmt.Fprintf(os.Stderr, "failed to read prompt: %v\n", err)
			os.Exit(1)
		}
		if err := json.Unmarshal(pb, &pm); err != nil {
			fmt.Fprintf(os.Stderr, "invalid prompt json: %v\n", err)
			os.Exit(1)
		}
		spec = contractgen.GenerateOpenAPI(pm)

		// Optionally write JSON Schema extracted from prompt
		if *jsonschemaOut != "" {
			schema := contractgen.GenerateJSONSchema(pm)
			var sb []byte
			if *pretty {
				sb, err = json.MarshalIndent(schema, "", "  ")
			} else {
				sb, err = json.Marshal(schema)
			}
			if err != nil {
				fmt.Fprintf(os.Stderr, "failed to marshal jsonschema: %v\n", err)
				os.Exit(1)
			}
			if err := os.MkdirAll(filepath.Dir(*jsonschemaOut), 0o755); err != nil {
				fmt.Fprintf(os.Stderr, "failed to create jsonschema dir: %v\n", err)
				os.Exit(1)
			}
			if err := os.WriteFile(*jsonschemaOut, sb, 0o644); err != nil {
				fmt.Fprintf(os.Stderr, "failed to write jsonschema file: %v\n", err)
				os.Exit(1)
			}
			fmt.Printf("JSON Schema written to %s (%d bytes)\n", *jsonschemaOut, len(sb))
		}
	} else {
		spec = registry.BuildOpenAPISpec()
	}

	var data []byte
	var err error
	if *pretty {
		data, err = json.MarshalIndent(spec, "", "  ")
	} else {
		data, err = json.Marshal(spec)
	}
	if err != nil {
		fmt.Fprintf(os.Stderr, "failed to marshal spec: %v\n", err)
		os.Exit(1)
	}

	if err := os.MkdirAll(filepath.Dir(*out), 0o755); err != nil {
		fmt.Fprintf(os.Stderr, "failed to create output dir: %v\n", err)
		os.Exit(1)
	}

	if err := os.WriteFile(*out, data, 0o644); err != nil {
		fmt.Fprintf(os.Stderr, "failed to write file: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("OpenAPI spec written to %s (%d bytes)\n", *out, len(data))
}
