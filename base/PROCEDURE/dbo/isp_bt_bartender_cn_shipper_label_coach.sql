SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Copyright: IDS                                                             */
/* Purpose: isp_BT_Bartender_CN_Shipper_Label_Coach                           */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date          Rev  Author     Purposes                                     */
/* 17-MAR-2021   1.0  CSCHONG    WMS-16479 Created                            */
/* 07-APR-2022   1.1  CSCHONG    Devops Scripts Combine & WMS-19248           */
/******************************************************************************/

CREATE PROC [dbo].[isp_BT_Bartender_CN_Shipper_Label_Coach]
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
      @c_Pickslipno      NVARCHAR(20),
      @c_sku             NVARCHAR(20),
      @n_intFlag         INT,
      @n_CntRec          INT,
      @c_SQL             NVARCHAR(4000),
      @c_SQLSORT         NVARCHAR(4000),
      @c_SQLJOIN         NVARCHAR(4000),
      @c_SStyle          NVARCHAR(20),
      @c_SSize           NVARCHAR(20),
      @c_SColor          NVARCHAR(20),
      @c_SDESCR          NVARCHAR(80),
      @c_ExecStatements  NVARCHAR(4000),
      @c_ExecArguments   NVARCHAR(4000)

  DECLARE  @d_Trace_StartTime  DATETIME,
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
           @c_SKU09            NVARCHAR(20),
           @c_SKU10            NVARCHAR(20),
           @c_SKU11            NVARCHAR(20),
           @c_SKU12            NVARCHAR(20),
           @c_SKU13            NVARCHAR(20),
           @c_SKU14            NVARCHAR(20),
           @c_SKU15            NVARCHAR(20),
           @c_SKU16            NVARCHAR(20),
           @c_SKUQty01         NVARCHAR(10),
           @c_SKUQty02         NVARCHAR(10),
           @c_SKUQty03         NVARCHAR(10),
           @c_SKUQty04         NVARCHAR(10),
           @c_SKUQty05         NVARCHAR(10) ,
           @c_SKUQty06         NVARCHAR(10) ,
           @c_SKUQty07         NVARCHAR(10) ,
           @c_SKUQty08         NVARCHAR(10) ,
           @c_SKUQty09         NVARCHAR(10) ,
           @c_SKUQty10         NVARCHAR(10) ,
           @c_SKUQty11         NVARCHAR(10) ,
           @c_SKUQty12         NVARCHAR(10) ,
           @c_SKUQty13         NVARCHAR(10) ,
           @c_SKUQty14         NVARCHAR(10) ,
           @c_SKUQty15         NVARCHAR(10) ,
           @c_SKUQty16         NVARCHAR(10) ,
           @n_TTLpage          INT,
           @n_CurrentPage      INT,
           @n_MaxLine          INT  ,
           @c_cartonno         NVARCHAR(10) ,
           @n_MaxCtnNo         INT,
           @n_skuqty           INT,
           @n_pageQty          INT,
           @n_Pickqty          INT,
           @n_PACKQty          INT,
           @c_col54            NVARCHAR(20),
           @c_col19            NVARCHAR(80),
           @c_orderkey         NVARCHAR(20),
           @c_storerkey        NVARCHAR(20),
           @c_GetCol55         NVARCHAR(100),
           @c_GetCol55_From     NVARCHAR(4000),
           @c_Col55            NVARCHAR(80)

   SET @d_Trace_StartTime = GETDATE()
   SET @c_Trace_ModuleName = ''

    -- SET RowNo = 0
    SET @c_SQL = ''
    SET @n_TTLpage =1
    SET @n_MaxLine = 14
    --SET @n_CntRec = 1
    --SET @n_intFlag = 1
    SET @c_col54 = ''

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


   CREATE TABLE [#TEMPSKU] (
      [ID]          [INT] NOT NULL,
      [Pickslipno]  [NVARCHAR] (20)  NULL,
      [CartonNo]    [NVARCHAR] (30)  NULL,
      [SKU]         [NVARCHAR] (20)  NULL,
      [Qty]         INT ,
      [Retrieve]    [NVARCHAR] (1) default 'N')

  SET @c_SQLJOIN = +' SELECT DISTINCT ST.B_Company,f.descr,ISNULL(RTRIM(f.state),'''') ,'
             + ' ISNULL(RTRIM(f.city),''''),ISNULL(RTRIM(f.address1),''''),'+ CHAR(13)      --5
             + ' ISNULL(RTRIM(cl.udf02),''''),ISNULL(RTRIM(ord.m_company),''''),ISNULL(RTRIM(ord.userdefine05),'''')'  --├ô┬ª┬╕├â├è├çcl
             + ' ,ISNULL(RTRIM(ord.c_city),''''),ORD.c_Company,'     --10
             + ' ISNULL(RTRIM(ORD.c_address1),''''),ISNULL(RTRIM(ORD.c_address2),''''),ISNULL(RTRIM(ord.userdefine01),''''),'
             + ' ISNULL(cl2.short,LEFT(Ord.Notes,1)) + SUBSTRING(Ord.Notes,2,LEN(Ord.Notes)),ISNULL(RTRIM(ORD.M_address1),''''),'     --15    --col15 isnull├ë├Ö├ü├ï,'')├Ç┬¿┬║├à, col14├ê┬ícl2┬╡├äshort
             + ' PD.Cartonno,PD.labelno,ct.cube,'''','''','     --20
             + CHAR(13) +
             + ' '''','''','''','''','''','''','''','''','''','''','  --30
             + ' '''','''','''','''','''','''','''','''','''','''','   --40
             + ' '''','''','''','''','''','''','''','''','''','''', '  --50
             + ' '''','''',ORD.xdockpokey,'''','''','''','''',''1'',PH.Pickslipno,CONVERT(NVARCHAR(20),GETDATE(),120) '   --60    --CS01
             + CHAR(13) +
             +' FROM ORDERS ORD WITH (NOLOCK) '
             +' JOIN PACKHEADER PH WITH (NOLOCK) ON PH.OrderKey = ORD.OrderKey'
             +' JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.Pickslipno = PH.Pickslipno '
             +' JOIN STORER ST (NOLOCK) ON ST.StorerKey = ORD.StorerKey'    --├ô┬ª┬╕├â├è├ç ST.StorerKey = ORD.StorerKey
             +' JOIN FACILITY f (NOLOCK) ON f.Facility = ord.Facility'
             +' LEFT JOIN PACKINFO PIF WITH (NOLOCK) ON PIF.Pickslipno = PD.Pickslipno AND PIF.CartonNo = PD.CartonNo '
             +' LEFT JOIN CARTONIZATION ct (NOLOCK) ON ct.CartonizationGroup = ST.CartonGroup AND ct.CartonType = PIF.CartonType'
             +' LEFT JOIN CODELKUP cl (NOLOCK) ON cl.LISTNAME=''TPYORDTYPE'' AND cl.Storerkey = ORD.StorerKey AND cl.Code=ORD.UserDefine10'   --├ô┬ª┬╕├â├è├ç cl.Storerkey = ORD.StorerKey, TPYORDTYPE ┬╡├äcode├ô┬ª┬╕├â├è├çORD.UserDefine10
             --+' AND PIF.CartonNo = PD.CartonNo '      --├ò├ó┬╢├Ä┬╢├á├ü├ï
             +' LEFT JOIN CODELKUP cl2 (NOLOCK) ON cl2.LISTNAME = ''TPYNOTETRF'' AND cl2.Storerkey= ORD.StorerKey AND cl2.Code = ORD.UserDefine10'  --├ö├╢┬╝├ônote├ù┬¬┬╗┬╗┬╡├äcodelkup
             +' WHERE PD.Pickslipno =  @c_Sparm01'
             +' AND PD.Cartonno >= CONVERT(INT,  @c_Sparm02)'
             +' AND PD.Cartonno <= CONVERT(INT,  @c_Sparm03)'


   IF @b_debug=1
   BEGIN
      PRINT @c_SQLJOIN
   END

   SET @c_SQL='INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09'  + CHAR(13) +
             +',Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22'  + CHAR(13) +
             +',Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34' + CHAR(13) +
             +',Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44'  + CHAR(13) +
             +',Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54'+ CHAR(13) +
             +',Col55,Col56,Col57,Col58,Col59,Col60) '

   SET @c_SQL = @c_SQL + @c_SQLJOIN

   --EXEC sp_executesql @c_SQL

   SET @c_ExecArguments = N'  @c_Sparm01           NVARCHAR(80)'
                         + ', @c_Sparm02           NVARCHAR(80) '
                         + ', @c_Sparm03           NVARCHAR(80) '

   EXEC sp_ExecuteSql     @c_SQL
                        , @c_ExecArguments
                        , @c_Sparm01
                        , @c_Sparm02
                        , @c_Sparm03


   IF @b_debug=1
   BEGIN
      PRINT @c_SQL
   END

   IF @b_debug=1
   BEGIN
      SELECT * FROM #Result (nolock)
   END

   DECLARE CUR_RowNoLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT Col59,col16
      FROM #Result

   OPEN CUR_RowNoLoop

   FETCH NEXT FROM CUR_RowNoLoop INTO @c_Pickslipno,@c_cartonno

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF @b_debug='1'
      BEGIN
         PRINT @c_Pickslipno +space(2) +@c_cartonno
      END

     DELETE #TEMPSKU

      INSERT INTO [#TEMPSKU] (ID,Pickslipno, cartonno, SKU,  Qty,   Retrieve)
      SELECT ROW_NUMBER() OVER (ORDER BY PD.Pickslipno,PD.Cartonno,S.MANUFACTURERSKU),PD.Pickslipno,PD.CartonNo,S.MANUFACTURERSKU,SUM(PD.Qty),'N'
      FROM PACKDETAIL AS PD WITH (NOLOCK)
      JOIN SKU S WITH (NOLOCK) ON s.StorerKey=PD.StorerKey AND s.sku = PD.Sku
      WHERE PD.Pickslipno = @c_Pickslipno
      AND PD.Cartonno = CAST(@c_cartonno as INT)
      GROUP BY PD.Pickslipno,PD.CartonNo,S.MANUFACTURERSKU
      ORDER BY PD.Pickslipno,PD.Cartonno,S.MANUFACTURERSKU

      SET @c_SKU01 = ''
      SET @c_SKU02 = ''
      SET @c_SKU03 = ''
      SET @c_SKU04 = ''
      SET @c_SKU05= ''
      SET @c_SKU06= ''
      SET @c_SKU07= ''
      SET @c_SKU08= ''
      SET @c_SKU09= ''
      SET @c_SKU10= ''
      SET @c_SKU11= ''
      SET @c_SKU12= ''
      SET @c_SKU13= ''
      SET @c_SKU14= ''
      SET @c_SKU15= ''
      SET @c_SKU16= ''
      SET @c_SKUQty01 = ''
      SET @c_SKUQty02 = ''
      SET @c_SKUQty03 = ''
      SET @c_SKUQty04 = ''
      SET @c_SKUQty05 = ''
      SET @c_SKUQty06 = ''
      SET @c_SKUQty07 = ''
      SET @c_SKUQty08 = ''
      SET @c_SKUQty09 = ''
      SET @c_SKUQty10 = ''
      SET @c_SKUQty11 = ''
      SET @c_SKUQty12 = ''
      SET @c_SKUQty13 = ''
      SET @c_SKUQty14 = ''
      SET @c_SKUQty15 = ''
      SET @c_SKUQty16 = ''
      SET @n_MaxCtnNo = 0
      SET @n_TTLpage = 1
      SET @n_pageQty = 0
      SET @n_Pickqty = 0
      SET @n_PACKQty = 0
      SET @c_storerkey = ''
      SET @c_orderkey = ''
      SET @c_col19 = ''

      SET @n_CurrentPage = 1
      SET @n_CntRec = 1
      SET @n_intFlag = 1

      SELECT @c_storerkey = PH.Storerkey
            ,@c_orderkey = PH.Orderkey
      FROM PACKHEADER PH (NOLOCK)
      WHERE PH.Pickslipno = @c_Pickslipno

      SELECT TOP 1 @c_GetCol55 = C.Long   ,
                 @c_GetCol55_From = C.Notes
      FROM Codelkup C WITH (NOLOCK)
      WHERE C.listname='TPYLBLCFG' and c.code = 'CTNCOL55'
      AND c.StorerKey = @c_StorerKey

      IF @b_debug = '1'
      BEGIN
         PRINT ' Get Col55 : ' + @c_GetCol55
         PRINT ' Get Col55 From: ' + @c_GetCol55_From
      END

      IF ISNULL(@c_GetCol55,'') = '' OR ISNULL(@c_GetCol55_From,'') = ''
      BEGIN
         SET @c_GetCol55 = 'MBOL.ExternMBOLKey'
         SET @c_GetCol55_From = 'ORDERS (NOLOCK) JOIN MBOL WITH (NOLOCK) ON MBOL.Mbolkey = ORDERS.mbolkey WHERE ORDERS.Orderkey = @c_OrderKey '
      END
      SET @c_ExecStatements = ''
      SET @c_ExecArguments = ''

      SET @c_ExecStatements = N' SELECT @c_Col55 = ' + @c_GetCol55 + ' FROM ' + @c_GetCol55_From

      SET @c_ExecArguments = N'@c_GetCol55   NVARCHAR(80) '
                             +',@c_OrderKey  NVARCHAR(30)'
                             +',@c_Col55     NVARCHAR(20) OUTPUT'

      EXEC sp_ExecuteSql @c_ExecStatements
                        , @c_ExecArguments
                        , @c_GetCol55
                        , @c_OrderKey
                        , @c_Col55 OUTPUT

      IF @b_debug = '1'
      BEGIN
         PRINT ' Col55 : ' + @c_Col55
      END
      /*CS15 END*/

      IF EXISTS (SELECT 1 FROM PackDetail pd (NOLOCK)
                 JOIN SKU s (NOLOCK) ON s.StorerKey = pd.StorerKey AND s.Sku = pd.SKU
                 WHERE pd.PickSlipNo=@c_PickSlipNo AND pd.CartonNo = @c_CartonNo AND s.ShelfLife>0)
      BEGIN
           SET @c_Col19 = N'µÿôτçâµÿôτóÄ'
      END


      SELECT @n_CntRec = COUNT (1)
      FROM #TEMPSKU
      WHERE Pickslipno = @c_Pickslipno
      AND Cartonno = @c_cartonno
      AND Retrieve = 'N'

      SET @n_TTLpage =  FLOOR(@n_CntRec / @n_MaxLine )

      IF @n_TTLpage = 0
      BEGIN
         SET @n_TTLpage = 1
      END
      ELSE
      BEGIN
         IF (@n_CntRec%@n_MaxLine) <> 0
         BEGIN
            SET @n_TTLpage = @n_TTLpage + 1
         END
      END

      SELECT @n_PickQty = SUM(Qty)
      FROM #TEMPSKU
      WHERE Pickslipno = @c_Pickslipno
      AND Cartonno = @c_cartonno

      WHILE @n_intFlag <= @n_CntRec
      BEGIN
         SELECT @c_sku    = SKU,
                @n_skuqty = SUM(Qty)
         FROM #TEMPSKU
         WHERE ID = @n_intFlag
         GROUP BY SKU

         IF (@n_intFlag%@n_MaxLine) = 1
         BEGIN
            SET @c_sku01    = @c_sku
            SET @c_SKUQty01 = CONVERT(NVARCHAR(10),@n_skuqty)

         END

         ELSE IF (@n_intFlag%@n_MaxLine) = 2
         BEGIN
            SET @c_sku02    = @c_sku
            SET @c_SKUQty02 = CONVERT(NVARCHAR(10),@n_skuqty)

         END

         ELSE IF (@n_intFlag%@n_MaxLine) = 3
         BEGIN
            SET @c_sku03    = @c_sku
            SET @c_SKUQty03 = CONVERT(NVARCHAR(10),@n_skuqty)
         END

         ELSE IF (@n_intFlag%@n_MaxLine) = 4
         BEGIN
            SET @c_sku04    = @c_sku
            SET @c_SKUQty04 = CONVERT(NVARCHAR(10),@n_skuqty)
         END

         ELSE IF (@n_intFlag%@n_MaxLine) = 5
         BEGIN
            SET @c_sku05    = @c_sku
            SET @c_SKUQty05 = CONVERT(NVARCHAR(10),@n_skuqty)
         END

         ELSE IF (@n_intFlag%@n_MaxLine) = 6
         BEGIN
            SET @c_sku06    = @c_sku
            SET @c_SKUQty06 = CONVERT(NVARCHAR(10),@n_skuqty)
         END
         ELSE IF (@n_intFlag%@n_MaxLine) = 7
         BEGIN
            SET @c_sku07    = @c_sku
            SET @c_SKUQty07 = CONVERT(NVARCHAR(10),@n_skuqty)
         END
         ELSE IF (@n_intFlag%@n_MaxLine) = 8
         BEGIN
            SET @c_sku08    = @c_sku
            SET @c_SKUQty08 = CONVERT(NVARCHAR(10),@n_skuqty)
         END
         ELSE IF (@n_intFlag%@n_MaxLine) = 9
         BEGIN
            SET @c_sku09    = @c_sku
            SET @c_SKUQty09 = CONVERT(NVARCHAR(10),@n_skuqty)
         END

         ELSE IF (@n_intFlag%@n_MaxLine) = 10
         BEGIN
            SET @c_sku10    = @c_sku
            SET @c_SKUQty10 = CONVERT(NVARCHAR(10),@n_skuqty)

         END
         ELSE IF (@n_intFlag%@n_MaxLine) = 11
         BEGIN
            SET @c_sku11    = @c_sku
            SET @c_SKUQty11 = CONVERT(NVARCHAR(10),@n_skuqty)

         END
         ELSE IF (@n_intFlag%@n_MaxLine) = 12
         BEGIN
            SET @c_sku12   = @c_sku
            SET @c_SKUQty12 = CONVERT(NVARCHAR(10),@n_skuqty)

         END
         ELSE IF (@n_intFlag%@n_MaxLine) = 13
         BEGIN
            SET @c_sku13    = @c_sku
            SET @c_SKUQty13 = CONVERT(NVARCHAR(10),@n_skuqty)

         END
         ELSE IF (@n_intFlag%@n_MaxLine) = 0              --CS01
         BEGIN
            SET @c_sku14    = @c_sku
            SET @c_SKUQty14 = CONVERT(NVARCHAR(10),@n_skuqty)

         END
         --ELSE IF (@n_intFlag%@n_MaxLine) = 15           --CS01 START
         --BEGIN
         --   SET @c_sku15    = @c_sku
         --   SET @c_SKUQty15 = CONVERT(NVARCHAR(10),@n_skuqty)
         --END
         --ELSE IF (@n_intFlag%@n_MaxLine) = 0
         --BEGIN
         --   SET @c_sku16    = @c_sku
         --   SET @c_SKUQty16 = CONVERT(NVARCHAR(10),@n_skuqty)
         --END                                            --CS01 End

         UPDATE #Result
         SET col19 = @c_Col19,
             col20 =  CAST(@n_PickQty as NVARCHAR(10))  ,
             Col21 = @c_sku01,
             Col22 = @c_SKUQty01,
             Col23 = @c_sku02,
             Col24 = @c_SKUQty02,
             Col25 = @c_sku03,
             Col26 = @c_SKUQty03,
             Col27 = @c_sku04,
             Col28 = @c_SKUQty04,
             Col29 = @c_sku05,
             Col30 = @c_SKUQty05,
             Col31 = @c_sku06,
             Col32 = @c_SKUQty06,
             Col33 = @c_sku07,
             Col34 = @c_SKUQty07,
             Col35 = @c_sku08,
             Col36 = @c_SKUQty08,
             Col37 = @c_sku09,
             Col38 = @c_SKUQty09,
             Col39 = @c_sku10,
             Col40 = @c_SKUQty10,
             Col41 = @c_sku11,
             Col42 = @c_SKUQty11,  --├ô┬ª┬╕├â├è├ç42
             Col43 = @c_sku12,
             Col44 = @c_SKUQty12,
             Col45 = @c_sku13,
             Col46 = @c_SKUQty13,
             Col47 = @c_sku14,
             Col48 = @c_SKUQty14,
             --Col49 = @c_sku15,                       --CS01 S
             --Col50 = @c_SKUQty15,
             --Col51 = @c_sku16,
             --Col52 = @c_SKUQty16,                    --CS01 E
             Col55 = @c_Col55
         WHERE Col59=@c_Pickslipno AND Col16=@c_cartonno AND Col58 = @n_CurrentPage


         IF (@n_intFlag%@n_MaxLine) = 0 AND @n_CurrentPage < @n_TTLpage
         BEGIN
            SET @n_CurrentPage = @n_CurrentPage + 1

            SET @c_SKU01 = ''
            SET @c_SKU02 = ''
            SET @c_SKU03 = ''
            SET @c_SKU04 = ''
            SET @c_SKU05= ''
            SET @c_SKU06= ''
            SET @c_SKU07= ''
            SET @c_SKU07= ''
            SET @c_SKU08= ''
            SET @c_SKU09= ''
            SET @c_SKU10= ''
            SET @c_SKU11= ''
            SET @c_SKU12= ''
            SET @c_SKU13= ''
            SET @c_SKU14= ''
            SET @c_SKU15= ''
            SET @c_SKU16= ''
            SET @c_SKUQty01 = ''
            SET @c_SKUQty02 = ''
            SET @c_SKUQty03 = ''
            SET @c_SKUQty04 = ''
            SET @c_SKUQty05 = ''
            SET @c_SKUQty06 = ''
            SET @c_SKUQty07 = ''
            SET @c_SKUQty08 = ''
            SET @c_SKUQty09 = ''
            SET @c_SKUQty10 = ''
            SET @c_SKUQty11 = ''
            SET @c_SKUQty12 = ''
            SET @c_SKUQty13 = ''
            SET @c_SKUQty14 = ''
            SET @c_SKUQty15 = ''
            SET @c_SKUQty16 = ''
            SET @n_pageqty = 0

            INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09
                                ,Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22
                                ,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34
                                ,Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44
                                ,Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54
                                ,Col55,Col56,Col57,Col58,Col59,Col60)
          SELECT TOP 1 Col01,Col02,Col03,Col04,Col05,Col06,Col07,Col08,Col09,Col10,
                         Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,col19,'',
                         '','','','','', '','','','','',
                         '','','','','', '','','','','',
                         '','','','','', '','','','','',
                         '','',col53,'','', '','',@n_CurrentPage,col59,col60           --CS01
            FROM  #Result
         END

         SET @n_intFlag = @n_intFlag + 1
      END

      FETCH NEXT FROM CUR_RowNoLoop INTO  @c_pickslipno,@c_cartonno

   END -- While
   CLOSE CUR_RowNoLoop
   DEALLOCATE CUR_RowNoLoop

   SELECT * FROM #Result (nolock)

EXIT_SP:

   SET @d_Trace_EndTime = GETDATE()
   SET @c_UserName = SUSER_SNAME()

   --EXEC isp_InsertTraceInfo
   --   @c_TraceCode = 'BARTENDER',
   --   @c_TraceName = 'isp_BT_Bartender_CN_Shipper_Label_Coach',
   --   @c_starttime = @d_Trace_StartTime,
   --   @c_endtime = @d_Trace_EndTime,
   --   @c_step1 = @c_UserName,
   --   @c_step2 = '',
   --   @c_step3 = '',
   --   @c_step4 = '',
   --   @c_step5 = '',
   --   @c_col1 = @c_Sparm01,
   --   @c_col2 = @c_Sparm02,
   --   @c_col3 = @c_Sparm03,
   --   @c_col4 = @c_Sparm04,
   --   @c_col5 = @c_Sparm05,
   --   @b_Success = 1,
   --   @n_Err = 0,
   --   @c_ErrMsg = ''

END

GO