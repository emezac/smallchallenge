FROM ruby:3.4.1-slim AS build
RUN apt-get update && apt-get install -y --no-install-recommends build-essential libyaml-dev pkg-config && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY Gemfile Gemfile.lock ./
RUN gem install bundler -v 4.0.11 --no-document && bundle config set deployment true && bundle install

FROM ruby:3.4.1-slim
WORKDIR /app
RUN groupadd --gid 10001 gateway && useradd --uid 10001 --gid gateway --no-create-home gateway
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /app/vendor/bundle /app/vendor/bundle
COPY --chown=gateway:gateway . .
RUN mkdir -p storage log tmp && chown -R gateway:gateway storage log tmp
ENV BUNDLE_PATH=/app/vendor/bundle BUNDLE_DEPLOYMENT=true RAILS_ENV=production
USER gateway
CMD ["bundle", "exec", "ruby", "bin/server", "-C", "config/puma.rb"]
