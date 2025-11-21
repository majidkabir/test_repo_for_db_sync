SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Copyright: LFL                                                             */
/* Purpose: isp_Bartender_Shipper_Label_KR_02                                 */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date        Rev  Author     Purposes                                       */
/* 09-Jan-2023 1.0  WLChooi    Created (WMS-21470)                            */
/* 09-Jan-2023 1.0  WLChooi    DevOps Combine Script                          */
/******************************************************************************/

CREATE PROC [dbo].[isp_Bartender_Shipper_Label_KR_02]
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
   -- SET ANSI_WARNINGS OFF                              

   DECLARE @c_getPickslipno NVARCHAR(10)
         , @c_getlabelno    NVARCHAR(20)
         , @C_RECEIPTKEY    NVARCHAR(11)
         , @c_Pickslipno    NVARCHAR(10)
         , @n_TTLCNT        INT
         , @n_TTLSKUQTY     INT
         , @n_Page          INT
         , @n_ID            INT
         , @n_RID           INT
         , @n_MaxLine       INT
         , @n_MaxLineRec    INT
         , @c_StateCity     NVARCHAR(80)
         , @c_OHCompany     NVARCHAR(45)
         , @c_OHAddress1    NVARCHAR(45)
         , @c_OHAddress2    NVARCHAR(45)
         , @c_OHAddress3    NVARCHAR(45)
         , @c_OHAddress4    NVARCHAR(45)
         , @c_ExtOrdkey     NVARCHAR(30)
         , @c_billtokey     NVARCHAR(20)
         , @c_consigneekey  NVARCHAR(20)
         , @c_czip          NVARCHAR(45)
         , @c_PDCartonNo    NVARCHAR(10)
         , @c_FacilityAdd   NVARCHAR(30)
         , @c_labelno       NVARCHAR(20)
         , @n_CurrentPage   INT
         , @n_intFlag       INT
         , @n_RecCnt        INT
         , @n_ttlqty        INT

   DECLARE @c_line01   NVARCHAR(80)
         , @c_Style    NVARCHAR(80)
         , @c_Scolor   NVARCHAR(80)
         , @c_Ssize    NVARCHAR(80)
         , @c_SMEASM   NVARCHAR(80)
         , @n_qty      INT
         , @c_Style01  NVARCHAR(80)
         , @c_Scolor01 NVARCHAR(80)
         , @c_SSize01  NVARCHAR(80)
         , @c_SMEASM01 NVARCHAR(80)
         , @n_qty01    INT
         , @c_line02   NVARCHAR(80)
         , @c_Style02  NVARCHAR(80)
         , @c_Scolor02 NVARCHAR(80)
         , @c_SSize02  NVARCHAR(80)
         , @c_SMEASM02 NVARCHAR(80)
         , @n_qty02    INT
         , @c_line03   NVARCHAR(80)
         , @c_Style03  NVARCHAR(80)
         , @c_Scolor03 NVARCHAR(80)
         , @c_SSize03  NVARCHAR(80)
         , @c_SMEASM03 NVARCHAR(80)
         , @n_qty03    INT
         , @c_line04   NVARCHAR(80)
         , @c_Style04  NVARCHAR(80)
         , @c_Scolor04 NVARCHAR(80)
         , @c_SSize04  NVARCHAR(80)
         , @c_SMEASM04 NVARCHAR(80)
         , @n_qty04    INT
         , @c_line05   NVARCHAR(80)
         , @c_Style05  NVARCHAR(80)
         , @c_Scolor05 NVARCHAR(80)
         , @c_SSize05  NVARCHAR(80)
         , @c_SMEASM05 NVARCHAR(80)
         , @n_qty05    INT
         , @c_line06   NVARCHAR(80)
         , @c_Style06  NVARCHAR(80)
         , @c_Scolor06 NVARCHAR(80)
         , @c_SSize06  NVARCHAR(80)
         , @c_SMEASM06 NVARCHAR(80)
         , @n_qty06    INT
         , @c_line07   NVARCHAR(80)
         , @c_Style07  NVARCHAR(80)
         , @c_Scolor07 NVARCHAR(80)
         , @c_SSize07  NVARCHAR(80)
         , @c_SMEASM07 NVARCHAR(80)
         , @n_qty07    INT
         , @n_ttlPqty  INT
         , @c_Notes    NVARCHAR(80)

   DECLARE @c_SQL     NVARCHAR(4000)
         , @c_SQLSORT NVARCHAR(4000)
         , @c_SQLJOIN NVARCHAR(4000)
         , @n_TTLpage INT
         , @n_CntRec  INT

   DECLARE @d_Trace_StartTime  DATETIME
         , @d_Trace_EndTime    DATETIME
         , @c_Trace_ModuleName NVARCHAR(20)
         , @d_Trace_Step1      DATETIME
         , @c_Trace_Step1      NVARCHAR(20)
         , @c_UserName         NVARCHAR(20)
         , @n_getskugroup      INT

   SET @d_Trace_StartTime = GETDATE()
   SET @c_Trace_ModuleName = N''

   -- SET RowNo = 0                     
   SET @c_SQL = N''
   SET @n_ttlPqty = 0
   SET @n_CurrentPage = 1
   SET @n_intFlag = 1
   SET @n_RecCnt = 1
   SET @n_getskugroup = 0

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

   CREATE TABLE [#TEMPSKUContent]
   (
      [ID]           [INT]          IDENTITY(1, 1) NOT NULL
    , [Pickslipno]   [NVARCHAR](20) NULL
    , cartonno       [NVARCHAR](10) NULL
    , [Style]        [NVARCHAR](20) NULL
    , [SColor]       [NVARCHAR](10) NULL
    , [SSize]        [NVARCHAR](10) NULL
    , [SMeasurement] [NVARCHAR](80) NULL
    , [skuqty]       INT            NULL
    , [ttlctn]       INT
    , [Retrieve]     [NVARCHAR](1)  DEFAULT 'N'
   )

   IF @b_debug = 1
   BEGIN
      PRINT 'start'
   END

   DECLARE CUR_StartRecLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT CASE WHEN (MAX(ISNULL(ST.[State], '')) + MAX(ISNULL(ST.City, ''))) <> '' THEN
                                (MAX(ISNULL(ST.[State], '')) + MAX(ISNULL(ST.City, '')))
                        ELSE (MAX(ISNULL(o.C_State, '')) + MAX(ISNULL(o.C_City, ''))) END AS StateCity
                 , MAX(o.LoadKey)
                 , MAX(o.C_Company)
                 , MAX(o.BillToKey)
                 , MAX(o.ConsigneeKey)
                 , pd.LabelNo
                 , CASE WHEN MAX(ISNULL(ST.Zip, '')) <> '' THEN MAX(ISNULL(ST.Zip, ''))
                        ELSE MAX(ISNULL(o.C_Zip, '')) END AS C_Zip
                 , CASE WHEN MAX(ISNULL(ST.Address1, '')) <> '' THEN MAX(ISNULL(ST.Address1, ''))
                        ELSE MAX(ISNULL(o.C_Address1, '')) END AS OHAddress1
                 , CASE WHEN MAX(ISNULL(ST.Address2, '')) <> '' THEN MAX(ISNULL(ST.Address2, ''))
                        ELSE MAX(ISNULL(o.C_Address2, '')) END AS OHAddress2
                 , CASE WHEN MAX(ISNULL(ST.Address3, '')) <> '' THEN MAX(ISNULL(ST.Address3, ''))
                        ELSE MAX(ISNULL(o.C_Address3, '')) END AS OHAddress3
                 , CASE WHEN MAX(ISNULL(ST.Address4, '')) <> '' THEN MAX(ISNULL(ST.Address4, ''))
                        ELSE MAX(ISNULL(o.C_Address4, '')) END AS OHAddress4
                 , 0 AS ttlqty
                 , ph.PickSlipNo
                 , MAX(ISNULL(O.Notes,'')) AS Notes
   FROM PackHeader AS ph WITH (NOLOCK)
   JOIN PackDetail AS pd WITH (NOLOCK) ON pd.PickSlipNo = ph.PickSlipNo
   JOIN LoadPlanDetail AS LPD WITH (NOLOCK) ON LPD.LoadKey = ph.LoadKey
   JOIN ORDERS AS o WITH (NOLOCK) ON o.OrderKey = LPD.OrderKey
   LEFT JOIN STORER ST WITH (NOLOCK) ON ST.StorerKey = o.ConsigneeKey
   JOIN FACILITY F WITH (NOLOCK) ON F.Facility = o.Facility
   WHERE pd.PickSlipNo = @c_Sparm1 AND pd.LabelNo = @c_Sparm2
   GROUP BY pd.LabelNo
          , ph.PickSlipNo

   OPEN CUR_StartRecLoop

   FETCH NEXT FROM CUR_StartRecLoop
   INTO @c_StateCity
      , @c_ExtOrdkey
      , @c_OHCompany
      , @c_billtokey
      , @c_consigneekey
      , @c_labelno
      , @c_czip
      , @c_OHAddress1
      , @c_OHAddress2
      , @c_OHAddress3
      , @c_OHAddress4
      , @n_ttlqty
      , @c_Pickslipno
      , @c_Notes


   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SELECT @n_ttlqty = SUM(PD.Qty)
      FROM PACKDETAIL PD (NOLOCK)
      WHERE PD.PickSlipNo = @c_Sparm1 
      AND PD.LabelNo = @c_Sparm2

      IF @b_debug = 1
      BEGIN
         PRINT 'Cur start'
      END

      INSERT INTO #Result (Col01, Col02, Col03, Col04, Col05, Col06, Col07, Col08, Col09, Col10, Col11, Col12, Col13
                         , Col14, Col15, Col16, Col17, Col18, Col19, Col20, Col21, Col22, Col23, Col24, Col25, Col26
                         , Col27, Col28, Col29, Col30, Col31, Col32, Col33, Col34, Col35, Col36, Col37, Col38, Col39
                         , Col40, Col41, Col42, Col43, Col44, Col45, Col46, Col47, Col48, Col49, Col50, Col51, Col52
                         , Col53, Col54, Col55, Col56, Col57, Col58, Col59, Col60)
      VALUES (@c_StateCity, @c_ExtOrdkey, @c_OHCompany, @c_billtokey, @c_consigneekey, @c_labelno, @c_czip
            , @c_OHAddress1, @c_OHAddress2, @c_OHAddress3, @c_OHAddress4, '', '', '', '', '', '', '', '', '', '', ''
            , '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', ''
            , CONVERT(NVARCHAR(10), @n_ttlqty), @c_Notes, '', '', '', '', '', '', '', '', @c_Pickslipno, 'O')


      IF @b_debug = 1
      BEGIN
         SELECT *
         FROM #Result (NOLOCK)
      END

      SET @n_MaxLine = 7
      SET @n_MaxLineRec = 7
      SET @n_TTLpage = 1

      --IF EXISTS (  SELECT 1
      --             FROM CODELKUP WITH (NOLOCK)
      --             WHERE LISTNAME = 'CTNLBL' AND Storerkey = @c_Sparm5)
      --BEGIN
      --   SET @n_getskugroup = 1
      --END

      DECLARE CUR_RowNoLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT Col59
                    , Col06
      FROM #Result
      WHERE Col59 = @c_Sparm1 AND Col06 = @c_Sparm2
      ORDER BY Col59
             , Col06

      OPEN CUR_RowNoLoop

      FETCH NEXT FROM CUR_RowNoLoop
      INTO @c_getPickslipno
         , @c_getlabelno

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         --IF @n_getskugroup = '1'
         --BEGIN
         --   INSERT INTO #TEMPSKUContent (
         --      -- ID -- this column value is auto-generated
         --      Pickslipno, cartonno, Style, SColor, SSize, SMeasurement, skuqty, Retrieve, ttlctn)
         --   SELECT ph.PickSlipNo
         --        , pd.CartonNo
         --        , S.Style
         --        , S.Color
         --        , S.Size
         --        , S.SKUGROUP
         --        , pd.Qty
         --        , 'N'
         --        , CASE WHEN ph.[Status] <> '0' THEN @c_Sparm4
         --               ELSE 0 END
         --   FROM PackHeader AS ph WITH (NOLOCK)
         --   JOIN PackDetail AS pd WITH (NOLOCK) ON pd.PickSlipNo = ph.PickSlipNo
         --   JOIN SKU S WITH (NOLOCK) ON S.StorerKey = pd.StorerKey AND S.Sku = pd.SKU
         --   WHERE pd.PickSlipNo = @c_getPickslipno AND pd.LabelNo = @c_labelno
         --   ORDER BY ph.PickSlipNo
         --          , pd.CartonNo
         --          , S.Style
         --          , S.Color
         --          , S.Size
         --          , S.SKUGROUP

         --END
         --ELSE
         --BEGIN
         INSERT INTO #TEMPSKUContent ( Pickslipno, cartonno, Style, SColor, SSize, SMeasurement, skuqty, Retrieve, ttlctn)
         SELECT ph.PickSlipNo
              , pd.CartonNo
              , S.Style
              , S.Color
              , S.Size
              , LEFT(TRIM(ISNULL(S.NOTES2,'')),80)
              , pd.Qty
              , 'N'
              , CASE WHEN ph.[Status] <> '0' THEN @c_Sparm4
                     ELSE 0 END
         FROM PackHeader AS ph WITH (NOLOCK)
         JOIN PackDetail AS pd WITH (NOLOCK) ON pd.PickSlipNo = ph.PickSlipNo
         JOIN SKU S WITH (NOLOCK) ON S.StorerKey = pd.StorerKey AND S.Sku = pd.SKU
         WHERE pd.PickSlipNo = @c_getPickslipno AND pd.LabelNo = @c_labelno
         ORDER BY ph.PickSlipNo
                , pd.CartonNo
                , S.Style
                , S.Color
                , S.Size
                , LEFT(TRIM(ISNULL(S.NOTES2,'')),80)
         --END

         IF @b_debug = '1'
         BEGIN
            SELECT 'carton'
                 , *
            FROM [#TEMPSKUContent]
         END

         SET @c_line01 = N''
         SET @c_Style01 = N''
         SET @c_Scolor01 = N''
         SET @c_SSize01 = N''
         SET @c_SMEASM01 = N''
         SET @n_qty01 = 0
         SET @c_line02 = N''
         SET @c_Style02 = N''
         SET @c_Scolor02 = N''
         SET @c_SSize02 = N''
         SET @c_SMEASM02 = N''
         SET @n_qty02 = 0
         SET @c_line03 = N''
         SET @c_Style03 = N''
         SET @c_Scolor03 = N''
         SET @c_SSize03 = N''
         SET @c_SMEASM03 = N''
         SET @n_qty03 = 0
         SET @c_line04 = N''
         SET @c_Style04 = N''
         SET @c_Scolor04 = N''
         SET @c_SSize04 = N''
         SET @c_SMEASM04 = N''
         SET @n_qty04 = 0
         SET @c_line05 = N''
         SET @c_Style05 = N''
         SET @c_Scolor05 = N''
         SET @c_SSize05 = N''
         SET @c_SMEASM05 = N''
         SET @n_qty05 = 0
         SET @c_line06 = N''
         SET @c_Style06 = N''
         SET @c_Scolor06 = N''
         SET @c_SSize06 = N''
         SET @c_SMEASM06 = N''
         SET @n_qty06 = 0
         SET @c_line07 = N''
         SET @c_Style07 = N''
         SET @c_Scolor07 = N''
         SET @c_SSize07 = N''
         SET @c_SMEASM07 = N''
         SET @n_qty07 = 0
         SET @n_TTLCNT = 0
         SET @c_PDCartonNo = N''


         SELECT @n_CntRec = COUNT(1)
         FROM [#TEMPSKUContent]
         WHERE Pickslipno = @c_getPickslipno AND Retrieve = 'N'

         SET @n_TTLpage = FLOOR(@n_CntRec / @n_MaxLine)

         IF @b_debug = '1'
         BEGIN
            SELECT *
            FROM #TEMPSKUContent WITH (NOLOCK)
            WHERE Retrieve = 'N'
            SELECT @n_CntRec '@n_CntRec'
                 , @n_TTLpage '@n_TTLpage'
         END


         WHILE @n_intFlag <= @n_CntRec
         BEGIN


            SELECT @c_Style = c.Style
                 , @c_Scolor = c.SColor
                 , @c_Ssize = c.SSize
                 , @c_SMEASM = c.SMeasurement
                 , @n_qty = c.skuqty
                 , @n_TTLCNT = c.ttlctn
                 , @c_PDCartonNo = c.cartonno
            FROM #TEMPSKUContent c WITH (NOLOCK)
            WHERE ID = @n_intFlag


            IF (@n_intFlag % @n_MaxLine) = 1
            BEGIN
               SET @c_Style01 = @c_Style
               SET @c_Scolor01 = @c_Scolor
               SET @c_SSize01 = @c_Ssize
               SET @c_SMEASM01 = @c_SMEASM
               SET @n_qty01 = @n_qty
            END
            ELSE IF (@n_intFlag % @n_MaxLine) = 2
            BEGIN
               SET @c_Style02 = @c_Style
               SET @c_Scolor02 = @c_Scolor
               SET @c_SSize02 = @c_Ssize
               SET @c_SMEASM02 = @c_SMEASM
               SET @n_qty02 = @n_qty
            END
            ELSE IF (@n_intFlag % @n_MaxLine) = 3
            BEGIN
               SET @c_Style03 = @c_Style
               SET @c_Scolor03 = @c_Scolor
               SET @c_SSize03 = @c_Ssize
               SET @c_SMEASM03 = @c_SMEASM
               SET @n_qty03 = @n_qty
            END
            ELSE IF (@n_intFlag % @n_MaxLine) = 4
            BEGIN
               SET @c_Style04 = @c_Style
               SET @c_Scolor04 = @c_Scolor
               SET @c_SSize04 = @c_Ssize
               SET @c_SMEASM04 = @c_SMEASM
               SET @n_qty04 = @n_qty
            END
            ELSE IF (@n_intFlag % @n_MaxLine) = 5
            BEGIN
               SET @c_Style05 = @c_Style
               SET @c_Scolor05 = @c_Scolor
               SET @c_SSize05 = @c_Ssize
               SET @c_SMEASM05 = @c_SMEASM
               SET @n_qty05 = @n_qty
            END
            ELSE IF (@n_intFlag % @n_MaxLine) = 6
            BEGIN
               SET @c_Style06 = @c_Style
               SET @c_Scolor06 = @c_Scolor
               SET @c_SSize06 = @c_Ssize
               SET @c_SMEASM06 = @c_SMEASM
               SET @n_qty06 = @n_qty
            END
            ELSE IF (@n_intFlag % @n_MaxLine) = 0
            BEGIN
               SET @c_Style07 = @c_Style
               SET @c_Scolor07 = @c_Scolor
               SET @c_SSize07 = @c_Ssize
               SET @c_SMEASM07 = @c_SMEASM
               SET @n_qty07 = @n_qty
            END

            SET @n_ttlPqty = (@n_qty01 + @n_qty02 + @n_qty03 + @n_qty04 + @n_qty05 + @n_qty06 + @n_qty07)

            IF (@n_RecCnt = @n_MaxLine) OR (@n_intFlag = @n_CntRec)
            BEGIN

               UPDATE #Result
               SET Col12 = @c_Style01
                 , Col13 = @c_Scolor01
                 , Col14 = @c_SSize01
                 , Col15 = @c_SMEASM01
                 , Col16 = CASE WHEN @n_qty01 > 0 THEN CONVERT(NVARCHAR(5), @n_qty01)
                                ELSE '' END
                 , Col17 = @c_PDCartonNo
                 , Col18 = CASE WHEN @n_TTLCNT > 0 THEN CONVERT(NVARCHAR(10), @n_TTLCNT)
                                ELSE '' END
                 , Col19 = @c_Style02
                 , Col20 = @c_Scolor02
                 , Col21 = @c_SSize02
                 , Col22 = @c_SMEASM02
                 , Col23 = CASE WHEN @n_qty02 > 0 THEN CONVERT(NVARCHAR(5), @n_qty02)
                                ELSE '' END
                 , Col24 = @c_Style03
                 , Col25 = @c_Scolor03
                 , Col26 = @c_SSize03
                 , Col27 = @c_SMEASM03
                 , Col28 = CASE WHEN @n_qty03 > 0 THEN CONVERT(NVARCHAR(5), @n_qty03)
                                ELSE '' END
                 , Col29 = @c_Style04
                 , Col30 = @c_Scolor04
                 , Col31 = @c_SSize04
                 , Col32 = @c_SMEASM04
                 , Col33 = CASE WHEN @n_qty04 > 0 THEN CONVERT(NVARCHAR(5), @n_qty04)
                                ELSE '' END
                 , Col34 = @c_Style05
                 , Col35 = @c_Scolor05
                 , Col36 = @c_SSize05
                 , Col37 = @c_SMEASM05
                 , Col38 = CASE WHEN @n_qty05 > 0 THEN CONVERT(NVARCHAR(5), @n_qty05)
                                ELSE '' END
                 , Col39 = @c_Style06
                 , Col40 = @c_Scolor06
                 , Col41 = @c_SSize06
                 , Col42 = @c_SMEASM06
                 , Col43 = CASE WHEN @n_qty06 > 0 THEN CONVERT(NVARCHAR(5), @n_qty06)
                                ELSE '' END
                 , Col44 = @c_Style07
                 , Col45 = @c_Scolor07
                 , Col46 = @c_SSize07
                 , Col47 = @c_SMEASM07
                 , Col48 = CASE WHEN @n_qty07 > 0 THEN CONVERT(NVARCHAR(5), @n_qty07)
                                ELSE '' END
                 , Col50 = @c_Notes
               WHERE Col59 = @c_getPickslipno AND Col06 = @c_getlabelno AND ID = @n_CurrentPage

               SET @n_RecCnt = 0

            END

            IF @n_RecCnt = 0 AND (@n_intFlag < @n_CntRec) --@n_RecCnt = 0 AND (@n_intFlag<@n_CntRec)--(@n_intFlag%@n_MaxLine) = 0 AND (@n_intFlag>@n_MaxLine)
            BEGIN

               SET @n_CurrentPage = @n_CurrentPage + 1

               INSERT INTO #Result (Col01, Col02, Col03, Col04, Col05, Col06, Col07, Col08, Col09, Col10, Col11, Col12
                                  , Col13, Col14, Col15, Col16, Col17, Col18, Col19, Col20, Col21, Col22, Col23, Col24
                                  , Col25, Col26, Col27, Col28, Col29, Col30, Col31, Col32, Col33, Col34, Col35, Col36
                                  , Col37, Col38, Col39, Col40, Col41, Col42, Col43, Col44, Col45, Col46, Col47, Col48
                                  , Col49, Col50, Col51, Col52, Col53, Col54, Col55, Col56, Col57, Col58, Col59, Col60)
               SELECT TOP 1 Col01
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
                          , ''
                          , ''
                          , ''
                          , ''
                          , ''
                          , Col17
                          , Col18
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
                          , Col49
                          , Col50
                          , ''
                          , ''
                          , ''
                          , ''
                          , ''
                          , ''
                          , ''
                          , ''
                          , Col59
                          , ''
               FROM #Result
               WHERE Col60 = 'O' AND Col59 = @c_getPickslipno AND Col06 = @c_getlabelno

               SET @c_line01 = N''
               SET @c_Style01 = N''
               SET @c_Scolor01 = N''
               SET @c_SSize01 = N''
               SET @c_SMEASM01 = N''
               SET @n_qty01 = 0
               SET @c_line02 = N''
               SET @c_Style02 = N''
               SET @c_Scolor02 = N''
               SET @c_SSize02 = N''
               SET @c_SMEASM02 = N''
               SET @n_qty02 = 0
               SET @c_line03 = N''
               SET @c_Style03 = N''
               SET @c_Scolor03 = N''
               SET @c_SSize03 = N''
               SET @c_SMEASM03 = N''
               SET @n_qty03 = 0
               SET @c_line04 = N''
               SET @c_Style04 = N''
               SET @c_Scolor04 = N''
               SET @c_SSize04 = N''
               SET @c_SMEASM04 = N''
               SET @n_qty04 = 0
               SET @c_line05 = N''
               SET @c_Style05 = N''
               SET @c_Scolor05 = N''
               SET @c_SSize05 = N''
               SET @c_SMEASM05 = N''
               SET @n_qty05 = 0
               SET @c_line06 = N''
               SET @c_Style06 = N''
               SET @c_Scolor06 = N''
               SET @c_SSize06 = N''
               SET @c_SMEASM06 = N''
               SET @n_qty06 = 0
               SET @c_line07 = N''
               SET @c_Style07 = N''
               SET @c_Scolor07 = N''
               SET @c_SSize07 = N''
               SET @c_SMEASM07 = N''
               SET @n_qty07 = 0

            END

            SET @n_intFlag = @n_intFlag + 1
            SET @n_RecCnt = @n_RecCnt + 1
         END

         FETCH NEXT FROM CUR_RowNoLoop
         INTO @c_getPickslipno
            , @c_getlabelno

      END -- While                     
      CLOSE CUR_RowNoLoop
      DEALLOCATE CUR_RowNoLoop

      FETCH NEXT FROM CUR_StartRecLoop
      INTO @c_StateCity
         , @c_ExtOrdkey
         , @c_OHCompany
         , @c_billtokey
         , @c_consigneekey
         , @c_labelno
         , @c_czip
         , @c_OHAddress1
         , @c_OHAddress2
         , @c_OHAddress3
         , @c_OHAddress4
         , @n_ttlqty
         , @c_Pickslipno
         , @c_Notes

   END -- While                     
   CLOSE CUR_StartRecLoop
   DEALLOCATE CUR_StartRecLoop

   SELECT *
   FROM #Result WITH (NOLOCK)

   EXIT_SP:

   SET @d_Trace_EndTime = GETDATE()
   SET @c_UserName = SUSER_SNAME()

   EXEC isp_InsertTraceInfo @c_TraceCode = 'BARTENDER'
                          , @c_TraceName = 'isp_Bartender_Shipper_Label_KR_02'
                          , @c_starttime = @d_Trace_StartTime
                          , @c_endtime = @d_Trace_EndTime
                          , @c_step1 = @c_UserName
                          , @c_step2 = ''
                          , @c_step3 = ''
                          , @c_step4 = ''
                          , @c_step5 = ''
                          , @c_col1 = @c_Sparm1
                          , @c_col2 = @c_Sparm2
                          , @c_col3 = @c_Sparm3
                          , @c_col4 = @c_Sparm4
                          , @c_col5 = @c_Sparm5
                          , @b_Success = 1
                          , @n_Err = 0
                          , @c_ErrMsg = ''


END -- procedure   

GO