SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/                 
/* Copyright: IDS                                                             */                 
/* Purpose: isp_Bartender_ROBOTLABEL_GetParm                                  */                 
/*                                                                            */                 
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date       Rev  Author     Purposes                                        */                 
/* 2018-08-02  1.0  CSCHONG    Created(WMS-5886)                              */  
/* 18-Jun-2019 1.1  CheeMun    INC0744298 - ADD ISNULL ECOM_SINGLE_FLAG       */                           
/******************************************************************************/                
                  
CREATE PROC [dbo].[isp_Bartender_ROBOTLABEL_GetParm]                      
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
                              
    
  DECLARE @d_Trace_StartTime   DATETIME,   
           @d_Trace_EndTime    DATETIME,  
           @c_Trace_ModuleName NVARCHAR(20),   
           @d_Trace_Step1      DATETIME,   
           @c_Trace_Step1      NVARCHAR(20),  
           @c_UserName         NVARCHAR(20),
           @c_getUCCno         NVARCHAR(20),
           @c_getUdef09        NVARCHAR(30),
           @c_ExecStatements   NVARCHAR(4000),    
           @c_ExecArguments    NVARCHAR(4000),
           @c_Pickdetkey       NVARCHAR(50),
           @c_storerkey        NVARCHAR(20),
           @n_Pqty             INT,   
           @n_rowno            INT   
  
   SET @d_Trace_StartTime = GETDATE()  
   SET @c_Trace_ModuleName = '' 

   IF @Parm03 = 'P'
   BEGIN
       SELECT DISTINCT PARM1 = td.dropid ,PARM2 = td.storerkey,PARM3=PD.sku ,PARM4 = OH.doctype ,PARM5 = td.taskdetailkey,
                       PARM6 =@Parm03,PARM7 = '' ,PARM8 = '',PARM9 = '',PARM10 = '',Key1 = 'dropid',Key2 = 'P',Key3 = '',Key4 = '',Key5 = '' 
       FROM taskdetail td WITH (NOLOCK)
       JOIN pickdetail pd WITH (NOLOCK) ON PD.taskdetailkey=td.taskdetailkey
       JOIN orders OH WITH (NOLOCK) ON OH.orderkey = PD.orderkey
       WHERE td.dropid=@Parm01
       AND td.storerkey = @Parm02
       AND td.message03='PACKSTATION'
	   AND ISNULL(OH.ecom_single_flag, '') <>'M'		--INC0744298
       GROUP BY td.dropid,PD.sku,OH.doctype,td.storerkey,td.taskdetailkey
       ORDER BY td.dropid,pd.sku 
   END
   ELSE IF @Parm03 = 'R'
   BEGIN

     SELECT DISTINCT PARM1 = pd.dropid ,PARM2 = pd.storerkey,PARM3= '',PARM4 = OH.doctype ,PARM5 = '',
                       PARM6 =@Parm03,PARM7 = '' ,PARM8 = '',PARM9 = '',PARM10 = '',Key1 = 'dropid',Key2 = 'R',Key3 = '',Key4 = '',Key5 = '' 
       FROM pickdetail pd WITH (NOLOCK) 
       JOIN orders OH WITH (NOLOCK) ON OH.orderkey = PD.orderkey
       WHERE pd.dropid=@Parm01
       AND pd.storerkey = @Parm02
       AND pd.Status<='5'
       AND ISNULL(OH.ecom_single_flag, '') <>'M'		--INC0744298
       GROUP BY pd.dropid,OH.doctype,pd.storerkey
       ORDER BY pd.dropid,OH.doctype,pd.storerkey

   END         
   EXIT_SP:    
  
      SET @d_Trace_EndTime = GETDATE()  
      SET @c_UserName = SUSER_SNAME()  
                                  
   END -- procedure   


GO