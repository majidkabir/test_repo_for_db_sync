SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/******************************************************************************/                   
/* Copyright: IDS                                                             */                   
/* Purpose: isp_BT_UCCLBL_MY_SKECHERS                                         */                   
/*                                                                            */                   
/* Modifications log:                                                         */                   
/*                                                                            */                   
/* Date       Rev  Author     Purposes                                        */  
/*28-NOV-2018 1.0  WLCHOOI	  Created (WMS-7114)                              */  
/*02-JUL-2019 1.1  WLCHOOI	  Fixed sorting issue (WL01)                      */  
/******************************************************************************/                  
                    
CREATE PROC [dbo].[isp_BT_UCCLBL_MY_SKECHERS]                        
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
      @c_labelline		 NVARCHAR(10)        
      
  DECLARE @d_Trace_StartTime   DATETIME,     
           @d_Trace_EndTime    DATETIME,    
           @c_Trace_ModuleName NVARCHAR(20),     
           @d_Trace_Step1      DATETIME,     
           @c_Trace_Step1      NVARCHAR(20),    
           @c_UserName         NVARCHAR(20),      
           @c_SKULBL01         NVARCHAR(10),
           @c_SKULBL02         NVARCHAR(10), 
           @c_SKULBL03         NVARCHAR(10),           
           @c_SKULBL04         NVARCHAR(10),   
           @c_SKULBL05         NVARCHAR(10),           
           @c_SKULBL06         NVARCHAR(10),  
           @c_SKULBL07         NVARCHAR(10),           
           @c_SKULBL08         NVARCHAR(10),
           @c_SKU01            NVARCHAR(80),           
           @c_SKU02            NVARCHAR(80),    
           @c_SKU03            NVARCHAR(80),           
           @c_SKU04            NVARCHAR(80),   
           @c_SKU05            NVARCHAR(80),           
           @c_SKU06            NVARCHAR(80),  
           @c_SKU07            NVARCHAR(80),           
           @c_SKU08            NVARCHAR(80),                   
           @c_SKUQty01         NVARCHAR(10),          
           @c_SKUQty02         NVARCHAR(10),    
           @c_SKUQty03         NVARCHAR(10),          
           @c_SKUQty04         NVARCHAR(10),     
           @c_SKUQty05         NVARCHAR(10),          
           @c_SKUQty06         NVARCHAR(10),    
           @c_SKUQty07         NVARCHAR(10),          
           @c_SKUQty08         NVARCHAR(10),                     
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
           @c_SumQTY           INT
           
           
    SET @d_Trace_StartTime = GETDATE()    
    SET @c_Trace_ModuleName = ''    
          
    -- SET RowNo = 0               
    SET @c_SQL = ''       
    SET @n_CurrentPage = 1  
    SET @n_TTLpage =1       
    SET @n_MaxLine = 8      
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
      [orderkey]    [NVARCHAR] (20) NULL,    
      [cartonno]    [NVARCHAR] (5) NULL,         
      [SKU]         [NVARCHAR] (120) NULL,             
      [PQty]        INT,  
      [labelno]     [NVARCHAR](20) NULL,  
      [LabelLine]	[NVARCHAR](10) NULL,
      [Retrieve]    [NVARCHAR](1) default 'N')  
      --RecGrp        INT)       
  
         
       SET @c_SQLJOIN = +' SELECT DISTINCT ORDERS.Orderkey,ISNULL(RTRIM(ORDERS.ExternOrderkey),''''),ORDERS.DeliveryDate,'  
                        + ' ISNULL(RTRIM(ORDERS.Route),''''),ISNULL(RTRIM(ROUTEMASTER.CarrierKey),''''),'+ CHAR(13)      --5        
                        + ' ISNULL(RTRIM(ORDERS.ConsigneeKey),''''),ISNULL(RTRIM(ORDERS.C_Company),''''),ISNULL(RTRIM(ORDERS.C_ADDRESS1),'''')+'' '','  
                        + ' ISNULL(RTRIM(ORDERS.C_ADDRESS2),'''')+'' '',ISNULL(RTRIM(ORDERS.C_ADDRESS3),'''')+'' '','+ CHAR(13)      --10    
                        + ' ISNULL(RTRIM(ORDERS.C_Address4),'''')+'' '',ISNULL(RTRIM(ORDERS.C_City),'''')+'' '',ISNULL(RTRIM(ORDERS.C_Zip),''''), '  
                        + ' '''', '''', ' + CHAR(13) --15
                        + ' CONVERT(NVARCHAR(60), ORDERS.Notes),CASE WHEN  ISNULL(RDT.RDTUSER.FullName,'''') = '''' THEN PACKHEADER.EditWho ELSE ISNULL(RDT.RDTUSER.FullName,'''') END, '           
                        + ' ISNULL(RTRIM(PACKDETAIL.DropID),''''),PACKDETAIL.CartonNo, ORDERS.Loadkey,  ' + CHAR(13)--20  
                        + ' '''','''','''','''','''','''','''','''','''','''',' + CHAR(13)  --30    
                        + ' '''','''','''','''','''','''','''','''','''','''','  + CHAR(13) --40         
                        + ' '''','''','''','''','''','''','''','''','''','''', ' + CHAR(13) --50         
                        + ' '''','''','''','''','''','''','''','''',PACKDETAIL.LABELNO,''O'' ' + CHAR(13)  --60            
                        + ' FROM  PACKDETAIL  WITH (NOLOCK) 		'	+ CHAR(13)									
                        + ' JOIN  PACKHEADER  WITH (NOLOCK)  ON (PACKDETAIL.PickSlipNo = PACKHEADER.PickSlipNo)	'+ CHAR(13)											
                        + ' JOIN  ORDERS      WITH (NOLOCK)  ON (PACKHEADER.Orderkey = ORDERS.Orderkey)		'+ CHAR(13)										
                        + ' JOIN  SKU         WITH (NOLOCK)  ON (PACKDETAIL.Storerkey = SKU.Storerkey)		'+ CHAR(13)										
                        + '						 				  AND (PACKDETAIL.Sku = SKU.Sku)		'+ CHAR(13)
                        + ' JOIN  PACK        WITH (NOLOCK)  ON (SKU.Packkey = PACK.Packkey)				'	+ CHAR(13)								
                        + ' LEFT JOIN  ROUTEMASTER WITH (NOLOCK)  ON (ORDERS.Route  = ROUTEMASTER.Route)		'+ CHAR(13)										
                        + ' LEFT JOIN  RDT.RDTUSER WITH (NOLOCK)  ON (PACKHEADER.EditWho = RDT.RDTUSER.UserName) 	'+ CHAR(13)												
                        + ' WHERE PACKDETAIL.PICKSLIPNO = @c_Sparm01   		'+ CHAR(13)										
                        + ' AND PACKDETAIL.LABELNO = @c_Sparm02'+ CHAR(13)
                        + ' GROUP BY ORDERS.Orderkey,ISNULL(RTRIM(ORDERS.ExternOrderkey),'''')'+ CHAR(13)
                        + ',ORDERS.DeliveryDate, ISNULL(RTRIM(ORDERS.Route),''''),ISNULL(RTRIM(ROUTEMASTER.CarrierKey),'''')'+ CHAR(13)
                        + ',ISNULL(RTRIM(ORDERS.ConsigneeKey),''''),ISNULL(RTRIM(ORDERS.C_Company),''''),ISNULL(RTRIM(ORDERS.C_ADDRESS1),'''')'+ CHAR(13)
                        + ',ISNULL(RTRIM(ORDERS.C_ADDRESS2),''''),ISNULL(RTRIM(ORDERS.C_ADDRESS3),'''')'+ CHAR(13)
                        + ',ISNULL(RTRIM(ORDERS.C_Address4),''''),ISNULL(RTRIM(ORDERS.C_City),'''')'+ CHAR(13)
                        + ',ISNULL(RTRIM(ORDERS.C_Zip),''''),CONVERT(NVARCHAR(60), ORDERS.Notes)'+ CHAR(13)
                        + ',CASE WHEN  ISNULL(RDT.RDTUSER.FullName,'''') = '''' THEN PACKHEADER.EditWho ELSE ISNULL(RDT.RDTUSER.FullName,'''') END'+ CHAR(13)
                        + ',ISNULL(RTRIM(PACKDETAIL.DropID),''''),PACKDETAIL.CartonNo,ORDERS.Loadkey,PACKDETAIL.LABELNO'

         
       
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
                          + ', @c_Sparm02          NVARCHAR(80) '      
						--  + ', @c_Sparm03          NVARCHAR(80) '   
                           
                           
   EXEC sp_ExecuteSql     @c_SQL       
                        , @c_ExecArguments      
                        , @c_Sparm01     
                        , @c_Sparm02 
						--, @c_Sparm03       
          
    --EXEC sp_executesql @c_SQL            
          
   IF @b_debug=1          
   BEGIN            
      PRINT @c_SQL            
   END    
     
           
   IF @b_debug=1          
   BEGIN          
      SELECT * FROM #Result (nolock)          
   END      
 
 
   SELECT @c_MaxLBLLine = MAX(LabelLine),
          @c_SumQTY = SUM(Qty)
   FROM PACKDETAIL (NOLOCK)
   WHERE pickslipno = @c_Sparm01
   AND LABELNO = @c_Sparm02

   UPDATE #RESULT
   SET COL14 = @c_MaxLBLLine, Col15 = @c_SumQTY
   WHERE COL59 = @c_Sparm02

   DECLARE CUR_RowNoLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   SELECT DISTINCT col59,col01,col19       
   FROM #Result                 
   WHERE Col60 = 'O'           
            
   OPEN CUR_RowNoLoop                    
               
   FETCH NEXT FROM CUR_RowNoLoop INTO @c_labelno,@c_orderkey,@c_cartonno      
                 
   WHILE @@FETCH_STATUS <> -1               
   BEGIN                   
      IF @b_debug='1'                
      BEGIN                
         PRINT @c_labelno                   
      END   
        
        
      INSERT INTO #TEMPSKU (Orderkey,Cartonno,SKU,PQty,labelno,labelline,Retrieve)          
      SELECT DISTINCT @c_orderkey,@c_cartonno,CASE WHEN ISNULL(CL1.SHORT,'') = 'Y' THEN S.DESCR ELSE S.SKU END,
                      pd.qty,@c_labelno,CAST(PD.LabelLine AS INT),'N'  --WL01
      FROM ORDERS AS o WITH (NOLOCK)   
      JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.orderkey = o.orderkey  
      JOIN PackDetail AS pd WITH (NOLOCK) ON pd.storerkey = OD.storerkey AND pd.sku = od.sku  
      JOIN SKU AS S WITH (NOLOCK)  ON (PD.Storerkey = S.Storerkey)												
						 				  AND (PD.Sku = S.Sku)	
			LEFT JOIN  CODELKUP CL1 WITH (NOLOCK)  ON (CL1.ListName = 'REPORTCFG') AND(CL1.Code = 'SHOWSKUDESC')	
                                         AND(CL1.Storerkey = PD.Storerkey)
                                         AND(CL1.Long = 'isp_BT_UCCLBL_MY_SKECHERS')
      WHERE pd.labelno = @c_labelno  
      AND pd.cartonno = CONVERT(INT,@c_cartonno)  
      AND o.orderkey = @c_orderkey  
      GROUP BY S.sku,PD.Qty,CL1.SHORT,S.DESCR,PD.LabelLine
      --ORDER BY REPLACE(LTRIM(REPLACE(PD.LabelLine, '0', ' ')), ' ', '0') --WL01
      ORDER BY CAST(PD.LabelLine AS INT) --WL01
      
	  SET @c_SKULBL01 = ''
	  SET @c_SKULBL02 = ''
	  SET @c_SKULBL03 = ''
	  SET @c_SKULBL04 = ''
	  SET @c_SKULBL05 = ''
	  SET @c_SKULBL06 = ''
	  SET @c_SKULBL07 = ''
	  SET @c_SKULBL08 = '' 
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
  
  
  --SELECT * FROM #TEMPSKU  
           
      SELECT @n_CntRec = COUNT (1)  
      FROM #TEMPSKU   
      WHERE labelno = @c_labelno  
      AND orderkey = @c_orderkey   
      AND Retrieve = 'N'   
        
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
        Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,                
        '','','','','', '','','','','',                
        '','','','','', '','','','','',                   
        '','','','','', '','','','','',                 
        '','','','','', '','','',Col59,Col60  
      FROM  #Result   
      WHERE Col60='O'   
    
      SET @c_SKULBL01 = ''
	   SET @c_SKULBL02 = ''
	   SET @c_SKULBL03 = ''
	   SET @c_SKULBL04 = ''
	   SET @c_SKULBL05 = ''
	   SET @c_SKULBL06 = ''
	   SET @c_SKULBL07 = ''
	   SET @c_SKULBL08 = '' 
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
              
        
      SELECT @c_labelline = LabelLine, 
             @c_sku = SKU,  
             @n_skuqty = SUM(PQty)  
      FROM #TEMPSKU   
      WHERE ID = @n_intFlag  
      GROUP BY SKU,LabelLine
        
      IF (@n_intFlag%@n_MaxLine) = 1 --AND @n_recgrp = @n_CurrentPage  
      BEGIN   
        --SELECT '1'
        SET @c_SKULBL01 = @c_labelline          
        SET @c_sku01 = @c_sku  
        SET @c_SKUQty01 = CONVERT(NVARCHAR(10),@n_skuqty)        
      END          
         
      ELSE IF (@n_intFlag%@n_MaxLine) = 2  --AND @n_recgrp = @n_CurrentPage  
      BEGIN      
        --SELECT '2'
        SET @c_SKULBL02 = @c_labelline        
        SET @c_sku02 = @c_sku  
        SET @c_SKUQty02 = CONVERT(NVARCHAR(10),@n_skuqty)           
      END    
      ELSE IF (@n_intFlag%@n_MaxLine) = 3  --AND @n_recgrp = @n_CurrentPage  
      BEGIN      
        --SELECT '3'   
        SET @c_SKULBL03 = @c_labelline     
        SET @c_sku03 = @c_sku  
        SET @c_SKUQty03 = CONVERT(NVARCHAR(10),@n_skuqty)           
      END    
      ELSE IF (@n_intFlag%@n_MaxLine) = 4  --AND @n_recgrp = @n_CurrentPage  
      BEGIN      
        --SELECT '4'   
        SET @c_SKULBL04 = @c_labelline     
        SET @c_sku04 = @c_sku  
        SET @c_SKUQty04 = CONVERT(NVARCHAR(10),@n_skuqty)           
      END    
      ELSE IF (@n_intFlag%@n_MaxLine) = 5 --AND @n_recgrp = @n_CurrentPage  
      BEGIN      
        --SELECT '5'   
        SET @c_SKULBL05 = @c_labelline     
        SET @c_sku05 = @c_sku  
        SET @c_SKUQty05 = CONVERT(NVARCHAR(10),@n_skuqty)           
      END    
      ELSE IF (@n_intFlag%@n_MaxLine) = 6  --AND @n_recgrp = @n_CurrentPage  
      BEGIN      
        --SELECT '6'   
        SET @c_SKULBL06 = @c_labelline     
        SET @c_sku06 = @c_sku  
        SET @c_SKUQty06 = CONVERT(NVARCHAR(10),@n_skuqty)           
      END    
      ELSE IF (@n_intFlag%@n_MaxLine) = 7  --AND @n_recgrp = @n_CurrentPage  
      BEGIN      
        --SELECT '7'     
        SET @c_SKULBL07 = @c_labelline   
        SET @c_sku07 = @c_sku  
        SET @c_SKUQty07 = CONVERT(NVARCHAR(10),@n_skuqty)           
      END    
      ELSE IF (@n_intFlag%@n_MaxLine) = 0  --AND @n_recgrp = @n_CurrentPage  
      BEGIN      
        --SELECT '8'   
        SET @c_SKULBL08 = @c_labelline     
        SET @c_sku08= @c_sku  
        SET @c_SKUQty08 = CONVERT(NVARCHAR(10),@n_skuqty)           
      END              
      
  UPDATE #Result                    
  SET Col21 = @c_skulbl01,
      Col22 = @c_sku01,           
      Col23 = @c_SKUQty01,
      Col24 = @c_skulbl02,          
      Col25 = @c_sku02,                  
      Col26 = @c_SKUQty02, 
      Col27 = @c_skulbl03,          
      Col28 = @c_sku03,           
      Col29 = @c_SKUQty03,  
      Col30 = @c_skulbl04,        
      Col31 = @c_sku04,          
      Col32 = @c_SKUQty04, 
      Col33 = @c_skulbl05,          
      Col34 = @c_sku05,          
      Col35 = @c_SKUQty05, 
      Col36 = @c_skulbl06,  
      Col37 = @c_sku06,  
      Col38 = @c_SKUQty06, 
      Col39 = @c_skulbl07,  
      Col40 = @c_sku07,  
      Col41 = @c_SKUQty07,  
      Col42 = @c_skulbl08, 
      Col43 = @c_sku08,  
      Col44 = @c_SKUQty08  
    WHERE ID = @n_CurrentPage   
      
   -- SELECT * FROM #Result    
     
    UPDATE  #TEMPSKU
    SET Retrieve ='Y'  
    WHERE ID= @n_intFlag   
                      
          
     SET @n_intFlag = @n_intFlag + 1    
  
     IF @n_intFlag > @n_CntRec  
     BEGIN  
       BREAK;  
     END        
   END  
   FETCH NEXT FROM CUR_RowNoLoop INTO @c_labelno,@c_orderkey,@c_cartonno          
          
      END -- While                     
      CLOSE CUR_RowNoLoop                    
      DEALLOCATE CUR_RowNoLoop     
     
         
 SELECT * FROM #Result (nolock)      
 --WHERE ISNULL(Col02,'') <> ''      
 --ORDER BY 1
              
EXIT_SP:      
    
   SET @d_Trace_EndTime = GETDATE()    
   SET @c_UserName = SUSER_SNAME()    
       
   EXEC isp_InsertTraceInfo     
      @c_TraceCode = 'BARTENDER',    
      @c_TraceName = 'isp_BT_UCCLBL_MY_SKECHERS',    
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