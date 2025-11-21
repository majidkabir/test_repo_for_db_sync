SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/                 
/* Copyright: IDS                                                             */                 
/* Purpose: isp_Bartender_UCCLBLSEP_GetParm                                   */                 
/*                                                                            */                 
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date       Rev  Author     Purposes                                        */                 
/* 2020-04-29 1.0  CSCHONG    Created(WMS-12966)                              */                            
/******************************************************************************/                
                  
CREATE PROC [dbo].[isp_Bartender_UCCLBLSEP_GetParm]                      
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
                              
   DECLARE                     
      @c_SQL             NVARCHAR(4000),        
      @c_SQLSORT         NVARCHAR(4000),        
      @c_SQLJOIN         NVARCHAR(4000),
      @c_condition1      NVARCHAR(150) ,
      @c_condition2      NVARCHAR(150),
      @c_SQLGroup        NVARCHAR(4000),
      @c_SQLOrdBy        NVARCHAR(150),
      @c_SQLinsert       NVARCHAR(4000) ,  
      @c_SQLSelect       NVARCHAR(4000),
      @c_PrintbyASN      NVARCHAR(5),
      @c_PrintbyUCC      NVARCHAR(5)
         
      
    
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
        
    -- SET RowNo = 0             
    SET @c_SQL = ''    
    SET @c_SQLJOIN = ''        
    SET @c_condition1 = ''
    SET @c_condition2= ''
    SET @c_SQLOrdBy = ''
    SET @c_SQLGroup = ''
    SET @c_ExecStatements = ''
    SET @c_ExecArguments = ''
    SET @c_SQLinsert = ''
    SET @c_SQLSelect = ''
    SET @c_PrintbyASN = 'N'
    SET @c_PrintbyUCC = 'N'

    IF EXISTS (SELECT 1 FROM RECEIPT WITH (NOLOCK)
                       WHERE receiptkey = @Parm02)
    BEGIN

      SET @c_PrintbyASN = 'Y'

    END

    IF EXISTS (SELECT 1 FROM UCC WITH (NOLOCK)
               WHERE UCCNo = @Parm01)
    BEGIN

     SET @c_PrintbyUCC = 'Y'

    END

     
    IF @c_PrintbyASN = 'Y' 
    BEGIN 
    SELECT DISTINCT PARM1 = RECEIPTDETAIL.Storerkey ,PARM2 = RECEIPTDETAIL.RECEIPTKEY,PARM3= RECEIPTDETAIL.UserDefine01,PARM4 = RECEIPTDETAIL.SKU,PARM5 = '',PARM6 ='',PARM7 = '' ,PARM8 = '',PARM9 = '',PARM10 = '',Key1 = 'ASN',Key2 = '',Key3 = '',Key4 = '',Key5 = ''  FROM  RECEIPTDETAIL RECEIPTDETAIL WITH (NOLOCK)    WHERE  RECEIPTDETAIL.receiptkey = @Parm02  AND  RECEIPTDETAIL.UserDefine01 = CASE WHEN ISNULL(RTRIM(@Parm01),'') <> '' THEN @Parm01 ELSE RECEIPTDETAIL.UserDefine01 END 
    END 
    ELSE IF  @c_PrintbyUCC = 'Y'
    BEGIN 
      SELECT DISTINCT PARM1 = UCC.Storerkey ,PARM2 = UCC.UCCno,PARM3= UCC.SKU,PARM4 = '',PARM5 = '',PARM6 ='',PARM7 = '' ,PARM8 = '',PARM9 = '',PARM10 = '',Key1 = 'UCC',Key2 = '',Key3 = '',Key4 = '',Key5 = '' FROM  UCC WITH (NOLOCK)    WHERE  UCC.uccno = @Parm01 
    END
   
   EXIT_SP:    
  
      SET @d_Trace_EndTime = GETDATE()  
      SET @c_UserName = SUSER_SNAME()  
                                  
   END -- procedure   


GO