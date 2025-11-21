SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: nspALCFG03                                            */
/* Creation Date: 18-APR-2018                                              */
/* Copyright: LF                                                           */
/* Written by:                                                             */
/*                                                                         */
/* Purpose: WMS-4344 Allocation Configure by codelkup                      */
/*          (Work with SkipPreAllocation)                                  */
/*                                                                         */
/* Called By: nspOrderProcessing                                           */
/*                                                                         */
/* PVCS Version: 1.3                                                       */
/*                                                                         */
/* Version: 8.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date        Author   Rev  Purposes                                      */
/* 17/04/2019  NJOW01   1.0  WMS-4344 allow allocate qtyreplen             */
/* 15/07/2019  NJOW02   1.1  Fix shelflife flag                            */
/* 18/07/2019  NJOW03   1.2  Change dyanmic sql by param                   */
/* 11-May-2020 Wan01    1.3  Dynamic SQL review, impact SQL cache log      */
/* 23-Jun-2021 NJOW04   1.4  WMS-17326 allow skip lottable filtering       */
/* 18-Apr-2022 NJOW05   1.5  WMS-19509 allow set sorting by dynamic SQL    */
/* 18-Apr-2022 NJOW05   1.5  DEVOPS Combine script                         */
/* 05-May-2022 NJOW06   1.6  WMS-19571 support get strategykey from wave   */
/*                           loadplan.defaultstrategykey and               */
/*                           config StorerDefaultAllocStrategy             */
/* 05-Sep-2022 NJOW07   1.7  WMS-19993 FIFO by multi UOM                   */
/* 18-Nov-2022 NJOW08   1.8  WMS-21206 Add force allocate lottable by      */
/*                           by config include empty lottable filterring   */
/* 29-Sep-2023 CLVN01   1.9  JSM-54130 Add AllocateStrategyKey to condition*/
/* 29-Sep-2023 CLVN01   1.9  JSM-54130 Fix Syntax Error                    */
/* 29-Jan-2023 NJOW09   2.0  WMS-24736 Add UCC allocation and allow skip   */
/*                           step by discrete or conso                     */
/* 12-Mar-2024 NJOW10   2.1  WMS-24736 Fix FIFO by UOM cater for UCC       */
/* 24-Jan-2024 NJOW11   2.2  Fix FULLPALLETBYLOC logic                     */
/***************************************************************************/

CREATE     PROC [dbo].[nspALCFG03]
   @c_DocumentNo NVARCHAR(10),
   @c_Facility   NVARCHAR(5),
   @c_StorerKey  NVARCHAR(15),
   @c_SKU        NVARCHAR(20),
   @c_Lottable01 NVARCHAR(18),
   @c_Lottable02 NVARCHAR(18),
   @c_Lottable03 NVARCHAR(18),
   @d_Lottable04 DATETIME,
   @d_Lottable05 DATETIME,
   @c_Lottable06 NVARCHAR(30),
   @c_Lottable07 NVARCHAR(30),
   @c_Lottable08 NVARCHAR(30),
   @c_Lottable09 NVARCHAR(30),
   @c_Lottable10 NVARCHAR(30),
   @c_Lottable11 NVARCHAR(30),
   @c_Lottable12 NVARCHAR(30),
   @d_Lottable13 DATETIME,
   @d_Lottable14 DATETIME,
   @d_Lottable15 DATETIME,
   @c_UOM        NVARCHAR(10),
   @c_HostWHCode NVARCHAR(10),
   @n_UOMBase    INT,
   @n_QtyLeftToFulfill INT,
   @c_OtherParms NVARCHAR(200)=''
AS
BEGIN
/*
   Codelkup Setup
   --------------
   Listname: nspALCFG03
   Short: AllocateStrategykey(optional)
   Storerkey: <Storer> (if setup short(AllocateStrategykey), storerkey is optional either key in storerkey or AllocateStrategykey)
   code2: for UOM(optional).

   Code                 Description                                                     Notes UDF01            UDF02  UDF03  UDF04  UDF05
   --------------------------------------------------------------------------------------------------------------------------------------
   ALLOCATEHOLD         Allow allocate from Hold Inventory(default N)                          Y/N
   FROMPBULKLOC         Allocate from bulk only (default N)                                    Y/N
   FROMPICKLOC          Allocate from pick only (default N)                                    Y/N
   FULLPALLETBYLOC      Allocate as full pallet if no remain qty at the loc (default N)        Y/N
   CONDITION            Additional allocation retrieve condition                          SQL
   SORTING              Custom sorting (default FIFO)                                     SQL  <BLANK>/DYNAMICSQL
   LOCTYPESEQ           Custom allocate by locationtype and sequence                           Locationtype by sequence (UDF01-05)
   SHELFLIFE            Allocation Check shelflife (default N)                                 E/M/N
   LISTNAME             Refer the allocation setting from user created listname                <Listname>
   ALLOCATEQTYREPLEN    Allow allocate qty reserved for replenish at bulk loc                  Y/N
   SKIPLOTTABLEFILTER   Allow skip filtering for certain lottable 01-15                        01-15
   FIFOBYMULTIUOM       Enforce FIFO by multiple UOM. (Default N)                         SQL  Y/N
   FORCELOTTABLEFILTER  Force filtering for certain lottable 01-05 to include empty lottable   01-15
   ALLOCATEBYUCC        Allocate by UCC (default N)                                            Y/N
   SKIPDISCRETE         Skip when discrete allocation (default N)                              Y/N
   SKIPLOADCONSO        Skip when load conosolidate allocation (default N)                     Y/N
   SKIPWAVECONSO        Skip when wave consolidate allocation (default N)                      Y/N

   Notes:
   1.  Code2 - Optional UOM. If de fined, the setup only apply to the same UOM in the strategy otherwise apply to all UOM
       using this pickcode. The values are 1 to 7 or empty.
   2.  UDF01 is the Y or N flag for enable or disable ALLOCATEHOLD, FROMPICKLOC, FROMBULKLOC, FULLPALLETBYLOC, FIFOBYMULTIUOM, ALLOCATEBYUCC, SKIPDISCRETE
       SKIPLOADCONSO and SKIPWAVECONSO. If ALLOCATEHOLD is not setup, will not allocate hold stock.
   3.  If FROMPICKLOC and FROMBULKLOC are not enabled/setup, it will allocate from both BULK and PICK. Pick Loc is determind
       by SKUXLOC.Locationtype IN('PICK','CASE').
   4.  SQL for CONDITION can be any filtering condition based on tables LOT, LOTATTRIBUTE, LOTxLOCxID, SKUXLOC, LOC, ID, PACK, SKU, STORER.
       e.g. LOC.LocationCategory='DYNPPICK' AND LOC.LocLevel=1
   5.  SQL for SORTING can be any field based on tables LOTxLOCxID, SKUXLOC, LOC, ID, SKU, PACK, LOTATTRIBUTE.
       Instead of field it also can be a code like FIFO or FIFO. We also can include calculated field in sorting like QTYAVAILABLE.
       The default sorting is FIFO Which is sort by LOTATTRIBUTE.Lottable05, LOTATTRIBUTE.Lot, LOC.LogicalLocation, LOC.Loc.
       e.g. LOTATTRIBUTE.Lottable05, CASE WHEN LOC.LocLevel = 1 THEN 1 ELSE 2 END, LOC.LogicalLocation, LOC.Loc
       e.g2. FEFO
       If UDF01 is set as DYNAMICSQL, it allow using DYNAMIC SQL method to return different sorting fields by conditions. The sorting fields must return to variable @c_SortingFields.
       In the Dyamic SQL we can apply the variables like @c_Orderkey, @c_OrderLineNumber, @c_Storerkey, @c_Sku, @c_Facility, etc. @c_Orderkey only applicable for discrete allocation mode.
       e.g. SELECT @c_SortFields = CASE WHEN O.Type = 'XYZ' THEN 'LOC.Pickzone, LOTATTRIBUTE.Lottable05, LOC.LogicalLoc' ELSE 'LOTATTRIBUTE.Lottable05, LOC.LogicalLoc' END
            FROM ORDERS O (NOLOCK) WHERE O.Orderkey = @c_Orderkey
       e.g2. SELECT @c_SortFields = CASE WHEN SKU.SkuGroup = 'FOOD' THEN 'LOTATTRIBUTE.Lottable04, LOC.LogicalLoc, LOC.Loc' ELSE 'FIFO' END
             FROM SKU (NOLOCK) WHERE Storerkey = @c_Storerkey AND Sku = @c_Sku
   6.  For LOCTYPESEQ, set the LOC.LocationType in UDF01-05. If set only allocate from the locationtype and follow the UDF field
       sequence. Should set for both preallocation and allocation strategy.
   7.  Short - Optional allocationstrategykey. if defined, the setup only apply to the same allocationstrategy of the sku otherwise apply to all.
   8.  Storerkey - storer. The setup only apply to the same storer of the sku.
       If Short is defined, storer is optional. if key-in storerkey, the setup apply to the same storer and allocationstrategykey
       if key-in allocationstrageykey, the setup apply to the same allocationstrategykey of all storer.
   9.  FULLPALLETBYLOC is only work for Pallet(UOM 1).
   10. For SHELFLIFE. Set E to enable check shelflife by expiry date in lottable04, M to check by manufacturing date, N is no checking.
   11. For LISTNAME. Only need to provide storerkey and UDF01. This option only can apply to listname 'nspALCFG03'
   12. For SKIPLOTTABLEFILTER, include the lottable need to skip filtering in the list delimited by comman from 01 to 15. e.g. 02,04,08
   13. For FIFOBYMULTIUOM, Must complete pick a batch before proceed to next irregardless different UOM. The sorting must be Lottable05.
       Notes is the optional SQL filtering condition to search the available lots from all location types of different UOM for FIFO calculation.
       SQL can be any filtering condition based on tables LOT, LOTATTRIBUTE, LOTxLOCxID, SKUXLOC, LOC, ID, PACK, SKU, STORER.
       e.g. LOC.LocationType IN('CASE','PICK') AND LOTATTRIBUTE.Lottable06='OK'
       LOT, LOTATTRIBUTE, LOTxLOCxID, SKUXLOC, LOC, ID, PACK, SKU, STORER
   14. For FORCELOTTABLEFILTER, include the lottable need to force filtering in the list delimited by comman from 01 to 15. e.g. 02,04,08
       The specific Orderdetail's Lottable value must exactly match with the lotattribute's lottable including empty lottable filter.
   15. For ALLOCATEBYUCC, only support UOM 2,6 & 7. Storerconfig UCCALLOCATION must turn on to change UCC Status to 3 and stamp UCC# to pickdetail.dropid after allocation.
   16. For SKIPDISCRETE, it allow to skip the allocation when the step allocate by disrete mode(by order).
   17. For SKIPLOADCONSO, it allow to skip the allocation when the step allocate by disrete mode(by load).
   18. For SKIPWAVECONSO, it allow to skip the allocation when the step allocate by disrete mode(by wave).
   19. For SKIPDISCRETE, SKIPLOADCONSO, SKIPWAVECONSO usually it work with storerconfig DiscreteAllocB4LoadConso, DiscreteAllocB4LoadConso, LoadConsoAllocB4WaveConso,
       DiscreteAllocAfterLoadConso, DiscreteAllocAfterWaveConso, LoadConsoAllocation and WaveConsoAllocation. By this config the strategy will execute two times in different mode,
       hence we can skip certain step by the code.

   Shelflife logic and sequence
   ----------------------------
   1. Order detail shelflife (orderdetail.Minshelflife)  - if Orderinfo4Allocation turn on with discrete allocation
   2. Consignee+Sku shelflife ((Consingneekey=Storer.MinShelflife/100) * Sku.Shelflife) - if Orderinfo4Allocation turn on with discrete allocation
   3. Consigneegroup + skugroup shelflife (Doclkup.consigneegroup + Doclkup.skugroup) - if Orderinfo4Allocation turn on with discrete allocation
   4. Sku outgoing shelflife (Sku.SUSR2)
   5. Storer+Sku shelflife ((Storer.MinShelflife/100) * Sku.Shelflife)
*/

   DECLARE @n_StorerSkuMinShelfLife    INT,
           @n_ConsigneeSkuMinShelfLife INT,
           --@n_ConsigneeMinShelfLife INT,
           @n_SkuOutGoingMinShelfLife  INT,
           @n_OrderMinShelfLife        INT,
           @n_ConsigneeSkuGroupMinShelfLife INT,
           @c_ContinueChkShelfLife NCHAR(1),
           @n_Cnt                  INT,
           @c_Condition       NVARCHAR(MAX),
           @c_SQLStatement    NVARCHAR(MAX),
           @c_SQLParms        NVARCHAR(MAX)='',       --(Wan01)
           @C_SortBy          NVARCHAR(2000),
           @c_Orderkey        NVARCHAR(10)='',
           @c_OrderLineNumber NVARCHAR(5)='',
           @c_ID              NVARCHAR(18),
           @c_UDF01 NVARCHAR(30),
           @c_UDF02 NVARCHAR(30),
           @c_UDF03 NVARCHAR(30),
           @c_UDF04 NVARCHAR(30),
           @c_UDF05 NVARCHAR(30),
           @c_LocTypeFlag NCHAR(1),
           @c_LocTypeList NVARCHAR(1000),
           @c_AllocateHoldFlag NCHAR(1),
           @c_AllocateQtyReplenFlag NCHAR(1),
           @c_OverAllocateFlag NCHAR(1),
           @c_SortingFlag      NCHAR(1),
           @c_Sortfields   NVARCHAR(2000),
           @c_SortMode     NVARCHAR(10), --NJOW05
           @c_LocTypeSort  NVARCHAR(2000),
           @c_CLKCondition NVARCHAR(MAX),
           @c_CLKConditionFlag NCHAR(1),
           @c_FromPickLocFlag  NCHAR(1),
           @c_FromBulkLocFlag  NCHAR(1),
           @c_AllocateStrategyKey NVARCHAR(10),
           @c_FullPalletByLocFlag NCHAR(1),
           @c_ShelfLifeFlag       NCHAR(1),
           @c_FIFOByMultiUOM      NCHAR(1)='N', --NJOW07
           @c_SQL                 NVARCHAR(MAX),
           @n_QtyAvailable     INT,
           @c_LOT              NVARCHAR(10),
           @c_LOC              NVARCHAR(10),
           @c_OtherValue       NVARCHAR(500),  --NJOW09
           @n_QtyToTake        INT,
           @n_LocQty           INT,
           @n_NoOfLot          INT,
           @c_ListName         NVARCHAR(10),
           @c_AllocateGetCasecntFrLottable NVARCHAR(30),
           @n_LotQtyAvailable  INT,
           @c_SkipLottableFilter  NVARCHAR(60), --NJOW04
           @c_Wavekey             NVARCHAR(10)='', --NJOW06
           @c_Loadkey             NVARCHAR(10)='', --NJOW06
           @c_key3                NVARCHAR(10)='',  --NJOW06
           @c_StorerDefaultAllocStrategy NVARCHAR(30)='', --NJOW06
           @dt_CurrLottable05     DATETIME, --NJOW07
           @c_ForceLottableFilter NVARCHAR(60), --NJOW08
           @c_AllocateByUCCFlag   NVARCHAR(1)='N', --NJOW09
           @c_SkipDiscreteFlag    NVARCHAR(1)='N', --NJOW09
           @c_SkipLoadConsoFlag   NVARCHAR(1)='N', --NJOW09
           @c_SkipWaveConsoFlag   NVARCHAR(1)='N', --NJOW09
           @n_PrevLotQtyAvailable INT = 0, --NJOW09
           @c_ConditionForLot     NVARCHAR(MAX) = '', --NJOW09
           @c_CLKConditionForLot  NVARCHAR(MAX) = ''  --NJOW09

    SET @c_LocTypeList = ''
    SET @c_LocTypeSort = ''
    SET @c_CLKCondition = ''
    SET @c_Condition = ''
   --SET @n_ConsigneeMinShelfLife = 0
   SET @n_SkuOutGoingMinShelfLife = 0
   SET @n_OrderMinShelfLife = 0
   SET @n_StorerSkuMinShelfLife = 0
   SET @n_ConsigneeSkuMinShelfLife = 0
   SET @n_ConsigneeSkuGroupMinShelfLife = 0
   SET @c_ContinueChkShelfLife = 'N'
   SET @c_SkipLottableFilter = '' --NJOW04
   SET @c_ForceLottableFilter = '' --NJOW08

   EXEC isp_Init_Allocate_Candidates         --(Wan01)

   SELECT @c_StorerDefaultAllocStrategy = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'StorerDefaultAllocStrategy') --NJOW06

   /*SELECT @c_AllocateGetCasecntFrLottable = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'AllocateGetCasecntFrLottable')

   IF ISNULL(@c_AllocateGetCasecntFrLottable,'') IN ('01','02','03','06','07','08','09','10','11','12') AND @c_UOM = '2'
   BEGIN
      SET @n_UOMBase = 1
   END*/

   IF LEN(@c_OtherParms) > 0
   BEGIN
      SELECT @c_OrderLineNumber = SUBSTRING(@c_OtherParms, 11, 5)
      SELECT @c_Key3 = SUBSTRING(@c_OtherParms, 16, 1)

      IF ISNULL(@c_OrderLineNumber,'') <> ''
      BEGIN
         SELECT @c_Orderkey = LEFT(@c_OtherParms, 10)  --discrete by order

         SELECT @c_ID = ID,
                @n_OrderMinShelfLife = MinShelfLife
         FROM ORDERDETAIL(NOLOCK)
         WHERE Orderkey = @c_Orderkey
         AND OrderLineNumber = @c_OrderLineNumber

         --NJOW06 S
         SELECT @c_Loadkey = Loadkey
         FROM LOADPLANDETAIL(NOLOCK)
         WHERE Orderkey = @c_Orderkey

         SELECT @c_Wavekey = Wavekey
         FROM WAVEDETAIL(NOLOCK)
         WHERE Orderkey = @c_Orderkey
         --NJOW06 E
      END

      --NJOW06 S
      IF ISNULL(@c_OrderLineNumber,'')='' AND ISNULL(@c_key3,'')=''
      BEGIN
      	 SELECT @c_Loadkey = LEFT(@c_OtherParms, 10)  --Load conso

      	 SELECT @c_Wavekey = MAX(WD.Wavekey)
      	 FROM LOADPLANDETAIL LPD (NOLOCK)
      	 JOIN WAVEDETAIL WD (NOLOCK) ON LPD.Orderkey = WD.Orderkey
      	 AND LPD.Loadkey = @c_Loadkey
      	 HAVING COUNT(DISTINCT WD.Wavekey) = 1
      END

      IF ISNULL(@c_OrderLineNumber,'')='' AND ISNULL(@c_key3,'')='W'
      BEGIN
      	 SELECT @c_Wavekey = LEFT(@c_OtherParms, 10) --Wave conso
      END
      --NJOW06 E
   END

   DECLARE  @TMP_CODELKUP TABLE (
       [LISTNAME] [nvarchar](10) NULL,
       [Code] [nvarchar](30) NULL,
       [Description] [nvarchar](250) NULL,
       [Short] [nvarchar](10) NULL,
       [Long] [nvarchar](250) NULL,
       [Notes] [nvarchar](4000) NULL,
       [Notes2] [nvarchar](4000) NULL,
       [Storerkey] [nvarchar](50) NULL,
       [UDF01] [nvarchar](60) NULL,
       [UDF02] [nvarchar](60) NULL,
       [UDF03] [nvarchar](60) NULL,
       [UDF04] [nvarchar](60) NULL,
       [UDF05] [nvarchar](60) NULL,
       [code2] [nvarchar](30) NULL
       )

   CREATE TABLE #TMP_LOT (LOT NVARCHAR(10) NULL,
                          QtyAvailable INT NULL DEFAULT(0))

  --NJOW06 S
   IF ISNULL(@c_Wavekey,'') <> ''
   BEGIN
   	  --Get strategy from wave
   	  SELECT @c_AllocateStrategykey = ALS.AllocateStrategyKey
   	  FROM WAVE W (NOLOCK)
   	  JOIN STRATEGY SY (NOLOCK) ON W.Strategykey = SY.Strategykey
   	  JOIN ALLOCATESTRATEGY ALS (NOLOCK) ON SY.AllocateStrategyKey = ALS.AllocateStrategyKey
   	  AND W.Wavekey = @c_Wavekey
   	  AND W.Strategykey <> ''
   	  AND W.Strategykey IS NOT NULL
   END

   IF ISNULL(@c_AllocateStrategykey,'') = '' AND ISNULL(@c_Loadkey,'') <> ''
   BEGIN
   	  --Get strategy from load defaultstrategykey
   	  SELECT TOP 1 @c_AllocateStrategykey = ALS.AllocateStrategyKey
   	  FROM LOADPLAN LP (NOLOCK)
   	  JOIN LOADPLANDETAIL LPD (NOLOCK) ON LP.Loadkey = LPD.Loadkey
   	  JOIN ORDERS O (NOLOCK) ON LPD.Orderkey = O.Orderkey
   	  JOIN STORER S (NOLOCK) ON O.Storerkey = S.Storerkey
   	  JOIN STRATEGY SY (NOLOCK) ON S.Strategykey = SY.Strategykey
   	  JOIN ALLOCATESTRATEGY ALS (NOLOCK) ON SY.AllocateStrategyKey = ALS.AllocateStrategyKey
   	  AND LP.Loadkey = @c_Loadkey
   	  AND LP.DefaultStrategykey = 'Y'
   	  AND S.Strategykey <> ''
   	  AND S.Strategykey IS NOT NULL
   END

   IF ISNULL(@c_AllocateStrategykey,'') = '' AND ISNULL(@c_StorerDefaultAllocStrategy,'') <> ''
   BEGIN
   	  --Get strategy from storerconfig StorerDefaultAllocStrategy
      SELECT @c_AllocateStrategykey = ALS.AllocateStrategyKey
      FROM STRATEGY SY (NOLOCK)
   	  JOIN ALLOCATESTRATEGY ALS (NOLOCK) ON SY.AllocateStrategyKey = ALS.AllocateStrategyKey
   	  WHERE SY.Strategykey = @c_StorerDefaultAllocStrategy
   END
   --NJOW06 E

   IF ISNULL(@c_AllocateStrategykey,'') = ''  --NJOW06
   BEGIN
   	  --Get strategy from sku
      SELECT @c_AllocateStrategykey = STRATEGY.AllocateStrategykey
      FROM SKU (NOLOCK)
      JOIN STRATEGY (NOLOCK) ON SKU.Strategykey = STRATEGY.Strategykey
      WHERE SKU.Storerkey = @c_Storerkey
      AND SKU.Sku = @c_Sku
   END

   IF EXISTS(SELECT 1 FROM ALLOCATESTRATEGYDETAIL (NOLOCK)
             WHERE LocationTypeOverride IN ('PICK','CASE')
			       AND AllocateStrategyKey = @c_AllocateStrategykey)	--(CLVN01)
      SET @c_OverAllocateFlag = 'Y'

   INSERT INTO @TMP_CODELKUP (Listname, Code, Description, Short, Long, Notes, Notes2, Storerkey, UDF01, UDF02, UDF03, UDF04, UDF05, Code2)
   SELECT CODELKUP.Listname,
          CODELKUP.Code,
          CODELKUP.Description,
          CODELKUP.Short,
          CODELKUP.Long,
          CODELKUP.Notes,
          CODELKUP.Notes2,
          CODELKUP.Storerkey,
          CODELKUP.UDF01,
          CODELKUP.UDF02,
          CODELKUP.UDF03,
          CODELKUP.UDF04,
          CODELKUP.UDF05,
          CODELKUP.Code2
   FROM CODELKUP (NOLOCK)
   LEFT JOIN STORER (NOLOCK) ON CODELKUP.Storerkey = STORER.Storerkey
   WHERE CODELKUP.Listname = 'nspALCFG03'
   AND ISNULL(CODELKUP.Storerkey,'') = CASE WHEN ISNULL(CODELKUP.Short,'') = @c_AllocateStrategykey AND STORER.Storerkey IS NULL THEN ISNULL(CODELKUP.Storerkey,'') ELSE @c_Storerkey END --if setup short and no setup storer ignore storer otherwise by storer.
   AND ISNULL(CODELKUP.Short,'') = CASE WHEN ISNULL(CODELKUP.Short,'') <> '' THEN @c_AllocateStrategykey ELSE ISNULL(CODELKUP.Short,'') END --if short setup must match Allocate strategykey

   SET @c_ListName = ''
   SELECT TOP 1 @c_ListName = TC.UDF01
   FROM @TMP_CODELKUP TC
   JOIN CODELKUP CL (NOLOCK) ON TC.UDF01 = CL.Listname
   WHERE CL.Code ='LISTNAME'

   --Get the configuration from user created listname
   IF ISNULL(@c_ListName,'') <> ''
   BEGIN
      INSERT INTO @TMP_CODELKUP (Listname, Code, Description, Short, Long, Notes, Notes2, Storerkey, UDF01, UDF02, UDF03, UDF04, UDF05, Code2)
      SELECT CODELKUP.Listname,
             CODELKUP.Code,
             CODELKUP.Description,
             CODELKUP.Short,
             CODELKUP.Long,
             CODELKUP.Notes,
             CODELKUP.Notes2,
             CODELKUP.Storerkey,
             CODELKUP.UDF01,
             CODELKUP.UDF02,
             CODELKUP.UDF03,
             CODELKUP.UDF04,
             CODELKUP.UDF05,
             CODELKUP.Code2
      FROM CODELKUP (NOLOCK)
      LEFT JOIN STORER (NOLOCK) ON CODELKUP.Storerkey = STORER.Storerkey
      WHERE CODELKUP.Listname = @c_ListName
      AND ISNULL(CODELKUP.Storerkey,'') = CASE WHEN ISNULL(CODELKUP.Short,'') = @c_AllocateStrategykey AND STORER.Storerkey IS NULL THEN ISNULL(CODELKUP.Storerkey,'') ELSE @c_Storerkey END --if setup short and no setup storer ignore storer otherwise by storer.
      AND ISNULL(CODELKUP.Short,'') = CASE WHEN ISNULL(CODELKUP.Short,'') <> '' THEN @c_AllocateStrategykey ELSE ISNULL(CODELKUP.Short,'') END --if short setup must match Allocate strategykey
   END

   --Retrieve codelkup loc type configurations
   SELECT TOP 1 @c_UDF01 = UDF01,
                @c_UDF02 = UDF01,
                @c_UDF03 = UDF03,
                @c_UDF04 = UDF04,
                @c_UDF05 = UDF05
   FROM @TMP_CODELKUP
   WHERE Code = 'LOCTYPESEQ'  --retrieve by location type defined in udf01-05 by field sequence
   AND (Code2 = @c_UOM OR ISNULL(Code2,'') = '')  --if defined uom in code2 only apply for the specific strategy uom
   ORDER BY CASE WHEN Code2 = @c_UOM THEN 0 ELSE 1 END --consider matched uom first

   SET @n_Cnt = @@ROWCOUNT

   IF @n_Cnt > 0
   BEGIN
      IF ISNULL(@c_UDF01,'') <> '' OR ISNULL(@c_UDF02,'') <> '' OR ISNULL(@c_UDF03,'') <> '' OR ISNULL(@c_UDF04,'') <> '' OR ISNULL(@c_UDF05,'') <> ''
         SET @c_LocTypeFlag = 'Y'
   END

   --Retrieve codelkup condition
   SELECT TOP 1 @c_CLKCondition = Notes
   FROM @TMP_CODELKUP
   WHERE Code = 'CONDITION'  --retrieve addition conditions
   AND (Code2 = @c_UOM OR ISNULL(Code2,'') = '')  --if defined uom in code2 only apply for the specific strategy uom
   ORDER BY CASE WHEN Code2 = @c_UOM THEN 0 ELSE 1 END --consider matched uom first

   SET @n_Cnt = @@ROWCOUNT

   IF @n_Cnt > 0
   BEGIN
      IF ISNULL(@c_CLKCondition,'') <> ''
      BEGIN
         SET @c_CLKConditionFlag = 'Y'
      END
   END

   SELECT TOP 1 @c_AllocateHoldFlag = ISNULL(UDF01,'')
   FROM @TMP_CODELKUP
   WHERE Code = 'ALLOCATEHOLD' --allow allocate hold inventory. default is filter out hold inventory.
   AND (Code2 = @c_UOM OR ISNULL(Code2,'') = '')
   ORDER BY CASE WHEN Code2 = @c_UOM THEN 0 ELSE 1 END

   SELECT TOP 1 @c_FromPickLocFlag = ISNULL(UDF01,'')
   FROM @TMP_CODELKUP
   WHERE Code = 'FROMPICKLOC' --allocation from pick location only. default is all location type.
   AND (Code2 = @c_UOM OR ISNULL(Code2,'') = '')
   ORDER BY CASE WHEN Code2 = @c_UOM THEN 0 ELSE 1 END

   SELECT TOP 1 @c_FromBulkLocFlag = ISNULL(UDF01,'')
   FROM @TMP_CODELKUP
   WHERE Code = 'FROMBULKLOC' --allocation from bulk location only. default is all location type.
   AND (Code2 = @c_UOM OR ISNULL(Code2,'') = '')
   ORDER BY CASE WHEN Code2 = @c_UOM THEN 0 ELSE 1 END

   SELECT TOP 1 @c_FullPalletByLocFlag = ISNULL(UDF01,'')
   FROM @TMP_CODELKUP
   WHERE Code = 'FULLPALLETBYLOC' --Allocate as Full pallet if the loc no remain qty. default is by packkey.
   AND (Code2 = @c_UOM OR ISNULL(Code2,'') = '')
   ORDER BY CASE WHEN Code2 = @c_UOM THEN 0 ELSE 1 END

   SELECT TOP 1 @c_SortFields = ISNULL(Notes,''), @c_SortMode = ISNULL(UDF01,'')  --NJOW05
   FROM @TMP_CODELKUP
   WHERE Code = 'SORTING' --user can define sorting fields. default is FIFO.
   AND (Code2 = @c_UOM OR ISNULL(Code2,'') = '')
   ORDER BY CASE WHEN Code2 = @c_UOM THEN 0 ELSE 1 END

   SELECT TOP 1 @c_AllocateQtyReplenFlag = ISNULL(UDF01,'')
   FROM @TMP_CODELKUP
   WHERE Code = 'ALLOCATEQTYREPLEN' --allow allocate qtyreplen from bulk. default is not allocate from qtyreplen.
   AND (Code2 = @c_UOM OR ISNULL(Code2,'') = '')
   ORDER BY CASE WHEN Code2 = @c_UOM THEN 0 ELSE 1 END

   SELECT TOP 1 @c_ShelfLifeFlag = ISNULL(UDF01,'')
   FROM @TMP_CODELKUP
   WHERE Code = 'SHELFLIFE' --allocation check shelflife. default is no checking.
   AND (Code2 = @c_UOM OR ISNULL(Code2,'') = '')
   ORDER BY CASE WHEN Code2 = @c_UOM THEN 0 ELSE 1 END

   SELECT TOP 1 @c_SkipLottableFilter = ISNULL(UDF01,'')  --NJOW04
   FROM @TMP_CODELKUP
   WHERE Code = 'SKIPLOTTABLEFILTER' --Skip lottable filtering.
   AND (Code2 = @c_UOM OR ISNULL(Code2,'') = '')
   ORDER BY CASE WHEN Code2 = @c_UOM THEN 0 ELSE 1 END

   SELECT TOP 1 @c_FIFOByMultiUOM = ISNULL(UDF01,''),  --NJOW07
                @c_CLKConditionForLot = ISNULL(Notes,'') --NJOW09
   FROM @TMP_CODELKUP
   WHERE Code = 'FIFOBYMULTIUOM' --FIFO by Multi UOM.
   AND (Code2 = @c_UOM OR ISNULL(Code2,'') = '')
   ORDER BY CASE WHEN Code2 = @c_UOM THEN 0 ELSE 1 END

   SELECT TOP 1 @c_ForceLottableFilter = ISNULL(UDF01,'')  --NJOW08
   FROM @TMP_CODELKUP
   WHERE Code = 'FORCELOTTABLEFILTER' --Force lottable filtering.
   AND (Code2 = @c_UOM OR ISNULL(Code2,'') = '')
   ORDER BY CASE WHEN Code2 = @c_UOM THEN 0 ELSE 1 END

   SELECT TOP 1 @c_AllocateByUCCFlag = ISNULL(UDF01,'')  --NJOW09
   FROM @TMP_CODELKUP
   WHERE Code = 'ALLOCATEBYUCC' --Allocate by UCC.
   AND (Code2 = @c_UOM OR ISNULL(Code2,'') = '')
   ORDER BY CASE WHEN Code2 = @c_UOM THEN 0 ELSE 1 END

   SELECT TOP 1 @c_SkipDiscreteFlag = ISNULL(UDF01,'')  --NJOW09
   FROM @TMP_CODELKUP
   WHERE Code = 'SKIPDISCRETE' --Skip Discrete
   AND (Code2 = @c_UOM OR ISNULL(Code2,'') = '')
   ORDER BY CASE WHEN Code2 = @c_UOM THEN 0 ELSE 1 END

   SELECT TOP 1 @c_SkipLoadConsoFlag = ISNULL(UDF01,'')  --NJOW09
   FROM @TMP_CODELKUP
   WHERE Code = 'SKIPLOADCONSO' --Skip Load Consolidate
   AND (Code2 = @c_UOM OR ISNULL(Code2,'') = '')
   ORDER BY CASE WHEN Code2 = @c_UOM THEN 0 ELSE 1 END

   SELECT TOP 1 @c_SkipWaveConsoFlag = ISNULL(UDF01,'')  --NJOW09
   FROM @TMP_CODELKUP
   WHERE Code = 'SKIPWAVECONSO' --Skip Wave Consolidate
   AND (Code2 = @c_UOM OR ISNULL(Code2,'') = '')
   ORDER BY CASE WHEN Code2 = @c_UOM THEN 0 ELSE 1 END

   --NJOW09 S
   IF ISNULL(@c_OrderLineNumber,'') <> '' AND @c_SkipDiscreteFlag = 'Y'
   BEGIN
      DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT TOP 0 NULL, NULL, NULL, NULL, NULL

      GOTO EXIT_SP
   END
   ELSE IF ISNULL(@c_OrderLineNumber,'')='' AND ISNULL(@c_key3,'')='' AND @c_SkipLoadConsoFlag = 'Y'
   BEGIN
      DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT TOP 0 NULL, NULL, NULL, NULL, NULL

      GOTO EXIT_SP
   END
   ELSE IF ISNULL(@c_OrderLineNumber,'')='' AND ISNULL(@c_key3,'')='W' AND @c_SkipWaveConsoFlag = 'Y'
   BEGIN
      DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT TOP 0 NULL, NULL, NULL, NULL, NULL

      GOTO EXIT_SP
   END
   --NJOW09 E

   IF ISNULL(@c_ShelfLifeFlag,'') IN('E','M')  --NJOW02
      SET @c_ContinueChkShelfLife = 'Y'

   IF ISNULL(@c_SortFields,'') <> ''
   BEGIN
      SET @c_SortingFlag = 'Y'
   END

   IF (ISNULL(@c_Lottable01,'') <> '' AND CHARINDEX('01',@c_SkipLottableFilter,1) = 0)  --NJOW04
      OR CHARINDEX('01',@c_ForceLottableFilter,1) > 0  --NJOW08
   BEGIN
      SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'') + " AND LOTTABLE01 = RTRIM(@c_Lottable01) "         --(Wan01)
   END

   IF (ISNULL(@c_Lottable02,'') <> '' AND CHARINDEX('02',@c_SkipLottableFilter,1) = 0)  --NJOW04
      OR CHARINDEX('02',@c_ForceLottableFilter,1) > 0  --NJOW08
   BEGIN
      SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'') + " AND LOTTABLE02 = RTRIM(@c_Lottable02) "         --(Wan01)
   END

   IF (ISNULL(@c_Lottable03,'') <> '' AND CHARINDEX('03',@c_SkipLottableFilter,1) = 0)  --NJOW04
      OR CHARINDEX('03',@c_ForceLottableFilter,1) > 0  --NJOW08
   BEGIN
      SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'') + " AND LOTTABLE03 = RTRIM(@c_Lottable03) "         --(Wan01)
   END

   IF CONVERT(char(10), @d_Lottable04, 103) <> "01/01/1900" AND @d_Lottable04 IS NOT NULL AND CHARINDEX('04',@c_SkipLottableFilter,1) = 0  --NJOW04
   BEGIN
      SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'') + " AND LOTTABLE04 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable04, 106)) " --(Wan01)
   END
   ELSE IF CHARINDEX('04',@c_ForceLottableFilter,1) > 0 --NJOW08
   BEGIN
      SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'') + " AND LOTTABLE04 IS NULL OR CONVERT(CHAR(10), LOTTABLE04, 103) = '01/01/1900 "
   END

   IF CONVERT(char(10), @d_Lottable05, 103) <> "01/01/1900" AND @d_Lottable05 IS NOT NULL AND CHARINDEX('05',@c_SkipLottableFilter,1) = 0  --NJOW04
   BEGIN
      SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'') + " AND LOTTABLE05 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable05, 106)) " --(Wan01)
   END
   ELSE IF CHARINDEX('05',@c_ForceLottableFilter,1) > 0 --NJOW08
   BEGIN
      SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'') + " AND LOTTABLE05 IS NULL OR CONVERT(CHAR(10), LOTTABLE05, 103) = '01/01/1900 "
   END

   IF (ISNULL(@c_Lottable06,'') <> '' AND CHARINDEX('06',@c_SkipLottableFilter,1) = 0)  --NJOW04
      OR CHARINDEX('06',@c_ForceLottableFilter,1) > 0  --NJOW08
   BEGIN
      SET @c_Condition = ISNULL(RTRIM(@c_Condition),'')+ ' AND Lottable06 = RTRIM(@c_Lottable06) '             --(Wan01)
   END

   IF (ISNULL(@c_Lottable07,'') <> '' AND CHARINDEX('07',@c_SkipLottableFilter,1) = 0)  --NJOW04
      OR CHARINDEX('07',@c_ForceLottableFilter,1) > 0  --NJOW08
   BEGIN
      SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') + ' AND Lottable07 = RTRIM(@c_Lottable07) '            --(Wan01)
   END

   IF (ISNULL(@c_Lottable08,'') <> '' AND CHARINDEX('08',@c_SkipLottableFilter,1) = 0)  --NJOW04
      OR CHARINDEX('08',@c_ForceLottableFilter,1) > 0  --NJOW08
   BEGIN
      SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') + ' AND Lottable08 = RTRIM(@c_Lottable08) '            --(Wan01)
   END

   IF (ISNULL(@c_Lottable09,'') <> '' AND CHARINDEX('09',@c_SkipLottableFilter,1) = 0)  --NJOW04
      OR CHARINDEX('09',@c_ForceLottableFilter,1) > 0  --NJOW08
   BEGIN
      SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') + ' AND Lottable09 = RTRIM(@c_Lottable09) '            --(Wan01)
   END

   IF (ISNULL(@c_Lottable10,'') <> '' AND CHARINDEX('10',@c_SkipLottableFilter,1) = 0)  --NJOW04
      OR CHARINDEX('10',@c_ForceLottableFilter,1) > 0  --NJOW08
   BEGIN
      SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') + ' AND Lottable10 = RTRIM(@c_Lottable10) '            --(Wan01)
   END

   IF (ISNULL(@c_Lottable11,'') <> '' AND CHARINDEX('11',@c_SkipLottableFilter,1) = 0)  --NJOW04
      OR CHARINDEX('11',@c_ForceLottableFilter,1) > 0  --NJOW08
   BEGIN
      SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') + ' AND Lottable11 = RTRIM(@c_Lottable11) '            --(Wan01)
   END

   IF (ISNULL(@c_Lottable12,'') <> '' AND CHARINDEX('12',@c_SkipLottableFilter,1) = 0)  --NJOW04
      OR CHARINDEX('12',@c_ForceLottableFilter,1) > 0  --NJOW08
   BEGIN
      SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') + ' AND Lottable12 = RTRIM(@c_Lottable12) '            --(Wan01)
   END

   IF CONVERT(char(10), @d_Lottable13, 103) <> '01/01/1900' AND @d_Lottable13 IS NOT NULL AND CHARINDEX('13',@c_SkipLottableFilter,1) = 0  --NJOW04
   BEGIN
      SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') + ' AND Lottable13 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable13, 106)) ' --(Wan01)
   END
   ELSE IF CHARINDEX('13',@c_ForceLottableFilter,1) > 0 --NJOW08
   BEGIN
      SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'') + " AND LOTTABLE13 IS NULL OR CONVERT(CHAR(10), LOTTABLE13, 103) = '01/01/1900 "
   END

   IF CONVERT(char(10), @d_Lottable14, 103) <> '01/01/1900' AND @d_Lottable14 IS NOT NULL AND CHARINDEX('14',@c_SkipLottableFilter,1) = 0  --NJOW04
   BEGIN
      SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') + ' AND Lottable14 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable14, 106)) ' --(Wan01)
   END
   ELSE IF CHARINDEX('14',@c_ForceLottableFilter,1) > 0 --NJOW08
   BEGIN
      SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'') + " AND LOTTABLE14 IS NULL OR CONVERT(CHAR(10), LOTTABLE14, 103) = '01/01/1900 "
   END

   IF CONVERT(char(10), @d_Lottable15, 103) <> '01/01/1900' AND @d_Lottable15 IS NOT NULL AND CHARINDEX('15',@c_SkipLottableFilter,1) = 0  --NJOW04
   BEGIN
      SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') + ' AND Lottable15 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable15, 106)) ' --(Wan01)
   END
   ELSE IF CHARINDEX('15',@c_ForceLottableFilter,1) > 0 --NJOW08
   BEGIN
      SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'') + " AND LOTTABLE15 IS NULL OR CONVERT(CHAR(10), LOTTABLE15, 103) = '01/01/1900 "
   END

   ------Order shelflife (orderdetail.Minshelflife)
   IF ISNULL(@n_OrderMinShelfLife,0) > 0 AND ISNULL(@c_OrderKey,'') <> '' AND @c_ContinueChkShelfLife = 'Y'
   BEGIN
        IF @c_ShelfLifeFlag = 'E'
        BEGIN
         SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'') + " AND ( DATEDIFF(day, GETDATE(), LOTTABLE04) >= @n_OrderMinShelfLife "    --(Wan01)
                             + "OR Lottable04 IS NULL OR CONVERT(CHAR(10), LOTTABLE04, 103) = '01/01/1900') "                             --(Wan01)
      END
      ELSE IF @c_ShelfLifeFlag = 'M'
        BEGIN
         SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'') + " AND ( DATEDIFF(day, LOTTABLE04, GETDATE()) <= @n_OrderMinShelfLife "    --(Wan01)
                             + "OR Lottable04 IS NULL OR CONVERT(CHAR(10), LOTTABLE04, 103) = '01/01/1900') "                             --(Wan01)
      END

      SET @c_ContinueChkShelfLife = 'N'
   END

   IF ISNULL(@c_OrderKey,'') <> '' AND @c_ContinueChkShelfLife = 'Y'
   BEGIN
      ------Consignee shelflife (Storer.MinShelfLife)
      /*
      SELECT @n_ConsigneeMinShelfLife = ISNULL(STORER.MinShelfLife,0)
      FROM ORDERS (NOLOCK)
      JOIN STORER (NOLOCK) ON (ORDERS.ConsigneeKey = STORER.StorerKey)
      WHERE ORDERS.OrderKey = @c_OrderKey

      IF ISNULL(@n_ConsigneeMinShelfLife,0) > 0
      BEGIN
         SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'') + " AND ( DATEDIFF(day, GETDATE(), LOTTABLE04) >= "
         + CAST(@n_ConsigneeMinShelfLife AS NVARCHAR(10)) + " OR Lottable04 IS NULL OR CONVERT(char(10), Lottable04, 103) = '01/01/1900') "
      END
      */
      ------Consignee+Sku shelflife (Storer.MinShelflife * Sku.Shelflife)
      SELECT @n_ConsigneeSkuMinShelfLife = (Sku.Shelflife * Storer.MinShelflife/100)
      FROM ORDERS O (NOLOCK)
      JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
      JOIN SKU (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku
      JOIN STORER (NOLOCK) ON O.Consigneekey = STORER.Storerkey
      WHERE O.Orderkey = @c_Orderkey
      AND OD.OrderLineNumber = @c_OrderLineNumber

      IF ISNULL(@n_ConsigneeSkuMinShelfLife,0) > 0
      BEGIN
          IF @c_ShelfLifeFlag = 'E'
         BEGIN
            SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'') + " AND ( DATEDIFF(day, GETDATE(), LOTTABLE04) >= @n_ConsigneeSkuMinShelfLife "   --(Wan01)
                                + "OR Lottable04 IS NULL OR CONVERT(CHAR(10), LOTTABLE04, 103) = '01/01/1900') "
         END
         ELSE IF @c_ShelfLifeFlag = 'M'
         BEGIN
            SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'') + " AND ( DATEDIFF(day, LOTTABLE04, GETDATE()) <= @n_ConsigneeSkuMinShelfLife "   --(Wan01)
                                + "OR Lottable04 IS NULL OR CONVERT(CHAR(10), LOTTABLE04, 103) = '01/01/1900') "
         END

         SET @c_ContinueChkShelfLife = 'N'
      END

      ------Consigneegroup + skugroup shelflife (Doclkup.consigneegroup + Doclkup.skugroup)
      IF @c_ContinueChkShelfLife = 'Y'
      BEGIN
         SELECT @n_ConsigneeSkuGroupMinShelfLife = DOCLKUP.Shelflife
         FROM ORDERS O (NOLOCK)
         JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
         JOIN SKU (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku
         JOIN STORER (NOLOCK) ON O.Consigneekey = STORER.Storerkey
         JOIN DOCLKUP (NOLOCK) ON STORER.Secondary = DOCLKUP.ConsigneeGroup AND SKU.Skugroup = DOCLKUP.Skugroup
         WHERE O.Orderkey = @c_Orderkey
         AND OD.OrderLineNumber = @c_OrderLineNumber

         IF ISNULL(@n_ConsigneeSkuGroupMinShelfLife,0) > 0
         BEGIN
              IF @c_ShelfLifeFlag = 'E'
            BEGIN
               SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'') + " AND ( DATEDIFF(day, GETDATE(), LOTTABLE04) >= @n_ConsigneeSkuGroupMinShelfLife "    --(Wan01)
                                   + "OR Lottable04 IS NULL OR CONVERT(CHAR(10), LOTTABLE04, 103) = '01/01/1900') "                                         --(Wan01)
            END
            ELSE IF @c_ShelfLifeFlag = 'M'
            BEGIN
               SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'') + " AND ( DATEDIFF(day, LOTTABLE04, GETDATE()) <= @n_ConsigneeSkuGroupMinShelfLife "    --(Wan01)
                                   + "OR Lottable04 IS NULL OR CONVERT(CHAR(10), LOTTABLE04, 103) = '01/01/1900') "                                         --(Wan01)
            END

            SET @c_ContinueChkShelfLife = 'N'
         END
      END
   END

   ------Sku outgoing shelflife (Sku.SUSR2)
   IF @c_ContinueChkShelfLife = 'Y'
   BEGIN
      SELECT @n_SkuOutGoingMinShelfLife = CASE WHEN ISNUMERIC(SUSR2) = 1 THEN CAST(SUSR2 AS INT)
                                          ELSE 0 END
      FROM  SKU (NOLOCK)
      WHERE SKU = @c_SKU
      AND   STORERKEY = @c_StorerKey

      IF ISNULL(@n_SkuOutGoingMinShelfLife,0) > 0
      BEGIN
        IF @c_ShelfLifeFlag = 'E'
          BEGIN
             SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'') + " AND ( DATEDIFF(day, GETDATE(), LOTTABLE04) >= @n_SkuOutGoingMinShelfLife "   --(Wan01)
                                 + "OR Lottable04 IS NULL OR CONVERT(char(10), Lottable04, 103) = '01/01/1900') "                                  --(Wan01)
         END
         ELSE IF @c_ShelfLifeFlag = 'M'
          BEGIN
             SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'') + " AND ( DATEDIFF(day, LOTTABLE04, GETDATE()) <= @n_SkuOutGoingMinShelfLife "   --(Wan01)
                                 + " OR Lottable04 IS NULL OR CONVERT(char(10), Lottable04, 103) = '01/01/1900') "                                 --(Wan01)
         END

         SET @c_ContinueChkShelfLife = 'N'
      END
   END

   ------Storer+Sku shelflife (Storer.MinShelflife * Sku.Shelflife)
   IF @c_ContinueChkShelfLife = 'Y'
   BEGIN
      SELECT @n_StorerSkuMinShelfLife = (Sku.Shelflife * Storer.MinShelflife/100)
      FROM Sku (nolock)
      JOIN Storer (nolock) ON Sku.Storerkey = Storer.Storerkey
      WHERE Sku.Sku = @c_sku
      AND Sku.Storerkey = @c_storerkey

      IF ISNULL(@n_StorerSkuMinShelfLife,0) > 0
      BEGIN
        IF @c_ShelfLifeFlag = 'E'
        BEGIN
            SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'') + " AND ( DATEDIFF(day, GETDATE(), LOTTABLE04) >= @n_StorerSkuMinShelfLife "   --(Wan01)
                                + "OR Lottable04 IS NULL OR CONVERT(CHAR(10), LOTTABLE04, 103) = '01/01/1900') "
         END
         ELSE IF @c_ShelfLifeFlag = 'M'
         BEGIN
            SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'') + " AND ( DATEDIFF(day, LOTTABLE04, GETDATE()) <= @n_StorerSkuMinShelfLife "   --(Wan01)
                                + "OR Lottable04 IS NULL OR CONVERT(CHAR(10), LOTTABLE04, 103) = '01/01/1900') "
         END

         SET @c_ContinueChkShelfLife = 'N'
      END
   END

   IF ISNULL(@c_ID,'') <> ''
   BEGIN
       SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'') + " AND LOTxLOCxID.Id = RTRIM(@c_ID) " --(Wan01)
   END

   IF ISNULL(@c_AllocateHoldFlag,'') <> 'Y'
   BEGIN
      SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'') + " AND LOT.STATUS = 'OK'  " +
                           " AND LOC.STATUS = 'OK' AND ID.STATUS = 'OK' " +
                           " AND LOC.LocationFlag = 'NONE' "
   END

   --NJOW09 S
   IF @c_FIFOByMultiUOM = 'Y'
      SET @c_ConditionForLot = @c_Condition

   IF ISNULL(@c_CLKConditionForLot,'') <> ''
   BEGIN
       IF LEFT(LTRIM(@c_CLKConditionForLot),3) <> 'AND'
          SET @c_CLKConditionForLot = ' AND ' + RTRIM(LTRIM(@c_CLKConditionForLot))
   END
   --NJOW09 E

   IF @c_LocTypeFlag = 'Y'
   BEGIN
       IF ISNULL(@c_UDF01,'') <> ''
          SELECT @c_LocTypeList =  @c_LocTypeList + " RTRIM(@c_UDF01),"                            --(Wan01)

       IF ISNULL(@c_UDF02,'') <> ''
          SELECT @c_LocTypeList =  @c_LocTypeList + " RTRIM(@c_UDF02),"                            --(Wan01)

       IF ISNULL(@c_UDF03,'') <> ''
          SELECT @c_LocTypeList =  @c_LocTypeList + " RTRIM(@c_UDF03),"                            --(Wan01)

       IF ISNULL(@c_UDF04,'') <> ''
          SELECT @c_LocTypeList =  @c_LocTypeList + " RTRIM(@c_UDF04),"                            --(Wan01)

       IF ISNULL(@c_UDF05,'') <> ''
          SELECT @c_LocTypeList =  @c_LocTypeList + " RTRIM(@c_UDF05),"                            --(Wan01)

       SET @c_LocTypeList = LEFT(@c_LocTypeList, LEN(@c_LocTypeList) - 1)

      SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'') + " AND LOC.LocationType IN (" + RTRIM(@c_LocTypeList) + ") "

      SELECT @c_LocTypeSort = " CASE WHEN LOC.LocationType = RTRIM(ISNULL(@c_UDF01,'''')) THEN 1 " +
                                   " WHEN LOC.LocationType = RTRIM(ISNULL(@c_UDF02,'''')) THEN 2 " +
                                   " WHEN LOC.LocationType = RTRIM(ISNULL(@c_UDF03,'''')) THEN 3 " +
                                   " WHEN LOC.LocationType = RTRIM(ISNULL(@c_UDF04,'''')) THEN 4 " +
                                   " WHEN LOC.LocationType = RTRIM(ISNULL(@c_UDF05,'''')) THEN 5 ELSE 6 END, "
   END

   IF @c_CLKConditionFlag = 'Y'
   BEGIN
       IF LEFT(LTRIM(@c_CLKCondition),3) <> 'AND'
          SET @c_CLKCondition = ' AND ' + RTRIM(LTRIM(@c_CLKCondition))
   END

   IF @c_FromPickLocFlag = 'Y'
   BEGIN
      SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'') + " AND SKUXLOC.LocationType IN('PICK','CASE') "
   END
   ELSE IF @c_FromBulkLocFlag = 'Y'
   BEGIN
      SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'') + " AND SKUXLOC.LocationType NOT IN('PICK','CASE') "
   END

   IF @c_SortingFlag = 'Y'
   BEGIN
   	  IF @c_SortMode = 'DYNAMICSQL'  --NJOW05
   	  BEGIN
   	  	 SELECT @c_SQLStatement = @c_SortFields
   	  	 SET @c_SortFields = ''

         SET @c_SQLParms = N'@c_Facility NVARCHAR(5), @c_StorerKey NVARCHAR(15), @c_SKU  NVARCHAR(20), @c_UOM NVARCHAR(10), @c_HostWHCode NVARCHAR(10)'
             +', @n_UOMBase INT, @n_QtyLeftToFulfill INT, @c_Orderkey NVARCHAR(10), @c_OrderLineNumber NVARCHAR(5), @c_Loadkey NVARCHAR(10), @c_Wavekey NVARCHAR(10)'
             +',@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), @d_Lottable04 DATETIME, @d_Lottable05 DATETIME'
             +',@c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), @c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30)'
             +',@c_Lottable11 NVARCHAR(30), @c_Lottable12 NVARCHAR(30), @d_Lottable13 DATETIME, @d_Lottable14 DATETIME, @d_Lottable15 DATETIME'
             +',@n_OrderMinShelfLife INT, @n_ConsigneeSkuMinShelfLife INT,@n_ConsigneeSkuGroupMinShelfLife INT'
             +',@n_SkuOutGoingMinShelfLife INT, @n_StorerSkuMinShelfLife INT'
             +',@c_ID NVARCHAR(18)'
             +',@c_UDF01 NVARCHAR(30), @c_UDF02 NVARCHAR(30), @c_UDF03 NVARCHAR(30), @c_UDF04 NVARCHAR(30), @c_UDF05 NVARCHAR(30)'
             +',@c_SortFields NVARCHAR(2000) OUTPUT'

         EXEC sp_executesql @c_SQLStatement, @c_SQLParms,
            @c_Facility   ,
            @c_StorerKey  ,
            @c_SKU        ,
            @c_UOM        ,
            @c_HostWHCode ,
            @n_UOMBase    ,
            @n_QtyLeftToFulfill,
            @c_Orderkey,
            @c_OrderLineNumber,
            @c_Loadkey,  --NJOW06
            @c_Wavekey   --NJOW06
           ,@c_Lottable01
           ,@c_Lottable02
           ,@c_Lottable03
           ,@d_Lottable04
           ,@d_Lottable05
           ,@c_Lottable06
           ,@c_Lottable07
           ,@c_Lottable08
           ,@c_Lottable09
           ,@c_Lottable10
           ,@c_Lottable11
           ,@c_Lottable12
           ,@d_Lottable13
           ,@d_Lottable14
           ,@d_Lottable15
           ,@n_OrderMinShelfLife
           ,@n_ConsigneeSkuMinShelfLife
           ,@n_ConsigneeSkuGroupMinShelfLife
           ,@n_SkuOutGoingMinShelfLife
           ,@n_StorerSkuMinShelfLife
           ,@c_ID
           ,@c_UDF01
           ,@c_UDF02
           ,@c_UDF03
           ,@c_UDF04
           ,@c_UDF05
           ,@c_SortFields OUTPUT

         IF @c_SortFields =  'FIFO'
            SET @c_SortBy = " ORDER BY " + RTRIM(@c_LocTypeSort) + " Lotattribute.Lottable05, Lotattribute.Lot, Loc.LogicalLocation, Loc.Loc "
         ELSE IF @c_SortFields =  'FEFO'
            SET @c_SortBy = " ORDER BY " + RTRIM(@c_LocTypeSort) + " Lotattribute.Lottable04, Lotattribute.Lot, Loc.LogicalLocation, Loc.Loc "
         ELSE IF ISNULL(@c_SortFields,'') = ''
            SET @c_SortBy = " ORDER BY " + RTRIM(@c_LocTypeSort) + " Lotattribute.Lottable05, Lotattribute.Lot, Loc.LogicalLocation, Loc.Loc "
         ELSE
            SET @c_SortBy = " ORDER BY " + RTRIM(@c_LocTypeSort) + RTRIM(@c_SortFields) + " "
   	  END
   	  ELSE
   	  BEGIN
         IF @c_SortFields =  'FIFO'
            SET @c_SortBy = " ORDER BY " + RTRIM(@c_LocTypeSort) + " Lotattribute.Lottable05, Lotattribute.Lot, Loc.LogicalLocation, Loc.Loc "
         ELSE IF @c_SortFields =  'FEFO'
            SET @c_SortBy = " ORDER BY " + RTRIM(@c_LocTypeSort) + " Lotattribute.Lottable04, Lotattribute.Lot, Loc.LogicalLocation, Loc.Loc "
          ELSE
            SET @c_SortBy = " ORDER BY " + RTRIM(@c_LocTypeSort) + RTRIM(@c_SortFields) + " "
      END
   END
   ELSE
      SET @c_SortBy = " ORDER BY " + RTRIM(@c_LocTypeSort) + " Lotattribute.Lottable05, Lotattribute.Lot, Loc.LogicalLocation, Loc.Loc "

   IF (@c_FullPalletByLocFlag = 'Y' AND @c_UOM = '1') OR (@c_OverAllocateFlag = 'Y')
      OR (@c_FIFOByMultiUOM = 'Y')  --NJOW07
   BEGIN
      SET @c_SQL = ''

      IF @c_FIFOByMultiUOM = 'Y'  --NJOW09
      BEGIN
         SELECT @c_SQLStatement = " INSERT INTO #TMP_LOT (Lot, QtyAvailable) " +
                                  " SELECT LOTxLOCxID.LOT, " +
                                  CASE WHEN @c_AllocateByUCCFlag = 'Y' THEN  --NJOW10
                                     " SUM(CASE WHEN UCC.UCCNo IS NOT NULL AND UCC.Status < '3' THEN UCC.Qty
                                                WHEN UCC.UCCNo IS NOT NULL AND UCC.Status >= '3' THEN 0
                                           ELSE LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED END)"
                                  WHEN @c_AllocateQtyReplenFlag = 'Y' THEN
                                     " SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) "
                                  ELSE
                                     " SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QTYREPLEN) " END +
                                  " FROM LOTxLOCxID (NOLOCK) " +
                                  " JOIN LOTATTRIBUTE (NOLOCK) ON (LOTxLOCxID.Lot = LOTATTRIBUTE.Lot) " +
                                  " JOIN LOT (NOLOCK) ON (LOTxLOCxID.Lot = LOT.Lot) " +
                                  " JOIN LOC (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC) " +
                                  " JOIN ID (NOLOCK) ON (LOTxLOCxID.Id = ID.ID) " +
                                  " JOIN SKUXLOC (NOLOCK) ON (LOTxLOCxID.Storerkey =  SKUXLOC.Storerkey AND LOTxLOCxID.Sku = SKUXLOC.Sku AND LOTxLOCxID.Loc =  SKUXLOC.Loc) " +
                                  " JOIN SKU (NOLOCK) ON (LOTxLOCxID.Storerkey =  SKU.Storerkey AND SKU.Sku =  SKUXLOC.Sku) " +
                                  " JOIN STORER (NOLOCK) ON (LOTxLOCxID.Storerkey =  STORER.Storerkey) " +
                                  " JOIN PACK (NOLOCK) ON (SKU.Packkey = PACK.Packkey) " +
                                  CASE WHEN @c_AllocateByUCCFlag = 'Y' THEN  --NJOW10
                                  " LEFT JOIN UCC (NOLOCK) ON (UCC.StorerKey = LOTxLOCxID.StorerKey AND UCC.SKU = LOTxLOCxID.SKU AND
                                                               UCC.LOT = LOTxLOCxID.LOT AND UCC.LOC = LOC.LOC AND UCC.ID = ID.ID) "
                                  ELSE " " END +
                                  " WHERE LOTxLOCxID.Storerkey = @c_Storerkey " +
                                  " AND LOTxLOCxID.Sku = @c_Sku " +
                                  " AND LOC.Facility = @c_Facility " +
                                  CASE WHEN @c_AllocateQtyReplenFlag = 'Y' THEN
                                       " AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) >= 1 "
                                  ELSE
                                       " AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QTYREPLEN) >= 1 "
                                  END  +
                                  ISNULL(RTRIM(@c_ConditionForLot),'') + " " + ISNULL(RTRIM(@c_CLKConditionForLot),'') +
                                  " GROUP BY LOTxLOCxID.LOT"

         SET @c_SQLParms = N'@c_Facility NVARCHAR(5), @c_StorerKey NVARCHAR(15), @c_SKU  NVARCHAR(20), @c_UOM NVARCHAR(10), @c_HostWHCode NVARCHAR(10)'
             +', @n_UOMBase INT, @n_QtyLeftToFulfill INT, @c_Orderkey NVARCHAR(10), @c_OrderLineNumber NVARCHAR(5), @c_Loadkey NVARCHAR(10), @c_Wavekey NVARCHAR(10)'
             +',@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), @d_Lottable04 DATETIME, @d_Lottable05 DATETIME'
             +',@c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), @c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30)'
             +',@c_Lottable11 NVARCHAR(30), @c_Lottable12 NVARCHAR(30), @d_Lottable13 DATETIME, @d_Lottable14 DATETIME, @d_Lottable15 DATETIME'
             +',@n_OrderMinShelfLife INT, @n_ConsigneeSkuMinShelfLife INT,@n_ConsigneeSkuGroupMinShelfLife INT'
             +',@n_SkuOutGoingMinShelfLife INT, @n_StorerSkuMinShelfLife INT'
             +',@c_ID NVARCHAR(18)'
             +',@c_UDF01 NVARCHAR(30), @c_UDF02 NVARCHAR(30), @c_UDF03 NVARCHAR(30), @c_UDF04 NVARCHAR(30), @c_UDF05 NVARCHAR(30)'

         EXEC sp_executesql @c_SQLStatement, @c_SQLParms,
            @c_Facility   ,
            @c_StorerKey  ,
            @c_SKU        ,
            @c_UOM        ,
            @c_HostWHCode ,
            @n_UOMBase    ,
            @n_QtyLeftToFulfill,
            @c_Orderkey,
            @c_OrderLineNumber,
            @c_Loadkey,
            @c_Wavekey
           ,@c_Lottable01
           ,@c_Lottable02
           ,@c_Lottable03
           ,@d_Lottable04
           ,@d_Lottable05
           ,@c_Lottable06
           ,@c_Lottable07
           ,@c_Lottable08
           ,@c_Lottable09
           ,@c_Lottable10
           ,@c_Lottable11
           ,@c_Lottable12
           ,@d_Lottable13
           ,@d_Lottable14
           ,@d_Lottable15
           ,@n_OrderMinShelfLife
           ,@n_ConsigneeSkuMinShelfLife
           ,@n_ConsigneeSkuGroupMinShelfLife
           ,@n_SkuOutGoingMinShelfLife
           ,@n_StorerSkuMinShelfLife
           ,@c_ID
           ,@c_UDF01
           ,@c_UDF02
           ,@c_UDF03
           ,@c_UDF04
           ,@c_UDF05

           DELETE FROM #TMP_LOT WHERE QtyAvailable = 0 --NJOW10
      END

      SELECT @c_SQLStatement = " DECLARE CURSOR_AVAILABLECFG CURSOR FAST_FORWARD READ_ONLY FOR " +
                              " SELECT LOTxLOCxID.LOT, LOTxLOCxID.LOC,LOTxLOCxID.ID, " +
                              CASE WHEN @c_AllocateByUCCFlag = 'Y' THEN  --NJOW09
                                 " QTYAVAILABLE = UCC.Qty, "
                              WHEN @c_AllocateQtyReplenFlag = 'Y' THEN
                                 " QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), "
                              ELSE
                                 " QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QTYREPLEN), " END +
                              CASE WHEN @c_AllocateByUCCFlag = 'Y' THEN  --NJOW09
                                 " UCC.UCCNo " ELSE " '1' "  END +
                              " FROM LOTxLOCxID (NOLOCK) " +
                              " JOIN LOTATTRIBUTE (NOLOCK) ON (LOTxLOCxID.Lot = LOTATTRIBUTE.Lot) " +
                              " JOIN LOT (NOLOCK) ON (LOTxLOCxID.Lot = LOT.Lot) " +
                              " JOIN LOC (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC) " +
                              " JOIN ID (NOLOCK) ON (LOTxLOCxID.Id = ID.ID) " +
                              " JOIN SKUXLOC (NOLOCK) ON (LOTxLOCxID.Storerkey =  SKUXLOC.Storerkey AND LOTxLOCxID.Sku = SKUXLOC.Sku AND LOTxLOCxID.Loc =  SKUXLOC.Loc) " +
                              " JOIN SKU (NOLOCK) ON (LOTxLOCxID.Storerkey =  SKU.Storerkey AND SKU.Sku =  SKUXLOC.Sku) " +
                              " JOIN STORER (NOLOCK) ON (LOTxLOCxID.Storerkey =  STORER.Storerkey) " +
                              " JOIN PACK (NOLOCK) ON (SKU.Packkey = PACK.Packkey) " +
                              CASE WHEN @c_AllocateByUCCFlag = 'Y' THEN  --NJOW09
                              " JOIN UCC (NOLOCK) ON (UCC.StorerKey = LOTxLOCxID.StorerKey AND UCC.SKU = LOTxLOCxID.SKU AND
                                                     UCC.LOT = LOTxLOCxID.LOT AND UCC.LOC = LOC.LOC AND UCC.ID = ID.ID AND UCC.Status < '3') "
                              ELSE " " END +
                              " WHERE LOTxLOCxID.Storerkey = @c_Storerkey " +
                              " AND LOTxLOCxID.Sku = @c_Sku " +
                              " AND LOC.Facility = @c_Facility " +
                              CASE WHEN @c_AllocateQtyReplenFlag = 'Y' THEN
                                 CASE WHEN @c_FIFOByMultiUOM = 'Y' OR (@c_FullPalletByLocFlag = 'Y' AND @c_UOM = '1') THEN --NJOW07 --NJOW11
                                    " AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) >= 1 "
                                 ELSE
                                    " AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) >= @n_uombase "
                                 END
                              ELSE
                                 CASE WHEN @c_FIFOByMultiUOM = 'Y' OR (@c_FullPalletByLocFlag = 'Y' AND @c_UOM = '1') THEN --NJOW07 --NJOW11
                                    " AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QTYREPLEN) >= 1 "
                                 ELSE
                                    " AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QTYREPLEN) >= @n_uombase "
                                 END
                              END  +
                              CASE WHEN @c_UOM = '1' AND @c_FullPalletByLocFlag = 'Y' THEN
                                  ' AND (LOTxLOCxID.QTYALLOCATED + LOTxLOCxID.QtyReplen) = 0
                                    AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) <= @n_QtyLeftToFulfill '
                                   ELSE ' ' END +  --NJOW11
                              ISNULL(RTRIM(@c_Condition),'') + " " + ISNULL(RTRIM(@c_CLKCondition),'') + " " + @c_SortBy

      --(Wan01) - START
      SET @c_SQLParms = N'@c_Facility NVARCHAR(5), @c_StorerKey NVARCHAR(15), @c_SKU  NVARCHAR(20), @c_UOM NVARCHAR(10), @c_HostWHCode NVARCHAR(10)'
          +', @n_UOMBase INT, @n_QtyLeftToFulfill INT, @c_Orderkey NVARCHAR(10), @c_OrderLineNumber NVARCHAR(5), @c_Loadkey NVARCHAR(10), @c_Wavekey NVARCHAR(10)'
          +',@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), @d_Lottable04 DATETIME, @d_Lottable05 DATETIME'
          +',@c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), @c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30)'
          +',@c_Lottable11 NVARCHAR(30), @c_Lottable12 NVARCHAR(30), @d_Lottable13 DATETIME, @d_Lottable14 DATETIME, @d_Lottable15 DATETIME'
          +',@n_OrderMinShelfLife INT, @n_ConsigneeSkuMinShelfLife INT,@n_ConsigneeSkuGroupMinShelfLife INT'
          +',@n_SkuOutGoingMinShelfLife INT, @n_StorerSkuMinShelfLife INT'
          +',@c_ID NVARCHAR(18)'
          +',@c_UDF01 NVARCHAR(30), @c_UDF02 NVARCHAR(30), @c_UDF03 NVARCHAR(30), @c_UDF04 NVARCHAR(30), @c_UDF05 NVARCHAR(30)'
      --(Wan01) - END

      EXEC sp_executesql @c_SQLStatement, @c_SQLParms,   --(Wan01)
         @c_Facility   ,
         @c_StorerKey  ,
         @c_SKU        ,
         @c_UOM        ,
         @c_HostWHCode ,
         @n_UOMBase    ,
         @n_QtyLeftToFulfill,
         @c_Orderkey,
         @c_OrderLineNumber,
         @c_Loadkey,  --NJOW06
         @c_Wavekey   --NJOW06
        ,@c_Lottable01                                   --(Wan01)
        ,@c_Lottable02                                   --(Wan01)
        ,@c_Lottable03                                   --(Wan01)
        ,@d_Lottable04                                   --(Wan01)
        ,@d_Lottable05                                   --(Wan01)
        ,@c_Lottable06                                   --(Wan01)
        ,@c_Lottable07                                   --(Wan01)
        ,@c_Lottable08                                   --(Wan01)
        ,@c_Lottable09                                   --(Wan01)
        ,@c_Lottable10                                   --(Wan01)
        ,@c_Lottable11                                   --(Wan01)
        ,@c_Lottable12                                   --(Wan01)
        ,@d_Lottable13                                   --(Wan01)
        ,@d_Lottable14                                   --(Wan01)
        ,@d_Lottable15                                   --(Wan01)
        ,@n_OrderMinShelfLife                            --(Wan01)
        ,@n_ConsigneeSkuMinShelfLife                     --(Wan01)
        ,@n_ConsigneeSkuGroupMinShelfLife                --(Wan01)
        ,@n_SkuOutGoingMinShelfLife                      --(Wan01)
        ,@n_StorerSkuMinShelfLife                        --(Wan01)
        ,@c_ID                                           --(Wan01)
        ,@c_UDF01                                        --(Wan01)
        ,@c_UDF02                                        --(Wan01)
        ,@c_UDF03                                        --(Wan01)
        ,@c_UDF04                                        --(Wan01)
        ,@c_UDF05                                        --(Wan01)

      --EXEC sp_ExecuteSQL @c_SQLStatement

      OPEN CURSOR_AVAILABLECFG

      FETCH NEXT FROM CURSOR_AVAILABLECFG INTO @c_LOT, @c_LOC, @c_ID, @n_QtyAvailable, @c_OtherValue --NJOW09

      WHILE (@@FETCH_STATUS <> -1) AND @n_QtyLeftToFulfill > 0
      BEGIN
      	 SET @n_PrevLotQtyAvailable = 0 --NJOW09  For @c_FIFOByMultiUOM=Y only

         IF @c_FIFOByMultiUOM = 'Y' --NJOW07
         BEGIN
         	 SELECT @dt_CurrLottable05 = Lottable05
         	 FROM LOTATTRIBUTE (NOLOCK)
         	 WHERE Lot = @c_Lot

           SELECT @n_PrevLotQtyAvailable = SUM(TL.QtyAvailable)
           FROM #TMP_LOT TL
           JOIN LOTATTRIBUTE LA (NOLOCK) ON TL.Lot = LA.Lot
           WHERE DATEDIFF(Day, LA.Lottable05, @dt_CurrLottable05) > 0 --NJOW09
           AND TL.QtyAvailable > 0

           SET @n_PrevLotQtyAvailable = ISNULL(@n_PrevLotQtyAvailable,0) --NJOW09

           IF @n_PrevLotQtyAvailable >= @n_QtyLeftToFulfill --NJOW09
           BEGIN
              --IF @n_PrevLotQtyAvailable >= @n_QtyLeftToFulfill --Previous batch can fulfill in next UOM and not to proceed next batch for current UOM
                 BREAK
              --ELSE IF @n_PrevLotQtyAvailable < @n_QtyLeftToFulfill --proceed next batch with the remaining qtylefttofulfill
              --BEGIN
              --	  SET @n_QtyLeftToFulfill = @n_QtyLeftToFulfill - @n_PrevLotQtyAvailable
              --END
           END
         END

         IF NOT EXISTS(SELECT 1 FROM #TMP_LOT WHERE Lot = @c_Lot)
         BEGIN
           INSERT INTO #TMP_LOT (Lot, QtyAvailable)
           SELECT LOTXLOCXID.Lot, SUM(LOTXLOCXID.Qty - LOTXLOCXID.QtyAllocated - LOTXLOCXID.QtyPicked
                  - CASE WHEN @c_AllocateQtyReplenFlag <> 'Y' THEN LOTXLOCXID.QtyReplen ELSE 0 END) --NJOW07
           FROM LOTXLOCXID (NOLOCK)
           JOIN LOT (NOLOCK) ON (LOTxLOCxID.Lot = LOT.Lot)
           JOIN LOC (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)
           JOIN ID (NOLOCK) ON (LOTxLOCxID.Id = ID.ID)
           WHERE LOTXLOCXID.Lot = @c_Lot
           AND ((LOT.Status = 'OK'
                 AND ID.Status = 'OK'
                 AND LOC.Status = 'OK'
                 AND LOC.LocationFlag = 'NONE') OR ISNULL(@c_AllocateHoldFlag,'') = 'Y')
           AND LOC.Facility = @c_Facility
           GROUP BY LOTXLOCXID.Lot

           /*SELECT Lot, Qty - QtyAllocated - QtyPicked
           FROM LOT (NOLOCK)
           WHERE LOT = @c_LOT*/
         END

         SET @n_LotQtyAvailable = 0

         SELECT @n_LotQtyAvailable = QtyAvailable
         FROM #TMP_LOT
         WHERE Lot = @c_Lot

         IF @n_LotQtyAvailable < @n_QtyAvailable
         BEGIN
             IF @c_UOM = '1'
                OR @c_AllocateByUCCFlag = 'Y' --NJOW09
                SET @n_QtyAvailable = 0
             ELSE
                SET @n_QtyAvailable = @n_LotQtyAvailable
         END

         IF @c_UOM = '1' AND @c_FullPalletByLocFlag = 'Y' --Pallet
         BEGIN
            SELECT @n_LocQty = 0, @n_NoOfLot = 0

            SELECT @n_LocQty = SUM(LLI.QTY - LLI.QTYALLOCATED - LLI.QTYPICKED - LLI.QtyReplen),
                   @n_NoOfLot = COUNT(DISTINCT LLI.Lot)
            FROM LOTXLOCXID LLI (NOLOCK)
            WHERE LLI.Loc = @c_LOC
            AND LLI.ID = @c_ID
            AND LLI.Storerkey = @c_Storerkey
            AND LLI.Sku = @c_Sku

            IF (@n_QtyLeftToFulfill - @n_PrevLotQtyAvailable) >= @n_QtyAvailable  --NJOW09
               AND @n_NoOfLot = 1 -- if multi lot per sku/loc/id then proceed to next strategy allocation by carton
            BEGIN
               SET @n_QtyToTake = @n_QtyAvailable
            END
            ELSE
            BEGIN
               SET @n_QtyToTake = 0
            END
         END
         ELSE
         BEGIN
         	  IF @c_AllocateByUCCFlag = 'Y' AND @c_UOM IN ('2','6','7')  --NJOW09
         	  BEGIN
         	  	 IF @c_FIFOByMultiUOM = 'Y'
         	  	 BEGIN
         	  	    IF(@n_QtyLeftToFulfill - @n_PrevLotQtyAvailable) <= 0
         	  	       SET @n_QtyToTake = 0
         	  	    ELSE IF @c_UOM = '2' AND (@n_QtyLeftToFulfill - @n_PrevLotQtyAvailable) < @n_QtyAvailable   --skip if partial UCC
         	  	       SET @n_QtyToTake = 0
         	  	    ELSE IF @c_UOM IN('6','7') AND (@n_QtyLeftToFulfill - @n_PrevLotQtyAvailable) < @n_QtyAvailable   --allocate partial UCC by @n_QtyLeftToFulfill after deduct from previous lot qty for next UOM
         	  	       SET @n_QtyToTake = @n_QtyLeftToFulfill - @n_PrevLotQtyAvailable
         	  	    ELSE
     	  	           SET @n_QtyToTake = @n_QtyAvailable
     	  	     END
     	  	     ELSE
     	  	        SET @n_QtyToTake = @n_QtyAvailable
         	  END
         	  ELSE
         	  BEGIN
               IF @n_UOMBase > 0       --(Wan01) Fixed divide by zero
               BEGIN
               	  IF @c_FIFOByMultiUOM = 'Y'  --NJOW09
               	  BEGIN
                     IF (@n_QtyLeftToFulfill - @n_PrevLotQtyAvailable) >= @n_QtyAvailable
                     BEGIN
                        SET @n_QtyToTake = Floor(@n_QtyAvailable / @n_UOMBase) * @n_UOMBase
                     END
                     ELSE
                     BEGIN
                     	 IF @n_UOMBase = 1 OR @c_UOM IN('6','7')
                     	 BEGIN
                     	 	  SET @n_QtyToTake = @n_QtyLeftToFulfill - @n_PrevLotQtyAvailable
                     	 END
                     	 ELSE
                           SET @n_QtyToTake = Floor((@n_QtyLeftToFulfill - @n_PrevLotQtyAvailable) / @n_UOMBase) * @n_UOMBase
                     END
                  END
                  ELSE
                  BEGIN
                     IF @n_QtyLeftToFulfill >= @n_QtyAvailable
                     BEGIN
                        SET @n_QtyToTake = Floor(@n_QtyAvailable / @n_UOMBase) * @n_UOMBase
                     END
                     ELSE
                     BEGIN
                        SET @n_QtyToTake = Floor(@n_QtyLeftToFulfill / @n_UOMBase) * @n_UOMBase
                     END
                  END
               END                     --(Wan01) Fixed divide by zero
            END
         END

         IF @n_QtyToTake > 0
         BEGIN
             UPDATE #TMP_LOT
             SET QtyAvailable = QtyAvailable - @n_QtyToTake
             WHERE Lot = @c_Lot

             IF @n_QtyToTake = @n_QtyAvailable AND @c_UOM = '1' AND @c_FullPalletByLocFlag = 'Y'
                SET @c_OtherValue = '@c_FULLPALLET=Y'  --'FULLPALLET'  --NJOW09
             --ELSE
             --  SET @c_OtherValue = '1'  --NJOW09 removed

             IF @c_AllocateByUCCFlag = 'Y' AND @c_UOM IN('2','6','7') --NJOW09
             BEGIN
             	  SET @c_OtherValue = '@c_UCCNo=' + LTRIM(RTRIM(@c_OtherValue))
             END

            --(Wan01) - START
            --IF ISNULL(@c_SQL,'') = ''
            --BEGIN
            --   SET @c_SQL = N'
            --         DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
            --         SELECT '''  + @c_LOT + ''', ''' + @c_LOC + ''', ''' + @c_ID + ''', ''' + CAST(@n_QtyToTake AS NVARCHAR(10)) + ''', ''' + @c_OtherValue + '''
            --         '
            --END
            --ELSE
            --BEGIN
            --   SET @c_SQL = @c_SQL + N'
            --         UNION ALL
            --         SELECT '''  + @c_LOT + ''', ''' + @c_LOC + ''', ''' + @c_ID + ''', ''' + CAST(@n_QtyToTake AS NVARCHAR(10)) + ''', ''' + @c_OtherValue + '''
            --         '
            --END
            SET @c_Lot       = RTRIM(@c_Lot)
            SET @c_Loc       = RTRIM(@c_Loc)
            SET @c_ID        = RTRIM(@c_ID)

            EXEC isp_Insert_Allocate_Candidates
               @c_Lot = @c_Lot
            ,  @c_Loc = @c_Loc
            ,  @c_ID  = @c_ID
            ,  @n_QtyAvailable = @n_QtyToTake
            ,  @c_OtherValue = @c_OtherValue
            --(Wan01) - END

            SET @n_QtyLeftToFulfill = @n_QtyLeftToFulfill - @n_QtyToTake
         END

         FETCH NEXT FROM CURSOR_AVAILABLECFG INTO @c_LOT, @c_LOC, @c_ID, @n_QtyAvailable, @c_OtherValue --NJOW09
      END
      CLOSE CURSOR_AVAILABLECFG
      DEALLOCATE CURSOR_AVAILABLECFG

      --(Wan01) - START
      EXEC isp_Cursor_Allocate_Candidates
      @n_SkipPreAllocationFlag = 1    --Return Lot column
      --IF ISNULL(@c_SQL,'') <> ''
      --BEGIN
      --   EXEC sp_ExecuteSQL @c_SQL
      --END
      --ELSE
      --BEGIN
      --   DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
      --   SELECT TOP 0 NULL, NULL, NULL, NULL, NULL
      --END
      --(Wan01) - END
   END
   ELSE
   BEGIN
      SELECT @c_SQLStatement = " DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR " +
                              " SELECT LOTxLOCxID.LOT, LOTxLOCxID.LOC,LOTxLOCxID.ID, " +
                              CASE WHEN @c_AllocateByUCCFlag = 'Y' THEN  --NJOW09
                                 " QTYAVAILABLE = UCC.Qty, "
                              WHEN @c_AllocateQtyReplenFlag = 'Y' THEN
                                 " QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), "
                              ELSE
                                 " QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QTYREPLEN), " END +
                              CASE WHEN @c_AllocateByUCCFlag = 'Y' THEN  --NJOW09
                                 " '@c_UCCNo=' + UCC.UCCNo " ELSE " '1' " END +
                              " FROM LOTxLOCxID (NOLOCK) " +
                              " JOIN LOTATTRIBUTE (NOLOCK) ON (LOTxLOCxID.Lot = LOTATTRIBUTE.Lot) " +
                              " JOIN LOT (NOLOCK) ON (LOTxLOCxID.Lot = LOT.Lot) " +
                              " JOIN LOC (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC) " +
                              " JOIN ID (NOLOCK) ON (LOTxLOCxID.Id = ID.ID) " +
                              " JOIN SKUXLOC (NOLOCK) ON (LOTxLOCxID.Storerkey =  SKUXLOC.Storerkey AND LOTxLOCxID.Sku = SKUXLOC.Sku AND LOTxLOCxID.Loc =  SKUXLOC.Loc) " +
                              " JOIN SKU (NOLOCK) ON (LOTxLOCxID.Storerkey =  SKU.Storerkey AND SKU.Sku =  SKUXLOC.Sku) " +
                              " JOIN STORER (NOLOCK) ON (LOTxLOCxID.Storerkey =  STORER.Storerkey) " +
                              " JOIN PACK (NOLOCK) ON (SKU.Packkey = PACK.Packkey) " +
                              CASE WHEN  @c_AllocateByUCCFlag = 'Y' THEN  --NJOW09
                              " JOIN UCC (NOLOCK) ON (UCC.StorerKey = LOTxLOCxID.StorerKey AND UCC.SKU = LOTxLOCxID.SKU AND
                                                     UCC.LOT = LOTxLOCxID.LOT AND UCC.LOC = LOC.LOC AND UCC.ID = ID.ID AND UCC.Status < '3') " ELSE " " END +
                              --" WHERE LOTxLOCxID.Storerkey = @c_Storerkey) " +	--(CLVN01)
							                " WHERE LOTxLOCxID.Storerkey = @c_Storerkey " +	    --(CLVN01)
                              " AND LOTxLOCxID.Sku = @c_Sku " +
                              " AND LOC.Facility = @c_Facility " +
                              CASE WHEN @c_AllocateQtyReplenFlag = 'Y' THEN
                                 " AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) >= @n_uombase "
                              ELSE
                                 " AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QTYREPLEN) >= @n_uombase " END +
                              ISNULL(RTRIM(@c_Condition),'') + " " + ISNULL(RTRIM(@c_CLKCondition),'') + " " + @c_SortBy

      --(Wan01) - START
      SET @c_SQLParms = N'@c_Facility NVARCHAR(5), @c_StorerKey NVARCHAR(15), @c_SKU  NVARCHAR(20), @c_UOM NVARCHAR(10), @c_HostWHCode NVARCHAR(10)'
          +', @n_UOMBase INT, @n_QtyLeftToFulfill INT, @c_Orderkey NVARCHAR(10), @c_OrderLineNumber NVARCHAR(5), @c_Loadkey NVARCHAR(10), @c_Wavekey NVARCHAR(10)'
          +',@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), @d_Lottable04 DATETIME, @d_Lottable05 DATETIME'
          +',@c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), @c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30)'
          +',@c_Lottable11 NVARCHAR(30), @c_Lottable12 NVARCHAR(30), @d_Lottable13 DATETIME, @d_Lottable14 DATETIME, @d_Lottable15 DATETIME'
          +',@n_OrderMinShelfLife INT, @n_ConsigneeSkuMinShelfLife INT,@n_ConsigneeSkuGroupMinShelfLife INT'
          +',@n_SkuOutGoingMinShelfLife INT, @n_StorerSkuMinShelfLife INT'
          +',@c_ID NVARCHAR(18)'
          +',@c_UDF01 NVARCHAR(30), @c_UDF02 NVARCHAR(30), @c_UDF03 NVARCHAR(30), @c_UDF04 NVARCHAR(30), @c_UDF05 NVARCHAR(30)'
      --(Wan01) - END

      EXEC sp_executesql @c_SQLStatement, @c_SQLParms,   --(Wan01)
         @c_Facility   ,
         @c_StorerKey  ,
         @c_SKU        ,
         @c_UOM        ,
         @c_HostWHCode ,
         @n_UOMBase    ,
         @n_QtyLeftToFulfill,
         @c_Orderkey,
         @c_OrderLineNumber,
         @c_Loadkey,  --NJOW06
         @c_Wavekey,  --NJOW06
         @c_Lottable01                                   --(Wan01)
        ,@c_Lottable02                                   --(Wan01)
        ,@c_Lottable03                                   --(Wan01)
        ,@d_Lottable04                                   --(Wan01)
        ,@d_Lottable05                                   --(Wan01)
        ,@c_Lottable06                                   --(Wan01)
        ,@c_Lottable07                                   --(Wan01)
        ,@c_Lottable08                                   --(Wan01)
        ,@c_Lottable09                                   --(Wan01)
        ,@c_Lottable10                                   --(Wan01)
        ,@c_Lottable11                                   --(Wan01)
        ,@c_Lottable12                                   --(Wan01)
        ,@d_Lottable13                                   --(Wan01)
        ,@d_Lottable14                                   --(Wan01)
        ,@d_Lottable15                                   --(Wan01)
        ,@n_OrderMinShelfLife                            --(Wan01)
        ,@n_ConsigneeSkuMinShelfLife                     --(Wan01)
        ,@n_ConsigneeSkuGroupMinShelfLife                --(Wan01)
        ,@n_SkuOutGoingMinShelfLife                      --(Wan01)
        ,@n_StorerSkuMinShelfLife                        --(Wan01)
        ,@c_ID                                           --(Wan01)
        ,@c_UDF01                                        --(Wan01)
        ,@c_UDF02                                        --(Wan01)
        ,@c_UDF03                                        --(Wan01)
        ,@c_UDF04                                        --(Wan01)
        ,@c_UDF05                                        --(Wan01)

      --EXEC sp_ExecuteSQL @c_SQLStatement
   END

   EXIT_SP:

   IF CURSOR_STATUS('GLOBAL' , 'CURSOR_AVAILABLECFG') in (0 , 1)
   BEGIN
      CLOSE CURSOR_AVAILABLECFG
      DEALLOCATE CURSOR_AVAILABLECFG
   END
END

GO