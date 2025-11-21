SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store Procedure:  isp_WS_InsertWSDT                                  */  
/* Creation Date: 11-Jul-2013                                           */  
/* Copyright: IDS                                                       */  
/* Written by: KTLow                                                    */  
/*                                                                      */  
/* Purpose: Insert Record Into WebService_Log                           */  
/*          - XTEP Outbound Process SOS#256707                       */  
/*          - PUMA Outbound Process SOS#274725                       */  
/*          - SCN Outbound Process SOS#280631                       */  
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
  
CREATE PROC [dbo].[isp_WS_InsertWSDT](  
           @c_LoadKey         NVARCHAR(10)  
         , @c_OrderKey        NVARCHAR(10)  
         , @c_StorerKey       NVARCHAR(15)  
         , @b_Success         INT            = 0  OUTPUT  
         , @n_Err             INT            = 0  OUTPUT  
         , @c_ErrMsg          NVARCHAR(250)  = '' OUTPUT  
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
         , @c_KeyValueIn1              NVARCHAR(60)  
         , @n_DBExists                 INT  
         , @n_RecordId                 INT  
  
   --WSDT_GENERIC_FIELDMAP  
   DECLARE @c_TempSelectStatement      VARCHAR(6000)  
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
   SET @c_KeyValueIn1         = ''  
   SET @n_DBExists            = 0  
   SET @n_RecordId            = 0  
  
   --Initialisation For WSDT_GENERIC_FIELDMAP  
   SET @c_TempSelectStatement  = ''  
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
      PRINT '[isp_WS_InsertWSDT]: Start...'  
  
      PRINT '[isp_WS_InsertWSDT]: @c_LoadKey=' + @c_LoadKey +  
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
  
      IF @b_debug = 1  
      BEGIN  
         PRINT '[isp_WS_InsertWSDT]: @c_DataStream=' + @c_DataStream +   
               ', @c_Type=' + @c_Type + ', @c_TargetDB=' + @c_TargetDB +  
               ', @c_KeyValueIn1=' + @c_KeyValueIn1  
      END  
  
      --Get WSDT_GENERIC_FIELDMAP Info  
      SET @c_ExecStatements = 'SELECT @c_TempSelectStatement = ISNULL(RTRIM(TempSelectStatement), ''''), '  
                            + '@c_TempTableName = ISNULL(RTRIM(TempTableName), ''''), '  
                            + '@c_TempInsertField = ISNULL(RTRIM(TempInsertField), ''''), '  
                            + '@c_TempTotalFilter = ISNULL(RTRIM(TempTotalFilter), '''')'  
                            + 'FROM ' + @c_TargetDB + '.dbo.WSDT_GENERIC_FIELDMAP WITH (NOLOCK) '  
                            + 'WHERE DataStream = @c_DataStream AND Type = @c_Type'  
  
      SET @c_ExecArguments = '@c_DataStream           NVARCHAR(4), ' +  
                             '@c_Type                 NVARCHAR(1), ' +  
                             '@c_TempSelectStatement  VARCHAR(6000) OUTPUT, ' +  
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
                       , @c_TempSelectStatement OUTPUT  
                       , @c_TempTableName OUTPUT  
                       , @c_TempInsertField OUTPUT  
                       , @c_TempTotalFilter OUTPUT  
  
      IF @@ERROR <> 0  
      BEGIN  
         SET @n_Continue = 3  
         SET @n_Err = 80003  
         SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))    
                       + ': Fail To Retrieve WSDT_GENERIC_FIELDMAP Info. (isp_WS_InsertWSDT)'  
         GOTO QUIT  
      END  
  
      IF @b_debug = 1  
      BEGIN  
         PRINT '[isp_WS_InsertWSDT]: @c_TempSelectStatement=' + @c_TempSelectStatement +   
               ', @c_TempTableName=' + @c_TempTableName + ', @c_TempInsertField=' + @c_TempInsertField +   
               ', @c_TempTotalFilter=' + @c_TempTotalFilter  
      END  
        
      IF @c_TempTableName = ''  
      BEGIN  
         SET @n_Continue = 3  
         SET @n_Err = 80001  
         SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) +  
                         ': Fail To Process. Undefine TableName In WSDT_GENERIC_FIELDMAP. (isp_WS_InsertWSDT)'  
         GOTO QUIT  
      END  
  
      IF @c_TempInsertField = ''  
      BEGIN  
         SET @n_Continue = 3  
         SET @n_Err = 80001  
         SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) +  
                         ': Fail To Process. Undefine ParentChildLinkage In WSDT_GENERIC_FIELDMAP. (isp_WS_InsertWSDT)'  
         GOTO QUIT  
      END  
  
      IF @c_TempSelectStatement = ''  
      BEGIN  
         SET @n_Continue = 3  
         SET @n_Err = 80001  
         SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) +  
                         ': Fail To Process. Undefine DefaultValue In WSDT_GENERIC_FIELDMAP. (isp_WS_InsertWSDT)'  
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
                       + ': Fail To Insert Record Into Temp Table. (isp_WS_InsertWSDT)'  
         GOTO QUIT  
      END  
  
      WHILE @@TRANCOUNT > 0  
     COMMIT TRAN   
      /********************************************/  
      /* Insert Into Temp Table (End)             */  
      /********************************************/  
      /********************************************/  
      /* Update WSDT Table (Start)                */  
      /********************************************/  
      SET @c_ExecStatements = 'SELECT @n_DBExists = (1) FROM ' + @c_TempTableName +   
                              ' WITH (NOLOCK) ' + @c_TempTotalFilter  
  
      SET @c_ExecArguments = '@c_DataStream  NVARCHAR(4), '  
                           + '@c_StorerKey   NVARCHAR(15), '  
                           + '@c_KeyValueIn1 NVARCHAR(60), '  
                           + '@n_DBExists    INT OUTPUT'  
  
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
                       , @n_DBExists OUTPUT  
  
      IF @n_DBExists = 1  
      BEGIN  
         SET @c_ExecStatements = 'DECLARE C_WSDTTableList CURSOR FAST_FORWARD READ_ONLY FOR '   
                               + 'SELECT RecordId FROM ' + @c_TempTableName + ' WITH (NOLOCK) '  
                               + @c_TempTotalFilter  
                               + ' AND WSDT_Status = ''W'' '  
  
         SET @c_ExecArguments = '@c_DataStream  NVARCHAR(4), '  
                              + '@c_StorerKey   NVARCHAR(15), '  
                              + '@c_KeyValueIn1 NVARCHAR(60)'  
  
         IF @b_debug = 1  
         BEGIN  
            PRINT '@c_ExecStatements = ' + @c_ExecStatements  
            PRINT '@c_ExecArguments = ' + @c_ExecArguments  
         END  
  
         EXEC sp_ExecuteSql @c_ExecStatements  
                           ,@c_ExecArguments   
                          , @c_DataStream   
                          , @c_StorerKey  
                          , @c_KeyValueIn1  
  
         OPEN C_WSDTTableList  
         FETCH NEXT FROM C_WSDTTableList INTO @n_RecordId  
  
         WHILE @@FETCH_STATUS <> -1          
         BEGIN  
            SET @c_ExecStatements = 'UPDATE ' +  @c_TempTableName + ' WITH (ROWLOCK) ' +  
                                    'SET WSDT_Status = ''0'' ' +  
                                    'WHERE RecordId = @n_RecordId'  
  
            SET @c_ExecArguments = '@n_RecordId INT'  
  
            EXEC sp_ExecuteSql @c_ExecStatements   
                             , @c_ExecArguments    
                             , @n_RecordId  
  
            IF @@ERROR <> 0  
            BEGIN  
               SET @n_Continue = 3  
               SET @n_Err = 80003  
               SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))    
                             + ': Fail To Update ' + @c_TempTableName + 'Record. (isp_WS_InsertWSDT)'  
               GOTO QUIT  
            END  
  
            WHILE @@TRANCOUNT > 0  
           COMMIT TRAN   
  
            FETCH NEXT FROM C_WSDTTableList INTO @n_RecordId  
         END  
         CLOSE C_WSDTTableList  
         DEALLOCATE C_WSDTTableList  
      END --IF @n_DBExists = 1        
      /********************************************/  
      /* Update WSDT Table (End)                  */  
      /********************************************/  
   END --IF @n_Continue = 1 OR @n_Continue = 2  
   /********************************************/  
   /* Main Process (End)                       */  
   /********************************************/  
   /********************************************/  
   /* Std - Error Handling (Start)             */  
   /********************************************/   
   QUIT:  
     
   IF CURSOR_STATUS('GLOBAL' , 'C_WSDTTableList') in (0 , 1)  
   BEGIN  
      CLOSE C_WSDTTableList   
      DEALLOCATE C_WSDTTableList   
   END   
  
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
    
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_WS_InsertWSDT'    
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
   /* Std - Error Handling (End)  */  
   /********************************************/     
END --End Procedure  

GO