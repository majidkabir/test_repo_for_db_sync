SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/                 
/* Copyright: IDS                                                             */                 
/* Purpose: isp_BT_Bartender_SHIPUCCLBL_04                                    */                 
/*                                                                            */                 
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date          Rev  Author     Purposes                                     */     
/* 12-JAN-2021   1.0  CSCHONG    WMS-15990 Created                            */   
/******************************************************************************/                
                  
CREATE PROC [dbo].[isp_BT_Bartender_SHIPUCCLBL_04]                      
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
                              
   DECLARE                  
      @c_Pickslipno      NVARCHAR(20),                    
      @c_sku             NVARCHAR(20),                         
      @n_intFlag         INT,     
      @n_CntRec          INT,    
      @c_SQL             NVARCHAR(4000),        
      @c_SQLSORT         NVARCHAR(4000),        
      @c_SQLJOIN         NVARCHAR(4000),
      @c_SStyle          NVARCHAR(20),
      @c_SSize           NVARCHAR(20),
      @c_SColor          NVARCHAR(20),
      @c_SDESCR          NVARCHAR(80),
      @c_ExecStatements  NVARCHAR(4000),      
      @c_ExecArguments   NVARCHAR(4000)           
    
  DECLARE  @d_Trace_StartTime  DATETIME,   
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
           @c_SKU06            NVARCHAR(20),   
           @c_SKU07            NVARCHAR(20),   
           @c_SKU08            NVARCHAR(20),     
           @c_SKU09            NVARCHAR(20),  
           @c_SKU10            NVARCHAR(20),                          
           @c_SKUQty01         NVARCHAR(10),        
           @c_SKUQty02         NVARCHAR(10),         
           @c_SKUQty03         NVARCHAR(10),         
           @c_SKUQty04         NVARCHAR(10),         
           @c_SKUQty05         NVARCHAR(10) ,
           @c_SKUQty06         NVARCHAR(10) ,
           @c_SKUQty07         NVARCHAR(10) ,
           @c_SKUQty08         NVARCHAR(10) ,
           @c_SKUQty09         NVARCHAR(10) ,
           @c_SKUQty10         NVARCHAR(10) ,
           @n_TTLpage          INT,        
           @n_CurrentPage      INT,
           @n_MaxLine          INT  ,
           @c_cartonno         NVARCHAR(10) ,
           @n_MaxCtnNo         INT,
           @n_skuqty           INT,
           @n_pageQty          INT,
           @n_Pickqty          INT,
           @n_PACKQty          INT,
           @c_col54            NVARCHAR(20), 
           @c_LineNo01         NVARCHAR(10),        
           @c_LineNo02         NVARCHAR(10),         
           @c_LineNo03         NVARCHAR(10),         
           @c_LineNo04         NVARCHAR(10),         
           @c_LineNo05         NVARCHAR(10) ,
           @c_LineNo06         NVARCHAR(10) ,
           @c_LineNo07         NVARCHAR(10) ,
           @c_LineNo08         NVARCHAR(10) ,
           @c_LineNo09         NVARCHAR(10) ,
           @c_LineNo10         NVARCHAR(10) 
  
   SET @d_Trace_StartTime = GETDATE()  
   SET @c_Trace_ModuleName = ''  
        
    -- SET RowNo = 0             
    SET @c_SQL = ''     
    SET @n_CurrentPage = 1
    SET @n_TTLpage =1     
    SET @n_MaxLine = 10  
    SET @n_CntRec = 1  
    SET @n_intFlag = 1        
    SET @c_col54 = ''
              
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
     
     
   CREATE TABLE [#TEMPSKU] (                   
      [ID]          [INT] IDENTITY(1,1) NOT NULL,                                      
      [Pickslipno]  [NVARCHAR] (20)  NULL,  
      [CartonNo]    [NVARCHAR] (30)  NULL,       
      [SKU]         [NVARCHAR] (20)  NULL,          
      [Qty]         INT , 
      [Retrieve]    [NVARCHAR] (1) default 'N')         
           
  SET @c_SQLJOIN = +' SELECT DISTINCT PIF.Cartonno,ORD.c_Company,ISNULL(RTRIM(ORD.c_country),'''') ,'
             + 'SUBSTRING(ISNULL(RTRIM(ORD.c_address1),'''') +space(2) + ISNULL(RTRIM(ORD.c_Address2),'''') + Space(2) + '
             + ' ISNULL(RTRIM(ORD.c_address3),'''') + ISNULL(RTRIM(ORD.c_address4),''''),1,80),PH.Pickslipno,'+ CHAR(13)      --5      
             + ' ORD.Externorderkey,PIF.cube,PIF.length,PIF.width,PIF.height,'     --10  
             + ' PIF.weight,'''','''','''','''','     --15  
             + ' '''','''','''','''','''','     --20       
             + CHAR(13) +      
             + ' '''','''','''','''','''','''','''','''','''','''','  --30  
             + ' '''','''','''','''','''','''','''','''','''','''','   --40       
             + ' '''','''','''','''','''','''','''','''','''','''', '  --50       
             + ' '''','''','''','''','''','''','''','''','''','''' '   --60     
             + CHAR(13) +            
             +' FROM ORDERS ORD WITH (NOLOCK) '
             +' JOIN PACKHEADER PH WITH (NOLOCK) ON PH.OrderKey = ORD.OrderKey'
             +' JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.Pickslipno = PH.Pickslipno ' 
             +' LEFT JOIN PACKINFO PIF WITH (NOLOCK) ON PIF.Pickslipno = PD.Pickslipno AND PIF.CartonNo = PD.CartonNo '
             +' AND PIF.CartonNo = PD.CartonNo '    
             +' WHERE PD.Pickslipno =  @c_Sparm01'                                           
             +' AND PD.Cartonno >= CONVERT(INT,  @c_Sparm02)'                                
             +' AND PD.Cartonno <= CONVERT(INT,  @c_Sparm03)'                    
            
          
   IF @b_debug=1        
   BEGIN        
      PRINT @c_SQLJOIN          
   END                
                 
   SET @c_SQL='INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09'  + CHAR(13) +           
             +',Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22'  + CHAR(13) +           
             +',Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34' + CHAR(13) +           
             +',Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44'  + CHAR(13) +           
             +',Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54'+ CHAR(13) +           
             +',Col55,Col56,Col57,Col58,Col59,Col60) '          
             
   SET @c_SQL = @c_SQL + @c_SQLJOIN        
           
   --EXEC sp_executesql @c_SQL        
       
   SET @c_ExecArguments = N'  @c_Sparm01           NVARCHAR(80)'    
                         + ', @c_Sparm02           NVARCHAR(80) '    
                         + ', @c_Sparm03           NVARCHAR(80) '                 
                            
   EXEC sp_ExecuteSql     @c_SQL     
                        , @c_ExecArguments    
                        , @c_Sparm01    
                        , @c_Sparm02  
                        , @c_Sparm03 
       
           
   IF @b_debug=1        
   BEGIN          
      PRINT @c_SQL          
   END  
              
   IF @b_debug=1        
   BEGIN        
      SELECT * FROM #Result (nolock)        
   END        
     
   DECLARE CUR_RowNoLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT DISTINCT Col05,col01        
      FROM #Result                 
             
   OPEN CUR_RowNoLoop                  
                
   FETCH NEXT FROM CUR_RowNoLoop INTO @c_Pickslipno,@c_cartonno    
                  
   WHILE @@FETCH_STATUS <> -1             
   BEGIN                 
      IF @b_debug='1'              
      BEGIN              
         PRINT @c_Pickslipno +space(2) +@c_cartonno             
      END 
        
      INSERT INTO [#TEMPSKU] (Pickslipno, cartonno, SKU,  Qty,   Retrieve)
      SELECT DISTINCT PD.Pickslipno,PD.CartonNo,PD.sku,SUM(PD.Qty),'N'
      FROM PACKDETAIL AS PD WITH (NOLOCK)
      JOIN SKU S WITH (NOLOCK) ON s.StorerKey=PD.StorerKey AND s.sku = PD.Sku 
      WHERE PD.Pickslipno = @c_Pickslipno
      AND PD.Cartonno = CAST(@c_cartonno as INT)  
      GROUP BY PD.Pickslipno,PD.CartonNo,PD.sku
      ORDER BY PD.Pickslipno,PD.Cartonno,PD.sku
         
      SET @c_SKU01 = ''
      SET @c_SKU02 = ''
      SET @c_SKU03 = ''
      SET @c_SKU04 = ''
      SET @c_SKU05= ''
      SET @c_SKU06= ''
      SET @c_SKU07= ''
      SET @c_SKU08= ''
      SET @c_SKU09= ''
      SET @c_SKU10= ''
      SET @c_SKUQty01 = ''
      SET @c_SKUQty02 = ''
      SET @c_SKUQty03 = ''
      SET @c_SKUQty04 = ''
      SET @c_SKUQty05 = ''
      SET @c_SKUQty06 = ''
      SET @c_SKUQty07 = ''
      SET @c_SKUQty08 = ''
      SET @c_SKUQty09 = ''
      SET @c_SKUQty10 = ''
      SET @n_MaxCtnNo = 0
      SET @n_TTLpage = 1
      SET @n_pageQty = 0
      SET @n_Pickqty = 0
      SET @n_PACKQty = 0
      SET @c_LineNo01 = ''
      SET @c_LineNo02 = ''
      SET @c_LineNo03 = ''
      SET @c_LineNo04 = ''
      SET @c_LineNo05 = ''
      SET @c_LineNo06 = ''      
      SET @c_LineNo07 = ''
      SET @c_LineNo08 = ''
      SET @c_LineNo09 = ''
      SET @c_LineNo10 = ''
            
      SELECT @n_CntRec = COUNT (1)
      FROM #TEMPSKU 
      WHERE Pickslipno = @c_Pickslipno
      AND Cartonno = @c_cartonno 
      AND Retrieve = 'N'      
         
      SET @n_TTLpage =  FLOOR(@n_CntRec / @n_MaxLine )
   
      IF @n_TTLpage = 0
      BEGIN    
         SET @n_TTLpage = 1
      END
      ELSE
      BEGIN
         IF (@n_CntRec%@n_MaxLine) <> 0
         BEGIN
            SET @n_TTLpage = @n_TTLpage + 1
         END
      END

      SELECT @n_PickQty = SUM(Qty)
      FROM #TEMPSKU 
      WHERE Pickslipno = @c_Pickslipno
      AND Cartonno = @c_cartonno  
   
      --SELECT @n_MaxCtnNo = MAX(cartonno)
      --      ,@n_PACKQty = SUM(Qty)
      --FROM PACKDETAIL WITH (NOLOCK)
      --WHERE Pickslipno = @c_Pickslipno
   
      --SELECT @n_PACKQty = SUM(Qty)
      --FROM PACKDETAIL WITH (NOLOCK)
      --WHERE Pickslipno = @c_Pickslipno
      --and Cartonno <= CAST(@c_cartonno as INT)
          
      --SELECT @n_PickQty = SUM(PIDET.Qty)
      --FROM PACKHEADER PH WITH (NOLOCK)
      --JOIN PICKDETAIL PIDET WITH (NOLOCK) ON PIDET.orderkey = PH.orderkey
      --WHERE PH.Pickslipno = @c_Pickslipno
         
      WHILE @n_intFlag <= @n_CntRec           
      BEGIN   
         SELECT @c_sku    = SKU,
                @n_skuqty = SUM(Qty)
         FROM #TEMPSKU 
         WHERE ID = @n_intFlag
         GROUP BY SKU
         
         IF (@n_intFlag%@n_MaxLine) = 1 
         BEGIN        
            SET @c_sku01    = @c_sku
            SET @c_SKUQty01 = CONVERT(NVARCHAR(10),@n_skuqty)
            SET @c_LineNo01 = CONVERT(NVARCHAR(10),@n_intFlag)   

         END        
          
         ELSE IF (@n_intFlag%@n_MaxLine) = 2
         BEGIN        
            SET @c_sku02    = @c_sku
            SET @c_SKUQty02 = CONVERT(NVARCHAR(10),@n_skuqty)
            SET @c_LineNo02 = CONVERT(NVARCHAR(10),@n_intFlag)  
     
         END        
           
         ELSE IF (@n_intFlag%@n_MaxLine) = 3
         BEGIN            
            SET @c_sku03    = @c_sku
            SET @c_SKUQty03 = CONVERT(NVARCHAR(10),@n_skuqty)   
            SET @c_LineNo03 = CONVERT(NVARCHAR(10),@n_intFlag)        
         END        
             
         ELSE IF (@n_intFlag%@n_MaxLine) = 4
         BEGIN        
            SET @c_sku04    = @c_sku
            SET @c_SKUQty04 = CONVERT(NVARCHAR(10),@n_skuqty)  
            SET @c_LineNo04 = CONVERT(NVARCHAR(10),@n_intFlag)         
         END     
          
         ELSE IF (@n_intFlag%@n_MaxLine) = 5
         BEGIN        
            SET @c_sku05    = @c_sku
            SET @c_SKUQty05 = CONVERT(NVARCHAR(10),@n_skuqty)  
            SET @c_LineNo05 = CONVERT(NVARCHAR(10),@n_intFlag)        
         END   
          
         ELSE IF (@n_intFlag%@n_MaxLine) = 6
         BEGIN        
            SET @c_sku06    = @c_sku
            SET @c_SKUQty06 = CONVERT(NVARCHAR(10),@n_skuqty) 
            SET @c_LineNo06 = CONVERT(NVARCHAR(10),@n_intFlag)        
         END  
         ELSE IF (@n_intFlag%@n_MaxLine) = 7
         BEGIN        
            SET @c_sku07    = @c_sku
            SET @c_SKUQty07 = CONVERT(NVARCHAR(10),@n_skuqty)   
            SET @c_LineNo07 = CONVERT(NVARCHAR(10),@n_intFlag)      
         END  
         ELSE IF (@n_intFlag%@n_MaxLine) = 8
         BEGIN        
            SET @c_sku08    = @c_sku
            SET @c_SKUQty08 = CONVERT(NVARCHAR(10),@n_skuqty) 
            SET @c_LineNo08 = CONVERT(NVARCHAR(10),@n_intFlag)        
         END  
         ELSE IF (@n_intFlag%@n_MaxLine) = 9
         BEGIN        
            SET @c_sku09    = @c_sku
            SET @c_SKUQty09 = CONVERT(NVARCHAR(10),@n_skuqty) 
            SET @c_LineNo09 = CONVERT(NVARCHAR(10),@n_intFlag)        
         END      
          
         ELSE IF (@n_intFlag%@n_MaxLine) = 0
         BEGIN        
            SET @c_sku10    = @c_sku
            SET @c_SKUQty10 = CONVERT(NVARCHAR(10),@n_skuqty)  
            SET @c_LineNo10 = CONVERT(NVARCHAR(10),@n_intFlag)   
                  
         END  
            
         UPDATE #Result                  
         SET Col12 = @c_sku01, 
             Col13 = @c_sku02,
             Col14 = @c_sku03,
             Col15 = @c_sku04,
             Col16 = @c_sku05, 
             Col17 = @c_sku06, 
             Col18 = @c_sku07, 
             Col19 = @c_sku08, 
             Col20 = @c_sku09, 
             Col21 = @c_sku10, 

             Col22 = @c_SKUQty01, 
             Col23 = @c_SKUQty02,   
             Col24 = @c_SKUQty03,    
             Col25 = @c_SKUQty04,  
             Col26 = @c_SKUQty05,
             Col27 = @c_SKUQty06,
             Col28 = @c_SKUQty07,
             Col29 = @c_SKUQty08, 
             Col30 = @c_SKUQty09,
             Col31 = @c_SKUQty10,

             Col32 = @c_LineNo01,
             Col33 = @c_LineNo02,
             Col34 = @c_LineNo03,
             Col35 = @c_LineNo04,
             Col36 = @c_LineNo05,
             Col37 = @c_LineNo06,
             Col38 = @c_LineNo07,
             Col39 = @c_LineNo08,
             Col40 = @c_LineNo09,
             Col41 = @c_LineNo10,

             col42 = CASE WHEN @n_CurrentPage = @n_TTLpage THEN  CAST(@n_PickQty as NVARCHAR(10)) ELSE '' END  

         WHERE ID = @n_CurrentPage  
          
          
         IF (@n_intFlag%@n_MaxLine) = 0 --AND (@n_CntRec - 1) <> 0
         BEGIN
            SET @n_CurrentPage = @n_CurrentPage + 1
   
            SET @c_SKU01 = ''
            SET @c_SKU02 = ''
            SET @c_SKU03 = ''
            SET @c_SKU04 = ''
            SET @c_SKU05= ''
            SET @c_SKU06= ''
            SET @c_SKU07= ''
            SET @c_SKU07= ''
            SET @c_SKU08= ''
            SET @c_SKU09= ''
            SET @c_SKU10= ''
            SET @c_SKUQty01 = ''
            SET @c_SKUQty02 = ''
            SET @c_SKUQty03 = ''
            SET @c_SKUQty04 = ''
            SET @c_SKUQty05 = ''
            SET @c_SKUQty06 = ''
            SET @c_SKUQty07 = ''
            SET @c_SKUQty08 = ''
            SET @c_SKUQty09 = ''
            SET @c_SKUQty10 = ''
            SET @n_pageqty = 0

            SET @c_LineNo01 = ''
            SET @c_LineNo02 = ''
            SET @c_LineNo03 = ''
            SET @c_LineNo04 = ''
            SET @c_LineNo05 = ''
            SET @c_LineNo06 = ''      
            SET @c_LineNo07 = ''
            SET @c_LineNo08 = ''
            SET @c_LineNo09 = ''
            SET @c_LineNo10 = '' 
         
            INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09                 
                                ,Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22               
                                ,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34                
                                ,Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44                 
                                ,Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54               
                                ,Col55,Col56,Col57,Col58,Col59,Col60) 
            SELECT TOP 1 Col01,Col02,Col03,Col04,Col05,Col06,Col07,Col08,Col09,Col10,                 
                         Col11,'','','','', '','','','','',              
                         '','','','','', '','','','','',              
                         '','','','','', '','','','','',                 
                         '','','','','', '','','','','',               
                         '','','','','', '','','','',''   
            FROM  #Result                
         END  
          
         SET @n_intFlag = @n_intFlag + 1   
      END    
     
      FETCH NEXT FROM CUR_RowNoLoop INTO  @c_pickslipno,@c_cartonno           
           
   END -- While                   
   CLOSE CUR_RowNoLoop                  
   DEALLOCATE CUR_RowNoLoop   
             
   SELECT * FROM #Result (nolock)        
            
EXIT_SP:    
  
   SET @d_Trace_EndTime = GETDATE()  
   SET @c_UserName = SUSER_SNAME()  
     
   EXEC isp_InsertTraceInfo   
      @c_TraceCode = 'BARTENDER',  
      @c_TraceName = 'isp_BT_Bartender_SHIPUCCLBL_04',  
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