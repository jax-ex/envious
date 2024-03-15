# Enum.each([".env", ".#{config_env()}.env"], fn file ->
#   with {:ok, file} <- File.read(".env"),
#        {:ok, envs} <- Dotenvy.Parser.parse(file) do
#     Sytem.put_env(envs)
#   end
# end)
