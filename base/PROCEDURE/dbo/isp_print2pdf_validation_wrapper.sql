SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/  
/* Stored Procedure: isp_Print2PDF_Validation_Wrapper                      */  
/* Creation Date: 07-Jan-2021                                              */  
/* Copyright: LFL                                                          */  
/* Written by: WLChooi                                                     */  
/*                                                                         */  
/* Purpose: Print to PDF Validation                                        */                                 
/*                                                                         */  
/* Called By: isp_GetPrint2PDFConfig                                       */  
/*                                                                         */  
/* GitLab Version: 1.0                                                     */  
/*                                                                         */  
/* Version: 7.0                                                            */  
/*                                                                         */  
/* Data Modifications:                                                     */  
/*                                                                         */  
/* Updates:                                                                */  
/* Date           Ver    Author   Purposes                                 */
/***************************************************************************/    
CREATE PROC [dbo].[isp_Print2PDF_Validation_Wrapper]    
(     
	   @c_Param01       NVARCHAR(50),
      @c_Param02       NVARCHAR(50),
      @c_Param03       NVARCHAR(50),
      @c_Param04       NVARCHAR(50),
      @c_Param05       NVARCHAR(50),
      @c_Exist         NVARCHAR(MAX),
      @c_NotExist      NVARCHAR(MAX),
      @c_Contain       NVARCHAR(MAX),
      @c_SQL           NVARCHAR(MAX),
      @b_InValid       BIT           OUTPUT,
      @b_Success       INT           OUTPUT,  
      @n_Err           INT           OUTPUT, 
      @c_ErrMsg        NVARCHAR(255) OUTPUT     
)    
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE @n_Continue     INT   
         , @n_StartTCount  INT   
         , @c_SPCode       NVARCHAR(50)        
         , @c_authority    NVARCHAR(30)
         , @c_option1      NVARCHAR(50)
         , @c_option2      NVARCHAR(50)
         , @c_option3      NVARCHAR(50)
         , @c_option4      NVARCHAR(50)
         , @c_option5      NVARCHAR(4000)
         , @c_PdfFolder    NVARCHAR(500)

   DECLARE @n_RecFound          INT, 
           @c_Type              NVARCHAR(10),
           @c_SQLArg            NVARCHAR(MAX)
              
   DECLARE @c_GetConditionName  NVARCHAR(255),
           @c_GetColumnName     NVARCHAR(255),
           @c_GetCondition      NVARCHAR(MAX),
           @c_GetType           NVARCHAR(255)
           
   SET @b_Success= 1   
   SET @n_Err    = 0    
   SET @c_ErrMsg = ''   
   SET @n_Continue = 1    
   SET @n_StartTCount = @@TRANCOUNT  
   SET @b_InValid = 0

   CREATE TABLE #TMP_Validation (
         ConditionName   NVARCHAR(255) NULL,
         ColumnName      NVARCHAR(255) NULL,
         Condition       NVARCHAR(MAX) NULL,
         [TYPE]          NVARCHAR(255) NULL,
   )
   
   IF LEN(@c_Exist) > 0
   BEGIN
      INSERT INTO #TMP_Validation (ConditionName, ColumnName, Condition, [Type])
      SELECT '@c_Exist','EXISTS',@c_Exist,'CONDITION'
   END
   
   IF LEN(@c_NotExist) > 0
   BEGIN
      INSERT INTO #TMP_Validation (ConditionName, ColumnName, Condition, [Type])
      SELECT '@c_NotExist','NOT EXISTS',@c_NotExist,'CONDITION'
   END
   
   IF LEN(@c_Contain) > 0
   BEGIN
      DECLARE @c_GetColumn NVARCHAR(255), @c_GetData NVARCHAR(255)
      
      DECLARE CUR_CONDITION CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT LTRIM(RTRIM(ColValue))
      FROM dbo.fnc_delimsplit (',',@c_Contain) 
      
      OPEN CUR_CONDITION
      
      FETCH NEXT FROM CUR_CONDITION INTO @c_GetCondition
      
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SELECT @c_GetColumn = LTRIM(RTRIM(ColValue)) FROM dbo.fnc_delimsplit ('=',@c_GetCondition) WHERE SeqNo = 1
         SELECT @c_GetData   = LTRIM(RTRIM(ColValue)) FROM dbo.fnc_delimsplit ('=',@c_GetCondition) WHERE SeqNo = 2
         
         INSERT INTO #TMP_Validation (ConditionName, ColumnName, Condition, [Type])
         SELECT '@c_Contain',@c_GetColumn,@c_GetData,'CONTAINS'
      
         FETCH NEXT FROM CUR_CONDITION INTO @c_GetCondition
      END
      CLOSE CUR_CONDITION
      DEALLOCATE CUR_CONDITION
   END
      
   DECLARE CUR_PACK_CONDITION CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT ConditionName, ColumnName, Condition, [TYPE]
   FROM  #TMP_Validation
   WHERE [TYPE] IN ('CONDITION', 'CONTAINS')
      
   OPEN CUR_PACK_CONDITION
      
   FETCH NEXT FROM CUR_PACK_CONDITION INTO @c_GetConditionName
                                         , @c_GetColumnName   
                                         , @c_GetCondition    
                                         , @c_GetType         
      
   WHILE @@FETCH_STATUS <> -1
   BEGIN 
      IF @c_GetType = 'CONDITION'
      BEGIN
         IF ISNULL(@c_GetCondition,'') <> ''
         BEGIN
            SET @c_GetCondition = REPLACE(LEFT(@c_GetCondition,5),'AND ','AND (') + SUBSTRING(@c_GetCondition,6,LEN(@c_GetCondition)-5)
            SET @c_GetCondition = REPLACE(LEFT(@c_GetCondition,4),'OR ','OR (') + SUBSTRING(@c_GetCondition,5,LEN(@c_GetCondition)-4)
            SET @c_SQL = @c_SQL + master.dbo.fnc_GetCharASCII(13) + CASE WHEN LEFT(LTRIM(@c_GetCondition),3) NOT IN ('AND','OR ') AND ISNULL(@c_GetCondition,'') <> '' THEN ' AND (' ELSE ' ' END + RTRIM(@c_GetCondition) + ')'
            --SET @c_SQL = @c_SQL + master.dbo.fnc_GetCharASCII(13) + CASE WHEN LEFT(LTRIM(@c_WhereCondition),3) NOT IN ('AND','OR ') AND ISNULL(@c_WhereCondition,'') <> '' THEN ' AND ' ELSE ' ' END + RTRIM(@c_WhereCondition) + ')'
         END 
      END
      ELSE
      BEGIN --CONTAINS
         IF ISNULL(@c_GetCondition,'') <> ''
         BEGIN
            SET @c_SQL = @c_SQL + master.dbo.fnc_GetCharASCII(13) + ' AND (' + @c_GetColumnName + ' IN (' + ISNULL(RTRIM(@c_GetCondition),'') + '))' 
            --SET @c_SQL = @c_SQL + master.dbo.fnc_GetCharASCII(13) + CASE WHEN LEFT(LTRIM(@c_WhereCondition),3) NOT IN ('AND','OR ') AND ISNULL(@c_WhereCondition,'') <> '' THEN ' AND ' ELSE ' ' END + RTRIM(@c_WhereCondition) + ')'
         END                
      END 
      
      SET @c_SQLArg = N'@n_RecFound int OUTPUT, '
                      +'@c_Param01  NVARCHAR(50), '
                      +'@c_Param02  NVARCHAR(50), '
                      +'@c_Param03  NVARCHAR(50), '
                      +'@c_Param04  NVARCHAR(50), '
                      +'@c_Param05  NVARCHAR(50)  '
                      
      EXEC sp_executesql @c_SQL, @c_SQLArg, @n_RecFound OUTPUT, @c_Param01, @c_Param02, @c_Param03, @c_Param04, @c_Param05
      PRINT @c_SQL PRINT @c_SQLArg
      
      IF @n_RecFound = 0 AND @c_GetType <> 'CONDITION'
      BEGIN 
         SET @b_InValid = 1 
      END 
      ELSE
      IF @n_RecFound > 0 AND @c_GetType = 'CONDITION' AND @c_GetColumnName = 'NOT EXISTS' 
      BEGIN 
         SET @b_InValid = 1 
      END 
      ELSE
      IF @n_RecFound = 0 AND @c_GetType = 'CONDITION' AND 
         (ISNULL(RTRIM(@c_GetColumnName),'') = '' OR @c_GetColumnName = 'EXISTS')  
      BEGIN 
         SET @b_InValid = 1 
      END 
      --SELECT @n_RecFound, @c_GetType, @c_GetColumnName, @b_InValid
      FETCH NEXT FROM CUR_PACK_CONDITION INTO @c_GetConditionName
                                            , @c_GetColumnName   
                                            , @c_GetCondition    
                                            , @c_GetType  
   END
        
QUIT_SP:  
   IF OBJECT_ID('tempdb..#TMP_Validation') IS NOT NULL
      DROP TABLE #TMP_Validation
      
   IF CURSOR_STATUS('LOCAL', 'CUR_PACK_CONDITION') IN (0 , 1)
   BEGIN
      CLOSE CUR_PACK_CONDITION
      DEALLOCATE CUR_PACK_CONDITION   
   END
      
   IF @n_continue = 3  -- Error Occured - Process And Return  
   BEGIN  
      SET @b_success = 0  
  
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCount  
      BEGIN  
         ROLLBACK TRAN  
      END  
      ELSE  
      BEGIN  
         WHILE @@TRANCOUNT > @n_StartTCount  
         BEGIN  
            COMMIT TRAN  
         END  
      END  
      Execute nsp_logerror @n_err, @c_errmsg, 'isp_Print2PDF_Validation_Wrapper'  
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN  
   END  
   ELSE  
   BEGIN  
      SET @b_success = 1  
      WHILE @@TRANCOUNT > @n_StartTCount  
      BEGIN  
         COMMIT TRAN  
      END   
  
      RETURN  
   END   
END 

GO