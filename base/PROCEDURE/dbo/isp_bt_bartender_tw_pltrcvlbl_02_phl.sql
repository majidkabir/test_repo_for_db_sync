SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/********************************************************************************/                 
/* Copyright: LFL                                                               */                 
/* Purpose: isp_BT_Bartender_TW_PLTRCVLBL_02_PHL                                */                 
/*                                                                              */                 
/* Modifications log:                                                           */                 
/*                                                                              */                 
/* Date       Rev  Author     Purposes                                          */                 
/* 2019-08-28 1.0  WLChooi    Created (WMS-10361)                                */ 
/********************************************************************************/                
                  
CREATE PROC [dbo].[isp_BT_Bartender_TW_PLTRCVLBL_02_PHL]                      
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
   --SET ANSI_WARNINGS OFF                --(CS01)                 
                              
   DECLARE                  
      @c_ReceiptKey      NVARCHAR(10),                         
      @n_intFlag         INT,     
      @n_CntRec          INT,    
      @c_SQL             NVARCHAR(4000),        
      @c_SQLSORT         NVARCHAR(4000),        
      @c_SQLJOIN         NVARCHAR(4000),
      @c_ExecStatements  NVARCHAR(4000),       
      @c_ExecArguments   NVARCHAR(4000),   
      @c_SKU_1           NVARCHAR(80),  
      @c_Descr_1         NVARCHAR(80), 
      @c_Lott02_1        NVARCHAR(80),  
      @c_Lott04_1        NVARCHAR(80),
      @c_Lott05_1        NVARCHAR(80),
      @c_Qty_1           NVARCHAR(80),
      @c_UOM_1           NVARCHAR(80),
      @c_Casecnt_1       NVARCHAR(80),
      @c_QtyPerCase_1    NVARCHAR(80),
      @c_QtyPieces_1     NVARCHAR(80),
      @c_Lott01_1        NVARCHAR(80),
      @c_Lott03_1        NVARCHAR(80),
      @c_Lott06_1        NVARCHAR(80),

      @c_SKU_2           NVARCHAR(80), 
      @c_Descr_2         NVARCHAR(80), 
      @c_Lott02_2        NVARCHAR(80),  
      @c_Lott04_2        NVARCHAR(80),
      @c_Lott05_2        NVARCHAR(80),
      @c_Qty_2           NVARCHAR(80),
      @c_UOM_2           NVARCHAR(80),
      @c_Casecnt_2       NVARCHAR(80),
      @c_QtyPerCase_2    NVARCHAR(80),
      @c_QtyPieces_2     NVARCHAR(80),
      @c_Lott01_2        NVARCHAR(80),
      @c_Lott03_2        NVARCHAR(80),
      @c_Lott06_2        NVARCHAR(80),

      @c_SKU             NVARCHAR(80),
      @c_Descr           NVARCHAR(80),
      @c_Lott02          NVARCHAR(80),
      @c_Lott04          NVARCHAR(80),
      @c_Lott05          NVARCHAR(80),
      @c_Qty             NVARCHAR(80),
      @c_UOM             NVARCHAR(80),
      @c_Casecnt         NVARCHAR(80),
      @c_QtyPerCase      NVARCHAR(80),
      @c_QtyPieces       NVARCHAR(80),
      @c_Lott01          NVARCHAR(80),
      @c_Lott03          NVARCHAR(80),
      @c_Lott06          NVARCHAR(80),
      
      @c_GetReceiptKey   NVARCHAR(10),
      
      @n_TTLpage         INT,          
      @n_CurrentPage     INT,  
      @n_MaxLine         INT          
    
  DECLARE  @d_Trace_StartTime   DATETIME,   
           @d_Trace_EndTime    DATETIME,  
           @c_Trace_ModuleName NVARCHAR(20),   
           @d_Trace_Step1      DATETIME,   
           @c_Trace_Step1      NVARCHAR(20),  
           @c_UserName         NVARCHAR(20)     
  
       SET @d_Trace_StartTime = GETDATE()  
       SET @c_Trace_ModuleName = '' 
       
       SET @n_CurrentPage = 1  
       SET @n_TTLpage =1       
       SET @n_MaxLine = 2      
       SET @n_CntRec = 1    
       SET @n_intFlag = 1  
        
    -- SET RowNo = 0             
       SET @c_SQL = ''                
              
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
                
      CREATE TABLE #Temp_RECEIPT (
       [ID]         [INT] IDENTITY(1,1) NOT NULL,                                        
       [SKU]        [NVARCHAR] (80) NULL,
       [Descr]      [NVARCHAR] (80) NULL,
       [Lott02]     [NVARCHAR] (80) NULL,
       [Lott04]     [NVARCHAR] (80) NULL,
       [Lott05]     [NVARCHAR] (80) NULL,
       [Qty]        [NVARCHAR] (80) NULL,
       [UOM]        [NVARCHAR] (80) NULL,
       [Casecnt]    [NVARCHAR] (80) NULL,
       [QtyPerCase] [NVARCHAR] (80) NULL,
       [QtyPieces]  [NVARCHAR] (80) NULL,
       [Lott01]     [NVARCHAR] (80) NULL,
       [Lott03]     [NVARCHAR] (80) NULL,
       [Lott06]     [NVARCHAR] (80) NULL
      )         
            
      SET @c_SQLJOIN = + ' SELECT DISTINCT RECDET.Storerkey, RECDET.Receiptkey, RECDET.ToId, '''', '''', ' + CHAR(13)   --5  
                       + ' '''','''','''','''','''', ' + CHAR(13) --10 
                       + ' '''','''','''','''','''','''','''','''','''','''','  + CHAR(13) --20       
                       + ' '''','''','''','''','''','''','''','''','''','''','  + CHAR(13) --30  
                       + ' '''','''','''','''','''','''','''','''','''','''','  + CHAR(13) --40       
                       + ' '''','''','''','''','''','''','''','''','''','''', ' + CHAR(13) --50       
                       + ' '''','''','''','''','''','''','''','''',REC.Receiptkey,''TW'' '  --60          
                       + CHAR(13) +            
                       + ' FROM RECEIPT REC WITH (NOLOCK)'        + CHAR(13)
                       + ' JOIN RECEIPTDETAIL RECDET WITH (nolock) ON RECDET.receiptkey=REC.Receiptkey'   + CHAR(13)
                       + ' JOIN SKU S WITH (NOLOCK) ON S.Sku=RECDET.SKU AND S.storerkey=RECDET.Storerkey' + CHAR(13)  
                       + ' JOIN PACK P WITH (NOLOCK) ON S.Packkey = P.PackKey'   + CHAR(13)
                       + ' WHERE REC.Receiptkey = @c_Sparm01 AND '   + CHAR(13)  
                       + ' RECDET.Toid = CASE WHEN ISNULL(RTRIM(@c_Sparm02),'''') <> '''' THEN @c_Sparm02 ELSE RECDET.Toid END'   
--PRINT @c_SQLJOIN
          
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

      SET @c_ExecArguments =    N'  @c_Sparm01         NVARCHAR(80)'    
                               + ', @c_Sparm02         NVARCHAR(80) '     

                         
                         
      EXEC sp_ExecuteSql     @c_SQL     
                           , @c_ExecArguments    
                           , @c_Sparm01    
                           , @c_Sparm02  
        
      IF @b_debug=1        
      BEGIN          
         PRINT @c_SQL          
      END              

      INSERT INTO #Temp_RECEIPT
      SELECT RECDET.SKU, S.DESCR, RECDET.Lottable02, CONVERT(NVARCHAR(10),ISNULL(RECDET.Lottable04,'1900/01/01'),120),
             CONVERT(NVARCHAR(10),ISNULL(RECDET.Lottable05,'1900/01/01'),120),                                                                                                                                                                       --                                                                                                  --  
             CASE WHEN RECDET.FinalizeFlag = 'Y' THEN CAST(SUM(RECDET.QtyReceived) AS NVARCHAR(80)) 
                                                 ELSE CAST(SUM(RECDET.BeforeReceivedQty) AS NVARCHAR(80)) END, 
             RECDET.UOM, P.Casecnt,
             CASE WHEN RECDET.FinalizeFlag = 'Y' THEN CAST(FLOOR(SUM(RECDET.Qtyreceived) / P.Casecnt) AS NVARCHAR(80)) 
                                                 ELSE CAST(FLOOR(SUM(RECDET.BeforeReceivedQty) / P.Casecnt) AS NVARCHAR(80)) END, 
             CASE WHEN RECDET.FinalizeFlag = 'Y' THEN CAST((SUM(RECDET.Qtyreceived) % CAST(P.Casecnt as INT)) AS NVARCHAR(80)) 
                                                 ELSE CAST((SUM(RECDET.BeforeReceivedQty) % CAST(P.Casecnt as INT)) AS NVARCHAR(80)) END,
             ISNULL(RECDET.Lottable01,''), ISNULL(RECDET.Lottable03,''), ISNULL(RECDET.Lottable06,'')
      FROM RECEIPT REC WITH (NOLOCK)      
      JOIN RECEIPTDETAIL RECDET WITH (nolock) ON RECDET.receiptkey = REC.Receiptkey   
      JOIN SKU S WITH (NOLOCK) ON S.Sku = RECDET.SKU AND S.storerkey = RECDET.Storerkey   
      JOIN PACK P WITH (NOLOCK) ON S.Packkey = P.PackKey  
      WHERE REC.Receiptkey = @c_Sparm01   
      AND RECDET.Toid = CASE WHEN ISNULL(RTRIM(@c_Sparm02),'') <> '' THEN @c_Sparm02 ELSE RECDET.Toid END 
      GROUP BY RECDET.SKU, S.DESCR, RECDET.Lottable02, CONVERT(NVARCHAR(10),ISNULL(RECDET.Lottable04,'1900/01/01'),120),
               CONVERT(NVARCHAR(10),ISNULL(RECDET.Lottable05,'1900/01/01'),120), RECDET.FinalizeFlag,
               RECDET.UOM, P.Casecnt, ISNULL(RECDET.Lottable01,''), ISNULL(RECDET.Lottable03,''), ISNULL(RECDET.Lottable06,'')

      IF @b_debug = 1
         SELECT * FROM #Temp_RECEIPT

      SELECT @n_CntRec = COUNT (1)  
      FROM #Temp_RECEIPT

      SET @n_TTLpage =  FLOOR(@n_CntRec / @n_MaxLine ) + CASE WHEN @n_CntRec % @n_MaxLine > 0 THEN 1 ELSE 0 END   
      
      WHILE @n_intFlag <= @n_CntRec             
      BEGIN
         IF @n_intFlag > @n_MaxLine AND (@n_intFlag % @n_MaxLine) = 1
         BEGIN 
            SET @n_CurrentPage = @n_CurrentPage + 1

            IF (@n_CurrentPage > @n_TTLpage)   
            BEGIN  
               BREAK;  
            END
            
            INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09                   
           ,Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22                 
           ,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34                  
           ,Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44                   
           ,Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54                 
           ,Col55,Col56,Col57,Col58,Col59,Col60)   
           SELECT TOP 1 Col01,Col02,Col03,'','','','','','','',       
                        '','','','','', '','','','','',
                        '','','','','', '','','','','',                
                        '','','','','', '','','','','',                   
                        '','','','','', '','','','','',                 
                        '','','','','', '','','',Col59,Col60 
            FROM #Result

            SET @c_SKU_1         = ''
            SET @c_Descr_1       = ''
            SET @c_Lott02_1      = ''
            SET @c_Lott04_1      = ''
            SET @c_Lott05_1      = ''
            SET @c_Qty_1         = ''
            SET @c_UOM_1         = ''
            SET @c_Casecnt_1     = ''
            SET @c_QtyPerCase_1  = ''
            SET @c_QtyPieces_1   = ''
            SET @c_Lott01_1      = ''
            SET @c_Lott03_1      = ''
            SET @c_Lott06_1      = ''

            SET @c_SKU_2         = ''
            SET @c_Descr_2       = ''
            SET @c_Lott02_2      = ''
            SET @c_Lott04_2      = ''
            SET @c_Lott05_2      = ''
            SET @c_Qty_2         = ''
            SET @c_UOM_2         = ''
            SET @c_Casecnt_2     = ''
            SET @c_QtyPerCase_2  = ''
            SET @c_QtyPieces_2   = ''
            SET @c_Lott01_2      = ''
            SET @c_Lott03_2      = ''
            SET @c_Lott06_2      = ''
         END

         SELECT   @c_SKU        = SKU    
                , @c_Descr      = Descr   
                , @c_Lott02     = Lott02    
                , @c_Lott04     = Lott04   
                , @c_Lott05     = Lott05    
                , @c_Qty        = Qty       
                , @c_UOM        = UOM       
                , @c_Casecnt    = Casecnt   
                , @c_QtyPerCase = QtyPerCase
                , @c_QtyPieces  = QtyPieces
                , @c_Lott01     = Lott01
                , @c_Lott03     = Lott03
                , @c_Lott06     = Lott06
          FROM #TEMP_RECEIPT 
          WHERE ID = @n_intFlag

          IF (@n_intFlag % @n_MaxLine) = 1 --AND @n_recgrp = @n_CurrentPage  
          BEGIN 
             SET @c_SKU_1        = @c_SKU       
             SET @c_Descr_1      = @c_Descr     
             SET @c_Lott02_1     = @c_Lott02    
             SET @c_Lott04_1     = @c_Lott04    
             SET @c_Lott05_1     = @c_Lott05    
             SET @c_Qty_1        = @c_Qty       
             SET @c_UOM_1        = @c_UOM       
             SET @c_Casecnt_1    = @c_Casecnt   
             SET @c_QtyPerCase_1 = @c_QtyPerCase
             SET @c_QtyPieces_1  = @c_QtyPieces  
             SET @c_Lott01_1     = @c_Lott01   
             SET @c_Lott03_1     = @c_Lott03 
             SET @c_Lott06_1     = @c_Lott06     
          END   
          ELSE IF (@n_intFlag % @n_MaxLine) = 0 --AND @n_recgrp = @n_CurrentPage  
          BEGIN   
             SET @c_SKU_2        = @c_SKU       
             SET @c_Descr_2      = @c_Descr     
             SET @c_Lott02_2     = @c_Lott02    
             SET @c_Lott04_2     = @c_Lott04    
             SET @c_Lott05_2     = @c_Lott05    
             SET @c_Qty_2        = @c_Qty       
             SET @c_UOM_2        = @c_UOM       
             SET @c_Casecnt_2    = @c_Casecnt   
             SET @c_QtyPerCase_2 = @c_QtyPerCase
             SET @c_QtyPieces_2  = @c_QtyPieces  
             SET @c_Lott01_2     = @c_Lott01      
             SET @c_Lott03_2     = @c_Lott03 
             SET @c_Lott06_2     = @c_Lott06  
          END      

          UPDATE #Result
          SET   Col04 = @c_SKU_1        
              , Col05 = @c_Descr_1     
              , Col06 = @c_Lott02_1    
              , Col07 = @c_Lott04_1    
              , Col08 = @c_Lott05_1    
              , Col09 = @c_Qty_1       
              , Col10 = @c_UOM_1       
              , Col11 = @c_Casecnt_1   
              , Col12 = @c_QtyPerCase_1
              , Col13 = @c_QtyPieces_1 
              , Col14 = @c_SKU_2       
              , Col15 = @c_Descr_2     
              , Col16 = @c_Lott02_2    
              , Col17 = @c_Lott04_2    
              , Col18 = @c_Lott05_2    
              , Col19 = @c_Qty_2       
              , Col20 = @c_UOM_2       
              , Col21 = @c_Casecnt_2   
              , Col22 = @c_QtyPerCase_2
              , Col23 = @c_QtyPieces_2 
              , Col24 = @c_Lott01_1 
              , Col25 = @c_Lott01_2 
              , Col26 = @c_Lott03_1 
              , Col27 = @c_Lott03_2 
              , Col28 = @c_Lott06_1 
              , Col29 = @c_Lott06_2 
         WHERE ID = @n_CurrentPage

         SET @n_intFlag = @n_intFlag + 1
         
         IF @n_intFlag > @n_CntRec  
         BEGIN  
            BREAK;  
         END  
      END

      --SELECT * FROM #Temp_RECEIPT
      SELECT * FROM #Result (nolock)        
            
EXIT_SP:    
  
      SET @d_Trace_EndTime = GETDATE()  
      SET @c_UserName = SUSER_SNAME()  
      
   --EXEC isp_InsertTraceInfo   
   --   @c_TraceCode = 'BARTENDER',  
   --   @c_TraceName = 'isp_BT_Bartender_TW_PLTRCVLBL_02_PHL',  
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