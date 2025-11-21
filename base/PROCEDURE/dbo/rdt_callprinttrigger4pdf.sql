SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE rdt_CallPrintTrigger4PDF
	-- Add the parameters for the stored procedure here
	 @cStorerkey    AS NVARCHAR(20),
	 @cMbolKey      AS NVARCHAR(20)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE 
            @c_ResponseString NVARCHAR(MAX), 
            @c_vbHttpStatusCode NVARCHAR(10), 
            @c_vbHttpStatusDesc NVARCHAR(100);
    DECLARE 
            @c_doc1 NVARCHAR(MAX),
            @c_vbErrMsg  NVARCHAR(MAX),
            @c_PDFFileName_Courier NVARCHAR(MAX),
            @b_Debug int = 1
    DECLARE
            @ctriggerName     NVARCHAR(30),
            @cReportName      NVARCHAR(30),
			@cFileFolder	  NVARCHAR(200),
			@cWebRequestURL   NVARCHAR(4000)

    --{\n    \"triggerName\":\"sean_trigger_parameter_test\",\n    \"storerKey\":\"test\",\n    \"reportName\":\"test\",\n    \"parameters\":{\n        \"isp_Trigger_Param_String\":\"abcdefg\",\n        \"isp_Trigger_Param_Date\":\"August 23, 2024\",\n        \"isp_Trigger_Param_DateTime\":\"August 20, 2024, 12:00:00 AM\",\n        \"isp_Trigger_Param_Int\":99,\n        \"isp_Trigger_Param_Boolean\":false\n    }\n}
	print 'begin'
    SELECT
        @ctriggerName = parm1_label,
        @cReportName = JReportFileName,
		@cFileFolder = FileFolder,
		@cWebRequestURL = PrintSettings
    FROM RDT.rdtReportDetail WITH(NOLOCK)
    WHERE storerkey = @cStorerkey
    AND ReportType = 'CLSTRUCK'
		 
		--SET @ctriggerName = 'rdt_john_trigger_test'
  --      SET @cReportName = 'clsruck'

    --SET @c_doc1 = '{\n    \"triggerName\":\"' + @ctriggerName + '\",'
    --SET @c_doc1 = @c_doc1 + '\n    \"storerKey\":\"' + @cStorerKey + '\",'
    --SET @c_doc1 = @c_doc1 + '\n    \"reportName\":\"' + @cReportName + '\",'
    --SET @c_doc1 = @c_doc1 + '\n    \"parameters\":{\n        \"PARAM_WMS_c_ReceiptKey\":\"'+ @cMbolKey + '\"\n    },'
    --SET @c_doc1 = @c_doc1 + '\n    \"origin\":\"rdt\",'
    --SET @c_doc1 = @c_doc1 + '\n}'

	SET @c_doc1 = '{    "triggerName":"' + @ctriggerName + '",'
    SET @c_doc1 = @c_doc1 + '    "storerKey":"' + @cStorerKey + '",'
    SET @c_doc1 = @c_doc1 + '    "reportName":"' + @cReportName + '",'
    SET @c_doc1 = @c_doc1 + '    "parameters":{        "PARAM_WMS_c_ReceiptKey":"'+ @cMbolKey + '"    }'
    SET @c_doc1 = @c_doc1 + '}'

               
			   --SET @cFileFolder = N'E:\COMObject\GenericWebServiceClient\WSconfig.ini'
			   --SET @cWebRequestURL = N'https://cdt-rdtapi.fulfillment.maersk.com/utc/RDTServer/countries'
			   --SET @cWebRequestURL = N'https://cdt-logireport.fulfillment.maersk.com/logi_trigger.jsp'
			   --SET @cWebRequestURL = N'https://172.16.64.7:443/logi_trigger.jsp'
print @c_doc1
    EXEC master.dbo.isp_GenericWebServiceClientV5 
            --@c_IniFilePath = N'E:\COMObject\GenericWebServiceClient\WSconfig.ini', -- nvarchar(100)
			@c_IniFilePath = @cFileFolder,
            --@c_WebRequestURL = N'https://cdt-rdtapi.fulfillment.maersk.com/utc/RDTServer/countries', -- nvarchar(1000)
			@c_WebRequestURL = @cWebRequestURL,
            @c_WebRequestMethod = N'POST', -- nvarchar(10)
            @c_ContentType = N'application/json', -- nvarchar(100)
            @c_WebRequestEncoding = N'UTF-8', -- nvarchar(30)
            @c_RequestString = @c_doc1,
            @c_ResponseString = @c_ResponseString OUTPUT, -- nvarchar(max)
            @c_vbErrMsg = @c_vbErrMsg OUTPUT, -- nvarchar(max)
            @n_WebRequestTimeout = 0, -- int
            @c_NetworkCredentialUserName = N'', -- nvarchar(100)
            @c_NetworkCredentialPassword = N'', -- nvarchar(100)
            @b_IsSoapRequest = 0, -- bit
            @c_RequestHeaderSoapAction = N'', -- nvarchar(100)
            @c_HeaderAuthorization = N'', -- nvarchar(4000)
            @c_ProxyByPass = N'1', -- nvarchar(1)
            @c_WebRequestHeaders = 'ClientSystem:RDT', -- Folder:Z:\GBR\DTSToExceed\nikecn01-chn-cdt|FileName:WMS_TESTING.pdf
            @c_vbHttpStatusCode = @c_vbHttpStatusCode OUTPUT, -- nvarchar(10)
            @c_vbHttpStatusDesc = @c_vbHttpStatusDesc OUTPUT -- nvarchar(100)

               
                  SELECT @c_ResponseString,@c_vbErrMsg,@c_vbHttpStatusCode,@c_vbHttpStatusDesc
               
END

GO