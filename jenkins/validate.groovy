#!/usr/bin/env groovy

/**
 * Jenkinsfile Syntax Validator
 *
 * This script validates the syntax of a Jenkinsfile by attempting to parse it.
 * It's useful for catching syntax errors before committing changes to version control.
 *
 * Prerequisites:
 * 1. Install Groovy:
 *    - On Ubuntu/Debian: sudo apt-get install groovy
 *    - Verify installation: groovy --version
 *
 * Usage:
 * 1. Make sure you have Groovy installed on your system
 * 2. Run the script with the Jenkinsfile path as an argument.
 *    If no argument is provided, it will look for a file named 'Jenkinsfile' in the current directory.
 *
 * The script will:
 * - Attempt to parse the Jenkinsfile
 * - Print a success message if the syntax is valid
 * - Print detailed error information if there are syntax errors
 */

def jenkinsfilePath = args.length > 0 ? args[0] : 'Jenkinsfile'

def file = new File(jenkinsfilePath)

if (!file.exists()) {
    println "Error: File not found: ${file.absolutePath}"
    println "Usage: ./validate.groovy [path/to/Jenkinsfile]"
    return
}

def jenkinsfile = file.text

try {
    def script = new groovy.lang.GroovyShell().parse(jenkinsfile)
    println "Syntax validation successful for ${file.absolutePath}!"
} catch (Exception e) {
    println "Syntax error found in ${file.absolutePath}:"
    println e.message
    println "\nStack trace:"
    e.printStackTrace()
    System.exit(1)
}
