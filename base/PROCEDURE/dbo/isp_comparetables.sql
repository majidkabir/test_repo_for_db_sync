SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************/    
/* Stored Procedure: isp_CompareTables								 */
/* Creation Date: 2019-04-15                                 */    
/* Copyright: IDS                                            */    
/* Written by: tucklungting											 */
/*                                                           */    
/* Purpose: Compare tables & missing columns between 2 DB    */  
/* Data Modifications:                                       */    
/*                                                           */    
/* Updates:                                                  */    
/* Date         Author  ver  Purposes                        */       
/* 2019-08-30   kocy    1.0  intital version                 */
/*************************************************************/    

CREATE PROCEDURE [dbo].[isp_CompareTables](
    @cDatabase1   VARCHAR(100)
   ,@cTableSchema1 VARCHAR(100)
   ,@cTable1      VARCHAR(100)
   ,@LinkedServer VARCHAR(100)
   ,@cDatabase2   VARCHAR(100)
   ,@cTableSchema2 VARCHAR(100)
   ,@cTable2      VARCHAR(100)
   ,@cSkipThisCol VARCHAR(100)
)
AS
BEGIN
	SET NOCOUNT ON;
   SET ANSI_NULLS ON;
   SET ANSI_WARNINGS ON;
	
	DECLARE @nRC             INT
	       ,@cSQL            VARCHAR(8000)
	       ,@cColumns_Table1 VARCHAR(8000)
	       ,@cColumns_Table2 VARCHAR(8000) 
	
	SET @nRC = 1
	IF (
	       @cDatabase1=''
	   OR  @cDatabase2=''
      OR  @cTableSchema1 = ''
      OR  @cTableSchema2 = ''
	   OR  @cTable1=''
	   OR  @cTable2=''
	   OR  @cDatabase1 IS NULL
	   OR  @cDatabase2 IS NULL
      OR  @cTableSchema1 IS NULL
      OR  @cTableSchema2 IS NULL
	   OR  @cTable1    IS NULL
	   OR  @cTable2    IS NULL
	   )
	BEGIN
	    PRINT 'ERROR MISSING PARAMETERS' 
	    RETURN
	END 
	
	
	SELECT @cSQL = 'SELECT column_name FROM '+@cDatabase1+'.INFORMATION_SCHEMA.Columns where Table_NAME = '''+@cTable1+''''
	
	CREATE Table #t
	(
		columnx VARCHAR(8000)
	) 
	INSERT INTO #t
	EXEC (@cSQL) 
	
	SELECT @cColumns_Table1 = (
	           CASE 
	                WHEN t.columnx!=@cSkipThisCol THEN COALESCE(@cColumns_Table1+',' ,'') 
	                    +t.columnx
	                ELSE ''
	           END
	       )
	FROM   (	SELECT *	FROM   #t ) AS t 
	
   DELETE
	FROM  #t 
	
	-- remove comma if @cSkipThisCol
	IF SUBSTRING(@cColumns_Table1 ,1 ,1)=','
	BEGIN
	   SET @cColumns_Table1 = SUBSTRING(@cColumns_Table1 ,2 ,LEN(@cColumns_Table1)-1);
	END 
	
	
	SELECT @cSQL = 'SELECT column_name FROM '+@LinkedServer+'.'+@cDatabase2+'.INFORMATION_SCHEMA.Columns where Table_NAME = '''+@cTable2+''''
	
	
	INSERT INTO #t
	EXEC (@cSQL)
	
	SELECT @cColumns_Table2 = (
	           CASE 
	                WHEN t.columnx!=@cSkipThisCol THEN COALESCE(@cColumns_Table2+',' ,'') 
	                    +t.columnx
	                ELSE ''
	           END
	       )
	FROM   ( SELECT * FROM #t ) AS t 

	IF (SUBSTRING(@cColumns_Table2 ,1 ,1)=',')
	BEGIN
	    SET @cColumns_Table2 = SUBSTRING(@cColumns_Table2 ,2 ,LEN(@cColumns_Table2)-1)
	END 
	
	IF @cColumns_Table2=''
	    SET @cColumns_Table2 = @cColumns_Table1
	
	IF @cColumns_Table2!=@cColumns_Table1
	BEGIN     
		PRINT 'Schema Table:  ' +@cTableSchema1+ '.' + @cTable1 
		PRINT CONVERT(CHAR(15), @cDatabase1 + ':') +  @cColumns_Table1
      PRINT 'Schema Table:  ' +@cTableSchema2+ '.' + @cTable2        
		PRINT CONVERT(CHAR(15), @cDatabase2 + ':') +  @cColumns_Table2
		PRINT ''
--	    SELECT 'Table COLUMNS ARE DIFFERENT' AS ERROR
--	          ,@cColumns_Table1 AS Columns_of_Table1
--	          ,@cColumns_Table2 AS Columns_of_Table2
	    
	    RETURN
	END 
	
	
--	SET @cSQL = 'SELECT '''+@cDatabase1+'.dbo. '+@cTable1+''' AS TableName, '+@cColumns_Table1 
--	   +' FROM '+@cDatabase1+'.dbo.'+@cTable1+' UNION ALL SELECT '''+
--	    @cDatabase2+'.dbo. '+@cTable2+''' As TableName, '+    
--	    @cColumns_Table2+' FROM '+@cDatabase2+'.dbo.'+@cTable2 
--	
--	SET @cSQL = 'SELECT Max(TableName) as TableName, '+@cColumns_Table1+' FROM (' 
--	   +@cSQL+') A GROUP BY '+@cColumns_Table1+' HAVING COUNT(*) = 1' 
--	
--	EXEC (@cSQL)
--	SET @nRC = @@ROWCOUNT 
--	
--	PRINT 'SQL: '+@cSQL 
--	
--	
--	PRINT @nRC
--	IF (@cSQL IS NOT NULL) -- no error bilding @cSQL statement
--	BEGIN
--	    IF (@nRC=0)
--	        SELECT 'ALL EQUAL '+@cDatabase1+'.dbo.'+@cTable1+' und '+
--	               @cDatabase2+'.dbo.'+@cTable2 AS RESULT
--	    ELSE
--	        SELECT CAST(@nRC AS VARCHAR)+' DIFFENCES FOUND BETWEEN'+
--	               @cDatabase1+'.dbo.'+@cTable1+' und '+@cDatabase2+'.dbo.'+@cTable2 AS RESULT
--	END
END

GO