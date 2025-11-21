SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

  
CREATE PROC [RDT].[rdt_PDDTPPrintSP01]  
(  
   @cFunc            INT
  ,@cReportType      NVARCHAR(20)  
  ,@cStorerkey       NVARCHAR(20)
  ,@c_Printer        NVARCHAR(20)
  ,@c_Parm01         NVARCHAR(60)
  ,@c_Parm02         NVARCHAR(60)
  ,@c_Parm03         NVARCHAR(60)
  ,@c_Parm04         NVARCHAR(60)
  ,@c_Parm05         NVARCHAR(60)
  ,@c_Parm06         NVARCHAR(60)
  ,@c_Parm07         NVARCHAR(60)
  ,@c_Parm08         NVARCHAR(60)
  ,@c_Parm09         NVARCHAR(60)
  ,@c_Parm10         NVARCHAR(60)
  ,@cJobID           NVARCHAR(60)
  ,@b_Success        INT            OUTPUT  
  ,@n_Err            INT            OUTPUT  
,  @c_ErrMsg         NVARCHAR(256)  OUTPUT  
  
)  
AS  
BEGIN  
     
   DECLARE @c_WebSocketURL    NVARCHAR(200)  
         , @c_RequestString   NVARCHAR(MAX) 
         , @cPrintData        NVARCHAR(MAX)
         , @cPrinterDesc      NVARCHAR(60)
         , @cPrinterInGroup   NVARCHAR(20)
         , @cSpoolerGroup     NVARCHAR(20)


   -- Get default printer in the group  
   SELECT @cSpoolerGroup = SpoolerGroup,@cPrinterDesc=DESCRIPTION  
   FROM rdt.rdtprinter WITH (NOLOCK)  
   WHERE printerid = @c_Printer  

   SELECT @c_WebSocketURL=IPAddress +':'+portno
   FROM rdt.rdtSpooler (NOLOCK)
   WHERE SpoolerGroup=@cSpoolerGroup

   SELECT @cprintdata=PrintData
   FROM dbo.CartonTrack (NOLOCK)
        WHERE trackingno=@c_Parm01
        AND udf01 IN('PDD')

   SET @cprintdata= REPLACE(@cprintdata,'<![CDATA[','')
   
   SET @cprintdata= REPLACE(@cprintdata,']]>','')
   
   SELECT @c_RequestString=PrintTemplate
   FROM rdt.rdtreportdetail (NOLOCK)
   WHERE storerkey=@cStorerkey
        AND ReportType=@cReportType
        AND Function_ID=@cFunc
        AND subplatform='PDD'

   SET @c_RequestString=REPLACE (@c_RequestString, '@cField01', @cprintdata)
   SET @c_RequestString=REPLACE (@c_RequestString, '@cField02', @cPrinterDesc)  
   SET @c_RequestString=REPLACE (@c_RequestString, '@cField03', @cJobID)  
   SET @c_RequestString=REPLACE (@c_RequestString, '@cField04', @c_Parm01)


   SELECT @c_WebSocketURL [WebSocketURL]  
         ,@c_RequestString [RequestString]  
                                     
END -- End of Procedure  


GO