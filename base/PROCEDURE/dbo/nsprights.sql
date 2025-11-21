SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************************/                  
/* SP: nspRIGHTS                                                                    */                  
/* Creation Date: Base                                                              */                  
/* Copyright: IDS                                                                   */                  
/* Written by: EXE, Modified by SHONG                                               */                  
/*                                                                                  */                  
/* Purpose: Grant Access Right to nSQL DB Roles                                     */                  
/*                                                                                  */                  
/* Usage:                                                                           */                  
/*                                                                                  */                  
/* Called By:                                                                       */                  
/*                                                                                  */                  
/* PVCS Version: 1.2                                                                */                  
/*                                                                                  */                  
/* Version: 5.4                                                                     */                  
/*                                                                                  */                  
/* Data Modifications:                                                              */                  
/*                                                                                  */                  
/*                                                                                  */                  
/* Updates:                                                                         */                  
/* Date         Author         Ver   Purposes                                       */                  
/* 25-May-2006  SHONG                Include "User Define Function" Access Right "  */                  
/* 11-Nov-2009  TLTING         1.1   with Schema (tlting01)                         */                
/* 18-Mar-2010  TLTING         1.2   cover RDT, SYNONYM objects  (tlting01)         */           
/* 26-Jun-2012  TLTING         1.3   Bug fix on Schema                              */               
/* 19-Jan-2014  TLTING         1.4   Table Function                                 */               
/* 11-Nov-2014  TLTING         1.5   Table Function - IF                            */               
/* 22-Jan-2015  TLTING         1.6   SP name field size length                      */       
/* 09-Aug-2016  TLTING         1.7   Sequence                                       */                   
/* 09-Aug-2016  TLTING         1.7   For Archive                                    */
/* 09-Oct-2019  TLTING         1.8   Ignore BI                                      */  
/* 17-Aug-2023  kelvinongcy    1.9   Enhance views table grant select only (kocy01) */
/************************************************************************************/                  
                
CREATE   PROCEDURE [dbo].[nspRIGHTS]                
 AS                
 BEGIN                
 SET NOCOUNT ON                
 SET QUOTED_IDENTIFIER OFF                
 SET ANSI_NULLS OFF                
 SET CONCAT_NULL_YIELDS_NULL OFF                
                
 DECLARE CURSOR_OBJECTS CURSOR FAST_FORWARD READ_ONLY FOR                
 SELECT sysobjects.type, sysobjects.name, schemas.name                 
 FROM sys.SYSOBJECTS sysobjects                 
 join sys.schemas schemas on schemas.schema_id = sysobjects.uid                
 WHERE type IN ('U', 'P', 'V', 'FN', 'SN', 'TF', 'IF','SO')                
 AND category <> 2   
 AND schemas.name <> 'BI'  
 ORDER BY sysobjects.type, sysobjects.name                
                
 OPEN CURSOR_OBJECTS                
 DECLARE @type NVARCHAR(2), @name sysname            
 DECLARE @command NVARCHAR(255)                
 DECLARE @Owner   NVARCHAR(60)                
                
 WHILE (1=1)                
 BEGIN                
 FETCH NEXT FROM CURSOR_OBJECTS                
 INTO @type, @name, @Owner                
 IF NOT @@FETCH_STATUS = 0                
 BREAK                
 --IF @type = 'U' OR @type = 'V' OR @type = 'SN'   --kocy01
 IF @type = 'U' OR @type = 'SN'                
 BEGIN                
  SELECT @command = 'GRANT SELECT, INSERT, UPDATE, DELETE  ON [' + @Owner + '].[' + RTRIM(@name) + '] TO nsql'                
  PRINT @command                
  EXEC(@command)              
  IF NOT @@ERROR = 0                
  PRINT 'Error'                
  END                
  ELSE IF @type = 'P' OR @type = 'FN'                 
  BEGIN                
  SELECT @command = 'GRANT EXECUTE ON [' + @Owner + '].[' + Rtrim(@name) + '] TO nsql'                
  PRINT @command                
  EXEC(@command)                
  IF NOT @@ERROR = 0                
   PRINT 'Error'          
   END          
  ELSE IF @type = 'SO'                  
  BEGIN                
  SELECT @command = 'GRANT UPDATE ON [' + @Owner + '].[' + Rtrim(@name) + '] TO nsql'                
  PRINT @command                
  EXEC(@command)                
  IF NOT @@ERROR = 0                
   PRINT 'Error'          
   END      
  --ELSE IF @type = 'TF'  OR @type = 'IF'  --kocy01
  ELSE IF @type = 'V'  OR @type = 'TF'  OR @type = 'IF' 
  BEGIN                
  SELECT @command = 'GRANT SELECT ON [' + @Owner + '].[' + Rtrim(@name) + '] TO nsql'                
  PRINT @command                
  EXEC(@command)                
  IF NOT @@ERROR = 0                
   PRINT 'Error'                
  END               
 END                
 CLOSE CURSOR_OBJECTS                
 DEALLOCATE CURSOR_OBJECTS                
 END

GO