SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure: isp_MOVE_ExtendedValidation                         */
/* Creation Date:                                                       */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: SOS#334061 - Project Merlion - GW - WMS_Move_Check          */
/*                                                                      */
/* Called By: nspItrnAddMove                                            */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver.  Purposes                                  */
/* 22-Oct-2015  YTWan   1.1   Return RDT Message (Wan01)                */
/* 07-Apr-2016  Wan02   1.2   Add ToLoc for Extended validation test    */
/* 27-Oct-2016  Shong   1.3   Add Set option                            */
/* 16-Jan-2017  TLTING01 1.3  Performance Tuning                        */
/************************************************************************/

CREATE PROC [dbo].[isp_MOVE_ExtendedValidation] 
      @c_Lot                  NVARCHAR(10)  
   ,  @c_FromLoc              NVARCHAR(10)
   ,  @c_FromID               NVARCHAR(18)
   ,  @c_MoveValidationRules  NVARCHAR(30) 
   ,  @b_Success              INT = 1        OUTPUT  
   ,  @c_ErrMsg               NVARCHAR(250)  OUTPUT
   ,  @c_ToLoc                NVARCHAR(18)  = ''         --(Wan02)
AS 
BEGIN 
SET NOCOUNT ON      
SET ANSI_NULLS OFF      
SET QUOTED_IDENTIFIER OFF      
SET CONCAT_NULL_YIELDS_NULL OFF     
DECLARE @b_InValid               BIT 
      , @n_Err                   INT

DECLARE @c_TableName             NVARCHAR(30) 
      , @c_Description           NVARCHAR(250) 
      , @c_ColumnName            NVARCHAR(250)
      , @c_RecFound              INT
      , @c_Condition             NVARCHAR(1000) 
      , @c_Type                  NVARCHAR(10)
      , @c_ColName               NVARCHAR(128) 
      , @c_ColType               NVARCHAR(128)
      , @c_WhereCondition        NVARCHAR(1000)
      , @c_SPName                NVARCHAR(100)

      , @c_SQL                   NVARCHAR(Max)
      , @n_GroupBy               INT
      , @c_GroupBy               NVARCHAR(MAX)      
 
      --, @c_ToLoc                 NVARCHAR(10)   --(Wan02)
      , @c_ToID                  NVARCHAR(18) 

      , @n_IsRDT                 INT            --(Wan01)
      , @c_RDTErrMsg             NVARCHAR(14)   --(Wan01)

SET @b_InValid = 0
SET @c_ErrMsg = ''

EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT            --(Wan01)

SELECT TOP 1 @c_ToLoc = ToLoc
      , @c_ToID = ToID
FROM #move

DECLARE CUR_MOVE_REQUIRED CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
SELECT Code, Description, Long, ISNULL(Notes2,'') 
      ,ISNULL(UDF01,'')                         --(Wan01)
FROM   CODELKUP WITH (NOLOCK)
WHERE  ListName = @c_MoveValidationRules
AND    SHORT    = 'REQUIRED'
ORDER BY Code

OPEN CUR_MOVE_REQUIRED

FETCH NEXT FROM CUR_MOVE_REQUIRED INTO @c_TableName, @c_Description, @c_ColumnName, @c_WhereCondition
                                      ,@c_RDTErrMsg   --(Wan01) 
WHILE @@FETCH_STATUS <> -1
BEGIN
   SET @c_RecFound = 0 
   -- TLTING01
   SET @c_SQL =N'SELECT @c_RecFound = COUNT(1)
                 FROM #move 
                 JOIN LOTxLOCxID WITH (NOLOCK) ON  (LOTxLOCxID.LOT = #move.LOT) 
                                               AND (LOTXLOCXID.Loc = #move.FromLoc)
                                               AND (LOTXLOCXID.id  = #move.FromID)
                 JOIN SKUxLOC    WITH (NOLOCK) ON  (SKUxLOC.Storerkey = LOTxLOCxID.Storerkey) 
                                               AND (SKUxLOC.Sku = LOTxLOCxID.Sku)
                                               AND (SKUxLOC.Loc = LOTxLOCxID.Loc) 
                 JOIN LOTATTRIBUTE WITH (NOLOCK)ON (LOTxLOCxID.Lot = LOTATTRIBUTE.Lot)                                              
                 JOIN STORER WITH (NOLOCK) ON (LOTxLOCxID.Storerkey = STORER.Storerkey)
                 JOIN SKU WITH (NOLOCK) ON (LOTxLOCxID.Storerkey = SKU.Storerkey)
                                        AND(LOTxLOCxID.Sku = SKU.Sku)
                 JOIN LOT WITH (NOLOCK) ON (LOTxLOCxID.Lot = LOT.Lot)
                 JOIN LOC WITH (NOLOCK) ON (LOTxLOCxID.Loc = LOC.Loc)
                 JOIN ID  WITH (NOLOCK) ON (LOTxLOCxID.ID = ID.Id)
                 JOIN LOC TOLOC WITH (NOLOCK) ON (TOLOC.Loc = #move.ToLoc)
                 LEFT JOIN ID  TOID  WITH (NOLOCK) ON (TOID.ID   = #move.ToID)
                 WHERE #move.ToLoc <> '''' AND 1 = 1 '

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
      --(Wan01) - START
      IF @n_IsRDT = 1
      BEGIN
         SET @c_ErrMsg = 'Col. not found'
      END
      ELSE
      BEGIN
         SET @c_ErrMsg = 'Invalid Column Name: ' + @c_ColumnName 
      END
      --(Wan02) - END
      GOTO QUIT
   END 

   IF @c_ColType IN ('char', 'nvarchar', 'varchar') 
      SET @c_SQL = @c_SQL + master.dbo.fnc_GetCharASCII(13) + ' AND ISNULL(RTRIM(' + @c_ColumnName + '),'''') = '''' '
   ELSE IF @c_ColType IN ('float', 'money', 'int', 'decimal', 'numeric', 'tinyint', 'real', 'bigint')
      SET @c_SQL = @c_SQL + master.dbo.fnc_GetCharASCII(13) + ' AND ' + @c_ColumnName + ' = 0 '
   --(Wan01) - START (standard check for datetime field)
   ELSE IF @c_ColType IN ('datetime')                          
      SET @c_SQL = @c_SQL + master.dbo.fnc_GetCharASCII(13) + ' AND (' + @c_ColumnName + ' IS NULL OR CONVERT(NVARCHAR(10),' + @c_ColumnName + ',112) = ''19000101'') '    
   --(Wan01) - END
   SET @c_SQL = @c_SQL + master.dbo.fnc_GetCharASCII(13) + CASE WHEN LEFT(LTRIM(@c_WhereCondition),3) NOT IN ('AND','OR ') AND ISNULL(@c_WhereCondition,'') <> '' THEN ' AND ' ELSE ' ' END + RTRIM(@c_WhereCondition) --+ ')'       
  
   EXEC sp_executesql @c_SQL, N'@c_RecFound INT OUTPUT', @c_RecFound OUTPUT

   IF @c_RecFound > 0  
   BEGIN 
      --(Wan01) - START
      SET @b_InValid = 1 
      IF @n_IsRDT = 1
      BEGIN
         SET @c_ErrMsg = @c_RDTErrMsg
      END
      ELSE
      BEGIN
         SET @c_ErrMsg = RTRIM(@c_ErrMsg) + 'Move Inventory - Lot:  ' + RTRIM(@c_Lot) 
                                          + ', From Loc: ' + RTRIM(@c_FromLoc) 
                                          + ', From ID: '  + RTRIM(@c_FromID) 
                                          + ', To Loc: '   + RTRIM(@c_ToLoc) 
                                          + ', To ID: '  + RTRIM(@c_ToID)
                                          + '. ' + RTRIM(@c_Description) + ' Is Required! ' + master.dbo.fnc_GetCharASCII(13)
      END
      --(Wan01) - END
   END 

   FETCH NEXT FROM CUR_MOVE_REQUIRED INTO @c_TableName, @c_Description, @c_ColumnName, @c_WhereCondition
                                        , @c_RDTErrMsg   --(Wan01)  
END 
CLOSE CUR_MOVE_REQUIRED
DEALLOCATE CUR_MOVE_REQUIRED 

IF @b_InValid = 1
   GOTO QUIT

----------- Check Condition ------

SET @b_InValid = 0 

DECLARE CUR_MOVE_CONDITION CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
SELECT Code, Description, Long, Notes, SHORT, ISNULL(Notes2,'')
      ,ISNULL(UDF01,'')                --(Wan01)
FROM   CODELKUP WITH (NOLOCK)
WHERE  ListName = @c_MoveValidationRules
AND    SHORT    IN ('CONDITION', 'CONTAINS')

OPEN CUR_MOVE_CONDITION

FETCH NEXT FROM CUR_MOVE_CONDITION INTO @c_TableName, @c_Description, @c_ColumnName, @c_Condition, @c_Type, @c_WhereCondition
                                      , @c_RDTErrMsg     --(Wan01)   

WHILE @@FETCH_STATUS <> -1
BEGIN
   SET @c_RecFound = 0    
   -- TLTING01
   SET @c_SQL =N'SELECT @c_RecFound = COUNT(1)
                 FROM #move 
                 JOIN LOTxLOCxID WITH (NOLOCK) ON  (LOTxLOCxID.LOT = #move.LOT) 
                                               AND (LOTXLOCXID.Loc = #move.FromLoc)
                                               AND (LOTXLOCXID.id  = #move.FromID)
                 JOIN SKUxLOC    WITH (NOLOCK) ON  (SKUxLOC.Storerkey = LOTxLOCxID.Storerkey) 
                                               AND (SKUxLOC.Sku = LOTxLOCxID.Sku)
                                               AND (SKUxLOC.Loc = LOTxLOCxID.Loc) 
                 JOIN LOTATTRIBUTE WITH (NOLOCK)ON (LOTxLOCxID.Lot = LOTATTRIBUTE.Lot)                                              
                 JOIN STORER WITH (NOLOCK) ON (LOTxLOCxID.Storerkey = STORER.Storerkey)
                 JOIN SKU WITH (NOLOCK) ON (LOTxLOCxID.Storerkey = SKU.Storerkey)
                                        AND(LOTxLOCxID.Sku = SKU.Sku)
                 JOIN LOT WITH (NOLOCK) ON (LOTxLOCxID.Lot = LOT.Lot)
                 JOIN LOC WITH (NOLOCK) ON (LOTxLOCxID.Loc = LOC.Loc)
                 JOIN ID  WITH (NOLOCK) ON (LOTxLOCxID.ID = ID.Id)
                 JOIN LOC TOLOC WITH (NOLOCK) ON (TOLOC.Loc = #move.ToLoc)
                 LEFT JOIN ID  TOID  WITH (NOLOCK) ON (TOID.ID   = #move.ToID)
                 WHERE #move.ToLoc <> '''' AND 1 = 1 '
   
   IF @c_Type = 'CONDITION'
     IF ISNULL(@c_Condition,'') <> ''
     BEGIN
         SET @c_GroupBy = ''
         SET @n_GroupBy = CHARINDEX('GROUP BY',@c_Condition,1)
         IF  @n_GroupBy > 0 
         BEGIN
            SET @c_GroupBy  = SUBSTRING(@c_Condition,@n_GroupBy,LEN(@c_Condition)-@n_GroupBy+1)
            SET @c_Condition = SUBSTRING(@c_Condition,1,@n_GroupBy  - 1)
         END

         SET @c_Condition = REPLACE(LEFT(@c_Condition,5),'AND ','AND (') + SUBSTRING(@c_Condition,6,LEN(@c_Condition)-5)
         SET @c_Condition = REPLACE(LEFT(@c_Condition,4),'OR ','OR (') + SUBSTRING(@c_Condition,5,LEN(@c_Condition)-4)
         SET @c_SQL = @c_SQL + master.dbo.fnc_GetCharASCII(13) + CASE WHEN LEFT(LTRIM(@c_Condition),3) NOT IN ('AND','OR ') AND ISNULL(@c_Condition,'') <> '' THEN ' AND (' ELSE ' ' END + RTRIM(@c_Condition)
         SET @c_SQL = @c_SQL + master.dbo.fnc_GetCharASCII(13) + CASE WHEN LEFT(LTRIM(@c_WhereCondition),3) NOT IN ('AND','OR ') AND ISNULL(@c_WhereCondition,'') <> '' THEN ' AND ' ELSE ' ' END + RTRIM(@c_WhereCondition) + ')'

         SET @c_SQL = @c_SQL + @c_GroupBy
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
      SET @c_GroupBy = ''
      IF ISNULL(@c_WhereCondition,'') <> '' 
      BEGIN
         SET @n_GroupBy = CHARINDEX('GROUP BY',@c_WhereCondition,1)
         IF  @n_GroupBy > 0 
         BEGIN
            SET @c_GroupBy  = SUBSTRING(@c_WhereCondition,@n_GroupBy,LEN(@c_WhereCondition)-@n_GroupBy+1)
            SET @c_WhereCondition = SUBSTRING(@c_WhereCondition,1,@n_GroupBy-1)
         END
      END

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

      SET @c_SQL = @c_SQL + @c_GroupBy
   END 

   EXEC sp_executesql @c_SQL, N'@c_RecFound int OUTPUT', @c_RecFound OUTPUT 

   IF @c_RecFound = 0 AND @c_Type <> 'CONDITION'
   BEGIN 
      SET @b_InValid = 1

      --(Wan01) - START 
      IF @n_IsRDT = 1
      BEGIN
         SET @c_ErrMsg = @c_RDTErrMsg
      END
      ELSE
      BEGIN
         SET @c_ErrMsg = @c_ErrMsg + RTRIM(@c_Description) + ' Is Invalid! ' + master.dbo.fnc_GetCharASCII(13)
      END
      --(Wan01) - END
   END 
   ELSE
   IF @c_RecFound > 0 AND @c_Type = 'CONDITION' AND @c_ColumnName = 'NOT EXISTS' 
   BEGIN 
      SET @b_InValid = 1 
      -- (Wan01) - START
      IF @n_IsRDT = 1
      BEGIN
         SET @c_ErrMsg = @c_RDTErrMsg
      END
      ELSE
      BEGIN
         SET @c_ErrMsg = RTRIM(@c_ErrMsg) + 'Move Inventory - Lot:  ' + RTRIM(@c_Lot) 
                                          + ', From Loc: ' + RTRIM(@c_FromLoc) 
                                          + ', From ID: '  + RTRIM(@c_FromID) 
                                          + ', To Loc: '   + RTRIM(@c_ToLoc) 
                                          + ', To ID: '  + RTRIM(@c_ToID)
                                          + '. ' + RTRIM(@c_Description) + ' Found! ' + master.dbo.fnc_GetCharASCII(13)
      END
      --(Wan01) - End
   END 
   ELSE
   IF @c_RecFound = 0 AND @c_Type = 'CONDITION' AND 
      (ISNULL(RTRIM(@c_ColumnName),'') = '' OR @c_ColumnName = 'EXISTS')  
   BEGIN 
      SET @b_InValid = 1
      --(Wan01) - START
      IF @n_IsRDT = 1
      BEGIN
         SET @c_ErrMsg = @c_RDTErrMsg
      END
      ELSE
      BEGIN
         SET @c_ErrMsg = RTRIM(@c_ErrMsg) + 'Move Inventory - Lot:  ' + RTRIM(@c_Lot) 
                                          + ', From Loc: ' + RTRIM(@c_FromLoc) 
                                          + ', From ID: '  + RTRIM(@c_FromID) 
                                          + ', To Loc: '   + RTRIM(@c_ToLoc) 
                                          + ', To ID: '  + RTRIM(@c_ToID)
                                          + '. ' + RTRIM(@c_Description) + ' Not Found! ' + master.dbo.fnc_GetCharASCII(13)
      END
      --(Wan01) - END
   END 

   FETCH NEXT FROM CUR_MOVE_CONDITION INTO @c_TableName, @c_Description, @c_ColumnName, @c_Condition, @c_Type, @c_WhereCondition
                                          ,@c_RDTErrMsg    
END 
CLOSE CUR_MOVE_CONDITION
DEALLOCATE CUR_MOVE_CONDITION 


IF @b_InValid = 1
   GOTO QUIT

----------- Check STOREDPROC ------
SET @b_InValid = 0 

DECLARE CUR_MOVE_SPCONDITION CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
SELECT Code, Description, Long 
FROM   CODELKUP WITH (NOLOCK)
WHERE  ListName = @c_MoveValidationRules
AND    SHORT    = 'STOREDPROC'

OPEN CUR_MOVE_SPCONDITION

FETCH NEXT FROM CUR_MOVE_SPCONDITION INTO @c_TableName, @c_Description, @c_SPName

WHILE @@FETCH_STATUS <> -1
BEGIN
   IF EXISTS (SELECT 1 FROM dbo.sysobjects (NOLOCK) WHERE name = RTRIM(@c_SPName) AND type = 'P')  
   BEGIN      
      SET @c_SQL = 'EXEC ' + @c_SPName + ' @c_Lot, @c_FromLoc, @c_FromID, @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT '      
   
      EXEC sp_executesql @c_SQL     
         , N'@c_Lot NVARCHAR(10), @c_FromLoc NVARCHAR(10), @c_FromID NVARCHAR(18), @b_Success Int OUTPUT, @n_Err Int OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT'      
         , @c_Lot  
         , @c_FromLoc
         , @c_FromID
         , @b_Success   OUTPUT      
         , @n_Err       OUTPUT      
         , @c_ErrMsg    OUTPUT    

      IF @b_Success <> 1
      BEGIN 
         SET @b_InValid = 1      
         CLOSE CUR_MOVE_SPCONDITION
         DEALLOCATE CUR_MOVE_SPCONDITION 
         GOTO QUIT
      END 
   END 
   FETCH NEXT FROM CUR_MOVE_SPCONDITION INTO @c_TableName, @c_Description, @c_SPName
END 
CLOSE CUR_MOVE_SPCONDITION
DEALLOCATE CUR_MOVE_SPCONDITION 

QUIT:
IF @b_InValid = 1 
   SET @b_Success = 0 
ELSE
   SET @b_Success = 1

END -- End Procedure

GO