#!groovy

import net.sf.json.JSONArray;
import net.sf.json.JSONObject;

pipeline {
    agent any
    tools {
        maven 'M2'
        jdk 'Jdk1.8u191'
    }

    environment {
        ECR_URL = 'https://758526784474.dkr.ecr.us-east-1.amazonaws.com/'
        RUN_PRE_BUILD = true
        RUN_BUILD_BRANCH = true
        RUN_BUILD_MASTER = true
        RUN_POST_BUILD = true
        RUN_CHECKS = true
        S3_BUCKET_ARTIFACT = "cdt-devops-tools-lambda-functions-artifacts"
        S3_BUCKET_TEMPLATE = "cdt-devops-tools-lambda-functions-template"
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '50'))
        timeout(time: 10, unit: 'MINUTES')
    }

    stages {
        stage('Check commit message') {
            steps {
                script {
                    current_commit_message = sh(script: '''
                git rev-list --format=%B --max-count=1 HEAD |head -2 |tail -1
              ''', returnStdout: true).trim()

                    if (current_commit_message == 'Prepare for next Release') {
                        currentBuild.result = 'ABORTED'
                        error('Parando build por ser um commit de CI.')
                    }
                }

            }
        }

        stage('Check Branch Name') {
            steps {
                script {
                    if (BRANCH_NAME.startsWith("master") || BRANCH_NAME.startsWith("feature") || BRANCH_NAME.startsWith("develop") || BRANCH_NAME.startsWith("release") || BRANCH_NAME.startsWith("hotfix")) {
                        echo "***** Let's go to the Build *****"

                    } else {
                        currentBuild.result = 'ABORTED'
                        error('Parando o build por não estar de acordo com a nomenclatura de Branch.')
                    }
                }
            }
        }

        stage('Notify') {
            steps {
                echo sh(returnStdout: true, script: 'env')
                notifyBuild('STARTED')
            }
        }

        stage('Pre-Build CheckList') {
            when {
                environment name: 'RUN_CHECKS', value: 'true'
            }
            steps {
                parallel(
                    "Commit Behind": {
                        checkCommitBehind()
                    }
                )
            }
        }

        stage('Pre-Build') {
            when {
                environment name: 'RUN_PRE_BUILD', value: 'true'
            }
            steps {
                script {
                    env['RUN_BUILD_BRANCH'] = false
                    env['RUN_BUILD_MASTER'] = false
                    if (BRANCH_NAME.startsWith("master")) {
                        echo "***** PERFORMING STEPS ON MASTER *****"
                        env['RUN_BUILD_MASTER'] = true
                        env['environment'] = "prd"
                        updateVersion(true)
                        env['RUN_DEPLOY'] = false
                    }
                    else if (BRANCH_NAME.startsWith("develop")) {
                        echo "***** PERFORMING STEPS ON DEVELOP BRANCH *****"
                        bump_git_tag()
                        env['RUN_BUILD_BRANCH'] = true
                        env['environment'] = "hml"
                        updateVersion(false)
                        env['RUN_DEPLOY'] = true

                    }
                    else if (BRANCH_NAME.startsWith("developer")) {
                        echo "***** PERFORMING STEPS ON DEVELOP BRANCH *****"
                        bump_git_tag()
                        env['RUN_BUILD_BRANCH'] = true
                        env['environment'] = "hml"
                        updateVersion(false)
                        env['RUN_DEPLOY'] = true
                    }
                    else if (BRANCH_NAME.startsWith("feature")) {
                        echo "***** PERFORMING STEPS ON HOTFIX BRANCH *****"
                        bump_git_tag()
                        env['RUN_BUILD_BRANCH'] = true
                        env['environment'] = "hml"
                        updateVersion(false)
                        env['RUN_DEPLOY'] = false
                    }
                    else if (BRANCH_NAME.startsWith("release")) {
                        echo "***** PERFORMING STEPS ON HOTFIX BRANCH *****"
                        bump_git_tag()
                        env['RUN_BUILD_BRANCH'] = true
                        env['environment'] = "hml"
                        updateVersion(false)
                        env['RUN_DEPLOY'] = false
                    }
                    else if (BRANCH_NAME.startsWith("hotfix")) {
                        echo "***** PERFORMING STEPS ON HOTFIX BRANCH *****"
                        bump_git_tag()
                        env['RUN_BUILD_BRANCH'] = true
                        env['environment'] = "hml"
                        updateVersion(false)
                        env['RUN_DEPLOY'] = false
                    }
                    else {
                        echo "***** BRANCHES MUST START WITH RELEASE OR DEVELOP *****"
                        echo "***** STOPPED BUILD *****"
                        currentBuild.result = 'FAILURE'
                    }
                    env['url_docker'] = "758526784474.dkr.ecr.us-east-1.amazonaws.com/image-linux-ruby-backend-qa:${newVersion}"
                }

                sh 'echo "***** FINISHED PRE-BUILD STEP *****"'
            }
        }

        stage('Build branch docker image'){
            when {
                environment name: 'RUN_BUILD_BRANCH', value: 'true'
            }
            steps {
                script {
                    withCredentials([sshUserPrivateKey(credentialsId: 'e145e174-145a-4213-ba52-555fba0a4871', keyFileVariable: 'keyssh', usernameVariable: 'userssh')]) {
                        sh '''cat "$keyssh" > ./keygit'''
                    }
                    withDockerRegistry(credentialsId: 'cf31ef09-c8cb-437a-83d0-9cdc63d666d7', url: 'https://index.docker.io') {
                        def app = docker.build("image-linux-ruby-backend-qa")
                    }
                    docker.withRegistry("${env.ECR_URL}",'ecr:us-east-1:ecr-private-registry'){
                        def app = docker.build("image-linux-ruby-backend-qa")
                        app.push(env['newVersion'])
                        app.push('latest')
                    }
                }
            }
        }

        stage ('delete image'){
            when {
                environment name: 'RUN_BUILD_BRANCH', value: 'true'
            }
            steps{
                script{
                    removeImage('image-linux-ruby-backend-qa',env['newVersion'])
                }
            }
        }

    }
    post {
        success {
            notifyBuild('SUCCESSFUL')
        }
        failure {
            notifyBuild('FAILED')
        }
        always {
            removeImage('image-linux-ruby-backend-qa',env['newVersion'])
            deleteDir()
        }
    }
}


def void removeImage(String build_name, String newVersion){
    script{
        try {
            env.build_name = build_name
            env.newVersion = newVersion
            sh(script: '''
                for i in `docker images | grep ${build_name} | grep ${newVersion} | awk '{print $3}'`
                    do
                        echo $i
                        docker rmi $i --force
                    done
            ''', returnStdout: false)
        } catch(err){
            error("erro na função removeImage")
        }
    }
}

def notifyBuild(String buildStatus = 'STARTED') {
    buildStatus = buildStatus ?: 'SUCCESSFUL'

    String colorCode = '#FF0000'
    String subject = "${buildStatus}: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]'"
    String summary = "${subject} \n (${env.BUILD_URL})  "
    String details = """<p>${buildStatus}: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]':</p>
    <p>Check console output at &QUOT;<a href='${env.BUILD_URL}'>${env.JOB_NAME} [${env.BUILD_NUMBER}]</a>&QUOT;</p>"""


    JSONArray attachments = new JSONArray();
    JSONObject attachment = new JSONObject();

    if (buildStatus == 'STARTED') {
        colorCode = '#FFFF00'
        attachment.put('text','Use a força, deixe a fluir! Elimine a DeathStar')
        attachment.put('thumb_url','https://i.ya-webdesign.com/images/x-wing-png-9.png')
    } else if (buildStatus == 'SUCCESSFUL') {
        colorCode = '#00FF00'
        attachment.put('text','Lembre se a força estará com você, sempre! DeathStar Explodiu')
        attachment.put('thumb_url','https://pngimg.com/uploads/explosion/explosion_PNG15362.png')

        JSONArray fields = new JSONArray();
        JSONObject field = new JSONObject();

        field.put('title', 'Template S3');
        field.put('value', env['fileOutput']);
        fields.add(field);

        field = new JSONObject();

        field.put('title', 'Version');
        field.put('value', env['newVersion']);
        fields.add(field);

        field.put('title', 'Path');
        field.put('value', 'image-linux-ruby-backend-qa');
        fields.add(field);

        attachment.put('fields',fields);
    } else {
        attachment.put('text','Você errou o tiro! DeathStar ainda vive')
        attachment.put('thumb_url','https://toppng.com/uploads/preview/the-death-star-star-wars-death-star-11562902961caqjz9dfv9.png')
        colorCode = '#FF0000'
    }

    String buildUrl = "${env.BUILD_URL}";
    attachment.put('title', subject);
    attachment.put('callback_id', buildUrl);
    attachment.put('title_link', buildUrl);
    attachment.put('fallback', subject);
    attachment.put('color', colorCode);
    attachments.add(attachment);
    echo attachments.toString();
    slackSend(attachments: attachments.toString())
}

def checkCommitBehind() {
    sh 'echo "Verifica se branch necessita de merge com master."'
    script {
        sh(script: '''set +x; set +e;
                      git fetch;
                      commitsBehind=$(git rev-list --left-right --count origin/master... |awk '{print $1}');
                      if [ ${commitsBehind} -ne 0 ]
                      then
                        echo "Esta branch está ${commitsBehind} commits atrás da master!"
                        exit 1
                      else
                        echo "Esta branch não tem commits atrás da master."
                      fi''')
    }

}

def bump_git_tag() {
    echo "Bumping Git CI Tag"

    script {
        sh "git fetch --tags"
        env['bumpci_tag'] = sh(script: '''
        current_tag=$(git tag -n9 -l |grep bumpci |awk '{print $1}' |sort -V |tail -1)
        if [[ $current_tag == '' ]]
        then
          current_tag=0.0.1
        fi
        echo "${bumpci_tag}"
      ''', returnStdout: true)
    }
}

def updateVersion(boolean isMaster){
    sh "git fetch --tags"
    env['docker_version'] = sh(script: '''
            current_tag=`git tag -n9 -l |grep docker_version |awk '{print $1}' |sort -V |tail -1`
            echo ${current_tag}
            ''', returnStdout: true).trim()

    if (env['docker_version'] == ''){
        env['docker_version'] = "1.0.0"
    }

    def oldVersion = "${env.docker_version}".tokenize('.')

    if(isMaster){
        major = oldVersion[0].toInteger()
        minor = oldVersion[1].toInteger() + 1
        patch = 0
    }else{
        major = oldVersion[0].toInteger()
        minor = oldVersion[1].toInteger()
        patch = oldVersion[2].toInteger() + 1
    }
    env['newVersion'] = major + '.' + minor + '.' + patch

    bump_version_tag()
}

def version_code_tag() {
    echo "getting Git version Tag"
    script {
        sh "git fetch --tags"
        env['bumpci_tag'] = sh(script: '''
            current_tag=$(git tag -n9 -l |grep version |awk '{print $1}' |sort -V |tail -1)
            if [[ $current_tag == '' ]]
            then
              echo 1.0.0 |tr -d '\n'
            else
              echo "${current_tag} + 1" |/bin/bc |/bin/tr -d '\n'"
            fi
            ''', returnStdout: true).trim()
    }
}

def bump_version_tag() {
    echo "Bumping version CI Tag"
    script {
        sh "git tag -a ${newVersion} -m docker_version && git push origin refs/tags/${newVersion}"
    }
}