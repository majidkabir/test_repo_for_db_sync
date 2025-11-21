SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* SP: RDT.rdtRIGHTS                                                    */
/* Creation Date: Base                                                  */
/* Copyright: IDS                                                       */
/* Written by: EXE, Modified by SHONG                                   */
/*                                                                      */
/* Purpose: Grant Access Right to nSQL DB Roles                         */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.5                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */ 
/*                                                                      */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 25-May-2006  SHONG         Include "User Define Function" Access     */
/*                            Rights                                    */ 
/************************************************************************/

CREATE PROCEDURE [RDT].[rdtRIGHTS]
 AS
 BEGIN
 SET NOCOUNT ON
 DECLARE CURSOR_OBJECTS CURSOR FAST_FORWARD READ_ONLY FOR
 SELECT sysobjects.type, sysobjects.name,  schema_name(schema_id) 
 FROM SYS.OBJECTS sysobjects    
 WHERE sysobjects.type IN ('U', 'P', 'V')    
 ORDER BY sysobjects.type, sysobjects.name    

 OPEN CURSOR_OBJECTS
 DECLARE @type NVARCHAR(2), @name NVARCHAR(60)
 DECLARE @command NVARCHAR(255)
 DECLARE @Owner   NVARCHAR(60)

 WHILE (1=1)
 BEGIN
 FETCH NEXT FROM CURSOR_OBJECTS
 INTO @type, @name, @Owner
 IF NOT @@FETCH_STATUS = 0
 BREAK
 IF @type = 'U' OR @type = 'V'
 BEGIN
 	SELECT @command = 'GRANT SELECT, INSERT, UPDATE, DELETE ON [' + @Owner + '].[' + RTRIM(@name) + '] TO nsql'
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
 END
 CLOSE CURSOR_OBJECTS
 DEALLOCATE CURSOR_OBJECTS
 END

GO