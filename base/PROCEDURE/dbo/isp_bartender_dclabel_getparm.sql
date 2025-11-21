SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/                     
/* Copyright: IDS                                                             */                     
/* Purpose: isp_Bartender_DCLabel_GetParm                                     */                     
/*                                                                            */                     
/* Modifications log:                                                         */                     
/*                                                                            */                     
/* Date       Rev  Author     Purposes                                        */                     
/* 2018-03-05 1.0  CSCHONG    Created (WMS-4242)                              */       
/* 2018-11-15 1.1  WLCHOOI    WMS-6976 - Use SUSR3 to decide which label      */  
/*                            to print                                        */   
/* 2022-02-23 1.1  WLChooi    DevOps Combine Script                           */
/******************************************************************************/                    
                      
 CREATE PROC [dbo].[isp_Bartender_DCLabel_GetParm]                          
(  @parm01           NVARCHAR(250),                  
   @parm02           NVARCHAR(250),                  
   @parm03           NVARCHAR(250),                  
   @parm04           NVARCHAR(250),                  
   @parm05           NVARCHAR(250),                  
   @parm06           NVARCHAR(250),                  
   @parm07           NVARCHAR(250),                  
   @parm08           NVARCHAR(250),                  
   @parm09           NVARCHAR(250),                  
   @parm10           NVARCHAR(250),            
   @b_debug          INT = 0                             
)                          
AS                          
BEGIN                          
   SET NOCOUNT ON                     
   SET ANSI_NULLS OFF                    
   SET QUOTED_IDENTIFIER OFF                     
   SET CONCAT_NULL_YIELDS_NULL OFF                    
                       
                                  
   DECLARE                      
      @c_ReceiptKey        NVARCHAR(10),                        
      @c_ExternOrderKey    NVARCHAR(10),                  
      @c_Deliverydate      DATETIME,                  
      @n_intFlag           INT,         
      @n_CntRec            INT,        
      @c_SQL               NVARCHAR(4000),            
      @c_SQLSORT           NVARCHAR(4000),            
      @c_SQLJOIN           NVARCHAR(4000),    
      @c_condition1        NVARCHAR(150) ,    
      @c_condition2        NVARCHAR(150),    
      @c_SQLGroup          NVARCHAR(4000),    
      @c_SQLOrdBy          NVARCHAR(150),    
      @c_ExecArguments     NVARCHAR(4000)    
          
  DECLARE @d_Trace_StartTime  DATETIME,       
          @d_Trace_EndTime    DATETIME,      
          @c_Trace_ModuleName NVARCHAR(20),       
          @d_Trace_Step1      DATETIME,       
          @c_Trace_Step1      NVARCHAR(20),      
          @c_UserName         NVARCHAR(20),    
          @n_cntsku           INT,    
          @c_mode             NVARCHAR(1),    
          @c_sku              NVARCHAR(20),    
          @c_rpttype          NVARCHAR(20),    
          @c_getUdef09        NVARCHAR(30)         
      
   SET @d_Trace_StartTime = GETDATE()      
   SET @c_Trace_ModuleName = ''      
            
   -- SET RowNo = 0                 
   SET @c_SQL = ''       
   SET @c_mode = '0'       
   SET @c_rpttype = ''    
   SET @c_getUdef09 = ''      
   SET @c_SQLJOIN = ''            
   SET @c_condition1 = ''    
   SET @c_condition2= ''    
   SET @c_SQLOrdBy = ''    
   SET @c_SQLGroup = ''    
    
   --WL01 S
   --SELECT DISTINCT @c_rpttype = ISNULL(C.Short,'WSN')    
   --FROM ORDERS OH WITH (NOLOCK)    
   --LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname='consignee'    
   --AND c.Code=OH.ConsigneeKey    
   --AND C.storerkey = OH.StorerKey    
   --WHERE OH.Orderkey = @parm01    

   SELECT DISTINCT @c_rpttype = ISNULL(Storer.Susr3,'')  
   FROM ORDERS OH (NOLOCK)   
   JOIN Storer (NOLOCK) ON Storer.Storerkey = OH.Consigneekey  
   WHERE OH.Orderkey = @parm01 
  
   IF(@c_rpttype <> 'WSN' AND @c_rpttype <> 'PY')  
   BEGIN  
      GOTO EXIT_SP  
   END 
   --WL01 E
    
   /* SET @c_ExecArguments = ''    
    
    SET @c_SQLJOIN = ' SELECT PARM1=@parm01,PARM2=@parm02,PARM3=@parm03,PARM4=@parm04,PARM5=@parm05,' + CHAR(13) +    
                     ' PARM6=@parm06,PARM7='''',PARM8='''',PARM9='''',PARM10='''',Key1=@c_rpttype,Key2='''',Key3='''',Key4='''',Key5='''' '           
           
        SET @c_ExecArguments = N'@parm01          NVARCHAR(80), '     
                             + ' @parm02          NVARCHAR(80)'    
                             + ' @parm03          NVARCHAR(80)'    
                             + ' @parm04          NVARCHAR(80)'    
                             + ' @parm05          NVARCHAR(80)'    
                             + ' @parm06          NVARCHAR(80)'    
                             + ' @c_rpttype       NVARCHAR(80)'    
                           
          
      SET @c_SQL = @c_SQLJOIN --+ CHAR(13) + @c_condition1 + CHAR(13) +  @c_SQLOrdBy    
         
         
    EXEC sp_executesql   @c_SQL      
                       , @c_ExecArguments        
                       , @parm01     
                       , @parm02     
                       , @parm03     
                       , @parm04     
                       , @parm05     
                       , @parm06     
                       , @c_rpttype    
   */    
                           
                           
   SELECT PARM1=@parm01,PARM2=@parm02,PARM3=@parm03,PARM4=@parm04,PARM5=@parm05,    
          PARM6=@parm06,PARM7='',PARM8='',PARM9='',PARM10='',Key1=@c_rpttype,Key2='',Key3='',Key4='',Key5=''      
                           
   EXIT_SP:        
      
   SET @d_Trace_EndTime = GETDATE()      
   SET @c_UserName = SUSER_SNAME()      
    
                                      
END -- procedure       


GO