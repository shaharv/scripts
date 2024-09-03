// Given a pod name string, returns the name of a running pod instance.
// The output of "kubectl get pods" is filtered to get running pods that match the name.
// Only one line of output is used - it is assumed no more than one pod instance is running.
// Extra "grep Running" is needed, as kubectl will also return pods with "Terminating" state,
// which are still running technically.
String getPodName(String podNameString) {
    def podName = sh(script: "kubectl get pods --no-headers --field-selector=status.phase=Running --selector=app.kubernetes.io/name=$podNameString -o wide | grep Running | cut -d' ' -f1 | head -1", returnStdout: true).trim()
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

boolean waitForPods(List<String> podNames) {
    def repeats = 15
    def sleepSeconds = 10
    for (int i = 1; i <= repeats; i++) {
        def podsStarted = 0
        for(podName in podNames) {
            echo "Waiting for " + podName + " (" + i + ") ..."
            def podInstance = k8sUtils.getPodName(podName)
            if (podInstance != "") {
                echo "Pod started: " + podInstance
                podsStarted++
            }
        }
        if (podsStarted == podNames.size()) {
            return true
        }
        sleep(sleepSeconds)
    }
    return false
}

// Perform a complete cleanup of K8s
void fullK8sCleanup() {
    sh "kubectl delete deployments  --all --all-namespaces         || true"
    sh "kubectl delete services     --all --all-namespaces         || true"
    sh "kubectl delete pods         --all --all-namespaces --force || true"
    sh "kubectl delete daemonsets   --all --all-namespaces         || true"
    sh "kubectl delete statefulsets --all --all-namespaces         || true"
    sh "kubectl delete jobs         --all --all-namespaces         || true"
    sh "kubectl delete pvc          --all --all-namespaces         || true"
    sh "kubectl delete pv           --all                          || true"
}

return this
