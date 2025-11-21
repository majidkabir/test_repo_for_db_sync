SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspLoadConsolidatedPickList                        */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
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
/************************************************************************/

/****** Object:  Stored Procedure dbo.nspLoadConsolidatedPickList    Script Date: 3/11/99 6:24:26 PM ******/
CREATE PROC [dbo].[nspLoadConsolidatedPickList](
@a_s_LoadKey NVARCHAR(10)
)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @d_date_start	datetime,
   @d_date_end		datetime,
   @c_sku		 NVARCHAR(20),
   @c_storerkey NVARCHAR(15),
   @c_lot		 NVARCHAR(10),
   @c_uom		 NVARCHAR(10),
   @c_Route        NVARCHAR(10),
   @c_Exe_String   NVARCHAR(60),
   @n_Qty          int,
   @c_Pack         NVARCHAR(20),
   @n_CaseCnt      int
   DECLARE @c_CurrOrderKey NVARCHAR(10),
   @c_MBOLKey	 NVARCHAR(10),
   @c_FirstTime    NVARCHAR(1),
   @c_PrintedFlag  NVARCHAR(1),
   @n_err          int,
   @n_Continue     int
   /*Create Temp Result table */
   SELECT   ConsoGroupNo = 0,
   LOADPLAN.LoadKey LoadKey,
   PickSlipNo=SPACE(10),
   PICKDETAIL.LOC   Loc,
   PICKDETAIL.SKU   SKU,
   ORDERS.StorerKey StorerKey1,
   ORDERS.OrderKey  OrderKey1,
   ORDERS.Route     Route1,
   ORDERS.StorerKey StorerKey2,
   ORDERS.OrderKey  OrderKey2,
   ORDERS.Route     Route2,
   ORDERS.StorerKey StorerKey3,
   ORDERS.OrderKey  OrderKey3,
   ORDERS.Route     Route3,
   ORDERS.StorerKey StorerKey4,
   ORDERS.OrderKey  OrderKey4,
   ORDERS.Route     Route4,
   ORDERS.StorerKey StorerKey5,
   ORDERS.OrderKey  OrderKey5,
   ORDERS.Route     Route5,
   ORDERS.StorerKey StorerKey6,
   ORDERS.OrderKey  OrderKey6,
   ORDERS.Route     Route6,
   ORDERS.StorerKey StorerKey7,
   ORDERS.OrderKey  OrderKey7,
   ORDERS.Route     Route7,
   ORDERS.StorerKey StorerKey8,
   ORDERS.OrderKey  OrderKey8,
   ORDERS.Route     Route8,
   PICKDETAIL.QTY   Qty1,
   PICKDETAIL.QTY   Qty2,
   PICKDETAIL.QTY   Qty3,
   PICKDETAIL.QTY   Qty4,
   PICKDETAIL.QTY   Qty5,
   PICKDETAIL.QTY   Qty6,
   PICKDETAIL.QTY   Qty7,
   PICKDETAIL.QTY   Qty8,
   Pack1=Space(20),
   Pack2=Space(20),
   Pack3=Space(20),
   Pack4=Space(20),
   Pack5=Space(20),
   Pack6=Space(20),
   Pack7=Space(20),
   Pack8=Space(20),
   PackTot=Space(20),
   PICKDETAIL.QTy  EachTot,
   PrintedFlag=SPACE(1)
   INTO #CONSOLIDATED
   FROM LOADPLAN (NOLOCK), ORDERS (NOLOCK), PICKDETAIL (NOLOCK)
   where 1 = 2
   DECLARE @c_Route1     NVARCHAR(10),
   @c_StorerKey1 NVARCHAR(15),
   @c_OrderKey1  NVARCHAR(10),
   @c_Route2     NVARCHAR(10),
   @c_StorerKey2 NVARCHAR(15),
   @c_OrderKey2  NVARCHAR(10),
   @c_Route3     NVARCHAR(10),
   @c_StorerKey3 NVARCHAR(15),
   @c_OrderKey3  NVARCHAR(10),
   @c_Route4     NVARCHAR(10),
   @c_StorerKey4 NVARCHAR(15),
   @c_OrderKey4  NVARCHAR(10),
   @c_Route5     NVARCHAR(10),
   @c_StorerKey5 NVARCHAR(15),
   @c_OrderKey5  NVARCHAR(10),
   @c_Route6     NVARCHAR(10),
   @c_StorerKey6 NVARCHAR(15),
   @c_OrderKey6  NVARCHAR(10),
   @c_Route7     NVARCHAR(10),
   @c_StorerKey7 NVARCHAR(15),
   @c_OrderKey7  NVARCHAR(10),
   @c_Route8     NVARCHAR(10),
   @c_StorerKey8 NVARCHAR(15),
   @c_OrderKey8  NVARCHAR(10)
   DECLARE @n_Qty1   int,
   @c_Pack1  NVARCHAR(20),
   @n_Qty2   int,
   @c_Pack2  NVARCHAR(20),
   @n_Qty3   int,
   @c_Pack3  NVARCHAR(20),
   @n_Qty4   int,
   @c_Pack4  NVARCHAR(20),
   @n_Qty5   int,
   @c_Pack5  NVARCHAR(20),
   @n_Qty6   int,
   @c_Pack6  NVARCHAR(20),
   @n_Qty7   int,
   @c_Pack7  NVARCHAR(20),
   @n_Qty8   int,
   @c_Pack8   NVARCHAR(20),
   @c_PackTot NVARCHAR(20),
   @n_EachTot int
   DECLARE @c_PickSlipNo NVARCHAR(10),
   @n_TotalPack  int,
   @n_TotalCase  int
   -- Set The Print Flag
   -- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, 8 - By Order
   --                          7 - Consolidated
   IF EXISTS(SELECT 1 FROM PickHeader (NOLOCK)
   WHERE ExternOrderKey = @a_s_LoadKey
   AND   Zone = "7")
   BEGIN
      SELECT @c_firsttime = 'N'
      SELECT @c_PrintedFlag = "Y"

      -- Change Print Flag to YES
      BEGIN TRAN
         -- Uses PickType as a Printed Flag
         UPDATE PickHeader
         SET PickType = '1',
         TrafficCop = NULL
         WHERE ExternOrderKey = @a_s_LoadKey
         AND Zone = "7"
         AND PickType = '0'
         SELECT @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            IF @@TRANCOUNT >= 1
            BEGIN
               ROLLBACK TRAN
            END
         END
      ELSE
         BEGIN
            IF @@TRANCOUNT > 0
            BEGIN
               COMMIT TRAN
               -- SELECT @c_PrintedFlag = "Y"
            END
         ELSE
            BEGIN
               SELECT @n_continue = 3
               ROLLBACK TRAN
            END
         END
      END
   ELSE
      BEGIN
         SELECT @c_firsttime = 'Y'
         SELECT @c_PrintedFlag = "N"
      END -- Record Not Exists
      -- Create Temp Table For Grouping
      SELECT  LOC=space(10),
      SKU.SKU SKU,
      ORDERS.OrderKey OrderKey,
      GroupNo=0,
      GroupSeq=0
      INTO #SKUGroup
      FROM SKU (NOLOCK), ORDERS (NOLOCK)
      WHERE 1 = 2
      -- Do a grouping for sku
      DECLARE @c_OrderKey  NVARCHAR(10),
      @c_LOC       NVARCHAR(10),
      @n_Count     int,
      @n_GroupNo   int,
      @n_GroupSeq  int,
      @n_CaseQty   int,
      @n_InnerQty  int,
      @n_InnerPack int,
      @n_RemainQty int
      DECLARE CUR_1 SCROLL CURSOR FOR
      SELECT 	DISTINCT ORDERDETAIL.OrderKey,
      ORDERDETAIL.SKU,
      PICKDETAIL.LOC
      FROM LOADPLANDetail (NOLOCK), ORDERDETAIL (NOLOCK), PICKDETAIL (NOLOCK)
      WHERE LOADPLANDetail.ORDERKEY = ORDERDETAIL.OrderKey
      AND  LOADPLANDetail.LoadKey = @a_s_LoadKey
      AND  PICKDETAIL.ORDERKEY = ORDERDETAIL.ORDERKEY
      AND  PICKDETAIL.ORDERLINENUMBER = PICKDETAIL.ORDERLINENUMBER
      ORDER BY PICKDETAIL.LOC, ORDERDETAIL.SKU, ORDERDETAIL.OrderKey
      OPEN CUR_1
      SELECT @n_GroupNo = 1
      SELECT @n_GroupSeq = 0
      FETCH NEXT FROM CUR_1 INTO @c_OrderKey, @c_SKU, @c_Loc
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SELECT  @n_Count =Count(*)
         FROM   #SKUGroup
         WHERE  OrderKey = @c_OrderKey
         IF @n_Count = 0
         BEGIN
            SELECT @n_GroupSeq = @n_GroupSeq + 1
            IF @n_GroupSeq > 8
            BEGIN
               SELECT @n_GroupNo=@n_GroupNo + 1
               SELECT @n_GroupSeq = 1
            END
            INSERT INTO #SKUGroup VALUES (" ",
            " ",
            @c_OrderKey,
            IsNULL(@n_GroupNo,  1) ,
            IsNULL(@n_GroupSeq, 1))
         END -- IF ORDERKEY NOT EXIST
         FETCH NEXT FROM CUR_1 INTO @c_OrderKey, @c_SKU, @c_Loc
      END -- WHILE FETCH STATUS <> -1
      FETCH FIRST FROM CUR_1 INTO @c_OrderKey, @c_SKU, @c_Loc
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SELECT @n_GroupNo = GroupNo,
         @n_GroupSeq = GroupSeq
         FROM   #SKUGroup
         WHERE  OrderKey = @c_OrderKey
         AND    LOC = " "
         AND    SKU = " "
         IF @@ROWCOUNT > 0
         BEGIN
            UPDATE #SKUGroup
            SET LOC = @c_LOC,
            SKU = @c_SKU
            WHERE  OrderKey = @c_OrderKey
            AND    LOC = " "
            AND    SKU = " "
         END
      ELSE
         BEGIN
            SELECT @n_Count = COUNT(*)
            FROM   #SKUGroup
            WHERE  OrderKey = @c_OrderKey
            AND    LOC = @c_Loc
            AND    SKU = @c_SKU
            IF @n_Count = 0
            BEGIN
               SELECT @n_GroupNo = GroupNo,
               @n_GroupSeq = GroupSeq
               FROM   #SKUGroup
               WHERE  OrderKey = @c_OrderKey
               INSERT INTO #SKUGroup VALUES (@c_LOC,
               @c_SKU,
               @c_OrderKey,
               IsNULL(@n_GroupNo,  1) ,
               IsNULL(@n_GroupSeq, 1))
            END
         END
         FETCH NEXT FROM CUR_1 INTO @c_OrderKey, @c_SKU, @c_Loc
      END
      DECLARE CUR_2 SCROLL CURSOR FOR
      SELECT DISTINCT LOC, SKU
      FROM   #SKUGroup
      ORDER BY LOC, SKU
      OPEN CUR_2
      FETCH NEXT FROM CUR_2 INTO @c_LOC, @c_SKU
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         DECLARE CUR_3 CURSOR FOR
         SELECT ORDERKEY, GroupNo, GroupSeq
         FROM   #SKUGroup
         WHERE  LOC = @c_LOC
         AND    SKU = @c_SKU
         OPEN CUR_3
         FETCH NEXT FROM CUR_3 INTO @c_OrderKey, @n_GroupNo, @n_GroupSeq
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            SELECT @c_Route     = ORDERS.Route,
            @c_StorerKey = ORDERS.StorerKey
            FROM   ORDERS (NOLOCK)
            WHERE  ORDERS.OrderKey = @c_OrderKey
            SELECT @n_Qty = 0
            SELECT @c_Pack = ""
            SELECT @n_CaseCnt=0
            SELECT @n_Qty       = SUM(PICKDETAIL.QTY),
            @n_CaseCnt   = ISNULL(PACK.CaseCnt, 0),
            @n_InnerPack = ISNULL(PACK.InnerPack, 0)
            FROM   PICKDETAIL (NOLOCK),
            SKU (NOLOCK),    PACK (NOLOCK)
            WHERE  PICKDETAIL.OrderKey = @c_OrderKey
            AND    PICKDETAIL.SKU   = @C_SKU
            AND    PICKDETAIL.LOC  = @C_LOC
            AND    SKU.SKU = PICKDETAIL.SKU
            AND    PACK.PACKKEY = SKU.PACKKEY
            GROUP BY PACK.CASECNT, PACK.InnerPack
            SELECT @n_RemainQty = 0
            SELECT @n_InnerQty  = 0
            IF ISNULL(@n_CaseCnt,0) = 0
            SELECT @c_Pack = "" -- No of Item in Carton not available
         ELSE
            BEGIN
               IF @n_Qty > @n_CaseCnt
               BEGIN
                  SELECT @n_CaseQty = FLOOR(@n_Qty / @n_CaseCnt)
                  SELECT @c_Pack = CONVERT(char(2), @n_CaseQty) + "/" + CONVERT(char(2),@n_CaseCnt) + " Ctn "
                  SELECT @n_RemainQty = @n_Qty % @n_CaseCnt
               END
            ELSE
               BEGIN
                  SELECT @n_CaseQty = 0
                  SELECT @n_RemainQty = @n_Qty
               END
               IF ISNULL(@n_InnerPack,0) > 0
               BEGIN
                  IF @n_RemainQty >= @n_InnerPack
                  BEGIN
                     SELECT @n_InnerQty  = FLOOR(@n_RemainQty / @n_InnerPack)
                     SELECT @n_Qty       = @n_RemainQty % @n_InnerPack
                     IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Pack)) <> '' SELECT @c_Pack = dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Pack)) + " & "
                     SELECT @c_Pack = dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Pack)) + CONVERT(char(2), @n_InnerQty) + "/" + CONVERT(char(2),@n_InnerPack) + " PK "
                  END
               ELSE
                  BEGIN
                     SELECT @n_InnerQty = 0
                     SELECT @n_Qty = @n_RemainQty
                  END
               END
            ELSE
               BEGIN
                  SELECT @n_InnerQty = 0
                  SELECT @n_Qty = @n_RemainQty
               END
            END
            SELECT @n_TotalPack = @n_TotalPack + @n_InnerQty
            SELECT @n_TotalCase = @n_TotalCase + @n_CaseQty
            SELECT @n_EachTot = @n_EachTot + @n_Qty
            IF @n_GroupSeq = 1
            BEGIN
               SELECT @c_Route1 = @c_Route
               SELECT @c_StorerKey1 = @c_StorerKey
               SELECT @c_OrderKey1 = @c_OrderKey
               SELECT @n_Qty1      = @n_Qty
               SELECT @c_Pack1     = @c_Pack
               SELECT @n_TotalPack = @n_InnerQty
               SELECT @n_TotalCase = @n_CaseQty
               SELECT @n_EachTot = @n_Qty
               UPDATE #CONSOLIDATED
               SET Route1 =IsNULL(@c_Route,"") ,
               StorerKey1 = @c_StorerKey,
               OrderKey1 = @c_OrderKey
               WHERE  ConsoGroupNo = @n_GroupNo
            END
         ELSE IF @n_GroupSeq = 2
            BEGIN
               SELECT @c_Route2 = @c_Route
               SELECT @c_StorerKey2 = @c_StorerKey
               SELECT @c_OrderKey2 = @c_OrderKey
               SELECT @n_Qty2      = @n_Qty
               SELECT @c_Pack2     = @c_Pack
               UPDATE #CONSOLIDATED
               SET Route2 = @c_Route,
               StorerKey2 = @c_StorerKey,
               OrderKey2 = @c_OrderKey
               WHERE  ConsoGroupNo = @n_GroupNo
            END
         ELSE IF @n_GroupSeq = 3
            BEGIN
               SELECT @c_Route3 = @c_Route
               SELECT @c_StorerKey3 = @c_StorerKey
               SELECT @c_OrderKey3 = @c_OrderKey
               SELECT @n_Qty3      = @n_Qty
               SELECT @c_Pack3     = @c_Pack
               UPDATE #CONSOLIDATED
               SET Route3 = @c_Route,
               StorerKey3 = @c_StorerKey,
               OrderKey3 = @c_OrderKey
               WHERE  ConsoGroupNo = @n_GroupNo
            END
         ELSE IF @n_GroupSeq = 4
            BEGIN
               SELECT @c_Route4 = @c_Route
               SELECT @c_StorerKey4 = @c_StorerKey
               SELECT @c_OrderKey4 = @c_OrderKey
               SELECT @n_Qty4      = @n_Qty
               SELECT @c_Pack4     = @c_Pack
               UPDATE #CONSOLIDATED
               SET Route4 = @c_Route,
               StorerKey4 = @c_StorerKey,
               OrderKey4 = @c_OrderKey
               WHERE  ConsoGroupNo = @n_GroupNo
            END
         ELSE IF @n_GroupSeq = 5
            BEGIN
               SELECT @c_Route5 = @c_Route
               SELECT @c_StorerKey5 = @c_StorerKey
               SELECT @c_OrderKey5 = @c_OrderKey
               SELECT @n_Qty5      = @n_Qty
               SELECT @c_Pack5     = @c_Pack
               UPDATE #CONSOLIDATED
               SET Route5 = @c_Route,
               StorerKey5 = @c_StorerKey,
               OrderKey5 = @c_OrderKey
               WHERE  ConsoGroupNo = @n_GroupNo
            END
         ELSE IF @n_GroupSeq = 6
            BEGIN
               SELECT @c_Route6 = @c_Route
               SELECT @c_StorerKey6 = @c_StorerKey
               SELECT @c_OrderKey6 = @c_OrderKey
               SELECT @n_Qty6      = @n_Qty
               SELECT @c_Pack6     = @c_Pack
               UPDATE #CONSOLIDATED
               SET Route6 = @c_Route,
               StorerKey6 = @c_StorerKey,
               OrderKey6 = @c_OrderKey
               WHERE  ConsoGroupNo = @n_GroupNo
            END
         ELSE IF @n_GroupSeq = 7
            BEGIN
               SELECT @c_Route7 = @c_Route
               SELECT @c_StorerKey7 = @c_StorerKey
               SELECT @c_OrderKey7 = @c_OrderKey
               SELECT @n_Qty7      = @n_Qty
               SELECT @c_Pack7     = @c_Pack
               UPDATE #CONSOLIDATED
               SET Route7 = @c_Route,
               StorerKey7 = @c_StorerKey,
               OrderKey7 = @c_OrderKey
               WHERE  ConsoGroupNo = @n_GroupNo
            END
         ELSE IF @n_GroupSeq = 8
            BEGIN
               SELECT @c_Route8 = @c_Route
               SELECT @c_StorerKey8 = @c_StorerKey
               SELECT @c_OrderKey8 = @c_OrderKey
               SELECT @n_Qty8      = @n_Qty
               SELECT @c_Pack8     = @c_Pack
               UPDATE #CONSOLIDATED
               SET Route8 = @c_Route,
               StorerKey8 = @c_StorerKey,
               OrderKey8 = @c_OrderKey
               WHERE  ConsoGroupNo = @n_GroupNo
            END
            IF @n_TotalCase > 0
            BEGIN
               SELECT @c_PackTot   = CONVERT(char(2), @n_TotalCase) + "/" + CONVERT(char(2),@n_CaseCnt) + " Ctn "
            END
         ELSE
            SELECT @c_PackTot = ""
            IF @n_TotalPack > 0
            BEGIN
               IF dbo.fnc_LTrim(dbo.fnc_RTrim(@n_TotalPack)) <> '' SELECT @c_PackTot = dbo.fnc_LTrim(dbo.fnc_RTrim(@c_PackTot)) + " & "
               SELECT @c_PackTot = dbo.fnc_LTrim(dbo.fnc_RTrim(@c_PackTot)) + CONVERT(char(2), @n_TotalPack) + "/" + CONVERT(char(2),@n_InnerPack) + " PK "
            END
            FETCH NEXT FROM CUR_3 INTO @c_OrderKey, @n_GroupNo, @n_GroupSeq
         END
         IF @c_FirstTime = 'N'
         BEGIN
            SELECT @c_PickSlipNo = PICKHEADER.PickHeaderKey
            FROM   PICKHEADER (NOLOCK)
            WHERE  ExternOrderKey = @a_s_Loadkey
            AND    Zone = "7"
            AND    CONVERT(int, OrderKey) = @n_GroupNo
         END
      ELSE
         SELECT @c_PickSlipNo = ''
         INSERT INTO #CONSOLIDATED VALUES (
         @n_GroupNo,
         @a_s_LoadKey,
         IsNULL(@c_PickSlipNo,''),
         @c_LOC,
         @c_SKU,
         IsNULL(@c_StorerKey1,""),
         IsNULL(@c_OrderKey1,""),
         IsNULL(@c_Route1,""),
         IsNULL(@c_StorerKey2,""),
         IsNULL(@c_OrderKey2,""),
         IsNULL(@c_Route2,""),
         IsNULL(@c_StorerKey3,""),
         IsNULL(@c_OrderKey3,""),
         IsNULL(@c_Route3,""),
         IsNULL(@c_StorerKey4,""),
         IsNULL(@c_OrderKey4,""),
         IsNULL(@c_Route4,""),
         IsNULL(@c_StorerKey5,""),
         IsNULL(@c_OrderKey5,""),
         IsNULL(@c_Route5,""),
         IsNULL(@c_StorerKey6,""),
         IsNULL(@c_OrderKey6,""),
         IsNULL(@c_Route6,""),
         IsNULL(@c_StorerKey7,""),
         IsNULL(@c_OrderKey7,""),
         IsNULL(@c_Route7,""),
         IsNULL(@c_StorerKey8,""),
         IsNULL(@c_OrderKey8,""),
         IsNULL(@c_Route8,""),
         IsNULL(@n_Qty1,0),
         IsNULL(@n_Qty2,0),
         IsNULL(@n_Qty3,0),
         IsNULL(@n_Qty4,0),
         IsNULL(@n_Qty5,0),
         IsNULL(@n_Qty6,0),
         IsNULL(@n_Qty7,0),
         IsNULL(@n_Qty8,0),
         IsNull(@c_Pack1,""),
         IsNull(@c_Pack2,""),
         IsNull(@c_Pack3,""),
         IsNull(@c_Pack4,""),
         IsNull(@c_Pack5,""),
         IsNull(@c_Pack6,""),
         IsNull(@c_Pack7,""),
         IsNull(@c_Pack8,""),
         IsNull(@c_PackTot,""),
         IsNull(@n_EachTot,0),
         @c_PrintedFlag)
         SELECT @n_Qty1=0
         SELECT @n_Qty2=0
         SELECT @n_Qty3=0
         SELECT @n_Qty4=0
         SELECT @n_Qty5=0
         SELECT @n_Qty6=0
         SELECT @n_Qty7=0
         SELECT @n_Qty8=0
         SELECT @c_Pack1=""
         SELECT @c_Pack2=""
         SELECT @c_Pack3=""
         SELECT @c_Pack4=""
         SELECT @c_Pack5=""
         SELECT @c_Pack6=""
         SELECT @c_Pack7=""
         SELECT @c_Pack8=""
         DEALLOCATE CUR_3
         FETCH NEXT FROM CUR_2 INTO @c_LOC, @c_SKU
      END
      DEALLOCATE CUR_2
      CLOSE CUR_1
      DEALLOCATE CUR_1
      IF @c_firsttime = 'Y'
      BEGIN
         DECLARE CUR_4 CURSOR FOR
         SELECT DISTINCT ConsoGroupNo
         FROM #CONSOLIDATED
         OPEN CUR_4
         FETCH NEXT FROM CUR_4 INTO @n_GroupNo
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            SELECT @c_OrderKey = CAST(@n_GroupNo AS NVARCHAR(10))
            EXEC nspGenPickSlipNo   @c_OrderKey,   @a_s_LoadKey,  "7", @c_PickSlipNo OUTPUT
            UPDATE #CONSOLIDATED
            SET PickSlipNo = @c_PickSlipNo
            WHERE ConsoGroupNo = @n_GroupNo
            FETCH NEXT FROM CUR_4 INTO @n_GroupNo
         END
         DEALLOCATE CUR_4
      END
      SELECT * FROM #CONSOLIDATED
      DROP TABLE #CONSOLIDATED
      DROP TABLE #SKUGroup
   END /* main procedure */


GO