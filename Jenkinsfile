pipeline {
    agent any

    tools {
        terraform 'ttff'
        ansible 'aann'
        maven 'mmvvnn'
    }

    environment {
        AWS_ACCESS_KEY = credentials('AWS_ACCESS_KEY')
        AWS_SECRET_KEY = credentials('AWS_SECRET_ACCESS_KEY')
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

        stage('Generate Inventory') {
            steps {
                script {
                    sh """
                        echo "[tomcat_server]" > inventory
                        echo "\$(terraform output -raw tomcat_server_ip) ansible_user=ubuntu ansible_ssh_private_key_file=\${SSH_KEY_FILE} ansible_python_interpreter=/usr/bin/python3" >> inventory

                        echo "" >> inventory
                        echo "[mysql_server]" >> inventory
                        echo "\$(terraform output -raw mysql_server_ip) ansible_user=ubuntu ansible_ssh_private_key_file=\${SSH_KEY_FILE} ansible_python_interpreter=/usr/bin/python3" >> inventory

                        echo "" >> inventory
                        echo "[maven_server]" >> inventory
                        echo "\$(terraform output -raw maven_server_ip) ansible_user=ubuntu ansible_ssh_private_key_file=\${SSH_KEY_FILE} ansible_python_interpreter=/usr/bin/python3" >> inventory
                    """
                }
            }
        }

        stage('Verify Ansible Connectivity') {
            steps {
                script {
                    // Fetch IP addresses from Terraform
                    def tomcatServerIp = sh(script: "terraform output -raw tomcat_server_ip", returnStdout: true).trim()
                    def mysqlServerIp = sh(script: "terraform output -raw mysql_server_ip", returnStdout: true).trim()
                    def mavenServerIp = sh(script: "terraform output -raw maven_server_ip", returnStdout: true).trim()

                    // Map of servers
                    def servers = [
                        "tomcat_server": tomcatServerIp,
                        "mysql_server" : mysqlServerIp,
                        "maven_server" : mavenServerIp
                    ]

                    def retries = 0
                    def maxRetries = 30
                    def waitTime = 10

                    def reachableServers = [:]
                    servers.each { name, ip -> reachableServers[name] = false }

                    // Retry loop
                    while (reachableServers.containsValue(false) && retries < maxRetries) {
                        servers.each { name, ip ->
                            if (!reachableServers[name]) {
                                withCredentials([sshUserPrivateKey(credentialsId: 'mujahed-ssh-key', keyFileVariable: 'SSH_KEY_FILE', usernameVariable: 'SSH_USER')]) {
                                    def result = sh(script: """
                                        ssh -o BatchMode=yes -o StrictHostKeyChecking=no -i \$SSH_KEY_FILE \$SSH_USER@${ip} 'echo SSH connected'
                                    """, returnStatus: true)

                                    if (result == 0) {
                                        echo "${name} (${ip}) is reachable via SSH."
                                        reachableServers[name] = true
                                    } else {
                                        echo "${name} (${ip}) is not reachable via SSH yet. Retrying."
                                    }
                                }
                            }
                        }

                        if (reachableServers.containsValue(false)) {
                            retries++
                            echo "Attempt ${retries}/${maxRetries} failed. Waiting for unreachable servers..."
                            sleep(waitTime)
                        }
                    }

                    // Exit if any are still unreachable
                    if (reachableServers.containsValue(false)) {
                        error "Some EC2 instances are not reachable via SSH after ${maxRetries} attempts."
                    }

                    // All reachable — run Ansible ping
                    echo "All servers are reachable via SSH. Running Ansible Ping..."
                    withCredentials([sshUserPrivateKey(credentialsId: 'mujahed-ssh-key', keyFileVariable: 'SSH_KEY_FILE', usernameVariable: 'SSH_USER')]) {
                        sh """
                            ansible -i inventory all -m ping
                        """
                    }
                }
            }
        }
    }


               stage('Run Ansible Setup') {
            steps {
                script {
                    sh """
                        ansible-playbook -i inventory setup.yml
                    """
                }
            }
        }

        stage('Build WAR with Maven') {
            steps {
                script {
                    sh """
                        ssh -o StrictHostKeyChecking=no -i ${SSH_PRIVATE_KEY_PATH} ubuntu@\$(terraform output -raw maven_server_ip) '
                            cd /home/ubuntu/app &&
                            mvn clean package
                        '
                    """
                }
            }
        }

        stage('Deploy WAR to Tomcat') {
            steps {
                script {
                    sh """
                        ansible-playbook -i inventory deploy.yml
                    """
                }
            }
        }
    }

    post {
        success {
            echo '✅ Pipeline executed successfully!'
        }
        failure {
            echo '❌ Pipeline failed. Check logs for details.'
        }
    }
}
