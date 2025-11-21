SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/                   
/* Copyright: LFL                                                             */                   
/* Purpose: isp_Bartender_SNLABEL_GetParm                                     */                   
/*                                                                            */                   
/* Modifications log:                                                         */                   
/*                                                                            */                   
/* Date       Rev  Author     Purposes                                        */   
/* 2021-01-25 1.0  CSCHONG    Created (WMS-16137)                             */                            
/******************************************************************************/                  
                    
CREATE PROC [dbo].[isp_Bartender_SNLABEL_GetParm]                        
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
      @n_intFlag         INT,       
      @n_CntRec          INT,      
      @c_SQL             NVARCHAR(4000),          
      @c_SQLSORT         NVARCHAR(4000),          
      @c_SQLJOIN         NVARCHAR(4000),
      @c_SQLJOIN1        NVARCHAR(4000),  
      @c_condition1      NVARCHAR(150) ,  
      @c_condition2      NVARCHAR(150),  
      @c_SQLGroup        NVARCHAR(4000),  
      @c_SQLOrdBy        NVARCHAR(150)  
        
   DECLARE  @d_Trace_StartTime   DATETIME,     
            @d_Trace_EndTime    DATETIME,    
            @c_Trace_ModuleName NVARCHAR(20),     
            @d_Trace_Step1      DATETIME,     
            @c_Trace_Step1      NVARCHAR(20),    
            @c_UserName         NVARCHAR(20),  
            @c_ExecStatements   NVARCHAR(4000),      
            @c_ExecArguments    NVARCHAR(4000),
            @c_Storerkey        NVARCHAR(15),
            @n_CurrentPage      INT = 1,
            @n_TotalPage        INT = 0

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
   
   CREATE TABLE #TMP_Result (
      PARM1     NVARCHAR(80),
      PARM2     NVARCHAR(80),
      PARM3     NVARCHAR(80),
      PARM4     NVARCHAR(80),
      PARM5     NVARCHAR(80),
      PARM6     NVARCHAR(80),
      PARM7     NVARCHAR(80),
      PARM8     NVARCHAR(80),
      PARM9     NVARCHAR(80),
      PARM10    NVARCHAR(80),
      Key01     NVARCHAR(80),
      Key02     NVARCHAR(80),
      Key03     NVARCHAR(80),
      Key04     NVARCHAR(80),
      Key05     NVARCHAR(80) )
   

      SET @c_SQL = ' SELECT DISTINCT PARM1 = @parm01,PARM2 = @parm02,PARM3 = '''' ,PARM4= '''',PARM5='''',PARM6='''',PARM7='''', '+  
                   ' PARM8='''',PARM9='''',PARM10='''',Key1=''storerkey'',Key2=''serialno'',Key3='''',' +  
                   ' Key4 = '''', ' +  
                   ' Key5 = '''' '
  
      SET @c_ExecArguments =  N'  @parm01           NVARCHAR(80)'      
                             + ', @parm02           NVARCHAR(80)'      
                             + ', @parm03           NVARCHAR(80)'   
                
      EXEC sp_ExecuteSql     @c_SQL       
                           , @c_ExecArguments      
                           , @parm01      
                           , @parm02     
                           , @parm03  


EXIT_SP:      
    
   SET @d_Trace_EndTime = GETDATE()    
   SET @c_UserName = SUSER_SNAME()    
                                   
END -- procedure     


GO