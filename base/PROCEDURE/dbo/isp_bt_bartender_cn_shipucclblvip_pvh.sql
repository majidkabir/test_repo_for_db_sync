SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/********************************************************************************/
/* Copyright: LFL                                                               */
/* Purpose: isp_BT_Bartender_CN_SHIPUCCLBLVIP_PVH                               */
/*                                                                              */
/* Modifications log:                                                           */
/*                                                                              */
/* Date       Rev  Author     Purposes                                          */
/* 2022-08-10 1.0  CHONGCS    Devops Scripts Combine & Created (WMS-20299)      */
/********************************************************************************/

CREATE PROC [dbo].[isp_BT_Bartender_CN_SHIPUCCLBLVIP_PVH]
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

      @c_UserDefine05    NVARCHAR(80),
      @c_Orderkey        NVARCHAR(10),
      @c_CartonNo        NVARCHAR(10),
      @n_SumQty          INT,
      @c_Sorting         NVARCHAR(4000),
      @c_ExtraSQL        NVARCHAR(4000),
      @c_JoinStatement   NVARCHAR(4000)

  DECLARE  @d_Trace_StartTime   DATETIME,
           @d_Trace_EndTime    DATETIME,
           @c_Trace_ModuleName NVARCHAR(20),
           @d_Trace_Step1      DATETIME,
           @c_Trace_Step1      NVARCHAR(20),
           @c_UserName         NVARCHAR(20)

   DECLARE @n_FirstPos INT, @n_SecondPos INT, @n_TotalLength INT, @c_Col15 NVARCHAR(80), @c_Col16 NVARCHAR(80)

   SET @d_Trace_StartTime = GETDATE()
   SET @c_Trace_ModuleName = ''

   SET @n_CurrentPage = 1
   SET @n_TTLpage = 1
   SET @n_MaxLine = 6
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

   CREATE TABLE #Temp_Orderdetail (
       [ID]               [INT] IDENTITY(1,1) NOT NULL,
       [Orderkey]         [NVARCHAR] (80) NULL,
       [CartonNo]         [NVARCHAR] (80) NULL,
       [OrderLineNumber]  [NVARCHAR] (80) NULL,
       [SKU]              [NVARCHAR] (80) NULL,
       [Retreive]         [NVARCHAR] (80) NULL
      )

   SET @c_Sorting = N' ORDER BY OH.Orderkey, PD.CartonNo DESC '

   SET @c_SQLJOIN = + ' SELECT DISTINCT ISNULL(OH.M_Company,''''), OH.trackingno, SUBSTRING(ISNULL(OH.Notes,''''),1,80), ISNULL(OH.C_Contact1,''''), ISNULL(OH.C_Phone2,''''), '  + CHAR(13)   --5 --CS01
                    + ' ISNULL(OH.C_Phone1,''''), ISNULL(OH.C_Address2,''''), ISNULL(OH.C_Address3,''''), ISNULL(OH.DeliveryPlace,''''), ISNULL(OH.CurrencyCode,''''), '  + CHAR(13)   --10
                    + ' ISNULL(CT.UDF02,''''), ISNULL(CT.UDF03,''''), ISNULL(CT.UDF01,''''), SUBSTRING(ISNULL(CT.Printdata,''''),1,80), ' + CHAR(13)   --14
                    + ' ISNULL(OH.Userdefine05,''''), '''', CONVERT(NVARCHAR(80), ISNULL(OH.Userdefine06,''''), 121), '''', '''', '''',  '  + CHAR(13)   --20
                    + ' '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', '  + CHAR(13)   --30
                    + ' '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', '  + CHAR(13)   --40
                    + ' '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', '  + CHAR(13)   --50
                    + ' '''', '''', '''', '''', '''', '''', '''', OH.Orderkey, PD.CartonNo, ''CN'' ' + CHAR(13)   --60
                    + ' FROM PACKHEADER PH WITH (NOLOCK)' + CHAR(13)
                    + ' JOIN PACKDETAIL PD WITH (NOLOCK) ON PH.Pickslipno = PD.Pickslipno'   + CHAR(13)
                    +   @c_JoinStatement
                    + ' LEFT JOIN CartonTrack CT WITH (NOLOCK) ON CT.TrackingNo = OH.trackingno AND CT.LabelNo = OH.Orderkey ' + CHAR(13)   --CS01
                    + ' WHERE PD.Pickslipno = @c_Sparm01 ' + CHAR(13)
                    + ' AND PD.CartonNo BETWEEN CAST(@c_Sparm02 AS INT) AND CAST(@c_Sparm03 AS INT) ' + CHAR(13)
                    + @c_Sorting
--PRINT @c_SQLJOIN

   IF @b_debug=1
   BEGIN
      PRINT @c_SQLJOIN
   END

   SET @c_SQL = 'INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09'  + CHAR(13) +
              + ',Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22'  + CHAR(13) +
              + ',Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34' + CHAR(13) +
              + ',Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44'  + CHAR(13) +
              + ',Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54'+ CHAR(13) +
              + ',Col55,Col56,Col57,Col58,Col59,Col60) '


   SET @c_SQL = @c_SQL + @c_SQLJOIN

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
   SELECT DISTINCT Col15, Col58, CAST(Col59 AS INT)
   FROM #Result
   WHERE Col60 = 'CN'
   ORDER BY Col58, CAST(Col59 AS INT)

   OPEN CUR_RowNoLoop

   FETCH NEXT FROM CUR_RowNoLoop INTO @c_UserDefine05, @c_Orderkey, @c_CartonNo

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SELECT @n_FirstPos    = CHARINDEX('|',@c_UserDefine05)
      SELECT @n_TotalLength = LEN(LTRIM(RTRIM(@c_UserDefine05)))

      IF @n_FirstPos > 0
      BEGIN
         SELECT @c_Col15 = SUBSTRING(@c_UserDefine05, 1, @n_FirstPos - 1)
         SELECT @c_Col16 = SUBSTRING(@c_UserDefine05, @n_FirstPos + 1, @n_TotalLength - @n_FirstPos)
      END
      ELSE
      BEGIN
         SELECT @c_Col15 = @c_UserDefine05
         SELECT @c_Col16 = @c_UserDefine05
      END

      UPDATE #Result
      SET Col15 = @c_Col15,
          Col16 = @c_Col16
      WHERE Col58 = @c_Orderkey

      IF @b_debug = 1
         SELECT @n_FirstPos, @c_Col15, @c_Col16, @n_TotalLength, @c_UserDefine05

      INSERT INTO #Temp_Orderdetail
      SELECT OH.OrderKey, PD.CartonNo, OD.OrderLineNumber, SUBSTRING(ISNULL(OD.Notes2,''),1,80), 'N'
      FROM ORDERS OH WITH (NOLOCK)
      JOIN PACKHEADER PH WITH (NOLOCK) ON OH.OrderKey = PH.OrderKey
      JOIN PACKDETAIL PD WITH (NOLOCK) ON PH.PickSlipNo = PD.Pickslipno
      JOIN ORDERDETAIL OD WITH (NOLOCK) ON OH.OrderKey = OD.OrderKey AND PD.SKU = OD.SKU
      WHERE OH.Orderkey = @c_Orderkey
      AND PD.CartonNo = CAST(@c_CartonNo AS INT)
      GROUP BY OH.OrderKey, PD.CartonNo, OD.OrderLineNumber, SUBSTRING(ISNULL(OD.Notes2,''),1,80)
      ORDER BY CAST(OD.OrderLineNumber AS INT)

      SET @c_SKU01  = ''
      SET @c_SKU02  = ''
      SET @c_SKU03  = ''
      SET @c_SKU04  = ''
      SET @c_SKU05  = ''
      SET @c_SKU06  = ''

      IF @b_debug = 1
         SELECT * FROM #Temp_Orderdetail

      SELECT @n_CntRec = COUNT (1)
      FROM #Temp_Orderdetail
      WHERE Orderkey = @c_Orderkey
      AND CartonNo = @c_CartonNo
      AND Retreive = 'N'

      SET @n_TTLpage =  FLOOR(@n_CntRec / @n_MaxLine ) + CASE WHEN @n_CntRec % @n_MaxLine > 0 THEN 1 ELSE 0 END

      WHILE @n_intFlag <= @n_CntRec AND @n_intFlag <= @n_MaxLine
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
                        Col11,Col12,Col13,Col14,Col15,Col16,Col17,'','','',
                        '','','','','','','','','','',
                        '','','','','', '','','','','',
                        '','','','','', '','','','','',
                        '','','','','', '','',Col58,Col59,Col60
            FROM #Result WHERE Col58 <> ''

            SET @c_SKU01  = ''
            SET @c_SKU02  = ''
            SET @c_SKU03  = ''
            SET @c_SKU04  = ''
            SET @c_SKU05  = ''
            SET @c_SKU06  = ''
         END

         SELECT @c_SKU = ISNULL(SKU,'')
         FROM #Temp_Orderdetail
         WHERE ID = @n_intFlag

         IF (@n_intFlag % @n_MaxLine) = 1 --AND @n_recgrp = @n_CurrentPage
         BEGIN
            SET @c_SKU01 = @c_SKU
         END
         ELSE IF (@n_intFlag % @n_MaxLine) = 2 --AND @n_recgrp = @n_CurrentPage
         BEGIN
            SET @c_SKU02 = @c_SKU
         END
         ELSE IF (@n_intFlag % @n_MaxLine) = 3 --AND @n_recgrp = @n_CurrentPage
         BEGIN
            SET @c_SKU03 = @c_SKU
         END
         ELSE IF (@n_intFlag % @n_MaxLine) = 4 --AND @n_recgrp = @n_CurrentPage
         BEGIN
            SET @c_SKU04 = @c_SKU
         END
         ELSE IF (@n_intFlag % @n_MaxLine) = 5 --AND @n_recgrp = @n_CurrentPage
         BEGIN
            SET @c_SKU05 = @c_SKU
         END
         ELSE IF (@n_intFlag % @n_MaxLine) = 0 --AND @n_recgrp = @n_CurrentPage
         BEGIN
            SET @c_SKU06 = @c_SKU
         END

         UPDATE #Result
         SET   Col18 = @c_SKU01
             , Col19 = @c_SKU02
             , Col20 = @c_SKU03
             , Col21 = @c_SKU04
             , Col22 = @c_SKU05
             , Col23 = @c_SKU06
         WHERE ID = @n_CurrentPage AND Col58 <> ''

         UPDATE #Temp_Orderdetail
         SET Retreive = 'Y'
         WHERE ID = @n_intFlag

         SET @n_intFlag = @n_intFlag + 1

         IF @n_intFlag > @n_CntRec AND @n_intFlag > @n_MaxLine
         BEGIN
            BREAK;
         END
      END

      FETCH NEXT FROM CUR_RowNoLoop INTO @c_UserDefine05, @c_Orderkey, @c_CartonNo
   END
   CLOSE CUR_RowNoLoop
   DEALLOCATE CUR_RowNoLoop

RESULT:
   SELECT * FROM #Result (nolock)
   ORDER BY ID

EXIT_SP:

   SET @d_Trace_EndTime = GETDATE()
   SET @c_UserName = SUSER_SNAME()

END -- procedure

GO