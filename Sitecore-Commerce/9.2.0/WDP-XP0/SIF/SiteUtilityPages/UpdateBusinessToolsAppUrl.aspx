<%@ Import Namespace="System.IO" %>
<%@ Import Namespace="System" %>
<%@ Import Namespace="System.Text.RegularExpressions" %>
<%@ Import Namespace="System.Configuration" %>
<%@ Import Namespace="log4net" %>
<%@ Import Namespace="Sitecore.Data.Engines" %>
<%@ Import Namespace="Sitecore.Data.Proxies" %>
<%@ Import Namespace="Sitecore.SecurityModel" %>
<%@ Import Namespace="Sitecore.Update" %>
<%@ Import Namespace="Sitecore.Update.Installer" %>
<%@ Import Namespace="Sitecore.Update.Installer.Exceptions" %>
<%@ Import Namespace="Sitecore.Update.Installer.Installer.Utils" %>
<%@ Import Namespace="Sitecore.Update.Installer.Utils" %>
<%@ Import Namespace="Sitecore.Update.Metadata" %>
<%@ Import Namespace="Sitecore.Update.Utils" %>
<%@ Import Namespace="Sitecore.Web" %>

<%@  Language="C#" Debug="true" %>
<html>
<script runat="server" language="C#">
    public void Page_Load(object sender, EventArgs e)
    {
		var port = WebUtil.GetQueryString("port");
		Sitecore.Data.Database core = Sitecore.Configuration.Factory.GetDatabase("core");
		if (!string.IsNullOrEmpty(port) && core != null)
		{
			using (new SecurityDisabler())
			{
				var businessToolsButtonItem = core.GetItem(new Sitecore.Data.ID("{C19BA3CD-6290-4C68-9A5D-2008A16FDBEF}"));
			
				if (businessToolsButtonItem != null)
				{				
					businessToolsButtonItem.Editing.BeginEdit();
					businessToolsButtonItem["Link"] = "https://localhost:" + port;
					businessToolsButtonItem.Editing.EndEdit();				
				}
			}
		}
		
		Response.Write("Update Biz App Url: " + DateTime.Now.ToString("t") + "<br>");
    }

    protected String GetTime()
    {
        return DateTime.Now.ToString("t");
    }
	
</script>
<body>
    <form id="MyForm" runat="server">
        <div>This page updates Business tools button url.</div>
        Current server time is <% =GetTime()%>
    </form>
</body>
</html>
