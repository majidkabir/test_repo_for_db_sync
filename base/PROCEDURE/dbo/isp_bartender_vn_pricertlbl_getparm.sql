SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/******************************************************************************/                   
/* Copyright: LFL                                                             */                   
/* Purpose: isp_Bartender_VN_PRICERTLBL_GetParm                               */   
/*        : Copy from isp_Bartender_VN_PRICERTLBL_GetParm                     */                 
/*                                                                            */                   
/* Modifications log:                                                         */                   
/*                                                                            */                   
/* Date       Rev  Author     Purposes                                        */                   
/* 2020-07-10 1.0  WLChooi    Created (WMS-14217)                             */    
/* 2020-09-17 1.1  WLChooi    WMS-15163 Remove Table Linkage to Receipt (WL01)*/            
/******************************************************************************/                  
                    
CREATE PROC [dbo].[isp_Bartender_VN_PRICERTLBL_GetParm]                        
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
   SET @c_SQLJOIN = ''          
   SET @c_condition1 = ''  
   SET @c_condition2= ''  
   SET @c_SQLOrdBy = ''  
   SET @c_SQLGroup = ''  
     
   --SELECT DISTINCT @c_getUCCno = ISNULL(UccNo,'')  
   --FROM UCC WITH (NOLOCK)  
   --WHERE UccNo = @parm01  
   --AND STATUS='1'  
     
   --SELECT DISTINCT @c_getUdef09 = ISNULL(UccNo,'')  
   --FROM UCC WITH (NOLOCK)  
   --WHERE Userdefined09 = @parm01  
     
   SET @c_ExecArguments = ''  

   IF EXISTS(SELECT 1 FROM RECEIPT R WITH (NOLOCK) WHERE R.receiptkey = @Parm01) 
   BEGIN  
      SET @c_SQLJOIN = ' SELECT DISTINCT PARM1=RH.Receiptkey,PARM2=RD.SKU,PARM3=RH.Storerkey,PARM4='''',PARM5='''',' + CHAR(13) +  
                       ' PARM6= '''',PARM7='''',PARM8='''',PARM9='''',PARM10='''',Key1=''Receiptkey'',Key2=''SKU'',Key3='''',Key4='''',Key5='''' ' + CHAR(13) +  
                       ' FROM RECEIPT RH WITH (NOLOCK)  ' + CHAR(13) +  
                       ' JOIN RECEIPTDETAIL RD WITH (NOLOCK) ON (RH.Receiptkey = RD.Receiptkey)' + CHAR(13) +  
                       ' WHERE RH.Receiptkey = @Parm01 '+ CHAR(13) +  
                       ' AND RD.SKU = @Parm02 ' + CHAR(13) +  
                       ' AND RH.Doctype <> ''R'' '    
   
   END  
   ELSE IF EXISTS(SELECT 1 FROM STORER ST WITH (NOLOCK) WHERE ST.storerkey = @Parm01)   
   BEGIN  
   	--WL01 START
      --SET @c_SQLJOIN = ' SELECT DISTINCT TOP 1 PARM1=RH.Receiptkey,PARM2=RD.SKU,PARM3=RH.Storerkey,PARM4='''',PARM5='''',' + CHAR(13) +  
      --                 ' PARM6= '''',PARM7='''',PARM8='''',PARM9='''',PARM10='''',Key1=''Receiptkey'',Key2=''SKU'',Key3='''',Key4='''',Key5='''' ' + CHAR(13) +  
      --                 ' FROM RECEIPT RH WITH (NOLOCK)  ' + CHAR(13) +  
      --                 ' JOIN RECEIPTDETAIL RD WITH (NOLOCK) ON (RH.Receiptkey = RD.Receiptkey)' + CHAR(13) +  
      --                 ' WHERE RH.storerkey = @Parm01 '+ CHAR(13) +  
      --                 ' AND RD.SKU = @Parm02 ' + CHAR(13) +  
      --                 ' AND RH.Doctype <> ''R'' '  + CHAR(13) +  
      --                 ' ORDER BY RH.receiptkey desc'  
      SET @c_SQLJOIN = ' SELECT DISTINCT TOP 1 PARM1=S.Storerkey,PARM2=S.SKU,PARM3='''',PARM4='''',PARM5='''',' + CHAR(13) +  
                       ' PARM6= '''',PARM7='''',PARM8='''',PARM9='''',PARM10='''',Key1=''Receiptkey'',Key2=''SKU'',Key3='''',Key4='''',Key5='''' ' + CHAR(13) +  
                       ' FROM SKU S WITH (NOLOCK)  ' + CHAR(13) +  
                       ' WHERE S.storerkey = @Parm01 '+ CHAR(13) +  
                       ' AND S.SKU = @Parm02 '
      --WL01 END
   END 
   
   SET @c_ExecArguments = N' @parm01          NVARCHAR(80),'  
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