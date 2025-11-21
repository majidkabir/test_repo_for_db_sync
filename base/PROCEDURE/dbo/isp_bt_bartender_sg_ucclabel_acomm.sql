SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/********************************************************************************/                   
/* Copyright: LFL                                                               */                   
/* Purpose: isp_BT_Bartender_SG_UCCLABEL_ACOMM                                  */                   
/*                                                                              */                   
/* Modifications log:                                                           */                   
/*                                                                              */                   
/* Date       Rev  Author     Purposes                                          */                   
/* 2021-06-28 1.0  WLChooi    Created (WMS-17316)                               */  
/* 2021-11-19 1.1  Mingle     Add new col32 (WMS-18308)                         */
/* 2021-11-19 1.1  Mingle     DevOps Combine Script                             */ 
/********************************************************************************/                  
                    
CREATE PROC [dbo].[isp_BT_Bartender_SG_UCCLABEL_ACOMM]                        
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
      @c_ReceiptKey      NVARCHAR(10),                           
      @n_intFlag         INT,       
      @n_CntRec          INT,      
      @c_SQL             NVARCHAR(4000),          
      @c_SQLSORT         NVARCHAR(4000),          
      @c_SQLJOIN         NVARCHAR(4000),  
      @c_ExecStatements  NVARCHAR(4000),         
      @c_ExecArguments   NVARCHAR(4000), 
      @c_Labelno         NVARCHAR(20), 
        
      @c_CheckConso      NVARCHAR(10),  
      @c_GetOrderkey     NVARCHAR(10),  
        
      @n_TTLpage         INT,            
      @n_CurrentPage     INT,    
      @n_MaxLine         INT,  
      @n_Casecnt         INT,
      @n_TotalCarton     INT,
        
      @c_DocType         NVARCHAR(1),
      @c_OrderGroup      NVARCHAR(50),  
      @c_Pickslipno      NVARCHAR(10),  
      @c_Cartonno        NVARCHAR(10),  
      @n_SumQty          INT,  
      @c_Sorting         NVARCHAR(4000),  
      @c_ExtraSQL        NVARCHAR(4000),  
      @c_JoinStatement   NVARCHAR(4000)
      
  DECLARE @c_SKU01              NVARCHAR(80),           
          @c_SKU02              NVARCHAR(80),    
          @c_SKU03              NVARCHAR(80),           
          @c_SKU04              NVARCHAR(80),   
          @c_SKU05              NVARCHAR(80),           
          @c_SKU06              NVARCHAR(80),  
          @c_SKU07              NVARCHAR(80),           
          @c_SKU08              NVARCHAR(80),        
          @c_SKU09              NVARCHAR(80),   
          @c_SKU10              NVARCHAR(80),              
          @c_SKUQty01           NVARCHAR(10),          
          @c_SKUQty02           NVARCHAR(10),    
          @c_SKUQty03           NVARCHAR(10),          
          @c_SKUQty04           NVARCHAR(10),     
          @c_SKUQty05           NVARCHAR(10),          
          @c_SKUQty06           NVARCHAR(10),    
          @c_SKUQty07           NVARCHAR(10),          
          @c_SKUQty08           NVARCHAR(10),     
          @c_SKUQty09           NVARCHAR(10),   
          @c_SKUQty10           NVARCHAR(10),
          @c_SKU                NVARCHAR(80),
          @n_SKUQty             INT   
      
  DECLARE  @d_Trace_StartTime   DATETIME,     
           @d_Trace_EndTime     DATETIME,    
           @c_Trace_ModuleName  NVARCHAR(20),     
           @d_Trace_Step1       DATETIME,     
           @c_Trace_Step1       NVARCHAR(20),    
           @c_UserName          NVARCHAR(20),
           @c_TotalQtyPerCtn    INT                 
    
   SET @d_Trace_StartTime = GETDATE()    
   SET @c_Trace_ModuleName = ''   
     
   SET @n_CurrentPage = 1    
   SET @n_TTLpage = 1         
   SET @n_MaxLine = 10       
   SET @n_CntRec = 1      
   SET @n_intFlag = 1    
   SET @c_ExtraSQL = ''  
   SET @c_JoinStatement = ''  
   SET @c_CheckConso = 'N'               
   SET @c_SQL = ''         
     
   --Discrete  
   SELECT TOP 1 @c_GetOrderkey = ORDERS.Orderkey
              , @c_DocType     = ORDERS.DocType
              , @c_OrderGroup  = ORDERS.OrderGroup
   FROM PACKHEADER (NOLOCK)  
   JOIN ORDERS (NOLOCK) ON ORDERS.ORDERKEY = PACKHEADER.ORDERKEY  
   WHERE PACKHEADER.Pickslipno = @c_Sparm01  
  
   IF ISNULL(@c_GetOrderkey,'') = ''  
   BEGIN  
      --Conso  
      SELECT TOP 1 @c_GetOrderkey = ORDERS.Orderkey  
                 , @c_DocType     = ORDERS.DocType
                 , @c_OrderGroup  = ORDERS.OrderGroup
      FROM PACKHEADER (NOLOCK)  
      JOIN LOADPLANDETAIL (NOLOCK) ON PACKHEADER.LOADKEY = LOADPLANDETAIL.LOADKEY  
      JOIN ORDERS (NOLOCK) ON ORDERS.ORDERKEY = LOADPLANDETAIL.ORDERKEY  
      WHERE PACKHEADER.Pickslipno = @c_Sparm01  
  
      IF ISNULL(@c_GetOrderkey,'') <> ''  
         SET @c_CheckConso = 'Y'  
      ELSE  
         GOTO EXIT_SP  
   END  
   
   SET @c_JoinStatement = N' JOIN ORDERS OH (NOLOCK) ON PH.ORDERKEY = OH.ORDERKEY ' + CHAR(13)  
     
   IF @c_CheckConso = 'Y'  
   BEGIN  
      SET @c_JoinStatement = N' JOIN LOADPLANDETAIL LPD (NOLOCK) ON PH.LOADKEY = LPD.LOADKEY ' + CHAR(13)  
                            + ' JOIN ORDERS OH (NOLOCK) ON OH.ORDERKEY = LPD.ORDERKEY ' + CHAR(13)  
   END  
     
   IF @b_debug = 1     
      SELECT @c_CheckConso       
                
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
      [Pickslipno]  [NVARCHAR] (10) NULL,    
      [CartonNo]    [NVARCHAR] (5)  NULL,         
      [SKU]         [NVARCHAR] (20) NULL,             
      [Qty]         [INT],  
      [Labelno]     [NVARCHAR] (20) NULL,  
      [Retrieve]    [NVARCHAR] (1) DEFAULT 'N')     

   IF @c_DocType = 'E' AND @c_OrderGroup = 'aCommerce'
   BEGIN
      SET @c_SQLJOIN = + ' SELECT DISTINCT PH.Pickslipno, OH.OrderKey, '''', '''', '''',' + CHAR(13) --5
                       + ' '''', '''', '''', '''', '''', '  + CHAR(13) --10
                       + ' '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', '  + CHAR(13) --20     
                       + ' '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', '  + CHAR(13) --30     
                       + ' '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', '  + CHAR(13) --40  
                       + ' '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', '  + CHAR(13) --50        
                       + ' '''', '''', '''', '''', '''', '''', '''', '''', '''', ''SG'' '  --60            
                       + CHAR(13) +              
                       + ' FROM PACKHEADER PH WITH (NOLOCK)'        + CHAR(13)  
                       + @c_JoinStatement  
                       + ' WHERE PH.Pickslipno = @c_Sparm01 '   + CHAR(13)   
   END
   ELSE
   BEGIN
      SET @c_SQLJOIN = + ' SELECT DISTINCT PD.LabelNo, PD.CartonNo, LTRIM(RTRIM(ISNULL(OH.C_Company,''''))), LTRIM(RTRIM(ISNULL(OH.C_Address1,''''))), LTRIM(RTRIM(ISNULL(OH.C_Address2,''''))), ' + CHAR(13) --5
                       + ' LTRIM(RTRIM(ISNULL(OH.C_Address3,''''))), LTRIM(RTRIM(ISNULL(OH.C_Address3,''''))), LTRIM(RTRIM(ISNULL(OH.C_Country,''''))), ' + CHAR(13) --8  
                       + ' OH.Consigneekey, OH.ExternOrderkey, ' + CHAR(13) --10   
                       + ' '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', '  + CHAR(13) --20         
                       + ' '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', '  + CHAR(13) --30     
                       + ' '''', OH.Buyerpo, '''', '''', '''', '''', '''', '''', '''', '''', '  + CHAR(13) --40  
                       + ' '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', '  + CHAR(13) --50        
                       + ' '''', '''', '''', '''', '''', '''', '''', OH.Orderkey, PD.Pickslipno, ''SG'' '  --60            
                       + CHAR(13) +              
                       + ' FROM PACKHEADER PH WITH (NOLOCK)'        + CHAR(13)  
                       + ' JOIN PACKDETAIL PD WITH (NOLOCK) ON PH.Pickslipno = PD.Pickslipno'   + CHAR(13)  
                       + @c_JoinStatement  
                       + ' WHERE PD.Pickslipno = @c_Sparm01 '   + CHAR(13)   
                       + ' AND PD.LabelNo =  @c_Sparm02 ' + CHAR(13)
   END    

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
   
   SET @c_ExecArguments = N' @c_Sparm01         NVARCHAR(80) '      
                        + ', @c_Sparm02         NVARCHAR(80) '       
                        + ', @c_Sparm03         NVARCHAR(80) '   
  
                           
                           
   EXEC sp_ExecuteSql  @c_SQL       
                     , @c_ExecArguments      
                     , @c_Sparm01      
                     , @c_Sparm02    
                     , @c_Sparm03  
          
   IF @b_debug=1          
   BEGIN            
      PRINT @c_SQL            
   END             

   IF @c_DocType = 'E' AND @c_OrderGroup = 'aCommerce'
   BEGIN
      GOTO RESULT
   END
   ELSE
   BEGIN
      DECLARE CUR_RowNoLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
      SELECT DISTINCT Col01, col59, Col02       
      FROM #Result                         
               
      OPEN CUR_RowNoLoop                    
                  
      FETCH NEXT FROM CUR_RowNoLoop INTO @c_Labelno, @c_Pickslipno, @c_Cartonno      
                    
      WHILE @@FETCH_STATUS <> -1               
      BEGIN  
         INSERT INTO #TEMPSKU (Pickslipno, Cartonno, SKU, Qty, Labelno, Retrieve)          
         SELECT DISTINCT @c_Pickslipno, @c_Cartonno, PD.SKU, PD.Qty, @c_Labelno, 'N'
         FROM PACKDETAIL PD (NOLOCK)
         WHERE PD.PickSlipNo = @c_Pickslipno
         AND PD.CartonNo = @c_Cartonno
         AND PD.LabelNo = @c_Labelno
      
         SET @c_SKU01 = ''  
         SET @c_SKU02 = ''  
         SET @c_SKU03 = ''  
         SET @c_SKU04 = ''  
         SET @c_SKU05 = ''  
         SET @c_SKU06 = ''  
         SET @c_SKU07 = ''  
         SET @c_SKU08 = ''  
         SET @c_SKU09 = ''  
         SET @c_SKU10 = ''  
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
      
         SELECT @n_CntRec = COUNT (1)  
         FROM #TEMPSKU   
         WHERE LabelNo = @c_Labelno  
         AND Pickslipno = @c_Pickslipno   
         AND Retrieve = 'N'   
           
         SET @n_TTLpage =  FLOOR(@n_CntRec / @n_MaxLine ) + CASE WHEN @n_CntRec % @n_MaxLine > 0 THEN 1 ELSE 0 END   
      
         WHILE @n_intFlag <= @n_CntRec             
         BEGIN    
            IF @n_intFlag > @n_MaxLine AND (@n_intFlag % @n_MaxLine) = 1 --AND @c_LastRec = 'N'  
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
                            '','','','','','','','','','',                 
                            '','','','','','','',Col58,Col59,Col60  
               FROM  #Result     
       
               SET @c_SKU01 = ''  
               SET @c_SKU02 = ''  
               SET @c_SKU03 = ''  
               SET @c_SKU04 = ''  
               SET @c_SKU05 = ''  
               SET @c_SKU06 = ''  
               SET @c_SKU07 = ''  
               SET @c_SKU08 = ''  
               SET @c_SKU09 = ''  
               SET @c_SKU10 = ''  
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
            END      
      
            SELECT @c_SKU    = SKU,  
                   @n_SKUQty = SUM(Qty)  
            FROM #TEMPSKU   
            WHERE ID = @n_intFlag  
            GROUP BY SKU
              
            IF (@n_intFlag % @n_MaxLine) = 1
            BEGIN         
              SET @c_SKU01 = @c_SKU
              SET @c_SKUQty01 = CONVERT(NVARCHAR(10),@n_SKUQty)        
            END     
            ELSE IF (@n_intFlag % @n_MaxLine) = 2
            BEGIN         
              SET @c_SKU02 = @c_SKU
              SET @c_SKUQty02 = CONVERT(NVARCHAR(10),@n_SKUQty)        
            END  
            ELSE IF (@n_intFlag % @n_MaxLine) = 3
            BEGIN         
              SET @c_SKU03 = @c_SKU
              SET @c_SKUQty03 = CONVERT(NVARCHAR(10),@n_SKUQty)        
            END  
            ELSE IF (@n_intFlag % @n_MaxLine) = 4
            BEGIN         
              SET @c_SKU04 = @c_SKU
              SET @c_SKUQty04 = CONVERT(NVARCHAR(10),@n_SKUQty)        
            END  
            ELSE IF (@n_intFlag % @n_MaxLine) = 5
            BEGIN         
              SET @c_SKU05 = @c_SKU
              SET @c_SKUQty05 = CONVERT(NVARCHAR(10),@n_SKUQty)        
            END  
            ELSE IF (@n_intFlag % @n_MaxLine) = 6
            BEGIN         
              SET @c_SKU06 = @c_SKU
              SET @c_SKUQty06 = CONVERT(NVARCHAR(10),@n_SKUQty)        
            END  
            ELSE IF (@n_intFlag % @n_MaxLine) = 7
            BEGIN         
              SET @c_SKU07 = @c_SKU
              SET @c_SKUQty07 = CONVERT(NVARCHAR(10),@n_SKUQty)        
            END  
            ELSE IF (@n_intFlag % @n_MaxLine) = 8
            BEGIN         
              SET @c_SKU08 = @c_SKU
              SET @c_SKUQty08 = CONVERT(NVARCHAR(10),@n_SKUQty)        
            END  
            ELSE IF (@n_intFlag % @n_MaxLine) = 9
            BEGIN         
              SET @c_SKU09 = @c_SKU
              SET @c_SKUQty09 = CONVERT(NVARCHAR(10),@n_SKUQty)        
            END    
            ELSE IF (@n_intFlag % @n_MaxLine) = 0
            BEGIN         
              SET @c_SKU10 = @c_SKU
              SET @c_SKUQty10 = CONVERT(NVARCHAR(10),@n_SKUQty)        
            END    
               
            UPDATE #Result                    
            SET Col11 = @c_SKU01,
                Col12 = @c_SKUQty01,        
                Col13 = @c_SKU02,
                Col14 = @c_SKUQty02,          
                Col15 = @c_SKU03,               
                Col16 = @c_SKUQty03, 
                Col17 = @c_SKU04,          
                Col18 = @c_SKUQty04,        
                Col19 = @c_SKU05,  
                Col20 = @c_SKUQty05,        
                Col21 = @c_SKU06,       
                Col22 = @c_SKUQty06, 
                Col23 = @c_SKU07,          
                Col24 = @c_SKUQty07,       
                Col25 = @c_SKU08, 
                Col26 = @c_SKUQty08,  
                Col27 = @c_SKU09,
                Col28 = @c_SKUQty09, 
                Col29 = @c_SKU10,  
                Col30 = @c_SKUQty10
            WHERE ID = @n_CurrentPage   
      
            UPDATE #TEMPSKU
            SET Retrieve ='Y'  
            WHERE ID = @n_intFlag   
                         
            SET @n_intFlag = @n_intFlag + 1    
      
            IF @n_intFlag > @n_CntRec  
            BEGIN  
               BREAK;  
            END        
         END  
      
         FETCH NEXT FROM CUR_RowNoLoop INTO @c_Labelno, @c_Pickslipno, @c_Cartonno               
      END -- While                     
      CLOSE CUR_RowNoLoop                    
      DEALLOCATE CUR_RowNoLoop  
   
      SELECT @c_TotalQtyPerCtn = SUM(PD.Qty)
      FROM PACKDETAIL PD (NOLOCK)
      WHERE PD.Pickslipno = @c_Sparm01 
      AND PD.LabelNo =  @c_Sparm02
      
      UPDATE #Result
      SET Col31 = CAST(@c_TotalQtyPerCtn AS NVARCHAR(80))
      WHERE Col01 = @c_Sparm02
      AND Col59 = @c_Sparm01
   END

RESULT:  
   SELECT * FROM #Result (nolock)       
   ORDER BY ID     
              
EXIT_SP:      
   IF OBJECT_ID('tempdb..#TEMPSKU') IS NOT NULL
      DROP TABLE #TEMPSKU
                               
END -- procedure     

GO