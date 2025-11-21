SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/
/* Function       : fnc_GetSecurityDBName                               */
/* Copyright      : LFL                                                 */
/*                                                                      */
/* Purpose: Return TSECURE database name                                */
/*                                                                      */
/*                                                                      */
/* Usage: SELECT * from dbo.fnc_GetSecurityDBName()                     */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author     Purposes                                */
/************************************************************************/

CREATE FUNCTION [dbo].[fnc_GetSecurityDBName]()
RETURNS VARCHAR(50)
BEGIN
	
	 DECLARE @c_currdbname NVARCHAR(50),
	         @c_tsecuredbname NVARCHAR(50)
	 
	 SELECT @c_currdbname = RTRIM(DB_NAME())
	 
	 SELECT @c_tsecuredbname = CASE WHEN CHARINDEX('IDS', @c_currdbname) > 0 OR CHARINDEX('LFL', @c_currdbname) > 0 THEN
	                                   'TSECURE'
	                                WHEN CHARINDEX('WMS', @c_currdbname) > 0 THEN
	                                   LEFT(@c_currdbname, CHARINDEX('WMS', @c_currdbname) - 1) + 'TSECURE'
	                                ELSE
	                                   'TSECURE'
	                           END	 	    

   IF NOT EXISTS (SELECT 1 FROM master.dbo.sysdatabases WHERE name = @c_tsecuredbname)
   BEGIN
   	  SELECT TOP 1 @c_tsecuredbname = name
   	  FROM master.dbo.sysdatabases 
   	  WHERE name like '%tsecure%'
   END
	                           
   RETURN @c_tsecuredbname
END

GO