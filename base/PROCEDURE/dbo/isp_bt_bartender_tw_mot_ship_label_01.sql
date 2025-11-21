SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO



/******************************************************************************/
/* Copyright: IDS                                                             */
/* Purpose: isp_BT_Bartender_TW_MOT_ship_Label_01                             */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 222-11-10 1.0  CSCHONG     Devops Scripts Conbine &Created (WMS-21087)     */
/******************************************************************************/

CREATE   PROC [dbo].[isp_BT_Bartender_TW_MOT_ship_Label_01]
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
      @c_SQLJOIN         NVARCHAR(4000),
      @c_col58           NVARCHAR(10)

  DECLARE @d_Trace_StartTime   DATETIME,
           @d_Trace_EndTime    DATETIME,
           @c_Trace_ModuleName NVARCHAR(20),
           @d_Trace_Step1      DATETIME,
           @c_Trace_Step1      NVARCHAR(20),
           @c_UserName         NVARCHAR(20),
           @c_SKU01            NVARCHAR(20),
           @c_SKU02            NVARCHAR(20),
           @c_SKU03            NVARCHAR(20),
           @c_SKU04            NVARCHAR(20),
           @c_SKU05            NVARCHAR(20),
           @c_SKU06            NVARCHAR(20),
           @c_SKU07            NVARCHAR(20),
           @c_SKU08            NVARCHAR(20),
           @c_SKUQty01         NVARCHAR(10),
           @c_SKUQty02         NVARCHAR(10),
           @c_SKUQty03         NVARCHAR(10),
           @c_SKUQty04         NVARCHAR(10),
           @c_SKUQty05         NVARCHAR(10),
           @c_SKUQty06         NVARCHAR(10),
           @c_SKUQty07         NVARCHAR(10),
           @c_SKUQty08         NVARCHAR(10),
           @n_TTLpage          INT,
           @n_CurrentPage      INT,
           @n_MaxLine          INT  ,
           @c_labelno          NVARCHAR(20) ,
           @c_orderkey         NVARCHAR(20) ,
           @n_skuqty           INT ,
           @n_skurqty          INT ,
           @c_cartonno         NVARCHAR(5),
           @n_loopno           INT,
           @c_LastRec          NVARCHAR(1),
           @c_ExecStatements   NVARCHAR(4000),
           @c_ExecArguments    NVARCHAR(4000),
           @c_col32            NVARCHAR(10)

   SET @d_Trace_StartTime = GETDATE()
   SET @c_Trace_ModuleName = ''

    -- SET RowNo = 0
    SET @c_SQL = ''
    SET @n_CurrentPage = 1
    SET @n_TTLpage =1
    SET @n_MaxLine = 8
    SET @n_CntRec = 1
    SET @n_intFlag = 1
    SET @n_loopno = 1
    SET @c_LastRec = 'Y'

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


      CREATE TABLE [#TEMPEATSKU01] (
      [ID]          [INT] IDENTITY(1,1) NOT NULL,
      [Orderkey]    [NVARCHAR] (20) NULL,
      [cartonno]    [NVARCHAR] (5) NULL,
      [SKU]         [NVARCHAR] (20) NULL,
      [PQty]        INT,
      [labelno]     [NVARCHAR](20) NULL,
      [Retrieve]    [NVARCHAR](1) default 'N')



         SET @c_SQLJOIN = +' SELECT DISTINCT pd.labelno,o.c_company,'
            + 'RTRIM(ISNULL(o.c_address1,'''')),RTRIM(ISNULL(o.c_address2,'''')),RTRIM(ISNULL(o.c_address3,'''')),'+ CHAR(13)      --5
             + ' RTRIM(ISNULL(o.c_address4,'''')),Substring(ISNULL(o.notes,''''),1,80),o.externorderkey,o.orderkey,'
             + ' CONVERT(NVARCHAR(10), o.deliverydate, 111),CONVERT(NVARCHAR(5), pd.cartonno),'     --11
             + ' CONVERT(NVARCHAR(5), ph.ttlcnts),'''','''','''','     --15
             + ' '''','''','''','''','''','     --20
             + CHAR(13) +
             + ' '''','''','''','''','''','''','''','''',ISNULL(o.route,''''),ph.PickSlipNo,'  --30    
             + ' pd.dropid,'''','''','''','''','''','''','''','''','''','   --40
             + ' '''','''','''','''','''','''','''','''','''','''', '  --50
             + ' '''','''','''','''','''','''','''',''1'','''',''O'' '   --60
             + CHAR(13) +
             + ' FROM PackHeader AS ph WITH (NOLOCK)'
             + ' JOIN PackDetail AS pd WITH (NOLOCK) ON pd.PickSlipNo = ph.PickSlipNo'
             + ' JOIN ORDERS AS o WITH (NOLOCK) ON o.OrderKey = ph.OrderKey '
             + ' JOIN Storer ST WITH (NOLOCK) ON ST.storerkey=o.storerkey '          
             + ' WHERE pd.pickslipno = @c_Sparm01 '
             + ' AND pd.cartonno =  @c_Sparm02 '


      IF @b_debug=1
      BEGIN
         PRINT @c_SQLJOIN
      END

  SET @c_SQL='INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09'  + CHAR(13) +
             +',Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22'  + CHAR(13) +
             +',Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34' + CHAR(13) +
             +',Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44'  + CHAR(13) +
             +',Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54'+ CHAR(13) +
             + ',Col55,Col56,Col57,Col58,Col59,Col60) '

SET @c_SQL = @c_SQL + @c_SQLJOIN


 SET @c_ExecArguments = N'     @c_Sparm01          NVARCHAR(80)'
                          + ', @c_Sparm02          NVARCHAR(80) '


   EXEC sp_ExecuteSql     @c_SQL
                        , @c_ExecArguments
                        , @c_Sparm01
                        , @c_Sparm02

   IF @b_debug=1
   BEGIN
      PRINT @c_SQL
   END


   IF @b_debug=1
   BEGIN
      SELECT * FROM #Result (nolock)
   END


  DECLARE CUR_RowNoLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
  SELECT DISTINCT col01,col09,col11
   FROM #Result
   WHERE Col60 = 'O'

   OPEN CUR_RowNoLoop

   FETCH NEXT FROM CUR_RowNoLoop INTO @c_labelno,@c_orderkey,@c_cartonno

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF @b_debug='1'
      BEGIN
         PRINT @c_labelno
      END

      INSERT INTO #TEMPEATSKU01 (Orderkey,Cartonno,SKU,PQty,labelno,Retrieve)
      Select DISTINCT @c_orderkey,@c_cartonno,ODT.sku, SUM(pd.qty),@c_labelno,'N'
      FROM (
      SELECT O.OrderKey, OD.SKU, OD.StorerKey
      FROM ORDERS AS O WITH (NOLOCK)
      JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.OrderKey = O.OrderKey
        WHERE   O.OrderKey = @c_orderkey
      GROUP BY O.OrderKey, OD.SKU, OD.StorerKey  ) AS ODT
      JOIN PackDetail AS pd WITH (NOLOCK) ON pd.StorerKey = ODT.StorerKey AND pd.SKU = ODT.SKU
       WHERE pd.labelno = @c_labelno
      AND pd.cartonno = CONVERT(INT,@c_cartonno)
      GROUP BY ODT.sku


      SET @c_SKU01 = ''
      SET @c_SKU02 = ''
      SET @c_SKU03 = ''
      SET @c_SKU04 = ''
      SET @c_SKU05 = ''
      SET @c_SKU06 = ''
      SET @c_SKU07 = ''
      SET @c_SKU08 = ''
      SET @c_SKUQty01 = ''
      SET @c_SKUQty02 = ''
      SET @c_SKUQty03 = ''
      SET @c_SKUQty04 = ''
      SET @c_SKUQty05 = ''
      SET @c_SKUQty06 = ''
      SET @c_SKUQty07 = ''
      SET @c_SKUQty08 = ''

      SELECT @n_CntRec = COUNT (1)
      FROM #TEMPEATSKU01
      WHERE labelno = @c_labelno
      AND orderkey = @c_orderkey
      AND Retrieve = 'N'

      SET @n_TTLpage =  FLOOR(@n_CntRec / @n_MaxLine ) + CASE WHEN @n_CntRec % @n_MaxLine > 0 THEN 1 ELSE 0 END


     WHILE @n_intFlag <= @n_CntRec
     BEGIN


       IF @n_intFlag > @n_MaxLine AND (@n_intFlag%@n_MaxLine) = 1 --AND @c_LastRec = 'N'
       BEGIN

         SET @n_CurrentPage = @n_CurrentPage + 1

       IF (@n_CurrentPage>@n_TTLpage)
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
                      Col11,Col12,'','','', '','','','','',
                      '','','','','', '','','',col29,col30,
                      col31,'','','','', '','','','','',
                      '','','','','', '','','','','',
                      '','','','','', '','','','',col60
          FROM  #Result
          WHERE Col60='O'


               SET @c_SKU01 = ''
               SET @c_SKU02 = ''
               SET @c_SKU03 = ''
               SET @c_SKU04 = ''
               SET @c_SKU05 = ''
               SET @c_SKU06 = ''
               SET @c_SKU07 = ''
               SET @c_SKU08 = ''
               SET @c_SKUQty01 = ''
               SET @c_SKUQty02 = ''
               SET @c_SKUQty03 = ''
               SET @c_SKUQty04 = ''
               SET @c_SKUQty05 = ''
               SET @c_SKUQty06 = ''
               SET @c_SKUQty07 = ''
               SET @c_SKUQty08 = ''

       END


      SELECT @c_sku = SKU,
            @n_skuqty = SUM(PQty)
      FROM #TEMPEATSKU01
      WHERE ID = @n_intFlag
      GROUP BY SKU


      IF (@n_intFlag%@n_MaxLine) = 1 --AND @n_recgrp = @n_CurrentPage
       BEGIN
         --SELECT '1'
        SET @c_sku01 = @c_sku
        SET @c_SKUQty01 = CONVERT(NVARCHAR(10),@n_skuqty)
       END

       ELSE IF (@n_intFlag%@n_MaxLine) = 2  --AND @n_recgrp = @n_CurrentPage
       BEGIN
         --SELECT '2'
        SET @c_sku02 = @c_sku
        SET @c_SKUQty02 = CONVERT(NVARCHAR(10),@n_skuqty)
       END
        ELSE IF (@n_intFlag%@n_MaxLine) = 3  --AND @n_recgrp = @n_CurrentPage
       BEGIN
         --SELECT '3'
        SET @c_sku03 = @c_sku
        SET @c_SKUQty03 = CONVERT(NVARCHAR(10),@n_skuqty)
       END
        ELSE IF (@n_intFlag%@n_MaxLine) = 4  --AND @n_recgrp = @n_CurrentPage
       BEGIN
         --SELECT '4'
        SET @c_sku04 = @c_sku
        SET @c_SKUQty04 = CONVERT(NVARCHAR(10),@n_skuqty)
       END
        ELSE IF (@n_intFlag%@n_MaxLine) = 5 --AND @n_recgrp = @n_CurrentPage
       BEGIN
         --SELECT '5'
        SET @c_sku05 = @c_sku
        SET @c_SKUQty05 = CONVERT(NVARCHAR(10),@n_skuqty)
       END
        ELSE IF (@n_intFlag%@n_MaxLine) = 6  --AND @n_recgrp = @n_CurrentPage
       BEGIN
         --SELECT '6'
        SET @c_sku06 = @c_sku
        SET @c_SKUQty06 = CONVERT(NVARCHAR(10),@n_skuqty)
       END
        ELSE IF (@n_intFlag%@n_MaxLine) = 7  --AND @n_recgrp = @n_CurrentPage
       BEGIN
         --SELECT '7'
        SET @c_sku07 = @c_sku
        SET @c_SKUQty07 = CONVERT(NVARCHAR(10),@n_skuqty)
       END
        ELSE IF (@n_intFlag%@n_MaxLine) = 0  --AND @n_recgrp = @n_CurrentPage
       BEGIN
         --SELECT '8'
        SET @c_sku08= @c_sku
        SET @c_SKUQty08 = CONVERT(NVARCHAR(10),@n_skuqty)
       END
  
SET @c_col32 = ''
SET @c_col32 = CAST((CAST(@c_SKUQty01 AS INT) + CAST(@c_SKUQty02 AS INT)+ CAST(@c_SKUQty03 AS INT)+ CAST( @c_SKUQty04 AS INT)
                     + CAST(@c_SKUQty05 AS INT)+ CAST( @c_SKUQty06 AS INT)+ CAST( @c_SKUQty07 AS INT)+ CAST( @c_SKUQty08 AS INT)) AS NVARCHAR(10))
        UPDATE #Result
          SET Col13 = @c_sku01,
              Col14 = @c_SKUQty01,
              Col15 = @c_sku02,
              Col16 = @c_SKUQty02,
              Col17 = @c_sku03,
              Col18 = @c_SKUQty03,
              Col19 = @c_sku04,
              Col20 = @c_SKUQty04,
              Col21 = @c_sku05,
              Col22 = @c_SKUQty05,
              Col23 = @c_sku06,
              Col24 = @c_SKUQty06,
              col25 = @c_sku07,
              Col26 = @c_SKUQty07,
              Col27 = @c_sku08,
              col28 = @c_SKUQty08,
              col32 = @c_col32
          WHERE ID = @n_CurrentPage

         -- SELECT * FROM #Result

          UPDATE  #TEMPEATSKU01
          SET Retrieve ='Y'
         WHERE ID= @n_intFlag


     SET @n_intFlag = @n_intFlag + 1

     IF @n_intFlag > @n_CntRec
     BEGIN
       BREAK;
     END
   END
   FETCH NEXT FROM CUR_RowNoLoop INTO @c_labelno,@c_orderkey,@c_cartonno

      END -- While
      CLOSE CUR_RowNoLoop
      DEALLOCATE CUR_RowNoLoop


   SELECT * FROM #Result (nolock)
   --WHERE ISNULL(Col02,'') <> ''
   ORDER BY col58

EXIT_SP:

   SET @d_Trace_EndTime = GETDATE()
   SET @c_UserName = SUSER_SNAME()



END -- procedure



GO