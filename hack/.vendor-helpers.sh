#!/usr/bin/env bash

PROJECT=github.com/containers/storage

# Downloads dependencies into vendor/ directory
mkdir -p vendor

if ! go list github.com/containers/storage/storage &> /dev/null; then
	rm -rf .gopath
	mkdir -p .gopath/src/github.com/containers
	ln -sf ../../../.. .gopath/src/${PROJECT}
	export GOPATH="${PWD}/.gopath:${PWD}/vendor"
fi
export GOPATH="$GOPATH:${PWD}/vendor"

find='find'
if [ "$(go env GOHOSTOS)" = 'windows' ]; then
	find='/usr/bin/find'
fi

clone() {
	local vcs="$1"
	local pkg="$2"
	local rev="$3"
	local url="$4"

	: ${url:=https://$pkg}
	local target="vendor/src/$pkg"

	echo -n "$pkg @ $rev: "

	if [ -d "$target" ]; then
		echo -n 'rm old, '
		rm -rf "$target"
	fi

	echo -n 'clone, '
	case "$vcs" in
		git)
			git clone --quiet --no-checkout "$url" "$target"
			( cd "$target" && git checkout --quiet "$rev" && git reset --quiet --hard "$rev" )
			;;
		hg)
			hg clone --quiet --updaterev "$rev" "$url" "$target"
			;;
	esac

	echo -n 'rm VCS, '
	( cd "$target" && rm -rf .{git,hg} )

	echo -n 'rm vendor, '
	( cd "$target" && rm -rf vendor Godeps/_workspace )

	echo done
}

clean() {
	local packages=(
		"${PROJECT}/cmd/oci-storage"
	)
	local storagePlatforms=( ${STORAGE_OSARCH:="linux/amd64"} )
	local buildTagCombos=(
		''
		'experimental'
	)

	echo

	echo -n 'collecting import graph, '
	local IFS=$'\n'
	local imports=( $(
		for platform in "${storagePlatforms[@]}"; do
			export GOOS="${platform%/*}";
			export GOARCH="${platform##*/}";
			for buildTags in "${buildTagCombos[@]}"; do
				go list -e -tags "$buildTags" -f '{{join .Deps "\n"}}' "${packages[@]}"
				go list -e -tags "$buildTags" -f '{{join .TestImports "\n"}}' "${packages[@]}"
			done
		done | grep -vE "^${PROJECT}/" | sort -u
	) )
	imports=( $(go list -e -f '{{if not .Standard}}{{.ImportPath}}{{end}}' "${imports[@]}") )
	unset IFS

	echo -n 'pruning unused packages, '
	findArgs=

	for import in "${imports[@]}"; do
		[ "${#findArgs[@]}" -eq 0 ] || findArgs+=( -or )
		findArgs+=( -path "vendor/src/$import" )
	done

	local IFS=$'\n'
	local prune=( $($find vendor -depth -type d -not '(' "${findArgs[@]}" ')') )
	unset IFS
	for dir in "${prune[@]}"; do
		$find "$dir" -maxdepth 1 -not -type d -not -name 'LICENSE*' -not -name 'COPYING*' -exec rm -v -f '{}' ';'
		rmdir "$dir" 2>/dev/null || true
	done

	echo -n 'pruning unused files, '
	$find vendor -type f -name '*_test.go' -exec rm -v '{}' ';'
	$find vendor -type f -name 'Vagrantfile' -exec rm -v '{}' ';'

	# These are the files that are left over after fix_rewritten_imports is run.
	echo -n 'pruning .orig files, '
	$find vendor -type f -name '*.orig' -exec rm -v '{}' ';'

	echo done
}

# Fix up hard-coded imports that refer to Godeps paths so they'll work with our vendoring
fix_rewritten_imports () {
       local pkg="$1"
       local remove="${pkg}/Godeps/_workspace/src/"
       local target="vendor/src/$pkg"

       echo "$pkg: fixing rewritten imports"
       $find "$target" -name \*.go -exec sed -i'.orig' -e "s|\"${remove}|\"|g" {} \;
}
