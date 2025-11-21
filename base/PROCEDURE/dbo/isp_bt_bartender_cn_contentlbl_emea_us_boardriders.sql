SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/******************************************************************************/                   
/* Copyright: IDS                                                             */                   
/* Purpose: isp_BT_Bartender_CN_CONTENTLBL_EMEA_US_BoardRiders                */                   
/*                                                                            */                   
/* Modifications log:                                                         */                   
/*                                                                            */                   
/* Date       Rev  Author     Purposes                                        */  
/*17-JUN-2019 1.0  WLCHOOI	  Created (WMS-9328)                               */ 
/*08-DEC-2020 1.1  PakYuen   Updated to 08, previously is 09,caused duplicate */  
/******************************************************************************/                  
                    
CREATE PROC [dbo].[isp_BT_Bartender_CN_CONTENTLBL_EMEA_US_BoardRiders]                        
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
 --  SET ANSI_WARNINGS OFF                    --CS01             
                                
   DECLARE                    
      @c_ReceiptKey      NVARCHAR(10),                      
      @c_sku             NVARCHAR(80),                           
      @n_intFlag         INT,       
      @n_CntRec          INT,      
      @c_SQL             NVARCHAR(4000),          
      @c_SQLSORT         NVARCHAR(4000),          
      @c_SQLJOIN         NVARCHAR(4000),  
      @c_col58           NVARCHAR(10),
      @c_labelline		 NVARCHAR(10),
      @n_CartonNo        INT        
      
   DECLARE @d_Trace_StartTime  DATETIME,     
           @d_Trace_EndTime    DATETIME,    
           @c_Trace_ModuleName NVARCHAR(20),     
           @d_Trace_Step1      DATETIME,     
           @c_Trace_Step1      NVARCHAR(20),    
           @c_UserName         NVARCHAR(20),      
           @c_Made01           NVARCHAR(50),
           @c_Made02           NVARCHAR(50), 
           @c_Made03           NVARCHAR(50),           
           @c_Made04           NVARCHAR(50),   
           @c_Made05           NVARCHAR(50),           
           @c_Made06           NVARCHAR(50),  
           @c_Made07           NVARCHAR(50),           
           @c_Made08           NVARCHAR(50),
           @c_Made09           NVARCHAR(50),
           @c_Made10           NVARCHAR(50),
           @c_Made11           NVARCHAR(50),
           @c_Made12           NVARCHAR(50),
           @c_Made13           NVARCHAR(50),
           @c_Made14           NVARCHAR(50),
           @c_Made15           NVARCHAR(50),
           @c_SKU01            NVARCHAR(80),           
           @c_SKU02            NVARCHAR(80),    
           @c_SKU03            NVARCHAR(80),           
           @c_SKU04            NVARCHAR(80),   
           @c_SKU05            NVARCHAR(80),           
           @c_SKU06            NVARCHAR(80),  
           @c_SKU07            NVARCHAR(80),           
           @c_SKU08            NVARCHAR(80), 
           @c_SKU09            NVARCHAR(80),
           @c_SKU10            NVARCHAR(80),
           @c_SKU11            NVARCHAR(80),
           @c_SKU12            NVARCHAR(80),
           @c_SKU13            NVARCHAR(80),
           @c_SKU14            NVARCHAR(80),
           @c_SKU15            NVARCHAR(80),                  
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
           @c_SKUQty11         NVARCHAR(10), 
           @c_SKUQty12         NVARCHAR(10), 
           @c_SKUQty13         NVARCHAR(10), 
           @c_SKUQty14         NVARCHAR(10),       
           @c_SKUQty15         NVARCHAR(10),           
           @n_TTLpage          INT,          
           @n_CurrentPage      INT,  
           @n_MaxLine          INT  ,  
           @c_labelno          NVARCHAR(20) ,  
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
           @c_Made             NVARCHAR(80),
           @n_SumPack          INT,
           @n_SumPick          INT,
           @n_MaxCtnNo         INT   

    SELECT @n_MaxCarton = MAX(PD.CartonNo)
    FROM PACKDETAIL PD (NOLOCK)
    WHERE PD.PICKSLIPNO = @c_Sparm01
    
    SET @d_Trace_StartTime = GETDATE()    
    SET @c_Trace_ModuleName = ''    
          
    -- SET RowNo = 0               
    SET @c_SQL = ''       
    SET @n_CurrentPage = 1  
    SET @n_TTLpage =1       
    SET @n_MaxLine = 15     
    SET @n_CntRec = 1    
    SET @n_intFlag = 1   
    SET @n_loopno = 1        
    SET @c_LastRec = 'Y'  
                
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
      [cartonno]    [NVARCHAR] (5)  NULL,  
      [labelno]     [NVARCHAR] (20) NULL,
      [Made]        [NVARCHAR] (20) NULL,
      [LabelLine]	  [NVARCHAR] (10) NULL,    
      [SKU]         [NVARCHAR] (80) NULL,             
      [PQty]        INT)
      
         
       SET @c_SQLJOIN = +' SELECT DISTINCT ISNULL(F.DESCR,''''), ISNULL(F.Address1,''''), ISNULL(F.Address2,''''), ISNULL(F.City,''''), ORD.Consigneekey, '   + CHAR(13) --5
                        +' ORD.C_Company, SUBSTRING(LTRIM(RTRIM(ISNULL(ORD.C_Address1,''''))) + '' '' + LTRIM(RTRIM(ISNULL(ORD.C_Address2,''''))),1,80), '+ CHAR(13) --7
                        +' SUBSTRING(LTRIM(RTRIM(ISNULL(ORD.C_Zip,''''))) + '' '' + LTRIM(RTRIM(ISNULL(ORD.C_City,''''))),1,80), '+ CHAR(13) --8
                        +' SUBSTRING(LTRIM(RTRIM(ISNULL(ORD.C_Country,''''))),1,80) , ORD.ExternOrderkey, '+ CHAR(13)      --10        
                        +' ORD.BuyerPO, '''', '''', '''', '''', '''', '''', '''', '''', '''', '+ CHAR(13)  --20
                        +' '''','''','''','''','''','''','''','''','''','''', ' + CHAR(13) --30 
                        +' '''','''','''','''','''','''','''','''','''','''', ' + CHAR(13) --40 
                        +' '''','''','''','''','''','''','''','''','''','''', ' + CHAR(13) --50 
                        +' '''','''','''','''','''','''',CAST(PIF.[WEIGHT] AS DECIMAL(10,2)),'''', ' + CHAR(13) --58
                        +' PD.CartonNo, PD.LABELNO ' + CHAR(13) --60               
                        +' FROM PACKDETAIL PD  WITH (NOLOCK) 		'	+ CHAR(13)									
                        +' JOIN PACKHEADER PH WITH (NOLOCK)  ON (PD.PickSlipNo = PH.PickSlipNo)	'+ CHAR(13)											
                        +' JOIN ORDERS ORD WITH (NOLOCK)  ON (ORD.Orderkey = PH.Orderkey)		'+ CHAR(13)			
                        +' JOIN ORDERDETAIL OD WITH (NOLOCK) ON ORD.Orderkey = OD.Orderkey '+ CHAR(13)		
                        +' JOIN FACILITY F WITH (NOLOCK) ON F.FACILITY = ORD.FACILITY ' + CHAR(13)		
                        +' JOIN SKU WITH (NOLOCK) ON SKU.SKU = PD.SKU AND SKU.STORERKEY = PH.STORERKEY ' + CHAR(13)	
                        +' JOIN PACKINFO PIF (NOLOCK) ON PIF.PICKSLIPNO = PH.PICKSLIPNO AND PIF.CARTONNO = PD.CARTONNO ' + CHAR(13)							
                        +' WHERE PD.PICKSLIPNO = @c_Sparm01   		'+ CHAR(13)										
                        +' AND PD.CartonNo = @c_Sparm02'+ CHAR(13)
                        --+' GROUP BY ISNULL(F.DESCR,''''), ISNULL(F.Address1,''''), ISNULL(F.Address2,''''), ISNULL(F.City,''''), ORD.Consigneekey, '   + CHAR(13) 
                        --+' ORD.C_Company, SUBSTRING(LTRIM(RTRIM(ISNULL(ORD.C_Address1,''''))) + '' '' + LTRIM(RTRIM(ISNULL(ORD.C_Address2,''''))),1,80), '+ CHAR(13)
                        --+' SUBSTRING(LTRIM(RTRIM(ISNULL(ORD.C_Zip,''''))) + '' '' + LTRIM(RTRIM(ISNULL(ORD.C_City,''''))),1,80), '+ CHAR(13) 
                        --+' SUBSTRING(LTRIM(RTRIM(ISNULL(ORD.C_Country,''''))),1,80), ' + CHAR(13)
                        --+' ORD.ExternOrderkey, ORD.BuyerPO, PD.CartonNo, PD.LABELNO ' 

       
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
   SELECT DISTINCT col60,col59       
   FROM #Result 
   ORDER BY col59                     
            
   OPEN CUR_RowNoLoop                    
               
   FETCH NEXT FROM CUR_RowNoLoop INTO @c_labelno,@c_cartonno      
                 
   WHILE @@FETCH_STATUS <> -1               
   BEGIN                   
      IF @b_debug='1'                
      BEGIN                
         PRINT @c_labelno                   
      END   

      INSERT INTO #TEMPSKU (labelno, Cartonno, Made, SKU, PQty, LabelLine)          
      SELECT DISTINCT PD.LabelNo, PD.CartonNo
                    , LOTT.Lottable08
                    , LTRIM(RTRIM(ISNULL(Sku.RetailSKU,''))) + ';' +  LTRIM(RTRIM(ISNULL(Sku.Style,'')))  + ';' +  
                    + LTRIM(RTRIM(ISNULL(Sku.Size,''))) + ';' +  LTRIM(RTRIM(ISNULL(Sku.Color,''))) + ';'
                    , PD.Qty, REPLACE(LTRIM(REPLACE(PD.LabelLine, '0', ' ')), ' ', '0') 
      FROM PACKDETAIL PD (NOLOCK) 
      JOIN PACKHEADER PH (NOLOCK) ON PH.PICKSLIPNO = PD.PICKSLIPNO
      JOIN SKU (NOLOCK) ON PD.SKU = SKU.SKU AND PH.STORERKEY = SKU.STORERKEY
      JOIN ORDERS ORD (NOLOCK) ON ORD.ORDERKEY = PH.ORDERKEY
      JOIN ORDERDETAIL OD (NOLOCK) ON ORD.ORDERKEY = OD.ORDERKEY
      JOIN PICKDETAIL PID (NOLOCK) ON PID.ORDERKEY = ORD.ORDERKEY AND PID.ORDERLINENUMBER = OD.ORDERLINENUMBER
                                  AND PID.SKU = OD.SKU
      JOIN LOTATTRIBUTE LOTT (NOLOCK) ON LOTT.LOT = PID.LOT
      WHERE PH.PICKSLIPNO = @c_Sparm01
      AND PD.LABELNO = @c_labelno
      GROUP BY PD.LabelNo, PD.CartonNo, LOTT.Lottable08, PD.SKU, PD.Qty, PD.LabelLine,Sku.RetailSKU,SKU.Style,SKU.Size,SKU.Color
      ORDER BY PD.CartonNo, REPLACE(LTRIM(REPLACE(PD.LabelLine, '0', ' ')), ' ', '0')
      
      SET @c_Made01 = ''
      SET @c_Made02 = ''
      SET @c_Made03 = ''
      SET @c_Made04 = ''
      SET @c_Made05 = ''
      SET @c_Made06 = ''
      SET @c_Made07 = ''
      SET @c_Made08 = ''
      SET @c_Made09 = ''
      SET @c_Made10 = '' 
      SET @c_Made11 = '' 
      SET @c_Made12 = '' 
      SET @c_Made13 = '' 
      SET @c_Made14 = '' 
      SET @c_Made15 = '' 
      
      SET @c_SKU01 = ''  
      SET @c_SKU02 = ''  
      SET @c_SKU03 = ''  
      SET @c_SKU04 = ''  
      SET @c_SKU05 = ''  
      SET @c_SKU06 = ''  
      SET @c_SKU07 = ''  
      SET @c_SKU08 = ''  
      SET @c_SKU09 = ''
      SET @c_SKU10 = ''
      SET @c_SKU11 = ''
      SET @c_SKU12 = ''
      SET @c_SKU13 = ''
      SET @c_SKU14 = ''
      SET @c_SKU15 = ''
      
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
      SET @c_SKUQty11 = ''
      SET @c_SKUQty12 = ''
      SET @c_SKUQty13 = ''
      SET @c_SKUQty14 = ''
      SET @c_SKUQty15 = ''
  
  --SELECT * FROM #TEMPSKU  
           
     SELECT @n_CntRec = COUNT (1)  
     FROM #TEMPSKU   
     WHERE LabelNo = @c_labelno  
     AND CartonNo = @c_cartonno    

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
          SELECT TOP 1 Col01,Col02,Col03,Col04,Col05,Col06,Col07,Col08,Col09,Col10,                   
                       Col11,'','','','','','','','','',                
                       '','','','','','','','','','',                
                       '','','','','','','','','','',                   
                       '','','','','','','','','','',                 
                       '','','','','','','','',Col59,Col60  
          FROM  #Result
          
          SET @c_Made01 = ''
          SET @c_Made02 = ''
          SET @c_Made03 = ''
          SET @c_Made04 = ''
          SET @c_Made05 = ''
          SET @c_Made06 = ''
          SET @c_Made07 = ''
          SET @c_Made08 = ''  
          SET @c_Made09 = ''
          SET @c_Made10 = '' 
          SET @c_Made11 = '' 
          SET @c_Made12 = '' 
          SET @c_Made13 = '' 
          SET @c_Made14 = '' 
          SET @c_Made15 = ''
          
          SET @c_SKU01 = ''  
          SET @c_SKU02 = ''  
          SET @c_SKU03 = ''  
          SET @c_SKU04 = ''  
          SET @c_SKU05 = ''  
          SET @c_SKU06 = ''  
          SET @c_SKU07 = ''  
          SET @c_SKU08 = ''  
          SET @c_SKU09 = ''
          SET @c_SKU10 = ''
          SET @c_SKU11 = ''
          SET @c_SKU12 = ''
          SET @c_SKU13 = ''
          SET @c_SKU14 = ''
          SET @c_SKU15 = ''
            
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
          SET @c_SKUQty11 = '' 
          SET @c_SKUQty12 = '' 
          SET @c_SKUQty13 = '' 
          SET @c_SKUQty14 = '' 
          SET @c_SKUQty15 = ''
          
       END      
                
      SELECT @c_Made   = Made, 
             @c_sku    = SKU,  
             @n_skuqty = SUM(PQty)  
      FROM #TEMPSKU   
      WHERE ID = @n_intFlag  
      GROUP BY Made, SKU

      IF (@n_intFlag%@n_MaxLine) = 1 --AND @n_recgrp = @n_CurrentPage  
      BEGIN   
         SET @c_Made01 = @c_Made          
         SET @c_sku01 = @c_sku  
         SET @c_SKUQty01 = CONVERT(NVARCHAR(10),@n_skuqty)        
      END

      ELSE IF (@n_intFlag%@n_MaxLine) = 2  --AND @n_recgrp = @n_CurrentPage  
      BEGIN      
         SET @c_Made02 = @c_Made        
         SET @c_sku02 = @c_sku  
         SET @c_SKUQty02 = CONVERT(NVARCHAR(10),@n_skuqty)           
      END   

      ELSE IF (@n_intFlag%@n_MaxLine) = 3  --AND @n_recgrp = @n_CurrentPage  
      BEGIN      
         SET @c_Made03 = @c_Made        
         SET @c_sku03 = @c_sku  
         SET @c_SKUQty03 = CONVERT(NVARCHAR(10),@n_skuqty)           
      END 

      ELSE IF (@n_intFlag%@n_MaxLine) = 4  --AND @n_recgrp = @n_CurrentPage  
      BEGIN      
         SET @c_Made04 = @c_Made        
         SET @c_sku04 = @c_sku  
         SET @c_SKUQty04 = CONVERT(NVARCHAR(10),@n_skuqty)           
      END 

      ELSE IF (@n_intFlag%@n_MaxLine) = 5  --AND @n_recgrp = @n_CurrentPage  
      BEGIN      
         SET @c_Made05 = @c_Made        
         SET @c_sku05 = @c_sku  
         SET @c_SKUQty05 = CONVERT(NVARCHAR(10),@n_skuqty)           
      END 

      ELSE IF (@n_intFlag%@n_MaxLine) = 6  --AND @n_recgrp = @n_CurrentPage  
      BEGIN      
         SET @c_Made06 = @c_Made        
         SET @c_sku06 = @c_sku  
         SET @c_SKUQty06 = CONVERT(NVARCHAR(10),@n_skuqty)           
      END 

      ELSE IF (@n_intFlag%@n_MaxLine) = 7  --AND @n_recgrp = @n_CurrentPage  
      BEGIN      
         SET @c_Made07 = @c_Made        
         SET @c_sku07 = @c_sku  
         SET @c_SKUQty07 = CONVERT(NVARCHAR(10),@n_skuqty)           
      END 

      ELSE IF (@n_intFlag%@n_MaxLine) = 8  --AND @n_recgrp = @n_CurrentPage  
      BEGIN      
         SET @c_Made08 = @c_Made        
         SET @c_sku08 = @c_sku  
         SET @c_SKUQty08 = CONVERT(NVARCHAR(10),@n_skuqty)           
      END 

      ELSE IF (@n_intFlag%@n_MaxLine) = 9  --AND @n_recgrp = @n_CurrentPage  
      BEGIN      
         SET @c_Made09 = @c_Made        
         SET @c_sku09 = @c_sku  
         SET @c_SKUQty09 = CONVERT(NVARCHAR(10),@n_skuqty)           
      END 

      ELSE IF (@n_intFlag%@n_MaxLine) = 10  --AND @n_recgrp = @n_CurrentPage  
      BEGIN      
         SET @c_Made10 = @c_Made        
         SET @c_sku10 = @c_sku  
         SET @c_SKUQty10 = CONVERT(NVARCHAR(10),@n_skuqty)           
      END 

      ELSE IF (@n_intFlag%@n_MaxLine) = 11  --AND @n_recgrp = @n_CurrentPage  
      BEGIN      
         SET @c_Made11 = @c_Made        
         SET @c_sku11 = @c_sku  
         SET @c_SKUQty11 = CONVERT(NVARCHAR(10),@n_skuqty)           
      END 

      ELSE IF (@n_intFlag%@n_MaxLine) = 12  --AND @n_recgrp = @n_CurrentPage  
      BEGIN      
         SET @c_Made12 = @c_Made        
         SET @c_sku12 = @c_sku  
         SET @c_SKUQty12 = CONVERT(NVARCHAR(10),@n_skuqty)           
      END 

      ELSE IF (@n_intFlag%@n_MaxLine) = 13  --AND @n_recgrp = @n_CurrentPage  
      BEGIN      
         SET @c_Made13 = @c_Made        
         SET @c_sku13 = @c_sku  
         SET @c_SKUQty13 = CONVERT(NVARCHAR(10),@n_skuqty)           
      END 

      ELSE IF (@n_intFlag%@n_MaxLine) = 14 --AND @n_recgrp = @n_CurrentPage  
      BEGIN      
         SET @c_Made14 = @c_Made        
         SET @c_sku14 = @c_sku  
         SET @c_SKUQty14 = CONVERT(NVARCHAR(10),@n_skuqty)           
      END 

      ELSE IF (@n_intFlag%@n_MaxLine) = 0  --AND @n_recgrp = @n_CurrentPage  
      BEGIN      
         SET @c_Made15 = @c_Made        
         SET @c_sku15 = @c_sku  
         SET @c_SKUQty15 = CONVERT(NVARCHAR(10),@n_skuqty)           
      END 

      --ELSE IF (@n_intFlag%@n_MaxLine) = 0  --AND @n_recgrp = @n_CurrentPage  
      --BEGIN      
      --   SET @c_Made02 = @c_Made        
      --   SET @c_sku02 = @c_sku  
      --   SET @c_SKUQty02 = CONVERT(NVARCHAR(10),@n_skuqty)           
      --END
     
      
  UPDATE #Result                    
  SET Col12 = @c_Made01, Col13 = @c_sku01, Col14 = @c_SKUQty01,
      Col15 = @c_Made02, Col16 = @c_sku02, Col17 = @c_SKUQty02, 
      Col18 = @c_Made03, Col19 = @c_sku03, Col20 = @c_SKUQty03,  
      Col21 = @c_Made04, Col22 = @c_sku04, Col23 = @c_SKUQty04, 
      Col24 = @c_Made05, Col25 = @c_sku05, Col26 = @c_SKUQty05, 
      Col27 = @c_Made06, Col28 = @c_sku06, Col29 = @c_SKUQty06, 
      Col30 = @c_Made07, Col31 = @c_sku07, Col32 = @c_SKUQty07,  
      Col33 = @c_Made08, Col34 = @c_sku08, Col35 = @c_SKUQty08,  --  py01  
      Col36 = @c_Made09, Col37 = @c_sku09, Col38 = @c_SKUQty09,
      Col39 = @c_Made10, Col40 = @c_sku10, Col41 = @c_SKUQty10,
      Col42 = @c_Made11, Col43 = @c_sku11, Col44 = @c_SKUQty11,
      Col45 = @c_Made12, Col46 = @c_sku12, Col47 = @c_SKUQty12,
      Col48 = @c_Made13, Col49 = @c_sku13, Col50 = @c_SKUQty13,
      Col51 = @c_Made14, Col52 = @c_sku14, Col53 = @c_SKUQty14,
      Col54 = @c_Made15, Col55 = @c_sku15, Col56 = @c_SKUQty15
    WHERE ID = @n_CurrentPage   
             
        SET @n_intFlag = @n_intFlag + 1    
  
        IF @n_intFlag > @n_CntRec  
        BEGIN  
          BREAK;  
        END        
      END  
      FETCH NEXT FROM CUR_RowNoLoop INTO @c_labelno,@c_cartonno          
          
   END -- While                     
   CLOSE CUR_RowNoLoop                    
   DEALLOCATE CUR_RowNoLoop
   
   UPDATE #RESULT
   SET COL58 = (SELECT SUM(Qty) FROM PACKDETAIL (NOLOCK) WHERE PICKSLIPNO = @c_Sparm01)
   WHERE COL59 = @c_Sparm02

   --DECLARE CUR_CTNNO CURSOR FAST_FORWARD READ_ONLY FOR
   --SELECT DISTINCT COL59 FROM #Result

   --OPEN CUR_CTNNO

   --FETCH NEXT FROM CUR_CTNNO INTO @n_CartonNo

   --WHILE (@@FETCH_STATUS) <> -1
   --BEGIN
   --   IF(@n_MaxCarton = @n_CartonNo)
   --   BEGIN
   --      UPDATE #RESULT
   --      SET Col59 = CAST(@n_CartonNo AS NVARCHAR(5)) + '/' + CAST(@n_MaxCarton AS NVARCHAR(5)) 
   --      WHERE Col59 = @n_CartonNo
   --   END
   --   FETCH NEXT FROM CUR_CTNNO INTO @n_CartonNo
   --END
   --CLOSE CUR_CTNNO
   --DEALLOCATE CUR_CTNNO

    SELECT @n_SumPick = SUM(Qty)
    FROM PICKDETAIL (NOLOCK)
    WHERE Orderkey IN (SELECT TOP 1 ORDERKEY FROM PACKHEADER (NOLOCK) WHERE PICKSLIPNO = @c_Sparm01)
     
    SELECT @n_SumPack  = SUM(Qty),
           @n_MaxCtnNo = MAX(CartonNo)
    FROM PACKDETAIL (NOLOCK)
    WHERE Pickslipno = @c_Sparm01

    IF( (@n_SumPick = @n_SumPack) AND (@n_MaxCtnNo = @c_Sparm02) )
    BEGIN
       UPDATE #Result
       SET COL59 = CAST(@c_Sparm02 AS NVARCHAR(5)) + '/' + CAST(@n_MaxCarton AS NVARCHAR(5)) 
       WHERE Col59 = @c_Sparm02
    END
    
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
      @c_TraceName = 'isp_BT_Bartender_CN_CONTENTLBL_EMEA_US_BoardRiders',    
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