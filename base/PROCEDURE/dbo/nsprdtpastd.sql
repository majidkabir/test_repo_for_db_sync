SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/**************************************************************************************/
/* Store Procedure:  nspRDTPASTD                                                      */
/* Creation Date: 28-Oct-2009                                                         */
/* Copyright: IDS                                                                     */
/* Written by:                                                                        */
/*                                                                                    */
/* Purpose:  Stored Procedure for PUTAWAY FROM ASN                                    */
/*                                                                                    */
/* Called FROM RDT Pallet Putaway                                                     */
/*                                                                                    */
/* Input Parameters:  @c_userid,          - User Id                                   */
/*                    @c_storerkey,       - Storerkey                                 */
/*                    @c_LOT,             - Lot                                       */
/*                    @c_SKU,             - Sku                                       */
/*                    @c_ID,              - Id                                        */
/*                    @c_FromLoc,         - FROM Location                             */
/*                    @n_Qty,             - Putaway Qty                               */
/*                    @c_uom,             - UOM unit                                  */
/*                    @c_PackKey,         - Packkey for sku                           */
/*                    @n_PutawayCapacity  - Putaway Capacity                          */
/*                                                                                    */
/* Output Parameters: @c_Final_ToLoc      - Final ToLocation                          */
/*                                                                                    */
/* Return Status:  None                                                               */
/*                                                                                    */
/* Usage:                                                                             */
/*                                                                                    */
/* Local Variables:                                                                   */
/*                                                                                    */
/* Called By:                                                                         */
/*                                                                                    */
/* PVCS Version: 1.5                                                                  */
/*                                                                                    */
/* Version: 5.4                                                                       */
/*                                                                                    */
/* Data Modifications:                                                                */
/*                                                                                    */
/* Updates:                                                                           */
/* Date         Author        Ver   Purposes                                          */
/* 28-Oct-2009  Shong               Created (Modified FROM nspASNPASTD)               */
/* 05-Jan-2010  Shong         1.1   Titan Project                                     */
/* 23-FEb-2010  Vicky         1.1   NextPnDLocation search should include             */
/*                                  PutawayZone (Vicky01)                             */
/* 24-Feb-2010  Shong         1.1   Force to loop if no location found in             */
/*                                  Aisle                                             */
/* 25-Feb-2010  Vicky         1.1   Fixes on Loop stopped when                        */
/*                                  NextAisle = StartAisle and did NOT                */
/*                                  to loop the next step in strategy                 */
/*                                  (Vicky02)                                         */
/* 26-Feb-2010  Shong         1.1   Fixing Pnd Outer/Centre Seq Issues                */
/* 27-Feb-2010  Vicky         1.1   Fixing Pnd Outer/Centre Seq (Vicky03)             */
/* 03-Mar-2010  ChewKP        1.1   Fixing QTYHand need to - QTYPicked                */
/*                                   (ChewKP01)                                       */
/* 26-May-2010  Vicky         1.2   Should NOT look at PutawayZone = ''               */
/*                                  to eliminate Performance issue (Vicky04)          */
/* 24-Jun-2010  ChewKP        1.3   Diana Project PA by BOM SKU Std Cube              */
/*                                  (ChewKP02)                                        */
/* 05-Aug-2010  ChewKP        1.3   Bug Fixes on STDCUBE & STDGROSSWEIGHT             */
/*                                  Calculation for BOMSKU (ChewKP03)                 */
/* 24-Aug-2010  Shong         1.3   Add new Strategy 03 - Put to Pick Loc If          */
/*                                  FROM Specified Location                           */
/* 03-Jan-2011  Shong         1.3   Cater Single SKU Putaway if SKU value pass        */
/*                                  in as Parameter                                   */
/* 05-Jan-2011  ChewKP        1.4   Cater Putaway if SKU value pass in as             */
/*                                  Parameter (ChewKP04)                              */
/* 23-Mar-2011  Leong         1.5   SOS# 209838 - Add ISNULL check and display        */
/*                                                error in handheld                   */
/* 14-Arp-2011  Audrey        1.5   SOS# 206770 - comment SET @b_MultiLotID           */
/*                                                = @n_IdCnt (ang01)                  */
/* 28-Sep-2011  Shong         1.6   SOS#224116 - US LCI Project (Shong001)            */
/* 07-Dec-2011  ChewKP        1.7   Failed Putaway when FromLoc = ToLoc               */
/*                                  (ChewKP05)                                        */
/* 06-Feb-2012  Shong         1.8   Include Restriction By UCC Carton Size            */
/* 21-Feb-2012  ChewKP        1.9   Calculating PackSize by Location                  */
/*                                  (ChewKP06)                                        */
/* 04-Apr-2012  Ung           2.0   Move check upfront for PAType = 28, 29 on         */
/*                                  LocationFlag and LocationStateRestriction         */
/*                                  2-Do not Mix Skus, 3-Do not Mix Lots              */
/* 09-Apr-2012  Ung           2.1   Fix PAType = 26-29, infinite loop (ung01)         */
/* 04-Jun-2012  ChewKP        2.2   SOS#245272 - Bug Fix (ChewKP05)                   */
/* 13-Jun-2012  Ung           2.3   SOS240955 Add dimention restriction               */
/*                                  17-Fit by UCC cube                                */
/* 20-Jul-2012  Ung           2.4   SOS251060 Further fix on SOS240955 (ung02)        */
/* 19-Jul-2012  Ung           2.5   SOS250731 PAType=61 Find PnD loc using            */
/*                                  LOC.MaxPallet (ung03)                             */
/* 13-Aug-2012  Ung           2.6   SOS252964 Add location state restriction          */
/*                                  12-ABC Descending, 13-ABC EXC                     */
/* 14-Mar-2013  Ung           2.7   SOS272442 (ung04)                                 */
/*                                  Fix PND not reset when chg PAType                 */
/*                                  Fix PAType 61 fail not run next strategln         */
/*                                  PAType 61 PND consider MaxPallet                  */
/*                                  PAType 61 search next aisle by zone, aisle        */
/* 13-Aug-2012  Ung           2.8   SOS251326 Add NoMixLottable01..04 (ung05)         */
/* 28-Jun-2012  Ung           2.9   SOS246200 Extra param and PutCode (ung06)         */
/*                                  SOS257227                                         */
/*                                  Add Fit by aisle (ung07)                          */
/*                                  Add PND_IN, PND_OUT (ung08)                       */
/*                                  Add PAType 05 From Zone then ToLoc (ung09)        */
/* 15-Aug-2013  Shong         3.0   Performance Tuning VF-CDC                         */
/* 21-Aug-2013  Shong         3.1   Order By Putaway Logical Location, Change         */
/*                                  Single Select into Cursor Loop                    */
/* 04-Feb-2014  ChewKP        3.2   SOS#292706 - Add Another PA Type '62'             */
/*                                  Search Empty Loc Consider PendingMoveIn           */
/*                                  (ChewKP07)                                        */
/* 06-Feb-2014  James         3.3   Bug fix (james01)                                 */
/* 05-May-2014  ChewKP        3.4   Include Multiple PutawayZone Search in            */
/*                                  PAType = '19', '21' (ChewKP08)                    */
/* 02-Dec-2013  Ung           3.5   SOS257227 Fix PAType 61 infinite loop             */
/* 30-May-2014  Ung           3.2   SOS322241 Add custom putaway strategy key         */
/*                                  Fix SUM without ISNULL                            */
/* 02-Nov-2014  James         3.3   Change '62' to include multizone (james02)        */
/* 28-May-2015  ChewKP        3.4   SOS#342117 Add NoMixLottable5-15(ChewKP09)        */
/* 03-Jun-2015  ChewKP        3.5   SOS#341733 - Cater NoMixLottable with             */
/*                                  CommingleSKU Flag on Loc setup                    */
/*                                  Fix SQL Statement (ChewKP10)                      */
/* 23-Sep-2015  James         3.6   SOS337104 - Add PAType 23 (james03)               */
/* 26-Nov-2015  Ung           3.7   SOS357411 Change PREPACKBYBOM                     */
/* 03-Feb-2016  Ung           3.8   SOS360340 Add PABookingKey                        */
/* 06-Jun-2016  Ung           3.9   IN00057923 Cater UCC.Status=3                     */
/* 11-Aug-2016  TLTING        4.0   (nolock) and remove SetROWCOUNT                   */
/* 25-Oct-2016  Ung           4.1   Performance tuning                                */
/* 11-Aug-2017  JHTAN         4.2   IN00433406 PAType = 07 did not suggest go         */
/*                                  to CASE location (JHTAN01)                        */
/* 05-Jun-2017  ChewKP        4.3   WMS-1956 - Add Fit by Aisle Multi Case            */
/*                                  Count (ChewKP11)                                  */
/* 19-Dec-2017  Leong         4.4   INC0075406 - Revise PAType 07 checking.           */
/* 15-May-2020  Shong         4.5   Replace Constant with Variable in Dynamic         */
/*                                  SQL Statement                                     */
/* 08-Jul-2020  Shong         4.6   Bug Fixing                                        */
/* 15-Dec-2020  NJOW01        4.7   WMS-15776 TH Michelin PA                          */
/* 12-Jan-2021  NJOW02        4.8   WMS-16023 type 07 cater for pendingmovein         */
/* 10-Feb-2023  NJOW03        4.9   WMS-21722 Allow check nomixlottable for all       */
/*                                  commingle sku in a loc.                           */
/* 10-Feb-2023  NJOW03        4.9   DEVOPS Combine Script                             */
/* 13-Feb-2024  Ung           5.0   WMS-24727 Add MaxSKU, MaxQTY, MaxCarton           */
/* 14-Feb-2023  SHONG01       5.1   WMS-12676 Mattel PA Strategy                      */
/* 15-Feb-2023  SHONG02       5.2   Fixing PA 52 to cater if Lottable04 is NULL       */
/* 13-Mar-2024  kelvinongcy   5.3   Performance tuning remove harcoded index (kocy01) */
/* 20-Mar-2024  CYU027        5.4   Use Pallet Height for Location                    */
/* 15-Apr-2024  SPChin        5.5   UWP-14640 Bug Fixed                               */
/* 31-May-2024  NLT013        5.6   UWP-20191 Skip PAType02 if fromLocation <>        */
/*                                  pa_FromLoc                                        */
/**************************************************************************************/
CREATE   PROCEDURE [dbo].[nspRDTPASTD]
     @c_userid          NVARCHAR(18)
   , @c_StorerKey       NVARCHAR(15)
   , @c_LOT             NVARCHAR(10)
   , @c_SKU             NVARCHAR(20)
   , @c_ID              NVARCHAR(18)
   , @c_FromLoc         NVARCHAR(10)
   , @n_Qty             INT = 0
   , @c_Uom             NVARCHAR(10) = ''
   , @c_PackKey         NVARCHAR(10) = ''
   , @n_PutawayCapacity INT
   , @c_Final_ToLoc     NVARCHAR(10)      OUTPUT
   , @c_PickAndDropLoc  NVARCHAR(10) = '' OUTPUT
   , @c_FitCasesInAisle NVARCHAR(1)  = '' OUTPUT
   , @c_Param1          NVARCHAR(20) = '' OUTPUT
   , @c_Param2          NVARCHAR(20) = '' OUTPUT
   , @c_Param3          NVARCHAR(20) = '' OUTPUT
   , @c_Param4          NVARCHAR(20) = '' OUTPUT
   , @c_Param5          NVARCHAR(20) = '' OUTPUT
   , @c_PAStrategyKey   NVARCHAR(10) = ''
   , @n_PABookingKey    INT = 0           OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Err                      INT,
           @c_ErrMsg                   NVARCHAR(255),
           @b_Debug                    INT,
           @cSQL                       NVARCHAR(2000),
           @cSQLParam                  NVARCHAR(1000)

   -- Added By Shong
   DECLARE @n_RowCount            INT,
           @c_ToLoc                    NVARCHAR(10) = '',
           @n_IdCnt                    INT,
           @b_MultiProductID           INT,
           @b_MultiLotID               INT,
           @c_PutawayStrategyKey       NVARCHAR(10),
           @b_Success                  INT,
           @n_StdGrossWgt              FLOAT(8),
           @n_pTraceHeadKey            NVARCHAR(10), -- Unique key value for the putaway trace header
           @n_PtraceDetailKey          NVARCHAR(10), -- part of key value for the putaway trace detail
           @n_LocsReviewed             INT, -- counter for the number of location reviewed
           @c_Reason                   NVARCHAR(80), -- putaway trace rejection reason text for putaway trace detail
           @d_StartDTim                DATETIME, -- Start time of this stored procedure
           @n_QtylocationLimit         INT, -- Location Qty Capacity for Case/Piece Pick Locations
           @c_Facility                 NVARCHAR(5), -- CDC Migration
           @n_MaxPallet                INT,
           @n_PalletQty                INT,
           @n_StackFactor              INT, -- SOS36712 KCPI
           @n_MaxPalletStackFactor     INT, -- SOS36712 KCPI
           @c_ToHostWhCode             NVARCHAR(10), -- SOS69388 KFP
           @c_Color                    NVARCHAR(10), --NJOW01
           @dt_Lottable05              DATETIME,  --NJOW01
           @c_Class                    NVARCHAR(10)  --NJOW01


   -- TITAN Project
   DECLARE @c_NextPnDLocation NVARCHAR(10),
           @c_NextPnDAisle    NVARCHAR(10),
           @c_LastPndAisle    NVARCHAR(10),
           @c_StartAisle      NVARCHAR(10),
           @c_LastPnDLocCat   NVARCHAR(10),
           @c_LastPnDLocZone  NVARCHAR(10), --(ung04)
           @c_NextPnDLocZone  NVARCHAR(10), --(ung04)
           @n_LoopAllAisle    INT,
           @cpa_PutawayZone01 NVARCHAR(10),
           @cpa_PutawayZone02 NVARCHAR(10),
           @cpa_PutawayZone03 NVARCHAR(10),
           @cpa_PutawayZone04 NVARCHAR(10),
           @cpa_PutawayZone05 NVARCHAR(10),
           @cpa_PutawayZoneExt NVARCHAR(1000),
           @c_MaxAisle        NVARCHAR(10), -- (Vicky02)
           @c_NextPnDLocCat   NVARCHAR(10), -- (SHONG02)
           @n_PrevPutLineNum  INT,  -- (Vicky03)
           @c_MultiPutawayZone NVARCHAR(100), -- (ChewKP08)
           @nPutawayZoneCount  INT, -- (ChewKP08)
           @c_ChkLocByCommingleSkuFlag  NVARCHAR(10),      --(ChewKP10)
           @c_ChkNoMixLottableForAllSku NVARCHAR(30) = '',  --NJOW03
           @c_UCC                       NVARCHAR(1) = ''

   /* -- US LCI Project (Shong001) --*/
   DECLARE @c_PalletType NVARCHAR(30) -- 1_Lot_CartonSize, 1_Lot_2CartonSize, Mixed_Lot_CartonSize
          ,@n_NumberOfPackSize INT
          ,@n_NumberOfSKU      INT
          ,@c_PA_Decription    NVARCHAR(60)
          ,@b_CheckCube        INT
          ,@b_PutawayBySKU     NVARCHAR(1)
          ,@n_InvBOMCube       FLOAT
          ,@c_SQLParms         NVARCHAR(MAX) = N'' 

   SELECT @c_ToLoc          = SPACE(10),
          @n_IdCnt          = 0,
          @b_MultiProductID = 0,
          @b_MultiLotID     = 0,
          @n_LocsReviewed   = 0,
          @d_StartDTim      = GETDATE(),
          @c_LastPndAisle   ='',
          @c_MaxAisle       = '', -- (Vicky02)
          @n_PrevPutLineNum = 0   -- (Vicky03)
          

   SET @c_Final_ToLoc = ''

   SELECT @c_Facility = Facility
   FROM   LOC WITH (NOLOCK)
   WHERE  Loc = @c_FromLoc

   DECLARE @c_Lottable01         NVARCHAR(18),
           @c_Lottable02         NVARCHAR(18),
           @c_Lottable03         NVARCHAR(18), -- SOS#140197
           @d_Lottable04         DATETIME,
           @d_Lottable05         DATETIME,     -- SOS#140197
           @d_CurrentLottable05  DATETIME,
           @c_SKU_ABC            NVARCHAR(5),
           @c_Style              NVARCHAR(20)

   DECLARE @c_PTraceType         NVARCHAR(30)
   SELECT @c_PTraceType = 'nspRDTPASTD'
   SELECT @c_SKU_ABC = ''

   DECLARE @NotMixLottable TABLE(
     RowRef  INT IDENTITY(1,1) NOT NULL,
     LottableNo INT  NULL )
   -- UWP - 15394
   DECLARE @f_totalHeight        DECIMAL(15,5),
           @b_config_PALDIMCALC  NVARCHAR( 10)

   SELECT @b_config_PALDIMCALC = ISNULL(SVALUE,'') FROM dbo.STORERCONFIG (NOLOCK)
   WHERE Storerkey = @c_StorerKey
     AND CONFIGKEY = 'PALDIMCALC'

    --(ChewKP10) - START
   SET @c_ChkLocByCommingleSkuFlag = 0
   SET @b_success = 0
   EXECUTE nspGetRight
           @c_facility
         , @c_StorerKey               -- Storer
         , @c_Sku       -- Sku
         , 'ChkLocByCommingleSkuFlag'  -- ConfigKey
         , @b_success                     OUTPUT
         , @c_ChkLocByCommingleSkuFlag    OUTPUT
         , @n_err                         OUTPUT
         , @c_errmsg                      OUTPUT

   IF @b_success <> 1
   BEGIN
      SET @c_ToLoc = ''
      GOTO LOCATION_ERROR
   END
   --(ChewKP10) - END
   
   --NJOW03 S
   SET @b_success = 0
   Execute nspGetRight
           @c_facility
         , @c_StorerKey               -- Storer
         , @c_Sku       -- Sku
         , 'ChkNoMixLottableForAllSku' -- ConfigKey
         , @b_success                     OUTPUT
         , @c_ChkNoMixLottableForAllSku   OUTPUT
         , @n_err                         OUTPUT
         , @c_errmsg                      OUTPUT

   IF @b_success <> 1
   BEGIN
      SET @c_ToLoc = ''
      GOTO LOCATION_ERROR
   END
   --NJOW03 E

   SET @b_success = 0
   Execute nspGetRight
           @c_facility
         , @c_StorerKey -- Storer
         , @c_Sku       -- Sku
         , 'UCC'        -- ConfigKey
         , @b_success   OUTPUT
         , @c_UCC       OUTPUT
         , @n_err       OUTPUT
         , @c_errmsg    OUTPUT

   IF @b_success <> 1
   BEGIN
      SET @c_ToLoc = ''
      GOTO LOCATION_ERROR
   END

   IF OBJECT_ID('tempdb..#t_PutawayZone') IS NOT NULL
      DROP TABLE #t_PutawayZone
   
   CREATE TABLE #t_PutawayZone (PutawayZone NVARCHAR(10))

   IF OBJECT_ID('tempdb..#t_LocationFlagInclude') IS NOT NULL
      DROP TABLE #t_LocationFlagInclude
   
   CREATE TABLE #t_LocationFlagInclude (LocationFlagInclude NVARCHAR(10))

   IF OBJECT_ID('tempdb..#t_LocStateRestriction') IS NOT NULL
      DROP TABLE #t_LocStateRestriction

   CREATE TABLE #t_LocStateRestriction (LocationStateRestriction NVARCHAR(10))

   DECLARE @t_SKUList TABLE (StorerKey NVARCHAR(15), SKU NVARCHAR(20))
 
   DECLARE @n_IsRDT Int
   EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT
 
    IF ISNULL(RTRIM(@c_SKU), '')<>'' AND @n_Qty > 0
       SET @b_PutawayBySKU = 'Y'
    ELSE
       SET @b_PutawayBySKU = 'N'

   -- If SKU NOT provided, then get FROM LOT
   IF ISNULL(RTRIM(@c_SKU), '')=''
   BEGIN
      IF ISNULL(RTRIM(@c_LOT), '')<>''
      BEGIN
         SELECT @c_StorerKey = StorerKey,
                @c_SKU = SKU
         FROM   LOT(NOLOCK)
         WHERE  LOT = @c_LOT
      END
   END

   -- Check if Pallet contain Conmingle LOT?
   SET @b_MultiLotID = 0
   IF ISNULL(RTRIM(@c_ID), '') <> ''
   BEGIN
      IF ISNULL(RTRIM(@c_SKU),'') = ''
      BEGIN
         SELECT @n_IdCnt = COUNT(DISTINCT LOT),
                @b_MultiProductID = CASE
                                       WHEN COUNT(DISTINCT SKU)>1 THEN 1
                                       ELSE 0
                                    END
         FROM   LOTxLOCxID WITH (NOLOCK)
         WHERE  ID = @c_ID AND
                LOC = @c_FromLoc AND
                QTY > 0
      END
      ELSE
      BEGIN
         SELECT @n_IdCnt = COUNT(DISTINCT LOT),
                @b_MultiProductID = 0
         FROM   LOTxLOCxID WITH (NOLOCK)
         WHERE  ID  = @c_ID AND
                LOC = @c_FromLoc AND
                SKU = @c_SKU AND
                StorerKey = @c_StorerKey AND
                QTY > 0
      END

      -- If More then 1 SKU then
      IF @b_MultiProductID = 0
      BEGIN
         -- (ChewKP04) Start
         IF ISNULL(RTRIM(@c_SKU),'') <> ''
         BEGIN
            SELECT @n_Qty = CASE
               WHEN @n_Qty=0 THEN ISNULL( SUM(QTY), 0)
                              ELSE @n_Qty
                            END,
                   @c_LOT = CASE
                              WHEN @n_IdCnt = 1 THEN MAX(LOT)
                              ELSE ''
                            END
            FROM  LOTxLOCxID WITH (NOLOCK)
            WHERE ID  = @c_ID AND
                  LOC = @c_FromLoc AND
                  QTY > 0 AND
                  StorerKey = @c_StorerKey AND
                  SKU = @c_SKU

            --SET @b_MultiLotID = @n_IdCnt(ang01)
         END -- (ChewKP04) End
         ELSE
         BEGIN
          SELECT @n_Qty = CASE
                              WHEN @n_Qty=0 THEN ISNULL( SUM(QTY), 0)
                              ELSE @n_Qty
                            END,
                   @c_SKU = SKU,
                   @c_LOT = CASE
                              WHEN @n_IdCnt = 1 THEN MAX(LOT)
                              ELSE ''
                            END
            FROM   LOTxLOCxID WITH (NOLOCK)
            WHERE  ID  = @c_ID AND
                   LOC = @c_FromLoc AND
                   QTY > 0 AND
                   StorerKey = @c_StorerKey
            GROUP BY StorerKey, SKU

            --SET @b_MultiLotID = @n_IdCnt(ang01)
         END
      END
      ELSE
      BEGIN
         SET @b_MultiLotID = 1 -- Multiproduct is multilot by definition of lot
         SET @c_LOT = ''
         SET @c_StorerKey = ''
         SET @c_SKU = ''
      END
   END -- ID NOT Blank
   ELSE
   BEGIN
      IF ISNULL(RTRIM(@c_LOT), '') <> ''
      BEGIN
         SELECT @n_IdCnt = COUNT(DISTINCT ID)
         FROM   LOTxLOCxID WITH (NOLOCK)
         WHERE  LOT  = @c_LOT AND
                LOC = @c_FromLoc AND
                QTY > 0

         IF @n_IdCnt = 1
         BEGIN
            SELECT @c_StorerKey = StorerKey,
                   @c_SKU = SKU,
                   @c_ID = ID,
                   @n_Qty = CASE
                              WHEN @n_Qty = 0 THEN QTY
                              ELSE @n_Qty
                            END
            FROM  LOTxLOCxID WITH (NOLOCK)
            WHERE LOT  = @c_LOT AND
                  LOC = @c_FromLoc AND
                  QTY > 0
         END
      END
   END

   IF @b_MultiProductID = 1
   BEGIN
      INSERT INTO @t_SKUList
      (
         StorerKey,
         SKU
      )
      SELECT DISTINCT StorerKey, SKU
      FROM  LOTxLOCxID WITH (NOLOCK)
      WHERE ID  = @c_ID AND
            LOC = @c_FromLoc AND
            QTY > 0
   END

   IF @b_MultiLotID <> 1
   BEGIN
      SELECT @c_Lottable01 = Lottable01,
             @c_Lottable02 = Lottable02,
             @c_Lottable03 = Lottable03,
             @d_Lottable04 = Lottable04,
             @d_Lottable05 = Lottable05
      FROM   LotAttribute WITH (NOLOCK)
      WHERE  LOT = @c_LOT
   END
   ELSE
   BEGIN
      -- If Multiple LOT Found, Get the last Lottables
      SELECT TOP 1
            @c_Lottable01 = Lottable01,
            @c_Lottable02 = Lottable02,
            @c_Lottable03 = Lottable03,
            @d_Lottable04 = Lottable04,
            @d_Lottable05 = Lottable05
      FROM  LotAttribute WITH (NOLOCK)
      JOIN LOTxLOCxID WITH (NOLOCK)
        ON LotAttribute.LOT = LOTxLOCxID.LOT
      WHERE ID = @c_ID
      ORDER BY LotAttribute.LOT DESC
   END

   DECLARE @n_PalletTotStdCube     DECIMAL(15,5),
           @n_PalletTotStdGrossWgt DECIMAL(15,5)

   IF @b_MultiProductID = 1
   BEGIN
      SELECT @n_PalletTotStdCube = (S.STDCUBE * LLI.Qty),
             @n_PalletTotStdGrossWgt = (S.STDGROSSWGT * LLI.Qty)
      FROM SKU s WITH (NOLOCK)
      JOIN LOTxLOCxID lli WITH (NOLOCK) ON S.StorerKey = LLI.StorerKey AND S.Sku = LLI.SKU
      WHERE LLI.Loc = @c_FromLoc AND
            LLI.Id  = @c_ID AND
            LLI.Qty > 0
   END
   ELSE
   BEGIN
      SELECT @n_PalletTotStdCube = (S.STDCUBE * LLI.Qty),
             @n_PalletTotStdGrossWgt = (S.STDGROSSWGT * LLI.Qty)
         FROM SKU S WITH (NOLOCK)
         JOIN LOTxLOCxID lli WITH (NOLOCK) ON S.StorerKey = LLI.StorerKey AND S.Sku = LLI.SKU
         WHERE LLI.Loc = @c_FromLoc AND
               LLI.Id  = @c_ID AND
               LLI.StorerKey = @c_StorerKey AND
               LLI.Sku = @c_SKU AND
               LLI.Qty > 0
   END

   /* -- CALCULATE BY BOMSKU Start (ChewKP02)--*/
   DECLARE @c_CalculateByBOM         NVARCHAR(1),
           @c_BOMSKU                 NVARCHAR(20),
           @n_LOQTY                  INT,
           @f_STDCUBE                DECIMAL(15,5),
           @f_TotalCube              DECIMAL(15,5),
           @f_STDGROSSWGT            DECIMAL(15,5),
           @f_TotalGROSSWGT          DECIMAL(15,5),
           @n_CaseCnt                INT,
           @f_CSTDCUBE               DECIMAL(15,5),
           @f_Length                 DECIMAL(15,5),
           @f_Width                  DECIMAL(15,5),
           @f_Height                 DECIMAL(15,5),
           @f_PPalletTotStdCube      DECIMAL(15,5),
           @f_PPPalletTotStdGrossWgt DECIMAL(15,5),
           @c_PrePackByBOM           NVARCHAR(1),
           @n_TotalBOMQTY            INT,
           @c_PPStorerkey            NVARCHAR(15)

   SET @c_PPStorerkey = ''

   IF @b_MultiProductID = 1
   BEGIN
      SELECT TOP 1 @c_PPStorerkey = StorerKey
      FROM   @t_SKUList t

      SELECT @c_PrePackByBOM = SVALUE FROM dbo.STORERCONFIG (NOLOCK)
      WHERE Storerkey = @c_PPStorerkey
      AND CONFIGKEY = 'PREPACKBYBOM'
   END
   ELSE
   BEGIN
      SELECT @c_PrePackByBOM = SVALUE FROM dbo.STORERCONFIG (NOLOCK)
      WHERE Storerkey = @c_StorerKey
      AND CONFIGKEY = 'PREPACKBYBOM'
   END

   IF @b_MultiProductID = 1
   BEGIN
      IF ISNULL(@c_PrePackByBOM,'') = '1'
      BEGIN
         SET @f_TotalCube              = 0
         SET @f_TotalGROSSWGT          = 0
         SET @f_PPalletTotStdCube      = 0 -- SOS# 209838
         SET @f_PPPalletTotStdGrossWgt = 0 -- SOS# 209838

         DECLARE CUR_CUBIC CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT DISTINCT
               LA.Lottable03, ISNULL( SUM( LLI.QTY), 0)
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
               JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = LLI.LOT)
               JOIN dbo.SKU WITH (NOLOCK) ON (SKU.StorerKey = LA.StorerKey AND SKU.SKU = LA.Lottable03)
            WHERE LLI.ID = @c_ID
               AND LLI.StorerKey = @c_PPStorerKey
               AND LLI.QTY > 0
            GROUP BY LA.Lottable03

         OPEN CUR_CUBIC
         FETCH NEXT FROM CUR_CUBIC INTO @c_BOMSKU , @n_LOQTY --, @f_STDCUBE , @f_Length, @f_Width, @f_Height (ChewKP03)

         WHILE @@FETCH_STATUS <> -1
         BEGIN
            SELECT @c_Packkey = PACKKEY,
                   @f_STDCUBE = SKU.STDCUBE, --(ChewKP03)
                   @f_Length  = SKU.Length,  --(ChewKP03)
                   @f_Width   = SKU.Width,   --(ChewKP03)
                   @f_Height  = SKU.Height   --(ChewKP03)
            FROM   SKU WITH (NOLOCK)
            WHERE  SKU = @c_BOMSKU
            AND    STORERKEY = @c_PPStorerkey

            IF ISNULL(@c_Packkey,'') = ''
            BEGIN
               SET @n_Err = 72891
               SET @c_ErrMsg = 'Invalid Packkey'
               EXEC nsp_logerror @n_Err, @c_ErrMsg, 'nspRDTPASTD'
               --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
               RAISERROR (@n_Err, 10, 1) WITH SETERROR -- SOS# 209838
               GOTO LOCATION_DONE
            END

            SELECT @n_CaseCnt = CaseCnt FROM PACK WITH (NOLOCK)
            WHERE PACKKEY = @c_Packkey

            IF ISNULL(@n_CaseCnt,0) = 0
            BEGIN
               SET @n_Err = 72892
               SET @c_ErrMsg = 'Invalid CaseCnt'
               EXEC nsp_logerror @n_Err, @c_ErrMsg, 'nspRDTPASTD'
               --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
               RAISERROR (@n_Err, 10, 1) WITH SETERROR -- SOS# 209838
               GOTO LOCATION_DONE
            END

            SELECT @n_TotalBOMQTY = SUM(QTY)  FROM BILLOFMATERIAL WITH (NOLOCK)
            WHERE SKU = @c_BOMSKU
            AND STORERKEY = @c_PPStorerkey

            IF ISNULL(@n_TotalBOMQTY,0) = 0
            BEGIN
               SET @n_Err = 72893
               SET @c_ErrMsg = 'Invalid BOM Qty'
               EXEC nsp_logerror @n_Err, @c_ErrMsg, 'nspRDTPASTD'
               --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
               RAISERROR (@n_Err, 10, 1) WITH SETERROR -- SOS# 209838
               GOTO LOCATION_DONE
            END

            IF ISNULL(@f_STDCUBE , 0) > 0
            BEGIN
               SET @f_TotalCube = @f_TotalCube + (
                                  ( (@n_LOQTY/@n_TotalBOMQTY) -- Component SKU Qty
                                    / @n_CaseCnt)
                                    * @f_STDCUBE)  --(ChewKP03)

               --SET @f_TotalCube = @f_TotalCube + ((@n_LOQTY / (@n_TotalBOMQTY * @n_CaseCnt)) * @f_STDCUBE)
               SET @f_TotalGROSSWGT  =  @f_STDGROSSWGT * @n_CaseCnt
            END
            ELSE
            BEGIN
               SET @f_CSTDCUBE = ISNULL(@f_Length,0) * ISNULL(@f_Width,0) *  ISNULL(@f_Height,0)
               --SET @f_TotalCube = @f_TotalCube + ((@n_LOQTY / (@n_TotalBOMQTY * @n_CaseCnt)) * @f_CSTDCUBE)
               SET @f_TotalCube = @f_TotalCube + (
                                  ( (@n_LOQTY/@n_TotalBOMQTY) -- Component SKU Qty
                                  / @n_CaseCnt)
                                  * @f_CSTDCUBE) --(ChewKP03)

               SET @f_TotalGROSSWGT = @f_STDGROSSWGT * @n_CaseCnt
            END
            FETCH NEXT FROM CUR_CUBIC INTO @c_BOMSKU , @n_LOQTY
         END
         CLOSE CUR_CUBIC --(ChewKP03)
         DEALLOCATE CUR_CUBIC  --(ChewKP03)

      SET @f_PPalletTotStdCube      = ISNULL(@f_TotalCube,0)     -- SOS# 209838
      SET @f_PPPalletTotStdGrossWgt = ISNULL(@f_TotalGROSSWGT,0) -- SOS# 209838
      END
   END
   ELSE
   BEGIN
      IF ISNULL(@c_PrePackByBOM,'') = '1'
      BEGIN
         SET @f_TotalCube              = 0
         SET @f_TotalGROSSWGT          = 0
         SET @f_PPalletTotStdCube      = 0 -- SOS# 209838
         SET @f_PPPalletTotStdGrossWgt = 0 -- SOS# 209838

         DECLARE CUR_CUBIC CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT DISTINCT
               LA.Lottable03, ISNULL( SUM( LLI.QTY), 0)
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
               JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = LLI.LOT)
               JOIN dbo.SKU WITH (NOLOCK) ON (SKU.StorerKey = LA.StorerKey AND SKU.SKU = LA.Lottable03)
            WHERE LLI.ID = @c_ID
               AND LLI.StorerKey = @c_StorerKey
               AND LLI.QTY > 0
            GROUP BY LA.Lottable03

         OPEN CUR_CUBIC
         FETCH NEXT FROM CUR_CUBIC INTO @c_BOMSKU , @n_LOQTY --, @f_STDCUBE , @f_Length, @f_Width, @f_Height --(ChewKP03)

         WHILE @@FETCH_STATUS <> -1
         BEGIN
            SELECT @c_Packkey = PACKKEY,
                   @f_STDCUBE = SKU.STDCUBE, --(ChewKP03)
                   @f_Length  = SKU.Length,  --(ChewKP03)
                   @f_Width   = SKU.Width,   --(ChewKP03)
                   @f_Height  = SKU.Height   --(ChewKP03)
            FROM   SKU WITH (NOLOCK)
            WHERE  SKU = @c_BOMSKU
            AND    STORERKEY = @c_StorerKey

            IF ISNULL(@c_Packkey,'') = ''
            BEGIN
               SET @n_Err = 72894
               SET @c_ErrMsg = 'Invalid Packkey'
               EXEC nsp_logerror @n_Err, @c_ErrMsg, 'nspRDTPASTD'
               --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
               RAISERROR (@n_Err, 10, 1) WITH SETERROR -- SOS# 209838
               GOTO LOCATION_DONE
            END

            SELECT @n_CaseCnt = CaseCnt FROM PACK WITH (NOLOCK)
            WHERE PACKKEY = @c_Packkey

            IF ISNULL(@n_CaseCnt,0) = 0
            BEGIN
               SET @n_Err = 72895
               SET @c_ErrMsg = 'Invalid CaseCnt'
               EXEC nsp_logerror @n_Err, @c_ErrMsg, 'nspRDTPASTD'
               --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
               RAISERROR (@n_Err, 10, 1) WITH SETERROR -- SOS# 209838
               GOTO LOCATION_DONE
            END

            SELECT @n_TotalBOMQTY = SUM(QTY)  FROM BILLOFMATERIAL WITH (NOLOCK)
            WHERE SKU = @c_BOMSKU
            AND STORERKEY = @c_StorerKey

            IF ISNULL(@n_TotalBOMQTY,0) = 0
            BEGIN
               SET @n_Err = 72896
               SET @c_ErrMsg = 'Invalid BOM Qty'
               EXEC nsp_logerror @n_Err, @c_ErrMsg, 'nspRDTPASTD'
               --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
               RAISERROR (@n_Err, 10, 1) WITH SETERROR -- SOS# 209838
               GOTO LOCATION_DONE
            END

            IF ISNULL(@f_STDCUBE , 0) > 0
            BEGIN
               SET @f_TotalCube = @f_TotalCube + (
                                  ( (@n_LOQTY/@n_TotalBOMQTY) -- Component SKU Qty
                                  / @n_CaseCnt)
                                  * @f_STDCUBE)   --(ChewKP03)

               SET @f_TotalGROSSWGT  =  @f_STDGROSSWGT * @n_CaseCnt
            END
            ELSE
            BEGIN
               SET @f_CSTDCUBE = ISNULL(@f_Length,0) * ISNULL(@f_Width,0) *  ISNULL(@f_Height,0)
               SET @f_TotalCube = @f_TotalCube + (
                                  ( (@n_LOQTY/@n_TotalBOMQTY) -- Component SKU Qty
                                  / @n_CaseCnt)
                                  * @f_CSTDCUBE) --(ChewKP03)

               SET @f_TotalGROSSWGT = @f_STDGROSSWGT * @n_CaseCnt
            END
            FETCH NEXT FROM CUR_CUBIC INTO @c_BOMSKU , @n_LOQTY
         END
         CLOSE CUR_CUBIC --(ChewKP03)
         DEALLOCATE CUR_CUBIC --(ChewKP03)

         SET @f_PPalletTotStdCube      = ISNULL(@f_TotalCube,0)     -- SOS# 209838
         SET @f_PPPalletTotStdGrossWgt = ISNULL(@f_TotalGROSSWGT,0) -- SOS# 209838
      END
   END
   /* -- CALCULATE BY BOMSKU End (ChewKP02)--*/

   IF ISNULL(RTRIM(@c_SKU), '') <> '' AND ISNULL(RTRIM(@c_StorerKey), '') <> ''
   BEGIN
      EXEC nspGetPack
            @c_StorerKey,
            @c_SKU,
            @c_LOT,
            @c_FromLoc,
            @c_ID,
            @c_PackKey OUTPUT,
            @b_Success OUTPUT,
            @n_Err     OUTPUT,
            @c_ErrMsg  OUTPUT

      SELECT @c_SKU_ABC = ABC FROM dbo.SKU WITH (NOLOCK) WHERE StorerKey = @c_StorerKey AND SKU = @c_SKU
      SELECT @c_Style = Style FROM SKU WITH (NOLOCK) WHERE StorerKey = @c_StorerKey AND SKU = @c_SKU
   END

   IF @b_Success = 0
   BEGIN
      SET @c_ToLoc = ''
      GOTO Location_Error
   END

   -- Get putaway strategy key
   IF @c_PAStrategyKey <> ''
      SET @c_PutawayStrategyKey =  @c_PAStrategyKey
   ELSE
   BEGIN
      IF @b_MultiProductID = 0
      BEGIN
         SELECT @c_PutawayStrategyKey = STRATEGY.PutAwayStrategyKey,
                @n_StdGrossWgt = SKU.StdGrossWgt
         FROM   STRATEGY WITH (NOLOCK)
         JOIN   SKU WITH (NOLOCK)
           ON   SKU.STRATEGYKEY = STRATEGY.Strategykey
         WHERE  SKU.StorerKey = @c_StorerKey AND
                SKU.SKU = @c_SKU
      END
      ELSE
      BEGIN
         SELECT TOP 1
               @c_PutawayStrategyKey = STRATEGY.PutAwayStrategyKey,
               @n_StdGrossWgt = 0
         FROM  STRATEGY WITH (NOLOCK)
         JOIN  SKU WITH (NOLOCK) ON  SKU.STRATEGYKEY = STRATEGY.Strategykey
         JOIN  LOTxLOCxID LLI WITH (NOLOCK) ON LLI.StorerKey = sku.StorerKey AND LLI.Sku = SKU.Sku
         WHERE LLI.Loc = @c_FromLoc AND
               LLI.Id = @c_ID AND
               LLI.Qty > 0
         ORDER BY LLI.Qty DESC
      END
   END

   IF ISNULL(RTRIM(@c_ID),'') <> '' AND @n_Qty = 0
   BEGIN
      SELECT @n_Qty = ISNULL( SUM(Qty), 0)
      FROM   LOTxLOCxID WITH (NOLOCK) --(james)
      WHERE  ID = @c_ID
   END

   IF ISNULL(RTRIM(@c_StorerKey),'') = ''
   BEGIN
      --SELECT * FROM @t_SKUList --(james)
      SELECT TOP 1 @c_StorerKey = StorerKey
      FROM   @t_SKUList t
   END

   --SET @b_Debug = 2
   SELECT @b_Debug = CONVERT(INT, NSQLValue)
   FROM   NSQLCONFIG WITH (NOLOCK)
   WHERE  ConfigKey = 'PutawayTraceReport'

   IF @c_userid='TEST'
   BEGIN
      SET @b_Debug = 2
      PRINT '---- Debug On ----'
      PRINT ' Putaway StrategyKey : ' + @c_PutawayStrategyKey
      PRINT ' Facility: ' + @c_Facility 
   END
   
   IF @c_userid='TEST1'
   BEGIN
      SET @b_Debug = 1
      PRINT '---- Trace On ----'
      PRINT ' Putaway StrategyKey : ' + @c_PutawayStrategyKey
      PRINT ' Facility: ' + @c_Facility 
   END

   IF @b_Debug IS NULL
   BEGIN
      SELECT @b_Debug = 0
   END

   IF @b_Debug = 1
   BEGIN
      -- insert records into PTRACEHEAD table
      EXEC nspPTH @c_PTraceType,
                  @c_userid,
                  @c_StorerKey,
                  @c_SKU,
                  @c_LOT,
                  @c_ID,
                  @c_PackKey,
                  @n_Qty,
                  @b_MultiProductID,
                  @b_MultiLotID,
                  @d_StartDTim,
                  NULL,
                  0,
                  NULL,
                  @n_pTraceHeadKey OUTPUT
   END

   DECLARE @c_PutawayStrategyLineNumber    NVARCHAR(5),
           @b_RestrictionsPassed   INT,
           @b_GotLoc    INT,
           @cpa_PAType                     NVARCHAR(5),
           @cpa_FromLoc                    NVARCHAR(10),
           @cpa_ToLoc                      NVARCHAR(10),
           @cpa_AreaKey                    NVARCHAR(10),
           @cpa_Zone                       NVARCHAR(10),
           @cpa_LocType                    NVARCHAR(10),
           @cpa_LocSearchType              NVARCHAR(10),
           @cpa_DimensionRestriction01     NVARCHAR(5),
           @cpa_DimensionRestriction02     NVARCHAR(5),
           @cpa_DimensionRestriction03     NVARCHAR(5),
           @cpa_DimensionRestriction04     NVARCHAR(5),
           @cpa_DimensionRestriction05     NVARCHAR(5),
           @cpa_DimensionRestriction06     NVARCHAR(5),
           @cpa_LocationTypeExclude01      NVARCHAR(10),
           @cpa_LocationTypeExclude02      NVARCHAR(10),
           @cpa_LocationTypeExclude03      NVARCHAR(10),
           @cpa_LocationTypeExclude04      NVARCHAR(10),
           @cpa_LocationTypeExclude05      NVARCHAR(10),
           @cpa_LocationFlagExclude01      NVARCHAR(10),
           @cpa_LocationFlagExclude02      NVARCHAR(10),
           @cpa_LocationFlagExclude03      NVARCHAR(10),
           @cpa_LocationCategoryExclude01  NVARCHAR(10),
           @cpa_LocationCategoryExclude02  NVARCHAR(10),
           @cpa_LocationCategoryExclude03  NVARCHAR(10),
           @cpa_LocationHandlingExclude01  NVARCHAR(10),
           @cpa_LocationHandlingExclude02  NVARCHAR(10),
           @cpa_LocationHandlingExclude03  NVARCHAR(10),
           @cpa_LocationFlagInclude01      NVARCHAR(10),
           @cpa_LocationFlagInclude02      NVARCHAR(10),
           @cpa_LocationFlagInclude03      NVARCHAR(10),
           @cpa_LocationCategoryInclude01  NVARCHAR(10),
           @cpa_LocationCategoryInclude02  NVARCHAR(10),
           @cpa_LocationCategoryInclude03  NVARCHAR(10),
           @cpa_LocationHandlingInclude01  NVARCHAR(10),
           @cpa_LocationHandlingInclude02  NVARCHAR(10),
           @cpa_LocationHandlingInclude03  NVARCHAR(10),
           @cpa_AreaTypeExclude01          NVARCHAR(10),
           @cpa_AreaTypeExclude02          NVARCHAR(10),
           @cpa_AreaTypeExclude03          NVARCHAR(10),
           @cpa_LocationTypeRestriction01  NVARCHAR(10),
           @cpa_LocationTypeRestriction02  NVARCHAR(10),
           @cpa_LocationTypeRestriction03  NVARCHAR(10),
           @cpa_LocationTypeRestriction04  NVARCHAR(10),
           @cpa_LocationTypeRestriction05  NVARCHAR(10),
           @cpa_LocationTypeRestriction06  NVARCHAR(10),
           @cpa_FitFullReceipt             NVARCHAR(5),
           @cpa_OrderType                  NVARCHAR(10),
           @npa_NumberofDaysOffSet         INT,
           @cpa_LocationStateRestriction1  NVARCHAR(5),
           @cpa_LocationStateRestriction2  NVARCHAR(5),
           @cpa_LocationStateRestriction3  NVARCHAR(5),
           @cpa_AllowFullPallets           NVARCHAR(5),
           @cpa_AllowFullCases             NVARCHAR(5),
           @cpa_AllowPieces                NVARCHAR(5),
           @cpa_CheckEquipmentProfileKey   NVARCHAR(5),
           @cpa_CheckRestrictions          NVARCHAR(5),
           @cpa_PutCode                    NVARCHAR(30),  --(ung06)
           @cpa_PutCodeSQL                 NVARCHAR(1000), --(ung06)
           @npa_TotalCube                  FLOAT,
           @npa_TotalWeight                FLOAT
           

   DECLARE @c_Loc_Type                     NVARCHAR(10),
           @c_loc_zone                     NVARCHAR(10),
           @c_loc_category                 NVARCHAR(10),
           @c_loc_flag                     NVARCHAR(10),
           @c_loc_handling                 NVARCHAR(10),
           @n_Loc_Width                    FLOAT,
           @n_Loc_Length                   FLOAT,
           @n_Loc_Height                   FLOAT,
           @n_Loc_CubicCapacity            FLOAT,
           @n_Loc_WeightCapacity           FLOAT,
           @c_movableunittype              NVARCHAR(10), -- 1=pallet,2=case,3=innerpack,4=other1,5=other2,6=piece
           @c_Loc_CommingleSku             NVARCHAR(1),
           @c_loc_comminglelot             NVARCHAR(1),
           @n_FromCube                     FLOAT, -- the cube of the product/id being putaway
           @n_ToCube                       FLOAT, -- the cube of existing product in the candidate location
           @n_FromWeight                   FLOAT, -- the weight of the product/id being putaway
           @n_ToWeight                     FLOAT, -- the weight of existing product in the candidate location
           @n_PalletWoodWidth              FLOAT, -- the width of the pallet wood being putaway
           @n_PalletWoodLength             FLOAT, -- the length of the pallet wood being putaway
           @n_PalletWoodHeight             FLOAT, -- the height of the pallet wood being putaway
           @n_PalletHeight                 FLOAT, -- the height of the pallet wood being putaway
           @n_CaseWidth                    FLOAT, -- the width of the cases on the  pallet being putaway
           @n_CaseLength                   FLOAT, -- the length of the cases on the  pallet being putaway
           @n_CaseHeight                   FLOAT, -- the height of the cases on the pallet being putaway
           @n_ExistingHeight               FLOAT, -- the height of any existing product in a candidate location
           @n_ExistingQuantity             integer, -- the quantity of any existing product in a candidate location
           @n_QuantityCapacity             integer, -- the quantity based on cube which could fit in candidate location
           @n_PackCaseCount                integer, -- the number of pieces in a case for the pack
           @n_UOMcapacity                  integer, -- the number of a UOM cubic capacity which fits inside a cube
           @n_PutawayTI                    integer, -- the number of cases on a pallet layer/tier
           @n_PutawayHI                    integer, -- the number of layers/tiers on a pallet
           @n_ToQty                        integer, -- Variable to hold quantity already in a location
           @n_ExistingLayers               integer, -- number of layers/tiers indicator
           @n_ExtraLayer                   integer, -- a partial layer/tier indicator
           @n_CubeUOM1                     FLOAT, -- volumetric cube of UOM1
           @n_QtyUOM1                      integer, -- number of eaches in UOM1
           @n_CubeUOM3                     FLOAT, -- volumetric cube of UOM2
           @n_QtyUOM3                      integer, -- number of eaches in UOM2
           @n_CubeUOM4                     FLOAT, -- volumetric cube of UOM4
           @n_QtyUOM4                      integer, -- number of eaches in UOM4
           @c_SearchZone                   NVARCHAR(10),
           @c_searchlogicalloc             NVARCHAR(18),
           @n_CurrLocMultiSku              INT, -- Current Location/Putaway Pallet is Commingled Sku
           @n_CurrLocMultiLot              INT    -- Current Location/Putaway Pallet is Commingled Lot

   -- For Checking Maximum Pallet
   -- Added by DLIM September 2001
   DECLARE @n_PendingPalletQty             INT,
           @n_TtlPalletQty                 INT
   -- END Add by DLIM

   -- SOS#133381 Add new restriction on Location Level And Aisle
   DECLARE @npa_LocLevelInclude01          INT,
           @npa_LocLevelInclude02          INT,
           @npa_LocLevelInclude03          INT,
           @npa_LocLevelInclude04          INT,
           @npa_LocLevelInclude05          INT,
           @npa_LocLevelInclude06          INT,
           @npa_LocLevelExclude01          INT,
           @npa_LocLevelExclude02          INT,
           @npa_LocLevelExclude03          INT,
           @npa_LocLevelExclude04          INT,
           @npa_LocLevelExclude05          INT,
           @npa_LocLevelExclude06          INT,
           @cpa_LocAisleInclude01          NVARCHAR(10),
           @cpa_LocAisleInclude02          NVARCHAR(10),
           @cpa_LocAisleInclude03          NVARCHAR(10),
           @cpa_LocAisleInclude04          NVARCHAR(10),
           @cpa_LocAisleInclude05          NVARCHAR(10),
           @cpa_LocAisleInclude06          NVARCHAR(10),
           @cpa_LocAisleExclude01          NVARCHAR(10),
           @cpa_LocAisleExclude02          NVARCHAR(10),
           @cpa_LocAisleExclude03          NVARCHAR(10),
           @cpa_LocAisleExclude04          NVARCHAR(10),
           @cpa_LocAisleExclude05          NVARCHAR(10),
           @cpa_LocAisleExclude06          NVARCHAR(10)

   DECLARE @n_loc_level                    INT,
           @c_loc_aisle                    NVARCHAR(10),
           @c_loc_ABC                      NVARCHAR(5),
           @c_LOC_HostWHCode               NVARCHAR(10) = '', --(SHONG01)
           @c_loc_NoMixLottable01          NVARCHAR(1),
           @c_loc_NoMixLottable02          NVARCHAR(1),
           @c_loc_NoMixLottable03          NVARCHAR(1),
           @c_loc_NoMixLottable04          NVARCHAR(1),
           @c_loc_NoMixLottable06          NVARCHAR(1), -- (ChewKP09)
           @c_loc_NoMixLottable07          NVARCHAR(1), -- (ChewKP09)
           @c_loc_NoMixLottable08          NVARCHAR(1), -- (ChewKP09)
           @c_loc_NoMixLottable09          NVARCHAR(1), -- (ChewKP09)
           @c_loc_NoMixLottable10          NVARCHAR(1), -- (ChewKP09)
           @c_loc_NoMixLottable11          NVARCHAR(1), -- (ChewKP09)
           @c_loc_NoMixLottable12          NVARCHAR(1), -- (ChewKP09)
           @c_loc_NoMixLottable13          NVARCHAR(1), -- (ChewKP09)
           @c_loc_NoMixLottable14          NVARCHAR(1), -- (ChewKP09)
           @c_loc_NoMixLottable15          NVARCHAR(1), -- (ChewKP09)
           @n_loc_MaxSKU                   INT,
           @n_loc_MaxQTY                   INT,
           @n_loc_MaxCarton                INT

   DECLARE @c_SQL_LocationTypeExclude      NVARCHAR(1000) = N'',
           @c_SQL_LocationCategoryInclude  NVARCHAR(1000) = N'',
           @c_SQL_LocationCategoryExclude  NVARCHAR(1000) = N'',
           @c_SQL_LocationHandlingInclude  NVARCHAR(1000) = N'',
           @c_SQL_LocationHandlingExclude  NVARCHAR(1000) = N'',
           @c_SQL_LocationFlagInclude      NVARCHAR(1000) = N'',
           @c_SQL_LocationFlagExclude      NVARCHAR(1000) = N'',
           @c_SQL_LocLevelInclude          NVARCHAR(1000) = N'',
           @c_SQL_LocLevelExclude          NVARCHAR(1000) = N'',
           @c_SQL_LocAisleInclude          NVARCHAR(1000) = N'',
           @c_SQL_LocAisleExclude          NVARCHAR(1000) = N'', 
           @c_SQL_LocTypeRestriction       NVARCHAR(1000) = N'',
           @c_SQL_LocStateRestriction      NVARCHAR(1000) = N''
           
   
   SELECT @c_PutawayStrategyLineNumber = SPACE(5),
          @b_GotLoc = 0

   WHILE (1=1)
   BEGIN
      SET @n_PrevPutLineNum = CAST(@c_PutawayStrategyLineNumber AS INT) -- (Vicky03)

      SELECT TOP 1 @c_PutawayStrategyLineNumber = putawaystrategylinenumber,
             @cpa_PAType = PAType,
             @cpa_FromLoc = FROMLOC,
             @cpa_ToLoc = ISNULL(TOLOC,''),
             @cpa_AreaKey = AreaKey,
             @cpa_Zone = Zone,
             @cpa_LocType = LocType,
             @cpa_LocSearchType = LocSearchType,
             @cpa_DimensionRestriction01 = DimensionRestriction01,
             @cpa_DimensionRestriction02 = DimensionRestriction02,
             @cpa_DimensionRestriction03 = DimensionRestriction03,
             @cpa_DimensionRestriction04 = DimensionRestriction04,
             @cpa_DimensionRestriction05 = DimensionRestriction05,
             @cpa_DimensionRestriction06 = DimensionRestriction06,
             @cpa_LocationTypeExclude01 = LocationTypeExclude01,
             @cpa_LocationTypeExclude02 = LocationTypeExclude02,
             @cpa_LocationTypeExclude03 = LocationTypeExclude03,
             @cpa_LocationTypeExclude04 = LocationTypeExclude04,
             @cpa_LocationTypeExclude05 = LocationTypeExclude05,
             @cpa_LocationCategoryExclude01 = LocationCategoryExclude01,
             @cpa_LocationCategoryExclude02 = LocationCategoryExclude02,
             @cpa_LocationCategoryExclude03 = LocationCategoryExclude03,
             @cpa_LocationHandlingExclude01 = LocationHandlingExclude01,
             @cpa_LocationHandlingExclude02 = LocationHandlingExclude02,
             @cpa_LocationHandlingExclude03 = LocationHandlingExclude03,
             @cpa_LocationFlagInclude01 = LocationFlagInclude01,
             @cpa_LocationFlagInclude02 = LocationFlagInclude02,
             @cpa_LocationFlagInclude03 = LocationFlagInclude03,
             @cpa_LocationFlagExclude01 = LocationFlagExclude01,
             @cpa_LocationFlagExclude02 = LocationFlagExclude02,
             @cpa_LocationFlagExclude03 = LocationFlagExclude03,             
             @cpa_LocationCategoryInclude01 = LocationCategoryInclude01,
             @cpa_LocationCategoryInclude02 = LocationCategoryInclude02,
             @cpa_LocationCategoryInclude03 = LocationCategoryInclude03,
             @cpa_LocationHandlingInclude01 = LocationHandlingInclude01,
             @cpa_LocationHandlingInclude02 = LocationHandlingInclude02,
             @cpa_LocationHandlingInclude03 = LocationHandlingInclude03,
             @cpa_AreaTypeExclude01 = AreaTypeExclude01,
             @cpa_AreaTypeExclude02 = AreaTypeExclude02,
             @cpa_AreaTypeExclude03 = AreaTypeExclude03,
             @cpa_LocationTypeRestriction01 = LocationTypeRestriction01,
             @cpa_LocationTypeRestriction02 = LocationTypeRestriction02,
             @cpa_LocationTypeRestriction03 = LocationTypeRestriction03,
             @cpa_FitFullReceipt = FitFullReceipt,
             @cpa_OrderType = OrderType,
             @npa_NumberofDaysOffSet = NumberofDaysOffSet,
             @cpa_LocationStateRestriction1 = LocationStateRestriction01,
             @cpa_LocationStateRestriction2 = LocationStateRestriction02,
             @cpa_LocationStateRestriction3 = LocationStateRestriction03,
             @cpa_AllowFullPallets = AllowFullPallets,
             @cpa_AllowFullCases = AllowFullCases,
             @cpa_AllowPieces = AllowPieces,
             @cpa_CheckEquipmentProfileKey = CheckEquipmentProfileKey,
             @cpa_CheckRestrictions = CheckRestrictions,
             @npa_LocLevelInclude01 = LocLevelInclude01,
             @npa_LocLevelInclude02 = LocLevelInclude02,
             @npa_LocLevelInclude03 = LocLevelInclude03,
             @npa_LocLevelInclude04 = LocLevelInclude04,
             @npa_LocLevelInclude05 = LocLevelInclude05,
             @npa_LocLevelInclude06 = LocLevelInclude06,
             @npa_LocLevelExclude01 = LocLevelExclude01,
             @npa_LocLevelExclude02 = LocLevelExclude02,
             @npa_LocLevelExclude03 = LocLevelExclude03,
             @npa_LocLevelExclude04 = LocLevelExclude04,
             @npa_LocLevelExclude05 = LocLevelExclude05,
             @npa_LocLevelExclude06 = LocLevelExclude06,
             @cpa_LocAisleInclude01 = LocAisleInclude01,
             @cpa_LocAisleInclude02 = LocAisleInclude02,
             @cpa_LocAisleInclude03 = LocAisleInclude03,
             @cpa_LocAisleInclude04 = LocAisleInclude04,
             @cpa_LocAisleInclude05 = LocAisleInclude05,
             @cpa_LocAisleInclude06 = LocAisleInclude06,
             @cpa_LocAisleExclude01 = LocAisleExclude01,
             @cpa_LocAisleExclude02 = LocAisleExclude02,
             @cpa_LocAisleExclude03 = LocAisleExclude03,
             @cpa_LocAisleExclude04 = LocAisleExclude04,
             @cpa_LocAisleExclude05 = LocAisleExclude05,
             @cpa_LocAisleExclude06 = LocAisleExclude06,
             @cpa_PutawayZone01     = PutawayZone01,
             @cpa_PutawayZone02     = PutawayZone02,
             @cpa_PutawayZone03     = PutawayZone03,
             @cpa_PutawayZone04     = PutawayZone04,
             @cpa_PutawayZone05     = PutawayZone05,
             @cpa_PutawayZoneExt    = '',
             @cpa_PutCode           = PutCode, --(ung06)
             @cpa_PutCodeSQL        = ''       --(ung06)
       FROM  PUTAWAYSTRATEGYDETAIL WITH (NOLOCK)
       WHERE PutAwayStrategyKey = @c_PutawayStrategyKey AND
             putawaystrategylinenumber>@c_PutawayStrategyLineNumber
       ORDER BY putawaystrategylinenumber

      IF @@ROWCOUNT = 0
      BEGIN
         BREAK
      END

      -- Construct MultiPutawayZone SQL for later use (ChewKP08)
      SET @nPutawayZoneCount = 0
      SET @c_MultiPutawayZone = ''
      SET @c_SearchZone = ''
      
      TRUNCATE TABLE #t_PutawayZone
      
      IF ISNULL(RTRIM(@cpa_PutawayZone01),'' )  <> ''
         INSERT INTO #t_PutawayZone(PutawayZone) VALUES (@cpa_PutawayZone01)
         
      IF ISNULL(RTRIM(@cpa_PutawayZone02),'' )  <> '' 
         INSERT INTO #t_PutawayZone(PutawayZone) VALUES (@cpa_PutawayZone02)
 
      IF ISNULL(RTRIM(@cpa_PutawayZone03),'' )  <> '' 
         INSERT INTO #t_PutawayZone(PutawayZone) VALUES (@cpa_PutawayZone03)

      IF ISNULL(RTRIM(@cpa_PutawayZone04),'' )  <> '' 
         INSERT INTO #t_PutawayZone(PutawayZone) VALUES (@cpa_PutawayZone04)

      IF ISNULL(RTRIM(@cpa_PutawayZone05),'' )  <> ''
         INSERT INTO #t_PutawayZone(PutawayZone) VALUES (@cpa_PutawayZone05)

      IF CAST(@c_PutawayStrategyLineNumber as INT) > @n_PrevPutLineNum
      BEGIN
         SET @c_StartAisle = ''
      END

      SET @c_SQLParms = N'@c_StorerKey NVARCHAR(15) ' +
                        ',@c_Facility  NVARCHAR(5)  ' +
                        ',@c_SKU       NVARCHAR(20) ' +
                        ',@c_LOT       NVARCHAR(10) ' +
                        ',@c_FromLoc   NVARCHAR(10) ' +
                        ',@c_ID        NVARCHAR(18) ' +
                        ',@n_Qty       INT      ' +
                        ',@n_StdGrossWgt FLOAT(8) ' + 
                        ',@cpa_LocationTypeExclude01  NVARCHAR(10) = ''''' +
                        ',@cpa_LocationTypeExclude02  NVARCHAR(10) = ''''' +
                        ',@cpa_LocationTypeExclude03  NVARCHAR(10) = ''''' +
                        ',@cpa_LocationTypeExclude04  NVARCHAR(10) = ''''' +
                        ',@cpa_LocationTypeExclude05  NVARCHAR(10) = ''''' +
                        ',@cpa_LocationCategoryExclude01  NVARCHAR(10)= ''''' +
                        ',@cpa_LocationCategoryExclude02  NVARCHAR(10)= ''''' +
                        ',@cpa_LocationCategoryExclude03  NVARCHAR(10)= ''''' +
                        ',@cpa_LocationCategoryInclude01  NVARCHAR(10)= ''''' +
                        ',@cpa_LocationCategoryInclude02  NVARCHAR(10)= ''''' +
                        ',@cpa_LocationCategoryInclude03  NVARCHAR(10)= ''''' +
                        ',@cpa_LocationHandlingInclude01  NVARCHAR(10)= ''''' +
                        ',@cpa_LocationHandlingInclude02  NVARCHAR(10)= ''''' +
                        ',@cpa_LocationHandlingInclude03  NVARCHAR(10)= ''''' +
                        ',@cpa_LocationHandlingExclude01  NVARCHAR(10) = ''''' +
                        ',@cpa_LocationHandlingExclude02  NVARCHAR(10) = ''''' +
                        ',@cpa_LocationHandlingExclude03  NVARCHAR(10) = ''''' +
                        ',@cpa_LocationFlagInclude01     NVARCHAR(10) = ''''' +
                        ',@cpa_LocationFlagInclude02     NVARCHAR(10) = ''''' +
                        ',@cpa_LocationFlagInclude03     NVARCHAR(10) = ''''' +
                        ',@cpa_LocationFlagExclude01     NVARCHAR(10) = ''''' +
                        ',@cpa_LocationFlagExclude02     NVARCHAR(10) = ''''' +
                        ',@cpa_LocationFlagExclude03     NVARCHAR(10) = ''''' +
                        ',@npa_LocLevelInclude01   INT = 0' +
                        ',@npa_LocLevelInclude02   INT = 0' +
                        ',@npa_LocLevelInclude03   INT = 0' +
                        ',@npa_LocLevelInclude04   INT = 0' +
                        ',@npa_LocLevelInclude05   INT = 0' +
                        ',@npa_LocLevelInclude06   INT = 0' +
                        ',@npa_LocLevelExclude01   INT = 0' +
                        ',@npa_LocLevelExclude02   INT = 0' +
                        ',@npa_LocLevelExclude03   INT = 0' +
                        ',@npa_LocLevelExclude04   INT = 0' +
                        ',@npa_LocLevelExclude05   INT = 0' +
                        ',@npa_LocLevelExclude06   INT = 0' +
                        ',@cpa_LocAisleInclude01  NVARCHAR(10) = ''''' +
                        ',@cpa_LocAisleInclude02  NVARCHAR(10) = ''''' +
                        ',@cpa_LocAisleInclude03  NVARCHAR(10) = ''''' +
                        ',@cpa_LocAisleInclude04  NVARCHAR(10) = ''''' +
                        ',@cpa_LocAisleInclude05  NVARCHAR(10) = ''''' +
                        ',@cpa_LocAisleInclude06  NVARCHAR(10) = ''''' +
                        ',@cpa_LocAisleExclude01  NVARCHAR(10) = ''''' +
                        ',@cpa_LocAisleExclude02  NVARCHAR(10) = ''''' +
                        ',@cpa_LocAisleExclude03  NVARCHAR(10) = ''''' +
                        ',@cpa_LocAisleExclude04  NVARCHAR(10) = ''''' +
                        ',@cpa_LocAisleExclude05  NVARCHAR(10) = ''''' +
                        ',@cpa_LocAisleExclude06  NVARCHAR(10) = ''''' +
                        ',@npa_TotalCube          FLOAT = 0 '+
                        ',@npa_TotalWeight        FLOAT = 0 ' + 
                        ',@cpa_LocationTypeRestriction01 NVARCHAR(10) = ''''' +
                        ',@cpa_LocationTypeRestriction02 NVARCHAR(10) = ''''' +
                        ',@cpa_LocationTypeRestriction03 NVARCHAR(10) = ''''' 
                         
      SELECT @c_SQL_LocationTypeExclude      = ''      
            , @c_SQL_LocationCategoryInclude = '' 
            , @c_SQL_LocationCategoryExclude = '' 
            , @c_SQL_LocationHandlingInclude = '' 
            , @c_SQL_LocationHandlingExclude = '' 
            , @c_SQL_LocationFlagInclude     = '' 
            , @c_SQL_LocationFlagExclude     = '' 
            , @c_SQL_LocLevelInclude         = '' 
            , @c_SQL_LocLevelExclude         = '' 
            , @c_SQL_LocAisleInclude         = '' 
            , @c_SQL_LocAisleExclude         = ''   
            , @c_SQL_LocTypeRestriction      = ''          

      SET @c_SQL_LocationTypeExclude  = [dbo].[fnc_BuildVariableString](@cpa_LocationTypeExclude01, '@cpa_LocationTypeExclude01', @c_SQL_LocationTypeExclude)
      SET @c_SQL_LocationTypeExclude  = [dbo].[fnc_BuildVariableString](@cpa_LocationTypeExclude02, '@cpa_LocationTypeExclude02', @c_SQL_LocationTypeExclude)
      SET @c_SQL_LocationTypeExclude  = [dbo].[fnc_BuildVariableString](@cpa_LocationTypeExclude03, '@cpa_LocationTypeExclude03', @c_SQL_LocationTypeExclude)
      SET @c_SQL_LocationTypeExclude  = [dbo].[fnc_BuildVariableString](@cpa_LocationTypeExclude04, '@cpa_LocationTypeExclude04', @c_SQL_LocationTypeExclude)
      SET @c_SQL_LocationTypeExclude  = [dbo].[fnc_BuildVariableString](@cpa_LocationTypeExclude05, '@cpa_LocationTypeExclude05', @c_SQL_LocationTypeExclude)
      IF ISNULL(RTRIM(@c_SQL_LocationTypeExclude),'') <> ''
      BEGIN
         IF CHARINDEX(',', @c_SQL_LocationTypeExclude) > 0 
         BEGIN
            SET @c_SQL_LocationTypeExclude  = ' AND LOC.LocationType NOT IN ('+ @c_SQL_LocationTypeExclude + ') '
         END
         ELSE 
         BEGIN
            SET @c_SQL_LocationTypeExclude  = ' AND LOC.LocationType <> ' + @c_SQL_LocationTypeExclude 
         END         
      END
      
      SET @c_SQL_LocationCategoryExclude = [dbo].[fnc_BuildVariableString](@cpa_LocationCategoryExclude01, '@cpa_LocationCategoryExclude01', @c_SQL_LocationCategoryExclude)
      SET @c_SQL_LocationCategoryExclude = [dbo].[fnc_BuildVariableString](@cpa_LocationCategoryExclude02, '@cpa_LocationCategoryExclude02', @c_SQL_LocationCategoryExclude)
      SET @c_SQL_LocationCategoryExclude = [dbo].[fnc_BuildVariableString](@cpa_LocationCategoryExclude03, '@cpa_LocationCategoryExclude03', @c_SQL_LocationCategoryExclude)
      IF ISNULL(RTRIM(@c_SQL_LocationCategoryExclude),'') <> ''
      BEGIN
         IF CHARINDEX(',', @c_SQL_LocationCategoryExclude) > 0 
         BEGIN
            SET @c_SQL_LocationCategoryExclude = ' AND LOC.LocationCategory NOT IN ('+ @c_SQL_LocationCategoryExclude + ') '
         END
         ELSE 
         BEGIN
            SET @c_SQL_LocationCategoryExclude = ' AND LOC.LocationCategory <> ' + @c_SQL_LocationCategoryExclude 
         END               
      END 
      
      SET @c_SQL_LocationCategoryInclude = [dbo].[fnc_BuildVariableString](@cpa_LocationCategoryInclude01, '@cpa_LocationCategoryInclude01', @c_SQL_LocationCategoryInclude)
      SET @c_SQL_LocationCategoryInclude = [dbo].[fnc_BuildVariableString](@cpa_LocationCategoryInclude02, '@cpa_LocationCategoryInclude02', @c_SQL_LocationCategoryInclude)
      SET @c_SQL_LocationCategoryInclude = [dbo].[fnc_BuildVariableString](@cpa_LocationCategoryInclude03, '@cpa_LocationCategoryInclude03', @c_SQL_LocationCategoryInclude)
      IF ISNULL(RTRIM(@c_SQL_LocationCategoryInclude),'') <> ''
      BEGIN
         IF CHARINDEX(',', @c_SQL_LocationCategoryInclude) > 0 
         BEGIN
            SET @c_SQL_LocationCategoryInclude = ' AND LOC.LocationCategory IN ('+ @c_SQL_LocationCategoryInclude + ') '
         END
         ELSE 
         BEGIN
            SET @c_SQL_LocationCategoryInclude = ' AND LOC.LocationCategory = ' + @c_SQL_LocationCategoryInclude 
         END                 
      END
      
      SET @c_SQL_LocationHandlingInclude = [dbo].[fnc_BuildVariableString](@cpa_LocationHandlingInclude01, '@cpa_LocationHandlingInclude01', @c_SQL_LocationHandlingInclude)     
      SET @c_SQL_LocationHandlingInclude = [dbo].[fnc_BuildVariableString](@cpa_LocationHandlingInclude02, '@cpa_LocationHandlingInclude02', @c_SQL_LocationHandlingInclude)
      SET @c_SQL_LocationHandlingInclude = [dbo].[fnc_BuildVariableString](@cpa_LocationHandlingInclude03, '@cpa_LocationHandlingInclude03', @c_SQL_LocationHandlingInclude)
      IF ISNULL(RTRIM(@c_SQL_LocationHandlingInclude),'') <> ''
      BEGIN
         IF CHARINDEX(',', @c_SQL_LocationHandlingInclude) > 0 
         BEGIN
            SET @c_SQL_LocationHandlingInclude = ' AND LOC.LocationHandling IN ('+ @c_SQL_LocationHandlingInclude + ') '
         END
         ELSE 
         BEGIN
            SET @c_SQL_LocationHandlingInclude = ' AND LOC.LocationHandling = ' + @c_SQL_LocationHandlingInclude 
         END                
      END
  

      SET @c_SQL_LocationHandlingExclude = [dbo].[fnc_BuildVariableString](@cpa_LocationHandlingExclude01, '@cpa_LocationHandlingExclude01', @c_SQL_LocationHandlingExclude)     
      SET @c_SQL_LocationHandlingExclude = [dbo].[fnc_BuildVariableString](@cpa_LocationHandlingExclude02, '@cpa_LocationHandlingExclude02', @c_SQL_LocationHandlingExclude)
      SET @c_SQL_LocationHandlingExclude = [dbo].[fnc_BuildVariableString](@cpa_LocationHandlingExclude03, '@cpa_LocationHandlingExclude03', @c_SQL_LocationHandlingExclude)
      IF ISNULL(RTRIM(@c_SQL_LocationHandlingExclude),'') <> ''
      BEGIN
         IF CHARINDEX(',', @c_SQL_LocationHandlingExclude) > 0 
         BEGIN
            SET @c_SQL_LocationHandlingExclude = ' AND LOC.LocationHandling NOT IN ('+ @c_SQL_LocationHandlingExclude + ') '
         END
         ELSE 
         BEGIN
            SET @c_SQL_LocationHandlingExclude = ' AND LOC.LocationHandling <> ' + @c_SQL_LocationHandlingExclude 
         END           
      END


      SET @c_SQL_LocationFlagInclude = [dbo].[fnc_BuildVariableString](@cpa_LocationFlagInclude01, '@cpa_LocationFlagInclude01', @c_SQL_LocationFlagInclude)     
      SET @c_SQL_LocationFlagInclude = [dbo].[fnc_BuildVariableString](@cpa_LocationFlagInclude02, '@cpa_LocationFlagInclude02', @c_SQL_LocationFlagInclude)
      SET @c_SQL_LocationFlagInclude = [dbo].[fnc_BuildVariableString](@cpa_LocationFlagInclude03, '@cpa_LocationFlagInclude03', @c_SQL_LocationFlagInclude)
      IF ISNULL(RTRIM(@c_SQL_LocationFlagInclude),'') <> ''
      BEGIN
         IF CHARINDEX(',', @c_SQL_LocationFlagInclude) > 0 
         BEGIN
            SET @c_SQL_LocationFlagInclude = ' AND LOC.LocationFlag IN ('+ @c_SQL_LocationFlagInclude + ') '
         END
         ELSE 
         BEGIN
            SET @c_SQL_LocationFlagInclude = ' AND LOC.LocationFlag = ' + @c_SQL_LocationFlagInclude 
         END               
      END
      
      SET @c_SQL_LocationFlagExclude = [dbo].[fnc_BuildVariableString](@cpa_LocationFlagExclude01, '@cpa_LocationFlagExclude01', @c_SQL_LocationFlagExclude)     
      SET @c_SQL_LocationFlagExclude = [dbo].[fnc_BuildVariableString](@cpa_LocationFlagExclude02, '@cpa_LocationFlagExclude02', @c_SQL_LocationFlagExclude)
      SET @c_SQL_LocationFlagExclude = [dbo].[fnc_BuildVariableString](@cpa_LocationFlagExclude03, '@cpa_LocationFlagExclude03', @c_SQL_LocationFlagExclude)
      IF ISNULL(RTRIM(@c_SQL_LocationFlagExclude),'') <> ''
      BEGIN
         IF CHARINDEX(',', @c_SQL_LocationFlagExclude) > 0 
         BEGIN
            SET @c_SQL_LocationFlagExclude = ' AND LOC.LocationFlag NOT IN ('+ @c_SQL_LocationFlagExclude + ') '
         END
         ELSE 
         BEGIN
            SET @c_SQL_LocationFlagExclude = ' AND LOC.LocationFlag <> ' + @c_SQL_LocationFlagExclude 
         END           
      END
                                  
      SET @c_SQL_LocLevelInclude = [dbo].[fnc_BuildVariableString](@npa_LocLevelInclude01, '@npa_LocLevelInclude01', @c_SQL_LocLevelInclude)   
      SET @c_SQL_LocLevelInclude = [dbo].[fnc_BuildVariableString](@npa_LocLevelInclude02, '@npa_LocLevelInclude02', @c_SQL_LocLevelInclude)
      SET @c_SQL_LocLevelInclude = [dbo].[fnc_BuildVariableString](@npa_LocLevelInclude03, '@npa_LocLevelInclude03', @c_SQL_LocLevelInclude)
      SET @c_SQL_LocLevelInclude = [dbo].[fnc_BuildVariableString](@npa_LocLevelInclude04, '@npa_LocLevelInclude04', @c_SQL_LocLevelInclude)
      SET @c_SQL_LocLevelInclude = [dbo].[fnc_BuildVariableString](@npa_LocLevelInclude05, '@npa_LocLevelInclude05', @c_SQL_LocLevelInclude)
      SET @c_SQL_LocLevelInclude = [dbo].[fnc_BuildVariableString](@npa_LocLevelInclude06, '@npa_LocLevelInclude06', @c_SQL_LocLevelInclude)
      IF ISNULL(RTRIM(@c_SQL_LocLevelInclude),'') <> ''
      BEGIN
         IF CHARINDEX(',', @c_SQL_LocLevelInclude) > 0 
         BEGIN
            SET @c_SQL_LocLevelInclude = ' AND LOC.LocLevel IN ('+ @c_SQL_LocLevelInclude + ') '
         END
         ELSE 
         BEGIN
            SET @c_SQL_LocLevelInclude = ' AND LOC.LocLevel = ' + @c_SQL_LocLevelInclude 
         END              
      END

      SET @c_SQL_LocLevelExclude = [dbo].[fnc_BuildVariableString](@npa_LocLevelExclude01, '@npa_LocLevelExclude01', @c_SQL_LocLevelExclude)   
      SET @c_SQL_LocLevelExclude = [dbo].[fnc_BuildVariableString](@npa_LocLevelExclude02, '@npa_LocLevelExclude02', @c_SQL_LocLevelExclude)
      SET @c_SQL_LocLevelExclude = [dbo].[fnc_BuildVariableString](@npa_LocLevelExclude03, '@npa_LocLevelExclude03', @c_SQL_LocLevelExclude)
      SET @c_SQL_LocLevelExclude = [dbo].[fnc_BuildVariableString](@npa_LocLevelExclude04, '@npa_LocLevelExclude04', @c_SQL_LocLevelExclude)
      SET @c_SQL_LocLevelExclude = [dbo].[fnc_BuildVariableString](@npa_LocLevelExclude05, '@npa_LocLevelExclude05', @c_SQL_LocLevelExclude)
      SET @c_SQL_LocLevelExclude = [dbo].[fnc_BuildVariableString](@npa_LocLevelExclude06, '@npa_LocLevelExclude06', @c_SQL_LocLevelExclude)
      IF ISNULL(RTRIM(@c_SQL_LocLevelExclude),'') <> ''
      BEGIN
         IF CHARINDEX(',', @c_SQL_LocLevelExclude) > 0 
         BEGIN
            SET @c_SQL_LocLevelExclude = ' AND LOC.LocLevel NOT IN ('+ @c_SQL_LocLevelExclude + ') '
         END
         ELSE 
         BEGIN
            SET @c_SQL_LocLevelExclude = ' AND LOC.LocLevel <> ' + @c_SQL_LocLevelExclude 
         END          
      END


      SET @c_SQL_LocAisleInclude = [dbo].[fnc_BuildVariableString](@cpa_LocAisleInclude01, '@cpa_LocAisleInclude01', @c_SQL_LocAisleInclude)   
      SET @c_SQL_LocAisleInclude = [dbo].[fnc_BuildVariableString](@cpa_LocAisleInclude02, '@cpa_LocAisleInclude02', @c_SQL_LocAisleInclude)
      SET @c_SQL_LocAisleInclude = [dbo].[fnc_BuildVariableString](@cpa_LocAisleInclude03, '@cpa_LocAisleInclude03', @c_SQL_LocAisleInclude)
      SET @c_SQL_LocAisleInclude = [dbo].[fnc_BuildVariableString](@cpa_LocAisleInclude04, '@cpa_LocAisleInclude04', @c_SQL_LocAisleInclude)
      SET @c_SQL_LocAisleInclude = [dbo].[fnc_BuildVariableString](@cpa_LocAisleInclude05, '@cpa_LocAisleInclude05', @c_SQL_LocAisleInclude)
      SET @c_SQL_LocAisleInclude = [dbo].[fnc_BuildVariableString](@cpa_LocAisleInclude06, '@cpa_LocAisleInclude06', @c_SQL_LocAisleInclude)
      IF ISNULL(RTRIM(@c_SQL_LocAisleInclude),'') <> ''
      BEGIN
         IF CHARINDEX(',', @c_SQL_LocAisleInclude) > 0 
         BEGIN
            SET @c_SQL_LocAisleInclude = ' AND LOC.LocAisle IN ('+ @c_SQL_LocAisleInclude + ') '
         END
         ELSE 
         BEGIN
            SET @c_SQL_LocAisleInclude = ' AND LOC.LocAisle = ' + @c_SQL_LocAisleInclude 
         END              
      END


      SET @c_SQL_LocAisleExclude = [dbo].[fnc_BuildVariableString](@cpa_LocAisleExclude01, '@cpa_LocAisleExclude01', @c_SQL_LocAisleExclude)   
      SET @c_SQL_LocAisleExclude = [dbo].[fnc_BuildVariableString](@cpa_LocAisleExclude02, '@cpa_LocAisleExclude02', @c_SQL_LocAisleExclude)
      SET @c_SQL_LocAisleExclude = [dbo].[fnc_BuildVariableString](@cpa_LocAisleExclude03, '@cpa_LocAisleExclude03', @c_SQL_LocAisleExclude)
      SET @c_SQL_LocAisleExclude = [dbo].[fnc_BuildVariableString](@cpa_LocAisleExclude04, '@cpa_LocAisleExclude04', @c_SQL_LocAisleExclude)
      SET @c_SQL_LocAisleExclude = [dbo].[fnc_BuildVariableString](@cpa_LocAisleExclude05, '@cpa_LocAisleExclude05', @c_SQL_LocAisleExclude)
      SET @c_SQL_LocAisleExclude = [dbo].[fnc_BuildVariableString](@cpa_LocAisleExclude06, '@cpa_LocAisleExclude06', @c_SQL_LocAisleExclude)
      IF ISNULL(RTRIM(@c_SQL_LocAisleExclude),'') <> ''
      BEGIN
         IF CHARINDEX(',', @c_SQL_LocAisleExclude) > 0 
         BEGIN
            SET @c_SQL_LocAisleExclude = ' AND LOC.LocAisle NOT IN ('+ @c_SQL_LocAisleExclude + ') '
         END
         ELSE 
         BEGIN
            SET @c_SQL_LocAisleExclude = ' AND LOC.LocAisle <> ' + @c_SQL_LocAisleExclude 
         END          
      END
                           
      SET @c_SQL_LocTypeRestriction = [dbo].[fnc_BuildVariableString](@cpa_LocationTypeRestriction01, '@cpa_LocationTypeRestriction01', @c_SQL_LocTypeRestriction)     
      SET @c_SQL_LocTypeRestriction = [dbo].[fnc_BuildVariableString](@cpa_LocationTypeRestriction02, '@cpa_LocationTypeRestriction02', @c_SQL_LocTypeRestriction)
      SET @c_SQL_LocTypeRestriction = [dbo].[fnc_BuildVariableString](@cpa_LocationTypeRestriction03, '@cpa_LocationTypeRestriction03', @c_SQL_LocTypeRestriction)
      IF ISNULL(RTRIM(@c_SQL_LocTypeRestriction),'') <> ''
      BEGIN         
         IF CHARINDEX(',', @c_SQL_LocTypeRestriction) > 0 
         BEGIN
            SET @c_SQL_LocTypeRestriction = ' AND LOC.LocationType IN ('+ @c_SQL_LocTypeRestriction + ') '
         END
         ELSE 
         BEGIN
            SET @c_SQL_LocTypeRestriction = ' AND LOC.LocationType = ' + @c_SQL_LocTypeRestriction 
         END           
      END

      -- (SHONG01)
      IF ISNULL(RTRIM(@cpa_LocationStateRestriction1),'') <> ''
         INSERT INTO #t_LocStateRestriction( LocationStateRestriction ) VALUES (@cpa_LocationStateRestriction1)
      IF ISNULL(RTRIM(@cpa_LocationStateRestriction2),'') <> ''
         INSERT INTO #t_LocStateRestriction( LocationStateRestriction ) VALUES (@cpa_LocationStateRestriction2)
      IF ISNULL(RTRIM(@cpa_LocationStateRestriction3),'') <> ''
         INSERT INTO #t_LocStateRestriction( LocationStateRestriction ) VALUES (@cpa_LocationStateRestriction3)

      -- PutCode (ung06)
      IF @cpa_PutCode <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cpa_PutCode AND type = 'P')
         BEGIN
            SET @c_ToLoc = ''
            SET @cSQL = 'EXEC ' + RTRIM( @cpa_PutCode) + ' @n_pTraceHeadKey, @n_PtraceDetailKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber ' +
               ' ,@c_StorerKey' +
               ' ,@c_SKU      ' +
               ' ,@c_LOT      ' +
               ' ,@c_FromLoc  ' +
               ' ,@c_ID       ' +
               ' ,@n_Qty      ' +
               ' ,@c_ToLoc    ' +
               ' ,@c_Param1   ' +
               ' ,@c_Param2   ' +
               ' ,@c_Param3   ' +
               ' ,@c_Param4   ' +
               ' ,@c_Param5   ' +
               ' ,@b_Debug    ' +
               ' ,@c_SQL      OUTPUT' +
               ' ,@b_RestrictionsPassed OUTPUT'
            SET @cSQLParam = '@n_pTraceHeadKey NVARCHAR(10), @n_PtraceDetailKey NVARCHAR(10), @c_PutawayStrategyKey NVARCHAR(10), @c_PutawayStrategyLineNumber NVARCHAR(5) ' +
               ' ,@c_StorerKey NVARCHAR(15) ' +
               ' ,@c_SKU       NVARCHAR(20) ' +
               ' ,@c_LOT       NVARCHAR(10) ' +
               ' ,@c_FromLoc   NVARCHAR(10) ' +
               ' ,@c_ID        NVARCHAR(18) ' +
               ' ,@n_Qty       INT      ' +
               ' ,@c_ToLoc     NVARCHAR(10) ' +
               ' ,@c_Param1    NVARCHAR(20) ' +
               ' ,@c_Param2    NVARCHAR(20) ' +
               ' ,@c_Param3    NVARCHAR(20) ' +
               ' ,@c_Param4    NVARCHAR(20) ' +
               ' ,@c_Param5    NVARCHAR(20) ' +
               ' ,@b_Debug     INT      ' +
               ' ,@c_SQL       NVARCHAR(1000) OUTPUT' +
               ' ,@b_RestrictionsPassed INT  OUTPUT'
            

            EXEC sp_ExecuteSql @cSQL, @cSQLParam, @n_pTraceHeadKey, @n_PtraceDetailKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber
               ,@c_StorerKey
               ,@c_SKU
               ,@c_LOT
               ,@c_FromLoc
               ,@c_ID
               ,@n_Qty
               ,@c_ToLoc
               ,@c_Param1
               ,@c_Param2
               ,@c_Param3
               ,@c_Param4
               ,@c_Param5
               ,@b_Debug
               ,@cpa_PutCodeSQL       OUTPUT
               ,@b_RestrictionsPassed OUTPUT
               
            IF @b_Debug=2
            BEGIN
               PRINT '>> @cpa_PutCode: ' + @cpa_PutCode
               PRINT '>> @cpa_PutCodeSQL: ' + @cpa_PutCodeSQL 
            END
                         
         END
      END

      SET @c_PickAndDropLoc = '' -- (ung04)
      SET @c_FitCasesInAisle = ''

      IF @b_Debug = 1
      BEGIN
         -- Insert records into PTRACEDETAIL table
         SELECT @c_Reason = 'CHANGE of Putaway Type to '+@cpa_PAType
         EXEC nspPTD 'nspRDTPASTD',
                     @n_pTraceHeadKey,
                     @c_PutawayStrategyKey,
                     @c_PutawayStrategyLineNumber,
                     @n_PtraceDetailKey,
                     '',
                     @c_Reason
      END

      IF @b_Debug = 2
      BEGIN
         PRINT '> @c_PutawayStrategyKey: ' + @c_PutawayStrategyKey  +  ', @c_PutawayStrategyLineNumber: ' + @c_PutawayStrategyLineNumber 
         PRINT '> CHANGE of Putaway Type to '+ @cpa_PAType
      END


-----------------------------------------------------------
      IF @cpa_PAType='01' -- If Source=FROMLOCATION, Putaway to TOLOCATION
      BEGIN
         IF @c_FromLoc = @cpa_FromLoc
         BEGIN
            IF ISNULL(RTRIM(@cpa_ToLoc),'') <> ''
            BEGIN
               SELECT @c_ToLoc = @cpa_ToLoc

               IF @cpa_CheckRestrictions='Y'
               BEGIN
                  SELECT @b_RestrictionsPassed = 0
                  GOTO PA_CHECKRESTRICTIONS

                  PATYPE01:
                  IF @b_RestrictionsPassed=1
                  BEGIN
                     SELECT @b_GotLoc = 1
                     IF @b_Debug = 1
                     BEGIN
                        SELECT @c_Reason = 'FOUND PAType=01: FROM location '
                                         + RTRIM(@c_FromLoc) + ' <> ' + RTRIM(@cpa_FromLoc)
                        EXEC nspPTD 'nspRDTPASTD',
                                    @n_pTraceHeadKey,
                                    @c_PutawayStrategyKey,
                                    @c_PutawayStrategyLineNumber,
                                    @n_PtraceDetailKey,
                                    @c_ToLoc,
                                    @c_Reason
                     END
                     BREAK
                  END
               END
               ELSE
               BEGIN
                  SELECT @b_GotLoc = 1
                  IF @b_Debug = 1
                  BEGIN
                     SELECT @c_Reason = 'FOUND PAType=01: FROM location '
                                      + RTRIM(@c_FromLoc) + ' <> ' + RTRIM(@cpa_FromLoc)
                     EXEC nspPTD 'nspRDTPASTD',
                                 @n_pTraceHeadKey,
                                 @c_PutawayStrategyKey,
                                 @c_PutawayStrategyLineNumber,
                                 @n_PtraceDetailKey,
                                 @c_ToLoc,
                                 @c_Reason
                  END
                  BREAK
               END
            END
         END
         ELSE
         BEGIN
            IF @b_Debug = 1
            BEGIN
               SELECT @c_Reason = 'FAILED PAType=01: FROM location '
                                + RTRIM(@c_FromLoc) + ' <> ' + RTRIM(@cpa_FromLoc)
               EXEC nspPTD 'nspRDTPASTD',
                           @n_pTraceHeadKey,
                           @c_PutawayStrategyKey,
                           @c_PutawayStrategyLineNumber,
                           @n_PtraceDetailKey,
                           @c_ToLoc,
                           @c_Reason
            END
         END
         CONTINUE
      END -- PAType = '01'
-----------------------------------------------------------
      IF @cpa_PAType = '03' -- If Source=FromLocATION, Putaway to Pick Location
      BEGIN
         IF @c_FromLoc = @cpa_FromLoc
         BEGIN
            SET @cpa_ToLoc = ''
            SELECT TOP 1
                  @cpa_ToLoc = LOC
            FROM  SKUxLOC SL WITH (NOLOCK)
            WHERE SL.StorerKey = @c_StorerKey
            AND   SL.Sku = @c_SKU
            AND   SL.LocationType IN ('PICK','CASE')

            IF ISNULL(RTRIM(@cpa_ToLoc),'') <> ''
            BEGIN
               SELECT @c_ToLoc = @cpa_ToLoc

               IF @cpa_CheckRestrictions = 'Y'
               BEGIN
                  SELECT @b_RestrictionsPassed = 0
                  GOTO PA_CHECKRESTRICTIONS

                  PATYPE03:
                  IF @b_RestrictionsPassed = 1
                  BEGIN
                     SELECT @b_GotLoc = 1
                     IF @b_Debug = 1
                     BEGIN
                        SELECT @c_Reason = 'FOUND PAType=03: FROM location ' + RTRIM(@c_FromLoc) + ' <> ' + RTRIM(@cpa_FromLoc)
                        EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                                    @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                                    @c_ToLoc, @c_Reason
                     END
                     BREAK
                  END
               END
               ELSE
               BEGIN
                  SELECT @b_GotLoc = 1
                  IF @b_Debug = 1
                  BEGIN
                     SELECT @c_Reason = 'FOUND PAType=03: FROM location ' + RTRIM(@c_FromLoc) + ' <> ' + RTRIM(@cpa_FromLoc)
                     EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                                 @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                                 @c_ToLoc, @c_Reason
                  END
                  BREAK
               END
            END -- LTRIM(RTRIM(@cpa_ToLoc),'') <> ''
     ELSE
            BEGIN
            IF @b_Debug = 1
            BEGIN
               SELECT @c_Reason = 'FAILED PAType=03: FROM location ' + RTRIM(@c_FromLoc) + ', PICK Location NOT Setup'
               EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                           @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                           @c_ToLoc, @c_Reason
            END
         END
         END
         ELSE
         BEGIN
            IF @b_Debug = 1
            BEGIN
               SELECT @c_Reason = 'FAILED PAType=03: FROM location ' + RTRIM(@c_FromLoc) + ' <> ' + RTRIM(@cpa_FromLoc)
               EXEC nspPTD 'nspASNPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                           @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                           @c_ToLoc, @c_Reason
            END
         END
         CONTINUE
      END -- PAType = '03'
-----------------------------------------------------------
      IF @cpa_PAType='05' -- If Source=ZONE, Putaway to TOLOCATION (ung09)
      BEGIN
         -- Get from PutawayZone
         DECLARE @c_FromPutawayZone NVARCHAR( 10)
         
         SELECT @c_FromPutawayZone = PutawayZone 
         FROM dbo.LOC WITH (NOLOCK) 
         WHERE LOC = @c_FromLoc

         IF @c_FromPutawayZone = @cpa_zone
         BEGIN
            IF ISNULL(RTRIM(@cpa_ToLoc),'') <> ''
            BEGIN
               SELECT @c_ToLoc = @cpa_ToLoc

               IF @cpa_CheckRestrictions='Y'
               BEGIN
                  SELECT @b_RestrictionsPassed = 0
                  GOTO PA_CHECKRESTRICTIONS

                  PATYPE05:
                  IF @b_RestrictionsPassed=1
                  BEGIN
                     SELECT @b_GotLoc = 1
                     IF @b_Debug = 1
                     BEGIN
                        SELECT @c_Reason = 'FOUND PAType=05: FROM PutawayZone '
                        + RTRIM(@cpa_zone) + ' to loc ' + RTRIM(@cpa_ToLoc)
                        EXEC nspPTD 'nspRDTPASTD',
                                    @n_pTraceHeadKey,
                                    @c_PutawayStrategyKey,
                                    @c_PutawayStrategyLineNumber,
                                    @n_PtraceDetailKey,
                                    @c_ToLoc,
                                    @c_Reason
                     END
                     BREAK
                  END
               END
               ELSE
               BEGIN
                  SELECT @b_GotLoc = 1
                  IF @b_Debug = 1
                  BEGIN
                     SELECT @c_Reason = 'FOUND PAType=01: FROM PutawayZone '
                                      + RTRIM(@cpa_zone) + ' to loc ' + RTRIM(@cpa_ToLoc)
                     EXEC nspPTD 'nspRDTPASTD',
                                 @n_pTraceHeadKey,
                                 @c_PutawayStrategyKey,
                                 @c_PutawayStrategyLineNumber,
                                 @n_PtraceDetailKey,
                                 @c_ToLoc,
                                 @c_Reason
                  END
                  BREAK
               END
            END
         END
         ELSE
         BEGIN
            IF @b_Debug = 1
            BEGIN
               SELECT @c_Reason = 'FAILED PAType=05: FROM putaway zone '
                                + RTRIM(@c_FromPutawayZone) + ' <> ' + RTRIM(@cpa_zone)
               EXEC nspPTD 'nspRDTPASTD',
                           @n_pTraceHeadKey,
                           @c_PutawayStrategyKey,
                           @c_PutawayStrategyLineNumber,
                           @n_PtraceDetailKey,
                           @c_ToLoc,
                           @c_Reason
            END
         END
         CONTINUE
      END -- PAType = '05'
-----------------------------------------------------------
      IF @cpa_PAType='59' OR -- SOS133180 UK Project - IF ID Held, PUT TO Specified ZONE
         @cpa_PAType='60'    -- SOS133180 UK Project - IF ID Held, PUT TO Specified location
      BEGIN
         IF ISNULL(RTRIM(@c_ID), '') = '' OR
            EXISTS(
                  SELECT 1
                  FROM   ID WITH (NOLOCK)
                  WHERE  ID = @c_ID AND
                  STATUS = 'OK'
                  )
         BEGIN
            IF @b_Debug = 1
            BEGIN
               SELECT @c_Reason = 'FAILED PAType=' + RTRIM(@cpa_PAType)
                                + ': Pallet ID NOT On-Hold OR Blank '

               EXEC nspPTD 'nspRDTPASTD',
                              @n_pTraceHeadKey,
                              @c_PutawayStrategyKey,
                              @c_PutawayStrategyLineNumber,
                              @n_PtraceDetailKey,
                              @c_ToLoc,
                              @c_Reason
            END
            CONTINUE
         END

         IF @cpa_PAType = '60'
         BEGIN
            IF ISNULL(RTRIM(@cpa_ToLoc),'') <> ''
            BEGIN
               SELECT @c_ToLoc = @cpa_ToLoc

               IF @cpa_CheckRestrictions='Y'
               BEGIN
                  SELECT @b_RestrictionsPassed = 0
                  GOTO PA_CHECKRESTRICTIONS

                  PATYPE60:
                  IF @b_RestrictionsPassed=1
                  BEGIN
                     SELECT @b_GotLoc = 1
                     IF @b_Debug = 1
                     BEGIN
                        SELECT @c_Reason = 'FOUND PAType=60: Held ID ' + RTRIM(@c_ID)
                                         + ' Putaway to specified location ' + RTRIM(@cpa_ToLoc)

                        EXEC nspPTD 'nspRDTPASTD',
                                    @n_pTraceHeadKey,
                                    @c_PutawayStrategyKey,
                                    @c_PutawayStrategyLineNumber,
                                    @n_PtraceDetailKey,
                                    @c_ToLoc,
                                    @c_Reason
                     END
                     BREAK
                  END

                  BEGIN
                     SELECT @b_GotLoc = 1
                     IF @b_Debug = 1
                     BEGIN
                        SELECT @c_Reason = 'FOUND PAType=60: Held ID ' + RTRIM(@c_ID)
                                         + ' Putaway to specified location ' + RTRIM(@cpa_ToLoc)

                        EXEC nspPTD 'nspRDTPASTD',
                                    @n_pTraceHeadKey,
                                    @c_PutawayStrategyKey,
                                    @c_PutawayStrategyLineNumber,
                                    @n_PtraceDetailKey,
                                    @c_ToLoc,
                                    @c_Reason
                     END
                     BREAK
                  END
               END
            END
            CONTINUE
         END
      END -- PAType = '59','60'
-----------------------------------------------------------
      IF @cpa_PAType = '02' OR -- IF source is FROMLOC then move to a location within the specified zone
         @cpa_PAType = '04' OR -- Search ZONE specified on this strategy record
         @cpa_PAType = '12' OR -- Search ZONE specified in sku table
         @cpa_PAType = '16' OR -- IDSV5 - Leo - SOS# 3553 - Search Location With the same Sku Within Sku Zone
         @cpa_PAType = '17' OR -- SOS36712 KCPI - Search Empty Location Within Sku Zone
         @cpa_PAType = '18' OR -- SOS36712 KCPI - Search Location Within Specified Zone
         @cpa_PAType = '19' OR -- SOS36712 KCPI - Search Empty Location Within Specified Zone
         @cpa_PAType = '21' OR -- Search Location With the same Sku (consider pendingmovein too) within Sku Zone SOS257227
         @cpa_PAType = '22' OR -- Search ZONE specified in sku table for Single Pallet AND must be Empty Loc
         @cpa_PAType = '23' OR -- Search loc within specified zones with same sku (consider pendingmovein too)
         @cpa_PAType = '24' OR -- Search ZONE specified in this strategy for Single Pallet AND must be empty Loc
         @cpa_PAType = '30' OR -- Search loc within specified zone (with pendingmovein)
         @cpa_PAType = '32' OR -- Search ZONE specified in sku table for Multi Pallet where unique sku = sku putaway
         @cpa_PAType = '34' OR -- Search ZONE specified in this strategy for Multi Pallet where unique sku = sku putaway
         @cpa_PAType = '42' OR -- Search ZONE specified in sku table for Empty Multi Pallet Location
         @cpa_PAType = '44' OR -- Search ZONE specified in this strategy for empty Multi Pallet location
         @cpa_PAType = '52' OR -- Search Zone specified in SKU table for matching Lottable02 AND Lottable04
         @cpa_PAType = '54' OR -- Search Zone Specified in SKU Table (Matching Lottable02 and Lottable04)
         @cpa_PAType = '55' OR -- SOS69388 KFP - Cross facility - search location within specified zone
                               --                with matching Lottable02 AND Lottable04 (do NOT mix sku)
         @cpa_PAType = '56' OR -- SOS69388 KFP - Cross facility - search Empty Location base on HostWhCode inventory = 0
         @cpa_PAType = '57' OR -- SOS69388 KFP - Cross facility - search suitable location within specified zone (mix with diff sku)
         @cpa_PAType = '58' OR -- SOS69388 KFP - Cross facility - search suitable location within specified zone (do NOT mix sku)
         @cpa_PAType = '59' OR -- SOS133180 UK Project - IF ID Held, PUT TO Specified ZONE
         @cpa_PAType = '61' OR -- SOS157089 TITAN Project - Search Specified Zone with Empty Pick & Drop Location
         @cpa_PAType = '62' OR -- SOS292706 - Search Empty Location Within Sku Zone Considering PendingMoveIn -- (ChewKP07)
         @cpa_PAType = '63'    --step1: Search Location With the same Sku consider shelflife by locationgroup, pallet type(sku.color) & max pallet per loc configure in codelkup. --NJOW01
                               --step2: Search empty Location by locationgroup, pallet type(sku.color) & max pallet per loc configure in codelkup
      BEGIN
         IF @cpa_PAType = '02' OR
            @cpa_PAType = '55' OR -- SOS69388 KFP - Cross facility - search location within specified zone
                                  --            with matching Lottable02 AND Lottable04 (do NOT mix sku)
            @cpa_PAType = '56' OR -- SOS69388 KFP - Cross facility - search Empty Location base on HostWhCode inventory = 0
            @cpa_PAType = '57' OR -- SOS69388 KFP - Cross facility - search suitable location within specified zone (mix with diff sku)
            @cpa_PAType = '58'    -- SOS69388 KFP - Cross facility - search suitable location within specified zone (do NOT mix sku)
         BEGIN
            IF @cpa_PAType = '02' --If PA_FromLoc does not equal to current location, need go to next strategy
            BEGIN
               IF ISNULL(@cpa_FromLoc, '') <> @c_FromLoc
               BEGIN
                  IF @b_Debug = 1
                  BEGIN
                     SELECT @c_Reason = 'FAILED PAType=02: FROM location '
                                    + RTRIM(@c_FromLoc) + ' <> ' + RTRIM(@cpa_FromLoc)
                     EXEC nspPTD 'nspRDTPASTD',
                                 @n_pTraceHeadKey,
                                 @c_PutawayStrategyKey,
                                 @c_PutawayStrategyLineNumber,
                                 @n_PtraceDetailKey,
                                 @c_ToLoc,
                                 @c_Reason
                  END
                  CONTINUE;
               END
            END

            IF @c_FromLoc = @cpa_FromLoc
            BEGIN
               SELECT @c_SearchZone = @cpa_Zone
                              
               IF ISNULL(RTRIM(@cpa_Zone),'') <> ''
               BEGIN
                  IF NOT EXISTS (SELECT 1 FROM #t_PutawayZone AS tpz WHERE tpz.PutawayZone = @cpa_Zone)
                     INSERT INTO #t_PutawayZone( PutawayZone ) VALUES (@cpa_Zone)
               END
            END
         END
         IF @cpa_PAType = '04' OR
            @cpa_PAType = '18' OR -- SOS36712 KCPI - Search Location Within Specified Zone
            @cpa_PAType = '19' OR -- SOS36712 KCPI - Search Empty Location Within Specified Zone
            @cpa_PAType = '23' OR -- Search loc within specified zones with same sku (consider pendingmovein too)
            @cpa_PAType = '24' OR
            @cpa_PAType = '30' OR -- Search loc within specified zone (with pendingmovein)
            @cpa_PAType = '34' OR
            @cpa_PAType = '44' OR
            @cpa_PAType = '54' OR
            @cpa_PAType = '59' OR
            @cpa_PAType = '61'    -- SOS157089 TITAN Project - Search Specified Zone with Empty Pick & Drop Location
         BEGIN
            SELECT @c_SearchZone = @cpa_Zone
            
            IF ISNULL(RTRIM(@cpa_Zone),'') <> ''
            BEGIN
               IF NOT EXISTS (SELECT 1 FROM #t_PutawayZone AS tpz WHERE tpz.PutawayZone = @cpa_Zone)
                  INSERT INTO #t_PutawayZone( PutawayZone ) VALUES (@cpa_Zone)
            END
         END
         IF @cpa_PAType = '12' OR
            @cpa_PAType = '16' OR -- IDSV5 - Leo - SOS# 3553 - Search Location With the same Sku Within Sku Zone
            @cpa_PAType = '17' OR -- SOS36712 KCPI - Search Empty Location Within Sku Zone
            @cpa_PAType = '21' OR -- Search Location With the same Sku (consider pendingmovein too) within Sku Zone
            @cpa_PAType = '22' OR
            @cpa_PAType = '32' OR
            @cpa_PAType = '42' OR
            @cpa_PAType = '52' OR -- (CheWKP07)
            @cpa_PAType = '59' OR -- (SHONG01)
            @cpa_PAType = '62'    -- (ChewKP07)

         BEGIN
            IF ISNULL(RTRIM(@c_SKU),'') <> '' AND NOT (@b_MultiProductID = 1)
            BEGIN
               SELECT @c_SearchZone = PutawayZone
               FROM SKU (NOLOCK)
               WHERE StorerKey = @c_StorerKey
               AND SKU = @c_SKU
               
               IF ISNULL(RTRIM(@c_SearchZone),'') <> ''
               BEGIN
                  IF NOT EXISTS (SELECT 1 FROM #t_PutawayZone AS tpz WHERE tpz.PutawayZone = @c_SearchZone)
                     INSERT INTO #t_PutawayZone( PutawayZone ) VALUES (@c_SearchZone)
               END

            END
            ELSE
            BEGIN
               IF ( SELECT COUNT( DISTINCT S.PutawayZone )
                    FROM @t_SKUList t
                    JOIN SKU s WITH (NOLOCK) ON t.StorerKey = S.StorerKey AND t.SKU = S.Sku ) > 1
               BEGIN
                  IF @b_Debug = 1
                  BEGIN
                     SELECT @c_Reason = 'FAILED PAType=' + RTRIM(@cpa_PAType) + ': Commodity AND Storer combination NOT found'
                     EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                                 @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                                 @c_ToLoc, @c_Reason
                  END
                  CONTINUE -- This search does NOT apply because there is no sku
               END
               ELSE
               BEGIN
                  SELECT TOP 1 @c_SearchZone = S.PutawayZone
                  FROM @t_SKUList t
                  JOIN SKU s WITH (NOLOCK) ON t.StorerKey = S.StorerKey AND t.SKU = S.Sku
                  
                  IF ISNULL(RTRIM(@c_SearchZone),'') <> ''
                  BEGIN
                     IF NOT EXISTS (SELECT 1 FROM #t_PutawayZone AS tpz WHERE tpz.PutawayZone = @c_SearchZone)
                        INSERT INTO #t_PutawayZone( PutawayZone ) VALUES (@c_SearchZone)
                  END
               END
            END
         END

         -- Chekcing
         IF @b_Debug = 2
         BEGIN
            PRINT 'PATyp : ' + @cpa_PAType
            PRINT '>  #t_PutawayZone' 
            SELECT * FROM #t_PutawayZone AS tpz WITH(NOLOCK)
            
         END

         IF ISNULL(RTRIM(@c_SearchZone),'') <> '' OR
            ( ISNULL(RTRIM(@cpa_PutawayZone01),'') <> '' OR
              ISNULL(RTRIM(@cpa_PutawayZone02),'') <> '' OR
              ISNULL(RTRIM(@cpa_PutawayZone03),'') <> '' OR
              ISNULL(RTRIM(@cpa_PutawayZone04),'') <> '' OR
              ISNULL(RTRIM(@cpa_PutawayZone05),'') <> '' OR
              ISNULL(RTRIM(@cpa_PutawayZoneExt),'') <> '')
         BEGIN
            IF @cpa_LocSearchType = '1' -- Search Zone By Location Code
            BEGIN
               IF @cpa_PAType = '02' OR -- IF source is FROMLOC then move to a location within the specified zone
                  @cpa_PAType = '04' OR -- Search ZONE specified on this strategy record
                  @cpa_PAType = '12' OR
                  @cpa_PAType = '59' OR -- SHONG01
                  @cpa_PAType = '61'    -- SOS157089 TITAN Project - Search Specified Zone with Empty Pick & Drop Location
               BEGIN
                  DECLARE @n_StdCube                float
                        , @c_SelectSQL              nvarchar(4000)
                        , @n_NoOfInclude            int
                        , @c_DimRestSQL             nvarchar(3000)

                  -- Build Location Flag Restriction SQL
                  SELECT @n_NoOfInclude = 0

                  IF  @cpa_PAType = '61' 
                  BEGIN
                     IF ISNULL(RTRIM(@cpa_PutawayZone01), '') <> ''
                        INSERT INTO #t_PutawayZone ( PutawayZone ) VALUES ( @cpa_PutawayZone01 )
                        
                     IF ISNULL(RTRIM(@cpa_PutawayZone02), '') <> ''
                        INSERT INTO #t_PutawayZone ( PutawayZone ) VALUES ( @cpa_PutawayZone02 )

                     IF ISNULL(RTRIM(@cpa_PutawayZone03), '') <> ''
                        INSERT INTO #t_PutawayZone ( PutawayZone ) VALUES ( @cpa_PutawayZone03 )

                     IF ISNULL(RTRIM(@cpa_PutawayZone04), '') <> ''
                        INSERT INTO #t_PutawayZone ( PutawayZone ) VALUES ( @cpa_PutawayZone04 )

                     IF ISNULL(RTRIM(@cpa_PutawayZone05), '') <> ''
                        INSERT INTO #t_PutawayZone ( PutawayZone ) VALUES ( @cpa_PutawayZone05 )
                        
                  END

                  -- Fit by Aisle -- (ung07)
                  SELECT @c_DimRestSQL = ''
                  IF '18'  IN (@cpa_DimensionRestriction01, @cpa_DimensionRestriction02, @cpa_DimensionRestriction03,
                              @cpa_DimensionRestriction04, @cpa_DimensionRestriction05, @cpa_DimensionRestriction06)
                  BEGIN
                     SELECT @c_DimRestSQL = RTRIM(@c_DimRestSQL) + ' AND dbo.nspPAFitInAisle( ' +
                        '''' + @c_PutawayStrategyKey        + ''', ' +
                        '''' + @c_PutawayStrategyLineNumber + ''', ' +
                        ' @c_NextPnDAisle, ' +
                        '''' + @c_StorerKey                 + ''', ' +
                        '''' + @c_Facility                  + ''', ' +
                        '''' + @c_FromLOC                   + ''', ' +
                        '''' + @cpa_DimensionRestriction01  + ''', ' +
                        '''' + @cpa_DimensionRestriction02  + ''', ' +
                        '''' + @cpa_DimensionRestriction03  + ''', ' +
                        '''' + @cpa_DimensionRestriction04  + ''', ' +
                        '''' + @cpa_DimensionRestriction05  + ''', ' +
                        '''' + @cpa_DimensionRestriction06  + ''', ' +
                        '''' + @c_ID                        + ''') = 1'
                        
                     SET @c_FitCasesInAisle = 'Y'
                  END
                  ELSE IF '19'  IN (@cpa_DimensionRestriction01, @cpa_DimensionRestriction02, @cpa_DimensionRestriction03,
                              @cpa_DimensionRestriction04, @cpa_DimensionRestriction05, @cpa_DimensionRestriction06)
                  BEGIN
                      SELECT @c_DimRestSQL = RTRIM(@c_DimRestSQL) + ' AND dbo.nspPAFitInAisle( ' +
                        '''' + @c_PutawayStrategyKey        + ''', ' +
                        '''' + @c_PutawayStrategyLineNumber + ''', ' +
                        ' @c_NextPnDAisle, ' +
                        '''' + @c_StorerKey                 + ''', ' +
                        '''' + @c_Facility                  + ''', ' +
                        '''' + @c_FromLOC                   + ''', ' +
                        '''' + @cpa_DimensionRestriction01  + ''', ' +
                        '''' + @cpa_DimensionRestriction02  + ''', ' +
                        '''' + @cpa_DimensionRestriction03  + ''', ' +
                        '''' + @cpa_DimensionRestriction04  + ''', ' +
                        '''' + @cpa_DimensionRestriction05  + ''', ' +
                        '''' + @cpa_DimensionRestriction06  + ''', ' +
                        '''' + @c_ID                        + ''') = 1'
                   SET @c_FitCasesInAisle = 'Y'
                  END
                  ELSE
                     SET @c_FitCasesInAisle = ''

                  -- Extended putaway strategy for zone
                  IF EXISTS( SELECT TOP 1 1 FROM CodeLKUP WITH (NOLOCK)
                           JOIN LOC WITH (NOLOCK) ON (LOC.PutawayZone = CodeLkup.Short)
                        WHERE ListName = 'PAStgLnExt'
                           AND Code LIKE RTRIM( @c_PutawayStrategyKey) + @c_PutawayStrategyLineNumber + '%'
                           AND Long = 'PutawayZone')
                  BEGIN
                     DECLARE @cPutawayZone NVARCHAR(10)
                     DECLARE @curPA CURSOR

                     SET @cpa_PutawayZoneExt = ''
                     SET @cPutawayZone = ''

                     -- Loop each ext zone
                     SET @curPA = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                        SELECT Short
                        FROM CodeLKUP WITH (NOLOCK)
                        WHERE ListName = 'PAStgLnExt'
                           AND Code LIKE RTRIM( @c_PutawayStrategyKey) + @c_PutawayStrategyLineNumber + '%'
                           AND Long = 'PutawayZone'
                     OPEN @curPA
                     FETCH NEXT FROM @curPA INTO @cPutawayZone
                     WHILE @@FETCH_STATUS = 0
                     BEGIN
                        -- Concat each ext zone
                        IF ISNULL(RTRIM(@cPutawayZone),'') <> ''
                        BEGIN
                           IF NOT EXISTS (SELECT 1 FROM #t_PutawayZone AS tpz WHERE tpz.PutawayZone = @cPutawayZone)
                              INSERT INTO #t_PutawayZone( PutawayZone ) VALUES (@cPutawayZone)
                        END
                                                               
                        FETCH NEXT FROM @curPA INTO @cPutawayZone
                     END

                     -- Remove last comma
                     --IF LEN( @cpa_PutawayZoneExt) > 0
                     --   SET @cpa_PutawayZoneExt = LEFT( @cpa_PutawayZoneExt, LEN( @cpa_PutawayZoneExt) - 1)

                     CLOSE @curPA
                     DEALLOCATE @curPA
                  END
                  
                  IF @b_Debug=2
                  BEGIN
                     IF ISNULL(RTRIM(@c_DimRestSQL),'') <> ''
                        PRINT '>>> @c_DimRestSQL: ' + @c_DimRestSQL
                  END

                  -- (SHONG01)
                  SET @c_SQL_LocStateRestriction = N''
                  IF EXISTS(SELECT 1 FROM #t_LocStateRestriction)
                  BEGIN
                      DECLARE @c_LocStateRestriction NVARCHAR(10)

                      DECLARE CUR_LocStateRestriction CURSOR FAST_FORWARD READ_ONLY FOR
                      SELECT LocationStateRestriction
                      FROM #t_LocStateRestriction

                      OPEN CUR_LocStateRestriction

                      FETCH NEXT FROM CUR_LocStateRestriction INTO @c_LocStateRestriction

                      WHILE @@FETCH_STATUS = 0
                      BEGIN
                          IF @c_LocStateRestriction='13'
                          BEGIN
                             IF ISNULL(RTRIM(@c_SKU_ABC),'') <> ''
                                SELECT @c_SQL_LocStateRestriction = @c_SQL_LocStateRestriction + N' AND LOC.ABC = ' + QUOTENAME(TRIM(@c_SKU_ABC), '''')
                          END

                          IF @c_LocStateRestriction='17'
                          BEGIN
                             IF ISNULL(RTRIM(@c_Lottable02),'') <> ''
                                SELECT @c_SQL_LocStateRestriction = @c_SQL_LocStateRestriction + N' AND LOC.HOSTWHCODE = ' + QUOTENAME(TRIM(@c_Lottable02), '''')
                          END

                          FETCH NEXT FROM CUR_LocStateRestriction INTO @c_LocStateRestriction
                      END -- While

                      CLOSE CUR_LocStateRestriction
                      DEALLOCATE CUR_LocStateRestriction
                  END

                  IF '1' IN (@cpa_LocationStateRestriction1,@cpa_LocationStateRestriction2,@cpa_LocationStateRestriction3)
                  BEGIN -- loc must be empty
                  
                     SELECT @c_SelectSQL =
                                       ' DECLARE Cur_PutawayLocation CURSOR FAST_FORWARD READ_ONLY FOR ' +
                                       ' SELECT LOC.LOC ' +
                                       ' FROM  LOC WITH (NOLOCK) ' +
                                       ' LEFT OUTER JOIN LOTxLOCxID WITH (NOLOCK) ON ( LOC.loc = LOTxLOCxID.LOC ) ' +
                                       ' LEFT OUTER JOIN SKU WITH (NOLOCK) ON SKU.StorerKey = LOTxLOCxID.StorerKey AND SKU.SKU = LOTxLOCxID.SKU '
                                                                                                    
                     IF EXISTS (SELECT 1 FROM #t_PutawayZone)
                     BEGIN
                        SELECT @c_SelectSQL = @c_SelectSQL + ' JOIN #t_PutawayZone PZ ON LOC.PutawayZone = PZ.PutawayZone ' 
                     END 
                                       
                  SELECT @c_SelectSQL = @c_SelectSQL +
                  ' WHERE   LOC.Facility = @c_Facility' +
                  CASE WHEN @cpa_PAType = '61' THEN ' AND LOC.LocAisle = @c_NextPnDAisle' ELSE '' END +
                  ISNULL( RTRIM(@c_SQL_LocationFlagInclude), '') +
                  ISNULL( RTRIM(@c_SQL_LocationFlagExclude), '') +
                  ISNULL( RTRIM(@c_SQL_LocationTypeExclude), '') +
                  ISNULL( RTRIM(@c_SQL_LocLevelInclude    ), '') +
                  ISNULL( RTRIM(@c_SQL_LocLevelExclude    ), '') +
                  ISNULL( RTRIM(@c_SQL_LocAisleInclude    ), '') +
                  ISNULL( RTRIM(@c_SQL_LocAisleExclude    ), '') +
                  ISNULL( RTRIM(@c_SQL_LocTypeRestriction ), '') +
                  ISNULL( RTRIM(@c_SQL_LocStateRestriction ), '') + -- (SHONG01)
                  ISNULL( RTRIM(@c_DimRestSQL), '') +  --(ung07)
                  ISNULL( RTRIM(@cpa_PutCodeSQL),'') + --(ung06)
                  ' GROUP BY LOC.PALogicalLoc, LOC.LOC ' +
                  ' HAVING (( SUM(LOTxLOCxID.Qty) - SUM(LOTxLOCxID.QtyPicked)) = 0 OR (SUM(LOTxLOCxID.Qty) - SUM(LOTxLOCxID.QtyPicked))  IS NULL )' + 
                  ' AND (SUM(LOTxLOCxID.PendingMoveIn) = 0 OR SUM(LOTxLOCxID.PendingMoveIn) IS NULL) '

                     SELECT @c_DimRestSQL = ''

                     -- modify by SHONG on 15-JAN-2004
                     -- to disable further checking of all locationstaterestriction = '1'
                     IF @cpa_LocationStateRestriction1 = '1'
                     BEGIN
                        SELECT @cpa_LocationStateRestriction1 = '',
                               @cpa_LocationStateRestriction2 = '',
                               @cpa_LocationStateRestriction3 = ''
                     END

                     
                     -- Fit by Cube
                     IF '1' IN (@cpa_DimensionRestriction01, @cpa_DimensionRestriction02, @cpa_DimensionRestriction03,
                                @cpa_DimensionRestriction04, @cpa_DimensionRestriction05, @cpa_DimensionRestriction06)
                     BEGIN
                        SELECT @c_DimRestSQL = ''
                        SET @npa_TotalCube = @n_PalletTotStdCube
                        SELECT @c_DimRestSQL = RTRIM(@c_DimRestSQL) + ' AND '
                        SELECT @c_DimRestSQL = RTRIM(@c_DimRestSQL) + ' MAX(LOC.CubicCapacity) - ' +
                                             ' SUM((ISNULL(LOTxLOCxID.Qty, 0) - ISNULL(LOTxLOCxID.QtyPicked,0) + ISNULL(LOTxLOCxID.PendingMoveIn,0))* ISNULL(SKU.STDCUBE,1)) >= ' +
                                             ' @npa_TotalCube '
                     END

                     -- Fit by BOMSKU Cube -- (ChewKP02)
                     IF '11' IN (@cpa_DimensionRestriction01, @cpa_DimensionRestriction02, @cpa_DimensionRestriction03,
                                 @cpa_DimensionRestriction04, @cpa_DimensionRestriction05, @cpa_DimensionRestriction06)
                     BEGIN
                        SELECT @c_DimRestSQL = ''
                        SELECT @n_InvBOMCube = 0
                        SET @npa_TotalCube = @f_PPalletTotStdCube
                        SELECT @c_DimRestSQL = RTRIM(@c_DimRestSQL) + ' AND '
                        SELECT @c_DimRestSQL = RTRIM(@c_DimRestSQL) + ' MAX(LOC.CubicCapacity) - ' +
                                             ' dbo.fnc_GetInvBOMCube(1,LOC.LOC,'''') >=  @npa_TotalCube '
                     END

                     -- Fit by LxWxH
                     IF '2' IN (@cpa_DimensionRestriction01, @cpa_DimensionRestriction02, @cpa_DimensionRestriction03,
                                @cpa_DimensionRestriction04, @cpa_DimensionRestriction05, @cpa_DimensionRestriction06)
                           AND   @c_Loc_Type NOT IN ('PICK','CASE') AND (@b_config_PALDIMCALC = '1')
                     BEGIN

                        SELECT @n_PalletWoodWidth  = PACK.PalletWoodWidth,
                               @n_PalletWoodLength = PACK.PalletWoodLength,
                               @n_PalletWoodHeight = PACK.PalletWoodHeight,
                               @n_CaseHeight = PACK.HeightUOM4
                        FROM PACK (NOLOCK)
                        WHERE PACK.Packkey = @c_PackKey

                        SET @n_IdCnt = 0;
                        SELECT @n_IdCnt = COUNT(DISTINCT ID)
                        FROM   LOTxLOCxID WITH (NOLOCK)
                        WHERE  StorerKey = @c_StorerKey
                          AND Loc = @c_ToLoc
                          AND (Qty > 0 OR PendingMoveIn > 0)
                        SET  @n_IdCnt = @n_IdCnt+1

                        SELECT @c_DimRestSQL = RTRIM(@c_DimRestSQL) + ' AND '
                        SELECT @c_DimRestSQL = RTRIM(@c_DimRestSQL)
                           +'(( ' + STR(@n_PalletWoodWidth) + ' * ' +STR(@n_IdCnt) + ' <= MAX(LOC.Width) AND ' + STR(@n_PalletWoodLength) +' <= MAX(LOC.Length))'
                           +' OR '
                           +'( ' + STR(@n_PalletWoodLength) + ' * ' +STR(@n_IdCnt) + ' <= MAX(LOC.Length) AND ' + STR(@n_PalletWoodWidth) +' <= MAX(LOC.Width)))'
                           +' AND '
                           +STR(@n_CaseHeight)+' + '+STR(@n_PalletWoodHeight)+' <= MAX(LOC.Height)'
                     END
                     
                     -- Fit by Weight
                     IF '3' IN (@cpa_DimensionRestriction01, @cpa_DimensionRestriction02, @cpa_DimensionRestriction03,
                                @cpa_DimensionRestriction04, @cpa_DimensionRestriction05, @cpa_DimensionRestriction06)
                     BEGIN
                        --SELECT @c_DimRestSQL = ''
                        SET @npa_TotalWeight = @n_PalletTotStdGrossWgt
                        SELECT @c_DimRestSQL = RTRIM(@c_DimRestSQL) + ' AND '
                        SELECT @c_DimRestSQL = RTRIM(@c_DimRestSQL) + ' MAX(LOC.WeightCapacity) - ' +
                                             ' SUM((ISNULL(LOTxLOCxID.Qty, 0) - ISNULL(LOTxLOCxID.QtyPicked,0) + ISNULL(LOTxLOCxID.PendingMoveIn,0))* ISNULL(SKU.STDGROSSWGT,1)) >= ' +
                                            ' @npa_TotalWeight '
                     END

                     --Fit by height
                     IF '5' IN (@cpa_DimensionRestriction01, @cpa_DimensionRestriction02, @cpa_DimensionRestriction03,
                                @cpa_DimensionRestriction04, @cpa_DimensionRestriction05, @cpa_DimensionRestriction06)
                           AND (@b_config_PALDIMCALC = '1')
                     BEGIN

                        SELECT @n_CaseHeight = PACK.HeightUOM4,
                               @n_PalletWoodHeight = PACK.PalletWoodHeight
                        FROM PACK (NOLOCK)
                        WHERE PACK.Packkey = @c_PackKey

--                         SELECT @c_DimRestSQL = ''
                        SELECT @c_DimRestSQL = RTRIM(@c_DimRestSQL) + ' AND '
                        SELECT @c_DimRestSQL = RTRIM(@c_DimRestSQL) + ' ('+STR(@n_CaseHeight)+' + '+STR(@n_PalletWoodHeight)+' <= MAX(LOC.Height)'
                     END

                     
                     -- Fit by BOMSKU Weight -- (ChewKP02)
                     IF '12' IN (@cpa_DimensionRestriction01, @cpa_DimensionRestriction02, @cpa_DimensionRestriction03,
                                 @cpa_DimensionRestriction04, @cpa_DimensionRestriction05, @cpa_DimensionRestriction06)
                     BEGIN
                        SELECT @c_DimRestSQL = ''
                        SET @npa_TotalWeight = @n_PalletTotStdGrossWgt
                        SELECT @c_DimRestSQL = RTRIM(@c_DimRestSQL) + ' AND '
                        SELECT @c_DimRestSQL = RTRIM(@c_DimRestSQL) + ' MAX(LOC.WeightCapacity) - ' +
                                             ' dbo.fnc_GetInvBOMCube(2,LOC.LOC,'''') >= @npa_TotalWeight '
                     END

                     SELECT @c_SelectSQL = RTRIM(@c_SelectSQL) + @c_DimRestSQL +
                                         ' ORDER BY LOC.PALogicalLoc, LOC.LOC '

                     -- to disable further checking of DimensionRestriction
                     IF @cpa_DimensionRestriction01 IN ('1', '3')
                        SELECT @cpa_DimensionRestriction01 = '0'
                     IF @cpa_DimensionRestriction02 IN ('1', '3')
                        SELECT @cpa_DimensionRestriction02 = '0'
                     IF @cpa_DimensionRestriction03 IN ('1', '3')
                        SELECT @cpa_DimensionRestriction04 = '0'
                     IF @cpa_DimensionRestriction04 IN ('1', '3')
                        SELECT @cpa_DimensionRestriction04 = '0'
                     IF @cpa_DimensionRestriction05 IN ('1', '3')
                        SELECT @cpa_DimensionRestriction05 = '0'
                     IF @cpa_DimensionRestriction06 IN ('1', '3')
                        SELECT @cpa_DimensionRestriction06 = '0'
                  END   -- loc must be empty

                  ELSE IF '3' IN (@cpa_LocationStateRestriction1,@cpa_LocationStateRestriction2,@cpa_LocationStateRestriction3)
                  BEGIN -- do NOT mix lot
                     SELECT @c_SelectSQL =
                                       ' DECLARE Cur_PutawayLocation CURSOR FAST_FORWARD READ_ONLY FOR ' +
                                       ' SELECT LOC.LOC ' +
                                       ' FROM LOC WITH (NOLOCK) LEFT OUTER JOIN LOTxLOCxID WITH (NOLOCK) ON ( LOC.loc = LOTxLOCxID.LOC ) ' 

                     IF EXISTS (SELECT 1 FROM #t_PutawayZone)
                     BEGIN
                        SELECT @c_SelectSQL = @c_SelectSQL + ' JOIN #t_PutawayZone PZ ON LOC.PutawayZone = PZ.PutawayZone ' 
                     END                                  
                           
                     SELECT @c_SelectSQL = @c_SelectSQL + 
                        ' LEFT OUTER JOIN SKU WITH (NOLOCK) ON SKU.StorerKey = LOTxLOCxID.StorerKey AND SKU.SKU = LOTxLOCxID.SKU ' +
                        ' WHERE LOC.Facility = @c_Facility ' +
                        ' AND (LOTxLOCxID.LOT = @c_LOT '  +
                        ' OR LOTxLOCxID.Lot IS NULL) ' +                                       
                           ISNULL( RTRIM(@c_SQL_LocationFlagInclude), '') +
                           ISNULL( RTRIM(@c_SQL_LocationFlagExclude), '') +
                           ISNULL( RTRIM(@c_SQL_LocationTypeExclude), '') +
                           ISNULL( RTRIM(@c_SQL_LocLevelInclude    ), '') +
                           ISNULL( RTRIM(@c_SQL_LocLevelExclude    ), '') +
                           ISNULL( RTRIM(@c_SQL_LocAisleInclude    ), '') +
                           ISNULL( RTRIM(@c_SQL_LocAisleExclude    ), '') +
                           ISNULL( RTRIM(@c_SQL_LocTypeRestriction ), '') +
                           ISNULL( RTRIM(@c_SQL_LocStateRestriction ), '') + -- (SHONG01)
                           ISNULL( RTRIM(@c_DimRestSQL), '') +  --(ung07)
                           ISNULL( RTRIM(@cpa_PutCodeSQL),'') + --(ung06)
                  CASE WHEN @cpa_PAType = '61' THEN ' AND LOC.LocAisle = @c_NextPnDAisle' ELSE '' END +
                        ' GROUP BY LOC.PALogicalLOC, LOC.LOC '


                     SELECT @c_DimRestSQL = ''

                     -- Fit by Cube
                     IF '1' IN (@cpa_DimensionRestriction01, @cpa_DimensionRestriction02, @cpa_DimensionRestriction03,
                                @cpa_DimensionRestriction04, @cpa_DimensionRestriction05, @cpa_DimensionRestriction06)
                     BEGIN
                        SELECT @c_DimRestSQL = ''
                        IF RTRIM(@c_DimRestSQL) IS NULL OR RTRIM(@c_DimRestSQL) = ''
                           SELECT @c_DimRestSQL = ' HAVING '
                        ELSE
                           SELECT @c_DimRestSQL = RTRIM(@c_DimRestSQL) + ' AND '
                        
                        SET @npa_TotalCube = @n_PalletTotStdCube
                        SELECT @c_DimRestSQL = RTRIM(@c_DimRestSQL) + ' MAX(LOC.CubicCapacity) - ' +
                                             ' SUM((ISNULL(LOTxLOCxID.Qty, 0) - ISNULL(LOTxLOCxID.QtyPicked,0) + ISNULL(LOTxLOCxID.PendingMoveIn,0)) * ISNULL(SKU.STDCUBE,1)) ' + 
                                             ' >= @npa_TotalCube' 
                        
                     END

                     -- Fit by BOMSKU Cube -- (ChewKP02)
                     IF '11' IN (@cpa_DimensionRestriction01, @cpa_DimensionRestriction02, @cpa_DimensionRestriction03,
                                 @cpa_DimensionRestriction04, @cpa_DimensionRestriction05, @cpa_DimensionRestriction06)
                     BEGIN
                        SELECT @c_DimRestSQL = ''
                        IF RTRIM(@c_DimRestSQL) IS NULL OR RTRIM(@c_DimRestSQL) = ''
                           SELECT @c_DimRestSQL = ' HAVING '
                        ELSE
                           SELECT @c_DimRestSQL = RTRIM(@c_DimRestSQL) + ' AND '
                        
                        SET @npa_TotalCube = @n_PalletTotStdCube
                        SELECT @c_DimRestSQL = RTRIM(@c_DimRestSQL) + ' MAX(LOC.CubicCapacity) - ' +
                                             ' dbo.fnc_GetInvBOMCube(1,LOC.LOC,'''') >= @npa_TotalCube' 
                     END

                     -- Fit by Weight
                     IF '3' IN (@cpa_DimensionRestriction01, @cpa_DimensionRestriction02, @cpa_DimensionRestriction03,
                                @cpa_DimensionRestriction04, @cpa_DimensionRestriction05, @cpa_DimensionRestriction06)
                     BEGIN
                        SELECT @c_DimRestSQL = ''
                        IF RTRIM(@c_DimRestSQL) IS NULL OR RTRIM(@c_DimRestSQL) = ''
                           SELECT @c_DimRestSQL = ' HAVING '
                        ELSE
                           SELECT @c_DimRestSQL = RTRIM(@c_DimRestSQL) + ' AND '
                        
                        SET @npa_TotalWeight = @n_PalletTotStdGrossWgt
                        SELECT @c_DimRestSQL = RTRIM(@c_DimRestSQL) + ' MAX(LOC.WeightCapacity) - ' +
                                             ' SUM((ISNULL(LOTxLOCxID.Qty, 0) - ISNULL(LOTxLOCxID.QtyPicked,0) + ISNULL(LOTxLOCxID.PendingMoveIn,0)) * ISNULL(SKU.STDGROSSWGT,1)) ' +
                                             ' >= @npa_TotalWeight' 
                     END

                     -- Fit by BOMSKU Weight -- (ChewKP02)
                     IF '12' IN (@cpa_DimensionRestriction01, @cpa_DimensionRestriction02, @cpa_DimensionRestriction03,
                                 @cpa_DimensionRestriction04, @cpa_DimensionRestriction05, @cpa_DimensionRestriction06)
                     BEGIN
                        SELECT @c_DimRestSQL = ''
                        IF RTRIM(@c_DimRestSQL) IS NULL OR RTRIM(@c_DimRestSQL) = ''
                           SELECT @c_DimRestSQL = ' HAVING '
                        ELSE
                           SELECT @c_DimRestSQL = RTRIM(@c_DimRestSQL) + ' AND '

                        SET @npa_TotalWeight = @f_PPPalletTotStdGrossWgt
                        SELECT @c_DimRestSQL = RTRIM(@c_DimRestSQL) + ' MAX(LOC.WeightCapacity) - ' +
                                             ' dbo.fnc_GetInvBOMCube(2,LOC.LOC,'''') >= @npa_TotalWeight'  
                     END

                     SELECT @c_SelectSQL = RTRIM(@c_SelectSQL) + @c_DimRestSQL +
                       ' ORDER BY LOC.PALogicalLOC, LOC.LOC '

                     -- to disable further checking of locationstaterestriction = '2'
                     IF @cpa_LocationStateRestriction1 = '2'
                        SELECT @cpa_LocationStateRestriction1 = ''
                     ELSE IF @cpa_LocationStateRestriction2 = '2'
                        SELECT @cpa_LocationStateRestriction2 = ''
                     ELSE
                        SELECT @cpa_LocationStateRestriction3 = ''

                     IF @cpa_DimensionRestriction01 IN ('1', '3')
                        SELECT @cpa_DimensionRestriction01 = '0'
                     IF @cpa_DimensionRestriction02 IN ('1', '3')
                        SELECT @cpa_DimensionRestriction02 = '0'
                     IF @cpa_DimensionRestriction03 IN ('1', '3')
                        SELECT @cpa_DimensionRestriction04 = '0'
                     IF @cpa_DimensionRestriction04 IN ('1', '3')
                        SELECT @cpa_DimensionRestriction04 = '0'
                     IF @cpa_DimensionRestriction05 IN ('1', '3')
                        SELECT @cpa_DimensionRestriction05 = '0'
                     IF @cpa_DimensionRestriction06 IN ('1', '3')
                        SELECT @cpa_DimensionRestriction06 = '0'

                  END   -- do NOT mix Lot
                  ELSE IF '2' IN (@cpa_LocationStateRestriction1,@cpa_LocationStateRestriction2,@cpa_LocationStateRestriction3)
                  BEGIN -- do NOT mix skus
                     SELECT @c_SelectSQL =
                        ' DECLARE Cur_PutawayLocation CURSOR FAST_FORWARD READ_ONLY FOR ' +
                        ' SELECT LOC.LOC ' +
                        ' FROM LOC (NOLOCK) LEFT OUTER JOIN LOTxLOCxID (NOLOCK) ON ( LOC.loc = LOTxLOCxID.LOC ) '
                         
                     IF EXISTS (SELECT 1 FROM #t_PutawayZone)
                     BEGIN
                        SELECT @c_SelectSQL = @c_SelectSQL + ' JOIN #t_PutawayZone PZ ON LOC.PutawayZone = PZ.PutawayZone ' 
                     END                                  
                           
                     SELECT @c_SelectSQL = @c_SelectSQL +                         
                        ' LEFT OUTER JOIN SKU WITH (NOLOCK) ON SKU.StorerKey = LOTxLOCxID.StorerKey AND SKU.SKU = LOTxLOCxID.SKU ' +
                        ' WHERE LOC.Facility = @c_Facility ' +
                        ' AND (LOTxLOCxID.StorerKey = @c_StorerKey OR LOTxLOCxID.StorerKey IS NULL) ' +
                        ' AND (LOTxLOCxID.sku = @c_SKU OR LOTxLOCxID.SKU IS NULL) ' +                        
                           ISNULL( RTRIM(@c_SQL_LocationFlagInclude), '') +
                           ISNULL( RTRIM(@c_SQL_LocationFlagExclude), '') +
                           ISNULL( RTRIM(@c_SQL_LocationTypeExclude), '') +
                           ISNULL( RTRIM(@c_SQL_LocLevelInclude    ), '') +
                           ISNULL( RTRIM(@c_SQL_LocLevelExclude    ), '') +
                           ISNULL( RTRIM(@c_SQL_LocAisleInclude    ), '') +
                           ISNULL( RTRIM(@c_SQL_LocAisleExclude    ), '') +
                           ISNULL( RTRIM(@c_SQL_LocTypeRestriction ), '') +
                           ISNULL( RTRIM(@c_SQL_LocStateRestriction ), '') + -- (SHONG01)
                           ISNULL( RTRIM(@c_DimRestSQL), '') +  --(ung07)
                           ISNULL( RTRIM(@cpa_PutCodeSQL),'') + --(ung06)
                        CASE WHEN @cpa_PAType = '61' THEN ' AND LOC.LocAisle = @c_NextPnDAisle' ELSE '' END +
                        ' GROUP BY LOC.PALogicalLOC, LOC.LOC '

                     SELECT @c_DimRestSQL = ''

                  -- Fit by Cube
                     IF '1' IN (@cpa_DimensionRestriction01, @cpa_DimensionRestriction02, @cpa_DimensionRestriction03,
                                @cpa_DimensionRestriction04, @cpa_DimensionRestriction05, @cpa_DimensionRestriction06)
                     BEGIN
                        SELECT @c_DimRestSQL = ''
                        IF RTRIM(@c_DimRestSQL) IS NULL OR RTRIM(@c_DimRestSQL) = ''
                           SELECT @c_DimRestSQL = ' HAVING '
                        ELSE
                           SELECT @c_DimRestSQL = RTRIM(@c_DimRestSQL) + ' AND '

                        SET @npa_TotalCube = @n_PalletTotStdCube
                        SELECT @c_DimRestSQL = RTRIM(@c_DimRestSQL) + ' MAX(LOC.CubicCapacity) - ' +
                                             ' SUM((ISNULL(LOTxLOCxID.Qty, 0) - ISNULL(LOTxLOCxID.QtyPicked,0) + ISNULL(LOTxLOCxID.PendingMoveIn,0))* ISNULL(SKU.STDCUBE,1)) ' + 
                                             ' >= @npa_TotalCube '  
                     END

                     -- Fit by BOMSKU Cube -- (ChewKP02)
                     IF '11' IN (@cpa_DimensionRestriction01, @cpa_DimensionRestriction02, @cpa_DimensionRestriction03,
                                 @cpa_DimensionRestriction04, @cpa_DimensionRestriction05, @cpa_DimensionRestriction06)
                     BEGIN
                        SELECT @c_DimRestSQL = ''
                        IF RTRIM(@c_DimRestSQL) IS NULL OR RTRIM(@c_DimRestSQL) = ''
                           SELECT @c_DimRestSQL = ' HAVING '
                        ELSE
                           SELECT @c_DimRestSQL = RTRIM(@c_DimRestSQL) + ' AND '

                        SET @npa_TotalCube = @f_PPalletTotStdCube
                        SELECT @c_DimRestSQL = RTRIM(@c_DimRestSQL) + ' MAX(LOC.CubicCapacity) - ' +
                                             ' dbo.fnc_GetInvBOMCube(1,LOC.LOC,'''') >= @npa_TotalCube'  
                     END

                     -- Fit by Weight
                     IF '3' IN (@cpa_DimensionRestriction01, @cpa_DimensionRestriction02, @cpa_DimensionRestriction03,
                                @cpa_DimensionRestriction04, @cpa_DimensionRestriction05, @cpa_DimensionRestriction06)
                     BEGIN
                        SELECT @c_DimRestSQL = ''
                        IF RTRIM(@c_DimRestSQL) IS NULL OR RTRIM(@c_DimRestSQL) = ''
                           SELECT @c_DimRestSQL = ' HAVING '
                        ELSE
                           SELECT @c_DimRestSQL = RTRIM(@c_DimRestSQL) + ' AND '
                           
                        SELECT @c_DimRestSQL = RTRIM(@c_DimRestSQL) + ' MAX(LOC.WeightCapacity) - ' +
                                             '( ( SUM(ISNULL(LOTxLOCxID.Qty, 0)) - SUM(ISNULL(LOTxLOCxID.QtyPicked,0)) + SUM(ISNULL(LOTxLOCxID.PendingMoveIn,0))) ' +
                                             '* @n_StdGrossWgt ) >= (@n_StdGrossWgt * @n_Qty )'
                     END

                     -- Fit by BOMSKU Weight -- (ChewKP02)
                     IF '12' IN (@cpa_DimensionRestriction01, @cpa_DimensionRestriction02, @cpa_DimensionRestriction03,
                                 @cpa_DimensionRestriction04, @cpa_DimensionRestriction05, @cpa_DimensionRestriction06)
                     BEGIN
                        SELECT @c_DimRestSQL = ''
                        IF RTRIM(@c_DimRestSQL) IS NULL OR RTRIM(@c_DimRestSQL) = ''
                           SELECT @c_DimRestSQL = ' HAVING '
                        ELSE
                           SELECT @c_DimRestSQL = RTRIM(@c_DimRestSQL) + ' AND '

                        SET @npa_TotalWeight = @f_PPPalletTotStdGrossWgt
                        SELECT @c_DimRestSQL = RTRIM(@c_DimRestSQL) + ' MAX(LOC.WeightCapacity) - ' +
                                             ' dbo.fnc_GetInvBOMCube(2,LOC.LOC,'''') >= @npa_TotalWeight' 
                     END

                     SELECT @c_SelectSQL = RTRIM(@c_SelectSQL) + @c_DimRestSQL +
                                         ' ORDER BY LOC.PALogicalLOC, LOC.LOC '

                     -- to disable further checking of locationstaterestriction = '2'
                     IF @cpa_LocationStateRestriction1 = '2'
                        SELECT @cpa_LocationStateRestriction1 = ''
                     ELSE IF @cpa_LocationStateRestriction2 = '2'
                        SELECT @cpa_LocationStateRestriction2 = ''
                     ELSE
                        SELECT @cpa_LocationStateRestriction3 = ''

                     IF @cpa_DimensionRestriction01 IN ('1', '3')
                        SELECT @cpa_DimensionRestriction01 = '0'
                     IF @cpa_DimensionRestriction02 IN ('1', '3')
                        SELECT @cpa_DimensionRestriction02 = '0'
                     IF @cpa_DimensionRestriction03 IN ('1', '3')
                        SELECT @cpa_DimensionRestriction04 = '0'
                     IF @cpa_DimensionRestriction04 IN ('1', '3')
                        SELECT @cpa_DimensionRestriction04 = '0'
                     IF @cpa_DimensionRestriction05 IN ('1', '3')
                        SELECT @cpa_DimensionRestriction05 = '0'
                     IF @cpa_DimensionRestriction06 IN ('1', '3')
                        SELECT @cpa_DimensionRestriction06 = '0'
                  END -- do NOT mix skus

                  ELSE -- no location state restrictions
                  BEGIN
                     SELECT @c_SelectSQL =
                                       ' DECLARE Cur_PutawayLocation CURSOR FAST_FORWARD READ_ONLY FOR ' +
                                       ' SELECT LOC.LOC ' +
                                       ' FROM LOC (NOLOCK)  ' 
                     IF EXISTS (SELECT 1 FROM #t_PutawayZone)
                     BEGIN
                        SELECT @c_SelectSQL = @c_SelectSQL + ' JOIN #t_PutawayZone PZ ON LOC.PutawayZone = PZ.PutawayZone ' 
                     END                                  
                           
                     SELECT @c_SelectSQL = @c_SelectSQL +                         
                                       ' LEFT OUTER JOIN LOTxLOCxID WITH (NOLOCK) ON ( LOC.loc = LOTxLOCxID.LOC ) ' +
                                       ' LEFT OUTER JOIN SKU WITH (NOLOCK) ON (SKU.StorerKey = LOTxLOCxID.StorerKey AND SKU.SKU = LOTxLOCxID.SKU) ' +
                                       ' WHERE  LOC.Facility = @c_Facility ' +                                       
                                          ISNULL( RTRIM(@c_SQL_LocationFlagInclude), '') +
                                          ISNULL( RTRIM(@c_SQL_LocationFlagExclude), '') +
                                          ISNULL( RTRIM(@c_SQL_LocationTypeExclude), '') +
                                          ISNULL( RTRIM(@c_SQL_LocLevelInclude    ), '') +
                                          ISNULL( RTRIM(@c_SQL_LocLevelExclude    ), '') +
                                          ISNULL( RTRIM(@c_SQL_LocAisleInclude    ), '') +
                                          ISNULL( RTRIM(@c_SQL_LocAisleExclude    ), '') +
                                          ISNULL( RTRIM(@c_SQL_LocTypeRestriction ), '') +
                                          ISNULL( RTRIM(@c_SQL_LocStateRestriction ), '') + -- (SHONG01)
                                          ISNULL( RTRIM(@c_DimRestSQL), '') +  --(ung07)
                                          ISNULL( RTRIM(@cpa_PutCodeSQL),'') + --(ung06)
                                       CASE WHEN @cpa_PAType = '61' THEN ' AND LOC.LocAisle = @c_NextPnDAisle' ELSE '' END +
                                       ' GROUP BY LOC.PALogicalLOC, LOC.LOC '

                     SELECT @c_DimRestSQL = ''

                     -- Fit by Cube
                     IF '1' IN (@cpa_DimensionRestriction01, @cpa_DimensionRestriction02, @cpa_DimensionRestriction03,
                                @cpa_DimensionRestriction04, @cpa_DimensionRestriction05, @cpa_DimensionRestriction06)
                     BEGIN
                        SELECT @c_DimRestSQL = ''
                        IF RTRIM(@c_DimRestSQL) IS NULL OR RTRIM(@c_DimRestSQL) = ''
                           SELECT @c_DimRestSQL = ' HAVING '
                        ELSE
                           SELECT @c_DimRestSQL = RTRIM(@c_DimRestSQL) + ' AND '

                        SET @npa_TotalCube = @n_PalletTotStdCube
                        SELECT @c_DimRestSQL = RTRIM(@c_DimRestSQL) + ' MAX(LOC.CubicCapacity) - ' +
                                             ' SUM((ISNULL(LOTxLOCxID.Qty, 0) - ISNULL(LOTxLOCxID.QtyPicked,0) + ISNULL(LOTxLOCxID.PendingMoveIn,0))* ISNULL(SKU.STDCUBE,1)) ' +
                                             ' >= @npa_TotalCube'
                     END

                     -- Fit by BOMSKU Cube -- (ChewKP02)
                     IF '11' IN (@cpa_DimensionRestriction01, @cpa_DimensionRestriction02, @cpa_DimensionRestriction03,
                                 @cpa_DimensionRestriction04, @cpa_DimensionRestriction05, @cpa_DimensionRestriction06)
                     BEGIN
                        SELECT @c_DimRestSQL = ''
                        IF RTRIM(@c_DimRestSQL) IS NULL OR RTRIM(@c_DimRestSQL) = ''
                           SELECT @c_DimRestSQL = ' HAVING '
                        ELSE
                           SELECT @c_DimRestSQL = RTRIM(@c_DimRestSQL) + ' AND '

                        SET @npa_TotalCube = @f_PPalletTotStdCube
                        SELECT @c_DimRestSQL = RTRIM(@c_DimRestSQL) + ' MAX(LOC.CubicCapacity) - ' +
                                             ' dbo.fnc_GetInvBOMCube(1,LOC.LOC,'''') >=  @npa_TotalCube'
                     END

                     -- Fit by Weight
                     IF '3' IN (@cpa_DimensionRestriction01, @cpa_DimensionRestriction02, @cpa_DimensionRestriction03,
                                @cpa_DimensionRestriction04, @cpa_DimensionRestriction05, @cpa_DimensionRestriction06)
                     BEGIN
                        --SELECT @c_DimRestSQL = ''
                        IF RTRIM(@c_DimRestSQL) IS NULL OR RTRIM(@c_DimRestSQL) = ''
                           SELECT @c_DimRestSQL = ' HAVING '
                        ELSE
                           SELECT @c_DimRestSQL = RTRIM(@c_DimRestSQL) + ' AND '

                        SET @npa_TotalWeight = @n_PalletTotStdGrossWgt
                        SELECT @c_DimRestSQL = RTRIM(@c_DimRestSQL) + ' MAX(LOC.WeightCapacity) - ' +
                                             ' SUM((ISNULL(LOTxLOCxID.Qty, 0) - ISNULL(LOTxLOCxID.QtyPicked,0) + ' + 
                                             ' ISNULL(LOTxLOCxID.PendingMoveIn,0))* ISNULL(SKU.STDGROSSWGT,1)) >=  @npa_TotalWeight'
                     END

                     -- Fit by LxWxH
                     IF '2' IN (@cpa_DimensionRestriction01, @cpa_DimensionRestriction02, @cpa_DimensionRestriction03,
                                @cpa_DimensionRestriction04, @cpa_DimensionRestriction05, @cpa_DimensionRestriction06)
                        AND   @c_Loc_Type NOT IN ('PICK','CASE')
                        AND (@b_config_PALDIMCALC = '1')
                     BEGIN

                        IF RTRIM(@c_DimRestSQL) IS NULL OR RTRIM(@c_DimRestSQL) = ''
                           SELECT @c_DimRestSQL = ' HAVING '
                        ELSE
                           SELECT @c_DimRestSQL = RTRIM(@c_DimRestSQL) + ' AND '

                        SELECT @n_PalletWoodWidth  = PACK.PalletWoodWidth,
                               @n_PalletWoodLength = PACK.PalletWoodLength,
                               @n_PalletWoodHeight = PACK.PalletWoodHeight,
                               @n_CaseHeight = PACK.HeightUOM4
                        FROM PACK (NOLOCK)
                        WHERE PACK.Packkey = @c_PackKey

                        SET @n_IdCnt = 0;
                        SELECT @n_IdCnt = COUNT(DISTINCT ID)
                        FROM   LOTxLOCxID WITH (NOLOCK)
                        WHERE  StorerKey = @c_StorerKey
                          AND Loc = @c_ToLoc
                          AND (Qty > 0 OR PendingMoveIn > 0)
                        SET  @n_IdCnt = @n_IdCnt+1

                        SELECT @c_DimRestSQL = RTRIM(@c_DimRestSQL)
                                             +'(( ' + STR(@n_PalletWoodWidth) + ' * ' +STR(@n_IdCnt) + ' <= MAX(LOC.Width) AND ' + STR(@n_PalletWoodLength) +' <= MAX(LOC.Length))'
                                             +' OR '
                                             +'( ' + STR(@n_PalletWoodLength) + ' * ' +STR(@n_IdCnt) + ' <= MAX(LOC.Length) AND ' + STR(@n_PalletWoodWidth) +' <= MAX(LOC.Width)))'
                                             +' AND '
                                             +STR(@n_CaseHeight)+' + '+STR(@n_PalletWoodHeight)+' <= MAX(LOC.Height)'
                     END


                     --Fit by height
                     IF '5' IN (@cpa_DimensionRestriction01, @cpa_DimensionRestriction02, @cpa_DimensionRestriction03,
                                @cpa_DimensionRestriction04, @cpa_DimensionRestriction05, @cpa_DimensionRestriction06) AND (@b_config_PALDIMCALC = '1')
                     BEGIN

--                         SELECT @c_DimRestSQL = ''
                        IF RTRIM(@c_DimRestSQL) IS NULL OR RTRIM(@c_DimRestSQL) = ''
                           SELECT @c_DimRestSQL = ' HAVING '
                        ELSE
                        SELECT @c_DimRestSQL = RTRIM(@c_DimRestSQL) + ' AND '

                        SELECT @n_CaseHeight = PACK.HeightUOM4,
                               @n_PalletWoodHeight = PACK.PalletWoodHeight
                        FROM PACK (NOLOCK)
                        WHERE PACK.Packkey = @c_PackKey

                        SELECT @c_DimRestSQL = RTRIM(@c_DimRestSQL) + ' ('+STR(@n_CaseHeight)+' + '+STR(@n_PalletWoodHeight)+') <= MAX(LOC.Height)'
                     END

                     -- Fit by BOMSKU Weight -- (ChewKP02)
                     IF '12' IN (@cpa_DimensionRestriction01, @cpa_DimensionRestriction02, @cpa_DimensionRestriction03,
                                 @cpa_DimensionRestriction04, @cpa_DimensionRestriction05, @cpa_DimensionRestriction06)
                     BEGIN
                        SELECT @c_DimRestSQL = ''
                        IF RTRIM(@c_DimRestSQL) IS NULL OR RTRIM(@c_DimRestSQL) = ''
                           SELECT @c_DimRestSQL = ' HAVING '
                        ELSE
                           SELECT @c_DimRestSQL = RTRIM(@c_DimRestSQL) + ' AND '
                        
                        SET @npa_TotalWeight = @f_PPPalletTotStdGrossWgt
                        SELECT @c_DimRestSQL = RTRIM(@c_DimRestSQL) + ' MAX(LOC.WeightCapacity) - ' +
                                             ' dbo.fnc_GetInvBOMCube(2,LOC.LOC,'''') >= @npa_TotalWeight '
                     END

                     SELECT @c_SelectSQL = RTRIM(@c_SelectSQL) + @c_DimRestSQL +
                              ' ORDER BY LOC.PALogicalLOC, LOC.LOC '

                     -- to disable further checking of locationstaterestriction = '2'
                     IF @cpa_LocationStateRestriction1 = '2'
                        SELECT @cpa_LocationStateRestriction1 = ''
                     ELSE IF @cpa_LocationStateRestriction2 = '2'
                        SELECT @cpa_LocationStateRestriction2 = ''
                     ELSE
                        SELECT @cpa_LocationStateRestriction3 = ''

                     IF @cpa_DimensionRestriction01 IN ('1', '3')
                        SELECT @cpa_DimensionRestriction01 = '0'
                     IF @cpa_DimensionRestriction02 IN ('1', '3')
                        SELECT @cpa_DimensionRestriction02 = '0'
                     IF @cpa_DimensionRestriction03 IN ('1', '3')
                        SELECT @cpa_DimensionRestriction04 = '0'
                     IF @cpa_DimensionRestriction04 IN ('1', '3')
                        SELECT @cpa_DimensionRestriction04 = '0'
                     IF @cpa_DimensionRestriction05 IN ('1', '3')
                        SELECT @cpa_DimensionRestriction05 = '0'
                     IF @cpa_DimensionRestriction06 IN ('1', '3')
                        SELECT @cpa_DimensionRestriction06 = '0'
                  END  -- no location state restrictions

                  SELECT @c_ToLoc = SPACE(10)
                  SELECT @cpa_ToLoc = SPACE(10)

                  -- TITAN Project
                  -- Getting the Next Empty Pick AND Drop Location
                  -- This logic also cater the Load Balancing
                  -- Get the Pick & Drop Location in Outer 1st then Centre
                  IF @cpa_PAType = '61'
                  BEGIN
                     SET @c_LastPndAisle  = ''
                     SET @c_LastPnDLocCat = ''
                     SET @c_LastPnDLocZone = '' --(ung04)
                     SET @c_StartAisle    = ''
                     SET @n_LoopAllAisle = 0

                     DECLARE @t_ZoneAisle TABLE (LocAisle NVARCHAR(10) PRIMARY KEY CLUSTERED)
                     DELETE @t_ZoneAisle -- This is required. Table can exist and contain last run data (ung04)

                     INSERT INTO @t_ZoneAisle
                     SELECT DISTINCT LocAisle FROM LOC WITH (NOLOCK) WHERE PutawayZone = @cpa_PutawayZone01 AND @cpa_PutawayZone01 <> ''
                     UNION
                     SELECT DISTINCT LocAisle FROM LOC WITH (NOLOCK) WHERE PutawayZone = @cpa_PutawayZone02 AND @cpa_PutawayZone02 <> ''
                     UNION
                     SELECT DISTINCT LocAisle FROM LOC WITH (NOLOCK) WHERE PutawayZone = @cpa_PutawayZone03 AND @cpa_PutawayZone03 <> ''
                     UNION
                     SELECT DISTINCT LocAisle FROM LOC WITH (NOLOCK) WHERE PutawayZone = @cpa_PutawayZone04 AND @cpa_PutawayZone04 <> ''
                     UNION
                     SELECT DISTINCT LocAisle FROM LOC WITH (NOLOCK) WHERE PutawayZone = @cpa_PutawayZone05 AND @cpa_PutawayZone05 <> ''
                     UNION
                        SELECT DISTINCT LOC.LOCAisle
                        FROM CodeLKUP WITH (NOLOCK)
                           JOIN LOC WITH (NOLOCK) ON (LOC.PutawayZone = CodeLkup.Short)
                        WHERE ListName = 'PAStgLnExt'
                           AND Code LIKE RTRIM( @c_PutawayStrategyKey) + @c_PutawayStrategyLineNumber + '%'
                           AND Long = 'PutawayZone'

                     SELECT @c_MaxAisle = ISNULL(MAX(LocAisle), '')
                     FROM @t_ZoneAisle

                     -- Get last PND aisle used from TaskDetail
                     IF @c_LastPndAisle = ''
                     BEGIN
                        SELECT TOP 1
                                @c_LastPndAisle = L.LocAisle
                              , @c_LastPnDLocCat = L.LocationCategory
                              , @c_LastPnDLocZone = L.PutawayZone --(ung04)
                        FROM  TaskDetail td WITH (NOLOCK)
                         JOIN  LOC L WITH (NOLOCK) ON (L.LOC = td.ToLOC AND L.LocationCategory IN (N'PnD_Ctr' ,N'PnD_In', N'PnD')) --(ung08)
                           JOIN  @t_ZoneAisle ZoneAisle ON (ZoneAisle.LocAisle = L.LocAisle)
                        WHERE L.Facility = @c_Facility
                           AND td.TaskType IN (N'PA', N'PAF')
                           AND td.Status = '9'     --(ung04)
                        ORDER BY td.EditDate DESC --(ung04)

                        -- IF Last Pnd Aisle was the Last Aisle Then Start FROM Beginning
                        -- (Shong02)
                        IF @c_LastPndAisle=@c_MaxAisle AND @c_LastPnDLocCat='PnD_Ctr'
                        BEGIN
                           SET @c_LastPndAisle = ''
                           SET @c_LastPnDLocCat = ''
                           SET @c_LastPnDLocZone = '' --(ung04)
                        END

                        IF @b_Debug = 1
                        BEGIN
                           IF @c_LastPndAisle = ''
                           BEGIN
                              SELECT @c_Reason = 'INFO No last used aisle found.'
                              EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, '', @c_Reason
                           END
                           ELSE
                           BEGIN
                              SELECT @c_Reason = 'INFO Found last used aisle. LastAisle=' + RTRIM( @c_LastPndAisle)
                              EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, '', @c_Reason
                           END
                        END
                     END

                     BEGIN
                        GET_NEXT_AISLE_61:
                        SET @c_NextPnDLocation = ''
                        SET @c_NextPnDAisle    = ''
                        SET @c_NextPnDLocCat   = ''
                        SET @c_NextPnDLocZone  = '' --(ung04)

                        IF @b_Debug = 2
                        BEGIN
                           PRINT 'Find next aisle starts..'
                           PRINT '  > @c_LastPndAisle: ' + @c_LastPndAisle    
                                 + ', @c_LastPnDLocCat: ' + @c_LastPnDLocCat 
                                 + ', @c_LastPnDLocZone: ' + @c_LastPnDLocZone 
                                 + '@c_MaxAisle: ' + @c_MaxAisle 
                        END

                        IF @c_LastPnDLocCat IN (N'PnD_In', N'PnD') --(ung08)
                        BEGIN
                           SELECT TOP 1
                                  @c_NextPnDLocation = L.LOC
                                 ,@c_NextPnDAisle = L.LocAisle
                                 ,@c_NextPnDLocCat = L.LocationCategory
                           FROM   LOC L WITH (NOLOCK)
                           JOIN @t_ZoneAisle ZoneAisle ON (ZoneAisle.LocAisle = L.LocAisle)
                           WHERE  L.LocationCategory IN (N'PnD_Ctr' ,N'PnD_In', N'PnD') --(ung08)
                              AND L.Facility = @c_Facility
                              AND (
                                    L.LocAisle>@c_LastPndAisle
                                    OR L.LocAisle=@c_LastPndAisle
                                    AND L.LocationCategory=N'PnD_Ctr'
                                  )
                              AND L.PutawayZone <> @c_LastPnDLocZone --(ung04)
                              AND (SELECT COUNT(DISTINCT LLI.Id)
                                   FROM LOTxLOCxID LLI WITH (NOLOCK)
                                   WHERE LLI.Loc = L.Loc
                                   AND (LLI.QTY > 0 OR LLI.PendingMoveIN > 0)) < L.MaxPallet
                           ORDER BY
                                  L.LocAisle
                                 ,CASE
                               WHEN L.LocationCategory IN (N'PnD_In', N'PnD') THEN 1 --(ung08)
                                       ELSE 2
                                 END
                                 ,L.LogicalLocation
                                 ,L.LOC
                        END
                        ELSE
                        BEGIN
                           SELECT TOP 1
                                  @c_NextPnDLocation = L.LOC
                                 ,@c_NextPnDAisle = L.LocAisle
                                 ,@c_NextPnDLocCat = L.LocationCategory
                           FROM   LOC L WITH (NOLOCK)
                                  JOIN @t_ZoneAisle ZoneAisle ON (ZoneAisle.LocAisle = L.LocAisle)
                           WHERE  L.LocationCategory IN (N'PnD_Ctr' ,N'PnD_In', N'PnD') --(ung08)
                                  AND L.Facility = @c_Facility
                                  AND L.LocAisle > @c_LastPndAisle
                                  AND L.PutawayZone <> @c_LastPnDLocZone --(ung04)
                                  AND (SELECT COUNT(DISTINCT LLI.Id)
                                       FROM LOTxLOCxID LLI WITH (NOLOCK)
                                       WHERE LLI.Loc = L.Loc
                                       AND (LLI.QTY > 0 OR LLI.PendingMoveIN > 0)) < L.MaxPallet
                           ORDER BY
                                  L.LocAisle
                                 ,CASE
                                    WHEN L.LocationCategory IN (N'PnD_In', N'PnD') THEN 1 --(ung08)
                                    ELSE 2
                                  END
                                 ,L.LogicalLocation
                                 ,L.LOC
                        END

                        IF @b_Debug = 1
                        BEGIN
                           IF @c_NextPnDLocation = ''
                           BEGIN
                              SELECT @c_Reason = 'INFO No PND found after last used aisle.'
                              EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_NextPnDLocation, @c_Reason
                           END
                           ELSE
                           BEGIN
                              SELECT @c_Reason = 'INFO Found PND after last used aisle. LastAisle=' + RTRIM( @c_LastPndAisle) + ' NextAisle=' + RTRIM( @c_NextPnDAisle)
                              EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_NextPnDLocation, @c_Reason
                           END
                        END

                        IF @b_Debug = 2
                        BEGIN                        
                           PRINT 'Find next aisle after last task aisle' 
                           PRINT + '@c_NextPnDAisle: ' + @c_NextPnDAisle    
                                 + ' , @c_NextPnDLocation: ' + @c_NextPnDLocation 
                                 + ' , @c_NextPnDLocCat: ' + @c_NextPnDLocCat   
                                 + ' , @c_StartAisle: ' + @c_StartAisle      
                        END

                        -- If not found, find all aisle
                        IF LEN(@c_NextPnDLocation) = 0 OR @c_NextPnDLocation IS NULL
                        BEGIN
                           SET @n_LoopAllAisle = @n_LoopAllAisle + 1

                           SELECT TOP 1
                                  @c_NextPnDLocation = L.LOC
                                 ,@c_NextPnDAisle = L.LocAisle
                                 ,@c_NextPnDLocCat = L.LocationCategory
                           FROM   LOC L WITH (NOLOCK)
                           JOIN @t_ZoneAisle ZoneAisle ON (ZoneAisle.LocAisle = L.LocAisle)
                           WHERE  L.LocationCategory IN (N'PnD_Ctr' ,N'PnD_In', N'PnD') --(ung08)
                              AND L.Facility = @c_Facility
                              AND (SELECT COUNT(DISTINCT LLI.Id)
                                   FROM LOTxLOCxID LLI WITH (NOLOCK)
                                   WHERE LLI.Loc = L.Loc
                                   AND (LLI.QTY > 0 OR LLI.PendingMoveIN > 0)) < L.MaxPallet
                           ORDER BY
                                  L.LocAisle
                                 ,CASE
                                    WHEN L.LocationCategory IN (N'PnD_In', N'PnD') THEN 1 --(ung08)
                                    ELSE 2
                                  END
                                 ,L.LogicalLocation
                                 ,L.LOC

                           IF @b_Debug = 1
                           BEGIN
                              IF @c_NextPnDLocation = ''
                              BEGIN
                                 SELECT @c_Reason = 'INFO No PND found in all aisle'
                                 EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_NextPnDLocation, @c_Reason
                              END
                              ELSE
                              BEGIN
                                 SELECT @c_Reason = 'INFO Found PND in all aisle. Aisle=' + RTRIM( @c_NextPnDAisle)
                                 EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_NextPnDLocation, @c_Reason
                              END
                           END
                        END
                     END

                     SET @c_PickAndDropLoc = @c_NextPnDLocation
                     IF @b_Debug = 2
                     BEGIN
                           PRINT 'Find next aisle in all aisle..'
                           PRINT '  > @c_NextPnDAisle: ' + @c_NextPnDAisle    
                                 + ', @c_NextPnDLocation: ' + @c_NextPnDLocation 
                                 + ', @c_NextPnDLocCat: ' + @c_NextPnDLocCat 
                                 + ', @c_StartAisle: ' + @c_StartAisle 
                        
                     END


                     IF LEN(@c_NextPnDAisle) = 0 OR
                        (@c_StartAisle = @c_NextPnDAisle AND LEN(@c_NextPnDAisle) > 0)
                     BEGIN
                        SET @b_GotLoc = 0
                        IF @b_Debug = 1
                        BEGIN
                           SELECT @c_Reason = 'FAILED PAType=61: Pick AND Drop Location NOT Available'
                           EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
                        END
                        SELECT @b_RestrictionsPassed = 0
                        --GOTO LOCATION_EXIT --(ung04)
                        CONTINUE             --(ung04)
                     END
                  END-- PAType '61'
                  ELSE
                  BEGIN
                     SET @c_PickAndDropLoc = ''
                     SET @c_FitCasesInAisle = ''
                  END

                  IF CHARINDEX('@c_NextPnDAisle', @c_SQLParms) = 0
                  BEGIN
                     SET @c_SQLParms = @c_SQLParms 
                                     + N',@c_NextPnDAisle NVARCHAR(10)'                     
                  END

                  IF @b_Debug = 2
                  BEGIN
                     PRINT '>>> 4 ' + @c_SelectSQL
                  END
                                                      
                  EXEC sp_ExecuteSql @c_SelectSQL
                     , @c_SQLParms
                     , @c_StorerKey 
                     , @c_Facility
                     , @c_SKU       
                     , @c_LOT       
                     , @c_FromLoc   
                     , @c_ID        
                     , @n_Qty       
                     , @n_StdGrossWgt
                     , @cpa_LocationTypeExclude01  
                     , @cpa_LocationTypeExclude02  
                     , @cpa_LocationTypeExclude03  
                     , @cpa_LocationTypeExclude04  
                     , @cpa_LocationTypeExclude05  
                     , @cpa_LocationCategoryExclude01 
                     , @cpa_LocationCategoryExclude02 
                     , @cpa_LocationCategoryExclude03 
                     , @cpa_LocationCategoryInclude01 
                     , @cpa_LocationCategoryInclude02 
                     , @cpa_LocationCategoryInclude03 
                     , @cpa_LocationHandlingInclude01 
                     , @cpa_LocationHandlingInclude02 
                     , @cpa_LocationHandlingInclude03 
                     , @cpa_LocationHandlingExclude01  
                     , @cpa_LocationHandlingExclude02  
                     , @cpa_LocationHandlingExclude03  
                     , @cpa_LocationFlagInclude01     
                     , @cpa_LocationFlagInclude02     
                     , @cpa_LocationFlagInclude03     
                     , @cpa_LocationFlagExclude01
                     , @cpa_LocationFlagExclude02
                     , @cpa_LocationFlagExclude03   
                     , @npa_LocLevelInclude01   
                     , @npa_LocLevelInclude02   
                     , @npa_LocLevelInclude03   
                     , @npa_LocLevelInclude04   
                     , @npa_LocLevelInclude05   
                     , @npa_LocLevelInclude06   
                     , @npa_LocLevelExclude01   
                     , @npa_LocLevelExclude02   
                     , @npa_LocLevelExclude03   
                     , @npa_LocLevelExclude04   
                     , @npa_LocLevelExclude05   
                     , @npa_LocLevelExclude06   
                     , @cpa_LocAisleInclude01  
                     , @cpa_LocAisleInclude02  
                     , @cpa_LocAisleInclude03  
                     , @cpa_LocAisleInclude04  
                     , @cpa_LocAisleInclude05  
                     , @cpa_LocAisleInclude06  
                     , @cpa_LocAisleExclude01  
                     , @cpa_LocAisleExclude02  
                     , @cpa_LocAisleExclude03  
                     , @cpa_LocAisleExclude04  
                     , @cpa_LocAisleExclude05  
                     , @cpa_LocAisleExclude06  
                     , @npa_TotalCube    
                     , @npa_TotalWeight                       
                     , @cpa_LocationTypeRestriction01
                     , @cpa_LocationTypeRestriction02
                     , @cpa_LocationTypeRestriction03
                     -- Add Extra Paramaters Here                     
                     , @c_NextPnDAisle
                     
                  SELECT @c_ToLoc = ''
                  OPEN Cur_PutawayLocation

                  FETCH NEXT FROM Cur_PutawayLocation INTO @c_ToLoc
                  WHILE @@FETCH_STATUS <> -1
                  BEGIN

                     IF @b_Debug = 2
                     BEGIN
                        PRINT @c_SelectSQL
                        PRINT '>> Last Loc:' + @cpa_ToLoc +  ', @c_ToLoc: ' + @c_ToLoc 
                     END

                     IF ISNULL(RTRIM(@c_ToLoc),'') = ''
                     BEGIN
                        IF @cpa_PAType = '61'
                        BEGIN
                           IF @c_NextPnDAisle <> @c_StartAisle
                           BEGIN
                              IF @b_Debug = 2
                              BEGIN
                                 PRINT '> @c_StartAisle: ' + @c_StartAisle + ', @c_NextPnDAisle: ' + @c_NextPnDAisle 
                              END

                              --(Vicky03) - Start
                              IF ISNULL(RTRIM(@c_StartAisle),'') = ''
                              BEGIN
                                 SET @c_StartAisle = @c_NextPnDAisle
                                 SET @c_LastPnDLocCat = '' --(Vicky03) - Start
                                 SET @c_LastPnDLocZone = '' --(ung04)
                              END
                              ELSE
                              BEGIN
                                 SET @c_LastPnDLocCat = @c_NextPnDLocCat -- (SHONG02)
                                 SET @c_LastPnDLocZone = @c_NextPnDLocZone --(ung04)
                              END
                              --(Vicky03) - END

                              SET @c_LastPndAisle = @c_NextPnDAisle
                              --SET @c_LastPnDLocCat = @c_NextPnDLocCat -- (SHONG02)
                              --SET @c_LastPnDLocCat = ''
                              SET @cpa_ToLoc = ''

                              IF @b_Debug = 2
                              BEGIN
                                 PRINT '> @c_StartAisle: ' + @c_StartAisle  
                                       + ', @c_LastPndAisle: ' + @c_LastPndAisle  
                                       + ', @c_LastPnDLocCat: ' + @c_LastPnDLocCat 
                                       + ', @cpa_ToLoc: ' + @cpa_ToLoc       
                              END
                              GOTO GET_NEXT_AISLE_61
                           END
                           ELSE
                              BREAK
                        END -- PAType = '61'
                        ELSE
                           BREAK
                     END -- IF ISNULL(RTRIM(@c_ToLoc),'') = ''

                     IF @cpa_ToLoc = @c_ToLoc
                        BREAK

                     SELECT @cpa_ToLoc = @c_ToLoc
                     SELECT @n_LocsReviewed = @n_LocsReviewed + 1

                     IF @cpa_CheckRestrictions = 'Y'
                     BEGIN
                        SELECT @b_RestrictionsPassed = 0
                        GOTO PA_CHECKRESTRICTIONS

                        PATYPE02_BYLOC_A:
                        IF @b_Debug = 2
                        BEGIN
                           PRINT '> @b_RestrictionsPassed: ' + CAST(@b_RestrictionsPassed AS VARCHAR) 
                        END

                        IF @b_RestrictionsPassed = 1
                        BEGIN
                           SELECT @b_GotLoc = 1
                           BREAK
                        END
                     END
                     ELSE
                     BEGIN
                        SELECT @b_GotLoc = 1
                        BREAK
                     END

                     FETCH NEXT FROM Cur_PutawayLocation INTO @c_ToLoc
                  END -- WHILE (1=1)
                  CLOSE Cur_PutawayLocation
                  DEALLOCATE Cur_PutawayLocation

                  IF @b_GotLoc = 1
                  BEGIN
                     IF @b_Debug = 1
                     BEGIN
                        SELECT @c_Reason = 'FOUND PAType=' + @cpa_PAType + ': Search Type by Location'
                        EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                                    @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                                    @c_ToLoc, @c_Reason
                        
                     END                     
                     BREAK
                  END
                  BEGIN
                     IF @cpa_PAType = '61'
                     BEGIN
                        -- StartAisle condition might changed (by another user) and never become next aisle, so @n_LoopAllAisle control all aisle only loop once
                        IF (@c_NextPnDAisle <> @c_StartAisle) AND (@n_LoopAllAisle < 2)
                        BEGIN
                           IF @b_Debug = 2
                    BEGIN
                              PRINT '> @c_StartAisle: ' + @c_StartAisle 
                                 + ', @c_NextPnDAisle: ' + @c_NextPnDAisle 
                           END

                           --(Vicky03) - Start
                           IF ISNULL(RTRIM(@c_StartAisle),'') = ''
                           BEGIN
                              SET @c_StartAisle = @c_NextPnDAisle
                              SET @c_LastPnDLocCat = '' --(Vicky03) - Start
                              SET @c_LastPnDLocZone = '' --(ung04)
                           END
                           ELSE
                           BEGIN
                              SET @c_LastPnDLocCat = @c_NextPnDLocCat -- (SHONG02)
                              SET @c_LastPnDLocZone = @c_NextPnDLocZone --(ung04)
                           END
                           --(Vicky03) - END

                           SET @c_LastPndAisle = @c_NextPnDAisle
                           --SET @c_LastPnDLocCat = @c_NextPnDLocCat -- (SHONG02)
                           --SET @c_LastPnDLocCat = ''
                           SET @cpa_ToLoc = ''

                           IF @b_Debug = 2
                           BEGIN
                              PRINT '> @c_StartAisle: ' + @c_StartAisle  
                                    + ', @c_LastPndAisle: ' + @c_LastPndAisle  
                                    + ', @c_LastPnDLocCat: ' + @c_LastPnDLocCat 
                                    + ', @cpa_ToLoc: ' + @cpa_ToLoc                                     
                           END
                           GOTO GET_NEXT_AISLE_61
                        END
                        ELSE
                           BREAK
                     END
                  END

               END -- END of PAType = 02, 04, 12, 61
               ELSE IF @cpa_PAType IN ('16', '17', '18', '19', '21', '22', '23', '24', '30', '32', '34', '42', '44', '52', '54',
                                       '55', '56', '57', '58', '59','62','63') -- (ChewKP07) --NJOW01 -- SHONG01
               BEGIN
                  SELECT @cpa_ToLoc = SPACE(10)
                  SELECT @n_RowCount = 0

                  IF @cpa_PAType IN ('16', '18', '21')
                  BEGIN                     
                     SELECT @c_SelectSQL = N' DECLARE CUR_PUTAWAYLOCATION CURSOR FAST_FORWARD READ_ONLY FOR ' +
                                       ' SELECT LOC.loc, '''' AS HostWhCode    ' +
                                       ' FROM LOTxLOCxID (NOLOCK) ' +
                                       ' JOIN LOC (NOLOCK) on LOTxLOCxID.loc = LOC.loc ' 

                     IF EXISTS (SELECT 1 FROM #t_PutawayZone)
                     BEGIN
                        SELECT @c_SelectSQL = @c_SelectSQL + ' JOIN #t_PutawayZone PZ ON LOC.PutawayZone = PZ.PutawayZone ' 
                     END                                  
                           
                     SELECT @c_SelectSQL = @c_SelectSQL +                         
                                       ' JOIN LotAttribute (NOLOCK) ON LotAttribute.LOT = LOTxLOCxID.LOT ' + 
                                       CASE WHEN @cpa_PAType = '21'
                                          THEN ' WHERE (Qty > 0 OR PendingMoveIn > 0) '
                                          ELSE ' WHERE Qty > 0 '
                                       END +
                                       ' AND LOTxLOCxID.sku = @c_SKU ' +
                                       ' AND LOTxLOCxID.StorerKey = @c_StorerKey' +
                                       ' AND LOC.Facility = @c_Facility' +
                                       @c_SQL_LocationCategoryExclude + 
                                       @c_SQL_LocationCategoryInclude + 
                                       @c_SQL_LocationFlagInclude     + 
                                       @c_SQL_LocationFlagExclude     +
                                       @c_SQL_LocationTypeExclude     +
                                       ISNULL( RTRIM(@c_SQL_LocTypeRestriction ), '') +   
                                       CASE WHEN 'DRIVEIN' IN (@cpa_LocationCategoryInclude01, @cpa_LocationCategoryInclude02,
                                                               @cpa_LocationCategoryInclude03)
                                                           AND @c_LOT <> '' AND @c_LOT IS NOT NULL
                                             THEN ' AND LotAttribute.Lottable02 = @c_Lottable02 ' +
                                                  ' AND LotAttribute.Lottable01 = @c_Lottable01 '
                                          ELSE ''
                                       END +
                                       CASE WHEN 'DOUBLEDEEP' IN (@cpa_LocationCategoryInclude01,
                                                                  @cpa_LocationCategoryInclude02,
                                                                  @cpa_LocationCategoryInclude03)
                                                              AND @c_LOT <> '' AND @c_LOT IS NOT NULL
                                             THEN ' AND LotAttribute.Lottable02 = @c_Lottable02 ' +
                                                  ' AND LotAttribute.Lottable04 = @d_Lottable04 '
                                          ELSE ''
                                       END +
                                       CASE WHEN @cpa_PutCodeSQL <> '' THEN RTRIM( @cpa_PutCodeSQL) ELSE '' --(ung06)
                                       END +
                                       ' GROUP BY LOC.PALogicalLoc, LOC.LOC, LOC.MaxPallet ' +
                                       CASE WHEN '4' IN (@cpa_LocationStateRestriction1,
                                                         @cpa_LocationStateRestriction2,
                                                         @cpa_LocationStateRestriction3)
                                        THEN ' HAVING COUNT(DISTINCT LOTxLOCxID.ID) < LOC.MaxPallet '
                                          ELSE ''
                                       END +
                                       ' ORDER BY LOC.PALogicalLoc, LOC.LOC '

                     SET @c_SQLParms = RTRIM(@c_SQLParms) + 
                                        ', @c_Lottable01 NVARCHAR(18)' +
                                        ', @c_Lottable02 NVARCHAR(18)' +
                                        ', @d_Lottable04 DATETIME '

                     IF @b_Debug = 2
                     BEGIN
                        PRINT 'PA Type: ' + @cpa_PAType 
                        PRINT '>> SQL: ' + @c_SelectSQL
                        PRINT '>> Parm: ' + @c_SQLParms 
                     END
                                                          
                     EXEC sp_ExecuteSql @c_SelectSQL
                     , @c_SQLParms
                     , @c_StorerKey 
                     , @c_Facility
                     , @c_SKU       
                     , @c_LOT       
                     , @c_FromLoc   
                     , @c_ID        
                     , @n_Qty       
                     , @n_StdGrossWgt
                     , @cpa_LocationTypeExclude01  
                     , @cpa_LocationTypeExclude02  
                     , @cpa_LocationTypeExclude03  
                     , @cpa_LocationTypeExclude04  
                     , @cpa_LocationTypeExclude05  
                     , @cpa_LocationCategoryExclude01 
                     , @cpa_LocationCategoryExclude02 
                     , @cpa_LocationCategoryExclude03 
                     , @cpa_LocationCategoryInclude01 
                     , @cpa_LocationCategoryInclude02 
                     , @cpa_LocationCategoryInclude03 
                     , @cpa_LocationHandlingInclude01 
                     , @cpa_LocationHandlingInclude02 
                     , @cpa_LocationHandlingInclude03 
                     , @cpa_LocationHandlingExclude01  
                     , @cpa_LocationHandlingExclude02  
                     , @cpa_LocationHandlingExclude03  
                     , @cpa_LocationFlagInclude01     
                     , @cpa_LocationFlagInclude02     
                     , @cpa_LocationFlagInclude03     
                     , @cpa_LocationFlagExclude01
                     , @cpa_LocationFlagExclude02
                     , @cpa_LocationFlagExclude03   
                     , @npa_LocLevelInclude01   
                     , @npa_LocLevelInclude02   
                     , @npa_LocLevelInclude03   
                     , @npa_LocLevelInclude04   
                     , @npa_LocLevelInclude05   
                     , @npa_LocLevelInclude06   
                     , @npa_LocLevelExclude01   
                     , @npa_LocLevelExclude02   
                     , @npa_LocLevelExclude03   
                     , @npa_LocLevelExclude04   
                     , @npa_LocLevelExclude05   
                     , @npa_LocLevelExclude06   
                     , @cpa_LocAisleInclude01  
                     , @cpa_LocAisleInclude02  
                     , @cpa_LocAisleInclude03  
                     , @cpa_LocAisleInclude04  
                     , @cpa_LocAisleInclude05  
                     , @cpa_LocAisleInclude06  
                     , @cpa_LocAisleExclude01  
                     , @cpa_LocAisleExclude02  
                     , @cpa_LocAisleExclude03  
                     , @cpa_LocAisleExclude04  
                     , @cpa_LocAisleExclude05  
                     , @cpa_LocAisleExclude06  
                     , @npa_TotalCube 
                     , @npa_TotalWeight 
                     , @cpa_LocationTypeRestriction01
                     , @cpa_LocationTypeRestriction02
                     , @cpa_LocationTypeRestriction03
                     -- Add Extra Paramaters Here                       
                     , @c_Lottable01 
                     , @c_Lottable02 
                     , @d_Lottable04  

                     -- Chekcing
                     IF @b_Debug = 2
                     BEGIN
                        PRINT '>> Storerkey is ' + @c_Storerkey + ', Sku is ' + @c_SKU + ', Facility is ' + @c_Facility
                        PRINT '>> PAType is ' + @cpa_PAType + ', ToLoc is ' + @cpa_ToLoc
                        PRINT '>> PutCodeSQL: ' + @cpa_PutCodeSQL
                     END
                  END -- END of @cpa_PAType = 16, 18, 21

                  -- Added by MaryVong on 16-Jun-2005 (SOS36712 KCPI) -Start(1)
                  -- Empty location
                  IF @cpa_PAType = '17' OR @cpa_PAType = '19'
                  BEGIN
                      SET @cpa_ToLoc = ISNULL(@cpa_ToLoc,'')  
                                         
                      SELECT @c_SelectSQL = 
                        ' DECLARE CUR_PUTAWAYLOCATION CURSOR FAST_FORWARD READ_ONLY FOR ' +
                        ' SELECT LOC.loc, '''' AS HostWhCode ' +
                        ' FROM LOC WITH (NOLOCK) ' 
                        
                     IF EXISTS (SELECT 1 FROM #t_PutawayZone)
                     BEGIN
                        SELECT @c_SelectSQL = @c_SelectSQL + ' JOIN #t_PutawayZone PZ ON LOC.PutawayZone = PZ.PutawayZone ' 
                     END                                  
                           
                     SELECT @c_SelectSQL = @c_SelectSQL +                         
                        ' LEFT OUTER JOIN SKUxLOC WITH (NOLOCK) ON (SKUxLOC.LOC = LOC.LOC) ' +
                        ' WHERE LOC.LOC >  @cpa_ToLoc ' +
                        ' AND LOC.Facility = @c_Facility' +
                        ISNULL( RTRIM(@c_SQL_LocationCategoryExclude ), '') + 
                        ISNULL( RTRIM(@c_SQL_LocationCategoryInclude ), '') + 

                        ISNULL( RTRIM(@c_SQL_LocationFlagInclude ), '')     +
                        ISNULL( RTRIM(@c_SQL_LocationFlagExclude ), '')     +
                        ISNULL( RTRIM(@c_SQL_LocationTypeExclude ), '')     +
                        ISNULL( RTRIM(@c_SQL_LocTypeRestriction ), '') +
                        CASE WHEN ISNULL(@cpa_PutCodeSQL,'') <> '' THEN RTRIM(@cpa_PutCodeSQL) END + --(ung06)
                        ' GROUP BY LOC.PALogicalLoc, LOC.LOC ' +
                        ' HAVING SUM(SKUxLOC.Qty - SKUxLOC.QtyPicked) = 0 OR SUM(SKUxLOC.Qty - SKUxLOC.QtyPicked) IS NULL ' +
                        ' ORDER BY LOC.PALogicalLoc, LOC.LOC '

                     IF @b_Debug = 2
                     BEGIN
                        PRINT 'PA Type: ' + @cpa_PAType + ' >>> ' + @c_SelectSQL
                     END

                     IF CHARINDEX('@cpa_ToLoc', @c_SQLParms) = 0
                     BEGIN
                        SET @c_SQLParms = @c_SQLParms + N', @cpa_ToLoc NVARCHAR(10)'
                     END

                     EXEC sp_ExecuteSql @c_SelectSQL
                     , @c_SQLParms 
                     , @c_StorerKey 
                     , @c_Facility
                     , @c_SKU       
                     , @c_LOT       
                     , @c_FromLoc   
                     , @c_ID        
                     , @n_Qty       
                     , @n_StdGrossWgt
                     , @cpa_LocationTypeExclude01  
                     , @cpa_LocationTypeExclude02  
                     , @cpa_LocationTypeExclude03  
                     , @cpa_LocationTypeExclude04  
                     , @cpa_LocationTypeExclude05  
                     , @cpa_LocationCategoryExclude01 
                     , @cpa_LocationCategoryExclude02 
                     , @cpa_LocationCategoryExclude03 
                     , @cpa_LocationCategoryInclude01 
                     , @cpa_LocationCategoryInclude02 
                     , @cpa_LocationCategoryInclude03 
                     , @cpa_LocationHandlingInclude01 
                     , @cpa_LocationHandlingInclude02 
                     , @cpa_LocationHandlingInclude03 
                     , @cpa_LocationHandlingExclude01  
                     , @cpa_LocationHandlingExclude02  
                     , @cpa_LocationHandlingExclude03  
                     , @cpa_LocationFlagInclude01     
                     , @cpa_LocationFlagInclude02     
                     , @cpa_LocationFlagInclude03     
                     , @cpa_LocationFlagExclude01
                     , @cpa_LocationFlagExclude02
                     , @cpa_LocationFlagExclude03
                     , @npa_LocLevelInclude01   
                     , @npa_LocLevelInclude02   
                     , @npa_LocLevelInclude03   
                     , @npa_LocLevelInclude04   
                     , @npa_LocLevelInclude05   
                     , @npa_LocLevelInclude06   
                     , @npa_LocLevelExclude01   
                     , @npa_LocLevelExclude02   
                     , @npa_LocLevelExclude03   
                     , @npa_LocLevelExclude04   
                     , @npa_LocLevelExclude05   
                     , @npa_LocLevelExclude06   
                     , @cpa_LocAisleInclude01  
                     , @cpa_LocAisleInclude02  
                     , @cpa_LocAisleInclude03  
                     , @cpa_LocAisleInclude04  
                     , @cpa_LocAisleInclude05  
                     , @cpa_LocAisleInclude06  
                     , @cpa_LocAisleExclude01  
                     , @cpa_LocAisleExclude02  
                     , @cpa_LocAisleExclude03  
                     , @cpa_LocAisleExclude04  
                     , @cpa_LocAisleExclude05  
                     , @cpa_LocAisleExclude06
                     , @npa_TotalCube 
                     , @npa_TotalWeight           
                     , @cpa_LocationTypeRestriction01
                     , @cpa_LocationTypeRestriction02
                     , @cpa_LocationTypeRestriction03
                     , @cpa_ToLoc
                     
                     -- Chekcing
                     IF @b_Debug = 2
                     BEGIN
                        PRINT '>  @c_Facility: ' + @c_Facility  
                        + ', @cpa_PAType: ' + @cpa_PAType 
                        + ', @cpa_ToLoc: ' + @cpa_ToLoc      
                        
                        PRINT '>  #t_PutawayZone'
                        SELECT * FROM #t_PutawayZone AS tpz WITH(NOLOCK)               
                     END
                  END -- @cpa_PAType = '17' OR @cpa_PAType = '19'

                  -- (ChewKP07)
                  -- Empty location
                  IF @cpa_PAType = '62'
                  BEGIN

                      SELECT @c_SelectSQL = +
                        ' DECLARE CUR_PUTAWAYLOCATION CURSOR FAST_FORWARD READ_ONLY FOR ' +
                        ' SELECT LOC.loc, '''' AS HostWhCode    ' +
                        ' FROM LOC WITH (NOLOCK) ' 

                     IF EXISTS (SELECT 1 FROM #t_PutawayZone)
                     BEGIN
                        SELECT @c_SelectSQL = @c_SelectSQL + ' JOIN #t_PutawayZone PZ ON LOC.PutawayZone = PZ.PutawayZone ' 
                     END                                  
                           
                     SELECT @c_SelectSQL = @c_SelectSQL +                         
                        --' LEFT OUTER JOIN LOTxLOCxID WITH (NOLOCK, INDEX=IDX_LOTxLOCxID_LOC) ON (LotxLocxID.Loc = Loc.Loc) ' +    --kocy01
                        ' LEFT OUTER JOIN LOTxLOCxID WITH (NOLOCK) ON (LotxLocxID.Loc = Loc.Loc) ' +
                        ' WHERE LOC.LOC > @cpa_ToLoc ' +
                        ' AND   LOC.Facility = @c_Facility' +
                        CASE WHEN @cpa_PutCodeSQL <> '' THEN RTRIM( @cpa_PutCodeSQL) END + --(ung06)
                        ' GROUP BY LOC.PALogicalLoc, LOC.LOC ' +
                        ' HAVING SUM( ISNULL(LotxLocxID.Qty,0) - ISNULL(LotxLocxID.QtyPicked,0))= 0 ' +
                        ' AND SUM(ISNULL(LotxLocxID.PendingMoveIn,0) ) = 0' +
                        ' AND SUM(ISNULL(LotxLocxID.QtyExpected,0)) = 0' +
                        ' ORDER BY LOC.PALogicalLoc, LOC.LOC '


                     IF @b_Debug = 2
                     BEGIN
                        PRINT 'PA Type: ' + @cpa_PAType + ' >>> ' + @c_SelectSQL
                     END

                     EXEC sp_ExecuteSql @c_SelectSQL, N'@c_Facility NVARCHAR(5), @cpa_ToLoc NVARCHAR(10) ', @c_Facility, @cpa_ToLoc

                     -- Chekcing
                     IF @b_Debug = 2
                     BEGIN
                        PRINT '>  @c_Facility: ' + @c_Facility  
                        + ', @cpa_PAType: ' + @cpa_PAType 
                        + ', @cpa_ToLoc: ' + @cpa_ToLoc
                                 
                        PRINT '>  #t_PutawayZone'
                        SELECT * FROM #t_PutawayZone AS tpz WITH(NOLOCK)               
                                              
                     END
                  END -- @cpa_PAType = '62'

                  -- Added by MaryVong on 16-Jun-2005 (SOS36712 KCPI) -END(1)
                  IF @cpa_PAType = '22' OR @cpa_PAType = '24'
                  BEGIN
                     DECLARE CUR_PUTAWAYLOCATION CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                     SELECT LOC.LOC, '' AS HostWhCode
                     FROM LOC WITH (NOLOCK)
                     LEFT OUTER JOIN SKUxLOC WITH (NOLOCK) ON (LOC.LOC = SKUxLOC.LOC)
                     JOIN CODELKUP WITH (NOLOCK) ON ( LOC.LocationCategory = CODELKUP.CODE
                                                 AND CODELKUP.LISTNAME = 'LOCCATEGRY'
                                                 AND CODELKUP.SHORT = 'S')
                     WHERE
                     LOC.PutawayZone = @c_SearchZone

                     AND LOC.Facility = @c_Facility -- CDC Migration
                     GROUP BY LOC.PALogicalLoc, LOC.LOC
                     HAVING SUM(SKUxLOC.Qty) = 0 OR SUM(SKUxLOC.Qty) IS NULL
                     ORDER BY LOC.PALogicalLoc, LOC.LOC

                     SELECT @n_RowCount = @@ROWCOUNT
                  END -- @cpa_PAType = '22' OR @cpa_PAType = '24'

                  IF @cpa_PAType = '32' OR @cpa_PAType = '34'
                  BEGIN
                     DECLARE CUR_PUTAWAYLOCATION CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                     SELECT LOC.LOC, '' AS HostWhCode
                     FROM SKUxLOC (NOLOCK)
                     JOIN LOC WITH (NOLOCK) ON LOC.Loc = SKUxLOC.Loc
                     JOIN (SELECT LOC.LOC FROM LOC (NOLOCK)
                           JOIN CODELKUP WITH (NOLOCK) ON (LOC.LocationCategory = CODELKUP.CODE
                                                 AND CODELKUP.LISTNAME = 'LOCCATEGRY'
                                                 AND CODELKUP.SHORT = 'M')
                           JOIN SKUxLOC WITH (NOLOCK) ON (SKUxLOC.LOC = LOC.LOC
                                                AND SKUxLOC.Qty - SKUxLOC.QtyPicked  > 0)
                           WHERE SKUxLOC.StorerKey = @c_StorerKey
                           AND   SKUxLOC.SKU = @c_SKU
                           AND   LOC.PutawayZone = @c_SearchZone
                           AND   LOC.Facility = @c_Facility -- CDC Migration
                           GROUP BY LOC.PALogicalLoc, LOC.LOC
                           HAVING COUNT(LOC.LOC) = 1) AS SINGLE_SKU ON (SKUxLOC.LOC = SINGLE_SKU.LOC)
                     GROUP BY LOC.PALogicalLoc, LOC.Loc
                     ORDER BY LOC.PALogicalLoc, LOC.Loc

                     --SELECT @n_RowCount = @@ROWCOUNT
                  END -- @cpa_PAType = '32' OR @cpa_PAType = '34'

                  IF @cpa_PAType = '42' OR @cpa_PAType = '44'
                  BEGIN

                     --SELECT @n_RowCount = @@ROWCOUNT
                     DECLARE CUR_PUTAWAYLOCATION CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                     SELECT LOC.LOC, '' AS HostWhCode
                     FROM LOC (NOLOCK)
                     LEFT OUTER JOIN SKUxLOC WITH (NOLOCK) ON (SKUxLOC.LOC = LOC.LOC)
                     JOIN CODELKUP WITH (NOLOCK) ON (LOC.LocationCategory = CODELKUP.CODE
                                                 AND CODELKUP.LISTNAME = 'LOCCATEGRY'
                                                 AND CODELKUP.SHORT = 'M')
                     WHERE LOC.PutawayZone = @c_SearchZone
                     AND   LOC.Facility = @c_Facility -- CDC Migration
                     GROUP BY LOC.PALogicalLoc, LOC.LOC
                     HAVING SUM(SKUxLOC.Qty - SKUxLOC.QtyPicked) = 0 OR SUM(SKUxLOC.Qty - SKUxLOC.QtyPicked) IS NULL
                     ORDER BY LOC.PALogicalLoc, LOC.LOC

                  END -- @cpa_PAType = '42' OR @cpa_PAType = '44'

                  IF @cpa_PAType = '52' OR @cpa_PAType = '54'
                  BEGIN
                     -- (Shong02) Comment this section, replace with Dynamic SQL and Performance Tuning
                     --DECLARE CUR_PUTAWAYLOCATION CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                     --SELECT LOC.LOC, '' AS HostWhCode
                     --FROM LOTxLOCxID WITH (NOLOCK)
                     --JOIN SKUxLOC WITH (NOLOCK) ON (SKUxLOC.StorerKey = LOTxLOCxID.StorerKey
                     --                           AND SKUxLOC.sku = LOTxLOCxID. sku
                     --                           AND SKUxLOC.StorerKey = @c_StorerKey
                     --                           AND SKUxLOC.sku = @c_SKU
                     --                           AND SKUxLOC.loc = LOTxLOCxID.loc)
                     --JOIN LotAttribute WITH (NOLOCK) ON (LOTxLOCxID.Lot = LotAttribute.lot)
                     --JOIN (SELECT Lottable02, Lottable04 FROM LotAttribute WITH (NOLOCK)
                     --      JOIN LOTxLOCxID WITH (NOLOCK) ON (LOTxLOCxID.LOT = LotAttribute.LOT)
                     --      WHERE LOTxLOCxID.Qty > 0) AS L
                     --            ON (L.Lottable02 = LotAttribute.Lottable02 AND L.Lottable04 = LotAttribute.Lottable04)
                     --JOIN LOC WITH (NOLOCK) ON (LOTxLOCxID.Loc = LOC.Loc
                     --                       AND LOC.PutawayZone = @c_SearchZone
                     --                       AND LOC.Facility = @c_Facility )-- CDC Migration
                     --GROUP BY LOC.PALogicalLoc, LOC.LOC
                     --ORDER BY LOC.PALogicalLoc, LOC.LOC

                     SELECT @c_SelectSQL = N' DECLARE CUR_PUTAWAYLOCATION CURSOR FAST_FORWARD READ_ONLY FOR ' +
                                          ' SELECT LOC.loc, '''' AS HostWhCode    ' +
                                          ' FROM LOTxLOCxID (NOLOCK) ' +
                                          ' JOIN LOC (NOLOCK) on LOTxLOCxID.loc = LOC.loc '

                     IF EXISTS (SELECT 1 FROM #t_PutawayZone)
                     BEGIN
                        SELECT @c_SelectSQL = @c_SelectSQL + ' JOIN #t_PutawayZone PZ ON LOC.PutawayZone = PZ.PutawayZone '
                     END

                     SELECT @c_SelectSQL = @c_SelectSQL +
                                       ' JOIN LotAttribute (NOLOCK) ON LotAttribute.LOT = LOTxLOCxID.LOT ' +
                                       ' WHERE LOTxLOCxID.Qty > 0 ' +
                                       ' AND LOTxLOCxID.sku = @c_SKU ' +
                                       ' AND LOTxLOCxID.StorerKey = @c_StorerKey' +
                                       ' AND LOC.Facility = @c_Facility' +
                                       ' AND LotAttribute.Lottable02 = @c_Lottable02 ' +
                                       CASE WHEN @d_Lottable04 IS NULL THEN
                                          ' AND LotAttribute.Lottable04 IS NULL '
                                          ELSE
                                          ' AND LotAttribute.Lottable04 = @d_Lottable04 '
                                       END +
                                       @c_SQL_LocationCategoryExclude +
                                       @c_SQL_LocationCategoryInclude +
                                       @c_SQL_LocationFlagInclude     +
                                       @c_SQL_LocationFlagExclude     +
                                       @c_SQL_LocationTypeExclude     +
                                       ISNULL( RTRIM(@c_SQL_LocTypeRestriction ), '') +
                                       CASE WHEN @cpa_PutCodeSQL <> '' THEN RTRIM( @cpa_PutCodeSQL) ELSE '' --(ung06)
                                       END +
                                       ' GROUP BY LOC.PALogicalLoc, LOC.LOC, LOC.MaxPallet ' +
                                       CASE WHEN '4' IN (@cpa_LocationStateRestriction1,
                                                         @cpa_LocationStateRestriction2,
                                                         @cpa_LocationStateRestriction3)
                                        THEN ' HAVING COUNT(DISTINCT LOTxLOCxID.ID) < LOC.MaxPallet '
                                          ELSE ''
                                       END +
                                       ' ORDER BY LOC.PALogicalLoc, LOC.LOC '

                     SET @c_SQLParms = RTRIM(@c_SQLParms) +
                                        ', @c_Lottable01 NVARCHAR(18)' +
                                        ', @c_Lottable02 NVARCHAR(18)' +
                                        ', @d_Lottable04 DATETIME '

                     IF @b_Debug = 2
                     BEGIN
                        PRINT 'PA Type: ' + @cpa_PAType
                        PRINT '>> SQL: ' + @c_SelectSQL
                        PRINT '>> Parm: ' + @c_SQLParms
                     END

                     EXEC sp_ExecuteSql @c_SelectSQL
                     , @c_SQLParms
                     , @c_StorerKey
                     , @c_Facility
                     , @c_SKU
                     , @c_LOT
                     , @c_FromLoc
                     , @c_ID
                     , @n_Qty
                     , @n_StdGrossWgt
                     , @cpa_LocationTypeExclude01
                     , @cpa_LocationTypeExclude02
                     , @cpa_LocationTypeExclude03
                     , @cpa_LocationTypeExclude04
                     , @cpa_LocationTypeExclude05
                     , @cpa_LocationCategoryExclude01
                     , @cpa_LocationCategoryExclude02
                     , @cpa_LocationCategoryExclude03
                     , @cpa_LocationCategoryInclude01
                     , @cpa_LocationCategoryInclude02
                     , @cpa_LocationCategoryInclude03
                     , @cpa_LocationHandlingInclude01
                     , @cpa_LocationHandlingInclude02
                     , @cpa_LocationHandlingInclude03
                     , @cpa_LocationHandlingExclude01
                     , @cpa_LocationHandlingExclude02
                     , @cpa_LocationHandlingExclude03
                     , @cpa_LocationFlagInclude01
                     , @cpa_LocationFlagInclude02
                     , @cpa_LocationFlagInclude03
                     , @cpa_LocationFlagExclude01
                     , @cpa_LocationFlagExclude02
                     , @cpa_LocationFlagExclude03
                     , @npa_LocLevelInclude01
                     , @npa_LocLevelInclude02
                     , @npa_LocLevelInclude03
                     , @npa_LocLevelInclude04
                     , @npa_LocLevelInclude05
                     , @npa_LocLevelInclude06
                     , @npa_LocLevelExclude01
                     , @npa_LocLevelExclude02
                     , @npa_LocLevelExclude03
                     , @npa_LocLevelExclude04
                     , @npa_LocLevelExclude05
                     , @npa_LocLevelExclude06
                     , @cpa_LocAisleInclude01
                     , @cpa_LocAisleInclude02
                     , @cpa_LocAisleInclude03
                     , @cpa_LocAisleInclude04
                     , @cpa_LocAisleInclude05
                     , @cpa_LocAisleInclude06
                     , @cpa_LocAisleExclude01
                     , @cpa_LocAisleExclude02
                     , @cpa_LocAisleExclude03
                     , @cpa_LocAisleExclude04
                     , @cpa_LocAisleExclude05
                     , @cpa_LocAisleExclude06
                     , @npa_TotalCube
                     , @npa_TotalWeight
                     , @cpa_LocationTypeRestriction01
                     , @cpa_LocationTypeRestriction02
                     , @cpa_LocationTypeRestriction03
                     , @c_Lottable01
                     , @c_Lottable02
                     , @d_Lottable04

                     -- Chekcing
                     IF @b_Debug = 2
                     BEGIN
                        PRINT '>> Storerkey is ' + @c_Storerkey + ', Sku is ' + @c_SKU + ', Facility is ' + @c_Facility
                        PRINT '>> PAType is ' + @cpa_PAType + ', ToLoc is ' + @cpa_ToLoc
                        PRINT '>> PutCodeSQL: ' + @cpa_PutCodeSQL
                     END

                     --SELECT @n_Rowcount = @@ROWCOUNT
                  END -- @cpa_PAType = '52' OR @cpa_PAType = '54'

                  -- Added by MaryVong on 1-Apr-2007 (SOS69388 KFP) -Start(1)
                  -- Cross facility, search location within specified zone base on HostWhCode,
                  -- with matching Lottable02 AND Lottable04 (do NOT mix sku)
                  IF @cpa_PAType = '55'
                  BEGIN
                     DECLARE CUR_PUTAWAYLOCATION CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                     SELECT LOC.LOC, LOC.HostWhCode
                     FROM LOC WITH (NOLOCK)
                     JOIN LOTxLOCxID WITH (NOLOCK) ON (LOTxLOCxID.LOC = LOC.LOC)
                     JOIN SKUxLOC WITH (NOLOCK) ON (SKUxLOC.StorerKey = LOTxLOCxID.StorerKey
                                                AND SKUxLOC.SKU = LOTxLOCxID.SKU
                                                AND SKUxLOC.StorerKey = @c_storerkey
                                                AND SKUxLOC.SKU = @c_SKU
                                                AND SKUxLOC.LOC = LOTxLOCxID.LOC)
                     JOIN LotAttribute WITH (NOLOCK) ON (LOTxLOCxID.LOT = LotAttribute.LOT
                                                     AND LOTxLOCxID.StorerKey = LotAttribute.StorerKey
                                                     AND LOTxLOCxID.SKU = LotAttribute.SKU)
                     JOIN (SELECT Lottable02, Lottable04
                     FROM LotAttribute WITH (NOLOCK)
                           JOIN LOTxLOCxID WITH (NOLOCK) ON (LOTxLOCxID.LOT = LotAttribute.LOT
                                                         AND LOTxLOCxID.StorerKey = LotAttribute.StorerKey
                                                         AND LOTxLOCxID.SKU = LotAttribute.SKU
                                                         AND LOTxLOCxID.StorerKey = @c_storerkey
                                                         AND LOTxLOCxID.SKU = @c_SKU
                                                         AND LOTxLOCxID.LOT = @c_LOT)
                           WHERE LOTxLOCxID.Qty > 0) AS LA
                        ON (LA.Lottable02 = LotAttribute.Lottable02 AND
                           ISNULL(LA.Lottable04, '') = ISNULL(LotAttribute.Lottable04, ''))
                     WHERE LOC.LOC > @cpa_ToLoc
                     AND   LOC.PutawayZone = @c_SearchZone
                     GROUP BY LOC.PALogicalLoc, LOC.LOC, LOC.HostWhCode
                     ORDER BY LOC.PALogicalLoc, LOC.LOC, LOC.HostWhCode
                  END -- @cpa_PAType = '55'

                  -- Cross facility, search Empty Location base on HostWhCode inventory = 0
                  IF @cpa_PAType = '56'
                  BEGIN
                     DECLARE CUR_PUTAWAYLOCATION CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                     SELECT LOC.LOC, LOC.HostWhCode
                     FROM LOC WITH (NOLOCK)
                     JOIN (SELECT LOC.HostWhCode
                           FROM LOC WITH (NOLOCK)
                           LEFT OUTER JOIN SKUxLOC WITH(NOLOCK) ON (SKUxLOC.LOC = LOC.LOC)
                           WHERE LOC.PutawayZone = @c_SearchZone
                           GROUP BY LOC.HostWhCode
                           HAVING SUM(SKUxLOC.Qty - SKUxLOC.QtyAllocated - SKUxLOC.QtyPicked) = 0 OR
                           SUM(SKUxLOC.Qty - SKUxLOC.QtyAllocated - SKUxLOC.QtyPicked) IS NULL) AS HWC
                           ON (HWC.HostWhCode = LOC.HostWhCode)
                     WHERE LOC.PutawayZone = @c_SearchZone
                     GROUP BY LOC.PALogicalLoc, LOC.LOC, LOC.HostWhCode
                     ORDER BY LOC.PALogicalLoc, LOC.LOC, LOC.HostWhCode
                  END -- @cpa_PAType = '56'

                  -- Cross facility, search suitable location within specified zone (mix with diff sku)
                  IF @cpa_PAType = '57'
                  BEGIN
                     DECLARE CUR_PUTAWAYLOCATION CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                     SELECT LOC.LOC,
                            MIXED_SKU.HostWhCode
                     FROM LOC WITH (NOLOCK)
                     JOIN (SELECT LOC.HostWhCode FROM LOC WITH (NOLOCK)
                           JOIN SKUxLOC WITH (NOLOCK) ON (SKUxLOC.LOC = LOC.LOC)
                           WHERE LOC.PutawayZone = @c_SearchZone
                           GROUP BY LOC.HostWhCode
                           HAVING SUM(SKUxLOC.Qty - SKUxLOC.QtyAllocated - SKUxLOC.QtyPicked) > 0 ) AS MIXED_SKU
                           ON (LOC.HostWhCode = MIXED_SKU.HostWhCode)
                     WHERE LOC.PutawayZone = @c_SearchZone
                     ORDER BY LOC.HostWhCode, LOC.PALogicalLoc, LOC.LOC

                  END -- @cpa_PAType = '57'

                  -- SOS69388 KFP - Cross facility, search suitable location within specified zone (do NOT mix sku)
                  IF @cpa_PAType = '58'
                  BEGIN
                     DECLARE CUR_PUTAWAYLOCATION CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                     SELECT LOC.LOC,
                            SINGLE_SKU.HostWhCode
                     FROM LOC WITH (NOLOCK)
                     JOIN (SELECT LOC.HostWhCode FROM LOC WITH (NOLOCK)
                           JOIN SKUxLOC WITH (NOLOCK) ON (SKUxLOC.LOC = LOC.LOC)
                           WHERE SKUxLOC.StorerKey = @c_storerkey
                           AND   SKUxLOC.SKU = @c_SKU
                           AND   LOC.PutawayZone = @c_SearchZone
                           GROUP BY LOC.HostWhCode
                           HAVING SUM(SKUxLOC.Qty - SKUxLOC.QtyAllocated - SKUxLOC.QtyPicked) > 0 ) AS SINGLE_SKU
                           ON (LOC.HostWhCode = SINGLE_SKU.HostWhCode)
                     WHERE LOC.PutawayZone = @c_SearchZone
                     ORDER BY LOC.HostWhCode, LOC.PALogicalLoc, LOC.LOC

                  END -- @cpa_PAType = '58'
                  -- Added by MaryVong on 1-Apr-2007 (SOS69388) -END(1)

                  -- Search loc within specified zones with same sku (consider pendingmovein too)
                  IF @cpa_PAType = '23'
                  BEGIN
                     SELECT @c_SelectSQL =
                                       ' DECLARE CUR_PUTAWAYLOCATION CURSOR FAST_FORWARD READ_ONLY FOR ' +
                                       ' SELECT LOC.loc, '''' AS HostWhCode    ' +
                                       ' FROM LOTxLOCxID (NOLOCK) ' +
                                       ' JOIN LOC (NOLOCK) on LOTxLOCxID.loc = LOC.loc ' +
                                       ' JOIN LotAttribute (NOLOCK) ON LotAttribute.LOT = LOTxLOCxID.LOT '
                                        
                     IF EXISTS (SELECT 1 FROM #t_PutawayZone)
                     BEGIN
                        SELECT @c_SelectSQL = @c_SelectSQL + ' JOIN #t_PutawayZone PZ ON LOC.PutawayZone = PZ.PutawayZone ' 
                     END                                  
                           
                     SELECT @c_SelectSQL = @c_SelectSQL +                         
                                       ' WHERE ( (Qty - QtyPicked) > 0 OR PendingMoveIn > 0) '  +
                                       ' AND LOTxLOCxID.sku = @c_SKU' +
                                ' AND LOTxLOCxID.StorerKey = @c_StorerKey' +
                                       ' AND LOC.Facility = @c_Facility ' +
                                       ISNULL( RTRIM(@c_SQL_LocationCategoryExclude ), '') + 
                                       ISNULL( RTRIM(@c_SQL_LocationCategoryInclude ), '') + 
                                       ISNULL( RTRIM(@c_SQL_LocationFlagInclude ), '')     + 
                                       ISNULL( RTRIM(@c_SQL_LocationFlagExclude ), '')     + 
                                       ISNULL( RTRIM(@c_SQL_LocTypeRestriction ), '') +
                                       CASE WHEN 'DRIVEIN' IN (@cpa_LocationCategoryInclude01, @cpa_LocationCategoryInclude02,
                                                               @cpa_LocationCategoryInclude03)
                                                           AND @c_LOT <> '' AND @c_LOT IS NOT NULL
                                             THEN ' AND LotAttribute.Lottable02 = @c_Lottable02 ' +
                                                  ' AND LotAttribute.Lottable01 = @c_Lottable01 '
                                          ELSE ''
                                       END +
                                       CASE WHEN 'DOUBLEDEEP' IN (@cpa_LocationCategoryInclude01,
                                                                  @cpa_LocationCategoryInclude02,
                                                                  @cpa_LocationCategoryInclude03)
                                                              AND @c_LOT <> '' AND @c_LOT IS NOT NULL
                                             THEN ' AND LotAttribute.Lottable02 = @c_Lottable02 ' +
                                                  ' AND LotAttribute.Lottable04 = @d_Lottable04 '
                                          ELSE ''
                                       END +
                                       CASE WHEN @cpa_PutCodeSQL <> '' THEN RTRIM( @cpa_PutCodeSQL) ELSE '' END +
                                       ' GROUP BY LOC.PALogicalLoc, LOC.LOC, LOC.MaxPallet ' +
                                       CASE WHEN '4' IN (@cpa_LocationStateRestriction1,
                                                         @cpa_LocationStateRestriction2,
                                                         @cpa_LocationStateRestriction3)
                                        THEN ' HAVING COUNT(DISTINCT LOTxLOCxID.ID) < LOC.MaxPallet '
                                          ELSE ''
                                       END +
                                       ' ORDER BY LOC.PALogicalLoc, LOC.LOC '

                     IF @b_Debug = 2
                     BEGIN
                        PRINT @c_SelectSQL
                     END

                     SET @c_SQLParms = @c_SQLParms +  
                                       N', @cpa_ToLoc NVARCHAR(10) OUTPUT' + 
                                        ', @c_Lottable01 NVARCHAR(18)' +
                                        ', @c_Lottable02 NVARCHAR(18)' +
                                        ', @d_Lottable04 DATETIME '
                     
                     SET @d_Lottable04 = CONVERT(char(8), @d_Lottable04, 112)

                     IF @b_Debug = 2
                     BEGIN
                        PRINT 'PA Type: ' + @cpa_PAType + ' >>> ' + @c_SelectSQL
                     END
                                          
                     EXEC sp_ExecuteSql @c_SelectSQL
                     , @c_SQLParms
                     , @c_StorerKey 
                     , @c_Facility
                     , @c_SKU       
                     , @c_LOT       
                     , @c_FromLoc   
                     , @c_ID        
                     , @n_Qty       
                     , @n_StdGrossWgt
                     , @cpa_LocationTypeExclude01  
                     , @cpa_LocationTypeExclude02  
                     , @cpa_LocationTypeExclude03  
                     , @cpa_LocationTypeExclude04 
                     , @cpa_LocationTypeExclude05  
                     , @cpa_LocationCategoryExclude01 
                     , @cpa_LocationCategoryExclude02 
                     , @cpa_LocationCategoryExclude03 
                     , @cpa_LocationCategoryInclude01 
                     , @cpa_LocationCategoryInclude02 
                     , @cpa_LocationCategoryInclude03 
                     , @cpa_LocationHandlingInclude01 
                     , @cpa_LocationHandlingInclude02 
                     , @cpa_LocationHandlingInclude03 
                     , @cpa_LocationHandlingExclude01  
                     , @cpa_LocationHandlingExclude02  
                     , @cpa_LocationHandlingExclude03  
                     , @cpa_LocationFlagInclude01     
                     , @cpa_LocationFlagInclude02     
                     , @cpa_LocationFlagInclude03     
                     , @cpa_LocationFlagExclude01
                     , @cpa_LocationFlagExclude02
                     , @cpa_LocationFlagExclude03
                     , @npa_LocLevelInclude01   
                     , @npa_LocLevelInclude02   
                     , @npa_LocLevelInclude03   
                     , @npa_LocLevelInclude04   
                     , @npa_LocLevelInclude05   
                     , @npa_LocLevelInclude06   
                     , @npa_LocLevelExclude01   
                     , @npa_LocLevelExclude02   
                     , @npa_LocLevelExclude03   
                     , @npa_LocLevelExclude04   
                     , @npa_LocLevelExclude05   
                     , @npa_LocLevelExclude06   
                     , @cpa_LocAisleInclude01  
                     , @cpa_LocAisleInclude02  
                     , @cpa_LocAisleInclude03  
                     , @cpa_LocAisleInclude04  
                     , @cpa_LocAisleInclude05  
                     , @cpa_LocAisleInclude06  
                     , @cpa_LocAisleExclude01  
                     , @cpa_LocAisleExclude02  
                     , @cpa_LocAisleExclude03  
                     , @cpa_LocAisleExclude04  
                     , @cpa_LocAisleExclude05  
                     , @cpa_LocAisleExclude06
                     , @npa_TotalCube 
                     , @npa_TotalWeight  
                     , @cpa_LocationTypeRestriction01
                     , @cpa_LocationTypeRestriction02
                     , @cpa_LocationTypeRestriction03
                     -- Add Extra Paramaters Here                     
                     , @cpa_ToLoc OUTPUT
                     , @c_Lottable01
                     , @c_Lottable02  
                     , @d_Lottable04

                     -- Chekcing
                     IF @b_Debug = 2
                     BEGIN
                        PRINT '> @c_Storerkey: ' + @c_Storerkey  
                        + ', @c_SKU: ' + @c_SKU  
                        + ', @c_Facility: ' + @c_Facility 
                        + ', @cpa_PAType: ' + @cpa_PAType
                        + ', @cpa_ToLoc: ' + @cpa_ToLoc       
                                                
                     END
                  END -- END of @cpa_PAType = '23'
                  IF @cpa_PAType = '30'
                  BEGIN
                     SELECT @c_SelectSQL =
                                       ' DECLARE CUR_PUTAWAYLOCATION CURSOR FAST_FORWARD READ_ONLY FOR ' +
                                       ' SELECT LOC.loc, '''' AS HostWhCode    ' +
                                       ' FROM LOTxLOCxID (NOLOCK) ' +
                                       ' JOIN LOC (NOLOCK) on LOTxLOCxID.loc = LOC.loc ' +
                                       ' JOIN LotAttribute (NOLOCK) ON LotAttribute.LOT = LOTxLOCxID.LOT ' 

                     IF EXISTS (SELECT 1 FROM #t_PutawayZone)
                     BEGIN
                        SELECT @c_SelectSQL = @c_SelectSQL + ' JOIN #t_PutawayZone PZ ON LOC.PutawayZone = PZ.PutawayZone ' 
                     END                                  
                           
                     SELECT @c_SelectSQL = @c_SelectSQL +                                                                
                                       ' WHERE ( (Qty - QtyPicked) > 0 OR PendingMoveIn > 0) '  +
                                       ' AND LOC.Facility = @c_Facility ' +
                                       @c_SQL_LocationCategoryInclude + 
                                       @c_SQL_LocationCategoryExclude +
                                       @c_SQL_LocationFlagInclude + 
                                       @c_SQL_LocationFlagExclude + 
                                       ISNULL( RTRIM(@c_SQL_LocTypeRestriction ), '') +
                                       CASE WHEN 'DRIVEIN' IN (@cpa_LocationCategoryInclude01, @cpa_LocationCategoryInclude02,
                                                               @cpa_LocationCategoryInclude03)
                                                           AND @c_LOT <> '' AND @c_LOT IS NOT NULL
                                             THEN ' AND LotAttribute.Lottable02 = @c_Lottable02 ' +
                                                  ' AND LotAttribute.Lottable01 = @c_Lottable01 '
                                          ELSE ''
                                       END +
                                       CASE WHEN 'DOUBLEDEEP' IN (@cpa_LocationCategoryInclude01,
                                                                  @cpa_LocationCategoryInclude02,
                                                                  @cpa_LocationCategoryInclude03)
                                                              AND @c_LOT <> '' AND @c_LOT IS NOT NULL
                                             THEN ' AND LotAttribute.Lottable02 = @c_Lottable02 ' +
                                                  ' AND LotAttribute.Lottable04 = @d_Lottable04 '
                                          ELSE ''
                                       END +
                                       CASE WHEN @cpa_PutCodeSQL <> '' THEN RTRIM( @cpa_PutCodeSQL) ELSE '' END +                                        
                                       ' GROUP BY LOC.PALogicalLoc, LOC.LOC, LOC.MaxPallet ' +
                                       CASE WHEN '4' IN (@cpa_LocationStateRestriction1,
                                                         @cpa_LocationStateRestriction2,
                                                         @cpa_LocationStateRestriction3)
                                        THEN ' HAVING COUNT(DISTINCT LOTxLOCxID.ID) < LOC.MaxPallet '
                                          ELSE ''
                                       END +
                                       ' ORDER BY LOC.PALogicalLoc, LOC.LOC '

                     IF @b_Debug = 2
                     BEGIN
                        PRINT @c_SelectSQL
                     END

                     SET @c_SQLParms = @c_SQLParms +                         
                        ', @c_Lottable01 NVARCHAR(18)' +
                        ', @c_Lottable02 NVARCHAR(18)' +
                        ', @d_Lottable04 DATETIME '
                     
                     SET @d_Lottable04 = CONVERT(char(8), @d_Lottable04, 112)

                     IF @b_Debug = 2
                     BEGIN
                        PRINT 'PA Type: ' + @cpa_PAType + ' >>> ' + @c_SelectSQL
                     END
                                                                
                     EXEC sp_ExecuteSql @c_SelectSQL, @c_SQLParms
                     , @c_StorerKey 
                     , @c_Facility
                     , @c_SKU       
                     , @c_LOT       
                     , @c_FromLoc   
                     , @c_ID        
                     , @n_Qty  
                     , @n_StdGrossWgt     
                     , @cpa_LocationTypeExclude01  
                     , @cpa_LocationTypeExclude02  
                     , @cpa_LocationTypeExclude03  
                     , @cpa_LocationTypeExclude04  
                     , @cpa_LocationTypeExclude05  
                     , @cpa_LocationCategoryExclude01 
                     , @cpa_LocationCategoryExclude02 
                     , @cpa_LocationCategoryExclude03 
                     , @cpa_LocationCategoryInclude01 
                     , @cpa_LocationCategoryInclude02 
                     , @cpa_LocationCategoryInclude03 
                     , @cpa_LocationHandlingInclude01 
                     , @cpa_LocationHandlingInclude02 
                     , @cpa_LocationHandlingInclude03 
                     , @cpa_LocationHandlingExclude01  
                     , @cpa_LocationHandlingExclude02  
                     , @cpa_LocationHandlingExclude03  
                     , @cpa_LocationFlagInclude01     
                     , @cpa_LocationFlagInclude02     
                     , @cpa_LocationFlagInclude03     
                     , @cpa_LocationFlagExclude01
                     , @cpa_LocationFlagExclude02
                     , @cpa_LocationFlagExclude03
                     , @npa_LocLevelInclude01   
                     , @npa_LocLevelInclude02   
                     , @npa_LocLevelInclude03   
                     , @npa_LocLevelInclude04   
                     , @npa_LocLevelInclude05   
                     , @npa_LocLevelInclude06   
                     , @npa_LocLevelExclude01   
                     , @npa_LocLevelExclude02   
                     , @npa_LocLevelExclude03   
                     , @npa_LocLevelExclude04   
                     , @npa_LocLevelExclude05   
                     , @npa_LocLevelExclude06   
                     , @cpa_LocAisleInclude01  
                     , @cpa_LocAisleInclude02  
                     , @cpa_LocAisleInclude03  
                     , @cpa_LocAisleInclude04  
                     , @cpa_LocAisleInclude05  
                     , @cpa_LocAisleInclude06  
                     , @cpa_LocAisleExclude01  
                     , @cpa_LocAisleExclude02  
                     , @cpa_LocAisleExclude03  
                     , @cpa_LocAisleExclude04  
                     , @cpa_LocAisleExclude05  
                     , @cpa_LocAisleExclude06  
                     , @npa_TotalCube 
                     , @npa_TotalWeight
                     , @cpa_LocationTypeRestriction01
                     , @cpa_LocationTypeRestriction02
                     , @cpa_LocationTypeRestriction03
                     -- Add Extra Paramaters Here
                     ,@c_Lottable01
                     ,@c_Lottable02   
                     ,@d_Lottable04 
                     
                     -- Chekcing
                     IF @b_Debug = 2
                     BEGIN
                        PRINT '> @c_Storerkey: ' + @c_Storerkey  
                        + ', @c_SKU: ' + @c_SKU  
                        + ', @c_Facility: ' + @c_Facility 
                        + ', @cpa_PAType: ' + @cpa_PAType
                        + ', @cpa_ToLoc: ' + @cpa_ToLoc                               
                     END
                  END -- END of @cpa_PAType = '30'
                  
                  --NJOW01 
                  --step1: Search Location With the same Sku consider shelflife by locationgroup, pallet type(sku.color) & max pallet per loc configure in codelkup
                  --step2: Search empty Location by locationgroup, pallet type(sku.color) & max pallet per loc configure in codelkup
                  IF @cpa_PAType = '63'
                  BEGIN
                     SELECT @cpa_ToLoc = SPACE(10)
                     
                     SELECT @c_Color = Color,
                            @c_Class = Class
                     FROM SKU (NOLOCK)
                     WHERE Storerkey = @c_Storerkey
                     AND Sku = @c_Sku
                                          
                     SELECT @dt_Lottable05 = MAX(LA.Lottable05)                     
                     FROM LOTXLOCXID  LLI (NOLOCK)
                     JOIN LOTATTRIBUTE LA (NOLOCK) ON LLI.Lot = LA.Lot
                     WHERE LLI.Storerkey = @c_Storerkey
                     AND LLI.Sku = @c_Sku
                     AND LLI.ID = @c_ID
                     AND LLI.Loc = @c_FromLoc
                     AND LLI.QTY - LLI.QTYPicked > 0

                     SELECT @c_SelectSQL = N' DECLARE CUR_PUTAWAYLOCATION CURSOR FAST_FORWARD READ_ONLY FOR ' +
                                       ' SELECT LOC.loc, '''' AS HostWhCode    ' +
                                       ' FROM LOC (NOLOCK) ' 
                                       
                     IF EXISTS (SELECT 1 FROM #t_PutawayZone)
                     BEGIN
                        SELECT @c_SelectSQL = @c_SelectSQL + ' JOIN #t_PutawayZone PZ ON LOC.PutawayZone = PZ.PutawayZone ' 
                     END                                  
                           
                     SELECT @c_SelectSQL = @c_SelectSQL + 
                                       ' JOIN CODELKUP CL (NOLOCK) ON CL.Listname = ''MATAPALLET'' AND LOC.LocationGroup = CL.Short AND CL.Code2 = @c_Color ' +
                                       ' OUTER APPLY (SELECT COUNT(DISTINCT LLI.ID) NoofID ' +
                                       '              FROM LOTXLOCXID LLI (NOLOCK) JOIN LOTATTRIBUTE LA (NOLOCK) ON LA.LOT = LLI.LOT  ' +                                       
                                       '              WHERE LLI.Loc = LOC.Loc AND (LLI.Qty > 0 OR LLI.PendingMoveIn > 0) AND LLI.sku = @c_SKU AND LLI.StorerKey = @c_StorerKey ' +
                                       '              HAVING COUNT(DISTINCT LLI.ID) < CAST(CL.UDF01 AS INT) ) AS INV ' +
                                                             --AND (DATEDIFF(day, MIN(LA.Lottable05), GETDATE()) < 90 OR @c_Class <> ''N'')) AS INV ' +
                                       ' OUTER APPLY (SELECT SUM(LLI.Qty+LLI.PendingMoveIn) Qty FROM LOTXLOCXID LLI (NOLOCK) WHERE LLI.Loc = LOC.Loc) AS BAL ' +
                                       ' OUTER APPLY (SELECT TOP 1 L.Loc 
                                                      FROM LOC L (NOLOCK) 
                                                      JOIN LOTXLOCXID LLI (NOLOCK) ON L.Loc = LLI.LOC     
                                                      JOIN LOTATTRIBUTE LA (NOLOCK) ON LLI.Lot = LA.Lot                                    
                                                      JOIN SKU (NOLOCK) ON LLI.Storerkey = SKU.Storerkey AND LLI.Sku = SKU.Sku             
                                                      WHERE LLI.Storerkey = @c_Storerkey 
                                                      AND SKU.Class = ''N''
                                                      AND @c_Class = ''N''
                                                      AND L.Loc = LOC.Loc 
                                                      AND L.LocationGroup NOT IN(''GA'',''RACK'') 
                                                      AND LA.Lottable05 <> @dt_Lottable05
                                                      AND LLI.Qty - LLI.QtyPicked > 0
                                                      AND DATEDIFF(day, LA.Lottable05, GETDATE()) >= 90) AS MIXL5 ' +                                                                         
                                       ' WHERE LOC.Facility = @c_Facility ' +
                                       ' AND MIXL5.Loc IS NULL ' +
                                       ' AND (ISNULL(BAL.Qty,0) = 0 OR ISNULL(INV.NoofID,0) > 0) ' +
                                       @c_SQL_LocationCategoryExclude + 
                                       @c_SQL_LocationCategoryInclude + 
                                       @c_SQL_LocationFlagInclude     + 
                                       @c_SQL_LocationFlagExclude     +
                                       @c_SQL_LocationTypeExclude     +
                                       ISNULL( RTRIM(@c_SQL_LocTypeRestriction ), '') +   
                                       CASE WHEN @cpa_PutCodeSQL <> '' THEN RTRIM( @cpa_PutCodeSQL) ELSE '' 
                                       END +
                                       ' GROUP BY LOC.PALogicalLoc, LOC.LOC, ISNULL(INV.NoofID,0) ' +
                                       ' ORDER BY CASE WHEN ISNULL(INV.NoofID,0) > 0 THEN 1 ELSE 2 END, LOC.PALogicalLoc, LOC.LOC '

                     SET @c_SQLParms = RTRIM(@c_SQLParms) + 
                                        ', @c_Color NVARCHAR(18), @dt_Lottable05 DATETIME, @c_Class NVARCHAR(10)' 

                     IF @b_Debug = 2
                     BEGIN
                        PRINT 'PA Type: ' + @cpa_PAType 
                        PRINT '>> SQL: ' + @c_SelectSQL
                        PRINT '>> Parm: ' + @c_SQLParms 
                     END
                                                          
                     EXEC sp_ExecuteSql @c_SelectSQL
                     , @c_SQLParms
                     , @c_StorerKey 
                     , @c_Facility
                     , @c_SKU       
                     , @c_LOT       
                     , @c_FromLoc   
                     , @c_ID        
                     , @n_Qty       
                     , @n_StdGrossWgt
                     , @cpa_LocationTypeExclude01  
                     , @cpa_LocationTypeExclude02  
                     , @cpa_LocationTypeExclude03  
                     , @cpa_LocationTypeExclude04  
                     , @cpa_LocationTypeExclude05  
                     , @cpa_LocationCategoryExclude01 
                     , @cpa_LocationCategoryExclude02 
                     , @cpa_LocationCategoryExclude03 
                     , @cpa_LocationCategoryInclude01 
                     , @cpa_LocationCategoryInclude02 
                     , @cpa_LocationCategoryInclude03 
                     , @cpa_LocationHandlingInclude01 
                     , @cpa_LocationHandlingInclude02 
                     , @cpa_LocationHandlingInclude03 
                     , @cpa_LocationHandlingExclude01  
                     , @cpa_LocationHandlingExclude02  
                     , @cpa_LocationHandlingExclude03  
                     , @cpa_LocationFlagInclude01     
                     , @cpa_LocationFlagInclude02     
                     , @cpa_LocationFlagInclude03     
                     , @cpa_LocationFlagExclude01
                     , @cpa_LocationFlagExclude02
                     , @cpa_LocationFlagExclude03   
                     , @npa_LocLevelInclude01   
                     , @npa_LocLevelInclude02   
                     , @npa_LocLevelInclude03   
                     , @npa_LocLevelInclude04   
                     , @npa_LocLevelInclude05   
                     , @npa_LocLevelInclude06   
                     , @npa_LocLevelExclude01   
                     , @npa_LocLevelExclude02   
                     , @npa_LocLevelExclude03   
                     , @npa_LocLevelExclude04   
                     , @npa_LocLevelExclude05   
                     , @npa_LocLevelExclude06   
                     , @cpa_LocAisleInclude01  
                     , @cpa_LocAisleInclude02  
                     , @cpa_LocAisleInclude03  
                     , @cpa_LocAisleInclude04  
                     , @cpa_LocAisleInclude05  
                     , @cpa_LocAisleInclude06  
                     , @cpa_LocAisleExclude01  
                     , @cpa_LocAisleExclude02  
                     , @cpa_LocAisleExclude03  
                     , @cpa_LocAisleExclude04  
                     , @cpa_LocAisleExclude05  
                     , @cpa_LocAisleExclude06  
                     , @npa_TotalCube 
                     , @npa_TotalWeight 
                     , @cpa_LocationTypeRestriction01
                     , @cpa_LocationTypeRestriction02
                     , @cpa_LocationTypeRestriction03
                     , @c_Color
                     , @dt_Lottable05
                     , @c_Class

                     -- Chekcing
                     IF @b_Debug = 2
                     BEGIN
                        PRINT '>> Storerkey is ' + @c_Storerkey + ', Sku is ' + @c_SKU + ', Facility is ' + @c_Facility
                        PRINT '>> PAType is ' + @cpa_PAType + ', ToLoc is ' + @cpa_ToLoc + ', color is ' + @c_Color + ', class is ' + @c_Class
                        PRINT '>> PutCodeSQL: ' + @cpa_PutCodeSQL + ', Lottable05 is ' + CAST(@dt_Lottable05 AS NVARCHAR)
                     END                  	
                  END -- END of @cpa_PAType = '63'

                  IF @b_Debug = 2
                  BEGIN                     
                     PRINT '> @c_LOT: ' + @c_LOT 
                     + ', @cpa_PAType: ' + @cpa_PAType                            
                  END

                  OPEN CUR_PUTAWAYLOCATION
                  FETCH NEXT FROM CUR_PUTAWAYLOCATION INTO @cpa_ToLoc, @c_ToHostWhCode

                  WHILE @@FETCH_STATUS <> -1
                  BEGIN
                     SET @c_ToLoc = ISNULL(@cpa_ToLoc,'')

                     IF @b_Debug = 2
                     BEGIN
                        PRINT '>>> @c_ToLoc: ' + @c_ToLoc          
                            + ', @c_ToHostWhCode: ' + @c_ToHostWhCode                    
                     END
                  
                     SELECT @n_LocsReviewed = @n_LocsReviewed + 1

                     IF @cpa_CheckRestrictions = 'Y'
                     BEGIN
                        SELECT @b_RestrictionsPassed = 0
                        GOTO PA_CHECKRESTRICTIONS

                        PATYPE02_BYLOC_B:

                        IF @b_RestrictionsPassed = 1
                        BEGIN
                           SELECT @b_GotLoc = 1
                           BREAK
                        END
                     END
                     ELSE
                     BEGIN
                        SELECT @b_GotLoc = 1
                        BREAK
                     END

                     FETCH NEXT FROM CUR_PUTAWAYLOCATION INTO @cpa_ToLoc, @c_ToHostWhCode
                  END -- @@FETCH_STATUS <> -1
                  CLOSE CUR_PUTAWAYLOCATION
                  DEALLOCATE CUR_PUTAWAYLOCATION

                  IF @b_GotLoc = 1
                  BEGIN
                     IF @b_Debug = 1
                     BEGIN
                        SELECT @c_Reason = 'FOUND PAType=' + @cpa_PAType + ': Search Type by Location'
                        EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                                    @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                                    @c_ToLoc, @c_Reason
                                    
                     END
                     BREAK
                  END -- @b_GotLoc = 1
               END -- IF PA_Type = '16','17','18','19','22','24','32','34','42','44','52','54','55','56','57','58','62' -- (ChewKP07)
            END -- IF @cpa_LocSearchType = '1'
            ELSE IF @cpa_LocSearchType = '2' -- Search Zone By Logical Location
            BEGIN
               SELECT @cpa_ToLoc = SPACE(10), @c_searchlogicalloc = SPACE(18)

               WHILE (1=1)
               BEGIN

                  SELECT TOP 1 @cpa_ToLoc = LOC,
                         @c_ToLoc = LOC,
                         @c_searchlogicalloc = LogicalLocation
                  FROM LOC WITH (NOLOCK)
                  WHERE LOGICALLOCATION > @c_searchlogicalloc
                  AND PutawayZone = @c_SearchZone
                  AND Facility = @c_Facility -- CDC Migration
                  ORDER BY LOGICALLOCATION

                  IF @@ROWCOUNT = 0
                  BEGIN
                     BREAK
                  END

                  SELECT @n_LocsReviewed = @n_LocsReviewed + 1

                  IF @cpa_CheckRestrictions = 'Y'
                  BEGIN
                     SELECT @b_RestrictionsPassed = 0
                     GOTO PA_CHECKRESTRICTIONS

                     PATYPE02_BYLOGICALLOC:
                     IF @b_RestrictionsPassed = 1
                     BEGIN
                        SELECT @b_GotLoc = 1
                        BREAK
                     END
                  END
                  ELSE
                  BEGIN
                     SELECT @b_GotLoc = 1
                     BREAK
                  END
               END -- While 1=1

               IF @b_GotLoc = 1
               BEGIN
                  IF @b_Debug = 1
                  BEGIN
                     SELECT @c_Reason = 'FOUND PAType=' + @cpa_PAType + ': Search Type by Route Sequence'
                     EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                                 @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                                 @c_ToLoc, @c_Reason
                  END
                  BREAK
               END
            END -- IF @cpa_LocSearchType = '2'
         END -- LTRIM(RTRIM(@c_SearchZone)) IS NOT NULL
                  
         CONTINUE
      END -- IF PARTYPE = '02'/'04'/'12'
-----------------------------------------------------------
      IF @cpa_PAType = '06' -- Use Absolute Location Specified in ToLoc
      BEGIN
         SELECT @c_ToLoc = @cpa_ToLoc
         IF ISNULL(RTRIM(@cpa_ToLoc),'') <> ''
         BEGIN
            IF @cpa_CheckRestrictions = 'Y'
            BEGIN
               SELECT @b_RestrictionsPassed = 0
               GOTO PA_CHECKRESTRICTIONS

               PATYPE06:
               IF @b_RestrictionsPassed = 1
               BEGIN
                  SELECT @b_GotLoc = 1
                  IF @b_Debug = 1
                  BEGIN
                     SELECT @c_Reason = 'FOUND PAType=06: Putaway Into To Location'
                     EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                                 @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                                 @c_ToLoc, @c_Reason
                  END
                  BREAK
               END
            END
            ELSE
            BEGIN
               SELECT @b_GotLoc = 1
               IF @b_Debug = 1
               BEGIN
                  SELECT @c_Reason = 'FOUND PAType=06: Putaway Into To Location'
                  EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                              @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                              @c_ToLoc, @c_Reason
               END
               BREAK
            END
         END
         CONTINUE
      END -- IF @cpa_PAType = '6'
-----------------------------------------------------------
      IF @cpa_PAType = '08' OR -- Use Pick Location Specified For Product
         @cpa_PAType = '07' OR -- Use Pick Location Specified For Product IF BOH = 0
         @cpa_PAType = '88'    -- Use Pick Location Specified For Product (Qty - QtyPicked in LocationFlag='NONE' = 0)
      BEGIN
         IF @b_MultiProductID = 0
         BEGIN
            SELECT @c_ToLoc = ''

               IF @cpa_PAType = '08' OR -- SOS#121517
                  @cpa_PAType = '07'    -- (JHTAN01)
               BEGIN
                  DECLARE CUR_PUTAWAYLOCATION CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                  SELECT LOC.LOC
                  FROM SKUxLOC WITH (NOLOCK)
                  JOIN LOC WITH (NOLOCK) ON SKUxLOC.Loc = LOC.Loc
                  WHERE StorerKey = @c_StorerKey
                  AND SKU = @c_SKU
                  AND LOC.Facility = @c_Facility -- CDC Migration
                  AND (SKUxLOC.LOCATIONTYPE = 'PICK' OR SKUxLOC.LOCATIONTYPE = 'CASE')
                  GROUP BY LOC.PALogicalLoc, LOC.Loc
                  ORDER BY LOC.PALogicalLoc, LOC.Loc
               END
               ELSE
               BEGIN
                  DECLARE CUR_PUTAWAYLOCATION CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                  SELECT LOC.LOC
                  FROM SKUxLOC WITH (NOLOCK)
                  JOIN LOC WITH (NOLOCK) ON SKUxLOC.Loc = LOC.Loc
                  WHERE StorerKey = @c_StorerKey
                  AND SKU = @c_SKU
                  AND LOC.Facility = @c_Facility -- CDC Migration
                  AND SKUxLOC.LOCATIONTYPE = 'PICK'
                  GROUP BY LOC.PALogicalLoc, LOC.Loc
                  ORDER BY LOC.PALogicalLoc, LOC.Loc
               END

            OPEN CUR_PUTAWAYLOCATION
            FETCH NEXT FROM CUR_PUTAWAYLOCATION INTO @c_ToLoc

            WHILE @@FETCH_STATUS <> -1 AND @c_ToLoc <> ''   -- (james01)
            BEGIN
               -- INC0075406 (Start)
               IF @cpa_PAType = '07'
               BEGIN
                  IF ( SELECT ISNULL( SUM((SKUxLOC.Qty - SKUxLOC.QtyPicked) + ISNULL(SLE.PendingMoveIn,0)), 0)  --NJOW02
                        FROM SKUxLOC WITH (NOLOCK)
                        JOIN LOC WITH (NOLOCK) ON SKUxLOC.loc = LOC.LOC
                        OUTER APPLY dbo.fnc_skuxloc_extended(SKUxLOC.StorerKey, SKUxLOC.Sku, SKUxLOC.Loc) AS SLE --NJOW02 
                        WHERE SKUxLOC.SKU = @c_SKU
                        AND SKUxLOC.StorerKey = @c_StorerKey
                        AND LOC.Facility = @c_Facility -- CDC Migration
                        AND LOC.LocationFlag = 'NONE'
                        AND LOC.LocationCategory <> 'VIRTUAL'
                        AND SKUxLOC.LOC <> @c_FromLoc) > 0 -- vicky
                  BEGIN
                     IF @b_Debug = 1
                     BEGIN
                        SELECT @c_Reason = 'FAILED PAType=07: Commodity has balance-on-hand qty'
                        EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                                    @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                                    @c_ToLoc, @c_Reason
                     END
                     IF @b_Debug = 2
                           PRINT '>> Reason: ' + 'FAILED PAType=07: Commodity has balance-on-hand qty'
                                                
                     SELECT @c_ToLoc = ''
                     --BREAK (james01)
                  END
               END

               /* Added By Vicky 10 Apr 2003 - CDC Migration */
               IF @cpa_PAType = '88'
               BEGIN
                  IF ( SELECT ISNULL( SUM(qty-qtypicked), 0)
                        FROM SKUxLOC WITH (NOLOCK)
                        JOIN LOC WITH (NOLOCK) ON (SKUxLOC.loc = LOC.loc)
                        WHERE sku = @c_SKU/**************************************************************************************/
                        AND StorerKey = @c_StorerKey
                        AND LOC.Facility = @c_Facility      -- wally 23.oct.2002
                        AND LocationFlag = 'NONE') > 0
                  BEGIN
                     IF @b_Debug = 1
                     BEGIN
                        SELECT @c_Reason = 'FAILED PAType=88: Commodity has balance-on-hand qty'
                        EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                                    @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                                    @c_ToLoc, @c_Reason
                     END
                     IF @b_Debug = 2
                           PRINT '>> Reason: ' +  'FAILED PAType=88: Commodity has balance-on-hand qty'                   
                     SELECT @c_ToLoc = ''
                     --BREAK (james01)
                  END
               END
               -- INC0075406 (End)

               IF ISNULL(RTRIM(@c_ToLoc),'') <> ''
               BEGIN
                  IF @cpa_CheckRestrictions = 'Y'
                  BEGIN
                     SELECT @b_RestrictionsPassed = 0
                     GOTO PA_CHECKRESTRICTIONS

                     PATYPE08:
                     IF @b_RestrictionsPassed = 1
                     BEGIN
                        SELECT @b_GotLoc = 1
                        BREAK
                     END
                  END
                  ELSE
                  BEGIN
                     SELECT @b_GotLoc = 1
                     BREAK
                  END
               END
               FETCH NEXT FROM CUR_PUTAWAYLOCATION INTO @c_ToLoc
            END -- While (1=1)
            CLOSE CUR_PUTAWAYLOCATION
            DEALLOCATE CUR_PUTAWAYLOCATION

            IF @b_GotLoc = 1
            BEGIN
               IF @b_Debug = 1
               BEGIN
                  SELECT @c_Reason = 'FOUND PAType=' + @cpa_PAType + ': Putaway to Assigned Piece Pick'
                  EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                              @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                              @c_ToLoc, @c_Reason
               END
               IF @b_Debug = 2
                  PRINT '>> Reason: ' + 'FOUND PAType=' + @cpa_PAType + ': Putaway to Assigned Piece Pick'
               
               BREAK
            END
         END -- IF @b_MultiProductID = 0
         CONTINUE
      END -- @cpa_PAType = '08','07','88'
-----------------------------------------------------------
      IF @cpa_PAType = '09' -- Use Location Specified In Product/Sku Table
      BEGIN
         IF @b_MultiProductID = 0
         BEGIN
            SELECT @c_ToLoc = PUTAWAYLOC
            FROM SKU WITH (NOLOCK)
            WHERE StorerKey = @c_StorerKey
            AND SKU = @c_SKU

            IF ISNULL(RTRIM(@c_ToLoc),'') <> ''
            BEGIN
               IF @cpa_CheckRestrictions = 'Y'
               BEGIN
                  SELECT @b_RestrictionsPassed = 0
                  GOTO PA_CHECKRESTRICTIONS

                  PATYPE09:
                  IF @b_RestrictionsPassed = 1
                  BEGIN
                     SELECT @b_GotLoc = 1
                     IF @b_Debug = 1
                     BEGIN
                        SELECT @c_Reason = 'FOUND PAType=09: Putaway to location specified on Commodity'
                        EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                                    @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                                    @c_ToLoc, @c_Reason
                     END
                     IF @b_Debug = 2
                        PRINT '>> Reason: ' +  'FOUND PAType=09: Putaway to location specified on Commodity'                  
                     BREAK
                  END
               END
               ELSE
               BEGIN
                  SELECT @b_GotLoc = 1
                  IF @b_Debug = 1
                  BEGIN
                     SELECT @c_Reason = 'FOUND PAType=09: Putaway to location specified on Commodity'
                     EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                                 @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                                 @c_ToLoc, @c_Reason
                  END
                  IF @b_Debug = 2
                     PRINT '>> Reason: ' + 'FOUND PAType=09: Putaway to location specified on Commodity'
                  BREAK
               END
            END
            ELSE
            BEGIN
               IF @b_Debug = 1
               BEGIN
                  SELECT @c_Reason = 'FAILED PAType=09: Commodity has no putaway location specified'
                  EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                  @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                  @c_ToLoc, @c_Reason
               END
               IF @b_Debug = 2
                     PRINT '>> Reason: ' + 'FAILED PAType=09: Commodity has no putaway location specified'
            END
         END -- IF @b_MultiProductID = 0
         CONTINUE
      END -- @cpa_PAType = '09'
-----------------------------------------------------------
      /* Start Add by DLIM for FBR22 20010620 */
      IF @cpa_PAType = '20' -- Use SKU pickface Location
      BEGIN
         IF @b_MultiProductID = 0
         BEGIN
            DECLARE CUR_PUTAWAYLOCATION CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT LOC.Loc
            FROM SKUxLOC WITH (NOLOCK)
            JOIN LOC WITH (NOLOCK) ON SKUxLOC.Loc = LOC.Loc
            WHERE StorerKey = @c_StorerKey
            AND SKU = @c_SKU
            AND SKUxLOC.LOCATIONTYPE = 'PICK'
            AND @cpa_FromLoc = @c_FromLoc
            AND LOC.Facility = @c_Facility -- CDC Migration
            GROUP BY LOC.PALogicalLoc, LOC.LOC
            ORDER BY LOC.PALogicalLoc, LOC.LOC

            OPEN CUR_PUTAWAYLOCATION
            FETCH NEXT FROM CUR_PUTAWAYLOCATION INTO @c_ToLoc
            WHILE @@FETCH_STATUS <> -1
            BEGIN
               IF @cpa_CheckRestrictions = 'Y'
               BEGIN
                  SELECT @b_RestrictionsPassed = 0
                  GOTO PA_CHECKRESTRICTIONS

                  PATYPE20:
                  IF @b_RestrictionsPassed = 1
                  BEGIN
 SELECT @b_GotLoc = 1
                     BREAK
                  END
               END
               ELSE
               BEGIN
                  SELECT @b_GotLoc = 1
                  BREAK
               END
               FETCH NEXT FROM CUR_PUTAWAYLOCATION INTO @c_ToLoc
            END -- WHILE (1=1)
            CLOSE CUR_PUTAWAYLOCATION
            DEALLOCATE CUR_PUTAWAYLOCATION

            IF @b_GotLoc = 1
            BEGIN
               IF @b_Debug = 1
               BEGIN
                  SELECT @c_Reason = 'FOUND PAType=20: Putaway to SKU pickface location'
                  EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                              @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                              @c_ToLoc, @c_Reason
               END
               IF @b_Debug = 2
                  PRINT '>> Reason: ' + 'FOUND PAType=20: Putaway to SKU pickface location'
               BREAK
            END
         END -- IF @b_MultiProductID = 0
         CONTINUE
      END -- @cpa_PAType = '20'
      /* END Add by DLIM for FBR22 20010620 */
-----------------------------------------------------------
      IF @cpa_PAType = '15' -- Use Case Pick Location Specified For Product
      BEGIN
         IF @b_MultiProductID = 0
         BEGIN
            SELECT @c_ToLoc = ''
            DECLARE CUR_PUTAWAYLOCATION CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT LOC.LOC
            FROM SKUxLOC WITH (NOLOCK)
            JOIN LOC WITH (NOLOCK) on SKUxLOC.Loc = LOC.Loc
            WHERE StorerKey = @c_StorerKey
            AND SKU = @c_SKU
            AND SKUxLOC.LOCATIONTYPE = 'CASE'
            AND LOC.Facility = @c_Facility -- SOS6421
            GROUP BY LOC.PALogicalLoc, LOC.LOC
            ORDER BY LOC.PALogicalLoc, LOC.LOC

            OPEN CUR_PUTAWAYLOCATION
            FETCH NEXT FROM CUR_PUTAWAYLOCATION INTO @c_ToLoc
            WHILE @@FETCH_STATUS <> -1
            BEGIN
               IF ISNULL(RTRIM(@c_ToLoc),'') <> ''
               BEGIN
                  IF @cpa_CheckRestrictions = 'Y'
                  BEGIN
                     SELECT @b_RestrictionsPassed = 0
                     GOTO PA_CHECKRESTRICTIONS

                     PATYPE15:
                  IF @b_RestrictionsPassed = 1
                     BEGIN
                        SELECT @b_GotLoc = 1
                        BREAK
                     END
                  END
                  ELSE
                  BEGIN
                     SELECT @b_GotLoc = 1
                     BREAK
                  END
               END
            FETCH NEXT FROM CUR_PUTAWAYLOCATION INTO @c_ToLoc
            END -- WHILE (1=1)
            CLOSE CUR_PUTAWAYLOCATION
            DEALLOCATE CUR_PUTAWAYLOCATION

            IF @b_GotLoc = 1
            BEGIN
               IF @b_Debug = 1
               BEGIN
                  SELECT @c_Reason = 'FOUND PAType=15: Putaway to Assogned Case Pick'
                  EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                              @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                              @c_ToLoc, @c_Reason
                              
               END
               IF @b_Debug = 2
                  PRINT '>> Reason: ' + 'FOUND PAType=15: Putaway to Assogned Case Pick'
               BREAK
            END
         END -- IF @b_MultiProductID = 0
         CONTINUE
      END -- @cpa_PAType = '15'
-----------------------------------------------------------
      IF @cpa_PAType='25' -- If Source=Specified Zone, Putaway to TOLOCATION
      BEGIN
         IF EXISTS(SELECT 1 FROM LOC WITH (NOLOCK)
                   WHERE PutawayZone = @cpa_Zone
                   AND   LOC = @c_FromLoc )
         BEGIN
            IF ISNULL(RTRIM(@cpa_ToLoc),'') <> ''
            BEGIN
               SELECT @c_ToLoc = @cpa_ToLoc

               IF @cpa_CheckRestrictions='Y'
               BEGIN
                  SELECT @b_RestrictionsPassed = 0
                  GOTO PA_CHECKRESTRICTIONS

                  PATYPE25:
                  IF @b_RestrictionsPassed=1
                  BEGIN
                     SELECT @b_GotLoc = 1
                     IF @b_Debug = 1
                     BEGIN
                        SELECT @c_Reason = 'FOUND PAType=25: Specified Zone '
                                         + RTRIM(@cpa_Zone) + ' Putaway to ' + RTRIM(@cpa_ToLoc)
                        EXEC nspPTD 'nspRDTPASTD',
                                    @n_pTraceHeadKey,
                                    @c_PutawayStrategyKey,
                                    @c_PutawayStrategyLineNumber,
                                    @n_PtraceDetailKey,
                                    @c_ToLoc,
                                    @c_Reason
                     END
                     IF @b_Debug = 2
                        PRINT '>> Reason: ' + 'FOUND PAType=25: Specified Zone '
                                         + RTRIM(@cpa_Zone) + ' Putaway to ' + RTRIM(@cpa_ToLoc)
                     BREAK
                  END
               END
               ELSE
               BEGIN
                  SELECT @b_GotLoc = 1
                  IF @b_Debug = 1
                  BEGIN
                     SELECT @c_Reason = 'FOUND PAType=25: Specified Zone '
                                         + RTRIM(@cpa_Zone) + ' Putaway to ' + RTRIM(@cpa_ToLoc)
                     EXEC nspPTD 'nspRDTPASTD',
                                 @n_pTraceHeadKey,
                                 @c_PutawayStrategyKey,
                                 @c_PutawayStrategyLineNumber,
                                 @n_PtraceDetailKey,
                                 @c_ToLoc,
                                 @c_Reason
                  END
                  BREAK
               END
            END
         END
         ELSE
         BEGIN
            IF @b_Debug = 1
            BEGIN
               SELECT @c_Reason = 'FAILED PAType=25: Specified Zone '
                                + RTRIM(@cpa_Zone) + ' <> ' + RTRIM(@cpa_FromLoc) + ' Zone'
               EXEC nspPTD 'nspRDTPASTD',
                           @n_pTraceHeadKey,
                           @c_PutawayStrategyKey,
                           @c_PutawayStrategyLineNumber,
                           @n_PtraceDetailKey,
                           @c_ToLoc,
                           @c_Reason
            END
            IF @b_Debug = 2
               PRINT '>> Reason: ' + 'FOUND PAType=25: Specified Zone '
                                    + RTRIM(@cpa_Zone) + ' Putaway to ' + RTRIM(@cpa_ToLoc)
            
         END
         CONTINUE
      END -- PAType = '25'
-----------------------------------------------------------
      IF @cpa_PAType BETWEEN '26' AND '29' --(Shong001)
      BEGIN
         SET @c_PalletType = ''
         SET @n_NumberOfSKU = 0
         SET @n_NumberOfPackSize = 0
         IF EXISTS(SELECT 1 FROM UCC WITH (NOLOCK) WHERE ID = @c_ID)
         BEGIN
          SELECT @n_NumberOfSKU = COUNT(DISTINCT UCC.SKU + L.Lottable02),
                 @n_NumberOfPackSize = COUNT(DISTINCT UCC.SKU + L.Lottable02 + CAST(Qty AS NVARCHAR(10)))
          FROM   UCC (NOLOCK)
          JOIN LOTATTRIBUTE l (NOLOCK) ON UCC.Lot = l.Lot AND l.StorerKey = @c_StorerKey
          WHERE  UCC.StorerKey = @c_StorerKey
          AND    UCC.ID = @c_ID
          AND    UCC.Loc = @c_FromLoc -- (ChewKP06)

            IF @n_NumberOfSKU = 1 AND @n_NumberOfPackSize = 1
             SET @c_PalletType = '1_Lot_CartonSize'
            ELSE IF @n_NumberOfSKU = 1 AND @n_NumberOfPackSize = 2
               SET @c_PalletType = '1_Lot_2CartonSize'
            ELSE
               SET @c_PalletType = 'Mixed_Lot_CartonSize'

         END
         -- Getting the UCC Qty for Loose Carton, this Carton going to putaway
         IF @c_PalletType = '1_Lot_2CartonSize'
         BEGIN
            IF @b_PutawayBySKU = 'N'
            BEGIN
               SELECT TOP 1 @n_Qty = QTY
               FROM   UCC WITH (NOLOCK)
               WHERE ID = @c_ID
               ORDER BY Qty
            END
         END
         IF @c_PalletType = 'Mixed_Lot_CartonSize'
         BEGIN
            IF @b_PutawayBySKU = 'N'
            BEGIN
                SELECT TOP 1 @n_Qty = QTY
                FROM   UCC WITH (NOLOCK)
                WHERE ID = @c_ID
                ORDER BY Qty DESC
            END
        END
         -- bookmark1
         SET @b_CheckCube = 0
         SET @n_FromCube = 0

         IF '1' IN (@cpa_DimensionRestriction01,
                    @cpa_DimensionRestriction02,
                    @cpa_DimensionRestriction03,
                    @cpa_DimensionRestriction04,
                    @cpa_DimensionRestriction05,
                    @cpa_DimensionRestriction06)
         BEGIN
            SELECT @n_FromCube = (@n_Qty * 1.000) * Sku.StdCube
            FROM Sku WITH (NOLOCK)
            WHERE SKU.StorerKey = @c_StorerKey
            AND SKU.Sku = @c_SKU

            SET @b_CheckCube = 1
         END

         -- Fit by UCC cube
         IF '17' IN (@cpa_DimensionRestriction01,
                    @cpa_DimensionRestriction02,
                    @cpa_DimensionRestriction03,
                    @cpa_DimensionRestriction04,
                    @cpa_DimensionRestriction05,
                    @cpa_DimensionRestriction06)
         BEGIN
            -- Get FROM cube
            IF EXISTS( SELECT 1 FROM dbo.UCC WITH (NOLOCK) WHERE LOC = @c_FromLOC AND ID = @c_ID AND Status = '1')
               -- UCC
               IF @b_PutawayBySKU = 'N'
                  -- Take all UCC cube
                  SELECT @n_FromCube = ISNULL( SUM( Pack.CubeUOM1), 0)
                  FROM dbo.UCC WITH (NOLOCK)
                     JOIN dbo.SKU WITH (NOLOCK) ON (UCC.StorerKey = SKU.StorerKey AND UCC.SKU = SKU.SKU)
                     JOIN dbo.Pack WITH (NOLOCK) ON (Pack.PackKey = SKU.PackKey)
                  WHERE UCC.LOC = @c_FromLOC
                     AND UCC.ID = @c_ID
                     AND Status = '1'
               ELSE
               BEGIN
                  -- Take 1 UCC cube
                  SELECT TOP 1
                     @n_FromCube = Pack.CubeUOM1
                  FROM dbo.UCC WITH (NOLOCK)
                     JOIN dbo.SKU WITH (NOLOCK) ON (UCC.StorerKey = SKU.StorerKey AND UCC.SKU = SKU.SKU)
                     JOIN dbo.Pack WITH (NOLOCK) ON (Pack.PackKey = SKU.PackKey)
                  WHERE UCC.LOC = @c_FromLOC
                     AND UCC.ID = @c_ID
                     AND UCC.StorerKey = @c_StorerKey
                     AND UCC.SKU = @c_SKU
                     AND UCC.Status = '1'
               END
            ELSE
            BEGIN
               -- NON-UCC
               IF @b_PutawayBySKU = 'N'
                  SELECT @n_FromCube = ISNULL( SUM((LOTxLOCxID.QTY - LOTxLOCxID.QTYPicked + LOTxLOCxID.PendingMoveIn) * SKU.STDCube), 0)
                  FROM LOTxLOCxID WITH (NOLOCK)
                     JOIN SKU WITH (NOLOCK) ON (LOTxLOCxID.StorerKey = SKU.StorerKey AND LOTxLOCxID.SKU = SKU.SKU)
                  WHERE LOTxLOCxID.LOC = @c_FromLoc
                     AND LOTxLOCxID.ID = @c_ID
                     AND (LOTxLOCxID.QTY > 0 OR LOTxLOCxID.PendingMoveIn > 0)
               ELSE
                  SELECT @n_FromCube = ISNULL( @n_QTY * SKU.STDCube, 0)
                  FROM SKU WITH (NOLOCK)
                  WHERE StorerKey = @c_StorerKey
                     AND SKU = @c_SKU
            END

            SET @b_CheckCube = 1
         END

       SET @c_PA_Decription = ''
       SELECT @c_PA_Decription = ISNULL(c.[Description],' Putaway Decription Not Define!')
       FROM CODELKUP c WITH (NOLOCK)
       WHERE c.LISTNAME = 'PATYPE'
       AND c.Code = @cpa_PAType

       IF @cpa_PAType = '28' -- 28 -- If Pallet with Multi SKU/Batch/Carton Size, Put-away to Zone Specified Location Category
       BEGIN
        IF @c_PalletType <> 'Mixed_Lot_CartonSize' AND @cpa_PAType = '28'
        BEGIN
            IF @b_Debug = 1
            BEGIN
               SELECT @c_Reason = 'FAILED PAType=28: Pallet must be Mixed SKU/Lottable02/Pack Size'

               EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                           @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                           @c_ToLoc, @c_Reason                           
            END
            IF @b_Debug = 2
               PRINT '>> Reason: ' + 'FAILED PAType=28: Pallet must be Mixed SKU/Lottable02/Pack Size'                  
            GOTO PATYPE25_29_QUIT
        END

         SELECT @c_ToLoc = ''
         SET @c_SelectSQL =
                  N'DECLARE CUR_PUTAWAYLOCATION CURSOR FAST_FORWARD READ_ONLY FOR ' +
                  N'SELECT LOC.LOC ' +
                  'FROM LOC WITH (NOLOCK) ' +
                  'WHERE LOC.Facility = @c_Facility' +
                  [dbo].[fnc_BuildPutawayRestriction] (@c_PutawayStrategyKey, @c_PutawayStrategyLineNumber,'Y', @n_FromCube, @c_StorerKey, @c_SKU, @c_LOT) +
                  CASE WHEN @cpa_PutCodeSQL <> '' THEN RTRIM( @cpa_PutCodeSQL) ELSE '' END + --(ung06)
               ' GROUP BY LOC.PALogicalLoc, LOC.LOC ' +
               ' ORDER BY LOC.PALogicalLoc,LOC.LOC '

            IF @b_Debug = 2
            BEGIN
               PRINT 'PA Type: ' + @cpa_PAType + ' >>> ' + @c_SelectSQL
            END
            
            EXEC sp_ExecuteSql @c_SelectSQL, N'Facility NVARCHAR(5)', @c_Facility

            OPEN CUR_PUTAWAYLOCATION
            FETCH NEXT FROM CUR_PUTAWAYLOCATION INTO @c_ToLoc
            WHILE @@FETCH_STATUS <> -1
            BEGIN
               IF ISNULL(RTRIM(@c_ToLoc),'') <> ''
               BEGIN
                  IF @cpa_CheckRestrictions = 'Y'
                  BEGIN
                     SELECT @b_RestrictionsPassed = 0
                     GOTO PA_CHECKRESTRICTIONS

                     PATYPE28:
                     IF @b_RestrictionsPassed = 1
                     BEGIN
                        SELECT @b_GotLoc = 1
                        BREAK
                     END
                  END
                  ELSE
                  BEGIN
                     SELECT @b_GotLoc = 1
                  END
               END
               FETCH NEXT FROM CUR_PUTAWAYLOCATION INTO @c_ToLoc
            END -- WHILE @@FETCH_STATUS
            CLOSE CUR_PUTAWAYLOCATION
            DEALLOCATE CUR_PUTAWAYLOCATION

            IF @b_GotLoc = 1
            BEGIN
               IF @b_Debug = 1
               BEGIN
                  SELECT @c_Reason = 'FOUND PAType=' + @cpa_PAType + ': ' + @c_PA_Decription
                  EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                              @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                              @c_ToLoc, @c_Reason                              
               END
               IF @b_Debug = 2
                  PRINT '>> Reason: ' + 'FOUND PAType=' + @cpa_PAType + ': ' + @c_PA_Decription               
               BREAK
            END
       END -- IF @cpa_PAType = '28'
       IF @cpa_PAType = '26' -- 26 -- If Pallet with Single SKU/Batch/Carton Size, Put-away to Empty Location in Specified Zone
       OR @cpa_PAType = '27' -- 27 -- If Pallet with Single SKU/Batch with 2 Carton Size, Put-away to Empty Location in Specified Zone
       OR @cpa_PAType = '29' -- 29 -- If Source=FROMLOCATION, Put-away to Location with Same Lot02 within SKU Zone
       BEGIN
        IF @c_PalletType <> '1_Lot_CartonSize' AND @cpa_PAType = '26'
        BEGIN
            IF @b_Debug = 1
            BEGIN
               SELECT @c_Reason = 'FAILED PAType=26: Pallet must be Single SKU/Lottable02/Pack Size'
               EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                           @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                           @c_ToLoc, @c_Reason
            END
            IF @b_Debug = 2
               PRINT '>> Reason: ' + 'FAILED PAType=26: Pallet must be Single SKU/Lottable02/Pack Size'               
            GOTO PATYPE25_29_QUIT
        END
        IF @c_PalletType <> '1_Lot_2CartonSize' AND @cpa_PAType = '27'
        BEGIN
            IF @b_Debug = 1
            BEGIN
               SELECT @c_Reason = 'FAILED PAType=27: Pallet must be Single SKU/Lottable02 with 2 Pack Size'
               EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                           @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                           @c_ToLoc, @c_Reason
            END
            IF @b_Debug = 2
               PRINT '>> Reason: ' + 'FAILED PAType=27: Pallet must be Single SKU/Lottable02 with 2 Pack Size'            
            GOTO PATYPE25_29_QUIT
        END
        IF @c_PalletType <> 'Mixed_Lot_CartonSize' AND @cpa_PAType = '28'
        BEGIN
            IF @b_Debug = 1
            BEGIN
               SELECT @c_Reason = 'FAILED PAType=28: Pallet Not with Mixed SKU/Lottable02/Pack Size'
               EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                           @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                           @c_ToLoc, @c_Reason
            END
            IF @b_Debug = 2
               PRINT '>> Reason: ' + 'FAILED PAType=28: Pallet Not with Mixed SKU/Lottable02/Pack Size'            
            GOTO PATYPE25_29_QUIT
        END
        IF @cpa_PAType = '29' AND @c_FromLoc <> @cpa_FromLoc
        BEGIN
            IF @b_Debug = 1
            BEGIN
               SELECT @c_Reason = 'FAILED PAType=29: From Loc Not Match'
               EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                           @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                           @c_ToLoc, @c_Reason
            END
            IF @b_Debug = 2
               PRINT '>> Reason: ' + 'FAILED PAType=29: From Loc Not Match'
            
            GOTO PATYPE25_29_QUIT
        END

        IF @cpa_PAType = '29'
        BEGIN
         SELECT @cpa_Zone = PutawayZone
         FROM SKU WITH (NOLOCK)
         WHERE StorerKey = @c_StorerKey AND
               SKU = @c_SKU

        END
         SELECT @c_ToLoc = ''

         IF @cpa_PAType IN ('26','27')
         BEGIN
            SET @c_SelectSQL =
             N'DECLARE CUR_PUTAWAYLOCATION CURSOR FAST_FORWARD READ_ONLY FOR ' +
             N'SELECT LOC.LOC ' +
              'FROM LOC WITH (NOLOCK) ' +
              'WHERE LOC.Facility = @c_Facility ' +
               [dbo].[fnc_BuildPutawayRestriction] (@c_PutawayStrategyKey, @c_PutawayStrategyLineNumber,'Y', @n_FromCube, @c_StorerKey, @c_SKU, @c_LOT) +
               CASE WHEN @cpa_PutCodeSQL <> '' THEN RTRIM( @cpa_PutCodeSQL) ELSE '' END +  --(ung06)
              'GROUP BY LOC.PALogicalLoc, LOC.LOC ' +
              'ORDER BY LOC.PALogicalLoc, LOC.LOC '

            IF @b_Debug = 2
            BEGIN
               PRINT 'PA Type: ' + @cpa_PAType + ' >>> ' + @c_SelectSQL
            END
                     
            EXEC sp_ExecuteSql @c_SelectSQL, N'@c_Facility NVARCHAR(5)', @c_Facility

         END
         ELSE
         IF @cpa_PAType = '29'
         BEGIN
            IF @b_CheckCube = 1
            BEGIN
                 IF NOT EXISTS(
                        SELECT 1
                        FROM LOTxLOCxID LLI WITH (NOLOCK)
                        JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON lli.Lot = la.Lot
 JOIN LOC WITH (NOLOCK) ON LOC.LOC = LLI.LOC
                        WHERE LOC.Facility = @c_Facility
                        AND   LOC.PutawayZone = @cpa_Zone
      AND   LLI.StorerKey = @c_StorerKey
                        AND   LLI.SKU = @c_SKU
                        AND   LA.Lottable02 = @c_Lottable02
                        AND   LLI.LOC > @c_ToLoc
                        AND   LOC.CubicCapacity >= @n_FromCube)
                     BEGIN
                        IF @b_Debug = 1
                        BEGIN
                           SELECT @c_Reason = 'FAILED Cube Fit: CubeRequired = ' + RTRIM(Convert(char(10),(@n_FromCube)))
                           EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                                       @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                                       '', @c_Reason
                        END
                           IF @b_Debug = 2
                              PRINT '>> Reason: ' + 'FAILED Cube Fit: CubeRequired = ' + RTRIM(Convert(char(10),(@n_FromCube)))                        
                        GOTO PATYPE25_29_QUIT
                     END
                END

               DECLARE CUR_PUTAWAYLOCATION CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT LOC.Loc
               FROM LOTxLOCxID LLI WITH (NOLOCK)
               JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON lli.Lot = la.Lot
               JOIN LOC WITH (NOLOCK) ON LOC.LOC = LLI.LOC
               WHERE LOC.Facility = @c_Facility
               AND   LOC.PutawayZone = @cpa_Zone
               AND   LLI.StorerKey = @c_StorerKey
               AND   LLI.SKU = @c_SKU
               AND   LA.Lottable02 = @c_Lottable02
               AND   LLI.LOC > @c_ToLoc
               GROUP BY LOC.PALogicalLoc, LOC.LOC
               HAVING SUM(ISNULL(LLI.Qty,0) - ISNULL(LLI.QtyPicked,0)) > 0
               ORDER BY LOC.PALogicalLoc, LOC.LOC

               --SPChin UWP-14640
               --OPEN CUR_PUTAWAYLOCATION

            END

            OPEN CUR_PUTAWAYLOCATION
            FETCH NEXT FROM CUR_PUTAWAYLOCATION INTO @c_ToLoc
            WHILE @@FETCH_STATUS <> -1
            BEGIN

               IF ISNULL(RTRIM(@c_ToLoc),'') = ''
               BEGIN
                  SELECT @c_ToLoc = ''
               END

               IF ISNULL(RTRIM(@c_ToLoc),'') <> ''
               BEGIN
                  IF @cpa_CheckRestrictions = 'Y'
                  BEGIN
                     SELECT @b_RestrictionsPassed = 0
                     GOTO PA_CHECKRESTRICTIONS

                     PATYPE26:
                     PATYPE27:
                     PATYPE29:
                     IF @b_RestrictionsPassed = 1
                     BEGIN
                        SELECT @b_GotLoc = 1
                        BREAK
                     END
                  END
                  ELSE
                  BEGIN
                     SELECT @b_GotLoc = 1
                  END
               END
               FETCH NEXT FROM CUR_PUTAWAYLOCATION INTO @c_ToLoc
            END -- WHILE 1=1
            CLOSE CUR_PUTAWAYLOCATION
            DEALLOCATE CUR_PUTAWAYLOCATION

            PATYPE25_29_QUIT:
            IF @b_GotLoc = 1
            BEGIN
               IF @b_Debug = 1
               BEGIN
                  SELECT @c_Reason = 'FOUND PAType=' + @cpa_PAType + ': ' + @c_PA_Decription
                  EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                              @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                              @c_ToLoc, @c_Reason
               END
               IF @b_Debug = 2
                  PRINT '>> Reason: ' + 'FOUND PAType=' + @cpa_PAType + ': ' + @c_PA_Decription     
                            
               BREAK
            END
       END -- IF @cpa_PAType = '26'
      END

-----------------------------------------------------------
   END -- WHILE (1=1)

   IF @b_GotLoc <> 1 -- No Luck
   BEGIN
      SELECT @c_ToLoc= ''
   END

   IF @b_Debug = 1
   BEGIN
      UPDATE PTRACEHEAD SET EndTime = GetDate(), PA_locFound = @c_ToLoc, PA_LocsReviewed = @n_LocsReviewed
      WHERE PTRACEHEADKey = @n_pTraceHeadKey
   END
   GOTO LOCATION_EXIT

   PA_CHECKRESTRICTIONS:
   SELECT @c_Loc_Type     = LOCATIONTYPE ,
          @c_loc_flag     = LocationFlag ,
          @c_loc_handling = LOCATIONHANDLING,
          @c_loc_category = LocationCategory,
          @c_loc_zone     = PutawayZone ,
          @c_Loc_CommingleSku = comminglesku,
          @c_loc_comminglelot = comminglelot,
          @n_Loc_Width  = WIDTH ,
          @n_Loc_Length = LENGTH ,
          @n_Loc_Height = HEIGHT ,
          @n_Loc_CubicCapacity  = CubicCapacity ,
          @n_Loc_WeightCapacity = WeightCapacity,
          @n_loc_level = LOC.LocLevel,
          @c_loc_aisle = LOC.LocAisle,
          @c_loc_ABC = LOC.ABC,
          @c_LOC_HostWHCode = ISNULL(LOC.HOSTWHCODE, ''), --(SHONG01)
          @c_loc_NoMixLottable01 = LOC.NoMixLottable01, --(ung05)
          @c_loc_NoMixLottable02 = LOC.NoMixLottable02, --(ung05)
          @c_loc_NoMixLottable03 = LOC.NoMixLottable03, --(ung05)
          @c_loc_NoMixLottable04 = LOC.NoMixLottable04, --(ung05)
          @c_loc_NoMixLottable06 = LOC.NoMixLottable06, -- (ChewKP09)
          @c_loc_NoMixLottable07 = LOC.NoMixLottable07, -- (ChewKP09)
          @c_loc_NoMixLottable08 = LOC.NoMixLottable08, -- (ChewKP09)
          @c_loc_NoMixLottable09 = LOC.NoMixLottable09, -- (ChewKP09)
          @c_loc_NoMixLottable10 = LOC.NoMixLottable10, -- (ChewKP09)
          @c_loc_NoMixLottable11 = LOC.NoMixLottable11, -- (ChewKP09)
          @c_loc_NoMixLottable12 = LOC.NoMixLottable12, -- (ChewKP09)
          @c_loc_NoMixLottable13 = LOC.NoMixLottable13, -- (ChewKP09)
          @c_loc_NoMixLottable14 = LOC.NoMixLottable14, -- (ChewKP09)

          @c_loc_NoMixLottable15 = LOC.NoMixLottable15, -- (ChewKP09)
          @n_loc_MaxSKU = LOC.MaxSKU,
          @n_loc_MaxQTY = LOC.MaxQTY,
          @n_loc_MaxCarton = LOC.MaxCarton
   FROM LOC WITH (NOLOCK)
   WHERE LOC = @c_ToLoc
   SELECT @c_movableunittype = @c_movableunittype
   SELECT @b_RestrictionsPassed = 1
   SELECT @c_Loc_Type = LTRIM(@c_Loc_Type)

   IF ISNULL(RTRIM(@c_Loc_Type),'') <> ''
   BEGIN
      IF @c_Loc_Type IN (@cpa_LocationTypeExclude01,@cpa_LocationTypeExclude02,@cpa_LocationTypeExclude03,@cpa_LocationTypeExclude04,@cpa_LocationTypeExclude05)
      BEGIN         
         IF @b_Debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED Location type ' + RTRIM(@c_Loc_Type) + ' was one of the excluded values'
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                        @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                        @c_ToLoc, @c_Reason
         END
         IF @b_Debug = 2
            PRINT '>> Reason: ' + 'FAILED Location type ' + RTRIM(@c_Loc_Type) + ' was one of the excluded values'         
            
         SELECT @b_RestrictionsPassed = 0
         GOTO RESTRICTIONCHECKDONE
      END
      ELSE
      BEGIN
         IF @b_Debug = 1
         BEGIN
            SELECT @c_Reason = 'PASSED Location type ' + RTRIM(@c_Loc_Type) + ' was NOT one of the excluded values'
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                        @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                        @c_ToLoc, @c_Reason

         END
         IF @b_Debug = 2
            PRINT '>> Reason: ' + 'PASSED Location type ' + RTRIM(@c_Loc_Type) + ' was NOT one of the excluded values'         
      END
   END

   IF ISNULL(RTRIM(@cpa_LocationTypeRestriction01),'') <> '' OR
      ISNULL(RTRIM(@cpa_LocationTypeRestriction02),'') <> '' OR
      ISNULL(RTRIM(@cpa_LocationTypeRestriction03),'') <> ''
   BEGIN
      IF @c_Loc_Type NOT IN (@cpa_LocationTypeRestriction01,@cpa_LocationTypeRestriction02,@cpa_LocationTypeRestriction03)
      BEGIN
         IF @b_Debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED Location type ' + RTRIM(@c_Loc_Type) + ' was NOT one of the specified values'
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                 @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                        @c_ToLoc, @c_Reason   
         END
         IF @b_Debug = 2
            PRINT '>> Reason: ' + 'FAILED Location type ' + RTRIM(@c_Loc_Type) + ' was NOT one of the specified values'
                           
         SELECT @b_RestrictionsPassed = 0
         GOTO RESTRICTIONCHECKDONE
      END
      ELSE
      BEGIN
         IF @b_Debug = 1
         BEGIN
            SELECT @c_Reason = 'PASSED Location type ' + RTRIM(@c_Loc_Type) + ' was one of the specified values'
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                        @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                        @c_ToLoc, @c_Reason
         END
         IF @b_Debug = 2
            PRINT '>> Reason: ' + 'PASSED Location type ' + RTRIM(@c_Loc_Type) + ' was one of the specified values'         
      END
   END

   SELECT @c_loc_flag = LTRIM(@c_loc_flag)

   IF ISNULL(RTRIM(@c_loc_flag),'') <> ''
   BEGIN
      IF @c_loc_flag IN (@cpa_LocationFlagexclude01,@cpa_LocationFlagexclude02,@cpa_LocationFlagexclude03)
      BEGIN
         IF @b_Debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED Location flag ' + RTRIM(@c_loc_flag) + ' was one of the excluded values'
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                        @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                        @c_ToLoc, @c_Reason
         END
         IF @b_Debug = 2
            PRINT '>> Reason: ' + 'FAILED Location flag ' + RTRIM(@c_loc_flag) + ' was one of the excluded values'
                     
         SELECT @b_RestrictionsPassed = 0
         GOTO RESTRICTIONCHECKDONE
      END
      ELSE
      BEGIN
         IF @b_Debug = 1
         BEGIN
            SELECT @c_Reason = 'PASSED Location flag ' + RTRIM(@c_loc_flag) + ' was NOT one of the excluded values'
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                        @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                        @c_ToLoc, @c_Reason
         END
         IF @b_Debug = 2
            PRINT '>> Reason: ' + 'PASSED Location flag ' + RTRIM(@c_loc_flag) + ' was NOT one of the excluded values'         
      END
   END

   IF ISNULL(RTRIM(@cpa_LocationFlagInclude01),'') <> '' OR
      ISNULL(RTRIM(@cpa_LocationFlagInclude02),'') <> '' OR
      ISNULL(RTRIM(@cpa_LocationFlagInclude03),'') <> ''
   BEGIN
      IF @c_loc_flag NOT IN (@cpa_LocationFlagInclude01,@cpa_LocationFlagInclude02,@cpa_LocationFlagInclude03)
      BEGIN
         IF @b_Debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED Location flag ' + RTRIM(@c_loc_flag) + ' was NOT one of the specified values'
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                        @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                        @c_ToLoc, @c_Reason
         END
         IF @b_Debug = 2
            PRINT '>> Reason: ' + 'FAILED Location flag ' + RTRIM(@c_loc_flag) + ' was NOT one of the specified values'
                     
         SELECT @b_RestrictionsPassed = 0
         GOTO RESTRICTIONCHECKDONE
      END
      ELSE
      BEGIN
         IF @b_Debug = 1
         BEGIN
            SELECT @c_Reason = 'PASSED Location flag ' + RTRIM(@c_loc_flag) + ' was one of the specified values'
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                        @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                        @c_ToLoc, @c_Reason
         END
         IF @b_Debug = 2
            PRINT '>> Reason: ' + 'PASSED Location flag ' + RTRIM(@c_loc_flag) + ' was one of the specified values'         
      END
   END

   SELECT @c_loc_category = LTRIM(@c_loc_category)

   IF ISNULL(RTRIM(@c_loc_category),'') <> ''
   BEGIN
      IF @c_loc_category IN (@cpa_LocationCategoryexclude01,@cpa_LocationCategoryexclude02,@cpa_LocationCategoryexclude03)
      BEGIN
         IF @b_Debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED Location category ' + RTRIM(@c_loc_category) + ' was one of the excluded values'
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                        @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                        @c_ToLoc, @c_Reason
         END
         IF @b_Debug = 2
            PRINT '>> Reason: ' + 'FAILED Location category ' + RTRIM(@c_loc_category) + ' was one of the excluded values'    
                 
         SELECT @b_RestrictionsPassed = 0
         GOTO RESTRICTIONCHECKDONE
      END
      ELSE
      BEGIN
         IF @b_Debug = 1
         BEGIN
            SELECT @c_Reason = 'PASSED Location category ' + RTRIM(@c_loc_category) + ' was NOT one of the excluded values'
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                        @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                        @c_ToLoc, @c_Reason
         END
         IF @b_Debug = 2
            PRINT '>> Reason: ' + 'PASSED Location category ' + RTRIM(@c_loc_category) + ' was NOT one of the excluded values'         
      END
   END

   IF ISNULL(RTRIM(@cpa_LocationCategoryInclude01),'') <> '' OR
      ISNULL(RTRIM(@cpa_LocationCategoryInclude02),'') <> '' OR
      ISNULL(RTRIM(@cpa_LocationCategoryInclude03),'') <> ''
   BEGIN
      IF @c_loc_category NOT IN (@cpa_LocationCategoryInclude01,@cpa_LocationCategoryInclude02,@cpa_LocationCategoryInclude03)
      BEGIN
         IF @b_Debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED Location category ' + RTRIM(@c_loc_category) + ' was NOT one of the specified values'
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                        @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                        @c_ToLoc, @c_Reason
         END
         IF @b_Debug = 2
            PRINT '>> Reason: ' + 'FAILED Location category ' + RTRIM(@c_loc_category) + ' was NOT one of the specified values'
                     
         SELECT @b_RestrictionsPassed = 0
         GOTO RESTRICTIONCHECKDONE
      END
      ELSE
      BEGIN
         IF @cpa_LocationCategoryInclude01 = 'DRIVEIN'
         BEGIN
            IF NOT EXISTS (SELECT 1 FROM LOTxLOCxID WITH (NOLOCK)
                                    JOIN LotAttribute WITH (NOLOCK) ON LOTxLOCxID.lot = LotAttribute.lot
                           WHERE LotAttribute.Lottable01 = @c_Lottable01
                             AND LotAttribute.Lottable02 = @c_Lottable02
                             AND LotAttribute.sku = @c_SKU
                             AND LotAttribute.StorerKey = @c_StorerKey
                             AND LOTxLOCxID.loc = @c_ToLoc)
            BEGIN
               IF (SELECT ISNULL( SUM(Qty), 0) FROM SKUxLOC WITH (NOLOCK) WHERE Loc = @c_ToLoc) > 0
               BEGIN
                  IF @b_Debug = 1
                  BEGIN
                     SELECT @c_Reason = 'FAILED Location category DRIVEIN ' + RTRIM(@c_loc_category) + ' Contain Different LOT AttributeS.'
                     EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                                 @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                                 @c_ToLoc, @c_Reason
                  END
                  IF @b_Debug = 2
                     PRINT '>> Reason: ' + 'FAILED Location category DRIVEIN ' + RTRIM(@c_loc_category) + ' Contain Different LOT AttributeS.'
                                          
                  SELECT @b_RestrictionsPassed = 0
                  GOTO RESTRICTIONCHECKDONE
               END
            END
         END
         -- END : by Wally 18.jan.2002
         /* CDC Migration Start */
         -- Added By SHONG 22.Jul.2002
         IF @c_loc_category = 'DOUBLEDEEP'
         BEGIN
            IF NOT EXISTS (SELECT 1
                           FROM LOTxLOCxID WITH (NOLOCK)
                           JOIN LotAttribute (NOLOCK) ON LOTxLOCxID.Lot = LotAttribute.Lot
                           WHERE LotAttribute.Lottable04 = @d_Lottable04
                           AND LotAttribute.Lottable02 = @c_Lottable02
                           AND LotAttribute.sku = @c_SKU
                    AND LotAttribute.StorerKey = @c_StorerKey
                           AND LOTxLOCxID.loc = @c_ToLoc)
            BEGIN
               IF (SELECT ISNULL( SUM(Qty), 0) FROM SKUxLOC WITH (NOLOCK) WHERE Loc = @c_ToLoc) > 0
               BEGIN
                  IF @b_Debug = 1
                  BEGIN
                     SELECT @c_Reason = 'FAILED Location category DOUBLEDEEP ' + RTRIM(@c_loc_category) + ' Contain Different LOT AttributeS.'
                     EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                                 @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                                 @c_ToLoc, @c_Reason
                  END
                  IF @b_Debug = 2
                     PRINT '>> Reason: ' + 'FAILED Location category DOUBLEDEEP ' + RTRIM(@c_loc_category) + ' Contain Different LOT AttributeS.'
                  
                  SELECT @b_RestrictionsPassed = 0
                  GOTO RESTRICTIONCHECKDONE
               END
            END
         END
         -- END : by Shong 22.Jul.2002
         /* CDC Migration END */
         IF @b_Debug = 1
         BEGIN
            SELECT @c_Reason = 'PASSED Location category ' + RTRIM(@c_loc_category) + ' was one of the specified values'
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                        @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                        @c_ToLoc, @c_Reason
         END
         IF @b_Debug = 2
            PRINT '>> Reason: ' + 'PASSED Location category ' + RTRIM(@c_loc_category) + ' was one of the specified values'         
      END
   END -- LocationCategory Checkign

   IF ISNULL(RTRIM(@c_loc_Handling),'') <> '' AND
     (ISNULL(RTRIM(@cpa_LocationHandlingExclude01),'') <> '' OR
      ISNULL(RTRIM(@cpa_LocationHandlingExclude02),'') <> '' OR
      ISNULL(RTRIM(@cpa_LocationHandlingExclude03),'') <> '' )
   BEGIN
      IF @c_loc_handling IN (@cpa_LocationHandlingExclude01,@cpa_LocationHandlingExclude02,@cpa_LocationHandlingExclude03)
      BEGIN
         IF @b_Debug = 1
         BEGIN
           SELECT @c_Reason = 'FAILED Location handling ' + RTRIM(@c_loc_handling) + ' was one of the excluded values'
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                        @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                        @c_ToLoc, @c_Reason
         END
         IF @b_Debug = 2
            PRINT '>> Reason: ' + 'FAILED Location handling ' + RTRIM(@c_loc_handling) + ' was one of the excluded values'   
                  
         SELECT @b_RestrictionsPassed = 0
         GOTO RESTRICTIONCHECKDONE
      END
   ELSE
      BEGIN
         IF @b_Debug = 1
         BEGIN
            SELECT @c_Reason = 'PASSED Location handling ' + RTRIM(@c_loc_handling) + ' was NOT one of the excluded values'
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                        @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                        @c_ToLoc, @c_Reason
         END
         IF @b_Debug = 2
            PRINT '>> Reason: ' + 'PASSED Location handling ' + RTRIM(@c_loc_handling) + ' was NOT one of the excluded values'         
      END
   END

   IF ISNULL(RTRIM(@cpa_LocationHandlingInclude01),'') <> '' OR
      ISNULL(RTRIM(@cpa_LocationHandlingInclude02),'') <> '' OR
      ISNULL(RTRIM(@cpa_LocationHandlingInclude03),'') <> ''
   BEGIN
      IF @c_loc_handling NOT IN (@cpa_LocationHandlingInclude01,@cpa_LocationHandlingInclude02,@cpa_LocationHandlingInclude03)
      BEGIN
         IF @b_Debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED Location handling ' + RTRIM(@c_loc_handling) + ' was NOT one of the specified values'
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                        @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                        @c_ToLoc, @c_Reason
         END
         IF @b_Debug = 2
            PRINT '>> Reason: ' + 'FAILED Location handling ' + RTRIM(@c_loc_handling) + ' was NOT one of the specified values'
                     
         SELECT @b_RestrictionsPassed = 0
         GOTO RESTRICTIONCHECKDONE
      END
      ELSE
      BEGIN
         IF @b_Debug = 1
         BEGIN
            SELECT @c_Reason = 'PASSED Location handling ' + RTRIM(@c_loc_handling) + ' was one of the specified values'
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                        @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                        @c_ToLoc, @c_Reason
         END
         IF @b_Debug = 2
            PRINT '>> Reason: ' + 'PASSED Location handling ' + RTRIM(@c_loc_handling) + ' was one of the specified values'         
      END
   END
   
   IF @b_MultiProductID = 1
   BEGIN
      SELECT @n_CurrLocMultiSku = 1
      IF @b_Debug = 1
      BEGIN
         SELECT @c_Reason = 'INFO   Commingled Sku Putaway Pallet Situation'
         EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                     @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                     @c_ToLoc, @c_Reason
      END
   END
   ELSE
   BEGIN
      IF EXISTS(SELECT 1 FROM LOTxLOCxID WITH (NOLOCK) WHERE LOC = @c_ToLoc AND (QTY-QTYPicked > 0 OR PendingMoveIN > 0) --(ung02)
                AND (StorerKey <> @c_StorerKey OR SKU <> @c_SKU))
      BEGIN
         IF @b_Debug = 1
         BEGIN
            SELECT @c_Reason = 'INFO   Commingled Sku Current Loc/Putaway Pallet Situation'
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                        @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                        @c_ToLoc, @c_Reason
         END
         SELECT @n_CurrLocMultiSku = 1
      END
      ELSE
      BEGIN
         SELECT @n_CurrLocMultiSku = 0
      END
   END

   IF @b_MultiLotID = 1
   BEGIN
      SELECT @n_CurrLocMultiLot = 1
      IF @b_Debug = 1
      BEGIN
         SELECT @c_Reason = 'INFO   Commingled Lot Putaway Pallet Situation'
         EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                     @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                     @c_ToLoc, @c_Reason
      END
   END
   ELSE
   BEGIN
      IF EXISTS(SELECT 1 FROM LOTxLOCxID WITH (NOLOCK) WHERE LOC = @c_ToLoc AND (QTY-QTYPicked > 0 OR PendingMoveIN > 0) AND LOT <> @c_LOT) --(ung02)
      BEGIN
         IF @b_Debug = 1
         BEGIN
            SELECT @c_Reason = 'INFO   Commingled Lot Current Loc/Putaway Pallet Situation'
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                        @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                        @c_ToLoc, @c_Reason
         END
         SELECT @n_CurrLocMultiLot = 1
      END
      ELSE
      BEGIN
         SELECT @n_CurrLocMultiLot = 0
      END
   END

   IF '2' IN (@cpa_LocationStateRestriction1,@cpa_LocationStateRestriction2,@cpa_LocationStateRestriction3)
          OR @c_Loc_CommingleSku = '0'
   BEGIN
      IF @n_CurrLocMultiSku = 1
      BEGIN
         IF @b_Debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED Do NOT mix commodities but ptwy pallet is commingled. Location commingle flag = ' + RTRIM(@c_Loc_CommingleSku)
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                        @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                        @c_ToLoc, @c_Reason
         END
         IF @b_Debug = 2
            PRINT '>> Reason: ' + 'FAILED Do NOT mix commodities but ptwy pallet is commingled. Location commingle flag = ' + RTRIM(@c_Loc_CommingleSku)
         
         SELECT @b_RestrictionsPassed = 0
         GOTO RESTRICTIONCHECKDONE
      END
      ELSE
      BEGIN
         IF @b_Debug = 1
         BEGIN
            SELECT @c_Reason = 'PASSED Do NOT mix commodities and ptwy pallet is NOT commingled.  Location commingle flag = ' + RTRIM(@c_Loc_CommingleSku)
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                        @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                        @c_ToLoc, @c_Reason
         END
      END
   END

   IF '3' IN (@cpa_LocationStateRestriction1,@cpa_LocationStateRestriction2,@cpa_LocationStateRestriction3)
          OR @c_loc_comminglelot = '0'
   BEGIN
      IF @n_CurrLocMultiLot = 1
      BEGIN
         IF @b_Debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED Do NOT mix lots and ptwy pallet is commingled. Location mix lots flag = ' + RTRIM(@c_loc_comminglelot)
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                        @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                        @c_ToLoc, @c_Reason
         END
         IF @b_Debug = 2
            PRINT '>> Reason: ' + 'FAILED Do NOT mix lots and ptwy pallet is commingled. Location mix lots flag = ' + RTRIM(@c_loc_comminglelot)
         
         SELECT @b_RestrictionsPassed = 0
         GOTO RESTRICTIONCHECKDONE
      END
      ELSE
      BEGIN
         IF @b_Debug = 1
         BEGIN
            SELECT @c_Reason = 'PASSED Do NOT mix lots and ptwy pallet is NOT commingled. Location mix lots flag = ' + RTRIM(@c_loc_comminglelot)
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                        @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                        @c_ToLoc, @c_Reason
         END
      END
   END

   -- Check NoMixLottable but commingleSKU (ung05)
   IF @c_loc_NoMixLottable01 = '1' OR @c_loc_NoMixLottable02 = '1' OR @c_loc_NoMixLottable03 = '1' OR @c_loc_NoMixLottable04 = '1'
      OR @c_loc_NoMixLottable04 = '1'
      OR @c_loc_NoMixLottable06 = '1'
      OR @c_loc_NoMixLottable07 = '1'
      OR @c_loc_NoMixLottable08 = '1'
      OR @c_loc_NoMixLottable09 = '1'
      OR @c_loc_NoMixLottable10 = '1'
      OR @c_loc_NoMixLottable11 = '1'
      OR @c_loc_NoMixLottable12 = '1'
      OR @c_loc_NoMixLottable13 = '1'
      OR @c_loc_NoMixLottable14 = '1'
      OR @c_loc_NoMixLottable15 = '1'
   BEGIN
      DECLARE @c_ToLOCSKU NVARCHAR( 20)
      SET @c_ToLOCSKU = ''

      IF @b_PutawayBySKU = 'Y'
         SELECT TOP 1
            @c_ToLOCSKU = SKU
         FROM LOTxLOCxID LLI WITH (NOLOCK)
         WHERE LLI.LOC = @c_ToLOC
            AND (LLI.StorerKey <> @c_StorerKey OR LLI.SKU <> @c_SKU)
            AND LLI.QTY-LLI.QTYPicked > 0
      ELSE
         SELECT TOP 1
            @c_ToLOCSKU = LOTxLOCxID.SKU
         FROM LOTxLOCxID WITH (NOLOCK)
            JOIN LOTAttribute WITH (NOLOCK) ON (LOTxLOCxID.LOT = LOTAttribute.LOT)
         WHERE LOTxLOCxID.LOC = @c_FromLoc
            AND LOTxLOCxID.ID = @c_ID
            AND (LOTxLOCxID.QTY-LOTxLOCxID.QTYPicked > 0)
            AND EXISTS (SELECT TOP 1 1
                  FROM LOTxLOCxID ToLLI WITH (NOLOCK)
                  JOIN LOTAttribute ToLA WITH (NOLOCK) ON (ToLLI.LOT = ToLA.LOT)
                  WHERE ToLLI.LOC = @c_ToLoc
                  AND (ToLLI.StorerKey <> LOTxLOCxID.StorerKey OR ToLLI.SKU <> LOTxLOCxID.SKU)
                  AND (ToLLI.QTY-ToLLI.QTYPicked > 0 OR ToLLI.PendingMoveIn > 0))

      IF @c_ToLOCSKU <> ''
      BEGIN
         -- (ChewKP10)
         IF @c_ChkLocByCommingleSkuFlag = '0'
         BEGIN
            IF @b_Debug = 1
            BEGIN
               SELECT @c_Reason = 'FAILED Do NOT mix lottables. CommingleSKU' +
                  '. From=' + RTRIM( @c_SKU) +
                  ', To=' + RTRIM( @c_ToLOCSKU)
               EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
            END

            SET @b_RestrictionsPassed = 0
            GOTO RESTRICTIONCHECKDONE
          END
      END
   END

   -- (ChewKP09)

   DECLARE   @c_From_Lottable      NVARCHAR( 30)
           , @c_To_Lottable        NVARCHAR( 30)
           , @c_SKU_MixLottable    NVARCHAR( 20)
           , @c_Storer_MixLottable NVARCHAR( 15)
           , @c_ExecStatements     NVARCHAR(4000)
           , @c_ExecArguments      NVARCHAR(4000)
           , @n_LottableNo         INT
           , @c_TempLottable       NVARCHAR(10)

   DELETE FROM @NotMixLottable
   IF @c_loc_NoMixLottable01 = '1'
      INSERT INTO @NotMixLottable (LottableNo ) VALUES (1)

   IF @c_loc_NoMixLottable02 = '1'
      INSERT INTO @NotMixLottable (LottableNo ) VALUES (2)

   IF @c_loc_NoMixLottable03 = '1'
      INSERT INTO @NotMixLottable (LottableNo ) VALUES (3)

   IF @c_loc_NoMixLottable04 = '1'
      INSERT INTO @NotMixLottable (LottableNo ) VALUES (4)

   IF @c_loc_NoMixLottable06 = '1'
      INSERT INTO @NotMixLottable (LottableNo ) VALUES (6)

   IF @c_loc_NoMixLottable07 = '1'
      INSERT INTO @NotMixLottable (LottableNo ) VALUES (7)

   IF @c_loc_NoMixLottable08 = '1'
      INSERT INTO @NotMixLottable (LottableNo ) VALUES (8)

   IF @c_loc_NoMixLottable09 = '1'
      INSERT INTO @NotMixLottable (LottableNo ) VALUES (9)

   IF @c_loc_NoMixLottable10 = '1'
      INSERT INTO @NotMixLottable (LottableNo ) VALUES (10)

   IF @c_loc_NoMixLottable11 = '1'
      INSERT INTO @NotMixLottable (LottableNo ) VALUES (11)

   IF @c_loc_NoMixLottable12 = '1'
      INSERT INTO @NotMixLottable (LottableNo ) VALUES (12)

   IF @c_loc_NoMixLottable13 = '1'
      INSERT INTO @NotMixLottable (LottableNo ) VALUES (13)

   IF @c_loc_NoMixLottable14 = '1'
      INSERT INTO @NotMixLottable (LottableNo ) VALUES (14)

   IF @c_loc_NoMixLottable15 = '1'
      INSERT INTO @NotMixLottable (LottableNo ) VALUES (15)

   DECLARE CurNotMixLottable CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT LottableNo
   FROM @NotMixLottable
   ORDER BY LottableNo

   OPEN CurNotMixLottable

   FETCH NEXT FROM CurNotMixLottable INTO @n_LottableNo

   WHILE @@FETCH_STATUS <> -1
   BEGIN

      SET @c_From_Lottable      = ''
      SET @c_To_Lottable        = ''
      SET @c_SKU_MixLottable    = ''
      SET @c_Storer_MixLottable = ''
      SET @c_TempLottable = 'Lottable' + RIGHT('00' + CONVERT(varchar, @n_LottableNo) , 2)
      SET @c_ExecStatements     = ''
      SET @c_ExecArguments      = ''



      IF @c_ChkLocByCommingleSkuFlag = '0'
      BEGIN
         SELECT TOP 1
            @c_ToLOCSKU = SKU
         FROM LOTxLOCxID LLI WITH (NOLOCK)
         WHERE LLI.LOC = @c_ToLOC
            AND (LLI.StorerKey <> @c_StorerKey OR LLI.SKU <> @c_SKU)
            AND LLI.QTY-LLI.QTYPicked > 0

         IF @c_ToLOCSKU <> ''
         BEGIN
            IF @b_Debug = 1
            BEGIN
               SELECT @c_Reason = 'FAILED Do NOT mix lottables. CommingleSKU' +
                  '. From=' + RTRIM( @c_SKU) +
                  ', To=' + RTRIM( @c_ToLOCSKU)
               EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
            END

            SELECT @b_RestrictionsPassed = 0
            BREAK
         END
      END

      SET @c_ExecStatements = N' SELECT TOP 1                                                             '+
                               + '    @c_Storer_MixLottable = LOTxLOCxID.StorerKey,                           '+
                               + '    @c_SKU_MixLottable = LOTxLOCxID.SKU,                                    '+
                               + '    @c_From_Lottable = LOTAttribute.' + @c_TempLottable
                               + ' FROM LOTxLOCxID WITH (NOLOCK)                                              '+
                               + ' JOIN LOTAttribute WITH (NOLOCK) ON (LOTxLOCxID.LOT = LOTAttribute.LOT)  '+
                               + ' WHERE LOTxLOCxID.LOC = @c_FromLoc '+
                               + ' AND LOTxLOCxID.ID = @c_ID '+
                               + ' AND LOTxLOCxID.StorerKey = @c_StorerKey '+
                               + ' AND LOTxLOCxID.SKU = @c_SKU '+
                               + ' AND (LOTxLOCxID.QTY-LOTxLOCxID.QTYPicked > 0)                           '+
                               + ' AND EXISTS (SELECT TOP 1 1                                              '+
                               + '     FROM LOTxLOCxID ToLLI WITH (NOLOCK)                                  '+
                               + '     JOIN LOTAttribute ToLA WITH (NOLOCK) ON (ToLLI.LOT = ToLA.LOT)    '+
                               + '     WHERE ToLLI.LOC = @c_ToLoc '+
                               + '     AND ToLLI.StorerKey = @c_StorerKey '+
                               CASE WHEN @c_ChkNoMixLottableForAllSku = '1' THEN ' ' ELSE 
                                 '     AND ToLLI.SKU = @c_SKU ' END +  --NJOW03
                               + '     AND ToLA.' + @c_TempLottable + ' <> LOTAttribute.' + @c_TempLottable
                               + '     AND (ToLLI.QTY-ToLLI.QTYPicked > 0 OR ToLLI.PendingMoveIn > 0))   '



       --SELECT @c_ExecStatements
      SET @c_ExecArguments = N'@c_FromLoc NVARCHAR(10)' +
                              ',@c_ID  NVARCHAR(18) ' +
                              ',@c_StorerKey NVARCHAR(15)' +
                              ',@c_SKU NVARCHAR(20)' +
                              ',@c_ToLoc NVARCHAR(10)' +
                              ',@c_Storer_MixLottable NVARCHAR(15) OUTPUT' +
                              ',@c_SKU_MixLottable  NVARCHAR(20) OUTPUT  ' +
                              ',@c_From_Lottable    NVARCHAR(30) OUTPUT'

      IF @b_Debug = 2
      BEGIN
         PRINT 'PA Type: ' + @cpa_PAType + ' >>> ' + @c_ExecStatements
      END
                     
      EXECUTE sp_ExecuteSql  @c_ExecStatements
                              , @c_ExecArguments
                              , @c_FromLoc
                              , @c_ID
                              , @c_StorerKey
                              , @c_SKU
                              , @c_ToLoc
                              , @c_Storer_MixLottable OUTPUT
                              , @c_SKU_MixLottable    OUTPUT
                              , @c_From_Lottable      OUTPUT



      IF @c_SKU_MixLottable <> ''
      BEGIN
         IF @b_Debug = 1
         BEGIN
            SET @c_ExecStatements = ''
            SET @c_ExecArguments = ''
            SET @c_To_Lottable   = ''

            SET @c_ExecStatements = N' SELECT TOP 1 @c_To_Lottable = ToLA.' + @c_TempLottable
                                       +' FROM LOTxLOCxID ToLLI WITH (NOLOCK)                                '+
                                       +' JOIN LOTAttribute ToLA WITH (NOLOCK) ON (ToLLI.LOT = ToLA.LOT)  '+
                                       +' WHERE ToLLI.LOC = @c_ToLoc '+
                                       +'    AND ToLLI.StorerKey = @c_Storer_MixLottable '+
                                       CASE WHEN @c_ChkNoMixLottableForAllSku = '1' THEN ' ' ELSE                                        
                                       '    AND ToLLI.SKU = @c_SKU_MixLottable ' END +   --NJOW03
                                       +'    AND ToLA.' + @c_TempLottable + ' <> @c_From_Lottable '
                                       +'    AND (ToLLI.QTY-ToLLI.QTYPicked > 0 OR ToLLI.PendingMoveIn > 0)  '



            --SELECT @c_ExecStatements
            SET @c_ExecArguments = N' @c_To_Lottable NVARCHAR(15) OUTPUT' +
                                    ',@c_ToLoc NVARCHAR(10)' +
                                    ',@c_Storer_MixLottable NVARCHAR(15)'+
                                    ',@c_SKU_MixLottable  NVARCHAR(20)'+
                                    ',@c_From_Lottable    NVARCHAR(30)'

            IF @b_Debug = 2
            BEGIN
               PRINT 'PA Type: ' + @cpa_PAType + ' >>> ' + @c_ExecStatements
            END
                     
            EXECUTE sp_ExecuteSql  @c_ExecStatements
                                 , @c_ExecArguments
                                 , @c_To_Lottable OUTPUT
                                 , @c_ToLoc
                                 , @c_Storer_MixLottable
                                 , @c_SKU_MixLottable
                                 , @c_From_Lottable


            SELECT @c_Reason = 'FAILED Do NOT mix ' + @c_TempLottable +
               '. ' + @c_TempLottable + '=' + RTRIM( @c_From_Lottable) +
               ', To=' + RTRIM( @c_To_Lottable) +
               ', SKU=' + RTRIM( @c_SKU_MixLottable)
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
         END

         SELECT @b_RestrictionsPassed = 0
         BREAK
         --GOTO RESTRICTIONCHECKDONE
      END
      ELSE
      BEGIN
         IF @b_Debug = 1
         BEGIN
            SELECT @c_Reason = 'PASSED Do NOT mix ' + @c_TempLottable --+ '. Location NoMixLottable01 flag = ' +
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
         END

      END

      FETCH NEXT FROM CurNotMixLottable INTO @n_LottableNo
   END
   CLOSE CurNotMixLottable
   DEALLOCATE CurNotMixLottable

   IF @b_RestrictionsPassed = 0
   BEGIN
      GOTO RESTRICTIONCHECKDONE
   END

   -- Added By SHONG - Check Max Pallet
   -- END Check Pallet
   SELECT @cpa_AreaTypeExclude01 = LTRIM(@cpa_AreaTypeExclude01)

   IF ISNULL(RTRIM(@cpa_AreaTypeExclude01),'') <> ''
   BEGIN
      IF EXISTS(SELECT * FROM AREADETAIL WITH (NOLOCK) WHERE PutawayZone = @c_loc_zone AND AREAKEY = @cpa_AreaTypeExclude01)
      BEGIN
         IF @b_Debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED Zone: ' + RTRIM(@c_loc_zone) + ' falls in excluded Area1: ' +  RTRIM(@cpa_AreaTypeExclude01)
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                        @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                        @c_ToLoc, @c_Reason
         END
         SELECT @b_RestrictionsPassed = 0
         GOTO RESTRICTIONCHECKDONE
      END
      ELSE
      BEGIN
         IF @b_Debug = 1
         BEGIN
            SELECT @c_Reason = 'PASSED Zone1 ' + RTRIM(@c_loc_zone) + ' is NOT excluded'
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                        @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                        @c_ToLoc, @c_Reason
         END
      END
   END

   SELECT @cpa_AreaTypeExclude02 = LTRIM(@cpa_AreaTypeExclude02)

   IF ISNULL(RTRIM(@cpa_AreaTypeExclude02),'') <> ''
   BEGIN
      IF EXISTS(SELECT 1 FROM AREADETAIL (NOLOCK) WHERE PutawayZone = @c_loc_zone AND AREAKEY = @cpa_AreaTypeExclude02)
      BEGIN
         IF @b_Debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED Zone: ' + RTRIM(@c_loc_zone) + ' falls in excluded Area2: ' +  RTRIM(@cpa_AreaTypeExclude02)
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                        @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                        @c_ToLoc, @c_Reason
         END
         SELECT @b_RestrictionsPassed = 0
         GOTO RESTRICTIONCHECKDONE
      END
      ELSE
      BEGIN
         IF @b_Debug = 1
         BEGIN
            SELECT @c_Reason = 'PASSED Zone2 ' + RTRIM(@c_loc_zone) + ' is NOT excluded'
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                        @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                        @c_ToLoc, @c_Reason
         END
      END
   END

   SELECT @cpa_AreaTypeExclude03 = LTRIM(@cpa_AreaTypeExclude03)

   IF ISNULL(RTRIM(@cpa_AreaTypeExclude03),'') <> ''
   BEGIN
      IF EXISTS(SELECT 1 FROM AREADETAIL WITH (NOLOCK) WHERE PutawayZone = @c_loc_zone AND AREAKEY = @cpa_AreaTypeExclude03)
      BEGIN
         IF @b_Debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED Zone: ' + RTRIM(@c_loc_zone) + ' falls in excluded Area3:' +  RTRIM(@cpa_AreaTypeExclude03)
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                        @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                        @c_ToLoc, @c_Reason
         END
         SELECT @b_RestrictionsPassed = 0
         GOTO RESTRICTIONCHECKDONE
      END
      ELSE
      BEGIN
         IF @b_Debug = 1
         BEGIN
            SELECT @c_Reason = 'PASSED Zone3 ' + RTRIM(@c_loc_zone) + ' is NOT excluded'
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                        @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                        @c_ToLoc, @c_Reason
         END
      END
   END

   IF '1' IN (@cpa_LocationStateRestriction1,@cpa_LocationStateRestriction2,@cpa_LocationStateRestriction3)
   BEGIN
      IF EXISTS(SELECT 1 FROM LOTxLOCxID WITH (NOLOCK) WHERE LOC = @c_ToLoc AND ((QTY - QtyPicked) > 0 OR PendingMoveIN > 0))  -- (ChewKP05)
      BEGIN
         IF @b_Debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED Location state says Location must be empty, but its NOT'
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                        @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                        @c_ToLoc, @c_Reason
         END
         SELECT @b_RestrictionsPassed = 0
         GOTO RESTRICTIONCHECKDONE
      END
      ELSE
      BEGIN
         IF @b_Debug = 1
         BEGIN
            SELECT @c_Reason = 'PASSED Location state says Location must be empty, and it is'
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                        @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                        @c_ToLoc, @c_Reason
         END
      END
   END

   IF '2' IN (@cpa_LocationStateRestriction1,@cpa_LocationStateRestriction2,@cpa_LocationStateRestriction3)
          OR @c_Loc_CommingleSku = '0'
   BEGIN
      IF @n_CurrLocMultiSku = 1
      BEGIN
         IF @b_Debug = 1
         BEGIN
    SELECT @c_Reason = 'FAILED Do NOT mix commodities'
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                        @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                        @c_ToLoc, @c_Reason
         END
         SELECT @b_RestrictionsPassed = 0
         GOTO RESTRICTIONCHECKDONE
      END
      ELSE
      BEGIN
         IF @b_Debug = 1
         BEGIN
            SELECT @c_Reason = 'PASSED do NOT mix commodities'
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                        @c_ToLoc, @c_Reason
         END
      END
   END

   IF '3' IN (@cpa_LocationStateRestriction1,@cpa_LocationStateRestriction2,@cpa_LocationStateRestriction3)
          OR @c_loc_comminglelot = '0'
   BEGIN
      IF @n_CurrLocMultiLot = 1
      BEGIN
         IF @b_Debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED Do NOT mix lots'
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                  @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                  @c_ToLoc, @c_Reason
         END
         SELECT @b_RestrictionsPassed = 0
         GOTO RESTRICTIONCHECKDONE
      END
      ELSE
      BEGIN
         IF @b_Debug = 1
         BEGIN
      SELECT @c_Reason = 'PASSED Do NOT mix lots'
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                  @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                  @c_ToLoc, @c_Reason
         END
      END
   END

   IF '4' IN (@cpa_LocationStateRestriction1,@cpa_LocationStateRestriction2,@cpa_LocationStateRestriction3)
   BEGIN
      -- get the pallet setup
      SELECT @n_MaxPallet = (CASE MaxPallet WHEN NULL THEN 0 ELSE MaxPallet END) FROM LOC WITH (NOLOCK) WHERE LOC = @c_ToLoc

      IF @n_MaxPallet > 0
      BEGIN
         SELECT @n_PalletQty = 0

         SELECT @n_PalletQty = ISNULL( COUNT(DISTINCT ID), 0)
         FROM   LOTxLOCxID WITH (NOLOCK)
         WHERE  LOC = @c_ToLoc
         AND  ( (Qty - QtyPicked) > 0 OR PendingMoveIn > 0 ) -- SOS#122545

         IF @n_PalletQty >= @n_MaxPallet
         BEGIN
            IF @b_Debug = 1
            BEGIN
               SELECT @c_Reason = 'FAILED - Fit By Max Pallet, Max Pallet: ' + RTRIM(CAST(@n_MaxPallet as NVARCHAR(10))) +
                                  ' Pallet Required: ' +  RTRIM( CAST((@n_PalletQty + 1) as NVARCHAR(10)))
               EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                           @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                           @c_ToLoc, @c_Reason
            END
            SELECT @b_RestrictionsPassed = 0
            GOTO RESTRICTIONCHECKDONE
         END
         ELSE
         BEGIN
            IF @b_Debug = 1
            BEGIN
               SELECT @c_Reason = 'PASSED - Fit By Max Pallet, Max Pallet: ' + RTRIM(CAST(@n_MaxPallet as NVARCHAR(10))) +
                                  ' Pallet Required: ' +  RTRIM( CAST((@n_PalletQty + 1) as NVARCHAR(10)))
               EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                           @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                           @c_ToLoc, @c_Reason
            END
         END
      END
   END

   -- Added by MaryVong on 20-Jul-2005 (SOS36712 KCPI) -Start(2)
   IF '5' IN (@cpa_LocationStateRestriction1,@cpa_LocationStateRestriction2,@cpa_LocationStateRestriction3)
   BEGIN
      -- get the pallet setup
      SELECT @n_MaxPallet = (CASE MaxPallet WHEN NULL THEN 0 ELSE MaxPallet END) FROM LOC WITH (NOLOCK) WHERE LOC = @c_ToLoc
      SELECT @n_StackFactor = (CASE StackFactor WHEN NULL THEN 0 ELSE StackFactor END) FROM SKU WITH (NOLOCK) WHERE Storerkey = @c_StorerKey AND Sku = @c_SKU
      SELECT @n_MaxPalletStackFactor = @n_MaxPallet * @n_StackFactor

      IF @b_Debug = 2
      BEGIN
         PRINT '> MaxPallet is ' + CONVERT(CHAR(3),@n_MaxPallet) + 'StackFactor is ' + CONVERT(CHAR(3),@n_StackFactor)
         PRINT '> MaxPallet * StackFactor is ' + CONVERT(CHAR(3),@n_MaxPalletStackFactor)
      END

      IF @n_MaxPalletStackFactor > 0
      BEGIN
         SELECT @n_PalletQty = 0

         SELECT @n_PalletQty = ISNULL( COUNT(DISTINCT ID), 0)
         FROM   LOTxLOCxID WITH (NOLOCK)
         WHERE  LOC = @c_ToLoc
         AND    (Qty > 0 OR PendingMoveIn > 0 )

         IF @n_PalletQty >= @n_MaxPalletStackFactor
         BEGIN
            -- error
            IF @b_Debug = 1
            BEGIN
               SELECT @c_Reason = 'FAILED - Fit By Max Pallet (Stack Factor), Max Pallet: ' + RTRIM(CAST(@n_MaxPallet as NVARCHAR(10))) +
                                  ' Pallet Required: ' +  RTRIM( CAST((@n_PalletQty + 1) as NVARCHAR(10)))
               EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                           @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                           @c_ToLoc, @c_Reason
            END
            SELECT @b_RestrictionsPassed = 0
            GOTO RESTRICTIONCHECKDONE
         END
         ELSE
         BEGIN
            IF @b_Debug = 1
            BEGIN
               SELECT @c_Reason = 'PASSED - Fit By Max Pallet (Stack Factor), Max Pallet: ' + RTRIM(CAST(@n_MaxPallet as NVARCHAR(10))) +
                                  ' Pallet Required: ' +  RTRIM( CAST((@n_PalletQty + 1) as NVARCHAR(10)))
               EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                           @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                           @c_ToLoc, @c_Reason
            END
         END
      END
   END
   -- Added by MaryVong on 20-Jul-2005 (SOS36712 KCPI) -End(2)

   -- Added by MaryVong on 31-Mar-2007 (SOS69388 KFP) -Start(2)
   -- '6' & '7' - Check with MaxPallet for HostWhCode instead of Loc
   -- KFP LOC Setup: Facility    Loc    HostWhCode
   --                Good        LOC1   LOC1
   --                Good        LOC2   LOC2
   --                Quarantine  LOC1Q  LOC1
   --                Quarantine  LOC2Q  LOC2
   IF '6' IN (@cpa_LocationStateRestriction1,@cpa_LocationStateRestriction2,@cpa_LocationStateRestriction3)
   BEGIN
      -- Get the pallet setup
      SELECT @n_MaxPallet = (CASE MaxPallet WHEN NULL THEN 0 ELSE MaxPallet END) FROM LOC WITH (NOLOCK) WHERE LOC = @c_ToLoc

      IF @n_MaxPallet > 0
      BEGIN
         SELECT @n_PalletQty = 0

         SELECT @n_PalletQty = ISNULL( COUNT(DISTINCT ID), 0)
         FROM   LOTxLOCxID WITH (NOLOCK)
         WHERE  LOC IN (SELECT LOC FROM LOC WITH (NOLOCK) WHERE HostWhCode = @c_ToHostWhCode)
         AND    (Qty > 0 OR PendingMoveIn > 0 )

         IF @n_PalletQty >= @n_MaxPallet
         BEGIN
            IF @b_Debug = 1
            BEGIN
               SELECT @c_Reason = 'FAILED - 6 - Fit By Max Pallet, Max Pallet: ' + RTRIM(CAST(@n_MaxPallet as NVARCHAR(10))) +
                                  ' Pallet Required: ' +  RTRIM( CAST((@n_PalletQty + 1) as NVARCHAR(10)))
               EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                           @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                           @c_ToLoc, @c_Reason
            END
            SELECT @b_RestrictionsPassed = 0
            GOTO RESTRICTIONCHECKDONE
         END
         ELSE
         BEGIN
            IF @b_Debug = 1
            BEGIN
               SELECT @c_Reason = 'PASSED - 6 - Fit By Max Pallet, Max Pallet: ' + RTRIM(CAST(@n_MaxPallet as NVARCHAR(10))) +
                                  ' Pallet Required: ' +  RTRIM( CAST((@n_PalletQty + 1) as NVARCHAR(10)))
               EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                           @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                           @c_ToLoc, @c_Reason
            END
         END
      END
   END

   IF '7' IN (@cpa_LocationStateRestriction1,@cpa_LocationStateRestriction2,@cpa_LocationStateRestriction3)
   BEGIN
     -- get the pallet setup
      SELECT @n_MaxPallet = (CASE MaxPallet WHEN NULL THEN 0 ELSE MaxPallet END) FROM LOC WITH (NOLOCK) WHERE LOC = @c_ToLoc
      SELECT @n_StackFactor = (CASE StackFactor WHEN NULL THEN 0 ELSE StackFactor END) FROM SKU WITH (NOLOCK) WHERE Storerkey = @c_StorerKey AND Sku = @c_SKU
      SELECT @n_MaxPalletStackFactor = @n_MaxPallet * @n_StackFactor

      IF @b_Debug = 2
      BEGIN
         PRINT '7 - MaxPallet is ' + CONVERT(CHAR(3),@n_MaxPallet) + 'StackFactor is ' + CONVERT(CHAR(3),@n_StackFactor)
         PRINT '7 - MaxPallet * StackFactor is ' + CONVERT(CHAR(3),@n_MaxPalletStackFactor)
      END

      IF @n_MaxPalletStackFactor > 0
      BEGIN
         SELECT @n_PalletQty = 0

         SELECT @n_PalletQty = ISNULL( COUNT(DISTINCT ID), 0)
         FROM   LOTxLOCxID (NOLOCK)
         -- WHERE  LOC = @c_ToLoc
         WHERE  LOC IN (SELECT LOC FROM LOC WITH (NOLOCK) WHERE HostWhCode = @c_ToHostWhCode)
         AND    (Qty > 0 OR PendingMoveIn > 0 )

         IF @n_PalletQty >= @n_MaxPalletStackFactor
         BEGIN
            -- error
            IF @b_Debug = 1
            BEGIN
               SELECT @c_Reason = 'FAILED - 7 - Fit By Max Pallet (Stack Factor), Max Pallet: ' + RTRIM(CAST(@n_MaxPallet as NVARCHAR(10))) +
                                  ' Pallet Required: ' +  RTRIM( CAST((@n_PalletQty + 1) as NVARCHAR(10)))
               EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                           @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                           @c_ToLoc, @c_Reason
            END
            SELECT @b_RestrictionsPassed = 0
            GOTO RESTRICTIONCHECKDONE
         END
         ELSE
         BEGIN
            IF @b_Debug = 1
            BEGIN
               SELECT @c_Reason = 'PASSED - 7 - Fit By Max Pallet (Stack Factor), Max Pallet: ' + RTRIM(CAST(@n_MaxPallet as NVARCHAR(10))) +
                                  ' Pallet Required: ' +  RTRIM( CAST((@n_PalletQty + 1) as NVARCHAR(10)))
               EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                           @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                           @c_ToLoc, @c_Reason
            END
         END
      END
   END
   -- Added by MaryVong on 31-Mar-2007 (SOS69388 KFP) -End(2)

   -- SOS#140197 (Start)
   IF '10' IN (@cpa_LocationStateRestriction1,@cpa_LocationStateRestriction2,@cpa_LocationStateRestriction3)
   BEGIN
      SET @d_CurrentLottable05 = NULL
      SELECT TOP 1
             @d_CurrentLottable05 = Lottable05
      FROM   LOTxLOCxID LLL WITH (NOLOCK)
      JOIN   LotAttribute LA WITH (NOLOCK) ON LLL.LOT = LA.LOT
      WHERE  LLL.LOC = @c_ToLoc
      AND    LLL.Qty - QtyPicked > 0

      IF @d_CurrentLottable05 IS NOT NULL AND @d_CurrentLottable05 <> @d_Lottable05
      BEGIN
         IF @b_Debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED Do NOT Mix Lottable05, Location Already Contain Lottable05 = ' + CONVERT(varchar(20), @d_CurrentLottable05)
            EXEC nspPTD 'nspRDTPASTD', @n_ptraceheadkey, @c_PutawayStrategyKey,
                        @c_putawaystrategylinenumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
         END
         SELECT @b_restrictionspassed = 0
         GOTO RESTRICTIONCHECKDONE
      END
      ELSE
      BEGIN
         IF @b_Debug = 1
         BEGIN
            SELECT @c_Reason = 'PASSED Do NOT Mix Lottable05'
            EXEC nspPTD 'nspRDTPASTD', @n_ptraceheadkey, @c_PutawayStrategyKey, @c_putawaystrategylinenumber, @n_PtraceDetailKey,
                        @c_ToLoc, @c_Reason
         END
      END
   END
   -- SOS#140197 (End)

   -- SOS# SKU Putaway to restrict by UCC Carton Qty
   IF '11' IN (@cpa_LocationStateRestriction1,@cpa_LocationStateRestriction2,@cpa_LocationStateRestriction3)
   BEGIN
      DECLARE @n_UCC_CartonSize INT

      SET @n_UCC_CartonSize = 0
      SELECT TOP 1 @n_UCC_CartonSize = ISNULL(Qty,0)
      FROM   UCC WITH (NOLOCK)
      WHERE  StorerKey = @c_StorerKey
        AND  SKU = @c_SKU
        AND  Loc = @c_ToLoc
        AND  Status IN ('0','1','2')

      IF @n_UCC_CartonSize <> ISNULL(@n_Qty,0) AND @n_UCC_CartonSize > 0
      BEGIN
         IF @b_Debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED Do NOT Mix UCC Ctn Sz, Loc Ctn Sz= ' + CONVERT(varchar(20), @n_UCC_CartonSize) +
                               '. UCC Ctn Size = ' + CONVERT(varchar(20), @n_Qty)
            EXEC nspPTD 'nspRDTPASTD', @n_ptraceheadkey, @c_PutawayStrategyKey,
                        @c_putawaystrategylinenumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
         END
         SELECT @b_restrictionspassed = 0
         GOTO RESTRICTIONCHECKDONE
      END
      ELSE
      BEGIN
         IF @b_Debug = 1
         BEGIN
            SELECT @c_Reason = 'PASSED Do NOT Mix UCC Ctn Sz, Loc Ctn Sz= ' + CONVERT(varchar(20), @n_UCC_CartonSize) +
                               '. UCC Ctn Size = ' + CONVERT(varchar(20), @n_Qty)
            EXEC nspPTD 'nspRDTPASTD', @n_ptraceheadkey, @c_PutawayStrategyKey, @c_putawaystrategylinenumber, @n_PtraceDetailKey,
                        @c_ToLoc, @c_Reason
         END
      END
   END
   -- SOS# Restrict UCC Carton Size (End)

   -- SOS252964 12-ABC Descending
   IF '12' IN (@cpa_LocationStateRestriction1,@cpa_LocationStateRestriction2,@cpa_LocationStateRestriction3) AND
      @c_SKU <> '' AND @c_loc_ABC <> '' AND @c_SKU_ABC <> ''
   BEGIN
      IF @c_loc_ABC < @c_SKU_ABC
      BEGIN
         IF @b_Debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED ABC descending. LOC ABC = ' + RTRIM( @c_loc_ABC) + '. SKU ABC = ' + RTRIM( @c_SKU_ABC)
            EXEC nspPTD 'nspRDTPASTD', @n_ptraceheadkey, @c_PutawayStrategyKey,
                        @c_putawaystrategylinenumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
         END
         SELECT @b_restrictionspassed = 0
         GOTO RESTRICTIONCHECKDONE
      END
      ELSE
      BEGIN
         IF @b_Debug = 1
         BEGIN
            SELECT @c_Reason = 'PASSED ABC descending. LOC ABC = ' + RTRIM( @c_loc_ABC) + '. SKU ABC = ' + RTRIM( @c_SKU_ABC)
            EXEC nspPTD 'nspRDTPASTD', @n_ptraceheadkey, @c_PutawayStrategyKey, @c_putawaystrategylinenumber, @n_PtraceDetailKey,
                        @c_ToLoc, @c_Reason
         END
      END
   END

   -- SOS252964 13-ABC Exact
   IF '13' IN (@cpa_LocationStateRestriction1,@cpa_LocationStateRestriction2,@cpa_LocationStateRestriction3) AND
      @c_SKU <> '' AND @c_loc_ABC <> '' AND @c_SKU_ABC <> ''
   BEGIN
      IF @c_loc_ABC <> @c_SKU_ABC
      BEGIN
         IF @b_Debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED ABC Exact. LOC ABC = ' + RTRIM( @c_loc_ABC) + '. SKU ABC = ' + RTRIM( @c_SKU_ABC)
            EXEC nspPTD 'nspRDTPASTD', @n_ptraceheadkey, @c_PutawayStrategyKey,
                        @c_putawaystrategylinenumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
         END
         SELECT @b_restrictionspassed = 0
         GOTO RESTRICTIONCHECKDONE
      END
      ELSE
      BEGIN
         IF @b_Debug = 1
         BEGIN
            SELECT @c_Reason = 'PASSED ABC Exact. LOC ABC = ' + RTRIM( @c_loc_ABC) + '. SKU ABC = ' + RTRIM( @c_SKU_ABC)
            EXEC nspPTD 'nspRDTPASTD', @n_ptraceheadkey, @c_PutawayStrategyKey, @c_putawaystrategylinenumber, @n_PtraceDetailKey,
                        @c_ToLoc, @c_Reason
         END
      END
   END

   -- MaxSKU
   IF '14' IN (@cpa_LocationStateRestriction1,@cpa_LocationStateRestriction2,@cpa_LocationStateRestriction3)
   BEGIN
      IF @n_loc_MaxSKU > 0
      BEGIN
         DECLARE @n_MaxSKU INT = 0

         SET @cSQL =
            ' SELECT @n_MaxSKU = COUNT( DISTINCT A.SKU) ' +
            ' FROM ' +
            ' (' +
               ' SELECT SKU ' +
               ' FROM dbo.LOTxLOCxID WITH (NOLOCK) ' +
               ' WHERE LOC = @c_ToLoc ' +
                  ' AND ( (Qty - QtyPicked) > 0 OR PendingMoveIn > 0 ) ' +
               ' UNION ' +
               ' SELECT SKU ' +
               ' FROM dbo.LOTxLOCxID WITH (NOLOCK) ' +
               ' WHERE LOC = @c_FromLoc ' +
                  CASE WHEN @c_ID  = '' THEN '' ELSE ' AND ID  = @c_ID  ' END +
                  CASE WHEN @c_SKU = '' THEN '' ELSE ' AND SKU = @c_SKU ' END +
                  CASE WHEN @c_LOT = '' THEN '' ELSE ' AND LOT = @c_LOT ' END +
                  ' AND QTY - QTYAllocated - QTYPicked > 0 ' +
            ' ) A '

         SET @cSQLParam =
            ' @c_FromLoc   NVARCHAR( 10), ' +
            ' @c_ID        NVARCHAR( 18), ' +
            ' @c_SKU       NVARCHAR( 20), ' +
            ' @c_LOT       NVARCHAR( 10), ' +
            ' @c_ToLoc     NVARCHAR( 10), ' +
            ' @n_MaxSKU    INT OUTPUT     '

         EXEC sp_ExecuteSql @cSQL, @cSQLParam,
            @c_FromLoc  = @c_FromLoc,
            @c_ID       = @c_ID,
            @c_SKU      = @c_SKU,
            @c_LOT      = @c_LOT,
            @c_ToLoc    = @c_ToLoc,
            @n_MaxSKU   = @n_MaxSKU OUTPUT

         IF @n_MaxSKU > @n_loc_MaxSKU
         BEGIN
            IF @b_Debug = 1
            BEGIN
               SELECT @c_Reason = 'FAILED - Fit By Max SKU, LOC.MAXSKU: ' + CAST( @n_loc_MaxSKU as NVARCHAR(10)) +
                                  ' After putaway SKU: ' +  CAST( @n_MaxSKU as NVARCHAR(10))
               EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                           @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                           @c_ToLoc, @c_Reason
            END
            SELECT @b_RestrictionsPassed = 0
            GOTO RESTRICTIONCHECKDONE
         END
         ELSE
         BEGIN
            IF @b_Debug = 1
            BEGIN
               SELECT @c_Reason = 'PASSED - Fit By Max SKU, LOC.MAXSKU: ' + CAST( @n_loc_MaxSKU as NVARCHAR(10)) +
                                  ' After putaway SKU: ' +  CAST( @n_MaxSKU as NVARCHAR(10))
               EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                           @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                           @c_ToLoc, @c_Reason
            END
         END
      END
   END

   -- MaxQTY
   IF '15' IN (@cpa_LocationStateRestriction1,@cpa_LocationStateRestriction2,@cpa_LocationStateRestriction3)
   BEGIN
      IF @n_loc_MaxQTY > 0
      BEGIN
         DECLARE @n_MaxQTY INT = 0

         -- From LOC
         IF @n_QTY > 0
            SET @n_MaxQTY = @n_QTY
         ELSE
         BEGIN
            SET @cSQL =
               ' SELECT @n_MaxQTY = ISNULL( SUM( QTY), 0) ' +
               ' FROM dbo.LOTxLOCxID WITH (NOLOCK) ' +
               ' WHERE LOC = @c_FromLoc ' +
                  CASE WHEN @c_ID  = '' THEN '' ELSE ' AND ID  = @c_ID  ' END +
                  CASE WHEN @c_SKU = '' THEN '' ELSE ' AND SKU = @c_SKU ' END +
                  CASE WHEN @c_LOT = '' THEN '' ELSE ' AND LOT = @c_LOT ' END +
                  ' AND QTY - QTYAllocated - QTYPicked > 0 '

            SET @cSQLParam =
               ' @c_FromLoc   NVARCHAR( 10), ' +
               ' @c_ID        NVARCHAR( 18), ' +
               ' @c_SKU       NVARCHAR( 20), ' +
               ' @c_LOT       NVARCHAR( 10), ' +
               ' @n_MaxQTY    INT OUTPUT     '

            EXEC sp_ExecuteSql @cSQL, @cSQLParam,
               @c_FromLoc  = @c_FromLoc,
               @c_ID       = @c_ID,
               @c_SKU      = @c_SKU,
               @c_LOT      = @c_LOT,
               @n_MaxQTY   = @n_MaxQTY OUTPUT
         END
      END
   END
   -- MaxCarton
   IF '16' IN (@cpa_LocationStateRestriction1,@cpa_LocationStateRestriction2,@cpa_LocationStateRestriction3)
   BEGIN
      IF @n_loc_MaxCarton > 0 AND @c_UCC = '1'
      BEGIN
         DECLARE @n_MaxCarton INT = 0

         -- From LOC
         IF @n_QTY > 0
            SET @n_MaxCarton = 1
         ELSE
         BEGIN
            SET @cSQL =
               ' SELECT @n_MaxCarton = COUNT( DISTINCT UCCNo), 0) ' +
               ' FROM dbo.UCC WITH (NOLOCK) ' +
               ' WHERE LOC = @c_FromLoc ' +
                  CASE WHEN @c_ID  = '' THEN '' ELSE ' AND ID  = @c_ID  ' END +
                  CASE WHEN @c_SKU = '' THEN '' ELSE ' AND SKU = @c_SKU ' END +
                  CASE WHEN @c_LOT = '' THEN '' ELSE ' AND LOT = @c_LOT ' END +
                  ' AND Status IN (''1'', ''3'', ''4'') '

            SET @cSQLParam =
               ' @c_FromLoc   NVARCHAR( 10), ' +
               ' @c_ID        NVARCHAR( 18), ' +
               ' @c_SKU       NVARCHAR( 20), ' +
               ' @c_LOT       NVARCHAR( 10), ' +
               ' @n_MaxCarton INT OUTPUT     '

            EXEC sp_ExecuteSql @cSQL, @cSQLParam,
               @c_FromLoc     = @c_FromLoc,
               @c_ID          = @c_ID,
               @c_SKU         = @c_SKU,
               @c_LOT         = @c_LOT,
               @n_MaxCarton   = @n_MaxCarton OUTPUT
         END

         -- To LOC
         SELECT @n_MaxCarton = @n_MaxCarton + COUNT( DISTINCT UCCNo)
         FROM dbo.UCC WITH (NOLOCK)
         WHERE StorerKey = @c_StorerKey
            AND LOC = @c_ToLoc
            AND Status IN ('1', '3', '4') -- 1=Received, 3=Alloc, 4=Replen

         IF @n_MaxCarton > @n_loc_MaxCarton
         BEGIN
            IF @b_Debug = 1
            BEGIN
               SELECT @c_Reason = 'FAILED - Fit By Max Carton, LOC.MAXCarton: ' + CAST( @n_loc_MaxCarton as NVARCHAR(10)) +
                                  ' After putaway carton: ' +  CAST( @n_MaxCarton as NVARCHAR(10))
               EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                           @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                           @c_ToLoc, @c_Reason
            END
            SELECT @b_RestrictionsPassed = 0
            GOTO RESTRICTIONCHECKDONE
         END
         ELSE
         BEGIN
            IF @b_Debug = 1
            BEGIN
               SELECT @c_Reason = 'PASSED - Fit By Max Carton, LOC.MAXCarton: ' + CAST( @n_loc_MaxCarton as NVARCHAR(10)) +
                                  ' After putaway carton: ' +  CAST( @n_MaxCarton as NVARCHAR(10))
               EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                           @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                           @c_ToLoc, @c_Reason
            END
         END
      END
   END
   -- (SHONG01)
   IF '17' IN (@cpa_LocationStateRestriction1,@cpa_LocationStateRestriction2,@cpa_LocationStateRestriction3) AND
         ISNULL(RTRIM(@c_Lottable02),'') <> ''
   BEGIN
      IF @c_LOC_HostWHCode <> @c_Lottable02
      BEGIN
         IF @b_Debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED HostWHCode <> Lottable02. LOC HostWHCode = ' + RTRIM( @c_LOC_HostWHCode) + '. Lottable02 = ' + RTRIM( @c_Lottable02)
            EXEC nspPTD 'nspRDTPASTD', @n_ptraceheadkey, @c_PutawayStrategyKey,
                        @c_putawaystrategylinenumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
         END
         SELECT @b_restrictionspassed = 0
         GOTO RESTRICTIONCHECKDONE
      END
      ELSE
      BEGIN
         IF @b_Debug = 1
         BEGIN
            SELECT @c_Reason = 'PASSED HostWHCode = Lottable02. LOC HostWHCode = ' + RTRIM( @c_LOC_HostWHCode) + '. Lottable02 = ' + RTRIM( @c_Lottable02)
            EXEC nspPTD 'nspRDTPASTD', @n_ptraceheadkey, @c_PutawayStrategyKey, @c_putawaystrategylinenumber, @n_PtraceDetailKey,
                        @c_ToLoc, @c_Reason
         END
      END
   END   -- SOS#133381 Location Alsie Restriction
   IF ISNULL(RTRIM(@cpa_LocAisleInclude01),'') <> '' OR
      ISNULL(RTRIM(@cpa_LocAisleInclude02),'') <> '' OR
      ISNULL(RTRIM(@cpa_LocAisleInclude03),'') <> '' OR
      ISNULL(RTRIM(@cpa_LocAisleInclude04),'') <> '' OR
      ISNULL(RTRIM(@cpa_LocAisleInclude05),'') <> '' OR
      ISNULL(RTRIM(@cpa_LocAisleInclude06),'') <> ''
   BEGIN
      IF @c_Loc_Aisle NOT IN (@cpa_LocAisleInclude01,@cpa_LocAisleInclude02,@cpa_LocAisleInclude03,
                              @cpa_LocAisleInclude04,@cpa_LocAisleInclude05,@cpa_LocAisleInclude06)
      BEGIN
   IF @b_Debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED Location Aisle ' + RTRIM(@c_Loc_Aisle) + ' was NOT one of the specified values'
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                        @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                        @c_ToLoc, @c_Reason
         END
         SELECT @b_RestrictionsPassed = 0
        GOTO RESTRICTIONCHECKDONE
      END
      ELSE
      BEGIN
         IF @b_Debug = 1
         BEGIN
            SELECT @c_Reason = 'PASSED Location Aisle ' + RTRIM(@c_Loc_Aisle) + ' was one of the specified values'
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                        @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                        @c_ToLoc, @c_Reason
         END
      END
   END

   IF ISNULL(RTRIM(@cpa_LocAisleExclude01),'') <> '' OR
      ISNULL(RTRIM(@cpa_LocAisleExclude02),'') <> '' OR
      ISNULL(RTRIM(@cpa_LocAisleExclude03),'') <> '' OR
      ISNULL(RTRIM(@cpa_LocAisleExclude04),'') <> '' OR
      ISNULL(RTRIM(@cpa_LocAisleExclude05),'') <> '' OR
      ISNULL(RTRIM(@cpa_LocAisleExclude06),'') <> ''
   BEGIN
      IF @c_Loc_Aisle IN (@cpa_LocAisleExclude01,@cpa_LocAisleExclude02,@cpa_LocAisleExclude03,
                 @cpa_LocAisleExclude04,@cpa_LocAisleExclude05,@cpa_LocAisleExclude06)
      BEGIN
         IF @b_Debug = 1
         BEGIN
      SELECT @c_Reason = 'FAILED Location Aisle ' + RTRIM(@c_Loc_Aisle) + ' was one of the excluded values'
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                        @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                        @c_ToLoc, @c_Reason
         END
         SELECT @b_RestrictionsPassed = 0
         GOTO RESTRICTIONCHECKDONE
      END
      ELSE
      BEGIN
         IF @b_Debug = 1
         BEGIN
            SELECT @c_Reason = 'PASSED Location Aisle ' + RTRIM(@c_Loc_Aisle) + ' was NOT one of the excluded values'
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                        @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                        @c_ToLoc, @c_Reason
         END
      END
   END

   IF ISNULL(@npa_LocLevelInclude01,0) <> 0 OR
      ISNULL(@npa_LocLevelInclude02,0) <> 0 OR
      ISNULL(@npa_LocLevelInclude03,0) <> 0 OR
      ISNULL(@npa_LocLevelInclude04,0) <> 0 OR
      ISNULL(@npa_LocLevelInclude05,0) <> 0 OR
      ISNULL(@npa_LocLevelInclude06,0) <> 0
   BEGIN
      IF @n_Loc_Level NOT IN (@npa_LocLevelInclude01,@npa_LocLevelInclude02,@npa_LocLevelInclude03,
                              @npa_LocLevelInclude04,@npa_LocLevelInclude05,@npa_LocLevelInclude06)
      BEGIN
         IF @b_Debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED Location Level ' + RTRIM(CAST(@n_Loc_Level as NVARCHAR(10))) + ' was NOT one of the specified values'
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                        @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                        @c_ToLoc, @c_Reason
         END
         SELECT @b_RestrictionsPassed = 0
         GOTO RESTRICTIONCHECKDONE
      END
      ELSE
      BEGIN
         IF @b_Debug = 1
         BEGIN
            SELECT @c_Reason = 'PASSED Location Level ' + RTRIM(CAST(@n_Loc_Level as NVARCHAR(10))) + ' was one of the specified values'
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                        @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                        @c_ToLoc, @c_Reason
         END
      END
   END

   IF (ISNULL(@npa_LocLevelExclude01,0) <> 0 OR
       ISNULL(@npa_LocLevelExclude02,0) <> 0 OR
       ISNULL(@npa_LocLevelExclude03,0) <> 0 OR
       ISNULL(@npa_LocLevelExclude04,0) <> 0 OR
       ISNULL(@npa_LocLevelExclude05,0) <> 0 OR
       ISNULL(@npa_LocLevelExclude06,0) <> 0 ) AND
       @n_Loc_Level > 0
   BEGIN
      IF @n_Loc_Level IN (@npa_LocLevelExclude01,@npa_LocLevelExclude02,@npa_LocLevelExclude03,
                          @npa_LocLevelExclude04,@npa_LocLevelExclude05,@npa_LocLevelExclude06)
      BEGIN
         IF @b_Debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED Location Level ' + RTRIM(CAST(@n_Loc_Level as NVARCHAR(10))) + ' was NOT one of the excluded values'
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                        @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                     @c_ToLoc, @c_Reason
         END
         SELECT @b_RestrictionsPassed = 0
         GOTO RESTRICTIONCHECKDONE
      END
      ELSE
      BEGIN
         IF @b_Debug = 1
         BEGIN
            SELECT @c_Reason = 'PASSED Location Level ' + RTRIM(CAST(@n_Loc_Level as NVARCHAR(10))) + ' was NOT one of the exclude values'
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                        @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                        @c_ToLoc, @c_Reason
         END
      END
   END

   SELECT @n_PalletWoodWidth  = PACK.PalletWoodWidth,
          @n_PalletWoodLength = PACK.PalletWoodLength,
          @n_PalletWoodHeight = PACK.PalletWoodHeight,
          @n_CaseLength       = PACK.LengthUOM1,
          @n_CaseWidth        = PACK.WidthUOM1,
          @n_CaseHeight       = PACK.HeightUOM1,
          @n_PutawayTI        = PACK.PalletTI,
          @n_PutawayHI        = PACK.PalletHI,
          @n_PackCaseCount    = PACK.CaseCnt,
          @n_CubeUOM1         = PACK.CubeUOM1,
          @n_QtyUOM1          = PACK.CaseCnt,
          @n_CubeUOM3         = PACK.CubeUOM3,
          @n_QtyUOM3          = PACK.Qty,
          @n_CubeUOM4         = PACK.CubeUOM4,
          @n_QtyUOM4          = PACK.Pallet
   FROM PACK (NOLOCK)
   WHERE PACK.Packkey = @c_PackKey

   IF '1' IN (@cpa_DimensionRestriction01,
              @cpa_DimensionRestriction02,
              @cpa_DimensionRestriction03,
              @cpa_DimensionRestriction04,
              @cpa_DimensionRestriction05,
              @cpa_DimensionRestriction06)
   BEGIN
      IF @n_CurrLocMultiLot = 0
      BEGIN
         SELECT @n_QuantityCapacity = 0
         IF @n_CubeUOM3 = 0 OR @n_CubeUOM3 IS NULL
         BEGIN
            SELECT @n_CubeUOM3 = Sku.StdCube
            FROM   SKU WITH (NOLOCK)
            WHERE  SKu.SKU = @c_SKU
            AND    SKU.StorerKey = @c_StorerKey -- SOS# 269085

            IF @n_CubeUOM3 IS NULL
               SELECT @n_CubeUOM3 = 0
         END

         IF @n_CubeUOM3 > 0
         BEGIN
            SELECT @n_UOMcapacity = (@n_Loc_CubicCapacity / @n_CubeUOM3)
            SELECT @n_QuantityCapacity = @n_UOMcapacity
         END
         ELSE
         BEGIN
          SET @n_QuantityCapacity = 0
         END

         SELECT @n_ToQty = SUM(LOTxLOCxID.Qty - LOTxLOCxID.QtyPicked + LOTxLOCxID.PendingMoveIn)
         FROM LOTxLOCxID WITH (NOLOCK)
         WHERE LOTxLOCxID.StorerKey = @c_StorerKey
         AND LOTxLOCxID.Sku = @c_SKU
         AND LOTxLOCxID.Loc = @c_ToLoc
         AND (LOTxLOCxID.Qty > 0 OR LOTxLOCxID.PendingMoveIn > 0)

         IF @n_ToQty IS NULL
         BEGIN
            SELECT @n_ToQty = 0
         END

         IF (@n_ToQty + @n_Qty ) > @n_QuantityCapacity AND @n_QuantityCapacity > 0
         BEGIN
            IF @b_Debug = 1
            BEGIN
               SELECT @c_Reason = 'FAILED Qty Fit: QtyCapacity = ' + RTRIM(CONVERT(char(10),@n_QuantityCapacity)) + '  QtyRequired = ' + RTRIM(Convert(char(10),(@n_ToQty + @n_Qty)))
               EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                           @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                           @c_ToLoc, @c_Reason
            END
            SELECT @b_RestrictionsPassed = 0
            GOTO RESTRICTIONCHECKDONE
         END
        ELSE
         BEGIN
            IF @b_Debug = 1
            BEGIN
               SELECT @c_Reason = 'PASSED Qty Fit: QtyCapacity = ' + RTRIM(CONVERT(char(10),@n_QuantityCapacity)) + '  QtyRequired = ' + RTRIM(Convert(char(10),(@n_ToQty + @n_Qty)))
               EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                           @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                           @c_ToLoc, @c_Reason
            END
         END
      END  -- End of IF @n_CurrLocMultiLot = 0
      ELSE
      BEGIN
         SELECT @n_ToCube = ISNULL( SUM((LOTxLOCxID.Qty - LOTxLOCxID.QtyPicked + LOTxLOCxID.PendingMoveIn) * Sku.StdCube), 0)
         FROM LOTxLOCxID WITH (NOLOCK), SKU WITH (NOLOCK)
         WHERE LOTxLOCxID.StorerKey = @c_StorerKey
         AND LOTxLOCxID.Sku = @c_SKU
         AND LOTxLOCxID.Loc = @c_ToLoc
         AND LOTxLOCxID.StorerKey = sku.StorerKey
         and LOTxLOCxID.sku = sku.sku
         AND (LOTxLOCxID.Qty > 0 OR LOTxLOCxID.PendingMoveIn > 0)

         IF ISNULL(RTRIM(@c_ID),'') <> ''
         BEGIN
            SELECT @n_FromCube = ISNULL( SUM((LOTxLOCxID.Qty - LOTxLOCxID.QtyPicked) * Sku.StdCube), 0)
            FROM LOTxLOCxID WITH (NOLOCK), Sku WITH (NOLOCK)
            WHERE LOTxLOCxID.StorerKey = @c_StorerKey
            AND LOTxLOCxID.Sku = @c_SKU
            AND LOTxLOCxID.Loc = @c_FromLoc
            AND LOTxLOCxID.Id = @c_ID
            AND LOTxLOCxID.StorerKey = sku.StorerKey
            and LOTxLOCxID.sku = sku.sku
            AND LOTxLOCxID.Qty > 0
         END
         ELSE
         BEGIN
            SELECT @n_FromCube = ISNULL( SUM((LOTxLOCxID.Qty - LOTxLOCxID.QtyPicked) * Sku.StdCube), 0)
            FROM LOTxLOCxID WITH (NOLOCK), SKU WITH (NOLOCK)
            WHERE LOTxLOCxID.StorerKey = @c_StorerKey
            AND LOTxLOCxID.Sku = @c_SKU  --vicky
            AND LOTxLOCxID.Loc = @c_FromLoc
            AND LOTxLOCxID.Lot = @c_LOT
            AND LOTxLOCxID.StorerKey = sku.StorerKey
            and LOTxLOCxID.sku = sku.sku
            AND LOTxLOCxID.Qty > 0
         END

         IF @n_Loc_CubicCapacity < (@n_ToCube + @n_FromCube)
         BEGIN
            IF @b_Debug = 1
            BEGIN
               SELECT @c_Reason = 'FAILED Cube Fit: CubeCapacity = ' + RTRIM(CONVERT(char(10),@n_Loc_CubicCapacity)) + '  CubeRequired = ' + RTRIM(Convert(char(10),(@n_ToCube + @n_FromCube)))
               EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                           @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                           @c_ToLoc, @c_Reason
            END
            SELECT @b_RestrictionsPassed = 0
            GOTO RESTRICTIONCHECKDONE
         END
         ELSE
         BEGIN
            IF @b_Debug = 1
            BEGIN
               SELECT @c_Reason = 'PASSED Cube Fit: CubeCapacity = ' + RTRIM(CONVERT(char(10),@n_Loc_CubicCapacity)) + '  CubeRequired = ' + RTRIM(Convert(char(10),(@n_ToCube + @n_FromCube)))
               EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                           @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                           @c_ToLoc, @c_Reason
            END
         END
      END
   END

   IF '2' IN (@cpa_DimensionRestriction01,
              @cpa_DimensionRestriction02,
              @cpa_DimensionRestriction03,
              @cpa_DimensionRestriction04,
              @cpa_DimensionRestriction05,
              @cpa_DimensionRestriction06)       AND
              @c_Loc_Type NOT IN ('PICK','CASE') AND
              @n_CurrLocMultiLot = 0
   BEGIN
      IF (@n_PutawayTI IS NULL OR @n_PutawayTI = 0) AND (@b_config_PALDIMCALC <> '1' )
      BEGIN
         IF @b_Debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED LxWxH Fit: Commodity PutawayTi = 0 OR is NULL'
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                        @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                        @c_ToLoc, @c_Reason
         END
         SELECT @b_RestrictionsPassed = 0
         GOTO RESTRICTIONCHECKDONE
      END
      IF (@n_PalletWoodWidth > @n_Loc_Width OR @n_PalletWoodLength > @n_Loc_Length) AND
         (@n_PalletWoodWidth > @n_Loc_Length OR @n_PalletWoodLength > @n_Loc_Width)
      BEGIN
         IF @b_Debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED LxWxH Fit: Wood/LocWidth=' + CONVERT(char(4),@n_PalletWoodWidth) + ' / ' + CONVERT(char(4),@n_Loc_Width) + '  Wood/locLength=' + CONVERT(char(4),@n_PalletWoodLength) + ' / ' + CONVERT(char(4),@n_Loc_Length)
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                        @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                        @c_ToLoc, @c_Reason
         END
         SELECT @b_RestrictionsPassed = 0
         GOTO RESTRICTIONCHECKDONE
      END
      ELSE
      BEGIN
         IF @b_Debug = 1
         BEGIN
            SELECT @c_Reason = 'PASSED LxWxH Fit: Wood/LocWidth=' + CONVERT(char(4),@n_PalletWoodWidth) + ' / ' + CONVERT(char(4),@n_Loc_Width) + '  Wood/locLength=' + CONVERT(char(4),@n_PalletWoodLength) + ' / ' + CONVERT(char(4),@n_Loc_Length)
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                        @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                        @c_ToLoc, @c_Reason
         END
      END
      ---UWP-15394 Calculate Height&Weight, config = PALDIMCALC
      IF (@b_config_PALDIMCALC = '1' )
      BEGIN
         --LOT AND SKU must be same
         SET @n_IdCnt = 0;
         SELECT @n_IdCnt = COUNT(DISTINCT ID)
         FROM   LOTxLOCxID WITH (NOLOCK)
         WHERE  StorerKey = @c_StorerKey
            AND Loc = @c_ToLoc
            AND (Qty > 0 OR PendingMoveIn > 0)
         SET  @n_IdCnt = @n_IdCnt+1
         IF (@n_PalletWoodWidth * @n_IdCnt > @n_Loc_Width OR @n_PalletWoodLength > @n_Loc_Length) AND (@n_PalletWoodLength * @n_IdCnt > @n_Loc_Length OR @n_PalletWoodWidth > @n_Loc_Width)
            BEGIN
               IF @b_Debug = 1
                  BEGIN
                     SELECT @c_Reason = 'FAILED LxWxN Fit: Pallet=(' + CONVERT(char(4),@n_PalletWoodWidth) + ' * ' + CONVERT(char(4),@n_PalletWoodLength) + ') * ' + CONVERT(char(4),@n_IdCnt) + ' , Loc:' + CONVERT(char(4),@n_Loc_Width) +' * ' + CONVERT(char(4),@n_Loc_Length)
                     EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                          @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                          @c_ToLoc, @c_Reason
                  END
               SELECT @b_RestrictionsPassed = 0
               GOTO RESTRICTIONCHECKDONE
            END
         ELSE
            BEGIN
               IF @b_Debug = 1
                  BEGIN
                     SELECT @c_Reason = 'PASSED LxWxN Fit: Pallet=(' + CONVERT(char(4),@n_PalletWoodWidth) + ' * ' + CONVERT(char(4),@n_PalletWoodLength) + ') * ' + CONVERT(char(4),@n_IdCnt) + ' , Loc:' + CONVERT(char(4),@n_Loc_Width) +' * ' + CONVERT(char(4),@n_Loc_Length)
                     EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                          @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                          @c_ToLoc, @c_Reason
                  END
            END
      --end width&length check, config = PALDIMCALC
      END


      ---UWP-15394 Calculate Height From HeightUOM4
      IF (@b_config_PALDIMCALC = '1' ) -- STORERCFG
      BEGIN
         SET @n_ExistingHeight =  @n_PalletWoodHeight

         SELECT @n_PalletHeight = PACK.HeightUOM4
         FROM PACK (NOLOCK)
         WHERE PACK.Packkey = @c_PackKey
      END
      ELSE
      BEGIN
         SELECT @n_ExistingQuantity = ISNULL( SUM(LOTxLOCxID.Qty - LOTxLOCxID.QtyPicked + LOTxLOCxID.PendingMoveIn), 0)
         FROM LOTxLOCxID WITH (NOLOCK)
         WHERE LOTxLOCxID.StorerKey = @c_StorerKey
         AND LOTxLOCxID.Sku = @c_SKU
         AND LOTxLOCxID.Loc = @c_ToLoc
         AND (LOTxLOCxID.Qty > 0 OR LOTxLOCxID.PendingMoveIn > 0)

         IF @n_ExistingQuantity IS NULL
         BEGIN
            SELECT @n_ExistingQuantity = 0
            SELECT @n_ExistingHeight = @n_PalletWoodHeight
         END
         ELSE
         BEGIN
            SELECT @n_ExistingLayers = @n_ExistingQuantity / (@n_PutawayTI * @n_PackCaseCount)
            SELECT @n_ExtraLayer = @n_ExistingQuantity % (@n_PutawayTI * @n_PackCaseCount)
            IF @n_ExtraLayer > 0
            BEGIN
               SELECT @n_ExistingLayers = @n_ExistingLayers + 1
            END
            SELECT @n_ExistingHeight = (@n_ExistingLayers * @n_CaseHeight) + @n_PalletWoodHeight
         END
         SELECT @n_ExistingLayers = @n_Qty / (@n_PutawayTI * @n_PackCaseCount)
         SELECT @n_ExtraLayer = @n_Qty % (@n_PutawayTI * @n_PackCaseCount)

         IF @n_ExtraLayer > 0
         BEGIN
            SELECT @n_ExistingLayers = @n_ExistingLayers + 1
         END
         SELECT @n_PalletHeight = @n_CaseHeight * @n_ExistingLayers
      END

      IF @n_ExistingHeight + @n_PalletHeight > @n_Loc_Height
      BEGIN
         IF @b_Debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED LxWxH Fit: LocHeight = ' + RTRIM(CONVERT(char(20),@n_Loc_Height)) + '  ExistingHeight = ' + RTRIM(CONVERT(char(20),@n_ExistingHeight)) + '  AdditionalHeight = ' + RTRIM(CONVERT(char(20),(@n_PalletHeight)))
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                        @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                        @c_ToLoc, @c_Reason
         END
         SELECT @b_RestrictionsPassed = 0
         GOTO RESTRICTIONCHECKDONE
      END
      ELSE
      BEGIN
         IF @b_Debug = 1
         BEGIN
            SELECT @c_Reason = 'PASSED LxWxH Fit: LocHeight = ' + RTRIM(CONVERT(char(20),@n_Loc_Height)) + '  ExistingHeight = ' + RTRIM(CONVERT(char(20),@n_ExistingHeight)) + '  AdditionalHeight = ' + RTRIM(CONVERT(char(20),(@n_PalletHeight)))
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                        @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                        @c_ToLoc, @c_Reason
         END
      END
   END

   IF '3' IN (@cpa_DimensionRestriction01,
              @cpa_DimensionRestriction02,
              @cpa_DimensionRestriction03,
              @cpa_DimensionRestriction04,
              @cpa_DimensionRestriction05,
              @cpa_DimensionRestriction06)
   BEGIN
      SELECT @n_ToWeight = ISNULL( SUM((LOTxLOCxID.Qty - LOTxLOCxID.QtyPicked + LOTxLOCxID.PendingMoveIn) * Sku.StdGrossWgt), 0)
      FROM LOTxLOCxID WITH (NOLOCK), SKU WITH (NOLOCK)
      WHERE LOTxLOCxID.StorerKey = Sku.StorerKey
      AND LOTxLOCxID.Sku = Sku.sku
      AND LOTxLOCxID.Loc = @c_ToLoc
      AND LOTxLOCxID.Qty > 0

      IF @n_ToWeight IS NULL
      BEGIN
         SELECT @n_ToWeight = 0
      END

      IF @b_MultiProductID = 0
      BEGIN
         SELECT @n_FromWeight = @n_Qty * @n_StdGrossWgt
      END
      ELSE
      BEGIN
         SELECT @n_FromWeight = ISNULL( SUM((LOTxLOCxID.Qty - LOTxLOCxID.QtyPicked) * Sku.StdGrossWgt), 0)
         FROM LOTxLOCxID WITH (NOLOCK), SKU WITH (NOLOCK)
         WHERE LOTxLOCxID.StorerKey = Sku.StorerKey
         AND LOTxLOCxID.Sku = Sku.sku
         AND LOTxLOCxID.Id = @c_ID

         IF @n_FromWeight IS NULL
         BEGIN
            SELECT @n_FromWeight = 0
         END
      END
      IF @n_Loc_WeightCapacity < ( @n_ToWeight + @n_FromWeight )
      BEGIN
         IF @b_Debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED Weight Fit: LocWeight = ' + RTRIM(CONVERT(char(20),@n_Loc_WeightCapacity)) + '  ExistingWeight = ' + RTRIM(CONVERT(char(20),@n_ToWeight)) + '  AdditionalWeight = ' + RTRIM(CONVERT(char(20),(@n_FromWeight)))
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                        @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                        @c_ToLoc, @c_Reason
         END
         SELECT @b_RestrictionsPassed = 0
         GOTO RESTRICTIONCHECKDONE
      END
      ELSE
      BEGIN
         IF @b_Debug = 1
         BEGIN
            SELECT @c_Reason = 'PASSED Weight Fit: LocWeight = ' + RTRIM(CONVERT(char(20),@n_Loc_WeightCapacity)) + '  ExistingWeight = ' + RTRIM(CONVERT(char(20),@n_ToWeight)) + '  AdditionalWeight = ' + RTRIM(CONVERT(char(20),(@n_FromWeight)))
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                        @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                        @c_ToLoc, @c_Reason
         END
      END
   END

   IF '4' IN (@cpa_DimensionRestriction01,
              @cpa_DimensionRestriction02,
              @cpa_DimensionRestriction03,
              @cpa_DimensionRestriction04,
              @cpa_DimensionRestriction05,
              @cpa_DimensionRestriction06)
   BEGIN
      SELECT @n_QtylocationLimit = QtyLocationLimit
      FROM SKUxLOC WITH (NOLOCK)
      WHERE StorerKey = @c_StorerKey
      AND SKU = @c_SKU
      AND Locationtype IN ('PICK', 'CASE')
      AND Loc = @c_ToLoc

      IF @n_QtylocationLimit IS NOT NULL
      BEGIN
         SELECT @n_ExistingQuantity = SUM((Qty - QtyPicked) + PendingMoveIN)
         FROM LOTxLOCxID WITH (NOLOCK)
         WHERE StorerKey = @c_StorerKey
         AND SKU = @c_SKU
         AND Loc = @c_ToLoc
         AND (Qty > 0
         OR  PendingMoveIn > 0)

         IF @n_ExistingQuantity IS NULL
         BEGIN
            SELECT @n_ExistingQuantity = 0
         END

         IF @n_QtylocationLimit < (@n_Qty + @n_ExistingQuantity)
         BEGIN
            IF @b_Debug = 1
            BEGIN
               SELECT @c_Reason = 'FAILED Qty Capacity: LocCapacity = ' + RTRIM(CONVERT(char(20),@n_QtylocationLimit)) + '  Required = ' + RTRIM(CONVERT(char(20),(@n_Qty + @n_ExistingQuantity)))
               EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                           @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                           @c_ToLoc, @c_Reason
            END
            SELECT @b_RestrictionsPassed = 0
            GOTO RESTRICTIONCHECKDONE
         END
         ELSE
         BEGIN
            IF @b_Debug = 1
            BEGIN
               SELECT @c_Reason = 'PASSED Qty Capacity: LocCapacity = ' + RTRIM(CONVERT(char(20),@n_QtylocationLimit)) + '  Required = ' + RTRIM(CONVERT(char(20),(@n_Qty + @n_ExistingQuantity)))
               EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                           @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                           @c_ToLoc, @c_Reason
            END
         END
      END
   END

   /********************************************************************
   Begin - Modified by Teoh To Cater for Height Restriction 30/3/2000
   *********************************************************************/
   IF '5' IN (@cpa_DimensionRestriction01,
              @cpa_DimensionRestriction02,
              @cpa_DimensionRestriction03,
              @cpa_DimensionRestriction04,
              @cpa_DimensionRestriction05,
              @cpa_DimensionRestriction06)
   BEGIN
      SET @f_totalHeight = 0
      --Compare height with HeightUOM4,
      IF @b_config_PALDIMCALC = '1'
      BEGIN
         SELECT @n_CaseHeight = PACK.HeightUOM4
         FROM PACK (NOLOCK)
         WHERE PACK.Packkey = @c_PackKey

         SET @f_totalHeight = @n_CaseHeight
      END
      ELSE
      BEGIN
         SET @f_totalHeight = @n_CaseHeight * @n_PutawayHI
      END

      IF (@f_totalHeight + @n_PalletWoodHeight) > @n_Loc_Height
      BEGIN
         IF @b_Debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED Height Restriction: Loc Height = ' + RTRIM(CONVERT(char(20), @n_Loc_Height)) + '. Pallet Build Height = ' +
            RTRIM(CONVERT(char(20), ((@f_totalHeight) + @n_PalletWoodHeight)))
            EXEC nspPTD 'nspRDTPASTD'-- SOS# 143046
               , @n_pTraceHeadKey, @c_PutawayStrategyKey,
                 @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                 @c_ToLoc, @c_Reason
         END
         SELECT @b_RestrictionsPassed = 0
         GOTO RESTRICTIONCHECKDONE
      END
      ELSE
      BEGIN
         IF @b_Debug = 1
         BEGIN
            SELECT @c_Reason = 'PASSED Height Restriction: Loc Height = ' + RTRIM(CONVERT(char(20), @n_Loc_Height)) + '. Pallet Build Height = ' +
            RTRIM(CONVERT(char(20), ((@f_totalHeight) + @n_PalletWoodHeight)))
            EXEC nspPTD 'nspRDTPASTD' -- SOS# 143046
               , @n_pTraceHeadKey, @c_PutawayStrategyKey,
                 @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                 @c_ToLoc, @c_Reason
         END
      END
   END
   /********************************************************************
   End - Modified by Teoh To Cater for Height Restriction 30/3/2000
   *********************************************************************/

   /********************************************************************
   Added by SHONG for SKIP JACK Project
   *********************************************************************/
   DECLARE
      @ucc_UCCNO      NVARCHAR(20),
      @ucc_StorerKey  NVARCHAR(15),
        @ucc_SKU        NVARCHAR(20),
        @ucc_Lottable02 NVARCHAR(18),
        @ucc_Qty        INT,
        @c_SKUZone      NVARCHAR(10)

   -- Reject If not all UCC can Putaway
   IF '16' IN (@cpa_DimensionRestriction01,
              @cpa_DimensionRestriction02,
              @cpa_DimensionRestriction03,
              @cpa_DimensionRestriction04,
              @cpa_DimensionRestriction05,
              @cpa_DimensionRestriction06)
   BEGIN
    DECLARE @t_LOC TABLE (LOC NVARCHAR(10))

    DECLARE @c_FoundLOC NVARCHAR(10)

    DECLARE CUR_UCC_PUTAWAY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
    SELECT UCCNo, UCC.Storerkey, UCC.SKU, LA.Lottable02, UCC.qty
    FROM UCC WITH (NOLOCK)
    JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON LA.Lot = UCC.Lot
    WHERE id =@c_ID

    OPEN CUR_UCC_PUTAWAY

    FETCH NEXT FROM CUR_UCC_PUTAWAY INTO @ucc_UCCNO,
       @ucc_StorerKey, @ucc_SKU, @ucc_Lottable02, @ucc_Qty

    WHILE @@FETCH_STATUS <> -1
    BEGIN
         SELECT @n_FromCube = @ucc_Qty * Sku.StdCube,
                @c_SKUZone  = SKU.PutawayZone
         FROM SKU WITH (NOLOCK)
         WHERE SKU.StorerKey = @ucc_StorerKey
         AND SKU.SKU = @ucc_SKU

         SET @c_FoundLOC = ''
         SELECT TOP 1 @c_FoundLOC = ISNULL(LOC.LOC,'')
         FROM LOC WITH (NOLOCK)
          JOIN (
              SELECT LOTxLOCxID.LOC,
                 ISNULL( SUM((LOTxLOCxID.Qty - LOTxLOCxID.QtyPicked + LOTxLOCxID.PendingMoveIn) * Sku.StdCube), 0) AS ToCube
               FROM LOTxLOCxID WITH (NOLOCK)
               JOIN LOC L (NOLOCK) ON L.Loc = LOTxLOCxID.Loc AND l.PutawayZone = @c_SKUZone
               JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON LA.Lot = LOTxLOCxID.Lot
               JOIN SKU WITH (NOLOCK) ON LOTxLOCxID.StorerKey = sku.StorerKey
                                     AND LOTxLOCxID.sku = sku.sku
               WHERE LOTxLOCxID.StorerKey = @c_StorerKey
               AND LOTxLOCxID.Sku = @c_SKU
               AND (LOTxLOCxID.Qty > 0 OR LOTxLOCxID.PendingMoveIn > 0)
               AND LA.Lottable02 = @ucc_Lottable02
               GROUP BY LOTxLOCxID.Loc) AS ToLOC ON ToLOC.Loc = LOC.Loc
          WHERE PutawayZone = @c_SKUZone
          AND LOC.CubicCapacity >= (ToLOC.ToCube + @n_FromCube)
          AND LOC.LOC NOT IN (SELECT LOC FROM @t_LOC)

         IF @c_FoundLOC = ''
         BEGIN
            SELECT TOP 1 @c_FoundLOC = ISNULL(LOC.LOC,'')
            FROM LOC WITH (NOLOCK)
            LEFT OUTER JOIN SKUxLOC WITH (NOLOCK) ON SKUxLOC.Loc = LOC.Loc
            WHERE LOC.PutawayZone = @c_SKUZone
            AND LOC.CubicCapacity >= @n_FromCube
            GROUP BY LOC.LOC
            HAVING ISNULL(SUM(SKUxLOC.Qty),0) = 0
         END
         IF @c_FoundLOC <> ''
         BEGIN
            IF @b_Debug = 1
            BEGIN
               SELECT @c_Reason = 'PASSED Cube Fit: Location With Same BatchNo/Empty for SKU '+ RTRIM(@ucc_SKU)
               + ' LOC: ' + @c_FoundLOC
               EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                           @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                           @c_ToLoc, @c_Reason

            END
            INSERT INTO @t_LOC VALUES (@c_FoundLOC)
        END
        ELSE
        BEGIN
            IF @b_Debug = 1
            BEGIN
               SELECT @c_Reason = 'FAILED Cube Fit: Location With Same BatchNo/Empty for SKU '+ RTRIM(@ucc_SKU)
               EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                           @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                           @c_ToLoc, @c_Reason
            END
            SELECT @b_RestrictionsPassed = 0
            GOTO RESTRICTIONCHECKDONE
         END

     FETCH NEXT FROM CUR_UCC_PUTAWAY INTO @ucc_UCCNO,
          @ucc_StorerKey, @ucc_SKU, @ucc_Lottable02, @ucc_Qty
    END
    CLOSE  CUR_UCC_PUTAWAY
    DEALLOCATE CUR_UCC_PUTAWAY
   END

   -- Fit by UCC cube
   IF '17' IN (@cpa_DimensionRestriction01,
              @cpa_DimensionRestriction02,
              @cpa_DimensionRestriction03,
              @cpa_DimensionRestriction04,
              @cpa_DimensionRestriction05,
              @cpa_DimensionRestriction06)
   BEGIN
      -- Get FROM cube
      IF EXISTS( SELECT 1 FROM dbo.UCC WITH (NOLOCK) WHERE LOC = @c_FromLOC AND ID = @c_ID AND Status = '1')
         -- UCC
         IF @b_PutawayBySKU = 'N'
            -- Take all UCC cube
            SELECT @n_FromCube = ISNULL( SUM( Pack.CubeUOM1), 0)
            FROM dbo.UCC WITH (NOLOCK)
               JOIN dbo.SKU WITH (NOLOCK) ON (UCC.StorerKey = SKU.StorerKey AND UCC.SKU = SKU.SKU)
               JOIN dbo.Pack WITH (NOLOCK) ON (Pack.PackKey = SKU.PackKey)
            WHERE UCC.LOC = @c_FromLOC
               AND UCC.ID = @c_ID
               AND Status = '1'
         ELSE
         BEGIN
            -- Take 1 UCC cube
            SELECT TOP 1
               @n_FromCube = Pack.CubeUOM1
            FROM dbo.UCC WITH (NOLOCK)
               JOIN dbo.SKU WITH (NOLOCK) ON (UCC.StorerKey = SKU.StorerKey AND UCC.SKU = SKU.SKU)
               JOIN dbo.Pack WITH (NOLOCK) ON (Pack.PackKey = SKU.PackKey)
            WHERE UCC.LOC = @c_FromLOC
               AND UCC.ID = @c_ID
               AND UCC.StorerKey = @c_StorerKey
               AND UCC.SKU = @c_SKU
               AND UCC.Status = '1'
         END
      ELSE
      BEGIN
         -- NON-UCC
         IF @b_PutawayBySKU = 'N'
            SELECT @n_FromCube = ISNULL( SUM((LOTxLOCxID.QTY - LOTxLOCxID.QTYPicked + LOTxLOCxID.PendingMoveIn) * SKU.STDCube), 0)
            FROM LOTxLOCxID WITH (NOLOCK)
               JOIN SKU WITH (NOLOCK) ON (LOTxLOCxID.StorerKey = SKU.StorerKey AND LOTxLOCxID.SKU = SKU.SKU)
            WHERE LOTxLOCxID.LOC = @c_FromLoc
               AND LOTxLOCxID.ID = @c_ID
               AND (LOTxLOCxID.QTY > 0 OR LOTxLOCxID.PendingMoveIn > 0)
         ELSE
            SELECT @n_FromCube = ISNULL( @n_QTY * SKU.STDCube, 0)
            FROM SKU WITH (NOLOCK)
            WHERE StorerKey = @c_StorerKey
               AND SKU = @c_SKU
      END

      -- Get TO cube
      IF EXISTS( SELECT 1 FROM dbo.UCC WITH (NOLOCK) WHERE LOC = @c_ToLOC AND Status = '1')
         -- UCC
         SELECT @n_ToCube = ISNULL( SUM( Pack.CubeUOM1), 0)
         FROM dbo.UCC WITH (NOLOCK)
            JOIN dbo.SKU WITH (NOLOCK) ON (UCC.StorerKey = SKU.StorerKey AND UCC.SKU = SKU.SKU)
            JOIN dbo.Pack WITH (NOLOCK) ON (Pack.PackKey = SKU.PackKey)
         WHERE UCC.LOC = @c_ToLOC
            AND Status = '1'
      ELSE
         -- NON-UCC
         SELECT @n_ToCube = ISNULL( SUM((LOTxLOCxID.QTY - LOTxLOCxID.QTYPicked + LOTxLOCxID.PendingMoveIn) * SKU.STDCube), 0)
         FROM LOTxLOCxID WITH (NOLOCK)
            JOIN SKU WITH (NOLOCK) ON (LOTxLOCxID.StorerKey = SKU.StorerKey AND LOTxLOCxID.SKU = SKU.SKU)
         WHERE LOTxLOCxID.LOC = @c_ToLoc
            AND (LOTxLOCxID.QTY > 0 OR LOTxLOCxID.PendingMoveIn > 0)

      IF @n_Loc_CubicCapacity < (@n_ToCube + @n_FromCube)
      BEGIN
         IF @b_Debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED Fit by UCC Cube: CubeCapacity = ' + RTRIM(CONVERT(char(10),@n_Loc_CubicCapacity)) + '  CubeRequired = ' + RTRIM(Convert(char(10),(@n_ToCube + @n_FromCube)))
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                        @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                        @c_ToLoc, @c_Reason
         END
         SELECT @b_RestrictionsPassed = 0
         GOTO RESTRICTIONCHECKDONE
      END
      ELSE
      BEGIN
         IF @b_Debug = 1
         BEGIN
            SELECT @c_Reason = 'PASSED Fit by UCC Cube : CubeCapacity = ' + RTRIM(CONVERT(char(10),@n_Loc_CubicCapacity)) + '  CubeRequired = ' + RTRIM(Convert(char(10),(@n_ToCube + @n_FromCube)))
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                        @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                        @c_ToLoc, @c_Reason
         END
      END
   END

   -- PutCode (ung06)
   IF @cpa_PutCode <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cpa_PutCode AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC ' + RTRIM( @cpa_PutCode) + ' @n_pTraceHeadKey, @n_PtraceDetailKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber ' +
            ' ,@c_StorerKey' +
            ' ,@c_SKU      ' +
            ' ,@c_LOT      ' +
            ' ,@c_FromLoc  ' +
            ' ,@c_ID       ' +
            ' ,@n_Qty      ' +
            ' ,@c_ToLoc    ' +
            ' ,@c_Param1   ' +
            ' ,@c_Param2   ' +
            ' ,@c_Param3   ' +
            ' ,@c_Param4   ' +
            ' ,@c_Param5   ' +
            ' ,@b_Debug    ' +
            ' ,@c_SQL      OUTPUT' +
            ' ,@b_RestrictionsPassed OUTPUT'
            
         SET @cSQLParam = '@n_pTraceHeadKey NVARCHAR(10), @n_PtraceDetailKey NVARCHAR(10), @c_PutawayStrategyKey NVARCHAR(10), @c_PutawayStrategyLineNumber NVARCHAR(5) ' +
            ' ,@c_StorerKey NVARCHAR(15) ' +
            ' ,@c_SKU       NVARCHAR(20) ' +
            ' ,@c_LOT       NVARCHAR(10) ' +
            ' ,@c_FromLoc   NVARCHAR(10) ' +
            ' ,@c_ID        NVARCHAR(18) ' +
            ' ,@n_Qty       INT      ' +
            ' ,@c_ToLoc     NVARCHAR(10) ' +
            ' ,@c_Param1    NVARCHAR(20) ' +
            ' ,@c_Param2    NVARCHAR(20) ' +
            ' ,@c_Param3    NVARCHAR(20) ' +
            ' ,@c_Param4    NVARCHAR(20) ' +
            ' ,@c_Param5    NVARCHAR(20) ' +
         ' ,@b_Debug     INT      ' +
            ' ,@c_SQL       NVARCHAR(1000) OUTPUT' +
            ' ,@b_RestrictionsPassed INT  OUTPUT'

         IF @b_Debug = 2
         BEGIN
            PRINT 'PA Type: ' + @cpa_PAType + ' >>> ' + @cSQL
         END
            
         EXEC sp_ExecuteSql @cSQL, @cSQLParam, @n_pTraceHeadKey, @n_PtraceDetailKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber
          ,@c_StorerKey
            ,@c_SKU
            ,@c_LOT
            ,@c_FromLoc
            ,@c_ID
            ,@n_Qty
            ,@c_ToLoc
            ,@c_Param1
            ,@c_Param2
            ,@c_Param3
            ,@c_Param4
            ,@c_Param5
            ,@b_Debug
            ,@cpa_PutCodeSQL       OUTPUT
            ,@b_RestrictionsPassed OUTPUT

         IF @b_Debug = 2
         BEGIN
            PRINT '@cpa_PutCodeSQL: ' + @cpa_PutCodeSQL 
         END
         
         IF @b_RestrictionsPassed = 0
            GOTO RESTRICTIONCHECKDONE
      END
   END

   IF OBJECT_ID(N'tempdb..#tLOCPendingMoveIn') IS NOT NULL
         DROP TABLE #tLOCPendingMoveIn
   IF OBJECT_ID(N'tempdb..#tUCCPendingMoveIn') IS NOT NULL
         DROP TABLE #tUCCPendingMoveIn

   CREATE TABLE #tLOCPendingMoveIn
      (
         LOC                NVARCHAR( 10) NOT NULL,
         LOCIDCnt           INT           NOT NULL,
         PendingMoveInIDCnt INT           NOT NULL
      )

   CREATE TABLE #tUCCPendingMoveIn
      (
         LOC    NVARCHAR( 10) NOT NULL,
         UCCNo  NVARCHAR( 20) NOT NULL,
         SKU    NVARCHAR( 20) NOT NULL,
         QTY    INT           NOT NULL
      )

   DECLARE @cUCC     NVARCHAR( 20)
   DECLARE @cLOT     NVARCHAR( 10)
   DECLARE @cLOC     NVARCHAR( 10)
   DECLARE @cID      NVARCHAR( 18)
   DECLARE @cPrevID  NVARCHAR( 18)
   DECLARE @cToID    NVARCHAR( 18)
   DECLARE @cSKU     NVARCHAR( 20)
   DECLARE @nQTY     INT
   DECLARE @cUCCSKU  NVARCHAR( 20)
   DECLARE @nUCCQTY  INT
   DECLARE @nMaxPallet          INT
   DECLARE @nLOCIDCnt           INT
   DECLARE @nPendingMoveInIDCnt INT
   DECLARE @cSuggestedLOC       NVARCHAR( 10)

   DECLARE @nTranCount INT
   -- Reject If not all UCC on pallet can Putaway
   IF '18' IN (@cpa_DimensionRestriction01,
              @cpa_DimensionRestriction02,
              @cpa_DimensionRestriction03,
              @cpa_DimensionRestriction04,
              @cpa_DimensionRestriction05,
              @cpa_DimensionRestriction06)
   BEGIN
      SET @cSQL =
         ' SELECT TOP 1 ' +
         '    @cLOC = LOC.LOC, ' +
         '    @nMaxPallet = LOC.MaxPallet, ' +
         '    @nLOCIDCnt = ISNULL( COUNT( DISTINCT ' +
         '        CASE WHEN UCC.UCCNo IS NOT NULL THEN UCC.UCCNO ' +
         '             WHEN LLI.ID    IS NOT NULL THEN LLI.ID ' +
         '             ELSE NULL ' +
         '        END), 0), ' +
         '    @nPendingMoveInIDCnt = ISNULL( t.PendingMoveInIDCnt, 0)  ' +
         ' FROM dbo.LOC with (NOLOCK) ' +
         '    LEFT JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LOC.LOC = LLI.LOC AND (LLI.QTY - LLI.QTYPicked > 0 OR LLI.PendingMoveIn > 0)) ' +
         '    LEFT JOIN UCC WITH (NOLOCK) ON (LLI.LOT = UCC.LOT AND LLI.LOC = UCC.LOC AND LLI.ID = UCC.ID AND UCC.Status IN (''1'', ''3'')) ' +
         '    LEFT JOIN #tLOCPendingMoveIn t ON (t.LOC = LOC.LOC) ' +
         ' WHERE LOC.Facility = @c_Facility ' +
         '    AND LOC.LOCAisle = @c_NextPnDAisle ' +
         '    AND NOT EXISTS( ' +
         '        SELECT 1 ' +
         '        FROM dbo.UCC WITH (NOLOCK) ' +
         '        WHERE StorerKey = @c_StorerKey ' +
         '           AND SKU = @cUCCSKU ' +
         '           AND QTY <> @nUCCQTY ' +
         '           AND Status IN ( ''1'', ''3'') ' +
         '           AND LOC = LOC.LOC) ' +
         '    AND NOT EXISTS( ' +
         '        SELECT 1 ' +
         '        FROM #tUCCPendingMoveIn ' +
         '        WHERE SKU = @cUCCSKU ' +
         '           AND QTY <> @nUCCQTY ' +
         '           AND LOC = LOC.LOC) ' +
         @c_SQL_LocationCategoryInclude +
         @c_SQL_LocationHandlingInclude +
         ' GROUP BY LOC.LogicalLocation, LOC.LOC, LOC.MaxPallet, t.PendingMoveInIDCnt ' +
         ' HAVING ISNULL( COUNT( DISTINCT ' +
         '        CASE WHEN UCC.UCCNo IS NOT NULL THEN UCC.UCCNO ' +
         '             WHEN LLI.ID    IS NOT NULL THEN LLI.ID ' +
         '             ELSE NULL ' +
         '        END), 0) ' +
         '     + ISNULL( t.PendingMoveInIDCnt, 0) + 1 <= LOC.MaxPallet ' +  
         ' ORDER BY LOC.LogicalLocation, LOC.LOC '
         
      SET @cSQLParam = N'@c_Facility NVARCHAR(5), ' +
         ' @c_StorerKey nvarchar(15), ' +
         ' @cUCCSKU     NVARCHAR( 20), ' +
         ' @nUCCQTY     INT, ' +
         ' @cLOC        NVARCHAR( 10) OUTPUT, ' +
         ' @nMaxPallet  INT           OUTPUT, ' +
         ' @nLOCIDCnt   INT           OUTPUT, ' +
         ' @nPendingMoveInIDCnt INT   OUTPUT '  +
         ',@c_NextPnDAisle NVARCHAR(10) ' +
         ',@cpa_LocationCategoryInclude01  NVARCHAR(10)= ''''' +
         ',@cpa_LocationCategoryInclude02  NVARCHAR(10)= ''''' +
         ',@cpa_LocationCategoryInclude03  NVARCHAR(10)= ''''' +
         ',@cpa_LocationHandlingInclude01  NVARCHAR(10)= ''''' +
         ',@cpa_LocationHandlingInclude02  NVARCHAR(10)= ''''' +
         ',@cpa_LocationHandlingInclude03  NVARCHAR(10)= '''''
         

      DECLARE @curUCC CURSOR
      SET @curUCC = CURSOR FOR
         SELECT DISTINCT UCCNo
         FROM dbo.UCC WITH (NOLOCK)
         WHERE LOC = @c_FromLOC
            AND ID = @c_ID
            AND Status = '1'
      OPEN @curUCC
      FETCH NEXT FROM @curUCC INTO @cUCC
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Get UCC info
         SET @cUCCSKU = ''
         SET @nUCCQTY =  0
         
         SELECT
            @cUCCSKU = SKU,
            @nUCCQTY = QTY
         FROM dbo.UCC WITH (NOLOCK)
         WHERE StorerKey = @c_StorerKey
            AND UCCNo = @cUCC

         -- Find LOC in aisle that fit the UCC
         SET @cLOC = ''

         IF @b_Debug = 2
         BEGIN
            PRINT 'PA Type: ' + @cpa_PAType + ' >>> ' + @cSQL
         END
                  
         EXEC sp_ExecuteSql @cSQL, @cSQLParam
            ,@c_Facility
            ,@c_StorerKey
            ,@cUCCSKU
            ,@nUCCQTY
            ,@cLOC        OUTPUT
            ,@nMaxPallet  OUTPUT
            ,@nLOCIDCnt   OUTPUT
            ,@nPendingMoveInIDCnt OUTPUT
            ,@c_NextPnDAisle  
            ,@cpa_LocationCategoryInclude01
            ,@cpa_LocationCategoryInclude02
            ,@cpa_LocationCategoryInclude03
            ,@cpa_LocationHandlingInclude01
            ,@cpa_LocationHandlingInclude02
            ,@cpa_LocationHandlingInclude03

         -- Save
         IF @cLOC <> ''
         BEGIN
            -- Insert UCC PendingMoveIn
            INSERT INTO #tUCCPendingMoveIn (LOC, UCCNo, SKU, QTY) VALUES (@cLOC, @cUCC, @cUCCSKU, @nUCCQTY)

            -- Update LOC PendingMoveIn
            IF NOT EXISTS( SELECT 1 FROM #tLOCPendingMoveIn WHERE LOC = @cLOC)
               INSERT INTO #tLOCPendingMoveIn (LOC, LOCIDCnt, PendingMoveInIDCnt) VALUES (@cLOC, @nLOCIDCnt, @nPendingMoveInIDCnt + 1)
            ELSE
               UPDATE #tLOCPendingMoveIn SET PendingMoveInIDCnt = @nPendingMoveInIDCnt + 1 WHERE LOC = @cLOC

            SET @c_FitCasesInAisle = 'Y'

            IF @b_Debug = 1
            BEGIN
               SELECT @c_Reason = 'PASSED Fit in aisle:' + RTRIM( @c_NextPnDAisle) +
                  '  UCCNo=' + RTRIM(@cUCC) +
                  '  LOCIDCnt=' + RTRIM(Convert(char(10),@nLOCIDCnt)) +
                  '  PMoveInIDCnt=' + RTRIM(Convert(char(10),@nPendingMoveInIDCnt)) +
                  '  MaxPL=' + RTRIM(Convert(char(10),@nMaxPallet))
               EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @cLOC, @c_Reason
            END
         END
         ELSE
         BEGIN
            IF @b_Debug = 1
            BEGIN
               SELECT @c_Reason = 'FAILED Fit in aisle:' + RTRIM( @c_NextPnDAisle) + '  UCC=' + RTRIM(@cUCC)
               EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @cLOC, @c_Reason
            END
            CLOSE @curUCC
            DEALLOCATE @curUCC

            SET @c_FitCasesInAisle = ''
            SELECT @b_RestrictionsPassed = 0
            GOTO RESTRICTIONCHECKDONE
         END
         FETCH NEXT FROM @curUCC INTO @cUCC
      END
      CLOSE @curUCC
      DEALLOCATE @curUCC

      -- Handling transaction
      --DECLARE @nTranCount INT
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN nspRDTPASTD_FitByAisle -- For rollback or commit only our own transaction

      -- Update LOTxLOCxID.PendingMoveIn
      SET @curUCC = CURSOR FOR
         SELECT t.UCCNo, t.LOC
         FROM #tUCCPendingMoveIn t WITH (NOLOCK)
         ORDER BY t.UCCNo
      OPEN @curUCC
      FETCH NEXT FROM @curUCC INTO @cUCC, @cSuggestedLOC
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Get UCC info
         SELECT
            @cLOT = LOT,
            @cLOC = LOC,
            @cID = ID,
            @cSKU = SKU,
            @nQTY = QTY
         FROM dbo.UCC WITH (NOLOCK)
         WHERE UCCNo = @cUCC

         -- Use UCCNo as ID for booking
         SET @cToID = RIGHT( RTRIM( @cUCC), 18)

         -- Unlock suggested LOC by UCC
         IF EXISTS( SELECT 1 FROM dbo.RFPutaway WITH (NOLOCK) WHERE StorerKey = @c_StorerKey AND CaseID = @cUCC)
            EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'
               ,@cLOC
               ,@cID
               ,'' -- @cSuggestedLOC
               ,@c_StorerKey
               ,@n_Err       OUTPUT
               ,@c_ErrMsg    OUTPUT
               ,@cUCCNo      = @cUCC

         -- Lock suggested LOC by UCC
         EXEC rdt.rdt_Putaway_PendingMoveIn @c_userid, 'LOCK'
            ,@cLOC
            ,@cID
            ,@cSuggestedLOC
            ,@c_StorerKey
            ,@n_Err       OUTPUT
            ,@c_ErrMsg    OUTPUT
            ,@cSKU        = @cSKU
            ,@nPutawayQTY = @nQTY
            ,@cUCCNo      = @cUCC
            ,@cFromLOT    = @cLOT
            ,@cToID       = @cToID
            ,@nPABookingKey = @n_PABookingKey OUTPUT

         IF @n_Err <> 0
         BEGIN
            ROLLBACK TRAN nspRDTPASTD_FitByAisle
            WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
               COMMIT TRAN

            IF @b_Debug = 1
            BEGIN
               SELECT @c_Reason = 'FAILED Fit in aisle:' + RTRIM( @c_NextPnDAisle) + '  LOC updated by others'
               EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @cSuggestedLOC, @c_Reason
            END

            SET @c_FitCasesInAisle = ''
            SELECT @b_RestrictionsPassed = 0
            GOTO RESTRICTIONCHECKDONE
         END

         FETCH NEXT FROM @curUCC INTO @cUCC, @cSuggestedLOC
      END
      CLOSE @curUCC
      DEALLOCATE @curUCC

      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN
   END

   IF '19' IN (@cpa_DimensionRestriction01,
              @cpa_DimensionRestriction02,
              @cpa_DimensionRestriction03,
              @cpa_DimensionRestriction04,
              @cpa_DimensionRestriction05,
              @cpa_DimensionRestriction06)
   BEGIN

      SET @cSQL =
         ' SELECT TOP 1 ' +
         '    @cLOC = LOC.LOC, ' +
         '    @nMaxPallet = LOC.MaxPallet, ' +
         '    @nLOCIDCnt = ISNULL( COUNT( DISTINCT ' +
         '        CASE WHEN UCC.UCCNo IS NOT NULL THEN UCC.UCCNO ' +
         '             WHEN LLI.ID    IS NOT NULL THEN LLI.ID ' +
         '             ELSE NULL ' +
         '        END), 0), ' +
         '    @nPendingMoveInIDCnt = ISNULL( t.PendingMoveInIDCnt, 0)  ' +
         ' FROM dbo.LOC with (NOLOCK) ' +
         '    LEFT JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LOC.LOC = LLI.LOC AND (LLI.QTY - LLI.QTYPicked > 0 OR LLI.PendingMoveIn > 0)) ' +
         '    LEFT JOIN UCC WITH (NOLOCK) ON (LLI.LOT = UCC.LOT AND LLI.LOC = UCC.LOC AND LLI.ID = UCC.ID AND UCC.Status IN (''1'', ''3'')) ' +
         '    LEFT JOIN #tLOCPendingMoveIn t ON (t.LOC = LOC.LOC) ' +
         ' WHERE LOC.Facility = @c_Facility ' +
         '    AND LOC.LOCAisle = @c_NextPnDAisle ' +
         @c_SQL_LocationCategoryInclude +
         @c_SQL_LocationHandlingInclude +
         ' GROUP BY LOC.LogicalLocation, LOC.LOC, LOC.MaxPallet, t.PendingMoveInIDCnt ' +
         ' HAVING ISNULL( COUNT( DISTINCT ' +
         '        CASE WHEN UCC.UCCNo IS NOT NULL THEN UCC.UCCNO ' +
         '             WHEN LLI.ID    IS NOT NULL THEN LLI.ID ' +
         '             ELSE NULL ' +
         '        END), 0) ' +
         '     + ISNULL( t.PendingMoveInIDCnt, 0) + 1 <= LOC.MaxPallet ' +  --LOC ID Cnt + PendingMoveInIDCnt + UCC (1)
         ' ORDER BY LOC.LogicalLocation, LOC.LOC '
         
      SET @cSQLParam = N'@c_Facility NVARCHAR(5), ' +
         ' @c_StorerKey nvarchar(15), ' +
         ' @cUCCSKU     NVARCHAR( 20), ' +
         ' @nUCCQTY     INT, ' +
         ' @cLOC        NVARCHAR( 10) OUTPUT, ' +
         ' @nMaxPallet  INT           OUTPUT, ' +
         ' @nLOCIDCnt   INT           OUTPUT, ' +
         ' @nPendingMoveInIDCnt INT   OUTPUT '  +
         ',@c_NextPnDAisle NVARCHAR(10) ' +
         ',@cpa_LocationCategoryInclude01  NVARCHAR(10)= ''''' +
         ',@cpa_LocationCategoryInclude02  NVARCHAR(10)= ''''' +
         ',@cpa_LocationCategoryInclude03  NVARCHAR(10)= ''''' +
         ',@cpa_LocationHandlingInclude01  NVARCHAR(10)= ''''' +
         ',@cpa_LocationHandlingInclude02  NVARCHAR(10)= ''''' +
         ',@cpa_LocationHandlingInclude03  NVARCHAR(10)= '''''
                  

      DECLARE @curUCC19 CURSOR
      SET @curUCC19 = CURSOR FOR
         SELECT DISTINCT UCCNo
         FROM dbo.UCC WITH (NOLOCK)
         WHERE LOC = @c_FromLOC
            AND ID = @c_ID
            AND Status = '1'
      OPEN @curUCC19
      FETCH NEXT FROM @curUCC19 INTO @cUCC
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Get UCC info
         SET @cUCCSKU = ''
         SET @nUCCQTY =  0
         SELECT
            @cUCCSKU = SKU,
            @nUCCQTY = QTY
         FROM dbo.UCC WITH (NOLOCK)
         WHERE StorerKey = @c_StorerKey
            AND UCCNo = @cUCC

         -- Find LOC in aisle that fit the UCC
         SET @cLOC = ''
         EXEC sp_ExecuteSql @cSQL, @cSQLParam
            ,@c_Facility
            ,@c_StorerKey
            ,@cUCCSKU
            ,@nUCCQTY
            ,@cLOC        OUTPUT
            ,@nMaxPallet  OUTPUT
            ,@nLOCIDCnt   OUTPUT
            ,@nPendingMoveInIDCnt OUTPUT
            ,@c_NextPnDAisle  
            ,@cpa_LocationCategoryInclude01
            ,@cpa_LocationCategoryInclude02
            ,@cpa_LocationCategoryInclude03
            ,@cpa_LocationHandlingInclude01
            ,@cpa_LocationHandlingInclude02
            ,@cpa_LocationHandlingInclude03
             
         -- Save
         IF @cLOC <> ''  AND @cLoc = @c_ToLoc
         BEGIN
            -- Insert UCC PendingMoveIn
            INSERT INTO #tUCCPendingMoveIn (LOC, UCCNo, SKU, QTY) VALUES (@cLOC, @cUCC, @cUCCSKU, @nUCCQTY)

            -- Update LOC PendingMoveIn
            IF NOT EXISTS( SELECT 1 FROM #tLOCPendingMoveIn WHERE LOC = @cLOC)
               INSERT INTO #tLOCPendingMoveIn (LOC, LOCIDCnt, PendingMoveInIDCnt) VALUES (@cLOC, @nLOCIDCnt, @nPendingMoveInIDCnt + 1)
            ELSE
               UPDATE #tLOCPendingMoveIn SET PendingMoveInIDCnt = @nPendingMoveInIDCnt + 1 WHERE LOC = @cLOC

            SET @c_FitCasesInAisle = 'Y'

            IF @b_Debug = 1
            BEGIN
               SELECT @c_Reason = 'PASSED Fit in aisle:' + RTRIM( @c_NextPnDAisle) +
                  '  UCCNo=' + RTRIM(@cUCC) +
                  '  LOCIDCnt=' + RTRIM(Convert(char(10),@nLOCIDCnt)) +
                  '  PMoveInIDCnt=' + RTRIM(Convert(char(10),@nPendingMoveInIDCnt)) +
                  '  MaxPL=' + RTRIM(Convert(char(10),@nMaxPallet))
               EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @cLOC, @c_Reason
            END
         END
         ELSE
         BEGIN
            IF @b_Debug = 1
            BEGIN
               SELECT @c_Reason = 'FAILED Fit in aisle:' + RTRIM( @c_NextPnDAisle) + '  UCC=' + RTRIM(@cUCC)
               EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @cLOC, @c_Reason
            END
            CLOSE @curUCC19
            DEALLOCATE @curUCC19

            SET @c_FitCasesInAisle = ''
            SELECT @b_RestrictionsPassed = 0
            GOTO RESTRICTIONCHECKDONE
         END
         FETCH NEXT FROM @curUCC19 INTO @cUCC
      END
      CLOSE @curUCC19
      DEALLOCATE @curUCC19

      -- Handling transaction

      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN nspRDTPASTD_FitByAisle -- For rollback or commit only our own transaction

      -- Update LOTxLOCxID.PendingMoveIn
      SET @curUCC19 = CURSOR FOR
         SELECT t.UCCNo, t.LOC
         FROM #tUCCPendingMoveIn t WITH (NOLOCK)
         ORDER BY t.UCCNo
      OPEN @curUCC19
      FETCH NEXT FROM @curUCC19 INTO @cUCC, @cSuggestedLOC
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Get UCC info
         SELECT
            @cLOT = LOT,
            @cLOC = LOC,
            @cID = ID,
            @cSKU = SKU,
            @nQTY = QTY
         FROM dbo.UCC WITH (NOLOCK)
         WHERE UCCNo = @cUCC

         -- Use UCCNo as ID for booking
         SET @cToID = RIGHT( RTRIM( @cUCC), 18)

         -- Unlock suggested LOC by UCC
         IF EXISTS( SELECT 1 FROM dbo.RFPutaway WITH (NOLOCK) WHERE StorerKey = @c_StorerKey AND CaseID = @cUCC)
            EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'
               ,@cLOC
               ,@cID
               ,'' -- @cSuggestedLOC
               ,@c_StorerKey
               ,@n_Err       OUTPUT
               ,@c_ErrMsg    OUTPUT
               ,@cUCCNo      = @cUCC

         -- Lock suggested LOC by UCC
         EXEC rdt.rdt_Putaway_PendingMoveIn @c_userid, 'LOCK'
            ,@cLOC
            ,@cID
            ,@cSuggestedLOC
            ,@c_StorerKey
            ,@n_Err       OUTPUT
            ,@c_ErrMsg    OUTPUT
            ,@cSKU        = @cSKU
            ,@nPutawayQTY = @nQTY
            ,@cUCCNo      = @cUCC
            ,@cFromLOT    = @cLOT
            ,@cToID       = @cToID
            ,@nPABookingKey = @n_PABookingKey OUTPUT

         IF @n_Err <> 0
         BEGIN
            ROLLBACK TRAN nspRDTPASTD_FitByAisle
            WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
               COMMIT TRAN

            IF @b_Debug = 1
            BEGIN
               SELECT @c_Reason = 'FAILED Fit in aisle:' + RTRIM( @c_NextPnDAisle) + '  LOC updated by others'
               EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @cSuggestedLOC, @c_Reason
           END

            SET @c_FitCasesInAisle = ''
            SELECT @b_RestrictionsPassed = 0
            GOTO RESTRICTIONCHECKDONE
         END

         FETCH NEXT FROM @curUCC19 INTO @cUCC, @cSuggestedLOC
      END
      CLOSE @curUCC19
      DEALLOCATE @curUCC19

      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN
   END



   /********************************************************************
   Failed If Putaway Loc = From Loc (ChewKP05)
   *********************************************************************/

   IF @c_FromLoc = @c_Toloc
   BEGIN
      IF @b_Debug = 1
      BEGIN
         SELECT @c_Reason = 'FAILED: From Location = Putaway Location '+ RTRIM(@c_FromLoc)
         EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey,
                     @c_PutawayStrategyLineNumber, @n_PtraceDetailKey,
                     @c_ToLoc, @c_Reason
      END
      SELECT @b_RestrictionsPassed = 0

   END

   RESTRICTIONCHECKDONE:   
   IF @cpa_PAType = '01'
   BEGIN
      GOTO PATYPE01
   END
   IF @cpa_PAType = '03'
   BEGIN
      GOTO PATYPE03
   END
   IF @cpa_PAType = '05' --(ung09)
      GOTO PATYPE05
   IF @cpa_PAType = '02' OR
      @cpa_PAType = '04' OR
      @cpa_PAType = '59' OR -- (SHONG01)
      @cpa_PAType = '12' OR -- SOS133180
      @cpa_PAType = '61'
   BEGIN
      IF @cpa_LocSearchType = '1'
      BEGIN
         GOTO PATYPE02_BYLOC_A
      END
      ELSE IF @cpa_LocSearchType = '2'
      BEGIN
         GOTO PATYPE02_BYLOGICALLOC
      END
   END

   IF @cpa_PAType = '04' OR
      @cpa_PAType = '16' OR -- IDSV5 - Leo - SOS# 3553 - Search Location With the same Sku Within Sku Zone
      @cpa_PAType = '17' OR -- SOS36712 KCPI - Search Empty Location Within Sku Zone
      @cpa_PAType = '18' OR -- SOS36712 KCPI - Search Location Within Specified Zone
      @cpa_PAType = '19' OR -- SOS36712 KCPI - Search Empty Location Within Specified Zone
      @cpa_PAType = '21' OR -- Search Location With the same Sku (consider pendingmovein too) within Sku Zone SOS257227
      @cpa_PAType = '22' OR -- Search ZONE specified in sku table for Single Pallet and must be Empty Loc
      @cpa_PAType = '23' OR -- Search loc within specified zones with same sku (consider pendingmovein too)
      @cpa_PAType = '24' OR -- Search ZONE specified in this strategy for Single Pallet and must be empty Loc
      @cpa_PAType = '30' OR -- Search loc within specified zone (with pendingmovein)
      @cpa_PAType = '32' OR -- Search ZONE specified in sku table for Multi Pallet where unique sku = sku putaway
      @cpa_PAType = '34' OR -- Search ZONE specified in this strategy for Multi Pallet where unique sku = sku putaway
      @cpa_PAType = '42' OR -- Search ZONE specified in sku table for Empty Multi Pallet Location
      @cpa_PAType = '44' OR -- Search ZONE specified in this strategy for empty Multi Pallet location
      -- added for China - Putaaway to location with matching Lottable02 and Lottable04
      @cpa_PAType = '52' OR -- Search Zone specified in SKU table for matching Lottable02 and Lottable04
      @cpa_PAType = '54' OR
      @cpa_PAType = '55' OR -- SOS69388 KFP - Cross facility - search location within specified zone
                            --                with matching Lottable02 and Lottable04 (do NOT mix sku)
      @cpa_PAType = '56' OR -- SOS69388 KFP - Cross facility - search Empty Location base on HostWhCode inventory = 0
      @cpa_PAType = '57' OR -- SOS69388 KFP - Cross facility - search suitable location within specified zone (mix with diff sku)
      @cpa_PAType = '58' OR -- SOS69388 KFP - Cross facility - search suitable location within specified zone (do NOT mix sku)
      @cpa_PAType = '59' OR -- SOS133180
      @cpa_PAType = '61' OR
      @cpa_PAType = '62' OR   -- (ChewKP07)
      @cpa_PAType = '63' --NJOW01
   BEGIN
      IF @cpa_LocSearchType = '1'
      BEGIN
         GOTO PATYPE02_BYLOC_B
      END
      IF @cpa_LocSearchType = '2'
      BEGIN
         GOTO PATYPE02_BYLOGICALLOC
      END
   END
   IF @cpa_PAType = '06'
   BEGIN
      GOTO PATYPE06
   END
   IF @cpa_PAType = '08' OR
      @cpa_PAType = '07' OR
      @cpa_PAType = '88' -- CDC Migration
   BEGIN
      GOTO PATYPE08
   END
   IF @cpa_PAType = '09'
   BEGIN
      GOTO PATYPE09
   END
   IF @cpa_PAType = '15'
   BEGIN
      GOTO PATYPE15
   END
   /* Start Add by DLIM for FBR22 20010620 */
   IF @cpa_PAType = '20'
   BEGIN
      GOTO PATYPE20
   END
   /* END Add by DLIM for FBR22 20010620 */

   IF @cpa_PAType = '25' -- (Shong001)
   BEGIN
      GOTO PATYPE25
   END
   IF @cpa_PAType = '26' -- (Shong001)
   BEGIN
      GOTO PATYPE26
   END
   IF @cpa_PAType = '27' -- (Shong001)
   BEGIN
      GOTO PATYPE27
   END
   IF @cpa_PAType = '28' -- (Shong001)
   BEGIN
      GOTO PATYPE28
   END
  IF @cpa_PAType = '29' -- (Shong001)
   BEGIN
      GOTO PATYPE29
   END

   IF @cpa_PAType = '60' -- SOS133180
   BEGIN
      GOTO PATYPE60
   END

   LOCATION_EXIT:
   IF @b_GotLoc = 1
   BEGIN
      SELECT @c_Final_ToLoc = @c_ToLoc
      IF @b_Debug = 2
      BEGIN
         PRINT 'Final Location is ' + @c_Final_ToLoc
         
      END
   END
   ELSE
      SET @c_Final_ToLoc = ''

   GOTO LOCATION_DONE

   Location_Error:
   SELECT @n_Err = 72897
   SET @c_ErrMsg = 'No Location'
   RAISERROR (@n_Err, 10, 1) WITH SETERROR -- SOS# 209838

   LOCATION_DONE:
END

GO