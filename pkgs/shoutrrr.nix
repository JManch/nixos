{ lib
, buildGoModule
, fetchFromGitHub
}:
buildGoModule rec {
  pname = "shoutrrr";
  version = "0.8.0";

  src = fetchFromGitHub {
    repo = "shoutrrr";
    owner = "containrrr";
    rev = "v${version}";
    sha256 = "sha256-DGyFo2oRZ39r1awqh5AXjOL2VShABarFbOMIcEXlWq4=";
  };

  vendorHash = "sha256-+LDA3Q6OSxHwKYoO5gtNUryB9EbLe2jJtUbLXnA2Lug=";

  meta = with lib; {
    description = "Notification library";
    homepage = "https://github.com/containrrr/shoutrrr";
    license = licenses.mit;
    maintainers = with maintainers; [ JManch ];
    platforms = platforms.linux;
    mainProgram = "shoutrrr";
  };
}
