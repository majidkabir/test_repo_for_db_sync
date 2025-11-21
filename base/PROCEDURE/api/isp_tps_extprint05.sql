SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: isp_TPS_ExtPrint05                                        */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date         Rev  Author     Purposes                                      */
/* 2023-12-11   1.0  yeekung    TPS-796 Created                               */
/* 2024-02-01   1.1  yeekung    TPS-869 Add more criteia                      */
/* 2024-11-06   1.2  YeeKung    TPS-989 Add Facility (yeekung02)              */
/******************************************************************************/

CREATE   PROC [API].[isp_TPS_ExtPrint05] (
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

DECLARE @tUCCLabel AS VariableTable
DECLARE @tCtnLabel AS VariableTable
DECLARE @tPackList AS VariableTable
DECLARE @cConsignee     NVARCHAR(15)
DECLARE @cReportType    nvarchar(20)
DECLARE @cLabelPrinter  NVARCHAR ( 30)
DECLARE @cPaperPrinter  NVARCHAR ( 30)
DECLARE @cTCPPrinter    NVARCHAR ( 30)
DECLARE @cPrinter       NVARCHAR ( 20)
DECLARE @cProcesstype   NVARCHAR ( 20)
DECLARE @nJobID         NVARCHAR ( 20)
DECLARE @nRC            INT
DECLARE @cSQL           NVARCHAR ( MAX)
DECLARE @cSQLParam      NVARCHAR ( MAX)
DECLARE @cColumn        NVARCHAR( 60)
DECLARE @cValue         NVARCHAR( 60)
DECLARE @cNewPaperPrinter NVARCHAR(20)
DECLARE @cNewLabelPrinter NVARCHAR(20)


DECLARE   @c_ModuleID           NVARCHAR(30) ='TPPack'
         , @c_ReportID           NVARCHAR(10) 
         , @c_PrinterID          NVARCHAR(30)  
         , @c_JobIDs             NVARCHAR(50)   = ''      
         , @c_PrintSource        NVARCHAR(20)
         , @c_AutoPrint          NVARCHAR(1)    = 'N'     

DECLARE @cFieldName1 NVARCHAR(max),
        @cFieldName2 NVARCHAR(max),
        @cFieldName3 NVARCHAR(max),
        @cFieldName4 NVARCHAR(max),
        @cParams1    NVARCHAR(max),
        @cParams2    NVARCHAR(max),
        @cParams3    NVARCHAR(max),
        @cParams4    NVARCHAR(max)

DECLARE @cCurLabel CURSOR
DECLARE @cCurPaper CURSOR

set @cLabelJobID = ''
set @cPackingJobID = ''

BEGIN

   SELECT @cPaperPrinter = PrinterID FROM api.AppPrinter WITH (NOLOCK) WHERE Workstation = @cWorkstation AND printerType = 'Paper'
   SELECT @cLabelPrinter = PrinterID FROM api.AppPrinter WITH (NOLOCK) WHERE Workstation = @cWorkstation AND printerType = 'Label'

	IF @cPickSlipNo <> ''
	BEGIN


      SET @cCurLabel = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT reporttype
      FROM WMReport WMR WITH (NOLOCK)
         JOIN WMReportdetail WMRD (NOLOCK) ON WMR.reportid =WMRD.reportid
      WHERE  Storerkey = @cStorerkey
            AND ispaperprinter <> 'Y'
            AND WMR.ReportType NOT IN (SELECT CODE
                                       FROM CODELKUP CL (NOLOCK)
                                       WHERE CL.Storerkey = @cStorerkey
                                          AND CL.LISTNAME = 'TPSPrtLast'
                                      )
            AND WMR.moduleid = @c_ModuleID
            AND (ISNULL(ComputerName,'') ='' OR ComputerName = @cWorkstation)
            AND (WMRD.Facility = '' OR WMRD.Facility = @cFacility)  
      ORDER BY WMR.reportid
      OPEN @cCurLabel
      FETCH NEXT FROM @cCurLabel INTO @cReportType
      WHILE @@FETCH_STATUS = 0
      BEGIN

         SELECT   @c_ReportID = WMR.reportid,
                  @c_PrintSource = CASE WHEN printtype = 'LOGIREPORT' THEN 'JReport' ELSE 'WMReport' END,
                  @cNewLabelPrinter = Defaultprinterid,
                  @cFieldName1  = keyFieldname1,
                  @cFieldName2  = keyFieldname2,
                  @cFieldName3  = keyFieldname3,
                  @cFieldName4  = keyFieldname4
         FROM WMReport WMR (NOLOCK)
         JOIN WMReportdetail WMRD (NOLOCK) ON WMR.reportid =WMRD.reportid
         WHERE Storerkey = @cStorerkey
            AND reporttype = @cReportType
            AND ModuleID ='TPPack'
            AND ispaperprinter <> 'Y'
            and (WMRD.username = '' OR WMRD.username = @cUsername)
            AND (ISNULL(ComputerName,'') ='' OR ComputerName = @cWorkstation)
            AND (WMRD.Facility = '' OR WMRD.Facility = @cFacility)  

         SET  @cSQL =
         ' SELECT  @cParams1 = '+ @cFieldName1  
            SELECT @cSQL= CASE WHEN ISNULL(@cFieldName2,'') <> ''THEN @cSQL +',@cParams2 = ' + @cFieldName2  ELSE  @cSQL END 
            SELECT @cSQL= CASE WHEN ISNULL(@cFieldName3,'') <> ''THEN @cSQL +',@cParams3 = '  + @cFieldName3  ELSE  @cSQL END
            SELECT @cSQL= CASE WHEN ISNULL(@cFieldName4,'') <> ''THEN @cSQL +',@cParams4 = '  + @cFieldName4  ELSE  @cSQL END
         SET @cSQL = @cSQL +' FROM Packdetail (NOLOCK)
            WHERE Storerkey = @cstorerkey
               AND Pickslipno = @cPickslipno
               AND CartonNO = @nCartonno'

         SET @cSQLParam = 
         ' @cFieldName1 NVARCHAR(max),
           @cFieldName2 NVARCHAR(max),
           @cFieldName3 NVARCHAR(max),
           @cFieldName4 NVARCHAR(max),
           @cParams1    NVARCHAR(max) OUTPUT,
           @cParams2    NVARCHAR(max) OUTPUT,
           @cParams3    NVARCHAR(max) OUTPUT,
           @cParams4    NVARCHAR(max) OUTPUT,
           @cstorerkey  NVARCHAR(20),
           @cPickslipno NVARCHAR(20),
           @nCartonno   INT'


         EXEC sp_ExecuteSQL @cSQL,@cSQLParam,@cFieldName1,@cFieldName2,@cFieldName3,@cFieldName4,
         @cParams1 OUTPUT,@cParams2 OUTPUT,@cParams3 OUTPUT,@cParams4 OUTPUT,@cstorerkey,@cPickslipno,@nCartonno 

         IF ISNULL(@cNewLabelPrinter,'')= ''
            SET @cNewLabelPrinter = @cLabelPrinter

         EXEC  [WM].[lsp_WM_Print_Report]
          @c_ModuleID      = @c_ModuleID           
         , @c_ReportID     = @c_ReportID         
         , @c_Storerkey    = @cStorerkey         
         , @c_Facility     = @cFacility        
         , @c_UserName     = @cUsername   
         , @c_ComputerName = @cWorkstation
         , @c_PrinterID    = @cNewLabelPrinter         
         , @n_NoOfCopy     = '1'     
         , @c_KeyValue1    = @cParams1        
         , @c_KeyValue2    = @cParams2        
         , @c_KeyValue3    = @cParams3     
         , @c_KeyValue4    = @cParams4       
         , @b_Success      = @b_Success         OUTPUT      
         , @n_Err          = @n_Err             OUTPUT
         , @c_ErrMsg       = @c_ErrMsg          OUTPUT
         , @c_PrintSource  = @c_PrintSource        
         , @b_SCEPreView   = 0         
         , @c_JobIDs       = @nJobID         OUTPUT    
         , @c_AutoPrint    = 'N'     

         SET @cLabelJobID = @nJobID

         FETCH NEXT FROM @cCurLabel INTO @cReportType

      END

      

      SET @cCurPaper = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT reporttype
      FROM WMReport WMR WITH (NOLOCK)
         JOIN WMReportdetail WMRD (NOLOCK) ON WMR.reportid = WMRD.reportid
      WHERE  Storerkey = @cStorerkey
            AND ispaperprinter = 'Y'
            AND WMR.ReportType NOT IN (SELECT CODE
                           FROM CODELKUP CL (NOLOCK)
                           WHERE CL.Storerkey = @cStorerkey
                              AND CL.LISTNAME = 'TPSPrtLast'
                           )
            AND WMR.moduleid = @c_ModuleID
            AND (ISNULL(ComputerName,'') ='' OR ComputerName = @cWorkstation)
            AND (WMRD.Facility = '' OR WMRD.Facility = @cFacility)  
      OPEN @cCurPaper
      FETCH NEXT FROM @cCurPaper INTO @cReportType
      WHILE @@FETCH_STATUS = 0
      BEGIN
         SELECT @c_ReportID   = WMR.reportid,
            @c_PrintSource    = CASE WHEN printtype='LOGIREPORT' THEN 'JReport' ELSE 'WMReport' END,
            @cNewPaperPrinter = Defaultprinterid,
            @cFieldName1      = keyFieldname1,
            @cFieldName2      = keyFieldname2,
            @cFieldName3      = keyFieldname3,
            @cFieldName4      = keyFieldname4
         FROM WMReport WMR (NOLOCK)
         JOIN WMReportdetail WMRD (NOLOCK) ON WMR.reportid = WMRD.reportid
         WHERE Storerkey = @cStorerkey
            AND reporttype = 'TPPACKLIST'
            AND ModuleID = 'TPPack'
            AND ispaperprinter = 'Y'
            AND (WMRD.username = '' OR WMRD.username = @cUsername)
            AND (ISNULL(ComputerName,'') ='' OR ComputerName = @cWorkstation)


         SET @cSQL = ''
         SET @cSQLParam = ''

         SET  @cSQL =
         'SELECT  @cParams1='+ @cFieldName1  
            SELECT @cSQL= CASE WHEN ISNULL(@cFieldName2,'') <> '' THEN @cSQL +',@cParams2 = '  + @cFieldName2  ELSE  @cSQL END 
            SELECT @cSQL= CASE WHEN ISNULL(@cFieldName3,'') <> '' THEN @cSQL +',@cParams3 = '  + @cFieldName3  ELSE  @cSQL END
            SELECT @cSQL= CASE WHEN ISNULL(@cFieldName4,'') <> '' THEN @cSQL +',@cParams4 = '  + @cFieldName4  ELSE  @cSQL END
         SET @cSQL = @cSQL +' FROM Packdetail (NOLOCK)
            WHERE Storerkey = @cstorerkey
               AND Pickslipno = @cPickslipno
               AND CartonNO = @nCartonno
         '

         SET @cSQLParam = 
         '  @cFieldName1 NVARCHAR(max),
            @cFieldName2 NVARCHAR(max),
            @cFieldName3 NVARCHAR(max),
            @cFieldName4 NVARCHAR(max),
            @cParams1    NVARCHAR(max) OUTPUT,
            @cParams2    NVARCHAR(max) OUTPUT,
            @cParams3    NVARCHAR(max) OUTPUT,
            @cParams4    NVARCHAR(max) OUTPUT,
            @cstorerkey  NVARCHAR(20),
            @cPickslipno NVARCHAR(20),
            @nCartonno   INT'

         EXEC sp_ExecuteSQL @cSQL,@cSQLParam,@cFieldName1,@cFieldName2,@cFieldName3,@cFieldName4,
            @cParams1 OUTPUT,@cParams2 OUTPUT,@cParams3 OUTPUT,@cParams4 OUTPUT,@cstorerkey,@cPickslipno,@nCartonno 

            
         IF ISNULL(@cNewPaperPrinter,'')= ''
            SET @cNewPaperPrinter = @cPaperPrinter


         EXEC  [WM].[lsp_WM_Print_Report]
            @c_ModuleID     = @c_ModuleID           
         , @c_ReportID     = @c_ReportID         
         , @c_Storerkey    = @cStorerkey         
         , @c_Facility     = @cFacility        
         , @c_UserName     = @cUsername     
         , @c_ComputerName = @cWorkstation
         , @c_PrinterID    = @cPaperPrinter         
         , @n_NoOfCopy     = '1'     
         , @c_KeyValue1    = @cParams1        
         , @c_KeyValue2    = @cParams2     
         , @c_KeyValue3    = @cParams3 
         , @c_KeyValue4    = @cParams4
         , @b_Success      = @b_Success         OUTPUT      
         , @n_Err          = @n_Err             OUTPUT
         , @c_ErrMsg       = @c_ErrMsg          OUTPUT
         , @c_PrintSource  = @c_PrintSource        
         , @b_SCEPreView   = 0         
         , @c_JobIDs       = @cPackingJobID         OUTPUT    
         , @c_AutoPrint    = 'N'   
                  
         SET @cPackingJobID = @nJobID 

         FETCH NEXT FROM @cCurPaper INTO @cReportType

      END

      CLOSE @cCurLabel
      DEALLOCATE @cCurLabel

      IF @cPrintPackList = 'Y'
      BEGIN

         SET @cCurLabel = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT reporttype
         FROM WMReport WMR WITH (NOLOCK)
            JOIN WMReportdetail WMRD (NOLOCK) ON WMR.reportid =WMRD.reportid
         WHERE  Storerkey = @cStorerkey
            AND ispaperprinter <> 'Y'
            AND WMR.ReportType IN (SELECT CL.CODE
                                       FROM CODELKUP CL(NOLOCK)
                                       WHERE CL.Storerkey = @cStorerkey
                                          AND CL.LISTNAME = 'TPSPrtLast'
                                       )
            AND WMR.moduleid = @c_ModuleID
            AND (ISNULL(ComputerName,'') ='' OR ComputerName= @cWorkstation)
            AND (WMRD.Facility = '' OR WMRD.Facility = @cFacility)  
         ORDER BY WMR.reportid
         OPEN @cCurLabel
         FETCH NEXT FROM @cCurLabel INTO @cReportType
         WHILE @@FETCH_STATUS = 0
         BEGIN

            SELECT   @c_ReportID = WMR.reportid,
                     @c_PrintSource = CASE WHEN printtype = 'LOGIREPORT' THEN 'JReport' ELSE 'WMReport' END,
                     @cNewLabelPrinter = Defaultprinterid,
                     @cFieldName1  = keyFieldname1,
                     @cFieldName2  = keyFieldname2,
                     @cFieldName3  = keyFieldname3,
                     @cFieldName4  = keyFieldname4
            FROM WMReport WMR (NOLOCK)
            JOIN WMReportdetail WMRD (NOLOCK) ON WMR.reportid =WMRD.reportid
            WHERE Storerkey = @cStorerkey
               AND reporttype = @cReportType
               AND ModuleID ='TPPack'
               AND ispaperprinter <> 'Y'
               and (WMRD.username = '' OR WMRD.username = @cUsername)
               AND (ISNULL(ComputerName,'') = '' OR ComputerName = @cWorkstation)
               AND (WMRD.Facility = '' OR WMRD.Facility = @cFacility)  

            SET  @cSQL =
            'select  @cParams1 ='+ @cFieldName1  
               SELECT @cSQL= CASE WHEN ISNULL(@cFieldName2,'') <> '' THEN @cSQL +',@cParams2 = '  + @cFieldName2  ELSE  @cSQL END 
               SELECT @cSQL= CASE WHEN ISNULL(@cFieldName3,'') <> '' THEN @cSQL +',@cParams3 = '  + @cFieldName3  ELSE  @cSQL END
               SELECT @cSQL= CASE WHEN ISNULL(@cFieldName4,'') <> '' THEN @cSQL +',@cParams4 = '  + @cFieldName4  ELSE  @cSQL END
            SET @cSQL = @cSQL +' FROM Packdetail (NOLOCK)
               WHERE Storerkey = @cstorerkey
                  AND Pickslipno = @cPickslipno
                  AND CartonNO = @nCartonno'

            SET @cSQLParam = 
            ' @cFieldName1 NVARCHAR(max),
               @cFieldName2 NVARCHAR(max),
               @cFieldName3 NVARCHAR(max),
               @cFieldName4 NVARCHAR(max),
               @cParams1    NVARCHAR(max) OUTPUT,
               @cParams2    NVARCHAR(max) OUTPUT,
               @cParams3    NVARCHAR(max) OUTPUT,
               @cParams4    NVARCHAR(max) OUTPUT,
               @cstorerkey  NVARCHAR(20),
               @cPickslipno NVARCHAR(20),
               @nCartonno   INT'



            EXEC sp_ExecuteSQL @cSQL,@cSQLParam,@cFieldName1,@cFieldName2,@cFieldName3,@cFieldName4,
               @cParams1 OUTPUT,@cParams2 OUTPUT,@cParams3 OUTPUT,@cParams4 OUTPUT,@cstorerkey,@cPickslipno,@nCartonno 

            IF ISNULL(@cNewLabelPrinter,'')= ''
               SET @cNewLabelPrinter = @cLabelPrinter

            EXEC  [WM].[lsp_WM_Print_Report]
             @c_ModuleID      = @c_ModuleID           
            , @c_ReportID     = @c_ReportID         
            , @c_Storerkey    = @cStorerkey         
            , @c_Facility     = @cFacility        
            , @c_UserName     = @cUsername   
            , @c_ComputerName = @cWorkstation
            , @c_PrinterID    = @cNewLabelPrinter         
            , @n_NoOfCopy     = '1'     
            , @c_KeyValue1    = @cParams1        
            , @c_KeyValue2    = @cParams2        
            , @c_KeyValue3    = @cParams3     
            , @c_KeyValue4    = @cParams4       
            , @b_Success      = @b_Success         OUTPUT      
            , @n_Err          = @n_Err             OUTPUT
            , @c_ErrMsg       = @c_ErrMsg          OUTPUT
            , @c_PrintSource  = @c_PrintSource        
            , @b_SCEPreView   = 0         
            , @c_JobIDs       = @nJobID         OUTPUT    
            , @c_AutoPrint    = 'N'     

            SET @cLabelJobID = @nJobID

            FETCH NEXT FROM @cCurLabel INTO @cReportType

         END


         SET @cCurPaper = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT reporttype
         FROM WMReport WMR WITH (NOLOCK)
            JOIN WMReportdetail WMRD (NOLOCK) ON WMR.reportid = WMRD.reportid
         WHERE  Storerkey = @cStorerkey
               AND ispaperprinter = 'Y'
               AND WMR.moduleid = @c_ModuleID
               AND WMR.ReportType IN ( SELECT CL.CODE
                           FROM CODELKUP CL(NOLOCK)
                           WHERE CL.Storerkey = @cStorerkey
                              AND CL.LISTNAME = 'TPSPrtLast'
                           )
               AND (ISNULL(ComputerName,'') ='' OR ComputerName = @cWorkstation)
               AND (WMRD.Facility = '' OR WMRD.Facility = @cFacility)  
         OPEN @cCurPaper
         FETCH NEXT FROM @cCurPaper INTO @cReportType
         WHILE @@FETCH_STATUS = 0
         BEGIN
            SELECT @c_ReportID   = WMR.reportid,
               @c_PrintSource    = CASE WHEN printtype='LOGIREPORT' THEN 'JReport' ELSE 'WMReport' END,
               @cNewPaperPrinter = Defaultprinterid,
               @cFieldName1      = keyFieldname1,
               @cFieldName2      = keyFieldname2,
               @cFieldName3      = keyFieldname3,
               @cFieldName4      = keyFieldname4
            FROM WMReport WMR (NOLOCK)
            JOIN WMReportdetail WMRD (NOLOCK) ON WMR.reportid = WMRD.reportid
            WHERE Storerkey = @cStorerkey
               AND reporttype = @cReportType
               AND ModuleID = 'TPPack'
               AND ispaperprinter = 'Y'
               AND (WMRD.username = '' OR WMRD.username = @cUsername)
               AND (ISNULL(ComputerName,'') ='' OR ComputerName = @cWorkstation)
               AND (WMRD.Facility = '' OR WMRD.Facility = @cFacility)  


            SET @cSQL = ''
            SET @cSQLParam = ''

            SET  @cSQL =
            'SELECT  @cParams1='+ @cFieldName1  
               SELECT @cSQL= CASE WHEN ISNULL(@cFieldName2,'') <> '' THEN @cSQL +',@cParams2 = '  + @cFieldName2  ELSE  @cSQL END 
               SELECT @cSQL= CASE WHEN ISNULL(@cFieldName3,'') <> '' THEN @cSQL +',@cParams3 = '  + @cFieldName3  ELSE  @cSQL END
               SELECT @cSQL= CASE WHEN ISNULL(@cFieldName4,'') <> '' THEN @cSQL +',@cParams4 = '  + @cFieldName4  ELSE  @cSQL END
            SET @cSQL = @cSQL +' FROM Packdetail (NOLOCK)
               WHERE Storerkey = @cstorerkey
                  AND Pickslipno = @cPickslipno
                  AND CartonNO = @nCartonno
           '

            SET @cSQLParam = 
            '  @cFieldName1 NVARCHAR(max),
               @cFieldName2 NVARCHAR(max),
               @cFieldName3 NVARCHAR(max),
               @cFieldName4 NVARCHAR(max),
               @cParams1    NVARCHAR(max) OUTPUT,
               @cParams2    NVARCHAR(max) OUTPUT,
               @cParams3    NVARCHAR(max) OUTPUT,
               @cParams4    NVARCHAR(max) OUTPUT,
               @cstorerkey  NVARCHAR(20),
               @cPickslipno NVARCHAR(20),
               @nCartonno   INT'

            EXEC sp_ExecuteSQL @cSQL,@cSQLParam,@cFieldName1,@cFieldName2,@cFieldName3,@cFieldName4,
               @cParams1 OUTPUT,@cParams2 OUTPUT,@cParams3 OUTPUT,@cParams4 OUTPUT,@cstorerkey,@cPickslipno,@nCartonno 

            
            IF ISNULL(@cNewPaperPrinter,'')= ''
               SET @cNewPaperPrinter = @cPaperPrinter


            EXEC  [WM].[lsp_WM_Print_Report]
              @c_ModuleID     = @c_ModuleID           
            , @c_ReportID     = @c_ReportID         
            , @c_Storerkey    = @cStorerkey         
            , @c_Facility     = @cFacility        
            , @c_UserName     = @cUsername     
            , @c_ComputerName = @cWorkstation
            , @c_PrinterID    = @cPaperPrinter         
            , @n_NoOfCopy     = '1'     
            , @c_KeyValue1    = @cParams1        
            , @c_KeyValue2    = @cParams2     
            , @c_KeyValue3    = @cParams3 
            , @c_KeyValue4    = @cParams4
            , @b_Success      = @b_Success         OUTPUT      
            , @n_Err          = @n_Err             OUTPUT
            , @c_ErrMsg       = @c_ErrMsg          OUTPUT
            , @c_PrintSource  = @c_PrintSource        
            , @b_SCEPreView   = 0         
            , @c_JobIDs       = @cPackingJobID         OUTPUT    
            , @c_AutoPrint    = 'N'   
                  
            SET @cPackingJobID = @nJobID 

            FETCH NEXT FROM @cCurPaper INTO @cReportType

         END
      END
	END

Quit:

END

SET QUOTED_IDENTIFIER OFF

GO