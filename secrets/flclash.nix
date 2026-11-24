{ mysecrets, myvars, ... }:
{
  age.secrets.flclash-subscriptions = {
    file = "${mysecrets}/flclash-subscriptions.json.age";
    mode = "0400";
    owner = myvars.username;
  };
}
