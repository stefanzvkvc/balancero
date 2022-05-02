{_, 0} = System.cmd("epmd", ["-daemon"])
:ok = LocalCluster.start()
{:ok, _apps} = Application.ensure_all_started(:balancero)
ExUnit.start()
