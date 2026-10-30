# syntax=docker/dockerfile:1

# 本番用イメージ。特定の置き場所（Kamal / PaaS など）に依存させず、設定はすべて環境変数で受け取る。
#
#   docker build -t zentoo-api apps/api
#
# 必要な環境変数: SECRET_KEY_BASE, JWT_SECRET_KEY, DATABASE_URL（または DB_HOST / DB_PORT / DB_USER / DB_PASSWORD / DB_NAME）
# 起動時に bin/docker-entrypoint が db:prepare を実行する（DB の作成とマイグレーション）。
# DB が空の初回起動では seed も実行されるため、そのときだけ SEED_USER_PASSWORD（ログインユーザーのパスワード）が必須。

ARG RUBY_VERSION=3.4.7
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

WORKDIR /rails

# postgresql-client: db:prepare が db/structure.sql を psql で読み込むために必要
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libpq5 libvips postgresql-client && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test"

# ビルド用のステージ（gem のビルドに必要なパッケージは最終イメージに入れない）
FROM base AS build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libpq-dev libyaml-dev pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

COPY . .

RUN bundle exec bootsnap precompile app/ lib/

# 最終イメージ
FROM base

COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

# root 以外で実行する
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    chown -R rails:rails db log storage tmp
USER 1000:1000

ENTRYPOINT ["/rails/bin/docker-entrypoint"]

EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD curl -fsS "http://localhost:${PORT:-3000}/up" || exit 1

CMD ["./bin/rails", "server"]
