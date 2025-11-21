SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/                 
/* Copyright: IDS                                                             */                 
/* Purpose: isp_Bartender_GetParm                                             */                 
/*                                                                            */                 
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date       Rev  Author     Purposes                                        */                 
/* 2014-10-15 1.0  CSCHONG    Created (SOS367787)                             */                 
/******************************************************************************/                
                  
CREATE PROC [dbo].[isp_Bartender_GetParm]                      
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
   SET ANSI_WARNINGS OFF                      
                              
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
           @c_Trace_Step1      NVARCHAR(20),  
           @c_UserName         NVARCHAR(20),
           @n_cntsku           INT,
           @c_mode             NVARCHAR(1),
           @c_sku              NVARCHAR(20),
           @c_getUCCno         NVARCHAR(20),
           @c_getUdef09        NVARCHAR(30)     
  
   SET @d_Trace_StartTime = GETDATE()  
   SET @c_Trace_ModuleName = ''  
        
    -- SET RowNo = 0             
    SET @c_SQL = ''   
    SET @c_mode = '0'   
    SET @c_getUCCno = ''
    SET @c_getUdef09 = ''          
    
    SELECT DISTINCT @c_getUCCno = ISNULL(UccNo,'')
    FROM UCC WITH (NOLOCK)
    WHERE UccNo = @c_parm01
    AND STATUS='1'
    
    SELECT DISTINCT @c_getUdef09 = ISNULL(UccNo,'')
    FROM UCC WITH (NOLOCK)
    WHERE Userdefined09 = @c_parm01
     
    IF @c_getUdef09 = '' AND @c_getUCCno <> ''
    BEGIN          
		 SELECT DISTINCT PARM1=U.UCCNo, PARM2='',PARM3='',PARM4='',PARM5='',PARM6='',PARM7='',PARM8='',PARM9='',PARM10=''
		 ,Key1='UccNo',Key2='',Key3='',Key4='',Key5='' 
		 FROM UCC U (NOLOCK) WHERE U.UccNo = @c_parm01
    END
    ELSE
    BEGIN
    	
		 SELECT DISTINCT PARM1=U.Userdefined09, PARM2='M',PARM3='',PARM4='',PARM5='',PARM6='',PARM7='',PARM8='',PARM9='',PARM10=''
		 ,Key1='UccNo',Key2='',Key3='',Key4='',Key5='' 
		 FROM UCC U (NOLOCK) WHERE U.Userdefined09 = @c_parm01
    	
    END	
       
            
   EXIT_SP:    
  
      SET @d_Trace_EndTime = GETDATE()  
      SET @c_UserName = SUSER_SNAME()  
     
             
   
  
                                  
   END -- procedure   



GO