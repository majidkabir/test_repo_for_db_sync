SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/******************************************************************************/                   
/* Copyright: IDS                                                             */                   
/* Purpose: isp_BT_Bartender_PACKINGLBL_Ikea                                  */                   
/*                                                                            */                   
/* Modifications log:                                                         */                   
/*                                                                            */                   
/* Date       Rev  Author     Purposes                                        */  
/*22-NOV-2019 1.0  CSCHONG   Created (WMS-11030)                              */  
/******************************************************************************/                  
                    
CREATE PROC [dbo].[isp_BT_Bartender_PACKINGLBL_Ikea]                        
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
      @c_ReceiptKey      NVARCHAR(10),                      
      @c_Supplier        NVARCHAR(80),                           
      @n_intFlag         INT,       
      @n_CntRec          INT,      
      @c_SQL             NVARCHAR(4000),          
      @c_SQLSORT         NVARCHAR(4000),          
      @c_SQLJOIN         NVARCHAR(4000),  
      @c_col58           NVARCHAR(10),
      @c_labelline       NVARCHAR(10),
      @n_CartonNo        INT        
      
   DECLARE @d_Trace_StartTime  DATETIME,     
           @d_Trace_EndTime    DATETIME,    
           @c_Trace_ModuleName NVARCHAR(20),     
           @d_Trace_Step1      DATETIME,     
           @c_Trace_Step1      NVARCHAR(20),    
           @c_UserName         NVARCHAR(20),      
           @c_Article01        NVARCHAR(50),
           @c_Article02        NVARCHAR(50), 
           @c_Article03        NVARCHAR(50),           
           @c_Article04        NVARCHAR(50),   
           @c_Article05        NVARCHAR(50),           
           @c_Article06        NVARCHAR(50),  
           @c_Article07        NVARCHAR(50),  
		     @c_Article08        NVARCHAR(50),
		     @c_Article09        NVARCHAR(50),
		     @c_Article10        NVARCHAR(50),         
           @c_Supplier01       NVARCHAR(80),           
           @c_Supplier02       NVARCHAR(80),    
           @c_Supplier03       NVARCHAR(80),           
           @c_Supplier04       NVARCHAR(80),   
           @c_Supplier05       NVARCHAR(80),           
           @c_Supplier06       NVARCHAR(80),  
           @c_Supplier07       NVARCHAR(80),  
		     @c_Supplier08       NVARCHAR(80),  
		     @c_Supplier09       NVARCHAR(80),  
		     @c_Supplier10       NVARCHAR(80),           
           @c_SDESCR01         NVARCHAR(10), 
           @c_SDESCR02         NVARCHAR(10),
           @c_SDESCR03         NVARCHAR(10),
           @c_SDESCR04         NVARCHAR(10),
           @c_SDESCR05         NVARCHAR(10),
           @c_SDESCR06         NVARCHAR(10),
           @c_SDESCR07         NVARCHAR(10),
		     @c_SDESCR08         NVARCHAR(10),
		     @c_SDESCR09         NVARCHAR(10),
		     @c_SDESCR10         NVARCHAR(10),                 
           @c_SKUQty01         NVARCHAR(10),          
           @c_SKUQty02         NVARCHAR(10),    
           @c_SKUQty03         NVARCHAR(10),          
           @c_SKUQty04         NVARCHAR(10),     
           @c_SKUQty05         NVARCHAR(10),          
           @c_SKUQty06         NVARCHAR(10),    
           @c_SKUQty07         NVARCHAR(10),
		     @c_SKUQty08         NVARCHAR(10), 
		     @c_SKUQty09         NVARCHAR(10), 
		     @c_SKUQty10         NVARCHAR(10),                      
           @n_TTLpage          INT,          
           @n_CurrentPage      INT,  
           @n_MaxLine          INT  ,  
           @c_refno            NVARCHAR(80) , 
		     @c_pickslipno       NVARCHAR(20) , 
           @c_orderkey         NVARCHAR(20) ,  
           @n_skuqty           INT ,  
           @n_skurqty          INT ,  
           @c_cartonno         NVARCHAR(5),  
           @n_loopno           INT,  
           @c_LastRec          NVARCHAR(1),  
           @c_ExecStatements   NVARCHAR(4000),      
           @c_ExecArguments    NVARCHAR(4000),   
           
           @c_MaxLBLLine       INT,
           @c_SumQTY           INT,
           @n_MaxCarton        INT,
           @c_Article          NVARCHAR(80),
           @n_SumPack          INT,
           @n_SumPick          INT,
           @n_MaxCtnNo         INT, 
           @c_SDESCR           NVARCHAR(10),
		     @n_ttlqty           INT  

    
    SET @d_Trace_StartTime = GETDATE()    
    SET @c_Trace_ModuleName = ''    
          
    -- SET RowNo = 0               
    SET @c_SQL = ''       
    SET @n_CurrentPage = 1  
    SET @n_TTLpage =1       
    SET @n_MaxLine = 10    
    SET @n_CntRec = 1    
    SET @n_intFlag = 1   
    SET @n_loopno = 1        
    SET @c_LastRec = 'Y'  
	 SET @n_ttlqty = 1
                
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
	  [pickslipno]  [NVARCHAR] (50)  NULL,                                          
      [refno]       [NVARCHAR] (50)  NULL,  
      [Article]     [NVARCHAR] (20) NULL,
      [Supplier]    [NVARCHAR] (10) NULL,    
      [SDESCR]      [NVARCHAR] (80) NULL,             
      [PQty]        INT)
      
         
       SET @c_SQLJOIN = +' SELECT DISTINCT MAX(ORD.mbolkey), ISNULL(C.code,''''), MIN(ORD.Userdefine10),CONVERT(NVARCHAR(10),getdate(),110), PD.refno,'   + CHAR(13) --5
                        +' '''','''', '+ CHAR(13) --7
                        +' '''', '+ CHAR(13) --8
                        +' '''', '''', '+ CHAR(13)      --10        
                        +' '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', '+ CHAR(13)  --20
                        +' '''','''','''','''','''','''','''','''','''','''', ' + CHAR(13) --30 
                        +' '''','''','''','''','''','''','''','''','''','''', ' + CHAR(13) --40 
                        +' '''','''','''','''','''','''','''', '+ CHAR(13) --47 
                        + ''''','''','''', ' + CHAR(13) --50 
                        +' '''','''','''','''','''','''','''','''', ' + CHAR(13) --58
                        +' '''', PH.Pickslipno ' + CHAR(13) --60               
                        +' FROM PACKDETAIL PD  WITH (NOLOCK)      '  + CHAR(13)                          
                        +' JOIN PACKHEADER PH WITH (NOLOCK)  ON (PD.PickSlipNo = PH.PickSlipNo) '+ CHAR(13)                               
                        +' JOIN ORDERS ORD WITH (NOLOCK)  ON (ORD.loadkey = PH.loadkey)    '+ CHAR(13)        
                        +' LEFT JOIN CODELKUP C (NOLOCK) ON C.Listname = ''IKEAFAC'' AND C.short = ORD.Facility ' + CHAR(13)                   
                        +'  WHERE PH.Pickslipno = @c_Sparm01 '+ CHAR(13)                            
                        +' AND PD.refno = @c_Sparm02'+ CHAR(13)
						      +' GROUP BY ISNULL(C.code,''''), PD.refno, PH.Pickslipno '

       
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
  
  
 SET @c_ExecArguments = N'     @c_Sparm01          NVARCHAR(80)'
                      +  ',    @c_Sparm02          NVARCHAR(80)'        
                           
                           
   EXEC sp_ExecuteSql     @c_SQL       
                        , @c_ExecArguments      
                        , @c_Sparm01     
                        , @c_Sparm02 
     
          
    --EXEC sp_executesql @c_SQL            
          
   IF @b_debug=1          
   BEGIN            
      PRINT @c_SQL            
   END    
     
           
   IF @b_debug=1          
   BEGIN          
      SELECT * FROM #Result (nolock)          
   END      

   DECLARE CUR_RowNoLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   SELECT DISTINCT col05,col60       
   FROM #Result 
   ORDER BY col05                     
            
   OPEN CUR_RowNoLoop                    
               
   FETCH NEXT FROM CUR_RowNoLoop INTO @c_refno,@c_pickslipno      
                 
   WHILE @@FETCH_STATUS <> -1               
   BEGIN                   
      IF @b_debug='1'                
      BEGIN                
         PRINT @c_refno                   
      END


      INSERT INTO #TEMPSKU (pickslipno,refno,Article,Supplier,SDESCR, PQty)          
      SELECT DISTINCT PH.Pickslipno,PD.refno,SUBSTRING(PD.sku,1,8)
                    , SUBSTRING(PD.sku,9,5)
                    , SUBSTRING(SKU.descr,1,80)
                    , sum(PD.Qty)
      FROM PACKDETAIL PD (NOLOCK) 
      JOIN PACKHEADER PH (NOLOCK) ON PH.PICKSLIPNO = PD.PICKSLIPNO
      JOIN SKU (NOLOCK) ON PD.SKU = SKU.SKU AND PH.STORERKEY = SKU.STORERKEY
      WHERE PH.PICKSLIPNO = @c_pickslipno
      AND PD.refno = @c_refno
      GROUP BY PH.pickslipno,PD.refno,SUBSTRING(PD.sku,1,8)
             , SUBSTRING(PD.sku,9,5)
             , SUBSTRING(SKU.descr,1,80)
      ORDER BY PD.refno,SUBSTRING(PD.sku,1,8) , SUBSTRING(PD.sku,9,5)


	  	  
	  SET @n_ttlqty = 1
	  
	  SELECT @n_ttlqty = SUM(Pqty)
	  FROM  #TEMPSKU 
	  WHERE refno =   @c_refno

	  IF @b_debug='1'                
      BEGIN                
         SELECT '#TEMPSKU',* FROM  #TEMPSKU                   
      END   
      
      SET @c_Article01 = ''
      SET @c_Article02 = ''
      SET @c_Article03 = ''
      SET @c_Article04 = ''
      SET @c_Article05 = ''
      SET @c_Article06 = ''
      SET @c_Article07 = ''
	   SET @c_Article08 = ''
	   SET @c_Article09 = ''
	   SET @c_Article10 = ''
 
      
      SET @c_Supplier01 = ''  
      SET @c_Supplier02 = ''  
      SET @c_Supplier03 = ''  
      SET @c_Supplier04 = ''  
      SET @c_Supplier05 = ''  
      SET @c_Supplier06 = ''  
      SET @c_Supplier07 = '' 
	   SET @c_Supplier08 = '' 
	   SET @c_Supplier09 = '' 
	   SET @c_Supplier10 = '' 
      
      SET @c_SDESCR01 = ''  
      SET @c_SDESCR02 = ''
      SET @c_SDESCR03 = ''
      SET @c_SDESCR04 = ''
      SET @c_SDESCR05 = ''
      SET @c_SDESCR06 = ''
      SET @c_SDESCR07 = ''
	   SET @c_SDESCR08 = ''
	   SET @c_SDESCR09 = ''
	   SET @c_SDESCR10 = ''

      
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
  
  --SELECT * FROM #TEMPSKU  
           
     SELECT @n_CntRec = COUNT (1)  
     FROM #TEMPSKU   
     WHERE refno = @c_refno  
     AND pickslipno = @c_pickslipno    

     SET @n_TTLpage =  FLOOR(@n_CntRec / @n_MaxLine ) + CASE WHEN @n_CntRec % @n_MaxLine > 0 THEN 1 ELSE 0 END   

     WHILE @n_intFlag <= @n_CntRec             
     BEGIN    

       IF @n_intFlag > @n_MaxLine AND (@n_intFlag%@n_MaxLine) = 1 --AND @c_LastRec = 'N'  
       BEGIN  
       
          SET @n_CurrentPage = @n_CurrentPage + 1  
          
          IF (@n_CurrentPage>@n_TTLpage)   
          BEGIN  
             BREAK;  
          END     
          
          INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09                   
                              ,Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22                 
                              ,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34                  
                              ,Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44                   
                              ,Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54                 
                              ,Col55,Col56,Col57,Col58,Col59,Col60)   
          SELECT TOP 1 Col01,Col02,Col03,Col04,Col05,'','','','','',                   
                       '','','','','','','','','','',                
                       '','','','','','','','','','',                
                       '','','','','',CAST(@n_TTLpage as nvarchar(10)),'','','','',                   
                       '','','','','','','','','','',                 
                       '',CAST(@n_ttlqty as nvarchar(10)),'','','','','','','',Col60  
          FROM  #Result
          
        SET @c_Article01 = ''
		  SET @c_Article02 = ''
		  SET @c_Article03 = ''
		  SET @c_Article04 = ''
		  SET @c_Article05 = ''
		  SET @c_Article06 = ''
		  SET @c_Article07 = ''
		  SET @c_Article08 = ''
		  SET @c_Article09 = ''
		  SET @c_Article10 = ''
 
      
		  SET @c_Supplier01 = ''  
		  SET @c_Supplier02 = ''  
		  SET @c_Supplier03 = ''  
		  SET @c_Supplier04 = ''  
		  SET @c_Supplier05 = ''  
		  SET @c_Supplier06 = ''  
		  SET @c_Supplier07 = '' 
		  SET @c_Supplier08 = '' 
		  SET @c_Supplier09 = '' 
		  SET @c_Supplier10 = '' 
          
        SET @c_SDESCR01 = ''  
        SET @c_SDESCR02 = ''
        SET @c_SDESCR03 = ''
        SET @c_SDESCR04 = ''
        SET @c_SDESCR05 = ''
        SET @c_SDESCR06 = ''
        SET @c_SDESCR07 = ''
		  SET @c_SDESCR08 = ''
		  SET @c_SDESCR09 = ''
		  SET @c_SDESCR10 = ''
        
        
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
        
          
       END      
                
      SELECT @c_Article   = Article, 
             @c_Supplier    = Supplier,  
             @n_skuqty = PQty,
             @c_SDESCR  = SDESCR     
      FROM #TEMPSKU   
      WHERE ID = @n_intFlag  

      IF (@n_intFlag%@n_MaxLine) = 1 --AND @n_recgrp = @n_CurrentPage  
      BEGIN   
         SET @c_Article01   = @c_Article          
         SET @c_Supplier01    = @c_Supplier
         SET @c_SKUQty01 = CONVERT(NVARCHAR(10),@n_skuqty) 
         SET @c_SDESCR01  = @c_SDESCR   
      END

      ELSE IF (@n_intFlag%@n_MaxLine) = 2  --AND @n_recgrp = @n_CurrentPage  
      BEGIN      
         SET @c_Article02 = @c_Article        
         SET @c_Supplier02 = @c_Supplier  
         SET @c_SKUQty02 = CONVERT(NVARCHAR(10),@n_skuqty)  
         SET @c_SDESCR02  = @c_SDESCR          
      END   

      ELSE IF (@n_intFlag%@n_MaxLine) = 3  --AND @n_recgrp = @n_CurrentPage  
      BEGIN      
         SET @c_Article03 = @c_Article       
         SET @c_Supplier03 = @c_Supplier  
         SET @c_SKUQty03 = CONVERT(NVARCHAR(10),@n_skuqty)   
         SET @c_SDESCR03  = @c_SDESCR         
      END 

      ELSE IF (@n_intFlag%@n_MaxLine) = 4  --AND @n_recgrp = @n_CurrentPage  
      BEGIN      
         SET @c_Article04 = @c_Article   
         SET @c_Supplier04 = @c_Supplier  
         SET @c_SKUQty04 = CONVERT(NVARCHAR(10),@n_skuqty) 
         SET @c_SDESCR04  = @c_SDESCR            
      END 

      ELSE IF (@n_intFlag%@n_MaxLine) = 5  --AND @n_recgrp = @n_CurrentPage  
      BEGIN      
         SET @c_Article05 = @c_Article     
         SET @c_Supplier05 = @c_Supplier  
         SET @c_SKUQty05 = CONVERT(NVARCHAR(10),@n_skuqty) 
         SET @c_SDESCR05  = @c_SDESCR             
      END 

      ELSE IF (@n_intFlag%@n_MaxLine) = 6  --AND @n_recgrp = @n_CurrentPage  
      BEGIN      
         SET @c_Article06 = @c_Article       
         SET @c_Supplier06 = @c_Supplier  
         SET @c_SKUQty06 = CONVERT(NVARCHAR(10),@n_skuqty)     
         SET @c_SDESCR06  = @c_SDESCR      
      END 

      ELSE IF (@n_intFlag%@n_MaxLine) = 7  --AND @n_recgrp = @n_CurrentPage  
      BEGIN      
         SET @c_Article07 = @c_Article   
         SET @c_Supplier07 = @c_Supplier  
         SET @c_SKUQty07 = CONVERT(NVARCHAR(10),@n_skuqty)   
         SET @c_SDESCR07  = @c_SDESCR         
      END 
	   ELSE IF (@n_intFlag%@n_MaxLine) = 8  --AND @n_recgrp = @n_CurrentPage  
      BEGIN      
         SET @c_Article08 = @c_Article   
         SET @c_Supplier08 = @c_Supplier  
         SET @c_SKUQty08 = CONVERT(NVARCHAR(10),@n_skuqty)   
         SET @c_SDESCR08  = @c_SDESCR         
      END 
	  ELSE IF (@n_intFlag%@n_MaxLine) = 9  --AND @n_recgrp = @n_CurrentPage  
      BEGIN      
         SET @c_Article09 = @c_Article   
         SET @c_Supplier09 = @c_Supplier  
         SET @c_SKUQty09   = CONVERT(NVARCHAR(10),@n_skuqty)   
         SET @c_SDESCR09  = @c_SDESCR         
      END 
	   ELSE IF (@n_intFlag%@n_MaxLine) = 0  --AND @n_recgrp = @n_CurrentPage  
      BEGIN      
         SET @c_Article10 = @c_Article   
         SET @c_Supplier10 = @c_Supplier  
         SET @c_SKUQty10 = CONVERT(NVARCHAR(10),@n_skuqty)   
         SET @c_SDESCR10  = @c_SDESCR         
      END 
      
  UPDATE #Result                    
  SET Col06 = @c_Article01, Col07 = @c_Supplier01,Col08 = @c_SDESCR01, Col09 = @c_SKUQty01,
      Col10 = @c_Article02, Col11 = @c_Supplier02,Col12 = @c_SDESCR02, Col13 = @c_SKUQty02, 
      Col14 = @c_Article03, Col15 = @c_Supplier03,Col16 = @c_SDESCR03, Col17 = @c_SKUQty03, 
      Col18 = @c_Article04, Col19 = @c_Supplier04,Col20 = @c_SDESCR04, Col21 = @c_SKUQty04, 
      Col22 = @c_Article05, Col23 = @c_Supplier05,Col24 = @c_SDESCR05, Col25 = @c_SKUQty05, 
      Col26 = @c_Article06, Col27 = @c_Supplier06,Col28 = @c_SDESCR06, Col29 = @c_SKUQty06,
      Col30 = @c_Article07, Col31 = @c_Supplier07,Col32 = @c_SDESCR07, Col33 = @c_SKUQty07,
	   Col34 = @c_Article08, Col35 = @c_Supplier08,Col36 = @c_SDESCR08, Col37 = @c_SKUQty08,
	   Col38 = @c_Article09, Col39 = @c_Supplier09,Col40 = @c_SDESCR09, Col41 = @c_SKUQty09,
	   Col42 = @c_Article10, Col43 = @c_Supplier10,Col44 = @c_SDESCR10, Col45 = @c_SKUQty10
	  ,Col46 = CAST(@n_TTLpage as nvarchar(10))
	  ,col51 = CAST(@n_ttlqty as nvarchar(10))
    WHERE ID = @n_CurrentPage   
             
        SET @n_intFlag = @n_intFlag + 1    
  
        IF @n_intFlag > @n_CntRec  
        BEGIN  
          BREAK;  
        END        
      END  
      FETCH NEXT FROM CUR_RowNoLoop INTO @c_refno,@c_pickslipno          
          
   END -- While                     
   CLOSE CUR_RowNoLoop                    
   DEALLOCATE CUR_RowNoLoop
   
    
    IF(@b_debug = 1)
    BEGIN
       SELECT @n_SumPick AS SUMPICK, @n_SumPack AS SUMPACK, @n_MaxCtnNo AS MAXCTN, @c_Sparm02 AS CURRENTCTN
    END
   
   SELECT * FROM #Result    

              
EXIT_SP:      
    
   SET @d_Trace_EndTime = GETDATE()    
   SET @c_UserName = SUSER_SNAME()    
       
   EXEC isp_InsertTraceInfo     
      @c_TraceCode = 'BARTENDER',    
      @c_TraceName = 'isp_BT_Bartender_PACKINGLBL_Ikea',    
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