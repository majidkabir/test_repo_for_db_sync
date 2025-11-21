SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: isp_TPS_ExtPrint04                                        */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date         Rev  Author     Purposes                                      */
/* 2023-07-27   1.0  yeekung    TPS-759 Created                               */
/* 2023-09-12   1.1  YeeKung    TPS-773/TPS-740 New print (yeekung3)          */
/* 2024-11-06   1.2  YeeKung    TPS-989 Add Facility (yeekung02)              */
/******************************************************************************/

CREATE   PROC [API].[isp_TPS_ExtPrint04] (
	@cStorerKey       NVARCHAR( 15),
   @cFacility        NVARCHAR( 5),
   @nFunc            INT,
   @cUserName        NVARCHAR( 128),
   @cLangCode        NVARCHAR( 3),
   @cScanNo          NVARCHAR( 50),
   @cpickslipNo      NVARCHAR( 30),
   @cDropID          NVARCHAR( 50),
   @cOrderKey        NVARCHAR( 10),
   @cLoadKey         NVARCHAR( 10),
   @cZone            NVARCHAR( 18),
   @EcomSingle       NVARCHAR( 1),
   @nCartonNo        INT,
   @cCartonType      NVARCHAR( 10),
   @cType            NVARCHAR( 30),
   @fCartonWeight    FLOAT,
   @fCartonCube      FLOAT,
   @cWorkstation     NVARCHAR( 30),
   @cLabelNo         NVARCHAR( 20),
   @cCloseCartonJson NVARCHAR (MAX),
   @cPrintPackList   NVARCHAR(1),
   @cLabelJobID      NVARCHAR ( 30) OUTPUT,
   @cPackingJobID    NVARCHAR ( 30) OUTPUT,
   @b_Success        INT = 1        OUTPUT,
   @n_Err            INT = 0        OUTPUT,
   @c_ErrMsg         NVARCHAR( 255) = ''  OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE @curAD CURSOR
DECLARE
	@cSKU             NVARCHAR(20),
   @cSkuBarcode      NVARCHAR(60),
   @cOrderLineNumber NVARCHAR(5),
   @cWeight          NVARCHAR(10),
   @cCube            NVARCHAR(10),
   @cLottableVal     NVARCHAR(20),
   @cSerialNoKey     NVARCHAR(60),
   @cErrMsg          NVARCHAR(128),
   @nQty             INT,
   @bsuccess         INT,
   @nErrNo           INT,
   @nTranCount       INT

DECLARE @CloseCtnList TABLE (
   SKU             NVARCHAR( 20),
   QTY             INT,
   Weight          FLOAT,
   Cube            FLOAT,
   lottableVal     NVARCHAR(60),
   SkuBarcode      NVARCHAR(60),
   ADCode          NVARCHAR(60)
)



DECLARE   @c_ModuleID           NVARCHAR(30) ='TPPack'
      , @c_ReportID           NVARCHAR(10) 
      , @c_PrinterID          NVARCHAR(30)  
      , @c_JobIDs             NVARCHAR(50)   = ''         --(Wan03) -- May return multiple jobs ID.JobID seperate by '|'
      , @c_PrintSource        NVARCHAR(20)
      , @c_AutoPrint          NVARCHAR(1)    = 'N'        --(Wan07)

--INSERT INTO @CloseCtnList (SKU, QTY, WEIGHT, CUBE, lottableVal,SkuBarcode, ADCode)
--SELECT
--Hdr.SKU
--, Hdr.Qty
--, Hdr.Weight
--, Hdr.Cube
--, Hdr.lottableValue
--, Det.barcodeVal
--, Det.AntiDiversionCode
--FROM OPENJSON(@cCloseCartonJson)
--WITH (
--   SKU            NVARCHAR( 20)  '$.SKU',
--   Qty            INT            '$.PackedQty',
--   Weight         FLOAT          '$.WEIGHT',
--   Cube           FLOAT          '$.CUBE',
--   lottableValue  NVARCHAR(60)   '$.Lottable',
--   barcodeObj     NVARCHAR(MAX)  '$.barcodeObj' AS JSON
--) AS Hdr
--CROSS APPLY OPENJSON(barcodeObj)
--WITH (
--   barcodeVal        NVARCHAR(60) '$.barcodeVal',
--   AntiDiversionCode NVARCHAR(60) '$.AntiDiversionCode'
--) AS Det

--SELECT 'aa',* FROM @CloseCtnList

DECLARE  @tUCCLabel AS VariableTable
DECLARE  @tCtnLabel AS VariableTable
DECLARE  @tPackList AS VariableTable
DECLARE  @cConsignee     NVARCHAR(15)
DECLARE  @cReportType    nvarchar(20)
DECLARE  @cLabelPrinter  NVARCHAR ( 30)
DECLARE  @cPaperPrinter  NVARCHAR ( 30)
DECLARE  @nJobID         INT
DECLARE  @nRC            INT
DECLARE  @cSQL           NVARCHAR ( MAX)
DECLARE  @cSQLParam      NVARCHAR ( MAX)
DECLARE  @cColumn        NVARCHAR( 60)
DECLARE  @cValue         NVARCHAR( 60)
DECLARE  @cTemplate      NVARCHAR(50),
         @cTemplateCode  NVARCHAR(60),
         @cCodeTwo       NVARCHAR(20),
         @cField01       NVARCHAR(10),
         @cVASType       NVARCHAR(10)


DECLARE @tOutBoundList AS VariableTable

set @cLabelJobID = ''
set @cPackingJobID = ''

BEGIN
	IF @cPickSlipNo <> ''
   BEGIN

      SELECT @cPaperPrinter = PrinterID FROM api.AppPrinter WITH (NOLOCK) WHERE Workstation = @cWorkstation AND printerType = 'Paper'
      SELECT @cLabelPrinter = PrinterID FROM api.AppPrinter WITH (NOLOCK) WHERE Workstation = @cWorkstation AND printerType = 'Label'


      IF EXISTS (  SELECT 1
            FROM dbo.DocInfo WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
            AND TableName = 'ORDERDETAIL'
            AND Key1 = @cOrderKey
            AND Rtrim(Substring(Docinfo.Data,31,30)) = 'L01'  )
      BEGIN

         DECLARE CursorLabel CURSOR LOCAL FAST_FORWARD READ_ONLY FOR

         SELECT Rtrim(Substring(Docinfo.Data,31,30))
               ,Rtrim(Substring(Docinfo.Data,61,30))
         FROM dbo.DocInfo WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND TableName = 'ORDERDETAIL'
         AND Key1 = @cOrderKey
         AND Key2 = '00001'
         AND Rtrim(Substring(Docinfo.Data,31,30)) = 'L01'

         OPEN CursorLabel
         FETCH NEXT FROM CursorLabel INTO @cVASType, @cField01
         WHILE @@FETCH_STATUS = 0
         BEGIN

            DECLARE CursorCodeLkup CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT Notes, Code2
            FROM dbo.CodeLkup WITH (NOLOCK)
            WHERE ListName = 'UALabel'
            AND Code  = @cField01
            AND Short = @cVASType
            AND StorerKey = @cStorerKey

            OPEN CursorCodeLkup
            FETCH NEXT FROM CursorCodeLkup INTO @cTemplate, @cCodeTwo
            WHILE @@FETCH_STATUS = 0
            BEGIN

               SET @cTemplateCode = ''
               SET @cTemplateCode = ISNULL(RTRIM(@cVASType),'')  + ISNULL(RTRIM(@cCodeTwo),'')

               IF @cTemplate = ''
               BEGIN
                  SET @nErrNo = 123162
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TemplateNotFound
                  GOTO Quit
               END

               --DELETE FROM @tOutBoundList

               --INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cPickSlipNo',  @cPickSlipNo)
               --INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@nCartonStart', @nCartonNo)
               --INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@nCartonEnd',   @nCartonNo)
               --INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cTemplateCode',   @cTemplateCode)

               ---- Print label
               --EXEC API.isp_Print @cLangCode, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,
               --   'SHIPLBLUA2', -- Report type
               --   @tOutBoundList, -- Report params
               --   'isp_TPS_ExtPrint04',
               --   @nErrNo  OUTPUT,
               --   @cErrMsg OUTPUT

               
               SELECT   @c_ReportID = WMR.reportid,
                        @c_PrintSource = CASE WHEN printtype='LOGIREPORT' THEN 'JReport' ELSE 'WMReport' END
               FROM WMReport WMR (NOLOCK)
               JOIN WMReportdetail WMRD (NOLOCK) ON WMR.reportid =WMRD.reportid
               WHERE Storerkey = @cStorerkey
                  AND reporttype = 'SHIPLBLUA2'
                  AND ModuleID ='TPPack'
                  AND ispaperprinter <> 'Y'
                  AND (WMRD.Facility = '' OR WMRD.Facility = @cFacility)  


               EXEC  [WM].[lsp_WM_Print_Report]
                @c_ModuleID = @c_ModuleID           
               , @c_ReportID = @c_ReportID         
               , @c_Storerkey = @cStorerkey         
               , @c_Facility  = @cFacility        
               , @c_UserName  = @cUsername   
               , @c_ComputerName = ''
               , @c_PrinterID = @cLabelPrinter         
               , @n_NoOfCopy  = '1'     
               , @c_KeyValue1 = @cPickSlipNo        
               , @c_KeyValue2 = @nCartonNo        
               , @c_KeyValue3 = @nCartonNo     
               , @c_KeyValue4 = @cTemplateCode       
               , @b_Success   = @b_Success         OUTPUT      
               , @n_Err       = @n_Err             OUTPUT
               , @c_ErrMsg    = @c_ErrMsg          OUTPUT
               , @c_PrintSource  = @c_PrintSource        
               , @b_SCEPreView   = 0         
               , @c_JobIDs      = @cLabelJobID         OUTPUT    
               , @c_AutoPrint  = 'N'     

               SET @cLabelJobID = @nJobID

               IF @nErrNo <> 0
                  GOTO QUIT

               FETCH NEXT FROM CursorCodeLkup INTO @cTemplate, @cCodeTwo

            END
            CLOSE CursorCodeLkup
            DEALLOCATE CursorCodeLkup

            FETCH NEXT FROM CursorLabel INTO @cVASType, @cField01
         END
      END
      ELSE IF EXISTS (  SELECT 1
                  FROM dbo.DocInfo WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                  AND TableName = 'ORDERDETAIL'
                  AND Key1 = @cOrderKey
                  AND Rtrim(Substring(Docinfo.Data,31,30)) = 'L02'  )
      BEGIN

         SET @cTemplate = ''

         DECLARE CursorCodeLkup CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT Notes, Code2
         FROM dbo.CodeLkup WITH (NOLOCK)
         WHERE ListName = 'UACCLabel'
         AND Code  = @cVASType
         AND StorerKey = @cStorerKey

         OPEN CursorCodeLkup
         FETCH NEXT FROM CursorCodeLkup INTO @cTemplate, @cCodeTwo
         WHILE @@FETCH_STATUS = 0
         BEGIN

            SET @cTemplateCode = ''
            SET @cTemplateCode = ISNULL(RTRIM(@cVASType),'')  + ISNULL(RTRIM(@cCodeTwo),'')

            IF @cTemplate = ''
            BEGIN
               SET @nErrNo = 123162
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TemplateNotFound
               GOTO Quit
            END

               --DELETE FROM @tOutBoundList

               --INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cPickSlipNo',  @cPickSlipNo)
               --INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@nCartonStart', @nCartonNo)
               --INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@nCartonEnd',   @nCartonNo)
               --INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cTemplateCode',   @cTemplateCode)

               ---- Print label
               --EXEC API.isp_Print @cLangCode, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,
               --   'SHIPLBLUA2', -- Report type
               --   @tOutBoundList, -- Report params
               --   'rdt_593PrintUA01',
               --   @nErrNo  OUTPUT,
               --   @cErrMsg OUTPUT

                              
               SELECT   @c_ReportID = WMR.reportid,
                        @c_PrintSource = CASE WHEN printtype='LOGIREPORT' THEN 'JReport' ELSE 'WMReport' END
               FROM WMReport WMR (NOLOCK)
               JOIN WMReportdetail WMRD (NOLOCK) ON WMR.reportid =WMRD.reportid
               WHERE Storerkey = @cStorerkey
                  AND reporttype = 'SHIPLBLUA2'
                  AND ModuleID ='TPPack'
                  AND ispaperprinter <> 'Y'
                  AND (WMRD.Facility = '' OR WMRD.Facility = @cFacility)  

               EXEC  [WM].[lsp_WM_Print_Report]
                @c_ModuleID = @c_ModuleID           
               , @c_ReportID = @c_ReportID         
               , @c_Storerkey = @cStorerkey         
               , @c_Facility  = @cFacility        
               , @c_UserName  = @cUsername   
               , @c_ComputerName = ''
               , @c_PrinterID = @cLabelPrinter         
               , @n_NoOfCopy  = '1'     
               , @c_KeyValue1 = @cPickSlipNo        
               , @c_KeyValue2 = @nCartonNo        
               , @c_KeyValue3 = @nCartonNo     
               , @c_KeyValue4 = @cTemplateCode       
               , @b_Success   = @b_Success         OUTPUT      
               , @n_Err       = @n_Err             OUTPUT
               , @c_ErrMsg    = @c_ErrMsg          OUTPUT
               , @c_PrintSource  = @c_PrintSource        
               , @b_SCEPreView   = 0         
               , @c_JobIDs      = @cLabelJobID         OUTPUT    
               , @c_AutoPrint  = 'N'     

               SET @cLabelJobID = @nJobID

               IF @n_Err <> 0
                  GOTO Quit

            FETCH NEXT FROM CursorCodeLkup INTO @cTemplate, @cCodeTwo

         END
         CLOSE CursorCodeLkup
         DEALLOCATE CursorCodeLkup

      END
      ELSE IF EXISTS (select 1 from orders (nolock)
         WHERE orderkey=@cOrderKey
         AND ordergroup ='JIT')
      BEGIN

         SELECT   @c_ReportID = WMR.reportid,
                  @c_PrintSource = CASE WHEN printtype='LOGIREPORT' THEN 'JReport' ELSE 'WMReport' END
         FROM WMReport WMR (NOLOCK)
         JOIN WMReportdetail WMRD (NOLOCK) ON WMR.reportid =WMRD.reportid
         WHERE Storerkey = @cStorerkey
            AND reporttype = 'CTNLBLUA'
            AND ModuleID ='TPPack'
            AND ispaperprinter <> 'Y'
            AND (WMRD.Facility = '' OR WMRD.Facility = @cFacility)  
            
         EXEC  [WM].[lsp_WM_Print_Report]
            @c_ModuleID = @c_ModuleID           
         , @c_ReportID = @c_ReportID         
         , @c_Storerkey = @cStorerkey         
         , @c_Facility  = @cFacility        
         , @c_UserName  = @cUsername   
         , @c_ComputerName = ''
         , @c_PrinterID = @cLabelPrinter         
         , @n_NoOfCopy  = '1'     
         , @c_KeyValue1 = @cLabelNo        
         , @c_KeyValue2 = ''    
         , @c_KeyValue3 = '' 
         , @c_KeyValue4 = ''       
         , @b_Success   = @b_Success         OUTPUT      
         , @n_Err       = @n_Err             OUTPUT
         , @c_ErrMsg    = @c_ErrMsg          OUTPUT
         , @c_PrintSource  = @c_PrintSource        
         , @b_SCEPreView   = 0         
         , @c_JobIDs      = @cLabelJobID         OUTPUT    
         , @c_AutoPrint  = 'N'     

         SET @cLabelJobID = @nJobID

            SELECT   @c_ReportID = WMR.reportid,
               @c_PrintSource = CASE WHEN printtype='LOGIREPORT' THEN 'JReport' ELSE 'WMReport' END
         FROM WMReport WMR (NOLOCK)
         JOIN WMReportdetail WMRD (NOLOCK) ON WMR.reportid =WMRD.reportid
         WHERE Storerkey = @cStorerkey
            AND reporttype = 'CTNRPTUA'
            AND ModuleID ='TPPack'
            AND ispaperprinter <> 'Y'
            AND (WMRD.Facility = '' OR WMRD.Facility = @cFacility)  
            
         EXEC  [WM].[lsp_WM_Print_Report]
            @c_ModuleID = @c_ModuleID           
         , @c_ReportID = @c_ReportID         
         , @c_Storerkey = @cStorerkey         
         , @c_Facility  = @cFacility        
         , @c_UserName  = @cUsername   
         , @c_ComputerName = ''
         , @c_PrinterID = @cLabelPrinter         
         , @n_NoOfCopy  = '1'     
         , @c_KeyValue1 =  @cPickSlipno       
         , @c_KeyValue2 = @cLabelNo   
         , @c_KeyValue3 = '' 
         , @c_KeyValue4 = ''       
         , @b_Success   = @b_Success         OUTPUT      
         , @n_Err       = @n_Err             OUTPUT
         , @c_ErrMsg    = @c_ErrMsg          OUTPUT
         , @c_PrintSource  = @c_PrintSource        
         , @b_SCEPreView   = 0         
         , @c_JobIDs      = @cLabelJobID         OUTPUT    
         , @c_AutoPrint  = 'N'     

         SET @cLabelJobID = @nJobID

      END

		IF @cPrintPackList = 'Y'
      BEGIN
         IF  EXISTS (select TOP 1 1 FROM WMReport WMR WITH (NOLOCK)
                        JOIN WMReportdetail WMRD (NOLOCK) ON WMR.reportid =WMRD.reportid
                     WHERE WMRD.StorerKey = @cStorerKey 
                        AND reportType ='TPPACKLIST'
                        AND WMR.moduleid = @c_ModuleID)
         BEGIN
            IF ISNULL(@cPaperPrinter,'') = ''
            BEGIN
               SET @b_Success = 0
               SET @n_Err = 175744
               SET @c_ErrMsg = rdt.rdtgetmessage( @n_Err, @cLangCode, 'DSP')--'Paper Printer setup not done. Please setup the Paper Printer. Function : isp_TPS_ExtPrint02'
               GOTO Quit
            END
            ELSE
            BEGIN
               SELECT @c_ReportID = WMR.reportid,
                        @c_PrintSource = CASE WHEN printtype='LOGIREPORT' THEN 'JReport' ELSE 'WMReport' END
               FROM WMReport WMR (NOLOCK)
               JOIN WMReportdetail WMRD (NOLOCK) ON WMR.reportid =WMRD.reportid
               WHERE Storerkey = @cStorerkey
                  AND reporttype = 'TPPACKLIST'
                  AND ModuleID ='TPPack'
                  AND (WMRD.Facility = '' OR WMRD.Facility = @cFacility)  

               EXEC  [WM].[lsp_WM_Print_Report]
                  @c_ModuleID = @c_ModuleID           
               , @c_ReportID = @c_ReportID         
               , @c_Storerkey = @cStorerkey         
               , @c_Facility  = @cFacility        
               , @c_UserName  = @cUsername   
               , @c_ComputerName = ''
               , @c_PrinterID = @cPaperPrinter         
               , @n_NoOfCopy  = '1'     
               , @c_KeyValue1 = @cStorerKey        
               , @c_KeyValue2 = @cPickSlipNo        
               , @c_KeyValue3 = @nCartonNo     
               , @c_KeyValue4 = @nCartonNo       
               , @b_Success   = @b_Success         OUTPUT      
               , @n_Err       = @n_Err             OUTPUT
               , @c_ErrMsg    = @c_ErrMsg          OUTPUT
               , @c_PrintSource  = @c_PrintSource        
               , @b_SCEPreView   = 0         
               , @c_JobIDs      = @cLabelJobID         OUTPUT    
               , @c_AutoPrint  = 'N'     

               set @cLabelJobID = @nJobID
            END
         END
      END
   END

Quit:

END

SET QUOTED_IDENTIFIER OFF

GO