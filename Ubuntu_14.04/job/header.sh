#!/bin/bash -e

#
# Header script is attached at the beginning of every script generated and
# contains the most common methods use across the script
#

before_exit() {
  ret=$?

  # Flush any remaining console
  echo $1
  echo $2

  if [ -n "$current_cmd_uuid" ]; then
    close_cmd $ret
  fi

  if [ -n "$current_grp_uuid" ]; then
    close_grp $ret
  fi

  if [ "$ret" -eq 0 ]; then
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

on_error() {
  ret=$?
  trap before_exit EXIT
  set -e
  exit $ret
}

exec_cmd() {
  begin_cmd "$@"

  cmd=$@

  trap on_error ERR
  set +e

  eval "$cmd"
  cmd_status=$?

  set -e
  trap on_error ERR
  trap before_exit EXIT

  if [ $cmd_status -ne 0 ]; then
    return $cmd_status
  fi

  close_cmd
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
  cmd_status=$1

  if [ -z "$cmd_status" ]; then
    cmd_status=0
  fi

  cmd_end_timestamp=`date +"%s"`
  # If cmd output has no newline at end, marker parsing
  # would break. Hence force a newline before the marker.
  echo ""
  echo "__SH__CMD__END__|{\"type\":\"cmd\",\"sequenceNumber\":\"$cmd_end_timestamp\",\"id\":\"$current_cmd_uuid\",\"exitcode\":\"$cmd_status\"}|$current_cmd"

  unset current_cmd
  unset current_cmd_uuid
}

exec_grp() {
  begin_grp "$@"
  group_name=$1

  eval "$group_name"

  close_grp
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
  group_status=$1

  if [ -z "$group_status" ]; then
    group_status=0
  fi

  group_end_timestamp=`date +"%s"`
  echo "__SH__GROUP__END__|{\"type\":\"grp\",\"sequenceNumber\":\"$group_end_timestamp\",\"id\":\"$current_grp_uuid\",\"is_shown\":\"$is_shown\",\"exitcode\":\"$group_status\"}|$current_grp"

  unset current_grp
  unset current_grp_uuid
}

trap on_error ERR
trap before_exit EXIT
