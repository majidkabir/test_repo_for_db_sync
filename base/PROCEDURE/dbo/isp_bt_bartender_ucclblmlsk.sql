SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/******************************************************************************/                   
/* Copyright: IDS                                                             */                   
/* Purpose: isp_BT_Bartender_UCCLBLMLSK                                       */                   
/*                                                                            */                   
/* Modifications log:                                                         */                   
/*                                                                            */                   
/* Date       Rev  Author     Purposes                                        */  
/*28-MAY-2020 1.0  CSCHONG   Created (WMS-13390)                              */  
/*12-JUN-2020 1.1  CSCHONG   WMS-13390 revised col07 logic (CS01)             */
/*15-JUL-2020 1.2  CSCHONG   WMS-14221 revised field logic (CS02)             */
/******************************************************************************/                  
                    
CREATE PROC [dbo].[isp_BT_Bartender_UCCLBLMLSK]                        
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
      @c_sku             NVARCHAR(80),                           
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
           @c_SKU01            NVARCHAR(80),           
           @c_SKU02            NVARCHAR(80),    
           @c_SKU03            NVARCHAR(80),           
           @c_SKU04            NVARCHAR(80),   
           @c_SKU05            NVARCHAR(80),           
           @c_SKU06            NVARCHAR(80),  
           @c_SKU07            NVARCHAR(80),  
           @c_SKU08            NVARCHAR(80),  --CS02         
           @c_AltSKU01         NVARCHAR(20), 
           @c_AltSKU02         NVARCHAR(20),
           @c_AltSKU03         NVARCHAR(20),
           @c_AltSKU04         NVARCHAR(20),
           @c_AltSKU05         NVARCHAR(20),
           @c_AltSKU06         NVARCHAR(20),
           @c_AltSKU07         NVARCHAR(20), 
           @c_AltSKU08         NVARCHAR(20),   --CS02                
           @c_SKUQty01         NVARCHAR(10),          
           @c_SKUQty02         NVARCHAR(10),    
           @c_SKUQty03         NVARCHAR(10),          
           @c_SKUQty04         NVARCHAR(10),     
           @c_SKUQty05         NVARCHAR(10),          
           @c_SKUQty06         NVARCHAR(10),    
           @c_SKUQty07         NVARCHAR(10),       
           @c_SKUQty08         NVARCHAR(10),     --CS02          
           @n_TTLpage          INT,          
           @n_CurrentPage      INT,  
           @n_MaxLine          INT  ,  
           @c_labelno          NVARCHAR(20) ,  
           @c_orderkey         NVARCHAR(20) ,  
           @n_skuqty           INT ,  
           @n_qtybypage        INT ,  
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
           @n_MaxCtnNo         INT, 
           @c_altsku           NVARCHAR(20)  
          
    SELECT TOP 1 @c_Pickslipno = PD.Pickslipno
    FROM PACKDETAIL PD (NOLOCK)
    WHERE PD.labelno = @c_Sparm01

    SELECT @n_MaxCarton = MAX(PD.CartonNo)
    FROM PACKDETAIL PD (NOLOCK)
    WHERE PD.PICKSLIPNO = @c_Pickslipno
    
    SET @d_Trace_StartTime = GETDATE()    
    SET @c_Trace_ModuleName = ''    
          
    -- SET RowNo = 0               
    SET @c_SQL = ''       
    SET @n_CurrentPage = 1  
    SET @n_TTLpage =1       
    SET @n_MaxLine = 8              --CS02     
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
      [SKU]         [NVARCHAR] (20) NULL,  
      [AltSKU]      [NVARCHAR] (20) NULL,            
      [PQty]        INT)
      
         
       SET @c_SQLJOIN = +' SELECT DISTINCT ISNULL(ORD.BuyerPO,''''), ISNULL(ORD.C_Phone1,''''), ISNULL(ORD.C_Contact1,''''),'
                        + 'ISNULL(ST.B_Address1,''''),ISNULL(ST.notes1,''''),'   + CHAR(13) --5
                        +' PD.labelno,'''','''','''','''', '+ CHAR(13) --10      
                        +' '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', '+ CHAR(13)  --20
                        +' '''','''','''','''','''','''',PD.CartonNo ,'''','''','''', ' + CHAR(13) --30 
                        +' '''','''','''',REPLACE(CONVERT(NVARCHAR(16),getdate(),120),''-'',''/''), '
                        + ' ST.Susr2,ST.Susr1,'''','''','''','''', ' + CHAR(13) --40     --CS02
                        +' '''','''','''','''','''','''','''', '+ CHAR(13) --47 
                        +' '''','''','''', ' + CHAR(13) --50 
                        +' '''','''','''','''','''','''','''','''', ' + CHAR(13) --58
                        +' '''', '''' ' + CHAR(13) --60               
                        +' FROM PACKDETAIL PD  WITH (NOLOCK)      '  + CHAR(13)                          
                        +' JOIN PACKHEADER PH WITH (NOLOCK)  ON (PD.PickSlipNo = PH.PickSlipNo) '+ CHAR(13)                               
                        +' JOIN ORDERS ORD WITH (NOLOCK)  ON (ORD.Orderkey = PH.Orderkey)    '+ CHAR(13)       
                    --    +' JOIN ORDERDETAIL OD WITH (NOLOCK) ON ORD.Orderkey = OD.Orderkey '+ CHAR(13)      
                        +' JOIN STORER ST WITH (NOLOCK) ON ST.Storerkey = ORD.consigneekey ' + CHAR(13)    
                    --    +' JOIN SKU WITH (NOLOCK) ON SKU.SKU = PD.SKU AND SKU.STORERKEY = PH.STORERKEY ' + CHAR(13)  
                    --    +' JOIN PACKINFO PIF (NOLOCK) ON PIF.PICKSLIPNO = PH.PICKSLIPNO AND PIF.CARTONNO = PD.CARTONNO ' + CHAR(13)                   
                        +' WHERE PD.labelno = @c_Sparm01       '+ CHAR(13)                            
                        +' AND PH.Storerkey = @c_Sparm02'+ CHAR(13)
  
       
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
   SELECT DISTINCT col06,col27     
   FROM #Result 
   ORDER BY col06                     
            
   OPEN CUR_RowNoLoop                    
               
   FETCH NEXT FROM CUR_RowNoLoop INTO @c_labelno,@c_cartonno      
                 
   WHILE @@FETCH_STATUS <> -1               
   BEGIN                   
      IF @b_debug='1'                
      BEGIN                
         PRINT @c_labelno                   
      END   

      INSERT INTO #TEMPSKU ( Cartonno, labelno,SKU,altsku, PQty)          
      SELECT DISTINCT PD.CartonNo,PD.LabelNo
                    , PD.sku
                    , Sku.altsku
                    , PD.Qty
      FROM PACKDETAIL PD (NOLOCK) 
      JOIN PACKHEADER PH (NOLOCK) ON PH.PICKSLIPNO = PD.PICKSLIPNO
      JOIN SKU (NOLOCK) ON PD.SKU = SKU.SKU AND PH.STORERKEY = SKU.STORERKEY
      JOIN ORDERS ORD (NOLOCK) ON ORD.ORDERKEY = PH.ORDERKEY
      JOIN ORDERDETAIL OD (NOLOCK) ON ORD.ORDERKEY = OD.ORDERKEY
      JOIN PICKDETAIL PID (NOLOCK) ON PID.ORDERKEY = ORD.ORDERKEY AND PID.ORDERLINENUMBER = OD.ORDERLINENUMBER
                                  AND PID.SKU = OD.SKU
      WHERE PD.LABELNO = @c_labelno
      GROUP BY PD.LabelNo, PD.CartonNo, PD.SKU, PD.Qty,Sku.altsku
      ORDER BY PD.CartonNo
      
      SET @c_SKU01 = ''  
      SET @c_SKU02 = ''  
      SET @c_SKU03 = ''  
      SET @c_SKU04 = ''  
      SET @c_SKU05 = ''  
      SET @c_SKU06 = ''  
      SET @c_SKU07 = '' 
      SET @c_SKU08 = ''  --CS02 
      
      SET @c_AltSKU01 = ''  
      SET @c_AltSKU02 = ''
      SET @c_AltSKU03 = ''
      SET @c_AltSKU04 = ''
      SET @c_AltSKU05 = ''
      SET @c_AltSKU06 = ''
      SET @c_AltSKU07 = ''
      SET @c_AltSKU08 = '' --CS02
      
      SET @c_SKUQty01 = ''  
      SET @c_SKUQty02 = ''  
      SET @c_SKUQty03 = ''  
      SET @c_SKUQty04 = ''  
      SET @c_SKUQty05 = ''  
      SET @c_SKUQty06 = ''  
      SET @c_SKUQty07 = ''  
      SET @c_SKUQty08 = ''    --CS02 
      SET @n_qtybypage = 0
  
  --SELECT * FROM #TEMPSKU  
           
     SELECT @n_CntRec = COUNT (1)
           ,@c_SumQTY = SUM(PQty)     --CS01  
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
          SELECT TOP 1 Col01,Col02,Col03,Col04,Col05,Col06,Col07,'','','',                   
                       '','','','','','','','','','',                
                       '','','','','','','',
                       '','','',                
                       '',cast(@n_CurrentPage as nvarchar(5)) + 'of' + cast (@n_TTLpage as nvarchar(5)),'',col34,Col35,Col36,'','','','',   --CS02                
                       '','','','','','','','','','',                 
                       '','','','','','','','','',''  
          FROM  #Result
          
          
          SET @c_SKU01 = ''  
          SET @c_SKU02 = ''  
          SET @c_SKU03 = ''  
          SET @c_SKU04 = ''  
          SET @c_SKU05 = ''  
          SET @c_SKU06 = ''  
          SET @c_SKU07 = '' 
          SET @c_SKU08 = ''  --CS02  
                 
          SET @c_AltSKU01 = ''  
          SET @c_AltSKU02 = ''
          SET @c_AltSKU03 = ''
          SET @c_AltSKU04 = ''
          SET @c_AltSKU05 = ''
          SET @c_AltSKU06 = ''
          SET @c_AltSKU07 = ''       
          SET @c_AltSKU08 = '' --CS02

          SET @c_SKUQty01 = ''  
          SET @c_SKUQty02 = ''  
          SET @c_SKUQty03 = ''  
          SET @c_SKUQty04 = ''  
          SET @c_SKUQty05 = ''  
          SET @c_SKUQty06 = ''  
          SET @c_SKUQty07 = ''  
          SET @c_SKUQty08 = ''    --CS02  
          SET @n_qtybypage = 0
          
       END      
                
      SELECT @c_sku    = SKU,  
             @n_skuqty = SUM(PQty),
             @c_altsku = altsku       
      FROM #TEMPSKU   
      WHERE ID = @n_intFlag  
      GROUP BY SKU,altsku

      IF (@n_intFlag%@n_MaxLine) = 1 --AND @n_recgrp = @n_CurrentPage  
      BEGIN            
         SET @c_sku01    = @c_sku  
         SET @c_SKUQty01 = CONVERT(NVARCHAR(10),@n_skuqty) 
         SET @c_altsku01  = @c_altsku 

      END

      ELSE IF (@n_intFlag%@n_MaxLine) = 2  --AND @n_recgrp = @n_CurrentPage  
      BEGIN            
         SET @c_sku02 = @c_sku  
         SET @c_SKUQty02 = CONVERT(NVARCHAR(10),@n_skuqty)  
         SET @c_altsku02  = @c_altsku       
      END   

      ELSE IF (@n_intFlag%@n_MaxLine) = 3  --AND @n_recgrp = @n_CurrentPage  
      BEGIN            
         SET @c_sku03 = @c_sku  
         SET @c_SKUQty03 = CONVERT(NVARCHAR(10),@n_skuqty)   
         SET @c_altsku03  = @c_altsku      
      END 

      ELSE IF (@n_intFlag%@n_MaxLine) = 4  --AND @n_recgrp = @n_CurrentPage  
      BEGIN             
         SET @c_sku04 = @c_sku  
         SET @c_SKUQty04 = CONVERT(NVARCHAR(10),@n_skuqty) 
         SET @c_altsku04  = @c_altsku        
      END 

      ELSE IF (@n_intFlag%@n_MaxLine) = 5  --AND @n_recgrp = @n_CurrentPage  
      BEGIN            
         SET @c_sku05 = @c_sku  
         SET @c_SKUQty05 = CONVERT(NVARCHAR(10),@n_skuqty) 
         SET @c_altsku05  = @c_altsku         
      END 

     ELSE IF (@n_intFlag%@n_MaxLine) = 6  --AND @n_recgrp = @n_CurrentPage  
      BEGIN            
         SET @c_sku06 = @c_sku  
         SET @c_SKUQty06 = CONVERT(NVARCHAR(10),@n_skuqty) 
         SET @c_altsku06  = @c_altsku         
      END 
      ELSE IF (@n_intFlag%@n_MaxLine) = 7 --AND @n_recgrp = @n_CurrentPage  
      BEGIN          
         SET @c_sku07 = @c_sku  
         SET @c_SKUQty07 = CONVERT(NVARCHAR(10),@n_skuqty)     
         SET @c_altsku07  = @c_altsku      
      END 

      ELSE IF (@n_intFlag%@n_MaxLine) = 0  --AND @n_recgrp = @n_CurrentPage  
      BEGIN          
         SET @c_sku08 = @c_sku  
         SET @c_SKUQty08 = CONVERT(NVARCHAR(10),@n_skuqty)     
         SET @c_altsku08  = @c_altsku      
      END 

      --ELSE IF (@n_intFlag%@n_MaxLine) = 0  --AND @n_recgrp = @n_CurrentPage  
      --BEGIN      
      --   SET @c_Made07 = @c_Made        
      --   SET @c_sku07 = @c_sku  
      --   SET @c_SKUQty07 = CONVERT(NVARCHAR(10),@n_skuqty)   
      --   SET @c_SSIZE07  = @c_SSIZE   
      --   SET @c_STYLECOLOR07 = @c_STYLECOLOR        
      --END 

    SET @n_qtybypage = CAST(@c_SKUQty01 as INT) + CAST(@c_SKUQty02 as INT) + CAST(@c_SKUQty03 as INT) + CAST(@c_SKUQty04  as INT)+ CAST(@c_SKUQty05  as INT) + CAST(@c_SKUQty06  as INT)
      
  UPDATE #Result                    
  SET col07 = @c_SumQTY,Col08 = @c_SKUQty01, Col09 = @c_SKUQty02 ,Col10 = @c_SKUQty03,Col11 = @c_SKUQty04, Col12 = @c_SKUQty05,   --CS01
      Col13 = @c_SKUQty06,col14=@c_SKUQty07,col15=@c_SKUQty08,
      Col16 = @c_sku01, Col17 = @c_sku02, Col18 = @c_sku03,Col19 = @c_sku04, Col20 = @c_sku05, 
      Col21 = @c_sku06, Col22 = @c_sku07,Col23 = @c_sku08,
      Col24 = @c_altsku01, Col25 = @c_altsku02,Col26 = @c_altsku03, Col27 = @c_altsku04, 
      Col28 = @c_altsku05, Col29 = @c_altsku06,Col30 = @c_altsku07,Col31 = @c_altsku08,
      col32 = CASE WHEN @c_cartonno = CAST(@n_MaxCarton as nvarchar(5)) THEN @c_cartonno + '/' + CAST(@n_MaxCarton as nvarchar(5))
              ELSE @c_cartonno + ' of' END,  --CS02
      col33 = case when isnull(col33,'') = '' THEN cast(@n_CurrentPage as nvarchar(5)) + ' of ' + cast (@n_TTLpage as nvarchar(5)) else col33 end    --CS02

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
   
   SELECT * FROM #Result    

              
EXIT_SP:      
    
   SET @d_Trace_EndTime = GETDATE()    
   SET @c_UserName = SUSER_SNAME()    
       
   EXEC isp_InsertTraceInfo     
      @c_TraceCode = 'BARTENDER',    
      @c_TraceName = 'isp_BT_Bartender_UCCLBLMLSK',    
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