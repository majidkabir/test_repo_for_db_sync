SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  isp_GetPackList10                                  */
/* Creation Date: 02-Jan-2020                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose:  WMS-11657 - [TW]SKX Create new RCM report_Pack Summary     */
/*           (modified from isp_GetPackList10)                          */
/*                                                                      */
/* Usage:  Used for report dw = r_dw_print_packlist_10                  */
/*                                                                      */
/* Called By: Exceed                                                    */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver.  Purposes                                  */
/* 15-Jan-2020  WLChooi 1.1   WMS-11657 - Use INT for Price (WL01)      */
/* 21-Apr-2020  WLChooi 1.2   WMS-12983 - Remove UserDefine02 (WL02)    */
/************************************************************************/

CREATE PROC [dbo].[isp_GetPackList10] (@c_LoadKey NVARCHAR(10))
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_debug int
   SELECT @b_debug = 0

   DECLARE @c_OrderKey        NVARCHAR(10),
           @c_SkuSize         NVARCHAR(5),
           @c_TempOrderKey    NVARCHAR(10),
           @c_PrevOrderKey    NVARCHAR(10),
           @c_Style           NVARCHAR(30),
           @c_Color           NVARCHAR(10),
           @c_PrevStyle       NVARCHAR(30),
           @c_PrevColor       NVARCHAR(10),
           @c_SkuSort         NVARCHAR(3),
           @b_success         int,
           @n_err             int,
           @c_errmsg          NVARCHAR(255),
           @n_Count           int,
           @c_SkuSize1        NVARCHAR(5),
           @c_SkuSize2        NVARCHAR(5),
           @c_SkuSize3        NVARCHAR(5),
           @c_SkuSize4        NVARCHAR(5),
           @c_SkuSize5        NVARCHAR(5),
           @c_SkuSize6        NVARCHAR(5),
           @c_SkuSize7        NVARCHAR(5),
           @c_SkuSize8        NVARCHAR(5),
           @c_SkuSize9        NVARCHAR(5),
           @c_SkuSize10       NVARCHAR(5),
           @c_SkuSize11       NVARCHAR(5),
           @c_SkuSize12       NVARCHAR(5),
           @c_SkuSize13       NVARCHAR(5),
           @c_SkuSize14       NVARCHAR(5),
           @c_SkuSize15       NVARCHAR(5),
           @c_SkuSize16       NVARCHAR(5),
           @c_SkuSize17       NVARCHAR(5),
           @c_SkuSize18       NVARCHAR(5),
           @c_SkuSize19       NVARCHAR(5),
           @c_SkuSize20       NVARCHAR(5),
           @c_SkuSize21       NVARCHAR(5),
           @c_SkuSize22       NVARCHAR(5),
           @c_SkuSize23       NVARCHAR(5),
           @c_SkuSize24       NVARCHAR(5),
           @c_SkuSize25       NVARCHAR(5),
           @c_SkuSize26       NVARCHAR(5),
           @c_SkuSize27       NVARCHAR(5),
           @c_SkuSize28       NVARCHAR(5),
           @c_SkuSize29       NVARCHAR(5),
           @c_SkuSize30       NVARCHAR(5),
           @c_SkuSize31       NVARCHAR(5),
           @c_SkuSize32       NVARCHAR(5)

         , @n_StyleWColor     INT         
         , @n_PrevStyleWColor INT         

         , @c_Division        NVARCHAR(18)
         , @c_Ordertype       NVARCHAR(20)
         , @n_TotalCartons    INT         
         , @c_SizeSort        NVARCHAR(10)
         , @c_GetOrderType    NVARCHAR(20) = '' 


   SET @c_Style      = ''
   SET @c_Color      = ''
   SET @c_PrevStyle  = ''
   SET @c_PrevColor  = ''
   SET @c_SkuSort    = ''

   SET @n_StyleWColor     = 0           
   SET @n_PrevStyleWColor = 0           

   SET @c_SizeSort        = ''          

   CREATE TABLE #TempPickSlip
          (SeqNo              INT   IDENTITY(1,1), 
           PickSlipNo         NVARCHAR(10)   NULL,
           Loadkey            NVARCHAR(10)   NULL,
           OrderKey           NVARCHAR(10)   NULL,
           ExternOrderKey     NVARCHAR(50)   NULL, 
           Notes              NVARCHAR(255)  NULL,
           ConsigneeKey       NVARCHAR(15)   NULL,
           Company            NVARCHAR(45)   NULL,
           c_Address1         NVARCHAR(45)   NULL,
           c_Address2         NVARCHAR(45)   NULL,
           c_Address3         NVARCHAR(45)   NULL,
           c_Address4         NVARCHAR(45)   NULL,
           C_City             NVARCHAR(45)   NULL,
           C_Zip              NVARCHAR(18)   NULL,
           InvoiceNo          NVARCHAR(20)   NULL,
           Stylecolor         NVARCHAR(30)   NULL,
           SkuDescr           NVARCHAR(60)   NULL,
           StorerNotes        NVARCHAR(255)  NULL,
           Qty                INT            NULL,
           UOM                NVARCHAR(10)   NULL,
           CaseCnt            float,
           lpuserdefdate01    datetime       NULL,
           Storerkey          NVARCHAR(15)   NULL,
           SkuSize1           NVARCHAR(5)    NULL,
           SkuSize2           NVARCHAR(5)    NULL,
           SkuSize3           NVARCHAR(5)    NULL,
           SkuSize4           NVARCHAR(5)    NULL,
           SkuSize5           NVARCHAR(5)    NULL,
           SkuSize6           NVARCHAR(5)    NULL,
           SkuSize7           NVARCHAR(5)    NULL,
           SkuSize8           NVARCHAR(5)    NULL,
           SkuSize9           NVARCHAR(5)    NULL,
           SkuSize10          NVARCHAR(5)    NULL,
           SkuSize11          NVARCHAR(5)    NULL,
           SkuSize12          NVARCHAR(5)    NULL,
           SkuSize13          NVARCHAR(5)    NULL,
           SkuSize14          NVARCHAR(5)    NULL,
           SkuSize15          NVARCHAR(5)    NULL,
           SkuSize16          NVARCHAR(5)    NULL,
           SkuSize17          NVARCHAR(5)    NULL,
           SkuSize18          NVARCHAR(5)    NULL,
           SkuSize19          NVARCHAR(5)    NULL,
           SkuSize20          NVARCHAR(5)    NULL,
           SkuSize21          NVARCHAR(5)    NULL,
           SkuSize22          NVARCHAR(5)    NULL,
           SkuSize23          NVARCHAR(5)    NULL,
           SkuSize24          NVARCHAR(5)    NULL,
           SkuSize25          NVARCHAR(5)    NULL,
           SkuSize26          NVARCHAR(5)    NULL,
           SkuSize27          NVARCHAR(5)    NULL,
           SkuSize28          NVARCHAR(5)    NULL,
           SkuSize29          NVARCHAR(5)    NULL,
           SkuSize30          NVARCHAR(5)    NULL,
           SkuSize31          NVARCHAR(5)    NULL,
           SkuSize32          NVARCHAR(5)    NULL,
           Qty1               int            NULL,
           Qty2               int            NULL,
           Qty3               int            NULL,
           Qty4               int            NULL,
           Qty5               int            NULL,
           Qty6               int            NULL,
           Qty7               int            NULL,
           Qty8               int            NULL,
           Qty9               int            NULL,
           Qty10              int            NULL,
           Qty11              int            NULL,
           Qty12              int            NULL,
           Qty13              int            NULL,
           Qty14              int            NULL,
           Qty15              int            NULL,
           Qty16              int            NULL,
           Qty17              int            NULL,
           Qty18              int            NULL,
           Qty19              int            NULL,
           Qty20              int            NULL,
           Qty21              int            NULL,
           Qty22              int            NULL,
           Qty23              int            NULL,
           Qty24              int            NULL,
           Qty25              int            NULL,
           Qty26              int            NULL,
           Qty27              int            NULL,
           Qty28              int            NULL,
           Qty29              int            NULL,
           Qty30              int            NULL,
           Qty31              int            NULL,
           Qty32              int            NULL,
           Division           NVARCHAR(18)   NULL,     
           OrderType          NVARCHAR(10)   NULL,     
           TotalCartons       INT            NULL,     
           OrdDetUserdef02    NVARCHAR(18)   NULL,     
           OrdDetUserdef09    NVARCHAR(18)   NULL,     
           GetOrderType       NVARCHAR(20)   NULL,     
           Notes2             NVARCHAR(255)  NULL,     
           Price              INT            NULL      --WL01
         )

   CREATE TABLE #SkuSZ
          ( Orderkey    NVARCHAR(10)   NULL
          , Storerkey   NVARCHAR(15)   NULL
          , Sku         NVARCHAR(20)   NULL
          , Size        NVARCHAR(5)    NULL
          )
   CREATE INDEX #SkuSZ_IDXKey ON #SkuSZ(Orderkey, Storerkey, Sku)

   SET @c_TempOrderKey = '' SET @n_Count = 0
   SET @c_SkuSize1=''  SET @c_SkuSize2=''  SET @c_SkuSize3=''  SET @c_SkuSize4=''
   SET @c_SkuSize5=''  SET @c_SkuSize6=''  SET @c_SkuSize7=''  SET @c_SkuSize8=''
   SET @c_SkuSize9=''  SET @c_SkuSize10='' SET @c_SkuSize11='' SET @c_SkuSize12=''
   SET @c_SkuSize13='' SET @c_SkuSize14='' SET @c_SkuSize15='' SET @c_SkuSize16=''
   SET @c_SkuSize17='' SET @c_SkuSize18='' SET @c_SkuSize19='' SET @c_SkuSize20=''
   SET @c_SkuSize21='' SET @c_SkuSize22='' SET @c_SkuSize23='' SET @c_SkuSize24=''
   SET @c_SkuSize25='' SET @c_SkuSize26='' SET @c_SkuSize27='' SET @c_SkuSize28=''
   SET @c_SkuSize29='' SET @c_SkuSize30='' SET @c_SkuSize31='' SET @c_SkuSize32=''

   SELECT DISTINCT OrderKey
   INTO #TempOrder
   FROM  LOADPLANDETAIL (NOLOCK)
   WHERE LOADPLANDETAIL.LoadKey = @c_LoadKey

   SET @n_TotalCartons = 0
   SELECT @n_TotalCartons = COUNT(DISTINCT PD.PickSlipNO + CONVERT(VARCHAR(5), PD.CartonNo))
   FROM LOADPLANDETAIL LPD WITH (NOLOCK)
   JOIN PACKHEADER     PH  WITH (NOLOCK) ON (LPD.Orderkey = PH.Orderkey)
   JOIN PACKDETAIL     PD  WITH (NOLOCK) ON (PH.PickSlipNo= PD.PickSlipNo)
   WHERE LPD.Loadkey = @c_LoadKey


   SELECT TOP 1 @c_TempOrderKey = Orderkey
   FROM  LOADPLANDETAIL (NOLOCK)
   WHERE LoadKey = @c_LoadKey

   SET @c_OrderType= ''
   SET @c_Division = ''

   SELECT TOP 1 @c_OrderType = OH.Type + CASE WHEN OH.Type = 'I' THEN  N'(補貨)' ELSE '' END
               ,@c_GetOrderType = OH.[Type]  
               ,@c_Division = ISNULL(RTRIM(OD.Lottable01),'')
   FROM ORDERS      OH  WITH (NOLOCK)
   JOIN ORDERDETAIL OD  WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey)
   JOIN SKU         SKU WITH (NOLOCK) ON (OD.Storerkey = SKU.Storerkey)
                                      AND(OD.Sku = SKU.Sku)

   WHERE OH.Orderkey = @c_TempOrderKey
   ORDER BY  OD.OrderLineNumber
   SET @c_TempOrderKey = ''


   WHILE (1=1)
   BEGIN
      SELECT @c_TempOrderKey = MIN(OrderKey)
      FROM #TempOrder
      WHERE OrderKey > @c_TempOrderKey

      IF @c_TempOrderKey IS NULL OR @c_TempOrderKey = ''  BREAK

      INSERT INTO #SKUSZ
            (Orderkey
            ,Storerkey
            ,Sku
            ,Size)
      SELECT DISTINCT 
             OD.Orderkey
            ,SKU.Storerkey
            ,SKU.Sku
            ,Size = CASE WHEN RCFG.ListName IS NOT NULL AND ISNULL(RTRIM(SKU.Measurement),'') <> ''
                         THEN ISNULL(RTRIM(SKU.Measurement),'')
                         ELSE ISNULL(RTRIM(SKU.Size),'')
                         END
      FROM ORDERDETAIL    OD   WITH (NOLOCK)
      JOIN SKU            SKU  WITH (NOLOCK) ON (SKU.Storerkey = OD.Storerkey AND SKU.SKU = OD.SKU)
      LEFT JOIN CODELKUP  RCFG WITH (NOLOCK) ON (RCFG.ListName = 'REPORTCFG')
                                             AND(RCFG.Code= 'ShowUSSize')
                                             AND(RCFG.Storerkey= SKU.Storerkey)
                                             AND(RCFG.Long = 'r_dw_print_packlist_09')
                                             AND(ISNULL(RTRIM(RCFG.Short),'') <> 'N')

      WHERE OD.OrderKey = @c_TempOrderKey
      AND OD.Loadkey = @C_Loadkey

      -- Get all unique sizes for the same order
      IF @c_GetOrderType <> 'ECOM'
      BEGIN
         DECLARE pick_cur CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT
                 ISNULL(RTRIM(SKUSZ.Size),'')                             
               , OD.Orderkey
               , ISNULL(RTRIM(SKU.Style),'')  + ISNULL(RTRIM(SKU.Color),'')
               , CASE WHEN ISNULL(RTRIM(OD.Lottable01),'') LIKE '10%'
                      THEN ISNULL(RTRIM(SKU.Color),'')
                      WHEN ISNULL(RTRIM(OD.Lottable01),'') LIKE '30%'
                      THEN ISNULL(RTRIM(SKU.Color),'')
                      ELSE '' END
               , CASE WHEN ISNULL(RTRIM(OD.Lottable01),'') LIKE '10%'
                      THEN 1
                      WHEN ISNULL(RTRIM(OD.Lottable01),'') LIKE '30%'
                      THEN 1
                      ELSE 0 END
           , OD.SKU
           , SizeSort = CASE WHEN ISNUMERIC(ISNULL(CL1.UDF05,'')) = 1 THEN CAST(ISNULL(CL1.UDF05,'') AS INT) ELSE 0 END
         FROM ORDERDETAIL OD (NOLOCK)
         JOIN LOADPLANDETAIL LP  WITH (NOLOCK) ON (LP.Orderkey = OD.Orderkey)
         JOIN SKU            SKU WITH (NOLOCK) ON (SKU.Storerkey = OD.Storerkey AND SKU.SKU = OD.SKU)
         JOIN #SKUSZ       SKUSZ WITH (NOLOCK) ON (OD.Orderkey = SKUSZ.Orderkey)                               
                                                 AND(SKU.Storerkey = SKUSZ.Storerkey AND SKU.SKU = SKUSZ.SKU) 
         LEFT JOIN CODELKUP  CL1 WITH (NOLOCK) ON (CL1.ListName = 'SKXSIZE')
                                               AND(CL1.Code = SKUSZ.Size)                                       
                                               AND(CL1.Storerkey= SKU.Storerkey)
         WHERE OD.OrderKey = @c_TempOrderKey
         AND OD.Loadkey = @C_Loadkey
         ORDER BY OD.OrderKey
               ,  ISNULL(RTRIM(SKU.Style),'')  + ISNULL(RTRIM(SKU.Color),'')
               ,  CASE WHEN ISNULL(RTRIM(OD.Lottable01),'') LIKE '10%'
                       THEN ISNULL(RTRIM(SKU.Color),'')
                       WHEN ISNULL(RTRIM(OD.Lottable01),'') LIKE '30%'
                       THEN ISNULL(RTRIM(SKU.Color),'')
                       ELSE '' END
               ,  SizeSort
      END
      ELSE
      BEGIN
         DECLARE pick_cur CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT
                 ISNULL(RTRIM(SKUSZ.Size),'')                              
               , OD.Orderkey
               , ISNULL(RTRIM(SKU.Style),'')  + ISNULL(RTRIM(SKU.Color),'')
               , CASE WHEN ISNULL(RTRIM(OD.Lottable01),'') LIKE '10%'
                      THEN ISNULL(RTRIM(SKU.Color),'')
                      WHEN ISNULL(RTRIM(OD.Lottable01),'') LIKE '30%'
                      THEN ISNULL(RTRIM(SKU.Color),'')
                      ELSE '' END
               , CASE WHEN ISNULL(RTRIM(OD.Lottable01),'') LIKE '10%'
                      THEN 1
                      WHEN ISNULL(RTRIM(OD.Lottable01),'') LIKE '30%'
                      THEN 1
                      ELSE 0 END
           , OD.SKU
           , SizeSort = CASE WHEN (@c_Division LIKE '10%' OR @c_Division LIKE '30%') AND CL.Code IS NOT NULL
                        THEN ISNULL(CL.Short,'')
                        ELSE ISNULL(RTRIM(SKUSZ.Size),'')
                        END
         FROM ORDERDETAIL OD (NOLOCK)
         JOIN LOADPLANDETAIL LP  WITH (NOLOCK) ON (LP.Orderkey = OD.Orderkey)
         JOIN SKU            SKU WITH (NOLOCK) ON (SKU.Storerkey = OD.Storerkey AND SKU.SKU = OD.SKU)
         JOIN #SKUSZ       SKUSZ WITH (NOLOCK) ON (OD.Orderkey = SKUSZ.Orderkey)                              
                                                 AND(SKU.Storerkey = SKUSZ.Storerkey AND SKU.SKU = SKUSZ.SKU) 
         LEFT JOIN CODELKUP  CL  WITH (NOLOCK) ON (CL.ListName = 'SIZELSTORD')
                                               AND(CL.Code = SKUSZ.Size)                                      
                                               AND(CL.Storerkey= SKU.Storerkey)
         WHERE OD.OrderKey = @c_TempOrderKey
         AND OD.Loadkey = @C_Loadkey
         ORDER BY OD.OrderKey
               ,  ISNULL(RTRIM(SKU.Style),'')  + ISNULL(RTRIM(SKU.Color),'')
               ,  CASE WHEN ISNULL(RTRIM(OD.Lottable01),'') LIKE '10%'
                       THEN ISNULL(RTRIM(SKU.Color),'')
                       WHEN ISNULL(RTRIM(OD.Lottable01),'') LIKE '30%'
                       THEN ISNULL(RTRIM(SKU.Color),'')
                       ELSE '' END
               ,  SizeSort
      END

      OPEN pick_cur
      FETCH NEXT FROM pick_cur INTO @c_SkuSize, @c_OrderKey
                                 ,  @c_Style
                                 ,  @c_Color
                                 ,  @n_StyleWColor     
                                 ,  @c_SkuSort
                                 ,  @c_SizeSort        



      WHILE (@@FETCH_STATUS <> -1)
      BEGIN
         SET @n_Count = @n_Count + 1
         IF @b_debug = 1
         BEGIN
            SELECT 'Count of sizes is ' + CONVERT(char(5), @n_Count)
         END

         SET @c_SkuSize1 = CASE @n_Count WHEN 1
                            THEN @c_SkuSize
                            ELSE @c_SkuSize1
                            END
         SET @c_SkuSize2 = CASE @n_Count WHEN 2
                            THEN @c_SkuSize
                            ELSE @c_SkuSize2
                            END
         SET @c_SkuSize3 =  CASE @n_Count WHEN 3
                            THEN @c_SkuSize
                            ELSE @c_SkuSize3
                            END
         SET @c_SkuSize4 =  CASE @n_Count WHEN 4
                            THEN @c_SkuSize
                            ELSE @c_SkuSize4
                            END
         SET @c_SkuSize5 =  CASE @n_Count WHEN 5
                            THEN @c_SkuSize
                            ELSE @c_SkuSize5
                            END
         SET @c_SkuSize6 =  CASE @n_Count WHEN 6
                            THEN @c_SkuSize
                            ELSE @c_SkuSize6
                            END
         SET @c_SkuSize7 =  CASE @n_Count WHEN 7
                            THEN @c_SkuSize
                            ELSE @c_SkuSize7
                            END
         SET @c_SkuSize8 =  CASE @n_Count WHEN 8
                            THEN @c_SkuSize
                            ELSE @c_SkuSize8
                            END
         SET @c_SkuSize9 =  CASE @n_Count WHEN 9
                            THEN @c_SkuSize
                            ELSE @c_SkuSize9
                            END
         SET @c_SkuSize10 = CASE @n_Count WHEN 10
                            THEN @c_SkuSize
                            ELSE @c_SkuSize10
                            END
         SET @c_SkuSize11 = CASE @n_Count WHEN 11
                            THEN @c_SkuSize
                            ELSE @c_SkuSize11
                            END
         SET @c_SkuSize12 = CASE @n_Count WHEN 12
                            THEN @c_SkuSize
                            ELSE @c_SkuSize12
                            END
         SET @c_SkuSize13 = CASE @n_Count WHEN 13
                            THEN @c_SkuSize
                            ELSE @c_SkuSize13
                            END
         SET @c_SkuSize14 = CASE @n_Count WHEN 14
                            THEN @c_SkuSize
                            ELSE @c_SkuSize14
                            END
         SET @c_SkuSize15 = CASE @n_Count WHEN 15
                            THEN @c_SkuSize
                            ELSE @c_SkuSize15
                            END
         SET @c_SkuSize16 = CASE @n_Count WHEN 16
                            THEN @c_SkuSize
                            ELSE @c_SkuSize16
                            END
         SET @c_SkuSize17 = CASE @n_Count WHEN 17
                            THEN @c_SkuSize
                            ELSE @c_SkuSize17
                            END
         SET @c_SkuSize18 = CASE @n_Count WHEN 18
                            THEN @c_SkuSize
                            ELSE @c_SkuSize18
                            END
         SET @c_SkuSize19 = CASE @n_Count WHEN 19
                            THEN @c_SkuSize
                            ELSE @c_SkuSize19
                            END
         SET @c_SkuSize20 = CASE @n_Count WHEN 20
                            THEN @c_SkuSize
                            ELSE @c_SkuSize20
                            END
         SET @c_SkuSize21 = CASE @n_Count WHEN 21
                            THEN @c_SkuSize
                            ELSE @c_SkuSize21
                            END
         SET @c_SkuSize22 = CASE @n_Count WHEN 22
                            THEN @c_SkuSize
                            ELSE @c_SkuSize22
                            END
         SET @c_SkuSize23 = CASE @n_Count WHEN 23
                            THEN @c_SkuSize
                            ELSE @c_SkuSize23
                            END
         SET @c_SkuSize24 = CASE @n_Count WHEN 24
                            THEN @c_SkuSize
                            ELSE @c_SkuSize24
                            END
         SET @c_SkuSize25 = CASE @n_Count WHEN 25
                            THEN @c_SkuSize
                            ELSE @c_SkuSize25
                            END
         SET @c_SkuSize26 = CASE @n_Count WHEN 26
                            THEN @c_SkuSize
                            ELSE @c_SkuSize26
                            END
         SET @c_SkuSize27 = CASE @n_Count WHEN 27
                            THEN @c_SkuSize
                            ELSE @c_SkuSize27
                            END
         SET @c_SkuSize28 = CASE @n_Count WHEN 28
                            THEN @c_SkuSize
                            ELSE @c_SkuSize28
                            END
         SET @c_SkuSize29 = CASE @n_Count WHEN 29
                            THEN @c_SkuSize
                            ELSE @c_SkuSize29
                            END
         SET @c_SkuSize30 = CASE @n_Count WHEN 30
                            THEN @c_SkuSize
                            ELSE @c_SkuSize30
                            END
         SET @c_SkuSize31 = CASE @n_Count WHEN 31
                            THEN @c_SkuSize
                            ELSE @c_SkuSize31
                            END
         SET @c_SkuSize32 = CASE @n_Count WHEN 32
                            THEN @c_SkuSize
                            ELSE @c_SkuSize32
                            END

         SET @c_PrevOrderKey = @c_OrderKey
         SET @c_PrevStyle = @c_Style
         SET @c_PrevColor = @c_Color
         SET @n_PrevStyleWColor = @n_StyleWColor     

         FETCH NEXT FROM pick_cur INTO @c_SkuSize, @c_OrderKey
                                    ,  @c_Style
                                    ,  @c_Color
                                    ,  @n_StyleWColor 
                                    ,  @c_SkuSort
                                    ,  @c_SizeSort   


         IF @b_debug = 1
         BEGIN
            SELECT 'PrevOrderkey= ' + @c_PrevOrderKey + ', Orderkey= ' + @c_OrderKey
         END

         IF (@c_PrevOrderKey <> @c_OrderKey) OR
            (@c_PrevStyle <> @c_Style) OR
            (@n_PrevStyleWColor = 1 AND @c_PrevColor <> @c_Color) OR
            (@@FETCH_STATUS = -1) -- last fetch
         BEGIN
            -- Insert into temp table
            INSERT INTO #TempPickSlip
            SELECT ISNULL(RTRIM(Pickheader.Pickheaderkey),''),
                   LOADPLANDETAIL.Loadkey,
                   ORDERS.Orderkey,
                   ISNULL(RTRIM(ORDERS.ExternOrderKey),''),
                   CONVERT(NVARCHAR(255), ORDERS.Notes) AS Notes,
                   ISNULL(RTRIM(ORDERS.ConsigneeKey),''),
                   ISNULL(RTRIM(ORDERS.C_Company),''),
                   ISNULL(RTRIM(ORDERS.c_Address1),''),
                   ISNULL(RTRIM(ORDERS.c_Address2),''),
                   ISNULL(RTRIM(ORDERS.c_Address3),''),
                   ISNULL(RTRIM(ORDERS.c_Address3),'') AS Address4,
                   ISNULL(RTRIM(ORDERS.c_City),''),
                   ISNULL(RTRIM(ORDERS.c_Zip),''),
                   ISNULL(RTRIM(ORDERS.InvoiceNo),''),
                   @c_PrevStyle AS StyleColour,
                   '',
                   CONVERT(NVARCHAR(255), STORER.Notes1) AS StorerNotes,
                   Qty = SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty),
                   N'件' AS UOM,
                   0 AS PACKCaseCnt,
                   LOADPLAN.lpuserdefdate01,
                   ORDERS.Storerkey,
                   @c_SkuSize1,
                   @c_SkuSize2,
                   @c_SkuSize3,
                   @c_SkuSize4,
                   @c_SkuSize5,
                   @c_SkuSize6,
                   @c_SkuSize7,
                   @c_SkuSize8,
                   @c_SkuSize9,
                   @c_SkuSize10,
                   @c_SkuSize11,
                   @c_SkuSize12,
                   @c_SkuSize13,
                   @c_SkuSize14,
                   @c_SkuSize15,
                   @c_SkuSize16,
                   @c_SkuSize17,
                   @c_SkuSize18,
                   @c_SkuSize19,
                   @c_SkuSize20,
                   @c_SkuSize21,
                   @c_SkuSize22,
                   @c_SkuSize23,
                   @c_SkuSize24,
                   @c_SkuSize25,
                   @c_SkuSize26,
                   @c_SkuSize27,
                   @c_SkuSize28,
                   @c_SkuSize29,
                   @c_SkuSize30,
                   @c_SkuSize31,
                   @c_SkuSize32,
                 CASE WHEN ISNULL(RTRIM(SKUSZ.Size),'') = @c_SkuSize1 AND ISNULL(RTRIM(SKUSZ.Size),'') <> ''
                     THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                     ELSE 0
                     END,
                 CASE WHEN ISNULL(RTRIM(SKUSZ.Size),'') = @c_SkuSize2 AND ISNULL(RTRIM(SKUSZ.Size),'') <> ''
                     THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                     ELSE 0
                     END,
                 CASE WHEN ISNULL(RTRIM(SKUSZ.Size),'') = @c_SkuSize3 AND ISNULL(RTRIM(SKUSZ.Size),'') <> ''
                     THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                     ELSE 0
                     END,
                 CASE WHEN ISNULL(RTRIM(SKUSZ.Size),'') = @c_SkuSize4 AND ISNULL(RTRIM(SKUSZ.Size),'') <> ''
                     THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                     ELSE 0
                     END,
                 CASE WHEN ISNULL(RTRIM(SKUSZ.Size),'') = @c_SkuSize5 AND ISNULL(RTRIM(SKUSZ.Size),'') <> ''
                     THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                     ELSE 0
                     END,
                 CASE WHEN ISNULL(RTRIM(SKUSZ.Size),'') = @c_SkuSize6 AND ISNULL(RTRIM(SKUSZ.Size),'') <> ''
                     THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                     ELSE 0
                     END,
                 CASE WHEN ISNULL(RTRIM(SKUSZ.Size),'') = @c_SkuSize7 AND ISNULL(RTRIM(SKUSZ.Size),'') <> ''
                     THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                     ELSE 0
                     END,
                 CASE WHEN ISNULL(RTRIM(SKUSZ.Size),'') = @c_SkuSize8 AND ISNULL(RTRIM(SKUSZ.Size),'') <> ''
                     THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                     ELSE 0
                     END,
                 CASE WHEN ISNULL(RTRIM(SKUSZ.Size),'') = @c_SkuSize9 AND ISNULL(RTRIM(SKUSZ.Size),'') <> ''
                     THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                     ELSE 0
                     END,
                 CASE WHEN ISNULL(RTRIM(SKUSZ.Size),'') = @c_SkuSize10 AND ISNULL(RTRIM(SKUSZ.Size),'') <> ''
                     THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                     ELSE 0
                     END,
                 CASE WHEN ISNULL(RTRIM(SKUSZ.Size),'') = @c_SkuSize11 AND ISNULL(RTRIM(SKUSZ.Size),'') <> ''
                     THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                     ELSE 0
                     END,
                 CASE WHEN ISNULL(RTRIM(SKUSZ.Size),'') = @c_SkuSize12 AND ISNULL(RTRIM(SKUSZ.Size),'') <> ''
                     THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                     ELSE 0
                     END,
                 CASE WHEN ISNULL(RTRIM(SKUSZ.Size),'') = @c_SkuSize13 AND ISNULL(RTRIM(SKUSZ.Size),'') <> ''
                     THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                     ELSE 0
                     END,
                 CASE WHEN ISNULL(RTRIM(SKUSZ.Size),'') = @c_SkuSize14 AND ISNULL(RTRIM(SKUSZ.Size),'') <> ''
                     THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                     ELSE 0
                     END,
                 CASE WHEN ISNULL(RTRIM(SKUSZ.Size),'') = @c_SkuSize15 AND ISNULL(RTRIM(SKUSZ.Size),'') <> ''
                     THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                     ELSE 0
                     END,
                 CASE WHEN ISNULL(RTRIM(SKUSZ.Size),'') = @c_SkuSize16 AND ISNULL(RTRIM(SKUSZ.Size),'') <> ''
                     THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                     ELSE 0
                     END,
                 CASE WHEN ISNULL(RTRIM(SKUSZ.Size),'') = @c_SkuSize17 AND ISNULL(RTRIM(SKUSZ.Size),'') <> ''
                     THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                     ELSE 0
                     END,
                 CASE WHEN ISNULL(RTRIM(SKUSZ.Size),'') = @c_SkuSize18 AND ISNULL(RTRIM(SKUSZ.Size),'') <> ''
                     THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                     ELSE 0
                     END,
                 CASE WHEN ISNULL(RTRIM(SKUSZ.Size),'') = @c_SkuSize19 AND ISNULL(RTRIM(SKUSZ.Size),'') <> ''
                     THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                     ELSE 0
                     END,
                 CASE WHEN ISNULL(RTRIM(SKUSZ.Size),'') = @c_SkuSize20 AND ISNULL(RTRIM(SKUSZ.Size),'') <> ''
                     THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                     ELSE 0
                     END,
                 CASE WHEN ISNULL(RTRIM(SKUSZ.Size),'') = @c_SkuSize21 AND ISNULL(RTRIM(SKUSZ.Size),'') <> ''
                     THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                     ELSE 0
                     END,
                 CASE WHEN ISNULL(RTRIM(SKUSZ.Size),'') = @c_SkuSize22 AND ISNULL(RTRIM(SKUSZ.Size),'') <> ''
                     THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                     ELSE 0
                     END,
                 CASE WHEN ISNULL(RTRIM(SKUSZ.Size),'') = @c_SkuSize23 AND ISNULL(RTRIM(SKUSZ.Size),'') <> ''
                     THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                     ELSE 0
                     END,
                 CASE WHEN ISNULL(RTRIM(SKUSZ.Size),'') = @c_SkuSize24 AND ISNULL(RTRIM(SKUSZ.Size),'') <> ''
                     THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                     ELSE 0
                     END,
                 CASE WHEN ISNULL(RTRIM(SKUSZ.Size),'') = @c_SkuSize25 AND ISNULL(RTRIM(SKUSZ.Size),'') <> ''
                     THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                     ELSE 0
                     END,
                 CASE WHEN ISNULL(RTRIM(SKUSZ.Size),'') = @c_SkuSize26 AND ISNULL(RTRIM(SKUSZ.Size),'') <> ''
                     THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                     ELSE 0
                     END,
                 CASE WHEN ISNULL(RTRIM(SKUSZ.Size),'') = @c_SkuSize27 AND ISNULL(RTRIM(SKUSZ.Size),'') <> ''
                     THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                     ELSE 0
                     END,
                 CASE WHEN ISNULL(RTRIM(SKUSZ.Size),'') = @c_SkuSize28 AND ISNULL(RTRIM(SKUSZ.Size),'') <> ''
                     THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                     ELSE 0
                     END,
                 CASE WHEN ISNULL(RTRIM(SKUSZ.Size),'') = @c_SkuSize29 AND ISNULL(RTRIM(SKUSZ.Size),'') <> ''
                     THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                     ELSE 0
                     END,
                 CASE WHEN ISNULL(RTRIM(SKUSZ.Size),'') = @c_SkuSize30 AND ISNULL(RTRIM(SKUSZ.Size),'') <> ''
                     THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                     ELSE 0
                     END,
                 CASE WHEN ISNULL(RTRIM(SKUSZ.Size),'') = @c_SkuSize31 AND ISNULL(RTRIM(SKUSZ.Size),'') <> ''
                     THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                     ELSE 0
                     END,
                 CASE WHEN ISNULL(RTRIM(SKUSZ.Size),'') = @c_SkuSize32 AND ISNULL(RTRIM(SKUSZ.Size),'') <> ''
                     THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                     ELSE 0
                     END
               , ''
               , @c_OrderType
               , @n_TotalCartons
               , ''--OD.Userdefine02     --WL02  
               , OD.Userdefine09       
               , @c_GetOrderType AS GetOrderType  
               , ISNULL(ORDERS.Notes2,'') AS Notes2   
               , MIN(ISNULL(SKU.Price,0.00)) AS Price   --WL01
            FROM ORDERDETAIL OD  WITH (NOLOCK)
            JOIN ORDERS          WITH (NOLOCK) ON (OD.OrderKey = ORDERS.OrderKey)
            JOIN PACK            WITH (NOLOCK) ON (OD.Packkey = PACK.Packkey)
            JOIN LOADPLANDETAIL  WITH (NOLOCK) ON (OD.OrderKey = LOADPLANDETAIL.OrderKey AND
                                                   LOADPLANDETAIL.Loadkey = ORDERS.Loadkey)
            JOIN LOADPLAN        WITH (NOLOCK) ON (LOADPLANDETAIL.Loadkey = LOADPLAN.Loadkey)
            JOIN SKU             WITH (NOLOCK) ON (SKU.StorerKey = OD.StorerKey AND
                                                   SKU.SKU = OD.SKU)
            JOIN #SKUSZ    SKUSZ WITH (NOLOCK)ON (OD.Orderkey = SKUSZ.Orderkey)                             --(Wan04)
                                                   AND(SKU.Storerkey = SKUSZ.Storerkey AND SKU.SKU = SKUSZ.SKU)  --(Wan04)
            JOIN STORER          WITH (NOLOCK) ON (ORDERS.Storerkey = STORER.Storerkey)
            LEFT JOIN PICKHEADER WITH (NOLOCK) ON (OD.OrderKey = Pickheader.orderkey)
            WHERE ORDERS.OrderKey = @c_PrevOrderKey
            AND  RTRIM(SKU.Style) + LTRIM(RTRIM(SKU.COLOR)) = @c_PrevStyle
            AND  SKU.Color = CASE WHEN @n_PrevStyleWColor = 1 THEN @c_PrevColor ELSE SKU.Color END

            GROUP BY ISNULL(RTRIM(Pickheader.Pickheaderkey),''),
                     LOADPLANDETAIL.Loadkey,
                     ORDERS.Orderkey,
                     ISNULL(RTRIM(ORDERS.ExternOrderKey),''),
                     CONVERT(NVARCHAR(255), ORDERS.Notes),
                     ISNULL(RTRIM(ORDERS.ConsigneeKey),''),
                     ISNULL(RTRIM(ORDERS.C_Company),''),
                     ISNULL(RTRIM(ORDERS.c_Address1),''),
                     ISNULL(RTRIM(ORDERS.c_Address2),''),
                     ISNULL(RTRIM(ORDERS.c_Address3),''),
                     ISNULL(RTRIM(ORDERS.c_Address3),''),
                     ISNULL(RTRIM(ORDERS.c_City),''),
                     ISNULL(RTRIM(ORDERS.c_Zip),''),
                     ISNULL(RTRIM(ORDERS.InvoiceNo),''),
                     ISNULL(RTRIM(SKU.Style),'') + @c_PrevColor,
                     CONVERT(NVARCHAR(255), STORER.Notes1),
                     LOADPLAN.lpuserdefdate01,
                     ORDERS.Storerkey,
                     ISNULL(RTRIM(SKUSZ.Size),'') 
                    --,OD.Userdefine02         --WL02  
                    ,OD.Userdefine09      
                    ,ISNULL(ORDERS.Notes2,'') 
            HAVING SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty) > 0
            ORDER BY ORDERS.OrderKey,
                     StyleColour,
                     UOM

            -- Reset counter and skusize
            SET @n_Count = 0
            SET @c_SkuSize1=''  SET @c_SkuSize2=''  SET @c_SkuSize3=''  SET @c_SkuSize4=''
            SET @c_SkuSize5=''  SET @c_SkuSize6=''  SET @c_SkuSize7=''  SET @c_SkuSize8=''
            SET @c_SkuSize9=''  SET @c_SkuSize10='' SET @c_SkuSize11='' SET @c_SkuSize12=''
            SET @c_SkuSize13='' SET @c_SkuSize14='' SET @c_SkuSize15='' SET @c_SkuSize16=''
            SET @c_SkuSize17='' SET @c_SkuSize18='' SET @c_SkuSize19='' SET @c_SkuSize20=''
            SET @c_SkuSize21='' SET @c_SkuSize22='' SET @c_SkuSize23='' SET @c_SkuSize24=''
            SET @c_SkuSize25='' SET @c_SkuSize26='' SET @c_SkuSize27='' SET @c_SkuSize28=''
            SET @c_SkuSize29='' SET @c_SkuSize30='' SET @c_SkuSize31='' SET @c_SkuSize32=''
         END
      END -- WHILE (@@FETCH_STATUS <> -1)

      CLOSE pick_cur
      DEALLOCATE pick_cur
   END -- WHILE (1=1)


   SELECT T.PickSlipNo, T.Loadkey, T.OrderKey, T.ExternOrderKey, T.Notes,
          T.ConsigneeKey Consigneekey, T.Company, T.c_Address1, T.c_Address2, T.c_Address3, T.c_Address4, T.c_City, T.c_Zip,
          T.StyleColor, T.SkuDescr, T.Storernotes, Qty=SUM(T.Qty), T.UOM, T.CaseCnt, T.lpuserdefdate01, T.Storerkey,
          T.SkuSize1,  T.SkuSize2,  T.SkuSize3,  T.SkuSize4,  T.SkuSize5,  T.SkuSize6,  T.SkuSize7,  T.SkuSize8,
          T.SkuSize9,  T.SkuSize10, T.SkuSize11, T.SkuSize12, T.SkuSize13, T.SkuSize14, T.SkuSize15, T.SkuSize16,
          T.SkuSize17, T.SkuSize18, T.SkuSize19, T.SkuSize20, T.SkuSize21, T.SkuSize22, T.SkuSize23, T.SkuSize24,
          T.SkuSize25, T.SkuSize26, T.SkuSize27, T.SkuSize28, T.SkuSize29, T.SkuSize30, T.SkuSize31, T.SkuSize32,
          SUM(T.Qty1) Qty1, SUM(T.Qty2) Qty2, SUM(T.Qty3) Qty3, SUM(T.Qty4) Qty4, SUM(T.Qty5) Qty5, SUM(T.Qty6) Qty6,
          SUM(T.Qty7) Qty7, SUM(T.Qty8) Qty8, SUM(T.Qty9) Qty9, SUM(T.Qty10) Qty10, SUM(T.Qty11) Qty11, SUM(T.Qty12) Qty12,
          SUM(T.Qty13) Qty13, SUM(T.Qty14) Qty14, SUM(T.Qty15) Qty15, SUM(T.Qty16) Qty16,
          SUM(T.Qty17) Qty17, SUM(T.Qty18) Qty18, SUM(T.Qty19) Qty19, SUM(T.Qty20) Qty20, SUM(T.Qty21) Qty21, SUM(T.Qty22) Qty22,
          SUM(T.Qty23) Qty23, SUM(T.Qty24) Qty24, SUM(T.Qty25) Qty25, SUM(T.Qty26) Qty26, SUM(T.Qty27) Qty27, SUM(T.Qty28) Qty28,
          SUM(T.Qty29) Qty29, SUM(T.Qty30) Qty30, SUM(T.Qty31) Qty31, SUM(T.Qty32) Qty32,
          ISNULL(STORER.Consigneefor,'') Consigneefor--, #TempOD.Userdefine04, T.InvoiceNo  
         ,  T.Division, T.InvoiceNo, T.OrderType, T.TotalCartons,T.OrdDetUserdef02,T.OrdDetUserdef09
         ,  T.GetOrderType, T.Notes2, T.Price 
   FROM #TempPickSlip T
   LEFT JOIN STORER (NOLOCK) ON T.Consigneekey = STORER.Storerkey AND STORER.Type = '2'
   --LEFT JOIN #TempOD (NOLOCK) ON T.Orderkey = #TempOD.Orderkey        
   GROUP BY T.PickSlipNo, T.Loadkey, T.OrderKey, T.ExternOrderKey, T.Notes,
            T.ConsigneeKey, T.Company, T.c_Address1, T.c_Address2, T.c_Address3, T.c_Address4, T.c_City, T.c_Zip,
            T.StyleColor, T.SkuDescr, T.Storernotes, T.UOM, T.CaseCnt, T.lpuserdefdate01, T.Storerkey,
            T.SkuSize1, T.SkuSize2, T.SkuSize3, T.SkuSize4, T.SkuSize5, T.SkuSize6, T.SkuSize7, T.SkuSize8,
            T.SkuSize9, T.SkuSize10, T.SkuSize11, T.SkuSize12, T.SkuSize13, T.SkuSize14, T.SkuSize15, T.SkuSize16,
            T.SkuSize17, T.SkuSize18, T.SkuSize19, T.SkuSize20, T.SkuSize21, T.SkuSize22, T.SkuSize23, T.SkuSize24,
            T.SkuSize25, T.SkuSize26, T.SkuSize27, T.SkuSize28, T.SkuSize29, T.SkuSize30, T.SkuSize31, T.SkuSize32,
            ISNULL(STORER.Consigneefor,'')--, #TempOD.Userdefine04, T.InvoiceNo       
         ,  T.Division, T.InvoiceNo, T.OrderType, T.TotalCartons,T.OrdDetUserdef02,T.OrdDetUserdef09 
         ,  T.GetOrderType, T.Notes2, T.Price 
   ORDER BY  MIN(T.SeqNo)

   DROP TABLE #TempOrder
   DROP TABLE #TempPickSlip
END

GO