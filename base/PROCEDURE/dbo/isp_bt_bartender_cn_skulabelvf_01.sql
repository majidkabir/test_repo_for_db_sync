SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/********************************************************************************/                   
/* Copyright: LFL                                                               */                   
/* Purpose: isp_BT_Bartender_CN_SKULABELVF_01                                   */                   
/*                                                                              */                   
/* Modifications log:                                                           */                   
/*                                                                              */                   
/* Date        Rev  Author     Purposes                                         */                   
/* 30-Aug-2022 1.0  WLChooi    Created (WMS-20651)                              */  
/* 30-Aug-2022 1.0  WLChooi    DevOps Combine Script                            */  
/********************************************************************************/                  
                    
CREATE PROC [dbo].[isp_BT_Bartender_CN_SKULABELVF_01]                        
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
   --SET ANSI_WARNINGS OFF                
                                
   DECLARE                    
      @n_intFlag         INT,       
      @n_CntRec          INT,      
      @c_SQL             NVARCHAR(4000),          
      @c_SQLSORT         NVARCHAR(4000),          
      @c_SQLJOIN         NVARCHAR(4000),  
      @c_ExecStatements  NVARCHAR(4000),         
      @c_ExecArguments   NVARCHAR(4000),  
      @c_RowID01         NVARCHAR(80),
      @c_SKU01           NVARCHAR(80),    
      @c_Qty01           NVARCHAR(80), 
      @c_RowID02         NVARCHAR(80),
      @c_SKU02           NVARCHAR(80),    
      @c_Qty02           NVARCHAR(80), 
      @c_RowID03         NVARCHAR(80),
      @c_SKU03           NVARCHAR(80),     
      @c_Qty03           NVARCHAR(80),  
      @c_RowID04         NVARCHAR(80),
      @c_SKU04           NVARCHAR(80),     
      @c_Qty04           NVARCHAR(80), 
      @c_RowID05         NVARCHAR(80),
      @c_SKU05           NVARCHAR(80),    
      @c_Qty05           NVARCHAR(80), 
      @c_RowID06         NVARCHAR(80),
      @c_SKU06           NVARCHAR(80),    
      @c_Qty06           NVARCHAR(80), 
      @c_RowID07         NVARCHAR(80),
      @c_SKU07           NVARCHAR(80),    
      @c_Qty07           NVARCHAR(80), 
      @c_RowID08         NVARCHAR(80),
      @c_SKU08           NVARCHAR(80),    
      @c_Qty08           NVARCHAR(80), 
      @c_RowID09         NVARCHAR(80),
      @c_SKU09           NVARCHAR(80),    
      @c_Qty09           NVARCHAR(80), 
      @c_RowID10         NVARCHAR(80),
      @c_SKU10           NVARCHAR(80),    
      @c_Qty10           NVARCHAR(80), 
      @c_RowID11         NVARCHAR(80),
      @c_SKU11           NVARCHAR(80),    
      @c_Qty11           NVARCHAR(80), 
      @c_RowID12         NVARCHAR(80),
      @c_SKU12           NVARCHAR(80),    
      @c_Qty12           NVARCHAR(80), 
      @c_RowID13         NVARCHAR(80),
      @c_SKU13           NVARCHAR(80),    
      @c_Qty13           NVARCHAR(80), 
      @c_RowID14         NVARCHAR(80),
      @c_SKU14           NVARCHAR(80),    
      @c_Qty14           NVARCHAR(80),
      @c_RowID15         NVARCHAR(80),
      @c_SKU15           NVARCHAR(80),    
      @c_Qty15           NVARCHAR(80), 
      @c_RowID           NVARCHAR(80),
      @c_SKU             NVARCHAR(80),  
      @c_Qty             NVARCHAR(80),  
      @c_ToID            NVARCHAR(30),
        
      @n_QtyReceived     INT, 
      @n_TTLpage         INT,            
      @n_CurrentPage     INT,    
      @n_MaxLine         INT,  
      @c_Sorting         NVARCHAR(4000),  
      @c_ExtraSQL        NVARCHAR(4000),  
      @c_JoinStatement   NVARCHAR(4000)
      
  DECLARE  @d_Trace_StartTime  DATETIME,     
           @d_Trace_EndTime    DATETIME,    
           @c_Trace_ModuleName NVARCHAR(20),     
           @d_Trace_Step1      DATETIME,     
           @c_Trace_Step1      NVARCHAR(20),    
           @c_UserName         NVARCHAR(20),
           @c_EditWho          NVARCHAR(20),
           @c_EditDate         NVARCHAR(16)
    
   SET @d_Trace_StartTime = GETDATE()    
   SET @c_Trace_ModuleName = ''   
     
   SET @n_CurrentPage = 1    
   SET @n_TTLpage = 1         
   SET @n_MaxLine = 15        
   SET @n_CntRec = 1      
   SET @n_intFlag = 1    
   SET @c_ExtraSQL = ''  
   SET @c_JoinStatement = ''          
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
        
   CREATE TABLE #Temp_Packdetail (  
       [ID]              [INT] IDENTITY(1,1) NOT NULL,         
       [ToId]            [NVARCHAR] (80) NULL,                            
       [SKU]             [NVARCHAR] (80) NULL,  
       [Qty]             [NVARCHAR] (80) NULL,  
       [Retreive]        [NVARCHAR] (80) NULL  
   )           
   
   ;WITH CTE AS (SELECT DISTINCT ReceiptKey
                 FROM RECEIPTDETAIL (NOLOCK)
                 WHERE ToID = @c_Sparm01
                 AND Storerkey = CASE WHEN ISNULL(@c_Sparm02,'') = '' THEN Storerkey ELSE @c_Sparm02 END)
   SELECT @n_QtyReceived = SUM(RD.QtyReceived)
   FROM RECEIPTDETAIL RD (NOLOCK)
   JOIN CTE ON CTE.ReceiptKey = RD.ReceiptKey

   ;WITH CTE AS (SELECT DISTINCT ReceiptKey
                 FROM RECEIPTDETAIL (NOLOCK)
                 WHERE ToID = @c_Sparm01
                 AND Storerkey = CASE WHEN ISNULL(@c_Sparm02,'') = '' THEN Storerkey ELSE @c_Sparm02 END)
   SELECT @c_EditWho = MAX(R.EditWho)
        , @c_EditDate = REPLACE(CONVERT(NVARCHAR(16), MAX(R.EditDate), 120), '-', '/')
   FROM RECEIPT R (NOLOCK)
   JOIN CTE ON CTE.ReceiptKey = R.ReceiptKey

   SET @c_SQLJOIN = + ' SELECT DISTINCT RD.ToID, CASE WHEN R.Userdefine10 = ''VC30'' THEN ''TNF'' '
                    + '                               WHEN R.Userdefine10 = ''VC40'' THEN ''VANS'' '
                    + '                               WHEN R.Userdefine10 = ''VC80'' THEN ''TBL'' '
                    + '                               WHEN R.Userdefine10 = ''VCD0'' THEN ''DKS'' '
                    + '                               ELSE ''IB'' END, '
                    + ' R.ReceiptGroup, '''', '''', '''', '''', '''', '''', '''', ' + CHAR(13) --10
                    + ' '''', '''', '''', '''', '''', ' + CHAR(13) --15
                    + ' '''', '''', '''', '''', '''', '  + CHAR(13) --20         
                    + ' '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', '  + CHAR(13) --30     
                    + ' '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', '  + CHAR(13) --40  
                    + ' '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', '  + CHAR(13) --50        
                    + ' '''', '''', '''', '''', '''', '''', '''', '''', RD.ToID, ''CN'' ' + CHAR(13) --60
                    + ' FROM RECEIPTDETAIL RD (NOLOCK) ' + CHAR(13)
                    + ' JOIN RECEIPT R (NOLOCK) ON R.Receiptkey = RD.Receiptkey ' + CHAR(13)
                    + ' WHERE RD.ToID = @c_Sparm01 ' + CHAR(13)
                    + ' AND RD.Storerkey = CASE WHEN ISNULL(@c_Sparm02,'''') = '''' THEN RD.Storerkey ELSE @c_Sparm02 END '
                
   SET @c_SQL='INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09'  + CHAR(13) +             
             +',Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22'  + CHAR(13) +             
             +',Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34' + CHAR(13) +             
             +',Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44'  + CHAR(13) +             
             +',Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54'+ CHAR(13) +             
             +',Col55,Col56,Col57,Col58,Col59,Col60) '    

   SET @c_SQL = @c_SQL + @c_SQLJOIN           

   SET @c_ExecArguments = N'  @c_Sparm01         NVARCHAR(80) '      
                        +  ', @c_Sparm02         NVARCHAR(80) '       
                        +  ', @c_Sparm03         NVARCHAR(80) '  
                        +  ', @c_Sparm04         NVARCHAR(80) '  
                        +  ', @c_Sparm05         NVARCHAR(80) '  
            
   EXEC sp_ExecuteSql @c_SQL       
                    , @c_ExecArguments      
                    , @c_Sparm01      
                    , @c_Sparm02    
                    , @c_Sparm03  
                    , @c_Sparm04
                    , @c_Sparm05

   DECLARE CUR_RowNoLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   SELECT DISTINCT Col01   
   FROM #Result   
   ORDER BY Col01
   
   OPEN CUR_RowNoLoop     
     
   FETCH NEXT FROM CUR_RowNoLoop INTO @c_ToID 
   
   WHILE @@FETCH_STATUS <> -1   
   BEGIN  
      INSERT INTO #Temp_Packdetail  
      SELECT @c_ToID, RD.SKU, SUM(RD.QtyReceived), 'N'  
      FROM RECEIPTDETAIL RD WITH (NOLOCK)  
      WHERE RD.ToId = @c_ToID   
      AND RD.StorerKey = CASE WHEN ISNULL(@c_Sparm02,'') = '' THEN RD.StorerKey ELSE @c_Sparm02 END
      GROUP BY RD.SKU
      ORDER BY RD.SKU

      SET @c_RowID01 = ''
      SET @c_SKU01   = ''
      SET @c_Qty01   = ''
      SET @c_RowID02 = ''
      SET @c_SKU02   = ''
      SET @c_Qty02   = ''
      SET @c_RowID03 = ''
      SET @c_SKU03   = ''
      SET @c_Qty03   = ''
      SET @c_RowID04 = ''
      SET @c_SKU04   = ''
      SET @c_Qty04   = ''
      SET @c_RowID05 = ''
      SET @c_SKU05   = ''
      SET @c_Qty05   = ''
      SET @c_RowID06 = ''
      SET @c_SKU06   = ''
      SET @c_Qty06   = ''
      SET @c_RowID07 = ''
      SET @c_SKU07   = ''
      SET @c_Qty07   = ''
      SET @c_RowID08 = ''
      SET @c_SKU08   = ''
      SET @c_Qty08   = ''
      SET @c_RowID09 = ''
      SET @c_SKU09   = ''
      SET @c_Qty09   = ''
      SET @c_RowID10 = ''
      SET @c_SKU10   = ''
      SET @c_Qty10   = ''
      SET @c_RowID11 = ''
      SET @c_SKU11   = ''
      SET @c_Qty11   = ''
      SET @c_RowID12 = ''
      SET @c_SKU12   = ''
      SET @c_Qty12   = ''
      SET @c_RowID13 = ''
      SET @c_SKU13   = ''
      SET @c_Qty13   = ''
      SET @c_RowID14 = ''
      SET @c_SKU14   = ''
      SET @c_Qty14   = ''
      SET @c_RowID15 = ''
      SET @c_SKU15   = ''
      SET @c_Qty15   = ''

      IF @b_debug = 1  
         SELECT * FROM #Temp_Packdetail  
   
      SELECT @n_CntRec = COUNT (1)    
      FROM #Temp_Packdetail  
      WHERE ToID = @c_ToID  
      AND Retreive = 'N'  
   
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
                        '','','','','','','','','','',  
                        '','','','','','','','','','',                  
                        '','','','','','','','','','',
                        '','','','','','','','','',Col50,                   
                        Col51,'','','','','','','',Col59,Col60   
            FROM #Result   
   
            SET @c_RowID01 = ''
            SET @c_SKU01   = ''
            SET @c_Qty01   = ''
            SET @c_RowID02 = ''
            SET @c_SKU02   = ''
            SET @c_Qty02   = ''
            SET @c_RowID03 = ''
            SET @c_SKU03   = ''
            SET @c_Qty03   = ''
            SET @c_RowID04 = ''
            SET @c_SKU04   = ''
            SET @c_Qty04   = ''
            SET @c_RowID05 = ''
            SET @c_SKU05   = ''
            SET @c_Qty05   = ''
            SET @c_RowID06 = ''
            SET @c_SKU06   = ''
            SET @c_Qty06   = ''
            SET @c_RowID07 = ''
            SET @c_SKU07   = ''
            SET @c_Qty07   = ''
            SET @c_RowID08 = ''
            SET @c_SKU08   = ''
            SET @c_Qty08   = ''
            SET @c_RowID09 = ''
            SET @c_SKU09   = ''
            SET @c_Qty09   = ''
            SET @c_RowID10 = ''
            SET @c_SKU10   = ''
            SET @c_Qty10   = ''
            SET @c_RowID11 = ''
            SET @c_SKU11   = ''
            SET @c_Qty11   = ''
            SET @c_RowID12 = ''
            SET @c_SKU12   = ''
            SET @c_Qty12   = ''
            SET @c_RowID13 = ''
            SET @c_SKU13   = ''
            SET @c_Qty13   = ''
            SET @c_RowID14 = ''
            SET @c_SKU14   = ''
            SET @c_Qty14   = ''
            SET @c_RowID15 = ''
            SET @c_SKU15   = ''
            SET @c_Qty15   = ''
         END  
   
         SELECT @c_RowID   = ID
              , @c_SKU     = SKU        
              , @c_Qty     = Qty  
         FROM #Temp_Packdetail   
         WHERE ID = @n_intFlag  
   
         IF (@n_intFlag % @n_MaxLine) = 1
         BEGIN   
            SET @c_RowID01    = @c_RowID
            SET @c_SKU01      = @c_SKU        
            SET @c_Qty01      = @c_Qty  
         END     
         ELSE IF (@n_intFlag % @n_MaxLine) = 2  
         BEGIN     
            SET @c_RowID02    = @c_RowID
            SET @c_SKU02      = @c_SKU        
            SET @c_Qty02      = @c_Qty        
         END    
         ELSE IF (@n_intFlag % @n_MaxLine) = 3  
         BEGIN     
            SET @c_RowID03    = @c_RowID
            SET @c_SKU03      = @c_SKU        
            SET @c_Qty03      = @c_Qty      
         END   
         ELSE IF (@n_intFlag % @n_MaxLine) = 4  
         BEGIN  
            SET @c_RowID04    = @c_RowID
            SET @c_SKU04      = @c_SKU        
            SET @c_Qty04      = @c_Qty        
         END   
         ELSE IF (@n_intFlag % @n_MaxLine) = 5
         BEGIN   
            SET @c_RowID05    = @c_RowID
            SET @c_SKU05      = @c_SKU        
            SET @c_Qty05      = @c_Qty        
         END 
         ELSE IF (@n_intFlag % @n_MaxLine) = 6  
         BEGIN    
            SET @c_RowID06    = @c_RowID
            SET @c_SKU06      = @c_SKU        
            SET @c_Qty06      = @c_Qty        
         END 
         ELSE IF (@n_intFlag % @n_MaxLine) = 7  
         BEGIN     
            SET @c_RowID07    = @c_RowID
            SET @c_SKU07      = @c_SKU        
            SET @c_Qty07      = @c_Qty        
         END 
         ELSE IF (@n_intFlag % @n_MaxLine) = 8  
         BEGIN  
            SET @c_RowID08    = @c_RowID
            SET @c_SKU08      = @c_SKU        
            SET @c_Qty08      = @c_Qty        
         END 
         ELSE IF (@n_intFlag % @n_MaxLine) = 9  
         BEGIN    
            SET @c_RowID09    = @c_RowID
            SET @c_SKU09      = @c_SKU        
            SET @c_Qty09      = @c_Qty        
         END 
         ELSE IF (@n_intFlag % @n_MaxLine) = 10  
         BEGIN    
            SET @c_RowID10    = @c_RowID
            SET @c_SKU10      = @c_SKU        
            SET @c_Qty10      = @c_Qty        
         END 
         ELSE IF (@n_intFlag % @n_MaxLine) = 11  
         BEGIN 
            SET @c_RowID11    = @c_RowID
            SET @c_SKU11      = @c_SKU        
            SET @c_Qty11      = @c_Qty        
         END 
         ELSE IF (@n_intFlag % @n_MaxLine) = 12  
         BEGIN   
            SET @c_RowID12    = @c_RowID
            SET @c_SKU12      = @c_SKU        
            SET @c_Qty12      = @c_Qty        
         END 
         ELSE IF (@n_intFlag % @n_MaxLine) = 13  
         BEGIN  
            SET @c_RowID13    = @c_RowID
            SET @c_SKU13      = @c_SKU        
            SET @c_Qty13      = @c_Qty        
         END 
         ELSE IF (@n_intFlag % @n_MaxLine) = 14  
         BEGIN 
            SET @c_RowID14    = @c_RowID
            SET @c_SKU14      = @c_SKU        
            SET @c_Qty14      = @c_Qty        
         END 
         ELSE IF (@n_intFlag % @n_MaxLine) = 0
         BEGIN     
            SET @c_RowID15    = @c_RowID
            SET @c_SKU15      = @c_SKU               
            SET @c_Qty15      = @c_Qty      
         END       
         
         UPDATE #Result  
         SET   Col04 = @c_RowID01
             , Col05 = @c_SKU01 
             , Col06 = @c_Qty01 
             , Col07 = @c_RowID02   
             , Col08 = @c_SKU02      
             , Col09 = @c_Qty02         
             , Col10 = @c_RowID03
             , Col11 = @c_SKU03     
             , Col12 = @c_Qty03
             , Col13 = @c_RowID04
             , Col14 = @c_SKU04        
             , Col15 = @c_Qty04      
             , Col16 = @c_RowID05
             , Col17 = @c_SKU05     
             , Col18 = @c_Qty05      
             , Col19 = @c_RowID06           
             , Col20 = @c_SKU06        
             , Col21 = @c_Qty06   
             , Col22 = @c_RowID07       
             , Col23 = @c_SKU07       
             , Col24 = @c_Qty07  
             , Col25 = @c_RowID08         
             , Col26 = @c_SKU08        
             , Col27 = @c_Qty08  
             , Col28 = @c_RowID09     
             , Col29 = @c_SKU09        
             , Col30 = @c_Qty09  
             , Col31 = @c_RowID10          
             , Col32 = @c_SKU10        
             , Col33 = @c_Qty10  
             , Col34 = @c_RowID11          
             , Col35 = @c_SKU11        
             , Col36 = @c_Qty11  
             , Col37 = @c_RowID12          
             , Col38 = @c_SKU12        
             , Col39 = @c_Qty12  
             , Col40 = @c_RowID13           
             , Col41 = @c_SKU13        
             , Col42 = @c_Qty13  
             , Col43 = @c_RowID14          
             , Col44 = @c_SKU14        
             , Col45 = @c_Qty14  
             , Col46 = @c_RowID15            
             , Col47 = @c_SKU15        
             , Col48 = @c_Qty15  
             , Col49 = @n_CurrentPage  
             , Col50 = @n_TTLpage
         WHERE ID = @n_CurrentPage
   
         UPDATE #Temp_Packdetail  
         SET Retreive = 'Y'  
         WHERE ID = @n_intFlag  
   
         SET @n_intFlag = @n_intFlag + 1  
        
         IF @n_intFlag > @n_CntRec    
         BEGIN    
            BREAK;    
         END    
      END  
 
      FETCH NEXT FROM CUR_RowNoLoop INTO @c_ToID
   END  
   CLOSE CUR_RowNoLoop  
   DEALLOCATE CUR_RowNoLoop  
  
   UPDATE #Result  
   SET Col51 = @n_QtyReceived  
     , Col52 = @c_EditWho
     , Col53 = @c_EditDate
   WHERE Col01 = @c_Sparm01 

RESULT:  
   SELECT * FROM #Result (nolock)       
   ORDER BY ID     
              
EXIT_SP:      
   IF OBJECT_ID('tempdb..#Result') IS NOT NULL
      DROP TABLE #Result

   IF OBJECT_ID('tempdb..#Temp_Packdetail') IS NOT NULL
      DROP TABLE #Temp_Packdetail
                
END -- procedure     

GO