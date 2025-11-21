SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/********************************************************************************/
/* Copyright: MAERSK                                                            */
/* Purpose: isp_Bartender_FullPalletWgt                                         */
/* Customer: Barry                                                              */
/* Modifications log:                                                           */
/*                                                                              */
/* Date       Rev    Author     Purposes                                        */
/* 2024-07-12 1.0    PYU015     UWP-26438 Created                               */
/* 2024-11-20 1.1.0  XGU017     UWP-27316 Updated                               */
/********************************************************************************/

CREATE     PROC [dbo].[isp_Bartender_FullPalletWgt]
(  @c_Sparm01  NVARCHAR(250) = '',
   @c_Sparm02  NVARCHAR(250) = '',
   @c_Sparm03  NVARCHAR(250) = '',
   @c_Sparm04  NVARCHAR(250) = '',
   @c_Sparm05  NVARCHAR(250) = '',
   @c_Sparm06  NVARCHAR(250) = '',
   @c_Sparm07  NVARCHAR(250) = '',
   @c_Sparm08  NVARCHAR(250) = '',
   @c_Sparm09  NVARCHAR(250) = '',
   @c_Sparm10  NVARCHAR(250) = '',
   @b_debug    INT = 0
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_SQL            NVARCHAR(MAX)  = ''
         , @c_ExecStatements NVARCHAR(4000) = ''
         , @c_ExecArguments  NVARCHAR(4000) = ''

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

   SET @c_SQL = N'INSERT INTO #Result' + CHAR(13)
               + '(Col01,Col02,Col03,Col04,Col05,Col06,Col07,Col08,Col09,Col10' + CHAR(13)
               + ',Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20' + CHAR(13)
               + ',Col21,Col22,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30' + CHAR(13)
               + ',Col31,Col32,Col33,Col34,Col35,Col36,Col37,Col38,Col39,Col40' + CHAR(13)
               + ',Col41,Col42,Col43,Col44,Col45,Col46,Col47,Col48,Col49,Col50' + CHAR(13)
               + ',Col51,Col52,Col53,Col54,Col55,Col56,Col57,Col58,Col59,Col60)'+ CHAR(13)

   SET @c_ExecStatements = N'SELECT rptdet.ToId '
                          + '     , rptdet.Lottable01 '
                          + '     , rptdet.Sku '
                          + '     , GETDATE() '
                          + '     , rptdet.ToLoc '
                          + '     , rptdet.BeforeReceivedQty '
                          + '     , cast(rptdet.Lottable07 as float) '
                          + '     , cast(rptdet.lottable06 as float) '
                          + '     , cast(rptdet.lottable06 as float)-cast(rptdet.lottable07 as float)-cast(rptdet.lottable10 as float)*rptdet.BeforeReceivedQty '
                          + '     ,''''                                               ' + CHAR(13) --10
                          + '     , '''','''','''','''','''','''','''','''','''','''' ' + CHAR(13) --20
                          + '     , '''','''','''','''','''','''','''','''','''','''' ' + CHAR(13) --30
                          + '     , '''','''','''','''','''','''','''','''','''','''' ' + CHAR(13) --40
                          + '     , '''','''','''','''','''','''','''','''','''','''' ' + CHAR(13) --50
                          + '     , '''','''','''','''','''','''','''','''','''','''' ' + CHAR(13) --60
                          + '  FROM RECEIPTDETAIL rptdet WITH (NOLOCK) '
                          + '  INNER JOIN RECEIPT rpt WITH (NOLOCK) ON rptdet.ReceiptKey = rpt.ReceiptKey '
                          + '  INNER JOIN SKU s WITH(NOLOCK) ON rptdet.Sku = s.Sku and rptdet.StorerKey = s.StorerKey '
                          + '  WHERE rptdet.ReceiptKey  = @c_Sparm01 '
                          + '    AND rptdet.ToId = @c_Sparm02 '

   SET @c_SQL = @c_SQL + @c_ExecStatements

   SET @c_ExecArguments = N'@c_Sparm01   NVARCHAR(250),'
                          +'@c_Sparm02   NVARCHAR(250)'

   EXEC sp_ExecuteSql @c_SQL
                    , @c_ExecArguments
                    , @c_Sparm01
                    , @c_Sparm02

   IF @b_debug = 1
   BEGIN
      PRINT '@c_SQL: ' + @c_SQL
   END

   SELECT * FROM #RESULT WITH (NOLOCK)

EXIT_SP:

END -- procedure

GO