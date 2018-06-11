FROM fedora:28

EXPOSE 80

ENV KERNEL linux-4.17
ENV MODULE fs/ext2
ENV CURRENT_KERNEL /spec-utils/$KERNEL
ENV CURRENT_PROJECT $CURRENT_KERNEL/$MODULE

COPY . spec-utils
WORKDIR spec-utils 

RUN dnf update  -y                                             && \
    dnf install -y @development-tools graphviz wget xz            \
        bison flex elfutils-libelf-devel bc openssl-devel         \
        redhat-rpm-config which                                && \
    dnf install -y perl-App-cpanminus perl-Pod-Checker         && \
    dnf install -y $(scripts/fedora-list-deps $(pwd)/cpanfile) && \
    dnf autoremove -y;                                            \
    dnf clean all
RUN cpanm --force --notest --with-all-features --local-lib extlib --installdeps .
RUN pip3 install lizard

RUN wget --quiet https://cdn.kernel.org/pub/linux/kernel/v4.x/$KERNEL.tar.xz && \
    tar xf $KERNEL.tar.xz && \
    rm $KERNEL.tar.xz;       \
    cd $KERNEL;              \ 
    make defconfig        && \
    make modules_prepare

ENV GRAPH_CONFIG .config.sample

RUN perl -Mlocal::lib=extlib bin/complexity_plan --kernel $CURRENT_KERNEL \
                             --module $CURRENT_PROJECT --mname ext2       \
                             --status config/status_ext2.conf.sample      \
                             --priority config/priority_ext2.conf.sample  \
                             --format sqlite --force                      \
                             --output web/ext2.db

CMD perl -Mlocal::lib=extlib /usr/bin/starman --port 80 --workers 1 \
                            --access-log web/access.log             \
                            --error-log web/error.log               \
                            web/graph.psgi
