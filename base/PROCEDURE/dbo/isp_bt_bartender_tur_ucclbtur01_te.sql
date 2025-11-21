SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/********************************************************************************/                     
/* Copyright: MAERSK                                                            */                     
/* Purpose: isp_BT_Bartender_TUR_UCCLBTUR01_TE                                  */                     
/*                                                                              */                     
/* Modifications log:                                                           */                     
/*                                                                              */                     
/* Date        Rev  Author     Purposes                                         */                     
/* 22-Jun-2023 1.0  WLChooi    Created (UWP-1977)                               */  
/* 22-Jun-2023 1.0  WLChooi    DevOps Combine Script                            */  
/* 20-Jul-2023 1.1  WLChooi    UWP-1977 - Logic change (WL01)                   */
/* 07-AUG-2023 1.2  CE         UWP-1977 - Logic change (CE01)                   */
/* 22-AUG-2023 1.3  CE         UWP-1977 - Logic change (CE02)                   */
/********************************************************************************/                    
                      
CREATE   PROC [dbo].[isp_BT_Bartender_TUR_UCCLBTUR01_TE]                          
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
      @c_GetCartonNo     NVARCHAR(10),  
      @c_Mode            NVARCHAR(10),

      @c_FAddress1       NVARCHAR(100),
      @c_FAddress2       NVARCHAR(100),
      @c_FAddress3       NVARCHAR(100),
      @c_FAddress4       NVARCHAR(100),
      @c_FCity           NVARCHAR(100),
      @c_FState          NVARCHAR(100),
      @c_FCountry        NVARCHAR(100),
      @c_FZip            NVARCHAR(100),
      @c_CAddress1       NVARCHAR(100),
      @c_CAddress2       NVARCHAR(100),
      @c_CAddress3       NVARCHAR(100),
      @c_CAddress4       NVARCHAR(100),
      @c_CCity           NVARCHAR(100),
      @c_CState          NVARCHAR(100),
      @c_CCountry        NVARCHAR(100),
      @c_CZip            NVARCHAR(100),
      @n_PackSize        INT   --CE02
        
  DECLARE  @d_Trace_StartTime   DATETIME,       
           @d_Trace_EndTime     DATETIME,      
           @c_Trace_ModuleName  NVARCHAR(20),       
           @d_Trace_Step1       DATETIME,       
           @c_Trace_Step1       NVARCHAR(20),      
           @c_UserName          NVARCHAR(20)                     
      
   SET @d_Trace_StartTime = GETDATE()      
   SET @c_Trace_ModuleName = N''     
       
   SET @n_CurrentPage = 1      
   SET @n_TTLpage =1           
   SET @n_MaxLine = 8         
   SET @n_CntRec = 1        
   SET @n_intFlag = 1      
   SET @c_ExtraSQL = N''    
   SET @c_JoinStatement = N''    
    
   SET @c_CheckConso = N'N'    
                     
   SET @c_SQL = N''   
       
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
         SET @c_CheckConso = N'Y'    
      ELSE    
         GOTO QUIT_SP    
   END    
     
   SET @c_JoinStatement = N' JOIN ORDERS O (NOLOCK) ON PH.ORDERKEY = O.ORDERKEY ' + CHAR(13)    
       
   IF @c_CheckConso = 'Y'    
   BEGIN    
      SET @c_JoinStatement = N' JOIN LOADPLANDETAIL LPD (NOLOCK) ON PH.LOADKEY = LPD.LOADKEY ' + CHAR(13)    
                           + N' JOIN ORDERS O (NOLOCK) ON O.ORDERKEY = LPD.ORDERKEY ' + CHAR(13)    
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

   SELECT @c_FAddress1 = F.Address1
        , @c_FAddress2 = F.Address2
        , @c_FAddress3 = F.Address3
        , @c_FAddress4 = F.Address4
        , @c_FCity     = F.City
        , @c_FState    = F.State
        , @c_FCountry  = F.Country
        , @c_FZip      = F.Zip
        , @c_CAddress1 = OH.C_Address1
        , @c_CAddress2 = OH.C_Address2
        , @c_CAddress3 = OH.C_Address3
        , @c_CAddress4 = OH.C_Address4
        , @c_CCity     = OH.C_City
        , @c_CState    = OH.C_State
        , @c_CCountry  = OH.C_Country
        , @c_CZip      = OH.C_Zip
   FROM ORDERS OH (NOLOCK)
   JOIN FACILITY F (NOLOCK) ON OH.Facility = F.Facility
   WHERE OH.Orderkey = @c_GetOrderkey

   DECLARE @T_T AS TABLE (RowID INT NOT NULL IDENTITY(1,1) PRIMARY KEY, Cols NVARCHAR(100), ColType NVARCHAR(10))
   DECLARE @c_FAddr1 NVARCHAR(100)
         , @c_FAddr2 NVARCHAR(100)
         , @c_FAddr3 NVARCHAR(100)
         , @c_FAddr4 NVARCHAR(100)
         , @c_CAddr1 NVARCHAR(100)
         , @c_CAddr2 NVARCHAR(100)
         , @c_CAddr3 NVARCHAR(100)
         , @c_CAddr4 NVARCHAR(100)

   INSERT INTO @T_T (Cols, ColType)
   SELECT ISNULL(@c_FAddress1,''), 'F1' UNION ALL
   SELECT ISNULL(@c_FAddress2,''), 'F1' UNION ALL
   SELECT ISNULL(@c_FAddress3,''), 'F2' UNION ALL
   SELECT ISNULL(@c_FAddress4,''), 'F2' UNION ALL
   SELECT ISNULL(@c_FCity    ,''), 'F3' UNION ALL
   SELECT ISNULL(@c_FState   ,''), 'F3' UNION ALL
   SELECT ISNULL(@c_FCountry ,''), 'F4' UNION ALL
   SELECT ISNULL(@c_FZip     ,''), 'F4' UNION ALL
   SELECT ISNULL(@c_CAddress1,''), 'C1' UNION ALL
   SELECT ISNULL(@c_CAddress2,''), 'C1' UNION ALL
   SELECT ISNULL(@c_CAddress3,''), 'C2' UNION ALL
   SELECT ISNULL(@c_CAddress4,''), 'C2' UNION ALL
   SELECT ISNULL(@c_CCity    ,''), 'C3' UNION ALL
   SELECT ISNULL(@c_CState   ,''), 'C3' UNION ALL
   SELECT ISNULL(@c_CCountry ,''), 'C4' UNION ALL
   SELECT ISNULL(@c_CZip     ,''), 'C4'

   SELECT @c_FAddr1 = STUFF((SELECT ', ' + RTRIM(Cols) FROM @T_T WHERE ISNULL(Cols,'') <> '' AND ColType = 'F1' ORDER BY RowID FOR XML PATH('')),1,2,'' )
   SELECT @c_FAddr2 = STUFF((SELECT ', ' + RTRIM(Cols) FROM @T_T WHERE ISNULL(Cols,'') <> '' AND ColType = 'F2' ORDER BY RowID FOR XML PATH('')),1,2,'' )
   SELECT @c_FAddr3 = STUFF((SELECT ', ' + RTRIM(Cols) FROM @T_T WHERE ISNULL(Cols,'') <> '' AND ColType = 'F3' ORDER BY RowID FOR XML PATH('')),1,2,'' )
   SELECT @c_FAddr4 = STUFF((SELECT ', ' + RTRIM(Cols) FROM @T_T WHERE ISNULL(Cols,'') <> '' AND ColType = 'F4' ORDER BY RowID FOR XML PATH('')),1,2,'' )

   IF ISNULL(@c_FAddr3,'') <> '' SET @c_FAddr3 = IIF(ISNULL(@c_FAddr4,'') <> '', @c_FAddr3 + ', ', @c_FAddr3)
   IF ISNULL(@c_FAddr2,'') <> '' SET @c_FAddr2 = IIF(ISNULL(@c_FAddr4,'') <> '' OR ISNULL(@c_FAddr3,'') <> '', @c_FAddr2 + ', ', @c_FAddr2)
   IF ISNULL(@c_FAddr1,'') <> '' SET @c_FAddr1 = IIF(ISNULL(@c_FAddr4,'') <> '' OR ISNULL(@c_FAddr3,'') <> '' OR ISNULL(@c_FAddr2,'') <> '', @c_FAddr1 + ', ', @c_FAddr1)

   SELECT @c_CAddr1 = STUFF((SELECT ', ' + RTRIM(Cols) FROM @T_T WHERE ISNULL(Cols,'') <> '' AND ColType = 'C1' ORDER BY RowID FOR XML PATH('')),1,2,'' )
   SELECT @c_CAddr2 = STUFF((SELECT ', ' + RTRIM(Cols) FROM @T_T WHERE ISNULL(Cols,'') <> '' AND ColType = 'C2' ORDER BY RowID FOR XML PATH('')),1,2,'' )
   SELECT @c_CAddr3 = STUFF((SELECT ', ' + RTRIM(Cols) FROM @T_T WHERE ISNULL(Cols,'') <> '' AND ColType = 'C3' ORDER BY RowID FOR XML PATH('')),1,2,'' )
   SELECT @c_CAddr4 = STUFF((SELECT ', ' + RTRIM(Cols) FROM @T_T WHERE ISNULL(Cols,'') <> '' AND ColType = 'C4' ORDER BY RowID FOR XML PATH('')),1,2,'' )

   IF ISNULL(@c_CAddr3,'') <> '' SET @c_CAddr3 = IIF(ISNULL(@c_CAddr4,'') <> '', @c_CAddr3 + ', ', @c_CAddr3)
   IF ISNULL(@c_CAddr2,'') <> '' SET @c_CAddr2 = IIF(ISNULL(@c_CAddr4,'') <> '' OR ISNULL(@c_CAddr3,'') <> '', @c_CAddr2 + ', ', @c_CAddr2)
   IF ISNULL(@c_CAddr1,'') <> '' SET @c_CAddr1 = IIF(ISNULL(@c_CAddr4,'') <> '' OR ISNULL(@c_CAddr3,'') <> '' OR ISNULL(@c_CAddr2,'') <> '', @c_CAddr1 + ', ', @c_CAddr1)

   SET @c_Sorting = N' ORDER BY PD.Pickslipno, PD.CartonNo DESC '    
    
   SET @c_SQLJOIN = N' SELECT CONCAT(F.Facility, ''-'', F.Descr) AS wh_name ' + CHAR(13)  
                  + N'      , ISNULL(@c_FAddr1,'''') AS wh_addr' + CHAR(13)   
                  + N'      , UPPER(FORMAT(PD.EditDate, ''MMM'')) AS ship_month ' + CHAR(13)  
                  + N'      , S.Company AS cust_name ' + CHAR(13)  
                  + N'      , ISNULL(@c_CAddr1,'''') AS cust_addr ' + CHAR(13)  
                  + N'      , O.ExternOrderKey AS Desp_note_no ' + CHAR(13)  
                  + N'      , C.UDF03 AS TEC_part_no ' + CHAR(13)   --WL01
                  + N'      , PD.Qty ' + CHAR(13)  
                  + N'      , LA.Lottable01 AS Batch ' + CHAR(13)   --CE01  
                  + N'      , CONCAT(''CARTON '', ROW_NUMBER() OVER (ORDER BY PD.CartonNo), '' of '', COUNT(*) OVER ()) AS box_cnt ' + CHAR(13)   --10  
                  + N'      , ISNULL(PD.Sku,'''') ' + CHAR(13)   --CE01 
                  + N'      , ISNULL(@c_FAddr2,'''') AS wh_addr1 ' + CHAR(13) 
                  + N'      , ISNULL(@c_FAddr3,'''') AS wh_addr2 ' + CHAR(13)                    
                  + N'      , ISNULL(@c_FAddr4,'''') AS wh_addr3 ' + CHAR(13)
                  + N'      , ISNULL(@c_CAddr2,'''') AS cust_addr1 ' + CHAR(13)     
                  + N'      , ISNULL(@c_CAddr3,'''') AS cust_addr2  ' + CHAR(13) 
                  + N'      , ISNULL(@c_CAddr4,'''') AS cust_addr3 ' + CHAR(13) 
                  + N'      , '''', '''', '''' ' + CHAR(13)   --20  
                  + N'      , '''', '''', '''', '''', '''', '''', '''', '''', '''', '''' ' + CHAR(13)   --30  
                  + N'      , '''', '''', '''', '''', '''', '''', '''', '''', '''', '''' ' + CHAR(13)   --40  
                  + N'      , '''', '''', '''', '''', '''', '''', '''', '''', '''', '''' ' + CHAR(13)   --50  
                  + N'      , '''', '''', '''', '''', '''', '''', '''', '''', P.Casecnt, PD.Pickslipno ' + CHAR(13)   --60   --CE02
                  + N' FROM PackDetail PD (NOLOCK) ' + CHAR(13)  
                  + N' JOIN PackHeader PH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo ' + CHAR(13)  
                  + @c_JoinStatement + CHAR(13)  
                  --+ N' JOIN ORDERDETAIL OD ON O.OrderKey = OD.OrderKey ' + CHAR(13) --CE01
                  + N' JOIN PICKDETAIL PKD (NOLOCK) ON PH.OrderKey = PKD.Orderkey and PD.Sku = PKD.Sku and PKD.DropID = PD.DropID ' + CHAR(13) --CE01
                  + N' JOIN LOTATTRIBUTE LA (NOLOCK) ON PKD.Lot = LA.Lot ' + CHAR(13) --CE01
                  + N' LEFT JOIN CODELKUP C (NOLOCK) ON PD.Sku = C.UDF02 AND PD.StorerKey = C.Storerkey AND O.ConsigneeKey = C.UDF01 ' + CHAR(13)   --WL01   --CE01
                  + N' JOIN FACILITY F (NOLOCK) ON O.Facility = F.Facility ' + CHAR(13)  
                  + N' LEFT JOIN STORER S (NOLOCK) ON O.ConsigneeKey = S.StorerKey ' + CHAR(13)  
                  + N' JOIN SKU (NOLOCK) ON SKU.Storerkey = PD.Storerkey AND SKU.SKU = PD.SKU ' + CHAR(13)   --CE02
                  + N' JOIN PACK P (NOLOCK) ON P.Packkey = SKU.Packkey '   --CE02
                  + N' WHERE PD.PickSlipNo = @c_Sparm01 ' + CHAR(13)  
                  + N' AND PD.CartonNo >= CONVERT(INT,@c_Sparm02) AND PD.CartonNo <= CONVERT(INT,@c_Sparm03) '   + CHAR(13)     
                  + @c_Sorting              
  
   IF @b_debug=1            
   BEGIN            
      PRINT @c_SQLJOIN              
   END                    
     
   SET @c_SQL=N'INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09'  + CHAR(13) +               
             +N',Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22'  + CHAR(13) +               
             +N',Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34' + CHAR(13) +               
             +N',Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44'  + CHAR(13) +               
             +N',Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54'+ CHAR(13) +               
             +N',Col55,Col56,Col57,Col58,Col59,Col60) '      
                    
   SET @c_SQL = @c_SQL + @c_SQLJOIN                  
                                    
   SET @c_ExecArguments = N'  @c_Sparm01         NVARCHAR(80) '        
                        + N', @c_Sparm02         NVARCHAR(80) '         
                        + N', @c_Sparm03         NVARCHAR(80) '     
                        + N', @c_Sparm04         NVARCHAR(80) '     
                        + N', @c_Sparm05         NVARCHAR(80) '  
                        + N', @c_FAddr1          NVARCHAR(80) '
                        + N', @c_FAddr2          NVARCHAR(80) '
                        + N', @c_FAddr3          NVARCHAR(80) '
                        + N', @c_FAddr4          NVARCHAR(80) '
                        + N', @c_CAddr1          NVARCHAR(80) '
                        + N', @c_CAddr2          NVARCHAR(80) '
                        + N', @c_CAddr3          NVARCHAR(80) '
                        + N', @c_CAddr4          NVARCHAR(80) '
                                       
   EXEC sp_ExecuteSql     @c_SQL         
                        , @c_ExecArguments        
                        , @c_Sparm01        
                        , @c_Sparm02      
                        , @c_Sparm03   
                        , @c_Sparm04  
                        , @c_Sparm05   
                        , @c_FAddr1
                        , @c_FAddr2
                        , @c_FAddr3
                        , @c_FAddr4
                        , @c_CAddr1
                        , @c_CAddr2
                        , @c_CAddr3
                        , @c_CAddr4
            
   IF @b_debug=1            
   BEGIN              
      PRINT @c_SQL              
   END          
  
QUIT_SP:    
   --CE02 S
   --SELECT * FROM #Result (NOLOCK)         
   --ORDER BY ID
   SET @n_PackSize = 0

   SELECT TOP 1 @n_PackSize = CASE WHEN ISNUMERIC(R.Col59) = 1 THEN CONVERT(INT, R.Col59) ELSE 0 END
   FROM #Result R (NOLOCK)

   SELECT 
      ID,Col01,Col02,Col03,Col04,Col05,Col06,Col07, qty as Col08, --Col08
      Col09,Col10,Col11,Col12,Col13,Col14,Col15,
      Col16,Col17,Col18,Col19,Col20,Col21,Col22,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,
      Col31,Col32,Col33,Col34,Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44,Col45,
      Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54,Col55,Col56,Col57,Col58,Col59,Col60 
   FROM(
         SELECT *
         FROM #Result (NOLOCK)  
         OUTER APPLY (SELECT TOP((#Result.Col08 + @n_PackSize - 1 ) / @n_PackSize) @n_PackSize qty FROM syscolumns) X
      --ORDER BY ID 
    ) ret
   --CE02 E   
END -- procedure     

GO