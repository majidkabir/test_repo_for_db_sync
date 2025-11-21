SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/          
/* Stored Procedure: ispDatamartVerifyDELLOG                            */          
/* Creation Date: 10-Jun-2010                                           */          
/* Copyright: IDS                                                       */          
/* Written by:                                                          */          
/*                                                                      */          
/* Purpose: Remove Delete Log record if parent table data exists.       */          
/*                                                                      */          
/* Called By:  Any other related Store Procedures.                      */          
/*                                                                      */          
/* PVCS Version: 1.0                                                    */          
/*                                                                      */          
/* Version: 5.4                                                         */          
/*                                                                      */          
/* Data Modifications:                                                  */          
/*                                                                      */          
/* Updates:                                                             */          
/* Date         Author     Purposes                                     */          
/* 29Sept2011   TLTING     Update status = 1 in progress                */      
/* 11-Jul-2017  JayLim     Enhance Performance    (jay01)               */
/* 19-Sep-2017  TLTING01   performance tune - avoid block               */
/************************************************************************/          
          
CREATE PROC [dbo].[ispDatamartVerifyDELLOG]          
   @c_TableName nvarchar(120),          
   @c_Prefix    nvarchar(40),             
   @c_Condition nvarchar(4000),        
   @c_Condition2 nvarchar(4000),          
   @b_Success   int OUTPUT        
AS          
BEGIN          
          
   DECLARE @c_SQLStatement nvarchar(max)          
         , @c_ExecArguments nvarchar(max)        
         , @b_debug        int         
         , @n_Cnt          int
         , @n_RowRef       bigint      --(jay01)
         , @n_RowRef2      bigint      --(jay01)
          
   SET @b_Success = 1           
   SET @b_debug = 0          
      
         
   IF ISNULL(RTRIM(@c_Condition),'') = '' OR ISNULL(RTRIM(@c_Condition2),'') = ''          
   BEGIN          
      SELECT @b_Success = 0          
      GOTO RETURN_SP           
   END          
          
   IF @b_Success = 1          
   BEGIN          
      BEGIN TRAN        
            
      SET @n_Cnt = 0           
      SELECT @c_SQLStatement = N' SELECT @n_Cnt = COUNT(1) FROM ' + RTRIM(LTRIM(@c_TableName)) + ' with (NOLOCK) ' +        
                              'WHERE STATUS = ''0'''      
          
      SELECT @c_ExecArguments = N'@n_Cnt  INT OUTPUT'        
      EXEC sp_ExecuteSql @c_SQLStatement        
                     ,@c_ExecArguments         
                     ,@n_Cnt OUTPUT        
                             
      IF @n_Cnt > 0         
      BEGIN          
         -- Start In progress      
         SELECT @c_SQLStatement = ''                           
        -- SELECT @c_SQLStatement = N'UPDATE ' + @c_TableName + ' with (ROWLOCK) ' +      
        --' SET STATUS = ''1'' ' +         
        -- ' FROM ' + @c_TableName + ' WHERE STATUS = ''0'''      
        -- IF @b_debug = 1          
        -- BEGIN          
        --    PRINT @c_SQLStatement          
        -- END          
                   
        -- EXEC sp_executesql @c_SQLStatement        
        -- IF @@ERROR <> 0          
        -- BEGIN          
        --    ROLLBACK TRAN        
        --    SELECT @b_Success = 0        
        --    GOTO RETURN_SP                    
        -- END
        SELECT DATEADD(MINUTE, -30, GETDATE())
        --(jay01)
        SELECT @c_SQLStatement = @c_SQLStatement + ' DECLARE CUR_UPDATE_Table CURSOR LOCAL FAST_FORWARD READ_ONLY FOR '  + master.dbo.fnc_GetCharASCII(13)
        SELECT @c_SQLStatement = @c_SQLStatement + ' SELECT RowRef FROM '+ RTRIM(LTRIM(@c_Tablename)) 
                                                 + ' WITH (NOLOCK) WHERE Status = ''0'' ' + master.dbo.fnc_GetCharASCII(13)
                                                 + ' AND adddate < DATEADD(MINUTE, -1, GETDATE()) ' + master.dbo.fnc_GetCharASCII(13)   -- tlting01
        SELECT @c_SQLStatement = @c_SQLStatement + ' OPEN CUR_UPDATE_Table '  + master.dbo.fnc_GetCharASCII(13)
        SELECT @c_SQLStatement = @c_SQLStatement + ' FETCH NEXT FROM CUR_UPDATE_Table INTO  @n_RowRef  ' + master.dbo.fnc_GetCharASCII(13)
        SELECT @c_SQLStatement = @c_SQLStatement + ' WHILE (@@FETCH_STATUS  <> -1) ' + master.dbo.fnc_GetCharASCII(13)
        SELECT @c_SQLStatement = @c_SQLStatement + ' BEGIN ' + master.dbo.fnc_GetCharASCII(13)
        SELECT @c_SQLStatement = @c_SQLStatement + ' UPDATE ' + @c_TableName + ' ' + master.dbo.fnc_GetCharASCII(13)
        SELECT @c_SQLStatement = @c_SQLStatement + ' SET STATUS = ''1''' + master.dbo.fnc_GetCharASCII(13)
        SELECT @c_SQLStatement = @c_SQLStatement + ' WHERE RowRef = @n_RowRef  ' + master.dbo.fnc_GetCharASCII(13)
        SELECT @c_SQLStatement = @c_SQLStatement + ' FETCH NEXT FROM CUR_UPDATE_Table INTO @n_RowRef  '+ master.dbo.fnc_GetCharASCII(13)
        SELECT @c_SQLStatement = @c_SQLStatement + ' END CLOSE CUR_UPDATE_Table DEALLOCATE CUR_UPDATE_Table ' + ' ' + master.dbo.fnc_GetCharASCII(13)
        

        IF @b_debug = 1          
        BEGIN          
           PRINT @c_SQLStatement   
        END   

         SELECT @c_ExecArguments = N'@c_TableName  nvarchar(120),'
                                   +'@n_RowRef BIGINT'   
                                        
         EXEC sp_ExecuteSql @c_SQLStatement ,@c_ExecArguments ,@c_TableName ,@n_RowRef
         IF @@ERROR <> 0          
         BEGIN          
            ROLLBACK TRAN        
            SELECT @b_Success = 0        
            GOTO RETURN_SP                    
         END
      
         -- Housekeep DELLOG where user insert data (delete) again, then system will use update to principle table      
         SELECT @c_SQLStatement = ''                           
         --SELECT @c_SQLStatement = N'DELETE ' + @c_TableName + ' with (ROWLOCK) FROM ' + @c_TableName +  ' ' + @c_Prefix  + ' ' +        
         --                     ' ' + @c_Condition2 +  -- JOIN         
         --                     ' ' + @c_Condition   -- STATUS = '1'      

        SELECT @c_SQLStatement = @c_SQLStatement + ' DECLARE CUR_DELETE_Table CURSOR LOCAL FAST_FORWARD READ_ONLY FOR '  + master.dbo.fnc_GetCharASCII(13)
        SELECT @c_SQLStatement = @c_SQLStatement + ' SELECT ' + @c_Prefix  + '.RowRef FROM  ' + RTRIM(LTRIM(@c_TableName)) +  ' ' + @c_Prefix  + ' WITH (NOLOCK) ' 
                                                 + ' ' + @c_Condition2 --JOIN
                                                 + ' ' + @c_Condition  --STATUS = '1' 
                                                 + master.dbo.fnc_GetCharASCII(13)
        SELECT @c_SQLStatement = @c_SQLStatement + ' OPEN CUR_DELETE_Table '  + master.dbo.fnc_GetCharASCII(13)
        SELECT @c_SQLStatement = @c_SQLStatement + ' FETCH NEXT FROM CUR_DELETE_Table INTO @n_RowRef2  ' + master.dbo.fnc_GetCharASCII(13)
        SELECT @c_SQLStatement = @c_SQLStatement + ' WHILE (@@FETCH_STATUS  <> -1) ' + master.dbo.fnc_GetCharASCII(13)
        SELECT @c_SQLStatement = @c_SQLStatement + ' BEGIN ' + master.dbo.fnc_GetCharASCII(13)
        SELECT @c_SQLStatement = @c_SQLStatement + ' DELETE FROM ' + @c_TableName + ' ' + master.dbo.fnc_GetCharASCII(13)
        SELECT @c_SQLStatement = @c_SQLStatement + ' WHERE RowRef = @n_RowRef2  ' + master.dbo.fnc_GetCharASCII(13)
        SELECT @c_SQLStatement = @c_SQLStatement + ' FETCH NEXT FROM CUR_DELETE_Table INTO @n_RowRef2  '+ master.dbo.fnc_GetCharASCII(13)
        SELECT @c_SQLStatement = @c_SQLStatement + ' END CLOSE CUR_DELETE_Table DEALLOCATE CUR_DELETE_Table ' + ' ' + master.dbo.fnc_GetCharASCII(13)

         IF @b_debug = 1          
         BEGIN          
            PRINT @c_SQLStatement   
         END
                   
         SELECT @c_ExecArguments = N'@c_TableName  nvarchar(120),'
                                   +'@n_RowRef2 BIGINT'  
                                    
         EXEC sp_ExecuteSql @c_SQLStatement ,@c_ExecArguments ,@c_TableName ,@n_RowRef2
         IF @@ERROR <> 0          
         BEGIN          
            ROLLBACK TRAN        
            SELECT @b_Success = 0        
            GOTO RETURN_SP                    
         END
       
         --EXEC sp_executesql @c_SQLStatement        
         --IF @@ERROR <> 0          
         --BEGIN          
         --   ROLLBACK TRAN        
         --   SELECT @b_Success = 0        
         --   GOTO RETURN_SP                    
         --END          
      END        
      
      COMMIT TRAN        
   END          
        
   RETURN_SP:        
END -- procedure

GO