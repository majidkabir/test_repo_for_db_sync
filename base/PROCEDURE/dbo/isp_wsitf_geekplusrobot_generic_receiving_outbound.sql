SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: isp_WSITF_GeekPlusRobot_Generic_RECEIVING_Outbound  */
/* Creation Date: 18-Jun-2018                                           */
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
/* Called By: Triggered by RDT                                          */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date           Author         Purposes											*/
/* 2018-06-18     Alex           Initial - Jira #WMS-13306              */
/************************************************************************/
CREATE PROC [dbo].[isp_WSITF_GeekPlusRobot_Generic_RECEIVING_Outbound](
      @c_StorerKey               NVARCHAR(15)
    , @c_PalletId                NVARCHAR(18)
    , @c_Facility                NVARCHAR(10)
    , @b_Debug                   INT
    , @b_Success                 INT               = 0  OUTPUT  
    , @n_Err                     INT               = 0  OUTPUT  
    , @c_ErrMsg                  NVARCHAR(250)     = '' OUTPUT  
    --, @c_InTransmitLogKey       NVARCHAR(10)      = '' 
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
         --, @c_flag                        NVARCHAR(1)
         --, @c_flag0                       NVARCHAR(1)
         --, @c_flag1                       NVARCHAR(1)
         --, @c_flag5                       NVARCHAR(1)
         --, @c_flag9                       NVARCHAR(1)

         , @n_LOGSerialNo                 INT
         , @c_FullRequestString           NVARCHAR(MAX)
         , @c_ResponseString              NVARCHAR(MAX)
         , @c_vbErrMsg                    NVARCHAR(MAX)

         , @c_Query                       NVARCHAR(MAX)
         , @c_CurrentDBName               NVARCHAR(15) 

         , @n_Exists                      INT

         , @c_IniFilePath                 VARCHAR(225) 
         , @c_WebRequestMethod            VARCHAR(10)
         , @c_ContentType                 VARCHAR(100)
         , @c_WebRequestEncoding          VARCHAR(30)
         , @c_WS_url                      NVARCHAR(250)

         --header
         , @c_warehouse_code              NVARCHAR(16)
         , @c_user_id                     NVARCHAR(16)
         , @c_user_key                    NVARCHAR(16)

         --body.receipt_list
         , @c_transaction_id              NVARCHAR(10)
         , @c_receipt_code                NVARCHAR(28)
         , @n_type                        INT
         , @c_pallet_code                 NVARCHAR(18)

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
         , @c_ErrLog_ErrMsg               NVARCHAR(250)

         , @n_IsExists                    INT
         , @c_ReservedSQLQuery1             NVARCHAR(MAX)
         , @c_SQLQuery                    NVARCHAR(MAX)
         , @c_SQLParams                   NVARCHAR(2000)

   SET @n_Continue                        = 1
   SET @n_StartCnt                        = @@TRANCOUNT

   SET @b_Success                         = 0
   SET @n_Err                             = 0
   SET @c_ErrMsg                          = ''

   SET @c_PalletId                        = ISNULL(RTRIM(@c_PalletId), '')
   SET @c_StorerKey                       = ISNULL(RTRIM(@c_StorerKey), '')
   SET @c_Facility                        = ISNULL(RTRIM(@c_Facility), '')

   SET @c_Application                     = 'GEEK+_RECEIVING_OUT'
   SET @c_MessageType                     = 'WS_OUT'
   --SET @c_flag                            = ''
   --SET @c_flag0                           = '0'
   --SET @c_flag1                           = '1'
   --SET @c_flag5                           = '5'
   --SET @c_flag9                           = '9'

   SET @n_LOGSerialNo                     = 0
   SET @c_FullRequestString               = ''
   SET @c_ResponseString                  = ''
   SET @c_vbErrMsg                        = ''

   SET @c_Query                           = ''
   SET @c_CurrentDBName                   = DB_NAME()

   SET @c_WebRequestMethod                = 'POST'
   SET @c_ContentType                     = 'application/json'
   SET @c_WebRequestEncoding              = 'UTF-8'
   SET @c_WS_url                          = ''

   --header
   SET @c_warehouse_code                  = ''
   SET @c_user_id                         = ''
   SET @c_user_key                        = ''

   --body.receipt_list
   SET @c_transaction_id                  = ''
   SET @c_receipt_code                    = ''
   SET @n_type                            = 5

   SET @c_pallet_code                     = ''

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

   SET @n_IsExists                        = 0
   SET @c_SQLQuery                        = ''
   SET @c_SQLParams                       = ''

   IF @b_Debug = 1
   BEGIN
      PRINT '>>>>>>>> isp_WSITF_GeekPlusRobot_Generic_RECEIVING_Outbound - BEGIN'
      PRINT '@c_StorerKey: ' + @c_StorerKey + ', @c_PalletId: ' + @c_PalletId + ', @c_Facility: ' + @c_Facility
   END 

   SELECT @n_IsExists = (1)
         ,@c_ReservedSQLQuery1 = ISNULL(RTRIM(ReservedSQLQuery1), '')
   FROM [dbo].[GEEKPBOT_INTEG_CONFIG] WITH (NOLOCK)
   WHERE InterfaceName = 'RECEIVING_OUTBOUND' 
   AND StorerKey = @c_StorerKey

   IF @n_IsExists = 0 OR @c_ReservedSQLQuery1 = ''
   BEGIN
       SET @n_Continue = 3
       SET @n_Err = 110001
       SET @c_ErrMsg = 'NSQL' 
                     + CONVERT(NVARCHAR(6),@n_Err) 
                     + ': [dbo].[GEEKPBOT_INTEG_CONFIG](InterfaceName=RECEIVING_OUTBOUND, StorerKey='
                     + @c_StorerKey + ') is not setup.(isp_WSITF_GeekPlusRobot_Generic_RECEIVING_Outbound)'
       GOTO QUIT
   END

   --IF NOT EXISTS ( SELECT 1 FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
   --   INNER JOIN dbo.Loc L WITH (NOLOCK) ON ( L.Loc = LLI.Loc AND L.LocationType = 'ROBOTSTG' AND L.Facility = @c_Facility )
   --   WHERE LLI.Id = @c_PalletId AND LLI.StorerKey = @c_StorerKey AND LLI.Qty > 0 )
   --BEGIN
   --   SET @n_Continue = 3
   --   SET @n_Err = 110002
   --   SET @c_ErrMsg = 'NSQL' 
   --                 + CONVERT(NVARCHAR(6),@n_Err) 
   --                 + ': invalid pallet id(' + @c_PalletId + ')/loc.(isp_WSITF_GeekPlusRobot_Generic_RECEIVING_Outbound)'
   --   GOTO QUIT
   --END

   IF NOT EXISTS ( SELECT 1 FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
      INNER JOIN dbo.Loc L WITH (NOLOCK) 
      ON ( L.Loc = LLI.Loc AND L.Facility = @c_Facility 
         AND L.LocationType IN (SELECT Code FROM dbo.CODELKUP (NOLOCK) WHERE LISTNAME = 'AGVSTG' AND Storerkey = @c_StorerKey)  )
      WHERE LLI.Id = @c_PalletId AND LLI.StorerKey = @c_StorerKey AND LLI.Qty > 0 )
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 110002
      SET @c_ErrMsg = 'NSQL' 
                    + CONVERT(NVARCHAR(6),@n_Err) 
                    + ': invalid pallet id(' + @c_PalletId + ')/loc.(isp_WSITF_GeekPlusRobot_Generic_RECEIVING_Outbound)'
      GOTO QUIT
   END

   SET @n_Exists = 0
   SELECT 
      @n_Exists = (1)
    , @c_warehouse_code = ISNULL(RTRIM(Short), '') 
   FROM dbo.Codelkup WITH (NOLOCK) 
   WHERE Listname = 'ROBOTFAC'
   AND Code = @c_Facility 
   AND StorerKey = @c_StorerKey
   
   IF @c_warehouse_code = '' OR @n_Exists = 0
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 110003
      SET @c_ErrMsg = 'NSQL' 
                    + CONVERT(NVARCHAR(6),@n_Err) 
                    + ': robot warehouse_code (codelkup, listname=ROBOTFAC) not setup.(isp_WSITF_GeekPlusRobot_Generic_RECEIVING_Outbound)'      
      GOTO QUIT
   END

   SET @n_Exists = 0
   SELECT 
      @n_Exists = (1)
    , @c_WS_url = Long 
    , @c_user_id = UDF01
    , @c_user_key = UDF02
    , @c_IniFilePath = Notes
   FROM dbo.Codelkup WITH (NOLOCK) 
   WHERE Listname = 'WebService'
   AND Code = @c_warehouse_code 
   AND StorerKey = @c_StorerKey
   AND Code2 = 'ASN'

   IF ISNULL(RTRIM(@c_WS_url), '') = '' OR @n_Exists = 0
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 110004
      SET @c_ErrMsg = 'NSQL' 
                    + CONVERT(NVARCHAR(6),@n_Err) 
                    + ': robot API Url (codelkup, listname=WebService) not setup.'
                    + '(isp_WSITF_GeekPlusRobot_Generic_RECEIVING_Outbound)'      
      GOTO QUIT
   END

   SET @n_Exists = 0
   SELECT 
      @n_Exists = (1)
    , @c_owner_code = ISNULL(RTRIM(Short), '') 
   FROM dbo.Codelkup WITH (NOLOCK) 
   WHERE Listname = 'ROBOTSTR'
   AND Code = @c_StorerKey 
   AND StorerKey = @c_StorerKey
   
   IF @c_owner_code = '' OR @n_Exists = 0
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 110005
      SET @c_ErrMsg = 'NSQL' 
                    + CONVERT(NVARCHAR(6),@n_Err) 
                    + ': robot owner_code (codelkup, listname=ROBOTSTR) not setup.'
                    + '(isp_WSITF_GeekPlusRobot_Generic_RECEIVING_Outbound)'      
      GOTO QUIT
   END

   EXEC [dbo].[nspg_GetKey]     
      'GEEK_REC_TRANSID'   
    , 10 
    , @c_transaction_id     OUTPUT    
    , @b_Success            OUTPUT    
    , @n_Err                OUTPUT    
    , @c_ErrMsg             OUTPUT

   IF @b_Success <> 1
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 110006
      SET @c_ErrMsg = 'NSQL' 
                    + CONVERT(NVARCHAR(6),@n_Err) 
                    + ': failed to generate transaction id - ' + @c_ErrMsg 
                    + '.(isp_WSITF_GeekPlusRobot_Generic_RECEIVING_Outbound)'
      GOTO QUIT
   END

   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      BEGIN TRY
         SET @c_SQLQuery = N'SELECT @c_FullRequestString = (ISNULL(RTRIM(( ' 
                       + @c_ReservedSQLQuery1 
                       + N')),''''))'
         
         SET @c_SQLParams = N'@c_warehouse_code NVARCHAR(16), @c_user_id NVARCHAR(16), @c_user_key NVARCHAR(16), '
                          + N'@c_transaction_id NVARCHAR(10), @c_PalletId NVARCHAR(18), '
                          + N'@c_owner_code NVARCHAR(16), @c_Facility NVARCHAR(10), @c_StorerKey NVARCHAR(15), '
                          + N'@c_FullRequestString NVARCHAR(MAX) OUTPUT'

         IF @b_Debug = 1
         BEGIN
            PRINT '>==================================================>'
            PRINT '>>>> Full ReservedSQLQuery1 (BEGIN)'
            PRINT @c_SQLQuery
            PRINT '>>>> Full ReservedSQLQuery1 (END)'
            PRINT '>==================================================>'
         END

         EXEC sp_ExecuteSql @c_SQLQuery
                          , @c_SQLParams
                          , @c_warehouse_code, @c_user_id, @c_user_key
                          , @c_transaction_id, @c_PalletId
                          , @c_owner_code, @c_Facility, @c_StorerKey
                          , @c_FullRequestString   OUTPUT

      END TRY
      BEGIN CATCH
         SET @n_Continue = 3
         SET @n_Err = 110007
			SET @c_ErrMsg = CONVERT(NVARCHAR(6),@n_Err) + ' ReservedSQLQuery1 Error - ' + ERROR_MESSAGE()

         IF @b_Debug = 1
         BEGIN
            PRINT '>>> GEN REQUEST QUERY CATCH EXCEPTION - ' + @c_ErrMsg
         END

          GOTO QUIT
		END CATCH

      BEGIN TRY
         IF @b_Debug = 1
         BEGIN
            PRINT '>>> Sending WS Request - ' + @c_WS_url
            PRINT '>>> Display Full Request String - Begin'
            PRINT @c_FullRequestString   
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
            , @n_WebRequestTimeout = 180000                          --@n_WebRequestTimeout -- Miliseconds
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
     
      SET @b_Success = 0
      SET @c_Query = N' SET ANSI_WARNINGS OFF; '
                   + N' INSERT INTO dbo.TCPSocket_OUTLog ( [Application], RemoteEndPoint, '
                   + N' MessageType, ErrMsg, [Data], MessageNum, StorerKey, ACKData, [Status] ) '
                   + N' VALUES ( ' 
                   + N'''' + REPLACE(@c_Application, '''', '''''') + ''', ' 
                   + N'''' + REPLACE(@c_WS_url, '''', '''''') + ''', ' 
                   + N'''' + REPLACE(@c_MessageType, '''', '''''') + ''', ' 
                   + N'''' + REPLACE(@c_VBErrMsg, '''', '''''') + ''', '
                   + N'N''' + REPLACE(@c_FullRequestString, '''', '''''') + ''', '
                   + QUOTENAME('', '''') + ', '
                   + N'''' + REPLACE(@c_StorerKey, '''', '''''') + ''', ' 
                   + N'N''' + REPLACE(@c_ResponseString, '''', '''''') + ''', '
                   + N'''9'' )'

      EXEC master.[dbo].[isp_SQLExecution]
         @c_CurrentDBName
       , @c_Query

      SET @n_LOGSerialNo = SCOPE_IDENTITY()

      IF @b_Debug = 1
      BEGIN
         PRINT '>>> @c_VBErrMsg - ' + @c_VBErrMsg
         PRINT '>>> ResponseString - Begin'
         PRINT @c_ResponseString
         PRINT '>>> ResponseString - END'
      END

      --(Alex01) timeout consider success, if robot no receive any ws request, operation can retrigger easily by using RDT - move by id. 
      IF ISNULL(RTRIM(@c_VBErrMsg), '') <> '' 
         AND ISNULL(RTRIM(@c_VBErrMsg), '') <> 'The operation has timed out' 
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 110008
         SET @c_ErrMsg = 'NSQL' 
                       + CONVERT(NVARCHAR(6),@n_Err) 
                       + ': ' + IIF(@n_LOGSerialNo > 0, ('Log Serial No (' + CONVERT(NVARCHAR, @n_LOGSerialNo) + ') - '), '') 
                       + @c_VBErrMsg + '.(isp_WSITF_GeekPlusRobot_Generic_RECEIVING_Outbound)'
         GOTO QUIT
      END
      
      IF ISNULL(RTRIM(@c_ResponseString), '') = ''
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 110009
         SET @c_ErrMsg = 'NSQL' 
                       + CONVERT(NVARCHAR(6),@n_Err) 
                       + ': ' + IIF(@n_LOGSerialNo > 0, ('Log Serial No (' + CONVERT(NVARCHAR, @n_LOGSerialNo) + ' - '), '') 
                       + 'Response String returned from GEEK+ server is empty.(isp_WSITF_GeekPlusRobot_Generic_RECEIVING_Outbound)'
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

      IF @b_Resp_Success <> 1
      BEGIN
         IF @b_Debug = 1
         BEGIN
            PRINT '>>>> GEEK+ Response False'
            PRINT 'Move inventory to ROBOT HOLD LOCATION'
         END

         BEGIN TRAN

         DECLARE GEEKPLUS_RECEIVEOUT_MOVEINVENTORY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT LLI.Lot, LLI.Loc, LLI.Sku, LLI.Qty
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
            INNER JOIN dbo.Loc L WITH (NOLOCK) 
            ON ( L.Loc = LLI.Loc AND L.Facility = @c_Facility 
               AND L.LocationType IN (SELECT Code FROM dbo.CODELKUP (NOLOCK) WHERE LISTNAME = 'AGVSTG' AND Storerkey = @c_StorerKey) )
            WHERE LLI.Id = @c_PalletId
            AND LLI.StorerKey = @c_StorerKey
            AND LLI.Qty > 0
            --AND LLI.Loc <> @c_ToLoc
         OPEN GEEKPLUS_RECEIVEOUT_MOVEINVENTORY
         
         FETCH NEXT FROM GEEKPLUS_RECEIVEOUT_MOVEINVENTORY INTO @c_Lot, @c_FromLoc, @c_Sku, @n_Qty
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            SELECT @c_ToLoc = Loc
            FROM [dbo].[LOC] WITH (NOLOCK)
            WHERE Facility = @c_Facility
            --AND LocationCategory = 'ROBOT' 
            --AND LocationType = 'ROBOTHOLD'
            AND LocationCategory IN ( SELECT Code FROM dbo.CODELKUP (NOLOCK) WHERE LISTNAME = 'AGVCAT' AND Storerkey = @c_StorerKey )
            AND LocationType IN ( SELECT Code FROM dbo.CODELKUP (NOLOCK) WHERE LISTNAME = 'AGVHOLD' AND Storerkey = @c_StorerKey ) 
            AND PickZone = ( 
               SELECT PickZone FROM dbo.Loc WITH (NOLOCK) 
               WHERE Facility = @c_Facility AND Loc = @c_FromLoc )
            
            IF ISNULL(RTRIM(@c_ToLoc), '') = ''
            BEGIN
               SET @n_Continue = 3
               SET @n_Err = 110010
               SET @c_ErrMsg = 'NSQL' 
                             + CONVERT(NVARCHAR(6),@n_Err) 
                             + ': ROBOT HOLD Location not setup.(isp_WSITF_GeekPlusRobot_Generic_RECEIVING_Outbound)'
               GOTO QUIT
            END
         
            IF @c_ToLoc <> @c_FromLoc
            BEGIN
               EXEC nspItrnAddMove
                  @n_ItrnSysId      = NULL                                       
                , @c_StorerKey      = @c_StorerKey                         -- @c_StorerKey   
                , @c_Sku            = @c_Sku                               -- @c_Sku         
                , @c_Lot            = @c_Lot                               -- @c_Lot         
                , @c_FromLoc        = @c_FromLoc                           -- @c_FromLoc     
                , @c_FromID         = @c_PalletId                          -- @c_FromID      
                , @c_ToLoc          = @c_ToLoc                             -- @c_ToLoc       
                ,  @c_ToID          = @c_PalletId                          -- @c_ToID        
                , @c_Status         = '0'                                  -- @c_Status      
                , @c_lottable01     = ''                                   -- @c_lottable01  
                , @c_lottable02     = ''                                   -- @c_lottable02  
                , @c_lottable03     = ''                                   -- @c_lottable03  
                , @d_lottable04     = NULL                                 -- @d_lottable04  
                , @d_lottable05     = NULL                                 -- @d_lottable05  
                , @c_lottable06     = ''                                   -- @c_lottable06  
                , @c_lottable07     = ''                                   -- @c_lottable07  
                , @c_lottable08     = ''                                   -- @c_lottable08  
                , @c_lottable09     = ''                                   -- @c_lottable09  
                , @c_lottable10     = ''                                   -- @c_lottable10  
                , @c_lottable11     = ''                                   -- @c_lottable11  
                , @c_lottable12     = ''                                   -- @c_lottable12  
                , @d_lottable13     = NULL                                 -- @d_lottable13  
                , @d_lottable14     = NULL                                 -- @d_lottable14  
                , @d_lottable15     = NULL                                 -- @d_lottable15  
                , @n_casecnt        = 0                                    -- @n_casecnt     
                , @n_innerpack      = 0                                    -- @n_innerpack   
                , @n_qty            = @n_Qty                               -- @n_qty         
                , @n_pallet         = 0                                    -- @n_pallet      
                , @f_cube           = 0                                    -- @f_cube        
                , @f_grosswgt       = 0                                    -- @f_grosswgt    
                , @f_netwgt         = 0                                    -- @f_netwgt      
                , @f_otherunit1     = 0                                    -- @f_otherunit1  
                , @f_otherunit2     = 0                                    -- @f_otherunit2  
                , @c_SourceKey      = @n_LOGSerialNo                       -- @c_SourceKey
                , @c_SourceType     = 'Robot Geek+ RECEIVING OUT Move'     -- @c_SourceType
                , @c_PackKey        = ''                                   -- @c_PackKey     
                , @c_UOM            = ''                                   -- @c_UOM         
                , @b_UOMCalc        = 0                                    -- @b_UOMCalc     
                , @d_EffectiveDate  = NULL                                 -- @d_EffectiveD  
                , @c_itrnkey        = ''                                   -- @c_itrnkey     
                , @b_Success        = @b_Success   OUTPUT                  -- @b_Success   
                , @n_err            = @n_Err       OUTPUT                  -- @n_err       
                , @c_errmsg         = @c_ErrMsg    OUTPUT                  -- @c_errmsg    
                , @c_MoveRefKey     = ''                                   -- @c_MoveRefKey  
         
               IF @b_Success <> 1
               BEGIN
                  SET @n_Continue = 3
                  SET @n_Err = 110011
                  SET @c_ErrMsg = 'NSQL' 
                                + CONVERT(NVARCHAR(6),@n_Err) 
                                + ': Failed to move inventory to ROBOT HOLD Location.(isp_WSITF_GeekPlusRobot_Generic_RECEIVING_Outbound)'
                  GOTO QUIT
               END
            END
         
            FETCH NEXT FROM GEEKPLUS_RECEIVEOUT_MOVEINVENTORY INTO @c_Lot, @c_FromLoc, @c_Sku, @n_Qty
         END
         CLOSE GEEKPLUS_RECEIVEOUT_MOVEINVENTORY
         DEALLOCATE GEEKPLUS_RECEIVEOUT_MOVEINVENTORY

         WHILE @@TRANCOUNT > 0
            COMMIT TRAN
      END

   END --@n_Continue = 1 OR @n_Continue = 2 End
   
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
      PRINT '>>>>>>>> isp_WSITF_GeekPlusRobot_Generic_RECEIVING_Outbound - END'
   END 

   IF CURSOR_STATUS('LOCAL' , 'GEEKPLUS_RECEIVEOUT_MOVEINVENTORY') in (0 , 1)  
   BEGIN  
      CLOSE GEEKPLUS_RECEIVEOUT_MOVEINVENTORY  
      DEALLOCATE GEEKPLUS_RECEIVEOUT_MOVEINVENTORY  
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

      --(Alex01) BEGIN
      --insert error log
      SET @c_ErrLog_ErrMsg = ('PalletID[' + @c_PalletId + '] - ' + @c_ErrMsg)
      SET @c_Query = N' SET ANSI_WARNINGS OFF; '
                   + N' EXECUTE nsp_logerror '  + CONVERT(NVARCHAR, @n_Err) + 
                   + N' , ''' + REPLACE(@c_ErrLog_ErrMsg, '''', '''''') + ''' , ''isp_WSITF_GeekPlusRobot_Generic_RECEIVING_Outbound'' '

      EXEC master.[dbo].[isp_SQLExecution]
         @c_CurrentDBName
       , @c_Query
      --SET @c_ErrLog_ErrMsg = ('PalletID[' + @c_PalletId + '] - ' + @c_ErrMsg)
      --EXECUTE nsp_logerror @n_Err, @c_ErrLog_ErrMsg, 'isp_WSITF_GeekPlusRobot_Generic_RECEIVING_Outbound'
      --(Alex01) END

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