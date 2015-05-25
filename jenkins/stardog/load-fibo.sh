#!/bin/bash
#
# Load the FIBO ontologies in the given clone of the Git repo (if run as a Jenkins job that's your current job workspace)
# into Stardog.
#

function initGlobals() {
	
	if [ "${WORKSPACE}" == "" ] ; then
	  echo "ERROR: This script can only run in the context of a Jenkins job"
		return 1
	fi
	if [ ! -d ${WORKSPACE}/fibo ] ; then
		echo "ERROR: The fibo repo could not be found"
		return 1
	fi

	fibo_repo_root=${WORKSPACE}/fibo

	if ! cd ${fibo_repo_root} >/dev/null ; then
		echo "ERROR: Could not find FIBO repo root: ${fibo_repo_root}"
		return 1
	fi

	if ! which stardog >/dev/null ; then
	  echo "ERROR: Stardog is not configured (or at least not on the PATH)"
	  return 1
	fi

  stardog_bin=$(which stardog)
  stardog_admin_bin=$(which stardog-admin)

  echo "Using ${stardog_bin}"
  echo "Using ${stardog_admin_bin}"

  return 0
}

function loadIntoMainFiboDb() {
	#
	# By using the Jenkins BUILD_URL for the named graph into which we're loading
	# everything we can easily find the relationship between the Named Graph and
	# the job that created it.
	#
	fibo_test_named_graph=${BUILD_URL}

	set -x
	find . -type f -name '*.rdf' | xargs ${stardog_bin} data add fibo --named-graph ${fibo_test_named_graph}
}

function getDatabases() {
	stardog-admin db list --verbose | sed 's/[|+]/ /g' | grep -v "Databases" | grep -v "\-\-\-\-"
}

function getDatabasesCreatedByThisJob() {
	getDatabases | grep jenkins-${JOB_NAME}
}

function removePreviousDatabases() {

	for db in $(getDatabasesCreatedByThisJob) ; do
		echo "Deleting database ${db}"
	done
}

function loadIntoTempJobDb() {

  echo "Creating temporary Stardog database ${BUILD_TAG}"

  set -x
  find . -type f -name '*.rdf' | xargs \
  ${stardog_admin_bin} db create \
  	--index-triples-only \
  	--name "${BUILD_TAG}" \
  	--type M \
  	--verbose \
  	--options preserve.bnode.ids=false reasoning.type=SL \
  	--
  rc=$?
  set +x

  sleep 5

  echo "@@@@@@@@@@@@@@@@@@@ stardog.log @@@@@@@@@@@@@@@@@@@@@"
  set -x
  tail -n 1000 /var/db/stardog/stardog.log	| sed -n '/Bulk loading data to new database ${BUILD_TAG}/,$p'
  set +x
  echo "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"

  tail -n 200 /var/db/stardog/stardog.log

  if [ ${rc} -eq 0 ] ; then
    echo Successfully created database http://stardog.edmcouncil.org/#/databases/${BUILD_TAG}
  fi

  return ${rc}
}

initGlobals || exit $?
removePreviousDatabases || exit $?
loadIntoTempJobDb