SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/                 
/* Copyright: IDS                                                             */                 
/* Purpose: isp_BT_Bartender_TW_SKU_Label_02_ELN                              */                 
/*                                                                            */                 
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date       Rev  Author     Purposes                                        */                 
/* 2016-11-18 1.0  CSCHONG    Created (WMS-620)                               */ 
/* 2017-04-17 1.1  CSCHONG    Fix sql recompile (CS01)                       */ 
/******************************************************************************/                
                  
CREATE PROC [dbo].[isp_BT_Bartender_TW_SKU_Label_02_ELN]                      
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
  -- SET ANSI_WARNINGS OFF                   --CS01               
                              
   DECLARE                  
      @c_ReceiptKey      NVARCHAR(10),                    
      @c_sku             NVARCHAR(20),                         
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
           @c_SKU01            NVARCHAR(20),         
			  @c_SKU02            NVARCHAR(20),          
			  @c_SKU03            NVARCHAR(20),        
		     @c_SKU04            NVARCHAR(20),        
			  @c_SKU05            NVARCHAR(20),        
			  @c_SKUQty01         NVARCHAR(10),        
			  @c_SKUQty02         NVARCHAR(10),         
			  @c_SKUQty03         NVARCHAR(10),         
			  @c_SKUQty04         NVARCHAR(10),         
			  @c_SKUQty05         NVARCHAR(10) ,
			  @n_TTLpage          INT,        
           @n_CurrentPage      INT,
           @n_MaxLine          INT  ,
           @c_TOId             NVARCHAR(80) ,
           @c_storerkey        NVARCHAR(20) ,
           @n_skuqty           INT 
  
   SET @d_Trace_StartTime = GETDATE()  
   SET @c_Trace_ModuleName = ''  
        
    -- SET RowNo = 0             
    SET @c_SQL = ''     
    SET @n_CurrentPage = 1
    SET @n_TTLpage =1     
    SET @n_MaxLine = 5    
    SET @n_CntRec = 1  
    SET @n_intFlag = 1        
              
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
     
     
      CREATE TABLE [#TEMPSKU03] (                   
      [ID]          [INT] IDENTITY(1,1) NOT NULL,        
      [ReceiptKey]  [NVARCHAR] (20) NULL,                                  
      [Storerkey]   [NVARCHAR] (20) NULL,  
      [Toid]        [NVARCHAR] (20) NULL,       
      [SKU]         [NVARCHAR] (20) NULL,           
      [Qty]         INT , 
      [Retrieve]    [NVARCHAR] (1) default 'N')         
  	        
  SET @c_SQLJOIN = +' SELECT DISTINCT RECDET.Toid,'''','''','''','''','+ CHAR(13)      --5      
             + ' '''','''','''','''','''','     --10  
             + ' '''','''','''','''','''','     --15  
             + ' '''','''','''','''','''','     --20       
             + CHAR(13) +      
             + ' '''','''','''','''','''','''','''','''','''','''','  --30  
             + ' '''','''','''','''','''','''','''','''','''','''','   --40       
             + ' '''','''','''','''','''','''','''','''','''','''', '  --50       
             + ' '''','''','''','''','''','''','''',RECDET.Receiptkey,RECDET.Storerkey,''O'' '   --60          
             + CHAR(13) +            
          -- + ' FROM RECEIPT REC WITH (NOLOCK)'       
             + ' FROM receiptdetail RECDET WITH (nolock) '   
           --+ ' JOIN SKU S WITH (NOLOCK) ON S.Sku=RECDET.SKU'   
          -- + ' JOIN PACK P WITH (NOLOCK) ON S.Packkey = P.PackKey'  
         --  + ' LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = ''ASNREASON'' AND C.Code = RECDET.conditioncode'
             + ' WHERE RECDET.Receiptkey = ''' + @c_Sparm01+ ''' AND'    
             + ' RECDET.Toid = ''' + @c_Sparm02+ ''' '   
             + ' GROUP BY RECDET.Toid,RECDET.Receiptkey,RECDET.Storerkey '

          
IF @b_debug=1        
BEGIN        
   PRINT @c_SQLJOIN          
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
  SELECT DISTINCT col01,col58 ,col59     
   FROM #Result               
   WHERE Col60 = 'O'         
          
   OPEN CUR_RowNoLoop                  
             
   FETCH NEXT FROM CUR_RowNoLoop INTO @c_toid,@c_ReceiptKey,@c_storerkey    
               
   WHILE @@FETCH_STATUS <> -1             
   BEGIN                 
      IF @b_debug='1'              
      BEGIN              
         PRINT @c_toid                 
      END 
      
      
      INSERT INTO [#TEMPSKU03] (ReceiptKey,Storerkey,SKU,toid,Qty,Retrieve)
      SELECT DISTINCT RD.ReceiptKey,RD.StorerKey,RD.SKU,RD.ToId,SUM(RD.QtyReceived),'N'
      FROM RECEIPTDETAIL AS RD WITH (NOLOCK) 
      WHERE Receiptkey =  @c_ReceiptKey
      AND Toid = @c_toid
      AND StorerKey = @c_storerkey  
      GROUP BY  RD.ReceiptKey,RD.StorerKey,RD.SKU,RD.ToId 
      
      SET @c_SKU01 = ''
      SET @c_SKU02 = ''
      SET @c_SKU03 = ''
      SET @c_SKU04 = ''
      SET @c_SKU05= ''
      SET @c_SKUQty01 = ''
      SET @c_SKUQty02 = ''
      SET @c_SKUQty03 = ''
      SET @c_SKUQty04 = ''
      SET @c_SKUQty05 = ''
         
      SELECT @n_CntRec = COUNT (1)
      FROM #TEMPSKU03 
      WHERE Receiptkey =  @c_ReceiptKey
      AND Toid = @c_toid
      AND StorerKey = @c_storerkey 
      AND Retrieve = 'N' 
      
      SET @n_TTLpage =  FLOOR(@n_CntRec / @n_MaxLine )
      
      
     WHILE @n_intFlag <= @n_CntRec           
     BEGIN   
     	
      SELECT @c_sku = SKU,
            @n_skuqty = SUM(Qty)
      FROM #TEMPSKU03 
      WHERE ID = @n_intFlag
      GROUP BY SKU
     	
     	IF (@n_intFlag%@n_MaxLine) = 1 
       BEGIN        
        SET @c_sku01 = @c_sku
        SET @c_SKUQty01 = CONVERT(NVARCHAR(10),@n_skuqty)        
       END        
       
       ELSE IF (@n_intFlag%@n_MaxLine) = 2
       BEGIN        
        SET @c_sku02 = @c_sku
        SET @c_SKUQty02 = CONVERT(NVARCHAR(10),@n_skuqty)        
       END        
        
       ELSE IF (@n_intFlag%@n_MaxLine) = 3
       BEGIN            
        SET @c_sku03 = @c_sku
        SET @c_SKUQty03 = CONVERT(NVARCHAR(10),@n_skuqty)       
       END        
          
       ELSE IF (@n_intFlag%@n_MaxLine) = 4
       BEGIN        
        SET @c_sku04 = @c_sku
        SET @c_SKUQty04 = CONVERT(NVARCHAR(10),@n_skuqty)       
       END        
      
       ELSE IF (@n_intFlag%@n_MaxLine) = 0
       BEGIN        
        SET @c_sku05 = @c_sku
        SET @c_SKUQty05 = CONVERT(NVARCHAR(10),@n_skuqty)       
       END 
         
         
       UPDATE #Result                  
       SET Col02 = @c_sku01,         
           Col03 = @c_SKUQty01,        
           Col04 = @c_sku02,                
           Col05 = @c_SKUQty02,         
           Col06 = @c_sku03,         
           Col07 = @c_SKUQty03,        
           Col08 = @c_sku04,        
           Col09 = @c_SKUQty04,        
           Col10 = @c_sku05,        
           Col11 = @c_SKUQty05    
       WHERE ID = @n_CurrentPage  
       
       
   IF (@n_intFlag%@n_MaxLine) = 0 --AND (@n_CntRec - 1) <> 0
    BEGIN
    	SET @n_CurrentPage = @n_CurrentPage + 1
    	
      SET @c_SKU01 = ''
      SET @c_SKU02 = ''
      SET @c_SKU03 = ''
      SET @c_SKU04 = ''
      SET @c_SKU05= ''
      SET @c_SKUQty01 = ''
      SET @c_SKUQty02 = ''
      SET @c_SKUQty03 = ''
      SET @c_SKUQty04 = ''
      SET @c_SKUQty05 = ''
    	
    	INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09                 
                            ,Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22               
                            ,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34                
                            ,Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44                 
                            ,Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54               
                            ,Col55,Col56,Col57,Col58,Col59,Col60) 
      SELECT TOP 1 Col01,'','','','', '','','','','',                 
                   '','','','','', '','','','','',              
                   '','','','','', '','','','','',              
                   '','','','','', '','','','','',                 
                   '','','','','', '','','','','',               
                   '','','','','', '','','','',''
     FROM  #Result 
      WHERE Col60='O'                    
    	
    END  
       
    SET @n_intFlag = @n_intFlag + 1   
    --SET @n_CntRec = @n_CntRec - 1 

           
  END    
  
   FETCH NEXT FROM CUR_RowNoLoop INTO @c_toid,@c_ReceiptKey,@c_storerkey          
        
      END -- While                   
      CLOSE CUR_RowNoLoop                  
      DEALLOCATE CUR_RowNoLoop   
      	 
SELECT * FROM #Result (nolock)        
            
EXIT_SP:    
  
   SET @d_Trace_EndTime = GETDATE()  
   SET @c_UserName = SUSER_SNAME()  
     
   EXEC isp_InsertTraceInfo   
      @c_TraceCode = 'BARTENDER',  
      @c_TraceName = 'isp_BT_Bartender_TW_SKU_Label_02_ELN',  
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
   
  
                                  
END -- procedure   



GO