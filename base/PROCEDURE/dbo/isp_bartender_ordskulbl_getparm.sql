SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/                 
/* Copyright: LFL                                                             */                 
/* Purpose: isp_Bartender_ORDSKULBL_GetParm                                   */                 
/*                                                                            */                 
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date       Rev  Author     Purposes                                        */                 
/* 2021-08-12 1.0  WLChooi    Created (WMS-17662) - DevOps Combine Script     */ 
/* 2022-01-12 1.1  WLChooi    Bug Fix - Filter Parm02 = SKU (WL01)            */                        
/******************************************************************************/                
CREATE PROC [dbo].[isp_Bartender_ORDSKULBL_GetParm]                      
(  @parm01            NVARCHAR(250),              
   @parm02            NVARCHAR(250),              
   @parm03            NVARCHAR(250),              
   @parm04            NVARCHAR(250),              
   @parm05            NVARCHAR(250),              
   @parm06            NVARCHAR(250),              
   @parm07            NVARCHAR(250),              
   @parm08            NVARCHAR(250),              
   @parm09            NVARCHAR(250),              
   @parm10            NVARCHAR(250),        
   @b_debug           INT = 0                         
)                      
AS                      
BEGIN                      
   SET NOCOUNT ON                 
   SET ANSI_NULLS OFF                
   SET QUOTED_IDENTIFIER OFF                 
   SET CONCAT_NULL_YIELDS_NULL OFF                
                              
   DECLARE @c_SQL               NVARCHAR(4000)
         , @c_SQLSORT           NVARCHAR(4000)
         , @c_SQLJOIN           NVARCHAR(4000)
         , @c_condition1        NVARCHAR(150)
         , @c_condition2        NVARCHAR(150)
         , @c_SQLGroup          NVARCHAR(4000)
         , @c_SQLOrdBy          NVARCHAR(150)
         , @c_SQLinsert         NVARCHAR(4000)
         , @c_SQLSelect         NVARCHAR(4000)
      
    
   DECLARE  @d_Trace_StartTime  DATETIME  
          , @d_Trace_EndTime    DATETIME 
          , @c_Trace_ModuleName NVARCHAR(20)   
          , @d_Trace_Step1      DATETIME 
          , @c_Trace_Step1      NVARCHAR(20)  
          , @c_UserName         NVARCHAR(20)
          , @c_ExecStatements   NVARCHAR(4000)    
          , @c_ExecArguments    NVARCHAR(4000)
          , @n_rowno            INT
          , @n_Copy             INT  
          , @c_Storerkey        NVARCHAR(15)    --WL01
          , @c_Condition        NVARCHAR(100) = ''   --WL01
  
   SET @d_Trace_StartTime = GETDATE()  
   SET @c_Trace_ModuleName = ''  
        
   -- SET RowNo = 0             
   SET @c_SQL = ''    
   SET @c_SQLJOIN = ''        
   SET @c_condition1 = ''
   SET @c_condition2= ''
   SET @c_SQLOrdBy = ''
   SET @c_SQLGroup = ''
   SET @c_ExecStatements = ''
   SET @c_ExecArguments = ''
   SET @c_SQLinsert = ''
   SET @c_SQLSelect = ''

   SET @n_Copy = 0

   IF ISNULL(@parm03,'') = ''
   BEGIN
      SET @n_Copy = 1 
   END
   ELSE
   BEGIN
      SET @n_Copy = CASE WHEN ISNUMERIC(@parm03) = 1 THEN CAST(@parm03 AS INT) ELSE 1 END
   END

   --WL01 S
   SELECT @c_Storerkey = OH.Storerkey
   FROM ORDERS OH (NOLOCK)
   WHERE OH.OrderKey = @parm01

   IF ISNULL(@parm02,'') <> ''
   BEGIN
      SET @c_Condition = ' AND S.SKU = @parm02 '
   END
   --WL01 E

   CREATE TABLE #TEMPRESULT  (
      PARM01       NVARCHAR(80),  
      PARM02       NVARCHAR(80),  
      PARM03       NVARCHAR(80),  
      PARM04       NVARCHAR(80),  
      PARM05       NVARCHAR(80),  
      PARM06       NVARCHAR(80),  
      PARM07       NVARCHAR(80),  
      PARM08       NVARCHAR(80),  
      PARM09       NVARCHAR(80),  
      PARM10       NVARCHAR(80),  
      Key01        NVARCHAR(80),
      Key02        NVARCHAR(80),
      Key03        NVARCHAR(80),
      Key04        NVARCHAR(80),
      Key05        NVARCHAR(80)
   )

   SET @c_SQLInsert = ''

   SET @c_SQLInsert =' INSERT INTO #TEMPRESULT (PARM01,PARM02,PARM03,PARM04,PARM05,PARM06,PARM07,PARM08,PARM09,PARM10, ' + CHAR(13) +
                     ' Key01,Key02,Key03,Key04,Key05)'   

   SET @c_SQLJOIN = ' SELECT PARM1 = S.Storerkey, ' + CHAR(13) +
                    ' PARM2 = RTRIM(S.SKU), PARM3 = TRIM(@parm01), PARM4 = '''', PARM5 = '''', PARM6 = '''',PARM7 = '''', ' + CHAR(13) +
                    ' PARM8 = '''', PARM9 = '''', PARM10 = '''', Key1 = ''Storerkey'', Key2 = ''SKU'', Key3 = ''Orderkey'', Key4 = '''', ' + CHAR(13) +
                    ' Key5 = '''' '  + CHAR(13) +   
                    ' FROM ORDERDETAIL OD WITH (NOLOCK) ' + CHAR(13) +
                    ' JOIN SKU S WITH (NOLOCK) ON S.Storerkey = OD.Storerkey AND S.SKU = OD.SKU ' + CHAR(13) +
                    ' WHERE OD.Orderkey = @parm01 ' + CHAR(13) +
                    ' AND S.Storerkey = @c_Storerkey ' + CHAR(13) +   --WL01
                    @c_Condition + CHAR(13) +   --WL01
                    ' GROUP BY S.Storerkey, S.SKU '
         
   SET @c_SQL = @c_SQLInsert + CHAR(13) + @c_SQLJOIN    
    
   SET @c_ExecArguments = N'   @parm01           NVARCHAR(80),' +
                           '   @parm02           NVARCHAR(80),' +   --WL01   
                           '   @c_Storerkey      NVARCHAR(15)'   --WL01   
                    
   EXEC sp_ExecuteSql     @c_SQL     
                        , @c_ExecArguments    
                        , @parm01    
                        , @parm02
                        , @c_Storerkey   --WL01

   WHILE @n_Copy > 1
   BEGIN
      INSERT INTO #TEMPRESULT (PARM01,PARM02,PARM03,PARM04,PARM05,PARM06,PARM07,PARM08,PARM09,PARM10, 
                               Key01,Key02,Key03,Key04,Key05)
      SELECT TOP 1 PARM01,PARM02,PARM03,PARM04,PARM05,PARM06,PARM07,PARM08,PARM09,PARM10,
                   Key01,Key02,Key03,Key04,Key05
      FROM #TEMPRESULT
      
      SET @n_Copy = @n_Copy - 1
   END  

   SELECT * FROM #TEMPRESULT (nolock)  
            
EXIT_SP:    
                                  
END -- procedure   

GO