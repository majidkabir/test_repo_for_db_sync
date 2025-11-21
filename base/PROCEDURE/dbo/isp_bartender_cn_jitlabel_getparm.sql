SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/                     
/* Copyright: IDS                                                             */                     
/* Purpose: isp_Bartender_CN_JITLabel_GetParm                                 */                     
/*                                                                            */                     
/* Modifications log:                                                         */                     
/*                                                                            */                     
/* Date       Rev  Author     Purposes                                        */     
/* 2023-08-11 1.0  CSCHONG    Devops Scripts Combine & WMS-23144-Create       */                  
/******************************************************************************/      
CREATE   PROC [dbo].[isp_Bartender_CN_JITLabel_GetParm]                        
(  @c_parm01            NVARCHAR(250),                
   @c_parm02            NVARCHAR(250),                
   @c_parm03            NVARCHAR(250),                
   @c_parm04            NVARCHAR(250),                
   @c_parm05            NVARCHAR(250),                
   @c_parm06            NVARCHAR(250),                
   @c_parm07            NVARCHAR(250),                
   @c_parm08            NVARCHAR(250),                
   @c_parm09            NVARCHAR(250),                
   @c_parm10            NVARCHAR(250),          
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
      @c_condition3      NVARCHAR(150),  
      @c_SQLGroup        NVARCHAR(4000),  
      @c_SQLOrdBy        NVARCHAR(150),  
      @c_storerkey       NVARCHAR(20)  
        
      
  DECLARE  @d_Trace_StartTime   DATETIME,     
           @d_Trace_EndTime    DATETIME,    
           @c_Trace_ModuleName NVARCHAR(20),     
           @d_Trace_Step1      DATETIME,     
           @c_Trace_Step1      NVARCHAR(20),    
           @c_UserName         NVARCHAR(20),  
           @c_getUCCno         NVARCHAR(20),  
           @c_getUdef09        NVARCHAR(30),  
           @c_ExecStatements   NVARCHAR(4000),      
           @c_ExecArguments    NVARCHAR(4000)        
    
   SET @d_Trace_StartTime = GETDATE()    
   SET @c_Trace_ModuleName = ''    
          
    -- SET RowNo = 0               
    SET @c_SQL = ''      
    SET @c_SQLJOIN = ''          
    SET @c_condition1 = ''  
    SET @c_condition2= ''  
    SET @c_condition3= ''  
    SET @c_SQLOrdBy = ''  
    SET @c_SQLGroup = ''  
    SET @c_ExecStatements = ''  
    SET @c_ExecArguments = ''  
  
  
                 SELECT DISTINCT  PARM1=PH.PickSlipNo,PARM2=PD.CartonNo,PARM3=PD.LabelNo,PARM4='',PARM5='',PARM6='',PARM7='',
                 PARM8='',PARM9='',PARM10='',Key1='',Key2='',Key3='',Key4='', Key5= ''     
                 FROM PACKHEADER PH WITH (NOLOCK) 
                 JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo
                 --JOIN ORDERS OH WITH (NOLOCK) ON OH.OrderKey = PH.OrderKey 
                 WHERE PH.Pickslipno = @c_parm01
                 ORDER BY PH.PickSlipNo,PD.CartonNo,PD.LabelNo  
                             
   EXIT_SP:      
    
      SET @d_Trace_EndTime = GETDATE()    
      SET @c_UserName = SUSER_SNAME()    
                                    
   END -- procedure     
  

GO