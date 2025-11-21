SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/                 
/* Copyright: IDS                                                             */                 
/* Purpose: isp_BT_Bartender_SHIPUCCLBL_01                                    */                 
/*                                                                            */                 
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date          Rev  Author     Purposes                                     */     
/* 17-SEP-2018   1.0  CSCHONG    WMS-5850&5854 Created                        */   
/* 16-Dec-2020   1.1  WLChooi    WMS-15899 - Add Col60 (WL01)                 */ 
/******************************************************************************/                
                  
CREATE PROC [dbo].[isp_BT_Bartender_SHIPUCCLBL_01]                      
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
           @c_SSTYLE01         NVARCHAR(20),         
           @c_SSTYLE02         NVARCHAR(20),          
           @c_SSTYLE03         NVARCHAR(20),        
           @c_SSTYLE04         NVARCHAR(20),        
           @c_SSTYLE05         NVARCHAR(20),  
           @c_SSTYLE06         NVARCHAR(20), 
           @c_SSTYLE07         NVARCHAR(20),     
           @c_SSIZE01          NVARCHAR(20),         
           @c_SSIZE02          NVARCHAR(20),          
           @c_SSIZE03          NVARCHAR(20),        
           @c_SSIZE04          NVARCHAR(20),        
           @c_SSIZE05          NVARCHAR(20),
           @c_SSIZE06          NVARCHAR(20),
           @c_SSIZE07          NVARCHAR(20),     
           @c_SColor01         NVARCHAR(20),         
           @c_SColor02         NVARCHAR(20),          
           @c_SColor03         NVARCHAR(20),        
           @c_SColor04         NVARCHAR(20),        
           @c_SColor05         NVARCHAR(20),    
           @c_SColor06         NVARCHAR(20),          
           @c_SColor07         NVARCHAR(20),                        
           @c_SKUQty01         NVARCHAR(10),        
           @c_SKUQty02         NVARCHAR(10),         
           @c_SKUQty03         NVARCHAR(10),         
           @c_SKUQty04         NVARCHAR(10),         
           @c_SKUQty05         NVARCHAR(10) ,
           @c_SKUQty06         NVARCHAR(10) ,
           @c_SKUQty07         NVARCHAR(10) ,
           @c_REF01            NVARCHAR(20),         
           @c_REF02            NVARCHAR(20),          
           @c_REF03            NVARCHAR(20),        
           @c_REF04            NVARCHAR(20),        
           @c_REF05            NVARCHAR(20),  
           @c_REF06            NVARCHAR(20),   
           @c_REF07            NVARCHAR(20),
           @n_TTLpage          INT,        
           @n_CurrentPage      INT,
           @n_MaxLine          INT  ,
           @c_cartonno         NVARCHAR(10) ,
           @n_MaxCtnNo         INT,
           @n_skuqty           INT,
           @n_pageQty          INT,
           @n_Pickqty          INT,
           @n_PACKQty          INT,
           @c_col54            NVARCHAR(20) 
  
   SET @d_Trace_StartTime = GETDATE()  
   SET @c_Trace_ModuleName = ''  
        
    -- SET RowNo = 0             
    SET @c_SQL = ''     
    SET @n_CurrentPage = 1
    SET @n_TTLpage =1     
    SET @n_MaxLine = 7  
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
      [SSTYLE]      [NVARCHAR] (20)  NULL,
      [SSIZE]       [NVARCHAR] (20)  NULL,
      [SCOLOR]      [NVARCHAR] (20)  NULL,         
      [Qty]         INT , 
      [CDESCR]      [NVARCHAR] (80)  NULL,  
      [Retrieve]    [NVARCHAR] (1) default 'N')         
           
  SET @c_SQLJOIN = +' SELECT DISTINCT PD.labelno,ORD.c_Company,(ISNULL(RTRIM(ORD.c_address1),'''') + ISNULL(RTRIM(ORD.C_Address2),'''')),'
             + 'S.company,(ISNULL(RTRIM(F.address1),'''') +space(2) + ISNULL(RTRIM(F.Address2),'''') + Space(2) + '
             + ' ISNULL(RTRIM(F.city),'''') + ISNULL(RTRIM(F.country),'''')),'+ CHAR(13)      --5      
             + ' ORD.Externorderkey,'''','''','''','''','     --10  
             + ' '''','''','''','''','''','     --15  
             + ' '''','''','''','''','''','     --20       
             + CHAR(13) +      
             + ' '''','''','''','''','''','''','''','''','''','''','  --30  
             + ' '''','''','''','''','''','''','''','''','''','''','   --40       
             + ' '''','''','''','''','''','''','''','''',ORD.Route,PD.CartonNo, '  --50       
             + ' '''',CONVERT(NVARCHAR(10),ORD.DeliveryDate,111),PIF.weight, '
             + ' '''','''','''',ISNULL(C.description,''''),(ISNULL(RTRIM(ORD.c_city),'''') +Space(2) + ISNULL(RTRIM(ORD.C_country),'''')), '
             --+ ' '''',(RTRIM(PH.Pickslipno) + ''O'') '   --60   --WL01
             + ' '''',ISNULL(ORD.BuyerPO,'''') '   --60   --WL01          
             + CHAR(13) +            
             +' FROM ORDERS ORD WITH (NOLOCK) '
             +' JOIN FACILITY F WITH (NOLOCK) ON F.facility = ORD.Facility'
             +' JOIN STORER S WITH (NOLOCK) ON S.storerkey = ORD.Storerkey'
             +' JOIN PACKHEADER PH WITH (NOLOCK) ON PH.OrderKey = ORD.OrderKey'
             +' JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.Pickslipno = PH.Pickslipno ' 
             +' LEFT JOIN PACKINFO PIF WITH (NOLOCK) ON PIF.Pickslipno = PD.Pickslipno AND PIF.CartonNo = PD.CartonNo '
             + 'LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = ''TMSHIP'' AND C.code=ORD.c_country AND C.storerkey = ORD.Storerkey'
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
      SELECT DISTINCT @c_Sparm01,col50   --WL01     
      FROM #Result               
      --WHERE RIGHT(Col60,1) = 'O'   --WL01   
             
   OPEN CUR_RowNoLoop                  
                
   FETCH NEXT FROM CUR_RowNoLoop INTO @c_Pickslipno,@c_cartonno    
                  
   WHILE @@FETCH_STATUS <> -1             
   BEGIN                 
      IF @b_debug='1'              
      BEGIN              
         PRINT @c_Pickslipno +space(2) +@c_cartonno             
      END 
        
      INSERT INTO [#TEMPSKU] (Pickslipno, cartonno, SKU, SSTYLE, SSIZE, SCOLOR, Qty,CDESCR,
                  Retrieve)
      SELECT DISTINCT PD.Pickslipno,PD.CartonNo,PD.sku,S.Style,S.Size,S.color,
             SUM(PD.Qty),ISNULL(C.Description,''''),'N'
      FROM PACKDETAIL AS PD WITH (NOLOCK)
      JOIN SKU S WITH (NOLOCK) ON s.StorerKey=PD.StorerKey AND s.sku = PD.Sku 
      LEFT JOIN Codelkup C WITH (NOLOCK) ON C.listname = 'TMBUSR1' and C.code = S.Busr1 AND C.storerkey = PD.storerkey
      WHERE PD.Pickslipno = @c_Pickslipno
      AND PD.Cartonno = CAST(@c_cartonno as INT)  
      GROUP BY PD.Pickslipno,PD.CartonNo,PD.sku,S.Style,S.Size,S.color,
               ISNULL(C.Description,'''')
      ORDER BY PD.Pickslipno,PD.Cartonno,PD.sku
         
      SET @c_SKU01 = ''
      SET @c_SKU02 = ''
      SET @c_SKU03 = ''
      SET @c_SKU04 = ''
      SET @c_SKU05= ''
      SET @c_SKU06= ''
      SET @c_SKU07= ''
      SET @c_SSTYLE01 = ''
      SET @c_SSTYLE02 = ''
      SET @c_SSTYLE03 = ''
      SET @c_SSTYLE04 = ''
      SET @c_SSTYLE05= ''
      SET @c_SSTYLE06 = ''
      SET @c_SSTYLE07 = ''
      SET @c_SSIZE01 = ''
      SET @c_SSIZE02 = ''
      SET @c_SSIZE03 = ''
      SET @c_SSIZE04 = ''
      SET @c_SSIZE05= ''
      SET @c_SSIZE06 = ''
      SET @c_SSIZE07 = ''
      SET @c_SColor01 = ''
      SET @c_SColor02 = ''
      SET @c_SColor03 = ''
      SET @c_SColor04 = ''
      SET @c_SColor05= ''
      SET @c_SColor06 = ''
      SET @c_SColor07 = ''
      SET @c_SKUQty01 = ''
      SET @c_SKUQty02 = ''
      SET @c_SKUQty03 = ''
      SET @c_SKUQty04 = ''
      SET @c_SKUQty05 = ''
      SET @c_SKUQty06 = ''
      SET @c_SKUQty07 = ''
      SET @c_REF01 = ''
      SET @c_REF02 = ''
      SET @c_REF03 = ''
      SET @c_REF04 = ''
      SET @c_REF05= ''
      SET @c_REF06= ''
      SET @c_REF07= ''
      SET @n_MaxCtnNo = 0
      SET @n_TTLpage = 1
      SET @n_pageQty = 0
      SET @n_Pickqty = 0
      SET @n_PACKQty = 0
      
            
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
   
      --   SET @c_col54 = CAST(@n_CurrentPage as NVARCHAR(5)) +  '/' + CAST(@n_TTLpage as NVARCHAR(5))
         
   
      SELECT @n_MaxCtnNo = MAX(cartonno)
            ,@n_PACKQty = SUM(Qty)
      FROM PACKDETAIL WITH (NOLOCK)
      WHERE Pickslipno = @c_Pickslipno
   
      SELECT @n_PACKQty = SUM(Qty)
      FROM PACKDETAIL WITH (NOLOCK)
      WHERE Pickslipno = @c_Pickslipno
      and Cartonno <= CAST(@c_cartonno as INT)
          
      SELECT @n_PickQty = SUM(PIDET.Qty)
      FROM PACKHEADER PH WITH (NOLOCK)
      JOIN PICKDETAIL PIDET WITH (NOLOCK) ON PIDET.orderkey = PH.orderkey
      WHERE PH.Pickslipno = @c_Pickslipno
         
      WHILE @n_intFlag <= @n_CntRec           
      BEGIN   
         SELECT @c_sku    = SKU,
                @c_SStyle = SSTYLE,
                @c_SSize  = SSIZE,
                @c_SColor = SCOLOR,
                @n_skuqty = SUM(Qty),
                @c_SDESCR = CDESCR
         FROM #TEMPSKU 
         WHERE ID = @n_intFlag
         GROUP BY SKU,SSTYLE, SSIZE, SCOLOR,CDESCR
         
         IF (@n_intFlag%@n_MaxLine) = 1 
         BEGIN        
            SET @c_sku01    = @c_sku
            SET @c_SSTYLE01 = @c_SStyle
            SET @c_SColor01 = @c_SColor
            SET @c_SSIZE01  = @c_SSize
            SET @c_SKUQty01 = CONVERT(NVARCHAR(10),@n_skuqty)  
            SET @c_REF01    =  @c_SDESCR    
            --  SET @n_pageQty = @n_pageQty
         END        
          
         ELSE IF (@n_intFlag%@n_MaxLine) = 2
         BEGIN        
            SET @c_sku02    = @c_sku
            SET @c_SSTYLE02 = @c_SStyle
            SET @c_SColor02 = @c_SColor
            SET @c_SSIZE02  = @c_SSize
            SET @c_SKUQty02 = CONVERT(NVARCHAR(10),@n_skuqty)
            SET @c_REF02    =  @c_SDESCR          
         END        
           
         ELSE IF (@n_intFlag%@n_MaxLine) = 3
         BEGIN            
            SET @c_sku03    = @c_sku
            SET @c_SSTYLE03 = @c_SStyle
            SET @c_SColor03 = @c_SColor
            SET @c_SSIZE03  = @c_SSize
            SET @c_SKUQty03 = CONVERT(NVARCHAR(10),@n_skuqty) 
            SET @c_REF03    =  @c_SDESCR         
         END        
             
         ELSE IF (@n_intFlag%@n_MaxLine) = 4
         BEGIN        
            SET @c_sku04    = @c_sku
            SET @c_SSTYLE04 = @c_SStyle
            SET @c_SColor04 = @c_SColor
            SET @c_SSIZE04  = @c_SSize
            SET @c_SKUQty04 = CONVERT(NVARCHAR(10),@n_skuqty) 
            SET @c_REF04    =  @c_SDESCR         
         END     
          
         ELSE IF (@n_intFlag%@n_MaxLine) = 5
         BEGIN        
            SET @c_sku05    = @c_sku
            SET @c_SSTYLE05 = @c_SStyle
            SET @c_SColor05 = @c_SColor
            SET @c_SSIZE05  = @c_SSize
            SET @c_SKUQty05 = CONVERT(NVARCHAR(10),@n_skuqty)  
            SET @c_REF05    =  @c_SDESCR        
         END   
          
         ELSE IF (@n_intFlag%@n_MaxLine) = 6
         BEGIN        
            SET @c_sku06    = @c_sku
            SET @c_SSTYLE06 = @c_SStyle
            SET @c_SColor06 = @c_SColor
            SET @c_SSIZE06  = @c_SSize
            SET @c_SKUQty06 = CONVERT(NVARCHAR(10),@n_skuqty)  
            SET @c_REF06    =  @c_SDESCR       
         END      
          
         ELSE IF (@n_intFlag%@n_MaxLine) = 0
         BEGIN        
            SET @c_sku07    = @c_sku
            SET @c_SSTYLE07 = @c_SStyle
            SET @c_SColor07 = @c_SColor
            SET @c_SSIZE07  = @c_SSize
            SET @c_SKUQty07 = CONVERT(NVARCHAR(10),@n_skuqty)  
            SET @c_REF07    =  @c_SDESCR 
 
           --SELECT @n_pageQty = SUM(qty)
           --FROM #TEMPSKU 
           --WHERE ID <= @n_intFlag
                  
         END  
          
          --IF @n_pageQty = 0
          --BEGIN
          --  SELECT @n_pageQty = SUM(qty)
          --  FROM #TEMPSKU
          --END 
   
         SET @n_pageQty = (cast(@c_SKUQty01 as INT ) + cast(@c_SKUQty02 as INT )+ cast(@c_SKUQty03 as INT )
                        + cast(@c_SKUQty04 as INT ) + cast(@c_SKUQty05 as INT ) + cast(@c_SKUQty06 as INT ) +cast(@c_SKUQty07 as INT ))
            
         UPDATE #Result                  
         SET Col07 = @c_sstyle01,         
             Col08 = @c_SColor01,         
             Col09 = @c_SSIZE01,        
             Col10 = @c_sku01, 
             Col11 = @c_REF01,       
             Col12 = @c_SKUQty01,        
             Col13 = @c_sstyle02,        
             Col14 = @c_SColor02,  
             Col15 = @c_SSIZE02,
             Col16 = @c_sku02,
             Col17 = @c_REF02,
             Col18 = @c_SKUQty02,
             Col19 = @c_sstyle03,
             Col20 = @c_SColor03,
             Col21 = @c_SSIZE03,
             Col22 = @c_sku03,
             Col23 = @c_REF03,
             Col24 = @c_SKUQty03,
             Col25 = @c_sstyle04,  
             Col26 = @c_SColor04,  
             Col27 = @c_SSIZE04,  
             Col28 = @c_sku04,  
             Col29 = @c_REF04,
             Col30 = @c_SKUQty04,  
             Col31 = @c_sstyle05,  
             Col32 = @c_SColor05,  
             Col33 = @c_SSIZE05,
             Col34 = @c_sku05, 
             Col35 = @c_REF05, 
             Col36 = @c_SKUQty05,  
             Col37 = @c_sstyle06, 
             Col38 = @c_SColor06,  
             Col39 = @c_SSIZE06,  
             Col40 = @c_sku06,  
             Col41 = @c_REF06,
             Col42 = @c_SKUQty06,  
             Col43 = @c_sstyle07,  
             Col44 = @c_SColor07,  
             Col45 = @c_SSIZE07,  
             Col46 = @c_sku07,
             Col47 = @c_REF07,
             Col48 = @c_SKUQty07,  
             Col51 = CAST(@n_MaxCtnNo AS NVARCHAR(10)),  
             Col54 = CAST(@n_CurrentPage as NVARCHAR(5)) +  '/' + CAST(@n_TTLpage as NVARCHAR(5)),
             Col55 = CAST(@n_pageqty as NVARCHAR(10)),  
             Col56 = CAST(@n_PACKQty as NVARCHAR(10)),             
             Col59 = CAST((@n_pickqty -@n_PACKQty) as nvarchar(10))  
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
            SET @c_SSTYLE01 = ''
            SET @c_SSTYLE02 = ''
            SET @c_SSTYLE03 = ''
            SET @c_SSTYLE04 = ''
            SET @c_SSTYLE05= ''
            SET @c_SSTYLE06 = ''
            SET @c_SSTYLE07 = ''
            SET @c_SSIZE01 = ''
            SET @c_SSIZE02 = ''
            SET @c_SSIZE03 = ''
            SET @c_SSIZE04 = ''
            SET @c_SSIZE05= ''
            SET @c_SSIZE06 = ''
            SET @c_SSIZE07 = ''
            SET @c_SColor01 = ''
            SET @c_SColor02 = ''
            SET @c_SColor03 = ''
            SET @c_SColor04 = ''
            SET @c_SColor05= ''
            SET @c_SColor06 = ''
            SET @c_SColor07 = ''
            SET @c_SKUQty01 = ''
            SET @c_SKUQty02 = ''
            SET @c_SKUQty03 = ''
            SET @c_SKUQty04 = ''
            SET @c_SKUQty05 = ''
            SET @c_SKUQty06 = ''
            SET @c_SKUQty07 = ''
            SET @c_REF01 = ''
            SET @c_REF02 = ''
            SET @c_REF03 = ''
            SET @c_REF04 = ''
            SET @c_REF05= ''
            SET @c_REF06= ''
            SET @c_REF07= ''
            SET @n_pageqty = 0
         
            INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09                 
                                ,Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22               
                                ,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34                
                                ,Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44                 
                                ,Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54               
                                ,Col55,Col56,Col57,Col58,Col59,Col60) 
            SELECT TOP 1 Col01,Col02,Col03,Col04,Col05,Col06,'','','','',                 
                         '','','','','', '','','','','',              
                         '','','','','', '','','','','',              
                         '','','','','', '','','','','',                 
                         '','','','','', '','','',Col49,Col50,               
                         '',Col52,Col53,'','', '',Col57,Col58,'',Col60   --WL01
            FROM  #Result 
            --WHERE RIGHT(Col60,1)='O'   --WL01                    
         END  
          
         SET @n_intFlag = @n_intFlag + 1   
         --SET @n_CntRec = @n_CntRec - 1 
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
      @c_TraceName = 'isp_BT_Bartender_SHIPUCCLBL_01',  
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