SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
  
/******************************************************************************/                   
/* Copyright: IDS                                                             */                   
/* Purpose: isp_Bartender_HK_WAYBILLLBL_GetParm                               */                   
/*                                                                            */                   
/* Modifications log:                                                         */                   
/*                                                                            */                   
/* Date       Rev  Author     Purposes                                        */                   
/* 2018-09-06 1.0  CSCHONG    Created (WMS-5999-6131)                          */                   
/******************************************************************************/                  
                    
CREATE PROC [dbo].[isp_Bartender_HK_WAYBILLLBL_GetParm]                        
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
           @c_UserName         NVARCHAR(20),  
           @c_sku              NVARCHAR(20)  
  
    
   SET @d_Trace_StartTime = GETDATE()    
   SET @c_Trace_ModuleName = ''    
          
    -- SET RowNo = 0               
    SET @c_SQL = ''     
    SET @c_SQLJOIN = ''          
  
  
     SET @c_SQLJOIN = ' SELECT DISTINCT PARM1=OH.storerkey,PARM2=OH.Orderkey,PARM3='''',PARM4='''',PARM5='''',' + CHAR(13) +  
                     ' PARM6= '''',PARM7='''',PARM8='''',PARM9='''',PARM10='''',Key1=''Storerkey'',Key2=''orderkey'',Key3='''',Key4='''',Key5='''' ' + CHAR(13) +  
                     ' FROM Orders OH WITH (NOLOCK)  ' + CHAR(13) +  
                     ' WHERE OH.storerkey = @Parm01 '+ CHAR(13) +  
                     ' AND OH.Orderkey = @Parm02 '   
      
        SET @c_ExecArguments = N'@parm01          NVARCHAR(80),'  
                             + ' @parm02          NVARCHAR(80),'   
                             + ' @parm03          NVARCHAR(80),'  
                             + ' @parm04          NVARCHAR(80),'  
                             + ' @parm05          NVARCHAR(80)'  
                         
        
      SET @c_SQL = @c_SQLJOIN + CHAR(13)   
       
     --PRINT @c_SQL  
       
    EXEC sp_executesql   @c_SQL    
                       , @c_ExecArguments    
                       , @parm01    
                       , @parm02   
                       , @parm03   
                       , @parm04  
                       , @parm05  
                         
   EXIT_SP:      
    
      SET @d_Trace_EndTime = GETDATE()    
      SET @c_UserName = SUSER_SNAME()    
  
                                    
   END -- procedure     
  
  

GO