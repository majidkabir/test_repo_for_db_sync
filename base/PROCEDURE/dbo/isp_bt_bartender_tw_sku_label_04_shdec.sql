SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/                 
/* Copyright: IDS                                                             */                 
/* Purpose: isp_BT_Bartender_TW_SKU_Label_04_SHDEC                            */                 
/*                                                                            */                 
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date       Rev  Author     Purposes                                        */                 
/* 2020-03-27 1.0  CSCHONG    Created (WMS-12560)                             */  
/******************************************************************************/                
                  
CREATE PROC [dbo].[isp_BT_Bartender_TW_SKU_Label_04_SHDEC]                      
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
      @c_skudescr        NVARCHAR(80),                    
      @n_intFlag         INT,     
      @n_CntRec          INT,    
      @c_SQL             NVARCHAR(4000),        
      @c_SQLSORT         NVARCHAR(4000),        
      @c_SQLJOIN         NVARCHAR(4000),
      @c_ExecStatements  NVARCHAR(4000),        
      @c_ExecArguments   NVARCHAR(4000)       
    
  DECLARE  @d_Trace_StartTime   DATETIME,   
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
           @c_SKUDESCR01       NVARCHAR(80),         
           @c_SKUDESCR02       NVARCHAR(20),          
           @c_SKUDESCR03       NVARCHAR(20),        
           @c_SKUDESCR04       NVARCHAR(20),        
           @c_SKUDESCR05       NVARCHAR(20),     
           @c_SKUQty01         NVARCHAR(10),        
           @c_SKUQty02         NVARCHAR(10),         
           @c_SKUQty03         NVARCHAR(10),         
           @c_SKUQty04         NVARCHAR(10),         
           @c_SKUQty05         NVARCHAR(10),
           @c_UOM              NVARCHAR(10),
           @c_UOM01            NVARCHAR(10),         
           @c_UOM02            NVARCHAR(10),          
           @c_UOM03            NVARCHAR(10),        
           @c_UOM04            NVARCHAR(10),        
           @c_UOM05            NVARCHAR(10),
           @n_casecnt          FLOAT,  
           @c_casecnt01        NVARCHAR(20),         
           @c_casecnt02        NVARCHAR(20),          
           @c_casecnt03        NVARCHAR(20),        
           @c_casecnt04        NVARCHAR(20),        
           @c_casecnt05        NVARCHAR(20),  
           @n_CtnQty           INT,
           @c_CtnQty01         NVARCHAR(10),        
           @c_CtnQty02         NVARCHAR(10),         
           @c_CtnQty03         NVARCHAR(10),         
           @c_CtnQty04         NVARCHAR(10),         
           @c_CtnQty05         NVARCHAR(10),
           @n_LQty             INT, 
           @c_LQty01           NVARCHAR(10),        
           @c_LQty02           NVARCHAR(10),         
           @c_LQty03           NVARCHAR(10),         
           @c_LQty04           NVARCHAR(10),         
           @c_LQty05           NVARCHAR(10),
           @c_LOTT02           NVARCHAR(18),
           @c_LOTT0201         NVARCHAR(18),        
           @c_LOTT0202         NVARCHAR(18),         
           @c_LOTT0203         NVARCHAR(18),         
           @c_LOTT0204         NVARCHAR(18),         
           @c_LOTT0205         NVARCHAR(18),
           @c_LOTT03           NVARCHAR(18),
           @c_LOTT0301         NVARCHAR(18),        
           @c_LOTT0302         NVARCHAR(18),         
           @c_LOTT0303         NVARCHAR(18),         
           @c_LOTT0304         NVARCHAR(18),         
           @c_LOTT0305         NVARCHAR(18),
           @c_LOTT04           NVARCHAR(10),
           @c_LOTT0401         NVARCHAR(10),        
           @c_LOTT0402         NVARCHAR(10),         
           @c_LOTT0403         NVARCHAR(10),         
           @c_LOTT0404         NVARCHAR(10),         
           @c_LOTT0405         NVARCHAR(10),
           @c_LOTT05           NVARCHAR(10),
           @c_LOTT0501         NVARCHAR(10),        
           @c_LOTT0502         NVARCHAR(10),         
           @c_LOTT0503         NVARCHAR(10),         
           @c_LOTT0504         NVARCHAR(10),         
           @c_LOTT0505         NVARCHAR(10),
           @n_TTLpage          INT,        
           @n_CurrentPage      INT,
           @n_MaxLine          INT  ,
           @c_TOId             NVARCHAR(80) ,
           @c_storerkey        NVARCHAR(20) ,
           @n_skuqty           INT 
  
   SET @d_Trace_StartTime = GETDATE()  
   SET @c_Trace_ModuleName = ''  
        
    -- SET RowNo = 0             
    SET @c_SQL = ''     
    SET @n_CurrentPage = 1
    SET @n_TTLpage =1     
    SET @n_MaxLine = 5    
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
     
     
      CREATE TABLE [#TEMPSKU04] (                   
      [ID]          [INT] IDENTITY(1,1) NOT NULL,        
      [ReceiptKey]  [NVARCHAR] (20) NULL,                                  
      [Storerkey]   [NVARCHAR] (20) NULL,  
      [Toid]        [NVARCHAR] (20) NULL,       
      [SKU]         [NVARCHAR] (20) NULL,           
      [Qty]         INT , 
      [skudescr]    [NVARCHAR] (80) NULL,
      [UOM]         [NVARCHAR] (10) NULL,
      [CASECNT]     FLOAT,
      [CntQty]      INT,
      [LQty]        INT,
      Lot02         [NVARCHAR] (18) NULL,
      Lot03         [NVARCHAR] (18) NULL,
      Lot04         [NVARCHAR] (10) NULL,
      Lot05         [NVARCHAR] (10) NULL,
      [Retrieve]    [NVARCHAR] (1) default 'N')         
           
  SET @c_SQLJOIN = +' SELECT DISTINCT REC.Storerkey,REC.Receiptkey,CONVERT(NVARCHAR(10),REC.receiptdate,111),'
             + ' MAX(RECDET.Toloc),RECDET.Toid,'+ CHAR(13)      --5      
             + ' '''','''','''','''','''','     --10  
             + ' '''','''','''','''','''','     --15  
             + ' '''','''','''','''','''','     --20       
             + CHAR(13) +      
             + ' '''','''','''','''','''','''','''','''','''','''','  --30  
             + ' '''','''','''','''','''','''','''','''','''','''','   --40       
             + ' '''','''','''','''','''','''','''','''','''','''', '  --50       
             + ' '''','''','''','''','''','''','''','''','''',''O'' '   --60          
             + CHAR(13) +            
             + ' FROM RECEIPT REC WITH (NOLOCK)'       
             + ' JOIN receiptdetail RECDET WITH (nolock)  ON RECDET.Receiptkey = REC.Receiptkey'   
             + ' JOIN SKU S WITH (NOLOCK) ON S.Sku=RECDET.SKU'   
             + ' JOIN PACK P WITH (NOLOCK) ON S.Packkey = P.PackKey'  
             + ' WHERE RECDET.Receiptkey = @c_Sparm01  AND'    
             + ' RECDET.Toid = @c_Sparm02 '   
             + ' GROUP BY CONVERT(NVARCHAR(10),REC.receiptdate,111),RECDET.Toid,REC.Receiptkey,REC.Storerkey '

          
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
   
    SET @c_ExecArguments = N'  @c_Sparm01         NVARCHAR(80)'    
                          + ' ,@c_Sparm02         NVARCHAR(80)'    
                                                                           
   EXEC sp_ExecuteSql     @c_SQL       
                        , @c_ExecArguments      
                        , @c_Sparm01  
                        , @c_Sparm02                           
        
   IF @b_debug=1        
   BEGIN          
      PRINT @c_SQL          
   END  
         
   IF @b_debug=1        
   BEGIN        
      SELECT * FROM #Result (nolock)        
   END        
  
  
  DECLARE CUR_RowNoLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
  SELECT DISTINCT col05,col02 ,col01     
   FROM #Result               
   WHERE Col60 = 'O'         
          
   OPEN CUR_RowNoLoop                  
             
   FETCH NEXT FROM CUR_RowNoLoop INTO @c_toid,@c_ReceiptKey,@c_storerkey    
               
   WHILE @@FETCH_STATUS <> -1             
   BEGIN                 
      IF @b_debug='1'              
      BEGIN              
         PRINT @c_toid                 
      END 
      
      
      INSERT INTO [#TEMPSKU04] (ReceiptKey,Storerkey,SKU,toid,Qty,skudescr,uom,CASECNT,CntQty,LQty,
                               Lot02,Lot03,Lot04,Lot05,Retrieve)
      SELECT DISTINCT RD.ReceiptKey,RD.StorerKey,RD.SKU,RD.ToId,SUM(RD.QtyReceived),s.descr,RD.uom,
     CASE WHEN ISNULL(p.casecnt,0) = 0 THEN 0 ELSE P.casecnt END,
     SUM(RD.QtyReceived/CAST(NULLIF(p.casecnt,0) as int) ), SUM(RD.QtyReceived%CAST(NULLIF(p.casecnt,0) as int) ),
     RD.lottable02,RD.lottable03,CONVERT(NVARCHAR(10),RD.lottable04,111),CONVERT(NVARCHAR(10),RD.lottable05,111),'N'
     FROM RECEIPTDETAIL AS RD WITH (NOLOCK) 
     JOIN SKU S WITH (NOLOCK) ON RD.storerkey = S.Storerkey AND RD.sku = S.sku
     JOIN PACK P WITH (NOLOCK) ON P.Packkey = S.packkey
     WHERE RD.Receiptkey =  @c_ReceiptKey
     AND RD.Toid = @c_toid
     AND RD.StorerKey = @c_storerkey  
     GROUP BY  RD.ReceiptKey,RD.StorerKey,RD.SKU,RD.ToId,s.descr,RD.uom,
     CASE WHEN ISNULL(p.casecnt,0) = 0 THEN 0 ELSE P.casecnt END, 
     RD.lottable02,RD.lottable03,CONVERT(NVARCHAR(10),RD.lottable04,111),CONVERT(NVARCHAR(10),RD.lottable05,111)
      
      SET @c_SKU01 = ''
      SET @c_SKU02 = ''
      SET @c_SKU03 = ''
      SET @c_SKU04 = ''
      SET @c_SKU05= ''
      SET @c_SKUDESCR01 = ''
      SET @c_SKUDESCR02 = ''
      SET @c_SKUDESCR03 = ''
      SET @c_SKUDESCR04 = ''
      SET @c_SKUDESCR05= ''
      SET @c_SKUQty01 = ''
      SET @c_SKUQty02 = ''
      SET @c_SKUQty03 = ''
      SET @c_SKUQty04 = ''
      SET @c_SKUQty05 = ''
      SET @c_UOM01    = ''        
      SET @c_UOM02    = ''
      SET @c_UOM03    = ''
      SET @c_UOM04   = ''
      SET @c_UOM05   = '' 
      SET @c_casecnt01  = ''       
      SET @c_casecnt02  = ''          
      SET @c_casecnt03  = ''      
      SET @c_casecnt04  = ''       
      SET @c_casecnt05  = ''
      SET @c_CtnQty01   = ''  
      SET @c_CtnQty02   = ''        
      SET @c_CtnQty03   = ''       
      SET @c_CtnQty04   = ''   
      SET @c_CtnQty05   = ''
      SET @c_LQty01     = ''   
      SET @c_LQty02     = ''   
      SET @c_LQty03     = '' 
      SET @c_LQty04     = ''      
      SET @c_LQty05     = ''
      SET @c_LOTT0201   = ''        
      SET @c_LOTT0202   = ''        
      SET @c_LOTT0203   = ''      
      SET @c_LOTT0204   = ''     
      SET @c_LOTT0205   = ''
      SET @c_LOTT0301   = ''       
      SET @c_LOTT0302   = ''       
      SET @c_LOTT0303   = ''     
      SET @c_LOTT0304   = ''       
      SET @c_LOTT0305   = ''
      SET @c_LOTT0401   = ''      
      SET @c_LOTT0402   = ''      
      SET @c_LOTT0403   = ''     
      SET @c_LOTT0404   = ''       
      SET @c_LOTT0405   = ''
      SET @c_LOTT0501   = ''      
      SET @c_LOTT0502   = ''     
      SET @c_LOTT0503   = ''        
      SET @c_LOTT0504   = ''         
      SET @c_LOTT0505   = ''
         
      SELECT @n_CntRec = COUNT (1)
      FROM #TEMPSKU04
      WHERE Receiptkey =  @c_ReceiptKey
      AND Toid = @c_toid
      AND StorerKey = @c_storerkey 
      AND Retrieve = 'N' 
      
      SET @n_TTLpage =  FLOOR(@n_CntRec / @n_MaxLine )
      
      
     WHILE @n_intFlag <= @n_CntRec           
     BEGIN   
      
      SELECT @c_sku = SKU,
             @c_skudescr = skudescr,
             @n_skuqty = SUM(Qty),
             @c_uom = UOM,
             @n_casecnt = CASECNT,
             @n_CtnQty = sum(cntqty),
             @n_Lqty = sum(lqty),
             @c_LOTT02 = Lot02,
             @c_LOTT03 = Lot03,
             @c_LOTT04 = lot04,
             @c_LOTT05 = lot05
      FROM #TEMPSKU04 
      WHERE ID = @n_intFlag
      GROUP BY SKU,uom,casecnt,lot02,lot03,lot04,lot05,skudescr
      
       IF (@n_intFlag%@n_MaxLine) = 1 
       BEGIN        
        SET @c_sku01 = @c_sku
        SET @c_SKUQty01 = CONVERT(NVARCHAR(10),@n_skuqty)  
        SET @c_SKUDESCR01 = @c_skudescr
        SET @c_UOM01 = @c_uom
        SET @c_casecnt01 = CAST(@n_casecnt as nvarchar(10))
        SET @c_CtnQty01 = CAST(@n_ctnqty as nvarchar(10))
        SET @c_lqty01 =  CAST(@n_lqty as nvarchar(10))    
        SET @c_LOTT0201 = @c_LOTT02
        SET @c_LOTT0301 = @c_LOTT03
        SET @c_LOTT0401 = @c_LOTT04
        SET @c_LOTT0501 = @c_LOTT05
       END        
       
       ELSE IF (@n_intFlag%@n_MaxLine) = 2
       BEGIN        
        SET @c_sku02 = @c_sku
        SET @c_SKUQty02 = CONVERT(NVARCHAR(10),@n_skuqty)
        SET @c_SKUDESCR02 = @c_skudescr
        SET @c_UOM02 = @c_uom
        SET @c_casecnt02 = CAST(@n_casecnt as nvarchar(10))
        SET @c_CtnQty02 = CAST(@n_ctnqty as nvarchar(10))
        SET @c_lqty02 =  CAST(@n_lqty as nvarchar(10))    
        SET @c_LOTT0202 = @c_LOTT02
        SET @c_LOTT0302 = @c_LOTT03
        SET @c_LOTT0402 = @c_LOTT04
        SET @c_LOTT0502 = @c_LOTT05        
       END        
        
       ELSE IF (@n_intFlag%@n_MaxLine) = 3
       BEGIN            
        SET @c_sku03 = @c_sku
        SET @c_SKUQty03 = CONVERT(NVARCHAR(10),@n_skuqty)  
        SET @c_SKUDESCR03 = @c_skudescr
        SET @c_UOM03 = @c_uom
        SET @c_casecnt03 = CAST(@n_casecnt as nvarchar(10))
        SET @c_CtnQty03 = CAST(@n_ctnqty as nvarchar(10))
        SET @c_lqty03 =  CAST(@n_lqty as nvarchar(10))    
        SET @c_LOTT0203 = @c_LOTT02
        SET @c_LOTT0303 = @c_LOTT03
        SET @c_LOTT0403 = @c_LOTT04
        SET @c_LOTT0503 = @c_LOTT05     
       END        
          
       ELSE IF (@n_intFlag%@n_MaxLine) = 4
       BEGIN        
        SET @c_sku04 = @c_sku
        SET @c_SKUQty04 = CONVERT(NVARCHAR(10),@n_skuqty)    
        SET @c_SKUDESCR04 = @c_skudescr
        SET @c_UOM04 = @c_uom
        SET @c_casecnt04 = CAST(@n_casecnt as nvarchar(10))
        SET @c_CtnQty04 = CAST(@n_ctnqty as nvarchar(10))
        SET @c_lqty04 =  CAST(@n_lqty as nvarchar(10))    
        SET @c_LOTT0204 = @c_LOTT02
        SET @c_LOTT0304 = @c_LOTT03
        SET @c_LOTT0404 = @c_LOTT04
        SET @c_LOTT0504 = @c_LOTT05   
       END        
      
       ELSE IF (@n_intFlag%@n_MaxLine) = 0
       BEGIN        
        SET @c_sku05 = @c_sku
        SET @c_SKUQty05 = CONVERT(NVARCHAR(10),@n_skuqty)    
        SET @c_SKUDESCR05 = @c_skudescr
        SET @c_UOM05 = @c_uom
        SET @c_casecnt05= CAST(@n_casecnt as nvarchar(10))
        SET @c_CtnQty05 = CAST(@n_ctnqty as nvarchar(10))
        SET @c_lqty05 =  CAST(@n_lqty as nvarchar(10))    
        SET @c_LOTT0205 = @c_LOTT02
        SET @c_LOTT0305 = @c_LOTT03
        SET @c_LOTT0405 = @c_LOTT04
        SET @c_LOTT0505 = @c_LOTT05   
       END 
         
         
       UPDATE #Result                  
       SET Col06 = @c_sku01,     
           Col07 = @c_SKUDESCR01,    
           Col08 = @c_SKUQty01, 
           Col09 = @c_uom01,
           Col10 = @c_casecnt01,
           Col11 = @c_ctnqty01,
           Col12 = @c_lqty01,
           Col13 = @c_LOTT0201,
           Col14 = @c_lott0301,
           Col15 = @c_lott0401,
           Col16 = @c_lott0501,        
           Col17 = @c_sku02,  
           Col18 = @c_SKUDESCR02,              
           Col19 = @c_SKUQty02,  
           Col20 = @c_uom02,
           Col21 = @c_casecnt02,
           Col22 = @c_ctnqty02,
           Col23 = @c_lqty02,
           Col24 = @c_LOTT0202,
           Col25 = @c_lott0302,
           Col26 = @c_lott0402,
           Col27 = @c_lott0502,            
           Col28 = @c_sku03,   
           Col29 = @c_SKUDESCR03,      
           Col30 = @c_SKUQty03,   
           Col31 = @c_uom03,
           Col32 = @c_casecnt03,
           Col33 = @c_ctnqty03,
           Col34 = @c_lqty03,
           Col35 = @c_LOTT0203,
           Col36 = @c_lott0303,
           Col37 = @c_lott0403,
           Col38 = @c_lott0503,          
           Col39 = @c_sku04,
           Col40 = @c_SKUDESCR04,        
           Col41 = @c_SKUQty04, 
           Col42 = @c_uom04,
           Col43 = @c_casecnt04,
           Col44 = @c_ctnqty04,
           Col45 = @c_lqty04,
           Col46 = @c_LOTT0204,
           Col47 = @c_lott0304,
           Col48 = @c_lott0404,
           Col49 = @c_lott0504,            
           Col50 = @c_sku05,   
           Col51 = @c_SKUDESCR05,     
           Col52 = @c_SKUQty05,
           Col53 = @c_uom05,
           Col54 = @c_casecnt05,
           Col55 = @c_ctnqty05,
           Col56 = @c_lqty05,
           Col57 = @c_LOTT0205,
           Col58 = @c_lott0305,
           Col59 = @c_lott0405,
           Col60 = @c_lott0505         
       WHERE ID = @n_CurrentPage  
       
       
    IF (@n_intFlag%@n_MaxLine) = 0 --AND (@n_CntRec - 1) <> 0
    BEGIN
      SET @n_CurrentPage = @n_CurrentPage + 1
      
      SET @c_SKU01 = ''
      SET @c_SKU02 = ''
      SET @c_SKU03 = ''
      SET @c_SKU04 = ''
      SET @c_SKU05= ''
      SET @c_SKUDESCR01 = ''
      SET @c_SKUDESCR02 = ''
      SET @c_SKUDESCR03 = ''
      SET @c_SKUDESCR04 = ''
      SET @c_SKUDESCR05= ''
      SET @c_SKUQty01 = ''
      SET @c_SKUQty02 = ''
      SET @c_SKUQty03 = ''
      SET @c_SKUQty04 = ''
      SET @c_SKUQty05 = ''
      SET @c_UOM01    = ''        
      SET @c_UOM02    = ''
      SET @c_UOM03    = ''
      SET @c_UOM04   = ''
      SET @c_UOM05   = '' 
      SET @c_casecnt01  = ''       
      SET @c_casecnt02  = ''          
      SET @c_casecnt03  = ''      
      SET @c_casecnt04  = ''       
      SET @c_casecnt05  = ''
      SET @c_CtnQty01   = ''  
      SET @c_CtnQty02   = ''        
      SET @c_CtnQty03   = ''       
      SET @c_CtnQty04   = ''   
      SET @c_CtnQty05   = ''
      SET @c_LQty01     = ''   
      SET @c_LQty02     = ''   
      SET @c_LQty03     = '' 
      SET @c_LQty04     = ''      
      SET @c_LQty05     = ''
      SET @c_LOTT0201   = ''        
      SET @c_LOTT0202   = ''        
      SET @c_LOTT0203   = ''      
      SET @c_LOTT0204   = ''     
      SET @c_LOTT0205   = ''
      SET @c_LOTT0301   = ''       
      SET @c_LOTT0302   = ''       
      SET @c_LOTT0303   = ''     
      SET @c_LOTT0304   = ''       
      SET @c_LOTT0305   = ''
      SET @c_LOTT0401   = ''      
      SET @c_LOTT0402   = ''      
      SET @c_LOTT0403   = ''     
      SET @c_LOTT0404   = ''       
      SET @c_LOTT0405   = ''
      SET @c_LOTT0501   = ''      
      SET @c_LOTT0502   = ''     
      SET @c_LOTT0503   = ''        
      SET @c_LOTT0504   = ''         
      SET @c_LOTT0505   = ''
      
      INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09                 
                            ,Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22               
                            ,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34                
                            ,Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44                 
                            ,Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54               
                            ,Col55,Col56,Col57,Col58,Col59,Col60) 
      SELECT TOP 1 Col01,Col02,Col03,Col04,Col05, '','','','','',                 
                   '','','','','', '','','','','',              
                   '','','','','', '','','','','',              
                   '','','','','', '','','','','',                 
                   '','','','','', '','','','','',               
                   '','','','','', '','','','',''
     FROM  #Result                    
      
    END  
       
    SET @n_intFlag = @n_intFlag + 1   
    --SET @n_CntRec = @n_CntRec - 1 

           
  END    
  
   FETCH NEXT FROM CUR_RowNoLoop INTO @c_toid,@c_ReceiptKey,@c_storerkey          
        
      END -- While                   
      CLOSE CUR_RowNoLoop                  
      DEALLOCATE CUR_RowNoLoop   
          
SELECT * FROM #Result (nolock)        
            
EXIT_SP:    
  
   SET @d_Trace_EndTime = GETDATE()  
   SET @c_UserName = SUSER_SNAME()  
     
   EXEC isp_InsertTraceInfo   
      @c_TraceCode = 'BARTENDER',  
      @c_TraceName = 'isp_BT_Bartender_TW_SKU_Label_04_SHDEC',  
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