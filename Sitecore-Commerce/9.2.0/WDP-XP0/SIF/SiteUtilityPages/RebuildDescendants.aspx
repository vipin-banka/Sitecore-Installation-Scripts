<%@ Import Namespace="System" %>
<%@ Import Namespace="Sitecore.ExperienceContentManagement.Administration.Helpers.DbCleanup" %>
<%@ Import Namespace="Sitecore.Jobs" %>

<%@ Page language="c#" %>
<script runat="server">
  
  public class CleanupTaskRunnerWithStatus : CleanupTaskRunner
  {
    public static bool Running 
    { 
      get
      {
        return JobHandle != null && JobManager.GetJob(JobHandle).Status.State != JobState.Finished;
      }
    }
  }

  void Page_Load(object sender, System.EventArgs e) 
  {
    var masterDbName = "master";
    var coreDbName = "core";
    var taskRunner = new CleanupTaskRunner();

    taskRunner.RunCleanUp(new TaskToRun[] 
    {
      new TaskToRun
      {
        Database = masterDbName,
        Task = CleanupTasks.RebuildDescendants
      },
      new TaskToRun
      {
        Database = coreDbName,
        Task = CleanupTasks.RebuildDescendants
      }
    });

    while(CleanupTaskRunnerWithStatus.Running) 
    {
      System.Threading.Thread.Sleep(1000);
    }
  }
</script>  
<!DOCTYPE html>
<html>
  <head>
    <title>Rebuild descendants</title>
    <meta content="Microsoft Visual Studio 7.0" name="GENERATOR">
    <meta content="C#" name="CODE_LANGUAGE">
    <meta content="JavaScript" name="vs_defaultClientScript">
    <meta content="http://schemas.microsoft.com/intellisense/ie5" name="vs_targetSchema">
    <link href="/default.css" rel="stylesheet">
  </head>
  <body>
  </body>
</html>
