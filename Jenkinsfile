pipeline {
    agent any

    tools {
        terraform 'ttff'
        ansible 'aann'
        maven 'mmvvnn'
    }

    environment {
        AWS_ACCESS_KEY = credentials('AWS_ACCESS_KEY')
        AWS_SECRET_ACCESS_KEY = credentials('AWS_SECRET_ACCESS_KEY')
        SSH_PRIVATE_KEY_PATH = "~/.ssh/mujahed.pem"
    }

    stages {
        stage('Checkout Repository') {
            steps {
                git branch: 'main', url: 'https://github.com/mehziya/spring-petclinic.git'
            }
        }

        stage('Setup Terraform') {
            steps {
                script {
                    sh '''
                    terraform init
                    terraform apply -auto-approve
                    '''
                }
            }
        }

        stage('Generate Ansible Inventory') {
            steps {
                script {
                    def output = sh(script: 'terraform output -json', returnStdout: true).trim()
                    def tfOutput = readJSON text: output

                    if (!tfOutput?.tomcat_server_ip?.value || !tfOutput?.mysql_server_ip?.value || !tfOutput?.maven_server_ip?.value) {
                        error "❌ One or more Terraform outputs are missing."
                    }

                    def tomcatIp = tfOutput.tomcat_server_ip.value
                    def mysqlIp = tfOutput.mysql_server_ip.value
                    def mavenIp = tfOutput.maven_server_ip.value

                    writeFile file: 'ansible/inventory.ini', text: """
[tomcat_server]
${tomcatIp} ansible_user=ubuntu ansible_ssh_private_key_file=${SSH_PRIVATE_KEY_PATH}

[mysql_server]
${mysqlIp} ansible_user=ubuntu ansible_ssh_private_key_file=${SSH_PRIVATE_KEY_PATH}

[maven_server]
${mavenIp} ansible_user=ubuntu ansible_ssh_private_key_file=${SSH_PRIVATE_KEY_PATH}
"""
                }
            }
        }

        stage('Verify Ansible Connectivity') {
            steps {
                sh 'ansible -i ansible/inventory.ini all -m ping'
            }
        }

        stage('Server Setup with Ansible') {
            steps {
                sh 'ansible-playbook -i ansible/inventory.ini ansible/setup.yml'
            }
        }

        stage('Build Application on Maven Server') {
            steps {
                sh '''
                ansible maven_server -i ansible/inventory.ini -m shell -a '
                    cd /home/ubuntu/spring-petclinic &&
                    mvn clean package
                '
                '''
            }
        }

        stage('Deploy WAR to Tomcat') {
            steps {
                script {
                    def tomcatIp = sh(script: "terraform output -raw tomcat_server_ip", returnStdout: true).trim()
                    def mavenIp = sh(script: "terraform output -raw maven_server_ip", returnStdout: true).trim()

                    sh """
                    ssh -o StrictHostKeyChecking=no -i ${SSH_PRIVATE_KEY_PATH} ubuntu@${mavenIp} \
                        'scp -o StrictHostKeyChecking=no /home/ubuntu/spring-petclinic/target/spring-petclinic.war ubuntu@${tomcatIp}:/opt/tomcat/webapps/'
                    """

                    sh "ansible tomcat_server -i ansible/inventory.ini -m systemd -a 'name=tomcat state=restarted'"
                }
            }
        }
    }

    post {
        success {
            echo "✅ Deployment completed successfully!"
        }
        failure {
            echo "❌ Deployment failed!"
        }
    }
}
