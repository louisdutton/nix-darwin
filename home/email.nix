{ user, ... }:
{
  programs.neomutt.enable = true;
  # programs.mbsync.enable = true;
  # programs.msmtp.enable = true;
  # programs.notmuch = {
  #   enable = true;
  #   hooks = {
  #     preNew = "mbsync --all";
  #   };
  # };
  # accounts.email = {
  #   maildirBasePath = "maildir";
  #
  #   accounts.givetree =
  #     let
  #       address = "l.dutton@givetree.com";
  #       realName = user.displayName;
  #       signature = {
  #         text = ''
  #           Best,\n
  #           ${user.displayName}
  #         '';
  #         showSignature = "append";
  #       };
  #     in
  #     {
  #       inherit address realName signature;
  #       flavor = "gmail.com";
  #       userName = address;
  #       primary = true;
  #       imap.host = "imap.gmail.com";
  #       smtp.host = "smtp.gmail.com";
  #       # gpg = {
  #       #   key = "F9119EC8FCC56192B5CF53A0BF4F64254BD8C8B5";
  #       #   signByDefault = true;
  #       # };
  #       passwordCommand = "mail-password";
  #       msmtp.enable = true;
  #       neomutt.enable = true;
  #
  #       notmuch = {
  #         enable = true;
  #         neomutt.enable = true;
  #       };
  #
  #       mbsync = {
  #         enable = true;
  #         create = "maildir";
  #       };
  #
  #       folders = {
  #         drafts = "drafts";
  #         inbox = "inbox";
  #         sent = "sent";
  #         trash = "trash";
  #       };
  #     };
  # };
}
