SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************************/             
/* Copyright: IDS                                                            */             
/* Purpose: isp_BT_Bartender_UCCLBL_JDSPORT                                  */             
/*                                                                           */             
/* Modifications log:                                                        */             
/*                                                                           */             
/* Date    Rev Author   Purposes                                             */       
/* 28-JAN-2019      1.0 CSCHONG   WMS-7741                                   */      
/* 26-Jun-2019      1.1 CSCHONG   WMS-7741 revised field mapping (CS01)      */    
/* 31-Dec-2019      1.2 JayC   Correct Total PageNo  INC0983445 (JC01)       */    
/*****************************************************************************/            
            
CREATE PROC [dbo].[isp_BT_Bartender_UCCLBL_JDSPORT]              
( @c_Sparm01     NVARCHAR(250),            
 @c_Sparm02     NVARCHAR(250),            
 @c_Sparm03     NVARCHAR(250),            
 @c_Sparm04     NVARCHAR(250),            
 @c_Sparm05     NVARCHAR(250),            
 @c_Sparm06     NVARCHAR(250),            
 @c_Sparm07     NVARCHAR(250),            
 @c_Sparm08     NVARCHAR(250),            
 @c_Sparm09     NVARCHAR(250),            
 @c_Sparm10     NVARCHAR(250),          
 @b_debug      INT = 0               
)               
AS              
BEGIN              
 SET NOCOUNT ON             
 SET ANSI_NULLS OFF            
 SET QUOTED_IDENTIFIER OFF            
 SET CONCAT_NULL_YIELDS_NULL OFF                    
                
 DECLARE             
  @c_Pickslipno   NVARCHAR(20),              
  @c_sku     NVARCHAR(20),               
  @n_intFlag    INT,         
  @n_CntRec    INT,        
  @c_SQL     NVARCHAR(4000),         
  @c_SQLSORT    NVARCHAR(4000),         
  @c_SQLJOIN    NVARCHAR(4000),      
  @c_ExtOrdKey   NVARCHAR(20),      
  @c_SSize    NVARCHAR(20),      
  @c_SColor    NVARCHAR(20),      
  @c_ExecStatements  NVARCHAR(4000),         
  @c_ExecArguments  NVARCHAR(4000)           
        
  DECLARE     @d_Trace_StartTime  DATETIME,        
     @d_Trace_EndTime      DATETIME,       
     @c_Trace_ModuleName    NVARCHAR(20),         
     @d_Trace_Step1   DATETIME,        
     @c_Trace_Step1   NVARCHAR(20),        
     @c_UserName    NVARCHAR(20),      
     @c_SKU01     NVARCHAR(20),           
     @c_SKU02     NVARCHAR(20),          
     @c_SKU03     NVARCHAR(20),          
     @c_SKU04     NVARCHAR(20),          
     @c_SKU05     NVARCHAR(20),        
     @c_SKU06     NVARCHAR(20),         
     @c_SKU07     NVARCHAR(20),         
     @c_SKU08     NVARCHAR(20),       
     @c_SKU09     NVARCHAR(20),      
     @c_SKU10     NVARCHAR(20),       
     @c_ExtORDKEY01   NVARCHAR(20),           
     @c_ExtORDKEY02   NVARCHAR(20),          
     @c_ExtORDKEY03   NVARCHAR(20),          
     @c_ExtORDKEY04   NVARCHAR(20),          
     @c_ExtORDKEY05   NVARCHAR(20),        
     @c_ExtORDKEY06   NVARCHAR(20),       
     @c_ExtORDKEY07   NVARCHAR(20),       
     @c_ExtORDKEY08   NVARCHAR(20),       
     @c_ExtORDKEY09   NVARCHAR(20),       
     @c_ExtORDKEY10   NVARCHAR(20),             
     @c_SKUQty01    NVARCHAR(10),          
     @c_SKUQty02    NVARCHAR(10),           
     @c_SKUQty03    NVARCHAR(10),           
     @c_SKUQty04    NVARCHAR(10),           
     @c_SKUQty05    NVARCHAR(10) ,      
     @c_SKUQty06    NVARCHAR(10) ,      
     @c_SKUQty07    NVARCHAR(10) ,      
     @c_SKUQty08    NVARCHAR(10) ,      
     @c_SKUQty09    NVARCHAR(10) ,      
     @c_SKUQty10         NVARCHAR(10) ,      
     @n_TTLpage    INT,          
     @n_CurrentPage   INT,      
     @n_MaxLine    INT ,      
     @n_MaxGrpLine    INT ,      
     @c_ToId     NVARCHAR(80) ,      
     @c_labelno    NVARCHAR(20) ,      
     @n_skuqty     INT,       
     @n_sumskuqty    INT       
        
 SET @d_Trace_StartTime = GETDATE()       
 SET @c_Trace_ModuleName = ''       
          
  -- SET RowNo = 0           
  SET @c_SQL = ''        
  SET @n_CurrentPage = 1      
  SET @n_TTLpage =1         
  SET @n_MaxLine = 10       
  SET @n_MaxGrpLine = 11       
  SET @n_CntRec = 1        
  SET @n_intFlag = 1         
            
  CREATE TABLE [#Result] (            
  [ID]   [INT] IDENTITY(1,1) NOT NULL,                 
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
  [ID]    [INT] IDENTITY(1,1) NOT NULL,                   
  [Pickslipno]  [NVARCHAR] (20)  NULL,        
  [labelno]   [NVARCHAR] (30)  NULL,         
  [SKU]    [NVARCHAR] (20)  NULL,        
  [ExtOrdKey]   [NVARCHAR] (20)  NULL,      
  [CartonNo]   INT  NULL,        
  [Qty]    INT ,       
  [Recgrp]      INT   NULL,      
  [Retrieve]   [NVARCHAR] (1) default 'N')           
           
  SET @c_SQLJOIN = +' SELECT DISTINCT PD.labelNo,PD.CartonNo,O.C_Company,ISNULL(O.C_Address1,''''),ISNULL(O.C_Address2,''''),'+ CHAR(13)    --5          
     + ' ISNULL(O.C_Address3,''''),ISNULL(O.C_Address4,''''),ISNULL(O.C_Country,''''),ISNULL(O.consigneekey,''''),''1'','  --10 --CS01a      
     + ' '''','''','''','''','''','  --15       
     + ' '''','''','''','''','''','  --20          
     + CHAR(13) +         
     + ' '''','''','''','''','''','''','''','''','''','''','  --30        
     + ' '''','''','''','''','''','''','''','''','''','''','   --40         
     + ' '''','''','''','''','''','''','''','''','''','''', '  --50         
     + ' '''','''','''','''','''','''','''','''',PH.Pickslipno,''O'' ' --60           
     + CHAR(13) +           
        + ' FROM PACKHEADER PH WITH (NOLOCK) '          
       + ' JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo '        
      + ' JOIN ORDERS O WITH (NOLOCK) ON O.Orderkey = pH.orderkey '       
     + ' WHERE PH.Pickslipno  = @c_Sparm01 AND'         
     + ' PD.labelNo = @c_Sparm02 '        
          
          
IF @b_debug=1         
BEGIN          
 PRINT @c_SQLJOIN           
END            
            
  SET @c_SQL='INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05,Col06,Col07,Col08,Col09'  + CHAR(13) +           
     +',Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22' + CHAR(13) +           
     +',Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34' + CHAR(13) +           
     +',Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44' + CHAR(13) +           
     +',Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54'+ CHAR(13) +          
     +',Col55,Col56,Col57,Col58,Col59,Col60) '           
        
SET @c_SQL = @c_SQL + @c_SQLJOIN          
          
  --EXEC sp_executesql @c_SQL         
        
  SET @c_ExecArguments = N'  @c_Sparm01  NVARCHAR(80)'        
       + ', @c_Sparm02  NVARCHAR(80) '        
       + ', @c_Sparm03  NVARCHAR(80) '       
      
               
               
 EXEC sp_ExecuteSql   @c_SQL         
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
  SELECT DISTINCT col01,col59         
 FROM    #Result           
 WHERE Col60 = 'O'      
 AND     Col01 = @c_Sparm02      
 AND     Col59 =@c_Sparm01           
          
 OPEN CUR_RowNoLoop            
           
 FETCH NEXT FROM CUR_RowNoLoop INTO @c_labelno,@c_pickslipno        
           
 WHILE @@FETCH_STATUS <> -1           
 BEGIN             
  IF @b_debug='1'            
  BEGIN            
   PRINT @c_labelno             
  END       
         
        
  INSERT INTO [#TEMPSKU] (Pickslipno, labelno, CartonNo, ExtOrdKey,SKU,Recgrp,Qty,      
      Retrieve)      
       SELECT PH.PickSlipNo as Pickslipno,PD.LabelNo as labelno,PD.CartonNo as cartonno,O.ExternOrderKey as externordkey,PD.SKU as sku      
     , (Row_Number() OVER (PARTITION BY PH.PickSlipNo,PD.Cartonno ORDER BY PD.Cartonno,PD.sku Asc)/@n_MaxGrpLine) +1 as recgrp,      
  (pd.qty),'N'      
      FROM PACKHEADER PH WITH (NOLOCK)       
      JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo       
      JOIN ORDERS O WITH (NOLOCK) ON O.Orderkey = pH.orderkey       
  WHERE PD.LabelNo = @c_labelno      
  AND PH.PickSlipNo = @c_pickslipno       
        
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
  SET @c_ExtORDKEY01 =''      
  SET @c_ExtORDKEY02 =''      
  SET @c_ExtORDKEY03 =''      
  SET @c_ExtORDKEY04 =''      
  SET @c_ExtORDKEY05 = ''      
  SET @c_ExtORDKEY06 =''      
  SET @c_ExtORDKEY07 =''      
  SET @c_ExtORDKEY08 = ''      
  SET @c_ExtORDKEY09 = ''      
  SET @c_ExtORDKEY10 = ''      
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
  SET @n_sumskuqty = 1      
       
         
  SELECT @n_CntRec = COUNT (1)      
  FROM #TEMPSKU       
  WHERE Pickslipno = @c_pickslipno      
  AND LabelNo = @c_labelno       
  AND Retrieve = 'N'       
        
  SET @n_TTLpage = 1      
      
  SELECT PH.PickSlipNo as Pickslipno,PD.LabelNo as labelno,PD.CartonNo as cartonno,O.ExternOrderKey as externordkey,PD.SKU as sku      
     , ((Row_Number() OVER (PARTITION BY PH.PickSlipNo,PD.Cartonno ORDER BY PD.Cartonno,PD.sku Asc)-1)/10) +1 as recgrp  --(JC01)    
   INTO #TEMPFULLSKU      
      FROM PACKHEADER PH WITH (NOLOCK)       
      JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo       
      JOIN ORDERS O WITH (NOLOCK) ON O.Orderkey = pH.orderkey       
  WHERE PH.PickSlipNo = @c_pickslipno       
       
      
  SELECT  @n_TTLpage  = sum(TT.TL)      
  FROM (select labelno,max(recgrp) as TL      
     FROM #TEMPFULLSKU       
     where pickslipno=@c_pickslipno      
     AND LabelNo = @c_labelno                --CS01      
     GROUP BY labelno) AS TT      
        
  select @n_sumskuqty = sum(Qty)      
  FROM #TEMPSKU      
  WHERE Pickslipno = @c_pickslipno      
  AND LabelNo = @c_labelno       
  --and Recgrp = @n_CurrentPage      
  group by labelno       
      
   WHILE @n_intFlag <= @n_CntRec          
   BEGIN        
        
  SELECT   @c_sku       = SKU,      
     @c_ExtOrdKey = ExtOrdKey,      
     @n_skuqty    = SUM(Qty)      
  FROM #TEMPSKU       
  WHERE ID = @n_intFlag      
  GROUP BY SKU,ExtOrdKey      
        
  IF (@n_intFlag%@n_MaxLine) = 1       
   BEGIN          
    SET @c_sku01     = @c_sku      
    SET @c_ExtOrdKey01 = @c_ExtOrdKey      
    SET @c_SKUQty01 = CONVERT(NVARCHAR(10),@n_skuqty)          
   END         
         
   ELSE IF (@n_intFlag%@n_MaxLine) = 2      
   BEGIN          
    SET @c_sku02  = @c_sku      
    SET @c_ExtOrdKey02 = @c_ExtOrdKey      
    SET @c_SKUQty02 = CONVERT(NVARCHAR(10),@n_skuqty)          
   END         
          
   ELSE IF (@n_intFlag%@n_MaxLine) = 3      
   BEGIN          
    SET @c_sku03  = @c_sku      
    SET @c_ExtOrdKey03 = @c_ExtOrdKey      
    SET @c_SKUQty03 = CONVERT(NVARCHAR(10),@n_skuqty)         
   END         
          
   ELSE IF (@n_intFlag%@n_MaxLine) = 4      
   BEGIN          
    SET @c_sku04  = @c_sku      
    SET @c_ExtOrdKey04 = @c_ExtOrdKey      
    SET @c_SKUQty04 = CONVERT(NVARCHAR(10),@n_skuqty)         
   END        
         
   ELSE IF (@n_intFlag%@n_MaxLine) = 5      
   BEGIN          
    SET @c_sku05  = @c_sku      
    SET @c_ExtOrdKey05 = @c_ExtOrdKey      
    SET @c_SKUQty05 = CONVERT(NVARCHAR(10),@n_skuqty)         
   END        
         
   ELSE IF (@n_intFlag%@n_MaxLine) = 6      
   BEGIN          
    SET @c_sku06  = @c_sku      
    SET @c_ExtOrdKey06 = @c_ExtOrdKey      
    SET @c_SKUQty06 = CONVERT(NVARCHAR(10),@n_skuqty)         
   END         
         
   ELSE IF (@n_intFlag%@n_MaxLine) = 7      
   BEGIN          
    SET @c_sku07  = @c_sku      
    SET @c_ExtOrdKey07 = @c_ExtOrdKey      
    SET @c_SKUQty07 = CONVERT(NVARCHAR(10),@n_skuqty)         
   END      
         
   ELSE IF (@n_intFlag%@n_MaxLine) = 8      
   BEGIN          
    SET @c_sku08  = @c_sku      
    SET @c_ExtOrdKey08 = @c_ExtOrdKey      
    SET @c_SKUQty08 = CONVERT(NVARCHAR(10),@n_skuqty)         
   END       
         
   ELSE IF (@n_intFlag%@n_MaxLine) = 9      
   BEGIN          
    SET @c_sku09  = @c_sku      
    SET @c_ExtOrdKey09 = @c_ExtOrdKey      
    SET @c_SKUQty09 = CONVERT(NVARCHAR(10),@n_skuqty)         
   END       
        
   ELSE IF (@n_intFlag%@n_MaxLine) = 0      
   BEGIN          
    SET @c_sku10  = @c_sku      
    SET @c_ExtOrdKey10 = @c_ExtOrdKey      
    SET @c_SKUQty10 = CONVERT(NVARCHAR(10),@n_skuqty)         
  END       
         
   UPDATE #Result            
   SET  Col11 = @n_TTLpage,       
     Col12 = @c_ExtOrdKey01,      
     Col13 = @c_sku01,      
     Col14 = @c_SKUQty01,      
     Col15 = @c_ExtOrdKey02,       
     Col16 = @c_sku02,      
     Col17 = @c_SKUQty02,      
     Col18 = @c_ExtOrdKey03,       
     Col19 = @c_sku03,        
     Col20 = @c_SKUQty03,       
     Col21 = @c_ExtOrdKey04,       
     Col22 = @c_sku04,        
     Col23 = @c_SKUQty04,       
     Col24 = @c_ExtOrdKey05,      
     Col25 = @c_sku05,            
     Col26 = @c_SKUQty05,       
     Col27 = @c_ExtOrdKey06,         
     Col28 = @c_sku06,       
     Col29 = @c_SKUQty06,       
     Col30 = @c_ExtOrdKey07,         
     Col31 = @c_sku07,      
     Col32 = @c_SKUQty07,       
     Col33 = @c_ExtOrdKey08,         
     Col34 = @c_sku08,       
     Col35 = @c_SKUQty08,      
     Col36 = @c_ExtOrdKey09,         
     Col37 = @c_sku09,       
     Col38 = @c_SKUQty09,       
     Col39 = @c_ExtOrdKey10,         
     Col40 = @c_sku10,       
     Col41 = @c_SKUQty10,      
     Col42 = CONVERT(NVARCHAR(10),@n_sumskuqty)             
   WHERE ID = @n_CurrentPage        
         
         
 IF (@n_intFlag%@n_MaxLine) = 0 AND @n_intFlag <> @n_CntRec --AND (@n_CntRec - 1) <> 0      
  BEGIN      
  SET @n_CurrentPage = @n_CurrentPage + 1      
      
      
  select @n_sumskuqty = sum(Qty)      
  FROM #TEMPSKU      
  WHERE Pickslipno = @c_pickslipno      
  AND LabelNo = @c_labelno       
  --and Recgrp = @n_CurrentPage      
  group by labelno       
      
  INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09             
          ,Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22            
          ,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34             
          ,Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44            
          ,Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54            
          ,Col55,Col56,Col57,Col58,Col59,Col60)       
  SELECT TOP 1 Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09,CAST(@n_CurrentPage as nvarchar(5)),    --CS01            
       Col11,'','','','', '','','','','',            
       '','','','','', '','','','','',            
       '','','','','', '','','','','',             
       '',CAST(@n_sumskuqty as nvarchar(10)),'','','', '','','','','',             
       '','','','','', '','','',Col59,''      
   FROM  #Result       
   WHERE Col60='O'        
         
         
         
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
  SET @c_ExtORDKEY01 =''      
  SET @c_ExtORDKEY02 =''      
  SET @c_ExtORDKEY03 =''      
  SET @c_ExtORDKEY04 =''      
  SET @c_ExtORDKEY05 = ''      
  SET @c_ExtORDKEY06 =''      
  SET @c_ExtORDKEY07 =''      
  SET @c_ExtORDKEY08 = ''      
  SET @c_ExtORDKEY09 = ''      
  SET @c_ExtORDKEY10 = ''      
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
  --SET @n_sumskuqty = 1            
        
  END       
         
  SET @n_intFlag = @n_intFlag + 1         
           
  END        
        
 FETCH NEXT FROM CUR_RowNoLoop INTO @c_labelno,@c_pickslipno        
          
  END -- While             
  CLOSE CUR_RowNoLoop             
  DEALLOCATE CUR_RowNoLoop       
          
SELECT * FROM #Result (nolock)          
          
EXIT_SP:        
        
 SET @d_Trace_EndTime = GETDATE()        
 SET @c_UserName = SUSER_SNAME()       
         
 --EXEC isp_InsertTraceInfo       
 -- @c_TraceCode = 'BARTENDER',        
 -- @c_TraceName = 'isp_BT_Bartender_TW_IDLABEL02_01',        
 -- @c_starttime = @d_Trace_StartTime,       
 -- @c_endtime = @d_Trace_EndTime,        
 -- @c_step1 = @c_UserName,        
 -- @c_step2 = '',        
 -- @c_step3 = '',        
 -- @c_step4 = '',        
 -- @c_step5 = '',        
 -- @c_col1 = @c_Sparm01,       
 -- @c_col2 = @c_Sparm02,        
 -- @c_col3 = @c_Sparm03,        
 -- @c_col4 = @c_Sparm04,        
 -- @c_col5 = @c_Sparm05,        
 -- @b_Success = 1,        
 -- @n_Err = 0,        
 -- @c_ErrMsg = ''            
       
                   
END -- procedure

GO