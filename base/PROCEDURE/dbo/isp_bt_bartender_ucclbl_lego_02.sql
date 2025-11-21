SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************************/                 
/* Copyright: IDS                                                            */                 
/* Purpose: isp_BT_Bartender_UCCLBL_LEGO_02                                  */                 
/*                                                                           */                 
/* Modifications log:                                                        */                 
/*                                                                           */                 
/* Date         Rev    Author    Purposes                                    */             
/* 01-DEC-2022  1.0    MINGLE    DevOps Combine Script(Created- WMS-21184)   */  
/*****************************************************************************/                
              
CREATE PROC [dbo].[isp_BT_Bartender_UCCLBL_LEGO_02]                  
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
  @c_Pickslipno      NVARCHAR(20),                  
  @c_sku             NVARCHAR(20),                   
  @n_intFlag         INT,             
  @n_CntRec          INT,            
  @c_SQL             NVARCHAR(4000),             
  @c_SQLSORT         NVARCHAR(4000),             
  @c_SQLJOIN         NVARCHAR(4000),          
  @c_ExtOrdKey       NVARCHAR(20),          
  @c_SSize           NVARCHAR(20),          
  @c_SColor          NVARCHAR(20),          
  @c_ExecStatements  NVARCHAR(4000),             
  @c_ExecArguments   NVARCHAR(4000)               
            
  DECLARE      
  @d_Trace_StartTime    DATETIME,            
  @d_Trace_EndTime      DATETIME,           
  @c_Trace_ModuleName   NVARCHAR(20),             
  @d_Trace_Step1        DATETIME,            
  @c_Trace_Step1        NVARCHAR(20),            
  @c_UserName           NVARCHAR(20),          
  @c_SKU01              NVARCHAR(20),               
  @c_SKU02              NVARCHAR(20),              
  @c_SKU03              NVARCHAR(20),              
  @c_SKU04              NVARCHAR(20),              
  @c_SKU05              NVARCHAR(20),            
  @c_SKU06              NVARCHAR(20),             
  @c_SKU07              NVARCHAR(20),             
  @c_SKU08              NVARCHAR(20),           
                        
  @c_SKUQty01           NVARCHAR(10),              
  @c_SKUQty02           NVARCHAR(10),               
  @c_SKUQty03           NVARCHAR(10),               
  @c_SKUQty04           NVARCHAR(10),               
  @c_SKUQty05           NVARCHAR(10) ,          
  @c_SKUQty06           NVARCHAR(10) ,          
  @c_SKUQty07           NVARCHAR(10) ,          
  @c_SKUQty08           NVARCHAR(10) ,          
            
  @n_TTLpage            INT,              
  @n_CurrentPage        INT,          
  @n_MaxLine            INT ,          
  @n_MaxGrpLine         INT ,          
  @c_ToId               NVARCHAR(80) ,          
  @c_labelno            NVARCHAR(20) ,          
  @n_skuqty             INT,           
  @n_sumskuqty          INT,    
  @n_MaxCtn             INT,   
  @c_Col33              NVARCHAR(20),    
  @n_CtnNo              INT                                   
         
 SET @d_Trace_StartTime = GETDATE()           
 SET @c_Trace_ModuleName = ''           
              
  -- SET RowNo = 0               
  SET @c_SQL = ''            
  SET @n_CurrentPage = 1          
  SET @n_TTLpage =1             
  SET @n_MaxLine = 6           
  SET @n_MaxGrpLine = 11           
  SET @n_CntRec = 1            
  SET @n_intFlag = 1       
  SET @n_MaxCtn = 1          
  SET @c_Col33 = ''    
  SET @n_CtnNo = 1    
                
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
  [ID]          [INT] IDENTITY(1,1) NOT NULL,                       
  [Pickslipno]  [NVARCHAR] (20)  NULL,            
  [labelno]     [NVARCHAR] (30)  NULL,             
  [SKU]         [NVARCHAR] (20)  NULL,               
  [CartonNo]    INT  NULL,            
  [Qty]         INT ,           
  [Recgrp]      INT   NULL,          
  [Retrieve]    [NVARCHAR] (1) DEFAULT 'N')               
               
   
DECLARE @c_LooseInd CHAR(1),    
        @c_TotalCarton NVARCHAR(20),    
        @c_PackClosed CHAR(1),    
        @c_Orderkey NVARCHAR(20)    
    
SELECT @c_PackClosed = CASE STATUS WHEN '9' THEN 'Y' ELSE 'N' END, @c_Orderkey = OrderKey    
FROM PackHeader WITH (NOLOCK)   
WHERE PickSlipNo = @c_Sparm01    
    
IF @c_PackClosed = 'Y'    
BEGIN    
   SELECT @c_TotalCarton = CAST(MAX(CartonNo) AS NVARCHAR(20))    
   FROM PackDetail WITH (NOLOCK)   
   WHERE PickSlipNo = @c_Sparm01    
END    
    
IF @c_PackClosed = 'N'    
BEGIN    
   IF EXISTS (SELECT PD.Sku, LA.Lottable07, P.CaseCnt     
   FROM PICKDETAIL PD (NOLOCK)  
   JOIN LOTATTRIBUTE LA (NOLOCK) ON PD.Lot = LA.Lot    
   JOIN SKU S (NOLOCK) ON PD.Storerkey = S.StorerKey    
                        AND PD.Sku = S.Sku    
   JOIN PACK P (NOLOCK) ON S.PACKKey = P.PackKey    
   WHERE PD.OrderKey = @c_Orderkey--'0006774161'    
   GROUP BY PD.Sku, LA.Lottable07 , P.CaseCnt    
   HAVING SUM(PD.QTY) % CAST(P.CaseCnt AS INTEGER) > 0)    
   BEGIN    
      SET @c_LooseInd = 'Y'    
      SET @c_TotalCarton = 'XX'    
   END    
   ELSE    
   BEGIN    
      SET @c_LooseInd = 'N'    
    
      SELECT @c_TotalCarton = Cast(Sum(TotalCarton) AS NVarchar(20)) FROM    
      (SELECT TotalCarton = SUM(PD.QTY) / P.CaseCnt    
      FROM PICKDETAIL PD (NOLOCK)  
      JOIN LOTATTRIBUTE LA (NOLOCK) ON PD.Lot = LA.Lot    
      JOIN SKU S (NOLOCK) ON PD.Storerkey = S.StorerKey    
                        AND PD.Sku = S.Sku    
      JOIN PACK P (NOLOCK) ON S.PACKKey = P.PackKey    
      WHERE PD.OrderKey = @c_Orderkey--'0006774161'    
      GROUP BY PD.Sku, P.CaseCnt) X    
   END    
END    
      
    
    
  SET @c_SQLJOIN = +' SELECT O.ExternOrderkey,O.C_Company,ISNULL(O.C_Address1,''''),ISNULL(O.C_Address2,''''),ISNULL(O.C_Address3,''''),'+ CHAR(13)    --5              
     + ' ISNULL(O.C_Address4,''''),ISNULL(C.long,''''),ISNULL(O.c_zip,''''),O.B_Company,ISNULL(O.B_Address1,''''),'  --10           
     + ' ISNULL(O.B_Address2,''''),ISNULL(O.B_Address3,''''),ISNULL(O.B_Address4,''''),ISNULL(C1.long,''''),ISNULL(O.B_zip,''''),'  --15           
     + ' CASE WHEN ISNULL(STC.susr2,'''') = '''' OR ISNULL(STC.storerkey,'''') = '''' THEN ISNULL(O.Route,'''') + ''-'' + ''NA'' '    
     + ' ELSE  ISNULL(O.Route,'''') + ''-'' + ISNULL(STC.susr2,'''') END,'   --16    
     + ' '''','''','''','''','  --20              
     + CHAR(13) +             
     + ' '''','''','''','''','''','''','''','''',PD.CartonNo,PD.labelNo,'  --30            
     + ' CASE WHEN ISNULL(STC.susr3,'''') = '''' OR ISNULL(STC.storerkey,'''') = '''' THEN ''INVALIDVAS'' '    
     + ' ELSE ISNULL(STC.susr3,'''') END,'  --31    
     + ' ISNULL(O.B_VAT,''''),PD.CartonNo,O.Orderdate,FORMAT (O.deliverydate, ''dd/MM/yyyy'') as date,O.Effectivedate,O.Type,O.Consigneekey,'''','''','   --40             
     + ' '''','''','''','''','''','''','''','''','''','''', '  --50             
     + ' '''','''','''','''','''','''','''','''',PH.Pickslipno,''O'' ' --60               
     + CHAR(13) +               
     + ' FROM PACKHEADER PH WITH (NOLOCK) '              
     + ' JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo '            
     + ' JOIN ORDERS O WITH (NOLOCK) ON O.Orderkey = pH.orderkey '       
     + ' JOIN STORER ST WITH (NOLOCK) ON ST.Storerkey = O.Storerkey '       
     + ' JOIN SKU S WITH (NOLOCK) ON S.Storerkey = PD.Storerkey AND S.sku = PD.sku '    
     + ' LEFT JOIN Storer STC WITH (NOLOCK) ON STC.Storerkey = O.Consigneekey '     
     + ' LEFT JOIN Codelkup C WITH (NOLOCK) ON  C.listname = ''ISOCOUNTRY'' AND C.code = O.C_Country '   
     + ' LEFT JOIN Codelkup C1 WITH (NOLOCK) ON C1.listname = ''ISOCOUNTRY'' AND C1.code = O.B_Country '   
     + ' WHERE PH.Pickslipno  = @c_Sparm01 AND'             
     + ' PD.labelNo = @c_Sparm02 '  + CHAR(13)  
     + ' GROUP BY O.ExternOrderkey,O.C_Company,ISNULL(O.C_Address1,''''),ISNULL(O.C_Address2,''''),ISNULL(O.C_Address3,''''),'  +CHAR(13)   
     + ' ISNULL(O.C_Address4,''''),ISNULL(C.long,''''),ISNULL(O.c_zip,''''),O.B_Company,ISNULL(O.B_Address1,''''), '    +CHAR(13)   
     + ' ISNULL(O.B_Address2,''''),ISNULL(O.B_Address3,''''),ISNULL(O.B_Address4,''''),ISNULL(C1.long,''''),ISNULL(O.B_zip,''''), '    +CHAR(13)   
     + ' CASE WHEN ISNULL(STC.susr2,'''') = '''' OR ISNULL(STC.storerkey,'''') = '''' THEN ISNULL(O.Route,'''') + ''-'' + ''NA'' '     
     + ' ELSE  ISNULL(O.Route,'''') + ''-'' + ISNULL(STC.susr2,'''') END,'    +CHAR(13)   
     + ' PD.CartonNo,PD.labelNo, CASE WHEN ISNULL(STC.susr3,'''') = '''' OR ISNULL(STC.storerkey,'''') = '''' THEN ''INVALIDVAS'' '    +CHAR(13)   
     + ' ELSE ISNULL(STC.susr3,'''') END, ISNULL(O.B_VAT,''''),PD.CartonNo,O.Orderdate,O.Deliverydate,O.Effectivedate,O.Type,PH.Pickslipno,O.Consigneekey    '        
              
              
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
  SELECT * FROM #Result (NOLOCK)              
 END              
            
  SELECT @n_CtnNo = CAST(Col29 AS INT)     
  FROM #Result    
  WHERE Col30 = @c_Sparm02          
  AND     Col59 =@c_Sparm01      
    
/* SELECT @n_MaxCtn = MAX(Cartonno)    
 FROM PACKDETAIL (NOLOCK)    
 WHERE Pickslipno =  @c_Sparm01    
    
    
 IF @n_CtnNo <> @n_MaxCtn    
 BEGIN    
   UPDATE #Result    
   SET Col33 = 'XX'    
   WHERE Col30 = @c_Sparm02          
  AND     Col59 =@c_Sparm01    
 END    
*/    
   
   UPDATE #Result    
   SET Col33 = @c_TotalCarton    
   WHERE Col30 = @c_Sparm02          
  AND     Col59 =@c_Sparm01       
    
            
  DECLARE CUR_RowNoLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR            
  SELECT DISTINCT col30,col59             
 FROM    #Result               
 WHERE Col60 = 'O'          
 AND     Col30 = @c_Sparm02          
 AND     Col59 =@c_Sparm01               
              
 OPEN CUR_RowNoLoop                
               
 FETCH NEXT FROM CUR_RowNoLoop INTO @c_labelno,@c_pickslipno            
               
 WHILE @@FETCH_STATUS <> -1               
 BEGIN                 
  IF @b_debug='1'                
  BEGIN                
   PRINT @c_labelno                 
  END           
             
            
  INSERT INTO [#TEMPSKU] (Pickslipno, labelno, CartonNo, SKU,Recgrp,Qty,          
      Retrieve)          
       SELECT PH.PickSlipNo as Pickslipno,PD.LabelNo as labelno,PD.CartonNo as cartonno,PD.SKU as sku          
     , (Row_Number() OVER (PARTITION BY PH.PickSlipNo,PD.Cartonno ORDER BY PD.Cartonno,PD.sku Asc)/@n_MaxGrpLine) +1 as recgrp,          
     (pd.qty),'N'          
      FROM PACKHEADER PH WITH (NOLOCK)      
      JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo           
      JOIN SKU S WITH (NOLOCK) ON S.Storerkey = PD.storerkey AND S.SKU = PD.SKU    
      JOIN PACK P WITH (NOLOCK) ON P.Packkey = S.Packkey           
  WHERE PD.LabelNo = @c_labelno          
  AND PH.PickSlipNo = @c_pickslipno    
  --AND PD.Qty < P.Casecnt           
            
  SET @c_SKU01 = ''          
  SET @c_SKU02 = ''          
  SET @c_SKU03 = ''          
  SET @c_SKU04 = ''          
  SET @c_SKU05 = ''          
  SET @c_SKU06 = ''          
  SET @c_SKU07 = ''          
  SET @c_SKU08 = ''          
          
  SET @c_SKUQty01 = ''          
  SET @c_SKUQty02 = ''          
  SET @c_SKUQty03 = ''          
  SET @c_SKUQty04 = ''          
  SET @c_SKUQty05 = ''          
  SET @c_SKUQty06 = ''          
  SET @c_SKUQty07 = ''          
  SET @c_SKUQty08 = ''          
         
  SET @n_sumskuqty = 1          
           
             
  SELECT @n_CntRec = COUNT (1)          
  FROM #TEMPSKU           
  WHERE Pickslipno = @c_pickslipno          
  AND LabelNo = @c_labelno           
  AND Retrieve = 'N'           
            
  SET @n_TTLpage = 1          
          
  SELECT PH.PickSlipNo as Pickslipno,PD.LabelNo as labelno,PD.CartonNo as cartonno,PD.SKU as sku          
     , ((Row_Number() OVER (PARTITION BY PH.PickSlipNo,PD.Cartonno ORDER BY PD.Cartonno,PD.sku Asc)-1)/8) +1 as recgrp          
   INTO #TEMPFULLSKU          
      FROM PACKHEADER PH WITH (NOLOCK)           
      JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo           
      JOIN SKU S WITH (NOLOCK) ON S.Storerkey = PD.storerkey AND S.SKU = PD.SKU    
      JOIN PACK P WITH (NOLOCK) ON P.Packkey = S.Packkey              
  WHERE PH.PickSlipNo = @c_pickslipno           
  --AND PD.Qty < P.Casecnt      
           
          
  SELECT  @n_TTLpage  = sum(TT.TL)          
  FROM (select labelno,max(recgrp) as TL          
        FROM #TEMPFULLSKU           
        where pickslipno=@c_pickslipno          
        AND LabelNo = @c_labelno                         
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
           @n_skuqty    = SUM(Qty)          
  FROM #TEMPSKU           
  WHERE ID = @n_intFlag          
  GROUP BY SKU          
            
   IF (@n_intFlag%@n_MaxLine) = 1           
   BEGIN              
    SET @c_sku01     = @c_sku              
    SET @c_SKUQty01 = CONVERT(NVARCHAR(10),@n_skuqty)              
   END             
             
   ELSE IF (@n_intFlag%@n_MaxLine) = 2          
   BEGIN              
    SET @c_sku02  = @c_sku               
    SET @c_SKUQty02 = CONVERT(NVARCHAR(10),@n_skuqty)              
   END             
              
   ELSE IF (@n_intFlag%@n_MaxLine) = 3          
   BEGIN              
    SET @c_sku03  = @c_sku               
    SET @c_SKUQty03 = CONVERT(NVARCHAR(10),@n_skuqty)             
   END             
              
   ELSE IF (@n_intFlag%@n_MaxLine) = 4          
   BEGIN              
    SET @c_sku04  = @c_sku               
    SET @c_SKUQty04 = CONVERT(NVARCHAR(10),@n_skuqty)             
   END            
             
   ELSE IF (@n_intFlag%@n_MaxLine) = 5          
   BEGIN              
    SET @c_sku05  = @c_sku               
    SET @c_SKUQty05 = CONVERT(NVARCHAR(10),@n_skuqty)             
   END            
             
   ELSE IF (@n_intFlag%@n_MaxLine) = 0         
   BEGIN              
    SET @c_sku06  = @c_sku               
    SET @c_SKUQty06 = CONVERT(NVARCHAR(10),@n_skuqty)             
   END                
                 
             
   UPDATE #Result                      
SET  Col17 = @c_sku01,          
     Col18 = @c_SKUQty01,         
     Col19 = @c_sku02,          
     Col20 = @c_SKUQty02,               
     Col21 = @c_sku03,            
     Col22 = @c_SKUQty03,                
     Col23 = @c_sku04,            
     Col24 = @c_SKUQty04,              
     Col25 = @c_sku05,                
     Col26 = @c_SKUQty05,                  
     Col27 = @c_sku06,           
     Col28 = @c_SKUQty06                
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
  SELECT TOP 1 Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09,Col10,                    
               Col11,Col12,Col13,Col14,Col15,Col16,'','','','',                
               '','','','','', '','','',Col29,Col30,                
               Col31,Col32,Col33,'','', '','','','','',                 
               '','','','','', '','','','','',                 
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
         
          
  SET @c_SKUQty01 = ''          
  SET @c_SKUQty02 = ''          
  SET @c_SKUQty03 = ''          
  SET @c_SKUQty04 = ''          
  SET @c_SKUQty05 = ''          
  SET @c_SKUQty06 = ''          
  SET @c_SKUQty07 = ''          
  SET @c_SKUQty08 = ''                 
            
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
           
                       
END -- procedure    

GO