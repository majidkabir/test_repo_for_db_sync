SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: isp_WSITF_GeekPlusRBT_SKU_Outbound                  */
/* Creation Date: 11-Jun-2018                                           */
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
/* Called By: Job Scheduler                                             */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date           Author         Purposes											*/
/* 2018-06-11     Alex           Initial - Jira #WMS-5213               */
/************************************************************************/
CREATE PROC [dbo].[isp_WSITF_GeekPlusRBT_SKU_Outbound](         
      @c_StorerKey              NVARCHAR(15)
    , @b_Debug                  INT
    , @b_Success                INT               = 0  OUTPUT  
    , @n_Err                    INT               = 0  OUTPUT  
    , @c_ErrMsg                 NVARCHAR(250)     = '' OUTPUT  
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
         , @c_flag                        NVARCHAR(1)
         , @c_flag0                       NVARCHAR(1)
         , @c_flag1                       NVARCHAR(1)
         , @c_flag5                       NVARCHAR(1)
         , @c_flag9                       NVARCHAR(1)
         , @c_ListName_WebService         NVARCHAR(10)           
         , @c_ListName_ROBOTFAC           NVARCHAR(10)
         , @c_ListName_ROBOTSTR           NVARCHAR(10)
         , @c_SConfKey_RBSTDDATA          NVARCHAR(30)

         , @c_TransmitLogKey              NVARCHAR(10)

         , @c_IniFilePath                 VARCHAR(225) 
         , @c_WebRequestMethod            VARCHAR(10)
         , @c_ContentType                 VARCHAR(100)
         , @c_WebRequestEncoding          VARCHAR(30)
         , @c_WS_url                      NVARCHAR(250)
         , @c_warehouse_code              NVARCHAR(16)
         , @c_user_id                     NVARCHAR(16)
         , @c_user_key                    NVARCHAR(16)

         , @c_SC_RBSTDDATA_Value          NVARCHAR(5)

         , @c_owner_code                  NVARCHAR(16)
         , @n_sku_status                  INT
         , @n_is_sequence_sku             INT

         , @c_transaction_id              NVARCHAR(10)
         , @c_FullRequestString           NVARCHAR(MAX)
         , @c_JSON_HEADER                 NVARCHAR(2000)
         , @c_JSON_BODY                   NVARCHAR(MAX)

         , @n_LOGSerialNo                 INT
         , @c_ResponseString              NVARCHAR(MAX)
         , @c_vbErrMsg                    NVARCHAR(MAX)
         , @c_Resp_MsgCode                NVARCHAR(10)
         , @c_Resp_Msg                    NVARCHAR(200)
         , @b_Resp_Success                BIT

         , @c_ListName_GeekAlert          NVARCHAR(10)
         , @b_SendAlert                   INT
         , @n_EmailGroupId                INT
         , @c_EmailTitle                  NVARCHAR(100)
         , @c_DTSITF_DBName               NVARCHAR(10)

   SET @n_Continue                        = 1
   SET @n_StartCnt                        = @@TRANCOUNT

   SET @b_Success                         = 0
   SET @n_Err                             = 0
   SET @c_ErrMsg                          = ''
   --SET @c_InTransmitLogKey                = ISNULL(RTRIM(@c_InTransmitLogKey), '')

   SET @c_Application                     = 'GEEK+_SKU_OUT'
   SET @c_MessageType                     = 'WS_OUT'
   SET @c_flag                            = ''
   SET @c_flag0                           = '0'
   SET @c_flag1                           = '1'
   SET @c_flag5                           = '5'
   SET @c_flag9                           = '9'
   SET @c_ListName_WebService             = 'WebService'
   SET @c_ListName_ROBOTFAC               = 'ROBOTFAC'
   SET @c_ListName_ROBOTSTR               = 'ROBOTSTR'
   SET @c_SConfKey_RBSTDDATA              = 'RBSTDDATA'

   SET @c_WebRequestMethod                = 'POST'
   SET @c_ContentType                     = 'application/json'
   SET @c_WebRequestEncoding              = 'UTF-8'
   SET @c_WS_url                          = ''
   SET @c_warehouse_code                  = ''
   SET @c_user_id                         = ''
   SET @c_user_key                        = ''

   SET @c_SC_RBSTDDATA_Value              = ''
   SET @c_owner_code                      = ''
   SET @n_sku_status                      = 1
   SET @n_is_sequence_sku                 = 0

   SET @c_transaction_id                  = ''
   SET @c_FullRequestString               = ''
   SET @c_JSON_HEADER                     = ''
   SET @c_JSON_BODY                       = ''

   SET @c_ListName_GeekAlert              = 'GEEK+ALERT'
   SET @b_SendAlert                       = 0
   SET @n_EmailGroupId                    = 0
   SET @c_EmailTitle                      = ''
   SET @c_DTSITF_DBName                   = ''

   IF OBJECT_ID('tempdb..#TEMP_Geek_SkuList') IS NOT NULL
   DROP TABLE #TEMP_Geek_SkuList

   CREATE TABLE #TEMP_Geek_SkuList(
      transmitlogkey    NVARCHAR(10) NOT NULL,
      sku               NVARCHAR(20) NOT NULL,
      storerkey         NVARCHAR(15) NOT NULL,
      transaction_id    NVARCHAR(10) NULL
   )

   --reprocess transmitlog with flag 0
   DECLARE GEEKPLUS_SKUOUT_REUPD_TL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT transmitlogkey
      FROM dbo.TRANSMITLOG3 WITH (NOLOCK)
      WHERE tablename IN ('ADDSKULOG', 'UPDSKULOG')
      AND key1 = @c_StorerKey
      AND transmitflag = @c_flag1

   OPEN GEEKPLUS_SKUOUT_REUPD_TL
   
   FETCH NEXT FROM GEEKPLUS_SKUOUT_REUPD_TL INTO @c_TransmitLogKey
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      UPDATE dbo.TRANSMITLOG3 WITH (ROWLOCK)
      SET transmitflag = @c_flag0
      WHERE transmitlogkey =  @c_TransmitLogKey

      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 100002
         SET @c_ErrMsg = 'NSQL' 
                       + CONVERT(NVARCHAR(6),@n_Err) 
                       + ': failed to update transmitflag of transmitlog3.(isp_WSITF_GeekPlusRBT_SKU_Outbound)'
         GOTO QUIT
      END
      FETCH NEXT FROM GEEKPLUS_SKUOUT_REUPD_TL INTO @c_TransmitLogKey
   END
   CLOSE GEEKPLUS_SKUOUT_REUPD_TL
   DEALLOCATE GEEKPLUS_SKUOUT_REUPD_TL

   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      IF @b_Debug = 1
      BEGIN
         PRINT '>>>>>>>> isp_WSITF_GeekPlusRBT_SKU_Outbound - BEGIN'
         PRINT '@c_StorerKey: ' + @c_StorerKey + ", @c_TransmitLogKey: " + @c_TransmitLogKey
      END 

      GET_PENDING_TRANSMITLOGS:
      IF NOT EXISTS( SELECT 1 FROM dbo.TRANSMITLOG3 WITH (NOLOCK)
         WHERE tablename IN ('ADDSKULOG', 'UPDSKULOG') 
         AND key1 = @c_StorerKey AND transmitflag = @c_flag0 )
      BEGIN
         GOTO QUIT
      END

      --Process with maximum 200 skus only
      INSERT INTO #TEMP_Geek_SkuList ( transmitlogkey, storerkey, sku )
      SELECT TOP 200
         transmitlogkey, key1, key3
      FROM dbo.TRANSMITLOG3 WITH (NOLOCK)
      WHERE tablename IN ('ADDSKULOG', 'UPDSKULOG') 
      AND key1 = @c_StorerKey 
      AND transmitflag = @c_flag0 

      --if No SKU to process, exit stored procedure
      --IF ISNULL(RTRIM(@c_InTransmitLogKey), '') <> ''
      --BEGIN
      --   IF NOT EXISTS( SELECT 1 FROM dbo.TRANSMITLOG3 WITH (NOLOCK)
      --      WHERE transmitlogkey = @c_InTransmitLogKey 
      --      AND tablename IN ('ADDSKULOG', 'UPDSKULOG') 
      --      AND transmitflag = @c_flag0 )
      --   BEGIN
      --      GOTO QUIT
      --   END
      --   --Process with input transmitlogkey only
      --   INSERT INTO #TEMP_Geek_SkuList ( transmitlogkey, storerkey, sku  )
      --   SELECT transmitlogkey, key1, key3
      --   FROM dbo.TRANSMITLOG3 WITH (NOLOCK)
      --   WHERE transmitlogkey = @c_InTransmitLogKey
      --   AND tablename IN ('ADDSKULOG', 'UPDSKULOG') 
      --   AND transmitflag = @c_flag0
      --END
      --ELSE
      --BEGIN
      --   IF NOT EXISTS( SELECT 1 FROM dbo.TRANSMITLOG3 WITH (NOLOCK)
      --      WHERE tablename IN ('ADDSKULOG', 'UPDSKULOG') 
      --      AND key1 = @c_StorerKey AND transmitflag = @c_flag0 )
      --   BEGIN
      --      GOTO QUIT
      --   END

      --   --Process with maximum 200 skus only
      --   INSERT INTO #TEMP_Geek_SkuList ( transmitlogkey, storerkey, sku )
      --   SELECT TOP 2--200
      --      transmitlogkey, key1, key3
      --   FROM dbo.TRANSMITLOG3 WITH (NOLOCK)
      --   WHERE tablename IN ('ADDSKULOG', 'UPDSKULOG') 
      --   AND key1 = @c_StorerKey 
      --   AND transmitflag = @c_flag0 
      --END

      --get transaction_id for each sku
      --update transmitflag to 1
      DECLARE GEEKPLUS_SKUOUT_UPDTL_FLAG1 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT transmitlogkey
         FROM #TEMP_Geek_SkuList
      OPEN GEEKPLUS_SKUOUT_UPDTL_FLAG1
      
      FETCH NEXT FROM GEEKPLUS_SKUOUT_UPDTL_FLAG1 INTO @c_TransmitLogKey
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         EXEC [dbo].[nspg_GetKey]     
           'geek_sku_transid'   
         , 10 
         , @c_transaction_id     OUTPUT    
         , @b_Success            OUTPUT    
         , @n_Err                OUTPUT    
         , @c_ErrMsg             OUTPUT

         IF @b_Success <> 1
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 100001
            SET @c_ErrMsg = 'NSQL' 
                          + CONVERT(NVARCHAR(6),@n_Err) 
                          + ': failed to generate transaction id - ' + @c_ErrMsg + '.(isp_WSITF_GeekPlusRBT_SKU_Outbound)'
            GOTO QUIT
         END

         --update transaction_id for each sku
         UPDATE #TEMP_Geek_SkuList
         SET transaction_id = @c_transaction_id
         WHERE transmitlogkey =  @c_TransmitLogKey

         UPDATE dbo.TRANSMITLOG3 WITH (ROWLOCK)
         SET transmitflag = @c_flag1
         WHERE transmitlogkey =  @c_TransmitLogKey

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 100002
            SET @c_ErrMsg = 'NSQL' 
                          + CONVERT(NVARCHAR(6),@n_Err) 
                          + ': failed to update transmitflag of transmitlog3.(isp_WSITF_GeekPlusRBT_SKU_Outbound)'
            GOTO QUIT
         END
         FETCH NEXT FROM GEEKPLUS_SKUOUT_UPDTL_FLAG1 INTO @c_TransmitLogKey
      END
      CLOSE GEEKPLUS_SKUOUT_UPDTL_FLAG1
      DEALLOCATE GEEKPLUS_SKUOUT_UPDTL_FLAG1

      SELECT 
         @c_owner_code = short
      FROM dbo.CODELKUP (NOLOCK)
      WHERE ListName = 'ROBOTSTR'
      AND StorerKey = @c_StorerKey
      
      EXECUTE dbo.nspGetRight  
        ''
      , @c_StorerKey
      , ''
      , 'RBSTDDATA'
      , @b_Success               OUTPUT
      , @c_SC_RBSTDDATA_Value    OUTPUT
      , @n_Err                   OUTPUT
      , @c_ErrMsg                OUTPUT

      IF @b_Success <> 1
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 100003
         SET @c_ErrMsg = 'NSQL' 
                       + CONVERT(NVARCHAR(6),@n_Err) 
                       + ': failed to get storerconfig - RBSTDATA.(isp_WSITF_GeekPlusRBT_SKU_Outbound)'
         GOTO QUIT
      END

      --construct json .body
      SET @c_JSON_BODY = (ISNULL(RTRIM((
         SELECT COUNT(1) As 'sku_amount'
         , ( 
            SELECT transaction_id As 'transaction_id'
             , @c_owner_code As 'owner_code'
             , RTRIM(s.SKU) As 'sku_code'
             , s.DESCR As 'sku_name'
             , @n_sku_status As 'sku_status'
             --, s.ItemClass As 'sku_type'
             , CASE WHEN (ISNULL(RTRIM(C1.Long), '') = '' OR ISNUMERIC(C1.Long) <> 1) 
                  THEN 0 
                  ELSE CONVERT(INT, C1.Long)
                END As 'sku_type'
             , CONVERT(DECIMAL(8,1), s.[Length]) As 'length'
             , CONVERT(DECIMAL(8,1), s.Width) As 'width'
             , CONVERT(DECIMAL(8,1), s.Height) As 'height'
             , CASE WHEN @c_SC_RBSTDDATA_Value = '1' 
                  THEN CONVERT(DECIMAL(21,3), s.STDCUBE) 
                  ELSE CONVERT(DECIMAL(21,3), s.[Cube]) 
               END As 'volume'
             , CASE WHEN @c_SC_RBSTDDATA_Value = '1' 
                  THEN CONVERT(DECIMAL(8,1), s.STDNETWGT) 
                  ELSE CONVERT(DECIMAL(8,1), s.NETWGT) 
               END As 'net_weight'
             , CASE WHEN @c_SC_RBSTDDATA_Value = '1' 
                  THEN CONVERT(DECIMAL(8,1), s.STDGROSSWGT) 
                  ELSE CONVERT(DECIMAL(8,1), s.GROSSWGT) 
               END As 'gross_weight'
             , @n_is_sequence_sku As 'is_sequence_sku'
             , (
                  SELECT bar_code as 'bar_code'
                  FROM dbo.Sku s2 WITH (NOLOCK)
                  UNPIVOT
                  (
                     bar_code for cols in ( s2.ALTSKU, s2.RETAILSKU, s2.MANUFACTURERSKU )
                  ) unpiv
                  where sku = s.sku and storerkey = s.storerkey
                  AND ISNULL(RTRIM(bar_code), '') <> ''
                  for JSON PATH
               ) as 'bar_code_list'
             , (
                  SELECT 
                     '1*' + CONVERT(NVARCHAR,IIF(p.InnerPack<=0, 1, p.InnerPack)) + 
                     '*' + CONVERT(NVARCHAR, (IIF(p.CaseCnt<=0, 1, p.CaseCnt)/(IIF(p.InnerPack<=0, 1, p.InnerPack)))) As 'packing_spec'
                   , CONVERT(DECIMAL(6,1), p.LengthUOM3) As 'mini_length'
                   , CONVERT(DECIMAL(6,1), p.WidthUOM3) As 'mini_width'
                   , CONVERT(DECIMAL(6,1), p.HeightUOM3) As 'mini_height'
                   , CONVERT(DECIMAL(10,3), p.CubeUOM3) As 'mini_volume'
                   , CASE WHEN @c_SC_RBSTDDATA_Value = '1'
                        THEN CONVERT(DECIMAL(8,1), p.GrossWgt) 
                        ELSE CONVERT(DECIMAL(8,1), p.NetWgt)
                     END As 'mini_weight'
                   , CONVERT(DECIMAL(6,1), p.LengthUOM2) As 'second_length'
                   , CONVERT(DECIMAL(6,1), p.WidthUOM2) As 'second_width'
                   , CONVERT(DECIMAL(6,1), p.HeightUOM2) As 'second_height'
                   , CONVERT(DECIMAL(10,3), p.CubeUOM2) As 'second_volume'
                   , 0 As 'second_weight'
                   , CONVERT(DECIMAL(6,1), p.LengthUOM1) As 'third_length'
                   , CONVERT(DECIMAL(6,1), p.WidthUOM1) As 'third_width'
                   , CONVERT(DECIMAL(6,1), p.HeightUOM1) As 'third_height'
                   , CONVERT(DECIMAL(10,3), p.CubeUOM1) As 'third_volume'
                   , 0 As 'third_weight'
                  FROM dbo.Pack p WITH (NOLOCK)
                  WHERE p.PackKey = s.PackKey
                  FOR JSON PATH
                ) As 'sku_packing'
            FROM #TEMP_Geek_SkuList t
            INNER JOIN dbo.SKU s WITH (NOLOCK)
            ON ( t.storerkey = s.storerkey and t.sku = s.sku )
            LEFT OUTER JOIN dbo.Codelkup C1 WITH (NOLOCK)
            ON ( C1.ListName = 'SKUTYPE' AND C1.StorerKey = s.StorerKey
               AND C1.Short = s.ItemClass )
            WHERE s.StorerKey = '18354'
            FOR JSON PATH     
            ) as 'sku_list'
            FROM #TEMP_Geek_SkuList
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER )
      ),''))

      --Send Web Service Request
      DECLARE GEEKPLUS_SKU_OUT_URL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT Code, Long, UDF01, UDF02, Notes
         FROM dbo.CODELKUP (NOLOCK)
         WHERE ListName = @c_ListName_WebService
         AND Code2 ='SKU'
         AND StorerKey = @c_StorerKey

      OPEN GEEKPLUS_SKU_OUT_URL
      
      FETCH NEXT FROM GEEKPLUS_SKU_OUT_URL INTO @c_warehouse_code, @c_WS_url, @c_user_id, @c_user_key, @c_IniFilePath
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SET @c_ResponseString                  = ''
         SET @c_vbErrMsg                        = ''
         SET @c_Resp_MsgCode                    = ''
         SET @c_Resp_Msg                        = ''
         SET @b_Resp_Success                    = 0
         SET @n_LOGSerialNo                     = 0

         --Invalid URL
         IF ISNULL(RTRIM(@c_WS_url), '') = ''
         BEGIN
            SET @c_flag = @c_flag5
            GOTO UPD_TL_AFTER_PROCESS
         END

         --construct JSON .header
         SET @c_JSON_HEADER = (ISNULL(RTRIM((
            SELECT 
               @c_warehouse_code As 'warehouse_code'
             , @c_user_id As 'user_id'
             , @c_user_key As 'user_key'
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER )
         ),''))
         
         SET @c_FullRequestString = N'{"header": ' + @c_JSON_HEADER + ', "body": ' + @c_JSON_BODY + '}'

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
            PRINT SUBSTRING(@c_FullRequestString, 44001, 4000)    
            PRINT SUBSTRING(@c_FullRequestString, 48001, 4000)    
            PRINT SUBSTRING(@c_FullRequestString, 52001, 4000)    
            PRINT SUBSTRING(@c_FullRequestString, 56001, 4000)    
            PRINT SUBSTRING(@c_FullRequestString, 60001, 4000)    
            PRINT SUBSTRING(@c_FullRequestString, 64001, 4000)    
            PRINT SUBSTRING(@c_FullRequestString, 68001, 4000)    
            PRINT SUBSTRING(@c_FullRequestString, 72001, 4000)    
            PRINT SUBSTRING(@c_FullRequestString, 76001, 4000)    
            PRINT SUBSTRING(@c_FullRequestString, 80001, 4000)    
            PRINT SUBSTRING(@c_FullRequestString, 84001, 4000)    
            PRINT SUBSTRING(@c_FullRequestString, 88001, 4000)    
            PRINT SUBSTRING(@c_FullRequestString, 92001, 4000)    
            PRINT SUBSTRING(@c_FullRequestString, 96001, 4000)    
            PRINT SUBSTRING(@c_FullRequestString, 100001, 4000)    
            PRINT SUBSTRING(@c_FullRequestString, 104001, 4000)    
            PRINT SUBSTRING(@c_FullRequestString, 108001, 4000)    
            PRINT SUBSTRING(@c_FullRequestString, 112001, 4000)    
            PRINT SUBSTRING(@c_FullRequestString, 116001, 4000)    
            PRINT SUBSTRING(@c_FullRequestString, 120001, 4000)    
            PRINT SUBSTRING(@c_FullRequestString, 124001, 4000)    
            PRINT SUBSTRING(@c_FullRequestString, 128001, 4000)    
            PRINT SUBSTRING(@c_FullRequestString, 132001, 4000)    
            PRINT SUBSTRING(@c_FullRequestString, 136001, 4000)    
            PRINT SUBSTRING(@c_FullRequestString, 140001, 4000)    
            PRINT SUBSTRING(@c_FullRequestString, 144001, 4000)    
            PRINT SUBSTRING(@c_FullRequestString, 148001, 4000)    
            PRINT SUBSTRING(@c_FullRequestString, 152001, 4000)    
            PRINT SUBSTRING(@c_FullRequestString, 156001, 4000)    
            PRINT SUBSTRING(@c_FullRequestString, 160001, 4000)    
            PRINT SUBSTRING(@c_FullRequestString, 164001, 4000)    
            PRINT SUBSTRING(@c_FullRequestString, 168001, 4000)    
            PRINT SUBSTRING(@c_FullRequestString, 172001, 4000)    
            PRINT SUBSTRING(@c_FullRequestString, 176001, 4000)    
            PRINT SUBSTRING(@c_FullRequestString, 180001, 4000)    
            PRINT SUBSTRING(@c_FullRequestString, 184001, 4000)    
            PRINT SUBSTRING(@c_FullRequestString, 188001, 4000)    
            PRINT SUBSTRING(@c_FullRequestString, 192001, 4000)    
            PRINT SUBSTRING(@c_FullRequestString, 196001, 4000)    
            PRINT SUBSTRING(@c_FullRequestString, 200001, 4000)    
            PRINT SUBSTRING(@c_FullRequestString, 204001, 4000)    
            PRINT SUBSTRING(@c_FullRequestString, 208001, 4000)    
            PRINT SUBSTRING(@c_FullRequestString, 212001, 4000)    
            PRINT SUBSTRING(@c_FullRequestString, 216001, 4000)    
            PRINT SUBSTRING(@c_FullRequestString, 220001, 4000)    
            PRINT SUBSTRING(@c_FullRequestString, 224001, 4000)    
            PRINT SUBSTRING(@c_FullRequestString, 228001, 4000)    
            PRINT SUBSTRING(@c_FullRequestString, 232001, 4000)    
            PRINT SUBSTRING(@c_FullRequestString, 236001, 4000)    
            PRINT SUBSTRING(@c_FullRequestString, 240001, 4000)    
            PRINT SUBSTRING(@c_FullRequestString, 244001, 4000)    
            PRINT SUBSTRING(@c_FullRequestString, 248001, 4000)    
            PRINT SUBSTRING(@c_FullRequestString, 252001, 4000)    
            PRINT SUBSTRING(@c_FullRequestString, 256001, 4000)    
            PRINT SUBSTRING(@c_FullRequestString, 260001, 4000)    
            PRINT SUBSTRING(@c_FullRequestString, 264001, 4000)    
            PRINT SUBSTRING(@c_FullRequestString, 268001, 4000)    
            PRINT SUBSTRING(@c_FullRequestString, 272001, 4000)    
            PRINT SUBSTRING(@c_FullRequestString, 276001, 4000)    
            PRINT SUBSTRING(@c_FullRequestString, 280001, 4000)    
            PRINT SUBSTRING(@c_FullRequestString, 284001, 4000)    
            PRINT SUBSTRING(@c_FullRequestString, 288001, 4000)    
            PRINT SUBSTRING(@c_FullRequestString, 292001, 4000)    
            PRINT SUBSTRING(@c_FullRequestString, 296001, 4000)
            PRINT '>>> Display Full Request String - End'
         END
         --send web service request to robot API
         BEGIN TRY
				EXEC master.dbo.isp_GenericWebServiceClient 
               @c_IniFilePath = @c_IniFilePath
				 , @c_WebRequestURL = @c_WS_url
				 , @c_WebRequestMethod = @c_WebRequestMethod          --@c_WebRequestMethod
				 , @c_ContentType = @c_ContentType                    --@c_ContentType
				 , @c_WebRequestEncoding = @c_WebRequestEncoding      --@c_WebRequestEncoding
				 , @c_RequestString = @c_FullRequestString            --@c_FullRequestString
				 , @c_ResponseString = @c_ResponseString OUTPUT      
				 , @c_vbErrMsg = @c_vbErrMsg OUTPUT		      														 
             , @n_WebRequestTimeout = 180000                      --@n_WebRequestTimeout -- Miliseconds
				 , @c_NetworkCredentialUserName = ''                  --@c_NetworkCredentialUserName -- leave blank if no network credential
				 , @c_NetworkCredentialPassword = ''                  --@c_NetworkCredentialPassword -- leave blank if no network credential
				 , @b_IsSoapRequest = 0                               --@b_IsSoapRequest  -- 1 = Add SoapAction in HTTPRequestHeader
				 , @c_RequestHeaderSoapAction = ''                    --@c_RequestHeaderSoapAction -- HTTPRequestHeader SoapAction value
				 , @c_HeaderAuthorization = ''                        --@c_HeaderAuthorization
				 , @c_ProxyByPass = '0'                               --@c_ProxyByPass, 1 >> Set Ip & Port, 0 >> Set Nothing, '' >> Skip Setup
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
            SET @n_Err = 100004
            SET @c_ErrMsg = 'NSQL' 
                          + CONVERT(NVARCHAR(6),@n_Err) 
                          + ': failed to get dbo.TCPSocket_OUTLog.(isp_WSITF_GeekPlusRBT_SKU_Outbound)'
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

         --Unexpected error from Geek+ API server
         --Quit cursor and send alert notification

         IF ISNULL(RTRIM(@c_VBErrMsg), '') <> ''
         BEGIN
            SET @b_SendAlert = 1
            SET @c_flag = @c_flag1
            SET @c_ErrMsg = IIF(@n_LOGSerialNo > 0, ('Log Serial No (' + CONVERT(NVARCHAR, @n_LOGSerialNo) + ') - '), '') 
                          + @c_VBErrMsg
            BREAK
         END

         IF ISNULL(RTRIM(@c_ResponseString), '') = ''
         BEGIN
            SET @b_SendAlert = 1
            SET @c_flag = @c_flag1
            SET @c_ErrMsg = IIF(@n_LOGSerialNo > 0, ('Log Serial No (' + CONVERT(NVARCHAR, @n_LOGSerialNo) + ') - '), '') 
                          + 'Response String returned from GEEK+ server is empty..'
            BREAK
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

         --Unexpected error from Geek+ API server
         --Quit cursor and send alert notification
         IF @b_Resp_Success <> 1
         BEGIN
            SET @c_flag = @c_flag5
            SET @c_ErrMsg = (@c_Resp_MsgCode + ': ' + @c_Resp_Msg)
            BREAK
         END
         ELSE 
         BEGIN
            SET @c_flag = @c_flag9
         END

         FETCH NEXT FROM GEEKPLUS_SKU_OUT_URL INTO @c_warehouse_code, @c_WS_url, @c_user_id, @c_user_key, @c_IniFilePath
      END
      CLOSE GEEKPLUS_SKU_OUT_URL
      DEALLOCATE GEEKPLUS_SKU_OUT_URL
      
      --update transmitflag to 5 or 9 after ws request sent.
      UPD_TL_AFTER_PROCESS:
      DECLARE GEEKPLUS_SKUOUT_UPDTL_AFTPROCESS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT transmitlogkey
         FROM #TEMP_Geek_SkuList
      OPEN GEEKPLUS_SKUOUT_UPDTL_AFTPROCESS
      
      FETCH NEXT FROM GEEKPLUS_SKUOUT_UPDTL_AFTPROCESS INTO @c_TransmitLogKey
      WHILE @@FETCH_STATUS <> -1
      BEGIN      
         UPDATE dbo.TRANSMITLOG3 WITH (ROWLOCK)
         SET transmitflag = @c_flag
         WHERE transmitlogkey =  @c_TransmitLogKey
      
         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 100002
            SET @c_ErrMsg = 'NSQL' 
                          + CONVERT(NVARCHAR(6),@n_Err) 
                          + ': failed to update transmitflag of transmitlog3.(isp_WSITF_GeekPlusRBT_SKU_Outbound)'
            GOTO QUIT
         END
         FETCH NEXT FROM GEEKPLUS_SKUOUT_UPDTL_AFTPROCESS INTO @c_TransmitLogKey
      END
      CLOSE GEEKPLUS_SKUOUT_UPDTL_AFTPROCESS
      DEALLOCATE GEEKPLUS_SKUOUT_UPDTL_AFTPROCESS

      IF @b_SendAlert <> 1
      BEGIN
         --reprocess if got pending transmitlog3
         IF EXISTS( SELECT 1 FROM dbo.TRANSMITLOG3 WITH (NOLOCK)
            WHERE tablename IN ('ADDSKULOG', 'UPDSKULOG') 
            AND key1 = @c_StorerKey AND transmitflag = @c_flag0 )
         BEGIN
            IF @b_Debug = 1
               PRINT '>>> Found pending transmitlog3....'
         
            DELETE FROM #TEMP_Geek_SkuList
            GOTO GET_PENDING_TRANSMITLOGS
         END
      END
      
   END --@n_Continue = 1 OR @n_Continue = 2 End
   
   --IF ISNULL(RTRIM(@c_InTransmitLogKey), '') = ''
   --BEGIN
   --   IF EXISTS( SELECT 1 FROM dbo.TRANSMITLOG3 WITH (NOLOCK)
   --      WHERE tablename IN ('ADDSKULOG', 'UPDSKULOG') 
   --      AND key1 = @c_StorerKey AND transmitflag = @c_flag0 )
   --   BEGIN
   --      IF @b_Debug = 1
   --      BEGIN
   --         PRINT '>>> Found pending transmitlog3....'
   --      END

   --      DELETE FROM #TEMP_Geek_SkuList
   --      GOTO GET_PENDING_TRANSMITLOGS
   --   END
   --END
   
   QUIT:
   --Send Error Notification
   IF @b_SendAlert = 1 AND ISNULL(RTRIM(@c_ErrMsg), '') <> ''
   BEGIN
      SELECT @n_EmailGroupId = ISNULL(TRY_CONVERT(INT, ISNULL(RTRIM(Short), '0')), 0)
           , @c_EmailTitle = ISNULL(RTRIM([Description]), '')
           , @c_DTSITF_DBName = ISNULL(RTRIM(UDF03), '')
      FROM dbo.Codelkup WITH (NOLOCK)
      WHERE ListName = @c_ListName_GeekAlert AND Code = @c_Application
      AND StorerKey = @c_StorerKey

      IF @n_EmailGroupId > 0 AND @c_DTSITF_DBName <> ''
      BEGIN
         EXEC [dbo].[isp_GeekPlusRBT_SendEmailAlert]
           @c_DTSITF_DBName               --@c_DTSITF_DBName
         , @n_EmailGroupId                --@n_EmailTo
         , @c_EmailTitle                  --@c_Subject
         , @c_ErrMsg                      --@c_EmailBody
         , @b_Success           OUTPUT
      END
   END

   IF @b_Debug = 1
   BEGIN
      PRINT '>>>>> EXIT SP'
      PRINT '@n_Err: ' + CONVERT(NVARCHAR, @n_Err) + ', @c_ErrMsg: ' + @c_ErrMsg + ', @b_Success: ' + CONVERT(NVARCHAR, @b_Success)
      PRINT '>>>>>>>> isp_WSITF_GeekPlusRBT_SKU_Outbound - END'
   END 

   IF CURSOR_STATUS('LOCAL' , 'GEEKPLUS_SKUOUT_UPDTL_FLAG1') in (0 , 1)  
   BEGIN  
      CLOSE GEEKPLUS_SKUOUT_UPDTL_FLAG1  
      DEALLOCATE GEEKPLUS_SKUOUT_UPDTL_FLAG1  
   END

   IF CURSOR_STATUS('LOCAL' , 'GEEKPLUS_SKU_OUT_URL') in (0 , 1)  
   BEGIN  
      CLOSE GEEKPLUS_SKU_OUT_URL  
      DEALLOCATE GEEKPLUS_SKU_OUT_URL  
   END

   IF CURSOR_STATUS('LOCAL' , 'GEEKPLUS_SKUOUT_UPDTL_AFTPROCESS') in (0 , 1)  
   BEGIN  
      CLOSE GEEKPLUS_SKUOUT_UPDTL_AFTPROCESS  
      DEALLOCATE GEEKPLUS_SKUOUT_UPDTL_AFTPROCESS  
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