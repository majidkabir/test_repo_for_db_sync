SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: isp_PrePack_ExtendedValidation                      */
/* Creation Date: 19-Aug-2019                                           */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: PrePack Extended Validation                                 */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/************************************************************************/

CREATE PROC [dbo].[isp_PrePack_ExtendedValidation] 
   @c_Pickslipno               NVARCHAR(10), 
   @c_PrePACKValidationRules   NVARCHAR(30), 
   @b_Success                  INT = 1       OUTPUT,    -- @b_Success = 0 (Fail), @b_Success = 1 (Success), @b_Success = 2 (Warning)
   @c_ErrMsg                   NVARCHAR(255) OUTPUT,
   @b_IsConso                  INT = 0

AS 
   SET NOCOUNT ON      
   SET ANSI_NULLS OFF      
   SET QUOTED_IDENTIFIER OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF  

DECLARE @bInValid bit 

DECLARE @c_TableName        NVARCHAR(30), 
        @c_Description      NVARCHAR(250), 
        @c_ColumnName       NVARCHAR(250),
        @n_RecFound         INT, 
        @c_Condition        NVARCHAR(1000), 
        @c_Type             NVARCHAR(10),
        @c_ColName          NVARCHAR(128), 
        @c_ColType          NVARCHAR(128),
        @c_SPName           NVARCHAR(100),              
        @n_err              INT,                        
        @c_WhereCondition   NVARCHAR(1000),
        @c_LabelLine        NVARCHAR(5),
        @c_CartonNo         NVARCHAR(5),
        @c_OrderLineNumber  NVARCHAR(5),
        @c_Orderkey         NVARCHAR(10) = '',
        @c_StorerKey        NVARCHAR(15),
        @b_CheckConso       INT = 0,
        @c_GetOrderkey      NVARCHAR(10) = ''

DECLARE @c_SQL nvarchar(Max),
        @c_SQLArg nvarchar(max)

SET @bInValid = 0
SET @c_ErrMsg = ''
SET @c_SPName  = ''                                  
SET @c_ErrMsg  = ''                                  
SET @b_Success = 1        

SELECT @c_GetOrderkey = Orderkey
FROM PICKHEADER (NOLOCK)
WHERE Pickheaderkey = @c_Pickslipno

IF @c_GetOrderkey = ''
BEGIN
   SET @b_CheckConso = 1

   SELECT TOP 1 @c_StorerKey = ORDERS.Storerkey
   FROM LOADPLAN (NOLOCK)
   JOIN LoadPlanDetail (NOLOCK) ON LoadPlanDetail.LoadKey = LoadPlan.LoadKey
   JOIN ORDERS (NOLOCK) ON ORDERS.OrderKey = LoadPlanDetail.OrderKey
   JOIN PICKHEADER (NOLOCK) ON PICKHEADER.ExternOrderKey = LOADPLAN.LoadKey
   WHERE PICKHEADER.Pickheaderkey = @c_Pickslipno
END
ELSE
BEGIN
   SET @b_CheckConso = 0

   SELECT TOP 1 @c_StorerKey = ORDERS.Storerkey
   FROM ORDERS (NOLOCK)
   JOIN PICKHEADER (NOLOCK) ON PICKHEADER.Orderkey = ORDERS.Orderkey
   WHERE PICKHEADER.Pickheaderkey = @c_Pickslipno
END

--Check if validation type match with IsConso status
IF @b_CheckConso <> @b_IsConso
BEGIN
   SET @bInValid = 1 
   SET @c_ErrMsg = 'Validation Type: PrePack ' + CASE WHEN @b_IsConso = 1 THEN '(By Load) ' ELSE '(By Order) ' END  + CHAR(13) +
                   'But the Pick Slip # ' + @c_Pickslipno + ' is ' + CASE WHEN @b_CheckConso = 1 THEN 'by Load ' ELSE 'by Order ' END
   GOTO QUIT
END

DECLARE CUR_PREPACK_REQUIRED CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
SELECT Code, Description, Long, ISNULL(Notes2,'')  
FROM   CODELKUP WITH (NOLOCK)
WHERE  ListName = @c_PrePACKValidationRules
AND    SHORT    = 'REQUIRED'
ORDER BY Code

OPEN CUR_PREPACK_REQUIRED

FETCH NEXT FROM CUR_PREPACK_REQUIRED INTO @c_TableName, @c_Description, @c_ColumnName, @c_WhereCondition 

WHILE @@FETCH_STATUS <> -1
BEGIN
   SET @n_RecFound = 0 
   
   IF @b_IsConso = 1
   BEGIN
      SET @c_SQL = N'SELECT @n_RecFound = COUNT(1), @c_Orderkey = MIN(ORDERS.Orderkey), '
                   +' @c_OrderLineNumber = MIN(ORDERDETAIL.ORDERLINENUMBER) '
                   +' FROM PICKHEADER (NOLOCK) '
                   +' JOIN LOADPLAN (NOLOCK) ON LOADPLAN.Loadkey = PICKHEADER.ExternOrderkey '
                   +' JOIN LOADPLANDETAIL WITH (NOLOCK) ON LOADPLAN.Loadkey = LOADPLANDETAIL.Loadkey '
                   +' JOIN ORDERS WITH (NOLOCK) ON ORDERS.OrderKey = LOADPLANDETAIL.OrderKey '
                   +' JOIN ORDERDETAIL WITH (NOLOCK) ON ORDERS.Orderkey = ORDERDETAIL.Orderkey'
                   +' JOIN SKU WITH (NOLOCK) ON ORDERDETAIL.Storerkey = SKU.Storerkey AND ORDERDETAIL.Sku = SKU.Sku'
                   +' JOIN PICKDETAIL WITH (NOLOCK) ON PICKDETAIL.ORDERKEY = ORDERDETAIL.ORDERKEY AND PICKDETAIL.ORDERLINENUMBER = ORDERDETAIL.ORDERLINENUMBER '
                   +'                              AND PICKDETAIL.SKU = ORDERDETAIL.SKU '
                   +' WHERE PICKHEADER.Pickheaderkey = @c_Pickslipno ' 
                   +' AND ORDERS.StorerKey = @c_StorerKey  '
   END
   ELSE
   BEGIN
      SET @c_SQL = N'SELECT @n_RecFound = COUNT(1), @c_Orderkey = MIN(ORDERS.Orderkey), '
                   +' @c_OrderLineNumber = MIN(ORDERDETAIL.ORDERLINENUMBER) '
                   +' FROM PICKHEADER (NOLOCK) '
                   +' JOIN ORDERS WITH (NOLOCK) ON PICKHEADER.OrderKey = ORDERS.OrderKey '
                   +' JOIN ORDERDETAIL WITH (NOLOCK) ON ORDERS.Orderkey = ORDERDETAIL.Orderkey'
                   +' JOIN LOADPLANDETAIL WITH (NOLOCK) ON ORDERS.Orderkey = LOADPLANDETAIL.Orderkey '
                   +' JOIN LOADPLAN (NOLOCK) ON LOADPLAN.Loadkey = LOADPLANDETAIL.Loadkey '
                   +' JOIN SKU WITH (NOLOCK) ON ORDERDETAIL.Storerkey = SKU.Storerkey AND ORDERDETAIL.Sku = SKU.Sku'
                   +' JOIN PICKDETAIL WITH (NOLOCK) ON PICKDETAIL.ORDERKEY = ORDERDETAIL.ORDERKEY AND PICKDETAIL.ORDERLINENUMBER = ORDERDETAIL.ORDERLINENUMBER '
                   +'                              AND PICKDETAIL.SKU = ORDERDETAIL.SKU '
                   +' WHERE PICKHEADER.Pickheaderkey = @c_Pickslipno ' 
                   +' AND ORDERS.StorerKey = @c_StorerKey  '
   END

   -- Get Column Type
   SET @c_TableName = LEFT(@c_ColumnName, CharIndex('.', @c_ColumnName) - 1)
   SET @c_ColName  = SUBSTRING(@c_ColumnName, 
                     CharIndex('.', @c_ColumnName) + 1, LEN(@c_ColumnName) - CharIndex('.', @c_ColumnName))

   SET @c_ColType = ''
   SELECT @c_ColType = DATA_TYPE 
   FROM   INFORMATION_SCHEMA.COLUMNS 
   WHERE  TABLE_NAME = @c_TableName
   AND    COLUMN_NAME = @c_ColName

   IF ISNULL(RTRIM(@c_ColType), '') = '' 
   BEGIN
      SET @bInValid = 1 
      SET @c_ErrMsg = 'Invalid Column Name: ' + @c_ColumnName 
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
                   +'@c_Orderkey  NVARCHAR(10) OUTPUT, '
                   +'@c_OrderLineNumber nvarchar(5) OUTPUT,'
                   +'@c_Pickslipno  NVARCHAR(10), '
                   +'@c_StorerKey  NVARCHAR(15) '

   EXEC sp_executesql @c_SQL, @c_SQLArg, @n_RecFound OUTPUT, @c_Orderkey OUTPUT, @c_OrderLineNumber OUTPUT,
                      @c_Pickslipno, @c_StorerKey --(jay01)
                      
   IF @n_RecFound > 0  
   BEGIN 
      SET @bInValid = 1 
      IF @c_TableName IN ('ORDERS','ORDERDETAIL','SKU','LOADPLAN','LOADPLANDETAIL','PICKDETAIL')
         SET @c_ErrMsg = RTRIM(@c_ErrMsg) + 'Order# ' + RTRIM(@c_Orderkey) + '. ' + 
                         'OrderLine# ' + RTRIM(@c_OrderLineNumber) + '. ' +
                         RTRIM(@c_Description) + ' Is Required! ' + master.dbo.fnc_GetCharASCII(13)
      ELSE
         SET @c_ErrMsg = RTRIM(@c_ErrMsg) + RTRIM(@c_Description) + ' Is Required! ' +  master.dbo.fnc_GetCharASCII(13)
   END 

   FETCH NEXT FROM CUR_PREPACK_REQUIRED INTO @c_TableName, @c_Description, @c_ColumnName, @c_WhereCondition  
END 
CLOSE CUR_PREPACK_REQUIRED
DEALLOCATE CUR_PREPACK_REQUIRED 

IF @bInValid = 1
   GOTO QUIT

----------- Check Condition ------

SET @bInValid = 0 

DECLARE CUR_PREPACK_CONDITION CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
SELECT Code, Description, Long, Notes, SHORT, ISNULL(Notes2,'')   
FROM   CODELKUP WITH (NOLOCK)
WHERE  ListName = @c_PrePACKValidationRules
AND    SHORT    IN ('CONDITION', 'CONTAINS')

OPEN CUR_PREPACK_CONDITION

FETCH NEXT FROM CUR_PREPACK_CONDITION INTO @c_TableName, @c_Description, @c_ColumnName, @c_Condition, @c_Type, @c_WhereCondition  

WHILE @@FETCH_STATUS <> -1
BEGIN
   IF @b_IsConso = 1
   BEGIN
      SET @c_SQL = N'SELECT @n_RecFound = COUNT(1), @c_Orderkey = MIN(ORDERS.Orderkey), '
                   +' @c_OrderLineNumber = MIN(ORDERDETAIL.ORDERLINENUMBER) '
                   +' FROM PICKHEADER (NOLOCK) '
                   +' JOIN LOADPLAN (NOLOCK) ON LOADPLAN.Loadkey = PICKHEADER.ExternOrderkey '
                   +' JOIN LOADPLANDETAIL WITH (NOLOCK) ON LOADPLAN.Loadkey = LOADPLANDETAIL.Loadkey '
                   +' JOIN ORDERS WITH (NOLOCK) ON ORDERS.OrderKey = LOADPLANDETAIL.OrderKey '
                   +' JOIN ORDERDETAIL WITH (NOLOCK) ON ORDERS.Orderkey = ORDERDETAIL.Orderkey'
                   +' JOIN SKU WITH (NOLOCK) ON ORDERDETAIL.Storerkey = SKU.Storerkey AND ORDERDETAIL.Sku = SKU.Sku'
                   +' JOIN PICKDETAIL WITH (NOLOCK) ON PICKDETAIL.ORDERKEY = ORDERDETAIL.ORDERKEY AND PICKDETAIL.ORDERLINENUMBER = ORDERDETAIL.ORDERLINENUMBER '
                   +'                              AND PICKDETAIL.SKU = ORDERDETAIL.SKU '
                   +' WHERE PICKHEADER.Pickheaderkey = @c_Pickslipno ' 
                   +' AND ORDERS.StorerKey = @c_StorerKey  '
   END
   ELSE
   BEGIN
      SET @c_SQL = N'SELECT @n_RecFound = COUNT(1), @c_Orderkey = MIN(ORDERS.Orderkey), '
                   +' @c_OrderLineNumber = MIN(ORDERDETAIL.ORDERLINENUMBER) '
                   +' FROM PICKHEADER (NOLOCK) '
                   +' JOIN ORDERS WITH (NOLOCK) ON PICKHEADER.OrderKey = ORDERS.OrderKey '
                   +' JOIN ORDERDETAIL WITH (NOLOCK) ON ORDERS.Orderkey = ORDERDETAIL.Orderkey'
                   +' JOIN LOADPLANDETAIL WITH (NOLOCK) ON ORDERS.Orderkey = LOADPLANDETAIL.Orderkey '
                   +' JOIN LOADPLAN (NOLOCK) ON LOADPLAN.Loadkey = LOADPLANDETAIL.Loadkey '
                   +' JOIN SKU WITH (NOLOCK) ON ORDERDETAIL.Storerkey = SKU.Storerkey AND ORDERDETAIL.Sku = SKU.Sku'
                   +' JOIN PICKDETAIL WITH (NOLOCK) ON PICKDETAIL.ORDERKEY = ORDERDETAIL.ORDERKEY AND PICKDETAIL.ORDERLINENUMBER = ORDERDETAIL.ORDERLINENUMBER '
                   +'                              AND PICKDETAIL.SKU = ORDERDETAIL.SKU '
                   +' WHERE PICKHEADER.Pickheaderkey = @c_Pickslipno ' 
                   +' AND ORDERS.StorerKey = @c_StorerKey  '
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
                   +'@c_Orderkey  NVARCHAR(10) OUTPUT, '
                   +'@c_OrderLineNumber nvarchar(5) OUTPUT,'
                   +'@c_Pickslipno  NVARCHAR(10), '
                   +'@c_StorerKey  NVARCHAR(15) '

   EXEC sp_executesql @c_SQL, @c_SQLArg, @n_RecFound OUTPUT, @c_Orderkey OUTPUT, @c_OrderLineNumber OUTPUT,
                      @c_Pickslipno, @c_StorerKey --(jay01)
                       
   IF @n_RecFound = 0 AND @c_Type <> 'CONDITION'
   BEGIN 
      SET @bInValid = 1 
      SET @c_ErrMsg = @c_ErrMsg + RTRIM(@c_Description) + ' Is Invalid! ' + + master.dbo.fnc_GetCharASCII(13)
   END 
   ELSE
   IF @n_RecFound > 0 AND @c_Type = 'CONDITION' AND @c_ColumnName = 'NOT EXISTS' 
   BEGIN 
      SET @bInValid = 1 
      IF CharIndex('ORDERS', @c_Condition) > 0 OR CharIndex('PICKDETAIL', @c_Condition) > 0 
         OR CharIndex('ORDERDETAIL', @c_Condition) > 0 OR CharIndex('SKU', @c_Condition) > 0    
         OR CharIndex('LOADPLAN', @c_Condition) > 0 OR CharIndex('LOADPLANDETAIL', @c_Condition) > 0 
      BEGIN
         SET @c_ErrMsg = RTRIM(@c_ErrMsg) + 'Order# ' + RTRIM(@c_Orderkey) + '. ' + 
                         'OrderLine# ' + RTRIM(@c_OrderLineNumber) + '. ' +
                         RTRIM(@c_Description) + ' Is Required! ' + master.dbo.fnc_GetCharASCII(13)
      END
      ELSE
         SET @c_ErrMsg = @c_ErrMsg + RTRIM(@c_Description) + ' Found! ' + master.dbo.fnc_GetCharASCII(13)
   END 
   ELSE
   IF @n_RecFound = 0 AND @c_Type = 'CONDITION' AND 
      (ISNULL(RTRIM(@c_ColumnName),'') = '' OR @c_ColumnName = 'EXISTS')  
   BEGIN 
      SET @bInValid = 1 
      SET @c_ErrMsg = @c_ErrMsg + RTRIM(@c_Description) + ' Not Found! ' + + master.dbo.fnc_GetCharASCII(13)
   END 

   FETCH NEXT FROM CUR_PREPACK_CONDITION INTO @c_TableName, @c_Description, @c_ColumnName, @c_Condition, @c_Type, @c_WhereCondition  
END 
CLOSE CUR_PREPACK_CONDITION
DEALLOCATE CUR_PREPACK_CONDITION 

IF @bInValid = 1
   GOTO QUIT

--Calling SP

SET @bInValid = 0
   
DECLARE CUR_PREPACK_SPCONDITION CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
SELECT Code, Description, Long 
FROM   CODELKUP WITH (NOLOCK)
WHERE  ListName = @c_PrePACKValidationRules
AND    SHORT    = 'STOREDPROC'

OPEN CUR_PREPACK_SPCONDITION

FETCH NEXT FROM CUR_PREPACK_SPCONDITION INTO @c_TableName, @c_Description, @c_SPName 

WHILE @@FETCH_STATUS <> -1
BEGIN
   IF EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_SPName) AND type = 'P')  
   BEGIN      
      SET @c_SQL = 'EXEC ' + @c_SPName + ' @c_Pickslipno, @c_StorerKey, @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT '      
   
      EXEC sp_executesql @c_SQL     
         , N'@c_Pickslipno NVARCHAR(10), @c_StorerKey NVARCHAR(15), @b_Success Int OUTPUT, @n_Err Int OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT'      
         , @c_Pickslipno      
         , @c_StorerKey      
         , @b_Success    OUTPUT      
         , @n_Err       OUTPUT      
         , @c_ErrMsg    OUTPUT    

      IF @b_Success <> 1
      BEGIN 
         SET @bInValid = 1      
         CLOSE CUR_PREPACK_SPCONDITION
         DEALLOCATE CUR_PREPACK_SPCONDITION 
         GOTO QUIT
      END 

   END 
   FETCH NEXT FROM CUR_PREPACK_SPCONDITION INTO @c_TableName, @c_Description, @c_SPName
END 
CLOSE CUR_PREPACK_SPCONDITION
DEALLOCATE CUR_PREPACK_SPCONDITION 

QUIT:
IF @bInValid = 1 
   SET @b_Success = 0 
ELSE
   SET @b_Success = 1

-- End Procedure

GO