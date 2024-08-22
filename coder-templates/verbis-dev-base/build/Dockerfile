FROM ubuntu:22.04

COPY docker.gpg cran.asc /usr/share/keyrings
COPY docker.list r.list /etc/apt/sources.list.d

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

RUN sed -i -e 's_http://archive._http://de.archive._g' /etc/apt/sources.list \
	&& apt-get update \
	&& DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates locales \
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
	docker-ce \
	stow \
	openjdk-19-jdk-headless maven \
	npm \
	zsh \
	clang \
	python3-pip r-base \
	libclang-14-dev libclang-dev psmisc lsb-release \
	r-cran-lme4 libcurl4-openssl-dev \
	&& ln -s /usr/libexec/docker/cli-plugins/docker-compose /usr/local/bin/ \
	&& rm -rf /var/lib/apt/lists/*

# Req'd for Lens, see https://github.com/samply/lens; uses package npm
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

RUN	pip3 --no-cache-dir install jupyterlab && \
	jupyter labextension disable "@jupyterlab/apputils-extension:announcements" && \
	Rscript -e "install.packages('IRkernel')" && \
	Rscript -e "IRkernel::installspec(user = FALSE)"

RUN	mkdir /ccp && \
	chown ${USER}:${USER} /ccp

# <RStudio Server>

RUN cd $(mktemp -d) && \
	wget https://download2.rstudio.org/server/jammy/amd64/rstudio-server-2024.04.2-764-amd64.deb && \
	dpkg -i rstudio-server-2024.04.2-764-amd64.deb && \
	rm rstudio-server-2024.04.2-764-amd64.deb && \
	find /var/lib/rstudio-server -user rstudio-server -exec chown -v coder:coder {} \; && \
	mkdir /home/${USER}/.rserver && \
	chown ${USER}:${USER} /home/${USER}/.rserver

RUN cat <<EOF >> /etc/rstudio/rserver.conf
server-pid-file=/tmp/rstudio-server.pid
#www-frame-origin=same
# Run rstudio data in user home directory as coder user
server-user=${USER}
server-data-dir=/home/${USER}/.rstudio/data
database-config-file=/etc/rstudio/database.conf
EOF

RUN cat <<EOF >> /etc/rstudio/database.conf
# Database conf
provider=sqlite
directory=/home/${USER}/.rstudio
EOF

# </RStudio Server>

COPY --from=samply/beam-file:task-based-files /usr/local/bin/beam-file /usr/bin/beam-file
COPY --from=samply/beam-connect:develop /usr/local/bin/beam-connect /usr/bin/beam-connect

USER ${USER}
WORKDIR /home/${USER}

RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

RUN curl -sSf https://sh.rustup.rs | bash -s -- -y

COPY functions.sh /verbis/functions.sh

RUN bash -c 'source /verbis/functions.sh && \
	verbis_install_vscode_extensions rust-lang.rust-analyzer serayuzgur.crates vadimcn.vscode-lldb'

RUN bash -c 'source ~/.profile && cargo install cargo-binstall cargo-outdated'
