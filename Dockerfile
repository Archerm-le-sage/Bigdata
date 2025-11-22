# Dockerfile pour Ansible sur Ubuntu
FROM ubuntu:22.04

# Évite les prompts interactifs
ENV DEBIAN_FRONTEND=noninteractive

# Installe Ansible et les outils nécessaires
RUN apt-get update && \
    apt-get install -y software-properties-common sshpass git python3 python3-pip && \
    apt-add-repository --yes --update ppa:ansible/ansible && \
    apt-get install -y ansible && \
    pip3 install google-auth google-auth-httplib2 google-auth-oauthlib

# Dossier de travail dans le conteneur
WORKDIR /ansible

# Par défaut : ouvre un shell
CMD ["/bin/bash"]
