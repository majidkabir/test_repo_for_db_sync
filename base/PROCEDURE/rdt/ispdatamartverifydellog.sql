SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/          
/* Stored Procedure: ispDatamartVerifyDELLOG                            */          
/* Creation Date: 11-Feb-2015                                           */          
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
/*                                                                      */           
/************************************************************************/          
          
CREATE PROC [RDT].[ispDatamartVerifyDELLOG]          
   @c_TableName nvarchar(120),          
   @c_Prefix    nvarchar(40),             
   @c_Condition nvarchar(4000),        
   @c_Condition2 nvarchar(4000),          
   @b_Success   int OUTPUT        
AS          
BEGIN          
          
   DECLARE @c_SQLStatement nvarchar(512)          
         , @c_ExecArguments nvarchar(512)        
         , @b_debug        int         
         , @n_Cnt          int         
          
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
      SELECT @c_SQLStatement = N' SELECT @n_Cnt = COUNT(1) FROM RDT.' + RTRIM(@c_TableName) + ' with (NOLOCK) ' +        
                              'WHERE STATUS = ''0'''      
          
      SELECT @c_ExecArguments = N'@n_Cnt  INT OUTPUT'        
      EXEC sp_ExecuteSql @c_SQLStatement        
                     ,@c_ExecArguments         
                     ,@n_Cnt OUTPUT        
                             
      IF @n_Cnt > 0         
      BEGIN          
         -- Start In progress      
         SELECT @c_SQLStatement = ''                           
         SELECT @c_SQLStatement = N'UPDATE RDT.' + @c_TableName + ' with (ROWLOCK) ' +      
        ' SET STATUS = ''1'' ' +         
         ' FROM RDT.' + @c_TableName + ' WHERE STATUS = ''0'''      
         IF @b_debug = 1          
         BEGIN          
            PRINT @c_SQLStatement          
         END          
                   
         EXEC sp_executesql @c_SQLStatement        
         IF @@ERROR <> 0          
         BEGIN          
            ROLLBACK TRAN        
            SELECT @b_Success = 0        
            GOTO RETURN_SP                    
         END       
      
         -- Housekeep DELLOG where user insert data (delete) again, then system will use update to principle table      
         SELECT @c_SQLStatement = ''                           
         SELECT @c_SQLStatement = N'DELETE RDT.' + @c_TableName + ' with (ROWLOCK) FROM RDT.' + @c_TableName +  ' ' + @c_Prefix  + ' ' +        
                              ' ' + @c_Condition2 +  -- JOIN         
                              ' ' + @c_Condition   -- STATUS = '1'      
      
         IF @b_debug = 1          
         BEGIN          
            PRINT @c_SQLStatement          
         END          
                   
         EXEC sp_executesql @c_SQLStatement        
         IF @@ERROR <> 0          
         BEGIN          
            ROLLBACK TRAN        
            SELECT @b_Success = 0        
            GOTO RETURN_SP                    
         END          
      END        
      
      COMMIT TRAN        
   END          
        
   RETURN_SP:        
END -- procedure 



GO