SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/******************************************************************************/                   
/* Copyright: IDS                                                             */                   
/* Purpose: isp_Bartender_UCCLBL_GetParm                                      */                   
/*                                                                            */                   
/* Modifications log:                                                         */                   
/*                                                                            */                   
/* Date       Rev  Author     Purposes                                        */  
/*22-Nov-2018 1.0  WLCHOOI    WMS-7030 & WMS-7031 & WMS-7366                  */
/*                            TRIPLE ECOM Shipping Label                      */
/******************************************************************************/                  
                    
CREATE PROC [dbo].[isp_Bartender_UCCLBL_GetParm]                        
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
 --  SET ANSI_WARNINGS OFF                        
                                
   DECLARE                    
      @c_ReceiptKey      NVARCHAR(10),                      
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
      SET @c_GetParm02 = CASE WHEN @c_parm02 = '' THEN '1' ELSE @c_parm02 END      
      SET @c_Getparm03 = CASE WHEN @c_parm03 = '' THEN '9999' ELSE @c_parm03 END               
   END                    
   ELSE  
   BEGIN  
      SET @c_GetParm01 = @c_parm01  
      --SET @c_GetParm02 = @c_parm02  
      --SET @c_Getparm03 = @c_parm03    
      SET @c_GetParm02 = CASE WHEN @c_parm02 = '' THEN '1' ELSE @c_parm02 END      
      SET @c_Getparm03 = CASE WHEN @c_parm03 = '' THEN '9999' ELSE @c_parm03 END   
   END   
      
   SET @n_TTLCtn = 0  
   SELECT @n_TTLCtn = MAX(PDET.Cartonno)  
   FROM PACKDETAIL PDET WITH (NOLOCK)  
   WHERE PDET.Pickslipno = @c_GetParm01   

   SELECT DISTINCT PARM1=PDET.Pickslipno, PARM2=PDET.LabelNo,PARM3='',PARM4='',  
                   PARM5='',PARM6='',PARM7='',  
                   PARM8='',PARM9='',PARM10='',Key1='Pickslipno',Key2='LabelNo', Key3=ISNULL(O.ShipperKey,''),Key4='',Key5=''          
   FROM   PACKHEADER PH (NOLOCK)   
   JOIN PACKDETAIL PDET (NOLOCK) ON PDET.Pickslipno = PH.Pickslipno
   JOIN ORDERS O WITH (NOLOCK) ON o.OrderKey=ph.OrderKey                        
   WHERE PDET.Pickslipno = @c_GetParm01 AND PDET.CartonNo >= CONVERT(INT,@c_GetParm02) AND PDET.CartonNo <= CONVERT(INT,@c_GetParm03)  
                
EXIT_SP:      
    
   SET @d_Trace_EndTime = GETDATE()    
   SET @c_UserName = SUSER_SNAME()    
                           
END -- procedure     

GO