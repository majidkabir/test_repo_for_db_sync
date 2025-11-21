SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/                 
/* Copyright: IDS                                                             */                 
/* Purpose: isp_Bartender_OBCTNLBL_GetParm                                    */                 
/*                                                                            */                 
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date       Rev  Author     Purposes                                        */                 
/* 2023-08-17 1.0  CSCHONG    Devops Scripts Combine & WMS-23367              */                           
/******************************************************************************/                
                  
CREATE   PROC [dbo].[isp_Bartender_OBCTNLBL_GetParm]                      
(  @c_Sparm01            NVARCHAR(250),              
   @c_Sparm02            NVARCHAR(250),              
   @c_Sparm03            NVARCHAR(250),              
   @c_Sparm04            NVARCHAR(250),              
   @c_Sparm05            NVARCHAR(250),              
   @c_Sparm06            NVARCHAR(250),              
   @c_Sparm07            NVARCHAR(250),              
   @c_Sparm08            NVARCHAR(250),              
   @c_Sparm09            NVARCHAR(250),              
   @c_Sparm10            NVARCHAR(250),        
   @b_debug           INT = 0                         
)                      
AS                      
BEGIN                      
   SET NOCOUNT ON                 
   SET ANSI_NULLS OFF                
   SET QUOTED_IDENTIFIER OFF                 
   SET CONCAT_NULL_YIELDS_NULL OFF                
                              
   DECLARE @n_TTLLabel   INT  
                
  

                      SELECT @n_TTLLabel = COUNT (DISTINCT PD.LabelNo)
                      FROM PACKHEADER PH WITH (NOLOCK) 
							 JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo
							 WHERE PH.Pickslipno = @c_Sparm01
							 AND PD.LabelNo =@c_Sparm02

                      SELECT DISTINCT PARM1= PD.Pickslipno,PARM2=PD.labelNo,PARM3= @n_TTLLabel ,PARM4= '',PARM5='',PARM6='',PARM7='',
						    PARM8='',PARM9='',PARM10='',Key1='',Key2='',Key3='',Key4='',Key5= ''
							 FROM PACKHEADER PH WITH (NOLOCK) 
							 JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo
							 LEFT JOIN ORDERS O WITH (NOLOCK) ON O.Orderkey = pH.orderkey
							 WHERE PH.Pickslipno = @c_Sparm01
							 AND PD.LabelNo =@c_Sparm02
   
            
   EXIT_SP:    
   
                                  
   END -- procedure   



GO