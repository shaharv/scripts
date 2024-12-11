def isDefinedNotEmpty(arg) {
    // validating that arg is not null object and the value of arg is not empty or "null"
    return (arg == 0) || (arg && (arg != "null") && (arg != "") && ("${arg}" != "null"))
}

// Verify that the Jenkins workspace is clean, and contains only the files from a clean git clone.
// Return true for a clean workspace and false otherwise.
boolean verifyCleanWorkspace() {
    // Check if a marker file exists. If it does, it means the Jenkins workspace was not deleted
    // by a previous job. The marker file is created at the end of this stage.
    def jobStartedFileName = "JENKINS_JOB_STARTED"
    def jobStartedFilePath = "${env.WORKSPACE}/${jobStartedFileName}"
    echo "Checking if ${jobStartedFilePath} exists."
    if (fileExists(jobStartedFilePath)) {
        echo "Jenkins workspace is not clean - marker file found!"
        return false
    }

    // As an extra safety check, check that the workspace files match the ones in git, to verify the
    // workspace was not tempered with.
    // git command breakdown:
    // - git diff-index --quiet HEAD --
    //   Detects changes to tracked files (both staged and unstaged). It will return 0 if there are no changes.
    // - git ls-files --others --ignored --exclude-standard
    //   Detects untracked files and ignored files. If the output is not empty, the workspace is not clean.
    //   Note that submodules are not included in this check.
    rc = sh(script: 'git diff-index --quiet HEAD -- && [ -z "$(git ls-files --others --ignored --exclude-standard)" ]', returnStatus: true)
    if (rc != 0) {
        echo "Jenkins workspace is not clean - diff detected!"
        return false
    }

    // Create the marker file
    echo "Workspace is clean. Creating the marker file ${jobStartedFilePath}"
    sh "touch ${env.WORKSPACE}/${jobStartedFileName}"

    return true
}

return this
