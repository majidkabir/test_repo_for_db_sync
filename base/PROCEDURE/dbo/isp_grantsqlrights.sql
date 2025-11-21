SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* SP: isp_GrantSQLRights                                               */
/* Creation Date: Base                                                  */
/* Copyright: IDS                                                       */
/* Written by: Modified by TLTING                                       */
/*                                                                      */
/* Purpose: Grant Access Right to specified DB Roles base on setup      */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */ 
/*                                                                      */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_GrantSQLRights] (@cDBRole NVARCHAR(30))
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF ISNULL(@cDBRole,'') = ''
   BEGIN
      PRINT 'Invalid DBRole !'
      GOTO SP_Exit   
   END 
   
   IF NOT  EXISTS ( SELECT 1  FROM SQLObjectRights WITH (NOLOCK)
	                  WHERE [DBRole] = @cDBRole  ) 
   BEGIN 
      PRINT 'Invalid DBRole !'
      GOTO SP_Exit   
   END 

	DECLARE CURSOR_OBJECTS CURSOR FAST_FORWARD READ_ONLY 
	FOR
 	    SELECT sysobjects.type,
	           sysobjects.name,
	           SCHEMA_NAME(SCHEMA_ID) 
	    FROM   SYS.OBJECTS sysobjects (NOLOCK) 
 	    WHERE  sysobjects.[type] IN ('U', 'P', 'V')
	    ORDER BY
	           sysobjects.type,
	           sysobjects.name 
	
	OPEN CURSOR_OBJECTS
	DECLARE @Type NVARCHAR(2),
	        @name NVARCHAR(60)
	
	DECLARE @command        NVARCHAR(255)
	DECLARE @Schema         NVARCHAR(60)
	DECLARE @RightFlag      VARCHAR(4) 
   DECLARE @cPermission    NVARCHAR(60)
   DECLARE @cObjectType    NVARCHAR(30)

	WHILE (1 = 1)
	BEGIN
	    FETCH NEXT FROM CURSOR_OBJECTS
	    INTO @Type, @name, @Schema 
	    IF NOT @@FETCH_STATUS = 0
	        BREAK
	    
	    SET @RightFlag = '' 
	    SELECT @RightFlag = RightFlag -- '0000' 1st Flag = SELECT, 2nd Flag = INSERT, 3rd Flag = UPDATE, 4th Flag = DELETE 
	    FROM  SQLObjectRights WITH (NOLOCK)
	    WHERE [DBRole] = @cDBRole 
	    AND   OjbName = @name 
	    AND   [Schema] = @Schema 	    
	    
	    IF @RightFlag = '' OR LEFT(@RightFlag, 1) <> '1'
	    BEGIN
	    	 IF @Type IN ('V') 
	    	   SET @cPermission = 'SELECT'
	    	 ELSE IF @Type IN ('U','TF')
	    	    SET @cPermission = 'SELECT, INSERT, UPDATE, DELETE'
	    	 ELSE IF @Type IN ('P','FN') 
	    	    SET @cPermission = 'EXECUTE'
	    	    
          SELECT @command = 'REVOKE ' + @cPermission + ' ON [' + @Schema + '].[' 
	                  + RTRIM(@name) + '] FROM ' + @cDBRole
	        
	       PRINT @command
	       EXEC (@command)	  
	       IF NOT @@ERROR = 0
	          PRINT 'Error'	         	 
	    END
	    ELSE
	    BEGIN
          IF @Type IN ('U', 'V') AND LEFT(@RightFlag, 1) = '1'
	       BEGIN	    	
             SET @cPermission = 'SELECT'

             IF LEN(@RightFlag) > 1 AND @Type ='U'
             BEGIN
          	    IF SUBSTRING(@RightFlag, 2, 1) = '1'
                  SET @cPermission = @cPermission + ', INSERT' 

          	    IF SUBSTRING(@RightFlag, 3, 1) = '1'
                  SET @cPermission = @cPermission + ', UPDATE'

          	    IF SUBSTRING(@RightFlag, 4, 1) = '1'
                  SET @cPermission = @cPermission + ', DELETE'                              
             END
          
	          SELECT @command = 'GRANT ' + @cPermission + ' ON [' + @Schema + '].[' 
	                  + RTRIM(@name) + '] TO ' + @cDBRole
	        
	           PRINT @command
	           EXEC (@command)
	           IF NOT @@ERROR = 0
	               PRINT 'Error'
	       END -- IF @Type IN ('U', 'V') 
	       ELSE 
	       IF @Type IN ('P','FN','TF') AND LEFT(@RightFlag, 1) = '1'
	       BEGIN
	           SELECT @command = 'GRANT EXECUTE ON [' + @Schema + '].[' + RTRIM(@name) 
	                  + '] TO ' + @cDBRole
	        
	           PRINT @command
	           EXEC (@command)
	           IF NOT @@ERROR = 0
	               PRINT 'Error'
	       END	    	
	    END

	END
	CLOSE CURSOR_OBJECTS
	DEALLOCATE CURSOR_OBJECTS

SP_Exit:

END

GO