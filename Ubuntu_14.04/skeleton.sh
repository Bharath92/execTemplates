#!/bin/bash -e

on_error() {
  ret=$?
  echo "__ON_ERROR__"
  set -e
  exit $ret
}

before_exit() {
  ret=$?
  if [ -n "$current_cmd_uuid" ]; then
    close_cmd $ret
  fi

  if [ -n "$current_grp_uuid" ]; then
    close_grp $ret
  fi

  if [ $ret -eq 0  ]; then
    # "on_success" is only defined for the last task, so execute "always" only
    # if this is the last task.
    if [ "$(type -t on_success)" == "function" ]; then
      exec_cmd "on_success" || true

      if [ "$(type -t always)" == "function" ]; then
        exec_cmd "always" || true
      fi
    fi

    echo "__SH__SCRIPT_END_SUCCESS__";
  else
    if [ "$(type -t on_failure)" == "function" ]; then
      exec_cmd "on_failure" || true
    fi

    if [ "$(type -t always)" == "function" ]; then
      exec_cmd "always" || true
    fi

    echo "__SH__SCRIPT_END_FAILURE__";
  fi
}

begin_grp() {
  # First argument is function to execute
  # Second argument is function description to be shown
  # Third argument is whether the group should be shown or not
  group_name=$1
  group_message=$2
  is_shown=true
  if [ ! -z "$3" ]; then
    is_shown=$3
  fi

  if [ -z "$group_message" ]; then
    group_message=$group_name
  fi
  group_uuid=$(cat /proc/sys/kernel/random/uuid)
  group_start_timestamp=`date +"%s"`
  echo ""
  echo "__SH__GROUP__START__|{\"type\":\"grp\",\"sequenceNumber\":\"$group_start_timestamp\",\"id\":\"$group_uuid\",\"is_shown\":\"$is_shown\"}|$group_message"

  export current_grp=$group_message
  export current_grp_uuid=$group_uuid
}

close_grp() {
  # First argument is the exit code of the group
  local group_status=$1
  if [ -z "$group_status" ]; then
    group_status=0
  fi

  group_end_timestamp=`date +"%s"`
  echo "__SH__GROUP__END__|{\"type\":\"grp\",\"sequenceNumber\":\"$group_end_timestamp\",\"id\":\"$current_grp_uuid\",\"is_shown\":\"$is_shown\",\"exitcode\":\"$group_status\"}|$current_grp"

  unset current_grp
  unset current_grp_uuid
}

begin_cmd() {
  cmd=$@
  cmd_uuid=$(cat /proc/sys/kernel/random/uuid)
  cmd_start_timestamp=`date +"%s"`
  echo "__SH__CMD__START__|{\"type\":\"cmd\",\"sequenceNumber\":\"$cmd_start_timestamp\",\"id\":\"$cmd_uuid\"}|$cmd"

  export current_cmd=$cmd
  export current_cmd_uuid=$cmd_uuid
}

close_cmd() {
  local cmd_status=$1
  if [ -z "$cmd_status" ]; then
    cmd_status=0
  fi

  cmd_end_timestamp=`date +"%s"`
  # If cmd output has no newline at end, marker parsing
  # would break. Hence force a newline before the marker.
  echo ""
  echo "__SH__CMD__END__|{\"type\":\"cmd\",\"sequenceNumber\":\"$cmd_start_timestamp\",\"id\":\"$current_cmd_uuid\",\"exitcode\":\"$cmd_status\"}|$current_cmd"

  unset current_cmd
  unset current_cmd_uuid
}

exec_grp() {
  begin_grp "$@"

  local group=$1

  eval "$group"

  close_grp
}

exec_cmd() {
  begin_cmd "$@"

  set +e

  cmd=$@

  eval "$cmd"
  cmd_status=$?

  set -e

  trap before_exit EXIT
  trap on_error ERR

  if [ $cmd_status -ne 0 ]; then
    return $cmd_status
  fi

  close_cmd
}

test_case1() {
  exec_cmd $'echo foo
    echo lol
    if [ "true" ]; then
      echo true
    fi
  '
}

test_case2() {
  exec_cmd $'echo in_test_case_2'
  exec_cmd $'ls'
}

test_case3() {
  exec_cmd $'echo fail'
  exec_cmd $'sl'
}

test_case4() {
  exec_cmd $'ls'
  exec_cmd $'echo "fail again"
  pwd
  sl'
}

test_case5() {
  exec_cmd $'echo "reset error trap and fail"'
  exec_cmd $'trap - ERR
  trap
  trap "" ERR
  pwd
  sl'
}

test_case6() {
  exec_cmd $'echo "reset EXIT trap and fail"'
  exec_cmd $'trap "" EXIT
  pwd
  sl'
}

test_case7() {
  exec_cmd $'echo "reset both traps and fail"'
  exec_cmd $'trap "" EXIT
  trap "" ERR
  sl'
}

test_case8() {
  exec_cmd $'exit 0'
}

test_case9() {
  exec_cmd $'exit 1'
}

### unhandled cases

test_case10() {
  exec_cmd $'echo "reset ERR trap, fail & continue"'
  exec_cmd $'trap "" ERR
  sl
  ls'
}

test_case11() {
  exec_cmd $'echo "reset both traps and fail"'
  exec_cmd $'trap "" EXIT
  trap "" ERR
  exit 1'
}

test_case12() {
  exec_cmd $'echo "reset ERR trap, fail & continue"'
  exec_cmd $'trap "" EXIT
  exit 0'
}

###

on_success() {
  echo "success :)"
}

on_failure() {
  echo "failure :("
}

always() {
  echo "always :|"
}

trap on_error ERR
trap before_exit EXIT

exec_grp "test_case1"
# exec_grp "test_case2"
# exec_grp "test_case3"
# exec_grp "test_case4"
# exec_grp "test_case5"
# exec_grp "test_case6"
# exec_grp "test_case7"
# exec_grp "test_case8"
# exec_grp "test_case9"
# exec_grp "test_case10"
# exec_grp "test_case11"
