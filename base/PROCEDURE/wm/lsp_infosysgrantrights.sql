SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROC [WM].[lsp_InfoSysGrantRights]
   @c_ObjectName NVARCHAR(100) = ''
  ,@c_Login      NVARCHAR(100) = '[ALPHA\GTWMSinfosys]'  
AS
BEGIN
   /* 
   Included Object Types are:  
   P - Stored Procedure  
   V - View  
   FN - SQL scalar-function 
   TR - Trigger  
   IF - SQL inlined table-valued function 
   TF - SQL table-valued function 
   U - Table (user-defined) 
   */  
   SET NOCOUNT ON  
   
   CREATE TABLE #runSQL
   (
      runSQL VARCHAR(2000) NOT NULL
   ) 
   
   --Declare @execSQL varchar(2000), @c_Login varchar(30), @space char (1), @TO char (2)  
   DECLARE @execSQL     NVARCHAR(2000)
          ,@space       CHAR(1)
          ,@TO          CHAR(2) 
           
   
   SET @to = 'TO' 
   SET @execSQL = 'Grant View Definition ON '  
   --SET @c_Login = REPLACE(REPLACE (@c_Login ,'[' ,'') ,']' ,'') 
   SET @space = ' ' 
   
   -- For Script View         
   IF  @c_Login = '[ALPHA\GTWMSinfosys]' 
   BEGIN
      INSERT INTO #runSQL
      SELECT @execSQL + 
             CASE WHEN SCHEMA_NAME(SCHEMA_ID) IS NULL THEN ''
                  ELSE SCHEMA_NAME(SCHEMA_ID) + '.' 
             END + [name] + @space + @TO + @space + @c_Login
      FROM  sys.all_objects s
      WHERE TYPE IN ('P' ,'FN' ,'IF' ,'TF' ,'U')
      AND   is_ms_shipped = 0
      AND   s.name IS NOT NULL
      AND   (s.name = @c_ObjectName OR @c_ObjectName = '')
      ORDER BY s.type ,s.name       
   END   
   
   -- For Stored Procedure 
   SET @execSQL = 'Grant EXECUTE ON '     
   INSERT INTO #runSQL
   SELECT @execSQL + 
          CASE WHEN SCHEMA_NAME(SCHEMA_ID) IS NULL THEN ''
               ELSE SCHEMA_NAME(SCHEMA_ID) + '.' 
          END + [name] + @space + @TO + @space + @c_Login
   FROM  sys.all_objects s
   WHERE TYPE IN ('P','FN')
   AND   is_ms_shipped = 0
   AND   s.name IS NOT NULL 
   AND   (s.name = @c_ObjectName OR @c_ObjectName = '')
   ORDER BY s.type ,s.name  

   -- For Table 
   SET @execSQL = 'GRANT SELECT, INSERT, UPDATE, DELETE ON '   
   INSERT INTO #runSQL
   SELECT @execSQL + 
          CASE WHEN SCHEMA_NAME(SCHEMA_ID) IS NULL THEN ''
               ELSE SCHEMA_NAME(SCHEMA_ID) + '.' 
          END + [name] + @space + @TO + @space + @c_Login
   FROM   sys.all_objects s
   WHERE  TYPE IN ('U')
   AND is_ms_shipped = 0
   AND s.name IS NOT NULL
   AND (s.name = @c_ObjectName OR @c_ObjectName = '')
   ORDER BY s.type ,s.name  
         
   SET @execSQL = '' 
       
   Execute_SQL:  
   
   SET ROWCOUNT 1  
   
   SELECT @execSQL = runSQL
   FROM   #runSQL 
   
   PRINT @execSQL --Comment out if you don't want to see the output 
   
   EXEC (@execSQL) 
   
   DELETE 
   FROM   #runSQL
   WHERE  runSQL = @execSQL 
   
   IF EXISTS (SELECT * FROM   #runSQL)
      GOTO Execute_SQL  
   
   SET ROWCOUNT 0 
   
   DROP TABLE #runSQL
   
END

GO