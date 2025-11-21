SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: isp_CheckTrackingNoThreshold                        */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Check if the temp tracking no fall below threshold.         */
/*          Send email alert if it does.                                */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 13-Jul-2016 1.0  James       Created                                 */
/************************************************************************/

CREATE PROC [dbo].[isp_CheckTrackingNoThreshold] (
   @cStorerkey      NVARCHAR( 15), 
   @nErrNo          INT             OUTPUT,  
   @cErrMsg         NVARCHAR( 20)   OUTPUT   
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @nCount         INT,
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


   SET @bSendEmail = 0
   SET @bMsgQueue = 0

   SELECT   
      @nThreshold       = ISNULL(Short, 0),  
      @cEmailRecipient1 = ISNULL(RTRIM(UDF01), ''),  
      @cEmailRecipient2 = ISNULL(RTRIM(UDF02), ''),  
      @cEmailRecipient3 = ISNULL(RTRIM(UDF03), ''),  
      @cEmailRecipient4 = ISNULL(RTRIM(UDF04), ''),  
      @cEmailRecipient5 = ISNULL(RTRIM(UDF05), '')  
   FROM dbo.CODELKUP WITH (NOLOCK)  
   WHERE LISTNAME = 'ChkTrackNo'  
   AND   Code = 'HMTemp'  
   AND   StorerKey = @cStorerKey

   IF @@ROWCOUNT = 0
      GOTO Quit

   SELECT @nCount = COUNT( 1) 
   FROM CARTONTRACK (NOLOCK) 
   WHERE KeyName = @cStorerKey 
   AND   CarrierName = 'HMTemp' 
   AND   LabelNo = '' 
   AND   CarrierRef2 = ''
   
   -- Hit Threshold, Send Email Alert  
   IF @nCount < @nThreshold 
      SET @bSendEmail = 1  

   -- Send Email Alert  
   IF @bSendEmail = 1  
   BEGIN  
      -- Get WebService_Log DB Name  
      SELECT @cWebServiceLogDBName = NSQLValue    
      FROM dbo.NSQLConfig WITH (NOLOCK)    
      WHERE ConfigKey = 'WebServiceLogDBName'   

      IF ISNULL( @cWebServiceLogDBName, '') = ''
         GOTO Quit

      SET @cSubject = 'H&M temporarily tracking no Alert - ' + REPLACE(CONVERT(NVARCHAR(19), GETDATE(), 126),'T',' ')  
  
      SET @cBody = 'H&M temporarily tracking no has fall below the threshold. ' + CHAR(13) + CHAR(10) 
      SET @cBody = @cBody + 'Current available tracking no: ' + CAST( @nCount AS NVARCHAR ( 5)) + CHAR(13) + CHAR(10)
      SET @cBody = @cBody + 'Threshold: ' + CAST( @nThreshold AS NVARCHAR( 5)) + CHAR(13) + CHAR(10)
      SET @cBody = @cBody + 'Please setup more temporarily tracking no in table CARTONTRACK.' + CHAR(13) + CHAR(10)  
      SET @cBody = @cBody + 'Kindly set the following in table CARTONTRACK: ' + CHAR(13) + CHAR(10)  
      SET @cBody = @cBody + ' - TrackingNo = Get the current largest tracking no + 1' + CHAR(13) + CHAR(10)  
      SET @cBody = @cBody + ' - CarrierName   = ''HMTemp'' ' + CHAR(13) + CHAR(10)  
      SET @cBody = @cBody + ' - KeyName   = ''HM'' ' + CHAR(13) + CHAR(10)  
      SET @cBody = @cBody + ' - LabelNo   = '''' (Blank)' + CHAR(13) + CHAR(10)  
      SET @cBody = @cBody + ' - CarrierRef1   = ''''  (Blank)' + CHAR(13) + CHAR(10)  
      SET @cBody = @cBody + ' - CarrierRef2   = ''''  (Blank)' + CHAR(13) + CHAR(10)  
      SET @cBody = @cBody + ' - Threshold     = Setup in CODELKUP.Short with LISTNAME = ''ChkTrackNo'' '   
  
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
   END -- IF @bSendEmail = 1  

   Quit:
END

GO