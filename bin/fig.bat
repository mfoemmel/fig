@set FIG_DIR=%~dp0

@"ruby.exe" --external-encoding UTF-8 --internal-encoding UTF-8 -r "%FIG_DIR%..\lib\fig\command\initialization.rb" -e "exit Fig::Command.new.run_fig_with_exception_handling ARGV" %*
