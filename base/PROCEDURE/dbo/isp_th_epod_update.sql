SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Stored Procedure: isp_TH_EPOD_Update                                 */
/* Creation Date: 29-Aug-2014                                           */
/* Copyright: IDS                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: duplicate from isp_EPOD_Update                              */
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
/* Date           Author      Purposes                                  */
/* 29-Aug-2014    CSCHONG     SOS319466  (CS01)                         */
/* 22-Feb-2018    Alex        Jira Ticket #WMS-3936 (Alex01)            */
/************************************************************************/

CREATE PROC [dbo].[isp_TH_EPOD_Update] (
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
   @nErrorNo             INT = 1             OUTPUT,
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
            
   --DECLARE @cMBOLKey             CHAR (10)             
   --      , @cMBOLLineNumber      CHAR ( 5)          
   --      , @cPOD_Status          CHAR ( 2)          
   --      , @cFinalizeFlag        CHAR ( 1)                     
                        
   -- SOS77243            
   DECLARE @cReasonCode          NVARCHAR(10)            
                  
   DECLARE @nReturnCode          INT              
         , @cSubject             NVARCHAR(255)              
         , @cEmailBodyHeader     NVARCHAR(255)              
         , @cTableHTML           NVARCHAR(MAX)              
         , @b_debug              INT     
         , @cE1_ePODOrderKey     NVARCHAR(50)    
         , @b_success            INT   
        -- , @c_GetEPODNotes     NVARCHAR(1000)     
   
   --(Alex01)
   DECLARE @cOrderType           NVARCHAR(20)
         , @cPOD_StorerKey       NVARCHAR(15)
         , @cExecStatements      NVARCHAR(4000)
         , @cExecArguments       NVARCHAR(1000)
         , @nContinue            INT
         , @nStartTCnt           INT
   
   DECLARE @cPODMbolKey          NVARCHAR(10)
         , @cPODMBOLLineNumber   NVARCHAR(50)
         , @cPODStorerKey        NVARCHAR(15)

   SET @nErrorNo           = 0            
   SET @cErrorMsg          = ''                    
   --SET @cMBOLKey           = ''            
   --SET @cMBOLLineNumber    = ''            
   --SET @cPOD_Status        = '0' -- Initialize current Status in POD table            
   --SET @cFinalizeFlag      = 'N'            
   SET @b_debug            = 1    
   SET @b_Success          = 1  

   --(Alex01)
   SET @cOrderType         = ''
   SET @cPOD_StorerKey     = ''
   SET @cExecStatements    = ''
   SET @cExecArguments     = ''
   SET @nContinue          = 1
   SET @nStartTCnt         = @@TRANCOUNT

--   IF ISNULL(@cEPODNotes,'') <> ''
--     BEGIN
--       SET @cEPODNotes = '|' + @cEPODNotes
--     END
               
   DECLARE @tError TABLE
      ( ErrorNo INT            
      , ErrorMessage NVARCHAR(1000))             
   
   --(Alex01)
   IF OBJECT_ID('tempdb..#tWMSStorerList') IS NOT NULL
      DROP TABLE #tWMSStorerList

   CREATE TABLE #tWMSStorerList(
      StorerKey      NVARCHAR(15)   NULL,
      ValidExtOrd    NVARCHAR(1)    NULL
   )
   --(Alex01)
   IF OBJECT_ID('tempdb..#tPOD') IS NOT NULL
      DROP TABLE #tPOD

   CREATE TABLE #tPOD(
      MBOLKey           NVARCHAR(10),
      MBOLLineNumber    NVARCHAR(50),
      StorerKey         NVARCHAR(15)   NULL,
      [Status]          NVARCHAR(10)   NULL,
      FinalizeFlag      NVARCHAR(1)    NULL
   )

   BEGIN TRAN
   /*------------------------*/            
   /* Process POD records    */            
   /*------------------------*/            
   --DECLARE @cPrevPODStatus       CHAR (1)           
   --      , @cPrevRefNo           CHAR (20)          
   --      , @cBlankRefNo          CHAR (20)    

   --(Alex01) BEGIN
   --IF NOT EXISTS (SELECT  TOP 1 * FROM CODELKUP (NOLOCK) WHERE Listname = 'EPODSTORER' AND Code = @cAccountID)  
   --BEGIN  
   --   SET @b_success = 0  
   --   SET @nErrorNo = 70001              
   --   SET @cErrorMsg = RTRIM(@cErrorMsg) + ' Invalid AccountID# ' + ISNULL(RTRIM(@cAccountID), '') + '.'            
   --   INSERT INTO @tError VALUES (@nErrorNo, @cErrorMsg)             
   --   GOTO QUIT     
   --END    
   
   IF @b_debug = 1
   BEGIN
      PRINT '======================'
      PRINT '>>> isp_TH_EPOD_Update STARTED'
      PRINT '>>> INSERT #tWMSStorerList '
   END

   --Extract all wms storers from wms codelkup (Alex01)
   INSERT INTO #tWMSStorerList (StorerKey, ValidExtOrd)
   SELECT C.StorerKey, ISNULL(RTRIM(SC.sValue), '')
   FROM Codelkup C WITH (NOLOCK)
   LEFT OUTER JOIN StorerConfig SC WITH (NOLOCK)
   ON SC.StorerKey = C.StorerKey AND ConfigKey = 'EPOD_VALIDATE_EXTORDKEY'
   WHERE C.ListName = 'EPODStorer' AND C.Code = @cAccountID

   IF @@ERROR <> 0 
   BEGIN 
      SET @nContinue = 3
      SET @nErrorNo = 70000
      SET @cErrorMsg = 'Failed to get WMS StorerKey - ' + ERROR_MESSAGE()
      INSERT INTO @tError VALUES (@nErrorNo, @cErrorMsg)
      GOTO QUIT
   END

   IF NOT EXISTS ( SELECT 1 FROM #tWMSStorerList )
   BEGIN
      SET @nContinue = 3
      --SET @b_success = 0 
      SET @nErrorNo = 70001
      SET @cErrorMsg = 'Invalid AccountID# ' + ISNULL(RTRIM(@cAccountID), '') + '.'
      INSERT INTO @tError VALUES (@nErrorNo, @cErrorMsg)
      GOTO QUIT
   END
   --IF NOT EXISTS (SELECT  TOP 1 * FROM POD P (NOLOCK) WHERE  P.OrderKey  = @cEPOD_OrderKey )  
   --BEGIN  
   --   SET @nErrorNo = 90001              
   --   SET @cErrorMsg = RTRIM(@cErrorMsg) + ' Invalid OrderKey ' + ISNULL(RTRIM(@cEPOD_OrderKey), '') + '.'            
   --   INSERT INTO @tError VALUES (@nErrorNo, @cErrorMsg)             
   --   GOTO QUIT     
   --END  

   --SELECT TOP 1 @cCurPODStatus   = P.Status
   --FROM POD P WITH (NOLOCK)
   --WHERE P.OrderKey  = @cEPOD_OrderKey

   SET @cOrderType = CASE 
                        WHEN EXISTS ( SELECT 1 FROM dbo.POD P WITH (NOLOCK) 
                              WHERE P.OrderKey = @cEPOD_OrderKey 
                              AND EXISTS ( SELECT 1 FROM #tWMSStorerList T 
                                 WHERE T.StorerKey = P.StorerKey )
                              ) THEN 'OrderKey'
                        WHEN EXISTS ( SELECT 1 FROM dbo.POD P WITH (NOLOCK) 
                              WHERE P.ExternOrderKey = @cEPOD_OrderKey 
                              AND EXISTS ( SELECT 1 FROM #tWMSStorerList T 
                                 WHERE T.StorerKey = P.StorerKey AND ValidExtOrd = '1' )
                              ) THEN 'ExternOrderKey'
                        ELSE '' END

   IF ISNULL(RTRIM(@cOrderType), '') = ''
   BEGIN
      SET @nContinue = 3
      SET @nErrorNo = 70003              
      SET @cErrorMsg = RTRIM(@cErrorMsg) + ' Invalid OrderKey ' + ISNULL(RTRIM(@cEPOD_OrderKey), '') + '.'            
      INSERT INTO @tError VALUES (@nErrorNo, @cErrorMsg)             
      GOTO QUIT 
   END

   SET @cExecStatements = ''
   SET @cExecArguments = ''
   SET @cExecStatements = N'INSERT INTO #tPOD(MBOLKey, MBOLLineNumber, StorerKey, [Status], FinalizeFlag) '
                        +  'SELECT P.Mbolkey, P.Mbollinenumber, StorerKey, [Status], FinalizeFlag '
                        +  'FROM POD P WITH (NOLOCK) '
                        +  'WHERE P.' + @cOrderType + ' = @cEPOD_OrderKey '
                        +  'AND EXISTS ( SELECT 1 FROM #tWMSStorerList T WHERE T.StorerKey = P.StorerKey ) '
   SET @cExecArguments = '@cEPOD_OrderKey NVARCHAR(50)'
   EXEC SP_EXECUTESQL @cExecStatements, @cExecArguments, @cEPOD_OrderKey
   IF @@ERROR <> 0 
   BEGIN 
      SET @nContinue = 3
      SET @nErrorNo = 70008
      SET @cErrorMsg = 'Failed to get WMS POD - ' + ERROR_MESSAGE()
      INSERT INTO @tError VALUES (@nErrorNo, @cErrorMsg)
      GOTO QUIT
   END

   IF @b_debug = 1
      PRINT '>>> INSERT #tPOD - ' + @cExecStatements

   IF EXISTS(SELECT 1 FROM #tPOD WHERE [Status] IN ('7', '8'))--@cPOD_Status in ('7','8')
   BEGIN            
      SET @nContinue = 3
      SET @nErrorNo = 70004
      SET @cErrorMsg = RTRIM(@cErrorMsg) + ' POD already Confirmed (' + ISNULL(RTRIM(@cEPOD_OrderKey), '') + ').'
      INSERT INTO @tError VALUES (@nErrorNo, @cErrorMsg)
      GOTO QUIT
   END

   IF EXISTS ( SELECT 1 FROM #tPOD WHERE [FinalizeFlag] = 'Y' )
   BEGIN 
      SET @nContinue = 3
      SET @nErrorNo = 70005
      SET @cErrorMsg = RTRIM(@cErrorMsg) + ' POD already Finalized (' + ISNULL(RTRIM(@cEPOD_OrderKey), '') + ').'
      INSERT INTO @tError VALUES (@nErrorNo, @cErrorMsg)
   END 
   --(Alex01) END

   IF (ISNULL(RTRIM(@cEPODStatus),'') = '')            
   BEGIN
      SET @nContinue = 3
      --SET @cBlankRefNo = RTRIM(@cEPODStatus)  + ISNULL(RTRIM(@cEPOD_OrderKey), '')            
      SET @nErrorNo = 70006         
      SET @cErrorMsg = RTRIM(@cErrorMsg) + ' Ref# cannot be blank (' + ISNULL(RTRIM(@cEPOD_OrderKey), '') + ').'            
      INSERT INTO @tError VALUES (@nErrorNo, @cErrorMsg)                 
      GOTO QUIT                  
   END

   -- Delivery Status Validation
   -- 0 - Notify
   -- 1 - Full Delivered
   -- 2 - Partial Delivered
   -- 3 - Delivered with POD Held
   -- 4 - Redeliver
   -- 5 - Close
   IF @cEPODStatus NOT IN ('0', '1', '2', '3', '4', '5')            
   BEGIN
      SET @nContinue = 3
      SET @nErrorNo = 70007    
      SET @cErrorMsg = RTRIM(@cErrorMsg) + ' Invalid Delivery Status: Ref# ' + ISNULL(RTRIM(@cEPOD_OrderKey), '') + ' (0-5).'            
      INSERT INTO @tError VALUES (@nErrorNo, @cErrorMsg)            
      GOTO QUIT            
   END
   
   IF @nContinue = 1
   BEGIN
      BEGIN TRY
         DECLARE CUR_TEMP_POD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT Mbolkey, Mbollinenumber, StorerKey
         FROM #tPOD
         WHERE FinalizeFlag = 'N'
         OPEN CUR_TEMP_POD              
         FETCH NEXT FROM CUR_TEMP_POD INTO @cPODMbolKey, @cPODMBOLLineNumber, @cPODStorerKey
         
         WHILE @@FETCH_STATUS <> -1          
         BEGIN
            SET @cReasonCode = ''            
            SELECT @cReasonCode = c.Long              
            FROM CODELKUP c WITH (NOLOCK) 
            WHERE ListName = 'ePODreason'
            AND C.StorerKey = @cPODStorerKey
            AND C.[Description]  = @cRejectReasonCode

            IF ISNULL(RTRIM(@cReasonCode),'') = ''          
               SET @cReasonCode = @cRejectReasonCode
   
            IF @b_debug=1
               PRINT 'Reason code = ' + @cReasonCode

            --EPOD.PODStatus = '0' (Notify)
            IF @cEPODStatus = '0' 
            BEGIN
               UPDATE POD WITH (ROWLOCK)
               SET [Status] = 'A' -- Arrive Destination
                  ,PODDate01 = @cEPOD_Date
                  ,PODDef09 =  @cAccountID
               WHERE Mbolkey = @cPODMbolKey
               AND Mbollinenumber = @cPODMBOLLineNumber
               AND FinalizeFlag = 'N'
            END  
            --EPOD.PODStatus = '1' (Full Delivered)               
            ELSE IF @cEPODStatus = '1'            
            BEGIN
               UPDATE POD WITH (ROWLOCK)
               SET [Status] = '7' -- Successful delivery
                  ,PODDef09  = @cAccountID
                  ,ActualDeliveryDate = @cEPOD_Date
                  ,Notes = case when ISNULL(POD.Notes,'') = '' then @cEPODNotes Else (POD.Notes + '|' + @cEPODNotes) END
                  ,Latitude = @cLatitude
                  ,Longtitude = @cLongtitude
                  ,EditDate  = GetDate()
                  ,TrafficCop = NULL
               WHERE Mbolkey = @cPODMbolKey
               AND Mbollinenumber = @cPODMBOLLineNumber
               AND FinalizeFlag = 'N'
            END
            -- EPOD.PODStatus = '2' (Partial Delivered)   
            ELSE IF @cEPODStatus = '2'          
            BEGIN
               UPDATE POD WITH (ROWLOCK)
               SET [Status] = '3' -- Partial Rejection
                  ,PODDef09  = @cAccountID
                  ,ActualDeliveryDate = @cEPOD_Date
                  ,RejectReasonCode = @cReasonCode
                  ,Notes = case when ISNULL(POD.Notes,'') = '' then @cEPODNotes Else (POD.Notes + '|' + @cEPODNotes) END
                  ,Latitude = @cLatitude
                  ,Longtitude = @cLongtitude
                  ,EditDate  = GetDate()                 
                  ,TrafficCop = NULL
               WHERE Mbolkey = @cPODMbolKey
               AND Mbollinenumber = @cPODMBOLLineNumber                     
               AND FinalizeFlag = 'N'
            END
            -- EPOD.PODStatus = '3' (Delivered With Held POD)
            ELSE IF @cEPODStatus = '3'           
            BEGIN
               UPDATE POD WITH (ROWLOCK)
               SET [Status] = '7' --Successful delivery
                  ,PODDef06 = 'Y'
                  ,PODDef09  = @cAccountID
                  ,ActualDeliveryDate = @cEPOD_Date
                  ,RejectReasonCode = @cReasonCode
                  ,Notes = case when ISNULL(POD.Notes,'') = '' then @cEPODNotes Else (POD.Notes + '|' + @cEPODNotes) END
                  ,Latitude = @cLatitude
                  ,Longtitude = @cLongtitude
                  ,EditDate  = GetDate()
                  ,EditWho   = @cAccountID
                  ,TrafficCop = NULL
               WHERE Mbolkey = @cPODMbolKey
               AND Mbollinenumber = @cPODMBOLLineNumber
               AND FinalizeFlag = 'N'
            END
            -- EPOD.PODStatus = '4' (Redelivery)
            ELSE IF @cEPODStatus = '4' 
            BEGIN
               UPDATE POD WITH (ROWLOCK)
               SET ReDeliveryDate = @cEPOD_Date
                  ,ReDeliveryCount = ISNULL(ReDeliveryCount,0) + 1
                  ,RejectReasonCode = @cReasonCode
                  ,PODDef09  = @cAccountID
                  ,Latitude = @cLatitude
                  ,Longtitude = @cLongtitude
                  ,EditDate  = GetDate()
                  ,EditWho   = @cAccountID
                  ,TrafficCop = NULL
               WHERE Mbolkey = @cPODMbolKey
               AND Mbollinenumber = @cPODMBOLLineNumber
               AND    FinalizeFlag = 'N'
            END
            ELSE IF @cEPODStatus = '5' -- EPOD.PODStatus = '5' (Close)
            BEGIN
               UPDATE POD WITH (ROWLOCK)
               SET [Status] = '2' --Full Rejection  
                  ,FullRejectDate = @cEPOD_Date 
                  ,RejectReasonCode = @cReasonCode
                  ,Notes = case when ISNULL(POD.Notes,'') = '' then @cEPODNotes Else (POD.Notes + '|' + @cEPODNotes) END
                  ,PODDef09  = @cAccountID
                  ,Latitude = @cLatitude
                  ,Longtitude = @cLongtitude
                  ,EditDate  = GetDate()
                  ,EditWho   = @cAccountID
                  ,TrafficCop = NULL
               WHERE Mbolkey = @cPODMbolKey
               AND Mbollinenumber = @cPODMBOLLineNumber
               AND FinalizeFlag = 'N'
            END
            FETCH NEXT FROM CUR_TEMP_POD INTO @cPODMbolKey, @cPODMBOLLineNumber, @cPODStorerKey
         END
         CLOSE CUR_TEMP_POD          
         DEALLOCATE CUR_TEMP_POD
      END TRY
      BEGIN CATCH
         IF @b_debug = 1 
         BEGIN 
            PRINT '>>> ERROR EXCEPTION : ' + CONVERT(NVARCHAR, ERROR_NUMBER()) + ERROR_MESSAGE()
         END 
         SET @nContinue = 3
         SET @nErrorNo = ERROR_NUMBER()
         SET @cErrorMsg = ERROR_MESSAGE()
         INSERT INTO @tError VALUES (@nErrorNo, @cErrorMsg)
         GOTO QUIT 
      END CATCH
   END

   --BEGIN TRAN            
   --IF @nErrorNo = 0             
   --BEGIN 
   --   SET @cReasonCode = ''            
      
   --   SELECT @cReasonCode = c.Long              
   --   FROM CODELKUP c WITH (NOLOCK) 
   --   --JOIN POD WITH (NOLOCK) ON POD.Storerkey=C.storerkey    
   --   WHERE ListName = 'ePODreason'
   --   AND C.StorerKey = @cPOD_StorerKey
   --   AND C.Description  = @cRejectReasonCode
   --   --and C.Storerkey = @cStorerKey

   --   IF ISNULL(RTRIM(@cReasonCode),'') = ''
   --   BEGIN            
   --      SET @cReasonCode = @cRejectReasonCode
   --   END
   
   --   IF @b_debug=1
   --   BEGIN
   --      PRINT 'Reason code = ' + @cReasonCode
   --   END
      
   --   -- EPOD.PODStatus = '0' (Notify)  
   --   IF @cEPODStatus = '0' 
   --   BEGIN
   --      IF @b_debug=1            
   --      BEGIN            
   --         PRINT 'status = 0'
   --      END            
   
   --      UPDATE POD WITH (ROWLOCK) 
   --         SET Status = 'A' -- Arrive Destination
   --            ,PODDate01 = @cEPOD_Date
   --            ,PODDef09 =  @cAccountID
   --      WHERE Orderkey = @cEPOD_OrderKey
   --      -- AND    StorerKey = @cStorerKey
   --      AND FinalizeFlag = 'N'
   --   END           
   --   -- EPOD.PODStatus = '1' (Full Delivered)               
   --   ELSE IF @cEPODStatus = '1'            
   --   BEGIN            
   --      UPDATE POD WITH (ROWLOCK)             
   --      SET Status = '7' -- Successful delivery            
   --         ,PODDef09  = @cAccountID                      
   --         ,ActualDeliveryDate = @cEPOD_Date            
   --         -- ,RejectReasonCode = ''             
   --         ,Notes = case when ISNULL(POD.Notes,'') = '' then @cEPODNotes Else (POD.Notes + '|' + @cEPODNotes) END              
   --         ,Latitude = @cLatitude            
   --         ,Longtitude = @cLongtitude             
   --         ,EditDate  = GetDate()             
   --         --  ,EditWho   = @cAccountID                   
   --         ,TrafficCop = NULL              
   --      WHERE Orderkey = @cEPOD_OrderKey           
   --      --  AND    MbolLineNumber = @cMBOLLineNumber            
   --      --  AND    StorerKey = @cStorerKey            
   --      AND    FinalizeFlag = 'N'
   --   END            
   --   ELSE IF @cEPODStatus = '2' -- EPOD.PODStatus = '2' (Partial Delivered)            
   --   BEGIN            
   --      UPDATE POD WITH (ROWLOCK)             
   --      SET Status = '3'     -- Partial Rejection          
   --         ,PODDef09  = @cAccountID                
   --         ,ActualDeliveryDate = @cEPOD_Date            
   --         ,RejectReasonCode = @cReasonCode             
   --         ,Notes = case when ISNULL(POD.Notes,'') = '' then @cEPODNotes Else (POD.Notes + '|' + @cEPODNotes) END               
   --         ,Latitude = @cLatitude            
   --         ,Longtitude = @cLongtitude             
   --         ,EditDate  = GetDate()             
   --         -- ,EditWho   = @cAccountID                   
   --         ,TrafficCop = NULL              
   --      WHERE Orderkey = @cEPOD_OrderKey
   --      --WHERE  MbolKey = @cMBOLKey             
   --      --AND    MbolLineNumber = @cMBOLLineNumber            
   --      --AND    StorerKey = @cStorerKey            
   --      AND FinalizeFlag = 'N'
   --   END
   --   ELSE IF @cEPODStatus = '3' -- EPOD.PODStatus = '3' (Delivered With Held POD)            
   --   BEGIN      
   --      UPDATE POD WITH (ROWLOCK)             
   --      SET Status = '7'               --Successful delivery  
   --         ,PODDef06 = 'Y'
   --         ,PODDef09  = @cAccountID                 
   --         ,ActualDeliveryDate = @cEPOD_Date            
   --         ,RejectReasonCode = @cReasonCode            
   --         ,Notes = case when ISNULL(POD.Notes,'') = '' then @cEPODNotes Else (POD.Notes + '|' + @cEPODNotes) END               
   --         ,Latitude = @cLatitude            
   --         ,Longtitude = @cLongtitude             
   --         ,EditDate  = GetDate()             
   --         ,EditWho   = @cAccountID                   
   --         ,TrafficCop = NULL              
   --      WHERE Orderkey = @cEPOD_OrderKey
   --      --  WHERE  MbolKey = @cMBOLKey             
   --      --  AND    MbolLineNumber = @cMBOLLineNumber            
   --      -- AND    StorerKey = @cStorerKey            
   --      AND FinalizeFlag = 'N'
   --   END            
   --   ELSE IF @cEPODStatus = '4' -- EPOD.PODStatus = '4' (Re-try)                  
   --   BEGIN
   --      UPDATE POD WITH (ROWLOCK)             
   --      SET ReDeliveryDate = @cEPOD_Date 
   --         ,ReDeliveryCount = ISNULL(ReDeliveryCount,0) + 1           
   --         ,RejectReasonCode = @cReasonCode  
   --         ,PODDef09  = @cAccountID   
   --         ,Latitude = @cLatitude            
   --         ,Longtitude = @cLongtitude         
   --         ,EditDate  = GetDate()             
   --         ,EditWho   = @cAccountID                   
   --         ,TrafficCop = NULL              
   --      WHERE Orderkey = @cEPOD_OrderKey
   --      --WHERE  MbolKey = @cMBOLKey             
   --      --AND    MbolLineNumber = @cMBOLLineNumber            
   --      --AND    StorerKey = @cStorerKey            
   --      AND    FinalizeFlag = 'N'
   --   END
   --   ELSE IF @cEPODStatus = '5' -- EPOD.PODStatus = '5' (Close)
   --   BEGIN                           
   --      UPDATE POD WITH (ROWLOCK)             
   --      SET Status = '2'               --Full Rejection  
   --         ,FullRejectDate = @cEPOD_Date 
   --         ,RejectReasonCode = @cReasonCode  
   --         ,Notes = case when ISNULL(POD.Notes,'') = '' then @cEPODNotes Else (POD.Notes + '|' + @cEPODNotes) END 
   --         ,PODDef09  = @cAccountID   
   --         ,Latitude = @cLatitude            
   --         ,Longtitude = @cLongtitude         
   --         ,EditDate  = GetDate()             
   --         ,EditWho   = @cAccountID                   
   --         ,TrafficCop = NULL              
   --      WHERE Orderkey = @cEPOD_OrderKey
   --      --WHERE  MbolKey = @cMBOLKey             
   --      --AND    MbolLineNumber = @cMBOLLineNumber            
   --      --AND    StorerKey = @cStorerKey            
   --      AND    FinalizeFlag = 'N'        
   --   END                       
            
   -- --END            
   --END          
   --COMMIT TRAN            

   QUIT:
   IF CURSOR_STATUS('LOCAL' , 'CUR_TEMP_POD') in (0 , 1)
   BEGIN              
      CLOSE CUR_TEMP_POD
      DEALLOCATE CUR_TEMP_POD
   END

   --Send Error Msg          
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

   WHILE @@TRANCOUNT < @nStartTCnt
      BEGIN TRAN

   IF @nContinue=3
   BEGIN 
      IF @@TRANCOUNT > @nStartTCnt AND @@TRANCOUNT = 1
      BEGIN  
         ROLLBACK TRAN  
      END  
      ELSE  
      BEGIN  
         WHILE @@TRANCOUNT > @nStartTCnt  
         BEGIN  
            COMMIT TRAN  
         END  
      END
      RETURN  
   END
   ELSE  
   BEGIN   
      WHILE @@TRANCOUNT > @nStartTCnt  
      BEGIN           
         COMMIT TRAN  
      END  
      RETURN  
   END
END -- Procedure 

GO