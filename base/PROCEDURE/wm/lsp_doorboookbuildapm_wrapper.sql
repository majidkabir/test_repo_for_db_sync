SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: lsp_DoorBoookBuildAPM_Wrapper                           */
/* Creation Date: 2022-04-07                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: LFWM-3482 - UAT RG  Generate appointment & Generate booking */
/*        : SP creation                                                 */
/*                                                                      */
/* Called By: SCE                                                       */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 8.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2022-04-07  Wan      1.0   Created & DevOps Combine Script           */
/************************************************************************/
CREATE   PROC [WM].[lsp_DoorBoookBuildAPM_Wrapper]
   @c_Facility          NVARCHAR(5)                
,  @c_Storerkey         NVARCHAR(15)              
,  @b_Success           INT = 1             OUTPUT
,  @n_Err               INT = 0             OUTPUT
,  @c_ErrMsg            NVARCHAR(255)  = '' OUTPUT
,  @c_UserName          NVARCHAR(128)  = ''  
,  @n_ErrGroupKey       INT            = 0  OUTPUT   

AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_StartTCnt                         INT            = @@TRANCOUNT
         , @n_Continue                          INT            = 1
      
         , @c_SQL                               NVARCHAR(4000) = ''
         , @c_SQLWhere                          NVARCHAR(1000) = ''
         , @c_SQLGrpFieldName                   NVARCHAR(1000) = ''
         , @c_SQLParms                          NVARCHAR(4000) = ''

         , @c_TableName                         NVARCHAR(50)   = 'AppointmentAutoBuild'
         , @c_SourceType                        NVARCHAR(50)   = 'lsp_DoorBoookBuildAPM_Wrapper'
         , @c_Refkey1                           NVARCHAR(20)   = ''                      
         , @c_Refkey2                           NVARCHAR(20)   = ''                      
         , @c_Refkey3                           NVARCHAR(20)   = ''    
         , @c_WriteType                         NVARCHAR(10)   = ''          
         , @n_LogWarningNo                      INT            = 0                 
         
         , @n_RowCnt                            INT            = 0

         , @c_AppointmentStrategyKey            NVARCHAR(10)   = ''
         , @c_ShipmentGroupProfile              NVARCHAR(100)  = ''
         , @c_AppointmentGroup                  NVARCHAR(1000) = ''
         , @c_AppointmentID                     NVARCHAR(20)   = ''
      
         , @n_Rowref_SHP                         INT            = 0
      
         , @c_GrpFieldName1                     NVARCHAR(100)  = ''
         , @c_GrpFieldName2                     NVARCHAR(100)  = ''
         , @c_GrpFieldName3                     NVARCHAR(100)  = ''
         , @c_GrpFieldName4                     NVARCHAR(100)  = ''
         , @c_GrpFieldName5                     NVARCHAR(100)  = ''
         , @c_GrpFieldName6                     NVARCHAR(100)  = ''
         , @c_GrpFieldName7                     NVARCHAR(100)  = ''
         , @c_GrpFieldName8                     NVARCHAR(100)  = ''
         , @c_GrpFieldName9                     NVARCHAR(100)  = ''
         , @c_GrpFieldName10                    NVARCHAR(100)  = ''
         
         , @CUR_SAPM                            CURSOR
         , @CUR_ERRLIST                         CURSOR
         
   DECLARE @t_Strategy  TABLE
         (  RowID                INT            IDENTITY(1,1)     PRIMARY KEY 
         ,  StrategyKey          NVARCHAR(10)   NOT NULL DEFAULT('')
         ,  LineNumber           NVARCHAR(5)    NOT NULL DEFAULT('')
         ,  TableName            NVARCHAR(30)   NOT NULL DEFAULT('')   
         ,  FieldName            NVARCHAR(50)   NOT NULL DEFAULT('')  
         ,  GroupByFieldName     NVARCHAR(1000) NOT NULL DEFAULT('')  
         ,  ShipmentGroupProfile NVARCHAR(100)  NOT NULL DEFAULT('')
         ,  [Priority]           NVARCHAR(5)    NOT NULL DEFAULT('')         
         )
     
   DECLARE  @t_WMSErrorList   TABLE                                 
         (  RowID                INT            IDENTITY(1,1)     PRIMARY KEY    
         ,  TableName            NVARCHAR(50)   NOT NULL DEFAULT('')  
         ,  SourceType           NVARCHAR(50)   NOT NULL DEFAULT('')  
         ,  Refkey1              NVARCHAR(20)   NOT NULL DEFAULT('')  
         ,  Refkey2              NVARCHAR(20)   NOT NULL DEFAULT('')  
         ,  Refkey3              NVARCHAR(20)   NOT NULL DEFAULT('')  
         ,  WriteType            NVARCHAR(50)   NOT NULL DEFAULT('')  
         ,  LogWarningNo         INT            NOT NULL DEFAULT(0)  
         ,  ErrCode              INT            NOT NULL DEFAULT(0)  
         ,  Errmsg               NVARCHAR(255)  NOT NULL DEFAULT('')    
         )  
             
   BEGIN TRY    
      IF OBJECT_ID('tempdb..#TMP_Shipment','u') IS NOT NULL
      BEGIN
         DROP TABLE #TMP_Shipment
      END
      
      CREATE TABLE #TMP_Shipment
         (  RowRef                  INT            NOT NULL DEFAULT(0)  PRIMARY KEY 
         ,  Facility                NVARCHAR(5)    NOT NULL DEFAULT('') 
         ,  Storerkey               NVARCHAR(15)   NOT NULL DEFAULT('')   
         ,  ShipmentProfileGroup    NVARCHAR(100)  NOT NULL DEFAULT('')          
         )

      IF OBJECT_ID('tempdb..#TMP_AppointmentGroup','u') IS NOT NULL
      BEGIN
         DROP TABLE #TMP_AppointmentGroup
      END
      
      CREATE TABLE #TMP_AppointmentGroup
         (  RowID                   INT            NOT NULL DEFAULT(0)  PRIMARY KEY 
         ,  FieldName               NVARCHAR(100)  NOT NULL DEFAULT('') 
         ,  FieldVariable           NVARCHAR(100)  NOT NULL DEFAULT('')   
         )
      
      SET @n_Err = 0  
   
      IF SUSER_SNAME() <> @c_UserName     
      BEGIN 
         EXEC [WM].[lsp_SetUser]   
               @c_UserName = @c_UserName  OUTPUT  
            ,  @n_Err      = @n_Err       OUTPUT  
            ,  @c_ErrMsg   = @c_ErrMsg    OUTPUT  
         
         IF @n_Err <> 0   
         BEGIN
            GOTO EXIT_SP  
         END          
                  
         EXECUTE AS LOGIN = @c_UserName  
      END 
      
      INSERT INTO @t_Strategy (  StrategyKey, LineNumber, TableName, FieldName, GroupByFieldName, ShipmentGroupProfile, [Priority] )
      SELECT asd.AppointmentStrategykey
            ,asd.AppointmentStrategyLineNumber
            ,TableName = IIF(CHARINDEX('.',asd.FieldName,1) > 0, LEFT(asd.FieldName,CHARINDEX('.',asd.FieldName,1)-1),'')
            ,FieldName = IIF(CHARINDEX('.',asd.FieldName,1) > 0, RIGHT(asd.FieldName,LEN(asd.FieldName) - CHARINDEX('.',asd.FieldName,1) ),'')
            ,GroupByFieldName = asd.FieldName
            ,ast.ShipmentGroupProfile
            ,ast.[Priority]
      FROM dbo.AppointmentStrategy AS ast WITH (NOLOCK)
      JOIN dbo.AppointmentStrategyDetail AS asd WITH (NOLOCK) ON asd.AppointmentStrategykey = ast.AppointmentStrategykey
      WHERE ast.Storerkey = @c_Storerkey
      AND   ast.Facility  = @c_Facility
      AND   ast.Active    =  'Y'
      ORDER BY ast.[Priority]
            ,  asd.AppointmentStrategykey
            ,  asd.AppointmentStrategyLineNumber


      SET @n_RowCnt = 0
      INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)           
      SELECT @c_TableName, @c_SourceType, ts.StrategyKey, ts.LineNumber, '', 'ERROR', 0, 560551, 'Invalid Grouping Table or Field found.' 
      FROM @t_Strategy AS ts WHERE (ts.TableName <> 'TMS_SHIPMENT' OR ts.FieldName = '')
  
      SET @n_RowCnt = @@ROWCOUNT
  
      IF @n_RowCnt > 0
      BEGIN
         SET @n_Continue = 3
         GOTO EXIT_SP
      END

      INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)           
      SELECT @c_TableName, @c_SourceType, ts.StrategyKey, ts.LineNumber, '', 'ERROR', 0, 560552, 'Invalid Grouping Field found.' 
      FROM @t_Strategy AS ts
      WHERE ts.tablename <> '' 
      AND ts.FieldName <> ''
      AND NOT EXISTS (SELECT 1 FROM sys.columns AS c WHERE c.object_id = OBJECT_ID(ts.tablename) AND c.[name] = ts.FieldName)
      
      IF @@ROWCOUNT > @n_RowCnt
      BEGIN
         SET @n_Continue = 3
         GOTO EXIT_SP
      END

      BEGIN TRAN      
      SET @CUR_SAPM = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT  ts.Strategykey
            , ts.ShipmentGroupProfile
      FROM @t_Strategy AS ts 
      GROUP BY ts.Strategykey
            ,  ts.ShipmentGroupProfile
            ,  ts.[Priority]
      ORDER BY ts.[Priority]
            ,  ts.Strategykey

      OPEN @CUR_SAPM 

      FETCH NEXT FROM @CUR_SAPM INTO @c_AppointmentStrategykey
                                    ,@c_ShipmentGroupProfile
 
      WHILE @@FETCH_STATUS <> -1 AND @n_Continue IN ( 1, 2 ) 
      BEGIN
         SET @c_SQL = N'SELECT'
                     + ' TMS_Shipment.RowRef'
                     + ',Facility = @c_Facility'
                     + ',Storerkey= @c_Storerkey'
                     + ',ShipmentGroupProfile = ISNULL(TMS_Shipment.ShipmentGroupProfile,'''')'
                     + ' FROM TMS_Shipment WITH (NOLOCK)'
                     + ' JOIN TMS_ShipmentTransOrderLink WITH (NOLOCK) ON TMS_ShipmentTransOrderLink.ShipmentGID = TMS_Shipment.ShipmentGID'
                     + ' JOIN TMS_TransportOrder WITH (NOLOCK) ON TMS_TransportOrder.ProvShipmentID = TMS_ShipmentTransOrderLink.ProvShipmentID'              
                     + ' WHERE TMS_TransportOrder.FacilityID = @c_Facility'
                     + ' AND TMS_TransportOrder.Principal  = @c_Storerkey'
                     + ' AND (TMS_Shipment.AppointmentID IS NULL OR TMS_Shipment.AppointmentID = '''')'
                     + ' AND TMS_Shipment.ShipmentGroupProfile = @c_ShipmentGroupProfile'
                     + ' GROUP BY TMS_Shipment.RowRef, ISNULL(TMS_Shipment.ShipmentGroupProfile,'''')'
                     + ' ORDER BY TMS_Shipment.RowRef'
                     
         SET @c_SQLParms = N'@c_Facility  NVARCHAR(5)'
                         + ',@c_Storerkey NVARCHAR(15)'
                         + ',@c_ShipmentGroupProfile  NVARCHAR(100)'
   
         TRUNCATE TABLE #TMP_Shipment;  
         INSERT INTO #TMP_Shipment (RowRef, Facility, Storerkey, ShipmentProfileGroup)     
         EXEC sp_ExecuteSQL @c_SQL
                           ,@c_SQLParms
                           ,@c_Facility
                           ,@c_Storerkey
                           ,@c_ShipmentGroupProfile 
                  
         IF @@ROWCOUNT = 0 
         BEGIN
            GOTO NEXT_STRATEGYKEY
         END                   
   
         TRUNCATE TABLE #TMP_AppointmentGroup;           
         ;WITH bgf AS 
         (  SELECT RowID = 1
            UNION ALL
            SELECT RowID = bgf.RowID + 1
            FROM bgf
            WHERE bgf.RowID < 10
      
         ) 
         , ag AS   
         (
            SELECT RowID = ROW_NUMBER() OVER (ORDER BY ts.LineNumber)
                  ,FieldName = ts.GroupByFieldName
            FROM @t_Strategy AS ts
            WHERE ts.StrategyKey = @c_AppointmentStrategyKey
         ) 
         INSERT INTO #TMP_AppointmentGroup (RowID, FieldName, FieldVariable)
         SELECT bgf.RowID
               ,FieldName = ISNULL(ag.FieldName,'''''')
               ,FieldVariable = '@c_GrpFieldName' + CONVERT(NVARCHAR(2),bgf.RowID)
         FROM bgf
         LEFT OUTER JOIN ag ON ag.RowID = bgf.RowID 
         ORDER BY bgf.RowID
       
         SELECT @c_SQLGrpFieldName = STRING_AGG ( tag.FieldName , ',' )
         WITHIN GROUP (ORDER BY tag.RowID ASC)
         FROM #TMP_AppointmentGroup AS tag         
   
         SELECT @c_SQLWhere = STRING_AGG ( tag.FieldName + ' = ' + tag.FieldVariable, ' AND ' )
            ,   @c_AppointmentGroup = STRING_AGG ( tag.FieldName , ',' )
         WITHIN GROUP (ORDER BY tag.RowID ASC)
         FROM #TMP_AppointmentGroup AS tag
         WHERE tag.FieldName <> ''''''
   
         SET @c_SQLWhere = ' WHERE ' + @c_SQLWhere
      
         SET @c_SQL = N'DECLARE CUR_GRP CURSOR FAST_FORWARD READ_ONLY FOR'
                     + ' SELECT '
                     + @c_SQLGrpFieldName
                     + ' FROM #TMP_Shipment t'
                     + ' JOIN TMS_Shipment WITH (NOLOCK) ON t.RowRef = TMS_Shipment.RowRef'
                     + ' GROUP BY ' + @c_AppointmentGroup
                     + ' ORDER BY ' + @c_AppointmentGroup
              
         EXEC ( @c_SQL )
   
         OPEN CUR_GRP
         FETCH NEXT FROM CUR_GRP INTO @c_GrpFieldName1
                                    , @c_GrpFieldName2
                                    , @c_GrpFieldName3
                                    , @c_GrpFieldName4    
                                    , @c_GrpFieldName5  
                                    , @c_GrpFieldName6
                                    , @c_GrpFieldName7
                                    , @c_GrpFieldName8
                                    , @c_GrpFieldName9    
                                    , @c_GrpFieldName10                                                                                            
   
         WHILE @@FETCH_STATUS <> -1 AND @n_Continue IN ( 1, 2 )
         BEGIN
            --Get Appointment#

            EXEC dbo.nspg_GetKey
                  @KeyName = N'AppointmentID'
                  , @fieldlength = 10            
                  , @keystring = @c_AppointmentID OUTPUT
                  , @b_Success = @b_Success       OUTPUT
                  , @n_err     = @n_err           OUTPUT       
                  , @c_errmsg  = @c_errmsg        OUTPUT
     
            IF @b_Success = 0 
            BEGIN
               SET @n_Continue = 3
               INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)           
               VALUES( @c_TableName, @c_SourceType, @c_AppointmentStrategykey, '', '', 'ERROR', 0, @n_Err, @c_errmsg) 
               BREAK
            END
      
            SET @c_SQL = N'DECLARE CUR_UPD CURSOR FAST_FORWARD READ_ONLY FOR'
                       + ' SELECT TMS_Shipment.RowRef'
                       + ' FROM #TMP_Shipment AS ts' 
                       + ' JOIN TMS_Shipment WITH (NOLOCK) ON TMS_Shipment.RowRef = ts.RowRef'
                       + @c_SQLWhere
                       + ' ORDER BY TMS_Shipment.RowRef'
                        
            SET @c_SQLParms = N'@c_GrpFieldName1   NVARCHAR(100)'
                            + ',@c_GrpFieldName2   NVARCHAR(100)'
                            + ',@c_GrpFieldName3   NVARCHAR(100)'
                            + ',@c_GrpFieldName4   NVARCHAR(100)'
                            + ',@c_GrpFieldName5   NVARCHAR(100)'
                            + ',@c_GrpFieldName6   NVARCHAR(100)'
                            + ',@c_GrpFieldName7   NVARCHAR(100)'
                            + ',@c_GrpFieldName8   NVARCHAR(100)'
                            + ',@c_GrpFieldName9   NVARCHAR(100)'
                            + ',@c_GrpFieldName10  NVARCHAR(100)'
                            
            EXEC sp_ExecuteSQL @c_SQL
                              ,@c_SQLParms
                              ,@c_GrpFieldName1   
                              ,@c_GrpFieldName2   
                              ,@c_GrpFieldName3   
                              ,@c_GrpFieldName4   
                              ,@c_GrpFieldName5   
                              ,@c_GrpFieldName6   
                              ,@c_GrpFieldName7   
                              ,@c_GrpFieldName8   
                              ,@c_GrpFieldName9   
                              ,@c_GrpFieldName10  
                 
            OPEN CUR_UPD
      
            FETCH NEXT FROM CUR_UPD INTO @n_Rowref_SHP
                        
            WHILE @@FETCH_STATUS <> -1 AND @n_Continue IN ( 1, 2 )
            BEGIN     
               UPDATE dbo.TMS_Shipment
                  SET AppointmentID = @c_AppointmentID
                     ,Editwho = SUSER_SNAME()
                     ,EditDate= GETDATE()
               WHERE RowRef = @n_Rowref_SHP
         
               IF @@ERROR <> 0
               BEGIN
                  SET @n_Continue = 3
                  SET @n_Err = 560553
                  SET @c_Errmsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Update TMS_Shipment Fail. (lsp_DoorBoookBuildAPM_Wrapper)'
                                 + '( ' + ERROR_MESSAGE() + ' )'
                                 
                  INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)           
                  VALUES( @c_TableName, @c_SourceType, @c_AppointmentStrategykey, '', '', 'ERROR', 0, @n_Err, @c_errmsg) 
                  
                  BREAK              
               END
               FETCH NEXT FROM CUR_UPD INTO @n_Rowref_SHP
            END
            CLOSE CUR_UPD
            DEALLOCATE CUR_UPD
      
            FETCH NEXT FROM CUR_GRP INTO @c_GrpFieldName1
                                       , @c_GrpFieldName2
                                       , @c_GrpFieldName3
                                       , @c_GrpFieldName4    
                                       , @c_GrpFieldName5  
                                       , @c_GrpFieldName6
                                       , @c_GrpFieldName7
                                       , @c_GrpFieldName8
                                       , @c_GrpFieldName9    
                                       , @c_GrpFieldName10
         END
         CLOSE CUR_GRP
         DEALLOCATE CUR_GRP
   
         NEXT_STRATEGYKEY:  
         FETCH NEXT FROM @CUR_SAPM INTO @c_AppointmentStrategykey
                                       ,@c_ShipmentGroupProfile
      END
      CLOSE @CUR_SAPM
      DEALLOCATE @CUR_SAPM   
   END TRY
   
   BEGIN CATCH
      SET @n_Continue = 3
      SET @n_Err = 0
      SET @c_ErrMsg = ERROR_MESSAGE()
      
      INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)           
      VALUES ( @c_TableName, @c_SourceType, @c_Facility, @c_Storerkey, '', 'ERROR', 0, @n_Err, @c_ErrMsg )
   END CATCH
                       
   EXIT_SP:
   
   IF (XACT_STATE()) = -1                                      
   BEGIN
      SET @n_Continue = 3
      ROLLBACK TRAN
   END 
  
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF @n_StartTCnt = 0 AND @@TRANCOUNT > @n_StartTCnt       
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_DoorBoookBuildAPM_Wrapper'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
   
   SET @CUR_ERRLIST = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT   twl.TableName           
         ,  twl.SourceType          
         ,  twl.Refkey1             
         ,  twl.Refkey2             
         ,  twl.Refkey3             
         ,  twl.WriteType           
         ,  twl.LogWarningNo        
         ,  twl.ErrCode             
         ,  twl.Errmsg                 
   FROM @t_WMSErrorList AS twl  
   ORDER BY twl.RowID  
     
   OPEN @CUR_ERRLIST  
     
   FETCH NEXT FROM @CUR_ERRLIST INTO   @c_TableName           
                                     , @c_SourceType          
                                     , @c_Refkey1             
                                     , @c_Refkey2             
                                     , @c_Refkey3             
                                     , @c_WriteType           
                                     , @n_LogWarningNo        
                                     , @n_Err             
                                     , @c_Errmsg              
     
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
      EXEC [WM].[lsp_WriteError_List]   
         @i_iErrGroupKey= @n_ErrGroupKey OUTPUT   
      ,  @c_TableName   = @c_TableName  
      ,  @c_SourceType  = @c_SourceType  
      ,  @c_Refkey1     = @c_Refkey1  
      ,  @c_Refkey2     = @c_Refkey2  
      ,  @c_Refkey3     = @c_Refkey3  
      ,  @n_LogWarningNo= @n_LogWarningNo  
      ,  @c_WriteType   = @c_WriteType  
      ,  @n_err2        = @n_err   
      ,  @c_errmsg2     = @c_errmsg   
      ,  @b_Success     = @b_Success      
      ,  @n_err         = @n_err          
      ,  @c_errmsg      = @c_errmsg           
       
      FETCH NEXT FROM @CUR_ERRLIST INTO   @c_TableName           
                                        , @c_SourceType          
                                        , @c_Refkey1             
                                        , @c_Refkey2             
                                        , @c_Refkey3             
                                        , @c_WriteType           
                                        , @n_LogWarningNo        
                                        , @n_Err             
                                        , @c_Errmsg       
   END  
   CLOSE @CUR_ERRLIST  
   DEALLOCATE @CUR_ERRLIST 
    
   IF @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN 
   END
         
   REVERT
END

GO