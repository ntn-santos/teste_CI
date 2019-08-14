# Use a Java SDK 8 base image.
# ---------------------------------------------------
FROM frolvlad/alpine-oraclejdk8:slim


# Define variables used in Dockerfile
# ---------------------------------------------------
ARG GRADLE_USER_HOME='/root/.gradle'
ARG ANDROID_HOME='/opt/android-sdk'
ARG ANDROID_SDK_PLATFORM=27
ARG ANDROID_SDK_TOOLS_VERSION=3859397
ARG ANDROID_BUILD_TOOLS_VERSION=28.0.3
ARG ANDROID_GRADLE_VERSION=4.6
ARG INSTALL_UPDATES=false
ARG INSTALL_ANDROID_M2REPOSITORY=false
ARG INSTALL_GOOGLE_M2REPOSITORY=false
ARG INSTALL_GOOGLE_PLAY_SERVICES=false


# Define PATH variables
# ---------------------------------------------------
ENV PATH="${PATH}:${ANDROID_HOME}/tools:${ANDROID_HOME}/tools/bin:${ANDROID_HOME}/platform-tools:${ANDROID_HOME}/build-tools/${ANDROID_BUILD_TOOLS_VERSION}"


# Define /var/www as working dir
# ---------------------------------------------------
WORKDIR /var/www
COPY  . /var/www
VOLUME  /var/www


# One run for everything
# ---------------------------------------------------
RUN \
# Define some colors used
export COLOR_OFF='\033[0m' && \
export YELLOW='\033[0;33m' && \
export BOLD_YELLOW='\033[1;33m' && \
# Install essential software
# ---------------------------------------------------
echo -e "\n\n${BOLD_YELLOW}[DevOps]${YELLOW} Instalando softwares essenciais e limpando cache do apk${COLOR_OFF}" && \
apk add --no-cache \
  bash \
  libstdc++ \
  unzip \
  wget && \
  rm -rf /var/cache/apk/* && \
\
# Environment files
# ---------------------------------------------------
# Create env files from env examples and import
# variables in current execution.
echo -e "\n\n${BOLD_YELLOW}[DevOps]${YELLOW} Importando variáveis de arquivos env${COLOR_OFF}" && \
cp .env.example .env && \
cp .gitlab.env.example .gitlab.env && \
source $(pwd)/.gitlab.env && \
echo -e "Arquivo .gitlab.env importado." && \
\
# Install Android SDK
# ---------------------------------------------------
# Verifica se existe a SDK do Android na pasta atual e
# faz download se for necessário. Em seguida, faz a extração
# na pasta do Android do PATH do usuário.
if [ -e sdk-tools-linux-${ANDROID_SDK_TOOLS_VERSION}.zip ]; then \
  cp sdk-tools-linux-${ANDROID_SDK_TOOLS_VERSION}.zip android-sdk.zip; \
else \
  echo -e "\n\n${BOLD_YELLOW}[DevOps]${YELLOW} Fazendo download e instalando Android SDK${COLOR_OFF}" && \
  wget ${ANDROID_SDK_DOWNLOAD_PATH:-'https://dl.google.com/android/repository'}/sdk-tools-linux-${ANDROID_SDK_TOOLS_VERSION}.zip \
    --http-user=${SOMA_DOWNLOAD_USER} \
    --http-password=${SOMA_DOWNLOAD_PASSWORD} \
    --output-document='android-sdk.zip' \
    --no-check-certificate \
    --quiet; \
fi && \
mkdir -p ${ANDROID_HOME} && \
unzip -q android-sdk.zip -d ${ANDROID_HOME} && \
rm android-sdk.zip && \
echo -e "Android SDK instalado com sucesso." && \
\
# Licenses and installation
# ---------------------------------------------------
# Accepts all SDK Manager installation licenses, then
# installs the SDK platform and build tools specified
# in Dockerfile environment variables.
echo -e "\n\n${BOLD_YELLOW}[DevOps]${YELLOW} Aceitando licenças do Android SDK Manager${COLOR_OFF}" && \
yes | sdkmanager --licenses &>/dev/null && \
echo -e "Licenças do SDK Manager aceitas." && \
echo -e "\n\n${BOLD_YELLOW}[DevOps]${YELLOW} Instalando platforms e build-tools com SDK Manager${COLOR_OFF}" && \
mkdir -p /root/.android && \
touch /root/.android/repositories.cfg && \
sdkmanager --verbose "platforms;android-${ANDROID_SDK_PLATFORM}" && \
sdkmanager --verbose "build-tools;${ANDROID_BUILD_TOOLS_VERSION}" && \
\
# Install Android M2 Repository
# ---------------------------------------------------
if [ ${INSTALL_ANDROID_M2REPOSITORY} == true ]; then \
  sdkmanager --verbose "extras;android;m2repository"; \
fi && \
\
# Install Google Repository
# ---------------------------------------------------
if [ ${INSTALL_GOOGLE_M2REPOSITORY} == true ]; then \
  sdkmanager --verbose "extras;google;m2repository"; \
fi && \
\
# Install Google Play Services
# ---------------------------------------------------
if [ ${INSTALL_GOOGLE_PLAY_SERVICES} == true ]; then \
  sdkmanager --verbose "extras;google;google_play_services"; \
fi && \
\
# Install SDK updates
# ---------------------------------------------------
if [ ${INSTALL_UPDATES} == true ]; then \
  sdkmanager --update --verbose; \
fi && \
echo -e "Pacotes instalados com sucesso." && \
\
# Download Gradle
# ---------------------------------------------------
echo -e "\n\n${BOLD_YELLOW}[DevOps]${YELLOW} Fazendo download e instalando Gradle${COLOR_OFF}" && \
wget ${GRADLE_DOWNLOAD_PATH}/gradle-${ANDROID_GRADLE_VERSION}-all.zip \
  --http-user=${SOMA_DOWNLOAD_USER} \
  --http-password=${SOMA_DOWNLOAD_PASSWORD} \
  --quiet && \
unzip -q gradle-${ANDROID_GRADLE_VERSION}-all.zip && \
rm -rf gradle-${ANDROID_GRADLE_VERSION}-all.zip && \
echo -e "Gradle instalado com sucesso." && \
\
# API Json Download
# ---------------------------------------------------
echo -e "\n\n${BOLD_YELLOW}[DevOps]${YELLOW} Fazendo download do JSON da API PlayStore${COLOR_OFF}" && \
wget ${JSON_DOWNLOAD_PATH}/api.json \
  --http-user=${SOMA_DOWNLOAD_USER} \
  --http-password=${SOMA_DOWNLOAD_PASSWORD} \
  --quiet && \
echo -e "Download do JSON API realizado com sucesso." && \
find / -type f -name 'api.json' && \
\
# Keystore Download
# ---------------------------------------------------
echo -e "\n\n${BOLD_YELLOW}[DevOps]${YELLOW} Fazendo download da keystore${COLOR_OFF}" && \
wget ${KEYSTORE_DOWNLOAD_PATH}/cpos.keystore \
  --http-user=${SOMA_DOWNLOAD_USER} \
  --http-password=${SOMA_DOWNLOAD_PASSWORD} \
  --quiet && \
echo -e "Download da keystore realizada com sucesso." && \
\
# Build with Gradle
# ---------------------------------------------------
echo -e "\n\n${BOLD_YELLOW}[DevOps]${YELLOW} Realizando build com Gradle${COLOR_OFF}" && \
/var/www/gradle-${ANDROID_GRADLE_VERSION}/bin/gradle \
  assembleDevelop \
  --project-prop buildDir=./builds \
  --project-prop GITLAB_CI=${GITLAB_CI} && \
echo -e "Build com gradle finalizado com sucesso." && \
\
# APK optimize with ZipAlign
# ---------------------------------------------------
 echo -e "\n\n${BOLD_YELLOW}[DevOps]${YELLOW} Otimizando APK com ZipAlign${COLOR_OFF}" && \
 zipalign -p 4 \
   /var/www/app/builds/outputs/apk/develop/release/app-develop-release.apk \
   /var/www/app/builds/outputs/apk/develop/release/cpos-android.apk && \
 echo -e "APK otimizada com sucesso." && \
 cp /var/www/app/builds/outputs/apk/develop/release/cpos-android.apk /

CMD tail -f /dev/null
