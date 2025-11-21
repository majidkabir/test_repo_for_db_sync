SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Copyright: IDS                                                             */
/* Purpose: BarTender IT69 Label                                              */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2014-02-10 1.0  CSCHONG    Created(SOS301440)                              */
/* 2014-05-07 2.0  CSCHONG    Change mapping for Column03 (CS02)              */
/* 2014-12-02 3.0  CSCHONG    Remove SET ANSI_WARNINGS (CS03)                 */
/* 2016-02-24 3.1  CSCHONG    Add in parameter value for log (CS04)           */
/* 2017-08-28 3.2  CSCHONG    Remove case when in where condition (CS05)      */
/* 2018-07-25 3.3  CSCHONG    WMS-5634 - handle new print method (CS06)       */
/* 2023-06-08 1.2  CSCHONG    change print line from main to sub (CS07)       */
/******************************************************************************/

CREATE   PROC [dbo].[isp_BT_Bartender_IT69_Label]
(  @c_Sparm1            NVARCHAR(250),
   @c_Sparm2            NVARCHAR(250),
   @c_Sparm3            NVARCHAR(250),
   @c_Sparm4            NVARCHAR(250),
   @c_Sparm5            NVARCHAR(250),
   @c_Sparm6            NVARCHAR(250),
   @c_Sparm7            NVARCHAR(250),
   @c_Sparm8            NVARCHAR(250),
   @c_Sparm9            NVARCHAR(250),
   @c_Sparm10           NVARCHAR(250),
   @b_debug             INT = 0
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   --SET ANSI_WARNINGS OFF               --(CS03)

   DECLARE
      @c_receiptkey      NVARCHAR(10),
      @c_lottable02      NVARCHAR(80),
      @c_lottable01      NVARCHAR(80),
      @C_sku             NVARCHAR(80),
      @C_Size            NVARCHAR(80),
      @C_BUSR6           NVARCHAR(80),
      @c_Rreceiptkey     NVARCHAR(10),
      @c_Rlottable02     NVARCHAR(80),
      @c_Rlottable01     NVARCHAR(80),
      @C_Rsku            NVARCHAR(80),
      @C_RSize           NVARCHAR(80),
      @C_RBUSR6          NVARCHAR(80),
      @c_GetCol01        NVARCHAR(80),
      @c_GetCol02        NVARCHAR(80),
      @c_GetCol03        NVARCHAR(80),
      @c_GetCol04        NVARCHAR(80),
      @c_GetCol05        NVARCHAR(80),
      @c_GetCol06        NVARCHAR(80),
      @c_GetCol07        NVARCHAR(80),
      @c_GetCol08        NVARCHAR(80),
      @n_intFlag         INT,
      @n_CntRec          INT,
      @c_RecLineNo       NVARCHAR(10)

  DECLARE @d_Trace_StartTime   DATETIME,
           @d_Trace_EndTime    DATETIME,
           @c_Trace_ModuleName NVARCHAR(20),
           @d_Trace_Step1      DATETIME,
           @c_Trace_Step1      NVARCHAR(20),
           @c_UserName         NVARCHAR(20)


   SET @d_Trace_StartTime = GETDATE()
   SET @c_Trace_ModuleName = ''
   SET @n_intFlag = 1

   IF ISNULL(@c_SParm4,'') <> ''
   BEGIN
     SET @n_CntRec = CONVERT(INT,@c_SParm4)
   END

    -- SET RowNo = 0


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

 --CS06 start
 IF @c_Sparm10 <> 'IT69'
 BEGIN
       --select @c_Sparm5 '@c_Sparm5'
       IF @c_Sparm5 = '1'
       BEGIN

       DECLARE CUR_StartRecLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
       SELECT DISTINCT (substring(RECD.lottable02,5,2)+space(1)+substring(RECD.lottable02,14,2)),
                (substring(s.sku,1,7)+ space(1)+substring(s.sku,8,3) + space(1) + substring(s.sku,11,3)),
                 ('EUR' + space(1) + s.BUSR7),s.BUSR6,'',substring(RECD.lottable02,1,12),
                substring(lottable01,5,2)+s.SKU+substring(lottable02,1,12)+substring(lottable02,14,2),
                RECD.ReceiptLineNumber                                                                       --CS07
          FROM RECEIPTDETAIL RECD WITH (NOLOCK)
          INNER JOIN SKU s WITH (NOLOCK) ON s.sku=RECD.sku AND s.storerkey = RECD.StorerKey            --CS07            
          WHERE RECD.receiptKey = @c_Sparm1
         --AND RECD.REceiptlinenumber=CASE WHEN ISNULL(RTRIM(@c_Sparm2 ),'') <> '' THEN  @c_Sparm2 ELSE RECD.REceiptlinenumber END   --CS04
          AND RECD.REceiptlinenumber = CASE WHEN ISNULL(RTRIM(@c_Sparm2),'') <> '' THEN @c_Sparm2 ELSE RECD.REceiptlinenumber END    --CS07
       OPEN CUR_StartRecLoop

      FETCH NEXT FROM CUR_StartRecLoop INTO @c_GetCol01,@c_GetCol02,@c_GetCol03,@c_GetCol04,@c_GetCol05,@c_GetCol06,@c_GetCol07,@c_RecLineNo    --CS07

       WHILE @@FETCH_STATUS <> -1
        BEGIN

           IF @b_debug=1
           BEGIN
             PRINT 'Cur start'
           END

         INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09
                                  ,Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22
                                  ,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34
                                  ,Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44
                                  ,Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54
                                  ,Col55,Col56,Col57,Col58,Col59,Col60)
           VALUES(@c_GetCol01,@c_GetCol02,@c_GetCol03,@c_GetCol04,@c_GetCol05,@c_GetCol06,@c_GetCol07,@c_Sparm1,@c_Sparm2,@c_Sparm3,    --(CS04)
                  @c_Sparm4,@c_Sparm5,'','','','','','','','',                                                                          --(CS04)
                   '','','','','','','','','','','','','','','','','','','','','','','','','','','','','',''
                  ,'','','','','','','','','','')


         IF @b_debug=1
         BEGIN
          SELECT * FROM #Result (nolock)
         END

         FETCH NEXT FROM CUR_StartRecLoop INTO @c_GetCol01,@c_GetCol02,@c_GetCol03,@c_GetCol04,@c_GetCol05,@c_GetCol06,@c_GetCol07,@c_RecLineNo   --CS07

         END -- While
         CLOSE CUR_StartRecLoop
         DEALLOCATE CUR_StartRecLoop

         END
         ELSE
            BEGIN

            --select 'start'
              SELECT @c_GetCol01 = substring(@c_Sparm3,5,2) + space(1) + @c_Sparm2,
                     @c_GetCol02 = substring(s.sku,1,7) + space(1) + substring(s.sku,8,3) + space(1) + substring(s.sku,11,3),
                     @c_GetCol03 = 'EUR' + space(2) + s.size,   --CS02
                     @c_GetCol03 = 'EUR' + space(2) + s.busr7,   --CS02
                     @c_GetCol04 = s.BUSR6,
                     @c_GetCol05 = '',
                     @c_GetCol06 = @c_Sparm3,
                     @c_GetCol07 = substring(@c_Sparm3,5,2) + s.sku + @c_Sparm3 + @c_Sparm2
                     FROM SKU s WITH (NOLOCK)
                     WHERE S.SKU = @c_Sparm1
                     --AND S.SKU = @c_Sparm6


             INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09
                                     ,Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22
                                     ,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34
                                     ,Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44
                                     ,Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54
                                     ,Col55,Col56,Col57,Col58,Col59,Col60)
              VALUES(@c_GetCol01,@c_GetCol02,@c_GetCol03,@c_GetCol04,@c_GetCol05,@c_GetCol06,@c_GetCol07,@c_Sparm1,@c_Sparm2,@c_Sparm3,    --(CS04)
                     @c_Sparm4,@c_Sparm5,'','','','','','','','',                                                                          --(CS04)
                      '','','','','','','','','','','','','','','','','','','','','','','','','','','','','',''
                     ,'','','','','','','','','','')


            IF @b_debug=1
            BEGIN
             SELECT * FROM #Result (nolock)
            END

     END


     IF @b_debug=1
      BEGIN
       PRINT 'Cur start'
       PRINT 'NoOfCopy : ' + convert(varchar(5),@n_CntRec)
      END
 END
 ELSE
 BEGIN

            SELECT @c_GetCol01 = @c_Sparm3 + space(1) + @c_Sparm6,
            @c_GetCol02 = substring(s.sku,1,7) + space(1) + substring(s.sku,8,3) + space(1) + substring(s.sku,11,3),
         -- @c_GetCol03 = 'EUR' + space(2) + s.size,   --CS02
            @c_GetCol03 = 'EUR' + space(2) + s.busr7,   --CS02
            @c_GetCol04 = s.BUSR6,
            @c_GetCol05 = @c_Sparm5,
            @c_GetCol06 = @c_Sparm5,
            @c_GetCol07 = @c_Sparm3 + s.sku + @c_Sparm5 + @c_Sparm6
            FROM SKU s WITH (NOLOCK)
            WHERE S.storerkey = @c_Sparm1
            AND S.SKU = @c_Sparm2

      INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09
                              ,Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22
                              ,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34
                              ,Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44
                              ,Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54
                              ,Col55,Col56,Col57,Col58,Col59,Col60)
      VALUES(@c_GetCol01,@c_GetCol02,@c_GetCol03,@c_GetCol04,@c_GetCol05,@c_GetCol06,@c_GetCol07,'','','',
            '','','','','','','','','','',
               '','','','','','','','','','','','','','','','','','','','','','','','','','','','','',''
            ,'','','','','','','','','','')


         IF @b_debug=1
         BEGIN
            SELECT * FROM #Result (nolock)
         END


 END



   WHILE (@n_intFlag < @n_CntRec)
   BEGIN
   INSERT INTO #result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09
                            ,Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22
                            ,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34
                            ,Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44
                            ,Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54
                            ,Col55,Col56,Col57,Col58,Col59,Col60)
   SELECT TOP 1 Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09
                            ,Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22
                            ,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34
                            ,Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44
                            ,Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54
                            ,Col55,Col56,Col57,Col58,Col59,Col60
   FROM #result WITH (NOLOCK)

   SET @n_intFlag = @n_intFlag + 1

   END

   SELECT * FROM #Result (nolock)

   EXIT_SP:

   SET @d_Trace_EndTime = GETDATE()
   SET @c_UserName = SUSER_SNAME()

   --EXEC isp_InsertTraceInfo
   --   @c_TraceCode = 'BARTENDER',
   --   @c_TraceName = 'isp_BT_Bartender_IT69_Label',
   --   @c_starttime = @d_Trace_StartTime,
   --   @c_endtime = @d_Trace_EndTime,
   --   @c_step1 = @c_UserName,
   --   @c_step2 = '',
   --   @c_step3 = '',
   --   @c_step4 = '',
   --   @c_step5 = '',
   --   @c_col1 = @c_Sparm1,
   --   @c_col2 = @c_Sparm2,
   --   @c_col3 = @c_Sparm3,
   --   @c_col4 = @c_Sparm4,
   --   @c_col5 = @c_Sparm5,
   --   @b_Success = 1,
   --   @n_Err = 0,
   --   @c_ErrMsg = ''


END -- procedure





GO