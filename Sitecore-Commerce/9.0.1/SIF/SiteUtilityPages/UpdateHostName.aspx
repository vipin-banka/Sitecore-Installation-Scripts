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
		var hostname = WebUtil.GetQueryString("hostname");
		Sitecore.Data.Database master = Sitecore.Configuration.Factory.GetDatabase("master");
		if (!string.IsNullOrEmpty(hostname) && master != null)
		{
			var siteDefinitionItem = master.GetItem("/sitecore/content/Sitecore/Storefront/Settings/Site Grouping/Storefront");
			if (siteDefinitionItem != null)
			{
				using (new SecurityDisabler())
				{
					siteDefinitionItem.Editing.BeginEdit();
					siteDefinitionItem["HostName"] = hostname;
					siteDefinitionItem.Editing.EndEdit();
				}
			}
		}
		
		Response.Write("Update host name: " + DateTime.Now.ToString("t") + "<br>");
    }

    protected String GetTime()
    {
        return DateTime.Now.ToString("t");
    }
	
</script>
<body>
    <form id="MyForm" runat="server">
        <div>This page updates host name for storefront website.</div>
        Current server time is <% =GetTime()%>
    </form>
</body>
</html>
