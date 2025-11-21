SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: isp_WSITF_GeekPlusRBT_Order_Outbound                */
/* Creation Date: 22-Jun-2018                                           */
/* Copyright: IDS                                                       */
/* Written by: KCY                                                      */
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
/* 2018-06-212    KCY            Initial - Jira #WMS-5290               */
/* 2018-08-08     KCY            Enhance ORD.doctype filter (KCY01)     */
/* 2018-08-10     Alex01         Default is_allow_lack to 1             */
/* 2019-04-10     KCY            Handle multiple pickslipno SKU (KCY02) */
/* 2019-06-19     Alex02         Jira #WMS-9484 change mapping          */
/* 2021-03-16     Alex03         Remove hardcoded db                    */
/************************************************************************/
CREATE PROC [dbo].[isp_WSITF_GeekPlusRBT_Order_Outbound](
      @c_TransmitlogKey          NVARCHAR(10)      = ''
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
         , @c_flag                        NVARCHAR(10)
         , @c_flag0                       NVARCHAR(1)
         , @c_flag1                       NVARCHAR(1)
         , @c_flag5                       NVARCHAR(1)
         , @c_flag9                       NVARCHAR(1)
         , @c_ListName_WebService         NVARCHAR(10)           
         , @c_ListName_ROBOTFAC           NVARCHAR(10)
         , @c_ListName_ROBOTSTR           NVARCHAR(10)
         , @c_SConfKey_RBSTDDATA          NVARCHAR(30)

         --, @c_TransmitLogKey              NVARCHAR(10)

         , @c_IniFilePath                 VARCHAR(225) 
         , @c_WebRequestMethod            VARCHAR(10)
         , @c_ContentType                 VARCHAR(100)
         , @c_WebRequestEncoding          VARCHAR(30)
         , @c_WS_url                      NVARCHAR(250)

         , @c_SC_RBSTDDATA_Value          NVARCHAR(5)

         , @c_owner_code                  NVARCHAR(16)
         , @n_sku_status                  INT
         , @n_is_sequence_sku             INT

         , @c_transaction_id              NVARCHAR(10)
         , @c_FullRequestString           NVARCHAR(MAX)
         , @c_JSON_HEADER                 NVARCHAR(2000)
         , @c_JSON_BODY                   NVARCHAR(MAX)
         , @c_JSON_OrderList              NVARCHAR(MAX)
         , @c_JSON_SKUList                NVARCHAR(MAX)

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

   DECLARE @c_WareHouseCode               NVARCHAR(16)
         , @c_user_id                     NVARCHAR(16)
         , @c_user_key                    NVARCHAR(16)
         , @c_CdlkCode2                   NVARCHAR(5)
         , @c_TLKey1                      NVARCHAR(30)
         , @c_TLKey2                      NVARCHAR(30)
         , @c_TLKey3                      NVARCHAR(30)
         , @c_Out_Order_Code              NVARCHAR(16)
         , @c_CdlkOwnerCode               NVARCHAR(16)
         , @c_OrderAmount                 NVARCHAR(5)
         , @c_CdlkFacility                NVARCHAR(10)  
         , @c_docType                     NVARCHAR(5)
         , @c_ORD_OrderKey                NVARCHAR(10) 
         , @c_ORD_docType                 NVARCHAR(10) 
         , @c_ORD_consigneekey            NVARCHAR(15)
         , @c_IsWaiting                   NVARCHAR(2)
         , @c_Printtype                   NVARCHAR(2)
         , @c_Carrier_type                NVARCHAR(2)
         , @c_Creation_date               NVARCHAR(15)
         , @c_PICKDET_SkuCode             NVARCHAR(64)
         , @n_PICKDET_Amount              INT
         , @n_SKU_Count                   INT
         , @n_ORD_Count                   INT
         , @n_Exists                      INT
         , @c_TableName                   NVARCHAR(30)
         , @c_StorerKey                   NVARCHAR(15)
         , @c_DTSITF_DBName               NVARCHAR(50)
         , @c_PickSlipNo                  NVARCHAR(10) 
         , @c_LoadKey                     NVARCHAR(10)
         , @n_CountCdlk                   INT
         , @c_MsgValue                    NVARCHAR(250)     --KCY02
         , @n_IsAllowLack                 INT               --(Alex01)

   SET @n_Continue                        = 1
   SET @n_StartCnt                        = @@TRANCOUNT
   SET @c_MsgValue                        = ''              --KCY02
   SET @c_VBErrMsg                        = ''

   SET @b_Success                         = 0
   SET @n_Err                             = 0
   SET @c_ErrMsg                          = ''
   --SET @c_InTransmitLogKey                = ISNULL(RTRIM(@c_InTransmitLogKey), '')

   SET @c_Application                     = 'GEEK+_ORDER_OUT'
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

   SET @c_SC_RBSTDDATA_Value              = ''
   SET @c_owner_code                      = ''
   SET @n_sku_status                      = 1
   SET @n_is_sequence_sku                 = 0

   SET @c_transaction_id                  = ''
   SET @c_FullRequestString               = ''
   SET @c_ResponseString                  = ''
   SET @c_JSON_HEADER                     = ''
   SET @c_JSON_BODY                       = ''
   SET @c_JSON_OrderList                  = ''
   SET @c_JSON_SKUList                    = ''

   SET @c_ListName_GeekAlert              = 'GEEK+ALERT'
   SET @b_SendAlert                       = 0
   SET @n_EmailGroupId                    = 0
   SET @c_EmailTitle                      = ''

   SET @c_WareHouseCode                   = ''
   SET @c_user_id                         = ''
   SET @c_user_key                        = ''
   SET @c_CdlkCode2                       = 'ORD'
   SET @c_TLKey1                          = '' 
   SET @c_TLKey2                          = '' 
   SET @c_TLKey3                          = '' 
   SET @c_Out_Order_Code                  = ''
   SET @c_CdlkOwnerCode                   = ''
   SET @c_OrderAmount                     = ''
   SET @c_CdlkFacility                    = ''
   SET @c_docType                         = ''
   SET @c_ORD_OrderKey                    = ''
   SET @c_ORD_docType                     = ''
   SET @c_ORD_consigneekey                = ''
   SET @c_IsWaiting                       = '1'
   SET @c_Printtype                       = '2'
   SET @c_Carrier_type                    = '1'
   SET @c_Creation_date                   =  CONVERT(NVARCHAR, CONVERT(BIGINT ,DATEDIFF(SECOND ,'1970-01-01 00:00:00.000', GETUTCDATE())) * 1000) --CONVERT(NVARCHAR(20), GETUTCDATE(), 120)
   SET @c_PICKDET_SkuCode                 = ''
   SET @n_PICKDET_Amount                  = 0
   SET @n_SKU_Count                       = 0
   SET @n_ORD_Count                       = 0
   SET @c_TableName                       = ''
   SET @c_StorerKey                       = ''
   SET @c_DTSITF_DBName                   = 'CNDTSITF'
   SET @c_PickSlipNo                      = ''
   SET @c_LoadKey                         = ''
   SET @n_CountCdlk                       = 0

   SET @n_IsAllowLack                     = 1      --(Alex01)

   IF @b_Debug = 1
   BEGIN
      PRINT '>>>>>>>> isp_WSITF_GeekPlusRBT_ORDERCANCEL_Outbound - INITAL BEGIN'
      PRINT '@c_TransmitlogKey: ' + @c_TransmitlogKey
      PRINT '>>>>>>>> isp_WSITF_GeekPlusRBT_ORDERCANCEL_Outbound - INITAL END'
   END 

   SET @n_Exists = 0
   SELECT @n_Exists = (1)
         ,@c_TableName = ISNULL(RTRIM(TableName), '')
         ,@c_TLKey1 = ISNULL(RTRIM(Key1), '')
         ,@c_TLKey2 = ISNULL(RTRIM(Key2), '')
         ,@c_StorerKey = ISNULL(RTRIM(Key3), '')
   FROM dbo.TRANSMITLOG3 WITH (NOLOCK)
   WHERE transmitlogkey = @c_TransmitlogKey 
   AND transmitflag = @c_flag0

   IF @n_Exists = 0
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 230300
      SET @c_ErrMsg = 'No records found in TRANSMITLOG3 table..'
      GOTO QUIT
   END

   IF @c_TableName <> 'RBTLOADRCM'
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 230301
      SET @c_ErrMsg = 'Invalid TransmitLog3 TableName..'
      GOTO QUIT
   END

   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      IF @b_Debug = 1
      BEGIN
         PRINT '>>>>>>>> isp_WSITF_GeekPlusRBT_Order_Outbound - BEGIN'
         PRINT '@c_StorerKey: ' + @c_StorerKey + ", @c_TransmitLogKey: " + @c_TransmitLogKey
      END 
      

      --GET OwnerCode
      SELECT @c_CdlkOwnerCode = ISNULL(RTRIM(short),'')
      FROM CODELKUP WITH (NOLOCK) 
      WHERE ListName ='ROBOTSTR' and Storerkey = @c_StorerKey

      --Built string(Start)
      IF OBJECT_ID('tempdb..#TEMP_Geek_ORD_List') IS NOT NULL
               DROP TABLE #TEMP_Geek_ORD_List

               CREATE TABLE #TEMP_Geek_ORD_List(
                  TransactionId  NVARCHAR(32)
                  , OrderKey     NVARCHAR(32)
                  , doctype      NVARCHAR(5)
                  , ConsigneeKey NVARCHAR(32)
                  , Code         NVARCHAR(50)
                  , Long         NVARCHAR(4000)
                  , UDF01        NVARCHAR(50)
                  , UDF02        NVARCHAR(50)
               )

      IF @c_TLKey2 = 'LOAD'
      BEGIN
            --check LoadPlanDetail, make sure location = robot ( <> robot ) --KCY02 START
            IF NOT EXISTS (SELECT 1 from dbo.Orders WITH (NOLOCK) WHERE Orderkey = @c_TLKey1) 
            BEGIN

               --Insert LOG
               SET @c_MessageType = 'WS_OUT, ERROR'
               SET @c_FullRequestString = 'Orders Record Not found!, LoadKey: ' + @c_TLKey1

               INSERT INTO dbo.TCPSocket_OUTLog ( [Application], RemoteEndPoint, MessageType, ErrMsg, [Data], MessageNum, StorerKey, ACKData, [Status] )
               VALUES ( @c_Application, @c_WS_url, @c_MessageType, @c_VBErrMsg, @c_FullRequestString, @c_TransmitlogKey, @c_StorerKey, @c_ResponseString, '9' )
               
            END
            --END KCY02 START

            --check PICKDETAIL --KCY02 START
            IF NOT EXISTS (SELECT 1 from dbo.PICKDETAIL WITH (NOLOCK) WHERE Orderkey IN 
                            (SELECT OrderKey FROM  dbo.Orders WITH (NOLOCK) WHERE LoadKey = @c_TLKey1) and Loc IN 
                             (SELECT Loc FROM dbo.LOC WITH (NOLOCK) where LocationCategory = 'ROBOT')
                           )
            BEGIN
               
               --Insert LOG
               SET @c_MessageType = 'WS_OUT, ERROR'
               SET @c_FullRequestString = 'PackTask Record Not found! PickDetail.Loc: ' + @c_MsgValue + ', LoadKey: ' + @c_TLKey1

               INSERT INTO dbo.TCPSocket_OUTLog ( [Application], RemoteEndPoint, MessageType, ErrMsg, [Data], MessageNum, StorerKey, ACKData, [Status] )
               VALUES ( @c_Application, @c_WS_url, @c_MessageType, @c_VBErrMsg, @c_FullRequestString, @c_TransmitlogKey, @c_StorerKey, @c_ResponseString, '9' )
               
            END --END KCY02 END

            --ORDER LIST
            DECLARE GEEKPLUS_ORDOUT_LOOPORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            --SELECT DISTINCT LoadKey, doctype, consigneekey,Facility
            --FROM dbo.Orders WITH (NOLOCK)
            --WHERE Loadkey = @c_TLKey1
            SELECT DISTINCT od.LoadKey, od.doctype, od.consigneekey,od.Facility
            FROM dbo.Orders od WITH (NOLOCK) 
			   INNER JOIN PICKDETAIL PK WITH (NOLOCK) ON PK.OrderKey = od.OrderKey
			   INNER JOIN dbo.LOC L WITH (NOLOCK) ON L.Loc = PK.Loc
            WHERE od.Loadkey = @c_TLKey1 AND L.LocationCategory='ROBOT' 

            OPEN GEEKPLUS_ORDOUT_LOOPORD
            FETCH NEXT FROM GEEKPLUS_ORDOUT_LOOPORD INTO @c_LoadKey, @c_ORD_docType, @c_ORD_consigneekey,@c_CdlkFacility
            WHILE @@FETCH_STATUS <> -1                                 
            BEGIN          
                  SET @n_ORD_Count = @n_ORD_Count + 1
                  --GET TransID
                  EXEC [dbo].[nspg_GetKey]     
                  'geek_Load_transid'   
                  , 10 
                  , @c_transaction_id     OUTPUT    
                  , @b_Success            OUTPUT    
                  , @n_Err                OUTPUT    
                  , @c_ErrMsg             OUTPUT

                  --GET Header(Start)
                  SELECT @n_CountCdlk = COUNT(Code)
                        ,@c_WareHouseCode = Code
                        ,@c_WS_url = Long
                        ,@c_user_id = UDF01
                        ,@c_user_key = UDF02
                        ,@c_IniFilePath = Notes
                  FROM dbo.CODELKUP (NOLOCK)
                  WHERE ListName = @c_ListName_WebService
                  AND Code2 ='ORD'
                  AND StorerKey = @c_StorerKey
                  AND Code = (SELECT Short FROM CODELKUP (NOLOCK) WHERE LISTNAME = 'ROBOTFAC' AND Storerkey = @c_StorerKey AND Code = @c_CdlkFacility) --Alex03
                  GROUP BY Code, Long, UDF01, UDF02, Notes
                  --GET Header(END)

                  IF @n_CountCdlk > 2
                  BEGIN
                     SET @c_flag = @c_flag5
                     SET  @b_SendAlert = 1 
                     SET @c_ErrMsg = 'Codelkup is more than 2: ' + @n_CountCdlk + ', Facility: ' + @c_CdlkFacility
                     GOTO UPD_TL_AFTER_PROCESS
                  END

                  INSERT INTO #TEMP_Geek_ORD_List (TransactionId , OrderKey, doctype, ConsigneeKey, Code, Long, UDF01, UDF02) 
                  VALUES (@c_transaction_id,@c_LoadKey,@c_ORD_docType, @c_ORD_consigneekey, @c_WareHouseCode, @c_WS_url, @c_user_id, @c_user_key)

               FETCH NEXT FROM GEEKPLUS_ORDOUT_LOOPORD INTO @c_LoadKey, @c_ORD_docType, @c_ORD_consigneekey,@c_CdlkFacility
            END
            CLOSE GEEKPLUS_ORDOUT_LOOPORD
            DEALLOCATE GEEKPLUS_ORDOUT_LOOPORD

            --Built Json(START)
            SET @c_FullRequestString = (ISNULL(RTRIM((
            SELECT 
               @c_WareHouseCode As 'header.warehouse_code'
               , @c_user_id As 'header.user_id'
               , @c_user_key As 'header.user_key'
               , @n_ORD_Count As 'body.order_amount'
               , ( 
               SELECT  
                  --order layer
                  ORD.TransactionId    As 'transaction_id'
                  , ORD.OrderKey     AS 'out_order_code'
                  , CASE WHEN ORD.doctype = 'E' THEN 0
                           WHEN ORD.doctype = 'N' THEN 
                           CASE WHEN EXISTS(SELECT 1 from dbo.CODELKUP C WITH (NOLOCK) WHERE C.ListName = 'VIPLIST' and C.CODE = ORD.ConsigneeKey)
                           THEN 20 ELSE 8 END
                     END AS 'order_type'
                  , @c_CdlkOwnerCode    AS 'owner_code'
                  , @c_IsWaiting        AS 'is_waiting'
                  , @n_IsAllowLack      AS 'is_allow_lack'  --(Alex01)
                  , @c_Creation_date    AS 'creation_date'
                  --, CASE WHEN ORD.doctype = '20' THEN '2' ELSE '0' END  AS 'priority'
                  ,CASE WHEN ORD.doctype = 'E' THEN 0
                           WHEN ORD.doctype = 'N' THEN 
                           CASE WHEN EXISTS(SELECT 1 from dbo.CODELKUP C WITH (NOLOCK) WHERE C.ListName = 'VIPLIST' and C.CODE = ORD.ConsigneeKey)
                           THEN 2 ELSE 0 END
                     END AS 'priority' --KCY01
                  --, CASE WHEN @c_TLKey2 IN ('LOAD','BATCH') THEN '1' WHEN @c_TLKey2 = 'ORDER' THEN '2' ELSE '' END AS 'designated_container_type' 
                  , '3' As 'designated_container_type' --(Alex02)
                  ,  @c_TLKey2 AS 'reservation1'
                  , (
               
                     SELECT 
                        ISNULL(RTRIM(PD.SKU), '') as 'sku_code'
                        , SUM(PD.Qty) As'amount'
                        , 0 AS 'sku_level'
                     FROM PickDetail PD WITH (NOLOCK) INNER JOIN loc L WITH (NOLOCK) ON L.LOC = PD.LOC
                     WHERE PD.Orderkey IN (SELECT OrderKey 
                                          From LoadPlanDetail WITH (NOLOCK) 
                                       WHERE loadkey= @c_TLKey1)
                                       AND L.LocationCategory = 'ROBOT'
                     GROUP BY SKU
                     FOR JSON PATH
                  ) as 'sku_list'
         
               FROM #TEMP_Geek_ORD_List ORD 
               FOR JSON PATH     
               ) as 'body.order_list'
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            )),'')) 
            --Built Json(END)
      END
      ELSE IF @c_TLKey2 = 'BATCH'
      BEGIN
            --check pickdetail location, make sure location = robot ( <> robot ) --KCY02 START
            IF NOT EXISTS (SELECT 1 from dbo.PICKDETAIL WITH (NOLOCK) WHERE Orderkey IN 
                           (SELECT OrderKey FROM  dbo.LoadPlanDetail WITH (NOLOCK) WHERE LoadKey = @c_TLKey1) and Loc IN 
                            (SELECT Loc FROM dbo.LOC WITH (NOLOCK) where LocationCategory = 'ROBOT')
                           )
            BEGIN

               select @c_MsgValue = Loc from dbo.PICKDETAIL WITH (NOLOCK) WHERE Orderkey IN 
               (SELECT OrderKey FROM  dbo.LoadPlanDetail WITH (NOLOCK) WHERE LoadKey = @c_TLKey1)

               SET @c_MessageType = 'WS_OUT, ERROR'
               SET @c_FullRequestString = 'PICKDETAIL Record Not found! PickDetail.Loc is ' + @c_MsgValue + ', LoadKey: ' + @c_TLKey1

               --Insert Log
               INSERT INTO dbo.TCPSocket_OUTLog ( [Application], RemoteEndPoint, MessageType, ErrMsg, [Data], MessageNum, StorerKey, ACKData, [Status] )
               VALUES ( @c_Application, @c_WS_url, @c_MessageType, @c_VBErrMsg, @c_FullRequestString, @c_TransmitlogKey, @c_StorerKey, @c_ResponseString, '9' )
               
            END
            --END KCY02 START

            --check packtask --KCY02 START
            IF NOT EXISTS (SELECT 1 from dbo.PackTask WITH (NOLOCK) WHERE TaskBatchNo IN 
                           (SELECT PickSlipNo FROM  dbo.PICKDETAIL WITH (NOLOCK) WHERE OrderKey IN 
                            (SELECT OrderKey FROM  dbo.LoadPlanDetail WITH (NOLOCK) WHERE  LoadKey = @c_TLKey1) and Loc IN 
                             (SELECT Loc FROM dbo.LOC WITH (NOLOCK) where LocationCategory = 'ROBOT'))
                           )
            BEGIN
               
               --Insert LOG
               SET @c_MessageType = 'WS_OUT, ERROR'
               SET @c_FullRequestString = 'PackTask Record Not found! LoadKey: ' + @c_TLKey1

               INSERT INTO dbo.TCPSocket_OUTLog ( [Application], RemoteEndPoint, MessageType, ErrMsg, [Data], MessageNum, StorerKey, ACKData, [Status] )
               VALUES ( @c_Application, @c_WS_url, @c_MessageType, @c_VBErrMsg, @c_FullRequestString, @c_TransmitlogKey, @c_StorerKey, @c_ResponseString, '9' )
               
            END --END KCY02 END

            --ORDER LIST
            DECLARE GEEKPLUS_ORDOUT_LOOPORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT DISTINCT PK.PickSlipNo, OD.DocType, OD.consigneekey,OD.Facility
            FROM   dbo.PICKDETAIL PK WITH (NOLOCK)
            INNER JOIN dbo.LOC L WITH (NOLOCK) ON L.Loc = PK.Loc
            INNER JOIN dbo.PackTask PT WITH (NOLOCK) ON PT.TaskBatchNo = PK.PickSlipNo
            INNER JOIN dbo.Orders OD WITH (NOLOCK) ON OD.Orderkey = PT.Orderkey
            WHERE  PK.OrderKey IN (SELECT LPD.OrderKey FROM  dbo.LoadPlanDetail LPD WITH (NOLOCK) WHERE  LPD.LoadKey = @c_TLKey1 )
            AND L.LocationCategory = 'ROBOT'

            OPEN GEEKPLUS_ORDOUT_LOOPORD
            FETCH NEXT FROM GEEKPLUS_ORDOUT_LOOPORD INTO @c_PickSlipNo, @c_ORD_docType, @c_ORD_consigneekey,@c_CdlkFacility
            WHILE @@FETCH_STATUS <> -1                                 
            BEGIN          
                  SET @n_ORD_Count = @n_ORD_Count + 1
                  --GET TransID
                  EXEC [dbo].[nspg_GetKey]     
                  'geek_batchno_transid'   
                  , 10 
                  , @c_transaction_id     OUTPUT    
                  , @b_Success            OUTPUT    
                  , @n_Err                OUTPUT    
                  , @c_ErrMsg             OUTPUT

                  --GET Header(Start)
                  SELECT @n_CountCdlk = COUNT(Code)
                        ,@c_WareHouseCode = Code
                        ,@c_WS_url = Long
                        ,@c_user_id = UDF01
                        ,@c_user_key = UDF02
                        ,@c_IniFilePath = Notes
                  FROM dbo.CODELKUP (NOLOCK)
                  WHERE ListName = @c_ListName_WebService
                  AND Code2 ='ORD'
                  AND StorerKey = @c_StorerKey
                  AND Code = (SELECT Short FROM CODELKUP (NOLOCK) WHERE LISTNAME = 'ROBOTFAC' AND Storerkey = @c_StorerKey AND Code = @c_CdlkFacility) --Alex03
                  GROUP BY Code, Long, UDF01, UDF02, Notes
                  --GET Header(END)

                  IF @n_CountCdlk > 2
                  BEGIN
                     SET @c_flag = @c_flag5
                     SET  @b_SendAlert = 1 
                     SET @c_ErrMsg = 'Codelkup is more than 2: ' + @n_CountCdlk + ', Facility: ' + @c_CdlkFacility
                     GOTO UPD_TL_AFTER_PROCESS
                  END

                  INSERT INTO #TEMP_Geek_ORD_List (TransactionId , OrderKey, doctype, ConsigneeKey, Code, Long, UDF01, UDF02) 
                  VALUES (@c_transaction_id,@c_PickSlipNo,@c_ORD_docType, @c_ORD_consigneekey, @c_WareHouseCode, @c_WS_url, @c_user_id, @c_user_key)

               FETCH NEXT FROM GEEKPLUS_ORDOUT_LOOPORD INTO @c_PickSlipNo, @c_ORD_docType, @c_ORD_consigneekey,@c_CdlkFacility
            END
            CLOSE GEEKPLUS_ORDOUT_LOOPORD
            DEALLOCATE GEEKPLUS_ORDOUT_LOOPORD

            SET @c_FullRequestString = (ISNULL(RTRIM((
            SELECT 
               @c_WareHouseCode As 'header.warehouse_code'
               , @c_user_id As 'header.user_id'
               , @c_user_key As 'header.user_key'
               , @n_ORD_Count As 'body.order_amount'
               , ( 
               SELECT  
                  --order layer
                  ORD.TransactionId    As 'transaction_id'
                  , ORD.OrderKey     AS 'out_order_code'
                  , CASE WHEN ORD.doctype = 'E' THEN 0
                           WHEN ORD.doctype = 'N' THEN 
                           CASE WHEN EXISTS(SELECT 1 from dbo.CODELKUP C WITH (NOLOCK) WHERE C.ListName = 'VIPLIST' and C.CODE = ORD.ConsigneeKey)
                           THEN 20 ELSE 8 END
                     END AS 'order_type'
                  , @c_CdlkOwnerCode    AS 'owner_code'
                  , @c_IsWaiting        AS 'is_waiting'
                  , @c_Creation_date    AS 'creation_date'
                  , @n_IsAllowLack      AS 'is_allow_lack'  --(Alex01)
                  --, CASE WHEN ORD.doctype = '20' THEN '2' ELSE '0' END  AS 'priority'
                  , CASE WHEN ORD.doctype = 'E' THEN 0
                           WHEN ORD.doctype = 'N' THEN 
                           CASE WHEN EXISTS(SELECT 1 from dbo.CODELKUP C WITH (NOLOCK) WHERE C.ListName = 'VIPLIST' and C.CODE = ORD.ConsigneeKey)
                           THEN 2 ELSE 0 END
                     END AS 'priority' --KCY01
                  --, CASE WHEN @c_TLKey2 IN ('LOAD','BATCH') THEN '1' WHEN @c_TLKey2 = 'ORDER' THEN '2' ELSE '' END AS 'designated_container_type'
                  , '1' As 'designated_container_type' --(Alex02)
                  ,  @c_TLKey2 AS 'reservation1'
                  , (
               
                     SELECT 
                        ISNULL(RTRIM(PD.SKU), '') as 'sku_code'
                        , SUM(PD.Qty) As'amount'
                        , 0 AS 'sku_level'
                     FROM PickDetail PD WITH (NOLOCK) INNER JOIN loc L WITH (NOLOCK) ON L.LOC = PD.LOC 
                     WHERE PD.Orderkey IN (SELECT OrderKey 
                                          From PackTask WITH (NOLOCK) 
                                       --WHERE TaskBatchNo= @c_PickSlipNo)
                                       WHERE TaskBatchNo= ORD.OrderKey) --KCY02
                                       AND L.LocationCategory = 'ROBOT'
                     GROUP BY SKU
                     FOR JSON PATH
                  ) as 'sku_list'
         
               FROM #TEMP_Geek_ORD_List ORD 
               FOR JSON PATH     
               ) as 'body.order_list'
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            )),'')) 
      END
      ELSE IF @c_TLKey2 = 'ORDER'
      BEGIN
            --check LoadPlanDetail, make sure location = robot ( <> robot ) --KCY02 START
            IF NOT EXISTS (SELECT 1 from dbo.LoadPlanDetail WITH (NOLOCK) WHERE Orderkey IN 
                           (SELECT OrderKey FROM  dbo.Orders WITH (NOLOCK) WHERE LoadKey = @c_TLKey1) 
                           )
            BEGIN

               --Insert LOG
               SET @c_MessageType = 'WS_OUT, ERROR'
               SET @c_FullRequestString = 'LoadPlanDetail Record Not found!, LoadKey: ' + @c_TLKey1

               INSERT INTO dbo.TCPSocket_OUTLog ( [Application], RemoteEndPoint, MessageType, ErrMsg, [Data], MessageNum, StorerKey, ACKData, [Status] )
               VALUES ( @c_Application, @c_WS_url, @c_MessageType, @c_VBErrMsg, @c_FullRequestString, @c_TransmitlogKey, @c_StorerKey, @c_ResponseString, '9' )
               
            END
            --END KCY02 START

            --check PICKDETAIL --KCY02 START
            IF NOT EXISTS (SELECT 1 from dbo.PICKDETAIL WITH (NOLOCK) WHERE Orderkey IN 
                            (SELECT OrderKey FROM  dbo.Orders WITH (NOLOCK) WHERE LoadKey = @c_TLKey1) and Loc IN 
                             (SELECT Loc FROM dbo.LOC WITH (NOLOCK) where LocationCategory = 'ROBOT')
                           )
            BEGIN
               
               --Insert LOG
               SET @c_MessageType = 'WS_OUT, ERROR'
               SET @c_FullRequestString = 'PackTask Record Not found! PickDetail.Loc: ' + @c_MsgValue + ', LoadKey: ' + @c_TLKey1

               INSERT INTO dbo.TCPSocket_OUTLog ( [Application], RemoteEndPoint, MessageType, ErrMsg, [Data], MessageNum, StorerKey, ACKData, [Status] )
               VALUES ( @c_Application, @c_WS_url, @c_MessageType, @c_VBErrMsg, @c_FullRequestString, @c_TransmitlogKey, @c_StorerKey, @c_ResponseString, '9' )
               
            END --END KCY02 END

            --ORDER LIST
            DECLARE GEEKPLUS_ORDOUT_LOOPORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            --SELECT LPD.OrderKey, OD.doctype, OD.consigneekey,OD.Facility
            --FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)
            --INNER JOIN Orders OD WITH (NOLOCK) ON OD.Orderkey = LPD.Orderkey
            --WHERE LPD.LoadKey = @c_TLKey1
            SELECT DISTINCT LPD.OrderKey, OD.doctype, OD.consigneekey,OD.Facility
            FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)
            INNER JOIN Orders OD WITH (NOLOCK) ON OD.Orderkey = LPD.Orderkey
            INNER JOIN PICKDETAIL PK WITH (NOLOCK) ON PK.OrderKey = od.OrderKey
			   INNER JOIN dbo.LOC L WITH (NOLOCK) ON L.Loc = PK.Loc
            WHERE od.Loadkey = @c_TLKey1 AND L.LocationCategory='ROBOT' 


            OPEN GEEKPLUS_ORDOUT_LOOPORD
            FETCH NEXT FROM GEEKPLUS_ORDOUT_LOOPORD INTO @c_ORD_OrderKey, @c_ORD_docType, @c_ORD_consigneekey,@c_CdlkFacility
            WHILE @@FETCH_STATUS <> -1                                 
            BEGIN   
                  SET @n_ORD_Count = @n_ORD_Count + 1
                  --GET TransID
                  EXEC [dbo].[nspg_GetKey]     
                  'geek_ord_transid'   
                  , 10 
                  , @c_transaction_id     OUTPUT    
                  , @b_Success            OUTPUT    
                  , @n_Err                OUTPUT    
                  , @c_ErrMsg             OUTPUT

                  --GET Header(Start)
                  SELECT @n_CountCdlk = COUNT(Code)
                        ,@c_WareHouseCode = Code
                        ,@c_WS_url = Long
                        ,@c_user_id = UDF01
                        ,@c_user_key = UDF02
                        ,@c_IniFilePath = Notes
                  FROM dbo.CODELKUP (NOLOCK)
                  WHERE ListName = @c_ListName_WebService
                  AND Code2 ='ORD'
                  AND StorerKey = @c_StorerKey
                  AND Code = (SELECT Short FROM CODELKUP (NOLOCK) WHERE LISTNAME = 'ROBOTFAC' AND Storerkey = @c_StorerKey AND Code = @c_CdlkFacility) --Alex03
                  GROUP BY Code, Long, UDF01, UDF02, Notes
                  --GET Header(END)

                  IF @n_CountCdlk > 2
                  BEGIN
                     SET @c_flag = @c_flag5
                     SET  @b_SendAlert = 1 
                     SET @c_ErrMsg = 'Codelkup is more than 2: ' + @n_CountCdlk + ', Facility: ' + @c_CdlkFacility
                     GOTO UPD_TL_AFTER_PROCESS
                  END

                  INSERT INTO #TEMP_Geek_ORD_List (TransactionId , OrderKey, doctype, ConsigneeKey, Code, Long, UDF01, UDF02) 
                  VALUES (@c_transaction_id,@c_ORD_OrderKey,@c_ORD_docType, @c_ORD_consigneekey, @c_WareHouseCode, @c_WS_url, @c_user_id, @c_user_key)

               FETCH NEXT FROM GEEKPLUS_ORDOUT_LOOPORD INTO @c_ORD_OrderKey, @c_ORD_docType, @c_ORD_consigneekey,@c_CdlkFacility
            END
            CLOSE GEEKPLUS_ORDOUT_LOOPORD
            DEALLOCATE GEEKPLUS_ORDOUT_LOOPORD

            SET @c_FullRequestString = (ISNULL(RTRIM((
            SELECT 
               @c_WareHouseCode As 'header.warehouse_code'
               , @c_user_id As 'header.user_id'
               , @c_user_key As 'header.user_key'
               , @n_ORD_Count As 'body.order_amount'
               , ( 
               SELECT  
                  --order layer
                  ORD.TransactionId    As 'transaction_id'
                  , ORD.OrderKey     AS 'out_order_code'
                  , CASE WHEN ORD.doctype = 'E' THEN 0
                           WHEN ORD.doctype = 'N' THEN 
                           CASE WHEN EXISTS(SELECT 1 from dbo.CODELKUP C WITH (NOLOCK) WHERE C.ListName = 'VIPLIST' and C.CODE = ORD.ConsigneeKey)
                           THEN 20 ELSE 8 END
                     END AS 'order_type'
                  , @c_CdlkOwnerCode    AS 'owner_code'
                  , @c_IsWaiting        AS 'is_waiting'
                  , @c_Creation_date    AS 'creation_date'
                  , @n_IsAllowLack      AS 'is_allow_lack'  --(Alex01)
                  --, CASE WHEN ORD.doctype = '20' THEN '2' ELSE '0' END  AS 'priority'
                  , CASE WHEN ORD.doctype = 'E' THEN 0
                           WHEN ORD.doctype = 'N' THEN 
                           CASE WHEN EXISTS(SELECT 1 from dbo.CODELKUP C WITH (NOLOCK) WHERE C.ListName = 'VIPLIST' and C.CODE = ORD.ConsigneeKey)
                           THEN 2 ELSE 0 END
                     END AS 'priority' --KCY01
                  --, CASE WHEN @c_TLKey2 IN ('LOAD','BATCH') THEN '1' WHEN @c_TLKey2 = 'ORDER' THEN '2' ELSE '' END AS 'designated_container_type'
                  , '2' As 'designated_container_type' --(Alex02)
                  ,  @c_TLKey2 AS 'reservation1'
                  , (
               
                     SELECT 
                        ISNULL(RTRIM(PD.SKU), '') as 'sku_code'
                        , SUM(PD.Qty) As'amount'
                        , 0 AS 'sku_level'
                     FROM PickDetail PD WITH (NOLOCK) INNER JOIN loc L WITH (NOLOCK) ON L.LOC = PD.LOC
                     WHERE Orderkey = ORD.OrderKey
                     AND L.LocationCategory = 'ROBOT'
                     GROUP BY SKU
                     FOR JSON PATH
                  ) as 'sku_list'
         
               FROM #TEMP_Geek_ORD_List ORD 
               FOR JSON PATH     
               ) as 'body.order_list'
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            )),'')) 
      END
      --Built string(END)

         --Send Web Service Request
         -- DECLARE GEEKPLUS_ORD_OUT_URL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         --SELECT Code, Long, UDF01, UDF02, Notes
         --FROM dbo.CODELKUP (NOLOCK)
         --WHERE ListName = @c_ListName_WebService
         --AND Code2 ='ORD'
         --AND StorerKey = @c_StorerKey
         --AND Code = (SELECT Short FROM CNWMS..CODELKUP (NOLOCK) WHERE LISTNAME = 'ROBOTFAC' AND Storerkey = @c_StorerKey AND Code = @c_Facility)

         --OPEN GEEKPLUS_ORD_OUT_URL
      
         --FETCH NEXT FROM GEEKPLUS_ORD_OUT_URL INTO @c_WareHouseCode, @c_WS_url, @c_user_id, @c_user_key, @c_IniFilePath
         --WHILE @@FETCH_STATUS <> -1
         --BEGIN
         SET @c_ResponseString                  = ''
         SET @c_vbErrMsg                        = ''
         SET @c_Resp_MsgCode                    = ''
         SET @c_Resp_Msg                        = ''
         SET @b_Resp_Success                    = 0
         SET @n_LOGSerialNo                     = 0

         --Invalid URL
         IF ISNULL(RTRIM(@c_WS_url), '') = ''
         BEGIN
            SET @c_flag = 'IGNOR'

            SET @c_MessageType = 'WS_OUT, IGNOR'
            SET @c_FullRequestString = 'WS URL is Empty! Order.faciliy: >>' + @c_CdlkFacility + ' , LoadKey: ' + @c_TLKey1

            INSERT INTO dbo.TCPSocket_OUTLog ( [Application], RemoteEndPoint, MessageType, ErrMsg, [Data], MessageNum, StorerKey, ACKData, [Status] )
            VALUES ( @c_Application, @c_WS_url, @c_MessageType, @c_VBErrMsg, @c_FullRequestString, @c_TransmitlogKey, @c_StorerKey, @c_ResponseString, '9' )
               
            GOTO UPD_TL_AFTER_PROCESS
         END

         --construct JSON .header
         --SET @c_JSON_HEADER = (ISNULL(RTRIM((
         --   SELECT 
         --      @c_WareHouseCode As 'warehouse_code'
         --    , @c_user_id As 'user_id'
         --    , @c_user_key As 'user_key'
         --   FOR JSON PATH, WITHOUT_ARRAY_WRAPPER )
         --),''))
         
         --SET @c_FullRequestString = N'{"header": ' + @c_JSON_HEADER + ', "body": ' + @c_JSON_BODY + '}'
         --SET @c_FullRequestString = @c_JSON_HEADER

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
               @c_IniFilePath
				   , @c_WS_url
				   , @c_WebRequestMethod           --@c_WebRequestMethod
				   , @c_ContentType                --@c_ContentType
				   , @c_WebRequestEncoding         --@c_WebRequestEncoding
				   , @c_FullRequestString          --@c_FullRequestString
				   , @c_ResponseString OUTPUT      
				   , @c_vbErrMsg OUTPUT		      														 
               , 120000                        --@n_WebRequestTimeout -- Miliseconds
				   , ''                            --@c_NetworkCredentialUserName -- leave blank if no network credential
				   , ''                            --@c_NetworkCredentialPassword -- leave blank if no network credential
				   , 0                             --@b_IsSoapRequest  -- 1 = Add SoapAction in HTTPRequestHeader
				   , ''                            --@c_RequestHeaderSoapAction -- HTTPRequestHeader SoapAction value
				   , ''                            --@c_HeaderAuthorization
				   , '0'                           --@c_ProxyByPass, 1 >> Set Ip & Port, 0 >> Set Nothing, '' >> Skip Setup
			END TRY
			BEGIN CATCH
				SET @c_vbErrMsg = CONVERT(NVARCHAR(5),ISNULL(ERROR_NUMBER() ,0)) + ' - ' + ERROR_MESSAGE()

            IF @b_Debug = 1
               PRINT '>>> WS CALL CATCH EXCEPTION - ' + @c_vbErrMsg

			END CATCH

         --INSERT LOG
         INSERT INTO dbo.TCPSocket_OUTLog ( [Application], RemoteEndPoint, MessageType, ErrMsg, [Data], MessageNum, StorerKey, ACKData, [Status] )
         VALUES ( @c_Application, @c_WS_url, @c_MessageType, @c_VBErrMsg, @c_FullRequestString, @c_TransmitlogKey, @c_StorerKey, @c_ResponseString, '9' )

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 100004
            SET @c_ErrMsg = 'failed to get dbo.TCPSocket_OUTLog'
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
            --BREAK
         END

         IF ISNULL(RTRIM(@c_ResponseString), '') = ''
         BEGIN
            SET @b_SendAlert = 1
            SET @c_flag = @c_flag1
            SET @c_ErrMsg = IIF(@n_LOGSerialNo > 0, ('Log Serial No (' + CONVERT(NVARCHAR, @n_LOGSerialNo) + ' - '), '') 
                           + 'Response String returned from GEEK+ server is empty..'
            --BREAK
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
           -- BREAK
         END
         ELSE 
         BEGIN
            SET @c_flag = @c_flag9
         END

      --   FETCH NEXT FROM GEEKPLUS_ORD_OUT_URL INTO @c_WareHouseCode, @c_WS_url, @c_user_id, @c_user_key, @c_IniFilePath
      --END
      --CLOSE GEEKPLUS_ORD_OUT_URL
      --DEALLOCATE GEEKPLUS_ORD_OUT_URL
      
      --update transmitflag to 5 or 9 after ws request sent.
      UPD_TL_AFTER_PROCESS:
      --DECLARE GEEKPLUS_SKUOUT_UPDTL_AFTPROCESS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      --   SELECT transmitlogkey
      --   FROM #TEMP_Geek_SkuList
      --OPEN GEEKPLUS_SKUOUT_UPDTL_AFTPROCESS
      
      --FETCH NEXT FROM GEEKPLUS_SKUOUT_UPDTL_AFTPROCESS INTO @c_TransmitLogKey
      --WHILE @@FETCH_STATUS <> -1
      --BEGIN      
      UPDATE dbo.TRANSMITLOG3 WITH (ROWLOCK)
      SET transmitflag = @c_flag
      WHERE transmitlogkey =  @c_TransmitLogKey
      
      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 100002
         SET @c_ErrMsg = 'failed to update transmitflag of transmitlog3.'
         GOTO QUIT
      END
      --   FETCH NEXT FROM GEEKPLUS_SKUOUT_UPDTL_AFTPROCESS INTO @c_TransmitLogKey
      --END
      --CLOSE GEEKPLUS_SKUOUT_UPDTL_AFTPROCESS
      --DEALLOCATE GEEKPLUS_SKUOUT_UPDTL_AFTPROCESS

      --IF @b_SendAlert <> 1
      --BEGIN
      --   --reprocess if got pending transmitlog3
      --   IF EXISTS( SELECT 1 FROM dbo.TRANSMITLOG3 WITH (NOLOCK)
      --      WHERE tablename IN ('ADDSKULOG', 'UPDSKULOG') 
      --      AND key1 = @c_StorerKey AND transmitflag = @c_flag0 )
      --   BEGIN
      --      IF @b_Debug = 1
      --         PRINT '>>> Found pending transmitlog3....'
         
      --      DELETE FROM #TEMP_Geek_SkuList
      --      GOTO GET_PENDING_TRANSMITLOGS
      --   END
      --END

      --   FETCH NEXT FROM GEEKPLUS_ORDOUT_TL INTO @c_TransmitLogKey, @c_TLKey1, @c_TLKey2, @c_TLKey3
      --END --@@FETCH_STATUS <> -1           
      --CLOSE GEEKPLUS_ORDOUT_TL
      --DEALLOCATE GEEKPLUS_ORDOUT_TL
      --Loop TL (END)

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
      FROM dbo.Codelkup WITH (NOLOCK)
      WHERE ListName = @c_ListName_GeekAlert AND Code = @c_Application
      AND StorerKey = @c_StorerKey

      IF @n_EmailGroupId > 0
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
      PRINT '>>>>>>>> isp_WSITF_GeekPlusRBT_Order_Outbound - END'
   END 

   IF OBJECT_ID('tempdb..#TEMP_Geek_ORD_List') IS NOT NULL
               DROP TABLE #TEMP_Geek_ORD_List

   IF CURSOR_STATUS('LOCAL' , 'GEEKPLUS_ORDOUT_REUPD_TL') in (0 , 1)  
   BEGIN  
      CLOSE GEEKPLUS_ORDOUT_REUPD_TL  
      DEALLOCATE GEEKPLUS_ORDOUT_REUPD_TL  
   END

   IF CURSOR_STATUS('LOCAL' , 'GEEKPLUS_ORD_OUT_URL') in (0 , 1)  
   BEGIN  
      CLOSE GEEKPLUS_ORD_OUT_URL  
      DEALLOCATE GEEKPLUS_ORD_OUT_URL  
   END

   IF CURSOR_STATUS('LOCAL' , 'GEEKPLUS_SKUOUT_UPDTL_AFTPROCESS') in (0 , 1)  
   BEGIN  
      CLOSE GEEKPLUS_SKUOUT_UPDTL_AFTPROCESS  
      DEALLOCATE GEEKPLUS_SKUOUT_UPDTL_AFTPROCESS  
   END
   IF CURSOR_STATUS('LOCAL' , 'GEEKPLUS_ORDOUT_LOOPSKU') in (0 , 1)  
   BEGIN  
      CLOSE GEEKPLUS_ORDOUT_LOOPSKU  
      DEALLOCATE GEEKPLUS_ORDOUT_LOOPSKU  
   END
   IF CURSOR_STATUS('LOCAL' , 'GEEKPLUS_ORDOUT_LOOPORD') in (0 , 1)  
   BEGIN  
      CLOSE GEEKPLUS_ORDOUT_LOOPORD  
      DEALLOCATE GEEKPLUS_ORDOUT_LOOPORD  
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