SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Copyright: LFL                                                             */
/* Purpose: isp_BT_Bartender_CN_TRCABLBL_01                                   */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2022-MAR-16 1.0  CSCHONG   Devops Scripts Combine & Created (WMS-19084)    */
/* 2023-Sep-08 1.1  WLChooi   WMS-23579 - Modify Col05 (WL01)                 */
/******************************************************************************/

CREATE   PROC [dbo].[isp_BT_Bartender_CN_TRCABLBL_01]
(
   @c_Sparm01 NVARCHAR(250)
 , @c_Sparm02 NVARCHAR(250)
 , @c_Sparm03 NVARCHAR(250)
 , @c_Sparm04 NVARCHAR(250)
 , @c_Sparm05 NVARCHAR(250)
 , @c_Sparm06 NVARCHAR(250)
 , @c_Sparm07 NVARCHAR(250)
 , @c_Sparm08 NVARCHAR(250)
 , @c_Sparm09 NVARCHAR(250)
 , @c_Sparm10 NVARCHAR(250)
 , @b_debug   INT = 0
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_SQL        NVARCHAR(4000)
         , @c_SQLSORT    NVARCHAR(4000)
         , @c_SQLJOIN    NVARCHAR(4000)
         , @c_condition1 NVARCHAR(150)
         , @c_condition2 NVARCHAR(150)
         , @c_SQLGroup   NVARCHAR(4000)
         , @c_SQLOrdBy   NVARCHAR(150)
         , @c_SQLinsert  NVARCHAR(4000)
         , @c_SQLSelect  NVARCHAR(4000)


   DECLARE @d_Trace_StartTime  DATETIME
         , @d_Trace_EndTime    DATETIME
         , @c_Trace_ModuleName NVARCHAR(20)
         , @d_Trace_Step1      DATETIME
         , @c_Trace_Step1      NVARCHAR(20)
         , @c_UserName         NVARCHAR(20)
         , @c_ExecStatements   NVARCHAR(4000)
         , @c_ExecArguments    NVARCHAR(4000)
         , @c_storerkey        NVARCHAR(20)
         , @n_Copy             INT
         , @n_rowno            INT

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

   SET @d_Trace_StartTime = GETDATE()
   SET @c_Trace_ModuleName = N''

   SET @c_SQL = N''
   SET @c_SQLJOIN = N''
   SET @c_condition1 = N''
   SET @c_condition2 = N''
   SET @c_SQLOrdBy = N''
   SET @c_SQLGroup = N''
   SET @c_ExecStatements = N''
   SET @c_ExecArguments = N''
   SET @c_SQLinsert = N''
   SET @c_SQLSelect = N''

   INSERT INTO #Result (Col01, Col02, Col03, Col04, Col05, Col06, Col07, Col08, Col09, Col10, Col11, Col12, Col13
                      , Col14, Col15, Col16, Col17, Col18, Col19, Col20, Col21, Col22, Col23, Col24, Col25, Col26
                      , Col27, Col28, Col29, Col30, Col31, Col32, Col33, Col34, Col35, Col36, Col37, Col38, Col39
                      , Col40, Col41, Col42, Col43, Col44, Col45, Col46, Col47, Col48, Col49, Col50, Col51, Col52
                      , Col53, Col54, Col55, Col56, Col57, Col58, Col59, Col60)
   SELECT PD.Sku
        , SUBSTRING(S.DESCR, 1, 80)
        , LOTT.Lottable09
        , (ISNULL(LOTT.Lottable07, '') + ISNULL(ST.Company, '')) AS col04 --4
        , (ISNULL(LOTT.Lottable11, '') + ISNULL(C1.Short, '') + ISNULL(C2.Code, '') + ISNULL(C2.Short, '') +   --WL01
           ISNULL(C3.Code, '') + ISNULL(C3.Long, '') ) AS col05   --WL01
        , ISNULL(CONVERT(NVARCHAR(10), LOTT.Lottable13, 111), '') AS Col06
        , CASE WHEN ISNULL(DATEDIFF(DAY, LOTT.Lottable13, LOTT.Lottable04), '') <> 0 THEN
                  CAST(ISNULL(DATEDIFF(DAY, LOTT.Lottable13, LOTT.Lottable04), '') AS NVARCHAR(10))
               ELSE '' END AS col07
        , LOTT.Lottable10 AS col08
        , SUBSTRING(
             PD.Notes
           , CHARINDEX('|', PD.Notes) + 1
           , (((LEN(PD.Notes)) - CHARINDEX('|', REVERSE(PD.Notes))) - CHARINDEX('|', PD.Notes))) AS col09
        , ISNULL(SUBSTRING(PD.Notes, 1, CHARINDEX('|', PD.Notes) - 1), '') AS col10
        , LOTT.Lottable03 AS Col11
        , OH.ExternOrderKey AS col12
        , ISNULL(CONVERT(NVARCHAR(10), GETDATE(), 111), '') AS Col13
        , PD.ID AS col14
        , OH.ConsigneeKey AS col15
        , ''
        , ''
        , ''
        , ''
        , ''
        , ''
        , ''
        , ''
        , ''
        , ''
        , ''
        , ''
        , ''
        , ''
        , ''
        , ''
        , ''
        , ''
        , ''
        , ''
        , ''
        , ''
        , ''
        , ''
        , ''
        , ''
        , ''
        , ''
        , ''
        , ''
        , ''
        , ''
        , ''
        , ''
        , ''
        , ''
        , ''
        , ''
        , ''
        , ''
        , ''
        , ''
        , ''
        , ''
        , ''
   FROM dbo.PICKDETAIL PD WITH (NOLOCK)
   JOIN ORDERS OH WITH (NOLOCK) ON OH.OrderKey = PD.OrderKey
   JOIN SKU S WITH (NOLOCK) ON S.StorerKey = PD.Storerkey AND S.Sku = PD.Sku
   LEFT JOIN dbo.LOTATTRIBUTE LOTT WITH (NOLOCK) ON  LOTT.Lot = PD.Lot
                                                 AND LOTT.StorerKey = PD.Storerkey
                                                 AND LOTT.Sku = PD.Sku
   LEFT JOIN dbo.STORER ST WITH (NOLOCK) ON  ST.StorerKey = LOTT.Lottable07
                                         AND ST.type = '2'
                                         AND ST.ConsigneeFor = PD.Storerkey
   LEFT JOIN dbo.CODELKUP C1 WITH (NOLOCK) ON  C1.LISTNAME = 'costcocoo'
                                           AND C1.Storerkey = OH.StorerKey
                                           AND C1.Code = LOTT.Lottable11
   LEFT JOIN dbo.CODELKUP C2 WITH (NOLOCK) ON  C2.LISTNAME = 'costcopro'
                                           AND C2.Storerkey = OH.StorerKey
                                           AND C2.Code = IIF(CHARINDEX('/',LOTT.Lottable12) = 0,   --WL01 S
                                                             LOTT.Lottable12,
                                                             SUBSTRING(LOTT.Lottable12,1,
                                                                   CHARINDEX('/',LOTT.Lottable12) - 1))
                                                             
   LEFT JOIN dbo.CODELKUP C3 WITH (NOLOCK) ON  C3.LISTNAME = 'costcocity'
                                           AND C3.Storerkey = OH.StorerKey
                                           AND C3.Code = IIF(CHARINDEX('/',LOTT.Lottable12) = 0,
                                                             LOTT.Lottable12,
                                                             SUBSTRING(LOTT.Lottable12,
                                                                       CHARINDEX('/',LOTT.Lottable12) + 1, 
                                                                       LEN(LOTT.Lottable12) - CHARINDEX('/',LOTT.Lottable12)) )   --WL01 E
   WHERE PD.ID = @c_Sparm01 AND PD.OrderKey = @c_Sparm02

   EXIT_SP:

   SET @d_Trace_EndTime = GETDATE()
   SET @c_UserName = SUSER_SNAME()

   SELECT *
   FROM #Result

END -- procedure


GO