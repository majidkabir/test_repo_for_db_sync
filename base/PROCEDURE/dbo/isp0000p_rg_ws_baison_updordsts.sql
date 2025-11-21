SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store Procedure:  isp0000P_RG_WS_BAISON_UpdOrdSts                    */
/* Creation Date: 23-Oct-2012                                           */
/* Copyright: IDS                                                       */
/* Written by: KTLow                                                    */
/*                                                                      */
/* Purpose: BAISON WS updateOrderLogisticsStatus Interface              */
/*          - Outbound Process SOS#256707   		                        */
/*          - Get The Updated OrderKey, Stored In WebService_Log To     */
/*            Send Out To HOST                                          */
/*                                                                      */
/* Input Parameters:  @c_OrderKey         - ''                          */
/*                    @c_StorerKey        - ''                          */
/*                    @c_DataStream       - ''                          */
/*                    @b_Debug            - 0                           */
/*                                                                      */
/* Output Parameters: @b_Success          - Success Flag  = 0           */
/*                    @n_Err              - Error Code    = 0           */
/*                    @c_ErrMsg           - Error Message = ''          */
/*                                                                      */
/* Called By:  RDT                                                      */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* 28-Jan-2019  TLTING_ext 1.1  enlarge externorderkey field length     */
/************************************************************************/

CREATE PROC [dbo].[isp0000P_RG_WS_BAISON_UpdOrdSts](
           @c_OrderKey        NVARCHAR(10)
         , @c_StorerKey       NVARCHAR(15)
         , @c_DataStream      NVARCHAR(4)
         , @b_Success         INT            = 0   OUTPUT
         , @n_Err             INT            = 0   OUTPUT
         , @c_ErrMsg          NVARCHAR(250)  = ''  OUTPUT
         , @b_Debug           INT            = 0
)
AS  
BEGIN
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF
   SET ANSI_WARNINGS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   /********************************************/
   /* Variables Declaration (Start)            */
   /********************************************/
	--General
   DECLARE @n_Continue                 INT
         , @n_StartTCnt                INT         
         , @c_ExecStatements           NVARCHAR(4000) 
         , @c_ExecArguments            NVARCHAR(4000)
         , @c_TargetDB                 NVARCHAR(30)  
         , @dt_GetDate                 DATETIME 
         , @c_SOStatus                 NVARCHAR(10)
         , @c_StorerConfig             NVARCHAR(30)
         , @c_StorerConfigSValue       NVARCHAR(10)

   --WebService_Log
   DECLARE @c_RequestString            NVARCHAR(MAX)
         , @c_Type                     NVARCHAR(1)
         , @c_ClientHost               NVARCHAR(1)
         , @c_WSIndicator              NVARCHAR(1)
         , @c_SourceType               NVARCHAR(125)
         , @n_SeqNo                    INT

   --Orders
   DECLARE @c_ExternOrderKey           NVARCHAR(50)   --tlting_ext
         , @c_ShipperKey               NVARCHAR(15)  
         , @c_UserDefine04             NVARCHAR(20)
         , @c_LogisticsStatus          NVARCHAR(64)

   -- Initialisation 
   SELECT @n_StartTCnt = @@TRANCOUNT, @n_Continue = 1, @b_Success = 0, @n_err = 0, @c_ErrMsg = ''
   SET @c_ExecStatements      = ''
   SET @c_ExecArguments       = ''
   SET @c_TargetDB            = 'CNDTSITFSKE'
   SET @dt_GetDate            = GETDATE()
   SET @c_SOStatus            = 'PENDPACK'
   SET @c_StorerConfig        = 'WSPickByTrackNo'
   SET @c_StorerConfigSValue  = '0'

   --Initialisation For WebService_Log
   SET @c_RequestString       = ''
   SET @c_Type                = 'O'
   SET @c_ClientHost          = ''
   SET @c_WSIndicator         = ''
   SET @n_SeqNo               = 0

   --Initialisation For Orders
   SET @c_ExternOrderKey      = ''
   SET @c_ShipperKey          = ''
   SET @c_UserDefine04        = ''
   SET @c_LogisticsStatus     = 'ORDER_FINISHED'
   SET @c_SourceType          = 'getOrderLogisticsStatus_Close'
   /********************************************/
   /* Variables Declaration (End)              */
   /********************************************/
   /********************************************/
   /* General Validation (Start)               */
   /********************************************/
   IF @b_Debug = 1
   BEGIN
      PRINT '[isp0000P_RG_WS_BAISON_UpdOrdSts]: Start...'

      PRINT '[isp0000P_RG_WS_BAISON_UpdOrdSts]: @c_OrderKey=' + @c_OrderKey +
            ', @c_StorerKey=' + @c_StorerKey + ', @c_DataStream=' + @c_DataStream
   END
   /********************************************/
   /* General Validation (End)                 */
   /********************************************/
   /********************************************/
   /* Main Process (Start)                     */
   /********************************************/
   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      EXECUTE nspGetRight
               NULL,                   -- Facility
               @c_StorerKey,           -- Storerkey
               NULL,                   -- Sku
               @c_StorerConfig,        -- Configkey
               @b_Success              OUTPUT,
               @c_StorerConfigSValue   OUTPUT,
               @n_Err                  OUTPUT,
               @c_ErrMsg               OUTPUT

      -- Reset TransmitFlag = "0" if record exists
      IF @c_StorerConfigSValue = '1'
      BEGIN
         SET @c_ExecStatements = 'SELECT @c_ClientHost = ISNULL(RTRIM(ClientHost), ''''), ' +
                                 '@c_WSIndicator = ISNULL(RTRIM(WSIndicator), '''') ' +
                                 'FROM ' + @c_TargetDB + '.dbo.ITFCONFIG_WSDT WITH (NOLOCK) ' +
                                 'WHERE DataStream = @c_DataStream ' +
                                 'AND [Type] = @c_Type ' +
                                 'AND StorerKey = @c_StorerKey'

         SET @c_ExecArguments = '@c_Type           NVARCHAR(1)' +
                                ', @c_StorerKey    NVARCHAR(15)' +
                                ', @c_DataStream   NVARCHAR(4)' +
                                ', @c_ClientHost   NVARCHAR(1) OUTPUT' +
                                ', @c_WSIndicator  NVARCHAR(1) OUTPUT'

         EXEC sp_ExecuteSql @c_ExecStatements 
                          , @c_ExecArguments  
                          , @c_Type  
                          , @c_StorerKey
                          , @c_DataStream
                          , @c_ClientHost    OUTPUT
                          , @c_WSIndicator   OUTPUT

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 80003
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))  
                          + ': Fail To Retrieve ITFConfig_WSDT Info. (isp0000P_RG_WS_BAISON_UpdOrdSts)'
            GOTO QUIT
         END

         IF @c_ClientHost <> '' AND @c_WSIndicator <> ''
         BEGIN
            SET ROWCOUNT 1

            --Get ExternOrderKey, ShipperKey, UserDefine04
            SELECT @c_ExternOrderKey = ISNULL(RTRIM(ExternOrderKey), ''),
                   @c_UserDefine04 = ISNULL(RTRIM(UserDefine04), ''),
                   @c_ShipperKey = ISNULL(RTRIM(ShipperKey), '')
            FROM ORDERS WITH (NOLOCK)
            WHERE OrderKey = @c_OrderKey
                  AND StorerKey = @c_StorerKey

            SET ROWCOUNT 0

            IF @c_ExternOrderKey <> ''
            BEGIN
               --Generate XML format
               SET @c_RequestString = '<root><orderCode>' + @c_ExternOrderKey + '</orderCode>' +
                                      '<logisticsStatus>' + @c_LogisticsStatus + '</logisticsStatus>' +
                                      '<shippingCode>' + @c_ShipperKey + '</shippingCode>' +
                                      '<logisticsCode>' + @c_UserDefine04 + '</logisticsCode></root>'

               --Insert Into WebService_Log
               BEGIN TRAN

               SET @c_ExecStatements = 'INSERT INTO ' + @c_TargetDB + '.dbo.WebService_Log (' +
                                       'DataStream' +
                                       ', StorerKey' +
                                       ', [Type]' +
                                       ', BatchNo' +
                                       ', WebRequestURL' +
                                       ', WebRequestMethod' +
                                       ', ContentType' +
                                       ', RequestString' +
                                       ', TimeIn' +
                                       ', Status' +
                                       ', ClientHost' +
                                       ', WSIndicator' +
                                       ', SourceKey' +
                                       ', SourceType' +
                                       ') VALUES (' +
                                       '@c_DataStream' +
                                       ', @c_StorerKey' +
                                       ', @c_Type' +
                                       ', ''''' +
                                       ', ''''' +
                                       ', ''''' +
                                       ', ''''' +
                                       ', @c_RequestString' +
                                       ', @dt_GetDate' +
                                       ', ''W''' +
                                       ', @c_ClientHost' +
                                       ', @c_WSIndicator' +
                                       ', @c_OrderKey' +
                                       ', @c_SourceType)'

               SET @c_ExecArguments = '@c_DataStream        NVARCHAR(4)' +
                                      ', @c_StorerKey       NVARCHAR(15)' +
                                      ', @c_Type            NVARCHAR(1)' +
                                      ', @c_RequestString   NVARCHAR(MAX)' +
                                      ', @dt_GetDate        DATETIME' +
                                      ', @c_ClientHost      NVARCHAR(1)' +
                                      ', @c_WSIndicator     NVARCHAR(1)' +
                                      ', @c_OrderKey        NVARCHAR(10)' +
                                      ', @c_SourceType      NVARCHAR(125)'

               EXEC sp_ExecuteSql @c_ExecStatements 
                                , @c_ExecArguments  
                                , @c_DataStream  
                                , @c_StorerKey
                                , @c_Type
                                , @c_RequestString
                                , @dt_GetDate
                                , @c_ClientHost
                                , @c_WSIndicator
                                , @c_OrderKey
                                , @c_SourceType

               IF @@ERROR <> 0
               BEGIN
                  ROLLBACK TRAN
                  SET @n_Continue = 3
                  SET @n_Err = 80003
                  SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))  
                                + ': Fail To Insert Record Into WebService_Log. (isp0000P_RG_WS_BAISON_UpdOrdSts)'
                  GOTO QUIT
               END

               --Update Orders.SOStatus
               UPDATE ORDERS WITH (ROWLOCK)
               SET SOStatus = @c_SOStatus,
                   Trafficcop = NULL,
                   EditDate = @dt_GetDate,
                   EditWho = SUSER_NAME()
               WHERE OrderKey = @c_OrderKey
               AND StorerKey = @c_StorerKey
               AND SOStatus = '0'
               AND Status = '5'

               IF @@ERROR <> 0
               BEGIN
                  ROLLBACK TRAN
                  SET @n_Continue = 3
                  SET @n_Err = 80003
                  SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))  
                                + ': Fail To Update ORDERS Record. (isp0000P_RG_WS_BAISON_UpdOrdSts)'
                  GOTO QUIT
               END
               ELSE
               BEGIN
                  WHILE @@TRANCOUNT > 0
			            COMMIT TRAN 
               END

               --Get SeqNo for the last record
               SET @c_ExecStatements = 'SELECT TOP 1 @n_SeqNo = SeqNo FROM ' + @c_TargetDB +
                                       '.dbo.WebService_Log WITH (NOLOCK) ' +
                                       'WHERE SourceKey = @c_OrderKey ' +
                                       'AND SourceType = @c_SourceType ' +
                                       'AND DataStream = @c_DataStream ' +
                                       'AND StorerKey = @c_StorerKey ' +
                                       'AND [Type] = @c_Type ' +
                                       'AND Status = ''W'' ' +
                                       'AND ISNULL(RTRIM(BatchNo), '''') = '''' ' +
                                       'ORDER BY SeqNo DESC'

               SET @c_ExecArguments = '@c_DataStream        NVARCHAR(4)' +
                                      ', @c_StorerKey       NVARCHAR(15)' +
                                      ', @c_Type            NVARCHAR(1)' +
                                      ', @c_OrderKey        NVARCHAR(10)' +
                                      ', @c_SourceType      NVARCHAR(125)' +
                                      ', @n_SeqNo           INT OUTPUT'

               EXEC sp_ExecuteSql @c_ExecStatements 
                                , @c_ExecArguments  
                                , @c_DataStream  
                                , @c_StorerKey
                                , @c_Type
                                , @c_OrderKey
                                , @c_SourceType
                                , @n_SeqNo OUTPUT

               IF @n_SeqNo > 0
               BEGIN
                  BEGIN TRAN

                  SET @c_ExecStatements = 'UPDATE ' +  @c_TargetDB + '.dbo.WebService_Log WITH (ROWLOCK) ' +
                                          'SET Status = ''0'' ' +
                                          'WHERE SeqNo = @n_SeqNo'

                  SET @c_ExecArguments = '@n_SeqNo INT'

                  EXEC sp_ExecuteSql @c_ExecStatements 
                                   , @c_ExecArguments  
                                   , @n_SeqNo

                  IF @@ERROR <> 0
                  BEGIN
                     ROLLBACK TRAN
                     SET @n_Continue = 3
                     SET @n_Err = 80003
                     SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))  
                                   + ': Fail To Update Record Into WebService_Log. (isp0000P_RG_WS_BAISON_UpdOrdSts)'
                     GOTO QUIT
                  END
                  ELSE
                  BEGIN
                     WHILE @@TRANCOUNT > 0
			               COMMIT TRAN 
                  END
               END --IF @n_SeqNo > 0
            END --IF @c_ExternOrderKey <> ''
         END --IF @c_ClientHost <> '' AND @c_WSIndicator <> ''
      END --IF @c_StorerConfigSValue = '1'      
   END --IF @n_Continue = 1 OR @n_Continue = 2
   /********************************************/
   /* Main Process (End)                       */
   /********************************************/
   /********************************************/
   /* Std - Error Handling (Start)             */
   /********************************************/ 
   QUIT:

   WHILE @@TRANCOUNT < @n_StartTCnt
      BEGIN TRAN 

   /* #INCLUDE <SPTPA01_2.SQL> */  
   IF @n_Continue=3  -- Error Occured 
   BEGIN  
      SELECT @b_Success = 0  
      IF @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         ROLLBACK TRAN  
      END  
      ELSE  
      BEGIN  
         WHILE @@TRANCOUNT > @n_StartTCnt  
         BEGIN  
            COMMIT TRAN  
         END  
      END
  
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp0000P_RG_WS_BAISON_UpdOrdSts'  
      -- RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  

      RETURN  
   END  
   ELSE  
   BEGIN  
      SELECT @b_Success = 1  
      WHILE @@TRANCOUNT > @n_StartTCnt  
      BEGIN           
         COMMIT TRAN  
      END  
      RETURN  
   END
   /********************************************/
   /* Std - Error Handling (End)               */
   /********************************************/
END --End Procedure

GO