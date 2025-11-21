SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/                       
/* Copyright: MAERSK                                                          */                       
/* Purpose: isp_BT_Bartender_CN_CONTENTLB1_DESIGUAL                           */                       
/*                                                                            */                       
/* Modifications log:                                                         */                       
/*                                                                            */                       
/* Date        Rev  Author     Purposes                                       */      
/* 16-Jun-2023 1.0  WLChooi    Created (WMS-22780)                            */  
/* 16-Jun-2023 1.0  WLChooi    DevOps Combine Script                          */   
/******************************************************************************/                      
                        
CREATE   PROC [dbo].[isp_BT_Bartender_CN_CONTENTLB1_DESIGUAL]                            
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
                                         
   DECLARE @c_SQL               NVARCHAR(4000)  
         , @d_Trace_StartTime   DATETIME         
         , @d_Trace_EndTime     DATETIME        
         , @c_Trace_ModuleName  NVARCHAR(20)         
         , @d_Trace_Step1       DATETIME        
         , @c_Trace_Step1       NVARCHAR(20)       
         , @c_UserName          NVARCHAR(20)               
         , @c_ExecArguments     NVARCHAR(4000)
         , @c_SQLJOIN           NVARCHAR(MAX)
         , @c_Storerkey         NVARCHAR(15)
         , @c_CheckConso        NVARCHAR(10) = 'N'
         , @c_JoinStatement     NVARCHAR(MAX)

   DECLARE @c_Col01             NVARCHAR(80)
         , @c_Col02             NVARCHAR(80)
         , @c_Col03             NVARCHAR(80)
         , @c_Col24             NVARCHAR(80)      

   DECLARE @c_SKU01             NVARCHAR(80) , @c_Qty01             NVARCHAR(80)
         , @c_SKU02             NVARCHAR(80) , @c_Qty02             NVARCHAR(80)
         , @c_SKU03             NVARCHAR(80) , @c_Qty03             NVARCHAR(80)
         , @c_SKU04             NVARCHAR(80) , @c_Qty04             NVARCHAR(80)
         , @c_SKU05             NVARCHAR(80) , @c_Qty05             NVARCHAR(80)
         , @c_SKU06             NVARCHAR(80) , @c_Qty06             NVARCHAR(80)
         , @c_SKU07             NVARCHAR(80) , @c_Qty07             NVARCHAR(80)
         , @c_SKU08             NVARCHAR(80) , @c_Qty08             NVARCHAR(80)
         , @c_SKU09             NVARCHAR(80) , @c_Qty09             NVARCHAR(80)
         , @c_SKU10             NVARCHAR(80) , @c_Qty10             NVARCHAR(80)
         , @c_SKU11             NVARCHAR(80) , @c_Qty11             NVARCHAR(80)
         , @c_SKU12             NVARCHAR(80) , @c_Qty12             NVARCHAR(80)
         , @c_SKU13             NVARCHAR(80) , @c_Qty13             NVARCHAR(80)
         , @c_SKU14             NVARCHAR(80) , @c_Qty14             NVARCHAR(80)
         , @c_SKU15             NVARCHAR(80) , @c_Qty15             NVARCHAR(80)
         , @c_SKU16             NVARCHAR(80) , @c_Qty16             NVARCHAR(80)
         , @c_SKU17             NVARCHAR(80) , @c_Qty17             NVARCHAR(80)
         , @c_SKU18             NVARCHAR(80) , @c_Qty18             NVARCHAR(80)
         , @c_SKU19             NVARCHAR(80) , @c_Qty19             NVARCHAR(80)
         , @c_SKU20             NVARCHAR(80) , @c_Qty20             NVARCHAR(80)
         , @c_SKU21             NVARCHAR(80) , @c_Qty21             NVARCHAR(80)
         , @c_SKU22             NVARCHAR(80) , @c_Qty22             NVARCHAR(80)
         , @c_SKU23             NVARCHAR(80) , @c_Qty23             NVARCHAR(80)
         , @c_SKU24             NVARCHAR(80) , @c_Qty24             NVARCHAR(80)
         , @c_SKU25             NVARCHAR(80) , @c_Qty25             NVARCHAR(80)
         , @c_SKU26             NVARCHAR(80) , @c_Qty26             NVARCHAR(80)
         , @c_SKU27             NVARCHAR(80) , @c_Qty27             NVARCHAR(80)
         , @c_SKU28             NVARCHAR(80) , @c_Qty28             NVARCHAR(80)
         , @c_SKU29             NVARCHAR(80) , @c_Qty29             NVARCHAR(80)
         , @c_SKU               NVARCHAR(80)  
         , @c_Qty               NVARCHAR(80)   
         , @c_LabelNo           NVARCHAR(20)  
         , @c_Pickslipno        NVARCHAR(10)  
         , @c_CartonNo          NVARCHAR(10) 
         , @n_intFlag           INT = 1   
         , @n_CntRec            INT = 1
         , @n_TTLpage           INT = 1        
         , @n_CurrentPage       INT = 1 
         , @n_MaxLine           INT = 29
         , @c_Col60             NVARCHAR(80)

   SET @d_Trace_StartTime = GETDATE()        
   SET @c_Trace_ModuleName = ''        
              
    -- SET RowNo = 0  
   SET @c_SQL = ''                 
   SET @c_SQLJOIN = ''   
   SET @c_ExecArguments = ''

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
       [Pickslipno]      [NVARCHAR] (80) NULL,  
       [LabelNo]         [NVARCHAR] (80) NULL,  
       [CartonNo]        [NVARCHAR] (80) NULL,       
       [LabelLine]       [NVARCHAR] (80) NULL,                               
       [SKU]             [NVARCHAR] (80) NULL,  
       [Qty]             [NVARCHAR] (80) NULL,  
       [Retreive]        [NVARCHAR] (80) NULL  
   )                

   --Discrete  
   SELECT TOP 1 @c_Storerkey = ORDERS.Storerkey
              , @c_Col60     = ORDERS.DeliveryNote
   FROM PACKHEADER (NOLOCK)  
   JOIN ORDERS (NOLOCK) ON ORDERS.ORDERKEY = PACKHEADER.ORDERKEY 
   WHERE PACKHEADER.Pickslipno = @c_Sparm01 

   IF ISNULL(@c_Storerkey,'') = ''  
   BEGIN  
      --Conso  
      SELECT TOP 1 @c_Storerkey = ORDERS.Storerkey
                 , @c_Col60     = ORDERS.DeliveryNote
      FROM PACKHEADER (NOLOCK)  
      JOIN LOADPLANDETAIL (NOLOCK) ON PACKHEADER.LOADKEY = LOADPLANDETAIL.LOADKEY  
      JOIN ORDERS (NOLOCK) ON ORDERS.ORDERKEY = LOADPLANDETAIL.ORDERKEY  
      WHERE PACKHEADER.Pickslipno = @c_Sparm01  

      IF ISNULL(@c_Storerkey,'') <> ''  
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

   SET @c_SQLJOIN = + ' SELECT DISTINCT PD.LabelNo, '''', '''', '''', '''', ' + CHAR(13)   --5
                    + ' '''', '''', '''', '''', '''', '   + CHAR(13)   --10 
                    + ' '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', ' + CHAR(13)  --20     
                    + ' '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', ' + CHAR(13)  --30
                    + ' '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', ' + CHAR(13)  --40
                    + ' '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', ' + CHAR(13)  --50
                    + ' '''', '''', '''', '''', '''', '''', '''', '''', '''', @c_Col60 ' + CHAR(13)  --60                
                    + ' FROM PACKDETAIL PD (NOLOCK) ' + CHAR(13)
                    + ' WHERE PD.Pickslipno = @c_Sparm01 ' + CHAR(13)  
                    + ' AND PD.CartonNo = CAST(@c_Sparm02 AS INT) '

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
      
   SET @c_ExecArguments = N'  @c_Sparm01          NVARCHAR(80) '          
                         + ', @c_Sparm02          NVARCHAR(80) '      
                         + ', @c_Sparm03          NVARCHAR(80) ' 
                         + ', @c_Sparm04          NVARCHAR(80) ' 
                         + ', @c_Sparm05          NVARCHAR(80) ' 
                         + ', @c_Col60            NVARCHAR(80) '  
                                
   EXEC sp_ExecuteSql     @c_SQL           
                        , @c_ExecArguments          
                        , @c_Sparm01         
                        , @c_Sparm02     
                        , @c_Sparm03   
                        , @c_Sparm04   
                        , @c_Sparm05   
                        , @c_Col60

   IF @b_debug = 1              
   BEGIN                
      PRINT @c_SQL                
   END     

   DECLARE CUR_RowNoLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   SELECT DISTINCT Col01, @c_Sparm01    
   FROM #Result   
   ORDER BY Col01
   
   OPEN CUR_RowNoLoop     
     
   FETCH NEXT FROM CUR_RowNoLoop INTO @c_LabelNo, @c_Pickslipno 
   
   WHILE @@FETCH_STATUS <> -1   
   BEGIN  
      INSERT INTO #Temp_Packdetail  
      SELECT @c_Pickslipno, @c_LabelNo, PD.CartonNo, PD.LabelLine
           , CAST(TRIM(ISNULL(S.Style,'')) AS NCHAR(20)) + CAST(TRIM(ISNULL(S.Color,'')) AS NCHAR(10)) +
             CAST(TRIM(ISNULL(S.Size,'')) AS NCHAR(10)) + CAST(TRIM(ISNULL(S.ALTSKU,'')) AS NCHAR(20))
           , SUM(PD.Qty), 'N'  
      FROM PACKHEADER PH WITH (NOLOCK)  
      JOIN PACKDETAIL PD WITH (NOLOCK) ON PH.PickSlipNo = PD.Pickslipno        
      JOIN SKU S WITH (NOLOCK) ON S.Sku = PD.SKU AND S.storerkey = PH.Storerkey     
      WHERE PD.PickSlipNo = @c_Pickslipno       
      AND PD.LabelNo = @c_LabelNo  
      GROUP BY PD.CartonNo, PD.LabelLine, PD.SKU
             , CAST(TRIM(ISNULL(S.Style,'')) AS NCHAR(20)) + CAST(TRIM(ISNULL(S.Color,'')) AS NCHAR(10)) +
               CAST(TRIM(ISNULL(S.Size,'')) AS NCHAR(10)) + CAST(TRIM(ISNULL(S.ALTSKU,'')) AS NCHAR(20))
      ORDER BY CAST(PD.LabelLine AS INT)  

      SET @c_SKU01 = '' SET @c_Qty01 = ''
      SET @c_SKU02 = '' SET @c_Qty02 = ''
      SET @c_SKU03 = '' SET @c_Qty03 = ''
      SET @c_SKU04 = '' SET @c_Qty04 = ''
      SET @c_SKU05 = '' SET @c_Qty05 = ''
      SET @c_SKU06 = '' SET @c_Qty06 = ''
      SET @c_SKU07 = '' SET @c_Qty07 = ''
      SET @c_SKU08 = '' SET @c_Qty08 = ''
      SET @c_SKU09 = '' SET @c_Qty09 = ''
      SET @c_SKU10 = '' SET @c_Qty10 = ''
      SET @c_SKU11 = '' SET @c_Qty11 = ''
      SET @c_SKU12 = '' SET @c_Qty12 = ''
      SET @c_SKU13 = '' SET @c_Qty13 = ''
      SET @c_SKU14 = '' SET @c_Qty14 = ''
      SET @c_SKU15 = '' SET @c_Qty15 = ''
      SET @c_SKU16 = '' SET @c_Qty16 = ''
      SET @c_SKU17 = '' SET @c_Qty17 = ''
      SET @c_SKU18 = '' SET @c_Qty18 = ''
      SET @c_SKU19 = '' SET @c_Qty19 = ''
      SET @c_SKU20 = '' SET @c_Qty20 = ''
      SET @c_SKU21 = '' SET @c_Qty21 = ''
      SET @c_SKU22 = '' SET @c_Qty22 = ''
      SET @c_SKU23 = '' SET @c_Qty23 = ''
      SET @c_SKU24 = '' SET @c_Qty24 = ''
      SET @c_SKU25 = '' SET @c_Qty25 = ''
      SET @c_SKU26 = '' SET @c_Qty26 = ''
      SET @c_SKU27 = '' SET @c_Qty27 = ''
      SET @c_SKU28 = '' SET @c_Qty28 = ''
      SET @c_SKU29 = '' SET @c_Qty29 = ''
   
      IF @b_debug = 1  
         SELECT * FROM #Temp_Packdetail  
   
      SELECT @n_CntRec = COUNT (1)    
      FROM #Temp_Packdetail  
      WHERE Pickslipno = @c_Pickslipno  
      AND LabelNo = @c_LabelNo  
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
           
            INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05,Col06,Col07,Col08,Col09                     
           ,Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22                   
           ,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34                    
           ,Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44                     
           ,Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54                   
           ,Col55,Col56,Col57,Col58,Col59,Col60)     
            SELECT TOP 1 Col01,'','','','','','','','','',         
                         '','','','','','','','','','', 
                         '','','','','','','','','','', 
                         '','','','','','','','','','', 
                         '','','','','','','','','','', 
                         '','','','','','','','','',Col60          
            FROM #Result WHERE Col01 <> ''  
   
            SET @c_SKU01 = '' SET @c_Qty01 = ''
            SET @c_SKU02 = '' SET @c_Qty02 = ''
            SET @c_SKU03 = '' SET @c_Qty03 = ''
            SET @c_SKU04 = '' SET @c_Qty04 = ''
            SET @c_SKU05 = '' SET @c_Qty05 = ''
            SET @c_SKU06 = '' SET @c_Qty06 = ''
            SET @c_SKU07 = '' SET @c_Qty07 = ''
            SET @c_SKU08 = '' SET @c_Qty08 = ''
            SET @c_SKU09 = '' SET @c_Qty09 = ''
            SET @c_SKU10 = '' SET @c_Qty10 = ''
            SET @c_SKU11 = '' SET @c_Qty11 = ''
            SET @c_SKU12 = '' SET @c_Qty12 = ''
            SET @c_SKU13 = '' SET @c_Qty13 = ''
            SET @c_SKU14 = '' SET @c_Qty14 = ''
            SET @c_SKU15 = '' SET @c_Qty15 = ''
            SET @c_SKU16 = '' SET @c_Qty16 = ''
            SET @c_SKU17 = '' SET @c_Qty17 = ''
            SET @c_SKU18 = '' SET @c_Qty18 = ''
            SET @c_SKU19 = '' SET @c_Qty19 = ''
            SET @c_SKU20 = '' SET @c_Qty20 = ''
            SET @c_SKU21 = '' SET @c_Qty21 = ''
            SET @c_SKU22 = '' SET @c_Qty22 = ''
            SET @c_SKU23 = '' SET @c_Qty23 = ''
            SET @c_SKU24 = '' SET @c_Qty24 = ''
            SET @c_SKU25 = '' SET @c_Qty25 = ''
            SET @c_SKU26 = '' SET @c_Qty26 = ''
            SET @c_SKU27 = '' SET @c_Qty27 = ''
            SET @c_SKU28 = '' SET @c_Qty28 = ''
            SET @c_SKU29 = '' SET @c_Qty29 = ''
         END  
   
         SELECT   @c_SKU               = SKU      
                , @c_Qty               = Qty  
         FROM #Temp_Packdetail   
         WHERE ID = @n_intFlag  
   
         IF (@n_intFlag % @n_MaxLine) = 1
         BEGIN   
            SET @c_SKU01      = @c_SKU              
            SET @c_Qty01      = @c_Qty  
         END     
         ELSE IF (@n_intFlag % @n_MaxLine) = 2  
         BEGIN     
            SET @c_SKU02      = @c_SKU        
            SET @c_Qty02      = @c_Qty        
         END    
         ELSE IF (@n_intFlag % @n_MaxLine) = 3  
         BEGIN     
            SET @c_SKU03      = @c_SKU        
            SET @c_Qty03      = @c_Qty      
         END   
         ELSE IF (@n_intFlag % @n_MaxLine) = 4  
         BEGIN     
            SET @c_SKU04      = @c_SKU        
            SET @c_Qty04      = @c_Qty        
         END   
         ELSE IF (@n_intFlag % @n_MaxLine) = 5 
         BEGIN     
            SET @c_SKU05      = @c_SKU        
            SET @c_Qty05      = @c_Qty        
         END 
         ELSE IF (@n_intFlag % @n_MaxLine) = 6  
         BEGIN     
            SET @c_SKU06      = @c_SKU        
            SET @c_Qty06      = @c_Qty        
         END 
         ELSE IF (@n_intFlag % @n_MaxLine) = 7  
         BEGIN     
            SET @c_SKU07      = @c_SKU        
            SET @c_Qty07      = @c_Qty        
         END 
         ELSE IF (@n_intFlag % @n_MaxLine) = 8  
         BEGIN     
            SET @c_SKU08      = @c_SKU        
            SET @c_Qty08      = @c_Qty        
         END 
         ELSE IF (@n_intFlag % @n_MaxLine) = 9  
         BEGIN     
            SET @c_SKU09      = @c_SKU        
            SET @c_Qty09      = @c_Qty        
         END 
         ELSE IF (@n_intFlag % @n_MaxLine) = 10  
         BEGIN     
            SET @c_SKU10      = @c_SKU        
            SET @c_Qty10      = @c_Qty        
         END 
         ELSE IF (@n_intFlag % @n_MaxLine) = 11 
         BEGIN     
            SET @c_SKU11      = @c_SKU        
            SET @c_Qty11      = @c_Qty        
         END 
         ELSE IF (@n_intFlag % @n_MaxLine) = 12  
         BEGIN     
            SET @c_SKU12      = @c_SKU        
            SET @c_Qty12      = @c_Qty        
         END 
         ELSE IF (@n_intFlag % @n_MaxLine) = 13  
         BEGIN     
            SET @c_SKU13      = @c_SKU        
            SET @c_Qty13      = @c_Qty        
         END 
         ELSE IF (@n_intFlag % @n_MaxLine) = 14  
         BEGIN     
            SET @c_SKU14      = @c_SKU        
            SET @c_Qty14      = @c_Qty        
         END 
         ELSE IF (@n_intFlag % @n_MaxLine) = 15 
         BEGIN     
            SET @c_SKU15      = @c_SKU        
            SET @c_Qty15      = @c_Qty        
         END 
         ELSE IF (@n_intFlag % @n_MaxLine) = 16 
         BEGIN     
            SET @c_SKU16      = @c_SKU        
            SET @c_Qty16      = @c_Qty        
         END 
         ELSE IF (@n_intFlag % @n_MaxLine) = 17  
         BEGIN     
            SET @c_SKU17      = @c_SKU        
            SET @c_Qty17      = @c_Qty        
         END 
         ELSE IF (@n_intFlag % @n_MaxLine) = 18  
         BEGIN     
            SET @c_SKU18      = @c_SKU        
            SET @c_Qty18      = @c_Qty        
         END 
         ELSE IF (@n_intFlag % @n_MaxLine) = 19  
         BEGIN     
            SET @c_SKU19      = @c_SKU        
            SET @c_Qty19      = @c_Qty        
         END 
         ELSE IF (@n_intFlag % @n_MaxLine) = 20  
         BEGIN     
            SET @c_SKU20      = @c_SKU        
            SET @c_Qty20      = @c_Qty        
         END 
         ELSE IF (@n_intFlag % @n_MaxLine) = 21  
         BEGIN     
            SET @c_SKU21      = @c_SKU        
            SET @c_Qty21      = @c_Qty        
         END 
         ELSE IF (@n_intFlag % @n_MaxLine) = 22  
         BEGIN     
            SET @c_SKU22      = @c_SKU        
            SET @c_Qty22      = @c_Qty        
         END 
         ELSE IF (@n_intFlag % @n_MaxLine) = 23  
         BEGIN     
            SET @c_SKU23      = @c_SKU        
            SET @c_Qty23      = @c_Qty        
         END 
         ELSE IF (@n_intFlag % @n_MaxLine) = 24  
         BEGIN     
            SET @c_SKU24      = @c_SKU        
            SET @c_Qty24      = @c_Qty        
         END 
         ELSE IF (@n_intFlag % @n_MaxLine) = 25  
         BEGIN     
            SET @c_SKU25      = @c_SKU        
            SET @c_Qty25      = @c_Qty        
         END 
         ELSE IF (@n_intFlag % @n_MaxLine) = 26  
         BEGIN     
            SET @c_SKU26      = @c_SKU        
            SET @c_Qty26      = @c_Qty        
         END 
         ELSE IF (@n_intFlag % @n_MaxLine) = 27  
         BEGIN     
            SET @c_SKU27      = @c_SKU        
            SET @c_Qty27      = @c_Qty        
         END 
         ELSE IF (@n_intFlag % @n_MaxLine) = 28  
         BEGIN     
            SET @c_SKU28      = @c_SKU        
            SET @c_Qty28      = @c_Qty        
         END 
         ELSE IF (@n_intFlag % @n_MaxLine) = 0
         BEGIN     
            SET @c_SKU29      = @c_SKU              
            SET @c_Qty29      = @c_Qty      
         END       
         
         UPDATE #Result  
         SET   Col02 = @c_SKU01 , Col31 = @c_Qty01
             , Col03 = @c_SKU02 , Col32 = @c_Qty02
             , Col04 = @c_SKU03 , Col33 = @c_Qty03
             , Col05 = @c_SKU04 , Col34 = @c_Qty04
             , Col06 = @c_SKU05 , Col35 = @c_Qty05
             , Col07 = @c_SKU06 , Col36 = @c_Qty06  
             , Col08 = @c_SKU07 , Col37 = @c_Qty07  
             , Col09 = @c_SKU08 , Col38 = @c_Qty08  
             , Col10 = @c_SKU09 , Col39 = @c_Qty09
             , Col11 = @c_SKU10 , Col40 = @c_Qty10
             , Col12 = @c_SKU11 , Col41 = @c_Qty11  
             , Col13 = @c_SKU12 , Col42 = @c_Qty12  
             , Col14 = @c_SKU13 , Col43 = @c_Qty13
             , Col15 = @c_SKU14 , Col44 = @c_Qty14
             , Col16 = @c_SKU15 , Col45 = @c_Qty15
             , Col17 = @c_SKU16 , Col46 = @c_Qty16
             , Col18 = @c_SKU17 , Col47 = @c_Qty17
             , Col19 = @c_SKU18 , Col48 = @c_Qty18
             , Col20 = @c_SKU19 , Col49 = @c_Qty19
             , Col21 = @c_SKU20 , Col50 = @c_Qty20
             , Col22 = @c_SKU21 , Col51 = @c_Qty21
             , Col23 = @c_SKU22 , Col52 = @c_Qty22
             , Col24 = @c_SKU23 , Col53 = @c_Qty23
             , Col25 = @c_SKU24 , Col54 = @c_Qty24
             , Col26 = @c_SKU25 , Col55 = @c_Qty25
             , Col27 = @c_SKU26 , Col56 = @c_Qty26
             , Col28 = @c_SKU27 , Col57 = @c_Qty27
             , Col29 = @c_SKU28 , Col58 = @c_Qty28
             , Col30 = @c_SKU29 , Col59 = @c_Qty29
         WHERE ID = @n_CurrentPage AND Col01 <> ''  

         UPDATE #Temp_Packdetail  
         SET Retreive = 'Y'  
         WHERE ID = @n_intFlag  
   
         SET @n_intFlag = @n_intFlag + 1  
        
         IF @n_intFlag > @n_CntRec    
         BEGIN    
            BREAK;    
         END    
      END  
   
      FETCH NEXT FROM CUR_RowNoLoop INTO @c_LabelNo, @c_Pickslipno   
   END  
   CLOSE CUR_RowNoLoop  
   DEALLOCATE CUR_RowNoLoop     
                 
   SELECT * FROM #Result (nolock)            
                  
EXIT_SP:                 
                              
END -- procedure

GO