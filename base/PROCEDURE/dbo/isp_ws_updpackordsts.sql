SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
  
/************************************************************************/  
/* Store Procedure:  isp_WS_UpdPackOrdSts                               */  
/* Creation Date: 26-April-2013                                         */  
/* Copyright: IDS                                                       */  
/* Written by: KTLow                                                    */  
/*                                                                      */  
/* Purpose: Web Service Update Pack Order Status Interface              */  
/*          - XTEP Outbound Process SOS#256707                       */  
/*          - PUMA Outbound Process SOS#274725                       */  
/*          - SCN Outbound Process SOS#280631                       */  
/*          - Get The Updated OrderKey, Stored In WebService_Log or     */  
/*            WSDT Table and Send Out To HOST                           */  
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
/* Version: 1.1                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver.  Purposes                                */  
/*11-Jul-2013   KTLow     1.0   Add StorerConfig - WSInstWSDTTable (KT01)*/  
/*01-Oct-2013   KTLow     1.1   CR SOS#290872 - Add StorerConfig for    */  
/*                              WSUpdOrdSOStsByCondition (KT02)         */  
/************************************************************************/  
  
CREATE PROC [dbo].[isp_WS_UpdPackOrdSts](  
           @c_OrderKey        NVARCHAR(10)  
         , @c_StorerKey       NVARCHAR(15)  
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
         , @dt_GetDate                 DATETIME   
         , @c_SOStatus                 NVARCHAR(10)  
         , @c_StorerConfig             NVARCHAR(30)  
         , @c_StorerConfigSValue       NVARCHAR(10)  
         , @c_StorerConfig1            NVARCHAR(30)  
         , @c_StorerConfigSValue1      NVARCHAR(10)  
         , @c_StorerConfig2            NVARCHAR(30) --(KT01)  
      , @c_StorerConfigSValue2      NVARCHAR(10) --(KT01)  
  
         , @c_StorerConfig3            NVARCHAR(30) --(KT02)  
         , @c_StorerConfigSValue3      NVARCHAR(10) --(KT02)  
  
         , @c_LoadKey                  NVARCHAR(10)    
         , @c_ListName                 NVARCHAR(10)  
         , @c_Type                     NVARCHAR(1)  
         , @c_DataStream               NVARCHAR(4)  
         , @c_TargetDB                 NVARCHAR(30)  
         , @c_SPName                   NVARCHAR(250)   
  
         , @c_UpdOrdSOStatusFilter     NVARCHAR(1000) --(KT02)  
         , @n_Exists                   INT --(KT02)  
  
   --WebService_Log  
   DECLARE @c_SourceType               NVARCHAR(125)  
         , @n_SeqNo                    INT  
  
   -- Initialisation   
   SELECT @n_StartTCnt = @@TRANCOUNT, @n_Continue = 1, @b_Success = 0, @n_err = 0, @c_ErrMsg = ''  
   SET @c_ExecStatements      = ''  
   SET @c_ExecArguments       = ''  
   SET @dt_GetDate            = GETDATE()  
   SET @c_SOStatus            = 'PENDPACK'  
   SET @c_StorerConfig        = 'WSPickByTrackNo'  
   SET @c_StorerConfigSValue  = '0'  
   SET @c_StorerConfig1       = 'WSInstWSLogByPass'  
   SET @c_StorerConfigSValue1 = '0'  
   SET @c_StorerConfig2       = 'WSInstWSDTTable' --(KT01)  
   SET @c_StorerConfigSValue2 = '0'               --(KT01)  
  
   SET @c_StorerConfig3       = 'WSUpdOrdSOStsByCondition' --(KT02)  
   SET @c_StorerConfigSValue3 = '0'               --(KT02)  
  
   SET @c_LoadKey             = ''  
   SET @c_ListName            = 'WebService'  
   SET @c_Type                = ''  
   SET @c_DataStream          = ''  
   SET @c_TargetDB            = ''  
   SET @c_SPName              = 'isp_WS_UpdPackOrdSts'  
  
   SET @c_UpdOrdSOStatusFilter = '' --(KT02)  
   SET @n_Exists              = 0 --(KT02)  
  
   --Initialisation For WebService_Log  
   SET @c_SourceType          = 'getOrderLogisticsStatus_Close'  
   SET @n_SeqNo               = 0  
   /********************************************/  
   /* Variables Declaration (End)              */  
   /********************************************/  
   /********************************************/  
   /* General Validation (Start)               */  
   /********************************************/  
   IF @b_Debug = 1  
   BEGIN  
      PRINT '[isp_WS_UpdPackOrdSts]: Start...'  
  
      PRINT '[isp_WS_UpdPackOrdSts]: @c_OrderKey=' + @c_OrderKey +  
            ', @c_StorerKey=' + @c_StorerKey  
   END  
   /********************************************/  
   /* General Validation (End)                 */  
   /********************************************/  
   /********************************************/  
   /* Main Process (Start)                     */  
   /********************************************/  
   IF @n_Continue = 1 OR @n_Continue = 2  
   BEGIN  
      --Get WSPickByTrackNo access right - Determine Whether Need to Send Out Web Service Interface  
      EXECUTE nspGetRight  
               NULL,                   -- Facility  
               @c_StorerKey,           -- Storerkey  
               NULL,                   -- Sku  
               @c_StorerConfig,        -- Configkey  
               @b_Success              OUTPUT,  
               @c_StorerConfigSValue   OUTPUT,  
               @n_Err                  OUTPUT,  
               @c_ErrMsg               OUTPUT  
  
      IF @b_Debug = 1  
      BEGIN  
         PRINT '[isp_WS_UpdPackOrdSts]: WSPickByTrackNo = ' + @c_StorerConfigSValue  
      END  
  
      IF @c_StorerConfigSValue = '0'  
      BEGIN  
         GOTO QUIT  
      END --IF @c_StorerConfigSValue = '0'  
  
      --Get WSInstWSLogByPass access right - By Pass Insert WebService_Log  
      EXECUTE nspGetRight  
               NULL,                   -- Facility  
               @c_StorerKey,           -- Storerkey  
               NULL,                   -- Sku  
               @c_StorerConfig1,       -- Configkey  
               @b_Success              OUTPUT,  
               @c_StorerConfigSValue1  OUTPUT,  
   @n_Err                  OUTPUT,  
               @c_ErrMsg               OUTPUT  
  
      IF @b_Debug = 1  
      BEGIN  
         PRINT '[isp_WS_UpdPackOrdSts]: WSInstWSLogByPass = ' + @c_StorerConfigSValue1  
      END  
  
      IF ISNULL(RTRIM(@c_StorerConfigSValue1), '0') = '0'  
      BEGIN  
         EXEC isp_WS_InsertWSLog @c_LoadKey  
                               , @c_OrderKey  
                               , @c_StorerKey  
                               , @b_Success OUTPUT  
                               , @n_Err OUTPUT  
                               , @c_ErrMsg OUTPUT  
                               , @c_StorerConfigSValue1  
                               , @b_Debug  
  
         IF @b_Success = 0  
         BEGIN  
            SET @n_Continue = 3  
            SET @n_Err = 80003  
            SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_err,0))    
                          + ': Fail To Insert Record Into WebService_Log. (isp_WS_UpdPackOrdSts)'  
            GOTO QUIT  
         END  
           
         IF @c_ErrMsg <> ''  
         BEGIN  
            SET @n_Continue = 3  
            GOTO QUIT  
         END  
      END --IF ISNULL(RTRIM(@c_StorerConfigSValue1), '0') = '0'  
  
      --Get WSInstWSDTTable access right - To Insert WSDT Table  
      EXECUTE nspGetRight  
               NULL,                   -- Facility  
               @c_StorerKey,           -- Storerkey  
               NULL,                   -- Sku  
               @c_StorerConfig2,       -- Configkey  
               @b_Success              OUTPUT,  
               @c_StorerConfigSValue2  OUTPUT,  
               @n_Err                  OUTPUT,  
               @c_ErrMsg               OUTPUT  
  
      IF @b_Debug = 1  
      BEGIN  
         PRINT '[isp_WS_UpdPackOrdSts]: WSInstWSDTTable = ' + @c_StorerConfigSValue2  
      END  
  
      IF ISNULL(RTRIM(@c_StorerConfigSValue2), '0') = '1'  
      BEGIN  
         EXEC isp_WS_InsertWSDT @c_LoadKey  
                               , @c_OrderKey  
                               , @c_StorerKey  
                               , @b_Success OUTPUT  
                               , @n_Err OUTPUT  
                               , @c_ErrMsg OUTPUT  
                               , @b_Debug  
  
         IF @b_Success = 0  
         BEGIN  
            SET @n_Continue = 3  
            SET @n_Err = 80003  
            SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_err,0))    
                          + ': Fail To Insert Record Into WSDT Table. (isp_WS_UpdPackOrdSts)'  
            GOTO QUIT  
         END  
           
         IF @c_ErrMsg <> ''  
         BEGIN  
            SET @n_Continue = 3  
            GOTO QUIT  
         END  
      END --IF @c_StorerConfig1 = '0'  
  
      --(KT02) - Start  
      --Get Codelkup Info  
      SELECT @c_DataStream = ISNULL(RTRIM(Code), ''),  
             @c_Type = ISNULL(RTRIM(Short), ''),  
             @c_TargetDB = ISNULL(RTRIM(UDF01), '')  
      FROM CodeLkup WITH (NOLOCK)  
      WHERE StorerKey = @c_StorerKey  
            AND Long = @c_SPName  
            AND ListName = @c_ListName  
  
      /********************************************/  
      /* Update Orders.SOStatus (Start)           */  
      /********************************************/  
      --Get Update Order SOStatus Option  
      EXECUTE nspGetRight  
               NULL,                   -- Facility  
               @c_StorerKey,           -- Storerkey  
               NULL,                   -- Sku  
               @c_StorerConfig3,       -- Configkey  
               @b_Success              OUTPUT,  
               @c_StorerConfigSValue3  OUTPUT,  
               @n_Err                  OUTPUT,  
               @c_ErrMsg               OUTPUT  
  
      IF @b_Debug = 1  
      BEGIN  
         PRINT '[isp_WS_UpdPackOrdSts]: WSUpdOrdSOStsByCondition = ' + @c_StorerConfigSValue3  
      END  
  
      IF ISNULL(RTRIM(@c_StorerConfigSValue3), '0') = '1'  
      BEGIN  
         --Get WSDT_GENERIC_FIELDMAP.UpdOrdSOStatusFilter  
         SET @c_ExecStatements = ''  
         SET @c_ExecArguments = ''  
  
         SET @c_ExecStatements = 'SELECT @c_UpdOrdSOStatusFilter = UpdOrdSOStatusFilter '  
                               + 'FROM ' + @c_TargetDB + '.dbo.WSDT_GENERIC_FIELDMAP WITH (NOLOCK) '  
                               + 'WHERE Datastream = @c_DataStream '  
                               + 'AND [Type] = @c_Type'  
  
         SET @c_ExecArguments = '@c_DataStream           NVARCHAR(4), '  
                              + '@c_Type                 NVARCHAR(1), '   
                              + '@c_UpdOrdSOStatusFilter NVARCHAR(1000) OUTPUT'  
  
         EXEC sp_ExecuteSql @c_ExecStatements  
                           ,@c_ExecArguments   
                           ,@c_DataStream  
                           ,@c_Type  
                           ,@c_UpdOrdSOStatusFilter OUTPUT  
  
         IF @b_debug = 1  
         BEGIN  
            PRINT '[isp_WS_UpdPackOrdSts]: @c_UpdOrdSOStatusFilter = ' + @c_UpdOrdSOStatusFilter  
         END  
  
         SET @c_ExecStatements = ''  
         SET @c_ExecArguments = ''  
  
         SET @c_ExecStatements = 'SELECT @n_Exists = (1) '  
                               + 'FROM ORDERS WITH (NOLOCK) '  
                               + @c_UpdOrdSOStatusFilter  
                               + ' AND SOStatus = ''0'''  
                               + ' AND Status = ''5'''  
  
         SET @c_ExecArguments = '@c_OrderKey    NVARCHAR(10), '  
                              + '@c_StorerKey   NVARCHAR(15), '  
                              + '@n_Exists      INT OUTPUT'   
  
         IF @b_debug = 1  
         BEGIN  
            PRINT '@c_ExecStatements = ' + @c_ExecStatements  
            PRINT '@c_ExecArguments = ' + @c_ExecArguments  
         END  
  
         EXEC sp_ExecuteSql @c_ExecStatements  
                           ,@c_ExecArguments   
                           ,@c_OrderKey  
                           ,@c_StorerKey  
                           ,@n_Exists OUTPUT  
  
         IF @b_debug = 1  
         BEGIN  
            PRINT '[isp_WS_UpdPackOrdSts]: @n_Exists = ' + CAST(CAST(@n_Exists AS INT)AS NVARCHAR)  
         END  
  
         IF @n_Exists = 0  
            SET @c_SOStatus = '5'  
  
      END  
      --(KT02) - End  
  
      UPDATE ORDERS WITH (ROWLOCK)  
      SET SOStatus = @c_SOStatus,  
          Trafficcop = NULL,  
          EditDate = @dt_GetDate,  
          EditWho = SUSER_NAME()  
      WHERE OrderKey = @c_OrderKey  
      AND StorerKey = @c_StorerKey  
      AND SOStatus = '0'  
      AND Status = '5'  
      /********************************************/  
      /* Update Orders.SOStatus (End)             */  
      /********************************************/  
  
      WHILE @@TRANCOUNT > 0  
     COMMIT TRAN  
  
      /******************************************************/  
      /* Update WebService_Log (Start)                      */  
      /******************************************************/  
      IF ISNULL(RTRIM(@c_StorerConfigSValue1), '0') = '0'  
      BEGIN  
         --(KT02) - Start  
--         SELECT @c_DataStream = ISNULL(RTRIM(Code), ''),  
--                @c_Type = ISNULL(RTRIM(Short), ''),  
--                @c_TargetDB = ISNULL(RTRIM(UDF01), '')  
--         FROM CodeLkup WITH (NOLOCK)  
--         WHERE StorerKey = @c_StorerKey  
--               AND Long = @c_SPName  
--               AND ListName = @c_ListName  
         --(KT02) - End  
  
         SET @c_ExecStatements = ''  
         SET @c_ExecArguments = ''  
  
         SET @c_ExecStatements = 'DECLARE C_WebServiceList CURSOR FAST_FORWARD READ_ONLY FOR '   
                               + 'SELECT SeqNo FROM ' + @c_TargetDB + '.dbo.WebService_Log WITH (NOLOCK) '  
                               + 'WHERE SourceKey = @c_OrderKey '  
                               + 'AND SourceType = @c_SourceType '  
                               + 'AND DataStream = @c_DataStream '  
                               + 'AND StorerKey = @c_StorerKey '  
                               + 'AND [Type] = @c_Type '  
                           + 'AND Status = ''W'' '  
                               + 'AND ISNULL(RTRIM(BatchNo), '''') = '''' '  
  
         SET @c_ExecArguments = '@c_OrderKey    NVARCHAR(10), '  
                              + '@c_SourceType  NVARCHAR(125), '   
                              + '@c_DataStream  NVARCHAR(4), '   
                              + '@c_StorerKey   NVARCHAR(15), '   
                              + '@c_Type        NVARCHAR(1)'  
  
         IF @b_debug = 1  
         BEGIN  
            PRINT '@c_ExecStatements = ' + @c_ExecStatements  
            PRINT '@c_ExecArguments = ' + @c_ExecArguments  
         END  
  
         EXEC sp_ExecuteSql @c_ExecStatements  
                           ,@c_ExecArguments   
                           ,@c_OrderKey  
                           ,@c_SourceType  
                           ,@c_DataStream  
                           ,@c_StorerKey  
                           ,@c_Type  
  
         OPEN C_WebServiceList  
         FETCH NEXT FROM C_WebServiceList INTO @n_SeqNo  
  
         WHILE @@FETCH_STATUS <> -1          
         BEGIN  
            SET @c_ExecStatements = 'UPDATE ' +  @c_TargetDB + '.dbo.WebService_Log WITH (ROWLOCK) ' +  
                                    'SET Status = ''0'' ' +  
                                    'WHERE SeqNo = @n_SeqNo'  
  
            SET @c_ExecArguments = '@n_SeqNo INT'  
  
            EXEC sp_ExecuteSql @c_ExecStatements   
                             , @c_ExecArguments    
                             , @n_SeqNo  
  
            IF @@ERROR <> 0  
            BEGIN  
               SET @n_Continue = 3  
               SET @n_Err = 80003  
               SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_err,0))    
                             + ': Fail To Update Record Into WebService_Log. (isp_WS_UpdPackOrdSts)'  
               GOTO QUIT  
            END  
  
            WHILE @@TRANCOUNT > 0  
           COMMIT TRAN   
  
            FETCH NEXT FROM C_WebServiceList INTO @n_SeqNo  
         END  
         CLOSE C_WebServiceList  
         DEALLOCATE C_WebServiceList  
      END  
      /******************************************************/  
      /* Update WebService_Log (End)                        */  
      /******************************************************/             
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
    
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_WS_UpdPackOrdSts'    
      -- RAISERROR @n_err @c_ErrMsg    
  
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