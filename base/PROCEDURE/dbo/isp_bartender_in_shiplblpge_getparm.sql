SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/******************************************************************************/                   
/* Copyright: LFL                                                             */                   
/* Purpose: isp_Bartender_IN_SHIPLBLPGE_GetParm                               */                   
/*                                                                            */                   
/* Modifications log:                                                         */                   
/*                                                                            */                   
/* Date       Rev  Author     Purposes                                        */                   
/* 2021-07-05 1.0  CHONGCS    Created (WMS-17228)                             */               
/******************************************************************************/                  
                    
CREATE   PROC [dbo].[isp_Bartender_IN_SHIPLBLPGE_GetParm]                        
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
      @c_ReceiptKey        NVARCHAR(10),                      
      @c_ExternOrderKey  NVARCHAR(10),                
      @c_Deliverydate    DATETIME,                
      @n_intFlag         INT,       
      @n_CntRec          INT,      
      @c_SQL             NVARCHAR(4000),          
      @c_SQLSORT         NVARCHAR(4000),          
      @c_SQLJOIN         NVARCHAR(4000),  
      @c_condition1      NVARCHAR(150) ,  
      @c_condition2      NVARCHAR(150),  
      @c_SQLGroup        NVARCHAR(4000),  
      @c_SQLOrdBy        NVARCHAR(150),  
      @c_ExecArguments   NVARCHAR(4000)  
           
   DECLARE @d_Trace_StartTime   DATETIME,     
           @d_Trace_EndTime    DATETIME,    
           @c_Trace_ModuleName NVARCHAR(20),     
           @d_Trace_Step1      DATETIME,     
           @c_Trace_Step1      NVARCHAR(20),    
           @c_UserName         NVARCHAR(20) 
    
    
   SET @d_Trace_StartTime = GETDATE()    
   SET @c_Trace_ModuleName = ''    

     
     
   SET @c_ExecArguments = ''  


     SELECT DISTINCT PARM1=PH.PickSlipNo,PARM2=PD.CartonNo,PARM3=PH.OrderKey,PARM4='',PARM5='',
                      PARM6= '',PARM7='',PARM8='',PARM9='',PARM10='',Key1='',Key2='',Key3='',Key4='',Key5='' 
     FROM packheader PH (NOLOCK)
     JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo
     WHERE PH.PickSlipNo = @Parm01 
     AND PD.CartonNo >= CAST(@parm02 AS INT) AND PD.CartonNo <= CAST(@parm03 AS INT)


EXIT_SP:      
   SET @d_Trace_EndTime = GETDATE()    
   SET @c_UserName = SUSER_SNAME()    
                                    
END -- procedure     

GO