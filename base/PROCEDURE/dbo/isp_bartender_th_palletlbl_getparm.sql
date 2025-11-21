SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
        
/******************************************************************************/                         
/* Copyright: IDS                                                             */                         
/* Purpose: isp_Bartender_TH_PALLETLBL_GetParm                                */                         
/*                                                                            */                         
/* Modifications log:                                                         */                         
/*                                                                            */                         
/* Date         Rev  Author     Purposes                                      */                            
/* 21-Feb-2019  1.1  CHEEMUN    SCTASK0310656 - Filter Non-Return Receipt     */        
/* 20-Feb-2020  1.2  WLChooi    WMS-12113-Cater for Storerkey = 'MATA' (WL01) */   
/* 25-JAN-2021  1.3  CSCHONG    WMS-16146 - add new param (CS01               */                 
/******************************************************************************/                        
                          
CREATE PROC [dbo].[isp_Bartender_TH_PALLETLBL_GetParm]                              
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
      @c_ReceiptKey      NVARCHAR(10),     
      @c_StorerKey       NVARCHAR(10),       
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
      
            
   SET @c_ExecArguments = ''        
        
   SELECT @c_StorerKey = STORERKEY FROM RECEIPT WITH (NOLOCK)    
   WHERE RECEIPTKEY = @Parm01  
     
   --SCTASK0310656 (START)    
   IF (@c_StorerKey = 'UA')    
   BEGIN    
      SET @c_SQLJOIN = ' SELECT DISTINCT PARM1 = RD.Receiptkey,PARM2 = RD.SKU,PARM3= '''',PARM4 = '''',PARM5 = '''',' + CHAR(13) +       
                       ' PARM6 ='''',PARM7 = '''' ,PARM8 = '''',PARM9 = '''',PARM10 = '''',' + CHAR(13) +     
                       ' Key1 = ''Receiptkey'',Key2 = ''SKU'',Key3 = '''',Key4 = '''',Key5 = '''' ' + CHAR(13) +        
                       ' FROM RECEIPT RH WITH (NOLOCK)  ' + CHAR(13) +        
                       ' JOIN RECEIPTDETAIL RD WITH (NOLOCK) ON (RH.Receiptkey = RD.Receiptkey AND RH.STORERKEY = RD.STORERKEY)' + CHAR(13) +        
                       ' WHERE RH.Receiptkey = @Parm01 ' +        
                       ' AND RD.Lottable07 = @Parm02 ' +        
                       ' AND RD.SKU= @Parm03 '    
      SET @c_condition1 = ' AND LEFT(LTRIM(RH.NOTES),2) <> ''RE'' '          
      SET @c_SQLJOIN = @c_SQLJOIN + @c_condition1    
        
   END    
   --SCTASK0310656 (END)  
   --WL01 START
   ELSE IF (@c_StorerKey = 'MATA')
   BEGIN
      SET @c_SQLJOIN = ' SELECT DISTINCT PARM1 = RD.Receiptkey, PARM2 = RD.Lottable02, ' + CHAR(13) +     
                       ' PARM3= CASE WHEN ISNULL(@Parm03,'''') <> '''' THEN @Parm03 ELSE ''0'' END'  + CHAR(13) + --CS01 
                       ' , PARM4 = '''', PARM5 = '''',' + CHAR(13) +       
                       ' PARM6 ='''',PARM7 = '''' ,PARM8 = '''',PARM9 = '''',PARM10 = '''',' + CHAR(13) +     
                       ' Key1 = ''Receiptkey'',Key2 = ''SKU'',Key3 = '''',Key4 = '''',Key5 = '''' ' + CHAR(13) +        
                       ' FROM RECEIPT RH WITH (NOLOCK)  ' + CHAR(13) +        
                       ' JOIN RECEIPTDETAIL RD WITH (NOLOCK) ON (RH.Receiptkey = RD.Receiptkey AND RH.STORERKEY = RD.STORERKEY)' + CHAR(13) +        
                       ' WHERE RH.Receiptkey = @Parm01 ' +          
                       ' AND RD.Lottable02 = CASE WHEN ISNULL(@Parm02,'''') = '''' THEN RD.Lottable02 ELSE @Parm02 END '
   END
   --WL01 END  
   ELSE    
   BEGIN    
      SET @c_SQLJOIN = ' SELECT DISTINCT PARM1 = RD.Receiptkey ,PARM2 = RD.SKU,PARM3= '''',PARM4 = '''',PARM5 = '''',' + CHAR(13) +       
                       ' PARM6 ='''',PARM7 = '''' ,PARM8 = '''',PARM9 = '''',PARM10 = '''',' + CHAR(13) +     
                       ' Key1 = ''Receiptkey'',Key2 = ''SKU'',Key3 = '''',Key4 = '''',Key5 = '''' ' + CHAR(13) +        
                       ' FROM RECEIPT RH WITH (NOLOCK)  ' + CHAR(13) +        
                       ' JOIN RECEIPTDETAIL RD WITH (NOLOCK) ON (RH.Receiptkey = RD.Receiptkey AND RH.STORERKEY = RD.STORERKEY)' + CHAR(13) +        
                       ' WHERE RH.Receiptkey = @Parm01 ' +        
                       ' AND RD.Lottable07 = @Parm02 ' +        
                       ' AND RD.SKU= @Parm03 '     
   END    
     
   SET @c_ExecArguments = N' @parm01          NVARCHAR(80),'        
                          +' @parm02          NVARCHAR(80),'         
                          +' @parm03          NVARCHAR(80),'    
                          +' @parm04          NVARCHAR(80),'   --WL01   
                          +' @parm05          NVARCHAR(80) '   --WL01                          
              
   SET @c_SQL = @c_SQLJOIN         
        
             
   EXEC sp_executesql   @c_SQL          
                      , @c_ExecArguments          
                      , @parm01          
                      , @parm02        
                      , @parm03   
                      , @parm04   --WL01
                      , @parm05   --WL01       
        
     -- print   @c_SQL                   
   EXIT_SP:            
          
   SET @d_Trace_EndTime = GETDATE()          
   SET @c_UserName = SUSER_SNAME()          
        
                                          
END -- procedure 



GO