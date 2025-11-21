SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Copyright: MAERSK                                                          */
/* Purpose: isp_BT_Bartender_TH_PACKLBL_02                                    */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date        Rev  Author     Purposes                                       */
/* 13-Jul-2023 1.0  WLChooi    Created (WMS-23071)                            */
/* 13-Jul-2023 1.0  WLChooi    DevOps Combine Script                          */
/* 21-Jul-2023 1.1  WLChooi    WMS-23071 - Bug Fix (WL01)                     */
/******************************************************************************/

CREATE   PROC [dbo].[isp_BT_Bartender_TH_PACKLBL_02]
(
   @c_Sparm1  NVARCHAR(250)
 , @c_Sparm2  NVARCHAR(250)
 , @c_Sparm3  NVARCHAR(250)
 , @c_Sparm4  NVARCHAR(250)
 , @c_Sparm5  NVARCHAR(250)
 , @c_Sparm6  NVARCHAR(250)
 , @c_Sparm7  NVARCHAR(250)
 , @c_Sparm8  NVARCHAR(250)
 , @c_Sparm9  NVARCHAR(250)
 , @c_Sparm10 NVARCHAR(250)
 , @b_debug   INT = 0
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_ExecStatements NVARCHAR(MAX)
         , @c_ExecArguments  NVARCHAR(MAX)
         , @c_SQLJOIN        NVARCHAR(MAX)
         , @c_SQL            NVARCHAR(MAX)
         , @c_Condition      NVARCHAR(MAX)
         , @c_SQLJOINTable   NVARCHAR(MAX)
         , @c_Orderkey       NVARCHAR(10)

   DECLARE @d_Trace_StartTime  DATETIME
         , @d_Trace_EndTime    DATETIME
         , @c_Trace_ModuleName NVARCHAR(20)
         , @d_Trace_Step1      DATETIME
         , @c_Trace_Step1      NVARCHAR(20)
         , @c_UserName         NVARCHAR(50)
         , @c_Qty              NVARCHAR(80)
         , @c_SKU              NVARCHAR(80)
         , @c_ExtPrice        NVARCHAR(80)
         , @c_Qty01            NVARCHAR(80)
         , @c_Qty02            NVARCHAR(80)
         , @c_Qty03            NVARCHAR(80)
         , @c_Qty04            NVARCHAR(80)
         , @c_Qty05            NVARCHAR(80)
         , @c_Qty06            NVARCHAR(80)
         , @c_Qty07            NVARCHAR(80)
         , @c_Qty08            NVARCHAR(80)
         , @c_SKU01            NVARCHAR(80)
         , @c_SKU02            NVARCHAR(80)
         , @c_SKU03            NVARCHAR(80)
         , @c_SKU04            NVARCHAR(80)
         , @c_SKU05            NVARCHAR(80)
         , @c_SKU06            NVARCHAR(80)
         , @c_SKU07            NVARCHAR(80)
         , @c_SKU08            NVARCHAR(80)
         , @c_ExtPrice01       NVARCHAR(80)
         , @c_ExtPrice02       NVARCHAR(80)
         , @c_ExtPrice03       NVARCHAR(80)
         , @c_ExtPrice04       NVARCHAR(80)
         , @c_ExtPrice05       NVARCHAR(80)
         , @c_ExtPrice06       NVARCHAR(80)
         , @c_ExtPrice07       NVARCHAR(80)
         , @c_ExtPrice08       NVARCHAR(80)
         , @n_CntRec           INT = 1
         , @n_TTLpage          INT = 1             
         , @n_CurrentPage      INT = 1     
         , @n_MaxLine          INT = 8
         , @n_intFlag          INT = 1
         , @n_Total            FLOAT = 0.00

   SET @d_Trace_StartTime = GETDATE()
   SET @c_Trace_ModuleName = N''

   CREATE TABLE [#Result]
   (
      [ID]    [INT]          IDENTITY(1, 1) NOT NULL
    , [Col01] [NVARCHAR](80) NULL
    , [Col02] [NVARCHAR](80) NULL
    , [Col03] [NVARCHAR](80) NULL
    , [Col04] [NVARCHAR](80) NULL
    , [Col05] [NVARCHAR](80) NULL
    , [Col06] [NVARCHAR](80) NULL
    , [Col07] [NVARCHAR](80) NULL
    , [Col08] [NVARCHAR](80) NULL
    , [Col09] [NVARCHAR](80) NULL
    , [Col10] [NVARCHAR](80) NULL
    , [Col11] [NVARCHAR](80) NULL
    , [Col12] [NVARCHAR](80) NULL
    , [Col13] [NVARCHAR](80) NULL
    , [Col14] [NVARCHAR](80) NULL
    , [Col15] [NVARCHAR](80) NULL
    , [Col16] [NVARCHAR](80) NULL
    , [Col17] [NVARCHAR](80) NULL
    , [Col18] [NVARCHAR](80) NULL
    , [Col19] [NVARCHAR](80) NULL
    , [Col20] [NVARCHAR](80) NULL
    , [Col21] [NVARCHAR](80) NULL
    , [Col22] [NVARCHAR](80) NULL
    , [Col23] [NVARCHAR](80) NULL
    , [Col24] [NVARCHAR](80) NULL
    , [Col25] [NVARCHAR](80) NULL
    , [Col26] [NVARCHAR](80) NULL
    , [Col27] [NVARCHAR](80) NULL
    , [Col28] [NVARCHAR](80) NULL
    , [Col29] [NVARCHAR](80) NULL
    , [Col30] [NVARCHAR](80) NULL
    , [Col31] [NVARCHAR](80) NULL
    , [Col32] [NVARCHAR](80) NULL
    , [Col33] [NVARCHAR](80) NULL
    , [Col34] [NVARCHAR](80) NULL
    , [Col35] [NVARCHAR](80) NULL
    , [Col36] [NVARCHAR](80) NULL
    , [Col37] [NVARCHAR](80) NULL
    , [Col38] [NVARCHAR](80) NULL
    , [Col39] [NVARCHAR](80) NULL
    , [Col40] [NVARCHAR](80) NULL
    , [Col41] [NVARCHAR](80) NULL
    , [Col42] [NVARCHAR](80) NULL
    , [Col43] [NVARCHAR](80) NULL
    , [Col44] [NVARCHAR](80) NULL
    , [Col45] [NVARCHAR](80) NULL
    , [Col46] [NVARCHAR](80) NULL
    , [Col47] [NVARCHAR](80) NULL
    , [Col48] [NVARCHAR](80) NULL
    , [Col49] [NVARCHAR](80) NULL
    , [Col50] [NVARCHAR](80) NULL
    , [Col51] [NVARCHAR](80) NULL
    , [Col52] [NVARCHAR](80) NULL
    , [Col53] [NVARCHAR](80) NULL
    , [Col54] [NVARCHAR](80) NULL
    , [Col55] [NVARCHAR](80) NULL
    , [Col56] [NVARCHAR](80) NULL
    , [Col57] [NVARCHAR](80) NULL
    , [Col58] [NVARCHAR](80) NULL
    , [Col59] [NVARCHAR](80) NULL
    , [Col60] [NVARCHAR](80) NULL
   )

   CREATE TABLE [#TEMPSKU]
   (
      [ID]              [INT]          IDENTITY(1, 1) NOT NULL
    , [Orderkey]        [NVARCHAR](20) NULL
    , [SKU]             [NVARCHAR](80) NULL
    , [Qty]             [INT] NULL
    , [ExtendedPrice]   [FLOAT] NULL
    , [Retrieve]        [NVARCHAR](1)  DEFAULT 'N'
   )

   SET @c_Orderkey = @c_Sparm1

   SET @c_SQLJOIN = N' SELECT DISTINCT ' + CHAR(13)
                  + N'        ISNULL(TRIM(OH.B_Contact1),''''), ISNULL(TRIM(OH.B_Address1),''''), ' + CHAR(13) --2
                  + N'        ISNULL(TRIM(OH.B_Address2),''''), ISNULL(TRIM(OH.B_Address3),''''), ' + CHAR(13) --4
                  + N'        ISNULL(TRIM(OH.B_Address4),''''), ISNULL(TRIM(OH.C_Contact1),''''), ' + CHAR(13) --6
                  + N'        ISNULL(TRIM(OH.C_Address1),''''), ISNULL(TRIM(OH.C_Address2),''''), ' + CHAR(13) --8
                  + N'        ISNULL(TRIM(OH.C_Address3),''''), ISNULL(TRIM(OH.C_Address4),''''), ' + CHAR(13) --10
                  + N'        ISNULL(TRIM(OH.C_City),''''), ' + CHAR(13) --11
                  + N'        '''', '''', '''', '''', '''', '''', '''', '''', '''', ' + CHAR(13) --20
                  + N'        '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', ' + CHAR(13) --30
                  + N'        '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', ' + CHAR(13) --40
                  + N'        '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', ' + CHAR(13) --50
                  + N'        '''', '''', '''', '''', '''', '''', '''', '''', '''', OH.Orderkey  ' + CHAR(13) --60
                  + N' FROM ORDERS OH (NOLOCK) ' + CHAR(13)
                  + N' WHERE OH.Orderkey = @c_Sparm1 ' + CHAR(13)
                  + N' AND OH.OrderGroup = ''ECOM'' ' + CHAR(13)

   IF @b_debug = 1
   BEGIN
      PRINT @c_SQLJOIN
   END

   SET @c_SQL = N' INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09' + CHAR(13)
                + N'                   ,Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22' + CHAR(13)
                + N'                   ,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34' + CHAR(13) 
                + N'                   ,Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44' + CHAR(13) 
                + N'                   ,Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54' + CHAR(13) 
                + N'                   ,Col55,Col56,Col57,Col58,Col59,Col60) '

   SET @c_SQL = @c_SQL + @c_SQLJOIN

   SET @c_ExecArguments = N'  @c_Sparm1         NVARCHAR(80)' 
                        + N' ,@c_Sparm2         NVARCHAR(80)'
                        + N' ,@c_Sparm3         NVARCHAR(80)' 
                        + N' ,@c_Sparm4         NVARCHAR(80)'
                        + N' ,@c_Sparm5         NVARCHAR(80)'

   EXEC sp_executesql @c_SQL
                    , @c_ExecArguments
                    , @c_Sparm1
                    , @c_Sparm2
                    , @c_Sparm3
                    , @c_Sparm4
                    , @c_Sparm5

   INSERT INTO #TEMPSKU (Orderkey, SKU, Qty, ExtendedPrice, Retrieve)
   SELECT OH.OrderKey
        , TRIM(S.DESCR)
        , SUM(PD.Qty)
        , OD.ExtendedPrice
        , 'N'
   FROM ORDERS OH (NOLOCK)
   JOIN ORDERDETAIL OD (NOLOCK) ON OD.OrderKey = OH.OrderKey
   JOIN SKU S (NOLOCK) ON S.StorerKey = OD.StorerKey AND S.Sku = OD.Sku
   JOIN PICKDETAIL PD (NOLOCK) ON PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber 
                              AND PD.SKU = OD.SKU AND PD.Storerkey = OD.StorerKey
   WHERE OH.OrderKey = @c_Orderkey
   GROUP BY OH.OrderKey
          , TRIM(S.DESCR)
          , OD.ExtendedPrice
   ORDER BY TRIM(S.DESCR)

   SET @c_Qty01 = N''
   SET @c_Qty02 = N''
   SET @c_Qty03 = N''
   SET @c_Qty04 = N''
   SET @c_Qty05 = N''
   SET @c_Qty06 = N''
   SET @c_Qty07 = N''
   SET @c_Qty08 = N''
   SET @c_SKU01 = N''
   SET @c_SKU02 = N''
   SET @c_SKU03 = N''
   SET @c_SKU04 = N''
   SET @c_SKU05 = N''
   SET @c_SKU06 = N''
   SET @c_SKU07 = N''
   SET @c_SKU08 = N''
   SET @c_ExtPrice01 = N''
   SET @c_ExtPrice02 = N''
   SET @c_ExtPrice03 = N''
   SET @c_ExtPrice04 = N''
   SET @c_ExtPrice05 = N''
   SET @c_ExtPrice06 = N''
   SET @c_ExtPrice07 = N''
   SET @c_ExtPrice08 = N''

   SELECT @n_CntRec = COUNT(1)
   FROM #TEMPSKU
   WHERE Orderkey = @c_Orderkey AND Retrieve = 'N'

   SET @n_TTLpage = FLOOR(@n_CntRec / @n_MaxLine) + CASE WHEN @n_CntRec % @n_MaxLine > 0 THEN 1
                                                         ELSE 0 END

   WHILE @n_intFlag <= @n_CntRec
   BEGIN
      IF @n_intFlag > @n_MaxLine AND (@n_intFlag % @n_MaxLine) = 1
      BEGIN
         SET @n_CurrentPage = @n_CurrentPage + 1

         IF (@n_CurrentPage > @n_TTLpage)
         BEGIN
            BREAK;
         END

         INSERT INTO #Result (Col01, Col02, Col03, Col04, Col05, Col06, Col07, Col08, Col09, Col10, Col11, Col12, Col13
                            , Col14, Col15, Col16, Col17, Col18, Col19, Col20, Col21, Col22, Col23, Col24, Col25, Col26
                            , Col27, Col28, Col29, Col30, Col31, Col32, Col33, Col34, Col35, Col36, Col37, Col38, Col39
                            , Col40, Col41, Col42, Col43, Col44, Col45, Col46, Col47, Col48, Col49, Col50, Col51, Col52
                            , Col53, Col54, Col55, Col56, Col57, Col58, Col59, Col60)
         SELECT TOP 1 Col01, Col02, Col03, Col04, Col05, Col06, Col07, Col08, Col09, Col10, Col11, '', ''
                    , '', '', '', '', '', '', ''
                    , '', '', '', '', '', '', '', '', '', ''
                    , '', '', '', '', '', '', '', '', '', ''
                    , '', '', '', '', '', '', '', '', '', ''
                    , '', '', '', '', '', '', '', '', '', Col60
         FROM #Result

         SET @c_Qty01 = N''
         SET @c_Qty02 = N''
         SET @c_Qty03 = N''
         SET @c_Qty04 = N''
         SET @c_Qty05 = N''
         SET @c_Qty06 = N''
         SET @c_Qty07 = N''
         SET @c_Qty08 = N''
         SET @c_SKU01 = N''
         SET @c_SKU02 = N''
         SET @c_SKU03 = N''
         SET @c_SKU04 = N''
         SET @c_SKU05 = N''
         SET @c_SKU06 = N''
         SET @c_SKU07 = N''
         SET @c_SKU08 = N''
         SET @c_ExtPrice01 = N''
         SET @c_ExtPrice02 = N''
         SET @c_ExtPrice03 = N''
         SET @c_ExtPrice04 = N''
         SET @c_ExtPrice05 = N''
         SET @c_ExtPrice06 = N''
         SET @c_ExtPrice07 = N''
         SET @c_ExtPrice08 = N''
      END

      SELECT @c_SKU = SKU
           , @c_Qty = CAST(Qty AS NVARCHAR)
           , @c_ExtPrice = CAST(ExtendedPrice AS NUMERIC(20,2))
      FROM #TEMPSKU
      WHERE ID = @n_intFlag
      GROUP BY SKU
             , Qty
             , ExtendedPrice

      IF (@n_intFlag % @n_MaxLine) = 1
      BEGIN
         SET @c_SKU01 = @c_SKU
         SET @c_Qty01 = @c_Qty
         SET @c_ExtPrice01 = @c_ExtPrice
         SET @n_Total = CAST(@n_Total + CAST(@c_ExtPrice01 AS NUMERIC(20,2)) AS NUMERIC(20,2))
      END
      ELSE IF (@n_intFlag % @n_MaxLine) = 2
      BEGIN
         SET @c_SKU02 = @c_SKU
         SET @c_Qty02 = @c_Qty
         SET @c_ExtPrice02 = @c_ExtPrice
         SET @n_Total = CAST(@n_Total + CAST(@c_ExtPrice02 AS NUMERIC(20,2)) AS NUMERIC(20,2))
      END
      ELSE IF (@n_intFlag % @n_MaxLine) = 3
      BEGIN
         SET @c_SKU03 = @c_SKU
         SET @c_Qty03 = @c_Qty
         SET @c_ExtPrice03 = @c_ExtPrice
         SET @n_Total = CAST(@n_Total + CAST(@c_ExtPrice03 AS NUMERIC(20,2)) AS NUMERIC(20,2))
      END
      ELSE IF (@n_intFlag % @n_MaxLine) = 4
      BEGIN
         SET @c_SKU04 = @c_SKU
         SET @c_Qty04 = @c_Qty
         SET @c_ExtPrice04 = @c_ExtPrice
         SET @n_Total = CAST(@n_Total + CAST(@c_ExtPrice04 AS NUMERIC(20,2)) AS NUMERIC(20,2))
      END
      ELSE IF (@n_intFlag % @n_MaxLine) = 5
      BEGIN
         SET @c_SKU05 = @c_SKU
         SET @c_Qty05 = @c_Qty
         SET @c_ExtPrice05 = @c_ExtPrice
         SET @n_Total = CAST(@n_Total + CAST(@c_ExtPrice05 AS NUMERIC(20,2)) AS NUMERIC(20,2))
      END
      ELSE IF (@n_intFlag % @n_MaxLine) = 6
      BEGIN
         SET @c_SKU06 = @c_SKU
         SET @c_Qty06 = @c_Qty
         SET @c_ExtPrice06 = @c_ExtPrice
         SET @n_Total = CAST(@n_Total + CAST(@c_ExtPrice06 AS NUMERIC(20,2)) AS NUMERIC(20,2))
      END
      ELSE IF (@n_intFlag % @n_MaxLine) = 7
      BEGIN
         SET @c_SKU07 = @c_SKU
         SET @c_Qty07 = @c_Qty
         SET @c_ExtPrice07 = @c_ExtPrice
         SET @n_Total = CAST(@n_Total + CAST(@c_ExtPrice07 AS NUMERIC(20,2)) AS NUMERIC(20,2))
      END
      ELSE IF (@n_intFlag % @n_MaxLine) = 0
      BEGIN
         SET @c_SKU08 = @c_SKU
         SET @c_Qty08 = @c_Qty
         SET @c_ExtPrice08 = @c_ExtPrice
         SET @n_Total = CAST(@n_Total + CAST(@c_ExtPrice08 AS NUMERIC(20,2)) AS NUMERIC(20,2))
      END

      UPDATE #Result
      SET Col12 = @c_SKU01
        , Col13 = @c_Qty01
        , Col14 = @c_ExtPrice01
        , Col15 = @c_SKU02
        , Col16 = @c_Qty02
        , Col17 = @c_ExtPrice02
        , Col18 = @c_SKU03
        , Col19 = @c_Qty03
        , Col20 = @c_ExtPrice03
        , Col21 = @c_SKU04
        , Col22 = @c_Qty04
        , Col23 = @c_ExtPrice04
        , Col24 = @c_SKU05
        , Col25 = @c_Qty05
        , Col26 = @c_ExtPrice05
        , Col27 = @c_SKU06
        , Col28 = @c_Qty06
        , Col29 = @c_ExtPrice06
        , Col30 = @c_SKU07
        , Col31 = @c_Qty07
        , Col32 = @c_ExtPrice07
        , Col33 = @c_SKU08
        , Col34 = @c_Qty08
        , Col35 = @c_ExtPrice08
      WHERE ID = @n_CurrentPage

      UPDATE #TEMPSKU
      SET Retrieve = 'Y'
      WHERE ID = @n_intFlag

      SET @n_intFlag = @n_intFlag + 1

      IF @n_intFlag > @n_CntRec
      BEGIN
         BREAK;
      END
   END

   QUIT_SP:

   SET @d_Trace_EndTime = GETDATE()
   SET @c_UserName = SUSER_SNAME()

   SELECT @n_intFlag = MAX(R.ID)
   FROM #Result R

   UPDATE #RESULT
   SET Col36 = IIF(ID = @n_intFlag, CAST(@n_Total AS NUMERIC(20,2)), NULL)
   WHERE Col60 = @c_Orderkey

   SELECT ID
        , Col01
        , Col02
        , Col03
        , Col04
        , Col05
        , Col06
        , Col07
        , Col08
        , Col09
        , Col10
        , Col11
        , Col12
        , Col13
        , Col14 = CASE WHEN ISNUMERIC(Col14) = 1 THEN FORMAT(CAST(Col14 AS NUMERIC(20,2)), '##,###,##0.00') ELSE Col14 END   --WL01
        , Col15
        , Col16
        , Col17 = CASE WHEN ISNUMERIC(Col17) = 1 THEN FORMAT(CAST(Col17 AS NUMERIC(20,2)), '##,###,##0.00') ELSE Col17 END   --WL01
        , Col18
        , Col19
        , Col20 = CASE WHEN ISNUMERIC(Col20) = 1 THEN FORMAT(CAST(Col20 AS NUMERIC(20,2)), '##,###,##0.00') ELSE Col20 END   --WL01
        , Col21
        , Col22
        , Col23 = CASE WHEN ISNUMERIC(Col23) = 1 THEN FORMAT(CAST(Col23 AS NUMERIC(20,2)), '##,###,##0.00') ELSE Col23 END   --WL01
        , Col24
        , Col25
        , Col26 = CASE WHEN ISNUMERIC(Col26) = 1 THEN FORMAT(CAST(Col26 AS NUMERIC(20,2)), '##,###,##0.00') ELSE Col26 END   --WL01
        , Col27
        , Col28
        , Col29 = CASE WHEN ISNUMERIC(Col29) = 1 THEN FORMAT(CAST(Col29 AS NUMERIC(20,2)), '##,###,##0.00') ELSE Col29 END   --WL01
        , Col30
        , Col31
        , Col32 = CASE WHEN ISNUMERIC(Col32) = 1 THEN FORMAT(CAST(Col32 AS NUMERIC(20,2)), '##,###,##0.00') ELSE Col32 END   --WL01
        , Col33
        , Col34
        , Col35 = CASE WHEN ISNUMERIC(Col35) = 1 THEN FORMAT(CAST(Col35 AS NUMERIC(20,2)), '##,###,##0.00') ELSE Col35 END   --WL01
        , Col36 = CASE WHEN ISNUMERIC(Col36) = 1 THEN FORMAT(CAST(Col36 AS NUMERIC(20,2)), '##,###,##0.00') ELSE Col36 END   --WL01
        , Col37
        , Col38
        , Col39
        , Col40
        , Col41
        , Col42
        , Col43
        , Col44
        , Col45
        , Col46
        , Col47
        , Col48
        , Col49
        , Col50
        , Col51
        , Col52
        , Col53
        , Col54
        , Col55
        , Col56
        , Col57
        , Col58
        , Col59
        , Col60
   FROM #Result WITH (NOLOCK)
END -- procedure 

GO