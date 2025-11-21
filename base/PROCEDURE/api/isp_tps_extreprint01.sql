SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: isp_TPS_ExtREPrint01                                      */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date         Rev  Author     Purposes                                      */
/* 2023-06-23   1.0  yeekung    TPS-690 Created                               */
/* 2023-09-12   1.1  YeeKung    TPS-773/TPS-740 New print (yeekung01)          */
/* 2023-12-11   1.3  YeeKung    TPS-826 Add params for paper (yeekung02)       */
/* 2024-02-09   1.4  YeeKung    TPS-821 Add reporttpe (yeekung03)             */ 
/* 2024-11-06   1.5  YeeKung    TPS-989 Add Facility (yeekung04)              */
/******************************************************************************/

CREATE   PROC [API].[isp_TPS_ExtREPrint01] (
	@cStorerKey      NVARCHAR( 15), 
   @cFacility       NVARCHAR( 5),  
   @nFunc           INT,           
   @cUserName       NVARCHAR( 128),
   @cLangCode       NVARCHAR( 3),  
   @cScanNo         NVARCHAR( 50), 
   @cpickslipNo     NVARCHAR( 30), 
   @cDropID         NVARCHAR( 50), 
   @cOrderKey       NVARCHAR( 10), 
   @nCartonNo       INT,    
   @cType           NVARCHAR( 30), 
   @cWorkstation    NVARCHAR( 30),  
   @PrinterType     NVARCHAR( 20), 
   @cPrintAllLbl    NVARCHAR (20), 
   @nPrintPackList  NVARCHAR (1),
   @cReporttype     NVARCHAR (20),
   @cLabelJobID     NVARCHAR ( 30) OUTPUT,
   @cPackingJobID   NVARCHAR ( 30) OUTPUT,
   @b_Success       INT            OUTPUT,
   @n_Err           INT            OUTPUT,
   @c_ErrMsg        NVARCHAR( 20)  OUTPUT
)
AS
   BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @tUCCLabel AS VariableTable
   DECLARE @tCtnLabel AS VariableTable
   DECLARE @tPackList AS VariableTable
   DECLARE @cConsignee     NVARCHAR(15)
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
         , @c_JobIDs             NVARCHAR(50)   = ''         --(Wan03) -- May return multiple jobs ID.JobID seperate by '|'
         , @c_PrintSource        NVARCHAR(20)
         , @c_AutoPrint          NVARCHAR(1)    = 'N'        --(Wan07)

   DECLARE  @cFieldName1 NVARCHAR(max),
            @cFieldName2 NVARCHAR(max),
            @cFieldName3 NVARCHAR(max),
            @cFieldName4 NVARCHAR(max),
            @cParams1    NVARCHAR(max),
            @cParams2    NVARCHAR(max),
            @cParams3    NVARCHAR(max),
            @cParams4    NVARCHAR(max)

   set @cLabelJobID = ''
   set @cPackingJobID = ''

   SELECT @cPaperPrinter = PrinterID FROM api.AppPrinter WITH (NOLOCK) WHERE Workstation = @cWorkstation AND printerType = 'Paper'
   SELECT @cLabelPrinter = PrinterID FROM api.AppPrinter WITH (NOLOCK) WHERE Workstation = @cWorkstation AND printerType = 'Label'

   select @cTCPPrinter =PrinterID from api.appworkstation (NOLOCK)WHERE Workstation = @cWorkstation


	IF @cPickSlipNo <> ''
	BEGIN
      
      IF @PrinterType = 'Label'
      BEGIN
         DECLARE @cCurLabel CURSOR
         SET @cCurLabel = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT reporttype
         FROM WMReport WMR WITH (NOLOCK)
            JOIN WMReportdetail WMRD (NOLOCK) ON WMR.reportid = WMRD.reportid
         WHERE  Storerkey = @cStorerkey
               AND ispaperprinter <> 'Y'
               AND WMR.moduleid = @c_ModuleID
               AND Reporttype =  CASE WHEN ISNULL(@cReporttype,'') <> '' THEN  @cReporttype ELSE   Reporttype END
               AND (ISNULL(ComputerName,'') ='' OR ComputerName = @cWorkstation)
               AND (WMRD.Facility = '' OR WMRD.Facility = @cFacility)  
         ORDER BY WMR.reportid
         OPEN @cCurLabel
         FETCH NEXT FROM @cCurLabel INTO @cReportType
         WHILE @@FETCH_STATUS = 0
         BEGIN

            SELECT   @c_ReportID = WMR.reportid,
                     @c_PrintSource = CASE WHEN printtype='LOGIREPORT' THEN 'JReport' ELSE 'WMReport' END,
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
               AND (ISNULL(ComputerName,'') ='' OR ComputerName= @cWorkstation)
               AND (WMRD.Facility = '' OR WMRD.Facility = @cFacility)  

            SET  @cSQL =
            '
               select  @cParams1 = '+ @cFieldName1  
                   SELECT @cSQL = CASE WHEN ISNULL(@cFieldName2,'') <> ''THEN @cSQL + ',@cParams2 = '  + @cFieldName2  ELSE  @cSQL END 
                   SELECT @cSQL = CASE WHEN ISNULL(@cFieldName3,'') <> ''THEN @cSQL + ',@cParams3 = '  + @cFieldName3  ELSE  @cSQL END
                   SELECT @cSQL = CASE WHEN ISNULL(@cFieldName4,'') <> ''THEN @cSQL + ',@cParams4 = '  + @cFieldName4  ELSE  @cSQL END
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

            IF ISNULL(@cNewLabelPrinter,'') = ''
               SET @cNewLabelPrinter = @cLabelPrinter

            select @c_ModuleID,@c_ReportID


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

            --To avoid the label print in sequence
            --EG: Labelno should print out first by use tcp method and UCC is bartender method
            --    but UCC print out first, 
            WAITFOR DELAY '00:00:02'


            SET @cLabelJobID = @nJobID

            FETCH NEXT FROM @cCurLabel INTO @cReportType
         END
      END

      IF @PrinterType = 'Paper'
      BEGIN

         DECLARE @cCurPaper CURSOR
         SET @cCurPaper = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT reporttype
         FROM WMReport WMR WITH (NOLOCK)
            JOIN WMReportdetail WMRD (NOLOCK) ON WMR.reportid = WMRD.reportid
         WHERE  Storerkey = @cStorerkey
               AND ispaperprinter = 'Y'
               AND WMR.moduleid = @c_ModuleID
               AND Reporttype =  CASE WHEN ISNULL(@cReporttype,'') <> '' THEN  @cReporttype ELSE   Reporttype END
               AND (ISNULL(ComputerName,'') = '' OR ComputerName = @cWorkstation)
               AND (WMRD.Facility = '' OR WMRD.Facility = @cFacility)  
         OPEN @cCurPaper
         FETCH NEXT FROM @cCurPaper INTO @cReportType
         WHILE @@FETCH_STATUS = 0
         BEGIN


            SELECT   @c_ReportID = WMR.reportid,
               @c_PrintSource = CASE WHEN printtype='LOGIREPORT' THEN 'JReport' ELSE 'WMReport' END,
               @cNewPaperPrinter = Defaultprinterid,
               @cFieldName1  = keyFieldname1,
               @cFieldName2  = keyFieldname2,
               @cFieldName3  = keyFieldname3,
               @cFieldName4  = keyFieldname4
            FROM WMReport WMR (NOLOCK)
            JOIN WMReportdetail WMRD (NOLOCK) ON WMR.reportid =WMRD.reportid
            WHERE Storerkey = @cStorerkey
               AND reporttype = 'TPPACKLIST'
               AND ModuleID ='TPPack'
               AND ispaperprinter = 'Y'
               and (WMRD.username = '' OR WMRD.username = @cUsername)
               AND (ISNULL(ComputerName,'') = '' OR ComputerName = @cWorkstation)
               AND (WMRD.Facility = '' OR WMRD.Facility = @cFacility)  


            SET @cSQL = ''
            SET @cSQLParam = ''

            SET  @cSQL =
            'SELECT  @cParams1 = '+ @cFieldName1  
                     SELECT @cSQL= CASE WHEN ISNULL(@cFieldName2,'') <> '' THEN @cSQL +',@cParams2 = '  + @cFieldName2  ELSE  @cSQL END 
                     SELECT @cSQL= CASE WHEN ISNULL(@cFieldName3,'') <> '' THEN @cSQL +',@cParams3 = '  + @cFieldName3  ELSE  @cSQL END
                     SELECT @cSQL= CASE WHEN ISNULL(@cFieldName4,'') <> '' THEN @cSQL +',@cParams4 = '  + @cFieldName4  ELSE  @cSQL END
            SET @cSQL = @cSQL +' FROM Packdetail (NOLOCK)                                         
               WHERE Storerkey = @cstorerkey
                  AND Pickslipno = @cPickslipno
                  AND CartonNO = @nCartonno
                  '

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
            , @c_JobIDs       = @nJobID         OUTPUT    
            , @c_AutoPrint    = 'N'   
                  
            SET @cPackingJobID = @nJobID  

            DELETE @tUCCLabel

            FETCH NEXT FROM @cCurPaper INTO @cReportType

         END
      END

      IF @n_Err = 0
         SET @b_Success = 1
	END

Quit:

END

GO