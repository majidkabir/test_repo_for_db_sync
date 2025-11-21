SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/                 
/* Copyright: LFL                                                             */                 
/* Purpose: Bartender SKU Label GetParm - isp_Bartender_PRICELBL01_GetParm    */                 
/*                                                                            */                 
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date       Rev  Author     Purposes                                        */                 
/* 2021-03-12 1.0  WLChooi    Created (WMS-16545)                             */ 
/* 2021-04-05 1.1  WLChooi    WMS-16545 - Add Storerkey to validate (WL01)    */                                
/******************************************************************************/                
                  
CREATE PROC [dbo].[isp_Bartender_PRICELBL01_GetParm]                      
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
                              
   DECLARE                     
      @c_SQL             NVARCHAR(4000),        
      @c_SQLSORT         NVARCHAR(4000),        
      @c_SQLJOIN         NVARCHAR(4000),
      @c_condition1      NVARCHAR(150) ,
      @c_condition2      NVARCHAR(150),
      @c_SQLGroup        NVARCHAR(4000),
      @c_SQLOrdBy        NVARCHAR(150),
      @c_SQLinsert       NVARCHAR(4000) ,  
      @c_SQLSelect       NVARCHAR(4000)   
      
    
  DECLARE  @d_Trace_StartTime  DATETIME,   
           @d_Trace_EndTime    DATETIME,  
           @c_Trace_ModuleName NVARCHAR(20),   
           @d_Trace_Step1      DATETIME,   
           @c_Trace_Step1      NVARCHAR(20),  
           @c_UserName         NVARCHAR(20),
           @c_getUCCno         NVARCHAR(20),
           @c_getUdef09        NVARCHAR(30),
           @c_ExecStatements   NVARCHAR(4000),    
           @c_ExecArguments    NVARCHAR(4000),
           @c_storerkey        NVARCHAR(20),
           @n_Pqty             INT,   
           @n_rowno            INT,
           @n_copy             INT,
           @c_ExtendedField01  NVARCHAR(50) = ''
  
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

   CREATE TABLE #TMP_SKU (
      Storerkey         NVARCHAR(15) NULL
    , SKU               NVARCHAR(20) NULL
    , Qty               INT NULL
   )

   IF EXISTS (SELECT 1 FROM RECEIPTDETAIL (NOLOCK) WHERE ToId = @parm02 AND Storerkey = @parm01)   --WL01
   BEGIN
      INSERT INTO #TMP_SKU(Storerkey, SKU, Qty)
      SELECT DISTINCT RD.Storerkey, RD.SKU
                    , SUM(RD.BeforeReceivedQty)
      FROM RECEIPT R (NOLOCK)
      JOIN RECEIPTDETAIL RD (NOLOCK) ON R.ReceiptKey = RD.Receiptkey
      WHERE RD.StorerKey = @parm01 AND RD.ToId = @parm02
      GROUP BY RD.Storerkey, RD.SKU
      HAVING SUM(RD.BeforeReceivedQty) > 0
   END
   ELSE
   BEGIN
      INSERT INTO #TMP_SKU(Storerkey, SKU, Qty)
      SELECT @parm01, @parm02, 1
   END

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

   SET @c_SQLInsert ='INSERT INTO #TEMPRESULT (PARM01,PARM02,PARM03,PARM04,PARM05,PARM06,PARM07,PARM08,PARM09,PARM10, ' + CHAR(13) +
                     ' Key01,Key02,Key03,Key04,Key05)'   

   SET @c_SQLJOIN = 'SELECT DISTINCT PARM1 = S.Storerkey, ' +
                    ' PARM2 = RTRIM(S.SKU), PARM3 = t.Qty, PARM4 = '''', PARM5 = '''', PARM6 = '''', PARM7 = '''', '+
                    ' PARM8 = '''', PARM9 = '''', PARM10 = '''', Key1 = ''Storerkey'', Key2 = ''SKU'', Key3 = '''', '+
                    ' Key4 = '''', Key5 = '''' '  +   
                    ' FROM SKU S WITH (NOLOCK) ' +
                    ' JOIN #TMP_SKU t ON t.SKU = S.SKU AND t.Storerkey = S.Storerkey '
                    --' WHERE S.Storerkey = @parm01 ' +
                    --' AND S.SKU = @parm02   ' 
         
   SET @c_SQL = @c_SQLInsert + CHAR(13) + @c_SQLJOIN    
    
   SET @c_ExecArguments = N'   @parm01            NVARCHAR(80),' +
                           '   @parm02            NVARCHAR(80) '
                    
   EXEC sp_ExecuteSql  @c_SQL     
                     , @c_ExecArguments    
                     , @parm01    
                     , @parm02

   SELECT * FROM #TEMPRESULT (nolock)  
            
EXIT_SP:    
   SET @d_Trace_EndTime = GETDATE()  
   SET @c_UserName = SUSER_SNAME()  
   
   IF OBJECT_ID('tempdb..#TEMPRESULT') IS NOT NULL
      DROP TABLE #TEMPRESULT
      
   IF OBJECT_ID('tempdb..#TMP_SKU') IS NOT NULL
      DROP TABLE #TMP_SKU
                                  
END -- procedure   

GO