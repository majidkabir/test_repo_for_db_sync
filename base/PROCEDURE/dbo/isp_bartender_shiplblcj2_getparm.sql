SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
    
    
/******************************************************************************/                     
/* Copyright: IDS                                                             */                     
/* Purpose: isp_Bartender_SHIPLBLCJ2_GetParm                                  */                     
/*                                                                            */                     
/* Modifications log:                                                         */                     
/*                                                                            */                     
/* Date       Rev  Author     Purposes                                        */                     
/* 2018-01-12 1.0  CSCHONG    Created (WMS-3415)                              */       
/* 2018-05-21 1.1  CSCHONG    WMS-4871&WMS4952 cater for nonecom (CS01)       */        
/* 2018-07-18 1.2  CSCHONG    WMS-5582 add new field (CS02)                   */       
/* 2018-10-23 1.3  WLCHOOI    Edit the logic of @c_GetParm02 and @c_GetParm03 */     
/* 2019-05-02 1.4  CSCHONG    WMS-8875 - revised printing logic (CS03)        */      
/******************************************************************************/                    
                      
CREATE PROC [dbo].[isp_Bartender_SHIPLBLCJ2_GetParm]                          
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
      @c_ReceiptKey        NVARCHAR(10),                        
      @c_ExternOrderKey  NVARCHAR(10),                  
      @c_Deliverydate    DATETIME,                  
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
    
    IF EXISTS (SELECT 1 FROM ORDERS WITH (NOLOCK)    
                WHERE ORDERS.Orderkey = @c_parm01)    
    BEGIN    
     SELECT @c_GetParm01 = MIN(PH.Pickslipno)     
                           FROM PACKHEADER PH WITH (NOLOCK)    
                           WHERE PH.Orderkey = @c_parm01    
     --SET @c_GetParm02 = '1'    
     --SET @c_Getparm03 = '9999'         
     SET @c_GetParm02 = CASE WHEN @c_parm02 = '' THEN '1' ELSE @c_parm02 END       --(WL01)  
     SET @c_Getparm03 = CASE WHEN @c_parm03 = '' THEN '9999' ELSE @c_parm03 END    --(WL01)               
    END                      
    ELSE    
    BEGIN    
     SET @c_GetParm01 = @c_parm01    
     --SET @c_GetParm02 = @c_parm02    
     --SET @c_Getparm03 = @c_parm03      
     SET @c_GetParm02 = CASE WHEN @c_parm02 = '' THEN '1' ELSE @c_parm02 END      --(WL01)  
     SET @c_Getparm03 = CASE WHEN @c_parm03 = '' THEN '9999' ELSE @c_parm03 END   --(WL01)    
    END     
        
   --CS02 Start    
  SET @n_TTLCtn = 0    
  SELECT @n_TTLCtn = MAX(PDET.Cartonno)    
  FROM PACKDETAIL PDET WITH (NOLOCK)    
  WHERE PDET.Pickslipno = @c_GetParm01     
    --CS02 END    
    
    SELECT DISTINCT PARM1=PDET.Pickslipno, PARM2=PDET.labelno,PARM3=PDET.CartonNo,PARM4=CAST(@n_TTLCtn as nvarchar(10)),  --CS02    
                    PARM5=PH.Storerkey,PARM6='',PARM7='',    
                    PARM8='',PARM9='',PARM10='',Key1='Pickslipno',Key2='labelno',    
                   -- Key3=CASE WHEN UPPER(o.type)='ECOM' THEN 'ECOM' ELSE 'NONEC' END,Key4='',Key5=''           --(CS01)  --CS03  
                    Key3=CASE WHEN O.DocType='E' THEN 'ECOM' ELSE 'NONEC' END,  
                    Key4=O.ShipperKey,Key5=''  
    FROM   PACKHEADER PH (NOLOCK)     
    JOIN PACKDETAIL PDET (NOLOCK) ON PDET.Pickslipno = PH.Pickslipno    
    JOIN ORDERS O WITH (NOLOCK) ON o.OrderKey=ph.OrderKey                         --(CS01)    
    WHERE PDET.Pickslipno = @c_GetParm01 AND PDET.CartonNo >= CONVERT(INT,@c_GetParm02) AND PDET.CartonNo <= CONVERT(INT,@c_GetParm03)    
    ORDER BY PDET.CartonNo,PDET.labelno    
         
                
   EXIT_SP:        
      
      SET @d_Trace_EndTime = GETDATE()      
      SET @c_UserName = SUSER_SNAME()      
                             
   END -- procedure       


GO