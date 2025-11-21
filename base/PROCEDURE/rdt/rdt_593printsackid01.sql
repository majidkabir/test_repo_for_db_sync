SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/  
/* Store procedure: rdt_593PrintSackID01                                   */  
/*                                                                         */  
/* Modifications log:                                                      */  
/*                                                                         */  
/* Date       Rev  Author   Purposes                                       */  
/* 2016-06-13 1.0  James    SOS370236 Created                              */  
/***************************************************************************/  
  
CREATE PROC [RDT].[rdt_593PrintSackID01] (  
   @nMobile    INT,  
   @nFunc      INT,  
   @nStep      INT,  
   @cLangCode  NVARCHAR( 3),  
   @cStorerKey NVARCHAR( 15),  
   @cOption    NVARCHAR( 1),  
   @cParam1    NVARCHAR(20),  -- OrderKey  
   @cParam2    NVARCHAR(20),  -- Carton no
   @cParam3    NVARCHAR(20),    
   @cParam4    NVARCHAR(20),  
   @cParam5    NVARCHAR(20),  
   @nErrNo     INT OUTPUT,  
   @cErrMsg    NVARCHAR( 20) OUTPUT  
)  
AS  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
  
   DECLARE @b_Success     INT  
     
   DECLARE @cDataWindow   NVARCHAR( 50)  
          ,@cTargetDB     NVARCHAR( 20)  
          ,@cLabelPrinter NVARCHAR( 10)  
          ,@cReportType   NVARCHAR( 10)
          ,@cPrintJobName NVARCHAR( 60)
          ,@cIntToToteNo  NVARCHAR( 10) 
          ,@cNoOfSack     NVARCHAR( 5) 
          ,@nNoOfSack     INT
          ,@nCurSackID    INT

   DECLARE @nTranCount     INT,
           @nThreshold     INT,
           @bSendEmail     INT,
           @bMsgQueue      INT,
           @nStartNumber   INT,
           @nEndNumber     INT,
           @bSuccess       INT,
           @cWebServiceLogDBName   NVARCHAR(30),  
           @cExecStatements        NVARCHAR(4000),  
           @cExecArguments         NVARCHAR(4000),
           @cRecipients            NVARCHAR(MAX),  
           @cBody                  NVARCHAR(MAX),  
           @cSubject               NVARCHAR(255), 
           @cEmailRecipient1       NVARCHAR(60),  
           @cEmailRecipient2       NVARCHAR(60),  
           @cEmailRecipient3       NVARCHAR(60),  
           @cEmailRecipient4       NVARCHAR(60),  
           @cEmailRecipient5       NVARCHAR(60)  

   DECLARE @cErrMsg1    NVARCHAR( 20),
           @cErrMsg2    NVARCHAR( 20),
           @cErrMsg3    NVARCHAR( 20),
           @cErrMsg4    NVARCHAR( 20),
           @cErrMsg5    NVARCHAR( 20)

   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN rdt_1711DefToTote01

   SET @cNoOfSack = @cParam1

   -- Both value must not blank
   IF ISNULL(@cNoOfSack, '') = '' 
   BEGIN
      SET @nErrNo = 101551  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Value required
      GOTO RollBackTran  
   END

   IF RDT.rdtIsValidQTY( @cNoOfSack, 1) = 0
   BEGIN
      SET @nErrNo = 101552
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid no'
      GOTO RollBackTran
   END

   SET @nNoOfSack = CAST( @cNoOfSack AS INT)
   SET @bSendEmail = 0
   SET @bMsgQueue = 0
   
   -- Get printer info  
   SELECT   
      @cLabelPrinter = Printer
   FROM rdt.rdtMobRec WITH (NOLOCK)  
   WHERE Mobile = @nMobile  
     
   /*-------------------------------------------------------------------------------  
  
                                    Print Ship Label  
  
   -------------------------------------------------------------------------------*/  
  
   -- Check label printer blank  
   IF @cLabelPrinter = ''  
   BEGIN  
      SET @nErrNo = 101553  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelPrnterReq  
      GOTO RollBackTran  
   END  

   SET @cReportType = 'JWINTSACK'
   SET @cPrintJobName = 'PRINT JACK WILL INTERNATIONAL SACK ID'

   -- Get report info  
   SET @cDataWindow = ''  
   SET @cTargetDB = ''  

   SELECT   
      @cDataWindow = ISNULL(RTRIM(DataWindow), ''),  
      @cTargetDB = ISNULL(RTRIM(TargetDB), '') 
   FROM RDT.RDTReport WITH (NOLOCK)   
   WHERE StorerKey = @cStorerKey  
      AND ReportType = @cReportType  

   -- Check data window
   IF ISNULL( @cDataWindow, '') = ''
   BEGIN
      SET @nErrNo = 101554
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup
      GOTO RollBackTran
   END

   -- Check database
   IF ISNULL( @cTargetDB, '') = ''
   BEGIN
      SET @nErrNo = 101555
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TgetDB Not Set
      GOTO RollBackTran
   END

   SET @nCurSackID = 0
   SELECT @nCurSackID = KeyCount
   FROM dbo.NCounter WITH (NOLOCK)
   WHERE KeyName = 'IntToteNoRange'

   SET @bSendEmail = 0
   SET @bMsgQueue = 0

   SELECT   
      @nThreshold       = ISNULL(Short, 0),  
      @nStartNumber     = ISNULL(Long, 0),  
      @nEndNumber       = ISNULL(Notes, 0),  
      @cEmailRecipient1 = ISNULL(RTRIM(UDF01), ''),  
      @cEmailRecipient2 = ISNULL(RTRIM(UDF02), ''),  
      @cEmailRecipient3 = ISNULL(RTRIM(UDF03), ''),  
      @cEmailRecipient4 = ISNULL(RTRIM(UDF04), ''),  
      @cEmailRecipient5 = ISNULL(RTRIM(UDF05), '')  
   FROM dbo.CODELKUP WITH (NOLOCK)  
   WHERE LISTNAME = 'JCKWToteNo'  
   AND   Code = 'IntToteNoRange'  
   AND   StorerKey = @cStorerKey
  
   -- Not Within ConNumber Range  
   IF (@nCurSackID + @nNoOfSack) < @nStartNumber OR (@nCurSackID + @nNoOfSack) > @nEndNumber   
   BEGIN      
      SET @bMsgQueue = 1

      GOTO RollBackTran
   END   

   -- Hit Threshold, Send Email Alert  
   IF ((@nCurSackID + @nNoOfSack) + @nThreshold) >= @nEndNumber  
   BEGIN
      SET @bSendEmail = 1  
      
      GOTO RollBackTran
   END
      
   -- Insert print job  (james15)
   SET @nErrNo = 0                    
   EXEC RDT.rdt_BuiltPrintJob                     
      @nMobile,                    
      @cStorerKey,                    
      @cReportType,                    
      @cPrintJobName,                    
      @cDataWindow,                    
      @cLabelPrinter,                    
      @cTargetDB,                    
      @cLangCode,                    
      @nErrNo  OUTPUT,                     
      @cErrMsg OUTPUT,                    
      @nNoOfSack 

   IF @nErrNo <> 0
      GOTO RollBackTran  

   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN rdt_1711DefToTote01

   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN rdt_1711DefToTote01   

   -- Show error in msg queue
   IF @bMsgQueue = 1
   BEGIN
      SET @nErrNo = 0

      SET @cErrMsg1 = rdt.rdtgetmessage( 101556, @cLangCode, 'DSP') --Not within
      SET @cErrMsg2 = rdt.rdtgetmessage( 101557, @cLangCode, 'DSP') --Default sack#
      SET @cErrMsg3 = rdt.rdtgetmessage( 101558, @cLangCode, 'DSP') --Range          

      SET @cErrMsg1 = SUBSTRING( @cErrMsg1, 7, 14)
      SET @cErrMsg2 = SUBSTRING( @cErrMsg2, 7, 14)
      SET @cErrMsg3 = SUBSTRING( @cErrMsg3, 7, 14)            

      EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
          @cErrMsg1, @cErrMsg2, @cErrMsg3

      IF @nErrNo = 1
      BEGIN
         SET @cErrMsg1 = ''
         SET @cErrMsg2 = ''
         SET @cErrMsg3 = ''
      END
      
      SET @nErrNo = 101557  
   END

   -- Send Email Alert  
   IF @bSendEmail = 1  
   BEGIN  
      -- Get WebService_Log DB Name  
      SELECT @cWebServiceLogDBName = NSQLValue    
      FROM dbo.NSQLConfig WITH (NOLOCK)    
      WHERE ConfigKey = 'WebServiceLogDBName'   
      
      SET @cSubject = 'Default Sack ID Alert - ' + REPLACE(CONVERT(NVARCHAR(19), GETDATE(), 126),'T',' ')  
  
      SET @cBody = CASE WHEN @nEndNumber - @cIntToToteNo > 0 THEN CAST(@nEndNumber - @cIntToToteNo AS NVARCHAR)   
                   ELSE 'No'   
                   END + ' default sack number remaining.' + CHAR(13) + CHAR(10)  
      SET @cBody = @cBody + 'Please setup a new range of sack number.' + CHAR(13) + CHAR(10)  
      SET @cBody = @cBody + 'Kindly update the following after that: ' + CHAR(13) + CHAR(10)  
      SET @cBody = @cBody + ' - Start Range = CODELKUP.Long WHERE Listname = ''DefToteNo'' AND Code = ''DefToteNoRange'' ' + CHAR(13) + CHAR(10)  
      SET @cBody = @cBody + ' - End Range   = CODELKUP.Notes WHERE Listname = ''DefToteNo'' AND Code = ''DefToteNoRange'' ' + CHAR(13) + CHAR(10)  
      SET @cBody = @cBody + ' - Current     = NCounter.KeyCount WHERE KeyName = ''JACKWSACK'' '   
  
      -- Insert into DTSITF.Email alert table to send out email (Chee02)  
      SET @cExecStatements = ''    
      SET @cExecArguments = ''     
      SET @cExecStatements = N'INSERT INTO ' + ISNULL(RTRIM(@cWebServiceLogDBName),'') + '.dbo.EmailAlert ( '    
                             + 'AttachmentID, Subject, Recipient1, Recipient2, Recipient3, '  
                             + 'Recipient4, Recipient5, EmailBody, Status) '     
                             + 'VALUES ( '    
                             + '@nAttachmentID, @cSubject, @cRecipient1, @cRecipient2, @cRecipient3, '  
                             + '@cRecipient4, @cRecipient5, @cEmailBody, @cStatus)'  
             
      SET @cExecArguments = N'@nAttachmentID  INT,           '   
                            + '@cSubject      NVARCHAR(255), '  
                            + '@cRecipient1   NVARCHAR(60),  '  
                            + '@cRecipient2   NVARCHAR(60),  '  
                            + '@cRecipient3   NVARCHAR(60),  '  
                            + '@cRecipient4   NVARCHAR(60),  '  
                            + '@cRecipient5   NVARCHAR(60),  '  
                            + '@cEmailBody    NVARCHAR(MAX), '  
                            + '@cStatus       NVARCHAR(1)    '  
  
      EXEC sp_ExecuteSql @cExecStatements, @cExecArguments,   
                         0, @cSubject, @cEmailRecipient1, @cEmailRecipient2, @cEmailRecipient3,   
                         @cEmailRecipient4, @cEmailRecipient5, @cBody, '0'   
  
      IF @@ERROR <> 0  
      BEGIN
         SET @nErrNo = 101560
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Send email fail
      END 
   END -- IF @bSendEmail = 1  

GO