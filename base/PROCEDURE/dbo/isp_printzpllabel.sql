SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_PrintZplLabel                                  */  
/*                                                                      */  
/* Purpose: Direct print to label printer                               */  
/* 1. Get print data from carton track                                  */  
/* 2. Generate print data to zpl file                                   */  
/* 3. Send file to printer                                              */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author     Purposes                                 */  
/* 29-Jun-2016 1.0  James      Created                                  */  
/* 29-Jul-2016 1.1  KTLow      Ignore Base64 Decode If No Setup In      */  
/*           Codelkup (KT01)         */  
/* 16-Jan-2018 1.2  James      WMS3192-Add Code2 filter in codelkup     */  
/*                             selection (james01)                      */  
/* 23-Oct-2019 1.3  KHChan     Extend Field Length (KH01)               */  
/* 20-Jul-2021 1.4  KHChan     LFI-2883 Extend Field Length (KH02)      */  
/* 20-Nov-2022 1.5  YeeKung     abandon cmdshell method                 */   
/* 29-Mar-2023 1.6  KHChan     Add parameter (KH03)                     */ 
/************************************************************************/  
  
CREATE   PROC [dbo].[isp_PrintZplLabel](  
    @cStorerKey        NVARCHAR( 15)    
   ,@cLabelNo          NVARCHAR(20)  
   --,@cTrackingNo       NVARCHAR(20) --(KH02)   
   ,@cTrackingNo       NVARCHAR(40) --(KH02)   
   --,@cPrinter          NVARCHAR(10) --(KH01)  
   ,@cPrinter          NVARCHAR(50) --(KH01)  
   ,@nErrNo            INT            OUTPUT    
   ,@cErrMsg           NVARCHAR(215)  OUTPUT  
   ,@cPrintMsg         NVARCHAR(MAX) = '' --(KH03)
)  
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
   SET ANSI_NULLS OFF  
  
   DECLARE @tCMDError TABLE(  
      ErrMsg NVARCHAR(250)  
   )  
  
   DECLARE  
      @cLabels                 NVARCHAR(MAX),  
      @cVBErrMsg               NVARCHAR(MAX) ='',  
      @cPrintData              NVARCHAR(MAX),  
      @cWorkingFilePath        NVARCHAR(250),  
      @cFilePath               NVARCHAR(250),  
      @cDelFilePath            NVARCHAR(250),  
      @cChkFilePath            NVARCHAR(250),  
      @cFileName               NVARCHAR(100),  
      @cPrintFilePath          NVARCHAR(250),  
      @cCMD                    NVARCHAR(1000),  
      @cFileType               NVARCHAR(10),  
      @cPrintServer            NVARCHAR(50),  
      @cLangCode               NVARCHAR(3),  
      @cStringEncoding         NVARCHAR(30),  
      @nReturnCode             INT,  
      @isExists                INT  
  
   DECLARE @c_AlertMessage       NVARCHAR(512),   
           @c_NewLineChar        NVARCHAR(2),   
           @c_PrintErrmsg        NVARCHAR(250),   
           @b_success            INT,  
           @n_Err                INT,  
           @cBatchFilePath       NVARCHAR(255)  
  
   DECLARE @cWorkingFilePath2 NVARCHAR(MAX)  
  
      SET @c_NewLineChar =  master.dbo.fnc_GetCharASCII(13) + master.dbo.fnc_GetCharASCII(10)     
  
      SET @cLangCode = 'ENG'  
  
      -- Get the related printing info, path, file type, etc  
      SELECT @cWorkingFilePath = UDF01,  
             @cFileType = UDF02,  
             @cPrintServer = UDF03,  
             @cStringEncoding = UDF04,  
             @cBatchFilePath = udf05,  
             @cWorkingFilePath2  = notes2  
      FROM dbo.CODELKUP WITH (NOLOCK)   
      WHERE ListName = 'PrintLabel'   
      AND   Code = 'FilePath'  
      AND   Storerkey = @cStorerKey  
      AND   (( ISNULL( Code2, '') = '') OR ( Code2 = 'ZPL'))   -- (james01)  
  
      IF @@ROWCOUNT = 0  
      BEGIN  
         SET @nErrNo = 101901    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Setup CODEKLP'    
         GOTO Quit  
      END  
  
      -- Get the print data  
      --(KH03) - S
      IF @cPrintMsg <> ''
         SET @cLabels = @cPrintMsg
      ELSE
      --(KH03) - E
         SELECT @cLabels = PrintData   
         FROM dbo.CartonTrack (nolock)   
         WHERE Trackingno = @cTrackingNo  
  
      IF ISNULL( @cLabels, '') = ''  
      BEGIN  
         SET @nErrNo = 101902    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'No Print Data'    
         GOTO Quit  
      END  
  
      -- Check if valid printer   
      IF ISNULL( @cPrinter, '') = ''  
      BEGIN  
         SET @nErrNo = 101903    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'No Printer'    
         GOTO Quit  
      END  
  
      --DECLARE @cWorkingFilePath2 NVARCHAR(MAX)  
  
      --set @cWorkingFilePath2 ='\\VMJPWMSSSPD4\d$\ZPL'  
  
      -- Construct print file  
      SET @cFileName = @cTrackingNo + '.' + @cFileType  
      SET @cFilePath = RTRIM( @cWorkingFilePath) + '\' + @cFileName  
      SET @cDelFilePath = 'DEL ' + RTRIM(@cWorkingFilePath2) + '\' + @cFileName  
  
      -- Encoding  
  IF @cStringEncoding <> '' --(KT01)  
  BEGIN  
   SET @cErrMsg = ''  
   EXEC master.dbo.isp_Base64Encode  
    @cStringEncoding,  
    @cLabels,  
    @cPrintData       OUTPUT,  
    @cErrMsg          OUTPUT  
  
   IF ISNULL( @cErrMsg, '') <> ''  
   BEGIN  
    SET @nErrNo = 101904  
    SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Print Error'    
    GOTO Quit  
   END  
  END --IF @cStringEncoding <> ''     
      DECLARE @bSuccess INT  
  
      -- Check if zpl file exists before creating. Delete if exists  
      -- EXEC master.dbo.xp_fileexist @cFilePath, @isExists OUTPUT  
  
      --SET @cChkFilePath = 'DIR ' + @cFilePath  
      --EXEC @isExists=XP_CMDSHELL @cChkFilePath  
      EXEC isp_FileExists @cFilePath, @isExists OUTPUT, @bSuccess OUTPUT      
  
      --If @Exists=0, then the file exists. This saves having to declare and query a temp table,   
      --but requires that you know the file name and extension.  
      --IF @isExists = 0  
      --   EXEC xp_cmdshell @cDelFilePath, no_output  
  
      --IF @isExists = 1      
      --   EXEC isp_DeleteFile @cFilePath, @bSuccess OUTPUT    
  
      IF @isExists = 0     
         EXEC [master].[dbo].[isp_GenericFileCreator]  
            @cPrintData,  
            @cFileName,  
            @cWorkingFilePath2,  
            @cvbErrMsg         OUTPUT  
  
      IF isnull(@cvbErrMsg,'')<>''  
      BEGIN  
         set @c_PrintErrmsg = @cvbErrMsg   
  
         -- Send Alert message  
         SET @c_AlertMessage = 'ERROR in printing label with tracking #: ' + @cTrackingNo + @c_NewLineChar     
         SET @c_AlertMessage = RTRIM(@c_AlertMessage) + 'EEROR: ' + RTRIM( @cvbErrMsg) + @c_NewLineChar     
         SET @c_AlertMessage = RTRIM(@c_AlertMessage) + 'By User: ' + sUser_sName() + @c_NewLineChar     
         SET @c_AlertMessage = RTRIM(@c_AlertMessage) + 'DateTime: ' + CONVERT(NVARCHAR(20), GETDATE())  +  @c_NewLineChar     
  
         EXEC nspLogAlert    
              @c_modulename         = 'isp_PrintZplLabel'         
            , @c_AlertMessage       = @c_AlertMessage       
            , @n_Severity           = '5'           
            , @b_success            = @b_success     OUTPUT           
            , @n_err                = @nErrNo         OUTPUT             
            , @c_errmsg             = @cErrmsg        OUTPUT          
            , @c_Activity           = 'Print_ZPL'    
            , @c_Storerkey          = @cStorerkey        
            , @c_SKU                = ''              
            , @c_UOM                = ''              
            , @c_UOMQty             = ''           
            , @c_Qty                = ''    
            , @c_Lot                = ''             
            , @c_Loc                = ''              
            , @c_ID                 = ''                 
            , @c_TaskDetailKey      = ''    
            , @c_UCCNo              = @cTrackingNo          
  
         SET @nErrNo = 101905  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Print Error'    
         GOTO Quit  
      END  
  
  
      DECLARE @cPrinterName NVARCHAR(20)  
      DECLARE @cSpoolerGroup NVARCHAR(20)  
  
      SELECT @cPrinterName=winprinter,  
             @cSpoolerGroup = spoolergroup  
      FROM RDT.RDTprinter (NOLOCK)  
      WHERE printerid=@cPrinter  
  
      SELECT @cPrintServer=ipaddress  
      FROM RDT.rdtspooler (NOLOCK)  
      WHERE spoolergroup=@cSpoolerGroup  
  
      -- Print command  
      SET @nReturnCode = 0  
      SET @cCMD = '"'+@cBatchFilePath+'" copy /b  "' + RTRIM( @cFilePath) + '" "\\' + RTRIM( @cPrintServer) + '\' + RTRIM( @cPrinterName) + '"'  
  
  
      --insert into testtest (a, b) values (@cCMD, @cFolder2Move)      
      DECLARE @tRDTPrintJob AS VariableTable      
      SET @nErrNo = 0      
      EXEC RDT.rdt_Print '99', '593', @cLangCode, 0, 1, '', @cStorerKey, @cPrinter, '',      
         'SHIPLABEL',     -- Report type      
         @tRDTPrintJob,    -- Report params      
         'isp_PrintZplLabel',      
         @nErrNo  OUTPUT,      
         @cErrMsg OUTPUT,      
         1,      
         @cCMD -- Print pdf file here     
  
  
      --IF @isExists = 1      
      --   EXEC isp_DeleteFile @cFilePath, @bSuccess OUTPUT    
  
  
      ---- Send print command  
      --INSERT INTO @tCMDError  
      --EXEC @nReturnCode = xp_cmdshell @cCMD  
  
      --IF @nReturnCode <> 0  
      --BEGIN  
      --   SELECT TOP 1 @c_PrintErrmsg = Errmsg FROM @tCMDError  
  
      --   -- Send Alert message  
      --   SET @c_AlertMessage = 'ERROR in printing label with tracking #: ' + @cTrackingNo + @c_NewLineChar     
      --   SET @c_AlertMessage = RTRIM(@c_AlertMessage) + 'EEROR: ' + RTRIM( @c_PrintErrmsg) + @c_NewLineChar     
      --   SET @c_AlertMessage = RTRIM(@c_AlertMessage) + 'PRINT CMD: ' + RTRIM( @cCMD) + @c_NewLineChar     
      --   SET @c_AlertMessage = RTRIM(@c_AlertMessage) + 'By User: ' + sUser_sName() + @c_NewLineChar     
      --   SET @c_AlertMessage = RTRIM(@c_AlertMessage) + 'DateTime: ' + CONVERT(NVARCHAR(20), GETDATE())  +  @c_NewLineChar     
  
      --   EXEC nspLogAlert    
      --        @c_modulename         = 'isp_PrintZplLabel'         
      --      , @c_AlertMessage       = @c_AlertMessage       
      --      , @n_Severity           = '5'           
      --      , @b_success            = @b_success     OUTPUT           
      --      , @n_err                = @nErrNo         OUTPUT             
      --      , @c_errmsg             = @cErrmsg        OUTPUT          
      --      , @c_Activity           = 'Print_ZPL'    
      --      , @c_Storerkey          = @cStorerkey        
      --      , @c_SKU                = ''              
      --      , @c_UOM                = ''              
      --      , @c_UOMQty             = ''           
      --      , @c_Qty                = ''    
      --      , @c_Lot                = ''             
      --      , @c_Loc                = ''              
      --      , @c_ID                 = ''                 
      --      , @c_TaskDetailKey      = ''    
      --      , @c_UCCNo              = @cTrackingNo          
  
      --   SET @nErrNo = 101905  
      --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Print Error'    
      --   GOTO Quit  
      --END  
  
      ---- If insert RDTPrintJob  
      --INSERT INTO RDT.RDTPrintJob(JobName, ReportID, JobStatus, Datawindow, NoOfParms, Parm1, Printer, NoOfCopy, Mobile, TargetDB, JobType)  
      --VALUES('PRINT_SHIPPINGLABEL', 'SHIPLABEL', '9', 'isp_PrintZplLabel', '1', @cTrackingNo, @cPrinter, 1, 0, '', 'DIRECTPRN')  
  
QUIT:  
  
END -- Procedure   

GO