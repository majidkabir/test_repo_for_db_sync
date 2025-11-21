SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store Procedure:  isp_WS_InsertWSLog                                 */  
/* Creation Date: 02-May-2013                                           */  
/* Copyright: IDS                                                       */  
/* Written by: KTLow                                                    */  
/*                                                                      */  
/* Purpose: Insert Record Into WebService_Log                           */  
/*          - XTEP Outbound Process SOS#256707                       */  
/*          - PUMA Outbound Process SOS#274725                       */  
/*                                                                      */  
/* Input Parameters:  @c_LoadKey          - ''                          */  
/*                    @c_OrderKey         - ''                          */  
/*                    @c_StorerKey        - ''                          */  
/*                    @b_Debug            - ''                          */  
/*                                                                      */  
/* Output Parameters: @b_Success          - Success Flag  = 0           */  
/*                    @n_Err              - Error Code    = 0           */  
/*                    @c_ErrMsg           - Error Message = ''          */  
/*                                                                      */  
/* Called By:  isp_WS_UpdPackOrdSts                                     */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 1.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author   Ver.  Purposes                                  */  
/************************************************************************/  
  
CREATE PROC [dbo].[isp_WS_InsertWSLog](  
           @c_LoadKey         NVARCHAR(10)  
         , @c_OrderKey        NVARCHAR(10)  
         , @c_StorerKey       NVARCHAR(15)  
         , @b_Success         INT            = 0  OUTPUT  
         , @n_Err             INT            = 0  OUTPUT  
         , @c_ErrMsg          NVARCHAR(250)  = '' OUTPUT  
         , @c_InstWSLogByPass NVARCHAR(10)   = '1'  
         , @b_Debug           INT            = 0  
)  
AS    
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET ANSI_WARNINGS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   SET XACT_ABORT ON  
   /********************************************/  
   /* Variables Declaration (Start)            */  
   /********************************************/  
 --General  
   DECLARE @n_Continue                 INT  
         , @n_StartTCnt                INT           
         , @c_ExecStatements           NVARCHAR(4000)   
         , @c_ExecArguments            NVARCHAR(4000)   
         , @c_TargetDB                 NVARCHAR(30)   
         , @c_DataStream               NVARCHAR(4)  
         , @c_ListName                 NVARCHAR(10)  
         , @c_SPName                   NVARCHAR(250)    
         , @c_Type                     NVARCHAR(1)  
         , @n_TotalRecords             INT  
         , @n_TotalLoop                INT  
         , @n_TotalRemain              INT  
         , @n_LoopCount                INT  
         , @n_MinRowNum                INT  
         , @n_MaxRowNum                INT  
         , @c_KeyValueIn1              NVARCHAR(60)  
  
   --WebService_Log  
   DECLARE @c_RequestString            NVARCHAR(MAX)  
         , @c_ClientHost               NVARCHAR(1)  
         , @c_WSIndicator              NVARCHAR(1)  
         , @c_SourceType               NVARCHAR(125)  
         , @n_SeqNo                    INT  
  
   --WSDT_GENERIC_FIELDMAP  
   DECLARE @c_SelectStatement          VARCHAR(6000)  
         , @c_TempSelectStatement      VARCHAR(6000)  
         , @n_RowLimitation            INT  
         , @c_XMLHeaderContent         VARCHAR(1000)  
         , @c_TempTableName            VARCHAR(50)  
         , @c_TempInsertField          VARCHAR(1000)  
         , @c_TempTotalFilter          VARCHAR(1000)  
  
   -- Initialisation   
   SELECT @n_StartTCnt = @@TRANCOUNT, @n_Continue = 1, @b_Success = 0, @n_Err = 0, @c_ErrMsg = ''  
   SET @c_ExecStatements      = ''  
   SET @c_ExecArguments       = ''  
   SET @c_TargetDB            = ''  
   SET @c_DataStream          = ''  
   SET @c_ListName            = 'WebService'  
   SET @c_SPName              = 'isp_WS_UpdPackOrdSts'  
   SET @c_Type                = ''  
   SET @n_TotalRecords        = 0  
   SET @n_TotalLoop           = 0  
   SET @n_TotalRemain         = 0  
   SET @n_LoopCount           = 0  
   SET @n_MinRowNum           = 0  
   SET @n_MaxRowNum           = 0  
   SET @c_KeyValueIn1         = ''  
  
   --Initialisation For WebService_Log  
   SET @c_RequestString       = ''  
   SET @c_ClientHost          = ''  
   SET @c_WSIndicator         = ''  
   SET @c_SourceType          = 'getOrderLogisticsStatus_Close'  
   SET @n_SeqNo               = 0  
  
   --Initialisation For WSDT_GENERIC_FIELDMAP  
   SET @c_SelectStatement      = ''  
   SET @c_TempSelectStatement  = ''  
   SET @n_RowLimitation        = 0  
   SET @c_XMLHeaderContent     = ''  
   SET @c_TempTableName        = ''  
   SET @c_TempInsertField      = ''  
   SET @c_TempTotalFilter      = ''  
   /********************************************/  
   /* Variables Declaration (End)              */  
   /********************************************/  
   /********************************************/  
   /* General Validation (Start)               */  
   /********************************************/  
   IF @b_Debug = 1  
   BEGIN  
      PRINT '[isp_WS_InsertWSLog]: Start...'  
  
      PRINT '[isp_WS_InsertWSLog]: @c_LoadKey=' + @c_LoadKey +  
            ', @c_OrderKey=' + @c_OrderKey + ', @c_StorerKey=' + @c_StorerKey  
   END  
   /********************************************/  
   /* General Validation (End)                 */  
   /********************************************/     
   /********************************************/  
   /* Main Process (Start)                     */  
   /********************************************/  
   IF @n_Continue = 1 OR @n_Continue = 2  
   BEGIN  
      IF @c_LoadKey <> ''  
         SET @c_KeyValueIn1 = @c_LoadKey  
      ELSE  
         SET @c_KeyValueIn1 = @c_OrderKey  
  
      --Get Codelkup Info  
      SELECT @c_DataStream = ISNULL(RTRIM(Code), ''),  
             @c_Type = ISNULL(RTRIM(Short), ''),  
             @c_TargetDB = ISNULL(RTRIM(UDF01), '')  
      FROM CodeLkup WITH (NOLOCK)  
      WHERE StorerKey = @c_StorerKey  
            AND Long = @c_SPName  
            AND ListName = @c_ListName  
  
      --Get ItfConfig_WSDT Info  
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
         SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))    
                       + ': Fail To Retrieve ITFConfig_WSDT Info. (isp_WS_InsertWSLog)'  
         GOTO QUIT  
      END  
  
      IF @b_debug = 1                                                                                                       
      BEGIN                                                                                                                 
         PRINT '[isp_WS_InsertWSLog]: @c_DataStream=' + @c_DataStream +   
               ', @c_Type=' + @c_Type + ', @c_TargetDB=' + @c_TargetDB +  
               ', @c_ClientHost=' + @c_ClientHost + ', @c_WSIndicator=' + @c_WSIndicator +  
               ', @c_KeyValueIn1=' + @c_KeyValueIn1  
      END  
  
      --Get WSDT_GENERIC_FIELDMAP Info  
      SET @c_ExecStatements = 'SELECT @c_SelectStatement = ISNULL(RTRIM(SelectStatement), ''''), '  
                            + '@c_TempSelectStatement = ISNULL(RTRIM(TempSelectStatement), ''''), '  
                            + '@n_RowLimitation = RowLimitation, '  
                            + '@c_XMLHeaderContent = ISNULL(RTRIM(XMLHeaderContent), ''''), '  
                            + '@c_TempTableName = ISNULL(RTRIM(TempTableName), ''''), '  
                            + '@c_TempInsertField = ISNULL(RTRIM(TempInsertField), ''''), '  
                            + '@c_TempTotalFilter = ISNULL(RTRIM(TempTotalFilter), '''')'  
                            + 'FROM ' + @c_TargetDB + '.dbo.WSDT_GENERIC_FIELDMAP WITH (NOLOCK) '  
                            + 'WHERE DataStream = @c_DataStream AND Type = @c_Type'  
  
      SET @c_ExecArguments = '@c_DataStream           NVARCHAR(4), ' +  
                             '@c_Type                 NVARCHAR(1), ' +  
                             '@c_SelectStatement      VARCHAR(6000) OUTPUT, ' +  
                             '@c_TempSelectStatement  VARCHAR(6000) OUTPUT, ' +  
                             '@n_RowLimitation        INT OUTPUT, ' +  
                             '@c_XMLHeaderContent     VARCHAR(1000) OUTPUT, ' +  
                             '@c_TempTableName        VARCHAR(50) OUTPUT, ' +  
                             '@c_TempInsertField      VARCHAR(1000) OUTPUT, ' +  
                             '@c_TempTotalFilter      VARCHAR(1000) OUTPUT'  
  
      IF @b_debug = 1                                                                                                       
      BEGIN                                                                                                                 
         PRINT '@c_ExecStatements = ' + @c_ExecStatements  
         PRINT '@c_ExecArguments = ' + @c_ExecArguments  
      END  
  
      EXEC sp_ExecuteSql @c_ExecStatements                                                                                  
                       , @c_ExecArguments                                                                                   
                       , @c_DataStream                                                                                       
                       , @c_Type                                                                                       
                       , @c_SelectStatement OUTPUT  
                       , @c_TempSelectStatement OUTPUT  
                       , @n_RowLimitation OUTPUT  
                       , @c_XMLHeaderContent OUTPUT  
                       , @c_TempTableName OUTPUT  
                       , @c_TempInsertField OUTPUT  
                       , @c_TempTotalFilter OUTPUT  
  
      IF @@ERROR <> 0  
      BEGIN  
         SET @n_Continue = 3  
         SET @n_Err = 80003  
         SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))    
                       + ': Fail To Retrieve WSDT_GENERIC_FIELDMAP Info. (isp_WS_InsertWSLog)'  
         GOTO QUIT  
      END  
  
      IF @b_debug = 1  
      BEGIN  
         PRINT '[isp_WS_InsertWSLog]: @c_SelectStatement=' + @c_SelectStatement +  
               ', @c_TempSelectStatement=' + @c_TempSelectStatement +   
               ', @n_RowLimitation=' + CAST(CAST(@n_RowLimitation AS INT)AS NVARCHAR) +   
               ', @c_XMLHeaderContent=' + @c_XMLHeaderContent + ', @c_TempTableName=' + @c_TempTableName +  
               ', @c_TempInsertField=' + @c_TempInsertField + ', @c_TempTotalFilter=' + @c_TempTotalFilter  
      END  
      /********************************************/  
      /* Output Line Records Limitation (Start)   */  
      /********************************************/  
      IF @n_RowLimitation > 0  
      BEGIN  
         IF @c_TempTableName = ''  
         BEGIN  
            SET @n_Continue = 3  
            SET @n_Err = 80001  
            SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) +  
                            ': Fail To Process. Undefine TableName In WSDT_GENERIC_FIELDMAP. (isp_WS_InsertWSLog)'  
            GOTO QUIT  
         END  
  
         IF @c_TempInsertField = ''  
         BEGIN  
            SET @n_Continue = 3  
            SET @n_Err = 80001  
            SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) +  
                            ': Fail To Process. Undefine ParentChildLinkage In WSDT_GENERIC_FIELDMAP. (isp_WS_InsertWSLog)'  
            GOTO QUIT  
         END  
  
         IF @c_TempSelectStatement = ''  
         BEGIN  
            SET @n_Continue = 3  
            SET @n_Err = 80001  
            SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) +  
                            ': Fail To Process. Undefine DefaultValue In WSDT_GENERIC_FIELDMAP. (isp_WS_InsertWSLog)'  
            GOTO QUIT  
         END  
  
         /********************************************/  
         /* Insert Into Temp Table (Start)           */  
         /********************************************/  
         SET @c_ExecStatements = ''  
         SET @c_ExecArguments = ''  
  
         SET @c_ExecStatements = 'INSERT INTO ' + @c_TempTableName + ' (' + @c_TempInsertField +  
                                 ') ' + @c_TempSelectStatement  
  
         SET @c_ExecArguments = '@c_DataStream  NVARCHAR(4), '  
                              + '@c_StorerKey   NVARCHAR(15), '  
                              + '@c_KeyValueIn1 NVARCHAR(60)'  
  
         IF @b_debug = 1                                                                                                       
         BEGIN                                                                                                                 
            PRINT '@c_ExecStatements = ' + @c_ExecStatements  
            PRINT '@c_ExecArguments = ' + @c_ExecArguments  
         END  
  
         EXEC sp_ExecuteSql @c_ExecStatements  
                          , @c_ExecArguments  
                          , @c_DataStream   
                          , @c_StorerKey  
                          , @c_KeyValueIn1  
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @n_Continue = 3  
            SET @n_Err = 80003  
            SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))    
                          + ': Fail To Insert Record Into Temp Table. (isp_WS_InsertWSLog)'  
            GOTO QUIT  
         END  
  
         WHILE @@TRANCOUNT > 0  
        COMMIT TRAN   
         /********************************************/  
         /* Insert Into Temp Table (End)             */  
         /********************************************/  
         /********************************************/  
         /* Get Total Records In Temp Table (Start)  */  
         /********************************************/  
         SET @c_ExecStatements = ''  
         SET @c_ExecArguments = ''  
  
         SET @c_ExecStatements = 'SELECT @n_TotalRecords = MAX(ISNULL(SeqNo, 0)) FROM ' + @c_TempTableName + ' ' + @c_TempTotalFilter  
  
         SET @c_ExecArguments = '@c_DataStream     NVARCHAR(4), '  
                              + '@c_StorerKey      NVARCHAR(15), '  
                              + '@c_KeyValueIn1    NVARCHAR(60), '  
                              + '@n_TotalRecords   INT OUTPUT'  
  
         IF @b_debug = 1                                                                                                       
         BEGIN                                                                                                                 
            PRINT '@c_ExecStatements = ' + @c_ExecStatements  
            PRINT '@c_ExecArguments = ' + @c_ExecArguments  
         END  
  
         EXEC sp_ExecuteSql @c_ExecStatements  
                          , @c_ExecArguments  
                          , @c_DataStream  
                          , @c_StorerKey  
                          , @c_KeyValueIn1  
                          , @n_TotalRecords OUTPUT  
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @n_Continue = 3  
            SET @n_Err = 80003  
            SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))    
                          + ': Fail To Obtain Maximum Record In Temp Table. (isp_WS_InsertWSLog)'  
            GOTO QUIT  
         END  
         /********************************************/  
         /* Get Total Records In Temp Table (End)    */  
         /********************************************/  
         IF @b_debug = 1  
         BEGIN  
            PRINT '[isp_WS_InsertWSLog]: @n_TotalRecords=' + CAST(CAST(@n_TotalRecords AS INT)AS NVARCHAR)  
         END  
  
         SET @n_TotalLoop = @n_TotalRecords / @n_RowLimitation  
         SET @n_TotalRemain = @n_TotalRecords % @n_RowLimitation  
      END --IF @n_RowLimitation > 0  
      /********************************************/  
      /* Output Line Records Limitation (End)     */  
      /********************************************/    
      IF @b_debug = 1  
      BEGIN  
         PRINT '[isp_WS_InsertWSLog]: @n_TotalLoop=' + CAST(CAST(@n_TotalLoop AS INT)AS NVARCHAR) +  
               ', @n_TotalRemain=' + CAST(CAST(@n_TotalRemain AS INT)AS NVARCHAR)  
      END    
      /******************************************************/  
      /* Get XML String & Insert Into WebService_Log (Start)*/  
      /******************************************************/    
      WHILE @n_LoopCount <= @n_TotalLoop  
      BEGIN  
         IF @n_LoopCount = @n_TotalLoop   
         BEGIN  
            --Last loop for remain records  
            IF @n_RowLimitation > 0  
            BEGIN  
               IF @n_TotalRemain > 0  
               BEGIN  
                  SET @n_MinRowNum = @n_MaxRowNum + 1  
                  SET @n_MaxRowNum = @n_MinRowNum + @n_TotalRemain  
               END  
               ELSE  
               BEGIN  
                  GOTO NEXT_BATCH  
               END --IF @n_TotalRemain > 0  
            END --IF @n_RowLimitation > 0  
         END  
         ELSE  
         BEGIN  
            --perform each batch, @n_TotalLoop always > 0 in this statement  
            SET @n_MinRowNum = @n_MaxRowNum + 1  
            SET @n_MaxRowNum = @n_RowLimitation * (@n_LoopCount + 1)              
         END  
  
         /******************************************************/  
         /* Get XML String (Start)                             */  
         /******************************************************/    
         SET @c_ExecStatements = ''  
         SET @c_ExecArguments = ''  
  
         SET @c_ExecStatements = 'SET @c_RequestString = (' + @c_SelectStatement + ')'  
         SET @c_ExecArguments = '@c_DataStream     NVARCHAR(4), '  
                              + '@c_StorerKey      NVARCHAR(15), '  
                              + '@n_MinRowNum      INT, '  
                              + '@n_MaxRowNum      INT, '  
                              + '@c_KeyValueIn1    NVARCHAR(60), '  
                  + '@c_RequestString  NVARCHAR(MAX) OUTPUT'  
  
         EXEC sp_ExecuteSql @c_ExecStatements   
                          , @c_ExecArguments    
                          , @c_DataStream    
                          , @c_StorerKey  
                          , @n_MinRowNum  
                          , @n_MaxRowNum  
                          , @c_KeyValueIn1  
                          , @c_RequestString OUTPUT  
  
         SET @c_RequestString = ISNULL(RTRIM(@c_RequestString), '')  
         IF @c_RequestString = ''  
         BEGIN  
            SET @n_Continue = 3  
            SET @n_Err = 80003  
            SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))    
                          + ': Fail To Generate XML Output String. (isp_WS_InsertWSLog)'  
            GOTO QUIT  
         END  
  
         SET @c_RequestString = @c_XMLHeaderContent + @c_RequestString  
  
         IF @b_debug = 1  
         BEGIN  
            PRINT '[isp_WS_InsertWSLog]: @c_RequestString=' + @c_RequestString  
         END    
         /******************************************************/  
         /* Get XML String (End)                               */  
         /******************************************************/    
         /******************************************************/  
         /* Insert WebService_Log (Start)                      */  
         /******************************************************/   
         SET @c_ExecStatements = ''  
         SET @c_ExecArguments = ''  
  
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
                                 ', GETDATE()' +  
                                 ', ''W''' +  
                                 ', @c_ClientHost' +  
                                 ', @c_WSIndicator' +  
                                 ', @c_KeyValueIn1' +  
                                 ', @c_SourceType)'  
  
         SET @c_ExecArguments = '@c_DataStream        NVARCHAR(4)' +  
                                ', @c_StorerKey       NVARCHAR(15)' +  
                                ', @c_Type            NVARCHAR(1)' +  
                                ', @c_RequestString   NVARCHAR(MAX)' +  
                                ', @c_ClientHost      NVARCHAR(1)' +  
                                ', @c_WSIndicator     NVARCHAR(1)' +  
                                ', @c_KeyValueIn1     NVARCHAR(60)' +  
                                ', @c_SourceType      NVARCHAR(125)'  
  
         EXEC sp_ExecuteSql @c_ExecStatements   
                          , @c_ExecArguments    
                          , @c_DataStream    
                          , @c_StorerKey  
                          , @c_Type  
                          , @c_RequestString  
                          , @c_ClientHost  
                          , @c_WSIndicator  
             , @c_KeyValueIn1  
                          , @c_SourceType  
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @n_Continue = 3  
            SET @n_Err = 80003  
            SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))    
                          + ': Fail To Insert Record Into WebService_Log. (isp0000P_RG_WS_BAISON_UpdOrdSts)'  
            GOTO QUIT  
         END  
         /******************************************************/  
         /* Insert WebService_Log (End)                        */  
         /******************************************************/   
         NEXT_BATCH:  
  
         WHILE @@TRANCOUNT > 0  
        COMMIT TRAN   
  
         SET @n_LoopCount = @n_LoopCount + 1  
      END --WHILE @n_LoopCount <= @n_TotalLoop  
      /******************************************************/  
      /* Get XML String & Insert Into WebService_Log (End)  */  
      /******************************************************/  
      /******************************************************/  
      /* Delete WSDT Table (Start)                          */  
      /******************************************************/  
      IF @n_RowLimitation > 0  
      BEGIN  
         SET @c_ExecStatements = ''  
         SET @c_ExecArguments = ''  
  
         SET @c_ExecStatements = 'DELETE ' + @c_TempTableName + ' WITH (ROWLOCK) ' + @c_TempTotalFilter  
  
         SET @c_ExecArguments = '@c_DataStream     NVARCHAR(4), '  
                              + '@c_StorerKey      NVARCHAR(15), '  
                              + '@c_KeyValueIn1    NVARCHAR(60)'  
  
         IF @b_debug = 1                                                                                                       
         BEGIN                                                                                                                 
            PRINT '@c_ExecStatements = ' + @c_ExecStatements  
            PRINT '@c_ExecArguments = ' + @c_ExecArguments  
         END  
  
         EXEC sp_ExecuteSql @c_ExecStatements  
                          , @c_ExecArguments  
                          , @c_DataStream  
                          , @c_StorerKey  
                          , @c_KeyValueIn1  
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @n_Continue = 3  
            SET @n_Err = 80003  
            SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))    
                          + ': Fail To Obtain Maximum Record In Temp Table. (isp_WS_InsertWSLog)'  
            GOTO QUIT  
         END  
  
         WHILE @@TRANCOUNT > 0  
        COMMIT TRAN   
      END  
      /******************************************************/  
      /* Delete WSDT Table (End)                            */  
      /******************************************************/  
      /******************************************************/  
      /* Update WebService_Log (Start)                      */  
      /******************************************************/  
      IF @c_InstWSLogByPass = '1'  
      BEGIN  
         SET @c_ExecStatements = ''  
         SET @c_ExecArguments = ''  
  
         SET @c_ExecStatements = 'DECLARE C_WebServiceList CURSOR FAST_FORWARD READ_ONLY FOR '   
                               + 'SELECT SeqNo FROM ' + @c_TargetDB + '.dbo.WebService_Log WITH (NOLOCK) '  
                               + 'WHERE SourceKey = @c_KeyValueIn1 '  
                               + 'AND SourceType = @c_SourceType '  
                               + 'AND DataStream = @c_DataStream '  
                               + 'AND StorerKey = @c_StorerKey '  
                               + 'AND [Type] = @c_Type '  
                               + 'AND Status = ''W'' '  
                               + 'AND ISNULL(RTRIM(BatchNo), '''') = '''' '  
  
         SET @c_ExecArguments = '@c_KeyValueIn1 NVARCHAR(60), '  
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
                           ,@c_KeyValueIn1  
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
               SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))    
                             + ': Fail To Update Record Into WebService_Log. (isp_WS_InsertWSLog)'  
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
    
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_WS_InsertWSLog'    
      -- RAISERROR @n_Err @c_ErrMsg    
  
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