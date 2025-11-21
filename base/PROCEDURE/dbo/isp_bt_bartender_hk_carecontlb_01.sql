SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Copyright: LFL                                                             */
/* Purpose: isp_BT_Bartender_HK_CARECONTLB_01                                 */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date        Rev  Author     Purposes                                       */
/* 21-Mar-2023 1.0  WLChooi    Created (WMS-21992)                            */
/* 21-Mar-2023 1.0  WLChooi    DevOps Combine Script                          */
/* 22-Mar-2023 1.1  ML         Fine tuned  @c_SQLJOIN                         */
/* 09-Oct-2023 1.2  ML         Fix multi record for single SKU                */
/******************************************************************************/

CREATE   PROC [dbo].[isp_BT_Bartender_HK_CARECONTLB_01]
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
         , @n_ID               INT
         , @n_RecID            BIGINT
         , @c_Data             NVARCHAR(MAX)
         , @c_ColValue         NVARCHAR(MAX)
         , @n_Loop             INT = 1
         , @c_WhereCondition   NVARCHAR(500) = ''
         , @n_NoOfCopy         INT = 1

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

   CREATE TABLE [#Result1]
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

   IF ISNULL(@c_Sparm3,'') <> ''
      SET @c_WhereCondition = @c_WhereCondition + ' AND PD.SKU = @c_Sparm3 '

   --   SET @c_SQLJOIN = N' SELECT DISTINCT ' + CHAR(13)
   --                  + N'        ISNULL(C1.Notes,''''), '''', '''', '''', '''',  ' + CHAR(13)   --5
   --                  + N'        '''', '''', '''', '''', '''', ' + CHAR(13) --10
   --                  + N'        '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', ' + CHAR(13) --20
   --                  + N'        '''', '''', '''', '''', '''', '''', S.Style, S.Color, OH.C_Country, S.SKU, ' + CHAR(13) --30
   --                  + N'        PID.Lot, LA.Lottable03, '''', '''', '''', '''', '''', '''', '''', '''', ' + CHAR(13) --40
   --                  + N'        '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', ' + CHAR(13) --50
   --                  + N'        '''', '''', '''', '''', '''', '''', '''', '''', '''', DI.RecordID  ' + CHAR(13) --60
   --                  + N' FROM PACKDETAIL PD (NOLOCK) ' + CHAR(13)
   --                  + N' JOIN PACKHEADER PH (NOLOCK) ON PD.Pickslipno = PH.Pickslipno ' + CHAR(13)
   --                  + N' JOIN ORDERS OH (NOLOCK) ON PH.Orderkey = OH.Orderkey ' + CHAR(13)
   --                  + N' JOIN PICKDETAIL PID (NOLOCK) ON PID.Orderkey = OH.Orderkey AND PID.Storerkey = PD.Storerkey ' + CHAR(13)
   --                  + N'                             AND PID.SKU = PD.SKU ' + CHAR(13)
   --                  + N' JOIN LOTATTRIBUTE LA (NOLOCK) ON LA.Lot = PID.Lot ' + CHAR(13)
   --                  + N' JOIN SKU S (NOLOCK) ON S.Storerkey = PID.Storerkey AND S.SKU = PID.SKU ' + CHAR(13)
   --                  + N' JOIN CODELKUP CL (NOLOCK) ON CL.LISTNAME = ''LULUCC'' AND CL.Code  = OH.C_Country ' + CHAR(13)
   --                  + N'                          AND CL.Storerkey = OH.StorerKey ' + CHAR(13)
   --                  + N' JOIN CODELKUP C1 (NOLOCK) ON C1.LISTNAME = ''LUCCCOO'' AND C1.Code  = LA.Lottable03 ' + CHAR(13)
   --                  + N'                          AND C1.Storerkey = OH.StorerKey AND C1.code2 = OH.C_Country ' + CHAR(13)
   --                  + N' JOIN DOCINFO DI (NOLOCK) ON DI.Storerkey = OH.Storerkey AND DI.Tablename = ''CC'' ' + CHAR(13)
   --                  + N'                         AND DI.Key1 = S.Style AND DI.Key2 = CL.Code2 ' + CHAR(13)
   --                  + N'                         AND DI.Key3 = S.Color ' + CHAR(13)
   --                  + N' WHERE PD.Storerkey = @c_Sparm1 AND PD.LabelNo = @c_Sparm2 ' + CHAR(13)


   SET @c_SQLJOIN = N' SELECT ISNULL((SELECT TOP 1 c.Notes ' + CHAR(13)
                  + N'        FROM PICKDETAIL a(NOLOCK) ' + CHAR(13)
                  + N'        JOIN LOTATTRIBUTE b(NOLOCK) ON a.Lot=b.Lot ' + CHAR(13)
                  + N'        JOIN CODELKUP c(NOLOCK) ON c.LISTNAME = ''LUCCCOO'' AND c.Code = b.Lottable03 AND c.Storerkey = a.StorerKey AND c.code2 = OH.C_Country ' + CHAR(13)
                  + N'        WHERE a.Orderkey=OH.Orderkey AND a.Storerkey=PD.Storerkey AND a.Sku=PD.Sku),''''), '''', '''', '''', '''',  ' + CHAR(13)   --5
                  + N'        '''', '''', '''', '''', '''', ' + CHAR(13) --10
                  + N'        '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', ' + CHAR(13) --20
                  + N'        '''', '''', '''', '''', '''', '''', S.Style, S.Color, OH.C_Country, S.SKU, ' + CHAR(13) --30
                  + N'        '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', ' + CHAR(13) --40
                  + N'        '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', ' + CHAR(13) --50
                  + N'        '''', '''', '''', '''', '''', '''', '''', '''', '''', DI.RecordID  ' + CHAR(13) --60
                  + N' FROM PACKDETAIL PD (NOLOCK) ' + CHAR(13)
                  + N' JOIN PACKHEADER PH (NOLOCK) ON PD.Pickslipno = PH.Pickslipno ' + CHAR(13)
                  + N' JOIN ORDERS OH (NOLOCK) ON PH.Orderkey = OH.Orderkey ' + CHAR(13)
                  + N' JOIN SKU S (NOLOCK) ON S.Storerkey = PD.Storerkey AND S.SKU = PD.SKU ' + CHAR(13)
                  + N' JOIN CODELKUP CL (NOLOCK) ON CL.LISTNAME = ''LULUCC'' AND CL.Code  = OH.C_Country ' + CHAR(13)
                  + N'                          AND CL.Storerkey = OH.StorerKey ' + CHAR(13)
                  + N' JOIN DOCINFO DI (NOLOCK) ON DI.Storerkey = OH.Storerkey AND DI.Tablename = ''CC'' ' + CHAR(13)
                  + N'                         AND DI.Key1 = S.Style AND DI.Key2 = CL.Code2 ' + CHAR(13)
                  + N'                         AND RIGHT(REPLICATE(''0'',10)+RTRIM(S.Color),10)=RIGHT(REPLICATE(''0'',10)+RTRIM(DI.Key3),10) ' + CHAR(13)
                  + N' JOIN SEQKey SQ (NOLOCK) ON Rowref<=PD.Qty ' + CHAR(13)
                  + N' WHERE PD.Storerkey = @c_Sparm1 AND PD.LabelNo = @c_Sparm2 ' + CHAR(13)
                  + @c_WhereCondition + CHAR(13)
                  + N' ORDER BY PD.Sku, SQ.Rowref ' + CHAR(13)

   IF @b_debug = 1
   BEGIN
      PRINT @c_SQLJOIN
   END

   SET @c_SQL = ' INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09' + CHAR(13)
              + '                     ,Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22' + CHAR(13)
              + '                     ,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34' + CHAR(13)
              + '                     ,Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44' + CHAR(13)
              + '                     ,Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54' + CHAR(13)
              + '                     ,Col55,Col56,Col57,Col58,Col59,Col60) '

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

   DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT R.ID, R.Col60 AS RecordID
   FROM #Result R
   GROUP BY R.ID, R.Col60

   OPEN CUR_LOOP

   FETCH NEXT FROM CUR_LOOP INTO @n_ID, @n_RecID

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SELECT @c_Data = [Data]
      FROM DOCINFO (NOLOCK)
      WHERE RecordID = @n_RecID

      SET @n_Loop = 2   --Col02

      DECLARE CUR_NLOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT ColValue
      FROM dbo.fnc_DelimSplit('|', @c_Data) FDS
      ORDER BY SeqNo   --(ML01)

      OPEN CUR_NLOOP

      FETCH NEXT FROM CUR_NLOOP
      INTO @c_ColValue

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF @n_Loop > 26   --Col26
            GOTO NEXT

         SET @c_SQL = N' UPDATE #RESULT SET Col' + RIGHT('00' + CAST(@n_Loop AS NVARCHAR(2)),2)
                    +  ' =  @c_ColValue '
                    +  ' WHERE ID = @n_ID '

         SET @c_ExecArguments = N' @n_ID INT, @c_ColValue NVARCHAR(MAX) '

         EXEC sp_executesql @c_SQL
                          , @c_ExecArguments
                          , @n_ID
                          , @c_ColValue

         NEXT:
         SET @n_Loop = @n_Loop + 1
         FETCH NEXT FROM CUR_NLOOP
         INTO @c_ColValue
      END
      CLOSE CUR_NLOOP
      DEALLOCATE CUR_NLOOP

      FETCH NEXT FROM CUR_LOOP INTO @n_ID, @n_RecID
   END
   CLOSE CUR_LOOP
   DEALLOCATE CUR_LOOP

   UPDATE #Result
   SET Col60 = ''

   IF ISNUMERIC(@c_Sparm4) = 1
   BEGIN
      SET @n_NoOfCopy = CAST(@c_Sparm4 AS INT)

      WHILE @n_NoOfCopy > 0
      BEGIN
         INSERT INTO #Result1 (Col01, Col02, Col03, Col04, Col05, Col06, Col07, Col08, Col09, Col10, Col11, Col12, Col13, Col14
                             , Col15, Col16, Col17, Col18, Col19, Col20, Col21, Col22, Col23, Col24, Col25, Col26, Col27, Col28
                             , Col29, Col30, Col31, Col32, Col33, Col34, Col35, Col36, Col37, Col38, Col39, Col40, Col41, Col42
                             , Col43, Col44, Col45, Col46, Col47, Col48, Col49, Col50, Col51, Col52, Col53, Col54, Col55, Col56
                             , Col57, Col58, Col59, Col60)
         SELECT DISTINCT
                Col01, Col02, Col03, Col04, Col05, Col06, Col07, Col08, Col09, Col10, Col11, Col12, Col13, Col14
              , Col15, Col16, Col17, Col18, Col19, Col20, Col21, Col22, Col23, Col24, Col25, Col26, Col27, Col28
              , Col29, Col30, Col31, Col32, Col33, Col34, Col35, Col36, Col37, Col38, Col39, Col40, Col41, Col42
              , Col43, Col44, Col45, Col46, Col47, Col48, Col49, Col50, Col51, Col52, Col53, Col54, Col55, Col56
              , Col57, Col58, Col59, Col60
         FROM #Result R

         SET @n_NoOfCopy = @n_NoOfCopy - 1
      END
   END
   ELSE
   BEGIN
      INSERT INTO #Result1 (Col01, Col02, Col03, Col04, Col05, Col06, Col07, Col08, Col09, Col10, Col11, Col12, Col13, Col14
                          , Col15, Col16, Col17, Col18, Col19, Col20, Col21, Col22, Col23, Col24, Col25, Col26, Col27, Col28
                          , Col29, Col30, Col31, Col32, Col33, Col34, Col35, Col36, Col37, Col38, Col39, Col40, Col41, Col42
                          , Col43, Col44, Col45, Col46, Col47, Col48, Col49, Col50, Col51, Col52, Col53, Col54, Col55, Col56
                          , Col57, Col58, Col59, Col60)
      SELECT Col01, Col02, Col03, Col04, Col05, Col06, Col07, Col08, Col09, Col10, Col11, Col12, Col13, Col14
           , Col15, Col16, Col17, Col18, Col19, Col20, Col21, Col22, Col23, Col24, Col25, Col26, Col27, Col28
           , Col29, Col30, Col31, Col32, Col33, Col34, Col35, Col36, Col37, Col38, Col39, Col40, Col41, Col42
           , Col43, Col44, Col45, Col46, Col47, Col48, Col49, Col50, Col51, Col52, Col53, Col54, Col55, Col56
           , Col57, Col58, Col59, Col60
      FROM #Result R
      ORDER BY [ID]
   END

   EXIT_SP:

   SET @d_Trace_EndTime = GETDATE()
   SET @c_UserName = SUSER_SNAME()

   SELECT *
   FROM #Result1 WITH (NOLOCK)

   IF CURSOR_STATUS('LOCAL', 'CUR_LOOP') IN (0 , 1)
   BEGIN
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP
   END

   IF CURSOR_STATUS('LOCAL', 'CUR_NLOOP') IN (0 , 1)
   BEGIN
      CLOSE CUR_NLOOP
      DEALLOCATE CUR_NLOOP
   END

   IF OBJECT_ID('tempdb..#Result') IS NOT NULL
      DROP TABLE #Result
END -- procedure

GO