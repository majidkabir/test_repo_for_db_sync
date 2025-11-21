SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/********************************************************************************/                   
/* Copyright: LFL                                                               */                   
/* Purpose: isp_BT_Bartender_TW_CTNLBL02_NIK                                    */                   
/*                                                                              */                   
/* Modifications log:                                                           */                   
/*                                                                              */                   
/* Date       Rev  Author     Purposes                                          */                   
/* 2021-12-14 1.0  WLChooi    Created (WMS-18647)                               */  
/* 2021-12-14 1.0  WLChooi    DevOps Combine Script                             */
/* 2022-06-24 1.1  CSCHONG    WMS-20007 revised totalctn (CS01)                 */
/* 2022-07-07 1.1  CSCHONG    WMS-20007 fix issue after go live (CS01a)         */
/********************************************************************************/                  
                    
CREATE PROC [dbo].[isp_BT_Bartender_TW_CTNLBL02_NIK]                        
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
      @n_IntFlag         INT,       
      @n_CntRec          INT,      
      @c_SQL             NVARCHAR(MAX),          
      @c_SQLSORT         NVARCHAR(MAX),          
      @c_SQLJOIN         NVARCHAR(MAX),  
      @c_SQLJOIN2        NVARCHAR(MAX), 
      @c_SQLInsert       NVARCHAR(MAX),
      @c_ExecStatements  NVARCHAR(MAX),         
      @c_ExecArguments   NVARCHAR(MAX),     
      @c_Storerkey       NVARCHAR(15),
      @c_Facility        NVARCHAR(5),
      @n_TTLpage         INT,            
      @n_CurrentPage     INT,    
      @n_MaxLine         INT,
      @c_Addr1           NVARCHAR(80),
      @c_Addr2           NVARCHAR(80),
      @c_Addr3           NVARCHAR(80),
      @c_Address         NVARCHAR(80),
      @c_CombineSQL      NVARCHAR(MAX) = '',
      @c_CombineSQLGrp   NVARCHAR(MAX) = '',
      @c_Orderkey        NVARCHAR(10) = '',
      @n_TotalCarton     INT = 0,
      @n_CurrentCarton   INT = 0

   DECLARE @c_Col01      NVARCHAR(80) = ''
         , @c_Col02      NVARCHAR(80) = ''
         , @c_Col03      NVARCHAR(80) = ''
         , @c_Col04      NVARCHAR(80) = ''
         , @c_Col05      NVARCHAR(80) = ''
         , @c_Col06      NVARCHAR(80) = ''
         , @c_Col07      NVARCHAR(80) = ''
         , @c_Col08      NVARCHAR(80) = ''
         , @c_Col09      NVARCHAR(80) = ''
         , @c_Col10      NVARCHAR(80) = ''
         , @c_Col11      NVARCHAR(80) = ''
         , @c_Col12      NVARCHAR(80) = ''
         , @c_Col13      NVARCHAR(80) = ''
         , @c_Col14      NVARCHAR(80) = ''
         , @c_Col15      NVARCHAR(80) = ''
         , @c_Col16      NVARCHAR(80) = ''
         , @c_Col17      NVARCHAR(80) = ''
         , @c_Col18      NVARCHAR(80) = ''
         , @c_Col19      NVARCHAR(80) = ''
         , @c_Col20      NVARCHAR(80) = ''
         , @c_Col21      NVARCHAR(80) = ''

   SET @n_CurrentPage = 1    
   SET @n_TTLpage = 1         
   SET @n_MaxLine = 10        
   SET @n_CntRec = 1      
   SET @n_IntFlag = 1             
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

   CREATE TABLE #TMP_ORDERS (
      Orderkey    NVARCHAR(10)
    , Storerkey   NVARCHAR(15)
    , Facility    NVARCHAR(5)
   )

--CS01 S

 CREATE TABLE #TMP_ORDERSGRP (
      [ID]    [INT] IDENTITY(1,1) NOT NULL,                              
      [Col01] [NVARCHAR] (80) NULL,                
      [Col02] [NVARCHAR] (80) NULL,                
      [Col03] [NVARCHAR] (80) NULL,                
      [Col04] [NVARCHAR] (80) NULL,                
      [Col05] DECIMAL(10,2),                    --CS01a 
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
      [Col17] [NVARCHAR] (80) NULL
   )

--CS01 E

   --By Load
   INSERT INTO #TMP_ORDERS (Orderkey, Storerkey, Facility)
   SELECT DISTINCT LPD.Orderkey, OH.Storerkey, OH.Facility
   FROM LOADPLANDETAIL LPD (NOLOCK)
   JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = LPD.OrderKey
   WHERE LPD.LoadKey = @c_Sparm01
   
   IF NOT EXISTS (SELECT 1 FROM #TMP_ORDERS)
   BEGIN
      --By Order
      INSERT INTO #TMP_ORDERS (Orderkey, Storerkey, Facility)
      SELECT OH.Orderkey, OH.StorerKey, OH.Facility
      FROM ORDERS OH (NOLOCK)
      WHERE OH.OrderKey = @c_Sparm01
   END
   
   IF NOT EXISTS (SELECT 1 FROM #TMP_ORDERS)
   BEGIN
      GOTO RESULT
   END

   SELECT TOP 1 @c_Storerkey = TOR.Storerkey
              , @c_Facility  = TOR.Facility
   FROM #TMP_ORDERS TOR

   SELECT @c_Addr1 = (SELECT ISNULL(CL.Code,'')
                      FROM CODELKUP CL (NOLOCK) 
                      WHERE CL.LISTNAME = 'NIKADDRESS' AND CL.Storerkey = @c_Storerkey
                      AND CL.Short = '1')
        , @c_Addr2 = (SELECT ISNULL(CL.Code,'')
                      FROM CODELKUP CL (NOLOCK) 
                      WHERE CL.LISTNAME = 'NIKADDRESS' AND CL.Storerkey = @c_Storerkey
                      AND CL.Short = '2')
        , @c_Addr3 = (SELECT ISNULL(CL.Code,'')
                      FROM CODELKUP CL (NOLOCK) 
                      WHERE CL.LISTNAME = 'NIKADDRESS' AND CL.Storerkey = @c_Storerkey
                      AND CL.Short = '3')

   IF ISNULL(@c_Addr1,'') <> ''
   BEGIN
      SELECT @c_CombineSQL = @c_CombineSQL + 'ISNULL(OH.' + @c_Addr1 + ','''') + '
   END

   IF ISNULL(@c_Addr2,'') <> ''
   BEGIN
      SELECT @c_CombineSQL = @c_CombineSQL + 'ISNULL(OH.' + @c_Addr2 + ','''') + '
   END

   IF ISNULL(@c_Addr3,'') <> ''
   BEGIN
      SELECT @c_CombineSQL = @c_CombineSQL + 'ISNULL(OH.' + @c_Addr3 + ','''') + '
   END

   IF ISNULL(@c_CombineSQL,'') <> ''
   BEGIN 
      SET @c_CombineSQL = ', LEFT(' + SUBSTRING(@c_CombineSQL, 1, LEN(@c_CombineSQL) - 2) + ', 80)'
      SET @c_CombineSQLGrp = @c_CombineSQL
   END
   ELSE
   BEGIN
      SET @c_CombineSQL = ' , '''' '
      SET @c_CombineSQLGrp = ''
   END

   SELECT @c_Col18 = CASE WHEN ISNULL(ST.B_Company,'') = ''  THEN N'台灣耐基商業有限公司匡威分公司' ELSE ST.B_Company END
        , @c_Col19 = CASE WHEN ISNULL(ST.B_Address1,'') = '' THEN (SELECT TOP 1 F.Address1 FROM FACILITY F (NOLOCK) WHERE F.Facility = @c_Facility) 
                                                             ELSE ST.B_Address1 END
        , @c_Col20 = CASE WHEN ISNULL(ST.B_Phone1,'') = ''   THEN (SELECT TOP 1 F.Phone1 FROM FACILITY F (NOLOCK) WHERE F.Facility = @c_Facility) 
                                                             ELSE ST.B_Phone1 END
   FROM STORER ST (NOLOCK)
   WHERE ST.StorerKey = @c_Storerkey

      --CS01 S
   SET @c_SQLInsert = 'INSERT INTO #TMP_ORDERSGRP (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09'  + CHAR(13) +             
                    + ',Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17)'   


   --SET @c_SQLJOIN = + ' DECLARE CUR_MAIN CURSOR FAST_FORWARD READ_ONLY FOR ' + CHAR(13)
     SET @c_SQLJOIN = + ' SELECT OH.ExternOrderkey, OH.Orderkey, ISNULL(TRIM(OH.C_Company),''''), ' + CHAR(13)
                    + ' CASE WHEN PH.Consigneekey IN (''0'','''') THEN ''d d'' ELSE ''d'' + RIGHT(REPLICATE(''0'', 10) + TRIM(PH.Consigneekey),10) + ''d'' END, ' + CHAR(13)
                    + ' CASE WHEN ISNULL(P.CaseCnt,0) = 0 
                             THEN 0
                             ELSE CONVERT(DECIMAL(20,2), SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty) / ISNULL(P.CaseCnt,0)) END, ' + CHAR(13)    --CS01   --CS01a
                    + ' OH.[Route], ISNULL(OH.DeliveryPlace,'''') ' + @c_CombineSQL + ' ,ISNULL(TRIM(OH.C_City),''''), ' + CHAR(13)
                    + ' CASE WHEN ISNULL(LPD.LoadLineNumber,'''') <> '''' THEN LPD.LoadLineNumber ELSE ''1'' END, ' + CHAR(13)
                    + ' PH.PickHeaderKey, CONVERT(NVARCHAR(10), LP.lpuserdefdate01, 111), ISNULL(OH.UserDefine05,''''), ' + CHAR(13)
                    + ' '''', DATENAME(Weekday,LP.lpuserdefdate01), FORMAT(LP.lpuserdefdate01,''MM/dd''), '''' ' + CHAR(13)   
                    + ' FROM ORDERS OH (NOLOCK) ' + CHAR(13)
                    + ' JOIN ORDERDETAIL OD (NOLOCK) ON OH.Orderkey = OD.Orderkey ' + CHAR(13)
                    + ' JOIN LOADPLANDETAIL LPD (NOLOCK) ON LPD.OrderKey = OH.OrderKey ' + CHAR(13)
                    + ' JOIN LOADPLAN LP (NOLOCK) ON LP.LoadKey = LPD.LoadKey ' + CHAR(13)
                    + ' JOIN PICKHEADER PH (NOLOCK) ON PH.Orderkey = OH.Orderkey ' + CHAR(13)
                    + ' JOIN SKU S (NOLOCK) ON S.StorerKey = OD.StorerKey AND S.SKU = OD.SKU ' + CHAR(13)
                    + ' JOIN PACK P (NOLOCK) ON P.PackKey = S.Packkey ' + CHAR(13)
                    + ' JOIN #TMP_ORDERS T (NOLOCK) ON T.Orderkey = OH.Orderkey ' + CHAR(13)
                    + ' WHERE (OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty) > 0 ' + CHAR(13)
                    + ' AND PH.Orderkey <> '''' ' + CHAR(13)
                    + ' GROUP BY OH.ExternOrderkey, OH.Orderkey, ISNULL(TRIM(OH.C_Company),''''), ' + CHAR(13)
                    + '          CASE WHEN PH.Consigneekey IN (''0'','''') THEN ''d d'' ELSE ''d'' + RIGHT(REPLICATE(''0'', 10) + TRIM(PH.Consigneekey),10) + ''d'' END, ' + CHAR(13)
                    + '          ISNULL(P.CaseCnt,0), ' + CHAR(13)
                    + '          OH.[Route], ISNULL(OH.DeliveryPlace,'''') ,ISNULL(TRIM(OH.C_City),''''), ' + CHAR(13)
                    + '          CASE WHEN ISNULL(LPD.LoadLineNumber,'''') <> '''' THEN LPD.LoadLineNumber ELSE ''1'' END, ' + CHAR(13) 
                    + '          PH.PickHeaderKey, CONVERT(NVARCHAR(10), LP.lpuserdefdate01, 111), ISNULL(OH.UserDefine05,''''), ISNULL(P.CaseCnt,0), ' + CHAR(13)    --CS01
                   -- + '          PH.PickHeaderKey, CONVERT(NVARCHAR(10), LP.lpuserdefdate01, 111), ISNULL(OH.UserDefine05,''''),  ' + CHAR(13)    --CS01
                    + '          FORMAT(LP.lpuserdefdate01,''MM/dd''), DATENAME(Weekday,LP.lpuserdefdate01) ' + @c_CombineSQLGrp + CHAR(13)
                    + ' UNION ALL ' + CHAR(13)
   SET @c_SQLJOIN2 = + ' SELECT OH.ExternOrderkey, OH.Orderkey, ISNULL(TRIM(OH.C_Company),''''), ' + CHAR(13)
                     + ' CASE WHEN PH.Consigneekey IN (''0'','''') THEN ''d d'' ELSE ''d'' + RIGHT(REPLICATE(''0'', 10) + TRIM(PH.Consigneekey),10) + ''d'' END, ' + CHAR(13)
                     + ' CASE WHEN ISNULL(P.CaseCnt,0) = 0 
                              THEN 0
                              ELSE CEILING(CONVERT(DECIMAL(20,2), SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty) / ISNULL(P.CaseCnt,0))) END, ' + CHAR(13)    --CS01
                     + ' OH.[Route], ISNULL(OH.DeliveryPlace,'''') ' + @c_CombineSQL + ' ,ISNULL(TRIM(OH.C_City),''''), ' + CHAR(13)
                     + ' CASE WHEN ISNULL(LPD.LoadLineNumber,'''') <> '''' THEN LPD.LoadLineNumber ELSE ''1'' END, ' + CHAR(13)
                     + ' PH.PickHeaderKey, CONVERT(NVARCHAR(10), LP.lpuserdefdate01, 111), ISNULL(OH.UserDefine05,''''), ' + CHAR(13)
                     + ' '''', DATENAME(Weekday,LP.lpuserdefdate01), FORMAT(LP.lpuserdefdate01,''MM/dd''), '''' ' + CHAR(13)  
                     + ' FROM ORDERS OH (NOLOCK) ' + CHAR(13)
                     + ' JOIN ORDERDETAIL OD (NOLOCK) ON OH.Orderkey = OD.Orderkey ' + CHAR(13)
                     + ' JOIN LOADPLANDETAIL LPD (NOLOCK) ON LPD.OrderKey = OH.OrderKey ' + CHAR(13)
                     + ' JOIN LOADPLAN LP (NOLOCK) ON LP.LoadKey = LPD.LoadKey ' + CHAR(13)
                     + ' JOIN PICKHEADER PH (NOLOCK) ON PH.ExternOrderkey = LPD.Loadkey ' + CHAR(13)
                     + ' JOIN SKU S (NOLOCK) ON S.StorerKey = OD.StorerKey AND S.SKU = OD.SKU ' + CHAR(13)
                     + ' JOIN PACK P (NOLOCK) ON P.PackKey = S.Packkey ' + CHAR(13)
                     + ' JOIN #TMP_ORDERS T (NOLOCK) ON T.Orderkey = OH.Orderkey ' + CHAR(13)
                     + ' WHERE (OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty) > 0 ' + CHAR(13)
                     + ' AND PH.Orderkey = '''' AND PH.ExternOrderkey <> '''' ' + CHAR(13)
                     + ' GROUP BY OH.ExternOrderkey, OH.Orderkey, ISNULL(TRIM(OH.C_Company),''''), ' + CHAR(13)
                     + '          CASE WHEN PH.Consigneekey IN (''0'','''') THEN ''d d'' ELSE ''d'' + RIGHT(REPLICATE(''0'', 10) + TRIM(PH.Consigneekey),10) + ''d'' END, ' + CHAR(13)
                     + '          ISNULL(P.CaseCnt,0), ' + CHAR(13)
                     + '          OH.[Route], ISNULL(OH.DeliveryPlace,'''') ,ISNULL(TRIM(OH.C_City),''''), ' + CHAR(13)
                     + '          CASE WHEN ISNULL(LPD.LoadLineNumber,'''') <> '''' THEN LPD.LoadLineNumber ELSE ''1'' END, ' + CHAR(13) 
                     + '          PH.PickHeaderKey, CONVERT(NVARCHAR(10), LP.lpuserdefdate01, 111), ISNULL(OH.UserDefine05,''''), ISNULL(P.CaseCnt,0), ' + CHAR(13)    --CS01
                     --+ '          PH.PickHeaderKey, CONVERT(NVARCHAR(10), LP.lpuserdefdate01, 111), ISNULL(OH.UserDefine05,''''),  ' + CHAR(13)    --CS01
                     + '          FORMAT(LP.lpuserdefdate01,''MM/dd''), DATENAME(Weekday,LP.lpuserdefdate01) ' + @c_CombineSQLGrp + CHAR(13)
                     + ' ORDER BY OH.Orderkey '
 
   IF @b_debug = 1          
   BEGIN          
      PRINT @c_SQLJOIN + @c_SQLJOIN2            
   END                     
                  
   SET @c_SQL = @c_SQLInsert + @c_SQLJOIN + @c_SQLJOIN2       
      
   SET @c_ExecArguments = N'  @c_Sparm01         NVARCHAR(80) '      
                        +  ', @c_Sparm02         NVARCHAR(80) '       
                        +  ', @c_Sparm03         NVARCHAR(80) '    
                        
   EXEC sp_ExecuteSql     @c_SQL       
                        , @c_ExecArguments      
                        , @c_Sparm01      
                        , @c_Sparm02    
                        , @c_Sparm03 
                        
   IF @b_debug=1          
   BEGIN            
      PRINT @c_SQL            
   END    

   --SELECT * FROM #TMP_ORDERSGRP
   ----CS01 S
   --SET @c_SQLInsert = 'INSERT INTO #TMP_ORDERSGRP (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09'  + CHAR(13) +             
   --                 + ',Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17'        

   --SET @c_SQL = 'SELECT Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09'  + CHAR(13) +             
   --           + ',Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22'  + CHAR(13) +             
   --           + ',Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34' + CHAR(13) +             
   --           + ',Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44'  + CHAR(13) +             
   --           + ',Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54'+ CHAR(13) +             
   --           + ',Col55,Col56,Col57,Col58,Col59,Col60) ' 
  
   DECLARE CUR_MAIN CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT Col01,Col02,Col03,Col04,CEILING(SUM(Col05)),Col06,col07,col08,col09,col10,             --CS01a
          col11, col12,col13,col14,col15,col16,col17  
   FROM #TMP_ORDERSGRP TOG
   JOIN #TMP_ORDERS TORD ON TORD.Orderkey=TOG.Col02
   GROUP BY Col01,Col02,Col03,Col04,Col06,col07,col08,col09,col10,
          col11, col12,col13,col14,col15,col16,col17  
   ORDER BY col02

   OPEN CUR_MAIN
   
   FETCH NEXT FROM CUR_MAIN INTO  @c_Col01, @c_Col02, @c_Col03, @c_Col04, @c_Col05
                                , @c_Col06, @c_Col07, @c_Col08, @c_Col09, @c_Col10
                                , @c_Col11, @c_Col12, @c_Col13, @c_Col14, @c_Col15
                                , @c_Col16, @c_Col17
   
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @n_TotalCarton = CAST(@c_Col05 AS INT)
      SET @n_CurrentCarton = 1

      IF @b_debug =1   --CS01
      BEGIN
        SELECT @n_CurrentCarton '@n_CurrentCarton', @c_Col05 '@c_Col05'
      END
      
      IF @n_TotalCarton <= 0
         SET @n_TotalCarton = 1

      IF @c_Sparm02 = 'TRUE'
      BEGIN
         SET @c_Col17 = N'專車'
      END
      ELSE
      BEGIN
         SET @c_Col17 = N''
      END
      
      SELECT @c_Col15 = CASE WHEN @c_Col15 ='Monday'    THEN N'一'
                             WHEN @c_Col15 ='Tuesday'   THEN N'二'
                             WHEN @c_Col15 ='Wednesday' THEN N'三'
                             WHEN @c_Col15 ='Thursday'  THEN N'四'
                             WHEN @c_Col15 ='Friday'    THEN N'五'
                             WHEN @c_Col15 ='Saturday'  THEN N'六'
                             WHEN @c_Col15 ='Sunday'    THEN N'日'
                             ELSE '' END

      SELECT @c_Col21 = ISNULL(CL.Short,'')
      FROM ORDERS OH (NOLOCK)
      JOIN StorerSODefault SOD (NOLOCK) ON OH.Consigneekey = SOD.Storerkey
      JOIN CODELKUP CL (NOLOCK) ON CL.LISTNAME = 'CARRIERKEY' AND CL.Code = SOD.Door 
                               AND CL.Storerkey = OH.StorerKey
      WHERE OH.OrderKey = @c_Col02

      IF ISNULL(@c_Col21,'') = ''
      BEGIN
         SET @c_Col21 = '#'
      END

      WHILE @n_CurrentCarton <= @n_TotalCarton
      BEGIN
         INSERT INTO #Result (Col01, Col02, Col03, Col04, Col05, Col06, Col07, Col08, Col09, Col10         
                            , Col11, Col12, Col13, Col14, Col15, Col16, Col17, Col18 ,Col19, Col20           
                            , Col21, Col22, Col23, Col24, Col25, Col26, Col27, Col28, Col29, Col30    
                            , Col31, Col32, Col33, Col34, Col35, Col36, Col37, Col38, Col39, Col40
                            , Col41, Col42, Col43, Col44, Col45, Col46, Col47, Col48, Col49, Col50
                            , Col51, Col52, Col53, Col54, Col55, Col56, Col57, Col58, Col59, Col60)
         SELECT @c_Col01, @c_Col02, @c_Col03, @c_Col04, @c_Col05
              , @c_Col06, @c_Col07, @c_Col08, @c_Col09, @c_Col10
              , @c_Col11, @c_Col12, @c_Col13, @n_CurrentCarton, @c_Col15
              , @c_Col16, @c_Col17, @c_Col18, @c_Col19, @c_Col20
              , @c_Col21, '', '', '', '', '', '', '', '', ''
              , '', '', '', '', '', '', '', '', '', ''
              , '', '', '', '', '', '', '', '', '', ''
              , '', '', '', '', '', '', '', '', '', ''

         SET @n_CurrentCarton = @n_CurrentCarton + 1
      END

      SET @c_Col21 = ''

      FETCH NEXT FROM CUR_MAIN INTO  @c_Col01, @c_Col02, @c_Col03, @c_Col04, @c_Col05
                                   , @c_Col06, @c_Col07, @c_Col08, @c_Col09, @c_Col10
                                   , @c_Col11, @c_Col12, @c_Col13, @c_Col14, @c_Col15
                                   , @c_Col16, @c_Col17
   END
   CLOSE CUR_MAIN
   DEALLOCATE CUR_MAIN

RESULT: 
   IF ISNULL(@c_Sparm03,'') = '' 
   BEGIN
      SELECT * FROM #Result    
      ORDER BY ID 
   END
   ELSE
   BEGIN
      SELECT * FROM #Result  
      WHERE Col14 = @c_Sparm03
      ORDER BY ID    
   END

QUIT_SP:
   IF CURSOR_STATUS('GLOBAL', 'CUR_MAIN') IN (0 , 1)
   BEGIN
      CLOSE CUR_MAIN
      DEALLOCATE CUR_MAIN   
   END

   IF OBJECT_ID('tempdb..#Result') IS NOT NULL
      DROP TABLE #Result

   IF OBJECT_ID('tempdb..#TMP_ORDERS') IS NOT NULL
      DROP TABLE #TMP_ORDERS

     IF OBJECT_ID('tempdb..#TMP_ORDERSGRP') IS NOT NULL
      DROP TABLE #TMP_ORDERSGRP
          
END -- procedure     

GO