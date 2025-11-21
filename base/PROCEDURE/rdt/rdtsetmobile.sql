SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: rdtSetMobile                                       */  
/* Creation Date:                                                       */  
/* Copyright: IDS                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose:                                                             */  
/*                                                                      */  
/* Called By:                                                           */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Rev  Author   Purposes                                   */  
/* 22-Nov-2007 1.3  Shong    SOS90411 Display error in another screen   */  
/* 07-Dec-2011 1.4  TLTING   Reset Mobile# after 9000                   */  
/* 02-Oct-2015 1.5  Ung      Performance tuning for CN Nov 11           */
/* 24-May-2024 1.6  NLT013   Add session id to get unique mobile        */
/************************************************************************/  
  
CREATE PROC [RDT].[rdtSetMobile] (  
   @nMobile     int  OUTPUT,  
   @cInMessage  NVARCHAR(1024),  
   @nFunction   int  OUTPUT,  
   @nScn        int  OUTPUT,  
   @nStep       int  OUTPUT,  
   @nMsgQueueNo int  OUTPUT,   
   @nErrNo      int  OUTPUT,  
   @cErrMsg     NVARCHAR(1024) OUTPUT,
   @cSessionID  NVARCHAR(60) = '' OUTPUT
)  
AS  
   SET NOCOUNT ON   -- SQL 2005 Standard  
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF     
   SET CONCAT_NULL_YIELDS_NULL OFF    

   DECLARE @nKey      int,  
           @cLang     NVARCHAR(3),  
           @nMenu     int,  
           @CheckMobile int,  
           @nTMobile    INT,
           @nStartIndex INT,
           @nLength     INT,
           @nLoginRemarks   NVARCHAR(40),
           @cLastSessionID    NVARCHAR(60),
           @dLoginDate        DATETIME,
           @cClientIP         NVARCHAR( 15)

   SET @nStartIndex = CHARINDEX('deviceID="', @cInMessage)
   IF @nStartIndex > 0
   BEGIN
      SET @nStartIndex = @nStartIndex + LEN('deviceID="')
      SET @nLength = CHARINDEX('"', SUBSTRING(@cInMessage, @nStartIndex, LEN(@cInMessage)))
      SET @cSessionID = SUBSTRING(@cInMessage, @nStartIndex, ABS(@nLength - 1))
   END

   SET @cClientIP = ''  
   SET @nStartIndex = CHARINDEX( 'clientIP="', @cInMessage)  
   IF @nStartIndex > 0  
   BEGIN  
      SET @nStartIndex = @nStartIndex + LEN( 'clientIP="')  
      SET @nLength = CHARINDEX( '"', SUBSTRING( @cInMessage, @nStartIndex, LEN( @cInMessage)))  
      SET @cClientIP = SUBSTRING( @cInMessage, @nStartIndex, ABS( @nLength - 1))  
   END  
  
   SET @CheckMobile = 0  

   IF @cSessionID IS NOT NULL AND TRIM(@cSessionID) <> ''
   BEGIN
      SELECT TOP 1
         @nLoginRemarks = ISNULL(Remarks, ''),
         @cLastSessionID = ISNULL(SessionID, ''),
         @dLoginDate = AddDate
      FROM RDT.RDTLoginLog WITH(NOLOCK )
      WHERE Mobile = @nMobile
         AND ISNULL(Remarks, '') NOT LIKE 'Fail to Login%'
      ORDER BY AddDate DESC

      --the mobile is in use and used by different device, and the device kept in live less than 24 hours
      IF @nLoginRemarks LIKE 'Login%' AND @cLastSessionID <> '' AND @cLastSessionID <> @cSessionID AND DATEDIFF(HH, @dLoginDate, GETDATE()) <= 24
      BEGIN
         DECLARE @cUserName NVARCHAR(18)
         SELECT @cUserName = UserName
         FROM RDT.RDTMOBREC WITH(NOLOCK)
         WHERE Mobile = @nMobile

         INSERT INTO RDT.rdtLoginLog (UserName, Mobile, ClientIP, Remarks, SessionID)
         VALUES ('Mobile used by ' + ISNULL(@cUserName, '') + ' - ' + @cLastSessionID, @nMobile, ISNULL(@cClientIP, ''), 'Fail to Login', @cSessionID)

         SET @nMobile = 0
      END
   END
  
   SELECT @nMobile = ISNULL(Mobile, 0),  
          @nFunction = Func,  
          @nScn      = Scn,  
          @nStep     = Step,  
          @CheckMobile = ISNULL(Mobile, 0),    
          @nMsgQueueNo = ISNULL(MsgQueueNo, 0)   
   FROM   RDT.RDTMOBREC (NOLOCK)  
   WHERE  Mobile = @nMobile  

  
   IF @nMobile =0  OR @nMobile IS NULL  or @CheckMobile =0  
   BEGIN  
      SELECT @nMobile = MAX(Mobile)  
      FROM   RDT.RDTMOBREC (NOLOCK)  
     
      IF @nMobile IS NULL OR @nMobile = 0  
         SELECT @nMobile = 1  
      ELSE  
      BEGIN   
         IF @nMobile > 9000  
         BEGIN  
            SET @CheckMobile = 0  
            SET @nTMobile = 500  
            WHILE @CheckMobile = 0  
            BEGIN  
               GOTO ReRun_MobileNo  
               GoBack_ReRun_MobileNo:  
               IF @CheckMobile = 0  
               BEGIN  
                  SET @nTMobile = @nTMobile + 500  
               END  
            END  
            SET @nMobile = @CheckMobile  
         END   
         SELECT @nMobile = @nMobile + 1           
      END  
        
      SELECT @cLang = 'ENG',  
             @nMenu = 0,  
             @nFunction = 0,  
             @nScn      = 0,  
             @nStep     = 0,  
             @nKey      = 1  
     
      BEGIN TRAN  

      IF NOT EXISTS(SELECT 1 FROM RDT.RDTXML_Root (NOLOCK) WHERE Mobile = @nMobile)
         INSERT INTO RDT.RDTXML_Root (mobile) VALUES (@nMobile)
     
      INSERT INTO RDT.RDTMOBREC(  
          Mobile,        Func,          Scn,           Step,         Menu,  
          InputKey)  
      VALUES(@nMobile,   @nFunction,    @nScn,         @nStep,       @nMenu,  
             @nKey)  
     
      IF @@ERROR <> 0  
      BEGIN  
         SELECT @nErrNo = @@ERROR  
         SELECT @cErrMsg = 'Insert into RDTMOBREC Failed! '  
         ROLLBACK  
      END  
      ELSE  
      BEGIN  
         COMMIT TRAN  
      END  
   END
      
   RETURN  
     
ReRun_MobileNo:     
BEGIN  
   SET @CheckMobile = 0  
   SELECT @CheckMobile = ISNULL(MAX(Mobile), 0)  
   FROM   RDT.RDTMOBREC (NOLOCK)   
   WHERE  Mobile < @nTMobile    
  
   IF @CheckMobile IS NULL OR @CheckMobile = 0  
   BEGIN  
      SELECT @CheckMobile = 1  
   END  
  
   -- Do not assign if the range is small. avoid + 1 hit max  
   IF @CheckMobile > @nTMobile - 10  
   BEGIN   
      SET @CheckMobile = 0  
   END   
     
   GOTO GoBack_ReRun_MobileNo  
END  

GO