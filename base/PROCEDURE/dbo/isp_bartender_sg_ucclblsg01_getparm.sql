SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/                   
/* Copyright: LFL                                                             */                   
/* Purpose: isp_Bartender_SG_UCCLBLSG01_GetParm                               */                   
/*                                                                            */                   
/* Modifications log:                                                         */                   
/*                                                                            */                   
/* Date       Rev  Author     Purposes                                        */      
/* 2021-08-11 1.0  WLChooi    Created - DevOps Combine Script (WMS-17658)     */                         
/******************************************************************************/                  
                    
CREATE PROC [dbo].[isp_Bartender_SG_UCCLBLSG01_GetParm]                        
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
                                
   DECLARE @n_intFlag          INT,       
           @n_CntRec           INT,      
           @c_SQL              NVARCHAR(4000),          
           @c_SQLSORT          NVARCHAR(4000),          
           @c_SQLJOIN          NVARCHAR(4000),  
           @c_condition1       NVARCHAR(150) ,  
           @c_condition2       NVARCHAR(150),  
           @c_SQLGroup         NVARCHAR(4000),  
           @c_SQLOrdBy         NVARCHAR(150)  
             
   DECLARE @d_Trace_StartTime  DATETIME,     
           @d_Trace_EndTime    DATETIME,    
           @c_Trace_ModuleName NVARCHAR(20),     
           @d_Trace_Step1      DATETIME,     
           @c_Trace_Step1      NVARCHAR(20),    
           @c_UserName         NVARCHAR(20),  
           @c_ExecStatements   NVARCHAR(4000),      
           @c_ExecArguments    NVARCHAR(4000)          
           
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
      
   SET @c_SQLJOIN = ' SELECT DISTINCT '        + CHAR(13)
                  + ' PARM1 = PD.Pickslipno, ' + CHAR(13)
                  + ' PARM2 = PD.CartonNo, '   + CHAR(13)
                  + ' PARM3 = PD.CartonNo, '   + CHAR(13)
                  + ' PARM4 = @Parm04, '       + CHAR(13)
                  + ' PARM5 = @Parm05, '       + CHAR(13)
                  + ' PARM6 = @Parm06, '       + CHAR(13)
                  + ' PARM7 = @Parm07, '       + CHAR(13)
                  + ' PARM8 = @Parm08, '       + CHAR(13)
                  + ' PARM9 = @Parm09, '       + CHAR(13)
                  + ' PARM10 = @Parm10, '      + CHAR(13)
                  + ' Key1 = ''Pickslipno'', ' + CHAR(13)
                  + ' Key2 = ''LabelNo'', '   + CHAR(13)
                  + ' Key3 = '''', '           + CHAR(13)
                  + ' Key4 = '''', '           + CHAR(13)
                  + ' Key5 = ''''  '           + CHAR(13)
                  + ' FROM PACKHEADER PH WITH (NOLOCK) ' + CHAR(13)
                  + ' JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo' + CHAR(13) 
                  + ' WHERE PH.Pickslipno = @Parm01 ' + CHAR(13)
                  + ' AND PD.CartonNo >= CONVERT(INT,@Parm02) AND PD.CartonNo <= CONVERT(INT,@Parm03) '  
  
   SET @c_SQL = @c_SQLJOIN   

   SET @c_ExecArguments = N'  @parm01           NVARCHAR(80)'      
                        +  ', @parm02           NVARCHAR(80)'      
                        +  ', @parm03           NVARCHAR(80)' 
                        +  ', @parm04           NVARCHAR(80)'   
                        +  ', @parm05           NVARCHAR(80)'       
                        +  ', @parm06           NVARCHAR(80)'  
                        +  ', @parm07           NVARCHAR(80)'  
                        +  ', @parm08           NVARCHAR(80)'  
                        +  ', @parm09           NVARCHAR(80)'  
                        +  ', @parm10           NVARCHAR(80)'  
           
   EXEC sp_ExecuteSql  @c_SQL       
                     , @c_ExecArguments      
                     , @parm01      
                     , @parm02     
                     , @parm03  
                     , @parm04
                     , @parm05
                     , @parm06     
                     , @parm07     
                     , @parm08  
                     , @parm09
                     , @parm10
              
EXIT_SP:      

END -- procedure     

GO