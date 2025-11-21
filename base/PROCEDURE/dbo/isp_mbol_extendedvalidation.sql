SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure: isp_MBOL_ExtendedValidation                         */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by: SHONG                                                    */
/*                                                                      */
/* Purpose: MBOL Extended Validation                                    */
/*                                                                      */
/* Called By: isp_ValidateMBOL                                          */
/*                                                                      */
/* PVCS Version: 1.6                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 09-Apr-2009  Shong     1.1   Bug Fixing (Shong001)                   */
/* 20-Apr-2009  Shong     1.2   Fixing Bug in the Condition (Shong002)  */
/* 15-Jul-2009  Shong     1.3   SOS#141726 Include Table Loadplan and   */
/*                              LoadplanDetail.                         */
/* 21-Apr-2011  Shong     1.4   Use Short as EXISTS/NOT EXISTS Condition*/
/* 16-JUL-2012  YTWan     1.5   SOS#248597: IDSUS Additional Validation */
/*                              - Add to call Dynamic Sub SP (Wan01)    */
/* 13-Sep-2012  YTWan     1.6   SOS#255779:MBOL Preaudit Check to return*/
/*                              allerrors. (Wan02)                      */
/* 03-Jan-2014  NJOW01    1.7   297537-Add Where condition and show     */                
/*                              line number                             */
/* 19-Jul-2017  JayLim    1.8   Performance tune-reduce cache log (jay01)*/
/* 23-Apr-2019  WLCHOOI   1.9   WMS-8712 - LEFT JOIN Load-related       */
/*                                         table (WL01)                 */
/* 01-Nov-2021  SHONG     2.0  Fixing Bugs (SWT01)                      */
/************************************************************************/
CREATE PROC [dbo].[isp_MBOL_ExtendedValidation] 
   @cMBOLKey               NVARCHAR(10), 
   @cStorerKey             NVARCHAR(15),
   @cMBOLValidationRules   NVARCHAR(30), 
   @nSuccess               int = 1        OUTPUT,    -- @nSuccess = 0 (Fail), @nSuccess = 1 (Success), @nSuccess = 2 (Warning)
   @cErrorMsg              NVARCHAR(2550) OUTPUT
AS 
   SET NOCOUNT ON      
   SET ANSI_NULLS OFF      
   SET QUOTED_IDENTIFIER OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF  

DECLARE @bInValid bit 

DECLARE @cTableName        NVARCHAR(30), 
        @cDescription      NVARCHAR(250), 
        @cColumnName       NVARCHAR(250),
        @cRecFound         int, 
        @cCondition        NVARCHAR(1000), 
        @cType             NVARCHAR(10),
        @cColName          NVARCHAR(128), 
        @cColType          NVARCHAR(128),
        @c_SPName          NVARCHAR(100),              --(Wan01)
        @n_err             INT,                        --(Wan01)
        @c_ErrMsg          NVARCHAR(255),              --(Wan01)
        @cWhereCondition   NVARCHAR(1000),
        @cMbolLineNumber   NVARCHAR(5)

DECLARE @cSQL nvarchar(Max),
        @cSQLArg nvarchar(max) --(jay01)

SET @bInValid = 0
SET @cErrorMsg = ''
SET @c_SPName  = ''                                   --(Wan01)
SET @c_ErrMsg  = ''                                   --(Wan01)
SET @nSuccess = 1                                     --(Wan01) --SOS#251991

DECLARE CUR_MBOL_REQUIRED CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
SELECT Code, Description, Long, ISNULL(Notes2,'')  
FROM   CODELKUP WITH (NOLOCK)
WHERE  ListName = @cMBOLValidationRules
AND    SHORT    = 'REQUIRED'
ORDER BY Code

OPEN CUR_MBOL_REQUIRED

FETCH NEXT FROM CUR_MBOL_REQUIRED INTO @cTableName, @cDescription, @cColumnName, @cWhereCondition 

WHILE @@FETCH_STATUS <> -1
BEGIN
   SET @cRecFound = 0 
   
   SET @cSQL = N'SELECT @cRecFound = COUNT(1), @cMBOLLineNumber = MIN(MBOLDETAIL.MBOLLineNumber) '
               +' FROM MBOL (NOLOCK) '
               +' JOIN MBOLDETAIL WITH (NOLOCK) ON MBOL.MBOLKey = MBOLDETAIL.MBOLKey '
               +' JOIN ORDERS WITH (NOLOCK) ON ORDERS.OrderKey = MBOLDETAIL.OrderKey '
               +' LEFT JOIN LOADPLANDETAIL WITH (NOLOCK) ON LOADPLANDETAIL.OrderKey = MBOLDETAIL.OrderKey '    --(WL01)
               +' LEFT JOIN LOADPLAN WITH (NOLOCK) ON LOADPLANDETAIL.LoadKey = LOADPLAN.LoadKey '  --(WL01)
               +' WHERE MBOL.MBOLKey= @cMBOLKey' 
               +' AND ORDERS.StorerKey = @cStorerKey '
    
   -- Get Column Type
   SET @cTableName = LEFT(@cColumnName, CharIndex('.', @cColumnName) - 1)
   SET @cColName   = SUBSTRING(@cColumnName, 
                     CharIndex('.', @cColumnName) + 1, LEN(@cColumnName) - CharIndex('.', @cColumnName))

   SET @cColType = ''
   SELECT @cColType = DATA_TYPE 
   FROM   INFORMATION_SCHEMA.COLUMNS 
   WHERE  TABLE_NAME = @cTableName
   AND    COLUMN_NAME = @cColName

   IF ISNULL(RTRIM(@cColType), '') = '' 
   BEGIN
      SET @bInValid = 1 
      SET @cErrorMsg = 'Invalid Column Name: ' + @cColumnName 
      GOTO QUIT
   END 

   IF @cColType IN ('char', 'nvarchar', 'varchar') 
      SET @cSQL = @cSQL + master.dbo.fnc_GetCharASCII(13) + ' AND ISNULL(RTRIM(' + @cColumnName + '),'''') = '''' '
   ELSE IF @cColType IN ('float', 'money', 'int', 'decimal', 'numeric', 'tinyint', 'real', 'bigint')
      SET @cSQL = @cSQL + master.dbo.fnc_GetCharASCII(13) + ' AND ' + @cColumnName + ' = 0 '

   SET @cSQL = @cSQL + master.dbo.fnc_GetCharASCII(13) + CASE WHEN LEFT(LTRIM(@cWhereCondition),3) NOT IN ('AND','OR ') AND ISNULL(@cWhereCondition,'') <> '' THEN ' AND ' ELSE ' ' END + RTRIM(@cWhereCondition) --+ ')'       

   --(jay01)
   SET @cSQLArg = N'@cRecFound int OUTPUT, '
                   +'@cMBOLLineNumber nvarchar(5) OUTPUT, '
                   +'@cMBOLKey NVARCHAR(10), '
                   +'@cStorerKey NVARCHAR(15) '

   EXEC sp_executesql @cSQL, @cSQLArg, @cRecFound OUTPUT, @cMBOLLineNumber OUTPUT, @cMBOLKey, @cStorerKey --(jay01)

   -- Bug Fixed (Shong001) 
   IF @cRecFound > 0  
   BEGIN 
      SET @bInValid = 1 
      IF @cTableName IN ('MBOLDETAIL','ORDERS')
         SET @cErrorMsg = RTRIM(@cErrorMsg) + 'Line# ' + RTRIM(@cMBOLLineNumber) + '. ' + RTRIM(@cDescription) + ' Is Required! ' + master.dbo.fnc_GetCharASCII(13)
      ELSE
         SET @cErrorMsg = RTRIM(@cErrorMsg) + RTRIM(@cDescription) + ' Is Required! ' +  master.dbo.fnc_GetCharASCII(13)
   END 

   FETCH NEXT FROM CUR_MBOL_REQUIRED INTO @cTableName, @cDescription, @cColumnName, @cWhereCondition  
END 
CLOSE CUR_MBOL_REQUIRED
DEALLOCATE CUR_MBOL_REQUIRED 

IF @cErrorMsg <> ''
BEGIN
   SET @n_err = 74001
   INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@cMBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                                                          '-----------------------------------------------------')            
   INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@cMBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERRORMSG',
                                                                          @cErrorMsg)    
   INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@cMBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                                                          '-----------------------------------------------------') 
END 

--(Wan02) - START
--IF @bInValid = 1
--   GOTO QUIT
SET @cErrorMsg = ''
--(Wan02) - END
----------- Check Condition ------

SET @bInValid = 0 

DECLARE CUR_MBOL_CONDITION CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
SELECT Code, Description, Long, Notes, SHORT, ISNULL(Notes2,'')   
FROM   CODELKUP WITH (NOLOCK)
WHERE  ListName = @cMBOLValidationRules
AND    SHORT    IN ('CONDITION', 'CONTAINS')

OPEN CUR_MBOL_CONDITION

FETCH NEXT FROM CUR_MBOL_CONDITION INTO @cTableName, @cDescription, @cColumnName, @cCondition, @cType, @cWhereCondition  

WHILE @@FETCH_STATUS <> -1
BEGIN   
   SET @cSQL = N'SELECT @cRecFound = COUNT(1), @cMBOLLineNumber = MIN(MBOLDETAIL.MBOLLineNumber) '
               +' FROM MBOL (NOLOCK) '
               +' JOIN MBOLDETAIL WITH (NOLOCK) ON MBOL.MBOLKey = MBOLDETAIL.MBOLKey '
               +' JOIN ORDERS WITH (NOLOCK) ON ORDERS.OrderKey = MBOLDETAIL.OrderKey '
               +' LEFT JOIN LOADPLANDETAIL WITH (NOLOCK) ON LOADPLANDETAIL.OrderKey = MBOLDETAIL.OrderKey '  --(WL01)
               +' LEFT JOIN LOADPLAN WITH (NOLOCK) ON LOADPLANDETAIL.LoadKey = LOADPLAN.LoadKey '  --(WL01)
               +' WHERE MBOL.MBOLKey= @cMBOLKey '
               +' AND ORDERS.StorerKey = @cStorerKey ' --(jay01)

   IF @cType = 'CONDITION'
   BEGIN
   	IF ISNULL(@cCondition,'') <> ''
   	  BEGIN
      	 SET @cCondition = REPLACE(LEFT(@cCondition,5),'AND ','AND (') + SUBSTRING(@cCondition,6,LEN(@cCondition)-5)
      	 SET @cCondition = REPLACE(LEFT(@cCondition,4),'OR ','OR (') + SUBSTRING(@cCondition,5,LEN(@cCondition)-4)
         SET @cSQL = @cSQL + master.dbo.fnc_GetCharASCII(13) + CASE WHEN LEFT(LTRIM(@cCondition),3) NOT IN ('AND','OR ') AND ISNULL(@cCondition,'') <> '' THEN ' AND (' ELSE ' ' END + RTRIM(@cCondition)
         SET @cSQL = @cSQL + master.dbo.fnc_GetCharASCII(13) + CASE WHEN LEFT(LTRIM(@cWhereCondition),3) NOT IN ('AND','OR ') AND ISNULL(@cWhereCondition,'') <> '' THEN ' AND ' ELSE ' ' END + RTRIM(@cWhereCondition) + ')'
      END 
      ELSE
      BEGIN
      	 IF ISNULL(@cWhereCondition,'') <> ''
      	 BEGIN
      	   SET @cWhereCondition = REPLACE(LEFT(@cWhereCondition,5),'AND ','AND (') + SUBSTRING(@cWhereCondition,6,LEN(@cWhereCondition)-5)
      	   SET @cWhereCondition = REPLACE(LEFT(@cWhereCondition,4),'OR ','OR (') + SUBSTRING(@cWhereCondition,5,LEN(@cWhereCondition)-4)
           SET @cSQL = @cSQL + master.dbo.fnc_GetCharASCII(13) + CASE WHEN LEFT(LTRIM(@cWhereCondition),3) NOT IN ('AND','OR ') AND ISNULL(@cWhereCondition,'') <> '' THEN ' AND (' ELSE ' ' END + RTRIM(@cWhereCondition) + ')'
         END
      END
      --SET @cSQL = @cSQL + master.dbo.fnc_GetCharASCII(13) + ' ' + @cCondition       
   END
   ELSE
   BEGIN --CONTAINS
   	  IF ISNULL(@cCondition,'') <> ''
   	  BEGIN
         SET @cSQL = @cSQL + master.dbo.fnc_GetCharASCII(13) + ' AND (' + @cColumnName + ' IN (' + ISNULL(RTRIM(@cCondition),'') + ')' 
         SET @cSQL = @cSQL + master.dbo.fnc_GetCharASCII(13) + CASE WHEN LEFT(LTRIM(@cWhereCondition),3) NOT IN ('AND','OR ') AND ISNULL(@cWhereCondition,'') <> '' THEN ' AND ' ELSE ' ' END + RTRIM(@cWhereCondition) + ')'
      END
      ELSE
      BEGIN
      	 IF ISNULL(@cWhereCondition,'') <> ''
      	 BEGIN
      	   SET @cWhereCondition = REPLACE(LEFT(@cWhereCondition,5),'AND ','AND (') + SUBSTRING(@cWhereCondition,6,LEN(@cWhereCondition)-5)
      	   SET @cWhereCondition = REPLACE(LEFT(@cWhereCondition,4),'OR ','OR (') + SUBSTRING(@cWhereCondition,5,LEN(@cWhereCondition)-4)
           SET @cSQL = @cSQL + master.dbo.fnc_GetCharASCII(13) + CASE WHEN LEFT(LTRIM(@cWhereCondition),3) NOT IN ('AND','OR ') AND ISNULL(@cWhereCondition,'') <> '' THEN ' AND (' ELSE ' ' END + RTRIM(@cWhereCondition) + ')'
         END
      END                   
      -- Shong002 Bug Fixed
      --SET @cSQL = @cSQL + master.dbo.fnc_GetCharASCII(13) + ' AND ' + @cColumnName + ' IN (' + ISNULL(RTRIM(@cCondition),'') + ')' 
   END 

   --(jay01)
   SET @cSQLArg = N'@cRecFound int OUTPUT, '
                   +'@cMBOLLineNumber nvarchar(5) OUTPUT, '
                   +'@cMBOLKey NVARCHAR(10), '
                   +'@cStorerKey NVARCHAR(15) '

   SET @cRecFound = 0 -- (SWT01)
   EXEC sp_executesql @cSQL, @cSQLArg, @cRecFound OUTPUT, @cMBOLLineNumber OUTPUT, @cMBOLKey, @cStorerKey --(jay01)
  
   IF @cRecFound = 0 AND @cType <> 'CONDITION'
   BEGIN 
      SET @bInValid = 1 
      SET @cErrorMsg = @cErrorMsg + RTRIM(@cDescription) + ' Is Invalid! ' + + master.dbo.fnc_GetCharASCII(13)
   END 
   ELSE
   IF @cRecFound > 0 AND @cType = 'CONDITION' AND @cColumnName = 'NOT EXISTS' 
   BEGIN 
      SET @bInValid = 1 
      IF CharIndex('MBOLDETAIL', @cCondition) > 0 OR CharIndex('ORDERS', @cCondition) > 0  
         SET @cErrorMsg = @cErrorMsg + 'Line# ' + RTRIM(@cMBOLLineNumber) + '. ' + RTRIM(@cDescription) + ' Found! ' + master.dbo.fnc_GetCharASCII(13)
      ELSE
         SET @cErrorMsg = @cErrorMsg + RTRIM(@cDescription) + ' Found! ' + master.dbo.fnc_GetCharASCII(13)
   END 
   ELSE
   IF @cRecFound = 0 AND @cType = 'CONDITION' AND 
      (ISNULL(RTRIM(@cColumnName),'') = '' OR @cColumnName = 'EXISTS')  
   BEGIN 
      SET @bInValid = 1 
      SET @cErrorMsg = @cErrorMsg + RTRIM(@cDescription) + ' Not Found! ' + + master.dbo.fnc_GetCharASCII(13)
   END 

   FETCH NEXT FROM CUR_MBOL_CONDITION INTO @cTableName, @cDescription, @cColumnName, @cCondition, @cType, @cWhereCondition  
END 
CLOSE CUR_MBOL_CONDITION
DEALLOCATE CUR_MBOL_CONDITION 

--(Wan01) - START
IF @cErrorMsg <> ''
BEGIN
   SET @n_err = 74002
   INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@cMBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                                                          '-----------------------------------------------------')            
   INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@cMBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERRORMSG',
                                                                          @cErrorMsg)    
   INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@cMBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                                                          '-----------------------------------------------------') 
END   

--(Wan02) - START
--IF @bInValid = 1
--   GOTO QUIT
--SET @bInValid = 0
--(Wan02) - END
   
DECLARE CUR_MBOL_CONDITION CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
SELECT Code, Description, Long 
FROM   CODELKUP WITH (NOLOCK)
WHERE  ListName = @cMBOLValidationRules
AND    SHORT    = 'STOREDPROC'

OPEN CUR_MBOL_CONDITION

FETCH NEXT FROM CUR_MBOL_CONDITION INTO @cTableName, @cDescription, @c_SPName 

WHILE @@FETCH_STATUS <> -1
BEGIN
   IF EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_SPName) AND type = 'P')  
   BEGIN      
      SET @cSQL = 'EXEC ' + @c_SPName + ' @c_MBOLKey, @cStorerKey, @nSuccess OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT '      
   
      EXEC sp_executesql @cSQL     
         , N'@c_MBOLKey NVARCHAR(10), @cStorerKey NVARCHAR(15), @nSuccess Int OUTPUT, @n_Err Int OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT'      
         , @cMBOLKey      
         , @cStorerKey      
         , @nSuccess    OUTPUT      
         , @n_Err       OUTPUT      
         , @c_ErrMsg    OUTPUT    

      IF @nSuccess <> 1
      BEGIN 
         SET @bInValid = 1      
         CLOSE CUR_MBOL_CONDITION
         DEALLOCATE CUR_MBOL_CONDITION 
         GOTO QUIT
      END 

   END 
   FETCH NEXT FROM CUR_MBOL_CONDITION INTO @cTableName, @cDescription, @c_SPName
END 
CLOSE CUR_MBOL_CONDITION
DEALLOCATE CUR_MBOL_CONDITION 
--(Wan01) - END

--PRINT @cSQL
--PRINT ''
--PRINT @cErrorMsg

QUIT:
IF @bInValid = 1 
   SET @nSuccess = 0 
ELSE
   SET @nSuccess = 1
   
--(Wan02) - START
--ELSE
     --SET @nSuccess = 1                                --(Wan01)
--   SET @cErrorMsg = @c_ErrMsg                         --(Wan01)
--(Wan02) - END

-- End Procedure

GO