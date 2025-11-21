SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*****************************************************************************/
/* Store Procedure: nsp_XDockOrderProcessing                                 */
/* Creation Date:                                                            */
/* Copyright: Maersk                                                         */
/* Written by:                                                               */
/*                                                                           */
/* Purpose:  CrossDock Order Processing (CrossDock Allocation)               */
/*                                                                           */
/* Input Parameters:  @c_ExternPOKey,  - ExternPOKey                         */
/*               @c_StorerKey,    - Storer                                   */
/*               @c_docarton,   - n/a                                        */
/*               @c_doroute,    - set to '1' for debug                       */
/*               @c_facility    - Facility                                   */
/*                                                                           */
/* Local Variables: UOM1=Pallet,    UOM2=Case,                               */
/*                  UOM3=InnerPack, UOM4=Each/Master Unit                    */
/*                                                                           */
/* Called By: XDOCK (Receipt) screen                                         */
/*                                                                           */
/* PVCS Version: 1.10                                                        */
/*                                                                           */
/* Version: 5.4                                                              */
/*                                                                           */
/* Data Modifications:                                                       */
/*                                                                           */
/* UPDATEs:                                                                  */
/* Date         Author     Ver. Purposes                                     */
/* 23-Dec-2003  RickyYee        Fixed Percentage Allocation Calculation      */ 
/* 17-Mar-2004  MaryVong        Added Drop Objects statement                 */
/* 16-Apr-2004  RickyYee        Add New Strategy for Carrefour Crossdock     */ 
/* 03-Aug-2004  Admin           Bug Fixes - Some Order Lines Skipped         */
/*                              because not sorted by RowNo                  */
/* 14-Jan-2005  YTWAN           C4 Msia Allocation - Match orderdetail's     */
/*                              exterpokey with lottable03 for allocation    */ 
/* 25-Feb-2005  YTWan           sos#32784 - System hangs during allocation   */
/* 25-Mar-2005  YTWan           sos#32784 - Refix after Ricky Advice         */
/* 22-Jun-2005  MaryVong        WSOS30495 WTC-XDOCK - Pick Case & Piece      */
/*                              separately, ie. UOM Allocation               */
/* 24-Jan-2006  MaryVong        SOS45047 WTCPH Default CaseID='(STORADDR)'   */ 
/*                              for store addressed stock                    */
/* 16-Jun-2006  Shong           SOS53100 Endless Loop (Fix bugs)             */
/*                              Change CURSOR Type to LOCAL FAST_FORWARD     */
/* 19-Jul-2006  ONG01           SOS49862 - delete #Consignee                 */
/* 20-Jun-2008  Shong           SOS109811 - Infinite Loop Issues             */ 
/* 18-Dec-2012  Audrey          SOS259787 - Create Temp table for unicode    */
/*                                        convertion             (ang01)     */
/* 07-Feb-2013  NJOW01          SOS#268108 - Create new type 11 similiar to  */
/*                              type 10 enhanced with condition if sku case  */
/*                              count is 0 default to 1 (listname:XDKSTRTYPE)*/
/* 30-May-2017  JIHHAUR         IN00360475 - declare ID nvarchar(10) not     */
/*                              enough (JHTAN01)                             */
/* 07-Mar-2024  Wan01           UWP-16306 - Moorebank Australia - Picking    */
/*                              issue while order processing for XDock       */
/* 15-Apr-2024 USH022-01        Ticket - UWP-18028- XDock Allocation Issue   */
/* 25-Sep-2024 SSA01            UWP-24194 - Enhanced XDock Allocation Strategy*/
/*****************************************************************************/
CREATE   PROCEDURE nsp_XDockOrderProcessing
   @c_ExternPOKey NVARCHAR(20) ,
   @c_StorerKey   NVARCHAR(15) ,
   @c_docarton    NCHAR (1),
   @c_doroute     NCHAR (1),
   @c_facility    NVARCHAR (5)
AS
BEGIN 
   SET NOCOUNT ON
   SET ANSI_WARNINGS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @i_success integer,
           @i_Error   integer,
           @c_ErrMsg  NVARCHAR(255),
           @n_Continue int, 
           @n_starttcnt int, 
           @c_SQLStmt NVarChar(1000),
           @c_OrderByStmt NVarChar(255),
           @b_debug NVARCHAR(1), @c_orderlinetbl NVARCHAR(13)  

   DECLARE @c_XDStrategykey NVARCHAR(10), @c_Type NVARCHAR(10), @c_OverAlloc NVARCHAR(1), 
           @c_UsrDefine01 NVARCHAR(30), @c_sort01 NVARCHAR(4), 
           @c_UsrDefine02 NVARCHAR(30), @c_sort02 NVARCHAR(4),
           @c_UsrDefine03 NVARCHAR(30), @c_sort03 NVARCHAR(4),
           @c_UsrDefine04 NVARCHAR(30), @c_sort04 NVARCHAR(4),
           @c_UsrDefine05 NVARCHAR(30), @c_sort05 NVARCHAR(4),
        -- SOS30495
        @c_UOM1 NVARCHAR(10), @c_UOM2 NVARCHAR(10), @c_UOM3 NVARCHAR(10), @c_UOM4 NVARCHAR(10)

  -- SOS30495
   DECLARE @c_UOMAlloc NVARCHAR(1), @c_GetPack NVARCHAR(1), @c_NextFlag NVARCHAR(1),  
        @n_PackPallet int, @n_PackCaseCnt int, @n_PackInner int,
        @c_PDUOM NVARCHAR(10), @n_UOMQty int

   -- SOS45047
   DECLARE @c_CaseID NVARCHAR(10)

   DECLARE @c_SKU NVARCHAR(20), @n_TotOrdQty int, @n_POOrdQty FLOAT, @n_PORcvQty FLOAT, @n_Percent float, 
           @c_orderkey NVARCHAR(10), @c_orderline NVARCHAR(5), @c_Packkey NVARCHAR(10), @c_UOM NVARCHAR(10), 
           @c_Lottable03 NVARCHAR(18), @c_pickdetkey NVARCHAR(18), @c_pickhdkey NVARCHAR(18), 
           @b_success NVARCHAR(1), @n_lastrow int, @n_cnt int, @n_RowCount int  
   
   DECLARE @n_OpenQty int, @n_ShippedQty int, @n_AllocateQty int, @n_PickQty int, 
           @n_CalOrdQty int, @n_RowNo int, @n_RowNo1 int, @n_err  int, @n_RemainQty int, 
           @n_InvQty int, @c_lot NVARCHAR(18), @c_loc NVARCHAR(10), @c_Id NVARCHAR(18), @n_PDAllocQty int

   DECLARE @d_LoadingDate datetime, @c_Sellername NVARCHAR(45), @c_SellerTerm NVARCHAR(10), @n_CalcPORcvQty float, 
           @d_StartDT datetime, @d_EndDT datetime, @n_CaseCnt float, @c_ConsigneeKey NVARCHAR(15), 
           @n_RemainOrdQty float, @n_PercentRemain float, @n_RemainCaseQty float, @n_CalcQty float
   DECLARE @c_SQLParms NVARCHAR(1000) = ''                                --(SSA01)

   SELECT @i_success = 0, @i_Error = 0, @n_Continue = 1, @n_starttcnt=@@TRANCOUNT 
   SELECT @n_err=0, @n_cnt = 0, @b_debug = '0'
   SELECT @c_orderlinetbl = 'orderline' + convert(NVARCHAR(4),@@spid)
  -- SOS30495
  SELECT @c_UOMAlloc = 'N', @c_GetPack = 'N', @c_NextFlag = 'N'
   -- SOS45047
   SELECT @c_CaseID = ''

   IF @c_doroute = '1' SELECT @b_debug ='1'


/* --ang01 start
   SELECT OD.Orderkey, OD.Orderlinenumber, OD.Storerkey, OD.Sku,
          OD.OriginalQty, OD.OpenQty, OD.ShippedQty, OD.AdjustedQty,
          OD.Qtypreallocated, OD.QtyAllocated, OD.Qtypicked, OD.Packkey,
          OD.UOM, OD.Lottable03, OD.Lottable05, OD.ExternPOKey,
          OH.Facility, OD.OpenQty AS CalOrdQty, IDENTITY(int, 1, 1) AS Rowno
     INTO #Ordlines
     FROM ORDERDETAIL OD (NOLOCK), ORDERS OH (NOLOCK)
    WHERE 1=2

   SELECT LLI.Storerkey, LLI.Sku, LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked AS Qty,
          LLI.Lot, LLI.Loc, LLI.ID, '                    ' ExternPOKey, LA.Lottable05, Loc.Facility,
          IDENTITY(int, 1, 1) AS Rowno
     INTO #Inventory
     FROM Lotxlocxid LLI (NOLOCK), Lotattribute LA (NOLOCK), Loc (NOLOCK)
    WHERE 1=2

   SELECT ConsigneeKey INTO #CONSIGNEE FROM ORDERS (NOLOCK)
    WHERE 1=2
*/ --ang02 end

--Create Temp table (ang01) Start
CREATE TABLE #Ordlines
(
  Orderkey nvarchar(10) NULL,
  Orderlinenumber nvarchar(5) NULL,
  Storerkey nvarchar(15) NULL,
  Sku nvarchar(20) NULL,
  OriginalQty int NULL,
  OpenQty int NULL,
  ShippedQty int NULL,
  AdjustedQty int NULL,
  Qtypreallocated int NULL,
  QtyAllocated int NULL,
  Qtypicked int NULL,
  Packkey nvarchar(10) NULL,
  UOM nvarchar(10) NULL,
  Lottable03 nvarchar(18) NULL,
  Lottable05 nvarchar(18) NULL,
  ExternPOKey nvarchar(20) NULL,
  Facility nvarchar(5) NULL,
  CalOrdQty int NULL,
  Rowno int IDENTITY(1,1) NOT NULL,
  ID nvarchar(18) NOT NULL                                                   --(SSA01)
)

CREATE TABLE #Inventory
(
  Storerkey nvarchar(15) NULL,
  Sku nvarchar(20) NULL,
  Qty int NULL,
  QtyAllocated int NULL,
  QtyPicked int NULL,
  Lot nvarchar(10) NULL,
  Loc nvarchar(10) NULL,
  ID nvarchar(18) NULL,   --(JHTAN01) CHANGE TO 18
  ExternPOKey nvarchar(20) NULL,
  Lottable05 datetime NULL,
  Facility nvarchar(5) NULL,
  Rowno int IDENTITY(1,1) NOT NULL
)


CREATE TABLE #TEMPSKU
(
Sku nvarchar(20) NULL
)


CREATE TABLE #CONSIGNEE
(
  ConsigneeKey nvarchar(15) NULL
)

--ang01 end

INSERT INTO #TEMPSKU
   SELECT DISTINCT Sku
     --INTO #TEMPSKU (ang01)
     FROM PODETAIL (NOLOCK)
    WHERE ExternPOKey = @c_ExternPOKey
      AND STORERKEY = @c_StorerKey

   SELECT @c_XDStrategykey = XS.XDockStrategyKey, 
          @c_Type          = XS.Type            , 
          @c_OverAlloc     = XS.Overalloc       , 
          @c_UsrDefine01   = XS.USERDEFINE01    , 
          @c_sort01        = XS.SORT01          , 
          @c_UsrDefine02   = XS.USERDEFINE02    , 
          @c_sort02        = XS.SORT02          , 
          @c_UsrDefine03   = XS.USERDEFINE03    , 
          @c_sort03        = XS.SORT03          , 
          @c_UsrDefine04   = XS.USERDEFINE04    , 
          @c_sort04        = XS.SORT04          , 
          @c_UsrDefine05   = XS.USERDEFINE05    , 
          @c_sort05        = XS.SORT05          ,
       -- SOS30495
          @c_UOM1         = XS.UOM1           ,
          @c_UOM2         = XS.UOM2           ,
          @c_UOM3         = XS.UOM3           ,
          @c_UOM4         = XS.UOM4          
     FROM STORER ST (NOLOCK), XDOCKStrategy XS (NOLOCK) 
    WHERE ST.XDockStrategykey = XS.XDockStrategyKey 
      AND ST.StorerKey = @c_StorerKey 

   IF @@Rowcount = 0 
   BEGIN 
      SELECT @n_Continue = 3
      SELECT @i_Error = 15010
      SELECT @c_ErrMsg = 'nsp_XDockOrderProcessing - CrossDock Strategy Not Found'      
   END

  -- Part 1
   IF (@n_Continue = 1 OR @n_Continue =2) 
   BEGIN
      INSERT INTO #Inventory (Storerkey, Sku, Qty, Lot, Loc, ID, ExternPOKey, Lottable05, Facility)
            SELECT LLI.Storerkey, LLI.Sku, LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked AS Qty,
                   LLI.Lot, LLI.Loc, LLI.ID, LA.Lottable03, LA.Lottable05, Loc.Facility
      --        INTO #Inventory
              FROM Lotxlocxid LLI (NOLOCK), Lotattribute LA (NOLOCK), Loc (NOLOCK), LOT (NOLOCK), ID (NOLOCK)   --(USH022 -01) - START-UWP-18028
             WHERE LA.Storerkey = @c_StorerKey
            AND LA.SKU IN (SELECT SKU FROM #TEMPSKU)
               AND LA.Lottable03 = @c_ExternPOKey
               AND Loc.Facility = @c_facility
               AND LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked > 0
               AND LLI.Lot = LA.Lot
               AND LLI.Loc = Loc.Loc
               AND LOT.status  = 'OK'                                     --(USH022 -01) - START-UWP-18028
               AND LOC.Status = 'OK'
               AND ID.Status = 'OK'
               AND Loc.LOCationFlag NOT IN ('DAMAGE', 'HOLD')
               AND LLI.Lot = LOT.Lot
               AND LLI.ID = ID.ID                                         --(USH022-01) - END-UWP-18028

      IF (SELECT COUNT(*) FROM #Inventory) = 0 
      BEGIN 
         SELECT @n_Continue = 3
         SELECT @i_Error = 15040
         SELECT @c_ErrMsg = 'nsp_XDockOrderProcessing - No Inventory to process'
      END
   END

  -- Part 2
   IF (@n_Continue = 1 OR @n_Continue =2) 
   BEGIN
      IF @c_Type = '01'
      BEGIN
         SELECT @c_SQLStmt = "INSERT INTO #Ordlines " +
                             "(Orderkey, Orderlinenumber, Storerkey, Sku, " +
                             "OriginalQty, OpenQty, ShippedQty, AdjustedQty, " +
                             "Qtypreallocated, QtyAllocated, Qtypicked, Packkey, " +
                             "UOM, Lottable03, Lottable05, ExternPOKey, " +
                             "Facility, CalOrdQty, ID) " +                                              --(SSA01)
                             "SELECT OD.Orderkey, OD.Orderlinenumber, OD.Storerkey, OD.Sku, "   +
                             "OD.OriginalQty, OD.OpenQty, OD.ShippedQty, OD.AdjustedQty, "      +
                             "OD.Qtypreallocated, OD.QtyAllocated, OD.Qtypicked, OD.Packkey, "  +       
                             "OD.UOM, OD.Lottable03, OD.Lottable05, OD.ExternPOKey, "           + 
                             "OH.Facility, (OD.OpenQty - OD.QtyAllocated - OD.Qtypicked) AS CalOrdQty," +
                             "OD.ID "                                                          +       --(SSA01)
                             "FROM ORDERDETAIL OD (NOLOCK), ORDERS OH (NOLOCK) "                +
                             "WHERE OH.Orderkey = OD.Orderkey "                                 + 
                             "AND OH.facility = N'" + dbo.fnc_RTrim(@c_facility) + "' "                  + 
                             "AND OH.status < '" + "2" + "' "                                   + 
                             "AND OD.Storerkey = N'" + dbo.fnc_RTrim(@c_StorerKey) + "' "                + 
                             "AND OD.ExternPOKey = N'" + dbo.fnc_RTrim(@c_ExternPOKey) + "' "            + 
                             "AND OD.OpenQty - OD.QtyAllocated - OD.Qtypicked > 0 "             +
                             "AND OD.SKU IN (SELECT SKU FROM #TEMPSKU) "                        +
                             "ORDER BY OD.Orderkey, OD.SKU "
         EXEC (@c_SQLStmt)
         
         IF (SELECT COUNT(*) FROM #Ordlines) = 0 
         BEGIN 
            SELECT @n_Continue = 3
            SELECT @i_Error = 15020
            SELECT @c_ErrMsg = 'nsp_XDockOrderProcessing - No OrderLines to process'
         END
      END 
      ELSE
      BEGIN
         IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_UsrDefine01)) <> '' OR dbo.fnc_RTrim(dbo.fnc_LTrim(@c_UsrDefine01)) IS NOT NULL
         BEGIN
            SELECT @c_OrderByStmt = dbo.fnc_RTrim(dbo.fnc_LTrim(@c_UsrDefine01)) + " " + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_sort01)) 
         END
         IF LEN(dbo.fnc_RTrim(dbo.fnc_LTrim(@c_OrderByStmt))) > 0 
         BEGIN 
            IF (dbo.fnc_RTrim(dbo.fnc_LTrim(@c_UsrDefine02)) <> '' OR dbo.fnc_RTrim(dbo.fnc_LTrim(@c_UsrDefine02)) IS NOT NULL)
            BEGIN 
               SELECT @c_OrderByStmt = @c_OrderByStmt + ", " + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_UsrDefine02)) + " " + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_sort02))
            END
         END
         ELSE  
         BEGIN
            IF (dbo.fnc_RTrim(dbo.fnc_LTrim(@c_UsrDefine02)) <> '' OR dbo.fnc_RTrim(dbo.fnc_LTrim(@c_UsrDefine02)) IS NOT NULL)
            BEGIN 
               SELECT @c_OrderByStmt = dbo.fnc_RTrim(dbo.fnc_LTrim(@c_UsrDefine02)) + " " + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_sort02))
            END
         END


         IF LEN(dbo.fnc_RTrim(dbo.fnc_LTrim(@c_OrderByStmt))) > 0 
         BEGIN 
            IF (dbo.fnc_RTrim(dbo.fnc_LTrim(@c_UsrDefine03)) <> '' OR dbo.fnc_RTrim(dbo.fnc_LTrim(@c_UsrDefine03)) IS NOT NULL)
            BEGIN 
               SELECT @c_OrderByStmt = @c_OrderByStmt + ", " + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_UsrDefine03)) + " " + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_sort03))
            END
         END
         ELSE  
         BEGIN
            IF (dbo.fnc_RTrim(dbo.fnc_LTrim(@c_UsrDefine03)) <> '' OR dbo.fnc_RTrim(dbo.fnc_LTrim(@c_UsrDefine03)) IS NOT NULL)
            BEGIN 
               SELECT @c_OrderByStmt = dbo.fnc_RTrim(dbo.fnc_LTrim(@c_UsrDefine03)) + " " + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_sort03))
            END
         END

         IF LEN(dbo.fnc_RTrim(dbo.fnc_LTrim(@c_OrderByStmt))) > 0 
         BEGIN 
            IF (dbo.fnc_RTrim(dbo.fnc_LTrim(@c_UsrDefine04)) <> '' OR dbo.fnc_RTrim(dbo.fnc_LTrim(@c_UsrDefine04)) IS NOT NULL)
            BEGIN 
               SELECT @c_OrderByStmt = @c_OrderByStmt + ", " + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_UsrDefine04)) + " " + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_sort04))
            END
         END
         ELSE  
         BEGIN
            IF (dbo.fnc_RTrim(dbo.fnc_LTrim(@c_UsrDefine04)) <> '' OR dbo.fnc_RTrim(dbo.fnc_LTrim(@c_UsrDefine04)) IS NOT NULL)
            BEGIN 
               SELECT @c_OrderByStmt = dbo.fnc_RTrim(dbo.fnc_LTrim(@c_UsrDefine04)) + " " + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_sort04))
            END
         END

         IF LEN(dbo.fnc_RTrim(dbo.fnc_LTrim(@c_OrderByStmt))) > 0 
         BEGIN 
            IF (dbo.fnc_RTrim(dbo.fnc_LTrim(@c_UsrDefine05)) <> '' OR dbo.fnc_RTrim(dbo.fnc_LTrim(@c_UsrDefine05)) IS NOT NULL)
            BEGIN 
               SELECT @c_OrderByStmt = @c_OrderByStmt + ", " + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_UsrDefine05)) + " " + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_sort05))
            END
         END
         ELSE  
         BEGIN
            IF (dbo.fnc_RTrim(dbo.fnc_LTrim(@c_UsrDefine05)) <> '' OR dbo.fnc_RTrim(dbo.fnc_LTrim(@c_UsrDefine05)) IS NOT NULL)
            BEGIN 
               SELECT @c_OrderByStmt = dbo.fnc_RTrim(dbo.fnc_LTrim(@c_UsrDefine05)) + " " + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_sort05))
            END
         END

         IF LEN(dbo.fnc_RTrim(dbo.fnc_LTrim(@c_OrderByStmt))) > 0  
         BEGIN
            SELECT @c_OrderByStmt = @c_OrderByStmt + ", OD.SKU " 
         END

         SELECT @c_SQLStmt = "INSERT INTO #Ordlines " + 
                             "(Orderkey, Orderlinenumber, Storerkey, Sku, " +
                             "OriginalQty, OpenQty, ShippedQty, AdjustedQty, " +
                             "Qtypreallocated, QtyAllocated, Qtypicked, Packkey, " +
                             "UOM, Lottable03, Lottable05, ExternPOKey, " +
                             "Facility, CalOrdQty,  ID) " +                                           --(SSA01)
                             "SELECT OD.Orderkey, OD.Orderlinenumber, OD.Storerkey, OD.Sku, "   +
                             "OD.OriginalQty, OD.OpenQty, OD.ShippedQty, OD.AdjustedQty, "      +
                             "OD.Qtypreallocated, OD.QtyAllocated, OD.Qtypicked, OD.Packkey, "  +       
                             "OD.UOM, OD.Lottable03, OD.Lottable05, OD.ExternPOKey, "           + 
                             "OH.Facility, (OD.OpenQty - OD.QtyAllocated - OD.Qtypicked) AS CalOrdQty, " +
                             "OD.ID " +                                                                --(SSA01)
                             "FROM ORDERDETAIL OD (NOLOCK), ORDERS OH (NOLOCK) "                +
                             "WHERE OD.ExternPOKey = N'" + dbo.fnc_RTrim(@c_ExternPOKey) + "' "          + 
                             "AND OH.Storerkey = N'" + dbo.fnc_RTrim(@c_StorerKey) + "' "                + 
                             "AND OD.SKU IN (SELECT SKU FROM #TEMPSKU) "                        +
                             "AND OH.facility = N'" + dbo.fnc_RTrim(@c_facility) + "' "                  + 
                             "AND OH.status < '" + "2" + "' "                                   + 
                             "AND OD.OpenQty - OD.QtyAllocated - OD.Qtypicked > 0 "             +
                             "AND OH.Orderkey = OD.Orderkey "                            



         IF len(dbo.fnc_RTrim(dbo.fnc_LTrim(@c_OrderByStmt))) > 0 
         BEGIN
            SELECT @c_SQLStmt = @c_SQLStmt + " ORDER BY " + @c_OrderByStmt
         END
         ELSE 
         BEGIN 
          SELECT @c_SQLStmt = @c_SQLStmt + " ORDER BY OD.Orderkey, OD.SKU "
         END

         IF @b_debug = '1' 
         BEGIN  
            select @c_SQLStmt 
         END

         EXEC (@c_SQLStmt)          
      
         IF @b_debug = '1' 
         BEGIN  
            select count(*) from #Ordlines 
         END
         
         IF (SELECT COUNT(*) FROM #Ordlines) = 0 
         BEGIN 
            SELECT @n_Continue = 3
            SELECT @i_Error = 15030
            SELECT @c_ErrMsg = 'nsp_XDockOrderProcessing - No OrderLines to process'
         END
      END      
   END

   -- Part 3
   IF (@n_Continue = 1 OR @n_Continue =2) 
   BEGIN
      IF @c_Type = '01' OR @c_Type = '03'  -- Percentage Calculation
      BEGIN    
         DECLARE CalPercent_Cursor CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
         SELECT Sku, SUM(OpenQty) AS TotOrdQty 
           FROM #Ordlines 
         GROUP BY SKU 

         OPEN CalPercent_Cursor 
         FETCH NEXT FROM CalPercent_Cursor INTO @c_SKU, @n_TotOrdQty

         WHILE @@FETCH_STATUS = 0
         BEGIN 
            SELECT @n_POOrdQty = SUM(QtyOrdered), @n_PORcvQty = SUM(QtyReceived)
              FROM PODETAIL (NOLOCK) 
             WHERE PODETAIL.ExternPOKey = @c_ExternPOKey 
               AND PODETAIL.STORERKEY = @c_StorerKey  
               AND PODETAIL.SKU = @c_SKU 

            SELECT @n_Percent = @n_PORcvQty /@n_POOrdQty 

            IF @b_debug = '1' 
            BEGIN  
               Print '% allocation'
               select @c_SKU 'Sku' , @n_TotOrdQty 'TotQty',  @n_POOrdQty 'poordqty', @n_PORcvQty 'porecvqty', @n_Percent 'percent'
               Select * from #Ordlines
            END

            IF @c_OverAlloc = 'N'
            BEGIN
               IF @n_Percent > 1 
               BEGIN 
                  SELECT @n_Percent = 1 
               END
            END
   
            UPDATE #Ordlines 
               SET CalOrdQty = FLOOR(@n_Percent * (OpenQty - QtyAllocated - Qtypicked)) 
             WHERE ExternPOKey = @c_ExternPOKey 
               AND SKU = @c_SKU 

            IF @b_debug = '1' 
            BEGIN   
               Print '% allocation'
               Select * from #Ordlines
            END

            IF (@n_PORcvQty / @n_POOrdQty) <> 1
            BEGIN 
               IF @c_OverAlloc = 'Y'
               BEGIN
                  SELECT @n_RemainQty = @n_PORcvQty - SUM(CalOrdQty) 
                    FROM #Ordlines 
                   WHERE Sku = @c_SKU

                  IF @b_debug = '1' 
                  BEGIN   
                     Print '% allocation'
                     Select @n_PORcvQty 'PORCV_QTY', @n_RemainQty 'RemainQty'
                  END


                  SELECT @n_lastrow = MAX(rowno)  
                    FROM #Ordlines 
                   WHERE SKU = @c_SKU 
   
                  UPDATE #Ordlines 
                     SET CalOrdQty = CalOrdQty + @n_RemainQty 
                   WHERE SKU = @c_SKU 
                     AND rowno = @n_lastrow              
               END
               ELSE
               BEGIN 
                  IF @c_OverAlloc = 'N' and (@n_PORcvQty /@n_POOrdQty) < 1
                  BEGIN
                     SELECT @n_RemainQty = @n_PORcvQty - SUM(CalOrdQty) 
                       FROM #Ordlines 
                      WHERE Sku = @c_SKU

                     SELECT @n_RowNo = 0

                     WHILE (@n_RemainQty > 0)
                     BEGIN    
                        IF @b_debug = '1' 
                        BEGIN  
                           print 'b4 selecting'                         
                           select @n_RowCount, @n_RemainQty, @n_RowNo, @c_SKU, OpenQty - QtyAllocated - Qtypicked, * from #ordlines
                        END

                        SET ROWCOUNT 1

                        SELECT @n_RowNo = rowno, @n_CalOrdQty = CalOrdQty, 
                               @n_OpenQty = OpenQty - QtyAllocated - Qtypicked - CalOrdQty  
                      FROM #Ordlines 
                         WHERE Rowno > @n_RowNo 
                           AND Sku = @c_SKU 
                           AND OpenQty - QtyAllocated - Qtypicked - CalOrdQty > 0 
                        ORDER BY Rowno 

                        SELECT @n_RowCount = @@ROWCOUNT

                        IF @b_debug = '1' 
                        BEGIN  
                           print 'after selecting'                         
                           select @n_RemainQty, @n_RowNo, @n_RowCount, @n_OpenQty 
                        END

         
                        IF @n_RemainQty > 0 and @n_RowCount = 0 AND @n_OpenQty > 0 
                        BEGIN 
                           SELECT @n_RowNo = 0, @n_OpenQty = 0 
                        END
                        ELSE 
                        BEGIN 
                           IF @n_RowCount = 0 
                           BEGIN 
                              SET ROWCOUNT 0
                              BREAK
                           END
                        END

                        SET ROWCOUNT 0
                           
                        IF @n_RowNo > 0 
                        BEGIN 
                           UPDATE #Ordlines 
                              SET CalOrdQty = CalOrdQty + 1 
                            WHERE SKU = @c_SKU and Rowno = @n_RowNo                                
   
                           SELECT @n_RemainQty  = @n_RemainQty  - 1  
                        END
                     END -- While
                  END
               END
            END                  
            
            FETCH NEXT FROM CalPercent_Cursor INTO @c_SKU, @n_TotOrdQty
         END
         
         CLOSE CalPercent_Cursor
         DEALLOCATE CalPercent_Cursor
      END -- Type = 01 or 03 --> Percentage Calculation 
      ELSE  
      BEGIN
         IF @c_Type = '02'  --> Sorting Calculation
         BEGIN    
            DECLARE Sort_Cursor CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
            SELECT Sku, SUM(OpenQty) AS TotOrdQty 
              FROM #Ordlines 
            GROUP BY SKU 
   
            OPEN Sort_Cursor 
            FETCH NEXT FROM Sort_Cursor INTO @c_SKU, @n_TotOrdQty
   
            IF @b_debug = '1' 
            BEGIN  
               print 'Type 2 BEGIN'
               select @c_SKU 'Sku' , @n_TotOrdQty 'TotQty'
            END

            WHILE @@FETCH_STATUS = 0
            BEGIN
               SELECT @n_POOrdQty = SUM(QtyOrdered), @n_PORcvQty = SUM(QtyReceived)
                 FROM PODETAIL (NOLOCK) 
                WHERE PODETAIL.ExternPOKey = @c_ExternPOKey 
                  AND PODETAIL.STORERKEY = @c_StorerKey  
                  AND PODETAIL.SKU = @c_SKU 

               IF @b_debug = '1' 
               BEGIN  
                  print 'Type 2 checking poqty'
                  select @n_PORcvQty 'porecqty', @n_POOrdQty 'poordqty'
               END
   
               IF @n_PORcvQty > @n_POOrdQty  
               BEGIN
                  IF @c_OverAlloc = 'Y'
                  BEGIN
                     SELECT @n_Percent = @n_PORcvQty/@n_POOrdQty
                     
                     UPDATE #Ordlines 
                        SET CalOrdQty = FLOOR(@n_Percent * (OpenQty - QtyAllocated - Qtypicked)) 
                      WHERE ExternPOKey = @c_ExternPOKey 
                        AND SKU = @c_SKU
                  END
               END               
               
               FETCH NEXT FROM Sort_Cursor INTO @c_SKU, @n_TotOrdQty
            END
            
            CLOSE Sort_Cursor
            DEALLOCATE Sort_Cursor
         END 
      END -- Type = 02 --> Sorting Calculation 
      IF @c_Type = '10' OR @c_Type = '11' --NJOW01 --> Allocate 1 case to each Order, Remaining Qty use Percentage Calculation
      BEGIN 
         DECLARE Sort01_Cursor CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
         SELECT Sku, SUM(OpenQty) AS TotOrdQty 
           FROM #Ordlines 
         GROUP BY SKU 
   
         OPEN Sort01_Cursor 
         FETCH NEXT FROM Sort01_Cursor INTO @c_SKU, @n_TotOrdQty
   
         WHILE @@FETCH_STATUS = 0
         BEGIN 
        /* 25 March 2005 YTWAN - sos#32784 - System hangs during allocation*/
            SELECT @n_POOrdQty = SUM(QtyOrdered)--, @n_PORcvQty = SUM(QtyReceived)
              FROM PODETAIL (NOLOCK) 
             WHERE PODETAIL.ExternPOKey = @c_ExternPOKey 
               AND PODETAIL.STORERKEY = @c_StorerKey  
               AND PODETAIL.SKU = @c_SKU 

        /*SELECT @n_PORcvQty = SUM(Qty - QtyAllocated - Qtypicked)
        FROM LOTxLOCxID LLI(NOLOCK) 
        INNER JOIN LOTATTRIBUTE LA (NOLOCK) ON (LA.Lot = LLI.Lot) AND
                                  (LA.Storerkey = LLI.Storerkey) AND
                                  (LA.Sku = LLI.Sku)    
        WHERE LA.Lottable03 = @c_ExternPOKey
        AND  LA.Storerkey = @c_StorerKey
        AND  LA.Sku     = @c_SKU*/

        --NJOW01 Exclude damage loc and other facility
        SELECT @n_PORcvQty = SUM(LLI.Qty - LLI.QtyAllocated - LLI.Qtypicked)
                FROM LOTxLOCxID LLI(NOLOCK)
                INNER JOIN LOTATTRIBUTE LA (NOLOCK) ON (LA.Lot = LLI.Lot) AND
                                          (LA.Storerkey = LLI.Storerkey) AND
                                          (LA.Sku = LLI.Sku)
                INNER JOIN LOC (NOLOCK) ON (LLI.Loc = LOC.Loc)          --(USH022-01) - START-UWP-18028
                INNER JOIN LOT (NOLOCK)  ON (LOT.lot = LLI.lot)
                INNER JOIN ID (NOLOCK) ON (ID.ID = LLI.ID)              --(USH022-01) - END-UWP-18028
                WHERE LA.Lottable03 = @c_ExternPOKey
                AND  LA.Storerkey = @c_StorerKey
                AND  LA.Sku     = @c_SKU
                AND  LOC.Facility = @c_facility
                AND LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked > 0      --(USH022-01)-UWP-18028
                AND LLI.Lot = LA.Lot
                AND LLI.Loc = Loc.Loc
                AND LOT.status  = 'OK'                                  --(USH022-01) - START-UWP-18028
                AND LOC.Status = 'OK'
                AND ID.Status = 'OK'
                AND Loc.LOCationFlag NOT IN ('DAMAGE', 'HOLD')          --(USH022-01) - END-UWP-18028
        
        
        /* 25 March 2005 YTWAN - System hangs during allocation */
   
            IF @n_PORcvQty > @n_POOrdQty  
            BEGIN
               IF @c_OverAlloc = 'Y'
               BEGIN
                  SELECT @n_Percent = @n_PORcvQty/@n_POOrdQty
                  --BEGIN TRAN 
                  
                  UPDATE #Ordlines 
                     SET CalOrdQty = FLOOR(@n_Percent * (OpenQty - QtyAllocated - Qtypicked)) 
                   WHERE ExternPOKey = @c_ExternPOKey 
                     AND STORERKEY = @c_StorerKey 
                     AND SKU = @c_SKU 

                  SELECT @n_err = @@ERROR
                  IF @n_err <> 0 
                  BEGIN
                     IF @@TRANCOUNT >= 1
                     BEGIN
                        ROLLBACK TRAN
                        SELECT @n_Continue = 3
                        SELECT @i_Error = 15034
                        SELECT @c_ErrMsg = 'nsp_XDockOrderProcessing - UPDATE Failed on #Ordlines'
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

                        SELECT @n_Continue = 3
                        SELECT @i_Error = 15034
                        SELECT @c_ErrMsg = 'nsp_XDockOrderProcessing - UPDATE Failed on #Ordlines'
                     END
                  END                     
               END -- @c_OverAlloc = 'Y'
            END
            ELSE
            BEGIN 
               IF @n_PORcvQty < @n_POOrdQty  
               BEGIN 
                  SELECT @n_CalcPORcvQty = @n_PORcvQty 

                  SELECT @n_CaseCnt = CaseCnt 
                   FROM PACK WITH (NOLOCK) JOIN SKU WITH (NOLOCK) 
                     ON PACK.PACKKEY = SKU.PACKKEY 
                    AND SKU.Storerkey = @c_StorerKey 
                    AND SKU.Sku = @c_SKU

                  IF @b_debug = '1'
                  BEGIN  
                     SELECT @c_SKU 'sku', @n_CalcPORcvQty 'recvqty', @n_CaseCnt 'caseqty'
                  END

                  IF @n_CaseCnt = 0 
                  BEGIN 
                     IF @c_Type = '11'  --NJOW01
                     BEGIN
                        SET @n_CaseCnt = 1 --NJOW01
                     END
                     ELSE
                     BEGIN
                        SELECT @n_Continue = 3
                        SELECT @i_Error = 15035
                        SELECT @c_ErrMsg = 'nsp_XDockOrderProcessing - CaseCnt = 0 for Sku: ' + @c_SKU + ' '                     
                        BREAK 
                     END
                  END 

                  IF (@n_Continue = 1 OR @n_Continue =2) 
                  BEGIN
                     BEGIN TRAN 
                     UPDATE #Ordlines 
                        SET CalOrdQty = 0 
                      WHERE ExternPOKey = @c_ExternPOKey 
                        AND STORERKEY = @c_StorerKey 
                        AND SKU = @c_SKU 

                     SELECT @n_err = @@ERROR
                     IF @n_err <> 0 
                     BEGIN
                        IF @@TRANCOUNT >= 1
                        BEGIN
                           ROLLBACK TRAN
                           SELECT @n_Continue = 3
                           SELECT @i_Error = 15038
                           SELECT @c_ErrMsg = 'nsp_XDockOrderProcessing - UPDATE Failed on #Ordlines'
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
   
                           SELECT @n_Continue = 3
                           SELECT @i_Error = 15038
                           SELECT @c_ErrMsg = 'nsp_XDockOrderProcessing - UPDATE Failed on #Ordlines'
                        END
                     END                     
                  END
   
                  -- allocate 1 case to each Order using sorting criteria 
            -- Reset #Consignee in order to assign 1 case each storer
            TRUNCATE TABLE #Consignee     -- ONG01

                  Select @n_RowNo = 0
                  
                  WHILE (1=1) AND (@n_Continue = 1 OR @n_Continue =2) 
                  BEGIN 
                     SET ROWCOUNT 1

                     SELECT @c_ConsigneeKey = Orders.ConsigneeKey, @n_RowNo = rowno, 
                            @c_orderkey = #Ordlines.Orderkey, @c_orderline = #Ordlines.Orderlinenumber  
                       FROM #Ordlines, Orders (NOLOCK) 
                      WHERE #Ordlines.Orderkey = Orders.OrderKey 
                        And #Ordlines.Storerkey = @c_StorerKey 
                        And #Ordlines.Sku = @c_SKU 
                        And #Ordlines.OpenQty - #Ordlines.QtyAllocated - #Ordlines.Qtypicked >= @n_CaseCnt
                        And #Ordlines.Rowno > @n_RowNo  
                        And ConsigneeKey NOT IN (SELECT ConsigneeKey FROM #CONSIGNEE)
                     Order By rowno  
                  
                     SELECT @n_RowCount = @@ROWCOUNT 

                     SET ROWCOUNT 0

                     IF @n_RowCount = 0 
                     BEGIN 
                        Break 
                     END 
                     ELSE
                     BEGIN  
                        BEGIN TRAN 
                        UPDATE #Ordlines 
                           SET CalOrdQty = @n_CaseCnt  
                         WHERE rowno = @n_RowNo

                        SELECT @n_err = @@ERROR
                        IF @n_err <> 0 
                        BEGIN
                           IF @@TRANCOUNT >= 1
                           BEGIN
                              ROLLBACK TRAN     
                              SELECT @n_Continue = 3
                              SELECT @i_Error = 15039
                              SELECT @c_ErrMsg = 'nsp_XDockOrderProcessing - UPDATE Failed on #Ordlines'
                           END
                        END
                        ELSE
                        BEGIN
                           IF @@TRANCOUNT > 0 
                           BEGIN
                              COMMIT TRAN

                              SELECT @n_CalcPORcvQty = @n_CalcPORcvQty - @n_CaseCnt 
                           END
                           ELSE
                           BEGIN
                              ROLLBACK TRAN
      
                              SELECT @n_Continue = 3
                              SELECT @i_Error = 15039
                              SELECT @c_ErrMsg = 'nsp_XDockOrderProcessing - UPDATE Failed on #Ordlines'
                           END
                        END                     

                        INSERT INTO #CONSIGNEE VALUES (@c_ConsigneeKey)
                     END
                  END -- While Loop #OrdLines, allocate 1 case to each Order using sorting criteria 

                  IF @b_debug = '1'
                  BEGIN  
                     print 'Case UPDATE for each store'
                     SELECT * from #Ordlines WHERE sku = @c_SKU
                    SELECT @n_CalcPORcvQty 'Remain Rec qty'
                  END

                  -- Remain Qty use the percentage to allocate
                  IF @n_CalcPORcvQty > 0 
                  BEGIN 
                     SELECT @n_RemainOrdQty = SUM(OpenQty - CalOrdQty) 
                       FROM #Ordlines 
                      WHERE STORERKEY = @c_StorerKey
                        AND SKU = @c_SKU 
                     GROUP BY SKU 

                     -- Ticket 53100, Endless Loop 
                     IF @n_RemainOrdQty > 0 
                     BEGIN 
                        SELECT @n_PercentRemain = @n_CalcPORcvQty / @n_RemainOrdQty
                        SELECT @n_RowNo = 0 
                        SELECT @n_CalcPORcvQty = FLOOR(@n_CalcPORcvQty/@n_CaseCnt)
      
                        IF @b_debug = '1'
                        BEGIN  
                           Print 'In the Calculate Loop'
                           SELECT @n_CalcPORcvQty 'Remain Rec qty', @n_RemainOrdQty 'remain ord qty',
                                  @n_PercentRemain '% cal', @n_CalcPORcvQty 'remain rec qty (cs)'
                        END
   
                        WHILE @n_CalcPORcvQty > 0  
                        BEGIN
                           IF @b_debug = '1'
                           BEGIN  
                              Print 'In the While Calculate Loop'
                              SELECT @n_CalcPORcvQty 'Remain Rec qty'

                           SELECT OpenQty, QtyAllocated , Qtypicked , CalOrdQty ,  @n_CaseCnt '@n_CaseCnt',
                                  FLOOR((OpenQty - QtyAllocated - Qtypicked - CalOrdQty)/@n_CaseCnt)
                             FROM #Ordlines 
                            WHERE STORERKEY = @c_StorerKey
                              AND SKU = @c_SKU 
                              AND ROWNO > @n_RowNo 

                           END
   
                           SET ROWCOUNT 1
    
                           SELECT @n_RowNo = rowno, 
                                  @n_RemainCaseQty = FLOOR((OpenQty - QtyAllocated - Qtypicked - CalOrdQty) / @n_CaseCnt)
                             FROM #Ordlines 
                            WHERE STORERKEY = @c_StorerKey
                              AND SKU = @c_SKU 
                              AND ROWNO > @n_RowNo 
                              AND OpenQty - QtyAllocated - Qtypicked - CalOrdQty >= @n_CaseCnt  
                           Order By Rowno 
            
   
                           SELECT @n_RowCount = @@ROWCOUNT 
   
                           SET ROWCOUNT 0 
   
                           IF @n_RowCount = 0 AND @n_CalcPORcvQty > 0 
                           BEGIN
                              SELECT @n_RowNo = 0 
                              
                              -- Added by SHONG on 20th Jun 2008 
                              -- To Provent Infinite Loop 
                              IF EXISTS(SELECT 1 FROM #Ordlines 
                                        WHERE STORERKEY = @c_StorerKey
                                          AND SKU = @c_SKU 
                                          AND OpenQty - QtyAllocated - Qtypicked - CalOrdQty >= @n_CaseCnt) 
                                 CONTINUE 
                              ELSE
                                 BREAK 
                           END
                           ELSE
                           BEGIN
                              IF @n_RowCount = 0 Break   
                           END
    
                           IF @n_RowCount = 1 
                           BEGIN 
                              SELECT @n_CalcQty = Round(@n_PercentRemain * @n_RemainCaseQty, 0)
   
                              IF @n_CalcQty = 0 AND @n_CalcPORcvQty > 0
                              BEGIN 
                                 SELECT @n_CalcQty = 1
                              END
   
                              IF @n_CalcPORcvQty - @n_CalcQty  < 0
                              BEGIN
                                 SELECT @n_CalcQty = @n_CalcPORcvQty 
                              END
   
                              IF @b_debug = '1'
                              BEGIN  
                                 Print 'In the While UPDATE'
                                 SELECT @n_CalcQty 'Cal qty'
                              END
   
                              BEGIN TRAN 
                              UPDATE #Ordlines 
                                 SET CalOrdQty = CalOrdQty + (@n_CalcQty * @n_CaseCnt)
                               WHERE rowno = @n_RowNo
      
                              SELECT @n_err = @@ERROR
                              IF @n_err <> 0 
                              BEGIN
                                 IF @@TRANCOUNT >= 1
                                 BEGIN
                                    ROLLBACK TRAN
                                    SELECT @n_Continue = 3
                                    SELECT @i_Error = 15039
                                    SELECT @c_ErrMsg = 'nsp_XDockOrderProcessing - UPDATE Failed on #Ordlines'
                                    BREAK
                                 END
                          END
                        ELSE
                              BEGIN
                                 IF @@TRANCOUNT > 0 
                                 BEGIN
                                    COMMIT TRAN
   
                                    IF @b_debug = '1'
                                    BEGIN  
                                       Print 'Before UPDATE @n_CalcPORcvQty'
                                       SELECT @n_CalcPORcvQty 'remain rec qty', @n_CalcQty 'Cal qty'
                                    END   
   
                                    SELECT @n_CalcPORcvQty = @n_CalcPORcvQty - @n_CalcQty
   
                                    IF @b_debug = '1'
                                    BEGIN  
                                       Print 'after UPDATE @n_CalcPORcvQty'
                                       SELECT @n_CalcPORcvQty 'remain rec qty', @n_CalcQty 'Cal qty'
                                    END   
                                 END
                                 ELSE
                                 BEGIN
                                    ROLLBACK TRAN
            
                                    SELECT @n_Continue = 3
                                    SELECT @i_Error = 15039
                                    SELECT @c_ErrMsg = 'nsp_XDockOrderProcessing - UPDATE Failed on #Ordlines'
                                    BREAK
                                 END
                              END
                           END
                        END
                     END -- if @n_RemainOrdQty
                     -- ENDHere Ticket 53100 
                  END -- @n_CalcPORcvQty > 0 
               END -- IF @n_PORcvQty < @n_POOrdQty 
            END

            FETCH NEXT FROM Sort01_Cursor INTO @c_SKU, @n_TotOrdQty  
         END

         CLOSE Sort01_Cursor
         DEALLOCATE Sort01_Cursor         
      END -- Type = 10 --> Allocate 1 case to each Order, Remaining Qty use Percentage Calculation

    IF @c_Type = '06' 
    BEGIN  
       SELECT Storerkey, Sku, OpenQty, QtyAllocated, Qtypicked, CalOrdQty, 
           Convert(int,Rowno) rowno, IDENTITY(int, 1, 1) AS Rowid 
        INTO #ordsku
         FROM #Ordlines 
       WHERE 1=2
    
       DECLARE Sort06_Cursor CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
       SELECT Distinct Sku 
         FROM #Ordlines 
    
       OPEN Sort06_Cursor 
       FETCH NEXT FROM Sort06_Cursor INTO @c_SKU 
    
       WHILE @@FETCH_STATUS = 0
       BEGIN 
          SELECT @n_POOrdQty = SUM(QtyOrdered), @n_PORcvQty = SUM(QtyReceived)
            FROM PODETAIL (NOLOCK) 
           WHERE PODETAIL.ExternPOKey = @c_ExternPOKey 
             AND PODETAIL.STORERKEY = @c_StorerKey  
             AND PODETAIL.SKU = @c_SKU 
    
        IF @n_POOrdQty <> @n_PORcvQty 
        BEGIN
          INSERT INTO #ordsku (Storerkey, Sku, OpenQty, QtyAllocated, Qtypicked, CalOrdQty, Rowno) 
          SELECT Storerkey, Sku, OpenQty, QtyAllocated, Qtypicked, CalOrdQty, Rowno 
            FROM #Ordlines 
           WHERE STORERKEY = @c_StorerKey 
               AND SKU = @c_SKU 
          ORDER BY rowno 
      
            SELECT @n_lastrow = MAX(rowid)  
              FROM #ordsku 
      
            SELECT @n_Percent = @n_PORcvQty/@n_POOrdQty   
      
            IF @n_PORcvQty > @n_POOrdQty  
            BEGIN
               IF @c_OverAlloc = 'Y'
               BEGIN
                  BEGIN TRAN 
                  
                  UPDATE #ordsku 
                     SET CalOrdQty = FLOOR(@n_Percent * (OpenQty - QtyAllocated - Qtypicked)) 
      
                  SELECT @n_err = @@ERROR
                  IF @n_err <> 0 
                  BEGIN
                     IF @@TRANCOUNT >= 1
                     BEGIN
                        ROLLBACK TRAN
                        SELECT @n_Continue = 3
                        SELECT @i_Error = 15034
                        SELECT @c_ErrMsg = 'nsp_XDockOrderProcessing - UPDATE Failed on #ordsku'
                     END
                  END
                  ELSE
                  BEGIN
                     IF @@TRANCOUNT > 0 
                     BEGIN 
                        SELECT @n_RemainQty = @n_PORcvQty - SUM(CalOrdQty) 
                          FROM #ordsku 
      
                        SELECT @n_RowNo = MIN(Rowid)  
                    FROM #ordsku 
         
                        UPDATE #ordsku 
                           SET CalOrdQty = CalOrdQty + @n_RemainQty 
                         WHERE rowid = @n_RowNo               
      
                        COMMIT TRAN
                     END
                     ELSE
                     BEGIN
                        ROLLBACK TRAN
      
                        SELECT @n_Continue = 3
                        SELECT @i_Error = 15034
                        SELECT @c_ErrMsg = 'nsp_XDockOrderProcessing - UPDATE Failed on #ordsku'
                     END
                  END                     
               END
            END
            ELSE
            BEGIN 
               IF @n_PORcvQty < @n_POOrdQty  
               BEGIN 
                  BEGIN TRAN 
  
              -- Apply Formula to All Rows
                  UPDATE #Ordsku 
                     SET CalOrdQty = CASE WHEN Convert(int, Convert(int,(CalOrdQty*@n_Percent))+(CalOrdQty*(1/(@n_lastrow*rowid)))) > CalOrdQty 
                              THEN CalOrdQty 
                              ELSE Convert(int, Convert(int,(CalOrdQty*@n_Percent))+(CalOrdQty*(1/(@n_lastrow*rowid)))) 
                           END 

                    SELECT @n_RemainQty = @n_PORcvQty - SUM(CalOrdQty) 
                      FROM #ordsku 

              IF @n_RemainQty < 0 
              BEGIN               
                UPDATE #Ordsku 
                       SET CalOrdQty = CalOrdQty - ABS(@n_RemainQty) 
                 WHERE rowid = @n_lastrow
              END
              ELSE
              BEGIN 
                SELECT @n_RowNo = 0
                WHILE @n_RemainQty > 0 
                BEGIN 
                  SET ROWCOUNT 1 

                  SELECT @n_RowNo = rowid, 
                       @n_CalcQty = OpenQty-QtyAllocated-Qtypicked-CalOrdQty 
                    FROM #ordsku 
                   WHERE OpenQty-QtyAllocated-Qtypicked-CalOrdQty > 0   
                    AND rowid > @n_RowNo

                  SET ROWCOUNT 0 

                  IF @n_CalcQty > @n_RemainQty 
                  BEGIN 
                    SELECT @n_CalcQty = @n_RemainQty 
                  END

                  UPDATE #ordsku 
                           SET CalOrdQty = CalOrdQty + @n_CalcQty
                   WHERE rowid = @n_RowNo              

                  SELECT @n_RemainQty = @n_RemainQty - @n_CalcQty 
                END
              END
      
                  SELECT @n_err = @@ERROR
                  IF @n_err <> 0 
                  BEGIN
                     IF @@TRANCOUNT >= 1
                     BEGIN
                        ROLLBACK TRAN
                        SELECT @n_Continue = 3
                        SELECT @i_Error = 15039
                        SELECT @c_ErrMsg = 'nsp_XDockOrderProcessing - UPDATE Failed on #Ordsku'
                        BREAK
                     END
                  END
                  ELSE
                  BEGIN
                IF @@TRANCOUNT > 0
                BEGIN
                       WHILE @@TRANCOUNT > 0 
                       BEGIN  
                          COMMIT TRAN
                       END
                END
                     ELSE
                     BEGIN
                        ROLLBACK TRAN
      
                        SELECT @n_Continue = 3
                        SELECT @i_Error = 15039
                        SELECT @c_ErrMsg = 'nsp_XDockOrderProcessing - UPDATE Failed on #Ordsku'
                        BREAK
                     END
                  END
               END
            END
  
          UPDATE #ordlines set CalOrdQty = #ordsku.CalOrdQty
            from #ordsku 
           WHERE #ordlines.rowno = #ordsku.rowno  

          Truncate table #ordsku
        END
    
          FETCH NEXT FROM Sort06_Cursor INTO @c_SKU 
       END
    
       CLOSE Sort06_Cursor
       DEALLOCATE Sort06_Cursor         
    
      DROP TABLE #ordsku
    END
   END

   -- SOS30495 UOM Allocation
   -- UOM1 = Pallet, UOM2 = Case, UOM3 = InnerPack, UOM4 = Master Unit
   IF (dbo.fnc_RTrim(dbo.fnc_LTrim(@c_UOM1)) <> '' AND dbo.fnc_RTrim(dbo.fnc_LTrim(@c_UOM1)) IS NOT NULL AND @c_UOM1 = 'Y') OR 
     (dbo.fnc_RTrim(dbo.fnc_LTrim(@c_UOM2)) <> '' AND dbo.fnc_RTrim(dbo.fnc_LTrim(@c_UOM2)) IS NOT NULL AND @c_UOM2 = 'Y') OR
     (dbo.fnc_RTrim(dbo.fnc_LTrim(@c_UOM3)) <> '' AND dbo.fnc_RTrim(dbo.fnc_LTrim(@c_UOM3)) IS NOT NULL AND @c_UOM3 = 'Y')
   BEGIN
      SELECT @c_UOMAlloc = 'Y'   -- UOM Allocation
     SELECT @c_GetPack = 'Y'    -- Get Pack Info
   END

   -- SOS45047 WTCPH Print Store-Addressed Label
   -- ContainerQty store No. of Labels to be printed
   -- Default CaseID to indicate as Store-Addressed stock if found ContainerQty > 0
   IF EXISTS (SELECT 1 FROM  Receipt RH (NOLOCK)
              INNER JOIN ReceiptDetail RD ON (RH.ReceiptKey = RD.ReceiptKey)
              INNER JOIN OrderDetail OL ON (RD.ExternReceiptKey = OL.ExternPOKey AND
                                          RD.StorerKey = OL.StorerKey) 
              WHERE RD.ExternReceiptKey = @c_ExternPOKey
              AND   RH.Status = '9'
              AND   RD.FinalizeFlag = 'Y'
              AND   RH.ContainerQty > 0)
   BEGIN
      SELECT @c_CaseID = '(STORADDR)'
   END
   ELSE
   BEGIN
      SELECT @c_CaseID = ''   
   END

   -- Part 4
   IF (@n_Continue = 1 OR @n_Continue =2) 
   BEGIN 
      IF @b_debug = '1'
      BEGIN 
      select * from #Ordlines WHERE sku = @c_SKU
         select * from #Inventory
      END

      SELECT @n_RowNo = 0  
      
      WHILE (1=1) and (@n_Continue = 1 OR @n_Continue =2)
      BEGIN 
         SET ROWCOUNT 1

         SELECT @n_RowNo = rowno,  @c_orderkey = Orderkey, @c_orderline = Orderlinenumber, 
                @c_SKU = Sku, @n_OpenQty = OpenQty - Qtypicked - QtyAllocated  , 
                @n_ShippedQty = ShippedQty, @n_AllocateQty = QtyAllocated, @n_PickQty = Qtypicked, 
                @c_Packkey = Packkey, @c_UOM = UOM, @c_Lottable03 = Lottable03, 
                @n_CalOrdQty = CalOrdQty  /* - Qtypicked - QtyAllocated */
                ,@c_Storerkey = Storerkey, @c_ID = ID                                --(SSA01)
           FROM #Ordlines 
          WHERE Rowno > @n_RowNo 
          ORDER BY Rowno 

         SELECT @n_RowCount = @@ROWCOUNT

         SET ROWCOUNT 0

         IF @n_RowCount = 0 
         BEGIN
            BREAK 
         END 
         
      -- SOS30495
      IF @c_GetPack = 'Y'  -- Get Pack Info
      BEGIN
        SELECT @n_PackPallet  = Pallet, 
             @n_PackCaseCnt = CaseCnt, 
             @n_PackInner   = InnerPack
          FROM PACK (NOLOCK) 
         WHERE Packkey = @c_PackKey

        If @b_debug = '1'
        BEGIN
          select 'rowno from #ordlines ', @n_RowNo 'rowno', @c_orderkey '@c_orderkey'
          select 'Pack info', @c_PackKey 'Packkey', @n_PackPallet 'PackPallet', @n_PackCaseCnt 'PackCaseCnt',
               @n_PackInner 'PackInner'
        End
      END         

         SELECT @n_RemainQty = @n_CalOrdQty  

         IF @b_debug = '1'
         BEGIN 
            select @c_SKU 'sku', @n_RemainQty 'remainqty', @n_OpenQty 'OpenQty'
            select @c_SKU 'sku', @n_CalOrdQty 'calqty', @n_OpenQty 'OpenQty'
         END

         IF @n_CalOrdQty > @n_OpenQty 
         BEGIN 
            BEGIN TRAN  

            UPDATE ORDERDETAIL 
               SET OpenQty = OpenQty + (@n_CalOrdQty - @n_OpenQty)
             WHERE Orderkey = @c_orderkey
               AND Orderlinenumber = @c_orderline 

            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
            IF @n_err <> 0 
            BEGIN 
               IF @@TRANCOUNT >= 1
               BEGIN
                  ROLLBACK TRAN 
               END

               SELECT @n_Continue = 3
               SELECT @c_ErrMsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 15095   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_ErrMsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": UPDATE of Orderdetail Table Failed (nsp_XDockOrderProcessing)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ErrMsg)) + " ) "
               BREAK 
            END 
            IF @n_Continue = 1 OR @n_Continue = 2
            BEGIN
               IF @@TRANCOUNT > 0 
               BEGIN
                  COMMIT TRAN
               END
               ELSE
               BEGIN 
                  ROLLBACK TRAN 
               END
            END 

            BEGIN TRANSACTION 
            
            UPDATE ORDERDETAIL 
               SET OriginalQty = OpenQty - (@n_CalOrdQty - @n_OpenQty),  
                   AdjustedQty = AdjustedQty + (@n_CalOrdQty - @n_OpenQty), 
                   Trafficcop = NULL 
             WHERE Orderkey = @c_orderkey
               AND Orderlinenumber = @c_orderline 

            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
            IF @n_err <> 0 
            BEGIN 
               SELECT @n_Continue = 3
               SELECT @c_ErrMsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 15095   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_ErrMsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": UPDATE of Orderdetail Table Failed (nsp_XDockOrderProcessing)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ErrMsg)) + " ) "
          BREAK 
            END 
            ELSE
            BEGIN
               COMMIT TRAN
            END 
         END -- @n_CalOrdQty > @n_OpenQty 
         SET @c_SQLStmt = N'SELECT TOP 1 @n_RowNo1 = rowno'                         --(SSA01)
            +', @n_InvQty = Qty'
            +', @c_lot = Lot'
            +', @c_loc = Loc'
            +', @c_Id  = ID'
            +' FROM  #Inventory'
            +' WHERE Storerkey = @c_Storerkey'
            +' AND   Sku = @c_SKU'
            +' AND   Qty > 0'
            + CASE WHEN @c_ID <> '' THEN 'AND ID = @c_ID' ELSE '' END
            +' AND   Rowno >= @n_RowNo1'
            +' ORDER BY Rowno'

         SET @c_SQLParms = N'@n_RowNo1      INT OUTPUT'
                         + ',@n_InvQty      INT OUTPUT'
                         + ',@c_lot         NVARCHAR(10) OUTPUT'
                         + ',@c_loc         NVARCHAR(10) OUTPUT'
                         + ',@c_ID          NVARCHAR(18) OUTPUT'
                         + ',@c_Storerkey   NVARCHAR(15) '
                         + ',@c_Sku         NVARCHAR(20) '
         SELECT @n_RowNo1 = 0
         
         WHILE (@n_RemainQty > 0)
         BEGIN
            --(SSA01) - START
            --SET ROWCOUNT 1
       
            --SELECT @n_RowNo1 = rowno, @n_InvQty = Qty, @c_lot = Lot, @c_loc = Loc, @c_Id = ID
            --FROM  #Inventory
            --WHERE Sku = @c_SKU
            --AND   Qty > 0
            --AND   Rowno >= @n_RowNo1

            SET @c_Lot = '' SET @c_Loc = ''

            EXEC sp_ExecuteSQL @c_SQLStmt
                              ,@c_SQLParms
                              ,@n_RowNo1     OUTPUT
                              ,@n_InvQty     OUTPUT
                              ,@c_lot        OUTPUT
                              ,@c_loc        OUTPUT
                              ,@c_ID         OUTPUT
                              ,@c_Storerkey
                              ,@c_Sku
   
            IF @@ROWCOUNT = 0 
            BEGIN 
               --SET ROWCOUNT 0
               BREAK 
            END

            --SET ROWCOUNT 0
            --(SSA01) - END

        -- SOS30495 UOM Allocation
            -- UOM1 = Pallet, UOM2 = Case, UOM3 = InnerPack, UOM4 = Master Unit
        -- Rules:
        /* A) If UOM1 is not blank and UOM1 = 'Y' and (@n_RemainQty >= @n_PackPallet), 
                     generate Pickdetail with uom='1' and qty=Pallet;
            if (@n_RemainQty = @n_RemainQty - @n_PackPallet > 0) and (@n_RemainQty >= @n_PackPallet)
                then Repeat A else goto B
           B) If UOM2 is not blank and UOM2 = 'Y' and (@n_RemainQty >= @n_PackCaseCnt), 
                     generate Pickdetail with uom='2' and qty=CaseCnt;
            if (@n_RemainQty = @n_RemainQty - @n_PackCaseCnt> 0) and (@n_RemainQty >= @n_PackCaseCnt)
                then Repeat B else goto C
           C) If UOM3 is not blank and UOM1 = 'Y' and (@n_RemainQty >= @n_PackInner), 
                     generate Pickdetail with uom='3' and qty=InnerPack;
            if (@n_RemainQty = @n_RemainQty - @n_PackInner > 0) and (@n_RemainQty >= @n_PackInner)
                then Repeat C else goto D
           D) If UOM4 is not blank and UOM1 = 'Y' and (@n_RemainQty > 0),
                     generate Pickdetail with uom='6' and qty=@n_RemainQty 
            */
            IF @c_UOMAlloc = 'Y'
            BEGIN
              If @b_debug = '1' 
              BEGIN
                select @n_InvQty '@n_InvQty', @n_RemainQty '@n_RemainQty'
              End     
               -- UOM1
              IF (@c_UOM1 = 'Y') AND (@n_PackPallet > 0) AND (@n_RemainQty >= @n_PackPallet)
              AND (@n_InvQty >= @n_PackPallet)    --@n_RemainQty)                   --(Wan01) 
              BEGIN
                If @b_debug = '1' 
                BEGIN
                  select 'UOM1 is setup'
                End
                  
                SELECT @n_PDAllocQty = @n_PackPallet
                SELECT @n_RemainQty = @n_RemainQty - @n_PackPallet
                SELECT @c_PDUOM = '1'
                SELECT @n_UOMQty = @n_PackPallet --@n_PDAllocQty / @n_PackPallet                                             
              END
               -- UOM2
              ELSE IF (@c_UOM2 = 'Y') AND (@n_PackCaseCnt > 0) AND (@n_RemainQty >= @n_PackCaseCnt)
                   AND (@n_InvQty >= @n_PackCaseCnt)--@n_RemainQty)                 --(Wan01) 
              BEGIN
                If @b_debug = '1' 
                BEGIN
                  select 'UOM2 is setup'
                End

                --IF @n_RemainQty % @n_PackCaseCnt > 0 -- having remainder          --(Wan01) - START
                --BEGIN
                --  SELECT @n_PDAllocQty = @n_RemainQty - (@n_RemainQty % @n_PackCaseCnt)
                --  SELECT @n_RemainQty = @n_RemainQty % @n_PackCaseCnt
                --END
                --ELSE
                --BEGIN
                --  SELECT @n_PDAllocQty = @n_RemainQty
                --  SELECT @n_RemainQty = 0
                --END
                SET @n_PDAllocQty = @n_PackCaseCnt
                SET @n_RemainQty = @n_RemainQty - @n_PackCaseCnt                    --(Wan01) - END
                SELECT @c_PDUOM = '2'
                SELECT @n_UOMQty = @n_PackCaseCnt                                                               
              END  
               -- UOM3
              ELSE IF (@c_UOM3 = 'Y') AND (@n_PackInner > 0) AND (@n_RemainQty >= @n_PackInner)   --(Wan01)
                   AND (@n_InvQty >= @n_PackInner)   --@n_RemainQty)                --(Wan01)
              BEGIN
                If @b_debug = '1' 
                BEGIN
                  select 'UOM3 is setup'
                End

                --IF @n_RemainQty % @n_PackInner > 0 -- having remainder            --(Wan01) - START
                --BEGIN
                --  SELECT @n_PDAllocQty = @n_RemainQty - (@n_RemainQty % @n_PackInner)
                --  SELECT @n_RemainQty = @n_RemainQty % @n_PackInner
                --END
                --ELSE
                --BEGIN
                --  SELECT @n_PDAllocQty = @n_RemainQty
                --  SELECT @n_RemainQty = 0
                --END
                SET @n_PDAllocQty = @n_PackInner
                SET @n_RemainQty = @n_RemainQty - @n_PackInner                      --(Wan01) - END
                SELECT @c_PDUOM = '3'
                SELECT @n_UOMQty = @n_PackInner                                                                 
              END
              -- UOM4                                                                      
              ELSE IF (@c_UOM4 = 'Y') AND (@n_RemainQty > 0) AND (@n_InvQty > 0)
              BEGIN
                If @b_debug = '1' 
                BEGIN
                  select 'UOM4 is setup'
                End

                 IF (@n_RemainQty - @n_InvQty) > 0 
                 BEGIN
                    SELECT @n_PDAllocQty = @n_InvQty
                    SELECT @n_RemainQty = @n_RemainQty - @n_InvQty  
                 END
                 ELSE
                 BEGIN 
                    SELECT @n_PDAllocQty = @n_RemainQty
                    SELECT @n_RemainQty = 0 
                 END
                 
                 SELECT @c_PDUOM = '6'
                 SELECT @n_UOMQty = 1               
              END

              If @b_debug = '1' 
              BEGIN               
                select 'PRINT ', @n_PDAllocQty '@n_PDAllocQty', @n_RemainQty '@n_RemainQty', @n_InvQty '@n_InvQty', @c_PDUOM '@c_PDUOM'
              END
            END -- SOS30495 UOM Allocation
            ELSE
            BEGIN -- @UOMAlloc <> 'Y' (Normal)
--                SET ROWCOUNT 1
--    
--                SELECT @n_RowNo1 = rowno, @n_InvQty = Qty, @c_lot = Lot, @c_loc = Loc, @c_Id = ID
--                  FROM #Inventory 
--                 WHERE Sku = @c_SKU 
--                   AND Qty > 0 
--                   AND Rowno > @n_RowNo1 
--    
--                IF @@ROWCOUNT = 0 
--                BEGIN 
--                   SET ROWCOUNT 0
--                   BREAK 
--                END
--    
--                SET ROWCOUNT 0

               IF (@n_RemainQty - @n_InvQty) > 0 
               BEGIN
                  SELECT @n_PDAllocQty = @n_InvQty
                  SELECT @n_RemainQty = @n_RemainQty - @n_InvQty  
               END
               ELSE
               BEGIN 
                  SELECT @n_PDAllocQty = @n_RemainQty
                  SELECT @n_RemainQty = 0 
               END
               
               SELECT @c_PDUOM = '6'
               SELECT @n_UOMQty = 1
               
            END   
            /*
            EXEC nspg_getkey
               'PICKHEADERKEY' ,
               10 ,
               @c_pickhdkey   OUTPUT ,
               @b_success     OUTPUT,
               @n_err         OUTPUT,
               @c_ErrMsg      OUTPUT 
   
            IF NOT @b_success = 1
            BEGIN
               SELECT @n_Continue = 3
               SELECT @i_Error = 15200
               SELECT @c_ErrMsg = 'nsp_XDockOrderProcessing - Generation of PickHeader Key Failed'
               BREAK
            END
            */
            EXEC nspg_getkey
               'PICKDETAILKEY' ,
               10 ,
               @c_pickdetkey  OUTPUT ,
               @b_success     OUTPUT,
               @n_err         OUTPUT,
               @c_ErrMsg      OUTPUT 
   
            IF NOT @b_success = 1
            BEGIN
               SELECT @n_Continue = 3
               SELECT @i_Error = 15150
               SELECT @c_ErrMsg = 'nsp_XDockOrderProcessing - Generation of PickDetail Key Failed'
               BREAK
            END
            /* 
            EXEC nspg_getkey
               'CARTONID' ,
               10 ,
               @c_caseid      OUTPUT ,
               @b_success     OUTPUT,
               @n_err         OUTPUT,
               @c_ErrMsg      OUTPUT 
   
            IF NOT @b_success = 1
            BEGIN
               SELECT @n_Continue = 3
               SELECT @i_Error = 15180
               SELECT @c_ErrMsg = 'nsp_XDockOrderProcessing - Generation of CASE ID Key Failed'
               BREAK
            END
            */       
            IF @b_debug = '1'
            BEGIN 
                select 'Values to insert into PickDetail'
                select @c_pickdetkey, @c_orderkey, @c_orderline, @c_StorerKey, @c_SKU, 
                      @n_PDAllocQty, @c_lot, @c_loc, @c_Id, @c_Packkey
            END
            
            BEGIN TRAN 
            INSERT PICKDETAIL (Pickdetailkey, CASEID, PickHeaderKey, OrderKey, Orderlinenumber, 
                               Storerkey, Sku, UOM, UOMQty, Qty, Lot, Loc, ID, Packkey, CartonGroup)  
                       --VALUES (@c_pickdetkey, '', '', @c_orderkey, @c_orderline,  -- SOS45047
                       --        @c_StorerKey, @c_SKU, 6, 1, @n_PDAllocQty, @c_lot, -- SOS30495
                       VALUES (@c_pickdetkey, @c_CaseID, '', @c_orderkey, @c_orderline,
                               @c_StorerKey, @c_SKU, @c_PDUOM, @n_UOMQty, @n_PDAllocQty, @c_lot, 
                           @c_loc, @c_Id, @c_Packkey, 'STD' ) 


            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
            IF @n_err <> 0 
            BEGIN 
               IF @@TRANCOUNT >= 1
               BEGIN
                  ROLLBACK TRAN 
               END

               SELECT @n_Continue = 3
               SELECT @c_ErrMsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 15200   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_ErrMsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": INSERT of Pickdetail Table Failed (nsp_XDockOrderProcessing)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ErrMsg)) + " ) "
               BREAK 
            END 
            IF @n_Continue = 1 or @n_Continue = 2
            BEGIN
               IF @@TRANCOUNT > 0 
               BEGIN
                  COMMIT TRAN
               END
               ELSE
               BEGIN 
                  ROLLBACK TRAN 
               END
            END 

            BEGIN TRAN     
            UPDATE #Inventory 
               SET Qty = Qty - @n_PDAllocQty 
             WHERE Rowno = @n_RowNo1  


            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
            IF @n_err <> 0 
            BEGIN 
               IF @@TRANCOUNT >= 1
               BEGIN
                  ROLLBACK TRAN 
               END

               SELECT @n_Continue = 3
               SELECT @c_ErrMsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 15220   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_ErrMsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": UPDATE of TEMP Table Failed (nsp_XDockOrderProcessing)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ErrMsg)) + " ) "
               BREAK 
            END 
            IF @n_Continue = 1 or @n_Continue = 2
            BEGIN
               IF @@TRANCOUNT > 0 
               BEGIN
                  COMMIT TRAN
               END
               ELSE
               BEGIN 
                  ROLLBACK TRAN 
               END
            END 
         END -- WHILE (@n_RemainQty > 0)
         
      END -- WHILE (1=1) and (@n_Continue = 1 OR @n_Continue =2)
   END -- Part 4 - IF (@n_Continue = 1 OR @n_Continue =2)  

   DROP TABLE #TEMPSKU 
   DROP TABLE #Ordlines
   DROP TABLE #CONSIGNEE
   DROP TABLE #Inventory

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SELECT @i_success = 0
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_starttcnt
         BEGIN
            COMMIT TRAN
         END
      END
      execute nsp_logerror @i_Error, @c_ErrMsg, "nsp_XDockOrderProcessing"
      RAISERROR (@c_ErrMsg, 16, 1) WITH SETERROR    -- SQL2012
      SELECT @i_success, @i_Error, @c_ErrMsg
      RETURN
   END
   ELSE
   BEGIN
      SELECT @i_success = 1
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      SELECT @i_success, @i_Error, @c_ErrMsg
      RETURN
   END
END

GO