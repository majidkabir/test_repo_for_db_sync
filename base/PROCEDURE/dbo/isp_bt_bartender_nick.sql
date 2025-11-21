SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Copyright: IDS                                                             */
/* Purpose: isp_BT_Bartender_Nick                                     */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2024-06-26 1.0  NLT013     Test                                 */
/******************************************************************************/

CREATE PROC [dbo].[isp_BT_Bartender_Nick]
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
      @c_sku             NVARCHAR(20),
      @n_intFlag         INT,
      @n_CntRec          INT,
      @c_SQL             NVARCHAR(4000),
      @c_SQLSORT         NVARCHAR(4000),
      @c_SQLJOIN         NVARCHAR(4000)

  DECLARE   @d_Trace_StartTime   DATETIME,
    @d_Trace_EndTime    DATETIME,
    @c_Trace_ModuleName NVARCHAR(20),
    @d_Trace_Step1      DATETIME,
    @c_Trace_Step1      NVARCHAR(20),
    @c_UserName         NVARCHAR(20),
    @c_col01            NVARCHAR(80) = '',
    @c_col02            NVARCHAR(80) = '',
    @c_col03            NVARCHAR(80) = '',
    @c_col04            NVARCHAR(80) = '',
    @c_col05            NVARCHAR(80) = '',
    @c_col06            NVARCHAR(80) = '',
    @c_col07            NVARCHAR(80) = '',
    @c_col08            NVARCHAR(80) = '',
    @c_col09            NVARCHAR(80) = '',
    @c_col10            NVARCHAR(80) = '',
    @c_col11            NVARCHAR(80) = '',
    @c_col12            NVARCHAR(80) = '',
    @c_col13            NVARCHAR(80) = '',
    @c_col14            NVARCHAR(80) = '',
    @c_Col15            NVARCHAR(80) = '', 
    @c_col16            NVARCHAR(80) = '',
    @c_col17            NVARCHAR(80) = '',
    @c_col18            NVARCHAR(80) = '',
    @c_col19            NVARCHAR(80) = '',
    @c_col20            NVARCHAR(80) = '',
    @c_col30            NVARCHAR(80) = '',
    @c_col31            NVARCHAR(80) = '',
    @c_col32            NVARCHAR(80) = '',
    @c_col33            NVARCHAR(80) = '',
    @c_col34            NVARCHAR(80) = '',
    @c_Col35            NVARCHAR(80) = '', 
    @c_col36            NVARCHAR(80) = '',
    @c_col37            NVARCHAR(80) = '',
    @c_col38            NVARCHAR(80) = '',
    @c_col39            NVARCHAR(80) = '',
    @c_col40            NVARCHAR(80) = '',
    @c_col41            NVARCHAR(80) = '',
    @c_col42            NVARCHAR(80) = '',
    @c_col43            NVARCHAR(80) = '',
    @c_col44            NVARCHAR(80) = '',
    @c_Col45            NVARCHAR(80) = '', 
    @c_col46            NVARCHAR(80) = '',
    @c_col47            NVARCHAR(80) = '',
    @c_col48            NVARCHAR(80) = '',
    @c_col49            NVARCHAR(80) = '',
    @c_col21            NVARCHAR(80) = '',
    @c_col22            NVARCHAR(80) = '',
    @c_col23            NVARCHAR(80) = '',
    @c_col24            NVARCHAR(80) = '',
    @c_Col25            NVARCHAR(80) = '', 
    @c_col26            NVARCHAR(80) = '',
    @c_col27            NVARCHAR(80) = '',
    @c_col28            NVARCHAR(80) = '',
    @c_col29            NVARCHAR(80) = '',
    @c_col50            NVARCHAR(80) = '',
    @c_col51            NVARCHAR(80) = '',
    @c_col52            NVARCHAR(80) = '',
    @c_col53            NVARCHAR(80) = '',
    @c_col54            NVARCHAR(80) = '',
    @c_Col55            NVARCHAR(80) = '', 
    @c_col56            NVARCHAR(80) = '',
    @c_col57            NVARCHAR(80) = '',
    @c_col58            NVARCHAR(80) = '',
    @c_col59            NVARCHAR(80) = '',
    @c_col60            NVARCHAR(80) = '',
    @n_cartonno         INT, 
    @c_labelno          NVARCHAR(20), 
    @n_TTLpage          INT,
    @n_CurrentPage      INT,
    @n_MaxLine          INT  ,
    @c_storerkey        NVARCHAR(20) ,
    @c_ExecStatements   NVARCHAR(4000),
    @c_ExecArguments    NVARCHAR(4000)

DECLARE @c_printdata            NVARCHAR(MAX),
        @c_DelimiterSign1       NVARCHAR(5),
        @c_DelimiterSign2       NVARCHAR(5),
        @n_SeqNo                INT,
        @c_ColValue             NVARCHAR(150),   
        @n_SeqNo2               INT,
        @c_ColValue2            NVARCHAR(150), 
        @c_cartoninfo           NVARCHAR(100),
        @c_cartonId             NVARCHAR(50),
        @c_pcs                  NVARCHAR(10) 

   SET @d_Trace_StartTime = GETDATE()
   SET @c_Trace_ModuleName = ''

    -- SET RowNo = 0
    SET @c_SQL = ''
    SET @n_CurrentPage = 1
    SET @n_TTLpage =1
    SET @n_MaxLine = 5
    SET @n_CntRec = 1
    SET @n_intFlag = 1
    SET @c_DelimiterSign1 = ';'


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


      INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09
                                 ,Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22
                                 ,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34
                                 ,Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44
                                 ,Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54
                                 ,Col55,Col56,Col57,Col58,Col59,Col60)
                   VALUES(@c_Sparm01, '', '','','', '', '', '', '', '',
                          '', '', '', '', '', '', '', '', '', '',
                          '', '', '', '', '', '', '', '', '', '', 
                          '', '', '', '', '', '', '', '', '', '',
                          '', '', '', '', '', '', '', '', '', '',
                          '', '', '', '', '', '', '', '', '', '') 


   IF @b_debug=1
   BEGIN
      SELECT * FROM #Result (nolock)
   END

SELECT * FROM #Result (nolock)

EXIT_SP:

   SET @d_Trace_EndTime = GETDATE()
   SET @c_UserName = SUSER_SNAME()




END -- procedure

GO