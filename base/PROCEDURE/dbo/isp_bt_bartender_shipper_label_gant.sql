SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/******************************************************************************/                   
/* Copyright: LFL                                                             */                   
/* Purpose: isp_BT_Bartender_Shipper_Label_Gant                               */                   
/*                                                                            */                   
/* Modifications log:                                                         */                   
/*                                                                            */                   
/* Date       Rev  Author     Purposes                                        */  
/*02-Dec-2020 1.0  WLChooi    Created (WMS-15785)                             */ 
/*18-May-2022 1.1  Mingle     Add new logic (WMS-19641)                       */
/******************************************************************************/                  
                    
CREATE PROC [dbo].[isp_BT_Bartender_Shipper_Label_Gant]                        
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
                    
      @c_altsku          NVARCHAR(80),                           
      @n_intFlag         INT,       
      @n_CntRec          INT,      
      @c_SQL             NVARCHAR(4000),          
      @c_SQLSORT         NVARCHAR(4000),          
      @c_SQLJOIN         NVARCHAR(4000),  
      @c_col58           NVARCHAR(10),
      @c_pickslipno      NVARCHAR(20),
      @n_CartonNo        INT ,
      @n_ttlqty          INT       
      
   DECLARE @d_Trace_StartTime  DATETIME,     
           @d_Trace_EndTime    DATETIME,    
           @c_Trace_ModuleName NVARCHAR(20),     
           @d_Trace_Step1      DATETIME,     
           @c_Trace_Step1      NVARCHAR(20),    
           @c_UserName         NVARCHAR(20),      
           @c_SSTYLE01         NVARCHAR(50),
           @c_SSTYLE02         NVARCHAR(50), 
           @c_SSTYLE03         NVARCHAR(50),           
           @c_SSTYLE04         NVARCHAR(50),   
           @c_SSTYLE05         NVARCHAR(50),           
           @c_SSTYLE06         NVARCHAR(50),  
           @c_SSTYLE07         NVARCHAR(50),           
           @c_SSTYLE08         NVARCHAR(50),
           @c_SSTYLE09         NVARCHAR(50),
           @c_SSTYLE10         NVARCHAR(50),
           @c_ALTSKU01         NVARCHAR(80),           
           @c_ALTSKU02         NVARCHAR(80),    
           @c_ALTSKU03         NVARCHAR(80),           
           @c_ALTSKU04         NVARCHAR(80),   
           @c_ALTSKU05         NVARCHAR(80),           
           @c_ALTSKU06         NVARCHAR(80),  
           @c_ALTSKU07         NVARCHAR(80),           
           @c_ALTSKU08         NVARCHAR(80), 
           @c_ALTSKU09         NVARCHAR(80),
           @c_ALTSKU10         NVARCHAR(80),                 
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
           @c_labelno          NVARCHAR(20) ,  
           @c_orderkey         NVARCHAR(20) ,  
           @n_skuqty           INT ,  
           @n_skurqty          INT ,  
           @c_cartonno         NVARCHAR(5),  
           @n_loopno           INT,  
           @c_LastRec          NVARCHAR(1),  
           @c_ExecStatements   NVARCHAR(4000),      
           @c_ExecArguments    NVARCHAR(4000), 
		   @c_busr5            NVARCHAR(30),	--ML01  
           
           @c_MaxLBLLine       INT,
           @c_SumQTY           INT,
           @n_MaxCarton        INT,
           @c_SSTYLE           NVARCHAR(80),
           @n_SumPack          INT,
           @n_SumPick          INT,
           @n_MaxCtnNo         INT,
		   --START ML01
		   @c_BUSR501         NVARCHAR(50),
           @c_BUSR502         NVARCHAR(50), 
           @c_BUSR503         NVARCHAR(50),           
           @c_BUSR504         NVARCHAR(50),   
           @c_BUSR505         NVARCHAR(50),           
           @c_BUSR506         NVARCHAR(50),  
           @c_BUSR507         NVARCHAR(50),           
           @c_BUSR508         NVARCHAR(50),
           @c_BUSR509         NVARCHAR(50),
           @c_BUSR510         NVARCHAR(50)
		   --END ML01

    SELECT @n_MaxCarton = MAX(PD.CartonNo)
    FROM PACKDETAIL PD (NOLOCK)
    WHERE PD.PICKSLIPNO = @c_Sparm01
    
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
      [Pickslipno]  [NVARCHAR] (20) NULL,
      [style]       [NVARCHAR] (20) NULL,  
      [altSKU]      [NVARCHAR] (80) NULL,             
      [PQty]        INT,
	  [busr5]       [NVARCHAR] (30) NULL )	--ML01
      
         
       SET @c_SQLJOIN = +' SELECT DISTINCT ORD.Orderkey, ORD.ExternOrderkey,CASE WHEN ORD.ordergroup=''VIP'' THEN ST.company else ORD.C_Company END, '  --3
                        +' ISNULL(ORD.C_Contact1,''''), ISNULL(ORD.C_Phone1,''''), '   + CHAR(13) --5
                        +' ISNULL(ORD.C_State,''''), LTRIM(RTRIM(ISNULL(ORD.C_City,''''))), '
                        --+' SUBSTRING(LTRIM(RTRIM(ISNULL(ORD.C_State,''''))) + '' '' + LTRIM(RTRIM(ISNULL(ORD.C_City,''''))) + '' '' + '+ CHAR(13) --8
                        --+' LTRIM(RTRIM(ISNULL(ORD.C_Address1,''''))) + '' '' + LTRIM(RTRIM(ISNULL(ORD.C_Address2,''''))) + '' '' + '+ CHAR(13) --8
                        --+' LTRIM(RTRIM(ISNULL(ORD.C_Address3,''''))) + '' '' + LTRIM(RTRIM(ISNULL(ORD.C_Address4,''''))),1,80), '+ CHAR(13) --8
                        +' SUBSTRING(LTRIM(RTRIM(ISNULL(ORD.C_Address1,''''))) + '' '' + LTRIM(RTRIM(ISNULL(ORD.C_Address2,''''))) + '' '' + '+ CHAR(13) --8
                        +' LTRIM(RTRIM(ISNULL(ORD.C_Address3,''''))) + '' '' + LTRIM(RTRIM(ISNULL(ORD.C_Address4,''''))),1,80), '+ CHAR(13) --8
                        +' PD.CartonNo , SUBSTRING(LTRIM(RTRIM(ISNULL(ORD.Notes,''''))),1,80), '+ CHAR(13)      --10        
                        +' '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', '+ CHAR(13)  --20
                        +' '''','''','''','''','''','''','''','''','''','''', ' + CHAR(13) --30 
                        +' '''','''','''','''','''','''','''','''','''','''', ' + CHAR(13) --40 
                        +' '''','''',ISNULL(ORD.Userdefine03,''''),ISNULL(ORD.OrderGroup,''''),CASE WHEN ORD.ordergroup=''VIP'' THEN ORD.Userdefine04 else pif.cartongid END,PD.LabelNo, ' --ML01
						+' '''','''','''','''', ' + CHAR(13) --50
                        +' '''','''','''','''','''','''', '''','''', ' + CHAR(13) --58
                        +' '''',PD.PICKSLIPNO ' + CHAR(13) --60               
                        +' FROM PACKDETAIL PD  WITH (NOLOCK)      '  + CHAR(13)                          
                        +' JOIN PACKHEADER PH WITH (NOLOCK)  ON (PD.PickSlipNo = PH.PickSlipNo) '+ CHAR(13)                               
                        +' JOIN ORDERS ORD WITH (NOLOCK)  ON (ORD.Orderkey = PH.Orderkey)    '+ CHAR(13)       
                        +' LEFT JOIN STORER ST WITH (NOLOCK) ON (ST.Storerkey = ORD.Consigneekey AND ST.Type= ''2'')  ' + CHAR(13)       
                        +' JOIN PackInfo PIF WITH (NOLOCK) ON (PD.Pickslipno = PIF.Pickslipno AND PIF.CartonNo = PD.CartonNo) ' + CHAR(13)  
                        --+' JOIN SKU WITH (NOLOCK) ON SKU.SKU = PD.SKU AND SKU.STORERKEY = PH.STORERKEY ' + CHAR(13)                    
                        +' WHERE PD.PICKSLIPNO = @c_Sparm01       '+ CHAR(13)                            
                        +' AND PD.CartonNo = @c_Sparm02'+ CHAR(13)


       
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
   SELECT DISTINCT col60,col09      
   FROM #Result 
   ORDER BY col09                     
            
   OPEN CUR_RowNoLoop                    
               
   FETCH NEXT FROM CUR_RowNoLoop INTO @c_pickslipno,@c_cartonno      
                 
   WHILE @@FETCH_STATUS <> -1               
   BEGIN                   
      IF @b_debug='1'                
      BEGIN                
         PRINT @c_labelno                   
      END   
      
      INSERT INTO #TEMPSKU (Cartonno,pickslipno, style, altSKU, PQty,busr5)	--ML01          
      SELECT DISTINCT PD.CartonNo
                    , PH.PICKSLIPNO
                    , LTRIM(RTRIM(ISNULL(Sku.sku,'')))      
                    , sku.altsku
                    , PD.Qty
					, sku.busr5	--ML01
      FROM PACKDETAIL PD (NOLOCK) 
      JOIN PACKHEADER PH (NOLOCK) ON PH.PICKSLIPNO = PD.PICKSLIPNO
      JOIN SKU (NOLOCK) ON PD.SKU = SKU.SKU AND PH.STORERKEY = SKU.STORERKEY
      WHERE PH.PICKSLIPNO = @c_pickslipno
      AND PD.cartonno = @c_cartonno
      GROUP BY PH.PICKSLIPNO,PD.CartonNo, PD.Qty, LTRIM(RTRIM(ISNULL(Sku.sku,''))),SKU.altsku,sku.busr5  --CS01	--ML01
      ORDER BY PD.CartonNo, sku.altsku
      
      SET @c_SSTYLE01 = ''
      SET @c_SSTYLE02 = ''
      SET @c_SSTYLE03 = ''
      SET @c_SSTYLE04 = ''
      SET @c_SSTYLE05 = ''
      SET @c_SSTYLE06 = ''
      SET @c_SSTYLE07 = ''
      SET @c_SSTYLE08 = ''
      SET @c_SSTYLE09 = ''
      SET @c_SSTYLE10 = '' 
      
      SET @c_ALTSKU01 = ''  
      SET @c_ALTSKU02 = ''  
      SET @c_ALTSKU03 = ''  
      SET @c_ALTSKU04 = ''  
      SET @c_ALTSKU05 = ''  
      SET @c_ALTSKU06 = ''  
      SET @c_ALTSKU07 = ''  
      SET @c_ALTSKU08 = ''  
      SET @c_ALTSKU09 = ''
      SET @c_ALTSKU10 = ''
      
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

	  --START ML01
	  SET @c_BUSR501 = ''
      SET @c_BUSR502 = ''
      SET @c_BUSR503 = ''
      SET @c_BUSR504 = ''
      SET @c_BUSR505 = ''
      SET @c_BUSR506 = ''
      SET @c_BUSR507 = ''
      SET @c_BUSR508 = ''
      SET @c_BUSR509 = ''
      SET @c_BUSR510 = ''
      --END ML01

      SELECT @n_CntRec = COUNT (1)  
      FROM #TEMPSKU   
      WHERE pickslipno = @c_pickslipno
      AND CartonNo = @c_cartonno    
      
      SET @n_ttlqty = 1
      
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
                         '','','','','','','','','','',                
                         '','','','','','','','','','',                
                         '','','','','','','','','','',                   
                         '','',Col43,Col44,Col45,Col46,'','','','',                
                         '','','','','','','','','',Col60  
            FROM  #Result
          
            SET @c_SSTYLE01 = ''
            SET @c_SSTYLE02 = ''
            SET @c_SSTYLE03 = ''
            SET @c_SSTYLE04 = ''
            SET @c_SSTYLE05 = ''
            SET @c_SSTYLE06 = ''
            SET @c_SSTYLE07 = ''
            SET @c_SSTYLE08 = ''
            SET @c_SSTYLE09 = ''
            SET @c_SSTYLE10 = '' 
            
            SET @c_ALTSKU01 = ''  
            SET @c_ALTSKU02 = ''  
            SET @c_ALTSKU03 = ''  
            SET @c_ALTSKU04 = ''  
            SET @c_ALTSKU05 = ''  
            SET @c_ALTSKU06 = ''  
            SET @c_ALTSKU07 = ''  
            SET @c_ALTSKU08 = ''  
            SET @c_ALTSKU09 = ''
            SET @c_ALTSKU10 = ''
            
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
           
		    --START ML01
			SET @c_BUSR501 = ''
            SET @c_BUSR502 = ''
            SET @c_BUSR503 = ''
            SET @c_BUSR504 = ''
            SET @c_BUSR505 = ''
            SET @c_BUSR506 = ''
            SET @c_BUSR507 = ''
            SET @c_BUSR508 = ''
            SET @c_BUSR509 = ''
            SET @c_BUSR510 = ''
			--END ML01
         END      
                
         SELECT --@c_SSTYLE = style, 
                @c_Altsku = altSKU,  
                @n_skuqty = SUM(PQty),
				@c_busr5 = busr5	--ML01
         FROM #TEMPSKU   
         WHERE ID = @n_intFlag  
         GROUP BY style,altSKU,busr5 --ML01

         SELECT @n_ttlqty = SUM(PQTY)
         FROM #TEMPSKU  
         where cartonno = @c_cartonno

         IF (@n_intFlag % @n_MaxLine) = 1 --AND @n_recgrp = @n_CurrentPage  
         BEGIN   
            --SET @c_SSTYLE01 = @c_SSTYLE 
			SET @c_BUSR501 = @c_BUSR5	--ML01
            SET @c_altsku01 = @c_altsku  
            SET @c_SKUQty01 = CONVERT(NVARCHAR(10),@n_skuqty)        
         END
         
         ELSE IF (@n_intFlag % @n_MaxLine) = 2  --AND @n_recgrp = @n_CurrentPage  
         BEGIN      
            --SET @c_SSTYLE02 = @c_SSTYLE      
			SET @c_BUSR502 = @c_BUSR5	--ML01
            SET @c_altsku02 = @c_altsku  
            SET @c_SKUQty02 = CONVERT(NVARCHAR(10),@n_skuqty)           
         END   
         
         ELSE IF (@n_intFlag % @n_MaxLine) = 3  --AND @n_recgrp = @n_CurrentPage  
         BEGIN      
            --SET @c_SSTYLE03 = @c_SSTYLE 
			SET @c_BUSR503 = @c_BUSR5	--ML01
            SET @c_altsku03 = @c_altsku  
            SET @c_SKUQty03 = CONVERT(NVARCHAR(10),@n_skuqty)           
         END 
         
         ELSE IF (@n_intFlag % @n_MaxLine) = 4  --AND @n_recgrp = @n_CurrentPage  
         BEGIN      
            --SET @c_SSTYLE04 = @c_SSTYLE
			SET @c_BUSR504 = @c_BUSR5	--ML01
            SET @c_altsku04 = @c_altsku  
            SET @c_SKUQty04 = CONVERT(NVARCHAR(10),@n_skuqty)           
         END 
         
         ELSE IF (@n_intFlag % @n_MaxLine) = 5  --AND @n_recgrp = @n_CurrentPage  
         BEGIN      
            --SET @c_SSTYLE05 = @c_SSTYLE   
			SET @c_BUSR505 = @c_BUSR5	--ML01
            SET @c_altsku05 = @c_altsku  
            SET @c_SKUQty05 = CONVERT(NVARCHAR(10),@n_skuqty)           
         END 
         
         ELSE IF (@n_intFlag % @n_MaxLine) = 6  --AND @n_recgrp = @n_CurrentPage  
         BEGIN      
            --SET @c_SSTYLE06 = @c_SSTYLE  
			SET @c_BUSR506 = @c_BUSR5	--ML01
            SET @c_altsku06 = @c_altsku  
            SET @c_SKUQty06 = CONVERT(NVARCHAR(10),@n_skuqty)           
         END 
         
         ELSE IF (@n_intFlag % @n_MaxLine) = 7  --AND @n_recgrp = @n_CurrentPage  
         BEGIN      
            --SET @c_SSTYLE07 = @c_SSTYLE 
			SET @c_BUSR507 = @c_BUSR5	--ML01
            SET @c_altsku07 = @c_altsku  
            SET @c_SKUQty07 = CONVERT(NVARCHAR(10),@n_skuqty)           
         END 
         
         ELSE IF (@n_intFlag % @n_MaxLine) = 8  --AND @n_recgrp = @n_CurrentPage  
         BEGIN      
            --SET @c_SSTYLE08 = @c_SSTYLE   
			SET @c_BUSR508 = @c_BUSR5	--ML01
            SET @c_altsku08 = @c_altsku  
            SET @c_SKUQty08 = CONVERT(NVARCHAR(10),@n_skuqty)           
         END 
         
         ELSE IF (@n_intFlag % @n_MaxLine) = 9  --AND @n_recgrp = @n_CurrentPage  
         BEGIN      
            --SET @c_SSTYLE09 = @c_SSTYLE    
			SET @c_BUSR509 = @c_BUSR5	--ML01
            SET @c_altsku09 = @c_altsku  
            SET @c_SKUQty09 = CONVERT(NVARCHAR(10),@n_skuqty)           
         END 
         
         ELSE IF (@n_intFlag % @n_MaxLine) = 0  --AND @n_recgrp = @n_CurrentPage  
         BEGIN      
            --SET @c_SSTYLE10 = @c_SSTYLE   
			SET @c_BUSR510 = @c_BUSR5
            SET @c_altsku10 = @c_altsku  
            SET @c_SKUQty10 = CONVERT(NVARCHAR(10),@n_skuqty)           
         END 

         UPDATE #Result                    
         SET Col12 = @c_BUSR501, Col11 = @c_altsku01, Col13 = @c_SKUQty01,	--START ML01
             Col15 = @c_BUSR502, Col14 = @c_altsku02, Col16 = @c_SKUQty02, 
             Col18 = @c_BUSR503, Col17 = @c_altsku03, Col19 = @c_SKUQty03,  
             Col21 = @c_BUSR504, Col20 = @c_altsku04, Col22 = @c_SKUQty04, 
             Col24 = @c_BUSR505, Col23 = @c_altsku05, Col25 = @c_SKUQty05, 
             Col27 = @c_BUSR506, Col26 = @c_altsku06, Col28 = @c_SKUQty06, 
             Col30 = @c_BUSR507, Col29 = @c_altsku07, Col31 = @c_SKUQty07,  
             Col33 = @c_BUSR508, Col32 = @c_altsku08, Col34 = @c_SKUQty08,               
             Col36 = @c_BUSR509, Col35 = @c_altsku09, Col37 = @c_SKUQty09,
             Col39 = @c_BUSR510, Col38 = @c_altsku10, Col40 = @c_SKUQty10,	--END ML01
             Col42 = CAST(@n_CurrentPage AS NVARCHAR(5)) + '/' + CAST(@n_TTLpage AS NVARCHAR(5))
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
   SET COL41 = (SELECT SUM(Qty) FROM PACKDETAIL (NOLOCK) WHERE PICKSLIPNO = @c_Sparm01 and cartonno = @c_Sparm02)
   WHERE COL60 = @c_Sparm01
   AND Col09 = @c_Sparm02

   IF(@b_debug = 1)
   BEGIN
      SELECT @n_SumPick AS SUMPICK, @n_SumPack AS SUMPACK, @n_MaxCtnNo AS MAXCTN, @c_Sparm02 AS CURRENTCTN
   END
   
   SELECT * FROM #Result    
 
EXIT_SP:      
    
   SET @d_Trace_EndTime = GETDATE()    
   SET @c_UserName = SUSER_SNAME()    
       
   --EXEC isp_InsertTraceInfo     
   --   @c_TraceCode = 'BARTENDER',    
   --   @c_TraceName = 'isp_BT_Bartender_Shipper_Label_Gant',    
   --   @c_starttime = @d_Trace_StartTime,    
   --   @c_endtime = @d_Trace_EndTime,    
   --   @c_step1 = @c_UserName,    
   --   @c_step2 = '',    
   --   @c_step3 = '',    
   --   @c_step4 = '',    
   --   @c_step5 = '',    
   --   @c_col1 = @c_Sparm01,     
   --   @c_col2 = @c_Sparm02,    
   --   @c_col3 = @c_Sparm03,    
   --   @c_col4 = @c_Sparm04,    
   --   @c_col5 = @c_Sparm05,    
   --   @b_Success = 1,    
   --   @n_Err = 0,    
   --   @c_ErrMsg = ''                
                                       
END -- procedure  

GO