#!/usr/bin/env bash

#
# Copyright 2023 teddyxlandlee
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# Arguments:
# - $1: timeout millis, stop join
# - $2: timeout millis, force termination
# - $3: url (file:/ schema) to version_manifest_v2.json
# - $4: url (file:/ schema) to vineflower.jar
# - $5: decompiler name
# - $6+: mappings name

# Working directory is right here
# Assume the repos are cloned

XDECOMPILER_PWD=$(pwd)
XDECOMPILER_RUN_RAW="java -Dxdecompiler.download.vineflower=$4 -Dxdecompiler.download.mc.manifest=$3"\
" @vmargs-main.txt"\
" -jar XDecompiler-fat.jar --decompiler $5 $(cat exargs-main.txt)"
XDECOMPILER_TIMEOUT_SOFT=$1
XDECOMPILER_TIMEOUT_FORCE=$2

XDECOMPILER_MAPPINGS=()
for ((i=6; i<=$#; i++)); do
    XDECOMPILER_MAPPINGS+=("--mappings")
    XDECOMPILER_MAPPINGS+=("${!i}")
done
XDECOMPILER_MAPPINGS_STR="${XDECOMPILER_MAPPINGS[@]}"

# Init
XDECOMPILER_INITIAL_DATE=$(date +%s%3N)
XDECOMPILER_TERMINATES=false

cd "${XDECOMPILER_PWD}/out/src"
git config user.name 'github-actions[bot]'
git config user.email 'github-actions[bot]@noreply.github.com'
cd "${XDECOMPILER_PWD}/out/resources"
git config user.name 'github-actions[bot]'
git config user.email 'github-actions[bot]@noreply.github.com'
cd "${XDECOMPILER_PWD}"

xdecompiler_checkout () {
  if "${XDECOMPILER_TERMINATES}" ; then return 1 ; fi

  # Arguments:
  # - $1: branch name

  cd "${XDECOMPILER_PWD}/out/src"
  git checkout -B $1
  #cd "${XDECOMPILER_PWD}/out/resources"
  #git checkout -B $1
  cd "${XDECOMPILER_PWD}"
}

xdecompiler_run () {
  if "${XDECOMPILER_TERMINATES}" ; then return 1 ; fi

  # Arguments:
  # - $1: version name

  # 0. Copy old files, into new directory
  mkdir ${XDECOMPILER_PWD}/out-tmp
  mkdir ${XDECOMPILER_PWD}/out-tmp/src
  mkdir ${XDECOMPILER_PWD}/out-tmp/resources
  cp -r -t ${XDECOMPILER_PWD}/out-tmp/src ${XDECOMPILER_PWD}/out/src/.git
  #cp -r -t ${XDECOMPILER_PWD}/out-tmp/resources ${XDECOMPILER_PWD}/out/resources/.git
  #rm -rf ${XDECOMPILER_PWD}/out

  # Use force termination
  timeout $(echo "( ${XDECOMPILER_INITIAL_DATE} + ${XDECOMPILER_TIMEOUT_FORCE} - $(date +%s%3N) ) * 0.001" | bc) \
   bash -c '#xdecompiler_run0
      set -e
      echo "Running for $1" >> "$4"
      IFS=" " read -r -a XDECOMPILER_MAPPINGS <<< "$5"
      # 1. Run main program, then add version stamp
      cd "$3"
      $2 --output-code "$3/out-tmp/src" \
                          --output-resources "$3/out-tmp/resources" \
                          "${XDECOMPILER_MAPPINGS[@]}" \
                          "$1"
      echo "$1" >> "$3/out-tmp/src/version.txt"

      # 2. Commit, tagging
      cd "$3/out-tmp/src"
      git add .
      git commit -m "$1"
      git tag "$1"
      #cd "$3/out-tmp/resources"
      #git add .
      #git commit -m "$1"
      #git tag "$1"
      cd "$3"

      echo "Successfully finished running for $1" >> "$4"
      set +e
   ' "xdecompiler_run0" "$1" "${XDECOMPILER_RUN_RAW}" "${XDECOMPILER_PWD}" "$GITHUB_STEP_SUMMARY" "${XDECOMPILER_MAPPINGS_STR}"
  #bash -c "echo '#1 breakpoint returns' $? ; exit $?"
  if [ "$?" == 124 ] ; then
    XDECOMPILER_TERMINATES=true
    return 1
  fi

  # 3. move back
  rm -rf "${XDECOMPILER_PWD}/out"
  mv -T "${XDECOMPILER_PWD}/out-tmp" "${XDECOMPILER_PWD}/out"

  #bash -c "echo '#2 breakpoint returns' $? ; exit $?"
  # Use soft termination
  if [ $(echo "${XDECOMPILER_INITIAL_DATE} + ${XDECOMPILER_TIMEOUT_SOFT}" - $(date +%s%3N) | bc) -le 0 ] ; then
  #bash -c "echo '#3 breakpoint returns' $? ; exit $?"
    XDECOMPILER_TERMINATES=true
    return 1
  fi
}

