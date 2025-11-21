SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/              
/* Store Procedure:  isp_GenericTBLArchive                               */              
/* Creation Date: 03-Feb-2020                                            */              
/* Copyright: IDS                                                        */              
/*                                                                       */              
/* Purpose:  A generic archive base on TBL_ARCHIVECONFIG - DataArchive   */              
/*           Calling script like isp_ArchiveTable                        */              
/*                                                                       */              
/* Input Parameters:  Setup in TBL_ARCHIVECONFIG                         */              
/*                                                                       */              
/* Usage:  Archive records with the same batch of tables,                */              
/*         (same interface) at one time.                                 */              
/*                                                                       */              
/* Updates:                                                              */              
/* Date         Author        Ver  Purposes                              */              
/* 03-Feb-2020  kelvinongcy   1.0  Initial version                       */              
/*************************************************************************/              
CREATE   PROC [dbo].[isp_GenericTBLArchive]                                  
(                 
     @c_arc_code           NVARCHAR(125)                          
   , @n_arc_def_schedule   INT                       
   , @c_Type               NVARCHAR(15)                      
   , @b_debug              BIT = 0                               
                                        
 )                                       
AS                                        
BEGIN                                        
   SET NOCOUNT ON                                        
   SET ANSI_NULLS OFF                                        
   SET QUOTED_IDENTIFIER OFF                                        
   SET CONCAT_NULL_YIELDS_NULL OFF                
   SET ANSI_DEFAULTS OFF                 
                                      
   DECLARE @c_StoredProcedure NVARCHAR(150)                 
          ,@c_StoredProcedure2 NVARCHAR(150)                
          ,@c_ArchiveKey NVARCHAR (10)                                                       
          ,@c_SourceDB NVARCHAR(20)                              
          ,@c_ArchiveDB NVARCHAR(20)                                             
          ,@c_TableSchema NVARCHAR(5)                
          ,@c_SrcTableName NVARCHAR(125)          
          ,@c_TgtTableName NVARCHAR(125)          
          ,@c_SQLCondition  NVARCHAR (4000)                
          ,@c_DateColumn NVARCHAR(20)                
          ,@n_Threshold INT                
          ,@c_Key1Name NVARCHAR(128)                            
          ,@c_Key2Name NVARCHAR(128)                            
          ,@c_Key3Name NVARCHAR(128)                            
          ,@c_Key4Name NVARCHAR(128)                            
          ,@c_Key5Name NVARCHAR(128)                          
          ,@c_Key6Name NVARCHAR(128)                
          ,@c_ExecStatements NVARCHAR(4000)                 
          ,@d_MaxDate NVARCHAR(200)                
          ,@d_Start DATETIME                     
          ,@n_Duration INT                              
          ,@n_RowCnt INT = 0                              
          ,@n_Id INT = ISNULL(TRY_CAST(SUBSTRING(REPLACE(REPLACE(REPLACE(CONVERT(VARCHAR,GETDATE(),126),'-',''),'T',''),':',''),3,10) AS INT),0)                              
          ,@c_Proc  NVARCHAR(128)                              
          ,@n_SQLId INT = 0                              
          ,@b_success INT = 1            
          ,@n_err INT                                
          ,@c_errmsg NVARCHAR(255)                  
          ,@n_continue INT = 1                
                                
   IF @b_debug is NULL                                
      SET @b_debug = 0                               
                                
   SELECT  @c_SrcTableName       = ''        
         , @c_TgtTableName   = ''        
         , @c_SQLCondition       = ''                              
         , @c_ExecStatements     = ''                              
         , @c_Proc               = ISNULL(OBJECT_NAME(@@ProcID),'')                               
                
              
   DECLARE C_ITEM CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                              
   SELECT    ISNULL (StoredProcedure, '') AS StoredProcedure                
            ,ISNULL (StoredProcedure2, '')  AS StoredProcedure2                             
            ,ISNULL(ArchiveKey, '') AS ArchiveKey                             
            ,ISNULL(SourceDB, '')  AS SourceDB                            
            ,ISNULL(ArchiveDB, '') AS ArchiveDB                              
            ,ISNULL(TableSchema, '') AS TableSchema                             
            ,ISNULL(SrcTableName, '') AS SrcTableName           
            , CASE WHEN ISNULL (TgtTableName, '') = '' THEN SrcTableName ELSE TgtTableName END AS TgtTableName         
            ,ISNULL (RTRIM(SQLCondition), '') AS SQLCondition                
            ,ISNULL (RTRIM(DateColumn), '') AS DateColumn                
            ,ISNULL (RTRIM(Threshold), '') AS Threshold                
            ,ISNULL(Key1Name, '') AS Key1Name                           
            ,ISNULL(Key2Name, '') AS Key2Name                                
            ,ISNULL(Key3Name, '') AS Key3Name                              
            ,ISNULL(Key4Name, '') AS Key4Name                           
            ,ISNULL(Key5Name, '') AS Key5Name                            
            ,ISNULL(Key6Name, '') AS Key6Name                    
   FROM  dbo.TBL_ArchiveConfig WITH (NOLOCK)                              
   WHERE ( arc_code = @c_arc_code OR Category = @c_arc_code)              
   AND  arc_def_schedule = @n_arc_def_schedule                             
   AND  [Type] = @c_Type                      
   AND  [Enabled] = '1'                              
                
   OPEN C_ITEM                               
   FETCH NEXT FROM C_ITEM INTO @c_StoredProcedure, @c_StoredProcedure2,  @c_ArchiveKey, @c_SourceDB, @c_ArchiveDB, @c_TableSchema,                                
                               @c_SrcTableName, @c_TgtTableName, @c_SQLCondition, @c_DateColumn, @n_Threshold,        
                               @c_Key1Name,  @c_Key2Name,  @c_Key3Name, @c_Key4Name, @c_Key5Name, @c_Key6Name                   
   WHILE @@FETCH_STATUS= 0                              
   BEGIN                    
                            
    IF (@c_StoredProcedure) <> ''                              
    BEGIN                  
                
      IF @c_Type = '1'                  
      BEGIN               
         IF @c_StoredProcedure <> 'isp_archiveTable_Generic'                      
         BEGIN                      
            SET @c_errmsg = + @c_arc_code +' : Error Config Of Stored Procedure. Valid SP - isp_archiveTable2_Generic '                
            RAISERROR (@c_ErrMsg, 16, 1) WITH SETERROR                   
         END                
              
         IF @c_StoredProcedure = 'isp_archiveTable_Generic'              
         BEGIN               
            IF @c_SourceDB = ''  OR @c_ArchiveDB = '' OR @c_SrcTableName = '' OR @c_Key1Name = ''                      
            BEGIN                      
              SET @c_errmsg = + @c_arc_code+ ' : Error Config Of Not Setup!'                   
              RAISERROR (@c_ErrMsg, 16, 1) WITH SETERROR                
            END                      
            
            IF @c_TableSchema = ''                      
            BEGIN                      
              SET @c_SrcTableName = 'dbo'                      
            END                      
                      
            SET @c_ExecStatements  =  ''                      
                      
            IF @c_SourceDB <> ''                      
            BEGIN                      
              SET @c_ExecStatements = @c_ExecStatements + '/* @c_SourceDB = */''' + @c_SourceDB + ''''                      
         END                      
                                  
            IF @c_ArchiveDB <> ''                      
            BEGIN                      
              SELECT @c_ExecStatements = @c_ExecStatements + CASE WHEN @c_ExecStatements = ''                       
                 THEN  ' /* @c_ArchiveDB = */''' + @c_ArchiveDB + ''''                      
                                     ELSE  ',/* @c_ArchiveDB = */''' + @c_ArchiveDB + ''''                   
                                     END                                                                                
            END                      
                      
            IF @c_TableSchema <> ''                      
            BEGIN                       
              SELECT @c_ExecStatements = @c_ExecStatements + CASE WHEN @c_ExecStatements = ''                       
                                     THEN  ' /* @c_TableSchema = */''' + @c_TableSchema + ''''                      
                                     ELSE  ',/* @c_TableSchema = */''' + @c_TableSchema + ''''                   
                                     END                         
            END                      
                      
            IF @c_SrcTableName <> ''                      
            BEGIN                       
              SELECT @c_ExecStatements = @c_ExecStatements + CASE WHEN @c_ExecStatements = ''                       
                                     THEN  ' /* @c_SrcTableName = */''' + @c_SrcTableName + ''''                      
                                     ELSE  ',/* @c_SrcTableName = */''' + @c_SrcTableName + ''''                   
                                     END                         
            END           
                    
            IF @c_TgtTableName <> ''        
            BEGIN        
               SELECT @c_ExecStatements = @c_ExecStatements + CASE WHEN @c_ExecStatements = ''                       
                                       THEN  ' /* @c_TgtTableName = */''' + @c_TgtTableName + ''''                      
                                       ELSE  ',/* @c_TgtTableName = */''' + @c_TgtTableName + ''''                   
                                       END                         
            END           
                        
            IF @c_DateColumn = '' AND @c_SQLCondition = ''            
            BEGIN            
               SET @c_errmsg = + @c_arc_code +' : Error Config DateColumn AND SQLCondition. Unable both config to be blank. Please at least set one of both config.'                
               RAISERROR (@c_ErrMsg, 16, 1) WITH SETERROR              
               GOTO QUIT            
            END                            
                        
            IF @c_DateColumn <> ''                   
            BEGIN                       
              SET @d_MaxDate = N'DATEADD(DAY, '+ CAST(@n_Threshold * -1 AS nvarchar ) + ', CONVERT(CHAR(10), GETDATE(), 120) ) '                
              SET @d_MaxDate = @c_SrcTableName +'.' +@c_DateColumn + ' < ' + @d_MaxDate                 
            END                 
                              
            IF @c_SQLCondition <> ''                
            BEGIN                
               SET @c_SQLCondition = IIF (@c_DateColumn <> '', @d_MaxDate + @c_SQLCondition,  @c_SQLCondition )                 
            END                
            ELSE                
            BEGIN            
               SET @c_SQLCondition = @d_MaxDate                
            END                
                            
            SELECT @c_ExecStatements = @c_ExecStatements + char(13)                 
                                    + ',/* @cCondition = */''' + @c_SQLCondition + ' '''                    
                      
            IF @c_Key1Name <> ''           
            BEGIN                       
              SELECT @c_ExecStatements = @c_ExecStatements + CASE WHEN @c_ExecStatements = ''                       
                                THEN + char(13) + '  /* @c_Key1Name = */''' + @c_Key1Name +  ''''                      
                                ELSE + char(13) + ',/* @c_Key1Name = */''' + @c_Key1Name +  ''''                      
                                END                      
            END                       
                    
            SELECT @c_ExecStatements = @c_ExecStatements + ',/* @c_Key2Name = */''' + @c_Key2Name + ''''                    
            SELECT @c_ExecStatements = @c_ExecStatements + ',/* @c_Key3Name = */''' + @c_Key3Name + ''''                    
            SELECT @c_ExecStatements = @c_ExecStatements + ',/* @c_Key4Name = */''' + @c_Key4Name + ''''                    
            SELECT @c_ExecStatements = @c_ExecStatements + ',/* @c_Key5Name = */''' + @c_Key5Name + ''''                    
            SELECT @c_ExecStatements = @c_ExecStatements + ',/* @c_Key6Name = */''' + @c_Key6Name + ''''                    
                    
            --SELECT @c_StoredProcedure, @c_SourceDB, @c_ArchiveDB, @c_TableSchema,                                
            --                       @c_SrcTableName, @c_TgtTableName, @c_SQLCondition, @c_Key1Name,  @c_Key2Name,  @c_Key3Name,                 
            --                       @c_Key4Name, @c_Key5Name, @c_Key6Name             
                              
            SELECT @c_ExecStatements = N' EXEC ' + @c_StoredProcedure + @c_ExecStatements               
                          
        END --IF @c_StoredProcedure = 'isp_archiveTable2_Generic'                   
      END  -- IF @c_Type = '1'                     
                           
      IF (@c_Type ='2')                    
      BEGIN                    
          IF  @c_ArchiveKey = ''                      
          BEGIN                      
            SET @c_errmsg = 'Error Config Of Not Setup!' + @c_arc_code +'|' +@c_ArchiveKey                   
            RAISERROR (@c_ErrMsg, 16, 1) WITH SETERROR                
          END                      
                      
           SET @c_ExecStatements  =  ''                    
                                      
           IF @c_ArchiveKey <> ''                      
           BEGIN                      
             SET @c_ExecStatements = @c_ExecStatements +' /* @c_ArchiveKey = */''' + @c_ArchiveKey + ''                                                  
                                    + ''', @b_success = ''0''' + ', @n_err = ''0'' ' + ', @c_errmsg ='''' '                   
           END                    
                      
           IF  @c_SQLCondition <> ''                  
           BEGIN                   
             SELECT @c_ExecStatements = @c_ExecStatements +', /* @c_SQLCondition = */''' + @c_SQLCondition +  ''''                      
           END                  
                             
           SELECT @c_ExecStatements = N' EXEC ' + @c_StoredProcedure + @c_ExecStatements                    
      END                   
                                 
    END --IF (@c_StoredProcedure) <> ''                 
                      
    IF (@c_Type = '3')                  
    BEGIN                                
      IF (@c_StoredProcedure2 <> '')                  
      BEGIN                        
        SET @c_ExecStatements = ''                  
        SET @c_ExecStatements = 'EXEC ' + @c_StoredProcedure2                       
      END                  
     ELSE                  
      BEGIN                  
         SET @c_errmsg = 'Error Config Of Not Setup! ' + @c_StoredProcedure2                  
         RAISERROR (@c_ErrMsg, 16, 1) WITH SETERROR                
      END                  
    END                  
                                    
      IF @b_debug  = 1                                
      BEGIN                                      
         PRINT @c_ExecStatements                                
      END                            
                             
      BEGIN TRY 
         BEGIN TRAN
         SET @d_Start = GETDATE()                                
         EXEC sp_ExecuteSql @c_ExecStatements                              
         SET @n_RowCnt = @@ROWCOUNT 
         COMMIT TRAN
      END TRY                              
      BEGIN CATCH                                
         EXEC ispLogError  @c_SourceDB, @c_TableSchema, @c_Proc, @n_Id, @c_ErrMsg OUTPUT, @n_Err OUTPUT, '',0,0, @c_SrcTableName                  
         RAISERROR (@c_ErrMsg, 16, 1) WITH SETERROR 
         ROLLBACK TRAN
      END CATCH                               
                                    
         SET @n_Duration = DATEDIFF(s, @d_Start, GETDATE())                                
         EXEC ispLogQuery @c_SourceDB, @c_TableSchema, @c_Proc, @n_Id, @c_ExecStatements, @n_Duration, @n_RowCnt, @c_SrcTableName, @n_SQLId OUTPUT                    
                           
   FETCH NEXT FROM C_ITEM INTO @c_StoredProcedure, @c_StoredProcedure2,  @c_ArchiveKey, @c_SourceDB, @c_ArchiveDB, @c_TableSchema,                                
                               @c_SrcTableName, @c_TgtTableName, @c_SQLCondition, @c_DateColumn, @n_Threshold,        
                               @c_Key1Name,  @c_Key2Name,  @c_Key3Name, @c_Key4Name, @c_Key5Name, @c_Key6Name                
   END                              
   CLOSE C_ITEM                              
   DEALLOCATE C_ITEM                              
               
  QUIT:            
            
END 

GO