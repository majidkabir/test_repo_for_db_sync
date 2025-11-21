SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Copyright: LFL                                                             */
/* Purpose: isp_BT_Bartender_TH_PACKLBL_01                                    */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date        Rev  Author     Purposes                                       */
/* 04-Apr-2023 1.0  WLChooi    Created (WMS-22045)                            */
/* 04-Apr-2023 1.0  WLChooi    DevOps Combine Script                          */
/******************************************************************************/

CREATE   PROC [dbo].[isp_BT_Bartender_TH_PACKLBL_01]
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
         , @c_Descr            NVARCHAR(80)
         , @c_Qty              NVARCHAR(80)
         , @c_SKU              NVARCHAR(80)
         , @c_UnitPrice        NVARCHAR(80)
         , @c_PaidPrice        NVARCHAR(80)
         , @c_Descr01          NVARCHAR(80)
         , @c_Descr02          NVARCHAR(80)
         , @c_Descr03          NVARCHAR(80)
         , @c_Descr04          NVARCHAR(80)
         , @c_Descr05          NVARCHAR(80)
         , @c_Descr06          NVARCHAR(80)
         , @c_Descr07          NVARCHAR(80)
         , @c_Descr08          NVARCHAR(80)
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
         , @c_UnitPrice01      NVARCHAR(80)
         , @c_UnitPrice02      NVARCHAR(80)
         , @c_UnitPrice03      NVARCHAR(80)
         , @c_UnitPrice04      NVARCHAR(80)
         , @c_UnitPrice05      NVARCHAR(80)
         , @c_UnitPrice06      NVARCHAR(80)
         , @c_UnitPrice07      NVARCHAR(80)
         , @c_UnitPrice08      NVARCHAR(80)
         , @c_PaidPrice01      NVARCHAR(80)
         , @c_PaidPrice02      NVARCHAR(80)
         , @c_PaidPrice03      NVARCHAR(80)
         , @c_PaidPrice04      NVARCHAR(80)
         , @c_PaidPrice05      NVARCHAR(80)
         , @c_PaidPrice06      NVARCHAR(80)
         , @c_PaidPrice07      NVARCHAR(80)
         , @c_PaidPrice08      NVARCHAR(80)
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
      [ID]        [INT]          IDENTITY(1, 1) NOT NULL
    , [Orderkey]  [NVARCHAR](20) NULL
    , [SKU]       [NVARCHAR](80) NULL
    , [DESCR]     [NVARCHAR](80) NULL
    , [Qty]       INT NULL
    , [UnitPrice] FLOAT NULL
    , [PaidPrice] FLOAT NULL
    , [Retrieve]  [NVARCHAR](1)  DEFAULT 'N'
   )

   SET @c_Orderkey = @c_Sparm1

   IF NOT EXISTS ( SELECT 1
                   FROM ORDERS OH (NOLOCK)
                   JOIN CODELKUP CL (NOLOCK) ON CL.LISTNAME = 'ECPACKLIST'
                                            AND CL.Notes = OH.BuyerPO
                                            AND CL.Storerkey = OH.StorerKey
                                            AND CL.Short = '1' 
                   WHERE OH.OrderKey = @c_Orderkey )
   BEGIN
      GOTO QUIT_SP
   END


   SET @c_SQLJOIN = N' SELECT DISTINCT ' + CHAR(13)
                  + N'        FORMAT(OH.OrderDate,''yyyy-MM-dd''), ISNULL(TRIM(OH.Externorderkey),''''), ' + CHAR(13) --2
                  + N'        ISNULL(TRIM(OH.C_Contact1),''''), ISNULL(TRIM(OH.C_Address1),''''), ' + CHAR(13) --4
                  + N'        ISNULL(TRIM(OH.C_Address2),'''') + ISNULL(TRIM(OH.C_Address3),''''), ' + CHAR(13) --5
                  + N'        ISNULL(TRIM(OH.C_City),'''') + ISNULL(TRIM(OH.C_State),'''') + ISNULL(TRIM(OH.C_Zip),''''), ' + CHAR(13) --6
                  + N'        ISNULL(TRIM(OH.C_Phone1),''''), OH.Storerkey, ISNULL(TRIM(OH.XDockPOKey),''''), ' + CHAR(13) --9
                  + N'        ISNULL(TRIM(F.Address2),''''), ' + CHAR(13) --10
                  + N'        ISNULL(TRIM(F.City),'''') + '' '' + ISNULL(TRIM(F.State),'''') + '' '' + ISNULL(TRIM(F.Zip),''''), ' + CHAR(13) --11
                  + N'        ISNULL(TRIM(OH.PmtTerm),''''), FORMAT(OH.DeliveryDate,''yyyy-MM-dd''), ISNULL(TRIM(OH.ExternOrderkey),''''), ' + CHAR(13) --14
                  + N'        ''*'' + ISNULL(TRIM(OH.ExternOrderkey),'''') + ''*'', '''', '''', '''', '''', '''', ' + CHAR(13) --20
                  + N'        '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', ' + CHAR(13) --30
                  + N'        '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', ' + CHAR(13) --40
                  + N'        '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', ' + CHAR(13) --50
                  + N'        '''', '''', '''', '''', '''', '''', ISNULL(CL.Long,''''), '''', '''', ''''  ' + CHAR(13) --60
                  + N' FROM ORDERS OH (NOLOCK) ' + CHAR(13)
                  + N' JOIN FACILITY F (NOLOCK) ON F.Facility = OH.Facility ' + CHAR(13)
                  + N' LEFT JOIN CODELKUP CL (NOLOCK) ON CL.LISTNAME = ''ECPacklist'' AND CL.Storerkey = OH.Storerkey ' + CHAR(13)
                  + N'                               AND CL.Notes = OH.BuyerPO ' + CHAR(13)
                  + N' WHERE OH.Orderkey = @c_Sparm1 ' + CHAR(13)

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

   INSERT INTO #TEMPSKU (Orderkey, SKU, DESCR, Qty, UnitPrice, Retrieve)
   SELECT OH.OrderKey
        , OD.Sku
        , S.DESCR
        , OD.QtyPicked + OD.ShippedQty
        , OD.UnitPrice
        , 'N'
   FROM ORDERS OH (NOLOCK)
   JOIN ORDERDETAIL OD (NOLOCK) ON OD.OrderKey = OH.OrderKey
   JOIN SKU S (NOLOCK) ON S.StorerKey = OD.StorerKey AND S.Sku = OD.Sku
   WHERE OH.OrderKey = @c_Orderkey
   GROUP BY OH.OrderKey
          , OD.Sku
          , S.DESCR
          , OD.QtyPicked + OD.ShippedQty
          , OD.UnitPrice
   ORDER BY OD.Sku

   SET @c_Descr01 = N''
   SET @c_Descr02 = N''
   SET @c_Descr03 = N''
   SET @c_Descr04 = N''
   SET @c_Descr05 = N''
   SET @c_Descr06 = N''
   SET @c_Descr07 = N''
   SET @c_Descr08 = N''
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
   SET @c_UnitPrice01 = N''
   SET @c_UnitPrice02 = N''
   SET @c_UnitPrice03 = N''
   SET @c_UnitPrice04 = N''
   SET @c_UnitPrice05 = N''
   SET @c_UnitPrice06 = N''
   SET @c_UnitPrice07 = N''
   SET @c_UnitPrice08 = N''
   SET @c_PaidPrice01 = N''
   SET @c_PaidPrice02 = N''
   SET @c_PaidPrice03 = N''
   SET @c_PaidPrice04 = N''
   SET @c_PaidPrice05 = N''
   SET @c_PaidPrice06 = N''
   SET @c_PaidPrice07 = N''
   SET @c_PaidPrice08 = N''

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
         SELECT TOP 1 Col01, Col02, Col03, Col04, Col05, Col06, Col07, Col08, Col09, Col10, Col11, Col12, Col13
                    , Col14, Col15, '', '', '', '', ''
                    , '', '', '', '', '', '', '', '', '', ''
                    , '', '', '', '', '', '', '', '', '', ''
                    , '', '', '', '', '', '', '', '', '', ''
                    , '', '', '', '', '', '', '', '', '', ''
         FROM #Result

         SET @c_Descr01 = N''
         SET @c_Descr02 = N''
         SET @c_Descr03 = N''
         SET @c_Descr04 = N''
         SET @c_Descr05 = N''
         SET @c_Descr06 = N''
         SET @c_Descr07 = N''
         SET @c_Descr08 = N''
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
         SET @c_UnitPrice01 = N''
         SET @c_UnitPrice02 = N''
         SET @c_UnitPrice03 = N''
         SET @c_UnitPrice04 = N''
         SET @c_UnitPrice05 = N''
         SET @c_UnitPrice06 = N''
         SET @c_UnitPrice07 = N''
         SET @c_UnitPrice08 = N''
         SET @c_PaidPrice01 = N''
         SET @c_PaidPrice02 = N''
         SET @c_PaidPrice03 = N''
         SET @c_PaidPrice04 = N''
         SET @c_PaidPrice05 = N''
         SET @c_PaidPrice06 = N''
         SET @c_PaidPrice07 = N''
         SET @c_PaidPrice08 = N''
      END

      SELECT @c_Descr = DESCR
           , @c_SKU = SKU
           , @c_Qty = CAST(Qty AS NVARCHAR)
           , @c_UnitPrice = CAST(UnitPrice AS NVARCHAR)
           , @c_PaidPrice = CAST(Qty * UnitPrice AS NVARCHAR)
      FROM #TEMPSKU
      WHERE ID = @n_intFlag
      GROUP BY SKU
             , DESCR
             , Qty
             , UnitPrice

      IF (@n_intFlag % @n_MaxLine) = 1
      BEGIN
         SET @c_Descr01 = @c_Descr
         SET @c_SKU01 = @c_SKU
         SET @c_Qty01 = @c_Qty
         SET @c_UnitPrice01 = @c_UnitPrice
         SET @c_PaidPrice01 = @c_PaidPrice
         SET @n_Total = CAST(@n_Total + CAST(@c_PaidPrice01 AS FLOAT) AS FLOAT)
      END
      ELSE IF (@n_intFlag % @n_MaxLine) = 2
      BEGIN
         SET @c_Descr02 = @c_Descr
         SET @c_SKU02 = @c_SKU
         SET @c_Qty02 = @c_Qty
         SET @c_UnitPrice02 = @c_UnitPrice
         SET @c_PaidPrice02 = @c_PaidPrice
         SET @n_Total = CAST(@n_Total + CAST(@c_PaidPrice02 AS FLOAT) AS FLOAT)
      END
      ELSE IF (@n_intFlag % @n_MaxLine) = 3
      BEGIN
         SET @c_Descr03 = @c_Descr
         SET @c_SKU03 = @c_SKU
         SET @c_Qty03 = @c_Qty
         SET @c_UnitPrice03 = @c_UnitPrice
         SET @c_PaidPrice03 = @c_PaidPrice
         SET @n_Total = CAST(@n_Total + CAST(@c_PaidPrice03 AS FLOAT) AS FLOAT)
      END
      ELSE IF (@n_intFlag % @n_MaxLine) = 4
      BEGIN
         SET @c_Descr04 = @c_Descr
         SET @c_SKU04 = @c_SKU
         SET @c_Qty04 = @c_Qty
         SET @c_UnitPrice04 = @c_UnitPrice
         SET @c_PaidPrice04 = @c_PaidPrice
         SET @n_Total = CAST(@n_Total + CAST(@c_PaidPrice04 AS FLOAT) AS FLOAT)
      END
      ELSE IF (@n_intFlag % @n_MaxLine) = 5
      BEGIN
         SET @c_Descr05 = @c_Descr
         SET @c_SKU05 = @c_SKU
         SET @c_Qty05 = @c_Qty
         SET @c_UnitPrice05 = @c_UnitPrice
         SET @c_PaidPrice05 = @c_PaidPrice
         SET @n_Total = CAST(@n_Total + CAST(@c_PaidPrice05 AS FLOAT) AS FLOAT)
      END
      ELSE IF (@n_intFlag % @n_MaxLine) = 6
      BEGIN
         SET @c_Descr06 = @c_Descr
         SET @c_SKU06 = @c_SKU
         SET @c_Qty06 = @c_Qty
         SET @c_UnitPrice06 = @c_UnitPrice
         SET @c_PaidPrice06 = @c_PaidPrice
         SET @n_Total = CAST(@n_Total + CAST(@c_PaidPrice06 AS FLOAT) AS FLOAT)
      END
      ELSE IF (@n_intFlag % @n_MaxLine) = 7
      BEGIN
         SET @c_Descr07 = @c_Descr
         SET @c_SKU07 = @c_SKU
         SET @c_Qty07 = @c_Qty
         SET @c_UnitPrice07 = @c_UnitPrice
         SET @c_PaidPrice07 = @c_PaidPrice
         SET @n_Total = CAST(@n_Total + CAST(@c_PaidPrice07 AS FLOAT) AS FLOAT)
      END
      ELSE IF (@n_intFlag % @n_MaxLine) = 0
      BEGIN
         SET @c_Descr08 = @c_Descr
         SET @c_SKU08 = @c_SKU
         SET @c_Qty08 = @c_Qty
         SET @c_UnitPrice08 = @c_UnitPrice
         SET @c_PaidPrice08 = @c_PaidPrice
         SET @n_Total = CAST(@n_Total + CAST(@c_PaidPrice08 AS FLOAT) AS FLOAT)
      END

      UPDATE #Result
      SET Col16 = @c_Descr01
        , Col17 = @c_Qty01
        , Col18 = @c_SKU01
        , Col19 = @c_UnitPrice01
        , Col20 = @c_PaidPrice01
        , Col21 = @c_Descr02
        , Col22 = @c_Qty02
        , Col23 = @c_SKU02
        , Col24 = @c_UnitPrice02
        , Col25 = @c_PaidPrice02
        , Col26 = @c_Descr03
        , Col27 = @c_Qty03
        , Col28 = @c_SKU03
        , Col29 = @c_UnitPrice03
        , Col30 = @c_PaidPrice03
        , Col31 = @c_Descr04
        , Col32 = @c_Qty04
        , Col33 = @c_SKU04
        , Col34 = @c_UnitPrice04
        , Col35 = @c_PaidPrice04
        , Col36 = @c_Descr05
        , Col37 = @c_Qty05
        , Col38 = @c_SKU05
        , Col39 = @c_UnitPrice05
        , Col40 = @c_PaidPrice05
        , Col41 = @c_Descr06
        , Col42 = @c_Qty06
        , Col43 = @c_SKU06
        , Col44 = @c_UnitPrice06
        , Col45 = @c_PaidPrice06
        , Col46 = @c_Descr07
        , Col47 = @c_Qty07
        , Col48 = @c_SKU07
        , Col49 = @c_UnitPrice07
        , Col50 = @c_PaidPrice07
        , Col51 = @c_Descr08
        , Col52 = @c_Qty08
        , Col53 = @c_SKU08
        , Col54 = @c_UnitPrice08
        , Col55 = @c_PaidPrice08
        , Col56 = @n_Total
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

   SELECT *
   FROM #Result WITH (NOLOCK)
END -- procedure 

GO