SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                                                                                  
/* Store Procedure: lsp_Populate_GetDocFieldsMap                        */                                                                                  
/* Creation Date: 2019-05-14                                            */                                                                                  
/* Copyright: LFL                                                       */                                                                                  
/* Written by: Wan                                                      */                                                                                  
/*                                                                      */                                                                                  
/* Purpose: LFWM-1819 - Populate PO Header                              */
/*                                                                      */
/* Called By: SCE                                                       */                                                                                  
/*          :                                                           */                                                                                  
/* PVCS Version: 1.1                                                    */                                                                                  
/*                                                                      */                                                                                  
/* Version: 8.0                                                         */                                                                                  
/*                                                                      */                                                                                  
/* Data Modifications:                                                  */                                                                                  
/*                                                                      */                                                                                  
/* Updates:                                                             */                                                                                  
/* Date        Author   Ver.  Purposes                                  */  
/* 2021-06-18  Wan01    1.1   LFWM-2811 - UATPhilippines  Populate of PO*/
/*                            in ASN (RECTYPE)                          */
/* 2021-07-20  Wan02    1.6   LFWM-2854 - UAT - TW  Receipt - Populate  */
/*                            from PO ( 1 PO 1 ASN ) in SCE does not    */
/*                            support codelkup 'PO2ASNMAP               */
/************************************************************************/                                                                                  
CREATE PROC [WM].[lsp_Populate_GetDocFieldsMap] 
      @c_SourceTable          NVARCHAR(30) 
   ,  @c_Sourcekey            NVARCHAR(10)
   ,  @c_SourceLineNumber     NVARCHAR(30)   = ''
   ,  @c_ListName             NVARCHAR(10)   = ''
   ,  @c_Code                 NVARCHAR(30)   = ''   
   ,  @c_Storerkey            NVARCHAR(15)   = '' 
   ,  @c_Code2                NVARCHAR(30)   = '' 
   ,  @c_DBName               NVARCHAR(30)   = ''
   ,  @c_UpdateCol            NVARCHAR(60)   = ''  OUTPUT
   ,  @c_ReturnSQL            NVARCHAR(MAX)  = ''  OUTPUT
AS  
BEGIN                                                                                                                                                        
   SET NOCOUNT ON                                                                                                                                           
   SET ANSI_NULLS OFF                                                                                                                                       
   SET QUOTED_IDENTIFIER OFF                                                                                                                                
   SET CONCAT_NULL_YIELDS_NULL OFF       

   DECLARE @n_Cnt             INT            = 0
         , @c_SQL             NVARCHAR(4000) = '' 
         , @c_SQLParm         NVARCHAR(4000) = '' 
  
         , @c_ToTable         NVARCHAR(30)   = ''
         , @c_FromTable       NVARCHAR(30)   = ''
         , @c_FromTableCol    NVARCHAR(100)  = ''
         , @c_ToTableCol      NVARCHAR(100)  = ''
         , @c_FromCol         NVARCHAR(30)   = ''
         , @c_ToCol           NVARCHAR(30)   = ''
         , @c_KeyCol          NVARCHAR(30)   = ''
         , @n_FromColType     INT            = 0
  
         , @c_TableAttribute  NVARCHAR(10)   = '' 
         , @c_Rule            NVARCHAR(255)  = ''     
         , @c_SPName          NVARCHAR(255)  = '' 
         , @c_CustomSQL       NVARCHAR(4000) = ''  
  
   IF @c_SourceLineNumber = ''  
   BEGIN  
      SET @c_TableAttribute = 'H'  
      --SET @c_ToTable        = 'RECEIPT'   
   END  
   ELSE  
   BEGIN  
      SET @c_TableAttribute = 'D'  
   END  
  
   SET @n_Cnt = 0  
   SET @c_Rule = ''  
   SET @c_CustomSQL = ''  
  
   SELECT @c_Rule         = ISNULL(RTRIM(CL.Long),'')  
         ,@c_CustomSQL    = ISNULL(RTRIM(CL.Notes),'')  
         ,@c_FromTableCol = ISNULL(RTRIM(CL.UDF01),'')
         ,@c_ToTableCol   = ISNULL(RTRIM(CL.UDF02),'')
         ,@n_Cnt    = 1  
   FROM CODELKUP CL WITH (NOLOCK)  
   WHERE CL.ListName = @c_Listname  
   AND   CL.Code = @c_Code  
   AND   CL.Storerkey = @c_Storerkey  
   AND   CL.Code2 = @c_Code2   
   AND   CL.Short = @c_TableAttribute  
  
   IF @n_Cnt = 0  
   BEGIN  
      GOTO EXIT_SP  
   END  
      
   SET @c_UpdateCol =  @c_ToTableCol                        --(Wan01)       
   IF CHARINDEX('.', @c_ToTableCol) > 0   
   BEGIN  
      SET @c_ToTable  = SUBSTRING(@c_ToTableCol, 1, CHARINDEX('.', @c_ToTableCol) - 1)  
      SET @c_UpdateCol= SUBSTRING(@c_ToTableCol, CHARINDEX('.', @c_ToTableCol) + 1
                                , LEN(@c_ToTableCol) -  CHARINDEX('.', @c_ToTableCol))  
   END  
  
   SET @c_FromCol =  @c_FromTableCol                        --(Wan01)
   IF CHARINDEX('.', @c_FromTableCol) > 0   
   BEGIN  
      SET @c_FromTable = SUBSTRING(@c_FromTableCol, 1, CHARINDEX('.', @c_FromTableCol) - 1)  
      SET @c_FromCol   = SUBSTRING(@c_FromTableCol, CHARINDEX('.', @c_FromTableCol) + 1
                                  , LEN(@c_FromTableCol) -  CHARINDEX('.', @c_FromTableCol))  
   END  

   IF @c_FromTable <> '' AND @c_FromTable <> @c_SourceTable --(Wan01) 
   BEGIN  
      GOTO EXIT_SP  
   END  
   
   IF @c_FromCol = '' AND @c_FromTable <> ''                --(Wan01)(Wan02)
   BEGIN    
      GOTO EXIT_SP    
   END   
   
   IF @c_UpdateCol = ''                                     --(Wan01)
   BEGIN    
      GOTO EXIT_SP    
   END   
   
   IF @c_ToTable <> ''                                      --(Wan01)
   BEGIN
      SET @n_Cnt = 0  
      SELECT @n_Cnt         = 1  
      FROM Sys.Objects O WITH (NOLOCK)  
      JOIN Sys.Columns C WITH (NOLOCK) ON (O.Object_Id = C.Object_Id)  
      WHERE O.[Name] = @c_ToTable  
      AND   O.[Type] = 'U' 
      AND   C.[Name] = @c_UpdateCol   
  
      IF @n_Cnt = 0  
      BEGIN  
         GOTO EXIT_SP  
      END  
   END                                                      --(Wan01)
   
   IF @c_Rule IN ('', 'MAPPING')  
   BEGIN  
  
      SET @n_Cnt = 0  
      SELECT @n_Cnt         = 1  
      FROM Sys.Objects O WITH (NOLOCK)  
      JOIN Sys.Columns C WITH (NOLOCK) ON (O.Object_Id = C.Object_Id)  
      WHERE O.[Name] = @c_SourceTable  
      AND   O.[Type] = 'U' 
      AND   C.[Name] = @c_FromCol   
  
      IF @n_Cnt = 0  
      BEGIN  
         GOTO EXIT_SP  
      END  
  
      SET @c_ReturnSQL = N' SELECT TOP 1 FromValue = ' + @c_FromCol                    --(Wan02) - Return 1 record
                       +  ' FROM ' + @c_SourceTable + ' WITH (NOLOCK)'  
  
      GOTO EXIT_SP  
   END  
  
   IF @c_CustomSQL = ''  
   BEGIN  
      GOTO EXIT_SP  
   END  
  
   IF @c_Rule = 'SQL'  
   BEGIN  
      SET @c_ReturnSQL = REPLACE (@c_CustomSQL, 'SELECT', 'SELECT TOP 1 FromValue = ') --(Wan02) - Return 1 record  
  
      GOTO EXIT_SP  
   END  
  
   IF @c_Rule = 'STOREDPROC'  
   BEGIN  
  
      SET @c_SPName = @c_CustomSQL  
      IF EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_SPName) AND type = 'P')            
      BEGIN   
         SET @c_SQL  = 'EXEC ' + @c_SPName 
                     + '  @c_SourceTable = @c_SourceTable'
                     + ', @c_SourceKey   = @c_SourceKey'
                     + ', @c_SourceLineNumber = @c_SourceLineNumber'  
                     + ', @c_ListName = @c_ListName'
                     + ', @c_Code = @c_Code'
                     + ', @c_Storerkey = @c_Storerkey'
                     + ', @c_Code2  = @c_Code2'
                     + ', @c_DBName = @c_DBName'
                     + ', @c_ReturnSQL = @c_ReturnSQL OUTPUT'
                     --+ ', @b_Success OUTPUT'            
  
         SET @c_SQLParm =  N'@c_SourceTable        NVARCHAR(30)'  
                        +  ',@c_SourceKey          NVARCHAR(30)'  
                        +  ',@c_SourceLineNumber   NVARCHAR(30)'  
                        +  ',@c_ListName           NVARCHAR(10)'   
                        +  ',@c_Code               NVARCHAR(30)'  
                        +  ',@c_Storerkey          NVARCHAR(15)'  
                        +  ',@c_Code2              NVARCHAR(30)'  
                        +  ',@c_DBName             NVARCHAR(60)'  
                        +  ',@c_ReturnSQL          NVARCHAR(MAX) OUTPUT'  
                        --+  ',@b_Success            INT            OUTPUT'  
                              
         EXEC sp_executesql @c_SQL            
                          , @c_SQLParm    
                          , @c_SourceTable                            
                          , @c_SourceKey  
                          , @c_SourceLineNumber  
                          , @c_ListName  
                          , @c_Code  
                          , @c_Storerkey  
                          , @c_Code2  
                          , @c_DBName       
                          , @c_ReturnSQL  OUTPUT            
                          --, @b_Success    OUTPUT           
  
         GOTO EXIT_SP  
      END  
   END  
   
EXIT_SP:

END

GO