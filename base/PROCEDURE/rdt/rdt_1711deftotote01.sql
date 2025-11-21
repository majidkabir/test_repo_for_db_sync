SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_1711DefToTote01                                 */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Generate sack id                                            */
/*                                                                      */
/* Called from: rdtfnc_PTS_Store_Sort                                   */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 02-Jun-2016 1.0  James       SOS370235 - Created                     */
/************************************************************************/

CREATE PROC [RDT].[rdt_1711DefToTote01] (
   @nMobile         INT,           
   @nFunc           INT,           
   @cLangCode       NVARCHAR( 3),  
   @nStep           INT,           
   @nInputKey       INT,           
   @cStorerkey      NVARCHAR( 15), 
   @cCaseID         NVARCHAR( 10), 
   @cLoc            NVARCHAR( 10), 
   @cSKU            NVARCHAR( 20), 
   @nQty            INT,           
   @cOption         NVARCHAR( 1), 
   @cDefToToteNo    NVARCHAR( 20)   OUTPUT,                         
   @nErrNo          INT             OUTPUT,  
   @cErrMsg         NVARCHAR( 20)   OUTPUT   
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

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

   SET @cDefToToteNo= ''

   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN rdt_1711DefToTote01

   SET @bSendEmail = 0
   SET @bMsgQueue = 0

   IF @nInputKey = 1
   BEGIN
      IF @nStep = 5
      BEGIN
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
         AND   Code = 'DefToteNoRange'  
         AND   StorerKey = @cStorerKey
        
         EXECUTE nspg_getkey
            @KeyName       = 'DefToteNoRange' ,
            @fieldlength   = 10,    
            @keystring     = @cDefToToteNo   OUTPUT,
            @b_success     = @bSuccess       OUTPUT,
            @n_err         = @nErrNo         OUTPUT,
            @c_errmsg      = @cErrMsg        OUTPUT,
            @b_resultset   = 0,
            @n_batch       = 1

         IF @nErrNo <> 0 OR @bSuccess <> 1
         BEGIN
            SET @nErrNo = 101451
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Get sack fail
            GOTO RollBackTran
         END

         -- Not Within ConNumber Range  
         IF @cDefToToteNo < @nStartNumber OR @cDefToToteNo > @nEndNumber   
         BEGIN      
            SET @bMsgQueue = 1

            GOTO RollBackTran
         END   

         -- Hit Threshold, Send Email Alert  
         IF @cDefToToteNo + @nThreshold >= @nEndNumber  
         BEGIN
            SET @bSendEmail = 1  
            
            GOTO RollBackTran
         END
      END
   END

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

      SET @cErrMsg1 = rdt.rdtgetmessage( 101452, @cLangCode, 'DSP') --Not within
      SET @cErrMsg2 = rdt.rdtgetmessage( 101453, @cLangCode, 'DSP') --Default sack#
      SET @cErrMsg3 = rdt.rdtgetmessage( 101454, @cLangCode, 'DSP') --Range          

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
      
      SET @nErrNo = 101452  
   END

   -- Send Email Alert  
   IF @bSendEmail = 1  
   BEGIN  
      -- Get WebService_Log DB Name  
      SELECT @cWebServiceLogDBName = NSQLValue    
      FROM dbo.NSQLConfig WITH (NOLOCK)    
      WHERE ConfigKey = 'WebServiceLogDBName'   
      
      SET @cSubject = 'Default Sack ID Alert - ' + REPLACE(CONVERT(NVARCHAR(19), GETDATE(), 126),'T',' ')  
  
      SET @cBody = CASE WHEN @nEndNumber - @cDefToToteNo > 0 THEN CAST(@nEndNumber - @cDefToToteNo AS NVARCHAR)   
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
         SET @nErrNo = 101455
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Send email fail
      END 
   END -- IF @bSendEmail = 1  

END

GO