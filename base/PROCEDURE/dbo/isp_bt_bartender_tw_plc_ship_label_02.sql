SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/                 
/* Copyright: IDS                                                             */                 
/* Purpose: isp_BT_Bartender_TW_price_Label_02                                */                 
/*                                                                            */                 
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date       Rev  Author     Purposes                                        */                 
/* 2018-01-23 1.0  CSCHONG    Created (WMS-3804)                              */ 
/******************************************************************************/                
                  
                  
CREATE PROC [dbo].[isp_BT_Bartender_TW_PLC_ship_Label_02]                      
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
      @c_Sku             NVARCHAR(20),   
      @n_cartonno        NVARCHAR(10),                      
      @n_intFlag         INT,     
      @n_CntRec          INT,    
      @c_SQL             NVARCHAR(4000),        
      @c_SQLSORT         NVARCHAR(4000),        
      @c_SQLJOIN         NVARCHAR(4000),
      @n_totalcase       INT,
      @n_sequence        INT,
      @c_skugroup        NVARCHAR(10),
      @n_CntSku          INT,
      @n_Qty             INT,
      @n_RecCnt          INT,
      @n_TTLPQTY         INT,
      @c_material        NVARCHAR(50),
      @c_size            NVARCHAR(10),
      @c_ExecStatements  NVARCHAR(4000),    
      @c_ExecArguments   NVARCHAR(4000)  
            
          
    
  DECLARE @d_Trace_StartTime   DATETIME,   
           @d_Trace_EndTime    DATETIME,  
           @c_Trace_ModuleName NVARCHAR(20),   
           @d_Trace_Step1      DATETIME,   
           @c_Trace_Step1      NVARCHAR(20),  
           @c_UserName         NVARCHAR(20),
           @n_TTLpage          INT,        
           @n_CurrentPage      INT,
           @n_MaxLine          INT    
           
   DECLARE  @c_stylecolor1   NVARCHAR(80),           
            @c_stylecolor2    NVARCHAR(80),            
            @c_stylecolor3    NVARCHAR(80),          
            @c_stylecolor4    NVARCHAR(80),          
            @c_stylecolor5    NVARCHAR(80),          
            @c_stylecolor6    NVARCHAR(80),          
            @c_stylecolor7    NVARCHAR(80),          
            @c_stylecolor8    NVARCHAR(80),          
            @c_stylecolor9    NVARCHAR(80),          
            @c_stylecolor10   NVARCHAR(80),  
            @c_stylecolor11   NVARCHAR(80),
            @c_stylecolor12   NVARCHAR(80),
            @c_stylecolor13   NVARCHAR(80),
            @c_stylecolor14   NVARCHAR(80),
            @c_stylecolor15   NVARCHAR(80),
            @c_stylecolor16   NVARCHAR(80),   
            @c_stylecolor17   NVARCHAR(80),   
            @c_size1          NVARCHAR(80),           
            @c_size2          NVARCHAR(80),            
            @c_size3          NVARCHAR(80),          
            @c_size4          NVARCHAR(80),          
            @c_size5          NVARCHAR(80),          
            @c_size6          NVARCHAR(80),          
            @c_size7          NVARCHAR(80),       
            @c_size8          NVARCHAR(80),         
            @c_size9          NVARCHAR(80),         
            @c_size10         NVARCHAR(80),
            @c_size11         NVARCHAR(80),
            @c_size12         NVARCHAR(80),
            @c_size13         NVARCHAR(80),
            @c_size14         NVARCHAR(80),
            @c_size15         NVARCHAR(80),
            @c_size16         NVARCHAR(80),   
            @c_size17         NVARCHAR(80),
            @n_qty1           INT,
            @n_qty2           INT,
            @n_qty3           INT,
            @n_qty4           INT,
            @n_qty5           INT,
            @n_qty6           INT,
            @n_qty7           INT,
            @n_qty8           INT,
            @n_qty9           INT,
            @n_qty10          INT,
            @n_qty11          INT,
            @n_qty12          INT,
            @n_qty13          INT,
            @n_qty14          INT,
            @n_qty15          INT,
            @n_qty16          INT,
            @n_qty17          INT
            
            
            
  
   SET @d_Trace_StartTime = GETDATE()  
   SET @c_Trace_ModuleName = ''  
        
    -- SET RowNo = 0             
    SET @c_SQL = ''  
    SET @c_Sku = '' 
    SET @c_skugroup = ''    
    SET @n_totalcase = 0  
    SET @n_sequence  = 1 
    SET @n_CntSku = 1  
    SET @n_Qty    = 0     
    SET @n_TTLpage =1     
    SET @n_MaxLine = 17 
    SET @n_CntRec = 1  
    SET @n_intFlag = 1   
    SET @n_RecCnt = 1    
    SET @n_TTLPQTY = 1
    SET @n_CurrentPage = 1
              
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
     
         
     CREATE TABLE [#skuContent02] (                     
      [ID]                    [INT] IDENTITY(1,1) NOT NULL,
      [PageNum]               [INT]           NULL,
      [Pickslipno]            [NVARCHAR] (20)  NULL, 
      [cartonno]              INT NULL,      
      [sku]                   [NVARCHAR] (20)  NULL,  
      [Material]              [NVARCHAR] (50) NULL,                                    
      [Size]                  [NVARCHAR] (10) NULL,                                         
      [skuqty]                INT NULL,                     
      [Retrieve]              [NVARCHAR] (1) default 'N')  
      
         
      
      
      SET @c_SQLJOIN = +N' SELECT DISTINCT pd.cartonno,ph.pickslipno,ISNULL(o.c_company,''''),o.externorderkey,'       --4
             + ' ISNULL(O.consigneekey,''''),o.OrderKey,'
             + ' substring(ISNULL(o.C_Address1,'''')+ISNULL(o.C_Address2,'''')+ISNULL(o.C_Address3,'''')+ISNULL(o.C_Address4,''''),1,80),' --7       
             + ' CONVERT(NVARCHAR(10),LP.lpuserdefdate01,111),'''','''','            --10
             + ' '''','''','''','''','''', '            --15   
             + ' '''','''','''','''','''','             --20               
         --    + CHAR(13) +      
             + ' '''','''','''','''','''','''','''','''','''','''','  --30  
             + ' '''','''','''','''','''','''','''','''','''','''','   --40       
             + ' '''','''','''','''','''','''','''','''','''','''', '  --50       
             + ' '''','''','''','''','''','''','''','''','''','''' '   --60          
           --  + CHAR(13) +            
             + ' FROM PackHeader AS ph WITH (NOLOCK)'       
             + ' JOIN PackDetail AS pd WITH (NOLOCK) ON pd.PickSlipNo = ph.PickSlipNo'   
             + ' JOIN ORDERS AS o WITH (NOLOCK) ON o.OrderKey = ph.OrderKey '    
             + ' JOIN Loadplan LP WITH (NOLOCK) ON LP.loadkey = O.loadkey'    
             + ' WHERE pd.pickslipno =@c_Sparm01'   
             + ' AND pd.labelno = @c_Sparm02 '  
             
             
   SET @c_SQL='INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09'  + CHAR(13) +           
             +',Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22'  + CHAR(13) +           
             +',Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34' + CHAR(13) +           
             +',Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44'  + CHAR(13) +           
             +',Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54'+ CHAR(13) +           
             + ',Col55,Col56,Col57,Col58,Col59,Col60) '          
    
     SET @c_SQL = @c_SQL + @c_SQLJOIN        
        
    SET @c_ExecArguments = N' @c_Sparm01      NVARCHAR(80)'    
                          + ',@c_Sparm02      NVARCHAR(80) '     
                            
                         
   EXEC sp_ExecuteSql     @c_SQL     
                        , @c_ExecArguments    
                        , @c_Sparm01    
                        , @c_Sparm02        
               
                        
    INSERT INTO #skuContent02
    (
      PageNum,
      Pickslipno,
      cartonno,
      sku,
      Material,
      [Size],
      skuqty,
      Retrieve
    )     
    SELECT DISTINCT 1,ph.PickSlipNo,pd.CartonNo,pd.SKU,(s.style+s.color),
    s.size,pd.Qty,'N'
    FROM PackHeader AS ph WITH (NOLOCK)       
    JOIN PackDetail AS pd WITH (NOLOCK) ON pd.PickSlipNo = ph.PickSlipNo   
    JOIN SKU S WITH (NOLOCK) ON S.StorerKey = pd.StorerKey AND s.sku = pd.SKU
    WHERE pd.pickslipno =@c_Sparm01  
     AND pd.labelno = @c_Sparm02       
                                    
               SET @c_stylecolor1   = ''  
               SET @c_stylecolor2   = ''  
               SET @c_stylecolor3   = ''  
               SET @c_stylecolor4   = ''  
               SET @c_stylecolor5   = ''  
               SET @c_stylecolor6   = ''  
               SET @c_stylecolor7   = ''  
               SET @c_stylecolor8   = ''  
               SET @c_stylecolor9   = ''  
               SET @c_stylecolor10  = ''  
               SET @c_stylecolor11  = ''  
               SET @c_stylecolor12  = ''  
               SET @c_stylecolor13  = ''  
               SET @c_stylecolor14  = ''  
               SET @c_stylecolor15  = ''  
               SET @c_stylecolor16  = ''  
               SET @c_stylecolor17  = ''  
               SET @c_size1         = ''  
               SET @c_size2         = ''  
               SET @c_size3         = ''  
               SET @c_size4         = ''  
               SET @c_size5         = ''  
               SET @c_size6         = ''  
               SET @c_size7         = ''  
               SET @c_size8         = ''  
               SET @c_size9         = ''  
               SET @c_size10        = ''  
               SET @c_size11        = ''  
               SET @c_size12        = ''  
               SET @c_size13        = ''  
               SET @c_size14        = ''  
               SET @c_size15        = ''  
               SET @c_size16        = ''  
               SET @c_size17        = ''  
               SET @n_qty1          = ''  
               SET @n_qty2          = ''  
               SET @n_qty3          = ''  
               SET @n_qty4          = ''  
               SET @n_qty5          = ''  
               SET @n_qty6          = ''  
               SET @n_qty7          = ''  
               SET @n_qty8          = ''  
               SET @n_qty9          = ''  
               SET @n_qty10         = ''  
               SET @n_qty11         = ''  
               SET @n_qty12         = ''  
               SET @n_qty13         = ''  
               SET @n_qty14         = ''  
               SET @n_qty15         = ''  
               SET @n_qty16         = ''  
               SET @n_qty17         = ''  
             
   
      SELECT @n_CntRec = COUNT (1)
      FROM #skuContent02
      WHERE pickslipno = @c_Sparm01
      AND Retrieve = 'N' 
      
      SET @n_TTLpage =  FLOOR(@n_CntRec / @n_MaxLine )
   
                                       
     WHILE @n_intFlag <= @n_CntRec           
     BEGIN   
     
     SET  @c_material = ''
     SET  @c_size     =''
     SET  @n_qty      = 0
     SET  @n_TTLPQty = 0
     
     
      SELECT @n_TTLPQty = SUM(skuqty)
      FROM #skuContent02 
      where pickslipno = @c_Sparm01
      
     
     SELECT  @c_material = Material,
             @c_size = size,
             @n_qty   = skuqty     
      FROM #skuContent02 
      WHERE ID = @n_intFlag
         
      IF (@n_intFlag%@n_MaxLine) = 1 
       BEGIN        
        SET @c_stylecolor1 = @c_material
        SET @c_size1       = @c_size
        SET @n_qty1        = @n_qty    
       END
       
      
       ELSE IF (@n_intFlag%@n_MaxLine) = 2
       BEGIN        
        SET @c_stylecolor2 = @c_material
        SET @c_size2       = @c_size
        SET @n_qty2        = @n_qty    
       END      
       
       ELSE IF (@n_intFlag%@n_MaxLine) = 3
       BEGIN        
        SET @c_stylecolor3 = @c_material
        SET @c_size3       = @c_size
        SET @n_qty3        = @n_qty    
       END                
            
            
       ELSE IF (@n_intFlag%@n_MaxLine) = 4
       BEGIN        
        SET @c_stylecolor4 = @c_material
        SET @c_size4       = @c_size
        SET @n_qty4        = @n_qty    
       END    
       
       ELSE IF (@n_intFlag%@n_MaxLine) = 5
       BEGIN        
        SET @c_stylecolor5 = @c_material
        SET @c_size5       = @c_size
        SET @n_qty5        = @n_qty    
       END      
       
       ELSE IF (@n_intFlag%@n_MaxLine) = 6
       BEGIN        
        SET @c_stylecolor6 = @c_material
        SET @c_size6       = @c_size
        SET @n_qty6        = @n_qty    
       END                
            
            
       ELSE IF (@n_intFlag%@n_MaxLine) = 7
       BEGIN        
        SET @c_stylecolor7 = @c_material
        SET @c_size7       = @c_size
        SET @n_qty7        = @n_qty    
       END                  
                
       ELSE IF (@n_intFlag%@n_MaxLine) = 8
       BEGIN        
        SET @c_stylecolor8 = @c_material
        SET @c_size8       = @c_size
        SET @n_qty8        = @n_qty    
       END      
       
       ELSE IF (@n_intFlag%@n_MaxLine) = 9
       BEGIN        
        SET @c_stylecolor9 = @c_material
        SET @c_size9       = @c_size
        SET @n_qty9        = @n_qty    
       END                
            
            
       ELSE IF (@n_intFlag%@n_MaxLine) = 10
       BEGIN        
        SET @c_stylecolor10 = @c_material
        SET @c_size10       = @c_size
        SET @n_qty10        = @n_qty    
       END  
       
        ELSE IF (@n_intFlag%@n_MaxLine) = 11
       BEGIN        
        SET @c_stylecolor11 = @c_material
        SET @c_size11       = @c_size
        SET @n_qty11        = @n_qty    
       END  
       
        ELSE IF (@n_intFlag%@n_MaxLine) = 12
       BEGIN        
        SET @c_stylecolor12 = @c_material
        SET @c_size12       = @c_size
        SET @n_qty12        = @n_qty    
       END  
       
        ELSE IF (@n_intFlag%@n_MaxLine) = 13
       BEGIN        
        SET @c_stylecolor13 = @c_material
        SET @c_size13       = @c_size
        SET @n_qty13        = @n_qty    
       END  
       
        ELSE IF (@n_intFlag%@n_MaxLine) = 14
       BEGIN        
        SET @c_stylecolor14 = @c_material
        SET @c_size14       = @c_size
        SET @n_qty14        = @n_qty    
       END  
       
        ELSE IF (@n_intFlag%@n_MaxLine) = 15
       BEGIN        
        SET @c_stylecolor15 = @c_material
        SET @c_size15       = @c_size
        SET @n_qty15        = @n_qty    
       END  
       
        ELSE IF (@n_intFlag%@n_MaxLine) = 16
       BEGIN        
        SET @c_stylecolor16 = @c_material
        SET @c_size16       = @c_size
        SET @n_qty16        = @n_qty    
       END  
       
       ELSE IF (@n_intFlag%@n_MaxLine) = 0
       BEGIN        
        SET @c_stylecolor17 = @c_material
        SET @c_size17       = @c_size
        SET @n_qty17        = @n_qty    
       END    
      
     IF (@n_intFlag=@n_CntRec) OR (@n_intFlag%@n_MaxLine) = 0
     BEGIN  
       UPDATE #Result                  
       SET Col09 = CONVERT(NVARCHAR(10),@n_TTLPQTY),
           Col10 = @c_stylecolor1,         
           Col11 = @c_size1,        
           Col12 = CASE WHEN @n_qty1 > 0 THEN CONVERT(NVARCHAR(10),@n_qty1) ELSE '' END,                
           Col13 = @c_stylecolor2,         
           Col14 = @c_size2,         
           Col15 = CASE WHEN @n_qty2 > 0 THEN CONVERT(NVARCHAR(10),@n_qty2) ELSE '' END,
           Col16 = @c_stylecolor3,        
           Col17 = @c_size3,        
           Col18 = CASE WHEN @n_qty3 > 0 THEN CONVERT(NVARCHAR(10),@n_qty3) ELSE '' END,        
           Col19 = @c_stylecolor4,
           Col20 = @c_size4,        
           Col21 = CASE WHEN @n_qty4 > 0 THEN CONVERT(NVARCHAR(10),@n_qty4) ELSE '' END,        
           Col22 = @c_stylecolor5,        
           Col23 = @c_size5,        
           Col24 = CASE WHEN @n_qty5 > 0 THEN CONVERT(NVARCHAR(10),@n_qty5) ELSE '' END, 
           Col25 = @c_stylecolor6,        
           Col26 = @c_size6,        
           Col27 = CASE WHEN @n_qty6 > 0 THEN CONVERT(NVARCHAR(10),@n_qty6) ELSE '' END,        
           Col28 = @c_stylecolor7,  
           Col29 = @c_size7,        
           Col30 = CASE WHEN @n_qty7 > 0 THEN CONVERT(NVARCHAR(10),@n_qty7) ELSE '' END,
           Col31 = @c_stylecolor8,  
           Col32 = @c_size8,        
           Col33 = CASE WHEN @n_qty8 > 0 THEN CONVERT(NVARCHAR(10),@n_qty8) ELSE '' END, 
           Col34 = @c_stylecolor9,  
           Col35 = @c_size9,        
           Col36 =CASE WHEN @n_qty9 > 0 THEN CONVERT(NVARCHAR(10),@n_qty9) ELSE '' END, 
           Col37 = @c_stylecolor10,  
           Col38 = @c_size10,        
           Col39 = CASE WHEN @n_qty10 > 0 THEN CONVERT(NVARCHAR(10),@n_qty10) ELSE '' END, 
           Col40 = @c_stylecolor11,  
           Col41 = @c_size11,        
           Col42 = CASE WHEN @n_qty11 > 0 THEN CONVERT(NVARCHAR(10),@n_qty11) ELSE '' END,  
           Col43 = @c_stylecolor12,  
           Col44 = @c_size12,        
           Col45 = CASE WHEN @n_qty12 > 0 THEN CONVERT(NVARCHAR(10),@n_qty12) ELSE '' END,  
           Col46 = @c_stylecolor13,  
           Col47 = @c_size13,        
           Col48 = CASE WHEN @n_qty13 > 0 THEN CONVERT(NVARCHAR(10),@n_qty13) ELSE '' END, 
           Col49 = @c_stylecolor14,  
           Col50 = @c_size14,        
           Col51 = CASE WHEN @n_qty14 > 0 THEN CONVERT(NVARCHAR(10),@n_qty14) ELSE '' END,  
           Col52 = @c_stylecolor15, 
           Col53 = @c_size15,        
           Col54 = CASE WHEN @n_qty15 > 0 THEN CONVERT(NVARCHAR(10),@n_qty15) ELSE '' END,  
           Col55 = @c_stylecolor16,  
           Col56 = @c_size16,        
           Col57 = CASE WHEN @n_qty16 > 0 THEN CONVERT(NVARCHAR(10),@n_qty16) ELSE '' END, 
           Col58 = @c_stylecolor17,  
           Col59 = @c_size17,        
           Col60 = CASE WHEN @n_qty17 > 0 THEN CONVERT(NVARCHAR(10),@n_qty17) ELSE '' END          
       WHERE ID = @n_CurrentPage  
       
       --SELECT @n_intFlag '@n_intFlag'
       --SELECT * FROM #TEMPOTMSKU01
       --SELECT * FROM #Result
       SET @n_RecCnt = 0
       
                       
      END    
      
      
    IF @n_RecCnt = 0 AND @n_intFlag<@n_CntRec AND @n_CurrentPage <= @n_TTLpage
    BEGIN
      SET @n_CurrentPage = @n_CurrentPage + 1
      
      INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09                 
                            ,Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22               
                            ,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34                
                            ,Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44                 
                            ,Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54               
                            ,Col55,Col56,Col57,Col58,Col59,Col60) 
      SELECT TOP 1 Col01,Col02,Col03,Col04,Col05,Col06,Col07,Col08,Col09,'',                 
                   '','','','','', '','','','','',              
                   '','','','','', '','','','','',              
                   '','','','','', '','','','','',                 
                   '','','','','', '','','','','',               
                   '','','','','', '','','','',''
      FROM  #Result 
      WHERE ID=1    
      
         SET @c_stylecolor1   = ''  
         SET @c_stylecolor2   = ''  
         SET @c_stylecolor3   = ''  
         SET @c_stylecolor4   = ''  
         SET @c_stylecolor5   = ''  
         SET @c_stylecolor6   = ''  
         SET @c_stylecolor7   = ''  
         SET @c_stylecolor8   = ''  
         SET @c_stylecolor9   = ''  
         SET @c_stylecolor10  = ''  
         SET @c_stylecolor11  = ''  
         SET @c_stylecolor12  = ''  
         SET @c_stylecolor13  = ''  
         SET @c_stylecolor14  = ''  
         SET @c_stylecolor15  = ''  
         SET @c_stylecolor16  = ''  
         SET @c_stylecolor17  = ''  
         SET @c_size1         = ''  
         SET @c_size2         = ''  
         SET @c_size3         = ''  
         SET @c_size4         = ''  
         SET @c_size5         = ''  
         SET @c_size6         = ''  
         SET @c_size7         = ''  
         SET @c_size8         = ''  
         SET @c_size9         = ''  
         SET @c_size10        = ''  
         SET @c_size11        = ''  
         SET @c_size12        = ''  
         SET @c_size13        = ''  
         SET @c_size14        = ''  
         SET @c_size15        = ''  
         SET @c_size16        = ''  
         SET @c_size17        = ''  
         SET @n_qty1          = ''  
         SET @n_qty2          = ''  
         SET @n_qty3          = ''  
         SET @n_qty4          = ''  
         SET @n_qty5          = ''  
         SET @n_qty6          = ''  
         SET @n_qty7          = ''  
         SET @n_qty8          = ''  
         SET @n_qty9          = ''  
         SET @n_qty10         = ''  
         SET @n_qty11         = ''  
         SET @n_qty12         = ''  
         SET @n_qty13         = ''  
         SET @n_qty14         = ''  
         SET @n_qty15         = ''  
         SET @n_qty16         = ''  
         SET @n_qty17         = ''  
      
    END 
    
      SET @n_intFlag = @n_intFlag + 1  
      SET @n_RecCnt =   @n_RecCnt + 1
   END     
   IF @b_debug=1        
   BEGIN          
      PRINT @c_SQL          
   END        
   IF @b_debug=1        
   BEGIN        
      SELECT * FROM #Result (nolock)        
   END                    
       
            
EXIT_SP:    
  
   SET @d_Trace_EndTime = GETDATE()  
   SET @c_UserName = SUSER_SNAME()  
     
   EXEC isp_InsertTraceInfo   
      @c_TraceCode = 'BARTENDER',  
      @c_TraceName = 'isp_BT_Bartender_TW_PLC_ship_Label_02',  
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
   
   SELECT * FROM #Result (nolock) 
                                  
END -- procedure   



GO