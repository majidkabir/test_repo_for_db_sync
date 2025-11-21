SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/********************************************************************************/                   
/* Copyright: LFL                                                               */                   
/* Purpose: isp_BT_Bartender_SG_UCCLBLSG01_PRSG                                 */                   
/*                                                                              */                   
/* Modifications log:                                                           */                   
/*                                                                              */                   
/* Date       Rev  Author     Purposes                                          */                   
/* 2021-08-11 1.0  WLChooi    Created - DevOps Combine Script (WMS-17658)       */
/********************************************************************************/                  
                    
CREATE PROC [dbo].[isp_BT_Bartender_SG_UCCLBLSG01_PRSG]                        
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
      @n_intFlag         INT,       
      @n_CntRec          INT,      
      @c_SQL             NVARCHAR(MAX),          
      @c_SQLSORT         NVARCHAR(MAX),          
      @c_SQLJOIN         NVARCHAR(MAX),  
      @c_ExecStatements  NVARCHAR(MAX),         
      @c_ExecArguments   NVARCHAR(MAX),  
        
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
      @c_Sorting         NVARCHAR(MAX),  
      @c_ExtraSQL        NVARCHAR(MAX),  
      @c_JoinStatement   NVARCHAR(MAX),
      @n_MaxCtn          INT,
      @c_GetPickslipno   NVARCHAR(10),
      @c_GetCartonNo     NVARCHAR(10)             
      
  DECLARE  @d_Trace_StartTime   DATETIME,     
           @d_Trace_EndTime     DATETIME,    
           @c_Trace_ModuleName  NVARCHAR(20),     
           @d_Trace_Step1       DATETIME,     
           @c_Trace_Step1       NVARCHAR(20),    
           @c_UserName          NVARCHAR(20)                   
    
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
         GOTO QUIT_SP  
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

   SET @c_Sorting = N' ORDER BY PD.Pickslipno, PD.CartonNo DESC '  
  
   SET @c_SQLJOIN = + ' SELECT DISTINCT OIF.[Platform], ' + CHAR(13) --1
                    + ' CASE WHEN @c_Sparm04 = ''FALSE'' OR ISNULL(PIF.TrackingNo,'''') = '''' THEN PH.Pickslipno ELSE OH.ExternOrderKey END, ' + CHAR(13) --2
                    + ' PIDET.DropID, ' + CHAR(13) --3
                    + ' CASE WHEN @c_Sparm04 = ''FALSE'' OR ISNULL(PIF.TrackingNo,'''') = '''' THEN '''' ELSE LTRIM(RTRIM(ISNULL(OH.C_Company,''''))) END, ' + CHAR(13) --4
                    + ' CASE WHEN @c_Sparm04 = ''FALSE'' OR ISNULL(PIF.TrackingNo,'''') = '''' THEN '''' ELSE LTRIM(RTRIM(ISNULL(OH.C_Address1,''''))) END,' + CHAR(13) --5
                    + ' CASE WHEN @c_Sparm04 = ''FALSE'' OR ISNULL(PIF.TrackingNo,'''') = '''' THEN '''' ELSE LTRIM(RTRIM(ISNULL(OH.C_Address2,''''))) END,' + CHAR(13) --6
                    + ' CASE WHEN @c_Sparm04 = ''FALSE'' OR ISNULL(PIF.TrackingNo,'''') = '''' THEN '''' ELSE LTRIM(RTRIM(ISNULL(OH.C_Address3,''''))) END, ' + CHAR(13)   --7
                    + ' CASE WHEN @c_Sparm04 = ''FALSE'' OR ISNULL(PIF.TrackingNo,'''') = '''' '
                    + '      THEN '''' '
                    + '      ELSE LTRIM(RTRIM(ISNULL(OH.C_Zip,''''))) + '' '' + LTRIM(RTRIM(ISNULL(OH.C_City,''''))) + '' '' + LTRIM(RTRIM(ISNULL(OH.C_Country,'''')))  END, ' + CHAR(13) --8  
                    + ' PD.CartonNo, ''XX'', ' + CHAR(13) --10   
                    + ' '''', CASE WHEN OH.Shipperkey = ''NinjaVan'' THEN ''Ninja Van'' ELSE ''LF'' END, ' + CHAR(13) --12
                    + ' ISNULL(PIF.TrackingNo,''''), '   --13
                    + ' ISNULL(OIF.EcomOrderID,''''), ISNULL(OIF.ReferenceID,''''), ISNULL(OIF.StoreName,''''), '  + CHAR(13) --16      
                    + ' CASE WHEN @c_Sparm04 = ''FALSE'' OR ISNULL(PIF.TrackingNo,'''') = '''' THEN '''' ELSE LTRIM(RTRIM(ISNULL(OH.C_Contact1,''''))) END, ' + CHAR(13)
                    + ' CASE WHEN @c_Sparm04 = ''FALSE'' OR ISNULL(PIF.TrackingNo,'''') = '''' THEN '''' ELSE LTRIM(RTRIM(ISNULL(OH.C_Phone1,''''))) END, ' + CHAR(13)
                    + ' CASE WHEN @c_Sparm04 = ''FALSE'' OR ISNULL(PIF.TrackingNo,'''') = '''' THEN '''' ELSE LTRIM(RTRIM(ISNULL(OH.C_Phone2,''''))) END, '''',  '   --20   
                    + ' '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', '  + CHAR(13) --30     
                    + ' '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', '  + CHAR(13) --40  
                    + ' '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', '  + CHAR(13) --50        
                    + ' '''', '''', '''', '''', '''', '''', '''', '''', PD.Pickslipno, ''SG'' '   --60            
                    + CHAR(13) +              
                    + ' FROM PACKHEADER PH WITH (NOLOCK)'        + CHAR(13)  
                    + ' JOIN PACKDETAIL PD WITH (NOLOCK) ON PH.Pickslipno = PD.Pickslipno'   + CHAR(13)  
                    +   @c_JoinStatement  
                    + ' JOIN PICKDETAIL PIDET WITH (NOLOCK) ON PIDET.Orderkey = OH.Orderkey AND PIDET.SKU = PD.SKU ' + CHAR(13)
                    + ' LEFT JOIN PACKINFO PIF WITH (NOLOCK) ON PIF.Pickslipno = PH.Pickslipno AND PIF.CartonNo = PD.CartonNo ' + CHAR(13)
                    + ' LEFT JOIN ORDERINFO OIF WITH (NOLOCK) ON OIF.Orderkey = OH.Orderkey ' + CHAR(13)
                    + ' WHERE PD.Pickslipno = @c_Sparm01 '   + CHAR(13)   
                    + ' AND PD.CartonNo >= CONVERT(INT,@c_Sparm02) AND PD.CartonNo <= CONVERT(INT,@c_Sparm03) '   + CHAR(13)   
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
                                  
  
   SET @c_ExecArguments =    N'  @c_Sparm01         NVARCHAR(80) '      
                            + ', @c_Sparm02         NVARCHAR(80) '       
                            + ', @c_Sparm03         NVARCHAR(80) '   
                            + ', @c_Sparm04         NVARCHAR(80) '   
                            + ', @c_Sparm05         NVARCHAR(80) '   
                                     
   EXEC sp_ExecuteSql     @c_SQL       
                        , @c_ExecArguments      
                        , @c_Sparm01      
                        , @c_Sparm02    
                        , @c_Sparm03 
                        , @c_Sparm04
                        , @c_Sparm05 
          
   IF @b_debug=1          
   BEGIN            
      PRINT @c_SQL            
   END        
   
   IF EXISTS (SELECT 1 FROM PACKHEADER (NOLOCK) WHERE Pickslipno = @c_Sparm01 AND [Status] = '9')
   BEGIN
      SELECT @n_MaxCtn = MAX(CartonNo)
      FROM PACKDETAIL (NOLOCK)
      WHERE Pickslipno = @c_Sparm01

      UPDATE #Result
      SET Col10 = @n_MaxCtn
      WHERE Col59 = @c_Sparm01
   END   
   
   DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT R.Col59, R.Col09
   FROM #Result R (NOLOCK)

   OPEN CUR_LOOP

   FETCH NEXT FROM CUR_LOOP INTO @c_GetPickslipno 
                               , @c_GetCartonNo   

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SELECT @n_SumQty = SUM(PD.Qty)
      FROM PACKDETAIL PD (NOLOCK)
      WHERE PD.PickSlipNo = @c_GetPickslipno
      AND PD.CartonNo = @c_GetCartonNo

      UPDATE #Result
      SET Col11 = CAST(@n_SumQty AS NVARCHAR)
      WHERE Col59 = @c_GetPickslipno
      AND Col09 = @c_GetCartonNo

      FETCH NEXT FROM CUR_LOOP INTO @c_GetPickslipno 
                                  , @c_GetCartonNo   
   END
   CLOSE CUR_LOOP
   DEALLOCATE CUR_LOOP

QUIT_SP:  
   SELECT * FROM #Result (NOLOCK)       
   ORDER BY ID     
          
END -- procedure     

GO