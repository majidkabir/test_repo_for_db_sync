SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure: isp_Allocate_ExtendedValidation                     */
/* Creation Date:                                                       */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: Allocation Validation SOS#353920                            */
/*                                                                      */
/* Called By: Allocation                                                */
/*                                                                      */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 19-Jul-2017  JayLim    1.2   Performance tune-reduce cache log (jay01)*/
/* 03-Jul-2018  SPChin    1.3   INC0229170 - Bug Fixed                  */
/************************************************************************/

CREATE PROC [dbo].[isp_Allocate_ExtendedValidation] 
   @c_Orderkey   NVARCHAR(10) = '', 
   @c_Loadkey    NVARCHAR(10) = '',
   @c_Wavekey    NVARCHAR(10) = '',
   @c_AllocateValidationRules NVARCHAR(30), 
   @c_Mode       NVARCHAR(10) = 'PRE',  -- PRE/POST 
   @b_Success    INT = 1       OUTPUT, 
   @c_ErrMsg     NVARCHAR(250) = '' OUTPUT 
AS 
DECLARE @b_InValid bit 

DECLARE @c_TableName   NVARCHAR(30), 
        @c_Description NVARCHAR(250), 
        @c_ColumnName  NVARCHAR(250),
        @n_RecFound    INT, 
        @c_Condition   NVARCHAR(4000), 
        @c_Type        NVARCHAR(10),
        @c_ColName     NVARCHAR(128), 
        @c_ColType     NVARCHAR(128),
        @c_WhereCondition   NVARCHAR(4000),
        @c_SPName           NVARCHAR(100), 
        @c_SQL         NVARCHAR(Max),
        @c_SQLArg      NVARCHAR(Max), --(jay01)
        @c_OrderLineNumber  NVARCHAR(5),
        @c_Orderkey2   NVARCHAR(10),
        @n_Err         INT 

SELECT @b_InValid = 0, @c_ErrMsg = '', @n_Err = 0, @b_Success = 1

DECLARE CUR_ALLOCATE_REQUIRED CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
SELECT Code, Description, Long, ISNULL(Notes2,'') 
FROM   CODELKUP WITH (NOLOCK)
WHERE  ListName = @c_AllocateValidationRules
AND    SHORT    = 'REQUIRED'
ORDER BY Code

OPEN CUR_ALLOCATE_REQUIRED

FETCH NEXT FROM CUR_ALLOCATE_REQUIRED INTO @c_TableName, @c_Description, @c_ColumnName, @c_WhereCondition 

WHILE @@FETCH_STATUS <> -1
BEGIN
   SET @n_RecFound = 0 

   --(jay01)
   SET @c_SQL = N'SELECT @n_RecFound = COUNT(1), @c_Orderkey2 = MIN(ORDERS.Orderkey), '
                +' @c_OrderLineNumber = MIN(ORDERDETAIL.OrderLineNumber) '
                +'FROM ORDERS (NOLOCK) '
                +'JOIN ORDERDETAIL WITH (NOLOCK) ON ORDERS.Orderkey = ORDERDETAIL.OrderKey '
                +'JOIN SKU WITH (NOLOCK) ON ORDERDETAIL.Storerkey = SKU.Storerkey AND ORDERDETAIL.Sku = SKU.Sku '
                +'JOIN PACK WITH (NOLOCK) ON SKU.Packkey = PACK.Packkey '       
                +'LEFT JOIN LOADPLAN WITH (NOLOCK) ON ORDERS.Loadkey = LOADPLAN.Loadkey '
                +'LEFT JOIN WAVE WITH (NOLOCK) ON ORDERS.Userdefine09 = WAVE.Wavekey '
                +'LEFT JOIN PICKDETAIL WITH (NOLOCK) ON ORDERDETAIL.Orderkey = PICKDETAIL.Orderkey '
                +                      ' AND ORDERDETAIL.OrderLineNumber = PICKDETAIL.OrderLineNumber '
                +'LEFT JOIN LOTATTRIBUTE WITH (NOLOCK) ON PICKDETAIL.Lot = LOTATTRIBUTE.Lot '
                +'LEFT JOIN LOC WITH (NOLOCK) ON PICKDETAIL.Loc = LOC.Loc '
                +'LEFT JOIN LOT WITH (NOLOCK) ON PICKDETAIL.Lot = LOT.Lot '
                +'LEFT JOIN ID WITH (NOLOCK) ON PICKDETAIL.ID = ID.Id '
                +'LEFT JOIN SKUXLOC WITH (NOLOCK) ON PICKDETAIL.Storerkey = SKUXLOC.Storerkey '
                +                       ' AND PICKDETAIL.Sku = SKUXLOC.Sku AND PICKDETAIL.Loc = SKUXLOC.Loc '
                +'LEFT JOIN LOTXLOCXID WITH (NOLOCK) ON PICKDETAIL.Lot = LOTXLOCXID.Lot '
                +                       ' AND PICKDETAIL.Loc = LOTXLOCXID.Loc AND PICKDETAIL.ID = LOTXLOCXID.ID '
   
   IF ISNULL(@c_Orderkey,'') <> '' 
   BEGIN
   	   SET @c_SQL = RTRIM(@c_SQL) + ' WHERE ORDERS.OrderKey = @c_OrderKey ' --(jay01)
   END
   ELSE IF ISNULL(@c_Loadkey,'') <> ''
   BEGIN
   	   SET @c_SQL = RTRIM(@c_SQL) + ' WHERE ORDERS.Loadkey = @c_LoadKey ' --(jay01)
   END
   ELSE IF ISNULL(@c_WaveKey,'') <> '' --INC0229170
   BEGIN
   	   SET @c_SQL = RTRIM(@c_SQL) + ' WHERE ORDERS.Userdefine09 = @c_WaveKey ' --(jay01)
   END
          
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
      CLOSE CUR_ALLOCATE_REQUIRED
      DEALLOCATE CUR_ALLOCATE_REQUIRED 
      GOTO QUIT
   END 

   IF @c_ColType IN ('char', 'nvarchar', 'varchar') 
      SET @c_SQL = @c_SQL + master.dbo.fnc_GetCharASCII(13) + ' AND ISNULL(RTRIM(' + @c_ColumnName + '),'''') = '''' '
   ELSE IF @c_ColType IN ('float', 'money', 'int', 'decimal', 'numeric', 'tinyint', 'real', 'bigint')
      SET @c_SQL = @c_SQL + master.dbo.fnc_GetCharASCII(13) + ' AND ' + @c_ColumnName + ' = 0 '
   ELSE IF @c_ColType IN ('datetime')
      SET @c_SQL = @c_SQL + master.dbo.fnc_GetCharASCII(13) + ' AND (' + @c_ColumnName + ' IS NULL OR CONVERT(NVARCHAR(10),' + @c_ColumnName + ',112) = ''19000101'') '    

   SET @c_SQL = @c_SQL + master.dbo.fnc_GetCharASCII(13) + CASE WHEN LEFT(LTRIM(@c_WhereCondition),3) NOT IN ('AND','OR ') AND ISNULL(@c_WhereCondition,'') <> '' THEN ' AND ' ELSE ' ' END + RTRIM(@c_WhereCondition) --+ ')'       
  
   --(jay01)
   SET @c_SQLArg = N'@n_RecFound int OUTPUT, '
                   +'@c_Orderkey2 nvarchar(10) OUTPUT, '
                   +'@c_OrderLineNumber nvarchar(5) OUTPUT, '
                   +'@c_Orderkey   NVARCHAR(10), '
                   +'@c_Loadkey    NVARCHAR(10), '
                   +'@c_Wavekey    NVARCHAR(10)   '
   
   EXEC sp_executesql @c_SQL, @c_SQLArg, 
                        @n_RecFound OUTPUT, 
                        @c_Orderkey2 OUTPUT, 
                        @c_OrderLineNumber OUTPUT, 
                        @c_Orderkey,
                        @c_Loadkey,
                        @c_Wavekey --(jay01)

   IF @n_RecFound > 0  
   BEGIN 
      SET @b_InValid = 1 
      IF @c_TableName IN ('ORDERDETAIL','SKU','PICKDETAIL','LOTATTRIBUTE','LOT','LOC','ID','PACK','SKUXLOC','LOTXLOCXID')
         SET @c_ErrMsg = RTRIM(@c_ErrMsg) + 'Order# ' + RTRIM(@c_Orderkey2) + ' Line# ' + RTRIM(@c_OrderLineNumber) + '. ' + RTRIM(@c_Description) + ' Is Required! ' + master.dbo.fnc_GetCharASCII(13)
      ELSE
         SET @c_ErrMsg = RTRIM(@c_ErrMsg) + 'Order# ' + RTRIM(@c_Orderkey2) + '. ' + RTRIM(@c_Description) + ' Is Required! ' + master.dbo.fnc_GetCharASCII(13)
   END 

   IF @b_InValid = 1
   BEGIN
      CLOSE CUR_ALLOCATE_REQUIRED
      DEALLOCATE CUR_ALLOCATE_REQUIRED 
      GOTO QUIT
   END

   FETCH NEXT FROM CUR_ALLOCATE_REQUIRED INTO @c_TableName, @c_Description, @c_ColumnName, @c_WhereCondition  
END 
CLOSE CUR_ALLOCATE_REQUIRED
DEALLOCATE CUR_ALLOCATE_REQUIRED 

----------- Check Condition ------

SET @b_InValid = 0 

DECLARE CUR_ALLOCATE_CONDITION CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
SELECT Code, Description, Long, Notes, SHORT, ISNULL(Notes2,'')   
FROM   CODELKUP WITH (NOLOCK)
WHERE  ListName = @c_AllocateValidationRules
AND    SHORT    IN ('CONDITION', 'CONTAINS')

OPEN CUR_ALLOCATE_CONDITION

FETCH NEXT FROM CUR_ALLOCATE_CONDITION INTO @c_TableName, @c_Description, @c_ColumnName, @c_Condition, @c_Type, @c_WhereCondition   

WHILE @@FETCH_STATUS <> -1
BEGIN
   SET @c_SQL = N'SELECT @n_RecFound = COUNT(1), @c_Orderkey2 = MIN(ORDERS.Orderkey), '
                +' @c_OrderLineNumber = MIN(ORDERDETAIL.OrderLineNumber) '
                +'FROM ORDERS (NOLOCK) '
                +'JOIN ORDERDETAIL WITH (NOLOCK) ON ORDERS.Orderkey = ORDERDETAIL.OrderKey '
                +'JOIN SKU WITH (NOLOCK) ON ORDERDETAIL.Storerkey = SKU.Storerkey AND ORDERDETAIL.Sku = SKU.Sku '
                +'JOIN PACK WITH (NOLOCK) ON SKU.Packkey = PACK.Packkey        '
                +'LEFT JOIN LOADPLAN WITH (NOLOCK) ON ORDERS.Loadkey = LOADPLAN.Loadkey '
                +'LEFT JOIN WAVE WITH (NOLOCK) ON ORDERS.Userdefine09 = WAVE.Wavekey '
                +'LEFT JOIN PICKDETAIL WITH (NOLOCK) ON ORDERDETAIL.Orderkey = PICKDETAIL.Orderkey '
                +                            ' AND ORDERDETAIL.OrderLineNumber = PICKDETAIL.OrderLineNumber '
                +'LEFT JOIN LOTATTRIBUTE WITH (NOLOCK) ON PICKDETAIL.Lot = LOTATTRIBUTE.Lot '
                +'LEFT JOIN LOC WITH (NOLOCK) ON PICKDETAIL.Loc = LOC.Loc '
                +'LEFT JOIN LOT WITH (NOLOCK) ON PICKDETAIL.Lot = LOT.Lot '
                +'LEFT JOIN ID WITH (NOLOCK) ON PICKDETAIL.ID = ID.Id '
                +'LEFT JOIN SKUXLOC WITH (NOLOCK) ON PICKDETAIL.Storerkey = SKUXLOC.Storerkey '
                +                            ' AND PICKDETAIL.Sku = SKUXLOC.Sku AND PICKDETAIL.Loc = SKUXLOC.Loc '
                +'LEFT JOIN LOTXLOCXID WITH (NOLOCK) ON PICKDETAIL.Lot = LOTXLOCXID.Lot '
                +                            ' AND PICKDETAIL.Loc = LOTXLOCXID.Loc AND PICKDETAIL.ID = LOTXLOCXID.ID '
   
   IF ISNULL(@c_Orderkey,'') <> '' 
   BEGIN
   	   SET @c_SQL = RTRIM(@c_SQL) + ' WHERE ORDERS.OrderKey = @c_OrderKey '
   END
   ELSE IF ISNULL(@c_Loadkey,'') <> ''
   BEGIN
   	   SET @c_SQL = RTRIM(@c_SQL) + ' WHERE ORDERS.Loadkey = @c_LoadKey '
   END
   ELSE IF ISNULL(@c_WaveKey,'') <> '' --INC0229170
   BEGIN
   	   SET @c_SQL = RTRIM(@c_SQL) + ' WHERE ORDERS.Userdefine09 = @c_WaveKey '
   END   
   
   IF @c_Type = 'CONDITION'
      IF ISNULL(@c_Condition,'') <> ''
      BEGIN
          SET @c_Condition = REPLACE(LEFT(@c_Condition,5),'AND ','AND (') + SUBSTRING(@c_Condition,6,LEN(@c_Condition)-5)
          SET @c_Condition = REPLACE(LEFT(@c_Condition,4),'OR ','OR (') + SUBSTRING(@c_Condition,5,LEN(@c_Condition)-4)
          SET @c_SQL = @c_SQL + master.dbo.fnc_GetCharASCII(13) + CASE WHEN LEFT(LTRIM(@c_Condition),3) NOT IN ('AND','OR ') AND ISNULL(@c_Condition,'') <> '' THEN ' AND (' ELSE ' ' END + RTRIM(@c_Condition)
          SET @c_SQL = @c_SQL + master.dbo.fnc_GetCharASCII(13) + CASE WHEN LEFT(LTRIM(@c_WhereCondition),3) NOT IN ('AND','OR ') AND ISNULL(@c_WhereCondition,'') <> '' THEN ' AND ' ELSE ' ' END + RTRIM(@c_WhereCondition) + ')'
      END 
      ELSE
      BEGIN
          IF ISNULL(@c_WhereCondition,'') <> ''
          BEGIN
            SET @c_WhereCondition = REPLACE(LEFT(@c_WhereCondition,5),'AND ','AND (') + SUBSTRING(@c_WhereCondition,6,LEN(@c_WhereCondition)-5)
            SET @c_WhereCondition = REPLACE(LEFT(@c_WhereCondition,4),'OR ','OR (') + SUBSTRING(@c_WhereCondition,5,LEN(@c_WhereCondition)-4)
            SET @c_SQL = @c_SQL + master.dbo.fnc_GetCharASCII(13) + CASE WHEN LEFT(LTRIM(@c_WhereCondition),3) NOT IN ('AND','OR ') AND ISNULL(@c_WhereCondition,'') <> '' THEN ' AND (' ELSE ' ' END + RTRIM(@c_WhereCondition) + ')'
         END
      END
   ELSE
   BEGIN --CONTAINS
      IF ISNULL(@c_Condition,'') <> ''
      BEGIN
         SET @c_SQL = @c_SQL + master.dbo.fnc_GetCharASCII(13) + ' AND (' + @c_ColumnName + ' IN (' + ISNULL(RTRIM(@c_Condition),'') + ')' 
         SET @c_SQL = @c_SQL + master.dbo.fnc_GetCharASCII(13) + CASE WHEN LEFT(LTRIM(@c_WhereCondition),3) NOT IN ('AND','OR ') AND ISNULL(@c_WhereCondition,'') <> '' THEN ' AND ' ELSE ' ' END + RTRIM(@c_WhereCondition) + ')'
      END
      ELSE
      BEGIN
          IF ISNULL(@c_WhereCondition,'') <> ''
          BEGIN
            SET @c_WhereCondition = REPLACE(LEFT(@c_WhereCondition,5),'AND ','AND (') + SUBSTRING(@c_WhereCondition,6,LEN(@c_WhereCondition)-5)
            SET @c_WhereCondition = REPLACE(LEFT(@c_WhereCondition,4),'OR ','OR (') + SUBSTRING(@c_WhereCondition,5,LEN(@c_WhereCondition)-4)
            SET @c_SQL = @c_SQL + master.dbo.fnc_GetCharASCII(13) + CASE WHEN LEFT(LTRIM(@c_WhereCondition),3) NOT IN ('AND','OR ') AND ISNULL(@c_WhereCondition,'') <> '' THEN ' AND (' ELSE ' ' END + RTRIM(@c_WhereCondition) + ')'
         END
      END                   
   END 

   --(jay01)
   SET @c_SQLArg = N'@n_RecFound int OUTPUT, '
                   +'@c_Orderkey2 nvarchar(10) OUTPUT, '
                   +'@c_OrderLineNumber nvarchar(5) OUTPUT, '
                   +'@c_Orderkey   NVARCHAR(10) , '
                   +'@c_Loadkey    NVARCHAR(10) , '
                   +'@c_Wavekey    NVARCHAR(10)   '

   EXEC sp_executesql @c_SQL, @c_SQLArg, 
                     @n_RecFound OUTPUT, 
                     @c_Orderkey2 OUTPUT, 
                     @c_OrderLineNumber OUTPUT, 
                     @c_Orderkey,
                     @c_Loadkey,
                     @c_Wavekey --(jay01)

   IF @n_RecFound = 0 AND @c_Type <> 'CONDITION'
   BEGIN 
      SET @b_InValid = 1 
      IF ISNULL(@c_Orderkey,'') <> ''
         SET @c_ErrMsg = @c_ErrMsg + 'Order# ' + RTRIM(@c_Orderkey) + '. ' + RTRIM(@c_Description) + ' Is Invalid! ' + master.dbo.fnc_GetCharASCII(13)
      ELSE IF ISNULL(@c_Loadkey,'') <> ''
         SET @c_ErrMsg = @c_ErrMsg + 'Load# ' + RTRIM(@c_Loadkey) + '. ' + RTRIM(@c_Description) + ' Is Invalid! ' + master.dbo.fnc_GetCharASCII(13)
      ELSE IF ISNULL(@c_Wavekey,'') <> ''
         SET @c_ErrMsg = @c_ErrMsg + 'Wave# ' + RTRIM(@c_Wavekey) + '. ' + RTRIM(@c_Description) + ' Is Invalid! ' + master.dbo.fnc_GetCharASCII(13)
      ELSE
         SET @c_ErrMsg = @c_ErrMsg + RTRIM(@c_Description) + ' Is Invalid! ' + master.dbo.fnc_GetCharASCII(13)         
   END 
   ELSE
   IF @n_RecFound > 0 AND @c_Type = 'CONDITION' AND @c_ColumnName = 'NOT EXISTS' 
   BEGIN 
      SET @b_InValid = 1 

      IF CharIndex('ORDERDETAIL', @c_Condition) > 0 OR CharIndex('SKU', @c_Condition) > 0 OR CharIndex('PICKDETAIL', @c_Condition) > 0 OR
         CharIndex('LOTATTRIBUTE', @c_Condition) > 0 OR CharIndex('LOT', @c_Condition) > 0 OR CharIndex('LOC', @c_Condition) > 0 OR
         CharIndex('ID', @c_Condition) > 0 OR CharIndex('PACK', @c_Condition) > 0 OR CharIndex('SKUXLOC', @c_Condition) > 0 OR 
         CharIndex('LOTXLOCXID', @c_Condition) > 0
         SET @c_ErrMsg = RTRIM(@c_ErrMsg) + 'Order# ' + RTRIM(@c_Orderkey2) + ' Line# ' + RTRIM(@c_OrderLineNumber) + '. ' + RTRIM(@c_Description) + ' Found! ' + master.dbo.fnc_GetCharASCII(13)
      ELSE
         SET @c_ErrMsg = RTRIM(@c_ErrMsg) + 'Order# ' + RTRIM(@c_Orderkey2) + '. ' + RTRIM(@c_Description) + ' Found! ' + master.dbo.fnc_GetCharASCII(13)
   END 
   ELSE
   IF @n_RecFound = 0 AND @c_Type = 'CONDITION' AND 
      (ISNULL(RTRIM(@c_ColumnName),'') = '' OR @c_ColumnName = 'EXISTS')  
   BEGIN 
      SET @b_InValid = 1 
      IF ISNULL(@c_Orderkey,'') <> ''
         SET @c_ErrMsg = @c_ErrMsg + 'Order# ' + RTRIM(@c_Orderkey) + '. ' + RTRIM(@c_Description) + ' Not Found! ' + master.dbo.fnc_GetCharASCII(13)
      ELSE IF ISNULL(@c_Loadkey,'') <> ''
         SET @c_ErrMsg = @c_ErrMsg + 'Load# ' + RTRIM(@c_Loadkey) + '. ' + RTRIM(@c_Description) + ' Not Found! ' + master.dbo.fnc_GetCharASCII(13)
      ELSE IF ISNULL(@c_Wavekey,'') <> ''
         SET @c_ErrMsg = @c_ErrMsg + 'Wave# ' + RTRIM(@c_Wavekey) + '. ' + RTRIM(@c_Description) + ' Not Found! ' + master.dbo.fnc_GetCharASCII(13)
      ELSE   
         SET @c_ErrMsg = @c_ErrMsg + RTRIM(@c_Description) + ' Not Found! ' + master.dbo.fnc_GetCharASCII(13)
   END 
   
   IF @b_InValid = 1
   BEGIN
      CLOSE CUR_ALLOCATE_CONDITION
      DEALLOCATE CUR_ALLOCATE_CONDITION 
      GOTO QUIT
   END
   
   FETCH NEXT FROM CUR_ALLOCATE_CONDITION INTO @c_TableName, @c_Description, @c_ColumnName, @c_Condition, @c_Type, @c_WhereCondition  
END 
CLOSE CUR_ALLOCATE_CONDITION
DEALLOCATE CUR_ALLOCATE_CONDITION 

DECLARE CUR_ALLOCATE_SPCONDITION CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
SELECT Code, Description, Long 
FROM   CODELKUP WITH (NOLOCK)
WHERE  ListName = @c_AllocateValidationRules
AND    SHORT    = 'STOREDPROC'

OPEN CUR_ALLOCATE_SPCONDITION

FETCH NEXT FROM CUR_ALLOCATE_SPCONDITION INTO @c_TableName, @c_Description, @c_SPName 

WHILE @@FETCH_STATUS <> -1
BEGIN
   IF EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_SPName) AND type = 'P')  
   BEGIN      

      SET @c_SQL = 'EXEC ' + @c_SPName+ ' @c_Orderkey, @c_Loadkey, @c_Wavekey, @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT '          
      EXEC sp_executesql @c_SQL,          
           N'@c_OrderKey NVARCHAR(10), @c_LoadKey NVARCHAR(10), @c_WaveKey NVARCHAR(10), @b_Success INT OUTPUT, @n_Err INT OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT',                         
           @c_Orderkey,          
           @c_Loadkey,
           @c_Wavekey,
           @b_Success OUTPUT,          
           @n_Err OUTPUT,          
           @c_ErrMsg OUTPUT
   END
   
   IF @b_Success <> 1
   BEGIN 
      SET @b_InValid = 1      
      CLOSE CUR_ALLOCATE_SPCONDITION
      DEALLOCATE CUR_ALLOCATE_SPCONDITION 
      GOTO QUIT
   END 

   FETCH NEXT FROM CUR_ALLOCATE_SPCONDITION INTO @c_TableName, @c_Description, @c_SPName
END 
CLOSE CUR_ALLOCATE_SPCONDITION
DEALLOCATE CUR_ALLOCATE_SPCONDITION 

--PRINT @c_SQL
--PRINT ''
--PRINT @c_ErrMsg

QUIT:
IF @b_InValid = 1 
   SET @b_Success = 0 
ELSE
   SET @b_Success = 1

-- End Procedure

GO