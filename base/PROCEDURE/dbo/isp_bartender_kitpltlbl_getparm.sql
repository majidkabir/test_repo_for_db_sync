SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/                   
/* Copyright: IDS                                                             */                   
/* Purpose: isp_Bartender_KITPLTLBL_GetParm                                   */                   
/*                                                                            */                   
/* Modifications log:                                                         */                   
/*                                                                            */                   
/* Date       Rev  Author     Purposes                                        */                   
/* 2019-04-29 1.0  WLCHOOI    Created(WMS-8769)                               */                              
/******************************************************************************/                  
                    
CREATE PROC [dbo].[isp_Bartender_KITPLTLBL_GetParm]                        
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
  

   SELECT DISTINCT PARM1 = K.Kitkey ,PARM2 = ISNULL(@parm02,''), PARM3='' ,PARM4 = '' ,PARM5 = '',  
                   PARM6 = '',PARM7 = '' ,PARM8 = '',PARM9 = '',PARM10 = '',Key1 = 'Kitkey',Key2 = '',Key3 = '',Key4 = '',Key5 = ''   
   FROM Kit K WITH (NOLOCK)  
   WHERE K.Kitkey = @parm01
 
   EXIT_SP:      
    
      SET @d_Trace_EndTime = GETDATE()    
      SET @c_UserName = SUSER_SNAME()    
     
END -- procedure     

GO