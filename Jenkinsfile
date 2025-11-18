pipeline {
  agent { label 'kaniko' }

  environment {
    // AWS / ECR
    AWS_REGION = 'us-west-2'
    ECR_REPO   = 'lesson-5-ecr' // Must match Terraform ECR module name

    // Paths
    APP_CONTEXT = 'backend-source/app' // build context with Dockerfile
    CHART_PATH  = 'charts/node-app/values.yaml' // chart values to update

    // Computed at runtime
    ACCOUNT_ID = ''
    ECR_REG    = ''
    IMAGE_TAG  = "${env.BUILD_NUMBER}"
    IMAGE      = ''
  }

  options {
    timestamps()
    disableConcurrentBuilds()
  }

  stages {
    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Resolve ECR registry') {
      steps {
        withCredentials([
          usernamePassword(credentialsId: 'aws-creds', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')
        ]) {
          sh '''
          set -euo pipefail
          ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
          echo "ACCOUNT_ID=${ACCOUNT_ID}" > .ecr_env
          echo "ECR_REG=${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com" >> .ecr_env
          '''
        }
        script {
          def envMap = readProperties file: '.ecr_env'
          env.ACCOUNT_ID = envMap['ACCOUNT_ID']
          env.ECR_REG    = envMap['ECR_REG']
          env.IMAGE      = "${env.ECR_REG}/${env.ECR_REPO}:${env.IMAGE_TAG}"
        }
      }
    }

    stage('Build & Push (Kaniko)') {
      environment {
        DOCKER_CONFIG = '/kaniko/.docker/'
      }
      steps {
        withCredentials([
          usernamePassword(credentialsId: 'aws-creds', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')
        ]) {
          sh '''
          set -euo pipefail
          mkdir -p /kaniko/.docker

          # Create ECR auth in Docker config for Kaniko
          PASSWORD=$(aws --region "$AWS_REGION" ecr get-login-password)
          AUTH=$(printf "AWS:%s" "$PASSWORD" | base64 | tr -d '\n')
          cat > /kaniko/.docker/config.json <<JSON
          {"auths": {"$ECR_REG": {"username": "AWS", "password": "$PASSWORD", "auth": "$AUTH"}}}
JSON

          /kaniko/executor \
            --context "$WORKSPACE/$APP_CONTEXT" \
            --dockerfile Dockerfile \
            --destination "$IMAGE" \
            --single-snapshot
          '''
        }
      }
    }

    stage('Update Helm chart image reference') {
      steps {
        sh '''
        set -euo pipefail
        # Replace placeholder repository once, keep updating tag each run
        if grep -q 'REPLACE_ME_ECR_REPOSITORY' "$CHART_PATH"; then
          sed -i "s|REPLACE_ME_ECR_REPOSITORY|$ECR_REG/$ECR_REPO|" "$CHART_PATH"
        fi
        # Update tag line safely (use POSIX character class for whitespace)
        sed -i "s/^[[:space:]]*tag:.*/  tag: $IMAGE_TAG/" "$CHART_PATH"
        '''
      }
    }

    stage('Commit & Push changes') {
      steps {
        withCredentials([
          usernamePassword(credentialsId: 'git-creds', usernameVariable: 'GIT_USER', passwordVariable: 'GIT_PASS')
        ]) {
          sh '''
          set -euo pipefail
          git config user.email "ci@jenkins.local"
          git config user.name  "jenkins-ci"
          git add "$CHART_PATH"
          git commit -m "chore(ci): update image tag to $IMAGE_TAG" || echo "No changes to commit"

          ORIGIN_URL=$(git remote get-url origin)
          if echo "$ORIGIN_URL" | grep -q '^https://'; then
            AUTH_URL=$(echo "$ORIGIN_URL" | sed -E "s#https://#https://$GIT_USER:$GIT_PASS@#")
            git push "$AUTH_URL" HEAD:main
          else
            # Assume SSH remote is configured in Jenkins environment
            git push origin HEAD:main
          fi
          '''
        }
      }
    }
  }

  post {
    success {
      echo "Build pushed: ${env.IMAGE}. Chart updated and pushed to main."
    }
    failure {
      echo 'Pipeline failed. Check Kaniko build, AWS credentials, and Git push permissions.'
    }
    cleanup {
      sh 'rm -f .ecr_env || true'
    }
  }
}
