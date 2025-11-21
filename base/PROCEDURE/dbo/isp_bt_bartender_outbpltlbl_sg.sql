SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/                   
/* Copyright: IDS                                                             */                   
/* Purpose: isp_BT_Bartender_OUTBPLTLBL_SG                                    */                   
/*                                                                            */                   
/* Modifications log:                                                         */                   
/*                                                                            */                   
/* Date       Rev  Author     Purposes                                        */   
/* 2018-10-09 1.0  CSCHONG    WMS-6575 created                                */ 
/* 2018-11-02 1.1  WLCHOOI    WMS-6893 - Added PickDetail.Loc  (WL01)         */    
/* 2020-04-29 1.2  WLChooi    WMS-13176 - Added Col41 to Col47 (WL02)         */                 
/******************************************************************************/                  
        
CREATE PROC [dbo].[isp_BT_Bartender_OUTBPLTLBL_SG]                        
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
     @c_sku             NVARCHAR(20),                           
     @n_intFlag         INT,       
     @n_CntRec          INT,      
     @c_SQL             NVARCHAR(4000),          
     @c_SQLSORT         NVARCHAR(4000),          
     @c_SQLJOIN         NVARCHAR(4000),  
     @c_SDESCR          NVARCHAR(80),  
     @c_SSize           NVARCHAR(20),  
     @c_LOTT02          NVARCHAR(20),  
     @c_ExecStatements  NVARCHAR(4000),        
     @c_ExecArguments   NVARCHAR(4000)             
      
   DECLARE @d_Trace_StartTime   DATETIME,     
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
           @c_SDESCR01         NVARCHAR(80),           
           @c_SDESCR02         NVARCHAR(80),            
           @c_SDESCR03         NVARCHAR(80),          
           @c_SDESCR04         NVARCHAR(80),          
           @c_SDESCR05         NVARCHAR(80),  
           @c_SDESCR06         NVARCHAR(80),  
           @c_SDESCR07         NVARCHAR(80),     
           @c_LOTT02_01        NVARCHAR(20),           
           @c_LOTT02_02        NVARCHAR(20),            
           @c_LOTT02_03        NVARCHAR(20),          
           @c_LOTT02_04        NVARCHAR(20),          
           @c_LOTT02_05        NVARCHAR(20),      
           @c_LOTT02_06        NVARCHAR(20),            
           @c_LOTT02_07        NVARCHAR(20),                
           @c_SKUQty01         NVARCHAR(10),          
           @c_SKUQty02         NVARCHAR(10),           
           @c_SKUQty03         NVARCHAR(10),           
           @c_SKUQty04         NVARCHAR(10),           
           @c_SKUQty05         NVARCHAR(10) ,  
           @c_SKUQty06         NVARCHAR(10) ,  
           @c_SKUQty07         NVARCHAR(10) ,  
           @n_TTLpage          INT,          
           @n_CurrentPage      INT,  
           @n_MaxLine          INT  ,  
           @c_Id               NVARCHAR(80) ,  
           @c_RDRECkey         NVARCHAR(20) ,  
           @n_skuqty           INT ,  
           @n_ttlqty           INT,  
           @n_ttlstdgwgt       FLOAT  

   --WL02 START
   DECLARE @c_LOTT01_01        NVARCHAR(18),           
           @c_LOTT01_02        NVARCHAR(18),            
           @c_LOTT01_03        NVARCHAR(18),          
           @c_LOTT01_04        NVARCHAR(18),          
           @c_LOTT01_05        NVARCHAR(18),      
           @c_LOTT01_06        NVARCHAR(18),            
           @c_LOTT01_07        NVARCHAR(18),
           @c_LOTT01           NVARCHAR(18)    
   --WL02 END
      
   SET @d_Trace_StartTime = GETDATE()    
   SET @c_Trace_ModuleName = ''    
        
    -- SET RowNo = 0               
   SET @c_SQL = ''       
   SET @n_CurrentPage = 1  
   SET @n_TTLpage =1       
   SET @n_MaxLine = 7    
   SET @n_CntRec = 1    
   SET @n_intFlag = 1          
          
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
    [PID]         [NVARCHAR] (30)  NULL,         
    [SKU]         [NVARCHAR] (20)  NULL,    
    [SDESCR]      [NVARCHAR] (80)  NULL,  
    [LOTT02]      [NVARCHAR] (20)  NULL,           
    [Qty]         INT ,   
    [StdGWGT]     FLOAT,  
    [Retrieve]    [NVARCHAR] (1) default 'N',
    [LOTT01]      [NVARCHAR] (20)  NULL)   --WL02
         
    SET @c_SQLJOIN = +' SELECT DISTINCT OH.c_company,OH.c_address1,OH.c_address2,OH.c_address3,OH.c_address4,'+ CHAR(13)      --5        
                     + ' OH.c_country,OH.externorderkey,OH.buyerpo,PD.ID,'''','     --10    
                     + ' '''','''','''','''','''','     --15    
                     + ' '''','''','''','''','''','     --20         
                     + CHAR(13) +        
                     + ' '''','''','''','''','''','''','''','''','''','''','  --30    
                     + ' '''','''','''','''','''','''','''','''','''',PD.loc,'   --40  --(WL01)        
                     + ' '''','''','''','''','''','''','''','''','''','''', '  --50         
                     + ' '''','''','''','''','''','''','''','''','''',''O'' '   --60            
                     + CHAR(13) +              
                     + ' FROM PICKDETAIL PD WITH (NOLOCK)'         
                     + ' JOIN ORDERS OH WITH (NOLOCK) ON OH.Orderkey = PD.Orderkey '    
                     + ' JOIN SKU S WITH (NOLOCK) ON S.Sku=PD.SKU AND S.Storerkey = PD.Storerkey'     
                     + ' JOIN PACK P WITH (NOLOCK) ON P.Packkey = S.Packkey '  
                     + ' WHERE PD.ID = @c_Sparm01'   
                     + ' GROUP BY OH.c_company,OH.c_address1,OH.c_address2,OH.c_address3,OH.c_address4, '  
                     + ' OH.c_country,OH.externorderkey,OH.buyerpo,PD.ID,p.casecnt,PD.loc '  
    
        
        
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
           --+ ', @c_Sparm02           NVARCHAR(80) '      
          --+ ', @c_Sparm03           NVARCHAR(80) '     
     
              
              
   EXEC sp_ExecuteSql    @c_SQL       
                       , @c_ExecArguments      
                       , @c_Sparm01      
         --, @c_Sparm02    
         --, @c_Sparm03   
       
         
   IF @b_debug=1          
   BEGIN            
      PRINT @c_SQL            
   END    
          
   IF @b_debug=1          
   BEGIN          
      SELECT * FROM #Result (nolock)          
   END          
       
       
   DECLARE CUR_RowNoLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   SELECT DISTINCT col09       
   FROM #Result                 
   WHERE Col60 = 'O'           
         
   OPEN CUR_RowNoLoop                    
          
   FETCH NEXT FROM CUR_RowNoLoop INTO @c_Id      
          
   WHILE @@FETCH_STATUS <> -1               
   BEGIN                   
      IF @b_debug='1'                
      BEGIN                
         PRINT @c_RDRECkey                   
      END   
        
      INSERT INTO [#TEMPSKU] (PID, SKU, SDESCR, LOTT02, Qty,stdgwgt,  
                              Retrieve, LOTT01)    --WL02
      SELECT DISTINCT PD.Id,PD.sku,substring(S.descr,1,80),LOTT.Lottable02,  
                      SUM(PD.Qty)/P.casecnt,sum(s.stdgrosswgt*(PD.qty/P.casecnt)),'N',
                      LOTT.Lottable01   --WL02  
      FROM PICKDETAIL AS PD WITH (NOLOCK)  
      JOIN SKU S WITH (NOLOCK) ON s.StorerKey=PD.StorerKey AND s.sku = PD.Sku   
      JOIN PACK P WITH (NOLOCK) ON P.Packkey = S.packkey  
      JOIN lotattribute LOTT WITH (NOLOCK) ON LOTT.Lot = PD.Lot  
      WHERE PD.id = @c_Id  
      GROUP BY PD.Id,PD.sku,substring(S.descr,1,80),LOTT.Lottable02,P.casecnt,LOTT.Lottable01   --WL02  
      ORDER BY PD.Id,PD.sku  
       
      SET @c_SKU01 = ''  
      SET @c_SKU02 = ''  
      SET @c_SKU03 = ''  
      SET @c_SKU04 = ''  
      SET @c_SKU05= ''  
      SET @c_SKU06= ''  
      SET @c_SKU07= ''  
      SET @c_SDESCR01 = ''  
      SET @c_SDESCR02 = ''  
      SET @c_SDESCR03 = ''  
      SET @c_SDESCR04 = ''  
      SET @c_SDESCR05= ''  
      SET @c_SDESCR06 = ''  
      SET @c_SDESCR07 = ''  
      SET @c_LOTT02_01 = ''  
      SET @c_LOTT02_02 = ''  
      SET @c_LOTT02_03 = ''  
      SET @c_LOTT02_04 = ''  
      SET @c_LOTT02_05 = ''  
      SET @c_LOTT02_06 = ''  
      SET @c_LOTT02_07 = ''  
      SET @c_SKUQty01 = ''  
      SET @c_SKUQty02 = ''  
      SET @c_SKUQty03 = ''  
      SET @c_SKUQty04 = ''  
      SET @c_SKUQty05 = ''  
      SET @c_SKUQty06 = ''  
      SET @c_SKUQty07 = ''  
      --WL02 START
      SET @c_LOTT01_01 = ''  
      SET @c_LOTT01_02 = ''  
      SET @c_LOTT01_03 = ''  
      SET @c_LOTT01_04 = ''  
      SET @c_LOTT01_05 = ''  
      SET @c_LOTT01_06 = ''  
      SET @c_LOTT01_07 = '' 
      --WL02 END
      
      SELECT @n_CntRec = COUNT (1)  
      FROM #TEMPSKU   
      WHERE pid = @c_Id  
      AND Retrieve = 'N'   
        
      SET @n_ttlqty =0  
      SET @n_ttlstdgwgt  =0  
        
      SELECT @n_ttlqty = SUM(Qty)  
            ,@n_ttlstdgwgt = SUM(stdgwgt)  
      FROM #TEMPSKU   
      WHERE pid = @c_Id  
          
      SET @n_TTLpage =  FLOOR(@n_CntRec / @n_MaxLine )  
          
        
      WHILE @n_intFlag <= @n_CntRec             
      BEGIN     
       
         SELECT @c_sku    = SKU,  
                @c_SDESCR = SDESCR,  
                @c_LOTT02 = LOTT02,  
                @n_skuqty = SUM(Qty),
                @c_LOTT01 = LOTT01   --WL02  
         FROM #TEMPSKU   
         WHERE ID = @n_intFlag  
         GROUP BY SKU,LOTT02, SDESCR,LOTT01   --WL02  
       
         IF (@n_intFlag%@n_MaxLine) = 1   
         BEGIN          
            SET @c_sku01     = @c_sku  
            SET @c_LOTT02_01 = @c_LOTT02  
            SET @c_SDESCR01  = @c_SDESCR  
            SET @c_SKUQty01  = CONVERT(NVARCHAR(10),@n_skuqty)  
            SET @c_LOTT01_01 = @c_LOTT01   --WL02   
         END          
        
         ELSE IF (@n_intFlag%@n_MaxLine) = 2  
         BEGIN          
            SET @c_sku02     = @c_sku  
            SET @c_LOTT02_02 = @c_LOTT02  
            SET @c_SDESCR02  = @c_SDESCR  
            SET @c_SKUQty02  = CONVERT(NVARCHAR(10),@n_skuqty)  
            SET @c_LOTT01_02 = @c_LOTT01   --WL02         
         END          
            
         ELSE IF (@n_intFlag%@n_MaxLine) = 3  
         BEGIN              
            SET @c_sku03     = @c_sku  
            SET @c_LOTT02_03 = @c_LOTT02  
            SET @c_SDESCR03  = @c_SDESCR  
            SET @c_SKUQty03  = CONVERT(NVARCHAR(10),@n_skuqty)    
            SET @c_LOTT01_03 = @c_LOTT01   --WL02      
         END          
            
         ELSE IF (@n_intFlag%@n_MaxLine) = 4  
         BEGIN          
            SET @c_sku04     = @c_sku  
            SET @c_LOTT02_04 = @c_LOTT02  
            SET @c_SDESCR04  = @c_SDESCR  
            SET @c_SKUQty04  = CONVERT(NVARCHAR(10),@n_skuqty)    
            SET @c_LOTT01_04 = @c_LOTT01   --WL02      
         END       
           
         ELSE IF (@n_intFlag%@n_MaxLine) = 5  
         BEGIN          
            SET @c_sku05     = @c_sku  
            SET @c_LOTT02_05 = @c_LOTT02  
            SET @c_SDESCR05  = @c_SDESCR  
            SET @c_SKUQty05  = CONVERT(NVARCHAR(10),@n_skuqty)    
            SET @c_LOTT01_05 = @c_LOTT01   --WL02      
         END     
           
         ELSE IF (@n_intFlag%@n_MaxLine) = 6  
         BEGIN          
            SET @c_sku06     = @c_sku  
            SET @c_LOTT02_06 = @c_LOTT02  
            SET @c_SDESCR06  = @c_SDESCR  
            SET @c_SKUQty06  = CONVERT(NVARCHAR(10),@n_skuqty)    
            SET @c_LOTT01_06 = @c_LOTT01   --WL02      
         END        
           
         ELSE IF (@n_intFlag%@n_MaxLine) = 0  
         BEGIN          
            SET @c_sku07     = @c_sku  
            SET @c_LOTT02_07 = @c_LOTT02  
            SET @c_SDESCR07  = @c_SDESCR  
            SET @c_SKUQty07  = CONVERT(NVARCHAR(10),@n_skuqty)  
            SET @c_LOTT01_07 = @c_LOTT01   --WL02        
         END           
           
         UPDATE #Result                    
         SET  Col10 = CAST(@n_ttlqty AS NVARCHAR(10)),   
              Col11 = CAST(@n_ttlstdgwgt AS NVARCHAR(10)),  
              Col12 = @c_sku01,  
              Col13 = @c_SDESCR01,  
              Col14 = @c_SKUQty01,  
              Col15 = @c_LOTT02_01,  
              Col16 = @c_sku02,  
              Col17 = @c_SDESCR02,  
              Col18 = @c_SKUQty02,  
              Col19 = @c_LOTT02_02,  
              Col20 = @c_sku03,    
              Col21 = @c_SDESCR03,    
              Col22 = @c_SKUQty03,    
              Col23 = @c_LOTT02_03,    
              Col24 = @c_sku04,    
              Col25 = @c_SDESCR04,    
              Col26 = @c_SKUQty04,    
              Col27 = @c_LOTT02_04,  
              Col28 = @c_sku05,    
              Col29 = @c_SDESCR05,    
              Col30 = @c_SKUQty05,   
              Col31 = @c_LOTT02_05,    
              Col32 = @c_sku06,    
              Col33 = @c_SDESCR06,    
              Col34 = @c_SKUQty06,    
              Col35 = @c_LOTT02_06,    
              Col36 = @c_sku07,    
              Col37 = @c_SDESCR07,    
              Col38 = @c_SKUQty07,  
              Col39 = @c_LOTT02_07,  
              --WL01 START   
              Col41 = @c_LOTT01_01,
              Col42 = @c_LOTT01_02,
              Col43 = @c_LOTT01_03,
              Col44 = @c_LOTT01_04,
              Col45 = @c_LOTT01_05,
              Col46 = @c_LOTT01_06,
              Col47 = @c_LOTT01_07      
              --WL01 END    
         WHERE ID = @n_CurrentPage    

         IF (@n_intFlag%@n_MaxLine) = 0 --AND (@n_CntRec - 1) <> 0  
         BEGIN  
            SET @n_CurrentPage = @n_CurrentPage + 1  
       
     
            INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09                   
                                ,Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22                 
                                ,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34                  
                                ,Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44                   
                                ,Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54                 
                                ,Col55,Col56,Col57,Col58,Col59,Col60)   
            SELECT TOP 1 Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09,'',                   
                '','','','','', '','','','','',                
                '','','','','', '','','','','',                
                '','','','','', '','','','',Col40,          --WL01          
                '','','','','', '','','','','',                 
                '','','','','', '','','','',''  
            FROM  #Result   
            WHERE Col60='O'  
            
            SET @c_SKU01 = ''  
            SET @c_SKU02 = ''  
            SET @c_SKU03 = ''  
            SET @c_SKU04 = ''  
            SET @c_SKU05= ''  
            SET @c_SKU06= ''  
            SET @c_SKU07= ''  
            SET @c_SDESCR01 = ''  
            SET @c_SDESCR02 = ''  
            SET @c_SDESCR03 = ''  
            SET @c_SDESCR04 = ''  
            SET @c_SDESCR05= ''  
            SET @c_SDESCR06 = ''  
            SET @c_SDESCR07 = ''  
            SET @c_LOTT02_01 = ''  
            SET @c_LOTT02_02 = ''  
            SET @c_LOTT02_03 = ''  
            SET @c_LOTT02_04 = ''  
            SET @c_LOTT02_05= ''  
            SET @c_LOTT02_06 = ''  
            SET @c_LOTT02_07 = ''  
            SET @c_SKUQty01 = ''  
            SET @c_SKUQty02 = ''  
            SET @c_SKUQty03 = ''  
            SET @c_SKUQty04 = ''  
            SET @c_SKUQty05 = ''  
            SET @c_SKUQty06 = ''  
            SET @c_SKUQty07 = ''    
            --WL02 START
            SET @c_LOTT01_01 = ''  
            SET @c_LOTT01_02 = ''  
            SET @c_LOTT01_03 = ''  
            SET @c_LOTT01_04 = ''  
            SET @c_LOTT01_05 = ''  
            SET @c_LOTT01_06 = ''  
            SET @c_LOTT01_07 = '' 
            --WL02 END                  
       
         END    
        
         SET @n_intFlag = @n_intFlag + 1     
      --SET @n_CntRec = @n_CntRec - 1      
      END      
       
      FETCH NEXT FROM CUR_RowNoLoop INTO  @c_Id            
         
   END -- While                     
   CLOSE CUR_RowNoLoop                    
   DEALLOCATE CUR_RowNoLoop     
         
   SELECT * FROM #Result (nolock)          
         
EXIT_SP:      
       
   SET @d_Trace_EndTime = GETDATE()    
   SET @c_UserName = SUSER_SNAME()    
        
   EXEC isp_InsertTraceInfo     
     @c_TraceCode = 'BARTENDER',    
     @c_TraceName = 'isp_BT_Bartender_OUTBPLTLBL_SG',    
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