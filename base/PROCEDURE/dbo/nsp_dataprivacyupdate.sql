SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO





/*********************************************************************************/          
/* Stored Procedure: nsp_DataPrivacyUpdate                                       */          
/* Creation Date: 03-Jun-2018                                                    */          
/* Copyright: IDS                                                                */          
/* Written by: TING                                                              */          
/*                                                                               */          
/* Purpose:  Orders Data Privacy Update                                          */          
/*                                                                               */          
/* Called By:  Backend Job                                                       */          
/*                                                                               */          
/* PVCS Version: 1.0                                                             */          
/*                                                                               */          
/* Version: 5.4                                                                  */          
/*                                                                               */          
/* Data Modifications:                                                           */          
/*                                                                               */          
/* Updates:                                                                      */          
/* Date           Author      Ver.  Purposes                                     */   
/*********************************************************************************/ 
/* 1/9/2021		KS Chin			1.1	Add table name and Table PK parameter  		 */
/* 25/10/2021		KS Chin			1.2	Add Listname param to standardlize codelkup	     */

CREATE   PROC  [dbo].[nsp_DataPrivacyUpdate] (  
   @c_StorerKey		NVARCHAR(20),    
   @c_WMS_DBName1 NVARCHAR(50) = '',   
   @c_WMS_DBName2 NVARCHAR(50) = '',   
   @c_WMS_DBName3 NVARCHAR(50) = '',         
   @c_WMS_DBName4 NVARCHAR(50) = '',   
   @c_WMS_DBName5 NVARCHAR(50) = '',
   @c_TblSchema NVARCHAR(50) = 'dbo',
   @c_TblName NVARCHAR(50)='', --added by KS for target table name input
   @c_TblPKKey NVARCHAR(50)='', -- added by KS for target table Primary Key
   @c_ListName NVARCHAR(10)='' -- added by KS for new Listname example DPrivRcpt
)  
AS  
BEGIN  
	SET NOCOUNT ON
	SET QUOTED_IDENTIFIER OFF
	SET ANSI_NULLS OFF
	SET CONCAT_NULL_YIELDS_NULL OFF
	
   DECLARE  @c_SQL1      NVARCHAR(4000)
          , @c_SQL2      NVARCHAR(4000)
          , @c_SQLParm   NVARCHAR(4000) = ''
          , @c_SQL       NVARCHAR(MAX)
          , @dt_CutOffdate      datetime  
          , @c_Flag      NVARCHAR(10)
		    , @n_Debug     INT
          , @n_row       INT
		    , @c_UpdColumn NVARCHAR(4000)
		    , @c_ColumnName Nvarchar(45)
		    , @n_threadhold INT

   DECLARE @c_DBName NVARCHAR(50) = ''
   		 		  
   SET @c_Flag = ''
   SET @c_SQL = ''
   SET @n_Debug = 0
   SET @c_UpdColumn = ''       
   
   IF @c_StorerKey IS NULL OR @c_StorerKey = ''
   BEGIN
      Select  'No Storer Orders Update!!'   
      Return
   END 
   
   IF @c_WMS_DBName1 IS NULL OR @c_WMS_DBName1 = ''
   BEGIN
      Select 'No DB Update!!'   
      Return
   END
   
   SET @c_SQL = ''
   SET @c_SQLParm = ''
   SET @n_threadhold = 0
   SET @c_SQL1 = ''
   SET @c_SQL2 = ''
    
   IF NOT exists (Select 1 from information_schema.tables  where table_type= 'BASE TABLE' and TABLE_SCHEMA = @c_TblSchema )
   BEGIN 
      PRINT 'Invalid Table schema for data to update !'
      GOTO EXIT_SP
   END    
   
   
   IF @c_ListName IS NULL OR @c_ListName='' --Added KS to get listname input validate
   BEGIN
	  PRINT 'Missing Listname parameter input!'
	  GOTO EXIT_SP
   END

   --Added by KS if no target table name input 
   IF @c_TblName=''
   BEGIN
    SET @c_SQL=N'SELECT @c_TblName=Code FROM ' +@c_TblSchema+'.codelkup (NOLOCK) WHERE LISTNAME ='''+@c_ListName+''' AND storerKey='''+@c_StorerKey+''''
    SET @c_SQLParm='@c_tblName NVARCHAR(50) OUTPUT'
	EXEC sp_ExecuteSQL @c_SQL,@c_SQLParm, @c_tblName out
	IF @n_Debug = 1
		BEGIN
		PRINT @c_SQL
		PRINT ' Get table name from codelkup table code column-  ' 
		PRINT @c_TblName
		END
	IF @c_tblName='' OR @c_tblName=NULL
		BEGIN PRINT 'Missing table name input info' +@c_SQL GOTO EXIT_SP END
	IF NOT exists (select 1 from sys.sysobjects WHERE id = object_id(N'['+@c_TblSchema+'].['+@c_TblName+']'))
		BEGIN
		PRINT 'Invalid Table Name for data to update !'
		GOTO EXIT_SP
		END
   END


   IF @c_TblPKKey='' --Added by KS, Get PK key for target Table from codelkup if no input by user
   BEGIN
	
	SET @c_SQL= N'SELECT DISTINCT @c_TblPKKey = Notes FROM ' +@c_TblSchema+'.codelkup (NOLOCK) WHERE LISTNAME ='''+@c_ListName+'C'' AND code2='''+@c_TblName+''''
	SET @c_SQLParm='@c_TblPKKey NVARCHAR(50) OUTPUT'
	EXEC sp_ExecuteSQL @c_SQL,@c_SQLParm, @c_TblPKKey out
	
	IF @c_TblPKKEY='' OR @c_TblPKKEY=NULL
		BEGIN
		SET @c_SQL = N'SELECT @c_TblPKKey =COLUMN_NAME FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE WHERE TABLE_NAME = '''+@c_TblName+'''
'		SET @c_SQLParm='@c_TblPKKey NVARCHAR(50) OUTPUT'
		EXEC sp_ExecuteSQL @c_SQL,@c_SQLParm, @c_TblPKKey out
		END
	IF @n_Debug = 1
		BEGIN 	
		PRINT ' Get PK Key from codelkup or info schema table -  ' 
		PRINT @c_TblPKKey
		END
	IF @c_TblPKKEY='' OR @c_TblPKKEY=NULL
		BEGIN PRINT 'Missing Primary Key for the table input' +@c_SQL GOTO EXIT_SP END
   END
    
   SET @c_SQL = N'Select @n_threadhold = Short, ' +  -- no of days
		            ' @c_SQL1 = ISNULL(RTRIM(Notes2),''''), ' +  -- program use. criteria filter identify record need to update
		            ' @c_SQL2 = ISNULL(RTRIM(Notes),'''') ' +  -- user define criteria for record filtering
   	            ' FROM ' + @c_TblSchema + '.codelkup (NOLOCK) ' +
   	            ' WHERE LISTNAME = @c_ListName ' +
   	            ' AND Storerkey = @c_StorerKey ' +
   	            ' AND Code = N'''+ @c_TblName +'''' 

   SET @c_SQLParm = N'@c_ListName NVARCHAR(10), @c_StorerKey NVARCHAR(20),  @n_threadhold INT OUTPUT,  @c_SQL1 NVARCHAR(4000) OUTPUT, @c_SQL2 NVARCHAR(4000) OUTPUT '  

   IF @n_Debug = 1
   BEGIN 
     PRINT 'Listname - ' +@c_Listname + '; PK Key value - ' + @c_TblPKKey  
	 PRINT ' SQL -  Filtering Config -'  
     PRINT @c_SQL 
   END
           
   EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_ListName, @c_StorerKey, @n_threadhold OUTPUT, @c_SQL1 OUTPUT, @c_SQL2 OUTPUT  

  IF @n_threadhold < 10 
   BEGIN 
      PRINT 'Invalid threadhold for data to update !'
      GOTO EXIT_SP
   END
   IF @c_SQL1 = ''
   BEGIN
      PRINT 'Invalid Filtering for data to update !'
      GOTO EXIT_SP      
   END

   Set @n_threadhold = 0 - @n_threadhold         
   Set @dt_CutOffdate = DateAdd ( day, @n_threadhold, getdate() )

   Declare @temp_CodelkupTabCol table
   ( [ColSeq] nvarchar(30),
	 ColName   NVARCHAR(50)
   )

   -- Table column to be update

   SET @c_SQL = ''
   SET @c_SQLParm = ''       
 
   SET @c_SQL = N'SELECT [Code],[Long] ' +
                  ' FROM ' + @c_TblSchema + '.CODELKUP WITH (NOLOCK)  ' + 
                  ' WHERE Listname = N'''+@c_ListName + 'C'' ' + --modified by KS input param for listname
                  ' AND Storerkey = @c_StorerKey  ' +
                  ' AND Short = ''1''   ' +
				  ' AND Code2 = '''+@c_TblName +'''' + --added by KS to get table Column
                  ' ORDER BY [Code] ASC   '       

   SET @c_SQLParm =  N'@c_StorerKey NVARCHAR(15) '  

   IF @n_Debug = 1
   BEGIN 
     PRINT ' SQL -  SELECT Orders Columns to Update -'  
     PRINT @c_SQL
   END
   
   INSERT INTO @temp_CodelkupTabCol ([ColSeq], ColName)     
   EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm,  @c_StorerKey 

   DECLARE CUR_READ_Temp_Column CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT [ColName] 
   FROM @temp_CodelkupTabCol
   ORDER BY [ColSeq] ASC

   OPEN CUR_READ_Temp_Column
   FETCH NEXT FROM CUR_READ_Temp_Column INTO @c_ColumnName

   WHILE (@@FETCH_STATUS <> -1)
   BEGIN  
      IF @c_UpdColumn = ''
      BEGIN
         SET @c_UpdColumn = ' SET '+@c_ColumnName+' =''*'' '
      END
      ELSE
      BEGIN
         SET @c_UpdColumn = @c_UpdColumn +', '+@c_ColumnName+' =''*'' '
      END

      FETCH NEXT FROM CUR_READ_Temp_Column INTO @c_ColumnName
   END
   CLOSE CUR_READ_Temp_Column
   DEALLOCATE CUR_READ_Temp_Column      
   
   IF @n_Debug = '1'
   BEGIN
      PRINT 'threadhold- ' + cast(@n_threadhold as nvarchar)
      PRINT 'SQL1- ' + @c_SQL1
      PRINT 'SQL2- ' + @c_SQL2
      PRINT 'CutOffdate- ' + Convert(char(10), @dt_CutOffdate, 112) 
      PRINT 'ColumnUpdate- ' + @c_UpdColumn
   END

   CREATE TABLE #DBTable
   ( DBName  nvarchar(50)  )

   CREATE TABLE #Old_Orders
   ( rowref INT NOT NULL IDENTITY(1,1) PRIMARY KEY,
      Orderkey  nvarchar(10) 
        )

   IF ISNULL(RTRIM(@c_WMS_DBName1 ), '') <> '' AND EXISTS (  SELECT 1 FROM sys.databases (NOLOCK) WHERE name = @c_WMS_DBName1   )
   BEGIN
   INSERT INTO #DBTable ( DBName )
   VALUES ( @c_WMS_DBName1 )
   END 
IF ISNULL(RTRIM(@c_WMS_DBName2 ), '') <> '' AND EXISTS (  SELECT 1 FROM sys.databases (NOLOCK) WHERE name = @c_WMS_DBName2   )
   BEGIN
   INSERT INTO #DBTable ( DBName )
   VALUES ( @c_WMS_DBName2 )
   END 

   IF ISNULL(RTRIM(@c_WMS_DBName3 ), '') <> '' AND EXISTS (  SELECT 1 FROM sys.databases (NOLOCK) WHERE name = @c_WMS_DBName3   )
   BEGIN
   INSERT INTO #DBTable ( DBName )
   VALUES ( @c_WMS_DBName3 )
   END 

   IF ISNULL(RTRIM(@c_WMS_DBName4 ), '') <> '' AND EXISTS (  SELECT 1 FROM sys.databases (NOLOCK) WHERE name = @c_WMS_DBName4   )
   BEGIN
   INSERT INTO #DBTable ( DBName )
   VALUES ( @c_WMS_DBName4 )
   END 

   IF ISNULL(RTRIM(@c_WMS_DBName5 ), '') <> '' AND EXISTS (  SELECT 1 FROM sys.databases (NOLOCK) WHERE name = @c_WMS_DBName5   )
   BEGIN
   PRINT 'DB5- ' +@c_WMS_DBName5
   INSERT INTO #DBTable ( DBName )
   VALUES ( @c_WMS_DBName5 )
   END 
   
   DECLARE DBName_Itemcur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
	SELECT DBName FROM #DBTable

	OPEN DBName_Itemcur   
	FETCH NEXT FROM DBName_Itemcur INTO @c_DBName  
	WHILE @@FETCH_STATUS = 0   
	BEGIN   

	   SET @c_SQL = ''	 
      SET @c_SQLParm = ''

      SET @c_SQL = N' USE ['+ @c_DBName + '] '  + CHAR(13) +    
					' Select ' +@c_TblPKKey  + CHAR(13) + --modified by KS to get table PK
					' From ' + @c_TblSchema + '.'+@c_TblName+' (nolock)  ' + Char(13) +
	 				' where Storerkey = @c_StorerKey  ' + Char(13) +
               ' AND Editdate < @dt_CutOffdate ' + Char(13) 

	  IF @c_SQL1 <> ''
	  BEGIN
		  SET @c_SQL =  @c_SQL + ' AND ' + @c_SQL1 + Char(13) 
	  END

	  IF @c_SQL2 <> ''
	  BEGIN
		  SET @c_SQL =  @c_SQL + ' AND ' + @c_SQL2 + Char(13)  
	  END

     SET @c_SQLParm =  N'@c_StorerKey  NVARCHAR(15), @dt_CutOffdate DATETIME '  

     IF @n_Debug = 1
     BEGIN 
          PRINT 'OrderKey List - ' + CHAR(13) + @c_SQL
     END

     IF @n_Debug = 1
     BEGIN 
        PRINT ' SQL -  SELECT Orders -'  
        PRINT @c_SQL
     END     
     
     TRUNCATE TABLE #Old_Orders

     INSERT INTO #Old_Orders ( Orderkey  )       
     EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm,  @c_StorerKey, @dt_CutOffdate  

     SET @c_SQL = ''

     IF @n_Debug = 1
     BEGIN
        SELECT @n_row = COUNT(1) FROM #Old_Orders
        PRINT ' Process #Old_Orders - ' + CAST (@n_row AS NVARCHAR(10))
     END
      
     IF EXISTS ( SELECT 1 FROM #Old_Orders )
     AND @c_UpdColumn <> ''
     BEGIN

     -- Update Orders
     SET @c_SQL = N' USE ['+ @c_DBName + '] '   + CHAR(13) 

     SET @c_SQL =  @c_SQL +
            ' SET NOCOUNT ON ' + Char(13) +
            ' Declare @c_Orderkey nvarchar(10) ' + Char(13) +
			   ' ' + Char(13) +
            ' DECLARE Orders_Itemcur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR ' + Char(13) +
		      ' Select O.Orderkey  ' + Char(13) +
				' From #Old_Orders O (nolock)  '  + Char(13)  + 
            ' OPEN Orders_Itemcur  ' + Char(13) +
	 			' FETCH NEXT FROM Orders_Itemcur INTO @c_Orderkey   ' + Char(13) +
	 			' WHILE @@FETCH_STATUS = 0  ' + Char(13) +
	 			' BEGIN  ' + Char(13) +
            ' ' + Char(13) +
	 			'  Update ' + @c_TblSchema + '.' + @c_TblName  + Char(13) + 
				   @c_UpdColumn + Char(13) + 
	 			'  , ArchiveCop = ArchiveCop  ' + Char(13) +
	 			'  Where '+@c_TblPKKey + ' = @c_Orderkey   ' + Char(13) +
	 			' FETCH NEXT FROM Orders_Itemcur INTO @c_Orderkey   ' + Char(13) +
	 			' END ' + Char(13) +
	 			' CLOSE Orders_Itemcur  ' + Char(13) +
	 			' DEALLOCATE Orders_Itemcur '

      IF @n_Debug = 1
      BEGIn
         PRINT 'Update SQL - ' +Char(13) + @c_SQL
      END
    
      EXEC (@c_SQL) 
      END
	 	FETCH NEXT FROM DBName_Itemcur INTO @c_DBName   
	END  
	CLOSE DBName_Itemcur   
	DEALLOCATE DBName_Itemcur 
            
END  

EXIT_SP:


GO