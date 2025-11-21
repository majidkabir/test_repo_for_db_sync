SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/********************************************************************************/                   
/* Copyright: LFL                                                               */                   
/* Purpose: isp_BT_Bartender_SG_UCCLABEL_EDR                                    */                   
/*                                                                              */                   
/* Modifications log:                                                           */                   
/*                                                                              */                   
/* Date        Rev  Author     Purposes                                         */                   
/* 04-Mar-2022 1.0  WLChooi    Created (WMS-19064)                              */  
/* 04-Mar-2022 1.0  WLChooi    DevOps Combine Script                            */  
/********************************************************************************/                  
                    
CREATE PROC [dbo].[isp_BT_Bartender_SG_UCCLABEL_EDR]                        
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

      @c_CheckConso      NVARCHAR(10),  
      @c_GetOrderkey     NVARCHAR(10),  
        
      @n_TTLpage         INT,            
      @n_CurrentPage     INT,    
      @n_MaxLine         INT,  
      
      @c_Sorting         NVARCHAR(4000),  
      @c_ExtraSQL        NVARCHAR(4000),  
      @c_JoinStatement   NVARCHAR(4000)              
      
  DECLARE  @d_Trace_StartTime   DATETIME,     
           @d_Trace_EndTime     DATETIME,    
           @c_Trace_ModuleName  NVARCHAR(20),     
           @d_Trace_Step1       DATETIME,     
           @c_Trace_Step1       NVARCHAR(20),    
           @c_UserName          NVARCHAR(20)              
    
   SET @d_Trace_StartTime = GETDATE()    
   SET @c_Trace_ModuleName = ''   
     
   SET @n_CurrentPage = 1    
   SET @n_TTLpage = 1                
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

   SET @c_Sorting = N' ORDER BY PD.Pickslipno, PD.CartonNo DESC '  
  
   SET @c_SQLJOIN = + ' SELECT DISTINCT ISNULL(OIF.[Platform],''''), OH.ExternOrderKey, PID.DropID, TRIM(ISNULL(OH.C_Company,'''')), ' + CHAR(13) --4
                    + ' TRIM(ISNULL(OH.C_Address1,'''')), TRIM(ISNULL(OH.C_Address2,'''')), TRIM(ISNULL(OH.C_Address3,'''')), ' + CHAR(13) --7
                    + ' LEFT(TRIM(ISNULL(OH.C_Zip,'''')) + '' '' + TRIM(ISNULL(OH.C_City,'''')) + '' '' + TRIM(ISNULL(OH.C_Country,'''')), 80), ' + CHAR(13) --8  
                    + ' PD.CartonNo, ''XX'', ' + CHAR(13) --10   
                    + ' PDET.Qty, CASE WHEN OH.Shipperkey = ''NinjaVan'' THEN ''Ninja Van'' ELSE ''LF'' END, ' + CHAR(13) --12
                    + ' ISNULL(OIF.StoreName,''''), ISNULL(PIF.TrackingNo,''''), ISNULL(OIF.EcomOrderId,''''), ISNULL(OIF.ReferenceID,''''), ' + CHAR(13) --15 
                    + ' TRIM(ISNULL(OH.C_Contact1,'''')), TRIM(ISNULL(OH.C_Phone1,'''')),TRIM(ISNULL(OH.C_Phone2,'''')), '''', ' + CHAR(13) --20         
                    + ' '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', '  + CHAR(13) --30     
                    + ' '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', '  + CHAR(13) --40  
                    + ' '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', '  + CHAR(13) --50        
                    + ' '''', '''', '''', '''', '''', '''', '''', OH.Orderkey, PD.Pickslipno, ''SG'' '  --60            
                    + CHAR(13) +              
                    + ' FROM PACKHEADER PH WITH (NOLOCK)' + CHAR(13)  
                    + ' JOIN PACKDETAIL PD WITH (NOLOCK) ON PH.Pickslipno = PD.Pickslipno' + CHAR(13)  
                    +   @c_JoinStatement  
                    + ' JOIN PICKDETAIL PID (NOLOCK) ON PID.Orderkey = OH.Orderkey ' + CHAR(13)
                    + ' LEFT JOIN ORDERINFO OIF (NOLOCK) ON OIF.Orderkey = OH.Orderkey ' + CHAR(13)
                    + ' LEFT JOIN PACKINFO PIF (NOLOCK) ON PIF.Pickslipno = PD.Pickslipno ' + CHAR(13)
                    + '                                AND PIF.CartonNo = PD.CartonNo ' + CHAR(13)
                    + ' CROSS APPLY (SELECT SUM(PACKDETAIL.Qty) AS Qty ' + CHAR(13)
                    + '              FROM PACKDETAIL (NOLOCK) ' + CHAR(13)
                    + '              WHERE PACKDETAIL.Pickslipno = PD.Pickslipno ' + CHAR(13)
                    + '              AND PACKDETAIL.CartonNo = PD.CartonNo) AS PDET ' + CHAR(13)
                    + ' WHERE PD.Pickslipno = @c_Sparm01 ' + CHAR(13)   
                    + ' AND PD.LabelNo =  @c_Sparm02 ' + CHAR(13)
                    + @c_Sorting                

   IF @b_debug=1          
   BEGIN          
      PRINT @c_SQLJOIN            
   END                  
                
   SET @c_SQL = 'INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05,Col06,Col07,Col08,Col09,Col10'  + CHAR(13) +             
              + ',Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20'  + CHAR(13) +             
              + ',Col21,Col22,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30' + CHAR(13) +             
              + ',Col31,Col32,Col33,Col34,Col35,Col36,Col37,Col38,Col39,Col40'  + CHAR(13) +             
              + ',Col41,Col42,Col43,Col44,Col45,Col46,Col47,Col48,Col49,Col50'+ CHAR(13) +             
              + ',Col51,Col52,Col53,Col54,Col55,Col56,Col57,Col58,Col59,Col60) '    
                  
   SET @c_SQL = @c_SQL + @c_SQLJOIN                
                       
   SET @c_ExecArguments = N'  @c_Sparm01         NVARCHAR(80) '      
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
      
   IF EXISTS (SELECT 1 FROM PACKHEADER (NOLOCK)
              WHERE Pickslipno = @c_Sparm01
              AND [Status] = '9')
   BEGIN 
      ;WITH CTE AS (
         SELECT MAX(CartonNo) AS CartonNo
         FROM PACKDETAIL (NOLOCK) 
         WHERE PickSlipNo = @c_Sparm01
      )
      UPDATE #Result
      SET Col10 = CTE.CartonNo
      FROM CTE
   END

RESULT:  
   SELECT * FROM #Result (nolock)       
   ORDER BY ID     
              
EXIT_SP:      
   SET @d_Trace_EndTime = GETDATE()    
   SET @c_UserName = SUSER_SNAME()    
      
END -- procedure     

GO