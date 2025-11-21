SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Copyright: IDS                                                             */
/* Purpose: isp_Bartender_PALLETLBL_SG_IDSMED                                 */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2019-10-29 1.0  CSCHONG    Created (WMS-10955)                             */
/* 2020-02-20 1.1  WLChooi    WMS-12122 - Filter by SKU (WL01)                */
/* 2021-04-19 1.2  CSCHONG    WMS-16825 - Add new field (CS02)                */
/* 2023-04-11 1.3  WLChooi    WMS-22225 - Add Col34 (WL02)                    */
/* 2023-04-11 1.3  WLChooi    DevOps Combine Script                           */
/******************************************************************************/

CREATE   PROC [dbo].[isp_Bartender_PALLETLBL_SG_IDSMED]
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

   DECLARE @c_ReceiptKey     NVARCHAR(10)
         , @c_ExternOrderKey NVARCHAR(10)
         , @c_Deliverydate   DATETIME
         , @n_intFlag        INT
         , @n_CntRec         INT
         , @c_SQL            NVARCHAR(4000)
         , @c_SQLSORT        NVARCHAR(4000)
         , @c_SQLJOIN        NVARCHAR(4000)

   DECLARE @d_Trace_StartTime  DATETIME
         , @d_Trace_EndTime    DATETIME
         , @c_Trace_ModuleName NVARCHAR(20)
         , @d_Trace_Step1      DATETIME
         , @c_Trace_Step1      NVARCHAR(20)
         , @c_UserName         NVARCHAR(20)
         , @n_cntsku           INT
         , @c_mode             NVARCHAR(1)
         , @c_sku              NVARCHAR(20)
         , @c_condition        NVARCHAR(150)
         , @c_GroupBy          NVARCHAR(4000)
         , @c_OrderBy          NVARCHAR(4000)
         , @c_ExecStatements   NVARCHAR(4000)
         , @c_ExecArguments    NVARCHAR(4000)
         , @c_RDTOID           NVARCHAR(20)
         , @c_Putawayzone      NVARCHAR(30)
         , @c_LocAisle         NVARCHAR(30)
         , @c_reclinenumber    NVARCHAR(20)

   SET @d_Trace_StartTime = GETDATE()
   SET @c_Trace_ModuleName = N''

   -- SET RowNo = 0             
   SET @c_SQL = N''
   SET @c_mode = N'0'

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

   CREATE TABLE [#UCCTResult]
   (
      Uccno NVARCHAR(20) NULL
    , SKU   NVARCHAR(20) NULL
   )

   SET @c_condition = N''
   SET @c_GroupBy = N''
   SET @c_OrderBy = N''
   SET @c_reclinenumber = N''

   SELECT TOP 1 @c_reclinenumber = RD.ReceiptLineNumber
   FROM RECEIPTDETAIL RD WITH (NOLOCK)
   WHERE RD.ReceiptKey = @c_Sparm01
   AND   RD.ToId = @c_Sparm02
   AND   RD.Sku = CASE WHEN ISNULL(@c_Sparm03, '') = '' THEN RD.Sku
                       ELSE @c_Sparm03 END --WL01
   AND   RD.FinalizeFlag = 'Y'
   ORDER BY RD.EditDate DESC

   SET @c_GroupBy = N' GROUP BY RECDET.SKU,substring(S.descr,1,80),RECDET.Lottable02,CONVERT(NVARCHAR(80),RECDET.Lottable04,103),'
                    + N' CONVERT(NVARCHAR(80),RECDET.Lottable05,103),RECDET.toid,RECDET.UOM,'
                    + N' RECDET.Lottable01 ,RECDET.Lottable03,RECDET.Receiptkey, '
                    + N' RECDET.Lottable06,RECDET.Lottable07,RECDET.Lottable08,RECDET.Lottable09,RECDET.Lottable10,RECDET.Lottable11,RECDET.Lottable12,'
                    --CS02 START
                    + N' RECDET.Lottable13,RECDET.Lottable14,RECDET.Lottable15,S.Altsku,S.ManufacturerSKU,S.RETAILSKU,RECDET.UserDefine01,RECDET.UserDefine02, '
                    + N' RECDET.UserDefine03,RECDET.UserDefine04,RECDET.UserDefine05,RECDET.UserDefine06,RECDET.UserDefine07,'
                    + N' RECDET.UserDefine08,RECDET.UserDefine09,RECDET.UserDefine10,REC.CarrierAddress1 '   --WL02
   --CS02 END

   SET @c_OrderBy = N' ORDER BY RECDET.editdate desc'

   SET @c_SQLJOIN = +N' SELECT TOP 12 RECDET.SKU,substring(S.descr,1,80),RECDET.Lottable02,CONVERT(NVARCHAR(80),RECDET.Lottable04,103),'
                    + CHAR(13) + N' CONVERT(NVARCHAR(80),RECDET.Lottable05,103),' --5   
                    + N' SUM(RECDET.QtyReceived),RECDET.toid,RECDET.UOM,'
                    + N' RECDET.Lottable01 ,RECDET.Lottable03, ' --10   
                    + N' RECDET.Lottable06,RECDET.Lottable07,RECDET.Lottable08,RECDET.Lottable09,RECDET.Lottable10,' --15       
                    + CHAR(13)
                    + +N' RECDET.Lottable11,RECDET.Lottable12,RECDET.Lottable13,RECDET.Lottable14,RECDET.Lottable15,' --20     --CS02 START 
                    + N' S.Altsku,S.ManufacturerSKU,S.RETAILSKU,RECDET.UserDefine01,RECDET.UserDefine02,'
                    + N' RECDET.UserDefine03,RECDET.UserDefine04,RECDET.UserDefine05,RECDET.UserDefine06,RECDET.UserDefine07,' --30
                    + N' RECDET.UserDefine08,RECDET.UserDefine09,RECDET.UserDefine10,REC.CarrierAddress1,'''',' --CS02 END   --WL02
                    + N' '''','''','''','''','''',' --40      
                    + N' '''','''','''','''','''','''','''','''','''','''', ' --50       
                    + N' '''','''','''','''','''','''','''','''','''',RECDET.Receiptkey ' --60          
                    + CHAR(13) + +N' FROM RECEIPT REC WITH (NOLOCK)'
                    + N' JOIN RECEIPTDETAIL RECDET WITH (NOLOCK) ON REC.Receiptkey=RECDET.Receiptkey'
                    + N' JOIN SKU s WITH (NOLOCK) ON s.storerkey = RECDET.storerkey AND s.sku=RECDET.sku'
                    + N' JOIN LOC L WITH (NOLOCK) ON L.loc = RECDET.Toloc '
                    + N' WHERE RECDET.receiptkey =  @c_Sparm01  AND RECDET.toid = @c_Sparm02 '
                    + CHAR(13)
                    --     + ' AND RECDET.SKU = CASE WHEN ISNULL(@c_Sparm03,'''') = '''' THEN RECDET.SKU ELSE @c_Sparm03 END ' + CHAR(13)   --WL01
                    + N' AND RECDET.receiptlinenumber = @c_reclinenumber '


   IF @b_debug = 1
   BEGIN
      SELECT @c_SQLJOIN + @c_GroupBy
      PRINT @c_SQLJOIN + @c_GroupBy
   END

   SET @c_SQL = N'INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09' + CHAR(13)
                + +N',Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22' + CHAR(13)
                + +N',Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34' + CHAR(13)
                + +N',Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44' + CHAR(13)
                + +N',Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54' + CHAR(13)
                + +N',Col55,Col56,Col57,Col58,Col59,Col60) '

   SET @c_SQL = @c_SQL + @c_SQLJOIN + @c_condition + @c_GroupBy

   SET @c_ExecArguments = N'    @c_Sparm01        NVARCHAR(80)' 
                        + N',   @c_Sparm02        NVARCHAR(80)'
                        + N',   @c_reclinenumber  NVARCHAR(10)' 
                        + N',   @c_Sparm03        NVARCHAR(80)'   --WL01 

   EXEC sp_executesql @c_SQL
                    , @c_ExecArguments
                    , @c_Sparm01
                    , @c_Sparm02
                    , @c_reclinenumber
                    , @c_Sparm03 --WL01   

   -- EXEC sp_executesql @c_SQL          

   IF @b_debug = 1
   BEGIN
      PRINT @c_SQL
   END


   IF @b_debug = 1
   BEGIN
      SELECT *
      FROM #Result (NOLOCK)
   END


   SELECT *
   FROM #Result (NOLOCK)

   EXIT_SP:

   SET @d_Trace_EndTime = GETDATE()
   SET @c_UserName = SUSER_SNAME()

   EXEC isp_InsertTraceInfo @c_TraceCode = 'BARTENDER'
                          , @c_TraceName = 'isp_Bartender_PALLETLBL_SG_IDSMED'
                          , @c_starttime = @d_Trace_StartTime
                          , @c_endtime = @d_Trace_EndTime
                          , @c_step1 = @c_UserName
                          , @c_step2 = ''
                          , @c_step3 = ''
                          , @c_step4 = ''
                          , @c_step5 = ''
                          , @c_col1 = @c_Sparm01
                          , @c_col2 = @c_Sparm02
                          , @c_col3 = @c_Sparm03
                          , @c_col4 = @c_Sparm04
                          , @c_col5 = @c_Sparm05
                          , @b_Success = 1
                          , @n_Err = 0
                          , @c_ErrMsg = ''

END -- procedure  

GO