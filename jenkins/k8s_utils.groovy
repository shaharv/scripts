// Given a pod name string, returns the name of a running pod.
// The output of "kubectl get pods" is filtered to get running pods that match the name.
// Only one line of output is used - it is assumed no more than one pod instance is running.
// Extra "grep Running" is needed, as kubectl will also return pods with "Terminating" state,
// which are still running technically.
String getRunningPodName(String podNameString) {
    def podName = sh(script: "kubectl get pods --no-headers --field-selector=status.phase=Running --selector=app.kubernetes.io/name=$podNameString -o wide | grep Running | cut -d' ' -f1 | head -1", returnStdout: true).trim()
    return podName
}

// Given a pod name string, returns the name of a most recent concrete pod.
// The returned pod might not be in a Running state; for running pods, use getRunningPodName.
String getNewestPodName(String podNameString) {
    def podName = sh(script: "kubectl get pods --no-headers --selector=app.kubernetes.io/name=$podNameString --all-namespaces -o custom-columns=NAME:.metadata.name,AGE:.metadata.creationTimestamp | sort -k2 -r | awk '{print \$1}' | head -1", returnStdout: true).trim()
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

boolean waitForPods(List<String> podNames, sleepSeconds = 10, repeats = 15) {
    for (int i = 1; i <= repeats; i++) {
        def podsStarted = 0
        for(podName in podNames) {
            echo "Waiting for " + podName + " (" + i + ") ..."
            def podInstance = k8sUtils.getRunningPodName(podName)
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

// Perform a complete cleanup of the K8s runtime.
// Docker images are not impacted (those reside in the local docker image registry).
void fullK8sCleanup() {
    // Forcefully stop and remove running pods, including kube-system pods.
    // System pods, such as Calico pods, will be restored by their daemonSet.
    sh "kubectl delete pods         --all --all-namespaces --force || true"

    // Remove pod lifecycle management entities.
    // Do not remove deployments and daemonsets from the kube-system namespace,
    // for not deleting entities of Calico (network plugin).
    // Note that in case Calico is removed, it could be restored using the following command:
    // "kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml".
    sh "kubectl delete deployments  --all                          || true"
    sh "kubectl delete statefulsets --all --all-namespaces         || true"
    sh "kubectl delete daemonsets   --all                          || true"
    sh "kubectl delete jobs         --all --all-namespaces         || true"

    // Remove services, which manage pods' networking
    sh "kubectl delete services     --all --all-namespaces         || true"

    // Remove pod storage related entities
    sh "kubectl delete pvc          --all --all-namespaces         || true"
    sh "kubectl delete pv           --all                          || true"
}

// Force kill all docker containers using their pid.
// This allows killing containers which could be stopped even with --force.
void forceKillAllDockerContainers() {
    sh "docker ps -q | xargs -I {} docker inspect --format '{{ .State.Pid }}' {} | xargs sudo kill -9 || true"
}

return this
