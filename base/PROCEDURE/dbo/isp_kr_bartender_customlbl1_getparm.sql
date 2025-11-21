SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/                 
/* Copyright: IDS                                                             */                 
/* Purpose: isp_KR_Bartender_CUSTOMLBL1_GetParm                               */                 
/*                                                                            */                 
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date       Rev  Author     Purposes                                        */                 
/* 2020-12-01 1.0  CSCHONG    Created (WMS-15759)                             */                 
/******************************************************************************/                
                  
CREATE PROC [dbo].[isp_KR_Bartender_CUSTOMLBL1_GetParm]                      
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
   @b_debug             INT = 0                         
)                      
AS                      
BEGIN                      
   SET NOCOUNT ON                 
   SET ANSI_NULLS OFF                
   SET QUOTED_IDENTIFIER OFF                 
   SET CONCAT_NULL_YIELDS_NULL OFF                                     
                              
   DECLARE                                     
      @c_GetOrderKey     NVARCHAR(10),                           
      @n_intFlag         INT,     
      @n_CntRec          INT,    
      @c_SQL             NVARCHAR(4000),        
      @c_SQLSORT         NVARCHAR(4000),        
      @c_SQLJOIN         NVARCHAR(4000)      
    
  DECLARE @d_Trace_StartTime   DATETIME,   
           @d_Trace_EndTime    DATETIME,  
           @c_Trace_ModuleName NVARCHAR(20),   
           @d_Trace_Step1      DATETIME,   
           @c_Trace_Step1      NVARCHAR(20),  
           @c_UserName         NVARCHAR(20)  
  
   SET @d_Trace_StartTime = GETDATE()  
   SET @c_Trace_ModuleName = ''  
        
    -- SET RowNo = 0             
    SET @c_SQL = ''   
    SET @c_GetOrderKey = ''          
    
   IF EXISTS (SELECT 1 FROM PICKDETAIL PD WITH (NOLOCK)  
              JOIN ORDERS OH WITH (NOLOCK) ON PD.Orderkey = OH.Orderkey
              WHERE PD.Orderkey = @c_parm01 AND OH.sostatus = 'HOLD')
   BEGIN
      SET @c_GetOrderKey = @c_parm01
   END
   ELSE
   BEGIN 
    SELECT TOP 1 @c_GetOrderKey = PD.Orderkey
    FROM PICKDETAIL PD WITH (NOLOCK)
    JOIN ORDERS OH WITH (NOLOCK) ON PD.Orderkey = OH.Orderkey
    WHERE PD.Sku = @c_parm01
    AND PD.DropID = @c_parm02
    AND OH.sostatus = 'HOLD'
   END  

  IF ISNULL(@c_GetOrderkey,'') <> ''
  BEGIN            
       SELECT DISTINCT PARM1=@c_GetOrderKey, PARM2='',PARM3='',PARM4='',PARM5='',PARM6='',PARM7='',PARM8='',PARM9='',PARM10=''
       ,Key1='Orderkey',Key2='',Key3='',Key4='',Key5=''     
  END
  ELSE
   BEGIN
     GOTO EXIT_SP
  END
                  
   EXIT_SP:    
  
      SET @d_Trace_EndTime = GETDATE()  
      SET @c_UserName = SUSER_SNAME()  
     
                                 
   END -- procedure   



GO