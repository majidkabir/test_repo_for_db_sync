SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: isp_WSITF_GeekPlusRBT_CONTAINER_Outbound            */
/* Creation Date: 21-Jun-2018                                           */
/* Copyright: IDS                                                       */
/* Written by: AlexKeoh                                                 */
/*                                                                      */
/* Purpose: Pass Incoming Request String For Interface                  */
/*                                                                      */
/* Input Parameters:  @c_StorerKey        - 'STORER'                    */
/*                    @b_Debug            - 0/1                         */
/*                    @c_TransmitLogKey   - 'Transmitlogkey'            */
/*                                                                      */
/* Output Parameters: @b_Success          - Success Flag  = 0           */
/*                    @n_Err              - Error No      = 0           */
/*                    @c_ErrMsg           - Error Message = ''          */
/*                                                                      */
/* Called By: LeafAPIServer - WMSAPI                                    */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date           Author         Purposes											*/
/* 2018-06-21     Alex           Initial - Jira #WMS-5243               */
/************************************************************************/
CREATE PROC [dbo].[isp_WSITF_GeekPlusRBT_CONTAINER_Outbound](
      @c_StorerKey               NVARCHAR(15)
    , @c_Facility                NVARCHAR(10)
    , @c_ITFType                 NVARCHAR(1)       -- P - PalletID , T - ToteID
    , @c_FromToteId              NVARCHAR(20)      = ''
    , @c_ToToteId                NVARCHAR(20)      = ''
    , @c_TransmitlogKey          NVARCHAR(10)      = ''
    , @b_Debug                   INT               = 0
    , @b_Success                 INT               = 0  OUTPUT  
    , @n_Err                     INT               = 0  OUTPUT  
    , @c_ErrMsg                  NVARCHAR(250)     = '' OUTPUT  
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF 
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @n_Continue                    INT
         , @n_StartCnt                    INT

         , @c_Application                 NVARCHAR(50)
         , @c_MessageType                 NVARCHAR(10)
         , @c_flag                        NVARCHAR(5)
         , @c_flag0                       NVARCHAR(1)
         , @c_flag1                       NVARCHAR(1)
         , @c_flag5                       NVARCHAR(1)
         , @c_flag9                       NVARCHAR(1)
         , @c_ListName_WebService         NVARCHAR(10)           
         , @c_ListName_ROBOTFAC           NVARCHAR(10)
         , @c_ListName_ROBOTSTR           NVARCHAR(10)

         , @n_LOGSerialNo                 INT
         , @c_FullRequestString           NVARCHAR(MAX)
         , @c_ResponseString              NVARCHAR(MAX)
         , @c_vbErrMsg                    NVARCHAR(MAX)

         , @n_Exists                      INT

         , @c_IniFilePath                 VARCHAR(225) 
         , @c_WebRequestMethod            VARCHAR(10)
         , @c_ContentType                 VARCHAR(100)
         , @c_WebRequestEncoding          VARCHAR(30)
         , @c_WS_url                      NVARCHAR(250)

         , @c_TotePrefixed                NVARCHAR(5)
         , @n_ToteStartNum                INT
         , @n_ToteEndNum                  INT 
         , @n_CurrToteNum                 INT

         , @n_TotalCntr                   INT
         , @n_Cntr_RowOffset              INT
         , @n_Cntr_RowFetch               INT

         --TL3
         , @c_TL3_TableName               NVARCHAR(30)

         --RECEIPTDETAIL
         , @c_ReceiptKey                  NVARCHAR(10)
         , @c_ToId                        NVARCHAR(18)

         --header
         , @c_warehouse_code              NVARCHAR(16)
         , @c_user_id                     NVARCHAR(16)
         , @c_user_key                    NVARCHAR(16)

         --body.receipt_list
         , @c_transaction_id              NVARCHAR(10)
         , @c_receipt_code                NVARCHAR(28)
         , @n_type                        INT
         , @c_pallet_code                 NVARCHAR(18)
         , @c_creation_date               NVARCHAR(20)

         --body.receipt_list.sku_list
         , @c_owner_code                  NVARCHAR(16)

         , @c_Resp_MsgCode                NVARCHAR(10)
         , @c_Resp_Msg                    NVARCHAR(200)
         , @b_Resp_Success                BIT

         , @c_Lot                         NVARCHAR(10)
         , @c_FromLoc                     NVARCHAR(10)
         , @c_Sku                         NVARCHAR(20)
         , @n_Qty                         INT
         , @c_ToLoc                       NVARCHAR(10)

         --, @c_ListName_GeekAlert          NVARCHAR(10)
         --, @b_SendAlert                   INT
         --, @n_EmailGroupId                INT
         --, @c_EmailTitle                  NVARCHAR(100)


   SET @n_Continue                        = 1
   SET @n_StartCnt                        = @@TRANCOUNT

   SET @b_Success                         = 0
   SET @n_Err                             = 0
   SET @c_ErrMsg                          = ''

   --SET @c_PalletId                        = ISNULL(RTRIM(@c_PalletId), '')
   SET @c_StorerKey                       = ISNULL(RTRIM(@c_StorerKey), '')
   SET @c_Facility                        = ISNULL(RTRIM(@c_Facility), '')

   SET @c_Application                     = 'GEEK+_CONTAINER_OUT'
   SET @c_MessageType                     = 'WS_OUT'
   SET @c_flag                            = ''
   SET @c_flag0                           = '0'
   SET @c_flag1                           = '1'
   SET @c_flag5                           = '5'
   SET @c_flag9                           = '9'
   SET @c_ListName_WebService             = 'WebService'
   SET @c_ListName_ROBOTFAC               = 'ROBOTFAC'
   SET @c_ListName_ROBOTSTR               = 'ROBOTSTR'

   SET @n_LOGSerialNo                     = 0
   SET @c_FullRequestString               = ''
   SET @c_ResponseString                  = ''
   SET @c_vbErrMsg                        = ''

   SET @c_TotePrefixed                    = ''
   SET @n_ToteStartNum                    = 0
   SET @n_ToteEndNum                      = 0

   SET @c_WebRequestMethod                = 'POST'
   SET @c_ContentType                     = 'application/json'
   SET @c_WebRequestEncoding              = 'UTF-8'
   SET @c_WS_url                          = ''

   --TL2
   SET @c_TL3_TableName                   = 'RBTCNTR_OUT'

   --RECEIPTDETAIL
   SET @c_ReceiptKey                      = ''
   SET @c_ToId                            = ''

   --header
   SET @c_warehouse_code                  = ''
   SET @c_user_id                         = ''
   SET @c_user_key                        = ''

   --body.receipt_list
   SET @c_transaction_id                  = ''
   SET @c_receipt_code                    = ''
   SET @n_type                            = 5

   SET @c_pallet_code                     = ''
   SET @c_creation_date                   = CONVERT(NVARCHAR, CONVERT(BIGINT ,DATEDIFF(SECOND ,'1970-01-01 00:00:00.000', GETUTCDATE())) * 1000) --CONVERT(NVARCHAR(20), GETUTCDATE(), 120)

   --body.receipt_list.sku_list
   SET @c_owner_code                      = ''

   SET @c_vbErrMsg                        = ''
   SET @c_Resp_MsgCode                    = ''
   SET @c_Resp_Msg                        = ''
   SET @b_Resp_Success                    = 0

   --SET @c_ListName_GeekAlert              = 'GEEK+ALERT'
   --SET @b_SendAlert                       = 0
   --SET @n_EmailGroupId                    = 0
   --SET @c_EmailTitle                      = ''

   SET @c_Lot                             = ''
   SET @c_FromLoc                         = ''
   SET @c_Sku                             = ''
   SET @n_Qty                             = 0
   SET @c_ToLoc                           = ''

   IF OBJECT_ID('tempdb..#TEMP_Geek_CNTR_List') IS NOT NULL
   DROP TABLE #TEMP_Geek_CNTR_List

   CREATE TABLE #TEMP_Geek_CNTR_List(
      seq               INT IDENTITY(1,1),
      container_id      NVARCHAR(32) NOT NULL,
      transaction_id    NVARCHAR(10) NULL
   )

   IF @b_Debug = 1
   BEGIN
      PRINT '>>>>>>>> isp_WSITF_GeekPlusRBT_CONTAINER_Outbound - INITAL BEGIN'
      PRINT '@c_StorerKey: ' + @c_StorerKey + ', @c_Facility: ' + @c_Facility
      PRINT '@c_ITFType: ' + @c_ITFType + ', @c_FromToteId: ' + @c_FromToteId + ', @c_ToToteId: ' + @c_ToToteId 
      --PRINT '@c_TargetDB: ' + @c_TargetDB + ', @c_TableName: ' + @c_TableName 
      PRINT '@c_TransmitlogKey: ' + @c_TransmitlogKey
      PRINT '>>>>>>>> isp_WSITF_GeekPlusRBT_CONTAINER_Outbound - INITAL END'
   END 

   IF ISNULL(RTRIM(@c_StorerKey), '') = ''
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 230301
      SET @c_ErrMsg = 'NSQL' 
                    + CONVERT(NVARCHAR(6),@n_Err) 
                    + ': Input param @c_StorerKey cannot be null or empty.(isp_WSITF_GeekPlusRBT_CONTAINER_Outbound)'
      GOTO QUIT
   END

   IF @c_ITFType NOT IN ('P', 'T')
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 230302
      SET @c_ErrMsg = 'NSQL' 
                    + CONVERT(NVARCHAR(6),@n_Err) 
                    + ': Invalid interface type - ' + @c_ITFType + '.(isp_WSITF_GeekPlusRBT_CONTAINER_Outbound)'
      GOTO QUIT
   END

   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      -- PALLET ID ( Run by Qcmder, TransmitLog Inserted by ITFTrigger - Receipt ANSStatus = '9' )
      IF @c_ITFType = 'P'
      BEGIN
         SET @c_flag = '1'
         SET @n_Exists = 0
         SELECT @n_Exists = (1)
               ,@c_ReceiptKey = ISNULL(RTRIM(key1), '')
         FROM dbo.TRANSMITLOG3 WITH (NOLOCK)
         WHERE tablename = @c_TL3_TableName
         AND key3 = @c_StorerKey AND transmitlogkey = @c_TransmitlogKey
         AND transmitflag IN (@c_flag0)
         
         IF @n_Exists = 0
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 230303
            SET @c_ErrMsg = 'NSQL' 
                          + CONVERT(NVARCHAR(6),@n_Err) 
                          + ': No records found in TRANSMITLOG3 table.(isp_WSITF_GeekPlusRBT_CONTAINER_Outbound)'
            GOTO QUIT
         END

         SET @n_Exists = 0
         SELECT @n_Exists = (1)
               ,@c_Facility = ISNULL(RTRIM(R.Facility), '')
         FROM dbo.RECEIPT R WITH (NOLOCK) 
         WHERE R.ReceiptKey = @c_ReceiptKey

         IF @n_Exists = 0
         BEGIN
            SET @c_flag = 'IGNOR'
            GOTO UPDATE_TL3
         END

         IF NOT EXISTS ( SELECT 1 FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
            WHERE ReceiptKey = @c_ReceiptKey AND ISNULL(RTRIM(ToId), '') <> '' ) 
         BEGIN
            SET @c_flag = 'IGNOR'
            GOTO UPDATE_TL3
         END

         SET @n_Exists = 0
         SELECT @n_Exists = (1)
               ,@c_warehouse_code = ISNULL(RTRIM(Short), '')
         FROM dbo.Codelkup WITH (NOLOCK)
         WHERE ListName = @c_ListName_ROBOTFAC
         AND Code = @c_Facility
         AND StorerKey = @c_StorerKey
         
         IF @c_warehouse_code = '' OR @n_Exists = 0
         BEGIN
            SET @c_flag = '5'
            GOTO UPDATE_TL3
         END
         
         SET @n_Exists = 0
         SELECT 
            @n_Exists = (1)
          , @c_WS_url = ISNULL(RTRIM(Long), '') 
          , @c_user_id = ISNULL(RTRIM(UDF01), '') 
          , @c_user_key = ISNULL(RTRIM(UDF02), '') 
          , @c_IniFilePath = ISNULL(RTRIM(Notes), '') 
         FROM dbo.Codelkup WITH (NOLOCK) 
         WHERE Listname = @c_ListName_WebService
         AND Code = @c_warehouse_code 
         AND StorerKey = @c_StorerKey
         AND Code2 = 'CTN'
         
         IF @n_Exists = 0 OR @c_WS_url = '' OR @c_IniFilePath = ''
         BEGIN
            SET @c_flag = '5'
            GOTO UPDATE_TL3
         END
         
         --Update flag to 1
         --UPDATE dbo.TRANSMITLOG3 WITH (ROWLOCK)
         --SET transmitflag = @c_flag1
         --WHERE transmitlogkey = @c_TransmitlogKey

         --IF @@ERROR <> 0
         --BEGIN
         --   SET @n_Continue = 3
         --   SET @n_Err = 230207
         --   SET @c_ErrMsg = 'fail to update TRANSMITLOG3 table flag to 1..'
         --   GOTO QUIT
         --END

         DECLARE GEEKPLUS_CNTROUT_RECEIPTDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT ToId 
            FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
            WHERE ReceiptKey = @c_ReceiptKey 
            AND ISNULL(RTRIM(ToId), '') <> ''
            GROUP BY ToId 
         
         OPEN GEEKPLUS_CNTROUT_RECEIPTDETAIL
         
         FETCH NEXT FROM GEEKPLUS_CNTROUT_RECEIPTDETAIL INTO @c_ToId
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            SET @c_transaction_id = ''
         
            EXEC [dbo].[nspg_GetKey]     
              'geek_cntr_transid'   
            , 10 
            , @c_transaction_id     OUTPUT    
            , @b_Success            OUTPUT    
            , @n_Err                OUTPUT    
            , @c_ErrMsg             OUTPUT
         
            IF @b_Success <> 1
            BEGIN
               SET @n_Continue = 3
               SET @n_Err = 230304
               SET @c_ErrMsg = 'NSQL' 
                             + CONVERT(NVARCHAR(6),@n_Err) 
                             + ': failed to generate transaction id - ' + @c_ErrMsg + '.(isp_WSITF_GeekPlusRBT_CONTAINER_Outbound)'
               GOTO QUIT
            END
         
            INSERT INTO #TEMP_Geek_CNTR_List (container_id, transaction_id)
            VALUES (@c_ToId, @c_transaction_id)
            
            FETCH NEXT FROM GEEKPLUS_CNTROUT_RECEIPTDETAIL INTO @c_ToId
         END
         CLOSE GEEKPLUS_CNTROUT_RECEIPTDETAIL
         DEALLOCATE GEEKPLUS_CNTROUT_RECEIPTDETAIL

         -- Update TL2 flag
         UPDATE_TL3:
         UPDATE dbo.TRANSMITLOG3 WITH (ROWLOCK)
         SET transmitflag = @c_flag
         WHERE transmitlogkey = @c_TransmitlogKey
      END --IF @c_ITFType = 'P'
      -- TOTE ID ( Trigger by exceed - run report )
      -- TOTE ID format should be alphanumeric ( T123456789 - T123456792 )
      ELSE IF @c_ITFType = 'T'
      BEGIN
         IF @b_Debug = 1
         BEGIN
            PRINT '@c_FromToteId: ' + @c_FromToteId + ', @c_ToToteId: ' + @c_ToToteId 
         END

         IF SUBSTRING(@c_FromToteId, 0, 1) <> SUBSTRING(@c_ToToteId, 0, 1)
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 230305
            SET @c_ErrMsg = 'NSQL' 
                          + CONVERT(NVARCHAR(6),@n_Err) 
                          + ': Prefixed of FromToteId & ToToteId must be same.(isp_WSITF_GeekPlusRBT_CONTAINER_Outbound)'
            GOTO QUIT
         END

         IF ISNUMERIC(SUBSTRING(@c_FromToteId, 2, (LEN(@c_FromToteId) - 1))) <> 1
            OR ISNUMERIC(SUBSTRING(@c_ToToteId, 2, (LEN(@c_ToToteId) - 1))) <> 1
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 230306
            SET @c_ErrMsg = 'NSQL' 
                          + CONVERT(NVARCHAR(6),@n_Err) 
                          + ': Invalid FromToteId/ToToteId format.(isp_WSITF_GeekPlusRBT_CONTAINER_Outbound)'
            GOTO QUIT
         END

         SET @n_Exists = 0
         SELECT @n_Exists = (1)
               ,@c_warehouse_code = ISNULL(RTRIM(Short), '')
         FROM dbo.Codelkup WITH (NOLOCK)
         WHERE ListName = @c_ListName_ROBOTFAC
         AND Code = @c_Facility
         AND StorerKey = @c_StorerKey
         
         IF @c_warehouse_code = '' OR @n_Exists = 0
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 230307
            SET @c_ErrMsg = 'NSQL' 
                          + CONVERT(NVARCHAR(6),@n_Err) 
                          + ': robot warehouse_code (codelkup, listname=ROBOTFAC) not setup.(isp_WSITF_GeekPlusRBT_CONTAINER_Outbound)'
            GOTO QUIT
         END
         
         SET @n_Exists = 0
         SELECT 
            @n_Exists = (1)
          , @c_WS_url = ISNULL(RTRIM(Long), '') 
          , @c_user_id = ISNULL(RTRIM(UDF01), '') 
          , @c_user_key = ISNULL(RTRIM(UDF02), '') 
          , @c_IniFilePath = ISNULL(RTRIM(Notes), '') 
         FROM dbo.Codelkup WITH (NOLOCK) 
         WHERE Listname = @c_ListName_WebService
         AND Code = @c_warehouse_code 
         AND StorerKey = @c_StorerKey
         AND Code2 = 'CTN'
         
         IF @n_Exists = 0 OR @c_WS_url = '' OR @c_IniFilePath = ''
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 230308
            SET @c_ErrMsg = 'NSQL' 
                          + CONVERT(NVARCHAR(6),@n_Err) 
                          + ': robot API Url (codelkup, listname=WebService, code2=CTN) not setup.(isp_WSITF_GeekPlusRBT_CONTAINER_Outbound)'
            GOTO QUIT
         END

         SET @c_TotePrefixed = SUBSTRING(@c_FromToteId, 1, 1)
         SET @n_ToteStartNum = CONVERT(INT, SUBSTRING(@c_FromToteId, 2, (LEN(@c_FromToteId) - 1)))
         SET @n_ToteEndNum = CONVERT(INT, SUBSTRING(@c_ToToteId, 2, (LEN(@c_ToToteId) - 1)))

         IF @n_ToteStartNum > @n_ToteEndNum
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 230309
            SET @c_ErrMsg = 'NSQL' 
                          + CONVERT(NVARCHAR(6),@n_Err) 
                          + ': FromToteId number must bigger than ToToteId.(isp_WSITF_GeekPlusRBT_CONTAINER_Outbound)'
            GOTO QUIT
         END
         
         DECLARE GEEKPLUS_CNTROUT_TOTELIST CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         WITH L(n) AS(SELECT 1 UNION ALL SELECT 1),
         L2(n) AS (SELECT 1 FROM L x,  L y),
         L3(n) AS (SELECT 1 FROM L2 x, L2 y),
         L4(n) AS (SELECT 1 FROM L3 x, L3 y),
         L5(n) AS (SELECT 1 FROM L4 x, L4 y),
         L6(n) AS (SELECT 0 UNION ALL 
                     SELECT TOP (@n_ToteEndNum - @n_ToteStartNum)
                     ROW_NUMBER() OVER (ORDER BY (SELECT NULL))
                     FROM L x, L5 y)
         SELECT (@n_ToteStartNum + n)
         FROM L6
         WHERE (@n_ToteStartNum + n) <= @n_ToteEndNum;
         
         OPEN GEEKPLUS_CNTROUT_TOTELIST
         
         FETCH NEXT FROM GEEKPLUS_CNTROUT_TOTELIST INTO @n_CurrToteNum
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            SET @c_transaction_id = ''
         
            EXEC [dbo].[nspg_GetKey]     
              'geek_cntr_transid'   
            , 10 
            , @c_transaction_id     OUTPUT    
            , @b_Success            OUTPUT    
            , @n_Err                OUTPUT    
            , @c_ErrMsg             OUTPUT
         
            IF @b_Success <> 1
            BEGIN
               SET @n_Continue = 3
               SET @n_Err = 230310
               SET @c_ErrMsg = 'NSQL' 
                             + CONVERT(NVARCHAR(6),@n_Err) 
                             + ': failed to generate transaction id - ' + @c_ErrMsg + '.(isp_WSITF_GeekPlusRBT_CONTAINER_Outbound)'
               GOTO QUIT
            END
            
            INSERT INTO #TEMP_Geek_CNTR_List (container_id, transaction_id)
            VALUES ((@c_TotePrefixed + RIGHT('0000000000' + CONVERT(NVARCHAR, @n_CurrToteNum) ,9)), @c_transaction_id)
            
            FETCH NEXT FROM GEEKPLUS_CNTROUT_TOTELIST INTO @n_CurrToteNum
         END
         CLOSE GEEKPLUS_CNTROUT_TOTELIST
         DEALLOCATE GEEKPLUS_CNTROUT_TOTELIST

      END --ELSE IF @c_ITFType = 'T'

      IF @b_Debug = 1
      BEGIN
         SELECT * FROM #TEMP_Geek_CNTR_List
      END

      --Send WebService Request
      IF EXISTS ( SELECT 1 FROM #TEMP_Geek_CNTR_List )
      BEGIN
         SELECT 
            @n_TotalCntr = COUNT(1)
          , @n_Cntr_RowOffset = 0
          , @n_Cntr_RowFetch = IIF(Count(1) < 200, Count(1), 200)
         FROM #TEMP_Geek_CNTR_List

         --Construct JSON and send http request
         FETCH_CONTAINER:
         IF @b_Debug = 1
         BEGIN
            PRINT '>>>> FETCHING CONTAINERS'
            PRINT '@n_TotalCntr: ' + CONVERT(NVARCHAR, @n_TotalCntr)
            PRINT '@n_Cntr_RowOffset: ' + CONVERT(NVARCHAR, @n_Cntr_RowOffset) + ', @n_Cntr_RowFetch: ' + CONVERT(NVARCHAR, @n_Cntr_RowFetch)
         END

         SET @c_FullRequestString = (ISNULL(RTRIM((
            SELECT 
               @c_warehouse_code As 'header.warehouse_code'
             , @c_user_id As 'header.user_id'
             , @c_user_key As 'header.user_key'
             --, COUNT(1) As 'body.container_amount'
             , @n_Cntr_RowFetch As 'body.container_amount'
             , ( 
                  SELECT
                     transaction_id As 'transaction_id'
                   , container_id As 'container_code'
                   , 0 As 'use_type'
                   , 1 As 'status'
                   , CASE WHEN @c_ITFType = 'P' THEN 1 WHEN @c_ITFType = 'T' THEN 2 ELSE 0 END As 'type'
                  FROM #TEMP_Geek_CNTR_List
                  ORDER BY seq
                  OFFSET @n_Cntr_RowOffset ROWS 
                  FETCH NEXT @n_Cntr_RowFetch ROWS ONLY
                  FOR JSON PATH 
               ) as 'body.container_list'
            --FROM #TEMP_Geek_CNTR_List
            --ORDER BY seq 
            --OFFSET @n_Cntr_RowOffset ROWS 
            --FETCH NEXT @n_Cntr_RowFetch ROWS ONLY
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
         )), ''))

         BEGIN TRY
            IF @b_Debug = 1
            BEGIN
               PRINT '>>> Sending WS Request - ' + @c_WS_url
               PRINT '>>> Display Full Request String - Begin'
               PRINT SUBSTRING(@c_FullRequestString, 1, 4000)    
               PRINT SUBSTRING(@c_FullRequestString, 4001, 4000)    
               PRINT SUBSTRING(@c_FullRequestString, 8001, 4000)    
               PRINT SUBSTRING(@c_FullRequestString, 12001, 4000)    
               PRINT SUBSTRING(@c_FullRequestString, 16001, 4000)    
               PRINT SUBSTRING(@c_FullRequestString, 20001, 4000)    
               PRINT SUBSTRING(@c_FullRequestString, 24001, 4000)    
               PRINT SUBSTRING(@c_FullRequestString, 28001, 4000)    
               PRINT SUBSTRING(@c_FullRequestString, 32001, 4000)    
               PRINT SUBSTRING(@c_FullRequestString, 36001, 4000)    
               PRINT SUBSTRING(@c_FullRequestString, 40001, 4000)
               PRINT '>>> Display Full Request String - End'
            END

            EXEC master.dbo.isp_GenericWebServiceClient 
                 @c_IniFilePath = @c_IniFilePath
		   	   , @c_WebRequestURL = @c_WS_url
		   	   , @c_WebRequestMethod = @c_WebRequestMethod              --@c_WebRequestMethod
		   	   , @c_ContentType = @c_ContentType                        --@c_ContentType
		   	   , @c_WebRequestEncoding = @c_WebRequestEncoding          --@c_WebRequestEncoding
		   	   , @c_RequestString = @c_FullRequestString                --@c_FullRequestString
		   	   , @c_ResponseString = @c_ResponseString         OUTPUT      
		   	   , @c_vbErrMsg = @c_vbErrMsg                     OUTPUT		      														 
               , @n_WebRequestTimeout = 120000                          --@n_WebRequestTimeout -- Miliseconds
		   	   , @c_NetworkCredentialUserName = ''                      --@c_NetworkCredentialUserName -- leave blank if no network credential
		   	   , @c_NetworkCredentialPassword = ''                      --@c_NetworkCredentialPassword -- leave blank if no network credential
		   	   , @b_IsSoapRequest = 0                                   --@b_IsSoapRequest  -- 1 = Add SoapAction in HTTPRequestHeader
		   	   , @c_RequestHeaderSoapAction = ''                        --@c_RequestHeaderSoapAction -- HTTPRequestHeader SoapAction value
		   	   , @c_HeaderAuthorization = ''                            --@c_HeaderAuthorization
		   	   , @c_ProxyByPass = '0'                                   --@c_ProxyByPass, 1 >> Set Ip & Port, 0 >> Set Nothing, '' >> Skip Setup

         END TRY
         BEGIN CATCH
            SET @c_vbErrMsg = CONVERT(NVARCHAR(5),ISNULL(ERROR_NUMBER() ,0)) + ' - ' + ERROR_MESSAGE()

            IF @b_Debug = 1
               PRINT '>>> WS CALL CATCH EXCEPTION - ' + @c_vbErrMsg
         END CATCH
         
         --INSERT LOG
         INSERT INTO dbo.TCPSocket_OUTLog ( [Application], RemoteEndPoint, MessageType, ErrMsg, [Data], MessageNum, StorerKey, ACKData, [Status] )
         VALUES ( @c_Application, @c_WS_url, @c_MessageType, @c_VBErrMsg, @c_FullRequestString, '', @c_StorerKey, @c_ResponseString, '9' )

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 230311
            SET @c_ErrMsg = 'NSQL' 
                          + CONVERT(NVARCHAR(6),@n_Err) 
                          + ': failed to get dbo.TCPSocket_OUTLog.(isp_WSITF_GeekPlusRBT_CONTAINER_Outbound)'
            GOTO QUIT
         END

         SET @n_LOGSerialNo = SCOPE_IDENTITY()

         IF @b_Debug = 1
         BEGIN
            PRINT '>>> @c_VBErrMsg - ' + @c_VBErrMsg
            PRINT '>>> ResponseString - Begin'
            PRINT @c_ResponseString
            PRINT '>>> ResponseString - END'
         END

         IF ISNULL(RTRIM(@c_VBErrMsg), '') <> ''
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 230312
            SET @c_ErrMsg = 'NSQL' 
                          + CONVERT(NVARCHAR(6),@n_Err) 
                          + ': ' + IIF(@n_LOGSerialNo > 0, ('Log Serial No (' + CONVERT(NVARCHAR, @n_LOGSerialNo) + ') - '), '') 
                          + @c_VBErrMsg + '.(isp_WSITF_GeekPlusRBT_CONTAINER_Outbound)'
            GOTO QUIT
         END
         
         IF ISNULL(RTRIM(@c_ResponseString), '') = ''
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 230313
            SET @c_ErrMsg = 'NSQL' 
                          + CONVERT(NVARCHAR(6),@n_Err) 
                          + ': ' + IIF(@n_LOGSerialNo > 0, ('Log Serial No (' + CONVERT(NVARCHAR, @n_LOGSerialNo) + ' - '), '') 
                          + 'Response String returned from GEEK+ server is empty.(isp_WSITF_GeekPlusRBT_CONTAINER_Outbound)'
            GOTO QUIT
         END

         SELECT 
            @c_Resp_MsgCode = MsgCode
          , @c_Resp_Msg = Msg
          , @b_Resp_Success = Success
         FROM OPENJSON(@c_ResponseString)
         WITH (
            MsgCode     NVARCHAR(10)    '$.header.msgCode',
            Msg         NVARCHAR(60)    '$.header.message',
            Success     BIT             '$.body.success'
         )
         
         IF @b_Debug = 1
         BEGIN
            PRINT '>>> Response JSON Body'
            PRINT 'Success - ' + CONVERT(NVARCHAR, @b_Resp_Success) + ', MsgCode - ' + @c_Resp_MsgCode + ', Message - ' + @c_Resp_Msg
         END

         IF @c_Resp_MsgCode <> '200' --OR @b_Resp_Success <> 1
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 230314
            SET @c_ErrMsg = 'NSQL' 
                          + CONVERT(NVARCHAR(6),@n_Err) 
                          + ': ROBOT API return error (' + @c_Resp_MsgCode + ' - ' + @c_Resp_Msg + ').(isp_WSITF_GeekPlusRBT_CONTAINER_Outbound)'

            IF @c_ITFType = 'P'
            BEGIN
               UPDATE dbo.TRANSMITLOG3 WITH (ROWLOCK)
               SET transmitflag = @c_flag5
               WHERE transmitlogkey = @c_TransmitlogKey
            END
            --Exit
            GOTO QUIT
         END

         IF @n_TotalCntr > (@n_Cntr_RowOffset + @n_Cntr_RowFetch)
         BEGIN
            SET @n_Cntr_RowOffset = @n_Cntr_RowOffset + @n_Cntr_RowFetch
            SET @n_Cntr_RowFetch =  IIF((@n_TotalCntr - @n_Cntr_RowOffset) > 200, 200, (@n_TotalCntr - @n_Cntr_RowOffset))
            GOTO FETCH_CONTAINER
         END
         
         --Update transmitflag to 9
         IF @c_ITFType = 'P'
         BEGIN
            UPDATE dbo.TRANSMITLOG3 WITH (ROWLOCK)
            SET transmitflag = @c_flag9
            WHERE transmitlogkey = @c_TransmitlogKey
         END
      END
   END --IF @n_Continue = 1 OR @n_Continue = 2

   QUIT:
   --Send Error Notification
   --IF @b_SendAlert = 1 AND ISNULL(RTRIM(@c_ErrMsg), '') <> ''
   --BEGIN
   --   SELECT @n_EmailGroupId = ISNULL(TRY_CONVERT(INT, ISNULL(RTRIM(Short), '0')), 0)
   --        , @c_EmailTitle = ISNULL(RTRIM([Description]), '')
   --   FROM dbo.Codelkup WITH (NOLOCK)
   --   WHERE ListName = @c_ListName_GeekAlert 
   --   AND Code = @c_Application
   --   AND StorerKey = @c_StorerKey

   --   IF @n_EmailGroupId > 0
   --   BEGIN
   --      EXEC [dbo].[isp_Geek+_SendEmailAlert]
   --        @c_DTSITF_DBName               --@c_DTSITF_DBName
   --      , @n_EmailGroupId                --@n_EmailTo
   --      , @c_EmailTitle                  --@c_Subject
   --      , @c_ErrMsg                      --@c_EmailBody
   --      , @b_Success           OUTPUT
   --   END
   --END

   IF @b_Debug = 1
   BEGIN
      PRINT '>>>>> EXIT SP'
      PRINT '@n_Err: ' + CONVERT(NVARCHAR, @n_Err) + ', @c_ErrMsg: ' + @c_ErrMsg + ', @b_Success: ' + CONVERT(NVARCHAR, @b_Success)
      PRINT '>>>>>>>> isp_WSITF_GeekPlusRBT_CONTAINER_Outbound - END'
   END 
   
   IF CURSOR_STATUS('LOCAL' , 'GEEKPLUS_CNTROUT_RECEIPTDETAIL') in (0 , 1)  
   BEGIN  
      CLOSE GEEKPLUS_CNTROUT_RECEIPTDETAIL  
      DEALLOCATE GEEKPLUS_CNTROUT_RECEIPTDETAIL  
   END

   IF CURSOR_STATUS('LOCAL' , 'GEEKPLUS_CNTROUT_TOTELIST') in (0 , 1)  
   BEGIN  
      CLOSE GEEKPLUS_CNTROUT_TOTELIST  
      DEALLOCATE GEEKPLUS_CNTROUT_TOTELIST  
   END

   WHILE @@TRANCOUNT < @n_StartCnt      
      BEGIN TRAN

   IF @n_Continue= 3  -- Error Occured - Process And Return      
   BEGIN      
      SET @b_Success = 0      
      IF @@TRANCOUNT > @n_StartCnt AND @@TRANCOUNT = 1
      BEGIN               
         ROLLBACK TRAN      
      END      
      ELSE      
      BEGIN      
         WHILE @@TRANCOUNT > @n_StartCnt      
         BEGIN      
            COMMIT TRAN      
         END      
      END   
      RETURN      
   END      
   ELSE      
   BEGIN      
      SELECT @b_Success = 1      
      WHILE @@TRANCOUNT > @n_StartCnt      
      BEGIN      
         COMMIT TRAN      
      END      
      RETURN      
   END

END -- Procedure  

GO