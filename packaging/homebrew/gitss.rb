class Gitss < Formula
  desc "GitSScan CLI to scan repositories and inspect Git status"
  homepage "https://github.com/previraza/gitsscan"
  url "https://github.com/previraza/gitsscan/releases/download/v3.0.0/gitss_3.0.0_linux_amd64.tar.gz"
  sha256 "REPLACE_SHA256"
  license "MIT"

  def install
    bin.install "gitss_3.0.0_linux_amd64/bin/gitss" => "gitss"
    (libexec/"gitss/lib").install Dir["gitss_3.0.0_linux_amd64/lib/*"]
    bash_completion.install "gitss_3.0.0_linux_amd64/completions/gitss.bash" => "gitss"

    inreplace bin/"gitss", %r{^GITSS_ROOT=.*$}, "GITSS_ROOT=\"#{libexec}/gitss\""
  end

  test do
    system "#{bin}/gitss", "--version"
  end
end
