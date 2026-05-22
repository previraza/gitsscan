_gitss_completions() {
  local cur prev
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"

  if [[ "$prev" == "--config" ]]; then
    COMPREPLY=( $(compgen -f -- "$cur") )
    return 0
  fi

  case "$cur" in
    --config=*)
      local value="${cur#--config=}"
      COMPREPLY=( $(compgen -f -- "$value") )
      local i
      for i in "${!COMPREPLY[@]}"; do
        COMPREPLY[$i]="--config=${COMPREPLY[$i]}"
      done
      return 0
      ;;
    --files-list=*)
      COMPREPLY=( $(compgen -W "--files-list=all --files-list=5 --files-list=10 --files-list=20" -- "$cur") )
      return 0
      ;;
    --scan-mode=*)
      COMPREPLY=( $(compgen -W "--scan-mode=mixed --scan-mode=web --scan-mode=git" -- "$cur") )
      return 0
      ;;
    --workers=*)
      COMPREPLY=( $(compgen -W "--workers=1 --workers=2 --workers=4 --workers=8" -- "$cur") )
      return 0
      ;;
  esac

  local opts
  opts="--help --version --dirty --clean --no-git -fl --files-list --files-list=all --files-list=5 --files-list=10 --files-list=20 --summary --disk --ahead --branch --last-commit --json --no-color --scan-mode --scan-mode=mixed --scan-mode=web --scan-mode=git --workers --workers=1 --workers=2 --workers=4 --workers=8 --fetch --pull --commit --push --dry-run --unsafe --config"
  COMPREPLY=( $(compgen -W "$opts" -- "$cur") )
}

complete -F _gitss_completions gitss
