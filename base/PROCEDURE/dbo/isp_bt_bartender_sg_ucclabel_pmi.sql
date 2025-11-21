SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

  
/********************************************************************************/                   
/* Copyright: LFL                                                               */                   
/* Purpose: isp_BT_Bartender_SG_UCCLABEL_PMI                                    */                   
/*                                                                              */                   
/* Modifications log:                                                           */                   
/*                                                                              */                   
/* Date       Rev  Author     Purposes                                          */                   
/* 2020-02-03 1.0  WLChooi    Created (WMS-11927)                               */  
/* 2020-05-08 1.1  CSCHONG    WMS-13227 revised col12 logic (CS01)              */
/********************************************************************************/                  
                    
CREATE PROC [dbo].[isp_BT_Bartender_SG_UCCLABEL_PMI]                        
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
      
      @c_ALTSKU01        NVARCHAR(80),    
      @c_SKU01           NVARCHAR(80),    
      @c_DESCR01         NVARCHAR(80),   
      @c_Qty01           NVARCHAR(80),  

      @c_ALTSKU02        NVARCHAR(80),    
      @c_SKU02           NVARCHAR(80),    
      @c_DESCR02         NVARCHAR(80),   
      @c_Qty02           NVARCHAR(80),  

      @c_ALTSKU03        NVARCHAR(80),    
      @c_SKU03           NVARCHAR(80),    
      @c_DESCR03         NVARCHAR(80),   
      @c_Qty03           NVARCHAR(80),  

      @c_ALTSKU04        NVARCHAR(80),    
      @c_SKU04           NVARCHAR(80),    
      @c_DESCR04         NVARCHAR(80),   
      @c_Qty04           NVARCHAR(80),  

      @c_ALTSKU05        NVARCHAR(80),    
      @c_SKU05           NVARCHAR(80),    
      @c_DESCR05         NVARCHAR(80),   
      @c_Qty05           NVARCHAR(80),  

      @c_ALTSKU06        NVARCHAR(80),    
      @c_SKU06           NVARCHAR(80),    
      @c_DESCR06         NVARCHAR(80),   
      @c_Qty06           NVARCHAR(80),  

      @c_ALTSKU07        NVARCHAR(80),    
      @c_SKU07           NVARCHAR(80),    
      @c_DESCR07         NVARCHAR(80),   
      @c_Qty07           NVARCHAR(80),  

      @c_ALTSKU08        NVARCHAR(80),    
      @c_SKU08           NVARCHAR(80),    
      @c_DESCR08         NVARCHAR(80),   
      @c_Qty08           NVARCHAR(80),  

      @c_ALTSKU          NVARCHAR(80),    
      @c_SKU             NVARCHAR(80),    
      @c_DESCR           NVARCHAR(80),   
      @c_Qty             NVARCHAR(80),   
      @c_InnerPack       NVARCHAR(80), 
      @c_Casecnt         NVARCHAR(80),  
        
      @c_CheckConso      NVARCHAR(10),  
      @c_GetOrderkey     NVARCHAR(10),  
        
      @n_TTLpage         INT,            
      @n_CurrentPage     INT,    
      @n_MaxLine         INT,  
      @n_Casecnt         INT,
      @n_TotalCarton     INT,
        
      @c_LabelNo         NVARCHAR(30),  
      @c_Pickslipno      NVARCHAR(10),  
      @c_CartonNo        NVARCHAR(10),  
      @n_SumQty          INT,  
      @c_Sorting         NVARCHAR(4000),  
      @c_ExtraSQL        NVARCHAR(4000),  
      @c_JoinStatement   NVARCHAR(4000)              
      
  DECLARE  @d_Trace_StartTime   DATETIME,     
           @d_Trace_EndTime     DATETIME,    
           @c_Trace_ModuleName  NVARCHAR(20),     
           @d_Trace_Step1       DATETIME,     
           @c_Trace_Step1       NVARCHAR(20),    
           @c_UserName          NVARCHAR(20),
           @c_caseid            NVARCHAR(20)   --CS01                   
    
   SET @d_Trace_StartTime = GETDATE()    
   SET @c_Trace_ModuleName = ''   
     
   SET @n_CurrentPage = 1    
   SET @n_TTLpage =1         
   SET @n_MaxLine = 8       
   SET @n_CntRec = 1      
   SET @n_intFlag = 1    
   SET @c_ExtraSQL = ''  
   SET @c_JoinStatement = ''  
  
   SET @c_CheckConso = 'N'  
      
-- SET RowNo = 0               
   SET @c_SQL = ''         
     
   --Discrete  
   SELECT TOP 1 @c_GetOrderkey = ORDERS.Orderkey  
   FROM PACKHEADER (NOLOCK)  
   JOIN ORDERS (NOLOCK) ON ORDERS.ORDERKEY = PACKHEADER.ORDERKEY  
   WHERE PACKHEADER.Pickslipno = @c_Sparm01  
  
   IF ISNULL(@c_GetOrderkey,'') = ''  
   BEGIN  
      --Conso  
      SELECT TOP 1 @c_GetOrderkey = ORDERS.Orderkey  
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
                         + ' CROSS APPLY (SELECT SUM(Qty) AS PickQTY FROM PICKDETAIL (NOLOCK) WHERE PICKDETAIL.ORDERKEY = OH.ORDERKEY) AS PIDET ' + CHAR(13)  
     
   IF @c_CheckConso = 'Y'  
   BEGIN  
      SET @c_JoinStatement = N' JOIN LOADPLANDETAIL LPD (NOLOCK) ON PH.LOADKEY = LPD.LOADKEY ' + CHAR(13)  
                            + ' JOIN ORDERS OH (NOLOCK) ON OH.ORDERKEY = LPD.ORDERKEY ' + CHAR(13)  
                            + ' CROSS APPLY (SELECT SUM(Qty) AS PickQTY FROM PICKDETAIL (NOLOCK) WHERE PICKDETAIL.ORDERKEY = OH.ORDERKEY) AS PIDET ' + CHAR(13)  
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
        
      CREATE TABLE #Temp_Packdetail (  
       [ID]         [INT] IDENTITY(1,1) NOT NULL,         
       [Pickslipno] [NVARCHAR] (80) NULL,  
       [LabelNo]    [NVARCHAR] (80) NULL,  
       [CartonNo]   [NVARCHAR] (80) NULL,       
       [LabelLine]  [NVARCHAR] (80) NULL, 
       [ALTSKU]     [NVARCHAR] (80) NULL,                               
       [SKU]        [NVARCHAR] (80) NULL,  
       [DESCR]      [NVARCHAR] (80) NULL,  
       [Qty]        [NVARCHAR] (80) NULL,  
       [InnerPack]  [NVARCHAR] (80) NULL, 
       [CaseCnt]    [NVARCHAR] (80) NULL, 
       [Retreive]   [NVARCHAR] (80) NULL  
      )           
  
      SET @c_Sorting = N' ORDER BY PD.Pickslipno, PD.CartonNo DESC '  
  
      SET @c_SQLJOIN = + ' SELECT DISTINCT PD.LabelNo, OH.ExternOrderKey, OH.Consigneekey, LTRIM(RTRIM(ISNULL(OH.C_Company,''''))), LTRIM(RTRIM(ISNULL(OH.C_Address1,''''))),' + CHAR(13) --5
                       + ' LTRIM(RTRIM(ISNULL(OH.C_Address2,''''))), LTRIM(RTRIM(ISNULL(OH.C_Address4,''''))), LTRIM(RTRIM(ISNULL(OH.C_Zip,''''))), ' + CHAR(13) --8  
                       + ' LTRIM(RTRIM(ISNULL(OH.C_Country,''''))), ISNULL(RM.TruckType,''''), ' + CHAR(13) --10   
                       + ' OH.Route, PD.CartonNo, '''', '''', '''', '''', LTRIM(RTRIM(ISNULL(OH.C_Address3,''''))), '''', '''', '''', '  + CHAR(13) --20         
                       + ' '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', '  + CHAR(13) --30     
                       + ' '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', '  + CHAR(13) --40  
                       + ' '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', '  + CHAR(13) --50        
                       + ' '''', '''', '''', '''', '''', '''', '''', OH.Orderkey, PD.Pickslipno, ''SG'' '  --60            
                       + CHAR(13) +              
                       + ' FROM PACKHEADER PH WITH (NOLOCK)'        + CHAR(13)  
                       + ' JOIN PACKDETAIL PD WITH (NOLOCK) ON PH.Pickslipno = PD.Pickslipno'   + CHAR(13)  
                       +   @c_JoinStatement  
                       + ' LEFT JOIN STORER ST WITH (NOLOCK) ON ST.STORERKEY = OH.Consigneekey ' + CHAR(13)
                       + ' LEFT JOIN RouteMaster RM WITH (NOLOCK) ON RM.Route = OH.Route ' + CHAR(13)
                       + ' WHERE PD.Pickslipno = @c_Sparm01 '   + CHAR(13)   
                       + ' AND PD.LabelNo =  @c_Sparm02 ' + CHAR(13)
                       + ' GROUP BY PD.LabelNo, OH.ExternOrderKey, OH.Consigneekey, LTRIM(RTRIM(ISNULL(OH.C_Company,''''))), LTRIM(RTRIM(ISNULL(OH.C_Address1,''''))), ' + CHAR(13)
                       + ' LTRIM(RTRIM(ISNULL(OH.C_Address2,''''))), LTRIM(RTRIM(ISNULL(OH.C_Address4,''''))), LTRIM(RTRIM(ISNULL(OH.C_Zip,''''))), ' + CHAR(13)
                       + ' LTRIM(RTRIM(ISNULL(OH.C_Country,''''))), ISNULL(RM.TruckType,''''), ' + CHAR(13)  
                       + ' OH.Route, PD.CartonNo, LTRIM(RTRIM(ISNULL(OH.C_Address3,''''))), OH.Orderkey, PD.Pickslipno ' + CHAR(13)  
                       + @c_Sorting                
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
                +',Col55,Col56,Col57,Col58,Col59,Col60) '    
                  
      SET @c_SQL = @c_SQL + @c_SQLJOIN                
                       
--EXEC sp_executesql @c_SQL            
  
      SET @c_ExecArguments =    N'  @c_Sparm01         NVARCHAR(80) '      
                               + ', @c_Sparm02         NVARCHAR(80) '       
                               + ', @c_Sparm03         NVARCHAR(80) '   
  
                           
                           
      EXEC sp_ExecuteSql     @c_SQL       
                           , @c_ExecArguments      
                           , @c_Sparm01      
                           , @c_Sparm02    
                           , @c_Sparm03  
          
      IF @b_debug=1          
      BEGIN            
         PRINT @c_SQL            
      END             
        
      --SELECT * FROM #RESULT  
      --GOTO EXIT_SP  
      DECLARE CUR_RowNoLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
      SELECT DISTINCT col01,col59,CAST(col12 AS INT)      
      FROM #Result   
      WHERE Col60 = 'SG'  
      ORDER BY col59, CAST(col12 AS INT)  
  
      OPEN CUR_RowNoLoop     
        
      FETCH NEXT FROM CUR_RowNoLoop INTO @c_LabelNo, @c_Pickslipno, @c_CartonNo   
  
      WHILE @@FETCH_STATUS <> -1   
      BEGIN  
         INSERT INTO #Temp_Packdetail  
         SELECT @c_Pickslipno, @c_LabelNo, @c_CartonNo, PD.LabelLine, S.ALTSKU, PD.SKU, S.DESCR, SUM(PD.Qty), P.InnerPack, P.CaseCnt, 'N'  
         FROM PACKHEADER PH WITH (NOLOCK)  
         JOIN PACKDETAIL PD WITH (NOLOCK) ON PH.PickSlipNo = PD.Pickslipno        
         JOIN SKU S WITH (NOLOCK) ON S.Sku = PD.SKU AND S.storerkey = PH.Storerkey     
         JOIN PACK P WITH (NOLOCK) ON P.Packkey = S.Packkey
         WHERE PD.PickSlipNo = @c_Pickslipno     
         AND PD.CartonNo = CAST(@c_CartonNo AS INT)  
         AND PD.LabelNo = @c_LabelNo  
         GROUP BY PD.LabelLine, S.ALTSKU, PD.SKU, S.DESCR, P.InnerPack, P.CaseCnt
         ORDER BY CAST(PD.LabelLine AS INT)  
  
         SET @c_ALTSKU01    = ''  
         SET @c_SKU01       = ''  
         SET @c_DESCR01     = ''  
         SET @c_Qty01       = ''  
         SET @c_ALTSKU02    = ''  
         SET @c_SKU02       = ''  
         SET @c_DESCR02     = ''  
         SET @c_Qty02       = ''  
         SET @c_ALTSKU03    = ''  
         SET @c_SKU03       = ''  
         SET @c_DESCR03     = ''  
         SET @c_Qty03       = ''  
         SET @c_ALTSKU04    = ''
         SET @c_SKU04       = ''
         SET @c_DESCR04     = ''
         SET @c_Qty04       = ''
         SET @c_ALTSKU05    = ''
         SET @c_SKU05       = ''
         SET @c_DESCR05     = ''
         SET @c_Qty05       = ''
         SET @c_ALTSKU06    = ''
         SET @c_SKU06       = ''
         SET @c_DESCR06     = ''
         SET @c_Qty06       = ''
         SET @c_ALTSKU07    = ''
         SET @c_SKU07       = ''
         SET @c_DESCR07     = ''
         SET @c_Qty07       = ''
         SET @c_ALTSKU08    = ''
         SET @c_SKU08       = ''
         SET @c_DESCR08     = ''
         SET @c_Qty08       = ''

         IF @b_debug = 1  
            SELECT * FROM #Temp_Packdetail  
  
         SELECT @n_CntRec = COUNT (1)    
         FROM #Temp_Packdetail  
         WHERE Pickslipno = @c_Pickslipno  
         AND LabelNo = @c_LabelNo  
         AND CartonNo = @c_CartonNo  
         AND Retreive = 'N'  
  
         /*SET @n_TTLpage =  FLOOR(@n_CntRec / @n_MaxLine ) + CASE WHEN @n_CntRec % @n_MaxLine > 0 THEN 1 ELSE 0 END     
        
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
               SELECT TOP 1 Col01,Col02,Col03,Col04,Col05,Col06,Col07,Col08,Col09,Col10,         
                            Col11,Col12,'','','','',Col17,'','','',  
                            '','','','','','','','','','',                  
                            '','','','','', '','','','','',                       
                            '','','','','', '','','','','',                   
                            '','','','','', '','',Col58,Col59,Col60   
               FROM #Result WHERE Col59 <> ''  
  
               SET @c_ALTSKU01    = ''  
               SET @c_SKU01       = ''  
               SET @c_DESCR01     = ''  
               SET @c_Qty01       = ''  
               SET @c_ALTSKU02    = ''  
               SET @c_SKU02       = ''  
               SET @c_DESCR02     = ''  
               SET @c_Qty02       = ''  
               SET @c_ALTSKU03    = ''  
               SET @c_SKU03       = ''  
               SET @c_DESCR03     = ''  
               SET @c_Qty03       = ''  
               SET @c_ALTSKU04    = ''
               SET @c_SKU04       = ''
               SET @c_DESCR04     = ''
               SET @c_Qty04       = ''
               SET @c_ALTSKU05    = ''
               SET @c_SKU05       = ''
               SET @c_DESCR05     = ''
               SET @c_Qty05       = ''
               SET @c_ALTSKU06    = ''
               SET @c_SKU06       = ''
               SET @c_DESCR06     = ''
               SET @c_Qty06       = ''
               SET @c_ALTSKU07    = ''
               SET @c_SKU07       = ''
               SET @c_DESCR07     = ''
               SET @c_Qty07       = ''
               SET @c_ALTSKU08    = ''
               SET @c_SKU08       = ''
               SET @c_DESCR08     = ''
               SET @c_Qty08       = ''
            END  
  
            SELECT   @c_ALTSKU    = ALTSKU      
                   , @c_SKU       = SKU     
                   , @c_DESCR     = Descr 
                   , @c_Qty       = Qty
                   , @c_InnerPack = CASE WHEN ISNULL(InnerPack,0) = 0 THEN 1 ELSE InnerPack END
             FROM #Temp_Packdetail   
             WHERE ID = @n_intFlag  

             IF (@n_intFlag % @n_MaxLine) = 1 --AND @n_recgrp = @n_CurrentPage    
             BEGIN   
                SET @c_ALTSKU01     = @c_ALTSKU     
                SET @c_SKU01        = @c_SKU           
                SET @c_DESCR01      = @c_DESCR 
                SET @c_Qty01        = CAST(@c_Qty AS INT) / CAST(@c_InnerPack AS INT)
             END        
             ELSE IF (@n_intFlag % @n_MaxLine) = 2 --AND @n_recgrp = @n_CurrentPage    
             BEGIN     
                SET @c_ALTSKU02     = @c_ALTSKU     
                SET @c_SKU02        = @c_SKU           
                SET @c_DESCR02      = @c_DESCR 
                SET @c_Qty02        = CAST(@c_Qty AS INT) / CAST(@c_InnerPack AS INT)
             END    
             ELSE IF (@n_intFlag % @n_MaxLine) = 3 --AND @n_recgrp = @n_CurrentPage    
             BEGIN     
                SET @c_ALTSKU03     = @c_ALTSKU     
                SET @c_SKU03        = @c_SKU           
                SET @c_DESCR03      = @c_DESCR 
                SET @c_Qty03       = CAST(@c_Qty AS INT) / CAST(@c_InnerPack AS INT)            
             END   
             ELSE IF (@n_intFlag % @n_MaxLine) = 4 --AND @n_recgrp = @n_CurrentPage    
             BEGIN     
                SET @c_ALTSKU04     = @c_ALTSKU     
                SET @c_SKU04        = @c_SKU           
                SET @c_DESCR04      = @c_DESCR 
                SET @c_Qty04        = CAST(@c_Qty AS INT) / CAST(@c_InnerPack AS INT)        
             END   
             ELSE IF (@n_intFlag % @n_MaxLine) = 5 --AND @n_recgrp = @n_CurrentPage    
             BEGIN     
                SET @c_ALTSKU05     = @c_ALTSKU     
                SET @c_SKU05        = @c_SKU           
                SET @c_DESCR05      = @c_DESCR 
                SET @c_Qty05        = CAST(@c_Qty AS INT) / CAST(@c_InnerPack AS INT)
             END  
             ELSE IF (@n_intFlag % @n_MaxLine) = 6 --AND @n_recgrp = @n_CurrentPage    
             BEGIN     
                SET @c_ALTSKU06     = @c_ALTSKU     
                SET @c_SKU06        = @c_SKU           
                SET @c_DESCR06      = @c_DESCR 
                SET @c_Qty06        = CAST(@c_Qty AS INT) / CAST(@c_InnerPack AS INT)
             END 
             ELSE IF (@n_intFlag % @n_MaxLine) = 7 --AND @n_recgrp = @n_CurrentPage    
             BEGIN     
                SET @c_ALTSKU07     = @c_ALTSKU     
                SET @c_SKU07        = @c_SKU           
                SET @c_DESCR07      = @c_DESCR 
                SET @c_Qty07        = CAST(@c_Qty AS INT) / CAST(@c_InnerPack AS INT)
             END 
             ELSE IF (@n_intFlag % @n_MaxLine) = 0 --AND @n_recgrp = @n_CurrentPage    
             BEGIN     
                SET @c_ALTSKU08     = @c_ALTSKU     
                SET @c_SKU08        = @c_SKU           
                SET @c_DESCR08      = @c_DESCR 
                SET @c_Qty08        = CAST(@c_Qty AS INT) / CAST(@c_InnerPack AS INT)           
             END    
  
             UPDATE #Result  
             SET   Col13 = @c_ALTSKU01      
                 , Col14 = @c_SKU01      
                 , Col15 = @c_DESCR01         
                 , Col16 = @c_Qty01  
                        
                 , Col18 = @c_ALTSKU02
                 , Col19 = @c_SKU02   
                 , Col20 = @c_DESCR02 
                 , Col21 = @c_Qty02    
                      
                 , Col22 = @c_ALTSKU03        
                 , Col23 = @c_SKU03     
                 , Col24 = @c_DESCR03 
                 , Col25 = @c_Qty03   
                      
                 , Col26 = @c_ALTSKU04  
                 , Col27 = @c_SKU04   
                 , Col28 = @c_DESCR04 
                 , Col29 = @c_Qty04   

                 , Col30 = @c_ALTSKU05
                 , Col31 = @c_SKU05 
                 , Col32 = @c_DESCR05 
                 , Col33 = @c_Qty05   

                 , Col34 = @c_ALTSKU06
                 , Col35 = @c_SKU06   
                 , Col36 = @c_DESCR06 
                 , Col37 = @c_Qty06   

                 , Col38 = @c_ALTSKU07
                 , Col39 = @c_SKU07   
                 , Col40 = @c_DESCR07 
                 , Col41 = @c_Qty07   

                 , Col42 = @c_ALTSKU08
                 , Col43 = @c_SKU08   
                 , Col44 = @c_DESCR08 
                 , Col45 = @c_Qty08   

                 , Col46 = @n_CurrentPage
                 , Col47 = @n_TTLpage
                  
            WHERE ID = @n_CurrentPage AND Col59 <> ''  
  
            UPDATE #Temp_Packdetail  
            SET Retreive = 'Y'  
            WHERE ID = @n_intFlag  
  
            SET @n_intFlag = @n_intFlag + 1  
           
            IF @n_intFlag > @n_CntRec    
            BEGIN    
               BREAK;    
            END    
         END  */
  
         SELECT @n_SumQty = SUM(Qty)
               ,@c_caseid = MAX(caseid)                   --CS01
         FROM PICKDETAIL (NOLOCK)
         WHERE ORDERKEY IN (SELECT DISTINCT COL58 FROM #RESULT) 
          
         --AND PD.LabelNo = @c_LabelNo  
         --AND PD.CartonNo = @c_CartonNo  

         SELECT TOP 1 @n_Casecnt = Casecnt
         FROM #Temp_Packdetail
         WHERE Pickslipno = @c_Pickslipno  
         AND LabelNo = @c_LabelNo  
         AND CartonNo = @c_CartonNo  

         SELECT @n_Casecnt = CASE WHEN ISNULL(@n_Casecnt,0) = 0 THEN 1.00 ELSE @n_Casecnt END

         --SELECT @n_TotalCarton = CEILING(@n_SumQty / CAST(@n_Casecnt AS FLOAT))  --CS01
         SET @n_totalCarton = CASE WHEN PATINDEX('%-0', @c_caseid) = 1   THEN    --CS01 START
                                         CAST(CAST(@c_caseid AS INT) AS VARCHAR(10)) 
                                    ELSE 
                                         CAST(CAST(@c_caseid AS INT) AS VARCHAR(10)) 
                                    END

         UPDATE #Result  
         SET Col12 = Col12 + '/' + CAST(@n_TotalCarton AS NVARCHAR(20))  
           , Col46 = 1
           , Col47 = 1
         WHERE Col59 = @c_Pickslipno  
         AND Col01 = @c_LabelNo  
         AND Col12 = @c_CartonNo  
  
         FETCH NEXT FROM CUR_RowNoLoop INTO @c_LabelNo, @c_Pickslipno, @c_CartonNo   
   END  
   CLOSE CUR_RowNoLoop  
   DEALLOCATE CUR_RowNoLoop  
  
RESULT:  
   SELECT * FROM #Result (nolock)       
   ORDER BY ID     
              
EXIT_SP:      
    
      SET @d_Trace_EndTime = GETDATE()    
      SET @c_UserName = SUSER_SNAME()    
        
   --EXEC isp_InsertTraceInfo     
   --   @c_TraceCode = 'BARTENDER',    
   --   @c_TraceName = 'isp_BT_Bartender_SG_UCCLABEL_PMI',    
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