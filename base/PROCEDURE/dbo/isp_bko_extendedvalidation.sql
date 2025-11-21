SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: isp_BKO_ExtendedValidation                          */
/* Creation Date: 19-AUG-2014                                           */
/* Copyright: LF                                                        */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: BOOKINGOUT Validation                                       */
/*        : : SOS#322304 - PH - CPPI WMS Door Booking Enhancement       */
/*                                                                      */
/* Called By: ispFinalizeBookingOut                                     */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 19-Jul-2017  JayLim    1.2   Performance tune-reduce cache log (jay01)*/
/************************************************************************/
CREATE PROC [dbo].[isp_BKO_ExtendedValidation] 
      @n_BookingNo            INT 
   ,  @c_BKOValidationRules   NVARCHAR(30)
   ,  @b_Success              INT = 1        OUTPUT 
   ,  @c_ErrMsg               NVARCHAR(250)  OUTPUT 
AS 
DECLARE @b_InValid bit 

DECLARE @c_TableName          NVARCHAR(30) 
      , @c_Description        NVARCHAR(250) 
      , @c_ColumnName         NVARCHAR(250)
      , @n_RecFound           int 
      , @c_Condition          NVARCHAR(1000) 
      , @c_Type               NVARCHAR(10)
      , @c_ColName            NVARCHAR(128) 
      , @c_ColType            NVARCHAR(128)
      , @c_WhereCondition     NVARCHAR(1000)


DECLARE @cSQL nvarchar(Max),
        @cSQLArg nvarchar(max) --(jay01)

SET @b_InValid = 0
SET @c_ErrMsg = ''

DECLARE CUR_BKO_REQUIRED CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
SELECT Code, Description, Long, ISNULL(Notes2,'') 
FROM   CODELKUP WITH (NOLOCK)
WHERE  ListName = @c_BKOValidationRules
AND    SHORT    = 'REQUIRED'
ORDER BY Code

OPEN CUR_BKO_REQUIRED

FETCH NEXT FROM CUR_BKO_REQUIRED INTO @c_TableName, @c_Description, @c_ColumnName, @c_WhereCondition 

WHILE @@FETCH_STATUS <> -1
BEGIN
   SET @n_RecFound = 0 
   
   SET @cSQL = N'SELECT @n_RecFound = COUNT(1)'
             + ' FROM BOOKING_OUT WITH (NOLOCK)'
             + ' LEFT JOIN LOADPLAN WITH (NOLOCK) ON (BOOKING_OUT.BookingNo = LOADPLAN.BookingNo)'
             +                                  ' OR ((BOOKING_OUT.Loadkey = LOADPLAN.Loadkey )'
             +                                  ' AND (ISNULL(BOOKING_OUT.Loadkey,'''') <> '''')'
             +                                  ' AND (ISNULL(BOOKING_OUT.Loadkey,'''') <> ''MULTI''))'
             + ' LEFT JOIN MBOL     WITH (NOLOCK) ON (BOOKING_OUT.MBOLKey = MBOL.MBOLKey)'
             +                                  ' AND(ISNULL(BOOKING_OUT.MBOLKey,'''') <> '''')'
             +                                  ' AND(ISNULL(BOOKING_OUT.MBOLKey,'''') <> ''MULTI'')'
             + ' WHERE BOOKING_OUT.BookingNo =   @n_BookingNo ' --(jay01)
 
    
   -- Get Column Type
   SET @c_TableName = LEFT(@c_ColumnName, CharIndex('.', @c_ColumnName) - 1)
   SET @c_ColName   = SUBSTRING(@c_ColumnName, 
                     CharIndex('.', @c_ColumnName) + 1, LEN(@c_ColumnName) - CharIndex('.', @c_ColumnName))

   SET @c_ColType = ''
   SELECT @c_ColType = DATA_TYPE 
   FROM   INFORMATION_SCHEMA.COLUMNS 
   WHERE  TABLE_NAME = @c_TableName
   AND    COLUMN_NAME = @c_ColName

   IF ISNULL(RTRIM(@c_ColType), '') = '' 
   BEGIN
      SET @b_InValid = 1 
      SET @c_ErrMsg = 'Invalid Column Name: ' + @c_ColumnName 
      GOTO QUIT
   END 

   IF @c_ColType IN ('char', 'nvarchar', 'varchar') 
      SET @cSQL = @cSQL + master.dbo.fnc_GetCharASCII(13) + ' AND (ISNULL(RTRIM(' + @c_ColumnName + '),'''') = '''' '
   ELSE IF @c_ColType IN ('float', 'money', 'int', 'decimal', 'numeric', 'tinyint', 'real', 'bigint')
      SET @cSQL = @cSQL + master.dbo.fnc_GetCharASCII(13) + ' AND (' + @c_ColumnName + ' = 0 '
         
   SET @cSQL = @cSQL + master.dbo.fnc_GetCharASCII(13) + CASE WHEN LEFT(LTRIM(@c_WhereCondition),3) NOT IN ('AND','OR ') AND ISNULL(@c_WhereCondition,'') <> '' THEN ' AND ' ELSE ' ' END + RTRIM(@c_WhereCondition) + ')'       

   --(jay01)
   SET @cSQLArg = N'@n_RecFound int OUTPUT, '
                  +'@n_BookingNo INT  '

   EXEC sp_executesql @cSQL, @cSQLArg , @n_RecFound OUTPUT, @n_BookingNo --(jay01)

   IF @n_RecFound > 0  
   BEGIN 
      SET @b_InValid = 1 
      IF @c_TableName IN ('BOOKING_OUT')
         SET @c_ErrMsg = RTRIM(@c_ErrMsg) + 'Booking #: ' + CONVERT(NVARCHAR(10), @n_BookingNo) + '. ' + RTRIM(@c_Description) + ' Is Required! ' + master.dbo.fnc_GetCharASCII(13)
      ELSE
         SET @c_ErrMsg = RTRIM(@c_ErrMsg) + RTRIM(@c_Description) + ' Is Required! ' + master.dbo.fnc_GetCharASCII(13)
      
   END 

   FETCH NEXT FROM CUR_BKO_REQUIRED INTO @c_TableName, @c_Description, @c_ColumnName, @c_WhereCondition  
END 
CLOSE CUR_BKO_REQUIRED
DEALLOCATE CUR_BKO_REQUIRED 

IF @b_InValid = 1
   GOTO QUIT

----------- Check Condition ------

SET @b_InValid = 0 

DECLARE CUR_BKO_CONDITION CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
SELECT Code, Description, Long, ISNULL(Notes,''), SHORT, ISNULL(Notes2,'')  
FROM   CODELKUP WITH (NOLOCK)
WHERE  ListName = @c_BKOValidationRules
AND    SHORT    IN ('CONDITION', 'CONTAINS')

OPEN CUR_BKO_CONDITION

FETCH NEXT FROM CUR_BKO_CONDITION INTO @c_TableName, @c_Description, @c_ColumnName, @c_Condition, @c_Type, @c_WhereCondition  

WHILE @@FETCH_STATUS <> -1
BEGIN   
   SET @cSQL = N'SELECT @n_RecFound = COUNT(1)'
             + ' FROM BOOKING_OUT WITH (NOLOCK)' 
             + ' LEFT JOIN LOADPLAN WITH (NOLOCK) ON (BOOKING_OUT.BookingNo = LOADPLAN.BookingNo)'
             +                                  ' OR ((BOOKING_OUT.Loadkey = LOADPLAN.Loadkey )'
             +                                  ' AND (ISNULL(BOOKING_OUT.Loadkey,'''') <> '''')'
             +                                  ' AND (ISNULL(BOOKING_OUT.Loadkey,'''') <> ''MULTI''))'
             + ' LEFT JOIN MBOL     WITH (NOLOCK) ON (BOOKING_OUT.MBOLKey = MBOL.MBOLKey)'
             +                                  ' AND(ISNULL(BOOKING_OUT.MBOLKey,'''') <> '''')'
             +                                  ' AND(ISNULL(BOOKING_OUT.MBOLKey,'''') <> ''MULTI'')'

             + ' WHERE BOOKING_OUT.BookingNo =   @n_BookingNo ' --(jay01)

   IF @c_Type = 'CONDITION'
      IF ISNULL(@c_Condition,'') <> ''
      BEGIN
         SET @c_Condition = REPLACE(LEFT(@c_Condition,5),'AND ','AND (') + SUBSTRING(@c_Condition,6,LEN(@c_Condition)-5)
         SET @c_Condition = REPLACE(LEFT(@c_Condition,4),'OR ','OR (') + SUBSTRING(@c_Condition,5,LEN(@c_Condition)-4)
         SET @cSQL = @cSQL + master.dbo.fnc_GetCharASCII(13) + CASE WHEN LEFT(LTRIM(@c_Condition),3) NOT IN ('AND','OR ') AND ISNULL(@c_Condition,'') <> '' THEN ' AND (' ELSE ' ' END + RTRIM(@c_Condition)
         SET @cSQL = @cSQL + master.dbo.fnc_GetCharASCII(13) + CASE WHEN LEFT(LTRIM(@c_WhereCondition),3) NOT IN ('AND','OR ') AND ISNULL(@c_WhereCondition,'') <> '' THEN ' AND ' ELSE ' ' END + RTRIM(@c_WhereCondition) + ')'
      END 
      ELSE
      BEGIN
         IF ISNULL(@c_WhereCondition,'') <> ''
         BEGIN
      	   SET @c_WhereCondition = REPLACE(LEFT(@c_WhereCondition,5),'AND ','AND (') + SUBSTRING(@c_WhereCondition,6,LEN(@c_WhereCondition)-5)
      	   SET @c_WhereCondition = REPLACE(LEFT(@c_WhereCondition,4),'OR ','OR (') + SUBSTRING(@c_WhereCondition,5,LEN(@c_WhereCondition)-4)
            SET @cSQL = @cSQL + master.dbo.fnc_GetCharASCII(13) + CASE WHEN LEFT(LTRIM(@c_WhereCondition),3) NOT IN ('AND','OR ') AND ISNULL(@c_WhereCondition,'') <> '' THEN ' AND (' ELSE ' ' END + RTRIM(@c_WhereCondition) + ')'
         END
      END
   ELSE
   BEGIN --CONTAINS
      IF ISNULL(@c_Condition,'') <> ''
      BEGIN
         SET @cSQL = @cSQL + master.dbo.fnc_GetCharASCII(13) + ' AND (' + @c_ColumnName + ' IN (' + ISNULL(RTRIM(@c_Condition),'') + ')' 
         SET @cSQL = @cSQL + master.dbo.fnc_GetCharASCII(13) + CASE WHEN LEFT(LTRIM(@c_WhereCondition),3) NOT IN ('AND','OR ') AND ISNULL(@c_WhereCondition,'') <> '' THEN ' AND ' ELSE ' ' END + RTRIM(@c_WhereCondition) + ')'
      END
      ELSE
      BEGIN
         IF ISNULL(@c_WhereCondition,'') <> ''
         BEGIN
            SET @c_WhereCondition = REPLACE(LEFT(@c_WhereCondition,5),'AND ','AND (') + SUBSTRING(@c_WhereCondition,6,LEN(@c_WhereCondition)-5)
            SET @c_WhereCondition = REPLACE(LEFT(@c_WhereCondition,4),'OR ','OR (') + SUBSTRING(@c_WhereCondition,5,LEN(@c_WhereCondition)-4)
            SET @cSQL = @cSQL + master.dbo.fnc_GetCharASCII(13) + CASE WHEN LEFT(LTRIM(@c_WhereCondition),3) NOT IN ('AND','OR ') AND ISNULL(@c_WhereCondition,'') <> '' THEN ' AND (' ELSE ' ' END + RTRIM(@c_WhereCondition) + ')'
         END
      END                   
   END    

   --(jay01)
   SET @cSQLArg = N'@n_RecFound int OUTPUT, '
                  +'@n_BookingNo INT  '

   EXEC sp_executesql @cSQL, @cSQLArg , @n_RecFound OUTPUT , @n_BookingNo --(jay01)

   IF @n_RecFound = 0 AND @c_Type <> 'CONDITION'
   BEGIN 
      SET @b_InValid = 1 
      SET @c_ErrMsg = @c_ErrMsg + RTRIM(@c_Description) + ' Is Invalid! ' + master.dbo.fnc_GetCharASCII(13)
   END 
   ELSE
   IF @n_RecFound > 0 AND @c_Type = 'CONDITION' AND @c_ColumnName = 'NOT EXISTS' 
   BEGIN 
      SET @b_InValid = 1 
      
      IF CharIndex('BOOKING_OUT', @c_Condition) > 0    
         SET @c_ErrMsg = RTRIM(@c_ErrMsg) + 'Booking #: ' + CONVERT(NVARCHAR(10), @n_BookingNo) + '. '  + RTRIM(@c_Description) + ' Found! ' + master.dbo.fnc_GetCharASCII(13)
      ELSE
         SET @c_ErrMsg = @c_ErrMsg + RTRIM(@c_Description) + ' Found! ' + master.dbo.fnc_GetCharASCII(13)
   END 
   ELSE
   IF @n_RecFound = 0 AND @c_Type = 'CONDITION' AND 
      (ISNULL(RTRIM(@c_ColumnName),'') = '' OR @c_ColumnName = 'EXISTS')  
   BEGIN 
      SET @b_InValid = 1 
      SET @c_ErrMsg = @c_ErrMsg + RTRIM(@c_Description) + ' Not Found! ' + master.dbo.fnc_GetCharASCII(13)
   END 
   
   FETCH NEXT FROM CUR_BKO_CONDITION INTO @c_TableName, @c_Description, @c_ColumnName, @c_Condition, @c_Type, @c_WhereCondition  
END 
CLOSE CUR_BKO_CONDITION
DEALLOCATE CUR_BKO_CONDITION 


QUIT:
IF @b_InValid = 1 
   SET @b_Success = 0 
ELSE
   SET @b_Success = 1

-- End Procedure

GO