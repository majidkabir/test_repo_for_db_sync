SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Copyright: LFL                                                             */
/* Purpose: BarTender Filter by ShipperKey                                    */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2021-06-04 1.0  WLChooi    Created (WMS-17199)                             */
/******************************************************************************/

CREATE PROC [dbo].[isp_BT_Bartender_KR_Shipper_Content_Label_ECCO]
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

   DECLARE
      @c_OrderKey        NVARCHAR(10),
      @c_ExternOrdKey    NVARCHAR(30),
      @c_ExternPOKey     NVARCHAR(20),
      @c_GetOrderKey     NVARCHAR(10),
      @c_GetExternOrdKey NVARCHAR(30),
      @c_GetExternPOKey  NVARCHAR(20),
      @c_OrdType         NVARCHAR(10),
      @c_GetOrdType      NVARCHAR(10),
      @c_LabelNo         NVARCHAR(20),
      @c_GetLabelNo      NVARCHAR(20),
      @c_Col10           NVARCHAR(30),
      @c_Col11           NVARCHAR(30)

   DECLARE
      @n_intFlag         INT,
      @n_CntRec          INT,
      @c_colNo           NVARCHAR(5),
      @n_cntsku          INT,
      @c_skuMeasurement  NVARCHAR(5),
      @c_BuyerPO         NVARCHAR(20),
      @c_GetBuyerPO      NVARCHAR(20),
      @c_notes2          NVARCHAR(4000),
      @c_OrderLineNo     NVARCHAR(5),
      @c_SKU             NVARCHAR(20),
      @n_Qty             INT,
      @c_PackKey         NVARCHAR(10),
      @c_UOM             NVARCHAR(10),
      @c_PHeaderKey      NVARCHAR(18),
      @c_SODestination   NVARCHAR(30),
      @n_RowNo           INT,
      @n_SumPickDETQTY   INT,
      @n_SumPackDETQTY   INT,
      @n_SumUnitPrice    INT,
      @c_SQL             NVARCHAR(4000),
      @c_SQLSORT         NVARCHAR(4000),
      @c_SQLJOIN         NVARCHAR(4000),
      @c_Udef04          NVARCHAR(80),
      @n_TTLPickQTY      INT,
      @c_ShipperKey      NVARCHAR(15),
      @n_MaxLine         INT,
      @n_TTLpage         INT,
      @n_CurrentPage     INT,
      @c_dropid          NVARCHAR(20),
      @n_ID              INT,
      @n_TTLLine         INT,
      @n_TTLQty          INT,
      @c_OrdUdef03       NCHAR(2),
      @c_itemclass       NCHAR(4),
      @c_skuGrp          NCHAR(5),
      @c_SkuStyle        NCHAR(5),
      @n_cntOrdUDef04    INT,
      @c_getOrdUdef04    NVARCHAR(80),
      @c_notes           NVARCHAR(20)

 DECLARE
      @c_colORDDETSKU1     NVARCHAR(60),
      @c_ColSDESCR1        NVARCHAR(60),
      @c_ColPDQty1         NVARCHAR(5),
      @c_colORDDETSKU2     NVARCHAR(60),
      @c_ColSDESCR2        NVARCHAR(60),
      @c_ColPDQty2         NVARCHAR(5),
      @c_colORDDETSKU3     NVARCHAR(60),
      @c_ColSDESCR3        NVARCHAR(60),
      @c_ColPDQty3         NVARCHAR(5),
      @c_colORDDETSKU4     NVARCHAR(60),
      @c_ColSDESCR4        NVARCHAR(60),
      @c_ColPDQty4         NVARCHAR(5),
      @c_colORDDETSKU5     NVARCHAR(60),
      @c_ColSDESCR5        NVARCHAR(60),
      @c_ColPDQty5         NVARCHAR(5),
      @c_colORDDETSKU6     NVARCHAR(60),
      @c_ColSDESCR6        NVARCHAR(60),
      @c_ColPDQty6         NVARCHAR(5),
      @c_colORDDETSKU7     NVARCHAR(60),
      @c_ColSDESCR7        NVARCHAR(60),
      @c_ColPDQty7         NVARCHAR(5),
      @c_colORDDETSKU8     NVARCHAR(60),
      @c_ColSDESCR8        NVARCHAR(60),
      @c_ColPDQty8         NVARCHAR(5)

DECLARE
      @c_colORDDETSKU9      NVARCHAR(60),
      @c_ColSDESCR9         NVARCHAR(60),
      @c_ColPDQty9          NVARCHAR(5),
      @c_colORDDETSKU10     NVARCHAR(60),
      @c_ColSDESCR10        NVARCHAR(60),
      @c_ColPDQty10         NVARCHAR(5),
      @c_colORDDETSKU11     NVARCHAR(60),
      @c_ColSDESCR11        NVARCHAR(60),
      @c_ColPDQty11         NVARCHAR(5),
      @c_colORDDETSKU12     NVARCHAR(60),
      @c_ColSDESCR12        NVARCHAR(60),
      @c_ColPDQty12         NVARCHAR(5),
      @c_colORDDETSKU13     NVARCHAR(60),
      @c_ColSDESCR13        NVARCHAR(60),
      @c_ColPDQty13         NVARCHAR(5),
      @c_colORDDETSKU14     NVARCHAR(60),
      @c_ColSDESCR14        NVARCHAR(60),
      @c_ColPDQty14         NVARCHAR(5),
      @c_colORDDETSKU15     NVARCHAR(60),
      @c_ColSDESCR15        NVARCHAR(60),
      @c_ColPDQty15         NVARCHAR(5),
      @c_colORDDETSKU16     NVARCHAR(60),
      @c_ColSDESCR16        NVARCHAR(60),
      @c_ColPDQty16         NVARCHAR(5),

      @c_ColContentsku      NVARCHAR(20),
      @c_ColContentDescr    NVARCHAR(60),
      @c_ColContentqty      NVARCHAR(5),
      @c_CartonType         NVARCHAR(10),
      @c_GETCartonType      NVARCHAR(10),
      @c_CartonNo           NVARCHAR(10),
      @c_CContact1          NVARCHAR(100)

   DECLARE @d_Trace_StartTime   DATETIME,
           @d_Trace_EndTime     DATETIME,
           @c_Trace_ModuleName  NVARCHAR(20),
           @d_Trace_Step1       DATETIME,
           @c_Trace_Step1       NVARCHAR(20),
           @c_UserName          NVARCHAR(20)

   SET @d_Trace_StartTime = GETDATE()
   SET @c_Trace_ModuleName = ''

   SET @c_SQL = ''
   SET @n_SumPickDETQTY = 0
   SET @n_SumPackDETQTY = 0
   SET @n_SumUnitPrice = 0
   SET @c_col10        = ''
   SET @c_Col11        = ''

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

   CREATE TABLE [#CartonContent] (
      [ID]          [INT] IDENTITY(1,1) NOT NULL,
      [OrderKey]    [NVARCHAR] (10) NULL,
      [ORDSku]      [NCHAR] (20)    NULL,
      [SDESCR]      [NVARCHAR](60)  NULL,
      [TTLPICKQTY]  [INT]           NULL,
      [Retrieve]    [NVARCHAR] (1) DEFAULT 'N')

   IF @b_debug = 1
   BEGIN
      PRINT 'start'
   END

   DECLARE CUR_StartRecLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT ORD.ExternOrderKey AS ORD_ExternOrdKey,ORD.ExternPOKey AS ORD_EXTPOKey,
          ORD.BuyerPO AS ORD_BuyerPO,ORD.OrderKey AS ORD_ORDKey,ORD.Type AS ORD_Type,
          PIF.CartonType,PDET.LabelNo,CONVERT(NVARCHAR(10),PDET.CartonNo),ORD.Notes,
          ORD.C_contact1              
   FROM ORDERS ORD WITH (NOLOCK)
   INNER JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.OrderKey = ORD.OrderKey
   JOIN PACKHEADER PH WITH (NOLOCK) ON PH.OrderKey = ORD.OrderKey
   JOIN PACKDETAIL PDET WITH (NOLOCK) ON PDET.PickSlipNo = PH.PickSlipNo
   LEFT JOIN PACKINFO PIF WITH (NOLOCK) ON PIF.PickSlipNo = PDET.PickSlipNo
   AND PIF.CartonNo = PDET.CartonNo
   WHERE PDET.PickSlipNo = @c_Sparm1
   AND PDET.CartonNo >= CONVERT(INT,@c_Sparm2)
   AND PDET.CartonNo <= CONVERT(INT,@c_Sparm3)
   GROUP BY ORD.ExternOrderKey ,ORD.ExternPOKey,
            ORD.BuyerPO ,ORD.OrderKey ,ORD.Type,
            PIF.CartonType,PDET.LabelNo,CONVERT(NVARCHAR(10),PDET.CartonNo),ORD.Notes,
            ORD.C_contact1

   OPEN CUR_StartRecLoop
   FETCH NEXT FROM CUR_StartRecLoop INTO @c_ExternORDKey,@c_ExternPOKey,@c_BuyerPO,@c_OrderKey,@c_OrdType,@c_CartonType,@c_LabelNo,@c_CartonNo,@c_Notes,@c_CContact1
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF @b_debug = 1
      BEGIN
         PRINT 'Cur start'
      END

      INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05,Col06,Col07,Col08,Col09
                           ,Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22
                           ,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34
                           ,Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44
                           ,Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54
                           ,Col55,Col56,Col57,Col58,Col59,Col60)
      VALUES(@c_ExternORDKey,@c_ExternPOKey,@c_BuyerPO,@c_OrderKey,@c_OrdType,@c_CartonType,
            '1',@c_LabelNo,'','','','','','','','','','','','',
            '','','','','','','','','','','','','','','','','','','','','','','','',@c_CartonNo,@c_Notes,'','','',''
            ,'','','','','','','','','',@c_CContact1)

      IF @b_debug = 1
      BEGIN
         SELECT * FROM #Result (NOLOCK)
      END

      SET @n_MaxLine     = 15
      SET @n_TTLpage     = 1
      SET @n_CurrentPage = 1
      SET @n_intFlag     = 1
      SET @n_TTLLIne     = 0
      SET @n_TTLQty      = 0

      DECLARE CUR_RowNoLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT Col01,Col02,Col03,Col04,Col05,Col06,Col08
      FROM #Result

      OPEN CUR_RowNoLoop
      FETCH NEXT FROM CUR_RowNoLoop INTO @c_GetExternORDKey,@c_GetExternPOKey,@c_GetBuyerPO,@c_GetOrderKey,
                                         @c_GetOrdType,@c_GetCartonType,@c_GetLabelNo
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SELECT TOP 1 @n_cntsku = COUNT(DISTINCT PD.SKU),
                      @n_SumPackDETQTY = SUM(PD.Qty)
         FROM ORDERDETAIL OD WITH (NOLOCK)
         JOIN PACKHEADER PH WITH (NOLOCK) ON PH.OrderKey = OD.OrderKey
         JOIN PackDetail PD WITH (NOLOCK) ON PD.PickSlipNo =PH.PickSlipNo
         AND PD.Storerkey=OD.Storerkey AND PD.SKU = OD.SKU
         JOIN SKU S WITH (NOLOCK) ON S.SKU = OD.SKU
         AND S.StorerKey = OD.StorerKey
         WHERE OD.OrderKey = @c_GetOrderKey
         AND PD.CartonNo >= CONVERT(INT,@c_Sparm2)
         AND PD.CartonNo <= CONVERT(INT,@c_Sparm3)

         IF @n_cntsku > 1
         BEGIN
            SET @c_col10 = 'MULTI'
            SET @c_Col11 = 'MULTI'
         END
         ELSE
         BEGIN
            SELECT TOP 1 @c_col10 = PD.SKU,
                         @c_Col11 = S.Descr
            FROM ORDERDETAIL OD WITH (NOLOCK)
            JOIN PACKHEADER PH WITH (NOLOCK) ON PH.OrderKey = OD.OrderKey
            JOIN PackDetail PD WITH (NOLOCK) ON PD.PickSlipNo =PH.PickSlipNo
            AND PD.Storerkey=OD.Storerkey AND PD.SKU = OD.SKU
            JOIN SKU S WITH (NOLOCK) ON S.SKU = OD.SKU
            AND S.StorerKey = OD.StorerKey
            WHERE OD.OrderKey = @c_GetOrderKey
            AND PD.CartonNo >= CONVERT(INT,@c_Sparm2)
            AND PD.CartonNo <= CONVERT(INT,@c_Sparm3)
         END

         DELETE #CartonContent
         INSERT INTO #CartonContent (OrderKey,ORDSku,SDESCR,TTLPICKQTY)

         SELECT OD.OrderKey
               ,OD.SKU
               ,S.Descr
               ,SUM(PD.Qty)
         FROM PackHeader PH WITH (NOLOCK)
         JOIN PackDetail PD WITH (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo
         JOIN Orders OH WITH (NOLOCK) ON (PH.OrderKey = OH.OrderKey)
         JOIN (SELECT DISTINCT OD1.OrderKey, OD1.StorerKey, OD1.Sku FROM OrderDetail OD1 WITH (NOLOCK)
         JOIN PackHeader PH1 WITH (NOLOCK) ON (OD1.StorerKey = PH1.StorerKey AND OD1.OrderKey = PH1.OrderKey)
         JOIN PackDetail PD1 WITH (NOLOCK) ON (PH1.PickSlipNo = PD1.PickSlipNo)
         WHERE PH1.OrderKey = @c_GetOrderKey)
         AS OD ON (OH.OrderKey = OD.OrderKey AND PD.StorerKey = OD.StorerKey AND PD.SKU = OD.SKU)
         JOIN SKU S WITH (NOLOCK)  ON  S.SKU = OD.SKU AND S.StorerKey = OD.Storerkey
         WHERE OH.OrderKey = @c_GetOrderKey
         AND PD.CartonNo >= CONVERT(INT,@c_Sparm2)
         AND PD.CartonNo <= CONVERT(INT,@c_Sparm3)
         GROUP BY OD.OrderKey
                 ,OD.sku
                 ,S.Descr

         IF @b_debug = '1'
         BEGIN
            SELECT 'carton',* FROM #CartonContent
         END

         SET @c_colno = ''

         SET @c_colORDDETSKU1      =''
         SET @c_ColSDESCR1         =''
         SET @c_ColPDQty1          =''
         SET @c_colORDDETSKU2      =''
         SET @c_ColSDESCR2         =''
         SET @c_ColPDQty2          =''
         SET @c_colORDDETSKU3      =''
         SET @c_ColSDESCR3         =''
         SET @c_ColPDQty3          =''
         SET @c_colORDDETSKU4      =''
         SET @c_ColSDESCR4         =''
         SET @c_ColPDQty4          =''
         SET @c_colORDDETSKU5      =''
         SET @c_ColSDESCR5         =''
         SET @c_ColPDQty5          =''
         SET @c_colORDDETSKU6      =''
         SET @c_ColSDESCR6         =''
         SET @c_ColPDQty6          =''
         SET @c_colORDDETSKU7      =''
         SET @c_ColSDESCR7         =''
         SET @c_ColPDQty7          =''
         SET @c_colORDDETSKU8      =''
         SET @c_ColSDESCR8         =''
         SET @c_ColPDQty8          =''
         SET @c_colORDDETSKU9      =''
         SET @c_ColSDESCR9         =''
         SET @c_ColPDQty9          =''
         SET @c_colORDDETSKU10     =''
         SET @c_ColSDESCR10        =''
         SET @c_ColPDQty10         =''
         SET @c_colORDDETSKU11     =''
         SET @c_ColSDESCR11        =''
         SET @c_ColPDQty11         =''
         SET @c_colORDDETSKU12     =''
         SET @c_ColSDESCR12        =''
         SET @c_ColPDQty12         =''
         SET @c_colORDDETSKU13     =''
         SET @c_ColSDESCR13        =''
         SET @c_ColPDQty13         =''
         SET @c_colORDDETSKU14     =''
         SET @c_ColSDESCR14        =''
         SET @c_ColPDQty14         =''
         SET @c_colORDDETSKU15     =''
         SET @c_ColSDESCR15        =''
         SET @c_ColPDQty15         =''
         SET @c_colORDDETSKU16     =''
         SET @c_ColSDESCR16        =''
         SET @c_ColPDQty16         =''

         SELECT @n_CntRec = COUNT(1)
         FROM #CartonContent
         WHERE Retrieve = 'N'

         SET @n_TTLpage =  FLOOR(@n_CntRec / @n_MaxLine ) + CASE WHEN @n_CntRec % @n_MaxLine > 0 THEN 1 ELSE 0 END

         IF @b_debug = '1'
         BEGIN
            PRINT ' Rec COUNT : ' + CONVERT(NVARCHAR(15),@n_CntRec)
            PRINT ' TTL Page NO : ' + CONVERT(NVARCHAR(15),@n_TTLpage)
            PRINT ' Current Page NO : ' + CONVERT(NVARCHAR(15),@n_CurrentPage)
            PRINT '@n_intFlag : ' + + CONVERT(NVARCHAR(15),@n_intFlag)
            PRINT '@n_intFlag%Maxline : ' + + CONVERT(NVARCHAR(15),(@n_intFlag % @n_MaxLine))
         END

         WHILE (@n_intFlag <=@n_CntRec)
         BEGIN
            IF @b_debug = '1'
            BEGIN
               SELECT * FROM  #CartonContent  WITH (NOLOCK)
               PRINT ' update for column no : ' + @c_Colno + 'with ID ' + CONVERT(NVARCHAR(2),@n_intFlag)
            END

            IF @n_intFlag > @n_MaxLine AND (@n_intFlag % @n_MaxLine) = 1
            BEGIN
               SET @n_CurrentPage = @n_CurrentPage + 1

               IF @b_debug = '1'
               BEGIN
                  PRINT 'Start page : ' + CONVERT(NVARCHAR(5),@n_CurrentPage)
                  PRINT 'Total page : ' + CONVERT(NVARCHAR(5),@n_TTLpage)
               END

               IF (@n_CurrentPage>@n_TTLpage)
               BREAK;

               INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09
                                    ,Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22
                                    ,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34
                                    ,Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44
                                    ,Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54
                                    ,Col55,Col56,Col57,Col58,Col59,Col60)
               VALUES(@c_ExternORDKey,@c_ExternPOKey,@c_BuyerPO,@c_OrderKey,@c_OrdType,@c_CartonType,
                     '1',@c_LabelNo,'','','','','','','','','','','','',
                     '','','','','','','','','','','','','','','','','','','','','','','','',@c_CartonNo,@c_Notes,'','','',''
                     ,'','','','','','','','','',@c_CContact1)

               IF @b_debug = '1'
               BEGIN
                  SELECT '1111',CONVERT(NVARCHAR(5),@n_CurrentPage) AS CurrentPage,* from #Result
               END

               SET @c_colORDDETSKU1      =''
               SET @c_ColSDESCR1         =''
               SET @c_ColPDQty1          =''
               SET @c_colORDDETSKU2      =''
               SET @c_ColSDESCR2         =''
               SET @c_ColPDQty2          =''
               SET @c_colORDDETSKU3      =''
               SET @c_ColSDESCR3         =''
               SET @c_ColPDQty3          =''
               SET @c_colORDDETSKU4      =''
               SET @c_ColSDESCR4         =''
               SET @c_ColPDQty4          =''
               SET @c_colORDDETSKU5      =''
               SET @c_ColSDESCR5         =''
               SET @c_ColPDQty5          =''
               SET @c_colORDDETSKU6      =''
               SET @c_ColSDESCR6         =''
               SET @c_ColPDQty6          =''
               SET @c_colORDDETSKU7      =''
               SET @c_ColSDESCR7         =''
               SET @c_ColPDQty7          =''
               SET @c_colORDDETSKU8      =''
               SET @c_ColSDESCR8         =''
               SET @c_ColPDQty8          =''
               SET @c_colORDDETSKU9      =''
               SET @c_ColSDESCR9         =''
               SET @c_ColPDQty9          =''
               SET @c_colORDDETSKU10     =''
               SET @c_ColSDESCR10        =''
               SET @c_ColPDQty10         =''
               SET @c_colORDDETSKU11     =''
               SET @c_ColSDESCR11        =''
               SET @c_ColPDQty11         =''
               SET @c_colORDDETSKU12     =''
               SET @c_ColSDESCR12        =''
               SET @c_ColPDQty12         =''
               SET @c_colORDDETSKU13     =''
               SET @c_ColSDESCR13        =''
               SET @c_ColPDQty13         =''
               SET @c_colORDDETSKU14     =''
               SET @c_ColSDESCR14        =''
               SET @c_ColPDQty14         =''
               SET @c_colORDDETSKU15     =''
               SET @c_ColSDESCR15        =''
               SET @c_ColPDQty15         =''
            END

            SET @n_TTLLine = 0
            SET @n_Qty = 0

            IF @b_debug = '1'
            BEGIN
               PRINT 'get record no : ' + CONVERT(NCHAR(5),@n_intFlag)
            END

            SELECT @c_ColContentsku   = ORDSku,
                   @c_Colcontentdescr = SDESCR,
                   @c_ColContentqty   = CONVERT(NCHAR(5),TTLPICKQTY)
            FROM  #CartonContent c WITH (NOLOCK)
            WHERE c.ID = @n_intFlag
            AND Retrieve = 'N'

            IF @b_debug= '1'
            BEGIN
               PRINT '(@n_intFlag % @n_MaxLine) : '+ CONVERT(NCHAR(10),(@n_intFlag % @n_MaxLine))
            END

            IF (@n_intFlag % @n_MaxLine) = 1
            BEGIN
               SET @c_colORDDETSKU1  = @c_ColContentsku
               SET @c_ColSDESCR1     = @c_Colcontentdescr
               SET @c_ColPDQty1      = @c_ColContentqty
            END
            ELSE IF (@n_intFlag % @n_MaxLine) = 2
            BEGIN
               SET @c_colORDDETSKU2  = @c_ColContentsku
               SET @c_ColSDESCR2     = @c_Colcontentdescr
               SET @c_ColPDQty2      = @c_ColContentqty
            END
            ELSE IF (@n_intFlag % @n_MaxLine) = 3
            BEGIN
               SET @c_colORDDETSKU3  = @c_ColContentsku
               SET @c_ColSDESCR3     = @c_Colcontentdescr
               SET @c_ColPDQty3      = @c_ColContentqty
            END
            ELSE IF (@n_intFlag % @n_MaxLine) = 4
            BEGIN
               SET @c_colORDDETSKU4  = @c_ColContentsku
               SET @c_ColSDESCR4     = @c_Colcontentdescr
               SET @c_ColPDQty4      = @c_ColContentqty
            END
            ELSE IF (@n_intFlag % @n_MaxLine) = 5
            BEGIN
               SET @c_colORDDETSKU5  = @c_ColContentsku
               SET @c_ColSDESCR5     = @c_Colcontentdescr
               SET @c_ColPDQty5      = @c_ColContentqty
            END
            ELSE IF (@n_intFlag % @n_MaxLine) = 6
            BEGIN
               SET @c_colORDDETSKU6  = @c_ColContentsku
               SET @c_ColSDESCR6     = @c_Colcontentdescr
               SET @c_ColPDQty6      = @c_ColContentqty
            END
            ELSE IF (@n_intFlag % @n_MaxLine) = 7
            BEGIN
               SET @c_colORDDETSKU7  = @c_ColContentsku
               SET @c_ColSDESCR7     = @c_Colcontentdescr
               SET @c_ColPDQty7      = @c_ColContentqty
            END
            ELSE IF (@n_intFlag % @n_MaxLine) = 8
            BEGIN
               SET @c_colORDDETSKU8  = @c_ColContentsku
               SET @c_ColSDESCR8     = @c_Colcontentdescr
               SET @c_ColPDQty8      = @c_ColContentqty
            END
            ELSE IF (@n_intFlag % @n_MaxLine) = 9
            BEGIN
               SET @c_colORDDETSKU9  = @c_ColContentsku
               SET @c_ColSDESCR9     = @c_Colcontentdescr
               SET @c_ColPDQty9      = @c_ColContentqty
            END
            ELSE IF (@n_intFlag % @n_MaxLine) = 10
            BEGIN
               SET @c_colORDDETSKU10  = @c_ColContentsku
               SET @c_ColSDESCR10     = @c_Colcontentdescr
               SET @c_ColPDQty10      = @c_ColContentqty
            END
            ELSE IF (@n_intFlag % @n_MaxLine) = 11
            BEGIN
               SET @c_colORDDETSKU11  = @c_ColContentsku
               SET @c_ColSDESCR11     = @c_Colcontentdescr
               SET @c_ColPDQty11      = @c_ColContentqty
            END
            ELSE IF (@n_intFlag % @n_MaxLine) = 12
            BEGIN
               SET @c_colORDDETSKU12  = @c_ColContentsku
               SET @c_ColSDESCR12     = @c_Colcontentdescr
               SET @c_ColPDQty12      = @c_ColContentqty
            END
            ELSE IF (@n_intFlag % @n_MaxLine) = 13
            BEGIN
               SET @c_colORDDETSKU13  = @c_ColContentsku
               SET @c_ColSDESCR13     = @c_Colcontentdescr
               SET @c_ColPDQty13      = @c_ColContentqty
            END
            ELSE IF (@n_intFlag % @n_MaxLine) = 14
            BEGIN
               SET @c_colORDDETSKU14  = @c_ColContentsku
               SET @c_ColSDESCR14     = @c_Colcontentdescr
               SET @c_ColPDQty14     = @c_ColContentqty
            END
            ELSE IF (@n_intFlag % @n_MaxLine) = 0
            BEGIN
               SET @c_colORDDETSKU15  = @c_ColContentsku
               SET @c_ColSDESCR15     = @c_Colcontentdescr
               SET @c_ColPDQty15     = @c_ColContentqty
            END

            SET @n_TTLQty = 0

            SELECT @n_TTLQty = SUM(TTLPICKQTY)
            FROM  #CartonContent c WITH (NOLOCK)

            UPDATE #Result
            SET Col09 = CONVERT(NVARCHAR(10),@n_TTLQty),
                Col10 = @c_col10,
                Col11 = @c_Col11,
                Col12 = @c_colORDDETSKU1,
                Col13 = @c_ColSDESCR1,
                Col14 = @c_ColPDQty1,
                Col15 = @c_colORDDETSKU2,
                Col16 = @c_ColSDESCR2,
                Col17 = @c_ColPDQty2,
                Col18 = @c_colORDDETSKU3,
                Col19 = @c_ColSDESCR3,
                Col20 = @c_ColPDQty3,
                Col21 = @c_colORDDETSKU4,
                Col22 = @c_ColSDESCR4,
                Col23 = @c_ColPDQty4,
                Col24 = @c_colORDDETSKU5,
                Col25 = @c_ColSDESCR5,
                Col26 = @c_ColPDQty5,
                Col27 = @c_colORDDETSKU6,
                Col28 = @c_ColSDESCR6,
                Col29 = @c_ColPDQty6,
                Col30 = @c_colORDDETSKU7,
                Col31 = @c_ColSDESCR7,
                Col32 = @c_ColPDQty7,
                Col33 = @c_colORDDETSKU8,
                Col34 = @c_ColSDESCR8,
                Col35 = @c_ColPDQty8,
                Col36 = @c_colORDDETSKU9,
                Col37 = @c_ColSDESCR9,
                Col38 = @c_ColPDQty9,
                Col39 = @c_colORDDETSKU10,
                Col40 = @c_ColSDESCR10,
                Col41 = @c_ColPDQty10,
                Col42 = @c_colORDDETSKU11,
                Col43 = @c_ColSDESCR11,
                Col44 = @c_ColPDQty11,
                Col46 = @c_colORDDETSKU12,
                Col47 = @c_ColSDESCR12,
                Col48 = @c_ColPDQty12,
                Col49 = @c_colORDDETSKU13,
                Col50 = @c_ColSDESCR13,
                Col51 = @c_ColPDQty13,
                Col52 = @c_colORDDETSKU14,
                Col53 = @c_ColSDESCR14,
                Col54 = @c_ColPDQty14,
                Col55 = @c_colORDDETSKU15,
                Col56 = @c_ColSDESCR15,
                Col57 = @c_ColPDQty15,
                Col60 = @c_CContact1
            WHERE ID = @n_CurrentPage

            UPDATE #CartonContent
            SET Retrieve ='Y'
            WHERE ID= @n_intFlag

            SET @n_intFlag = @n_intFlag + 1

            IF @n_intFlag > @n_CntRec
            BEGIN
               BREAK;
            END

            IF @b_debug = '1'
            BEGIN
               SELECT CONVERT(NVARCHAR(3),@n_intFlag),* FROM #Result
            END
         END
      FETCH NEXT FROM CUR_RowNoLoop INTO @c_GetExternORDKey,@c_GetExternPOKey,@c_GetBuyerPO,@c_GetOrderKey,
                                         @c_GetOrdType,@c_GetCartonType,@c_GetLabelNo
      END
      CLOSE CUR_RowNoLoop
      DEALLOCATE CUR_RowNoLoop

      FETCH NEXT FROM CUR_StartRecLoop INTO @c_ExternORDKey,@c_ExternPOKey,@c_BuyerPO,@c_OrderKey,@c_OrdType,@c_CartonType,@c_LabelNo,@c_CartonNo,@c_Notes,@c_CContact1
   END -- While
   CLOSE CUR_StartRecLoop
   DEALLOCATE CUR_StartRecLoop

   SELECT * from #result WITH (NOLOCK)

   EXIT_SP:

   SET @d_Trace_EndTime = GETDATE()
   SET @c_UserName = SUSER_SNAME()

   EXEC isp_InsertTraceInfo
      @c_TraceCode = 'BARTENDER',
      @c_TraceName = 'isp_BT_Bartender_KR_Shipper_Content_Label_ECCO',
      @c_starttime = @d_Trace_StartTime,
      @c_endtime = @d_Trace_EndTime,
      @c_step1 = @c_UserName,
      @c_step2 = '',
      @c_step3 = '',
      @c_step4 = '',
      @c_step5 = '',
      @c_col1 = @c_Sparm1,
      @c_col2 = @c_Sparm2,
      @c_col3 = @c_Sparm3,
      @c_col4 = @c_Sparm4,
      @c_col5 = @c_Sparm5,
      @b_Success = 1,
      @n_Err = 0,
      @c_ErrMsg = ''
END -- procedure

GO