FROM ubuntu:22.04

COPY docker.gpg /usr/share/keyrings
COPY docker.list /etc/apt/sources.list.d

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

RUN sed -i -e 's_http://archive._http://de.archive._g' /etc/apt/sources.list \
        && apt-get update \
        && DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates locales lsb-release \
        && sed -i -e "s/# $LANG UTF-8/$LANG UTF-8/" /etc/locale.gen \
        && dpkg-reconfigure --frontend=noninteractive locales \
        && update-locale LANG=en_US.UTF-8 \
        && apt-get update \
        && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        bash-completion \
        curl \
        git \
        golang \
        sudo \
        vim \
        wget \
        nano \
        lsof \
        libssl-dev \
        jq curl rsync \
        stow \
        openjdk-19-jdk-headless maven \
        npm \
        zsh \
        clang \
        python3-pip r-base \
        && rm -rf /var/lib/apt/lists/*

# Add Docker's official GPG key and repository
RUN apt-get update \
        && apt-get install -y ca-certificates curl \
        && install -m 0755 -d /etc/apt/keyrings \
        && curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc \
        && chmod a+r /etc/apt/keyrings/docker.asc \
        && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
        && apt-get update \
        && apt-get install -y docker-ce docker-ce-cli containerd.io \
        && ln -s /usr/libexec/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose

### Give CA Cert of Clinic
COPY klima-ca.klima.ads.local_klima-ca.crt /usr/local/share/ca-certificates/
COPY klima-ca.klima.ads.local_klima-ca.pem /usr/local/share/ca-certificates/
RUN chmod 644 /usr/local/share/ca-certificates/klima-ca.klima.ads.local_klima-ca.pem
RUN chmod 644 /usr/local/share/ca-certificates/klima-ca.klima.ads.local_klima-ca.crt
RUN update-ca-certificates

# Required for Lens, see https://github.com/samply/lens; uses package npm
RUN npm -g install prettier @angular/cli

RUN curl -fsSL https://code-server.dev/install.sh | bash -s

RUN echo "source /verbis/functions.sh" >> /etc/bash.bashrc

ARG USER=coder
RUN useradd --groups sudo,docker --no-create-home --shell /bin/bash ${USER} \
        && echo "${USER} ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/${USER} \
        && chmod 0440 /etc/sudoers.d/${USER}

COPY profile /home/${USER}/.profile
COPY github-ssh-config /etc/ssh/ssh_config.d/github.conf
COPY config.toml /home/${USER}/.cargo/config.toml

RUN mkdir /mnt/cache \
        && chown $USER:$USER /mnt/cache \
        && chown $USER:$USER /home/${USER} /home/${USER}/.profile /home/${USER}/.cargo /home/${USER}/.cargo/config.toml

RUN bash -c 'curl -L $(curl -s https://api.github.com/repos/rui314/mold/releases/latest | jq -r ".assets[] | select (.name | contains(\"x86_64\")) | .browser_download_url") | tar -C /usr/local --strip-components=1 --no-overwrite-dir -xzf -'

RUN pip3 --no-cache-dir install jupyterlab && \
        jupyter labextension disable "@jupyterlab/apputils-extension:announcements" && \
        Rscript -e "install.packages('IRkernel')" && \
        Rscript -e "IRkernel::installspec(user = FALSE)"

RUN mkdir /ccp && \
        chown ${USER}:${USER} /ccp

COPY --from=samply/beam-file /usr/local/bin/beam-file /usr/bin/beam-file

USER ${USER}
WORKDIR /home/${USER}

RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

RUN curl -sSf https://sh.rustup.rs | bash -s -- -y

COPY functions.sh /verbis/functions.sh

RUN bash -c 'source /verbis/functions.sh && \
        verbis_install_vscode_extensions rust-lang.rust-analyzer serayuzgur.crates vadimcn.vscode-lldb'

RUN bash -c 'source ~/.profile && cargo install cargo-binstall cargo-outdated'
