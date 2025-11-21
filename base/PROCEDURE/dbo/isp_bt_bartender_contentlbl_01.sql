SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/                 
/* Copyright: IDS                                                             */                 
/* Purpose: isp_BT_Bartender_CONTENTLBL_01                                    */                 
/*                                                                            */                 
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date          Rev  Author     Purposes                                     */     
/* 17-JUN-2019   1.0  CSCHONG    WMS-9327 Created                             */            
/******************************************************************************/                
                  
CREATE PROC [dbo].[isp_BT_Bartender_CONTENTLBL_01]                      
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
      @c_SStyle          NVARCHAR(80),
      @c_SSize           NVARCHAR(80),
      @c_SColor          NVARCHAR(80),
      @c_SDESCR          NVARCHAR(80),
     @c_PDQty           NVARCHAR(80),
      @c_ExecStatements  NVARCHAR(4000),      
      @c_ExecArguments   NVARCHAR(4000)           
    
  DECLARE  @d_Trace_StartTime  DATETIME,   
           @d_Trace_EndTime    DATETIME,  
           @c_Trace_ModuleName NVARCHAR(20),   
           @d_Trace_Step1      DATETIME,   
           @c_Trace_Step1      NVARCHAR(80),  
           @c_UserName         NVARCHAR(80),
           @c_SizeQty01        NVARCHAR(80),         
           @c_SizeQty02        NVARCHAR(80),          
           @c_SizeQty03        NVARCHAR(80),        
           @c_SizeQty04        NVARCHAR(80),        
           @c_SizeQty05        NVARCHAR(80),  
           @c_SizeQty06        NVARCHAR(80),       
           @c_SSTYLE01         NVARCHAR(80),         
           @c_SSTYLE02         NVARCHAR(80),          
           @c_SSTYLE03         NVARCHAR(80),        
           @c_SSTYLE04         NVARCHAR(80),        
           @c_SSTYLE05         NVARCHAR(80),  
           @c_SSTYLE06         NVARCHAR(80),     
           @c_SSIZE01          NVARCHAR(80),         
           @c_SSIZE02          NVARCHAR(80),          
           @c_SSIZE03          NVARCHAR(80),        
           @c_SSIZE04          NVARCHAR(80),        
           @c_SSIZE05          NVARCHAR(80),
           @c_SSIZE06          NVARCHAR(80),     
           @c_SColor01         NVARCHAR(80),         
           @c_SColor02         NVARCHAR(80),          
           @c_SColor03         NVARCHAR(80),        
           @c_SColor04         NVARCHAR(80),        
           @c_SColor05         NVARCHAR(80),    
           @c_SColor06         NVARCHAR(80),                                  
           @c_SKUQty01         NVARCHAR(80),        
           @c_SKUQty02         NVARCHAR(80),         
           @c_SKUQty03         NVARCHAR(80),         
           @c_SKUQty04         NVARCHAR(80),         
           @c_SKUQty05         NVARCHAR(80) ,
           @c_SKUQty06         NVARCHAR(80) ,
           @n_TTLpage          INT,        
           @n_CurrentPage      INT,
           @n_MaxLine          INT  ,
           @n_MAxPageLine      INT  ,
           @n_RecPerLine       INT  ,
           @c_cartonno         NVARCHAR(10) ,
           @n_MaxCtnNo         INT,
           @n_skuqty           INT,
           @n_pageQty          INT,
           @n_LineQty          INT,
           @n_Pickqty          INT,
           @n_PACKQty          INT,
           @c_col54            NVARCHAR(20),
           @c_Delimiter        NVARCHAR(5),
           @n_cntSize          INT,
           @n_TTLPQty          INT,
           @c_getpickslipno    NVARCHAR(10) ,
           @c_getcartonno      NVARCHAR(10) , 
           @c_STYLEDESCR       NVARCHAR(80) ,
           @c_PrevSTYLEDESCR   NVARCHAR(80) ,
           @c_GSColor          NVARCHAR(80) ,
           @c_GSize            NVARCHAR(80) ,
           @c_SizeQty          NVARCHAR(80) ,
           @n_GQty             INT,
           @n_MRecGrp          INT,
           @n_GRecGrp          INT,
           @n_lineCnt          INT        
           
  
   SET @d_Trace_StartTime = GETDATE()  
   SET @c_Trace_ModuleName = ''  
        
    -- SET RowNo = 0             
    SET @c_SQL = ''     
    SET @n_CurrentPage = 1
    SET @n_TTLpage     = 1     
    SET @n_MAxPageLine = 6  
    SET @n_RecPerLine  = 12
    SET @n_CntRec      = 1  
    SET @n_intFlag     = 1        
    SET @c_col54       = ''
    SET @c_Delimiter   = ';'
    SET @n_cntSize     = 1
    SET @c_PrevSTYLEDESCR = ''
    SET @n_lineCnt = 1
    SET @n_LineQty = 0
              
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
      [ID]             [INT] IDENTITY(1,1) NOT NULL,                                      
      [Pickslipno]     [NVARCHAR] (20)  NULL,  
      [CartonNo]       [NVARCHAR] (30)  NULL,        
      [SSTYLEDESCR]    [NVARCHAR] (80)  NULL,
      [SSIZE]          [NVARCHAR] (20)  NULL,
      [SCOLOR]         [NVARCHAR] (80)  NULL, 
      [SMeasurement]   [NVARCHAR] (80)  NULL,          
      [Qty]            INT , 
      [RecGrp]         INT,
      [Retrieve]       [NVARCHAR] (1) default 'N')     
     
     CREATE TABLE [#TEMPSKUINFO] (                   
      [ID]             [INT] IDENTITY(1,1) NOT NULL,                                      
      [Pickslipno]     [NVARCHAR] (20)  NULL,  
      [CartonNo]       [NVARCHAR] (30)  NULL,        
      [SSTYLEDESCR]    [NVARCHAR] (80)  NULL,
      [SSIZE]          [NVARCHAR] (80)  NULL,
      [SCOLOR]         [NVARCHAR] (80)  NULL,          
      [Qty]            NVARCHAR(80) , 
      [TTLQty]         INT ,
      [Retrieve]       [NVARCHAR] (1) default 'N')        
           
  SET @c_SQLJOIN = +' SELECT DISTINCT (ISNULL(C.UDF04,'''')+RIGHT(RTRIM(ORD.Externorderkey),7)),SUBSTRING(ORD.Ordergroup + LEFT(ORD.Notes,12),1,80),ORD.consigneekey,'
             + ' ORD.c_Company,PD.CartonNo,'+ CHAR(13)      --5      
             + ' ORD.Externorderkey,ORD.BuyerPO,'''','''','''','     --10  
             + ' '''','''','''','''','''','     --15  
             + ' '''','''','''','''','''','     --20       
             + CHAR(13) +      
             + ' '''','''','''','''','''','''','''','''','''','''','  --30  
             + ' '''','''','''','''','''','''','''',PD.labelno,RIGHT(PD.labelno,7),PIF.weight,'   --40       
             + ' '''','''','''','''','''','''','''','''','''','''', '  --50       
             + ' '''','''','''', '
             + ' '''','''','''','''','''', '
             + ' '''',(RTRIM(PH.Pickslipno) + ''O'') '   --60          
             + CHAR(13) +            
             +' FROM ORDERS ORD WITH (NOLOCK) '
           --+' JOIN FACILITY F WITH (NOLOCK) ON F.facility = ORD.Facility'
           --+' JOIN STORER S WITH (NOLOCK) ON S.storerkey = ORD.Storerkey'
             +' JOIN PACKHEADER PH WITH (NOLOCK) ON PH.OrderKey = ORD.OrderKey'
             +' JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.Pickslipno = PH.Pickslipno ' 
             +' LEFT JOIN PACKINFO PIF WITH (NOLOCK) ON PIF.Pickslipno = PD.Pickslipno AND PIF.CartonNo = PD.CartonNo '
             + 'LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = ''BRToll'' AND C.code=RTRIM(ORD.shipperkey)' 
         -- +  'AND C.storerkey = ORD.Storerkey'
           --  +' AND PIF.CartonNo = PD.CartonNo '    
             + ' WHERE PD.Pickslipno =  @c_Sparm01'                                           
             + ' AND PD.Cartonno = CONVERT(INT,  @c_Sparm02)'                                
           --  + ' AND PD.Cartonno <= CONVERT(INT,  @c_Sparm03)'                    
            
          
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
  
  SET @c_SSIZE = ''

  DECLARE CUR_RowNoLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
  SELECT DISTINCT LEFT(col60,10),col05     
  FROM #Result               
  WHERE RIGHT(Col60,1) = 'O'   
          
   OPEN CUR_RowNoLoop                  
             
   FETCH NEXT FROM CUR_RowNoLoop INTO @c_Pickslipno,@c_cartonno    
               
   WHILE @@FETCH_STATUS <> -1             
   BEGIN                 
      IF @b_debug='1'              
      BEGIN              
         PRINT @c_Pickslipno +space(2) +@c_cartonno             
      END 

     SET @n_cntSize = 1
     SET @n_TTLPQty = 1


     SELECT @n_cntSize = COUNT(DISTINCT S.Size)
           ,@n_TTLPQty = SUM(PD.Qty)
     FROM packdetail pd (nolock)
      JOIN sku s (nolock) on s.StorerKey = pd.StorerKey and s.Sku = pd.sku 
      WHERE PD.Pickslipno = @c_Pickslipno
      AND PD.Cartonno = CAST(@c_cartonno as INT) 
      
      INSERT INTO [#TEMPSKU] (Pickslipno, cartonno, SSTYLEDESCR, SSIZE, SCOLOR,SMeasurement, Qty,
                  RecGrp,Retrieve)
      SELECT DISTINCT PD.Pickslipno,PD.CartonNo,SUBSTRING((S.Style+space(1)+S.Descr),1,80),S.Size,S.color,
                     s.Measurement,pd.qty
                 ,(Row_Number() OVER (PARTITION BY SUBSTRING((S.Style+space(1)+S.Descr),1,80) ORDER BY S.Measurement Asc)) AS recgrp 
                 ,'N'
      FROM packdetail pd (nolock)
      JOIN sku s (nolock) on s.StorerKey = pd.StorerKey and s.Sku = pd.sku 
      WHERE PD.Pickslipno = @c_Pickslipno
      AND PD.Cartonno = CAST(@c_cartonno as INT)  
      GROUP BY PD.Pickslipno,PD.CartonNo,SUBSTRING((S.Style+space(1)+S.Descr),1,80),S.Size,S.color,
                     s.Measurement,pd.qty
      ORDER BY PD.Pickslipno,PD.Cartonno,S.measurement

     DECLARE CUR_StyleLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT  Pickslipno, cartonno, SSTYLEDESCR, SSIZE, SCOLOR, Qty,RecGrp
      FROM [#TEMPSKU]               
      WHERE Pickslipno =    @c_Pickslipno
     and CartonNo = @c_cartonno
     order by ID
          
      OPEN CUR_StyleLoop                  
             
      FETCH NEXT FROM CUR_StyleLoop INTO @c_getpickslipno,@c_getcartonno,@c_STYLEDESCR,@c_GSize,@c_GSColor ,@n_Gqty,@n_GRecGrp   
               
      WHILE @@FETCH_STATUS <> -1             
      BEGIN 

     SET @n_MRecGrp = 1
     SET @n_lineCnt = 1

     SELECT @n_MRecGrp = MAX(RecGrp)
     FROM [#TEMPSKU]
     WHERE pickslipno = @c_getpickslipno
     and cartonno = @c_getcartonno
     and SSTYLEDESCR = @c_STYLEDESCR

     SET @n_lineCnt = @n_MRecGrp

     IF @b_debug = '1'
     BEGIN
      -- SELECT *  FROM [#TEMPSKU]   
      SELECT @n_MRecGrp '@n_MRecGrp', @n_lineCnt '@n_lineCnt',@n_GRecGrp '@n_GRecGrp'
     END

     IF @n_MRecGrp >= @n_GRecGrp          
     BEGIN  
           IF @n_MRecGrp = '1' 
           BEGIN      
             SET @c_SSTYLE = @c_STYLEDESCR
             SET @c_SColor = @c_GSColor
             SET @c_SSIZE  = @c_GSize + space(1) + @c_Delimiter
             SET @c_PDQty = CONVERT(NVARCHAR(10),@n_Gqty)   
             SET @n_LineQty =  @n_Gqty
           END
           ELSE 
           BEGIN
              
             SET @c_SSTYLE = @c_STYLEDESCR
             SET @c_SColor = @c_GSColor
             SET @c_SSIZE  = (ISNULL(@c_SSIZE,'') + @c_GSize+ @c_Delimiter) 
             SET @c_PDQty =  (@c_PDQty + CONVERT(NVARCHAR(10),@n_Gqty) + @c_Delimiter)  
             SET @n_LineQty =  @n_LineQty + @n_Gqty

           END
       END  

      IF @n_MRecGrp%@n_RecPerLine = 0 OR @n_MRecGrp = @n_GRecGrp
      BEGIN
         INSERT INTO #TEMPSKUINFO (Pickslipno, cartonno, SSTYLEDESCR, SSIZE, SCOLOR, Qty,TTLQty)
         VALUES (@c_getpickslipno,@c_getcartonno,@c_SSTYLE,@c_SSIZE,@c_SColor,@c_PDQty,@n_LineQty)

       SET @c_SSTYLE = ''
       SET @c_SColor = ''
       SET @c_SSIZE = ''
       SET @c_PDQty = ''
       SET @n_MRecGrp = 1
       END

     FETCH NEXT FROM CUR_StyleLoop INTO @c_getpickslipno,@c_getcartonno,@c_STYLEDESCR,@c_GSize,@c_GSColor ,@n_Gqty,@n_GRecGrp          
        
      END -- While                   
      CLOSE CUR_StyleLoop                  
      DEALLOCATE CUR_StyleLoop 

     IF @b_debug = '1'
     BEGIN
       SELECT * from #TEMPSKUINFO
     END

           
      SET @c_SSTYLE01 = ''
      SET @c_SSTYLE02 = ''
      SET @c_SSTYLE03 = ''
      SET @c_SSTYLE04 = ''
      SET @c_SSTYLE05= ''
      SET @c_SSTYLE06 = ''
      SET @c_SSIZE01 = ''
      SET @c_SSIZE02 = ''
      SET @c_SSIZE03 = ''
      SET @c_SSIZE04 = ''
      SET @c_SSIZE05= ''
      SET @c_SSIZE06 = ''
      SET @c_SColor01 = ''
      SET @c_SColor02 = ''
      SET @c_SColor03 = ''
      SET @c_SColor04 = ''
      SET @c_SColor05= ''
      SET @c_SColor06 = ''
      SET @c_SKUQty01 = ''
      SET @c_SKUQty02 = ''
      SET @c_SKUQty03 = ''
      SET @c_SKUQty04 = ''
      SET @c_SKUQty05 = ''
      SET @c_SKUQty06 = ''
      SET @n_MaxCtnNo = 0
      SET @n_TTLpage = 1
      SET @n_pageQty = 0
      SET @n_Pickqty = 0
      SET @n_PACKQty = 0

      SELECT @n_CntRec = COUNT (1)
      FROM #TEMPSKUINFO 
      WHERE Pickslipno = @c_Pickslipno
      AND Cartonno = @c_cartonno 

      SET @n_TTLpage =  FLOOR(@n_CntRec / @n_MAxPageLine )

    WHILE @n_intFlag <= @n_CntRec           
     BEGIN   
      
      SELECT 
             @c_SStyle = SSTYLEDESCR,
             @c_SSize  = SSIZE,
             @c_SColor = SCOLOR,
             @c_SizeQty = Qty,
             @n_skuqty = SUM(ttlqty)
      FROM #TEMPSKUINFO 
      WHERE Cartonno = @c_cartonno 
      GROUP BY SSTYLEDESCR,SSIZE, SCOLOR,Qty
      
      IF (@n_intFlag%@n_MAxPageLine) = 1 
      BEGIN        
        SET @c_SizeQty01  = @c_SizeQty
        SET @c_SSTYLE01   = @c_SStyle
        SET @c_SColor01   = @c_SColor
        SET @c_SSIZE01    = @c_SSize
        SET @c_SKUQty01   = CONVERT(NVARCHAR(10),@n_skuqty)   
      END        
       
      ELSE IF (@n_intFlag%@n_MAxPageLine) = 2
      BEGIN        
        SET @c_SizeQty02  = @c_SizeQty
        SET @c_SSTYLE02 = @c_SStyle
        SET @c_SColor02 = @c_SColor
        SET @c_SSIZE02  = @c_SSize
        SET @c_SKUQty02 = CONVERT(NVARCHAR(10),@n_skuqty)       
      END        
        
      ELSE IF (@n_intFlag%@n_MAxPageLine) = 3
      BEGIN            
        SET @c_SizeQty03  = @c_SizeQty
        SET @c_SSTYLE03 = @c_SStyle
        SET @c_SColor03 = @c_SColor
        SET @c_SSIZE03  = @c_SSize
        SET @c_SKUQty03 = CONVERT(NVARCHAR(10),@n_skuqty)      
      END        
          
      ELSE IF (@n_intFlag%@n_MAxPageLine) = 4
      BEGIN        
        SET @c_SizeQty04  = @c_SizeQty
        SET @c_SSTYLE04 = @c_SStyle
        SET @c_SColor04 = @c_SColor
        SET @c_SSIZE04  = @c_SSize
        SET @c_SKUQty04 = CONVERT(NVARCHAR(10),@n_skuqty)       
      END     
       
      ELSE IF (@n_intFlag%@n_MAxPageLine) = 5
      BEGIN        
        SET @c_SizeQty05  = @c_SizeQty
        SET @c_SSTYLE05 = @c_SStyle
        SET @c_SColor05 = @c_SColor
        SET @c_SSIZE05  = @c_SSize
        SET @c_SKUQty05 = CONVERT(NVARCHAR(10),@n_skuqty)         
      END   
       
      ELSE IF (@n_intFlag%@n_MAxPageLine) = 0
      BEGIN        
        SET @c_SizeQty06  = @c_SizeQty
        SET @c_SSTYLE06 = @c_SStyle
        SET @c_SColor06 = @c_SColor
        SET @c_SSIZE06  = @c_SSize
        SET @c_SKUQty06 = CONVERT(NVARCHAR(10),@n_skuqty)       
      END
      
         
       UPDATE #Result                  
       SET Col08 = @c_sstyle01,         
           Col09 = @c_SColor01,         
           Col10 = @c_SSIZE01,        
           Col11 = @c_SizeQty01,       
           Col12 = @c_SKUQty01,        
           Col13 = @c_sstyle02,        
           Col14 = @c_SColor02,  
           Col15 = @c_SSIZE02,
           Col16 = @c_SizeQty02,
           Col17 = @c_SKUQty02,
           Col18 = @c_sstyle03,
           Col19 = @c_SColor03,
           Col20 = @c_SSIZE03,
           Col21 = @c_SizeQty03,
           Col22 = @c_SKUQty03,
           Col23 = @c_sstyle04,
           Col24 = @c_SColor04,
           Col25 = @c_SSIZE04,  
           Col26 = @c_SizeQty04,  
           Col27 = @c_SKUQty04,  
           Col28 = @c_sstyle05,  
           Col29 = @c_SColor05,
           Col30 = @c_SSIZE05,  
           Col31 = @c_SizeQty05,  
           Col32 = @c_SKUQty05,  
           Col33 = @c_sstyle06,
           Col34 = @c_SColor06, 
           Col35 = @c_SSIZE06, 
           Col36 = @c_SizeQty06,  
           Col37 = @c_SKUQty06, 
           Col41 = CAST(@n_TTLPQty as nvarchar(10))
       WHERE ID = @n_CurrentPage  
       
       
   IF (@n_intFlag%@n_MAxPageLine) = 0 --AND (@n_CntRec - 1) <> 0
   BEGIN
      SET @n_CurrentPage = @n_CurrentPage + 1

      SET @c_SizeQty01 = ''
      SET @c_SizeQty02 = ''
      SET @c_SizeQty03 = ''
      SET @c_SizeQty04 = ''
      SET @c_SizeQty05= ''
      SET @c_SizeQty06= ''
      SET @c_SSTYLE01 = ''
      SET @c_SSTYLE02 = ''
      SET @c_SSTYLE03 = ''
      SET @c_SSTYLE04 = ''
      SET @c_SSTYLE05= ''
      SET @c_SSTYLE06 = ''
      SET @c_SSIZE01 = ''
      SET @c_SSIZE02 = ''
      SET @c_SSIZE03 = ''
      SET @c_SSIZE04 = ''
      SET @c_SSIZE05= ''
      SET @c_SSIZE06 = ''
      SET @c_SColor01 = ''
      SET @c_SColor02 = ''
      SET @c_SColor03 = ''
      SET @c_SColor04 = ''
      SET @c_SColor05= ''
      SET @c_SColor06 = ''
      SET @c_SKUQty01 = ''
      SET @c_SKUQty02 = ''
      SET @c_SKUQty03 = ''
      SET @c_SKUQty04 = ''
      SET @c_SKUQty05 = ''
      SET @c_SKUQty06 = ''
      SET @n_pageqty = 0
      
      INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09                 
                            ,Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22               
                            ,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34                
                            ,Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44                 
                            ,Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54               
                            ,Col55,Col56,Col57,Col58,Col59,Col60) 
      SELECT TOP 1 Col01,Col02,Col03,Col04,Col05,Col06,Col07,'','','',                 
                   '','','','','', '','','','','',              
                   '','','','','', '','','','','',              
                   '','','','','', '','',col38,col39,col40,                 
                   '','','','','', '','','','','',               
                   '','','','','', '','','','',col60
     FROM  #Result 
     WHERE RIGHT(Col60,1)='O'                    
      
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
      @c_TraceName = 'isp_BT_Bartender_CONTENTLBL_01',  
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