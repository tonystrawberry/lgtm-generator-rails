FROM public.ecr.aws/lambda/ruby:2.7

RUN yum groupinstall -y 'Development Tools'

RUN yum install -y libmagickwand-devel libtool-ltdl-devel libjpeg-turbo-devel libpng-devel pkgconfig glibc ghostscript

ENV PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:/usr/lib/pkgconfig

RUN curl https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-1.2.4.tar.gz --output libwebp-1.2.4.tar.gz \
    && tar xvzf libwebp-1.2.4.tar.gz\
    && cd libwebp-1.2.4 \
    && ./configure \
    && make \
    && make install \
    && /sbin/ldconfig /usr/local/lib

RUN git clone https://github.com/ImageMagick/ImageMagick.git ImageMagick-7.1.0
RUN cd ImageMagick-7.1.0\
 && ./configure CPPFLAGS='-I/opt/local/include' LDFLAGS='-L/opt/local/lib' \
                --prefix=/usr \
                --without-perl \
                --with-modules \
                --without-magick-plus-plus \
                --disable-static \
                --disable-docs \
                --with-jpeg=yes \
                --with-jp2=yes \
                --with-png=yes \
                --with-webp=yes \
                --with-gslib=yes \
 && make\
 && make install\
 && /sbin/ldconfig /usr/local/lib

# Copy function code
COPY app.rb ${LAMBDA_TASK_ROOT}

# Copy dependency management file
COPY Gemfile ${LAMBDA_TASK_ROOT}

# Install dependencies under LAMBDA_TASK_ROOT
ENV GEM_HOME=${LAMBDA_TASK_ROOT}

RUN bundle install

# Set the CMD to your handler (could also be done as a parameter override outside of the Dockerfile)
CMD [ "app.LambdaFunction::Handler.process" ]
