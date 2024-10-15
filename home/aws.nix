{ ... }:
{
  programs.awscli = {
    enable = false;
    settings =
      let
        region = "eu-west-1";
        mkProfile = id: {
          sso_session = "travelchapter";
          sso_account_id = id;
          sso_role_name = "TC-Developer-Access-Dev";
          region = region;
          output = "json";
        };
      in
      {
        "sso-session travelchapter" = {
          sso_start_url = "https://travelchapter.awsapps.com/start";
          sso_region = region;
          sso_registration_scopes = "sso:account:access";
        };
        "profile data-dev" = mkProfile "327913457104";
        "profile hub-dev" = mkProfile "809561633273";
      };
  };
}
