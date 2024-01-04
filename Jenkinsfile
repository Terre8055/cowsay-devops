pipeline {
    agent any

    parameters {
        string(name: 'major_minor_version', defaultValue: '1.0', description: 'The major.minor version for release.')
    }

    options {
        timestamps()
        timeout(time: 15, unit: 'MINUTES') 
        gitLabConnection('gitlab')
    }

    environment {
        AWS_ECR = "644435390668.dkr.ecr.ap-south-1.amazonaws.com"
        RUNTIME_ENV_IP = "13.234.75.250"
        RUNTIME_ENV_USER = "ec2-user@${RUNTIME_ENV_IP}"
        RUNTIME_PORT_MAIN = "80"
        RUNTIME_PORT_STAGING = "3000"

        STATIC_IP="3.110.122.251"
    }

    triggers {
        gitlab(triggerOnPush: true, triggerOnMergeRequest: true, branchFilterType: 'All')    
    }

    stages {
        stage('Verify Release Branch') {
            when {
                branch "main"
            }
            steps {
                script {
                    echo 'Hiii'
                    def releaseBranch = "release/${params.major_minor_version}"
                    def branchExists = sh(script: "git show-ref --verify --quiet refs/heads/${releaseBranch}", returnStatus: true)

                    if (branchExists == 0) {
                        echo "Release branch ${releaseBranch} already exists. Proceeding with versioning..."
                    } else {
                        echo "Release branch ${releaseBranch} doesn't exist. Manual creation required."
                        currentBuild.result = 'FAILURE'
                        error "Manual creation of the release branch is required."
                    }
                }
            }
        }


        stage('Checkout to Release') {
            when {
                expression { BRANCH_NAME ==~ /(main|staging)/ }
            }
            steps {
                script {
                    def releaseBranch = "release/${params.major_minor_version}"
                    def versionFile = 'version.txt'

                    sh "git checkout ${releaseBranch}"

                    if (!fileExists(versionFile)) {
                        echo "Creating version.txt..."
                        writeFile file: versionFile, text: "${params.major_minor_version}.0"
                        echo "Version.txt created with initial version."
                    }

                    def currentVersion = readFile(versionFile).trim()
                    def parts = currentVersion.split('\\.')
                    def patchVersion = parts[2].toInteger() + 1

                    def newVersion = "${parts[0]}.${parts[1]}.${patchVersion}"
                    echo "New version: ${newVersion}"

                    sh "git config user.email michaelappiah2018@icloud.com"
                    sh "git config user.name Terre8055"

                    echo "Config added"

                    writeFile file: versionFile, text: newVersion
                    withCredentials([usernamePassword(credentialsId: 'gt_token', passwordVariable: 'GITLAB_PASSWORD', usernameVariable: 'GITLAB_USERNAME')]) {

                        sh "git add ${versionFile}"
                        sh "git commit -m 'Incremented patch version'"
                        sh "git remote set-url origin https://${GITLAB_USERNAME}:${GITLAB_PASSWORD}@gitlab.com/Terre8055/cowsay_freestyle.git"
                        sh "git push origin ${releaseBranch}"
                    }
                }
            }
        }
    

        stage('Build') {
            steps {
                script {
                    try {
                        sh 'docker build -t cowsay-mike .'
                    } catch (Exception buildError) {
                        echo "Build failed: ${buildError.message}"
                        currentBuild.result = 'FAILURE'
                        error "Build failed."
                    }
                }
            }
        }

        stage('Test') {
            when {
                branch "feature/*"
            }
            steps {
                script {
                    try {
                        sh '''
                        docker stop cowsay || true
                        docker rm cowsay || true
                        docker run --detach --publish=8081:8080 --name=cowsay cowsay-mike:latest
                        sleep 5s
                        curl -fsSLi http://13.234.75.250:8081
                        docker stop cowsay
                        docker rm cowsay
                        '''
                    } catch (Exception testError) {
                        echo "Test failed: ${testError.message}"
                        currentBuild.result = 'FAILURE'
                        error "Test failed."
                    }
                }
            }
        }

        stage("Publish") {
            steps {
                script {
                    def releaseBranch = "release/${params.major_minor_version}"
                    def versionFile = 'version.txt'

                    def releaseVersion = readFile(versionFile).trim()
                    echo "Publishing version: ${releaseVersion}"

                    sh("aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin ${AWS_ECR}")
                    sh("docker tag cowsay-mike:latest ${AWS_ECR}/cowsay-mike:${releaseVersion}")
                    sh("docker push ${AWS_ECR}/cowsay-mike:${releaseVersion}")
                    sh 'docker image rm cowsay-mike:latest'
                }
            }
        }

        stage("Deploy") {
            when {
                expression { BRANCH_NAME ==~ /(main|staging)/ }
            }
            steps {
                script {
                    def releaseBranch = "release/${params.major_minor_version}"
                    def versionFile = 'version.txt'
                    def releaseVersion = readFile(versionFile).trim()

                    echo "Releasing version: ${releaseVersion}"

                    def nameBranch = env.BRANCH_NAME

                    echo "${nameBranch}"

                    sh """
                        ssh -i /var/jenkins_home/confion-ec2-ssh-mike.pem -o 'StrictHostKeyChecking no' ec2-user@ec2-3-110-122-251.ap-south-1.compute.amazonaws.com \
                        'aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin ${AWS_ECR} && \
                        sleep 5s && \
                        docker pull ${AWS_ECR}/cowsay-mike:${releaseVersion} && \
                        sleep 5s && \
                        docker rm -f cowsay  && \
                        docker run -d  -p ${RUNTIME_PORT_STAGING}:8080 --name cowsay ${AWS_ECR}/cowsay-mike:${releaseVersion}'
                        sleep 5s
                    """

                    sh """
                        if [ "${nameBranch}" == 'main' ]; then
                            echo "Running on ${nameBranch}......."
                            docker rm -f cowsay
                            docker run -d -p ${RUNTIME_PORT_MAIN}:8080 --name cowsay ${AWS_ECR}/cowsay-mike:${releaseVersion}
                            docker ps
                        else
                            echo "Running on ${nameBranch}......."
                            docker rm -f cowsay
                            
                            docker run -d -p ${RUNTIME_PORT_STAGING}:8080 --name cowsay ${AWS_ECR}/cowsay-mike:${releaseVersion}
                            docker ps

                        fi
                        sleep 5s
                    """

                }
            }
        }


        stage('Release') {
            when {
                branch "main"
            }
            steps {
                script {
                    def releaseBranch = "release/${params.major_minor_version}"
                    def versionFile = 'version.txt'

                    def releaseVersion = readFile(versionFile).trim()
                    echo "Releasing version: ${releaseVersion}"

                    sh "git config user.email michaelappiah2018@icloud.com"
                    sh "git config user.name Terre8055"

                    echo "Config added"

                    def tagName = "v${releaseVersion}"

                    def tagExists = sh(script: "git rev-parse -q --verify refs/tags/${tagName}", returnStatus: true) == 0

                    if (tagExists) {
                        echo "Tag ${tagName} already exists. Deleting..."
                        withCredentials([usernamePassword(credentialsId: 'gt_token', passwordVariable: 'GITLAB_PASSWORD', usernameVariable: 'GITLAB_USERNAME')]) {
                            sh "git tag -d ${tagName}"
                            sh "git remote set-url origin https://${GITLAB_USERNAME}:${GITLAB_PASSWORD}@gitlab.com/Terre8055/cowsay_freestyle.git"
                            sh "git push --delete origin ${tagName}"
                        }
                    }


                    withCredentials([usernamePassword(credentialsId: 'gt_token', passwordVariable: 'GITLAB_PASSWORD', usernameVariable: 'GITLAB_USERNAME')]) {
                        sleep 5
                        sh 'git reset --hard'
                        sh 'rm version.txt'
                        sh 'git rm version.txt'
                        sh "git tag -a ${tagName} -m 'Release version ${releaseVersion}'"
                        sh "git remote set-url origin https://${GITLAB_USERNAME}:${GITLAB_PASSWORD}@gitlab.com/Terre8055/cowsay_freestyle.git"
                        sleep 5
                        sh 'git push origin --tags'
                    }
                }
            }
        }


        stage("E2E test") {
            when {
                expression { BRANCH_NAME ==~ /(main|staging)/ }
            }
            steps {
                script {
                    def nameBranch = env.BRANCH_NAME

                    try {
                        sh """
                            sleep 5s
                            if [ "${nameBranch}" == 'main' ]; then
                                curl ${STATIC_IP}:${RUNTIME_PORT_MAIN}
                            else
                                curl ${STATIC_IP}:${RUNTIME_PORT_STAGING}
                            fi
                            sleep 5s
                        """
                    } catch (Exception e2eError) {
                        echo "E2E test failed: ${e2eError.message}"
                        currentBuild.result = 'FAILURE'
                        error "E2E test failed."
                    }
                }
            }
        }
    }
}
