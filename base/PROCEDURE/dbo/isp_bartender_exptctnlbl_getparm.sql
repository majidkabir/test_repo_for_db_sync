SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/                 
/* Copyright: LFL                                                             */                 
/* Purpose: isp_Bartender_EXPTCTNLBL_GetParm                                  */                 
/*                                                                            */                 
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date       Rev  Author     Purposes                                        */                 
/* 2022-01-19 1.0  WLChooi    Created (WMS-18768)                             */  
/* 2022-01-19 1.0  WLChooi    DevOps Combine Script                           */  
/******************************************************************************/                
CREATE PROC [dbo].[isp_Bartender_EXPTCTNLBL_GetParm]                      
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
         , @c_SQLInsert         NVARCHAR(4000)  
    
   DECLARE  @d_Trace_StartTime  DATETIME  
          , @d_Trace_EndTime    DATETIME 
          , @c_Trace_ModuleName NVARCHAR(20)   
          , @d_Trace_Step1      DATETIME 
          , @c_Trace_Step1      NVARCHAR(20)  
          , @c_UserName         NVARCHAR(20)
          , @c_ExecStatements   NVARCHAR(4000)    
          , @c_ExecArguments    NVARCHAR(4000)
  
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
   SET @c_SQLInsert = ''

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

   SET @c_SQLJOIN = ' SELECT DISTINCT PARM1 = PD.Pickslipno, ' + CHAR(13) +
                    ' PARM2 = PD.LabelNo, PARM3 = '''', PARM4 = '''', PARM5 = '''', PARM6 = '''',PARM7 = '''', ' + CHAR(13) +
                    ' PARM8 = '''', PARM9 = '''', PARM10 = '''', Key1 = ''Pickslipno'', Key2 = ''LabelNo'', Key3 = '''', Key4 = '''', ' + CHAR(13) +
                    ' Key5 = '''' '  + CHAR(13) +   
                    ' FROM PACKDETAIL PD WITH (NOLOCK) ' + CHAR(13) +
                    ' WHERE PD.Storerkey = @parm01 ' + CHAR(13) +
                    ' AND PD.LabelNo = @parm02 '
         
   SET @c_SQL = @c_SQLInsert + CHAR(13) + @c_SQLJOIN    
    
   SET @c_ExecArguments = N'   @parm01           NVARCHAR(80),' +
                           '   @parm02           NVARCHAR(80) '
                    
   EXEC sp_ExecuteSql     @c_SQL     
                        , @c_ExecArguments    
                        , @parm01    
                        , @parm02

   SELECT * FROM #TEMPRESULT (NOLOCK)  
            
EXIT_SP:    
                                  
END -- procedure   

GO