defmodule Teiserver.SpringTokenTest do
  use Central.ServerCase, async: false
  require Logger
  alias Central.Helpers.GeneralTestLib

  import Teiserver.TeiserverTestLib,
    only: [tls_setup: 0, raw_setup: 0, _send_raw: 2, _recv_raw: 1, _recv_until: 1]

  test "c.user.get_token - insecure" do
    %{socket: socket} = raw_setup()
    _welcome = _recv_raw(socket)

    # Get by email
    _send_raw(socket, "c.user.get_token_by_email token_test_user@\ttoken_password\n")
    reply = _recv_raw(socket)

    assert reply ==
             "NO cmd=c.user.get_token_by_email\tcannot get token over insecure connection\n"

    # Now get by name
    _send_raw(socket, "c.user.get_token_by_name token_test_user@\ttoken_password\n")
    reply = _recv_raw(socket)

    assert reply == "NO cmd=c.user.get_token_by_name\tcannot get token over insecure connection\n"

    _send_raw(socket, "EXIT\n")
    _recv_raw(socket)
  end

  test "c.user.get_token_by_email - correct" do
    user =
      GeneralTestLib.make_user(%{
        "name" => "token_test_user",
        "email" => "token_test_user@",
        "password" => "token_password",
        "data" => %{
          "verified" => true
        }
      })

    Teiserver.User.recache_user(user.id)

    %{socket: socket} = tls_setup()
    _welcome = _recv_raw(socket)

    _send_raw(socket, "c.user.get_token_by_email token_test_user@\ttoken_password\n")
    reply = _recv_until(socket)
    assert reply =~ "s.user.user_token token_test_user@\t"

    token =
      String.replace(reply, "s.user.user_token token_test_user@\t", "")
      |> String.replace("\n", "")

    assert token != ""

    # Now do it by name and check results
    _send_raw(socket, "c.user.get_token_by_name token_test_user\ttoken_password\n")
    reply = _recv_raw(socket)
    assert reply =~ "s.user.user_token token_test_user\t"

    token2 =
      String.replace(reply, "s.user.user_token token_test_user\t", "")
      |> String.replace("\n", "")

    assert token2 != ""

    # Token 1 and 2 will almost certainly be different, instead we
    # check to ensure they pull back the same user
    {:ok, user1, _claims} = Central.Account.Guardian.resource_from_token(token)
    {:ok, user2, _claims} = Central.Account.Guardian.resource_from_token(token)

    assert user1.id == user.id
    assert user2.id == user.id

    # Exit this socket, we need to be sure it'll work with a new (insecure) socket
    _send_raw(socket, "EXIT\n")
    _recv_raw(socket)

    # New socket!
    %{socket: socket} = raw_setup()
    _welcome = _recv_raw(socket)

    _send_raw(socket, "c.user.login #{token}\tLobby Name\n")
    reply = _recv_raw(socket)
    assert reply =~ "ACCEPTED token_test_user\n"

    _send_raw(socket, "EXIT\n")
    _recv_raw(socket)
  end

  test "c.user.login - bad token" do
    %{socket: socket} = raw_setup()
    _welcome = _recv_raw(socket)

    token = "SomeBadToken"

    _send_raw(socket, "c.user.login #{token}\tLobby Name\n")
    reply = _recv_raw(socket)
    assert reply == "DENIED token_login_failed\n"
  end

  test "c.user.get_token_by_email - incorrect" do
    %{socket: socket} = tls_setup()
    _welcome = _recv_raw(socket)

    _send_raw(socket, "c.user.get_token_by_email nouser@\ttoken_password\n")
    reply = _recv_raw(socket)
    assert reply == "NO cmd=c.user.get_token_by_email\tinvalid credentials\n"

    _send_raw(socket, "c.user.get_token_by_email nouser@ token_password\n")
    reply = _recv_raw(socket)
    assert reply == "NO cmd=c.user.get_token_by_email\tbad format\n"
  end

  test "c.user.get_token_by_name - incorrect" do
    %{socket: socket} = tls_setup()
    _welcome = _recv_raw(socket)

    _send_raw(socket, "c.user.get_token_by_name nouser\ttoken_password\n")
    reply = _recv_raw(socket)
    assert reply == "NO cmd=c.user.get_token_by_name\tinvalid credentials\n"

    _send_raw(socket, "c.user.get_token_by_name nouser token_password\n")
    reply = _recv_raw(socket)
    assert reply == "NO cmd=c.user.get_token_by_name\tbad format\n"
  end
end
