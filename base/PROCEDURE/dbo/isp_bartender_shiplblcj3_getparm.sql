SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
 
/******************************************************************************/                     
/* Copyright: LFL                                                             */                     
/* Purpose: isp_Bartender_SHIPLBLCJ3_GetParm                                  */   
/*          Copy and modify from isp_Bartender_SHIPLBLCJ2_GetParm             */                   
/*                                                                            */                     
/* Modifications log:                                                         */                     
/*                                                                            */                     
/* Date       Rev  Author     Purposes                                        */                     
/* 2021-08-13 1.0  WLChooi    Created (WMS-17608)                             */          
/******************************************************************************/                                  
CREATE PROC [dbo].[isp_Bartender_SHIPLBLCJ3_GetParm] (
   @c_parm01            NVARCHAR(250),                  
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
      @n_intFlag         INT,         
      @n_CntRec          INT,        
      @c_SQL             NVARCHAR(4000),            
      @c_SQLSORT         NVARCHAR(4000),            
      @c_SQLJOIN         NVARCHAR(4000)          
        
   DECLARE @d_Trace_StartTime   DATETIME,       
           @d_Trace_EndTime    DATETIME,      
           @c_Trace_ModuleName NVARCHAR(20),       
           @d_Trace_Step1      DATETIME,       
           @c_UserName         NVARCHAR(20),    
           @c_Trace_Step1      NVARCHAR(20),      
           @c_GetParm01        NVARCHAR(30),    
           @c_GetParm02        NVARCHAR(30),    
           @c_GetParm03        NVARCHAR(30),    
           @n_TTLCtn           INT    
      
   SET @d_Trace_StartTime = GETDATE()      
   SET @c_Trace_ModuleName = ''      
            
   -- SET RowNo = 0                 
   SET @c_SQL = ''    
    
   IF EXISTS (SELECT 1 
              FROM ORDERS WITH (NOLOCK)    
              WHERE ORDERS.Orderkey = @c_parm01)    
   BEGIN    
      SELECT @c_GetParm01 = PH.Pickslipno    
      FROM PACKHEADER PH WITH (NOLOCK)    
      WHERE PH.Orderkey = @c_parm01    
            
      SET @c_GetParm02 = CASE WHEN @c_parm02 = '' THEN '1' ELSE @c_parm02 END
      SET @c_Getparm03 = CASE WHEN @c_parm03 = '' THEN '9999' ELSE @c_parm03 END            
   END                      
   ELSE    
   BEGIN    
      SET @c_GetParm01 = @c_parm01    
      SET @c_GetParm02 = CASE WHEN @c_parm02 = '' THEN '1' ELSE @c_parm02 END 
      SET @c_Getparm03 = CASE WHEN @c_parm03 = '' THEN '9999' ELSE @c_parm03 END  
   END     

   SET @n_TTLCtn = 0  
     
   SELECT @n_TTLCtn = MAX(PD.Cartonno)    
   FROM PACKDETAIL PD WITH (NOLOCK)    
   WHERE PD.Pickslipno = @c_GetParm01     

   SELECT DISTINCT PARM1 = PD.Pickslipno, PARM2 = PD.labelno, PARM3 = PD.CartonNo, PARM4 = CAST(@n_TTLCtn AS NVARCHAR(10)), 
                   PARM5 = PH.Storerkey, PARM6 = '', PARM7 = '',    
                   PARM8 = '', PARM9 = '', PARM10 = '',
                   Key1 = 'Pickslipno', Key2 = 'Labelno',    
                   Key3 = CASE WHEN OH.DocType='E' THEN 'ECOM' ELSE 'NONEC' END,  
                   Key4 = OH.ShipperKey, 
                   Key5 = CASE WHEN ISNULL(OH.[Type],'') = '' THEN 'NOTYPE' ELSE OH.[Type] END
   FROM PACKHEADER PH (NOLOCK)     
   JOIN PACKDETAIL PD (NOLOCK) ON PD.Pickslipno = PH.Pickslipno    
   JOIN ORDERS OH WITH (NOLOCK) ON OH.OrderKey = PH.OrderKey   
   WHERE PD.Pickslipno = @c_GetParm01 AND PD.CartonNo >= CONVERT(INT,@c_GetParm02) AND PD.CartonNo <= CONVERT(INT,@c_GetParm03)    
   ORDER BY PD.CartonNo, PD.labelno    
         
EXIT_SP:                                    
END -- procedure       

GO