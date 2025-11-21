SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/  
/* Store procedure: rdt_593Print14                                         */  
/*                                                                         */  
/* Purpose: Print invoice using parameter keyed in.                        */  
/*          GUI.Userdefine01 as Base64 encoded string containing           */
/*          the invoice in PDF form                                        */
/*                                                                         */  
/* Date       Rev  Author   Purposes                                       */  
/* 2017-11-02 1.0  James    WMS3192. Created                               */  
/***************************************************************************/  
  
CREATE PROC [RDT].[rdt_593Print14] (  
   @nMobile    INT,  
   @nFunc      INT,  
   @nStep      INT,  
   @cLangCode  NVARCHAR( 3),  
   @cStorerKey NVARCHAR( 15),  
   @cOption    NVARCHAR( 1),  
   @cParam1    NVARCHAR(20),  -- OrderKey  
   @cParam2    NVARCHAR(20),  -- Carton no
   @cParam3    NVARCHAR(20),  -- Reprint from web service  
   @cParam4    NVARCHAR(20),  
   @cParam5    NVARCHAR(20),  
   @nErrNo     INT OUTPUT,  
   @cErrMsg    NVARCHAR( 20) OUTPUT  
)  
AS  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
  
   DECLARE @cDataWindow   NVARCHAR( 50)  
          ,@cTargetDB     NVARCHAR( 20)  
          ,@cPrinter      NVARCHAR( 10)
          ,@cOrderKey     NVARCHAR( 10)  
          ,@cVBErrMsg         NVARCHAR( MAX)
          ,@cPrintData        NVARCHAR( MAX)
          ,@cWorkingFilePath  NVARCHAR( 250)
          ,@cFilePath         NVARCHAR( 250)
          ,@cDelFilePath      NVARCHAR( 250)
          ,@cChkFilePath      NVARCHAR( 250)
          ,@cFileName         NVARCHAR( 100)
          ,@cPrintFilePath    NVARCHAR( 250)
          ,@cCMD              NVARCHAR( 1000)
          ,@cFileType         NVARCHAR( 10)
          ,@cPrintServer      NVARCHAR( 50)
          ,@cStringEncoding   NVARCHAR( 30)
          ,@cGUIExtOrderKey   NVARCHAR( 30)
          ,@cInvoiceNo        NVARCHAR( 10)
          ,@cOrd_Status       NVARCHAR( 10)
          ,@nReturnCode       INT
          ,@isExists          INT
          ,@bSuccess          INT

   DECLARE @c_AlertMessage       NVARCHAR(512), 
           @c_NewLineChar        NVARCHAR(2), 
           @c_PrintErrmsg        NVARCHAR(250), 
           @b_success            INT,
           @n_Err                INT
   
   -- Screen mapping
   -- OrderKey = @cParam1
   -- ExternOrderKey = @cParam2
   -- Invoice = @cParam3
   -- UserDefinedPrinter = @cParam4

   IF ISNULL( @cParam1, '') = '' AND ISNULL( @cParam2, '') = '' AND ISNULL( @cParam3, '') = ''
   BEGIN
      SET @nErrNo = 116601  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --VALUE REQUIRED
      GOTO Quit  
   END

   -- Get the print data
   SELECT @cOrderKey = O.OrderKey, @cOrd_Status = O.Status
   FROM GUI GUI WITH (NOLOCK)
   JOIN ORDERS O WITH (NOLOCK) ON GUI.ExternOrderKey = O.BuyerPO
   WHERE ( ISNULL( @cParam1, '') = '' OR O.OrderKey = @cParam1)
   AND   ( ISNULL( @cParam2, '') = '' OR O.ExternOrderKey = @cParam2)
   AND   ( ISNULL( @cParam3, '') = '' OR GUI.InvoiceNo = @cParam3)
   AND   O.StorerKey = @cStorerKey

   IF @@ROWCOUNT = 0
   BEGIN
      SET @nErrNo = 116602
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --NO MATCH FOUND
      GOTO Quit  
   END

   IF @cOrd_Status < '5'
   BEGIN
      SET @nErrNo = 116603
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --ORD NOT PACK CFM
      GOTO Quit  
   END

   SELECT @cGUIExtOrderKey = BuyerPO
   FROM dbo.ORDERS WITH (NOLOCK)
   WHERE OrderKey = @cOrderKey
   AND   StorerKey = @cStorerkey

   SELECT TOP 1 @cInvoiceNo = InvoiceNo
   FROM dbo.GUIDetail WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey 
   AND   ExternOrderKey = @cGUIExtOrderKey
   ORDER BY 1

   IF @@ROWCOUNT = 0
   BEGIN
      SET @nErrNo = 116604
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --NO INVOICE VAL
      GOTO Quit  
   END

   -- Get the related printing info, path, file type, etc
   SELECT @cWorkingFilePath = UDF01,
            @cFileType = UDF02,
            @cPrintServer = UDF03,
            @cStringEncoding = UDF04,
            @cPrintFilePath = Notes   -- foxit program
   FROM dbo.CODELKUP WITH (NOLOCK) 
   WHERE ListName = 'PrintLabel' 
   AND   Code = 'FilePath'
   AND   Storerkey = @cStorerKey
   AND   (( ISNULL( code2, '') = '') OR ( code2 = 'PDF'))

   IF @@ROWCOUNT = 0
   BEGIN
      SET @nErrNo = 116605
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Setup CODEKLP'  
      GOTO Quit
   END

   -- Construct print file
   SET @cFileName = RTRIM( @cGUIExtOrderKey) + '-' + RTRIM( @cInvoiceNo) + '.' + @cFileType
   SET @cFilePath = RTRIM( @cWorkingFilePath) + '\' + @cFileName
   SET @cDelFilePath = 'DEL ' + RTRIM( @cWorkingFilePath) + '\' + @cFileName

   -- Check if invoice pdf file exists
   --EXEC master.dbo.xp_fileexist @cFilePath, @isExists OUTPUT

   SET @cChkFilePath = 'DIR ' + @cFilePath
   EXEC @isExists=XP_CMDSHELL @cChkFilePath

   --If @Exists=0, then the file exists. This saves having to declare and query a temp table, 
   --but requires that you know the file name and extension.
   IF @isExists <> 0
   BEGIN
      SET @nErrNo = 116606
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --NO PDF INVOICE
      GOTO Quit  
   END

   IF ISNULL( @cParam4, '') <> ''
   BEGIN
      IF NOT EXISTS ( SELECT 1 FROM RDT.RDTPRINTER WITH (NOLOCK)
                      WHERE PrinterID = @cParam4)
      BEGIN
         SET @nErrNo = 116607
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --INV PRINTER
         GOTO Quit  
      END
      ELSE
         SET @cPrinter = @cParam4
   END
   ELSE
   BEGIN
      SELECT @cPrinter = Printer_Paper
      FROM rdt.rdtMobRec WITH (NOLOCK)
      WHERE Mobile = @nMobile

      -- Check if valid printer 
      IF ISNULL( @cPrinter, '') = ''
      BEGIN
         SET @nErrNo = 116608
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'No Printer'  
         GOTO Quit
      END
   END

   -- Print command
   SET @nReturnCode = 0
   --SET @cCMD = '""' + @cPrintFilePath + '" /t "' + @cWorkingFilePath + '\' + @cFileName + '" "' + @cPrintServer + '"'
   SET @cCMD = '""' + @cPrintFilePath + '" /t "' + @cWorkingFilePath + '\' + @cFileName + '" "' + @cPrinter + '"'
   --SET @cCMD = @cPrintFilePath + ' /t ' + @cWorkingFilePath + '\' + @cFileName + ' ' + @cPrinter 

   DECLARE @tCMDError TABLE(
      ErrMsg NVARCHAR(250)
   )

   -- Send print command
   INSERT INTO @tCMDError
   EXEC @nReturnCode = xp_cmdshell @cCMD
   
   IF @nReturnCode <> 0
   BEGIN
      SET @c_NewLineChar =  master.dbo.fnc_GetCharASCII(13) + master.dbo.fnc_GetCharASCII(10)   

      SELECT TOP 1 @c_PrintErrmsg = Errmsg FROM @tCMDError

      -- Send Alert message
      SET @c_AlertMessage = 'ERROR in printing label with invoice #: ' + @cInvoiceNo + @c_NewLineChar   
      SET @c_AlertMessage = RTRIM(@c_AlertMessage) + 'EEROR: ' + RTRIM( @c_PrintErrmsg) + @c_NewLineChar   
      SET @c_AlertMessage = RTRIM(@c_AlertMessage) + 'PRINT CMD: ' + RTRIM( @cCMD) + @c_NewLineChar   
      SET @c_AlertMessage = RTRIM(@c_AlertMessage) + 'By User: ' + sUser_sName() + @c_NewLineChar   
      SET @c_AlertMessage = RTRIM(@c_AlertMessage) + 'DateTime: ' + CONVERT(NVARCHAR(20), GETDATE())  +  @c_NewLineChar   

      EXEC nspLogAlert  
           @c_modulename         = 'rdt_593Print14'       
         , @c_AlertMessage       = @c_AlertMessage     
         , @n_Severity           = '5'         
         , @b_success            = @b_success     OUTPUT         
         , @n_err                = @nErrNo         OUTPUT           
         , @c_errmsg             = @cErrmsg        OUTPUT        
         , @c_Activity           = 'Print_Invoice'  
         , @c_Storerkey          = @cStorerkey      
         , @c_SKU                = ''            
         , @c_UOM                = ''            
         , @c_UOMQty             = ''         
         , @c_Qty                = ''  
         , @c_Lot                = ''           
         , @c_Loc                = ''            
         , @c_ID                 = ''               
         , @c_TaskDetailKey      = ''  
         , @c_UCCNo              = @cInvoiceNo        

      SET @nErrNo = 116609
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Print Error'  
      GOTO Quit
   END
   
   -- If insert RDTPrintJob
   INSERT INTO RDT.RDTPrintJob(JobName, ReportID, JobStatus, Datawindow, NoOfParms, Parm1, Printer, NoOfCopy, Mobile, TargetDB, JobType)
   VALUES('PRINT_INVOICE', 'INVOICE', '9', 'rdt_593Print14', '1', @cInvoiceNo, @cPrinter, 1, 0, '', 'DIRECTPRN')

   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 116610
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Ins Job Fail'  
      GOTO Quit
   END

Quit:  

GO