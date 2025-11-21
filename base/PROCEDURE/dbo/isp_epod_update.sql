SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_EPOD_Update                                    */
/* Creation Date: 04-Apr-2013                                           */
/* Copyright: IDS                                                       */
/* Written by: Shong                                                    */
/*                                                                      */
/* Purpose: Update POD Status using ePOD method                         */
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
/* Date         Author   Ver  Purposes                                  */
/* 09-May-2013  CSCHONG  1.1  SOS276392  (CS01)                         */
/* 25-JUL-2013  CSCHONG  1.2  Fix the bug when order key not exist(CS01)*/
/* 06-Jun-2014  CHEE     1.3  Add EPOD.AddDate & EPOD.Try (Chee01)      */
/* 17-Jul-2014  CHEE     1.4  SOS#314938 Search for EPOD.OrderKey = POD.*/
/*                            TrackCOl02 & POD.FinalizeFlag='N'(Chee02) */
/* 30-Jul-2014  CHEE     1.5  SOS#314938 Update POD FullRejectDate,     */
/*                            PartialRejectDate, RedeliveryDate based on*/
/*                            EPOD status when turned on StorerConfig - */ 
/*                            CP_ShowPODEventHistory (Chee03)           */
/* 27-Jul-2017  TLTING   1.6  Wrong datatype                            */
/* 26-Feb-2018  Alex     1.7  Bug Fixed (Alex01)                        */
/************************************************************************/

CREATE PROC [dbo].[isp_EPOD_Update] (
  @cStorerKey           NVARCHAR(15),
  @cEPOD_OrderKey       NVARCHAR(50),
  @cEPODStatus          NVARCHAR(10),
  @cEPOD_Date           DATETIME,
  @cEPODNotes           NVARCHAR(1000),
  @cLatitude            NVARCHAR(30),
  @cLongtitude          NVARCHAR(30),
  @cAccountID           NVARCHAR(30),
  @cRejectReasonCode    NVARCHAR(20),
  @nePODKey             BIGINT,
  @dLocationCaptureDate DATETIME,
  @nUID                 INT,
  @cContainImage        NVARCHAR(1),
  @cEmailTitle          NVARCHAR(250)  = '',
  @cEmailRecipients     NVARCHAR(1000) = '',
  @nErrorNo             INT = 1 OUTPUT,
  @cErrorMsg            NVARCHAR(2048) = '' OUTPUT,
  @cEPODAddDate         DATETIME,  -- (Chee01)
  @nEPODTry             INT        -- (Chee01)
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_WARNINGS OFF
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE
      @cMBOLKey          NVARCHAR (10),
      @cMBOLLineNumber   NVARCHAR ( 5),
      @cCurPODStatus     NVARCHAR ( 2),
      @cFinalizeFlag     NVARCHAR ( 1),
      @nCurrRowId        INT

   -- SOS77243
   DECLARE
      @cResonCode  NVARCHAR(10)

   -- (Chee04)
   DECLARE
      @cCP_ShowPODEventHistory NVARCHAR(1)

   DECLARE @nReturnCode      INT
         , @cSubject         NVARCHAR(255)
         , @cEmailBodyHeader NVARCHAR(255)
         , @cTableHTML       NVARCHAR(MAX)
         , @b_debug          INT
         , @cE1_ePODOrderKey NVARCHAR(50)
         , @b_success        INT

   SET @nErrorNo = 0
   SET @cErrorMsg = ''
   SET @nCurrRowId = 0
   SET @cMBOLKey = ''
   SET @cMBOLLineNumber = ''
   SET @cCurPODStatus = '0' -- Initialize current Status in POD table
   SET @cFinalizeFlag = 'N'
   SET @b_debug = 1
   SET @b_Success = 1

   DECLARE @tError TABLE
      ( ErrorNo INT
      , ErrorMessage NVARCHAR(1000))

   /*------------------------*/
   /* Process POD records    */
   /*------------------------*/
   DECLARE
      --@cPrevPODStatus CHAR (1),
      --@cPrevRefNo  CHAR (20),
      @cBlankRefNo NVARCHAR (20)

   --IF NOT EXISTS (SELECT  TOP 1 * FROM CODELKUP (NOLOCK) WHERE  Code = @cAccountID) --Alex01
   IF NOT EXISTS (SELECT  TOP 1 * FROM CODELKUP (NOLOCK) WHERE ListName = 'EPODStorer' AND Code = @cAccountID) --Alex01
   BEGIN
      SET @b_success = 0
      SET @nErrorNo = 90001
      SET @cErrorMsg = RTRIM(@cErrorMsg) + ' Invalid AccountID# ' + ISNULL(RTRIM(@cAccountID), '') + '.'
      INSERT INTO @tError VALUES (@nErrorNo, @cErrorMsg)
      GOTO QUIT
   END

   IF @b_success <> 0
   BEGIN
      SET @cMBOLKey = ''

      SELECT TOP 1
         @cMBOLKey        = P.MbolKey
        ,@cMBOLLineNumber = P.MbolLineNumber
        ,@cCurPODStatus   = P.Status
        ,@cFinalizeFlag   = P.FinalizeFlag
      --  ,@cEPODStatus     = P.Status
        ,@cStorerKey      = P.Storerkey
      FROM POD P WITH (NOLOCK)
      JOIN CODELKUP c WITH (NOLOCK) ON c.LISTNAME = 'EPODStorer' AND  c.Code = @cAccountID AND c.StorerKey = p.Storerkey
      WHERE P.OrderKey  = @cEPOD_OrderKey
      AND   P.FinalizeFlag='N'
      ORDER BY P.OrderKey

      IF @b_debug = '1'
      BEGIN
         PRINT ' cmbolkey based on order key : ' + @cMBOLKey + 'for account : ' +   @cAccountID
      END

      IF ISNULL(RTRIM(@cMBOLKey), '') = ''
      BEGIN
         SELECT TOP 1
            @cMBOLKey  = P.MbolKey
           ,@cMBOLLineNumber = P.MbolLineNumber
           ,@cCurPODStatus   = P.Status 
           ,@cFinalizeFlag   = P.FinalizeFlag 
         --  ,@cEPODStatus     = P.Status
           ,@cStorerKey      = P.Storerkey
         FROM POD P WITH (NOLOCK)
         JOIN CODELKUP c WITH (NOLOCK) ON c.LISTNAME = 'EPODStorer' AND  c.Code = @cAccountID AND c.StorerKey = p.Storerkey
         WHERE P.InvoiceNo  = @cEPOD_OrderKey
         AND   P.FinalizeFlag='N'
         ORDER BY P.OrderKey
      END

      IF @b_debug = '1'
      BEGIN
         PRINT ' cmbolkey based on invoice no : ' + @cMBOLKey + 'for account : ' +   @cAccountID
      END

      IF ISNULL(RTRIM(@cMBOLKey), '') = ''
      BEGIN
         SELECT TOP 1
            @cMBOLKey        = P.MbolKey
           ,@cMBOLLineNumber = P.MbolLineNumber
           ,@cCurPODStatus   = P.Status
           ,@cFinalizeFlag   = P.FinalizeFlag
         --  ,@cEPODStatus     = P.Status
           ,@cStorerKey      = P.Storerkey
         FROM POD P WITH (NOLOCK)
         JOIN CODELKUP c WITH (NOLOCK) ON c.LISTNAME = 'EPODStorer' AND  c.Code = @cAccountID AND c.StorerKey = p.Storerkey
         WHERE P.ExternOrderKey  = @cEPOD_OrderKey
         AND   P.FinalizeFlag='N'
         ORDER BY P.OrderKey
      END

      IF @b_debug = '1'
      BEGIN
         PRINT ' cmbolkey based on externorder key : ' + @cMBOLKey + 'for account : ' +   @cAccountID
      END

      IF ISNULL(RTRIM(@cMBOLKey), '') = ''
      BEGIN
         IF @b_debug = '1'
         BEGIN
            PRINT ' storerkey : ' + @cStorerKey
         END

         IF EXISTS(SELECT 1 FROM StorerConfig sc WITH (NOLOCK)
                   JOIN  CODELKUP c WITH (NOLOCK) ON c.LISTNAME = 'EPODStorer'
                   AND  c.Code = @cAccountID AND c.StorerKey = sc.Storerkey
                   --AND sc.StorerKey = @cStorerKey
                   WHERE   sc.ConfigKey = 'OWITF'
                   AND svalue='1')
         BEGIN
            SET @cE1_ePODOrderKey = SUBSTRING(@cEPOD_OrderKey, 6, 10)

            IF @b_debug = '1'
            BEGIN
               PRINT ' Orderkey : ' + @cE1_ePODOrderKey
            END

            IF ISNULL(@cE1_ePODOrderKey,'') <> ''   --(CS01)
            BEGIN
               SELECT TOP 1
                  @cMBOLKey        = P.MbolKey
                 ,@cMBOLLineNumber = P.MbolLineNumber
                 ,@cCurPODStatus   = P.Status
                 ,@cFinalizeFlag   = P.FinalizeFlag
               --  ,@cEPODStatus     = P.Status
                 ,@cStorerKey      = P.Storerkey
               FROM POD P WITH (NOLOCK)
               JOIN CODELKUP c WITH (NOLOCK) ON c.LISTNAME = 'EPODStorer' AND  c.Code = @cAccountID AND c.StorerKey = p.Storerkey
               WHERE P.InvoiceNo  = @cE1_ePODOrderKey
               AND   P.FinalizeFlag='N'
               ORDER BY P.OrderKey
            END

            IF @b_debug = '1'
            BEGIN
               PRINT ' MBOL KEY : ' + @cMBOLKey
            END
         END --(CS01)
      END

      -- Search for EPOD.OrderKey = POD.TrackCol02 and POD.FinalizeFlag='N'(Chee02)
      IF ISNULL(RTRIM(@cMBOLKey), '') = ''
      BEGIN
         SELECT TOP 1
            @cMBOLKey        = P.MbolKey
           ,@cMBOLLineNumber = P.MbolLineNumber
           ,@cCurPODStatus   = P.Status
           ,@cFinalizeFlag   = P.FinalizeFlag
         --  ,@cEPODStatus     = P.Status
           ,@cStorerKey      = P.Storerkey
         FROM POD P WITH (NOLOCK)
         JOIN CODELKUP c WITH (NOLOCK) ON c.LISTNAME = 'EPODStorer' AND  c.Code = @cAccountID AND c.StorerKey = p.Storerkey
         WHERE P.TrackCol02  = @cEPOD_OrderKey
         AND   P.FinalizeFlag='N'
         ORDER BY P.OrderKey
      END

      IF @b_debug = '1'
      BEGIN
         PRINT ' cmbolkey based on trackcol02 key : ' + @cMBOLKey + 'for account : ' +   @cAccountID
      END

      IF ISNULL(RTRIM(@cMBOLKey), '') = ''
      BEGIN
         SET @nErrorNo = 70005
         SET @cErrorMsg = RTRIM(@cErrorMsg) + ' Invalid Ref# ' + ISNULL(RTRIM(@cEPOD_OrderKey), '') + '.'
         INSERT INTO @tError VALUES (@nErrorNo, @cErrorMsg)
         GOTO QUIT
      END

      -- Avoid duplicate same errmsg for same PODStatus & RefNo
      -- Eg. 'P;;A,', both with RefNo = blank, but different PODStatus
      IF (ISNULL(RTRIM(@cEPODStatus),'') = '')
      BEGIN
         SET @cBlankRefNo = RTRIM(@cEPODStatus)  + ISNULL(RTRIM(@cEPOD_OrderKey), '')
         SET @nErrorNo = 70005
         SET @cErrorMsg = RTRIM(@cErrorMsg) + ' Ref# cannot be blank (' + ISNULL(RTRIM(@cEPOD_OrderKey), '') + ').'
         INSERT INTO @tError VALUES (@nErrorNo, @cErrorMsg)
         --GOTO QUIT
      END

      IF @b_debug=1
      BEGIN
         PRINT ' Order Key : ' + @cEPOD_OrderKey
         PRINT 'Status : ' + @cEPODStatus
         PRINT ' MBOKLKEY : ' + @cMBOLKey
         PRINT ' MBOL LINE ' + @cMBOLLineNumber
         PRINT ' Storerkey : ' + @cStorerKey
      END

      IF @cCurPODStatus = '8'
      BEGIN
         -- Avoid duplicate same errmsg for same RefNo
         SET @nErrorNo = 70008
         SET @cErrorMsg = RTRIM(@cErrorMsg) + ' POD already arrived at DC (' + ISNULL(RTRIM(@cEPOD_OrderKey), '') + ').'
         INSERT INTO @tError VALUES (@nErrorNo, @cErrorMsg)
         --GOTO QUIT
      END

      -- Delivery Status Validation
      -- F-Full Delivery
      -- P-Partial Delivery
      -- R-Reject
      IF @cEPODStatus NOT IN ('0','1', '2', '3', '4')
      BEGIN
         SET @nErrorNo = 70009
         SET @cErrorMsg = RTRIM(@cErrorMsg) + ' Invalid Delivery Status: Ref# ' + ISNULL(RTRIM(@cEPOD_OrderKey), '') + ' (1-4).'
         INSERT INTO @tError VALUES (@nErrorNo, @cErrorMsg)
         --GOTO QUIT
      END

      IF @b_debug = 1
      BEGIN
         PRINT 'Error Code :' + convert(varchar(5),@nErrorNo)
      END

      -- (Chee04)
      SET @cCP_ShowPODEventHistory = ''
      EXEC nspGetRight  
         NULL,                      -- facility  
         @cStorerKey,               -- Storerkey  
         NULL,                      -- Sku  
         'CP_ShowPODEventHistory',  -- Configkey  
         @b_success               OUTPUT,  
         @cCP_ShowPODEventHistory OUTPUT,  
         @nErrorNo                OUTPUT,  
         @cErrorMsg               OUTPUT

      IF @b_success <> 1
      BEGIN
         SET @b_success = 0
         SET @nErrorNo = 90002
         SET @cErrorMsg = 'nspGetRight - CP_ShowPODEventHistory: ' + RTRIM(@cErrorMsg)
         INSERT INTO @tError VALUES (@nErrorNo, @cErrorMsg)
         GOTO QUIT
      END

      BEGIN TRAN
      IF @nErrorNo = 0
      BEGIN
         -- EPOD.PODStatus = '1' (Delivered)
         IF @cEPODStatus = '1'
         BEGIN
            UPDATE POD WITH (ROWLOCK)
            SET    Status = '7' -- Successful delivery
                  ,PODDef09  = @cEPODStatus                 --CS01
                  ,ActualDeliveryDate = @cEPOD_Date
                  ,RejectReasonCode = ''    
                  ,Notes = @cEPODNotes
                  ,Latitude = @cLatitude
                  ,Longtitude = @cLongtitude 
                  ,EditDate  = GetDate()
                  ,EditWho   = @cAccountID
                  ,TrafficCop = NULL
            WHERE  MbolKey = @cMBOLKey
            AND    MbolLineNumber = @cMBOLLineNumber
            AND    StorerKey = @cStorerKey
            AND    FinalizeFlag = 'N'   
         END
         ELSE IF @cEPODStatus = '2' -- EPOD.PODStatus = '2' (Redelivered)
         BEGIN
            UPDATE POD WITH (ROWLOCK)
            SET    Status = '4'
                  ,PODDef09  = @cEPODStatus                 --CS01
                  ,ActualDeliveryDate = @cEPOD_Date
                  ,RejectReasonCode = ''    
                  ,Notes = @cEPODNotes
                  ,Latitude = @cLatitude
                  ,Longtitude = @cLongtitude 
                  ,EditDate  = GetDate()
                  ,EditWho   = @cAccountID
                  ,TrafficCop = NULL
                  ,RedeliveryDate = CASE WHEN @cCP_ShowPODEventHistory = '1' THEN @cEPOD_Date ELSE RedeliveryDate END -- (Chee04)
            WHERE  MbolKey = @cMBOLKey 
            AND    MbolLineNumber = @cMBOLLineNumber
            AND    StorerKey = @cStorerKey
            AND    FinalizeFlag = 'N'
         END
         ELSE IF @cEPODStatus = '3' -- EPOD.PODStatus = '3' (Full Reject)
         BEGIN
            SET @cResonCode = ''

            SELECT @cResonCode = c.Long
            FROM CODELKUP c WITH (NOLOCK)
            WHERE ListName = 'ePODreason'
            and @cRejectReasonCode = C.Description
            and C.Storerkey = @cStorerKey

            IF ISNULL(RTRIM(@cResonCode),'') = ''
               SET @cResonCode = @cRejectReasonCode

            UPDATE POD WITH (ROWLOCK)
            SET    Status = '2'
                  ,PODDef09  = @cEPODStatus                 --CS01
                  ,ActualDeliveryDate = @cEPOD_Date
                  ,RejectReasonCode = @cResonCode
                  ,Notes = @cEPODNotes
                  ,Latitude = @cLatitude
                  ,Longtitude = @cLongtitude
                  ,EditDate  = GetDate()
                  ,EditWho   = @cAccountID
                  ,TrafficCop = NULL
                  ,FullRejectDate = CASE WHEN @cCP_ShowPODEventHistory = '1' THEN @cEPOD_Date ELSE FullRejectDate END -- (Chee04)
            WHERE  MbolKey = @cMBOLKey
            AND    MbolLineNumber = @cMBOLLineNumber
            AND    StorerKey = @cStorerKey
            AND    FinalizeFlag = 'N'
         END
         ELSE IF @cEPODStatus = '4' -- EPOD.PODStatus = '4' (Partial Reject)
         BEGIN
            SELECT @cResonCode = c.Long
            FROM CODELKUP c WITH (NOLOCK)
            WHERE ListName = 'ePODreason'
            and @cRejectReasonCode = C.Description
            and C.Storerkey = @cStorerKey

            IF ISNULL(RTRIM(@cResonCode),'') = ''
               SET @cResonCode = @cRejectReasonCode

            UPDATE POD WITH (ROWLOCK)
            SET    Status = '3'
                  ,PODDef09  = @cEPODStatus            --CS01
                  ,ActualDeliveryDate = @cEPOD_Date
                  ,RejectReasonCode = @cResonCode
                  ,Notes = @cEPODNotes
                  ,Latitude = @cLatitude
                  ,Longtitude = @cLongtitude
                  ,EditDate  = GetDate()
                  ,EditWho   = @cAccountID
                  ,TrafficCop = NULL
                  ,PartialRejectDate = CASE WHEN @cCP_ShowPODEventHistory = '1' THEN @cEPOD_Date ELSE PartialRejectDate END -- (Chee04)
            WHERE  MbolKey = @cMBOLKey 
            AND    MbolLineNumber = @cMBOLLineNumber
            AND    StorerKey = @cStorerKey
            AND    FinalizeFlag = 'N'
         END
      END
   END
   COMMIT TRAN

QUIT:
   -- Update ErrMsg
   IF @nErrorNo <> 0 AND ISNULL(RTRIM(@cEmailRecipients),'') <> ''
   BEGIN 
      SET @cSubject = @cEmailTitle + ' (' + @cEPOD_OrderKey + ')'
      SET @cEmailBodyHeader = @cStorerkey + ' EPOD Update Error '
      SET @cTableHTML =
             N'<H1>' + @cEmailBodyHeader + '</H1>' +
             N'<table border="1">' +
             N'<tr><th>Error No</th><th>Error Message</th>' +
             CAST ( ( SELECT td = ErrorNo, ''
                            ,td = ErrorMessage, ''
                      FROM @tError
               FOR XML PATH('tr'), TYPE
             ) AS NVARCHAR(MAX) ) +
             N'</table>' ;

      EXEC @nReturnCode = msdb.dbo.sp_send_dbmail @recipients=@cEmailRecipients
                                          ,  @subject=@cSubject
                                          ,  @body=@cTableHTML
                                          ,  @body_format='HTML';
   END

END -- Procedure

GO