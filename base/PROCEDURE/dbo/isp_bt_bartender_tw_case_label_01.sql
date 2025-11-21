SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/                 
/* Copyright: IDS                                                             */                 
/* Purpose: isp_BT_Bartender_TW_ID_Label_01                                   */                 
/*                                                                            */                 
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date       Rev  Author     Purposes                                        */                 
/* 2015-08-24 1.0  CSCHONG    Created (SOS350411)                             */ 
/* 2015-11-06 1.1  CSCHONG    Modify col6 logic -mail (CS02)                  */
/* 2017-04-17 5.3  CSCHONG    Fix sql recompile (CS03)                        */ 
/******************************************************************************/                
                  
CREATE PROC [dbo].[isp_BT_Bartender_TW_CASE_Label_01]                      
(  @c_Sparm01            NVARCHAR(250),              
   @c_Sparm02            NVARCHAR(250),              
   @c_Sparm03            NVARCHAR(250),              
   @c_Sparm04            NVARCHAR(250),              
   @c_Sparm05            NVARCHAR(250),              
   @c_Sparm06            NVARCHAR(250),              
   @c_Sparm07            NVARCHAR(250),              
   @c_Sparm08            NVARCHAR(250),              
   @c_Sparm09            NVARCHAR(250),              
   @c_Sparm10            NVARCHAR(250),        
   @b_debug              INT = 0                         
)                      
AS                      
BEGIN                      
   SET NOCOUNT ON                 
   SET ANSI_NULLS OFF                
   SET QUOTED_IDENTIFIER OFF                 
   SET CONCAT_NULL_YIELDS_NULL OFF                
  -- SET ANSI_WARNINGS OFF                    --CS03               
                              
   DECLARE                  
      @c_ReceiptKey      NVARCHAR(10),                    
      @c_GetMaxSku       NVARCHAR(20),                         
      @n_intFlag         INT,     
      @n_CntRec          INT,    
      @c_SQL             NVARCHAR(4000),        
      @c_SQLSORT         NVARCHAR(4000),        
      @c_SQLJOIN         NVARCHAR(4000),
      @n_totalcase       INT,
      @n_sequence        INT,
      @c_skugroup        NVARCHAR(10),
      @n_CntSku          INT,
      @n_TTLQty          INT      
          
    
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
    SET @c_GetMaxSku = '' 
    SET @c_skugroup = ''    
    SET @n_totalcase = 0  
    SET @n_sequence  = 1 
    SET @n_CntSku = 1  
    SET @n_TTLQty = 0     
              
    CREATE TABLE [#Result] (             
      [ID]    [INT] IDENTITY(1,1) NOT NULL,                            
      [Col01] [NVARCHAR] (80) NULL,              
      [Col02] [NVARCHAR] (80) NULL,              
      [Col03] [NVARCHAR] (80) NULL,              
      [Col04] [NVARCHAR] (80) NULL,              
      [Col05] [NVARCHAR] (80) NULL,              
      [Col06] [NVARCHAR] (80) NULL,              
      [Col07] [NVARCHAR] (80) NULL,              
      [Col08] [NVARCHAR] (80) NULL,              
      [Col09] [NVARCHAR] (80) NULL,              
      [Col10] [NVARCHAR] (80) NULL,              
      [Col11] [NVARCHAR] (80) NULL,              
      [Col12] [NVARCHAR] (80) NULL,              
      [Col13] [NVARCHAR] (80) NULL,              
      [Col14] [NVARCHAR] (80) NULL,              
      [Col15] [NVARCHAR] (80) NULL,              
      [Col16] [NVARCHAR] (80) NULL,              
      [Col17] [NVARCHAR] (80) NULL,              
      [Col18] [NVARCHAR] (80) NULL,              
      [Col19] [NVARCHAR] (80) NULL,              
      [Col20] [NVARCHAR] (80) NULL,              
      [Col21] [NVARCHAR] (80) NULL,              
      [Col22] [NVARCHAR] (80) NULL,              
      [Col23] [NVARCHAR] (80) NULL,              
      [Col24] [NVARCHAR] (80) NULL,              
      [Col25] [NVARCHAR] (80) NULL,              
      [Col26] [NVARCHAR] (80) NULL,              
      [Col27] [NVARCHAR] (80) NULL,              
      [Col28] [NVARCHAR] (80) NULL,              
      [Col29] [NVARCHAR] (80) NULL,              
      [Col30] [NVARCHAR] (80) NULL,              
      [Col31] [NVARCHAR] (80) NULL,              
      [Col32] [NVARCHAR] (80) NULL,              
      [Col33] [NVARCHAR] (80) NULL,              
      [Col34] [NVARCHAR] (80) NULL,              
      [Col35] [NVARCHAR] (80) NULL,              
      [Col36] [NVARCHAR] (80) NULL,              
      [Col37] [NVARCHAR] (80) NULL,              
      [Col38] [NVARCHAR] (80) NULL,              
      [Col39] [NVARCHAR] (80) NULL,              
      [Col40] [NVARCHAR] (80) NULL,              
      [Col41] [NVARCHAR] (80) NULL,              
      [Col42] [NVARCHAR] (80) NULL,              
      [Col43] [NVARCHAR] (80) NULL,              
      [Col44] [NVARCHAR] (80) NULL,              
      [Col45] [NVARCHAR] (80) NULL,              
      [Col46] [NVARCHAR] (80) NULL,              
      [Col47] [NVARCHAR] (80) NULL,              
      [Col48] [NVARCHAR] (80) NULL,              
      [Col49] [NVARCHAR] (80) NULL,              
      [Col50] [NVARCHAR] (80) NULL,             
      [Col51] [NVARCHAR] (80) NULL,              
      [Col52] [NVARCHAR] (80) NULL,              
      [Col53] [NVARCHAR] (80) NULL,              
      [Col54] [NVARCHAR] (80) NULL,              
      [Col55] [NVARCHAR] (80) NULL,              
      [Col56] [NVARCHAR] (80) NULL,              
      [Col57] [NVARCHAR] (80) NULL,              
      [Col58] [NVARCHAR] (80) NULL,              
      [Col59] [NVARCHAR] (80) NULL,              
      [Col60] [NVARCHAR] (80) NULL             
     )            
              
            
  SET @c_SQLJOIN = +N' SELECT DISTINCT REC.ReceiptKey,REC.Userdefine06,REC.ExternReceiptkey,'       --3
             +N' CASE WHEN REC.Userdefine01=''Y'' THEN N''急貨'' ELSE '' '' END ,'             --4    
             + ' ISNULL(REC.CarrierName,''''),ISNULL(C.Long,''''),ISNULL(C.description,''''),'''','''','''' ,' --10
             + ''''',REC.warehousereference,'''','''','''', ' --15  
             + ' '''','''','''','''','''','     --20       
         --    + CHAR(13) +      
             + ' '''','''','''','''','''','''','''','''','''','''','  --30  
             + ' '''','''','''','''','''','''','''','''','''','''','   --40       
             + ' '''','''','''','''','''','''','''','''','''','''', '  --50       
             + ' '''','''','''','''','''','''','''','''','''','''' '   --60          
           --  + CHAR(13) +            
             + ' FROM RECEIPT REC WITH (NOLOCK)'       
             + ' JOIN receiptdetail RECDET WITH (nolock) ON RECDET.receiptkey=REC.Receiptkey'   
            --+ ' JOIN SKU S WITH (NOLOCK) ON S.Sku=RECDET.SKU'    
             + ' LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = ''itemclass'' AND C.Code = REC.signatory '
             + ' AND C.storerkey=REC.storerkey'
             + ' WHERE REC.Receiptkey =''' + @c_Sparm01+ ''' '   
             --+ ' RECDET.Toid = CASE WHEN ISNULL(RTRIM(''' + @c_Sparm02+ '''),'''') <> '''' THEN ''' + @c_Sparm02+ ''' ELSE RECDET.Toid END'   
          
IF @b_debug=1        
BEGIN        
   SELECT @c_SQLJOIN          
END                
              
  SET @c_SQL='INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09'  + CHAR(13) +           
             +',Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22'  + CHAR(13) +           
             +',Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34' + CHAR(13) +           
             +',Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44'  + CHAR(13) +           
             +',Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54'+ CHAR(13) +           
             + ',Col55,Col56,Col57,Col58,Col59,Col60) '          
    
SET @c_SQL = @c_SQL + @c_SQLJOIN        
        
EXEC sp_executesql @c_SQL          
        
   IF @b_debug=1        
   BEGIN          
      PRINT @c_SQL          
   END        
   IF @b_debug=1        
   BEGIN        
      SELECT * FROM #Result (nolock)        
   END        

   DECLARE CUR_RowNoLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                         
   SELECT DISTINCT Col01 FROM #Result          
       
   OPEN CUR_RowNoLoop            
       
   FETCH NEXT FROM CUR_RowNoLoop INTO @c_receiptkey    
         
   WHILE @@FETCH_STATUS <> -1            
   BEGIN   
 
   SET @c_getMaxsku = ''

   SELECT @c_getMaxsku = MAX(SKU)
   FROM RECEIPTDETAIL WITH (NOLOCK)
   WHERE RECEIPTKEY = @c_receiptkey

   SELECT  @c_Skugroup = SKUGROUP  
   FROM SKU WITH (NOLOCK)
   WHERE SKU = @c_getMaxsku

   SELECT @n_CntSKU = COUNT(SKU)
         ,@n_TTLQty = SUM(qtyexpected)
   FROM RECEIPTDETAIL WITH (NOLOCK)
   WHERE RECEIPTKEY = @c_receiptkey

   SET @n_totalcase = 1

   SELECT @n_totalcase = containerqty
   FROM RECEIPT WITH (NOLOCK)
   WHERE RECEIPTKEY = @c_receiptkey

   IF @b_debug='1'
   BEGIN
       PRINT 'sku group : ' + @c_Skugroup + ' with total case : ' + convert (nvarchar(10),@n_totalcase)
       PRINT 'count SKU : ' + convert (nvarchar(10),@n_CntSKU) + ' with totla qty : ' + convert (nvarchar(10),@n_TTLQty)
   END

   UPDATE #Result
   SET Col08 = @c_Skugroup,
       Col09 = convert(nvarchar(10),@n_sequence) +'/' + convert(nvarchar(10),@n_totalcase),
       col10 = convert(nvarchar(10),@n_CntSKU),
       Col11 = convert(nvarchar(10),@n_TTLQty)

   WHILE @n_sequence < @n_totalcase
   BEGIN
      
     SET @n_sequence = @n_sequence + 1
     INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09           
            ,Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22         
            ,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34           
            ,Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44           
            ,Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54           
            ,Col55,Col56,Col57,Col58,Col59,Col60)
    SELECT Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,(convert(nvarchar(10),@n_sequence) +'/' + convert(nvarchar(10),@n_totalcase))           
            ,Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22         
            ,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34           
            ,Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44           
            ,Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54           
            ,Col55,Col56,Col57,Col58,Col59,Col60
    FROM #RESULT
    WHERE ID = 1

   END 
  

   FETCH NEXT FROM CUR_RowNoLoop INTO @c_receiptkey    
   END -- While             
   CLOSE CUR_RowNoLoop            
   DEALLOCATE CUR_RowNoLoop                  
       
            
EXIT_SP:    
  
   SET @d_Trace_EndTime = GETDATE()  
   SET @c_UserName = SUSER_SNAME()  
     
   EXEC isp_InsertTraceInfo   
      @c_TraceCode = 'BARTENDER',  
      @c_TraceName = 'isp_BT_Bartender_TW_CASE_Label_01',  
      @c_starttime = @d_Trace_StartTime,  
      @c_endtime = @d_Trace_EndTime,  
      @c_step1 = @c_UserName,  
      @c_step2 = '',  
      @c_step3 = '',  
      @c_step4 = '',  
      @c_step5 = '',  
      @c_col1 = @c_Sparm01,   
      @c_col2 = @c_Sparm02,  
      @c_col3 = @c_Sparm03,  
      @c_col4 = @c_Sparm04,  
      @c_col5 = @c_Sparm05,  
      @b_Success = 1,  
      @n_Err = 0,  
      @c_ErrMsg = ''              
   
   SELECT * FROM #Result (nolock) 
                                  
END -- procedure   



GO