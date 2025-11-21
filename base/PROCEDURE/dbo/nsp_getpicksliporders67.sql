SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: nsp_GetPickSlipOrders67                             */
/* Creation Date:20/01/2017                                             */
/* Copyright: IDS                                                       */
/* Written by:CSCHONG                                                   */
/*                                                                      */
/* Purpose:WMS-960 - E-land Pick Order Report Modification              */
/*                                                                      */
/* Called By:r_dw_print_pickorder67(copy from nsp_GetPickSlipOrders31)  */
/*                                                                      */
/* PVCS Version: 1.2 (Unicode)                                          */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 05-Nov-2004  MaryVong      Set sizes (text) on every page            */
/*                            - (SOS#28037).                            */
/* 16-Nov-2004  MaryVong      Increase Sku size upto 32 sizes           */
/*                            - (SOS#29528).                            */
/* 17-May-2005  ONG           - NSC Project Change Request. (SOS#35110) */
/*                                                                      */
/* 26-Sep-2008  TLTING        SOS117420/SQL2005 - Add fnc_RTrim to make */
/*                             substring result is NULL.  (tlting01)    */
/* 05-Mar-2009  TLTING        Performance Tune (tlting02)               */
/* 23-Feb-2010  Vanessa       SOS#160570 New Request for Apparel Pick   */
/*                            Slip. (Vanessa01)                         */
/* 05-May-2010  GTGOH         Add in Loc.LogicalLocation                */
/*                            SOS#171564 (GOH01)                        */
/* 26-Mar-2012  Leong         SOS# 239687 - Add ISNULL check            */
/* 26-Jun-2012  NJOW01        248533-Fix empty size show qty issue      */
/* 03-AUG-2012  YTWan         SOS#252198: Fixed to show qty issue and   */
/*                            show Empty on first size (Wan01)          */
/* 11-Sep-2013  YTWan         SOS#288743:Add orders.Invoice for converse*/
/*                            (Wan02)                                   */
/* 19-Mar-2014  NJOW02        306223-configurable sorting by codelkup   */
/* 02-DEC-2015  YTWan         SOS#357939 - CNV - Pick List              */
/*                            ( Change to US Size ) (Wan03)             */
/************************************************************************/

CREATE PROC [dbo].[nsp_GetPickSlipOrders67] (@c_LoadKey NVARCHAR(10))
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_PickSlipNo      NVARCHAR(10),
           @c_OrderKey        NVARCHAR(10),
           @c_BuyerPO         NVARCHAR(20),
           @c_OrderGroup      NVARCHAR(10),
           @c_ExternOrderKey  NVARCHAR(30),
           @c_Route           NVARCHAR(10),
           @c_Notes           NVARCHAR(255),
           @d_OrderDate       datetime,
           @c_ConsigneeKey    NVARCHAR(15),
           @c_Company         NVARCHAR(45),
           @d_DeliveryDate    datetime,
           @c_Notes2          NVARCHAR(255),
           @c_Loc             NVARCHAR(10),
           @c_Sku             NVARCHAR(20),
           @c_UOM             NVARCHAR(10),
           @c_SkuSize         NVARCHAR(5),
           @n_Qty             int,
           @c_Floor           NVARCHAR(1),
           @c_TempOrderKey    NVARCHAR(10),
           @c_TempFloor       NVARCHAR(1),
           @c_TempSize        NVARCHAR(5),
           @n_TempQty         int,
           @c_PrevOrderKey    NVARCHAR(10),
           @c_PrevFloor       NVARCHAR(1),
           @b_success         int,
           @n_err             int,
           @c_errmsg          NVARCHAR(255),
           @n_Count           int,
           @c_Column          NVARCHAR(10),
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
           @c_SkuSize32       NVARCHAR(5),
           @n_Qty1            int,
           @n_Qty2            int,
           @n_Qty3            int,
           @n_Qty4            int,
           @n_Qty5            int,
           @n_Qty6            int,
           @n_Qty7            int,
           @n_Qty8            int,
           @n_Qty9            int,
           @n_Qty10           int,
           @n_Qty11           int,
           @n_Qty12           int,
           @n_Qty13           int,
           @n_Qty14           int,
           @n_Qty15           int,
           @n_Qty16           int,
           @n_Qty17           int,
           @n_Qty18           int,
           @n_Qty19           int,
           @n_Qty20           int,
           @n_Qty21           int,
           @n_Qty22           int,
           @n_Qty23           int,
           @n_Qty24           int,
           @n_Qty25           int,
           @n_Qty26           int,
           @n_Qty27           int,
           @n_Qty28           int,
           @n_Qty29           int,
           @n_Qty30           int,
           @n_Qty31           int,
           @n_Qty32           int,
           @c_Bin             NVARCHAR(2),
           @C_BUSR6           NVARCHAR(30),
           @c_LogicalLocation NVARCHAR(18),    -- GOH01
           @c_Sort            NVARCHAR(5)    --(Wan01)

   DECLARE @b_debug int
   SELECT @b_debug = 0

   CREATE TABLE #TempPickSlip (
               PickSlipNo       NVARCHAR(10) NULL,
               Loadkey          NVARCHAR(10) NULL,
               OrderKey         NVARCHAR(10) NULL,
               BuyerPO          NVARCHAR(20) NULL,
               OrderGroup       NVARCHAR(10) NULL,
               ExternOrderKey   NVARCHAR(30) NULL,
               Route            NVARCHAR(10) NULL,
               Notes            NVARCHAR(255)NULL,
               OrderDate        datetime NULL,
               ConsigneeKey     NVARCHAR(15) NULL,
               Company          NVARCHAR(45) NULL,
               DeliveryDate     datetime NULL,
               Notes2           NVARCHAR(255)NULL,
               InvoiceNo        NVARCHAR(20) NULL,  --(Wan02)
               Loc              NVARCHAR(10) NULL,
               LogicalLocation  NVARCHAR(18) NULL,  -- GOH01
               StyleColor       NVARCHAR(30) NULL,  -- (Vanessa01)
               UOM              NVARCHAR(10) NULL,
               LFloor           NVARCHAR(5)  NULL,
               Bin              NVARCHAR(2)  NULL,
               PutawayZone      NVARCHAR(10) NULL,  -- (Vanessa01)
               SkuSize1         NVARCHAR(5)  NULL,
               SkuSize2         NVARCHAR(5)  NULL,
               SkuSize3         NVARCHAR(5)  NULL,
               SkuSize4         NVARCHAR(5)  NULL,
               SkuSize5         NVARCHAR(5)  NULL,
               SkuSize6         NVARCHAR(5)  NULL,
               SkuSize7         NVARCHAR(5)  NULL,
               SkuSize8         NVARCHAR(5)  NULL,
               SkuSize9         NVARCHAR(5)  NULL,
               SkuSize10        NVARCHAR(5)  NULL,
               SkuSize11        NVARCHAR(5)  NULL,
               SkuSize12        NVARCHAR(5)  NULL,
               SkuSize13        NVARCHAR(5)  NULL,
               SkuSize14        NVARCHAR(5)  NULL,
               SkuSize15        NVARCHAR(5)  NULL,
               SkuSize16        NVARCHAR(5)  NULL,
               SkuSize17        NVARCHAR(5)  NULL,
               SkuSize18        NVARCHAR(5)  NULL,
               SkuSize19        NVARCHAR(5)  NULL,
               SkuSize20        NVARCHAR(5)  NULL,
               SkuSize21        NVARCHAR(5)  NULL,
               SkuSize22        NVARCHAR(5)  NULL,
               SkuSize23        NVARCHAR(5)  NULL,
               SkuSize24        NVARCHAR(5)  NULL,
               SkuSize25        NVARCHAR(5)  NULL,
               SkuSize26        NVARCHAR(5)  NULL,
               SkuSize27        NVARCHAR(5)  NULL,
               SkuSize28        NVARCHAR(5)  NULL,
               SkuSize29        NVARCHAR(5)  NULL,
               SkuSize30        NVARCHAR(5)  NULL,
               SkuSize31        NVARCHAR(5)  NULL,
               SkuSize32        NVARCHAR(5)  NULL,
               Qty1             int      NULL,
               Qty2             int      NULL,
               Qty3             int      NULL,
               Qty4             int      NULL,
               Qty5             int      NULL,
               Qty6             int      NULL,
               Qty7             int      NULL,
               Qty8             int      NULL,
               Qty9             int      NULL,
               Qty10            int      NULL,
               Qty11            int      NULL,
               Qty12            int      NULL,
               Qty13            int      NULL,
               Qty14            int      NULL,
               Qty15            int      NULL,
               Qty16            int      NULL,
               Qty17            int      NULL,
               Qty18            int      NULL,
               Qty19            int      NULL,
               Qty20            int      NULL,
               Qty21            int      NULL,
               Qty22            int      NULL,
               Qty23            int      NULL,
               Qty24            int      NULL,
               Qty25            int      NULL,
               Qty26            int      NULL,
               Qty27            int      NULL,
               Qty28            int      NULL,
               Qty29            int      NULL,
               Qty30            int      NULL,
               Qty31            int      NULL,
               Qty32            int      NULL)

   --NJOW02
   CREATE TABLE #SizeSortByListName (LFloor NVARCHAR(5) NULL )

   --(Wan03) - START
   CREATE TABLE #SkuSZ
          ( Orderkey    NVARCHAR(10)   NULL
          , Storerkey   NVARCHAR(15)   NULL
          , Sku         NVARCHAR(20)   NULL
          , Size        NVARCHAR(5)    NULL
          )
   CREATE INDEX #SkuSZ_IDXKey ON #SkuSZ(Orderkey, Storerkey, Sku)
   --(Wan03) - END

   SELECT @c_TempFloor = '', @c_TempOrderKey = '', @n_Count = 0
   SELECT @c_SkuSize1='',  @c_SkuSize2='',  @c_SkuSize3='',  @c_SkuSize4=''
   SELECT @c_SkuSize5='',  @c_SkuSize6='',  @c_SkuSize7='',  @c_SkuSize8=''
   SELECT @c_SkuSize9='',  @c_SkuSize10='', @c_SkuSize11='', @c_SkuSize12=''
   SELECT @c_SkuSize13='', @c_SkuSize14='', @c_SkuSize15='', @c_SkuSize16=''
   SELECT @c_SkuSize17='', @c_SkuSize18='', @c_SkuSize19='', @c_SkuSize20=''
   SELECT @c_SkuSize21='', @c_SkuSize22='', @c_SkuSize23='', @c_SkuSize24=''
   SELECT @c_SkuSize25='', @c_SkuSize26='', @c_SkuSize27='', @c_SkuSize28=''
   SELECT @c_SkuSize29='', @c_SkuSize30='', @c_SkuSize31='', @c_SkuSize32=''

   SET @c_Sort = ''                                   --(Wan01)
   SELECT DISTINCT OrderKey
   INTO #TempOrder
   FROM LOADPLANDETAIL WITH (NOLOCK)
   WHERE LOADPLANDETAIL.LoadKey = @c_LoadKey
   
   WHILE (1 = 1)
   BEGIN
      SELECT @c_TempOrderKey = MIN(OrderKey)
      FROM #TempOrder
      WHERE OrderKey > @c_TempOrderKey

      IF ISNULL(RTRIM(@c_TempOrderKey),'') = ''
         BREAK
      
      --NJOW02
      DELETE #SizeSortByListName
      INSERT INTO #SizeSortByListName
         SELECT SUBSTRING(PD.Loc, 2, 1)
         FROM PICKDETAIL PD (NOLOCK)
         JOIN LOTATTRIBUTE LA (NOLOCK) ON PD.Lot = LA.Lot
         WHERE PD.OrderKey = @c_TempOrderKey
         AND LEFT(LA.Lottable01,2) IN('10','30')
         AND PD.Storerkey = 'CNV'
         GROUP BY SUBSTRING(PD.Loc, 2, 1)

      --(Wan03) - START  
      INSERT INTO #SKUSZ
            (   Orderkey
            ,   Storerkey
            ,   Sku
            ,   Size
              )
      SELECT DISTINCT 
             OH.Orderkey
            ,SKU.Storerkey
            ,SKU.Sku
            ,Size = CASE WHEN RCFG.ListName IS NOT NULL AND ISNULL(RTRIM(SKU.Measurement),'') <> '' 
                         THEN ISNULL(RTRIM(SKU.Measurement),'') 
                         ELSE ISNULL(RTRIM(SKU.Size),'') 
                         END   
      FROM ORDERS         OH   WITH (NOLOCK)
      JOIN PICKDETAIL     PD   WITH (NOLOCK) ON (OH.Orderkey = PD.Orderkey)
      JOIN SKU            SKU  WITH (NOLOCK) ON (SKU.Storerkey = PD.Storerkey AND SKU.SKU = PD.SKU)
      LEFT JOIN CODELKUP  RCFG WITH (NOLOCK) ON (RCFG.ListName = 'REPORTCFG')
                                             AND(RCFG.Code= 'ShowUSSize_PLIST')
                                             AND(RCFG.Storerkey= SKU.Storerkey)
                                             AND(RCFG.Long = 'r_dw_print_pickorder31')
                                             AND(ISNULL(RTRIM(RCFG.Short),'') <> 'N')
      WHERE OH.OrderKey = @c_TempOrderKey
      AND OH.Loadkey = @c_LoadKey
      --(Wan03) - END  
               
      -- Get all unique sizes for the same order and same floor
      -- tlting02 -CURSOR LOCAL
      DECLARE pick_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT ISNULL(RTRIM(SKUSZ.SIZE),'') SSize, -- SOS# 239687                                       --(Wan03)
                ORDERS.OrderKey,
                SUBSTRING(PICKDETAIL.Loc, 2, 1) LFloor
--                ISNULL(RTRIM(SKU.BUSR6),'') BUSR6 -- SOS# 239687                                       --(Wan01) - Take out BUSR6
--               , Sort = CASE WHEN ISNULL(RTRIM(SKU.SIZE),'') = '' 
--                             THEN ' ' + ISNULL(RTRIM(SKU.BUSR6),'') 
--                             ELSE ISNULL(NULLIF(RTRIM(SKU.BUSR6),''),' ') + ISNULL(RTRIM(SKU.SIZE),'')  
--                             END
         FROM PICKDETAIL WITH (NOLOCK)
         JOIN ORDERS WITH (NOLOCK) on PICKDETAIL.OrderKey = ORDERS.OrderKey
         JOIN LOADPLANDETAIL WITH (NOLOCK) on PICKDETAIL.OrderKey = LOADPLANDETAIL.OrderKey
         AND LOADPLANDETAIL.Loadkey = ORDERS.Loadkey
         JOIN SKU WITH (NOLOCK) on (SKU.SKU = PICKDETAIL.SKU AND SKU.Storerkey = PICKDETAIL.Storerkey)
         JOIN #SKUSZ  SKUSZ WITH (NOLOCK) ON (ORDERS.Orderkey = SKUSZ.Orderkey)                          --(Wan03)
                                          AND(SKU.Storerkey = SKUSZ.Storerkey AND SKU.SKU = SKUSZ.SKU)   --(Wan03)
         LEFT JOIN #SizeSortByListName ON (SUBSTRING(PICKDETAIL.Loc, 2, 1) = #SizeSortByListName.LFloor) --NJOW02
         LEFT JOIN CODELKUP (NOLOCK) ON (SKUSZ.Size = CODELKUP.Code AND CODELKUP.Listname = 'SIZELSTORD')  --NJOW02 --(Wan03)
         WHERE LOADPLANDETAIL.LoadKey = @c_LoadKey
         AND PICKDETAIL.OrderKey = @c_TempOrderKey
         AND ORDERS.OrderKey = @c_TempOrderKey
         GROUP BY ISNULL(RTRIM(SKUSZ.SIZE),''),                                                          --(Wan03)         
                  ORDERS.OrderKey,
                  SUBSTRING(PICKDETAIL.Loc, 2, 1),
                  CASE WHEN ISNULL(#SizeSortByListName.LFloor,'') <> '' THEN
                       ISNULL(CODELKUP.Short,'')
                   ELSE ISNULL(RTRIM(SKUSZ.SIZE),'') END --NJOW02                                        --(Wan03)                                                                                                
--                  ISNULL(RTRIM(SKU.BUSR6),'')                                                          --(Wan01) - Take out BUSR6
--                 ,CASE WHEN ISNULL(RTRIM(SKU.SIZE),'') = '' 
--                             THEN ' ' + ISNULL(RTRIM(SKU.BUSR6),'') 
--                             ELSE ISNULL(NULLIF(RTRIM(SKU.BUSR6),''),' ') + ISNULL(RTRIM(SKU.SIZE),'')  
--                             END
         ORDER BY ORDERS.OrderKey,
         --         LFloor, BUSR6,                                                                       --(Wan01)
         --         SSize                                                                                --(Wan01)
                  LFloor, 
                  CASE WHEN ISNULL(#SizeSortByListName.LFloor,'') <> '' THEN
                       ISNULL(CODELKUP.Short,'')
                   ELSE ISNULL(RTRIM(SKUSZ.SIZE),'') END, --NJOW02                                       --(Wan03)                                                
                  ISNULL(RTRIM(SKUSZ.SIZE),'')                                                           --(Wan03)
      OPEN pick_cur
      FETCH NEXT FROM pick_cur INTO @c_SkuSize, @c_OrderKey, @c_Floor--, @C_BUSR6                        --(Wan01) - Take out BUSR6
                                  --, @c_Sort                                                            --(Wan01)

      WHILE (@@FETCH_STATUS <> -1)
      BEGIN
         SELECT @n_Count = @n_Count + 1

         IF @b_debug = 1
         BEGIN
            SELECT 'Count of sizes is ' + CONVERT(char(5), @n_Count)
         END

         SELECT @c_SkuSize1 = CASE @n_Count WHEN 1 THEN @c_SkuSize
                                 ELSE @c_SkuSize1
                              END
         SELECT @c_SkuSize2 = CASE @n_Count WHEN 2 THEN @c_SkuSize
                              ELSE @c_SkuSize2
                              END
         SELECT @c_SkuSize3 = CASE @n_Count WHEN 3 THEN @c_SkuSize
                              ELSE @c_SkuSize3
                              END
         SELECT @c_SkuSize4 = CASE @n_Count WHEN 4 THEN @c_SkuSize
                              ELSE @c_SkuSize4
                              END
         SELECT @c_SkuSize5 = CASE @n_Count WHEN 5 THEN @c_SkuSize
                              ELSE @c_SkuSize5
                              END
         SELECT @c_SkuSize6 = CASE @n_Count WHEN 6 THEN @c_SkuSize
                              ELSE @c_SkuSize6
                              END
         SELECT @c_SkuSize7 = CASE @n_Count WHEN 7 THEN @c_SkuSize
                              ELSE @c_SkuSize7
                              END
         SELECT @c_SkuSize8 = CASE @n_Count WHEN 8 THEN @c_SkuSize
                              ELSE @c_SkuSize8
                              END
         SELECT @c_SkuSize9 = CASE @n_Count WHEN 9 THEN @c_SkuSize
                              ELSE @c_SkuSize9
                              END
         SELECT @c_SkuSize10 = CASE @n_Count WHEN 10 THEN @c_SkuSize
                               ELSE @c_SkuSize10
                               END
         SELECT @c_SkuSize11 = CASE @n_Count WHEN 11 THEN @c_SkuSize
                               ELSE @c_SkuSize11
                               END
         SELECT @c_SkuSize12 = CASE @n_Count WHEN 12 THEN @c_SkuSize
                               ELSE @c_SkuSize12
                               END
         SELECT @c_SkuSize13 = CASE @n_Count WHEN 13 THEN @c_SkuSize
                               ELSE @c_SkuSize13
                               END
         SELECT @c_SkuSize14 = CASE @n_Count WHEN 14 THEN @c_SkuSize
                               ELSE @c_SkuSize14
                               END
         SELECT @c_SkuSize15 = CASE @n_Count WHEN 15 THEN @c_SkuSize
                               ELSE @c_SkuSize15
                               END
         SELECT @c_SkuSize16 = CASE @n_Count WHEN 16 THEN @c_SkuSize
                               ELSE @c_SkuSize16
                               END
         SELECT @c_SkuSize17 = CASE @n_Count WHEN 17 THEN @c_SkuSize
                               ELSE @c_SkuSize17
                               END
         SELECT @c_SkuSize18 = CASE @n_Count WHEN 18 THEN @c_SkuSize
                               ELSE @c_SkuSize18
                               END
         SELECT @c_SkuSize19 = CASE @n_Count WHEN 19 THEN @c_SkuSize
                               ELSE @c_SkuSize19
                               END
         SELECT @c_SkuSize20 = CASE @n_Count WHEN 20 THEN @c_SkuSize
                               ELSE @c_SkuSize20
                               END
         SELECT @c_SkuSize21 = CASE @n_Count WHEN 21 THEN @c_SkuSize
                               ELSE @c_SkuSize21
                               END
         SELECT @c_SkuSize22 = CASE @n_Count WHEN 22 THEN @c_SkuSize
                               ELSE @c_SkuSize22
                               END
         SELECT @c_SkuSize23 = CASE @n_Count WHEN 23 THEN @c_SkuSize
                               ELSE @c_SkuSize23
                               END
         SELECT @c_SkuSize24 = CASE @n_Count WHEN 24 THEN @c_SkuSize
                               ELSE @c_SkuSize24
                               END
         SELECT @c_SkuSize25 = CASE @n_Count WHEN 25 THEN @c_SkuSize
                               ELSE @c_SkuSize25
                               END
         SELECT @c_SkuSize26 = CASE @n_Count WHEN 26 THEN @c_SkuSize
                               ELSE @c_SkuSize26
                               END
         SELECT @c_SkuSize27 = CASE @n_Count WHEN 27 THEN @c_SkuSize
                               ELSE @c_SkuSize27
                               END
         SELECT @c_SkuSize28 = CASE @n_Count WHEN 28 THEN @c_SkuSize
                               ELSE @c_SkuSize28
                               END
         SELECT @c_SkuSize29 = CASE @n_Count WHEN 29 THEN @c_SkuSize
                               ELSE @c_SkuSize29
                               END
         SELECT @c_SkuSize30 = CASE @n_Count WHEN 30 THEN @c_SkuSize
                               ELSE @c_SkuSize30
                               END
         SELECT @c_SkuSize31 = CASE @n_Count WHEN 31 THEN @c_SkuSize
                               ELSE @c_SkuSize31
                               END
         SELECT @c_SkuSize32 = CASE @n_Count WHEN 32 THEN @c_SkuSize
                               ELSE @c_SkuSize32
                               END

         IF @b_debug = 1
         BEGIN
            IF @c_TempOrderKey = '0000907514' -- checking any OrderKey
            BEGIN
               SELECT 'SkuSize is ' + @c_SkuSize
               SELECT 'SkuSize1 to 16 is ' + @c_SkuSize1+','+ @c_SkuSize2+','+ @c_SkuSize3+','+ @c_SkuSize4+','+
                     @c_SkuSize5+','+ @c_SkuSize6+','+ @c_SkuSize7+','+ @c_SkuSize8+','+
                     @c_SkuSize9+','+ @c_SkuSize10+','+ @c_SkuSize11+','+ @c_SkuSize12+','+
                     @c_SkuSize13+','+ @c_SkuSize14+','+ @c_SkuSize15+','+ @c_SkuSize16+','+
                     @c_SkuSize17+','+ @c_SkuSize18+','+ @c_SkuSize19+','+ @c_SkuSize20+','+
                     @c_SkuSize21+','+ @c_SkuSize22+','+ @c_SkuSize23+','+ @c_SkuSize24+','+
                     @c_SkuSize25+','+ @c_SkuSize26+','+ @c_SkuSize27+','+ @c_SkuSize28+','+
                     @c_SkuSize29+','+ @c_SkuSize30+','+ @c_SkuSize31+','+ @c_SkuSize32
            END
         END

         SELECT @c_PrevOrderKey = @c_OrderKey
         SELECT @c_PrevFloor = @c_Floor

         FETCH NEXT FROM pick_cur INTO @c_SkuSize, @c_OrderKey, @c_Floor--, @C_BUSR6                    --(Wan01) - Take out BUSR6 
                                    --,  @c_Sort                                                        --(Wan01)

         IF @b_debug = 1
         BEGIN
            SELECT 'PrevOrderKey= ' + @c_PrevOrderKey + ', OrderKey= ' + @c_OrderKey
            SELECT 'PrevFloor= ' + @c_PrevFloor + ', Floor= ' + @c_Floor
         END

         IF (@c_PrevOrderKey <> @c_OrderKey) OR
            (@c_PrevOrderKey = @c_OrderKey AND @c_PrevFloor <> @c_Floor) OR
            (@@FETCH_STATUS = -1) -- last fetch
         BEGIN
            SELECT @c_PickSlipNo = NULL

            -- Insert into temp table
            INSERT INTO #TempPickSlip
            SELECT PickHeader.PickHeaderKey,
                  LOADPLANDETAIL.Loadkey,
                  ORDERS.OrderKey,
                  ORDERS.BuyerPO,
                  ORDERS.OrderGroup,
                  ORDERS.ExternOrderKey,
                  ORDERS.Route,
                  CONVERT(NVARCHAR(255), ORDERS.Notes) Notes,
                  ORDERS.OrderDate,
                  ORDERS.ConsigneeKey,
                  ORDERS.C_Company,
                  ORDERS.DeliveryDate,
                  CONVERT(NVARCHAR(255), ORDERS.Notes2) Notes2,
                  ISNULL(RTRIM(ORDERS.InvoiceNo),'') InvoiceNo,                                    --(Wan02)
                  --SUBSTRING(PICKDETAIL.Loc, 1, 7),                                               --(Wan01)
                  ISNULL(RTRIM(PICKDETAIL.Loc),''),                                                --(Wan01)
                  LOC.LogicalLocation,    -- GOH01
                  ISNULL(RTRIM(SKU.Style),'') + ISNULL(RTRIM(SKU.Color),'') StyleColor,
                  PACK.PackUom3 UOM,
                  SUBSTRING(PICKDETAIL.Loc, 2, 1) LFloor,
                  SUBSTRING(PICKDETAIL.Loc, 7, 2) Bin,
                  Loc.PutawayZone,
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
                  -- SOS29528
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
                  --(Wan03) - START
                  CASE WHEN SKUSZ.SIZE = @c_SkuSize1 --AND ISNULL(SKU.Size,'') <> ''
                                 THEN SUM(PICKDETAIL.Qty)
                                 ELSE 0
                                 END,
                  CASE WHEN SKUSZ.SIZE = @c_SkuSize2 AND ISNULL(SKUSZ.Size,'') <> ''
                                 THEN SUM(PICKDETAIL.Qty)
                                 ELSE 0
                                 END,
                  CASE WHEN SKUSZ.SIZE = @c_SkuSize3 AND ISNULL(SKUSZ.Size,'') <> ''
                                 THEN SUM(PICKDETAIL.Qty)
                                 ELSE 0
                                 END,
                  CASE WHEN SKUSZ.SIZE = @c_SkuSize4 AND ISNULL(SKUSZ.Size,'') <> ''
                                 THEN SUM(PICKDETAIL.Qty)
                                 ELSE 0
                                 END,
                  CASE WHEN SKUSZ.SIZE = @c_SkuSize5 AND ISNULL(SKUSZ.Size,'') <> ''
                                 THEN SUM(PICKDETAIL.Qty)
                                 ELSE 0
                                 END,
                  CASE WHEN SKUSZ.SIZE = @c_SkuSize6 AND ISNULL(SKUSZ.Size,'') <> ''
                                 THEN SUM(PICKDETAIL.Qty)
                                 ELSE 0
                                 END,
                  CASE WHEN SKUSZ.SIZE = @c_SkuSize7 AND ISNULL(SKUSZ.Size,'') <> ''
                                 THEN SUM(PICKDETAIL.Qty)
                                 ELSE 0
                                 END,
                  CASE WHEN SKUSZ.SIZE = @c_SkuSize8 AND ISNULL(SKUSZ.Size,'') <> ''
                                 THEN SUM(PICKDETAIL.Qty)
                                 ELSE 0
                                 END,
                  CASE WHEN SKUSZ.SIZE = @c_SkuSize9 AND ISNULL(SKUSZ.Size,'') <> ''
                                 THEN SUM(PICKDETAIL.Qty)
                                 ELSE 0
                                 END,
                  CASE WHEN SKUSZ.SIZE = @c_SkuSize10 AND ISNULL(SKUSZ.Size,'') <> ''
                                 THEN SUM(PICKDETAIL.Qty)
                                 ELSE 0
                                 END,
                  CASE WHEN SKUSZ.SIZE = @c_SkuSize11 AND ISNULL(SKUSZ.Size,'') <> ''
                                 THEN SUM(PICKDETAIL.Qty)
                                 ELSE 0
                                 END,
                  CASE WHEN SKUSZ.SIZE = @c_SkuSize12 AND ISNULL(SKUSZ.Size,'') <> ''
                                 THEN SUM(PICKDETAIL.Qty)
                                 ELSE 0
                                 END,
                  CASE WHEN SKUSZ.SIZE = @c_SkuSize13 AND ISNULL(SKUSZ.Size,'') <> ''
                                 THEN SUM(PICKDETAIL.Qty)
                                 ELSE 0
                                 END,
                  CASE WHEN SKUSZ.SIZE = @c_SkuSize14 AND ISNULL(SKUSZ.Size,'') <> ''
                                 THEN SUM(PICKDETAIL.Qty)
                                 ELSE 0
                                 END,
                  CASE WHEN SKUSZ.SIZE = @c_SkuSize15 AND ISNULL(SKUSZ.Size,'') <> ''
                                 THEN SUM(PICKDETAIL.Qty)
                                 ELSE 0
                                 END,
                  CASE WHEN SKUSZ.SIZE = @c_SkuSize16 AND ISNULL(SKUSZ.Size,'') <> ''
                                 THEN SUM(PICKDETAIL.Qty)
                                 ELSE 0
                                 END,
                  -- SOS29528   
                  CASE WHEN SKUSZ.SIZE = @c_SkuSize17 AND ISNULL(SKUSZ.Size,'') <> ''
                                 THEN SUM(PICKDETAIL.Qty)
                                 ELSE 0
                                 END,
                  CASE WHEN SKUSZ.SIZE = @c_SkuSize18 AND ISNULL(SKUSZ.Size,'') <> ''
                                 THEN SUM(PICKDETAIL.Qty)
                                 ELSE 0
                                 END,
                  CASE WHEN SKUSZ.SIZE = @c_SkuSize19 AND ISNULL(SKUSZ.Size,'') <> ''
                                 THEN SUM(PICKDETAIL.Qty)
                                 ELSE 0
                                 END,
                  CASE WHEN SKUSZ.SIZE = @c_SkuSize20 AND ISNULL(SKUSZ.Size,'') <> ''
                                 THEN SUM(PICKDETAIL.Qty)
                                 ELSE 0
                                 END,
                  CASE WHEN SKUSZ.SIZE = @c_SkuSize21 AND ISNULL(SKUSZ.Size,'') <> ''
                                 THEN SUM(PICKDETAIL.Qty)
                                 ELSE 0
                                 END,
                  CASE WHEN SKUSZ.SIZE = @c_SkuSize22 AND ISNULL(SKUSZ.Size,'') <> ''
                                 THEN SUM(PICKDETAIL.Qty)
                                 ELSE 0
                                 END,
                  CASE WHEN SKUSZ.SIZE = @c_SkuSize23 AND ISNULL(SKUSZ.Size,'') <> ''
                                 THEN SUM(PICKDETAIL.Qty)
                                 ELSE 0
                                 END,
                  CASE WHEN SKUSZ.SIZE = @c_SkuSize24 AND ISNULL(SKUSZ.Size,'') <> ''
                                 THEN SUM(PICKDETAIL.Qty)
                                 ELSE 0
                                 END,
                  CASE WHEN SKUSZ.SIZE = @c_SkuSize25 AND ISNULL(SKUSZ.Size,'') <> ''
                                 THEN SUM(PICKDETAIL.Qty)
                                 ELSE 0
                                 END,
                  CASE WHEN SKUSZ.SIZE = @c_SkuSize26 AND ISNULL(SKUSZ.Size,'') <> ''
                                 THEN SUM(PICKDETAIL.Qty)
                                 ELSE 0
                                 END,
                  CASE WHEN SKUSZ.SIZE = @c_SkuSize27 AND ISNULL(SKUSZ.Size,'') <> ''
                                 THEN SUM(PICKDETAIL.Qty)
                                 ELSE 0
                                 END,
                  CASE WHEN SKUSZ.SIZE = @c_SkuSize28 AND ISNULL(SKUSZ.Size,'') <> ''
                                 THEN SUM(PICKDETAIL.Qty)
                                 ELSE 0
                                 END,
                  CASE WHEN SKUSZ.SIZE = @c_SkuSize29 AND ISNULL(SKUSZ.Size,'') <> ''
                                 THEN SUM(PICKDETAIL.Qty)
                                 ELSE 0
                                 END,
                  CASE WHEN SKUSZ.SIZE = @c_SkuSize30 AND ISNULL(SKUSZ.Size,'') <> ''
                                 THEN SUM(PICKDETAIL.Qty)
                                 ELSE 0
                                 END,
                  CASE WHEN SKUSZ.SIZE = @c_SkuSize31 AND ISNULL(SKUSZ.Size,'') <> ''
                                 THEN SUM(PICKDETAIL.Qty)
                                 ELSE 0
                                 END,
                  CASE WHEN SKUSZ.SIZE = @c_SkuSize32 AND ISNULL(SKUSZ.Size,'') <> ''
                                     THEN SUM(PICKDETAIL.Qty)
                                     ELSE 0
                                     END
                  --(Wan03) - END
            FROM PICKDETAIL WITH (NOLOCK)
            JOIN ORDERS WITH (NOLOCK) ON PICKDETAIL.OrderKey = ORDERS.OrderKey
            JOIN PACK WITH (NOLOCK) ON PICKDETAIL.Packkey = PACK.Packkey
            JOIN LOADPLANDETAIL WITH (NOLOCK) ON PICKDETAIL.OrderKey = LOADPLANDETAIL.OrderKey AND
                                                 LOADPLANDETAIL.Loadkey = ORDERS.Loadkey
            LEFT OUTER JOIN PICKHEADER WITH (NOLOCK) ON PICKHEADER.OrderKey = ORDERS.OrderKey
            JOIN SKU WITH (NOLOCK) ON (SKU.SKU = PICKDETAIL.SKU AND SKU.Storerkey = PICKDETAIL.Storerkey)
            JOIN #SKUSZ  SKUSZ WITH (NOLOCK) ON (ORDERS.Orderkey = SKUSZ.Orderkey)                          --(Wan03)
                                             AND(SKU.Storerkey = SKUSZ.Storerkey AND SKU.SKU = SKUSZ.SKU)   --(Wan03)
            JOIN LOC WITH (NOLOCK) ON (LOC.LOC = PICKDETAIL.LOC)
            WHERE LOADPLANDETAIL.LoadKey = @c_LoadKey
            AND ORDERS.OrderKey = @c_PrevOrderKey
            AND PICKDETAIL.OrderKey = @c_PrevOrderKey
            AND SUBSTRING(PICKDETAIL.Loc, 2, 1) = @c_PrevFloor
            AND 1=CASE SKUSZ.SIZE WHEN @c_SkuSize1 THEN 1                                                   --(Wan03)
                                  WHEN @c_SkuSize2 THEN 1
                                  WHEN @c_SkuSize3 THEN 1
                                  WHEN @c_SkuSize4 THEN 1
                                  WHEN @c_SkuSize5 THEN 1
                                  WHEN @c_SkuSize6 THEN 1
                                  WHEN @c_SkuSize7 THEN 1
                                  WHEN @c_SkuSize8 THEN 1
                                  WHEN @c_SkuSize9 THEN 1
                                  WHEN @c_SkuSize10 THEN 1
                                  WHEN @c_SkuSize11 THEN 1
                                  WHEN @c_SkuSize12 THEN 1
                                  WHEN @c_SkuSize13 THEN 1
                                  WHEN @c_SkuSize14 THEN 1
                                  WHEN @c_SkuSize15 THEN 1
                                  WHEN @c_SkuSize16 THEN 1
                                  -- SOS29528
                                  WHEN @c_SkuSize17 THEN 1
                                  WHEN @c_SkuSize18 THEN 1
                                  WHEN @c_SkuSize19 THEN 1
                                  WHEN @c_SkuSize20 THEN 1
                                  WHEN @c_SkuSize21 THEN 1
                                  WHEN @c_SkuSize22 THEN 1
                                  WHEN @c_SkuSize23 THEN 1
                                  WHEN @c_SkuSize24 THEN 1
                                  WHEN @c_SkuSize25 THEN 1
                                  WHEN @c_SkuSize26 THEN 1
                                  WHEN @c_SkuSize27 THEN 1
                                  WHEN @c_SkuSize28 THEN 1
                                  WHEN @c_SkuSize29 THEN 1
                                  WHEN @c_SkuSize30 THEN 1
                                  WHEN @c_SkuSize31 THEN 1
                                  WHEN @c_SkuSize32 THEN 1
                    ELSE 0
                    END
            GROUP BY LOADPLANDETAIL.Loadkey,
                     ORDERS.OrderKey,
                     ORDERS.BuyerPO,
                     ORDERS.OrderGroup,
                     ORDERS.ExternOrderKey,
                     ORDERS.Route,
                     CONVERT(NVARCHAR(255), ORDERS.Notes),
                     ORDERS.OrderDate,
                     ORDERS.ConsigneeKey,
                     ORDERS.C_Company,
                     ORDERS.DeliveryDate,
                     CONVERT(NVARCHAR(255), ORDERS.Notes2),
                     ISNULL(RTRIM(ORDERS.InvoiceNo),''),                                           --(Wan02)
                     --SUBSTRING(PICKDETAIL.Loc, 1, 7),                                            --(Wan01)
                     ISNULL(RTRIM(PICKDETAIL.Loc),''),                                             --(Wan01)
                     LOC.LogicalLocation,    --GOH01
                     ISNULL(RTRIM(SKU.Style),'') + ISNULL(RTRIM(SKU.Color),''),
                     SKUSZ.SIZE,                                                                   --(Wan03)
                     PACK.PackUom3,
                     SUBSTRING(PICKDETAIL.Loc, 2, 1),
                     SUBSTRING(PICKDETAIL.Loc, 7, 2),
                     Loc.PutawayZone,
                     PickHeader.PickHeaderKey
            ORDER BY ORDERS.OrderKey,
                     LFloor,
                     Bin,
                     StyleColor,
                     UOM

            -- Reset counter and skusize
            SELECT @n_Count = 0
            SELECT @c_SkuSize1='',  @c_SkuSize2='',  @c_SkuSize3='',  @c_SkuSize4=''
            SELECT @c_SkuSize5='',  @c_SkuSize6='',  @c_SkuSize7='',  @c_SkuSize8=''
            SELECT @c_SkuSize9='',  @c_SkuSize10='', @c_SkuSize11='', @c_SkuSize12=''
            SELECT @c_SkuSize13='', @c_SkuSize14='', @c_SkuSize15='', @c_SkuSize16=''
            SELECT @c_SkuSize17='', @c_SkuSize18='', @c_SkuSize19='', @c_SkuSize20=''
            SELECT @c_SkuSize21='', @c_SkuSize22='', @c_SkuSize23='', @c_SkuSize24=''
            SELECT @c_SkuSize25='', @c_SkuSize26='', @c_SkuSize27='', @c_SkuSize28=''
            SELECT @c_SkuSize29='', @c_SkuSize30='', @c_SkuSize31='', @c_SkuSize32=''
         END
      END -- WHILE (@@FETCH_STATUS <> -1)
      CLOSE pick_cur
      DEALLOCATE pick_cur

      DECLARE @n_pickslips_required int,
              @c_NextNo             NVARCHAR(9),
              @min                  int,
              @max                  int,
              @c_HCTNo              NVARCHAR(12)

      -- tlting02  performance tune
      SET @n_pickslips_required = 0
      SELECT @n_pickslips_required = COUNT(1)
      FROM (SELECT (OrderKey)
            FROM #TempPickSlip WITH (NOLOCK)
            WHERE ISNULL(RTRIM(PickSlipNo), '') = ''
            GROUP BY OrderKey) A

      IF @@ERROR <> 0
      BEGIN
         GOTO FAILURE
      END
      ELSE IF @n_pickslips_required > 0
      BEGIN
         EXECUTE nspg_GetKey
               'PICKSLIP'
               , 9
               , @c_NextNo  OUTPUT
               , @b_success OUTPUT
               , @n_err     OUTPUT
               , @c_errmsg  OUTPUT
               , 0
               , @n_pickslips_required

         IF @b_success <> 1
         BEGIN
            GOTO FAILURE
         END

         SELECT @c_OrderKey = ''

         WHILE 1 = 1
         BEGIN
            SELECT @c_OrderKey = MIN(OrderKey)
            FROM   #TempPickSlip WITH (NOLOCK)
            WHERE  OrderKey > @c_OrderKey
            AND    ISNULL(RTRIM(PickSlipNo),'') = ''

            IF ISNULL(RTRIM(@c_OrderKey),'') = ''
               BREAK

            IF NOT EXISTS(SELECT 1 FROM PickHeader WITH (NOLOCK) WHERE OrderKey = @c_OrderKey)
            BEGIN
               SELECT @c_PickSlipNo = 'P' + @c_NextNo
               SELECT @c_NextNo = RIGHT ( REPLICATE ('0', 9) + dbo.fnc_LTrim( dbo.fnc_RTrim( STR( CAST(@c_NextNo AS INT) + 1))), 9)

               IF EXISTS(SELECT 1 FROM ORDERS WITH (NOLOCK) WHERE OrderKey = @c_OrderKey AND Orders.IntermodalVehicle = 'ILOT')
               BEGIN
                  SET @c_HCTNo = ''

                  SELECT @min = CAST(dbo.fnc_LTrim(dbo.fnc_RTrim(Short)) AS INT)
                       , @max = CAST(dbo.fnc_LTrim(dbo.fnc_RTrim(Long)) AS INT)
                  FROM CodeLkUp WITH (NOLOCK)
                  WHERE ListName='HCTNO'

                  EXECUTE nspg_GetKeyMinMax
                           'HCTNO'
                           , 10
                           , @min
                           , @max
                           , @c_HCTNo   OUTPUT
                           , @b_success OUTPUT
                           , @n_err     OUTPUT
                           , @c_errmsg  OUTPUT
                           , 0
                           , 1

                  SET @c_HCTNo = RIGHT (dbo.fnc_RTrim(@c_HCTNo) + CAST((@c_HCTNo % 7) AS NVARCHAR(1)), 10)
                  SET @c_HCTNo = RIGHT (REPLICATE ('0', 10) + dbo.fnc_RTrim(@c_HCTNo), 10)

                  IF CAST(@c_HCTNo AS INT) >= (@max * 10)
                  BEGIN
                     --SELECT 'FAIL @c_HCTNo =' + CAST(@c_HCTNo AS CHAR)+ '>= @mAX=' + CAST(@mAX AS CHAR) -- FOR TESTING ONLY
                     SET @c_HCTNo = ''
                  END
               END
               ELSE
               BEGIN
                  SET @c_HCTNo = ''
               END

               BEGIN TRAN
               IF NOT EXISTS (SELECT 1 FROM PickHeader WITH (NOLOCK) WHERE PickHeaderKey = @c_PickSlipNo)
               BEGIN
                  INSERT INTO PickHeader (PickHeaderKey, OrderKey, ExternOrderKey, PickType, Zone, TrafficCop, ConsigneeKey)
                  VALUES (@c_PickSlipNo, @c_OrderKey, @c_LoadKey, '0', '8', '', @c_HCTNo)
               END

               SELECT @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                  IF @@TRANCOUNT >= 1
                  BEGIN
                     ROLLBACK TRAN
                     GOTO FAILURE
                  END
               END
               ELSE
               BEGIN
                  IF @@TRANCOUNT > 0
                  BEGIN
                     COMMIT TRAN
                  END
                  ELSE
                  BEGIN
                     ROLLBACK TRAN
                     GOTO FAILURE
                  END
               END -- @n_err <> 0
            END -- NOT EXISTS
         END   -- WHILE

         UPDATE #TempPickSlip
         SET PickSlipNo = PICKHEADER.PickHeaderKey
         FROM  PICKHEADER WITH (NOLOCK)
         WHERE PICKHEADER.ExternOrderKey = #TempPickSlip.LoadKey
         AND   PICKHEADER.OrderKey = #TempPickSlip.OrderKey
         AND   PICKHEADER.Zone = '8'
         AND   ISNULL(RTRIM(#TempPickSlip.PickSlipNo),'') = ''

      END
      GOTO SUCCESS

 FAILURE:
     DELETE FROM #TempPickSlip
     RETURN

 SUCCESS:
      -- Added By SHONG. Do Auto Scan-in SOS#28999
      DECLARE @cPickSlipNo NVARCHAR(10)
      SELECT @cPickSlipNo = ''

      DECLARE C_PickSlip CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT #TempPickSlip.PickSlipNo
         FROM #TempPickSlip WITH (NOLOCK)
         LEFT JOIN PickingInfo WITH (NOLOCK) ON (#TempPickSlip.PickSlipNo = PickingInfo.PickSlipNo)
         WHERE ISNULL(RTRIM(PickingInfo.PickSlipNo),'') = ''
         ORDER BY #TempPickSlip.PickSlipNo

      OPEN C_PickSlip
      FETCH NEXT FROM C_PickSlip INTO @cPickSlipNo

      WHILE (@@FETCH_STATUS <> -1)
      BEGIN
         IF NOT EXISTS(SELECT 1 FROM PickingInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo )
         BEGIN
            INSERT INTO PickingInfo (PickSlipNo, ScanInDate, PickerID, ScanOutDate)
            VALUES (@cPickSlipNo, GetDate(), sUser_sName(), NULL)
         END

         FETCH NEXT FROM C_PickSlip INTO @cPickSlipNo
      END
      CLOSE C_PickSlip
      DEALLOCATE C_PickSlip
   END -- WHILE (1 = 1)

   SELECT PickSlipNo, Loadkey, OrderKey, BuyerPO, OrderGroup, ExternOrderKey, Route, Notes, OrderDate,
         ConsigneeKey, Company, DeliveryDate, Notes2, Loc, StyleColor, UOM, LFloor, Bin, PutawayZone,
         SkuSize1, SkuSize2, SkuSize3, SkuSize4, SkuSize5, SkuSize6, SkuSize7, SkuSize8,
         SkuSize9, SkuSize10, SkuSize11, SkuSize12, SkuSize13, SkuSize14, SkuSize15, SkuSize16,
         -- SOS29528
         SkuSize17, SkuSize18, SkuSize19, SkuSize20, SkuSize21, SkuSize22, SkuSize23, SkuSize24,
         SkuSize25, SkuSize26, SkuSize27, SkuSize28, SkuSize29, SkuSize30, SkuSize31, SkuSize32,
         SUM(Qty1) Qty1, SUM(Qty2) Qty2, SUM(Qty3) Qty3, SUM(Qty4) Qty4, SUM(Qty5) Qty5, SUM(Qty6) Qty6,
         SUM(Qty7) Qty7, SUM(Qty8) Qty8, SUM(Qty9) Qty9, SUM(Qty10) Qty10, SUM(Qty11) Qty11, SUM(Qty12) Qty12,
         SUM(Qty13) Qty13, SUM(Qty14) Qty14, SUM(Qty15) Qty15, SUM(Qty16) Qty16,
         -- SOS29528
         SUM(Qty17) Qty17, SUM(Qty18) Qty18, SUM(Qty19) Qty19, SUM(Qty20) Qty20, SUM(Qty21) Qty21, SUM(Qty22) Qty22,
         SUM(Qty23) Qty23, SUM(Qty24) Qty24, SUM(Qty25) Qty25, SUM(Qty26) Qty26, SUM(Qty27) Qty27, SUM(Qty28) Qty28,
         SUM(Qty29) Qty29, SUM(Qty30) Qty30, SUM(Qty31) Qty31, SUM(Qty32) Qty32
         ,LogicalLocation     --GOH01
         ,InvoiceNo           --(Wan02)
   FROM #TempPickSlip WITH (NOLOCK)
   GROUP BY PickSlipNo, Loadkey, OrderKey, BuyerPO, OrderGroup, ExternOrderKey, Route, Notes, OrderDate,
            ConsigneeKey, Company, DeliveryDate, Notes2, Loc, StyleColor, UOM, LFloor, Bin, PutawayZone,
            SkuSize1, SkuSize2, SkuSize3, SkuSize4, SkuSize5, SkuSize6, SkuSize7, SkuSize8,
            SkuSize9, SkuSize10, SkuSize11, SkuSize12, SkuSize13, SkuSize14, SkuSize15, SkuSize16,
            -- SOS29528
            SkuSize17, SkuSize18, SkuSize19, SkuSize20, SkuSize21, SkuSize22, SkuSize23, SkuSize24,
            SkuSize25, SkuSize26, SkuSize27, SkuSize28, SkuSize29, SkuSize30, SkuSize31, SkuSize32
            , LogicalLocation --GOH01
            , InvoiceNo       --(Wan02)

   DROP TABLE #TempOrder
   DROP TABLE #TempPickSlip
END

GO