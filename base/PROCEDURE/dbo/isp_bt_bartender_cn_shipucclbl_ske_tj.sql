SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/********************************************************************************/                   
/* Copyright: LFL                                                               */                   
/* Purpose: isp_BT_Bartender_CN_SHIPUCCLBL_SKE_TJ                               */                   
/*                                                                              */                   
/* Modifications log:                                                           */                   
/*                                                                              */                   
/* Date       Rev  Author     Purposes                                          */                   
/* 2020-09-07 1.0  WLChooi    Created (WMS-14927)                               */  
/* 2021-03-04 1.1  WLChooi    WMS-16435 - Update Col04, Remove Col30 (WL01)     */
/********************************************************************************/                  
                    
CREATE PROC [dbo].[isp_BT_Bartender_CN_SHIPUCCLBL_SKE_TJ]                        
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
      @c_SKU01           NVARCHAR(80),    
      @c_Size01          NVARCHAR(80),   
      @c_Qty01           NVARCHAR(80),  
  
      @c_SKU02           NVARCHAR(80),    
      @c_Size02          NVARCHAR(80),   
      @c_Qty02           NVARCHAR(80),  
  
      @c_SKU03           NVARCHAR(80),    
      @c_Size03          NVARCHAR(80),   
      @c_Qty03           NVARCHAR(80),  
  
      @c_SKU04           NVARCHAR(80),    
      @c_Size04          NVARCHAR(80),   
      @c_Qty04           NVARCHAR(80),  
  
      @c_SKU05           NVARCHAR(80),    
      @c_Size05          NVARCHAR(80),   
      @c_Qty05           NVARCHAR(80),  
      
      @c_SKU06           NVARCHAR(80),    
      @c_Size06          NVARCHAR(80),   
      @c_Qty06           NVARCHAR(80), 
      
      @c_SKU07           NVARCHAR(80),    
      @c_Size07          NVARCHAR(80),   
      @c_Qty07           NVARCHAR(80), 
      
      @c_SKU08           NVARCHAR(80),    
      @c_Size08          NVARCHAR(80),   
      @c_Qty08           NVARCHAR(80), 
      
      @c_SKU09           NVARCHAR(80),    
      @c_Size09          NVARCHAR(80),   
      @c_Qty09           NVARCHAR(80), 
      
      @c_SKU10           NVARCHAR(80),    
      @c_Size10          NVARCHAR(80),   
      @c_Qty10           NVARCHAR(80), 
  
      @c_SKU             NVARCHAR(80),  
      @c_Size            NVARCHAR(80),  
      @c_Qty             NVARCHAR(80),  
        
      @c_CheckConso      NVARCHAR(10),  
      @c_GetOrderkey     NVARCHAR(10),  
        
      @n_TTLpage         INT,            
      @n_CurrentPage     INT,    
      @n_MaxLine         INT,  
        
      @c_LabelNo            NVARCHAR(30),  
      @c_Pickslipno         NVARCHAR(10),  
      @c_CartonNo           NVARCHAR(10),  
      @n_SumQty             INT,  
      @c_Sorting            NVARCHAR(4000),  
      @c_ExtraSQL           NVARCHAR(4000),  
      @c_JoinStatement      NVARCHAR(4000),
      @c_AllExtOrderkey     NVARCHAR(80) = '',   --WL01 
      @c_Col26              NVARCHAR(80) = '',   --WL01   
      @c_Col02              NVARCHAR(80) = '',   --WL01   
      @c_Col03              NVARCHAR(80) = '',   --WL01   
      @c_Col05              NVARCHAR(80) = '',   --WL01   
      @c_Col06              NVARCHAR(80) = '',   --WL01    
      @c_Storerkey          NVARCHAR(15) = ''    --WL01          

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
   SET @n_MaxLine = 10        
   SET @n_CntRec = 1      
   SET @n_intFlag = 1    
   SET @c_ExtraSQL = ''  
   SET @c_JoinStatement = ''  
  
   SET @c_CheckConso = 'N'  
      
-- SET RowNo = 0               
   SET @c_SQL = ''         

   --Discrete  
   SELECT TOP 1 @c_GetOrderkey = ORDERS.Orderkey, 
                @c_Col26       = ISNULL(ORDERS.Notes,''),   --WL01
                @c_Col02       = SUBSTRING(LTRIM(RTRIM(ISNULL(ORDERS.C_State,''))),1,4),   --WL01
                @c_Col03       = '(' + SUBSTRING(LTRIM(RTRIM(ISNULL(ORDERS.C_City,''))),1,4) + ')',   --WL01
                @c_Col05       = LTRIM(RTRIM(ISNULL(ORDERS.C_Company,''))),   --WL01
                @c_Col06       = LEFT(LTRIM(RTRIM(ISNULL(ORDERS.C_Address1,''))) + ' ' + LTRIM(RTRIM(ISNULL(ORDERS.C_Address2,''))),80),   --WL01 
                @c_Storerkey   = ORDERS.Storerkey   --WL01
   FROM PACKHEADER (NOLOCK)  
   JOIN ORDERS (NOLOCK) ON ORDERS.ORDERKEY = PACKHEADER.ORDERKEY  
   WHERE PACKHEADER.Pickslipno = @c_Sparm01  
  
   IF ISNULL(@c_GetOrderkey,'') = ''  
   BEGIN  
      --Conso  
      SELECT TOP 1 @c_GetOrderkey = ORDERS.Orderkey,
                   @c_Col26       = ISNULL(ORDERS.Notes,''),   --WL01
                   @c_Col02       = SUBSTRING(LTRIM(RTRIM(ISNULL(ORDERS.C_State,''))),1,4),   --WL01
                   @c_Col03       = '(' + SUBSTRING(LTRIM(RTRIM(ISNULL(ORDERS.C_City,''))),1,4) + ')',   --WL01
                   @c_Col05       = LTRIM(RTRIM(ISNULL(ORDERS.C_Company,''))),   --WL01
                   @c_Col06       = LEFT(LTRIM(RTRIM(ISNULL(ORDERS.C_Address1,''))) + ' ' + LTRIM(RTRIM(ISNULL(ORDERS.C_Address2,''))),80),   --WL01
                   @c_Storerkey   = ORDERS.Storerkey   --WL01
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
   
   --WL01 S
   IF @c_CheckConso = 'Y'  
   BEGIN  
      SELECT @c_AllExtOrderkey = CAST(STUFF((SELECT DISTINCT TOP 5 ',' + RTRIM(OH.ExternOrderkey) 
                                 FROM PACKHEADER PH (NOLOCK)
                                 JOIN LOADPLANDETAIL LPD (NOLOCK) ON LPD.LoadKey = PH.LoadKey
                                 JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = LPD.OrderKey
                                 WHERE PH.PickSlipNo = @c_Sparm01
                                 ORDER BY ',' + RTRIM(OH.ExternOrderkey) FOR XML PATH('')),1,1,'' ) AS NVARCHAR(80))
   END 
   ELSE
   BEGIN
      SELECT @c_AllExtOrderkey = MAX(OH.ExternOrderkey)
      FROM PACKHEADER PH (NOLOCK)
      JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = PH.Orderkey
      WHERE PH.PickSlipNo = @c_Sparm01
   END

   SELECT @c_Col26 = LEFT(LTRIM(RTRIM(@c_Col26)), 80)
   --WL01 E
     
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
       [ID]              [INT] IDENTITY(1,1) NOT NULL,         
       [Pickslipno]      [NVARCHAR] (80) NULL,  
       [LabelNo]         [NVARCHAR] (80) NULL,  
       [CartonNo]        [NVARCHAR] (80) NULL,       
       [LabelLine]       [NVARCHAR] (80) NULL,                               
       [SKU]             [NVARCHAR] (80) NULL,  
       [Size]            [NVARCHAR] (80) NULL,  
       [Qty]             [NVARCHAR] (80) NULL,  
       [Retreive]        [NVARCHAR] (80) NULL  
      )           
  
      SET @c_Sorting = N' ORDER BY PH.Pickslipno, PD.CartonNo DESC '  
  
      IF @c_Sparm10 = 'BARCODE'  
      BEGIN  
         SET @c_SQLJOIN = ' SELECT DISTINCT ' + CHAR(13)  
                        + ' '''','''','''','''','''','''','''','''','''','''', ' + CHAR(13)  
                        + ' '''','''','''','''','''','''','''','''','''','''', ' + CHAR(13)  
                        + ' '''','''','''','''','''','''','''','''','''','''', ' + CHAR(13)  
                        + ' '''','''','''','''','''','''','''','''','''','''', ' + CHAR(13)  
                        + ' '''','''','''','''','''','''','''','''','''','''', ' + CHAR(13)  
                        + ' '''','''','''','''','''','''','''',LabelNo,'''',''Barcode'' '  
                        + ' FROM PACKDETAIL (NOLOCK) ' + CHAR(13)  
                        + ' WHERE Pickslipno = @c_Sparm01 '  + CHAR(13)  
                        + ' AND CartonNo BETWEEN CAST(@c_Sparm02 AS INT) AND CAST(@c_Sparm03 AS INT) '  
         SET @c_ExtraSQL = ' UNION ALL '  
      END  
      ELSE  
      --WL01 S 
      BEGIN  
         SET @c_SQLJOIN = + ' SELECT DISTINCT OH.Loadkey, @c_Col02, '
                          + ' @c_Col03, ' + CHAR(13) --3
                          + ' @c_AllExtOrderkey, '
                          + ' @c_Col05, ' + CHAR(13) --5
                          + ' @c_Col06, ' + CHAR(13) --6
                          + ' '''' ,'''' ,'''' ,'''' , ' + CHAR(13) --10   
                          + ' '''' ,'''' ,'''' ,'''' ,'''' ,'''' ,'''' ,'''' ,'''' ,'''' ,'  + CHAR(13) --20         
                          + ' '''' ,PD.LabelNo ,PD.CartonNo ,CONVERT(NVARCHAR(80),MAX(PD.EditDate),120), ' + CHAR(13) --24
                          + ' '''' ,@c_Col26 ,'''' ,'''' ,ISNULL(ST.B_Address4,''''), ' + CHAR(13) --29
                          + ' '''', '
                          + ' '''' ,'''' ,'''' ,'''' ,'''' ,'''' ,'''' ,'''' ,'''' ,'''' ,'  + CHAR(13) --40
                          + ' '''' ,'''' ,'''' ,'''' ,'''' ,'''' ,'''' ,'''' ,'''' ,'''' , ' + CHAR(13) --50         
                          + ' '''' ,'''' ,'''' ,'''' ,'''' ,'''' ,'''' ,'''' ,PH.Pickslipno ,''CN'' '  --60         
                          + CHAR(13) +              
                          + ' FROM PACKHEADER PH WITH (NOLOCK)'        + CHAR(13)  
                          + ' JOIN PACKDETAIL PD WITH (NOLOCK) ON PH.Pickslipno = PD.Pickslipno'   + CHAR(13)
                          +   @c_JoinStatement  
                          + ' LEFT JOIN STORER ST WITH (NOLOCK) ON ST.STORERKEY = OH.Consigneekey ' + CHAR(13)
                          + ' WHERE PH.Pickslipno = @c_Sparm01 '   + CHAR(13)    
                          + ' AND PD.CartonNo BETWEEN CAST(@c_Sparm02 AS INT) AND CAST(@c_Sparm03 AS INT) ' + CHAR(13)  
                          + ' GROUP BY OH.Loadkey, ' +
                          + ' PD.LabelNo ,PD.CartonNo , PH.Pickslipno, ISNULL(ST.B_Address4,'''') ' + CHAR(13)  
                          + @c_Sorting  
      END   
      /*BEGIN  
         SET @c_SQLJOIN = + ' SELECT DISTINCT OH.Loadkey, SUBSTRING(LTRIM(RTRIM(ISNULL(OH.C_State,''''))),1,4), '  
                          + ' ''('' + SUBSTRING(LTRIM(RTRIM(ISNULL(OH.C_City,''''))),1,4) + '')'', ' + CHAR(13) --3    
                          + ' CASE WHEN MAX(OH.ExternOrderKey) LIKE ''SA%'' THEN SUBSTRING(LTRIM(RTRIM(MAX(OH.ExternOrderKey))),1,LEN(LTRIM(RTRIM(MAX(OH.ExternOrderKey)))) - 4)   
                              ELSE MAX(OH.ExternOrderKey) END, ' + CHAR(13) --4  
                          + ' LTRIM(RTRIM(ISNULL(OH.C_Company,''''))), ' + CHAR(13)   --5    
                          + ' LEFT(LTRIM(RTRIM(ISNULL(OH.C_Address1,''''))) + '' '' + LTRIM(RTRIM(ISNULL(OH.C_Address2,''''))),80), ' + CHAR(13) --6  
                          + ' '''' ,'''' ,'''' ,'''' , ' + CHAR(13) --10   
                          + ' '''' ,'''' ,'''' ,'''' ,'''' ,'''' ,'''' ,'''' ,'''' ,'''' ,'  + CHAR(13) --20         
                          + ' '''' ,PD.LabelNo ,PD.CartonNo ,CONVERT(NVARCHAR(80),MAX(PD.EditDate),120), ' + CHAR(13) --24  
                          + ' '''' ,MAX(SUBSTRING(OH.Notes, 1, 80)) ,'''' ,'''' ,ISNULL(ST.B_Address4,''''), ' + CHAR(13) -- 29    
                          + ' CASE WHEN MAX(OH.ExternOrderKey) LIKE ''SA%'' THEN RIGHT(LTRIM(RTRIM(MAX(OH.ExternOrderKey))),4) ELSE '''' END,'  + CHAR(13) --30     
                          + ' MAX(OH.ExternOrderKey) ,'''' ,'''' ,'''' ,'''' ,'''' ,'''' ,'''' ,'''' ,'''' ,'  + CHAR(13) --40         
                          + ' '''' ,'''' ,'''' ,'''' ,'''' ,'''' ,'''' ,'''' ,'''' ,'''' , ' + CHAR(13) --50         
                          + ' '''' ,'''' ,'''' ,'''' ,'''' ,'''' ,'''' ,'''' ,PD.Pickslipno ,''CN'' '  --60            
                          + CHAR(13) +              
                          + ' FROM PACKHEADER PH WITH (NOLOCK)'        + CHAR(13)  
                          + ' JOIN PACKDETAIL PD WITH (NOLOCK) ON PH.Pickslipno = PD.Pickslipno'   + CHAR(13)  
                          +   @c_JoinStatement  
                          + ' LEFT JOIN STORER ST WITH (NOLOCK) ON ST.STORERKEY = OH.Consigneekey ' + CHAR(13)   
                          + ' WHERE PD.Pickslipno = @c_Sparm01 '   + CHAR(13)    
                          + ' AND PD.CartonNo BETWEEN CAST(@c_Sparm02 AS INT) AND CAST(@c_Sparm03 AS INT) ' + CHAR(13)  
                          + ' GROUP BY OH.Loadkey, SUBSTRING(LTRIM(RTRIM(ISNULL(OH.C_State,''''))),1,4), '   
                          + ' ''('' + SUBSTRING(LTRIM(RTRIM(ISNULL(OH.C_City,''''))),1,4) + '')'', ' + CHAR(13)    
                          + ' LTRIM(RTRIM(ISNULL(OH.C_Company,''''))), ' + CHAR(13)  
                          + ' LTRIM(RTRIM(ISNULL(OH.C_Address1,''''))) + '' '' + LTRIM(RTRIM(ISNULL(OH.C_Address2,''''))), ' + CHAR(13)  
                          + ' PD.LabelNo ,PD.CartonNo , PD.Pickslipno, ISNULL(ST.B_Address4,'''') ' + CHAR(13)  
                          + @c_Sorting  
      END*/
      --WL01 E    
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
                  
      IF @c_Sparm10 = 'BARCODE'  
      BEGIN  
         SET @c_SQL = @c_SQL + @c_SQLJOIN + @c_ExtraSQL + @c_SQLJOIN    
      END  
      ELSE  
      BEGIN  
         SET @c_SQL = @c_SQL + @c_SQLJOIN  
      END          
      
              
          
--EXEC sp_executesql @c_SQL            
  
      SET @c_ExecArguments =    N'  @c_Sparm01         NVARCHAR(80) '      
                               + ', @c_Sparm02         NVARCHAR(80) '       
                               + ', @c_Sparm03         NVARCHAR(80) '  
                               + ', @c_AllExtOrderkey  NVARCHAR(80) '   --WL01 
                               + ', @c_Col26           NVARCHAR(80) '   --WL01 
                               + ', @c_Col02           NVARCHAR(80) '   --WL01 
                               + ', @c_Col03           NVARCHAR(80) '   --WL01 
                               + ', @c_Col05           NVARCHAR(80) '   --WL01 
                               + ', @c_Col06           NVARCHAR(80) '   --WL01 
  
                           
                           
      EXEC sp_ExecuteSql     @c_SQL       
                           , @c_ExecArguments      
                           , @c_Sparm01      
                           , @c_Sparm02    
                           , @c_Sparm03  
                           , @c_AllExtOrderkey   --WL01
                           , @c_Col26            --WL01
                           , @c_Col02            --WL01
                           , @c_Col03            --WL01
                           , @c_Col05            --WL01
                           , @c_Col06            --WL01
          
      IF @b_debug=1          
      BEGIN            
         PRINT @c_SQL            
      END             
        
      --SELECT * FROM #RESULT  
      --GOTO EXIT_SP  
      DECLARE CUR_RowNoLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
      SELECT DISTINCT col22,col59,CAST(col23 AS INT)      
      FROM #Result   
      WHERE Col60 = 'CN'  
      ORDER BY col59, CAST(col23 AS INT)  
  
      OPEN CUR_RowNoLoop     
        
      FETCH NEXT FROM CUR_RowNoLoop INTO @c_LabelNo, @c_Pickslipno, @c_CartonNo   
  
      WHILE @@FETCH_STATUS <> -1   
      BEGIN  
         INSERT INTO #Temp_Packdetail  
         SELECT @c_Pickslipno, @c_LabelNo, @c_CartonNo, PD.LabelLine, PD.SKU, S.Size, SUM(PD.Qty), 'N'  
         FROM PACKHEADER PH WITH (NOLOCK)  
         JOIN PACKDETAIL PD WITH (NOLOCK) ON PH.PickSlipNo = PD.Pickslipno        
         JOIN SKU S WITH (NOLOCK) ON S.Sku = PD.SKU AND S.storerkey = PH.Storerkey     
         WHERE PD.PickSlipNo = @c_Pickslipno     
         AND PD.CartonNo = CAST(@c_CartonNo AS INT)  
         AND PD.LabelNo = @c_LabelNo  
         GROUP BY PD.LabelLine, PD.SKU, S.Size  
         ORDER BY CAST(PD.LabelLine AS INT)  
  
         SET @c_SKU01  = ''  
         SET @c_Size01 = ''  
         SET @c_Qty01  = ''  
         SET @c_SKU02  = ''  
         SET @c_Size02 = ''  
         SET @c_Qty02  = ''  
         SET @c_SKU03  = ''  
         SET @c_Size03 = ''  
         SET @c_Qty03  = ''  
         SET @c_SKU04  = ''  
         SET @c_Size04 = ''  
         SET @c_Qty04  = '' 
         SET @c_SKU05  = ''  
         SET @c_Size05 = ''  
         SET @c_Qty05  = ''   
         SET @c_SKU06  = ''  
         SET @c_Size06 = ''  
         SET @c_Qty06  = ''  
         SET @c_SKU07  = ''  
         SET @c_Size07 = ''  
         SET @c_Qty07  = ''  
         SET @c_SKU08  = ''  
         SET @c_Size08 = ''  
         SET @c_Qty08  = ''  
         SET @c_SKU09  = ''  
         SET @c_Size09 = ''  
         SET @c_Qty09  = ''  
         SET @c_SKU10  = ''  
         SET @c_Size10 = ''  
         SET @c_Qty10  = ''  

         IF @b_debug = 1  
            SELECT * FROM #Temp_Packdetail  
  
         SELECT @n_CntRec = COUNT (1)    
         FROM #Temp_Packdetail  
         WHERE Pickslipno = @c_Pickslipno  
         AND LabelNo = @c_LabelNo  
         AND CartonNo = @c_CartonNo  
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
               SELECT TOP 1 Col01,Col02,Col03,Col04,Col05,Col06,'','','','',         
                           '','','','','', '','','','','',  
                           '',Col22,Col23,Col24,'',Col26,'','',Col29,Col30,                  
                           Col31,'','','','', '','','','','',                       
                           '','','','','', '','','','','',                   
                           '','','','','', '','','',Col59,Col60   
               FROM #Result WHERE Col59 <> ''  
  
               SET @c_SKU01  = ''  
               SET @c_Size01 = ''  
               SET @c_Qty01  = ''  
               SET @c_SKU02  = ''  
               SET @c_Size02 = ''  
               SET @c_Qty02  = ''  
               SET @c_SKU03  = ''  
               SET @c_Size03 = ''  
               SET @c_Qty03  = ''  
               SET @c_SKU04  = ''  
               SET @c_Size04 = ''  
               SET @c_Qty04  = ''  
               SET @c_SKU05  = ''  
               SET @c_Size05 = ''  
               SET @c_Qty05  = ''  
               SET @c_SKU06  = ''  
               SET @c_Size06 = ''  
               SET @c_Qty06  = ''  
               SET @c_SKU07  = ''  
               SET @c_Size07 = ''  
               SET @c_Qty07  = ''  
               SET @c_SKU08  = ''  
               SET @c_Size08 = ''  
               SET @c_Qty08  = ''  
               SET @c_SKU09  = ''  
               SET @c_Size09 = ''  
               SET @c_Qty09  = ''  
               SET @c_SKU10  = ''  
               SET @c_Size10 = ''  
               SET @c_Qty10  = '' 
            END  
  
            SELECT   @c_SKU               = SKU      
                   , @c_Size              = Size     
                   , @c_Qty               = Qty  
            FROM #Temp_Packdetail   
            WHERE ID = @n_intFlag  
  
            IF (@n_intFlag % @n_MaxLine) = 1 --AND @n_recgrp = @n_CurrentPage    
            BEGIN   
               SET @c_SKU01      = @c_SKU         
               SET @c_Size01     = @c_Size       
               SET @c_Qty01      = @c_Qty  
            END     
            ELSE IF (@n_intFlag % @n_MaxLine) = 2 --AND @n_recgrp = @n_CurrentPage    
            BEGIN     
               SET @c_SKU02      = @c_SKU         
               SET @c_Size02     = @c_Size       
               SET @c_Qty02      = @c_Qty             
            END    
            ELSE IF (@n_intFlag % @n_MaxLine) = 3 --AND @n_recgrp = @n_CurrentPage    
            BEGIN     
               SET @c_SKU03      = @c_SKU         
               SET @c_Size03     = @c_Size       
               SET @c_Qty03      = @c_Qty         
            END   
            ELSE IF (@n_intFlag % @n_MaxLine) = 4 --AND @n_recgrp = @n_CurrentPage    
            BEGIN     
               SET @c_SKU04      = @c_SKU         
               SET @c_Size04     = @c_Size       
               SET @c_Qty04      = @c_Qty        
            END   
            ELSE IF (@n_intFlag % @n_MaxLine) = 5 --AND @n_recgrp = @n_CurrentPage    
            BEGIN     
               SET @c_SKU05      = @c_SKU         
               SET @c_Size05     = @c_Size       
               SET @c_Qty05      = @c_Qty          
            END 
            ELSE IF (@n_intFlag % @n_MaxLine) = 6 --AND @n_recgrp = @n_CurrentPage    
            BEGIN     
               SET @c_SKU06      = @c_SKU         
               SET @c_Size06     = @c_Size       
               SET @c_Qty06      = @c_Qty           
            END 
            ELSE IF (@n_intFlag % @n_MaxLine) = 7 --AND @n_recgrp = @n_CurrentPage    
            BEGIN     
               SET @c_SKU07       = @c_SKU         
               SET @c_Size07     = @c_Size       
               SET @c_Qty07      = @c_Qty           
            END 
            ELSE IF (@n_intFlag % @n_MaxLine) = 8 --AND @n_recgrp = @n_CurrentPage    
            BEGIN     
               SET @c_SKU08      = @c_SKU         
               SET @c_Size08     = @c_Size       
               SET @c_Qty08      = @c_Qty            
            END 
            ELSE IF (@n_intFlag % @n_MaxLine) = 9 --AND @n_recgrp = @n_CurrentPage    
            BEGIN     
               SET @c_SKU09      = @c_SKU         
               SET @c_Size09     = @c_Size       
               SET @c_Qty09      = @c_Qty            
            END 
            ELSE IF (@n_intFlag % @n_MaxLine) = 0 --AND @n_recgrp = @n_CurrentPage    
            BEGIN     
               SET @c_SKU10      = @c_SKU         
               SET @c_Size10     = @c_Size       
               SET @c_Qty10      = @c_Qty       
            END       
            
            UPDATE #Result  
            SET   Col07 = @c_SKU01      
                , Col08 = @c_SKU02      
                , Col09 = @c_SKU03         
                , Col10 = @c_SKU04         
                , Col11 = @c_SKU05     
                , Col12 = @c_Size01  
                , Col13 = @c_Size02   
                , Col14 = @c_Size03         
                , Col15 = @c_Size04       
                , Col16 = @c_Size05      
                , Col17 = @c_Qty01      
                , Col18 = @c_Qty02       
                , Col19 = @c_Qty03         
                , Col20 = @c_Qty04         
                , Col21 = @c_Qty05     
                , Col27 = @n_CurrentPage  
                , Col28 = @n_TTLpage
                , Col32 = @c_SKU06
                , Col33 = @c_SKU07
                , Col34 = @c_SKU08
                , Col35 = @c_SKU09
                , Col36 = @c_SKU10  
                , Col37 = @c_Size06
                , Col38 = @c_Size07
                , Col39 = @c_Size08
                , Col40 = @c_Size09
                , Col41 = @c_Size10
                , Col42 = @c_Qty06
                , Col43 = @c_Qty07
                , Col44 = @c_Qty08
                , Col45 = @c_Qty09
                , Col46 = @c_Qty10
            WHERE ID = @n_CurrentPage AND Col59 <> ''  
  
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
         SET Col25 = @n_SumQty  
         WHERE Col59 = @c_Pickslipno  
         AND Col22 = @c_LabelNo  
         AND Col23 = @c_CartonNo  
  
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
   --   @c_TraceName = 'isp_BT_Bartender_CN_SHIPUCCLBL_SKE_TJ',    
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