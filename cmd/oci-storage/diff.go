package main

import (
	"encoding/json"
	"fmt"
	"io"
	"os"

	"github.com/containers/storage/pkg/archive"
	"github.com/containers/storage/pkg/mflag"
	"github.com/containers/storage/storage"
)

func changes(flags *mflag.FlagSet, action string, m storage.Mall, args []string) int {
	if len(args) < 1 {
		return 1
	}
	to := args[0]
	from := ""
	if len(args) >= 2 {
		from = args[1]
	}
	changes, err := m.Changes(to, from)
	if err != nil {
		fmt.Fprintf(os.Stderr, "%v\n", err)
		return 1
	}
	if jsonOutput {
		json.NewEncoder(os.Stdout).Encode(changes)
	} else {
		for _, change := range changes {
			what := "?"
			switch change.Kind {
			case archive.ChangeAdd:
				what = "Add"
			case archive.ChangeModify:
				what = "Modify"
			case archive.ChangeDelete:
				what = "Delete"
			}
			fmt.Printf("%s %q\n", what, change.Path)
		}
	}
	return 0
}

func diff(flags *mflag.FlagSet, action string, m storage.Mall, args []string) int {
	if len(args) < 2 {
		return 1
	}
	to := args[0]
	from := ""
	if len(args) >= 2 {
		from = args[1]
	}
	reader, err := m.Diff(to, from)
	if err != nil {
		fmt.Fprintf(os.Stderr, "%v\n", err)
		return 1
	}
	_, err = io.Copy(os.Stdout, reader)
	if err != nil {
		fmt.Fprintf(os.Stderr, "%v\n", err)
		return 1
	}
	return 0
}

func applyDiff(flags *mflag.FlagSet, action string, m storage.Mall, args []string) int {
	if len(args) < 1 {
		return 1
	}
	_, err := m.ApplyDiff(args[0], os.Stdin)
	if err != nil {
		fmt.Fprintf(os.Stderr, "%v\n", err)
		return 1
	}
	return 0
}

func diffSize(flags *mflag.FlagSet, action string, m storage.Mall, args []string) int {
	if len(args) < 1 {
		return 1
	}
	to := args[0]
	from := ""
	if len(args) >= 2 {
		from = args[1]
	}
	n, err := m.DiffSize(to, from)
	if err != nil {
		fmt.Fprintf(os.Stderr, "%v\n", err)
		return 1
	}
	fmt.Printf("%d\n", n)
	return 0
}

func init() {
	commands = append(commands, command{
		names:       []string{"changes"},
		usage:       "Compare two layers",
		optionsHelp: "[options [...]] layerNameOrID [referenceLayerNameOrID]",
		minArgs:     1,
		maxArgs:     2,
		action:      changes,
		addFlags: func(flags *mflag.FlagSet, cmd *command) {
			flags.BoolVar(&jsonOutput, []string{"-json", "j"}, jsonOutput, "Prefer JSON output")
		},
	})
	commands = append(commands, command{
		names:       []string{"diffsize"},
		usage:       "Compare two layers",
		optionsHelp: "[options [...]] layerNameOrID [referenceLayerNameOrID]",
		minArgs:     1,
		maxArgs:     2,
		action:      diffSize,
	})
	commands = append(commands, command{
		names:       []string{"diff"},
		usage:       "Compare two layers",
		optionsHelp: "[options [...]] layerNameOrID [referenceLayerNameOrID]",
		minArgs:     1,
		maxArgs:     2,
		action:      diff,
	})
	commands = append(commands, command{
		names:       []string{"applydiff"},
		optionsHelp: "[options [...]] layerNameOrID [referenceLayerNameOrID]",
		usage:       "Apply a diff to a layer",
		minArgs:     1,
		maxArgs:     1,
		action:      applyDiff,
	})
}
