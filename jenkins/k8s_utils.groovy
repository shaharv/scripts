// Given a pod name string, returns the name of a running pod instance.
// The output of "kubectl get pods" is filtered to get running pods that match the name.
// Only one line of output is used - it is assumed no more than one pod instance is running.
String getPodName(String podNameString) {
    def podName = sh(script: "kubectl get pods --no-headers --field-selector=status.phase=Running --selector=app.kubernetes.io/name=${podNameString} -o custom-columns=':metadata.name' | head -n 1", returnStdout: true).trim()
    return podName
}

// Run the specified command inside the specified pod instance.
// Optionally run in a specific container in the pod.
void runInPod(String podName, String containerName, String runCommand) {
    // Create a script for running kubectl (required due to nested quotes)
    def scriptPath = "${env.WORKSPACE}/run_on_k8s.sh"
    def scriptContent = "#!/bin/bash\n"
    scriptContent += "set -exuo pipefail\n"
    // Construct the kubectl command
    def kubectlCmd = "kubectl exec ${podName} "
    if (containerName != "") {
        kubectlCmd += "-c ${containerName} "
    }
    kubectlCmd += "-- /bin/sh -c "
    kubectlCmd += "\"${runCommand}\""
    scriptContent += "${kubectlCmd}\n"
    // Run the generated script
    writeFile file: "${scriptPath}", text: scriptContent
    sh "chmod +x ${scriptPath}"
    sh "cat ${scriptPath}"
    sh "kubectl get pods"
    sh "${scriptPath}"
    // Cleanup
    sh "rm ${scriptPath}"
}

return this
