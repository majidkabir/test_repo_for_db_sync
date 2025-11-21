SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: nsp_GetPickSlipNike02                               */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: Generate PickSlip                                           */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
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
/* 26-Jun-2012  SPChin        SOS247512 - Remove debug message          */
/* 17-Feb-2015  Leong         SOS#333779 - Include SKU.Busr6.           */
/*                            (Ref: nsp_GetPackSlipNike01)              */
/* 24-Aug-2017  JihHaur       IN00430773 Missing 1 char at Loc (JH01)   */
/* 28-Jan-2019  TLTING_ext 1.1  enlarge externorderkey field length      */
/* 20-SEP-2019  CSCHONG       WMS-10617 revised field logic (CS01)      */
/************************************************************************/

CREATE PROC [dbo].[nsp_GetPickSlipNike02] (@c_LoadKey NVARCHAR(10))
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   DECLARE @b_debug INT
   SELECT @b_debug = 0

   DECLARE
   @c_PickSlipNo      NVARCHAR(10),
   @c_OrderKey        NVARCHAR(10),
   @c_BuyerPO         NVARCHAR(20),
   @c_OrderGroup      NVARCHAR(10),
   @c_ExternOrderKey  NVARCHAR(50),   --tlting_ext
   @c_Route           NVARCHAR(10),
   @c_Notes           NVARCHAR(255),
   @d_OrderDate       DATETIME,
   @c_ConsigneeKey    NVARCHAR(15),
   @c_Company         NVARCHAR(45),
   @d_DeliveryDate    DATETIME,
   @c_Notes2          NVARCHAR(255),
   @c_Loc             NVARCHAR(10),
   @c_Sku             NVARCHAR(20),
   @c_UOM             NVARCHAR(10),
   @c_SkuSize         NVARCHAR(5),
   @n_Qty             INT,
   @c_Floor           NVARCHAR(1),
   @c_TempOrderKey    NVARCHAR(10),
   @c_TempFloor       NVARCHAR(1),
   @c_TempSize        NVARCHAR(5),
   @n_TempQty         INT,
   @c_PrevOrderKey    NVARCHAR(10),
   @c_PrevFloor       NVARCHAR(1),
   @b_success         INT,
   @n_err             INT,
   @c_errmsg          NVARCHAR(255),
   @n_Count           INT,
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
   @n_Qty1            INT,
   @n_Qty2            INT,
   @n_Qty3            INT,
   @n_Qty4            INT,
   @n_Qty5            INT,
   @n_Qty6            INT,
   @n_Qty7            INT,
   @n_Qty8            INT,
   @n_Qty9            INT,
   @n_Qty10           INT,
   @n_Qty11           INT,
   @n_Qty12           INT,
   @n_Qty13           INT,
   @n_Qty14           INT,
   @n_Qty15           INT,
   @n_Qty16           INT,
   @n_Qty17           INT,
   @n_Qty18           INT,
   @n_Qty19           INT,
   @n_Qty20           INT,
   @n_Qty21           INT,
   @n_Qty22           INT,
   @n_Qty23           INT,
   @n_Qty24           INT,
   @n_Qty25           INT,
   @n_Qty26           INT,
   @n_Qty27           INT,
   @n_Qty28           INT,
   @n_Qty29           INT,
   @n_Qty30           INT,
   @n_Qty31           INT,
   @n_Qty32           INT,
   @c_Bin             NVARCHAR(2),
   @C_BUSR6           NVARCHAR(30),
   @c_BUSR6_01        NVARCHAR(30), -- SOS# 333779
   @c_BUSR6_02        NVARCHAR(30),
   @c_BUSR6_03        NVARCHAR(30),
   @c_BUSR6_04        NVARCHAR(30),
   @c_BUSR6_05        NVARCHAR(30),
   @c_BUSR6_06        NVARCHAR(30),
   @c_BUSR6_07        NVARCHAR(30),
   @c_BUSR6_08        NVARCHAR(30),
   @c_BUSR6_09        NVARCHAR(30),
   @c_BUSR6_10        NVARCHAR(30),
   @c_BUSR6_11        NVARCHAR(30),
   @c_BUSR6_12        NVARCHAR(30),
   @c_BUSR6_13        NVARCHAR(30),
   @c_BUSR6_14        NVARCHAR(30),
   @c_BUSR6_15        NVARCHAR(30),
   @c_BUSR6_16        NVARCHAR(30),
   @c_BUSR6_17        NVARCHAR(30),
   @c_BUSR6_18        NVARCHAR(30),
   @c_BUSR6_19        NVARCHAR(30),
   @c_BUSR6_20        NVARCHAR(30),
   @c_BUSR6_21        NVARCHAR(30),
   @c_BUSR6_22        NVARCHAR(30),
   @c_BUSR6_23        NVARCHAR(30),
   @c_BUSR6_24        NVARCHAR(30),
   @c_BUSR6_25        NVARCHAR(30),
   @c_BUSR6_26        NVARCHAR(30),
   @c_BUSR6_27        NVARCHAR(30),
   @c_BUSR6_28        NVARCHAR(30),
   @c_BUSR6_29        NVARCHAR(30),
   @c_BUSR6_30        NVARCHAR(30),
   @c_BUSR6_31        NVARCHAR(30),
   @c_BUSR6_32        NVARCHAR(30),
   @c_SkuSize33       NVARCHAR(5),       --CS01   
   @c_SkuSize34       NVARCHAR(5),       --CS01   
   @c_SkuSize35       NVARCHAR(5),       --CS01   
   @c_SkuSize36       NVARCHAR(5),       --CS01   
   @c_size            NVARCHAR(20),      --CS01
   @c_MoreField       NVARCHAR(30)       --CS01


   CREATE TABLE #TempPickSlip
      (  PickSlipNo     NVARCHAR(10) NULL,
         Loadkey        NVARCHAR(10) NULL,
         OrderKey       NVARCHAR(10) NULL,
         BuyerPO        NVARCHAR(20) NULL,
         OrderGroup     NVARCHAR(10) NULL,
         ExternOrderKey NVARCHAR(50) NULL,   --tlting_ext
         Route          NVARCHAR(10) NULL,
         Notes          NVARCHAR(255)NULL,
         OrderDate      DATETIME     NULL,
         ConsigneeKey   NVARCHAR(15) NULL,
         Company        NVARCHAR(45) NULL,
         DeliveryDate   DATETIME     NULL,
         Notes2         NVARCHAR(255)NULL,
         Loc            NVARCHAR(10) NULL,
         Sku            NVARCHAR(20) NULL,
         UOM            NVARCHAR(10) NULL,
         LFloor         NVARCHAR(5) NULL,
         Bin            NVARCHAR(2) NULL,
         SkuSize1       NVARCHAR(5) NULL,
         SkuSize2       NVARCHAR(5) NULL,
         SkuSize3       NVARCHAR(5) NULL,
         SkuSize4       NVARCHAR(5) NULL,
         SkuSize5       NVARCHAR(5) NULL,
         SkuSize6       NVARCHAR(5) NULL,
         SkuSize7       NVARCHAR(5) NULL,
         SkuSize8       NVARCHAR(5) NULL,
         SkuSize9       NVARCHAR(5) NULL,
         SkuSize10      NVARCHAR(5) NULL,
         SkuSize11      NVARCHAR(5) NULL,
         SkuSize12      NVARCHAR(5) NULL,
         SkuSize13      NVARCHAR(5) NULL,
         SkuSize14      NVARCHAR(5) NULL,
         SkuSize15      NVARCHAR(5) NULL,
         SkuSize16      NVARCHAR(5) NULL,
         SkuSize17      NVARCHAR(5) NULL,
         SkuSize18      NVARCHAR(5) NULL,
         SkuSize19      NVARCHAR(5) NULL,
         SkuSize20      NVARCHAR(5) NULL,
         SkuSize21      NVARCHAR(5) NULL,
         SkuSize22      NVARCHAR(5) NULL,
         SkuSize23      NVARCHAR(5) NULL,
         SkuSize24      NVARCHAR(5) NULL,
         SkuSize25      NVARCHAR(5) NULL,
         SkuSize26      NVARCHAR(5) NULL,
         SkuSize27      NVARCHAR(5) NULL,
         SkuSize28      NVARCHAR(5) NULL,
         SkuSize29      NVARCHAR(5) NULL,
         SkuSize30      NVARCHAR(5) NULL,
         SkuSize31      NVARCHAR(5) NULL,
         SkuSize32      NVARCHAR(5) NULL,
         Qty1           INT NULL,
         Qty2           INT NULL,
         Qty3           INT NULL,
         Qty4           INT NULL,
         Qty5           INT NULL,
         Qty6           INT NULL,
         Qty7           INT NULL,
         Qty8           INT NULL,
         Qty9           INT NULL,
         Qty10          INT NULL,
         Qty11          INT NULL,
         Qty12          INT NULL,
         Qty13          INT NULL,
         Qty14          INT NULL,
         Qty15          INT NULL,
         Qty16          INT NULL,
         Qty17          INT NULL,
         Qty18          INT NULL,
         Qty19          INT NULL,
         Qty20          INT NULL,
         Qty21          INT NULL,
         Qty22          INT NULL,
         Qty23          INT NULL,
         Qty24          INT NULL,
         Qty25          INT NULL,
         Qty26          INT NULL,
         Qty27          INT NULL,
         Qty28          INT NULL,
         Qty29          INT NULL,
         Qty30          INT NULL,
         Qty31          INT NULL,
         Qty32          INT NULL,
		 SkuSize33      NVARCHAR(5) NULL,         --CS01 Start     
         SkuSize34      NVARCHAR(5) NULL,                          
         SkuSize35      NVARCHAR(5) NULL,                          
         SkuSize36      NVARCHAR(5) NULL,                          
         Qty33          INT      NULL,                             
         Qty34          INT      NULL,                             
         Qty35          INT      NULL,                             
         Qty36          INT      NULL,                             
         MoreField      NVARCHAR(30) NULL)        --CS01 End  


   SELECT @c_TempFloor = '', @c_TempOrderKey = '', @n_Count = 0
   SELECT @c_SkuSize1='',  @c_SkuSize2='',  @c_SkuSize3='',  @c_SkuSize4=''
   SELECT @c_SkuSize5='',  @c_SkuSize6='',  @c_SkuSize7='',  @c_SkuSize8=''
   SELECT @c_SkuSize9='',  @c_SkuSize10='', @c_SkuSize11='', @c_SkuSize12=''
   SELECT @c_SkuSize13='', @c_SkuSize14='', @c_SkuSize15='', @c_SkuSize16=''
   SELECT @c_SkuSize17='', @c_SkuSize18='', @c_SkuSize19='', @c_SkuSize20=''
   SELECT @c_SkuSize21='', @c_SkuSize22='', @c_SkuSize23='', @c_SkuSize24=''
   SELECT @c_SkuSize25='', @c_SkuSize26='', @c_SkuSize27='', @c_SkuSize28=''
   SELECT @c_SkuSize29='', @c_SkuSize30='', @c_SkuSize31='', @c_SkuSize32=''
   SELECT @c_SkuSize33='', @c_SkuSize34='', @c_SkuSize35='', @c_SkuSize36=''         --CS01
   SELECT @c_MoreField = ''                                                                


   SELECT DISTINCT OrderKey
   INTO #TempOrder
   FROM LOADPLANDETAIL (NOLOCK)
   WHERE LOADPLANDETAIL.LoadKey = @c_LoadKey

   WHILE (1=1)
   BEGIN
      SELECT @c_TempOrderKey = MIN(OrderKey)
      FROM #TempOrder
      WHERE OrderKey > @c_TempOrderKey

      IF @c_TempOrderKey IS NULL OR @c_TempOrderKey = ''  BREAK

      -- Get all unique sizes for the same order and same floor
      -- tlting02 -CURSOR LOCAL
      DECLARE pick_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(PICKDETAIL.Sku)), 10, 5)) SSize,   -- (tlting01)
            ORDERS.Orderkey,
            SUBSTRING(PICKDETAIL.Loc, 2, 1) LFloor,
            '' BUSR6 --,SKU.BUSR6 BUSR6      --CS01
			,CASE WHEN ISNUMERIC(C.short) = 1 THEN CAST(CAST(C.Short as Float) as nvarchar(10)) ELSE C.Short END  --CS01
      FROM PICKDETAIL (NOLOCK)
      JOIN ORDERS (NOLOCK) on PICKDETAIL.OrderKey = ORDERS.OrderKey
      JOIN LOADPLANDETAIL (NOLOCK) on PICKDETAIL.OrderKey = LOADPLANDETAIL.OrderKey
      AND LOADPLANDETAIL.Loadkey = ORDERS.Loadkey
      JOIN SKU (NOLOCK) on (SKU.SKU = PICKDETAIL.SKU AND SKU.Storerkey = PICKDETAIL.Storerkey)
	   --CS01 Start
      LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'SIZELSTORD' AND C.storerkey = PICKDETAIL.storerkey 
                                     AND C.code = dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(PICKDETAIL.Sku)), 10, 5))
      --CS01 End
      WHERE LOADPLANDETAIL.LoadKey = @c_LoadKey
      AND PICKDETAIL.OrderKey = @c_TempOrderKey
      AND ORDERS.OrderKey = @c_TempOrderKey
      GROUP BY dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(PICKDETAIL.Sku)), 10, 5)),     -- (tlting01)
               ORDERS.OrderKey,
               SUBSTRING(PICKDETAIL.Loc, 2, 1),
               --BUSR6
			   CASE WHEN ISNUMERIC(C.short) = 1 THEN CAST(CAST(C.Short as Float) as nvarchar(10)) ELSE C.Short END --CS01
      ORDER BY ORDERS.OrderKey,
               LFloor, --BUSR6,
               --SSize
			   CASE WHEN ISNUMERIC(C.short) = 1 THEN CAST(CAST(C.Short as Float) as nvarchar(10)) ELSE C.Short END --CS01

      OPEN pick_cur
      FETCH NEXT FROM pick_cur INTO @c_SkuSize, @c_OrderKey, @c_Floor, @C_BUSR6,@c_size   --CS01

      WHILE (@@FETCH_STATUS <> -1)
      BEGIN
         SELECT @n_Count = @n_Count + 1

         IF @b_debug = 1
         BEGIN
            SELECT 'Count of sizes is ' + CONVERT(char(5), @n_Count)
         END

         SELECT @c_SkuSize1 =  CASE @n_Count WHEN 1
                  THEN @c_SkuSize
                  ELSE @c_SkuSize1
                  END
         SELECT @c_SkuSize2 =  CASE @n_Count WHEN 2
                  THEN @c_SkuSize
                  ELSE @c_SkuSize2
                  END
         SELECT @c_SkuSize3 =  CASE @n_Count WHEN 3
                  THEN @c_SkuSize
                  ELSE @c_SkuSize3
                  END
         SELECT @c_SkuSize4 =  CASE @n_Count WHEN 4
                  THEN @c_SkuSize
                  ELSE @c_SkuSize4
                  END
         SELECT @c_SkuSize5 =  CASE @n_Count WHEN 5
                  THEN @c_SkuSize
                  ELSE @c_SkuSize5
                  END
         SELECT @c_SkuSize6 =  CASE @n_Count WHEN 6
                  THEN @c_SkuSize
                  ELSE @c_SkuSize6
                  END
         SELECT @c_SkuSize7 =  CASE @n_Count WHEN 7
                  THEN @c_SkuSize
                  ELSE @c_SkuSize7
                  END
         SELECT @c_SkuSize8 =  CASE @n_Count WHEN 8
                  THEN @c_SkuSize
                  ELSE @c_SkuSize8
                  END
         SELECT @c_SkuSize9 =  CASE @n_Count WHEN 9
                  THEN @c_SkuSize
                  ELSE @c_SkuSize9
                  END
         SELECT @c_SkuSize10 = CASE @n_Count WHEN 10
                  THEN @c_SkuSize
                  ELSE @c_SkuSize10
                  END
         SELECT @c_SkuSize11 = CASE @n_Count WHEN 11
                  THEN @c_SkuSize
                  ELSE @c_SkuSize11
                  END
         SELECT @c_SkuSize12 = CASE @n_Count WHEN 12
                  THEN @c_SkuSize
                  ELSE @c_SkuSize12
                  END
         SELECT @c_SkuSize13 = CASE @n_Count WHEN 13
                  THEN @c_SkuSize
                  ELSE @c_SkuSize13
                  END
         SELECT @c_SkuSize14 = CASE @n_Count WHEN 14
                  THEN @c_SkuSize
                  ELSE @c_SkuSize14
                  END
         SELECT @c_SkuSize15 = CASE @n_Count WHEN 15
                  THEN @c_SkuSize
                  ELSE @c_SkuSize15
                  END
         SELECT @c_SkuSize16 = CASE @n_Count WHEN 16
                  THEN @c_SkuSize
                  ELSE @c_SkuSize16
                  END
         SELECT @c_SkuSize17 = CASE @n_Count WHEN 17
                  THEN @c_SkuSize
                  ELSE @c_SkuSize17
                  END
         SELECT @c_SkuSize18 = CASE @n_Count WHEN 18
                  THEN @c_SkuSize
                  ELSE @c_SkuSize18
                  END
         SELECT @c_SkuSize19 = CASE @n_Count WHEN 19
                  THEN @c_SkuSize
                  ELSE @c_SkuSize19
                  END
         SELECT @c_SkuSize20 = CASE @n_Count WHEN 20
                  THEN @c_SkuSize
                  ELSE @c_SkuSize20
                  END
         SELECT @c_SkuSize21 = CASE @n_Count WHEN 21
                  THEN @c_SkuSize
                  ELSE @c_SkuSize21
                  END
         SELECT @c_SkuSize22 = CASE @n_Count WHEN 22
                  THEN @c_SkuSize
                  ELSE @c_SkuSize22
                  END
         SELECT @c_SkuSize23 = CASE @n_Count WHEN 23
                  THEN @c_SkuSize
                  ELSE @c_SkuSize23
                  END
         SELECT @c_SkuSize24 = CASE @n_Count WHEN 24
                  THEN @c_SkuSize
                  ELSE @c_SkuSize24
                  END
         SELECT @c_SkuSize25 = CASE @n_Count WHEN 25
                  THEN @c_SkuSize
                  ELSE @c_SkuSize25
                  END
         SELECT @c_SkuSize26 = CASE @n_Count WHEN 26
                  THEN @c_SkuSize
                  ELSE @c_SkuSize26
                  END
         SELECT @c_SkuSize27 = CASE @n_Count WHEN 27
                  THEN @c_SkuSize
                  ELSE @c_SkuSize27
                  END
         SELECT @c_SkuSize28 = CASE @n_Count WHEN 28
                  THEN @c_SkuSize
                  ELSE @c_SkuSize28
                  END
         SELECT @c_SkuSize29 = CASE @n_Count WHEN 29
                  THEN @c_SkuSize
                  ELSE @c_SkuSize29
                  END
         SELECT @c_SkuSize30 = CASE @n_Count WHEN 30
                  THEN @c_SkuSize
                  ELSE @c_SkuSize30
                  END
         SELECT @c_SkuSize31 = CASE @n_Count WHEN 31
                  THEN @c_SkuSize
                  ELSE @c_SkuSize31
                  END
         SELECT @c_SkuSize32 = CASE @n_Count WHEN 32
                  THEN @c_SkuSize
                  ELSE @c_SkuSize32
                  END

         --CS01 Start

         SELECT @c_SkuSize33 = CASE @n_Count WHEN 33
                               THEN @c_SkuSize
                               ELSE @c_SkuSize33
                               END  
         SELECT @c_SkuSize34 = CASE @n_Count WHEN 34
                               THEN @c_SkuSize
                               ELSE @c_SkuSize34
                               END  

         SELECT @c_SkuSize35 = CASE @n_Count WHEN 35
                               THEN @c_SkuSize
                               ELSE @c_SkuSize35
                               END  
         SELECT @c_SkuSize36 = CASE @n_Count WHEN 36
                               THEN @c_SkuSize
                               ELSE @c_SkuSize36
                               END
                               
         IF @n_Count > 36
         BEGIN
           SET @c_MoreField = 'More Fields'
         END
		 --CS01 END
         -- SOS# 333779
		 -- WMS-10617 CS01-- remove --start 
		 /*
         SELECT @c_BUSR6_01 = CASE @n_Count WHEN 1
                               THEN @c_BUSR6
                               ELSE @c_BUSR6_01
                               END
         SELECT @c_BUSR6_02 = CASE @n_Count WHEN 2
                               THEN @c_BUSR6
                               ELSE @c_BUSR6_02
                               END
         SELECT @c_BUSR6_03 = CASE @n_Count WHEN 3
                               THEN @c_BUSR6
                               ELSE @c_BUSR6_03
                               END
         SELECT @c_BUSR6_04 = CASE @n_Count WHEN 4
                               THEN @c_BUSR6
                               ELSE @c_BUSR6_04
                               END
         SELECT @c_BUSR6_05 = CASE @n_Count WHEN 5
                               THEN @c_BUSR6
                               ELSE @c_BUSR6_05
                               END
         SELECT @c_BUSR6_06 = CASE @n_Count WHEN 6
                               THEN @c_BUSR6
                               ELSE @c_BUSR6_06
                               END
         SELECT @c_BUSR6_07 = CASE @n_Count WHEN 7
                               THEN @c_BUSR6
                               ELSE @c_BUSR6_07
                               END
         SELECT @c_BUSR6_08 = CASE @n_Count WHEN 8
                               THEN @c_BUSR6
                               ELSE @c_BUSR6_08
                               END
         SELECT @c_BUSR6_09 = CASE @n_Count WHEN 9
                               THEN @c_BUSR6
                               ELSE @c_BUSR6_09
                               END
         SELECT @c_BUSR6_10 = CASE @n_Count WHEN 10
                               THEN @c_BUSR6
                               ELSE @c_BUSR6_10
                               END
         SELECT @c_BUSR6_11 = CASE @n_Count WHEN 11
                               THEN @c_BUSR6
                               ELSE @c_BUSR6_11
                               END
         SELECT @c_BUSR6_12 = CASE @n_Count WHEN 12
                               THEN @c_BUSR6
                               ELSE @c_BUSR6_12
                               END
         SELECT @c_BUSR6_13 = CASE @n_Count WHEN 13
                               THEN @c_BUSR6
                               ELSE @c_BUSR6_13
                               END
         SELECT @c_BUSR6_14 = CASE @n_Count WHEN 14
                               THEN @c_BUSR6
                               ELSE @c_BUSR6_14
                               END
         SELECT @c_BUSR6_15 = CASE @n_Count WHEN 15
                               THEN @c_BUSR6
                               ELSE @c_BUSR6_15
                               END
         SELECT @c_BUSR6_16 = CASE @n_Count WHEN 16
                               THEN @c_BUSR6
                               ELSE @c_BUSR6_16
                               END
         SELECT @c_BUSR6_17 = CASE @n_Count WHEN 17
                               THEN @c_BUSR6
                               ELSE @c_BUSR6_17
                               END
         SELECT @c_BUSR6_18 = CASE @n_Count WHEN 18
                               THEN @c_BUSR6
                               ELSE @c_BUSR6_18
                               END
         SELECT @c_BUSR6_19 = CASE @n_Count WHEN 19
                               THEN @c_BUSR6
                               ELSE @c_BUSR6_19
                               END
         SELECT @c_BUSR6_20 = CASE @n_Count WHEN 20
                               THEN @c_BUSR6
                               ELSE @c_BUSR6_20
                               END
         SELECT @c_BUSR6_21 = CASE @n_Count WHEN 21
                               THEN @c_BUSR6
                               ELSE @c_BUSR6_21
                               END
         SELECT @c_BUSR6_22 = CASE @n_Count WHEN 22
                               THEN @c_BUSR6
                               ELSE @c_BUSR6_22
                               END
         SELECT @c_BUSR6_23 = CASE @n_Count WHEN 23
                               THEN @c_BUSR6
                               ELSE @c_BUSR6_23
                               END
         SELECT @c_BUSR6_24 = CASE @n_Count WHEN 24
                               THEN @c_BUSR6
                               ELSE @c_BUSR6_24
                               END
         SELECT @c_BUSR6_25 = CASE @n_Count WHEN 25
                               THEN @c_BUSR6
                               ELSE @c_BUSR6_25
                               END
         SELECT @c_BUSR6_26 = CASE @n_Count WHEN 26
                               THEN @c_BUSR6
                               ELSE @c_BUSR6_26
                               END
         SELECT @c_BUSR6_27 = CASE @n_Count WHEN 27
                               THEN @c_BUSR6
                               ELSE @c_BUSR6_27
                               END
         SELECT @c_BUSR6_28 = CASE @n_Count WHEN 28
                               THEN @c_BUSR6
                               ELSE @c_BUSR6_28
                               END
         SELECT @c_BUSR6_29 = CASE @n_Count WHEN 29
                               THEN @c_BUSR6
                               ELSE @c_BUSR6_29
                               END
         SELECT @c_BUSR6_30 = CASE @n_Count WHEN 30
                               THEN @c_BUSR6
                               ELSE @c_BUSR6_30
                               END
         SELECT @c_BUSR6_31 = CASE @n_Count WHEN 31
                               THEN @c_BUSR6
                               ELSE @c_BUSR6_31
                               END
         SELECT @c_BUSR6_32 = CASE @n_Count WHEN 32
                               THEN @c_BUSR6
                               ELSE @c_BUSR6_32
                               END
         */
         IF @b_debug = 1
         BEGIN
            IF @c_TempOrderKey = '0000907514' -- checking any orderkey
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

               SELECT 'BUSR6_01 to 32 is ' + @c_BUSR6_01+','+ @c_BUSR6_02+','+ @c_BUSR6_03+','+ @c_BUSR6_04+','+
                                          @c_BUSR6_05+','+ @c_BUSR6_06+','+ @c_BUSR6_07+','+ @c_BUSR6_08+','+
                                          @c_BUSR6_09+','+ @c_BUSR6_10+','+ @c_BUSR6_11+','+ @c_BUSR6_12+','+
                                          @c_BUSR6_13+','+ @c_BUSR6_14+','+ @c_BUSR6_15+','+ @c_BUSR6_16+','+
                                          @c_BUSR6_17+','+ @c_BUSR6_18+','+ @c_BUSR6_19+','+ @c_BUSR6_20+','+
                                          @c_BUSR6_21+','+ @c_BUSR6_22+','+ @c_BUSR6_23+','+ @c_BUSR6_24+','+
                                          @c_BUSR6_25+','+ @c_BUSR6_26+','+ @c_BUSR6_27+','+ @c_BUSR6_28+','+
                                          @c_BUSR6_29+','+ @c_BUSR6_30+','+ @c_BUSR6_31+','+ @c_BUSR6_32
            END
         END

         SELECT @c_PrevOrderKey = @c_OrderKey
         SELECT @c_PrevFloor = @c_Floor

         FETCH NEXT FROM pick_cur INTO @c_SkuSize, @c_OrderKey, @c_Floor, @C_BUSR6,@c_size   --CS01

         IF @b_debug = 1
         BEGIN
            SELECT 'PrevOrderkey= ' + @c_PrevOrderKey + ', Orderkey= ' + @c_OrderKey
            SELECT 'PrevFloor= ' + @c_PrevFloor + ', Floor= ' + @c_Floor
         END


         IF (@c_PrevOrderKey <> @c_OrderKey) OR
            (@c_PrevOrderKey = @c_OrderKey AND @c_PrevFloor <> @c_Floor) OR
            (@@FETCH_STATUS = -1) -- last fetch
         BEGIN
            SELECT @c_PickSlipNo = NULL

   --       SELECT @c_PickSlipNo = @c_PrevOrderKey
   --             FROM PICKHEADER (NOLOCK)
   --             WHERE Orderkey = @c_OrderKey

            -- Insert into temp table
            INSERT INTO #TempPickSlip
            SELECT PickHeader.PickHeaderKey,
                  LOADPLANDETAIL.Loadkey,
                  ORDERS.Orderkey,
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
                  SUBSTRING(PICKDETAIL.Loc, 1, 8),  --(JH01)
                  SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(PICKDETAIL.Sku)), 1, 9) StyleColour,
                  PACK.PackUom3 UOM,
                  SUBSTRING(PICKDETAIL.Loc, 2, 1) LFloor,
                  SUBSTRING(PICKDETAIL.Loc, 7, 2) Bin,
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
                  -- (tlting01) - if substring result is Blank, make it (RTRIM) NULL. That what SQl2000 do
                  CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(PICKDETAIL.Sku)), 10, 5)) = @c_SkuSize1  --AND SKU.BUSR6 = @c_BUSR6_01
                                     THEN SUM(PICKDETAIL.Qty)
                                     ELSE 0
                                     END,
                  CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(PICKDETAIL.Sku)), 10, 5)) = @c_SkuSize2  --AND SKU.BUSR6 = @c_BUSR6_02
                                     THEN SUM(PICKDETAIL.Qty)
                                     ELSE 0
                                     END,
                  CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(PICKDETAIL.Sku)), 10, 5)) = @c_SkuSize3  --AND SKU.BUSR6 = @c_BUSR6_03
                                     THEN SUM(PICKDETAIL.Qty)
                                     ELSE 0
                                     END,
                  CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(PICKDETAIL.Sku)), 10, 5)) = @c_SkuSize4  --AND SKU.BUSR6 = @c_BUSR6_04
                                     THEN SUM(PICKDETAIL.Qty)
                                     ELSE 0
                                     END,
                  CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(PICKDETAIL.Sku)), 10, 5)) = @c_SkuSize5  --AND SKU.BUSR6 = @c_BUSR6_05
                                     THEN SUM(PICKDETAIL.Qty)
                                     ELSE 0
                                     END,
                  CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(PICKDETAIL.Sku)), 10, 5)) = @c_SkuSize6  --AND SKU.BUSR6 = @c_BUSR6_06
                                     THEN SUM(PICKDETAIL.Qty)
                                     ELSE 0
                                     END,
                  CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(PICKDETAIL.Sku)), 10, 5)) = @c_SkuSize7  --AND SKU.BUSR6 = @c_BUSR6_07
                                     THEN SUM(PICKDETAIL.Qty)
                                     ELSE 0
                                     END,
                  CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(PICKDETAIL.Sku)), 10, 5)) = @c_SkuSize8  --AND SKU.BUSR6 = @c_BUSR6_08
                                     THEN SUM(PICKDETAIL.Qty)
                                     ELSE 0
                                     END,
                  CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(PICKDETAIL.Sku)), 10, 5)) = @c_SkuSize9  --AND SKU.BUSR6 = @c_BUSR6_09
                                     THEN SUM(PICKDETAIL.Qty)
                                     ELSE 0
                                     END,
                  CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(PICKDETAIL.Sku)), 10, 5)) = @c_SkuSize10  --AND SKU.BUSR6 = @c_BUSR6_10
                                     THEN SUM(PICKDETAIL.Qty)
                                     ELSE 0
                                     END,
                  CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(PICKDETAIL.Sku)), 10, 5)) = @c_SkuSize11  --AND SKU.BUSR6 = @c_BUSR6_11
                                     THEN SUM(PICKDETAIL.Qty)
                                     ELSE 0
                                     END,
                  CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(PICKDETAIL.Sku)), 10, 5)) = @c_SkuSize12  --AND SKU.BUSR6 = @c_BUSR6_12
                                     THEN SUM(PICKDETAIL.Qty)
                                     ELSE 0
                                     END,
                  CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(PICKDETAIL.Sku)), 10, 5)) = @c_SkuSize13  --AND SKU.BUSR6 = @c_BUSR6_13
                                     THEN SUM(PICKDETAIL.Qty)
                                     ELSE 0
                                     END,
                  CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(PICKDETAIL.Sku)), 10, 5)) = @c_SkuSize14  --AND SKU.BUSR6 = @c_BUSR6_14
                                     THEN SUM(PICKDETAIL.Qty)
                                     ELSE 0
                                     END,
                  CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(PICKDETAIL.Sku)), 10, 5)) = @c_SkuSize15  --AND SKU.BUSR6 = @c_BUSR6_15
                                     THEN SUM(PICKDETAIL.Qty)
                                     ELSE 0
                                     END,
                  CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(PICKDETAIL.Sku)), 10, 5)) = @c_SkuSize16  --AND SKU.BUSR6 = @c_BUSR6_16
                                     THEN SUM(PICKDETAIL.Qty)
                                     ELSE 0
                                     END,
                  CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(PICKDETAIL.Sku)), 10, 5)) = @c_SkuSize17  --AND SKU.BUSR6 = @c_BUSR6_17
                                     THEN SUM(PICKDETAIL.Qty)
                                     ELSE 0
                                     END,
                  CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(PICKDETAIL.Sku)), 10, 5)) = @c_SkuSize18  --AND SKU.BUSR6 = @c_BUSR6_18
                                     THEN SUM(PICKDETAIL.Qty)
                                     ELSE 0
                                     END,
                  CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(PICKDETAIL.Sku)), 10, 5)) = @c_SkuSize19  --AND SKU.BUSR6 = @c_BUSR6_19
                                     THEN SUM(PICKDETAIL.Qty)
                                     ELSE 0
                                     END,
                  CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(PICKDETAIL.Sku)), 10, 5)) = @c_SkuSize20  --AND SKU.BUSR6 = @c_BUSR6_20
                                     THEN SUM(PICKDETAIL.Qty)
                                     ELSE 0
                                     END,
                  CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(PICKDETAIL.Sku)), 10, 5)) = @c_SkuSize21  --AND SKU.BUSR6 = @c_BUSR6_21
                                     THEN SUM(PICKDETAIL.Qty)
                                     ELSE 0
                                     END,
                  CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(PICKDETAIL.Sku)), 10, 5)) = @c_SkuSize22  --AND SKU.BUSR6 = @c_BUSR6_22
                                     THEN SUM(PICKDETAIL.Qty)
                                     ELSE 0
                                     END,
                  CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(PICKDETAIL.Sku)), 10, 5)) = @c_SkuSize23  --AND SKU.BUSR6 = @c_BUSR6_23
                                     THEN SUM(PICKDETAIL.Qty)
                                     ELSE 0
                                     END,
                  CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(PICKDETAIL.Sku)), 10, 5)) = @c_SkuSize24  --AND SKU.BUSR6 = @c_BUSR6_24
                                     THEN SUM(PICKDETAIL.Qty)
                                     ELSE 0
                                     END,
                  CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(PICKDETAIL.Sku)), 10, 5)) = @c_SkuSize25  --AND SKU.BUSR6 = @c_BUSR6_25
                                     THEN SUM(PICKDETAIL.Qty)
                                     ELSE 0
                                     END,
                  CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(PICKDETAIL.Sku)), 10, 5)) = @c_SkuSize26  --AND SKU.BUSR6 = @c_BUSR6_26
                                     THEN SUM(PICKDETAIL.Qty)
                                     ELSE 0
                                     END,
                  CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(PICKDETAIL.Sku)), 10, 5)) = @c_SkuSize27  --AND SKU.BUSR6 = @c_BUSR6_27
                                     THEN SUM(PICKDETAIL.Qty)
                                     ELSE 0
                                     END,
                  CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(PICKDETAIL.Sku)), 10, 5)) = @c_SkuSize28  --AND SKU.BUSR6 = @c_BUSR6_28
                                     THEN SUM(PICKDETAIL.Qty)
                                     ELSE 0
                                     END,
                  CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(PICKDETAIL.Sku)), 10, 5)) = @c_SkuSize29  --AND SKU.BUSR6 = @c_BUSR6_29
                                     THEN SUM(PICKDETAIL.Qty)
                                     ELSE 0
                                     END,
                  CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(PICKDETAIL.Sku)), 10, 5)) = @c_SkuSize30  --AND SKU.BUSR6 = @c_BUSR6_30
                                     THEN SUM(PICKDETAIL.Qty)
                                     ELSE 0
                                     END,
                  CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(PICKDETAIL.Sku)), 10, 5)) = @c_SkuSize31  --AND SKU.BUSR6 = @c_BUSR6_31
                                     THEN SUM(PICKDETAIL.Qty)
                                     ELSE 0
                                     END,
                  CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(PICKDETAIL.Sku)), 10, 5)) = @c_SkuSize32  --AND SKU.BUSR6 = @c_BUSR6_32
                                     THEN SUM(PICKDETAIL.Qty)
                                     ELSE 0
                                     END
				  --CS01 Start
                 ,@c_SkuSize33,
                 @c_SkuSize34,      
                 @c_SkuSize35,
                 @c_SkuSize36,   
                 CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(PICKDETAIL.Sku)), 10, 5)) = @c_SkuSize33  
                                     THEN SUM(PICKDETAIL.Qty)
                                     ELSE 0
                                     END,
                 CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(PICKDETAIL.Sku)), 10, 5)) = @c_SkuSize34     
                        THEN SUM(PICKDETAIL.Qty)
                        ELSE 0
                        END, 
                 CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(PICKDETAIL.Sku)), 10, 5)) = @c_SkuSize35
                        THEN SUM(PICKDETAIL.Qty)
                        ELSE 0
                        END,
                CASE WHEN dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(PICKDETAIL.Sku)), 10, 5)) = @c_SkuSize36     
                        THEN SUM(PICKDETAIL.Qty)
                        ELSE 0
                        END
                ,@c_MoreField      
                --CS01 End                            
            FROM PICKDETAIL (NOLOCK)
            JOIN ORDERS (NOLOCK) ON PICKDETAIL.OrderKey = ORDERS.OrderKey
            JOIN PACK (NOLOCK) ON PICKDETAIL.Packkey = PACK.Packkey
            JOIN LOADPLANDETAIL (NOLOCK) ON PICKDETAIL.OrderKey = LOADPLANDETAIL.OrderKey AND
                                            LOADPLANDETAIL.Loadkey = ORDERS.Loadkey
            JOIN SKU (NOLOCK) ON (SKU.StorerKey = PICKDETAIL.StorerKey AND
                                  SKU.SKU = PICKDETAIL.SKU)
            LEFT OUTER JOIN PICKHEADER (NOLOCK) ON PICKHEADER.OrderKey = ORDERS.OrderKey
            WHERE LOADPLANDETAIL.LoadKey = @c_LoadKey
            AND ORDERS.OrderKey = @c_PrevOrderKey
            AND PICKDETAIL.OrderKey = @c_PrevOrderKey
            AND SUBSTRING(PICKDETAIL.Loc, 2, 1) = @c_PrevFloor
            AND 1 = CASE dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(PICKDETAIL.Sku)), 10, 5)) WHEN @c_SkuSize1    -- (tlting01)
                                                     THEN 1
                           WHEN @c_SkuSize2
                                                     THEN 1
                           WHEN @c_SkuSize3
                                                     THEN 1
                           WHEN @c_SkuSize4
                                                     THEN 1
                           WHEN @c_SkuSize5
                                                     THEN 1
                           WHEN @c_SkuSize6
                                                     THEN 1
                           WHEN @c_SkuSize7
                                                     THEN 1
                           WHEN @c_SkuSize8
                                                     THEN 1
                           WHEN @c_SkuSize9
                                                     THEN 1
                           WHEN @c_SkuSize10
                                                     THEN 1
                           WHEN @c_SkuSize11
                                                     THEN 1
                           WHEN @c_SkuSize12
                                                     THEN 1
                           WHEN @c_SkuSize13
                                                     THEN 1
                           WHEN @c_SkuSize14
                                                     THEN 1
                           WHEN @c_SkuSize15
                                                     THEN 1
                           WHEN @c_SkuSize16
                                                     THEN 1
                           -- SOS29528
                           WHEN @c_SkuSize17
                                                     THEN 1
                           WHEN @c_SkuSize18
                                                     THEN 1
                           WHEN @c_SkuSize19
                                                     THEN 1
                           WHEN @c_SkuSize20
                                                     THEN 1
                           WHEN @c_SkuSize21
                                                     THEN 1
                           WHEN @c_SkuSize22
                                                     THEN 1
                           WHEN @c_SkuSize23
                                                     THEN 1
                           WHEN @c_SkuSize24
                                                     THEN 1
                           WHEN @c_SkuSize25
                                                     THEN 1
                           WHEN @c_SkuSize26
                                                     THEN 1
                           WHEN @c_SkuSize27
                                                     THEN 1
                           WHEN @c_SkuSize28
                                                     THEN 1
                           WHEN @c_SkuSize29
                                                     THEN 1
                           WHEN @c_SkuSize30
                                                     THEN 1
                           WHEN @c_SkuSize31
                                                     THEN 1
                           WHEN @c_SkuSize32
                                                     THEN 1
                           --CS01 Start
							WHEN @c_SkuSize33
											         THEN 1
							WHEN @c_SkuSize34
											         THEN 1
							WHEN @c_SkuSize35
											         THEN 1
							WHEN @c_SkuSize36
											         THEN 1
							--CS01 End
                                                     ELSE 0
                                                     END
            GROUP BY LOADPLANDETAIL.Loadkey,
                     ORDERS.Orderkey,
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
                     SUBSTRING(PICKDETAIL.Loc, 1, 8),  --(JH01)
                     SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(PICKDETAIL.Sku)), 1, 9),
                     dbo.fnc_RTrim(SUBSTRING(dbo.fnc_RTrim(dbo.fnc_LTrim(PICKDETAIL.Sku)), 10, 5)),    -- (tlting01)
                     PACK.PackUom3,
                     SUBSTRING(PICKDETAIL.Loc, 2, 1),
                     SUBSTRING(PICKDETAIL.Loc, 7, 2),
                     PickHeader.PickHeaderKey,
                     SKU.BUSR6
            ORDER BY ORDERS.OrderKey,
                     LFloor,
                     Bin,
                     StyleColour,
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
			   SELECT @c_SkuSize33='', @c_SkuSize34='', @c_SkuSize35='', @c_SkuSize36=''    --CS01
         END
      END -- WHILE (@@FETCH_STATUS <> -1)
      CLOSE pick_cur
      DEALLOCATE pick_cur

      DECLARE @n_pickslips_required INT,
              @c_NextNo  NVARCHAR(9),
              @min INT,
              @max INT,
              @c_HCTNo NVARCHAR(12)

      -- tlting02  performance tune
      SELECT @n_pickslips_required = COUNT(1)
      FROM ( SELECT (OrderKey)
             FROM #TempPickSlip with (NOLOCK)
             WHERE ISNULL(RTrim(PickSlipNo), '') = ''
             GROUP BY OrderKey  ) A

--     GROUP BY OrderKey

--     SELECT @n_pickslips_required = Count(DISTINCT OrderKey)
--     FROM #TempPickSlip
--     WHERE dbo.fnc_RTrim(PickSlipNo) IS NULL OR dbo.fnc_RTrim(PickSlipNo) = ''
      IF @@ERROR <> 0
      BEGIN
         GOTO FAILURE
      END
      ELSE IF @n_pickslips_required > 0
      BEGIN
         EXECUTE nspg_GetKey 'PICKSLIP', 9, @c_NextNo OUTPUT, @b_success OUTPUT, @n_err  OUTPUT, @c_errmsg OUTPUT, 0, @n_pickslips_required

         IF @b_success <> 1
            GOTO FAILURE

         SELECT @c_OrderKey = ''
         WHILE 1=1
         BEGIN
            SELECT @c_OrderKey = MIN(OrderKey)
            FROM   #TempPickSlip
            WHERE  OrderKey > @c_OrderKey
            AND    PickSlipNo IS NULL

            IF dbo.fnc_RTrim(@c_OrderKey) IS NULL OR dbo.fnc_RTrim(@c_OrderKey) = ''
               BREAK

            IF NOT Exists(SELECT 1 FROM PickHeader (NOLOCK) WHERE OrderKey = @c_OrderKey)
            BEGIN
               -- SELECT @c_PickSlipNo = 'P' + RIGHT ( REPLICATE ('0', 9) + dbo.fnc_LTrim( dbo.fnc_RTrim( STR( CAST(@c_PickSlipNo AS INT)))), 9)
               SELECT @c_PickSlipNo = 'P' + @c_NextNo
               SELECT @c_NextNo = RIGHT ( REPLICATE ('0', 9) + dbo.fnc_LTrim( dbo.fnc_RTrim( STR( CAST(@c_NextNo AS INT) + 1))), 9)

               -- BEGIN added by Ong SOS35110 17/5/05
               IF Exists(SELECT 1 FROM ORDERS (NOLOCK) WHERE OrderKey = @c_OrderKey and Orders.IntermodalVehicle = 'ILOT')
               BEGIN
                  SET @c_HCTNo = ''

                  SELECT @min = CAST(dbo.fnc_LTrim(dbo.fnc_RTrim(short)) AS INT), @max = CAST(dbo.fnc_LTrim(dbo.fnc_RTrim(Long)) AS INT)
                  FROM codelkup (NOLOCK)
                  WHERE ListName = 'HCTNO'

                  EXECUTE nspg_GetKeyMinMax 'HCTNO', 10, @min, @max, @c_HCTNo OUTPUT, @b_success OUTPUT, @n_err  OUTPUT, @c_errmsg OUTPUT, 0, 1
                  SET @c_HCTNo = RIGHT (dbo.fnc_RTrim(@c_HCTNo) + CAST((@c_HCTNo % 7) AS NVARCHAR(1)), 10)
                  SET @c_HCTNo = RIGHT (REPLICATE ('0', 10) + dbo.fnc_RTrim(@c_HCTNo), 10)

                  IF CAST(@c_HCTNo AS INT) >= (@max * 10)
                  BEGIN
                     --SELECT 'FAIL @c_HCTNo =' + CAST(@c_HCTNo AS CHAR)+ '>= @mAX=' + CAST(@mAX AS CHAR) -- FOR TESTING ONLY    --SOS247512
                     SET @c_HCTNo =''
                  END
               END
               ELSE
                  SET @c_HCTNo = ''

               BEGIN TRAN
               --edit by James 09/03/2008
               IF NOT EXISTS (SELECT 1 FROM PickHeader (NOLOCK) WHERE PickHeaderKey = @c_PickSlipNo)
               BEGIN
                  INSERT INTO PICKHEADER (PickHeaderKey, OrderKey, ExternOrderKey, PickType, Zone, TrafficCop, ConsigneeKey)
                  VALUES (@c_PickSlipNo, @c_OrderKey, @c_LoadKey, '0', '8', '', @c_HCTNo)
               END

               -- END added by Ong SOS35110 17/5/05

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
            END -- NOT Exists
         END   -- WHILE

         UPDATE #TempPickSlip
         SET PickSlipNo = PICKHEADER.PickHeaderKey
         FROM  PICKHEADER (NOLOCK)
         WHERE PICKHEADER.ExternOrderKey = #TempPickSlip.LoadKey
         AND   PICKHEADER.OrderKey = #TempPickSlip.OrderKey
         AND   PICKHEADER.Zone = '8'
         AND   #TempPickSlip.PickSlipNo IS NULL

      END
      GOTO SUCCESS

FAILURE:
      DELETE FROM #TempPickSlip
      RETURN

SUCCESS:
      -- Added By SHONG
      -- Do Auto Scan-in SOS#28999
      -- Begin
      DECLARE @cPickSlipNo   NVARCHAR(10)

      SELECT @cPickSlipNo = ''
      -- WHILE 1=1
      -- BEGIN
      --    SELECT @cPickSlipNo = MIN(PickSlipNo)
      --    FROM   #TempPickSlip
      --    WHERE  PickSlipNo > @cPickSlipNo
      --
      --    IF dbo.fnc_RTrim(@cPickSlipNo) IS NULL OR dbo.fnc_RTrim(@cPickSlipNo) = ''
      --       BREAK

      -- tlting02 use cursor
      DECLARE C_PickSlip CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT #TempPickSlip.PickSlipNo      -- tlting02 add DISTINCT
      FROM #TempPickSlip (NOLOCK)
      LEFT JOIN PickingInfo (NOLOCK) on (#TempPickSlip.PickSlipNo = PickingInfo.PickSlipNo)
      WHERE PickingInfo.PickSlipNo is NULL
      ORDER BY #TempPickSlip. PickSlipNo

      OPEN C_PickSlip
      FETCH NEXT FROM C_PickSlip INTO @cPickSlipNo

      WHILE (@@FETCH_STATUS <> -1)
      BEGIN -- while cursor
         --edit by James 09/03/2008
         IF NOT Exists(SELECT 1 FROM PickingInfo (NOLOCK) WHERE PickSlipNo = @cPickSlipNo )
         BEGIN
            INSERT INTO PickingInfo  (PickSlipNo, ScanInDate, PickerID, ScanOutDate)
            VALUES (@cPickSlipNo, GetDate(), sUser_sName(), NULL)
         END

         FETCH NEXT FROM C_PickSlip INTO @cPickSlipNo
      END   -- tlting  @cPickSlipNo   - C_PickSlip
      CLOSE C_PickSlip
      DEALLOCATE C_PickSlip
      --END
   END -- WHILE (1=1)

   SELECT PickSlipNo, Loadkey, OrderKey, BuyerPO, OrderGroup, ExternOrderKey, Route, Notes, OrderDate,
          ConsigneeKey, Company, DeliveryDate, Notes2, Loc, Sku, UOM, LFloor, Bin,
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
          SUM(Qty29) Qty29, SUM(Qty30) Qty30, SUM(Qty31) Qty31, SUM(Qty32) Qty32, SkuSize33, SkuSize34, SkuSize35, SkuSize36,   --CS01
          SUM(Qty33) Qty33, SUM(Qty34) Qty34, SUM(Qty35) Qty35, SUM(Qty36) Qty36,MoreField                             --CS01
   FROM #TempPickSlip
   GROUP BY PickSlipNo, Loadkey, OrderKey, BuyerPO, OrderGroup, ExternOrderKey, Route, Notes, OrderDate,
            ConsigneeKey, Company, DeliveryDate, Notes2, Loc, Sku, UOM, LFloor, Bin,
            SkuSize1, SkuSize2, SkuSize3, SkuSize4, SkuSize5, SkuSize6, SkuSize7, SkuSize8,
            SkuSize9, SkuSize10, SkuSize11, SkuSize12, SkuSize13, SkuSize14, SkuSize15, SkuSize16,
            -- SOS29528
            SkuSize17, SkuSize18, SkuSize19, SkuSize20, SkuSize21, SkuSize22, SkuSize23, SkuSize24,
            SkuSize25, SkuSize26, SkuSize27, SkuSize28, SkuSize29, SkuSize30, SkuSize31, SkuSize32
			, SkuSize33, SkuSize34, SkuSize35, SkuSize36,MoreField       --CS01

   DROP TABLE #TempOrder
   DROP TABLE #TempPickSlip

END

GO