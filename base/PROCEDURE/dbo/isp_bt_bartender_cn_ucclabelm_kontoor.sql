SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/                   
/* Copyright: LFL                                                             */                   
/* Purpose: isp_BT_Bartender_CN_UCCLabelM_Kontoor                             */                   
/*                                                                            */                   
/* Modifications log:                                                         */                   
/*                                                                            */                   
/* Date       Rev  Author     Purposes                                        */  
/*20-Mar-2020 1.0  WLChooi	  Created (WMS-12571)                              */  
/*03-Aug-2020 1.1  WLChooi	  Bug Fix (WL01)                                   */  
/******************************************************************************/                  
                    
CREATE PROC [dbo].[isp_BT_Bartender_CN_UCCLabelM_Kontoor]                        
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
 --  SET ANSI_WARNINGS OFF                    --CS01             
                                
DECLARE                    
      @c_ReceiptKey      NVARCHAR(10),                           
      @n_intFlag         INT,       
      @n_CntRec          INT,      
      @c_SQL             NVARCHAR(4000),          
      @c_SQLSORT         NVARCHAR(4000),          
      @c_SQLJOIN         NVARCHAR(4000),  
      @c_ExecStatements  NVARCHAR(4000),         
      @c_ExecArguments   NVARCHAR(4000),     
   
      @c_Style01         NVARCHAR(80),   
      @c_Qty01           NVARCHAR(80),  
      @c_Style02         NVARCHAR(80),   
      @c_Qty02           NVARCHAR(80),  
      @c_Style03         NVARCHAR(80),   
      @c_Qty03           NVARCHAR(80),  
      @c_Style04         NVARCHAR(80),  
      @c_Qty04           NVARCHAR(80),  
      @c_Style05         NVARCHAR(80), 
      @c_Qty05           NVARCHAR(80),
      @c_Style06         NVARCHAR(80), 
      @c_Qty06           NVARCHAR(80),  
      @c_Style07         NVARCHAR(80), 
      @c_Qty07           NVARCHAR(80),  
      @c_Style08         NVARCHAR(80), 
      @c_Qty08           NVARCHAR(80),  
      @c_Style09         NVARCHAR(80), 
      @c_Qty09           NVARCHAR(80),  
 
      @c_Style           NVARCHAR(80),  
      @c_Qty             NVARCHAR(80),  
        
      @c_CheckConso      NVARCHAR(10),  
      @c_GetOrderkey     NVARCHAR(10),  
        
      @n_TTLpage         INT,            
      @n_CurrentPage     INT,    
      @n_MaxLine         INT,  
        
      @c_LabelNo         NVARCHAR(30),  
      @c_Pickslipno      NVARCHAR(10),  
      @c_CartonNo        NVARCHAR(10),  
      @n_SumQty          INT,  
      @c_Sorting         NVARCHAR(4000),  
      @c_ExtraSQL        NVARCHAR(4000),  
      @c_JoinStatement   NVARCHAR(4000),
      
      @n_MaxCarton       INT,
      @n_TTLPageAll      INT,
      @n_CntRecAll       INT   
      
  DECLARE  @d_Trace_StartTime   DATETIME,     
           @d_Trace_EndTime    DATETIME,    
           @c_Trace_ModuleName NVARCHAR(20),     
           @d_Trace_Step1      DATETIME,     
           @c_Trace_Step1      NVARCHAR(20),    
           @c_UserName         NVARCHAR(20)       
    
   SET @d_Trace_StartTime = GETDATE()    
   SET @c_Trace_ModuleName = ''   
     
   SET @n_CurrentPage = 1    
   SET @n_TTLpage = 1         
   SET @n_MaxLine = 9       
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

   CREATE TABLE #Temp_Packdetail (  
      [ID]         [INT] IDENTITY(1,1) NOT NULL,         
      [Pickslipno] [NVARCHAR] (80) NULL,  
      [LabelNo]    [NVARCHAR] (80) NULL,  
      [CartonNo]   [NVARCHAR] (80) NULL,       
      [LabelLine]  [NVARCHAR] (80) NULL,                               
      [Style]      [NVARCHAR] (80) NULL,  
      [Qty]        [NVARCHAR] (80) NULL,  
      [Retreive]   [NVARCHAR] (80) NULL  
   )           
  
   SET @c_Sorting = N' ORDER BY PD.Pickslipno, PD.CartonNo DESC '  
     
   SET @c_SQLJOIN = + ' SELECT DISTINCT PD.LabelNo, OH.ExternOrderkey, PD.Pickslipno, PD.CartonNo, CONVERT(NVARCHAR(16), GETDATE(), 120) ,  ' + CHAR(13)    --5 
                    + ' ISNULL(OH.C_Country,''''), LEFT(LTRIM(RTRIM(ISNULL(OH.C_Address4,''''))) + LTRIM(RTRIM(ISNULL(OH.C_Address3,''''))),80), ' + CHAR(13) --7
                    + ' LEFT(LTRIM(RTRIM(ISNULL(OH.C_Address2,''''))) + LTRIM(RTRIM(ISNULL(OH.C_Company,''''))),80), ' + CHAR(13) --8
                    + ' ''B'', OH.Consigneekey, ' + CHAR(13)  --10 
                    + ' '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', ' + CHAR(13)    --20 
                    + ' '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', ' + CHAR(13)    --30 
                    + ' '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', ' + CHAR(13)    --40 
                    + ' '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', ' + CHAR(13)    --50 
                    + ' '''', '''', '''', '''', '''', '''', '''', '''', '''', '''' '  + CHAR(13)    --60 
         
                    + CHAR(13) +              
                    + ' FROM PACKHEADER PH WITH (NOLOCK)'        + CHAR(13)  
                    + ' JOIN PACKDETAIL PD WITH (NOLOCK) ON PH.Pickslipno = PD.Pickslipno'   + CHAR(13)  
                    +   @c_JoinStatement  
                    --+ ' LEFT JOIN STORER ST WITH (NOLOCK) ON ST.STORERKEY = OH.Consigneekey ' + CHAR(13)  
                    + ' WHERE PD.Pickslipno = @c_Sparm01 '   + CHAR(13)    
                    + ' AND PD.CartonNo BETWEEN CAST(@c_Sparm02 AS INT) AND CAST(@c_Sparm03 AS INT) ' + CHAR(13)   
                    + @c_Sorting  
         
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
  
   SET @c_ExecArguments = N'   @c_Sparm01          NVARCHAR(80) '      
                         + ',  @c_Sparm02          NVARCHAR(80) '      
                         + ',  @c_Sparm03          NVARCHAR(80) ' 
                         + ',  @c_Sparm04          NVARCHAR(80) ' 
                         + ',  @c_Sparm05          NVARCHAR(80) ' 
                         + ',  @c_Sparm06          NVARCHAR(80) ' 
                                              
   EXEC sp_ExecuteSql     @c_SQL       
                        , @c_ExecArguments      
                        , @c_Sparm01     
                        , @c_Sparm02  
                        , @c_Sparm03
                        , @c_Sparm04
                        , @c_Sparm05
                        , @c_Sparm06

   DECLARE CUR_RowNoLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   SELECT DISTINCT col01,col03,CAST(col04 AS INT)      
   FROM #Result    
   ORDER BY col03, CAST(col04 AS INT)  
   
   OPEN CUR_RowNoLoop     
     
   FETCH NEXT FROM CUR_RowNoLoop INTO @c_LabelNo, @c_Pickslipno, @c_CartonNo   
   
   WHILE @@FETCH_STATUS <> -1   
   BEGIN  
      INSERT INTO #Temp_Packdetail  
      SELECT TOP (@n_MaxLine) @c_Pickslipno, @c_LabelNo, @c_CartonNo, PD.LabelLine, PD.SKU, SUM(PD.Qty), 'N'  
      FROM PACKHEADER PH WITH (NOLOCK)  
      JOIN PACKDETAIL PD WITH (NOLOCK) ON PH.PickSlipNo = PD.Pickslipno        
      --JOIN SKU S WITH (NOLOCK) ON S.Sku = PD.SKU AND S.storerkey = PH.Storerkey     
      WHERE PD.PickSlipNo = @c_Pickslipno     
      AND PD.CartonNo = CAST(@c_CartonNo AS INT)  
      AND PD.LabelNo = @c_LabelNo  
      GROUP BY PD.LabelLine, PD.SKU
      ORDER BY CAST(PD.LabelLine AS INT)  
   
      SET @c_Style01    = ''  
      SET @c_Qty01      = ''  
      SET @c_Style02    = ''  
      SET @c_Qty02      = ''  
      SET @c_Style03    = ''  
      SET @c_Qty03      = ''  
      SET @c_Style04    = ''  
      SET @c_Qty04      = ''  
      SET @c_Style05    = ''  
      SET @c_Qty05      = ''  
      SET @c_Style06    = ''  
      SET @c_Qty06      = ''  
      SET @c_Style07    = ''  
      SET @c_Qty07      = ''  
      SET @c_Style08    = ''  
      SET @c_Qty08      = ''
      SET @c_Style09    = ''
      SET @c_Qty09      = ''

      IF @b_debug = 1  
         SELECT * FROM #Temp_Packdetail  
   
      SELECT @n_CntRec = COUNT (1)    
      FROM #Temp_Packdetail  
      WHERE Pickslipno = @c_Pickslipno  
      AND LabelNo = @c_LabelNo  
      AND CartonNo = @c_CartonNo  
      AND Retreive = 'N'  

      SELECT @n_CntRecAll = COUNT(DISTINCT LabelLine)
      FROM PACKDETAIL (NOLOCK)
      WHERE Pickslipno = @c_Pickslipno  
      AND LabelNo = @c_LabelNo  
      AND CartonNo = @c_CartonNo  

      SET @n_CntRecAll = @n_CntRecAll - 9
      SET @n_TTLPageAll = FLOOR(@n_CntRecAll / 17 ) + CASE WHEN @n_CntRecAll % 17 > 0 THEN 1 ELSE 0 END + 1   --WL01  
      --select @n_TTLPageAll

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
            SELECT TOP 1 Col01,Col02,Col03,Col04,Col05,Col06,Col07,Col08,Col09,Col10,         
                        '','','','','', '','','','','',  
                        '','','','','','','','','','',                  
                        '','','','','', '','','','','',                    
                        '','','','','', '','','','','',                   
                        '','','','','', '','','','',''   
            FROM #Result WHERE col03 <> ''  
   
            SET @c_Style01    = ''
            SET @c_Qty01      = ''
            SET @c_Style02    = ''
            SET @c_Qty02      = ''
            SET @c_Style03    = ''
            SET @c_Qty03      = ''
            SET @c_Style04    = ''
            SET @c_Qty04      = ''
            SET @c_Style05    = ''
            SET @c_Qty05      = ''
            SET @c_Style06    = ''
            SET @c_Qty06      = ''
            SET @c_Style07    = ''
            SET @c_Qty07      = ''
            SET @c_Style08    = ''
            SET @c_Qty08      = ''
            SET @c_Style09    = ''
            SET @c_Qty09      = ''      
         END  
   
         SELECT   @c_Style      = Style     
                , @c_Qty        = Qty    
          FROM #Temp_Packdetail   
          WHERE ID = @n_intFlag  
   
          IF (@n_intFlag % @n_MaxLine) = 1 --AND @n_recgrp = @n_CurrentPage    
          BEGIN         
             SET @c_Style01    = @c_Style       
             SET @c_Qty01      = @c_Qty  
          END     
          ELSE IF (@n_intFlag % @n_MaxLine) = 2 --AND @n_recgrp = @n_CurrentPage    
          BEGIN            
             SET @c_Style02    = @c_Style       
             SET @c_Qty02      = @c_Qty             
          END    
          ELSE IF (@n_intFlag % @n_MaxLine) = 3 --AND @n_recgrp = @n_CurrentPage    
          BEGIN            
             SET @c_Style03    = @c_Style       
             SET @c_Qty03      = @c_Qty             
          END   
          ELSE IF (@n_intFlag % @n_MaxLine) = 4 --AND @n_recgrp = @n_CurrentPage    
          BEGIN             
             SET @c_Style04    = @c_Style       
             SET @c_Qty04      = @c_Qty             
          END  
          ELSE IF (@n_intFlag % @n_MaxLine) = 5 --AND @n_recgrp = @n_CurrentPage    
          BEGIN             
             SET @c_Style05    = @c_Style       
             SET @c_Qty05      = @c_Qty             
          END  
          ELSE IF (@n_intFlag % @n_MaxLine) = 6 --AND @n_recgrp = @n_CurrentPage    
          BEGIN             
             SET @c_Style06    = @c_Style       
             SET @c_Qty06      = @c_Qty             
          END  
          ELSE IF (@n_intFlag % @n_MaxLine) = 7 --AND @n_recgrp = @n_CurrentPage    
          BEGIN             
             SET @c_Style07    = @c_Style       
             SET @c_Qty07      = @c_Qty             
          END  
          ELSE IF (@n_intFlag % @n_MaxLine) = 8 --AND @n_recgrp = @n_CurrentPage    
          BEGIN             
             SET @c_Style08    = @c_Style       
             SET @c_Qty08      = @c_Qty             
          END   
          ELSE IF (@n_intFlag % @n_MaxLine) = 0 --AND @n_recgrp = @n_CurrentPage    
          BEGIN            
             SET @c_Style09    = @c_Style       
             SET @c_Qty09      = @c_Qty             
          END       
   
          UPDATE #Result  
          SET   Col12 = @c_Style01     
              , Col13 = @c_Qty01      
              , Col14 = @c_Style02        
              , Col15 = @c_Qty02      
              , Col16 = @c_Style03 
              , Col17 = @c_Qty03     
              , Col18 = @c_Style04        
              , Col19 = @c_Qty04      
              , Col20 = @c_Style05      
              , Col21 = @c_Qty05      
              , Col22 = @c_Style06      
              , Col23 = @c_Qty06      
              , Col24 = @c_Style07       
              , Col25 = @c_Qty07     
              , Col26 = @c_Style08
              , Col27 = @c_Qty08
              , Col28 = @c_Style09
              , Col29 = @c_Qty09
              , Col60 = CAST(@n_CurrentPage AS NVARCHAR(10)) + '/' + CAST(@n_TTLPageAll AS NVARCHAR(10))  
         WHERE ID = @n_CurrentPage AND col03 <> ''  
   
         UPDATE #Temp_Packdetail  
         SET Retreive = 'Y'  
         WHERE ID = @n_intFlag  
   
         SET @n_intFlag = @n_intFlag + 1  
        
         IF @n_intFlag > @n_CntRec    
         BEGIN    
            BREAK;    
         END    
      END  
   
      SELECT @n_SumQty = SUM(PD.Qty)  
      FROM PACKDETAIL PD (NOLOCK)  
      WHERE PD.PickSlipNo = @c_Pickslipno  
      AND PD.LabelNo = @c_LabelNo  
      AND PD.CartonNo = @c_CartonNo  
   
      UPDATE #Result  
      SET Col11 = @n_SumQty  
      WHERE Col03 = @c_Pickslipno  
      AND Col01 = @c_LabelNo  
      AND Col04 = @c_CartonNo  

      SELECT @n_MaxCarton = MAX(CartonNo)
      FROM PACKDETAIL (NOLOCK)
      WHERE PICKSLIPNO = @c_Sparm01

      UPDATE #Result
      SET Col04 = Col04 + '-' + CAST(@n_MaxCarton AS NVARCHAR(5) )
      WHERE Col03 = @c_Pickslipno   
      AND Col04 = @n_MaxCarton 
   
      FETCH NEXT FROM CUR_RowNoLoop INTO @c_LabelNo, @c_Pickslipno, @c_CartonNo   
   END  
   CLOSE CUR_RowNoLoop  
   DEALLOCATE CUR_RowNoLoop  

   IF @b_debug=1          
   BEGIN            
      PRINT @c_SQL           
   END    
        
   IF @b_debug=1          
   BEGIN          
      SELECT * FROM #Result (nolock) where Col60 <> ''           
   END      
            
   SELECT * FROM #Result (nolock) where Col60 <> ''         

EXIT_SP:      
    
   SET @d_Trace_EndTime = GETDATE()    
   SET @c_UserName = SUSER_SNAME()    
       
   EXEC isp_InsertTraceInfo     
      @c_TraceCode = 'BARTENDER',    
      @c_TraceName = 'isp_BT_Bartender_CN_UCCLabelM_Kontoor',    
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