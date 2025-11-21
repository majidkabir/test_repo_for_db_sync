SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
      
/************************************************************************/      
/* Stored Procedure: ispOrderBatching                                   */      
/* Creation Date: 21-Jan-2014                                           */      
/* Copyright: IDS                                                       */      
/* Written by: Chee Jun Yan                                             */      
/*                                                                      */      
/* Purpose: Assign Batch Number to orders within Load based on passed   */      
/*          parameters value:                                           */      
/*          @n_OrderCount - Number of orders per batch                  */      
/*          @c_PickZones  - Assign batch based on pickzone given        */      
/*                          [ZoneA,ZoneB,ZoneC,ZoneD (Comma delimited)] */      
/*          @c_Mode:                                                    */      
/*          0 - Normal, assign based on ordercount and pick zones given */      
/*              (1 batch 1 zone multi ord, 1 ord single/multi qty single/multi zone, 1 ord multi batch)*/      
/*          1 - Only batch order with total qty > 1 and with single     */      
/*              pickzone                                                */      
/*              (1 batch 1 zone multi ord, 1 ord multi qty 1 zone, 1 ord 1 batch)*/      
/*          2 - Only batch order with total qty > 1 and with multiple   */      
/*              pickzone                                                */      
/*              (1 batch 1 zone multi ord, 1 ord multi qty multi zone, 1 ord multi batch)*/      
/*          3 - Only batch order with total qty > 1 including single    */      
/*              and multiple pickzone                                   */      
/*              (1 batch 1 zone multi ord, 1 ord multi qty single/multi zone, 1 ord multi batch)*/      
/*          4 - Only Batch Order with Qty >1 and with multi pickzone,   */      
/*              but not split batch  by pickzone, one order always      */      
/*              assign to one batch.                                    */      
/*              (1 batch multi zone multi ord, 1 ord multi qty multi zone, 1 ord 1 batch)*/      
/*          5 - Only Batch Order with Qty >1, with single and multi     */      
/*              pickzone, but not split batch by pickzone, one order    */      
/*              always assign to one batch.                             */      
/*              (1 batch multi zone multi ord, 1 ord multi qty single/multi zone, 1 ord 1 batch)*/      
/*          9 - Only Batch Order with Qty = 1 and Sort by Loc, split    */      
/*              batch for different pick zone.                          */      
/*              (1 batch 1 zone multi ord, 1 ord 1 qty 1 zone, 1 ord 1 batch)*/      
/*                                                                      */      
/*          1=Multi-S 4=Multi-M 5=BIG 9=Single                          */      
/*                                                                      */      
/* Called By:                                                           */      
/*                                                                      */      
/* PVCS Version: 3.8                                                    */      
/*                                                                      */      
/* Version: 1.0                                                         */      
/*                                                                      */      
/* Data Modifications:                                                  */      
/*                                                                      */      
/* Updates:                                                             */      
/* Date         Author  Rev   Purposes                                  */      
/* 21-01-2014   Chee    1.0   Initial Version                           */      
/* 18-06-2014   Chee    1.1   Bug Fix - Clear Diff for new batch        */      
/*                            Show error message when no result (Chee01)*/      
/* 04-07-2014   Chee    1.2   Filter by mode first, before filter by  */      
/*                            pickzone (Chee02)                         */      
/* 23-07-2014   Chee    1.3   Update PickDetail.Notes = Pickzone + '-'  */      
/*                            + Batch + ':' + Mode (Chee03)             */      
/* 30-07-2014   Chee    1.4   Add leading zeros to batch number, for    */      
/*                            sorting purpose (Chee04)                  */      
/* 16-12-2014   Shong   1.5   Sort By Average Score when min(Score) is  */      
/*                            similar SOS328734                         */      
/* 27-03-2015   NJOW01  1.6   328734-Add loadkey in notes               */      
/* 22-07-2015   NJOW02  1.7   Fix incorrect batch count                 */      
/* 06-08-2015   NJOW03  1.8   328734-Change ':' to '-' at notes value   */      
/* 08-12-2015   NJOW04  1.9   358572-change logic.                      */      
/* 10-08-2016   NJOW05  2.0   358572-validate order count parameter     */      
/* 23-08-2016   NJOW06  2.1   375824-add parameter for rpt re-gen batch */      
/* 07-09-2016   TLTING  2.2   Performance Tune (tlting01)               */      
/* 10-07-2017   Wan01   2.3   WMS-2304 - CN-Nike SDC WMS ECOM Generate  */      
/*                            PackTask CR                               */      
/* 07-09-2016   TLTING  2.4   Performance Tune (tlting02)               */      
/* 28-03-2018   SPChin  2.5   INC0152000 - Bug Fixed                    */      
/* 03-04-2018   Wan03   2.6   WMS-4406 - ECOM Auto Allocation Dashboard */      
/* 24-04-2018   NJOW07  2.7   WMS-4775 remove deviceposition and        */      
/*                            replenishmentgroup when Re-Generate       */      
/* 18-07-2018   TLTING  2.8   Performance Tune (tlting03)               */      
/* 29-JUL-2019  CSCHONG 2.9   WMS-9278 - add new parameter (CS01)       */      
/* 19-Dec-2019  NJOW08  3.0   WMS-11479 - CN IKEA support group by      */      
/*                            loc.descr instead of pickzone             */      
/* 03-Aug-2020  NJOW09  3.1   WMS-14563 Avoid split single order(mode 9)*/      
/*                            loc into two batch by config. Sort by loc */      
/* 19-Aug-2020  NJOW10  3.2   WMS-14811 determine single/multi order    */      
/*                            by ECOM_SINGLE_Flag                       */      
/* 05-Oct-2021  NJOW    3.3   DEVOPS combine script                     */      
/* 05-Oct-2021  NJOW11  3.4   WMS-18023 split batch by qty limit        */      
/* 11-Feb-2022  NJOW12  3.5   WMS-18863 M9 Split batch by lottable02    */      
/* 11-Feb-2022  NJOW12  3.5   DEVOPS Combine script                     */      
/* 11-Mar-2022  SYChua  3.6   JSM-56364 - Fix for 18467 that has 9 digit*/      
/*                            Score value (SY01)                        */      
/* 21-Jul-2022  WLChooi 3.7   WMS-20271 - Remove SKU.BUSR7 filter (WL01)*/      
/* 14-Jul-2022  WLChooi 3.8   WMS-20707 - Extend @c_rptprocess (WL02)   */      
/* 16-Mar-2023  NJOW13  3.9   WMS-21961 Allow configure orders sorting  */     
/* 12-Jun-2023  WinSern 4.0   Add Status<'3'when update pickdetail(ws01)*/     
/************************************************************************/      
      
CREATE   PROC [dbo].[ispOrderBatching]      
     @c_LoadKey     NVARCHAR(10)      
   , @n_OrderCount  INT      
   , @c_PickZones   NVARCHAR(4000)OUTPUT  --(Wan01) Return PickZOnes      
   , @c_Mode        NVARCHAR(1) = '0'      
   , @b_Success     INT           OUTPUT      
   , @n_Err         INT           OUTPUT      
   , @c_ErrMsg      NVARCHAR(250) OUTPUT      
   , @c_CallSource  NVARCHAR(10) = '' -- NJOW04 'RPT'- call from report no regenerate. 'RPTREGEN' - call from report with regenerate      
   , @c_WaveKey     NVARCHAR(10) = ''     --(Wan01)      
   , @c_UOM         NVARCHAR(500)= ''     --(Wan01)      
   , @c_updatepick  NCHAR(5)     = 'N'    --(Wan03)      
   , @c_rptprocess  NVARCHAR(4000) = ''     --(CS01)   --WL02      
      
AS      
BEGIN      
   SET NOCOUNT ON      
   SET QUOTED_IDENTIFIER OFF      
   SET ANSI_NULLS OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF      
      
   DECLARE      
      @n_Continue   INT,      
      @n_StartTCnt  INT, -- Holds the current transaction count      
      @c_OrderKey   NVARCHAR(10),      
      @n_Counter    INT,      
      @n_BatchNo    INT,      
      @n_Count      INT,      
    @c_PickZone   NVARCHAR(10),      
      @b_debug      INT,      
      @b_Found      INT,   -- (Chee01)      
      @c_BatchCode  NVARCHAR(10), --NJOW04      
      @c_OrderMode  NVARCHAR(10), --NJOW04      
      @c_Storerkey  NVARCHAR(15), --NJOW05      
      @c_Facility   NVARCHAR(5), --NJOW05      
      @c_UDF01      NVARCHAR(30), --NJOW05      
      @c_UDF02      NVARCHAR(30), --NJOW05      
      @c_Pickdetailkey NVARCHAR(10),  -- tlting01      
      @c_BatchNo    NVARCHAR(10),     -- tlting01      
      @n_RowRef     BIGINT            -- tlting01      
   ,  @c_Sourcekey   NVARCHAR(10)            --(Wan01)      
   ,  @c_BatchSource NVARCHAR(2)             --(Wan01) 'LP'- Loadkey, 'WP'- Wavekey      
   ,  @c_ZoneList    NVARCHAR(4000)          --(Wan01)   --INC0152000      
   ,  @c_SQL         NVARCHAR(4000)          --(Wan01)      
   ,  @c_SQLArgument  NVARCHAR(4000)         --(Wan01)      
   ,  @n_RecCnt                  INT         --(Wan01)      
   ,  @c_BatchOrderZoneFromTask  NVARCHAR(30)--(Wan01)      
   ,  @c_ExcludeLocType          NVARCHAR(50)--(Wan01)      
   ,  @c_replenishrequire        NVARCHAR(1) --(CS01)      
   ,  @c_OrderBatchBylocdescr    NVARCHAR(10)--NJOW08      
   ,  @c_OrderBatchByLocDescr_OPT1 NVARCHAR(50) --NJOW08      
   ,  @c_CurrLoc                   NVARCHAR(10) --NJOW09      
   ,  @c_NextLoc                   NVARCHAR(10) --NJOW09      
   --,  @c_CurrLocType               NVARCHAR(10) --NJOW09      
   ,  @c_OrdBatchM9LocNotSplitBth  NVARCHAR(30) --NJOW09      
   ,  @n_NextLocOrdCnt             INT          --NJOW09      
   ,  @c_OrdBatchBySingleFlag      NVARCHAR(10) --NJOW10      
   ,  @c_OrdBatchM9Lot2SplitBth    NVARCHAR(30) --NJOW12      
   ,  @n_GroupNo                   INT          --NJOW12      
   ,  @n_PrevGroupNo               INT          --NJOW12      
   ,  @c_ByUOM                     NVARCHAR(10) --WL02      
   ,  @c_OrdBatchConfig            NVARCHAR(30)=''   --NJOW13             
   ,  @c_OrdBatchConfig_Opt5       NVARCHAR(MAX)=''  --NJOW13      
   ,  @c_OrderSorting              NVARCHAR(2000)='' --NJOW13       
   ,  @c_IsCustomOrdSort           NVARCHAR(1)='N'   --NJOW13      
      
   --NJOW11      
   DECLARE      
      @n_CurrBatchQty              INT      
   ,  @n_CurrOrdQty                INT      
   ,  @n_MaxBatchQty               INT      
   ,  @c_OrdBatchQtyLimit          NVARCHAR(30)      
      
  SET @c_ZoneList = @c_PickZones         --(Wan01)      
  SET @c_replenishrequire = ''               --(CS01)      
      
  CREATE TABLE #OrderTable      
   ( rowref    INT NOT NULL IDENTITY(1,1) PRIMARY KEY,      
      OrderKey  NVARCHAR(10),      
      Loc       NVARCHAR(10),      
      Score     INT  NULL DEFAULT (0),       --(Wan02) Fixed to default 0      
      Qty       INT,      
      Diff      INT NULL DEFAULT (0)         --(Wan01) Fixed to default 0      
      
   )      
   Create index IDX_OrderTable_Ord ON #OrderTable (OrderKey, LOC)      
      
  CREATE TABLE #BatchResultTable      
   (  rowref    INT NOT NULL IDENTITY(1,1) PRIMARY KEY,      
      BatchNo  NVARCHAR(10),      
      OrderKey  NVARCHAR(10),      
      Loc       NVARCHAR(10),      
      Score     INT NULL DEFAULT (0), --(Wan02) Fixed to default 0      
      Status    NCHAR(1) DEFAULT '0'      
   )      
   Create index IDX_BatchResultTable_Ord ON #BatchResultTable (OrderKey, LOC)      
      
      
   CREATE TABLE #PickZoneTable      
   (      
      rowref    INT NOT NULL IDENTITY(1,1) PRIMARY KEY,      
      PickZone NVARCHAR(10)      
   )      
      
   -- Shong001      
   CREATE TABLE #OrderAvgScore      
   (      
      rowref    INT NOT NULL IDENTITY(1,1) PRIMARY KEY,      
      OrderKey  NVARCHAR(10),      
      Score     INT NULL DEFAULT (0), --(Wan02) Fixed to default 0      
      )      
      
   Create index IDX_OrderAvgScore_Ord ON #OrderAvgScore  (OrderKey)          
   --(Wan01) - START      
   CREATE TABLE #TMP_ORDAVGSCORE      
   ( RowRef    INT NOT NULL IDENTITY(1,1) PRIMARY KEY,      
      OrderKey  NVARCHAR(10),      
      AVgScore  INT      
   )      
      
   -- CREATE #TMP_PICKLOC if not calling Function not create it      
   IF OBJECT_ID('tempdb..#TMP_PICKLOC','u') IS NULL      
   BEGIN      
      CREATE TABLE #TMP_PICKLOC      
         (  PickDetailKey  NVARCHAR(10)   NOT NULL DEFAULT ('')   PRIMARY KEY      
         ,  Loc            NVARCHAR(10)   NOT NULL DEFAULT ('')      
     ,  TaskDetailKey  NVARCHAR(10)   NOT NULL DEFAULT ('')      
         )      
      CREATE INDEX #IDX_PICKLOC_LOC ON #TMP_PICKLOC (Loc)      
   END      
   --(Wan01) - END      
      
  --NJOW12      
  CREATE TABLE #SkuLot2Grouping      
   ( rowref      INT NOT NULL IDENTITY(1,1) PRIMARY KEY,      
      Sku        NVARCHAR(20),      
      Lottable02 NVARCHAR(18) NOT NULL DEFAULT (''),      
      GroupNo    INT NOT NULL DEFAULT (0)      
   )      
      
   --DECLARE @t_OrderTable TABLE (      
   --   OrderKey  NVARCHAR(10),      
   --   Loc       NVARCHAR(10),      
   --   Score     INT,      
   --   Qty       INT,      
   --   Diff      INT      
   --)      
      
   --DECLARE @t_BatchResultTable TABLE (      
   --   BatchNo   NVARCHAR(10),      
   --   OrderKey  NVARCHAR(10),      
   --   Loc       NVARCHAR(10),      
   --   Score     INT,      
   --   Status    NCHAR(1) DEFAULT '0'      
   --)      
      
   --DECLARE @t_PickZoneTable TABLE(      
   --   PickZone NVARCHAR(10)      
   --)      
      
   ---- Shong001      
   --DECLARE @t_OrderAvgScore TABLE (      
   --OrderKey  NVARCHAR(10),      
   --Score     INT)      
      
   DECLARE @n_MinScore INT      
   SET @n_MinScore = 0      
      
   SELECT @n_StartTCnt=@@TRANCOUNT , @n_Continue=1, @b_Success=1, @n_Err=0      
   SELECT @c_ErrMsg=''      
   SELECT @b_debug = 0,      
          @b_Found = 0  -- (Chee01)      
      
   IF @@TRANCOUNT = 0      
      BEGIN TRAN      
      
   --(Wan01) - START      
   SET @c_BatchSource = 'LP'      
   IF ISNULL(RTRIM(@c_Wavekey),'') <> ''      
   BEGIN      
      SELECT TOP 1 @c_Storerkey = ORDERS.Storerkey      
                  ,@c_Facility = ORDERS.Facility      
      FROM ORDERS (NOLOCK)      
      JOIN wavedetail (NOLOCK) on wavedetail.orderkey = orders.orderkey      
      WHERE wavedetail.wavekey = @c_Wavekey   -- tlting03      
      
      SET @c_BatchSource = 'WP'      
   END      
   --(Wan01) - END      
      
   IF ISNULL(RTRIM(@c_Loadkey),'') <> ''                                --(Wan01)      
   BEGIN      
      --NJOW05      
      SELECT TOP 1 @c_Storerkey = Storerkey      
                  ,@c_Facility = Facility      
      FROM ORDERS (NOLOCK)      
      WHERE Loadkey = @c_Loadkey      
   END                                                                  --(Wan01)      
      
   --NJOW04 Start      
   SELECT @c_OrderMode = CASE WHEN @c_Mode = '9' THEN 'S-' + @c_Mode ELSE 'M-' + @c_Mode END      
      
   IF ISNULL(@c_LoadKey, '') = '' AND @c_BatchSource = 'LP'             --(Wan01)      
   BEGIN      
      SELECT @n_Continue = 3      
      SELECT @n_Err = 63500      
      SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Loadkey is empty. (ispOrderBatching)'      
      GOTO Quit      
   END      
      
   IF ISNULL(RTRIM(@c_Loadkey),'') <> ''                                --(Wan01)      
   BEGIN      
      IF NOT EXISTS(SELECT 1 FROM LOADPLANDETAIL WITH (NOLOCK) WHERE LoadKey = @c_LoadKey)      
      BEGIN      
         SELECT @n_Continue = 3      
         SELECT @n_Err = 63501      
         SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Invalid LoadKey. (ispOrderBatching)'      
         GOTO Quit      
      END      
   END                                                                  --(Wan01)      
      
   --(Wan01) - START      
   IF ISNULL(RTRIM(@c_Wavekey),'') <> ''      
   BEGIN      
      IF NOT EXISTS(SELECT 1 FROM WAVEDETAIL WITH (NOLOCK) WHERE Wavekey = @c_WaveKey)      
      BEGIN      
         SELECT @n_Continue = 3      
         SELECT @n_Err = 63520      
         SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Invalid WaveKey. (ispOrderBatching)'      
         GOTO Quit      
      END      
   END          
   SELECT @c_ByUOM = dbo.fnc_GetParamValueFromString('@byuom', @c_rptprocess, @c_ByUOM)   --WL02      
      
   IF ISNULL(@c_ByUOM,'') <> 'Y' SET @c_ByUOM = 'N'   --WL02      
      
   IF ISNULL(@c_UOM,'') <> '' AND @c_Mode <> '9'       
      AND (LEFT(TRIM(ISNULL(@c_rptprocess,'')), 5) <> 'byuom' OR @c_ByUOM = 'N') --CS01   --WL02      
   BEGIN      
      SET @n_Continue = 3      
      SET @n_Err = 63521      
      SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Invalid Mode with UOM. UOM filtering only for Mode = ''9''. (ispOrderBatching)'      
      GOTO QUIT      
   END      
   --(Wan01) - END      
      
   --(CS01) START      
      
   IF LEFT(TRIM(ISNULL(@c_rptprocess,'')), 5) = 'byuom' OR @c_ByUOM = 'Y'   --WL02      
   BEGIN      
      IF @c_UOM = '6'      
       BEGIN      
       SET @c_replenishrequire = 'N'      
       END      
       ELSE      
       BEGIN      
          SET  @c_replenishrequire = 'Y'      
       END      
   END      
      
   --(CS01) END      
      
   IF ISNULL(@n_OrderCount, 0) <= 0      
   BEGIN      
      SELECT @n_Continue = 3      
      SELECT @n_Err = 63502      
      SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Order count must be larger than zero. (ispOrderBatching)'      
      GOTO Quit      
   END      
      
   --NJOW05      
   SELECT TOP 1 @c_UDF01 = UDF01, @c_UDF02 = UDF02      
   FROM CODELKUP(NOLOCK)      
   WHERE Listname = 'BATCHCOUNT'      
   AND Storerkey = @c_Storerkey      
   AND Short = @c_Mode      
   AND (Code2 = @c_Facility OR ISNULL(Code2,'')='')      
   ORDER BY ISNULL(Code2,'') DESC      
      
   IF ISNULL(@c_UDF01,'') <> '' AND ISNUMERIC(@c_UDF01) = 1      
   BEGIN      
        IF ISNULL(@n_OrderCount, 0) > CAST(@c_UDF01 AS INT)      
        BEGIN      
         SELECT @n_Continue = 3      
         SELECT @n_Err = 63503      
         SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Order count cannot larger than maximum limit ' + RTRIM(@c_UDF01) + ' (ispOrderBatching)'      
         GOTO Quit      
        END      
   END      
      
   IF ISNULL(@c_UDF02,'') <> '' AND NOT EXISTS (SELECT 1 FROM dbo.fnc_DelimSplit(',', @c_UDF02) AS VAL WHERE ISNUMERIC(Colvalue) = 0)      
   BEGIN      
        IF NOT EXISTS(SELECT 1 FROM dbo.fnc_DelimSplit(',', @c_UDF02) AS VAL      
                      WHERE CAST(colvalue AS INT) = @n_Ordercount)      
        BEGIN      
         SELECT @n_Continue = 3      
         SELECT @n_Err = 63504      
         SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Order count value must be in ' + RTRIM(@c_UDF02) + ' (ispOrderBatching)'      
         GOTO Quit      
        END      
   END      
      
   --NJOW08      
   SET @c_OrderBatchBylocdescr = ''      
   EXEC nspGetRight      
        @c_Facility  = @c_Facility      
      , @c_StorerKey = @c_StorerKey      
      , @c_sku       = NULL      
      , @c_ConfigKey = 'OrderBatchByLocDescr'      
      , @b_Success   = @b_Success         OUTPUT      
      , @c_authority = @c_OrderBatchBylocdescr   OUTPUT      
      , @n_err       = @n_err             OUTPUT      
      , @c_errmsg    = @c_errmsg          OUTPUT      
      , @c_Option1   = @c_OrderBatchByLocDescr_OPT1  OUTPUT      
      
   IF @c_OrderBatchBylocdescr = '1'      
   BEGIN      
        IF @c_OrderBatchByLocDescr_OPT1 = 'TMALL' AND ISNULL(@c_Loadkey,'') <> ''      
        BEGIN      
         IF NOT EXISTS(SELECT 1      
                         FROM LOADPLANDETAIL LPD (NOLOCK)      
                         JOIN ORDERS O (NOLOCK) ON LPD.Orderkey = O.Orderkey      
                         JOIN ORDERINFO OI (NOLOCK) ON O.Orderkey = OI.Orderkey      
                         WHERE LPD.Loadkey = @c_Loadkey      
                         AND OI.StoreName = '618'      
                         AND O.Shipperkey = 'SN')      
           BEGIN      
              SET @c_OrderBatchBylocdescr = '0'      
           END      
        END      
   END      
      
   --NJOW09      
   SET @c_OrdBatchM9LocNotSplitBth = ''      
   EXEC nspGetRight      
        @c_Facility  = @c_Facility      
      , @c_StorerKey = @c_StorerKey      
      , @c_sku       = NULL      
      , @c_ConfigKey = 'OrdBatchM9LocNotSplitBth'      
      , @b_Success   = @b_Success   OUTPUT      
      , @c_authority = @c_OrdBatchM9LocNotSplitBth   OUTPUT      
      , @n_err       = @n_err             OUTPUT      
      , @c_errmsg    = @c_errmsg          OUTPUT      
      
 --NJOW10      
   SET @c_OrdBatchBySingleFlag = ''      
   EXEC nspGetRight      
        @c_Facility  = @c_Facility      
      , @c_StorerKey = @c_StorerKey      
      , @c_sku       = NULL      
      , @c_ConfigKey = 'OrdBatchBySingleFlag'      
      , @b_Success   = @b_Success         OUTPUT      
      , @c_authority = @c_OrdBatchBySingleFlag   OUTPUT      
      , @n_err       = @n_err             OUTPUT      
      , @c_errmsg    = @c_errmsg          OUTPUT      
      
   --NJOW12      
   SET @c_OrdBatchM9Lot2SplitBth = ''      
   EXEC nspGetRight      
        @c_Facility  = @c_Facility      
      , @c_StorerKey = @c_StorerKey      
      , @c_sku       = NULL      
      , @c_ConfigKey = 'OrdBatchM9Lot2SplitBth'      
      , @b_Success   = @b_Success         OUTPUT      
      , @c_authority = @c_OrdBatchM9Lot2SplitBth   OUTPUT      
      , @n_err       = @n_err             OUTPUT      
      , @c_errmsg    = @c_errmsg          OUTPUT      
      
   --(Wan01) - START      
   SET @c_BatchOrderZoneFromTask = ''      
   EXEC nspGetRight      
        @c_Facility  = @c_Facility      
      , @c_StorerKey = @c_StorerKey      
      , @c_sku       = NULL      
      , @c_ConfigKey = 'BatchOrderZoneFromTask'      
      , @b_Success   = @b_Success         OUTPUT      
      , @c_authority = @c_BatchOrderZoneFromTask   OUTPUT      
      , @n_err       = @n_err             OUTPUT      
      , @c_errmsg    = @c_errmsg          OUTPUT      
      , @c_Option1   = @c_ExcludeLocType  OUTPUT      
      
   --NJOW11      
   SET @c_OrdBatchQtyLimit = ''      
   IF LEFT(@c_updatepick,2) IN ('NQ','YQ') AND ISNUMERIC(SUBSTRING(@c_updatepick,3,3)) = 1      
   BEGIN      
      SET @c_OrdBatchQtyLimit = '1'      
      SET @n_MaxBatchQty = SUBSTRING(@c_updatepick,3,3)      
      SET @c_updatepick = LEFT(@c_updatepick,1)      
   END      
        
   --NJOW13 S      
   SET @c_OrdBatchConfig = ''      
   SET @c_OrdBatchConfig_Opt5 = ''                    
   SET @c_OrderSorting = ''      
   EXEC nspGetRight      
        @c_Facility  = @c_Facility      
      , @c_StorerKey = @c_StorerKey      
      , @c_sku       = NULL      
      , @c_ConfigKey = 'OrdBatchConfig'      
      , @b_Success   = @b_Success             OUTPUT      
      , @c_authority = @c_OrdBatchConfig      OUTPUT      
      , @n_err       = @n_err                 OUTPUT      
      , @c_errmsg    = @c_errmsg              OUTPUT      
      , @c_Option5   = @c_OrdBatchConfig_Opt5 OUTPUT      
                                                                              
   IF @c_OrdBatchConfig = '1'      
   BEGIN      
      SELECT @c_OrderSorting = RTRIM(dbo.fnc_GetParamValueFromString('@c_OrderSorting', @c_OrdBatchConfig_Opt5, @c_OrderSorting))      
               
      IF ISNULL(@c_OrderSorting,'') <> ''        
         SET @c_IsCustomOrdSort = 'Y'           
   END      
   --NJOW13 E      
      
   SET @c_SQL= N'SELECT DISTINCT'      
             + ' PD.PickDetailKey'      
            + CASE WHEN @c_BatchOrderZoneFromTask = '1'      
                    THEN ',Loc = ISNULL(TD.LogicalToLoc,PD.Loc)'      
                    ELSE ',Loc = PD.Loc'      
                    END      
             + CASE WHEN @c_BatchOrderZoneFromTask = '1'      
                    THEN ',TaskDetailKey=ISNULL(TD.TaskDetailKey,'''')'      
                    ELSE ',TaskDetailKey='''''      
                    END      
             + ' FROM ORDERS O WITH (NOLOCK)'      
             + ' JOIN PICKDETAIL PD WITH (NOLOCK) ON O.Orderkey = PD.Orderkey'      
             + CASE WHEN @c_BatchOrderZoneFromTask = '1'      
                    THEN ' LEFT JOIN TASKDETAIL TD (NOLOCK) ON PD.TaskDetailKey = TD.TaskDetailKey'      
                    ELSE ''      
                    END      
             + CASE WHEN @c_BatchSource = 'LP'      
                    THEN ' WHERE O.Loadkey = @c_Loadkey'      
                    --ELSE ' WHERE O.UserDefine09 = @c_Wavekey'      
                    -- TLTING03 Performance tune      
                    ELSE ' WHERE EXISTS(SELECT 1 FROM dbo.WAVEDETAIL WD (NOLOCK) WHERE WD.Orderkey = O.Orderkey ' +      
                         ' AND WD.WAVEKey = @c_Wavekey) '      
                    END      
             + CASE WHEN @c_UOM = '' THEN ''      
                    ELSE ' AND EXISTS(SELECT 1 FROM dbo.fnc_DelimSplit('','',@c_UOM) WHERE ColValue = PD.UOM)'      
                    END      
      
   SET @c_SQLArgument = N'@c_Loadkey   NVARCHAR(10)'      
                      + ',@c_Wavekey   NVARCHAR(10)'      
                      + ',@c_UOM       NVARCHAR(500)'      
      
   INSERT INTO #TMP_PICKLOC      
      (  PickDetailKey      
      ,  Loc      
      ,  TaskDetailKey)      
   EXEC sp_executesql @c_SQL      
         ,  @c_SQLArgument      
         ,  @c_Loadkey      
         ,  @c_Wavekey      
         ,  @c_UOM      
      
   IF @c_BatchOrderZoneFromTask = '1'      
   BEGIN      
      IF NOT EXISTS (SELECT 1 FROM #TMP_PICKLOC)      
      BEGIN      
         SET @n_Continue = 3      
         SET @n_Err = 63522      
         SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Pick To Loc not found. (ispOrderBatching)'      
         GOTO QUIT      
      END      
      
      SET @n_RecCnt = 0      
      SET @c_SQL= N'SELECT @n_RecCnt = 1'      
             + ' FROM #TMP_PICKLOC PL'      
             + ' JOIN LOC L WITH (NOLOCK) ON (PL.Loc = L.Loc)'      
             + ' WHERE PL.TaskDetailKey = '''''      
             + CASE WHEN @c_ExcludeLocType = '' THEN ''      
                    ELSE ' AND L.LocationType NOT IN (SELECT ColValue FROM dbo.fnc_DelimSplit('','',@c_ExcludeLocType))'      
                    END      
      
      SET @c_SQLArgument = N'@c_ExcludeLocType  NVARCHAR(50)'      
                         + ',@n_RecCnt          INT OUTPUT'      
      
      
      EXEC sp_executesql @c_SQL      
                     ,  @c_SQLArgument      
                     ,  @c_ExcludeLocType      
                     ,  @n_RecCnt OUTPUT      
      
      IF @n_RecCnt > 0      
      BEGIN      
         SET @n_Continue = 3      
         SET @n_Err = 63523      
         SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': There Are Pick Task Not Released. (ispOrderBatching)'      
         GOTO QUIT      
      END      
   END      
      
   IF @c_PickZones = 'ALL'      
   BEGIN      
      SET @c_ZoneList = ''      
      
      IF @c_OrderBatchBylocdescr = '1'  --NJOW08      
      BEGIN      
         SELECT @c_ZoneList = @c_ZoneList + RTRIM(Loc.Descr) + ','      
         FROM #TMP_PICKLOC PL      
         JOIN LOC WITH (NOLOCK) ON  PL.Loc = LOC.Loc      
         WHERE LOC.Descr <> ''      
         AND LOC.Descr IS NOT NULL      
         GROUP BY LOC.Descr      
         ORDER BY LOC.Descr      
      END      
      ELSE      
      BEGIN      
         SELECT @c_ZoneList = @c_ZoneList + RTRIM(Loc.PickZone) + ','      
         FROM #TMP_PICKLOC PL      
         JOIN LOC WITH (NOLOCK) ON  PL.Loc = LOC.Loc      
         GROUP BY LOC.PickZone      
         ORDER BY LOC.PickZone      
      END      
      
      IF ISNULL(@c_ZoneList,'') <> ''      
      BEGIN      
         SET @c_ZoneList = LEFT(@c_ZoneList, LEN(RTRIM(@c_ZoneList)) - 1)      
         SET @c_PickZones = @c_ZoneList      
      END      
      ELSE      
      BEGIN      
         SET @c_ZoneList = @c_PickZones      
      END      
   END      
   --(Wan01) - END      
      
   WHILE CHARINDEX(',', @c_PickZones) > 0      
   BEGIN      
      SET @n_Count = CHARINDEX(',', @c_PickZones)      
      INSERT INTO #PickZoneTable ( PickZone ) VALUES (LTRIM(RTRIM(SUBSTRING(@c_PickZones, 1, @n_Count-1))))      
      SET @c_PickZones = SUBSTRING(@c_PickZones, @n_Count+1, LEN(@c_PickZones)-@n_Count)      
   END      
   INSERT INTO #PickZoneTable (PickZone) VALUES (LTRIM(RTRIM(@c_PickZones)))      
      
   WHILE @@TRANCOUNT > 0      
      COMMIT TRAN;      
      
   IF @@TRANCOUNT = 0      
      BEGIN TRAN;      
      
   -- Assign batch based on pickzone given      
   IF @c_Mode IN ('4','5') --NJOW04      
   BEGIN      
      --(Wan01) - START      
      IF ISNULL(RTRIM(@c_Wavekey),'') <> ''      
      BEGIN      
         DECLARE C_PICKZONE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
         SELECT Wavekey FROM WAVE WITH (NOLOCK) WHERE Wavekey = @c_Wavekey      
      END      
      ELSE      
      BEGIN      
           --not split by pickzone so create 1 dummy record      
         DECLARE C_PICKZONE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
         SELECT loadkey FROM LOADPLAN(NOLOCK) WHERE Loadkey = @c_Loadkey      
      END      
      --(Wan01) - END      
   END      
   ELSE      
   BEGIN      
      DECLARE C_PICKZONE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
      SELECT PickZone FROM #PickZoneTable      
   END      
      
   OPEN C_PICKZONE      
   FETCH NEXT FROM C_PICKZONE INTO @c_PickZone      
      
   --(Wan01) - START      
   IF ISNULL(RTRIM(@c_Wavekey),'') <> ''      
   BEGIN      
      INSERT INTO #TMP_ORDAVGSCORE (OrderKey, AVgScore)      
      --SELECT OS.OrderKey, AVG(OS.Score) AS AVgScore     --SY01      
      SELECT OS.OrderKey, AVG(CAST(OS.Score AS BIGINT)) AS AVgScore     --SY01      
      FROM (      
              SELECT PD.Orderkey, L.Loc, L.Score AS Score      
              FROM PickDetail PD (NOLOCK)      
              JOIN WAVEDETAIL WPD (NOLOCK) ON (WPD.OrderKey = PD.OrderKey)      
              JOIN #TMP_PICKLOC PL  ON (PD.PickDetailKey = PL.PickDetailkey)      
              JOIN LOC          L  (NOLOCK) ON (PL.Loc = L.Loc)      
              WHERE WPD.WaveKey = @c_WaveKey      
              AND L.Score> 0      
              GROUP BY PD.OrderKey, L.LOC, L.Score      
  ) AS OS      
      GROUP BY OS.Orderkey      
   END      
   ELSE      
   BEGIN      
      --NJOW04      
      INSERT INTO #TMP_ORDAVGSCORE (OrderKey, AVgScore)      
      --SELECT OS.OrderKey, AVG(OS.Score) AS AVgScore     --SY01      
      SELECT OS.OrderKey, AVG(CAST(OS.Score AS BIGINT)) AS AVgScore     --SY01      
      FROM (      
              SELECT PD.Orderkey, L.Loc, L.Score AS Score      
              FROM PickDetail PD (NOLOCK)      
              JOIN LOADPLANDETAIL LPD (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)      
              JOIN #TMP_PICKLOC PL          ON (PD.PickDetailKey = PL.PickDetailkey) --(Wan01)      
              JOIN LOC          L  (NOLOCK) ON (PL.Loc = L.Loc)                      --(Wan01)      
              WHERE LPD.LoadKey = @c_LoadKey      
              AND L.Score > 0      
              GROUP BY PD.OrderKey, L.LOC, Score      
           ) AS OS      
      GROUP BY OS.Orderkey      
   END      
   --(Wan01) - END      
      
   WHILE (@@FETCH_STATUS <> -1)      
   BEGIN      
      --(Wan01) - START      
      IF ISNULL(RTRIM(@c_Wavekey),'') <> ''      
      BEGIN      
         SET @c_Sourcekey = @c_Wavekey      
      
         INSERT INTO #OrderTable (OrderKey, Loc, Score, Qty)      
         SELECT PD.OrderKey, L.LOC,      
                CASE WHEN L.Score = 0 THEN      
    OS.AVgScore      
                ELSE L.Score END AS Score,      
                SUM(PD.Qty) AS Qty      
         FROM PICKDETAIL PD (NOLOCK)      
         JOIN WAVEDETAIL WPD (NOLOCK)  ON (WPD.OrderKey = PD.OrderKey)      
         JOIN #TMP_PICKLOC PL          ON (PD.PickDetailKey = PL.PickDetailkey)      
         JOIN LOC          L  (NOLOCK) ON (PL.Loc = L.Loc)      
         LEFT JOIN #TMP_ORDAVGSCORE OS ON PD.Orderkey = OS.Orderkey      
         LEFT JOIN PACKTASK PT (NOLOCK) ON PD.Orderkey = PT.Orderkey      
         WHERE WPD.WaveKey = @c_WaveKey      
         AND (L.Score > 0      
              OR ISNULL(OS.Orderkey,'') <> '' OR @c_Mode = '9')      
         AND (ISNULL(PT.TaskBatchNo,'') = '' OR ISNULL(@c_CallSource,'') <> 'RPT')      
         GROUP BY PD.OrderKey, L.LOC,      
                  CASE WHEN L.Score = 0 THEN      
                     OS.AVgScore      
                  ELSE L.Score END      
      END      
      ELSE      
      BEGIN      
         SET @c_Sourcekey = @c_LoadKey      
      
         INSERT INTO #OrderTable (OrderKey, Loc, Score, Qty)      
         SELECT PD.OrderKey, L.LOC,      
                CASE WHEN L.Score = 0 THEN      
                   OS.AVgScore      
                ELSE L.Score END AS Score, --NJOW04      
                --ISNULL(L.Score, 0) AS Score,      
                SUM(PD.Qty) AS Qty      
         FROM PickDetail PD (NOLOCK)      
         JOIN LOADPLANDETAIL LPD (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)      
         JOIN #TMP_PICKLOC PL          ON (PD.PickDetailKey = PL.PickDetailkey) --(Wan01)      
         JOIN LOC          L  (NOLOCK) ON (PL.Loc = L.Loc)                      --(Wan01)      
         LEFT JOIN #TMP_ORDAVGSCORE OS ON PD.Orderkey = OS.Orderkey --NJOW04      
         LEFT JOIN PACKTASK PT (NOLOCK) ON PD.Orderkey = PT.Orderkey --NJOW04      
         WHERE LPD.LoadKey = @c_LoadKey      
         --  AND L.PickZone = @c_PickZone  -- (Chee02)      
         AND (L.Score > 0      
              OR ISNULL(OS.Orderkey,'') <> '' OR @c_Mode = '9') --NJOW04      
         AND (ISNULL(PT.TaskBatchNo,'') = '' OR ISNULL(@c_CallSource,'') <> 'RPT') --NJOW04      
         GROUP BY PD.OrderKey, L.LOC, --ISNULL(L.Score, 0)      
                  CASE WHEN L.Score = 0 THEN      
                     OS.AVgScore      
                  ELSE L.Score END --NJOW04      
      END      
      --(Wan01) - END      
      IF @c_Mode IN ('1', '2', '3', '4', '5', '9')      
      BEGIN      
         -- Exclude orders with total qty <= 1      
         IF @c_Mode = '9'  --NJOW04      
         BEGIN      
            IF @c_OrdBatchBySingleFlag = '1' --NJOW10      
            BEGIN      
               DELETE #OrderTable      
               FROM #OrderTable      
               JOIN ORDERS O (NOLOCK) ON #OrderTable.Orderkey = O.Orderkey      
               WHERE O.ECOM_SINGLE_Flag <> 'S'      
            END      
            ELSE      
            BEGIN      
               DELETE FROM #OrderTable      
               WHERE OrderKey IN (SELECT OrderKey      
                                  FROM #OrderTable      
                                  GROUP BY OrderKey      
                                HAVING SUM(Qty) > 1)      
            END      
         END      
         ELSE      
         BEGIN      
            IF @c_OrdBatchBySingleFlag = '1' --NJOW10      
            BEGIN      
               DELETE #OrderTable      
               FROM #OrderTable      
               JOIN ORDERS O (NOLOCK) ON #OrderTable.Orderkey = O.Orderkey      
               WHERE O.ECOM_SINGLE_Flag = 'S'      
            END      
            ELSE      
            BEGIN      
               DELETE FROM #OrderTable      
               WHERE OrderKey IN (SELECT OrderKey      
                                  FROM #OrderTable      
                                  GROUP BY OrderKey      
                                  HAVING SUM(Qty) <= 1)      
            END      
         END      
      
         IF @c_Mode = '1'      
         BEGIN      
            -- Exclude orders with multi pickzone      
            IF @c_OrderBatchBylocdescr = '1' --NJOW08      
            BEGIN      
               DELETE FROM #OrderTable      
               WHERE EXISTS  (SELECT 1 -- O.OrderKey      
                                  FROM #OrderTable O      
                                  JOIN PickDetail   PD (NOLOCK) ON (O.OrderKey = PD.OrderKey)      
                                  JOIN #TMP_PICKLOC PL          ON (PD.PickDetailKey = PL.PickDetailkey) --(Wan01)      
                                  JOIN LOC          L  (NOLOCK) ON (PL.Loc = L.Loc)                      --(Wan01)      
                                  WHERE ISNULL(L.Descr, '') <> ''      
                                    AND L.Score > 0      
                                    AND PD.OrderKey =  #OrderTable.OrderKey      
                                  GROUP BY PD.OrderKey      
                                  HAVING COUNT(DISTINCT L.Descr) > 1)      
            END      
            ELSE      
            BEGIN      
               DELETE FROM #OrderTable      
               WHERE EXISTS  (SELECT 1 -- O.OrderKey      
                                  FROM #OrderTable O      
                                  JOIN PickDetail   PD (NOLOCK) ON (O.OrderKey = PD.OrderKey)      
                                  JOIN #TMP_PICKLOC PL          ON (PD.PickDetailKey = PL.PickDetailkey) --(Wan01)      
                                  JOIN LOC          L  (NOLOCK) ON (PL.Loc = L.Loc)                      --(Wan01)      
                                  WHERE ISNULL(L.PickZone, '') <> ''      
                              AND L.Score > 0      
                                    AND PD.OrderKey =  #OrderTable.OrderKey      
                                  GROUP BY PD.OrderKey      
                                  HAVING COUNT(DISTINCT L.PickZone) > 1)      
            END      
         END      
         ELSE IF @c_Mode = '2'      
                 OR @c_Mode = '4' --NJOW04      
         BEGIN      
            -- Exclude orders with single pickzone      
            IF @c_OrderBatchBylocdescr = '1' --NJOW08      
            BEGIN      
               DELETE FROM #OrderTable      
               WHERE OrderKey IN (SELECT O.OrderKey      
                                  FROM #OrderTable O      
                                  JOIN PickDetail PD (NOLOCK) ON (O.OrderKey = PD.OrderKey)      
                                  JOIN #TMP_PICKLOC PL          ON (PD.PickDetailKey = PL.PickDetailkey) --(Wan01)      
                                  JOIN LOC          L  (NOLOCK) ON (PL.Loc = L.Loc)                      --(Wan01)      
                                  WHERE ISNULL(L.Descr, '') <> ''      
                                    AND L.Score > 0      
                                  GROUP BY O.OrderKey      
                                  HAVING COUNT(DISTINCT L.Descr) = 1)      
            END      
            ELSE      
            BEGIN      
               DELETE FROM #OrderTable      
               WHERE OrderKey IN (SELECT O.OrderKey      
                                  FROM #OrderTable O      
                                  JOIN PickDetail PD (NOLOCK) ON (O.OrderKey = PD.OrderKey)      
                                  JOIN #TMP_PICKLOC PL          ON (PD.PickDetailKey = PL.PickDetailkey) --(Wan01)      
                                  JOIN LOC          L  (NOLOCK) ON (PL.Loc = L.Loc)                      --(Wan01)      
                                  WHERE ISNULL(L.PickZone, '') <> ''      
                                    AND L.Score > 0      
                                  GROUP BY O.OrderKey      
                                  HAVING COUNT(DISTINCT L.PickZone) = 1)      
            END      
         END      
      END -- IF @c_Mode IN ('1', '2', '3')      
      
      -- (Chee02)      
      IF @c_Mode NOT IN ('4','5') --NJOW04      
      BEGIN      
          IF @c_OrderBatchBylocdescr = '1' --NJOW08      
          BEGIN      
            DELETE #OrderTable      
            FROM #OrderTable O      
            JOIN LOC L  (NOLOCK) ON (L.LOC = O.LOC)      
            WHERE L.Descr <> @c_PickZone      
         END      
         ELSE      
         BEGIN      
            DELETE #OrderTable      
            FROM #OrderTable O      
            JOIN LOC L  (NOLOCK) ON (L.LOC = O.LOC)      
            WHERE L.PickZone <> @c_PickZone      
         END      
      END      
      
      SELECT      
        @n_Count = COUNT(1),      
        @n_Counter = 1,      
        @n_BatchNo = 1      
      FROM #OrderTable      
      
      -- Shong001 Start      
      SELECT TOP 1  @n_MinScore  = score      
      FROM  #OrderTable      
      ORDER BY score      
      
      INSERT INTO #OrderAvgScore (OrderKey, Score)      
      SELECT OrderKey, Score      
      FROM #OrderTable t1      
      WHERE EXISTS(SELECT 1 FROM #OrderTable t2 WHERE t1.OrderKey = t2.OrderKey AND t2.Score = @n_MinScore)      
      -- Shong001 End      
      
      --NJOW04      
      IF @n_Count > 0      
      BEGIN      
         EXECUTE nspg_getkey      
             'ORDBATCHNO'      
             , 9      
             , @c_BatchCode   OUTPUT      
             , @b_Success OUTPUT      
             , @n_Err     OUTPUT      
             , @c_ErrMsg  OUTPUT      
      
         SET @c_BatchCode = 'B' + @c_BatchCode      
      END      
      
      --NJOW12      
      IF @c_OrdBatchM9Lot2SplitBth = '1' AND @c_Mode = '9' --Single order      
      BEGIN      
         TRUNCATE TABLE #SkuLot2Grouping      
      
         INSERT INTO #SkuLot2Grouping (Sku, Lottable02, GroupNo)      
         SELECT PD.sku, LA.lottable02, ROW_NUMBER() OVER(PARTITION BY PD.sku ORDER BY PD.sku)      
         FROM #OrderTable O (NOLOCK)      
         JOIN PICKDETAIL PD (NOLOCK) ON O.OrderKey =  PD.OrderKey      
         JOIN LOTATTRIBUTE LA (NOLOCK) ON PD.Lot = LA.Lot      
         GROUP BY PD.Sku, LA.Lottable02      
         ORDER BY 2, PD.Sku      
      END      
      
      SET @n_CurrBatchQty = 0  --NJOW11      
      SET @n_PrevGroupNo = 0  --NJOW12      
      WHILE (@n_Count > 0)      
      BEGIN      
         IF @c_Mode = '9' --NJOW04  single order      
         BEGIN      
           IF @c_OrdBatchM9LocNotSplitBth = '1'      
           BEGIN      
               --NJOW09      
               SET @c_CurrLoc = ''      
               /*      
               SELECT TOP 1      
                      @c_OrderKey = O.OrderKey,      
                      @c_CurrLoc = MIN(O.Loc)      
               FROM #OrderTable O      
               JOIN LOC L (NOLOCK) ON O.Loc = L.Loc      
               GROUP BY O.Orderkey      
               ORDER BY MIN(L.LogicalLocation), MIN(O.Loc), O.OrderKey      
               */      
                     
               --NJOW13 S      
               SET @c_SQL = N'SELECT TOP 1      
                         @c_OrderKey = ORDERS.OrderKey,      
                         @c_CurrLoc = MIN(LOC.Loc)      
                  FROM #OrderTable O       
                  JOIN ORDERS (NOLOCK) ON O.Orderkey = ORDERS.Orderkey      
                  JOIN LOC (NOLOCK) ON O.Loc = LOC.Loc      
                  GROUP BY ORDERS.Orderkey ' +      
                  CASE WHEN @c_IsCustomOrdSort = 'Y' THEN      
                     ' ORDER BY ' + @c_OrderSorting       
                  ELSE          
                     ' ORDER BY MIN(LOC.LogicalLocation), MIN(LOC.Loc), ORDERS.OrderKey'      
                  END      
                     
               EXEC sp_executesql @c_SQL      
                   ,  N'@c_Orderkey NVARCHAR(10) OUTPUT, @c_CurrLoc NVARCHAR(10) OUTPUT'      
                   ,  @c_Orderkey OUTPUT      
                   ,  @c_CurrLoc OUTPUT                     
               --NJOW13 E          
                 
               /*SET @c_CurrLocType = ''      
               SELECT TOP 1      
                      @c_OrderKey = O.OrderKey,      
                      @c_CurrLoc = MIN(O.Loc),      
                 @c_CurrLocType = MIN(ISNULL(SL.LocationType,''))      
               FROM #OrderTable O      
               JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey = PD.Orderkey      
               JOIN LOC L (NOLOCK) ON O.Loc = L.Loc      
               LEFT JOIN SKUXLOC SL (NOLOCK) ON L.Loc = SL.Loc AND PD.Storerkey = SL.Storerkey AND PD.Sku = SL.Sku AND SL.LocationType IN('PICK','CASE')      
               GROUP BY O.Orderkey      
               ORDER BY MIN(L.LogicalLocation), MIN(O.Loc), O.OrderKey*/      
           END      
           ELSE IF @c_OrdBatchM9Lot2SplitBth = '1'  --NJOW12      
           BEGIN      
               SET @n_GroupNo = 0      
               /*      
               SELECT TOP 1      
                      @c_OrderKey = O.OrderKey,      
                      @n_GroupNo = MIN(G.GroupNo)      
               FROM #OrderTable O      
               JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey = PD.Orderkey      
               JOIN LOTATTRIBUTE LA (NOLOCK) ON PD.Lot = LA.Lot      
               JOIN #SkuLot2Grouping G (NOLOCK) ON PD.Sku = G.Sku AND LA.Lottable02 = G.Lottable02      
               JOIN LOC L (NOLOCK) ON O.Loc = L.Loc      
               GROUP BY O.Orderkey      
               ORDER BY MIN(G.GroupNo), MIN(L.LogicalLocation), MIN(O.Loc), O.OrderKey      
               */      
                     
               --NJOW13 S      
               SET @c_SQL = N'SELECT TOP 1      
                         @c_OrderKey = ORDERS.OrderKey,      
                         @n_GroupNo = MIN(G.GroupNo)      
                   FROM #OrderTable O       
                   JOIN ORDERS (NOLOCK) ON O.Orderkey = ORDERS.Orderkey      
                   JOIN PICKDETAIL PD (NOLOCK) ON ORDERS.Orderkey = PD.Orderkey      
                   JOIN LOTATTRIBUTE LA (NOLOCK) ON PD.Lot = LA.Lot      
                   JOIN #SkuLot2Grouping G (NOLOCK) ON PD.Sku = G.Sku AND LA.Lottable02 = G.Lottable02      
                   JOIN LOC (NOLOCK) ON O.Loc = LOC.Loc      
                   GROUP BY ORDERS.Orderkey ' +      
                   CASE WHEN @c_IsCustomOrdSort = 'Y' THEN      
                      ' ORDER BY MIN(G.GroupNo),' + @c_OrderSorting       
                   ELSE          
                      ' ORDER BY MIN(G.GroupNo), MIN(LOC.LogicalLocation), MIN(LOC.Loc), ORDERS.OrderKey'      
                   END      
                     
               EXEC sp_executesql @c_SQL      
                   ,  N'@c_Orderkey NVARCHAR(10) OUTPUT, @n_GroupNo INT OUTPUT'      
                   ,  @c_Orderkey OUTPUT      
                   ,  @n_GroupNo OUTPUT             
               --NJOW13 E                                 
                 
               IF ISNULL(@n_GroupNo, 0) <> ISNULL(@n_PrevGroupNo,0) AND @n_PrevGroupNo <> 0 -- close current batch and process this order again in next batch      
               BEGIN      
                 SET @n_PrevGroupNo = @n_GroupNo      
                  GOTO CloseBatch      
               END      
               SET @n_PrevGroupNo = @n_GroupNo      
           END      
           ELSE      
           BEGIN      
              /*      
              SELECT TOP 1      
                     @c_OrderKey = O.OrderKey      
              FROM #OrderTable O      
              JOIN LOC L (NOLOCK) ON O.Loc = L.Loc      
              GROUP BY O.Orderkey      
              ORDER BY MIN(L.LogicalLocation), MIN(O.Loc), O.OrderKey --NJOW09      
              */      
      
              --NJOW13 S      
              SET @c_SQL = N'SELECT TOP 1      
                        @c_OrderKey = ORDERS.OrderKey      
                 FROM #OrderTable O       
                 JOIN ORDERS (NOLOCK) ON O.Orderkey = ORDERS.Orderkey      
                 JOIN LOC (NOLOCK) ON O.Loc = LOC.Loc      
                 GROUP BY ORDERS.Orderkey ' +      
                 CASE WHEN @c_IsCustomOrdSort = 'Y' THEN      
                    ' ORDER BY ' + @c_OrderSorting       
                 ELSE          
                    ' ORDER BY MIN(LOC.LogicalLocation), MIN(LOC.Loc), ORDERS.OrderKey'      
                 END         
                    
              EXEC sp_executesql @c_SQL      
                  ,  N'@c_Orderkey NVARCHAR(10) OUTPUT'      
                  ,  @c_Orderkey OUTPUT      
              --NJOW13 E                                   
           END      
         END      
         ELSE IF @c_IsCustomOrdSort = 'Y' --NJOW13      
         BEGIN      
            SET @c_SQL = N'SELECT TOP 1      
                      @c_OrderKey = ORDERS.OrderKey      
               FROM #OrderTable O       
               JOIN ORDERS (NOLOCK) ON O.Orderkey = ORDERS.Orderkey      
               JOIN LOC (NOLOCK) ON O.Loc = LOC.Loc      
               GROUP BY ORDERS.Orderkey ' +      
               CASE WHEN @c_IsCustomOrdSort = 'Y' THEN      
                  ' ORDER BY ' + @c_OrderSorting       
               ELSE          
                  ' ORDER BY MIN(LOC.LogicalLocation), MIN(LOC.Loc), ORDERS.OrderKey'      
               END      
                  
            EXEC sp_executesql @c_SQL      
                ,  N'@c_Orderkey NVARCHAR(10) OUTPUT'      
                ,  @c_Orderkey OUTPUT      
         END       
         ELSE IF @n_Counter = 1      
         BEGIN      
            -- Clear Diff field for each new batch (Chee01)      
            UPDATE #OrderTable SET Diff = NULL      
      
            IF @b_debug = 1      
            BEGIN      
               SELECT 'RESTART'      
      
               SELECT      
               OrderKey = OrderKey, AVG(CAST(Score AS FLOAT)) AVgScore      
               FROM #OrderAvgScore O      
               GROUP BY OrderKey      
               ORDER BY AVG(CAST(Score AS FLOAT))      
            END      
      
            --NJOW02      
            IF (SELECT COUNT(1) FROM #OrderAvgScore) > 0      
            BEGIN      
              SELECT TOP 1      
                     @c_OrderKey = OrderKey      
              FROM #OrderAvgScore O      
              GROUP BY OrderKey      
              ORDER BY AVG(CAST(Score AS FLOAT))      
            END      
            ELSE      
            BEGIN      
              SELECT TOP 1      
  @c_OrderKey = OrderKey      
              FROM #OrderTable O      
              GROUP BY Orderkey      
              ORDER BY AVG(CAST(O.Score AS FLOAT)), O.OrderKey      
            END      
         END      
         ELSE      
         BEGIN      
            UPDATE #OrderTable      
            SET Diff = B.Diff      
            FROM #OrderTable O      
            JOIN (      
               SELECT      
                  OrderKey, Loc, Score,      
                  CASE WHEN ODiff <= MIN(ABS(Score-RScore)) THEN ODiff      
                       ELSE MIN(ABS(Score-RScore))      
                  END AS Diff      
               FROM (      
                  SELECT O.OrderKey, O.Loc, O.Score, O.Diff AS ODiff, R.Score AS RScore      
                  FROM #OrderTable O      
                  CROSS JOIN #BatchResultTable R      
                  WHERE R.Status <> '9'      
                  GROUP BY O.OrderKey, O.Loc, O.Diff, O.Score, R.Score      
               ) AS A      
               Group BY OrderKey, Loc, Score, ODiff      
            ) AS B      
            ON O.OrderKey = B.OrderKey AND O.Loc = B.Loc      
      
            SELECT TOP 1      
               @c_OrderKey = OrderKey      
            FROM #OrderTable      
            GROUP BY OrderKey      
            ORDER BY AVG(CAST(Diff AS FLOAT))      
         END      
      
         --NJOW11      
         IF @c_OrdBatchQtyLimit = '1'      
         BEGIN      
            SET @n_CurrOrdQty = 0      
            SELECT @n_CurrOrdQty = SUM(PD.Qty)      
            FROM PICKDETAIL PD (NOLOCK)      
            JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku      
            WHERE PD.Orderkey = @c_Orderkey      
            --AND SKU.BUSR7 = '20'   --WL01      
      
            IF @n_CurrOrdQty + @n_CurrBatchQty > @n_MaxBatchQty      
         BEGIN      
               IF @n_CurrOrdQty > @n_MaxBatchQty AND @n_CurrBatchQty = 0      
               BEGIN      
               --The order qty more than batch limit, just place one order into one batch and close it      
                  UPDATE #BatchResultTable      
                  SET Status = '9'      
      
                  INSERT INTO #BatchResultTable (BatchNo, OrderKey, Loc, Score)      
                  SELECT      
                     CAST(@n_BatchNo AS NVARCHAR),      
                     OrderKey,      
                     Loc,      
                     Score      
                  FROM #OrderTable O      
                  WHERE OrderKey = @c_OrderKey      
      
                  DELETE FROM #OrderTable      
                  WHERE OrderKey = @c_OrderKey      
      
                  DELETE FROM #OrderAvgScore      
                  WHERE Orderkey = @c_Orderkey      
      
                  SELECT @n_Count = COUNT(1)      
                  FROM #OrderTable      
      
                  SET @n_CurrBatchQty = 0      
                 GOTO CloseBatch      
               END      
               ELSE      
               BEGIN      
                  --close current batch and process this order again in next batch      
                  SET @n_CurrBatchQty = 0      
                  GOTO CloseBatch      
               END      
            END      
            ELSE      
            BEGIN      
              SET @n_CurrBatchQty = @n_CurrBatchQty + @n_CurrOrdQty      
            END      
         END      
      
         UPDATE #BatchResultTable      
         SET Status = '9'      
      
         INSERT INTO #BatchResultTable (BatchNo, OrderKey, Loc, Score)      
         SELECT      
            CAST(@n_BatchNo AS NVARCHAR),      
            OrderKey,      
            Loc,      
            Score      
         FROM #OrderTable O      
         WHERE OrderKey = @c_OrderKey      
      
         DELETE FROM #OrderTable      
         WHERE OrderKey = @c_OrderKey      
      
         --NJOW02      
         DELETE FROM #OrderAvgScore      
         WHERE Orderkey = @c_Orderkey      
      
         IF @c_Mode = '9' AND @c_OrdBatchM9LocNotSplitBth = '1' --NJOW09      
         BEGIN      
            SET @c_NextLoc = ''      
            SET @n_NextLocOrdCnt = 0      
                  
            /*      
            SELECT TOP 1      
                   @c_NextLoc = MIN(O.Loc)      
            FROM #OrderTable O      
            JOIN LOC L (NOLOCK) ON O.Loc = L.Loc      
            GROUP BY O.Orderkey      
            ORDER BY MIN(L.LogicalLocation), MIN(O.Loc), O.OrderKey*/      
                  
            --NJOW13 S                     
            SET @c_SQL = N'SELECT TOP 1      
                      @c_NextLoc = MIN(LOC.Loc)      
               FROM #OrderTable O       
               JOIN ORDERS (NOLOCK) ON O.Orderkey = ORDERS.Orderkey      
               JOIN LOC (NOLOCK) ON O.Loc = LOC.Loc      
               GROUP BY ORDERS.Orderkey ' +      
               CASE WHEN @c_IsCustomOrdSort = 'Y' THEN      
                  ' ORDER BY ' + @c_OrderSorting       
               ELSE          
                  ' ORDER BY MIN(LOC.LogicalLocation), MIN(LOC.Loc), ORDERS.OrderKey'      
               END         
                  
            EXEC sp_executesql @c_SQL      
                ,  N'@c_NextLoc NVARCHAR(10) OUTPUT'      
                ,  @c_NextLoc OUTPUT                     
            --NJOW13 E          
                                                     
            IF @c_Currloc <> @c_NextLoc      
            BEGIN      
               SELECT @n_NextLocOrdCnt = COUNT(1)      
               FROM  #OrderTable      
               WHERE Loc = @c_NextLoc      
            END      
         END      
      
         SET @n_Counter = @n_Counter + 1      
      
         SELECT @n_Count = COUNT(1)      
         FROM #OrderTable      
      
         IF (@n_Counter > @n_OrderCount      
            OR (@c_Mode = '9' AND  @c_OrdBatchM9LocNotSplitBth = '1' AND (@n_Counter - 1) + @n_NextLocOrdCnt > @n_OrderCount AND @c_Currloc <> @c_NextLoc)) --NJOW09 if next loc ord cnt can't fit curr batch create new batch      
            AND @n_OrderCount > 0  --NJOW11      
            --AND NOT (@c_Mode = '9' AND @c_CurrLoc = @c_NextLoc AND @c_CurrLocType NOT IN('PICK','CASE') AND @c_OrdBatchM9LocNotSplitBth = '1')  --NJOW09      
         BEGIN      
            --NJOW11      
            CloseBatch:      
      
            print 'close group'      
            IF @b_debug = 1      
            BEGIN      
               SELECT 'DONE BatchNo: ' + CAST(@n_BatchNo AS NVARCHAR)      
               SELECT * FROM #BatchResultTable      
            END      
      
            SET @n_BatchNo = @n_BatchNo + 1      
            SET @n_Counter = 1      
      
            -- (Chee01)      
            IF @b_Found = 0      
               SET @b_Found = 1      
      
            IF @@TRANCOUNT = 0      
               BEGIN TRAN;      
      
            -- tlting01      
            SET @c_Pickdetailkey = ''      
            SET @c_BatchNo = ''      
            DECLARE Orders_Pickdet_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
                  SELECT PD.Pickdetailkey, R.BatchNo      
               FROM PickDetail PD with (NOLOCK)      
               JOIN #TMP_PICKLOC PL ON(PD.PickDetailKey = PL.PickDetailKey)            --(Wan01)      
               JOIN #BatchResultTable R ON PD.OrderKey = R.OrderKey AND PL.Loc = R.Loc --(Wan01)      
      
      
              OPEN Orders_Pickdet_cur      
              FETCH NEXT FROM Orders_Pickdet_cur INTO @c_Pickdetailkey, @c_BatchNo      
              WHILE @@FETCH_STATUS = 0      
              BEGIN      
                UPDATE PickDetail WITH (ROWLOCK)      
                SET Notes = CASE WHEN @c_Mode IN('4','5') THEN      
                               --@c_LoadKey + '--' + RIGHT('000' + @c_BatchNo, 3) + '-' + @c_Mode   --NJOW04          --(Wan01)      
                               @c_Sourcekey + '--' + RIGHT('000' + @c_BatchNo, 3) + '-' + @c_Mode + @c_replenishrequire --(Wan01)  --CS01      
                            ELSE      
                               --@c_LoadKey + '-' + @c_PickZone + '-' + RIGHT('000' + @c_BatchNo, 3) + '-' + @c_Mode   -- (Chee03, Chee04)      
                               @c_Sourcekey + '-' + @c_PickZone + '-' + RIGHT('000' + @c_BatchNo, 3) + '-' + @c_Mode  + @c_replenishrequire --(Wan01) --CS01      
                            END      
                  , TrafficCop = NULL      
                  , PickSlipNo = @c_BatchCode  --NJOW04      
                  , [Status]   = CASE WHEN @c_updatepick = 'Y' AND [Status] < '3' THEN '3' ELSE [Status] END  --(Wan03)       --(ws01)  
                  , EditWho    = SUSER_SNAME()      
                  , EditDate   = GETDATE()      
                    WHERE PICKDETAIL.Pickdetailkey = @c_Pickdetailkey      
      
                SELECT @n_err = @@ERROR      
      
                IF @n_err <> 0      
                BEGIN      
                  CLOSE Orders_Pickdet_cur      
                  DEALLOCATE Orders_Pickdet_cur      
                   SELECT @n_Continue = 3      
                   SELECT @n_Err = 63505      
                   SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Failed to Update PickDetail. (ispOrderBatching)'      
                   GOTO Quit      
                END      
      
                   FETCH NEXT FROM Orders_Pickdet_cur INTO @c_Pickdetailkey, @c_BatchNo      
              END      
              CLOSE Orders_Pickdet_cur      
              DEALLOCATE Orders_Pickdet_cur      
      
              --NJOW04 Start      
              -- tlting01      
            SET @n_RowRef = 0      
            DECLARE PackTask_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
                  SELECT PT.RowRef      
               FROM PACKTASK PT with (NOLOCK)      
               JOIN #BatchResultTable R ON PT.OrderKey = R.OrderKey      
      
              OPEN PackTask_cur      
           FETCH NEXT FROM PackTask_cur INTO @n_RowRef      
              WHILE @@FETCH_STATUS = 0      
              BEGIN      
                 UPDATE PACKTASK WITH (ROWLOCK)      
                 SET TaskBatchNo = @c_BatchCode,      
                     OrderMode = @c_OrderMode,      
                     EditDate   = GETDATE(),      
                     DevicePosition = '', --NJOW07      
                     ReplenishmentGroup = '' --NJOW07      
                 WHERE RowRef = @n_RowRef      
                 SELECT @n_err = @@ERROR      
                 IF @n_err <> 0      
                 BEGIN      
                    CLOSE PackTask_cur      
                  DEALLOCATE PackTask_cur      
                    SELECT @n_Continue = 3      
                    SELECT @n_Err = 63506      
                    SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Failed to Update PackTask. (ispOrderBatching)'      
                    GOTO Quit      
                 END      
                 FETCH NEXT FROM PackTask_cur INTO @n_RowRef      
              END      
              CLOSE PackTask_cur      
              DEALLOCATE PackTask_cur      
              -- tlting01 end      
      
            INSERT INTO PACKTASK (Orderkey, TaskBatchNo, OrderMode)      
            SELECT BT.Orderkey, @c_BatchCode, @c_OrderMode      
            FROM #BatchResultTable BT      
            LEFT JOIN PACKTASK PT (NOLOCK) ON BT.Orderkey = PT.Orderkey      
            WHERE ISNULL(PT.Orderkey,'') = ''      
            GROUP BY BT.Orderkey      
            ORDER BY BT.Orderkey      
      
            IF @@ERROR <> 0      
            BEGIN      
               SELECT @n_Continue = 3      
               SELECT @n_Err = 63507      
               SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Failed to Insert PackTask. (ispOrderBatching)'      
               GOTO Quit      
            END      
      
            IF @n_Count > 0      
            BEGIN      
               EXECUTE nspg_getkey      
               'ORDBATCHNO'      
               , 9      
               , @c_BatchCode   OUTPUT      
               , @b_Success OUTPUT      
               , @n_Err     OUTPUT      
               , @c_ErrMsg  OUTPUT      
      
               SET @c_BatchCode = 'B' + @c_BatchCode      
            END      
            --NJOW04 End      
      
            WHILE @@TRANCOUNT > 0      
               COMMIT TRAN;      
      
            TRUNCATE TABLE #BatchResultTable  -- Performance Tune Truncate Instead of Delete      
         END  --@n_Counter > @n_OrderCount      
      END --(@n_Count > 0)      
      
      IF EXISTS(SELECT 1 FROM #BatchResultTable)      
      BEGIN      
         -- (Chee01)      
         IF @b_Found = 0      
            SET @b_Found = 1      
      
         -- tlting01      
         IF @@TRANCOUNT = 0      
            BEGIN TRAN;      
      
         -- tlting01      
         SET @c_Pickdetailkey = ''      
         SET @c_BatchNo = ''      
         DECLARE Orders_Pickdet_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
              SELECT PD.Pickdetailkey, R.BatchNo      
            FROM PickDetail PD with (NOLOCK)      
            JOIN #TMP_PICKLOC PL ON(PD.PickDetailKey = PL.PickDetailKey)            --(Wan01)      
            JOIN #BatchResultTable R ON PD.OrderKey = R.OrderKey AND PL.Loc = R.Loc --(Wan01)      
      
          OPEN Orders_Pickdet_cur      
      
          FETCH NEXT FROM Orders_Pickdet_cur INTO @c_Pickdetailkey, @c_BatchNo      
          WHILE @@FETCH_STATUS = 0      
          BEGIN      
             UPDATE PickDetail WITH (ROWLOCK)      
             SET Notes = CASE WHEN @c_Mode IN('4','5') THEN      
                            --@c_LoadKey + '--' + RIGHT('000' + @c_BatchNo, 3) + '-' + @c_Mode   --NJOW04      
                            @c_SourceKey + '--' + RIGHT('000' + @c_BatchNo, 3) + '-' + @c_Mode + @c_replenishrequire   --Wan01   --CS01      
                         ELSE      
                            --@c_LoadKey + '-' + @c_PickZone + '-' + RIGHT('000' + @c_BatchNo, 3) + '-' + @c_Mode   -- (Chee03, Chee04)      
                            @c_SourceKey + '-' + @c_PickZone + '-' + RIGHT('000' + @c_BatchNo, 3) + '-' + @c_Mode  + @c_replenishrequire --(Wan01)--(CS01)      
                         END      
               , TrafficCop = NULL      
               , PickSlipNo = @c_BatchCode  --NJOW04      
               , [Status]   = CASE WHEN @c_updatepick = 'Y' AND [Status] < '3' THEN '3' ELSE [Status] END  --(Wan03)    --(ws01)    
               , EditWho    = SUSER_SNAME()      
               , EditDate   = GETDATE()      
               WHERE PICKDETAIL.Pickdetailkey = @c_Pickdetailkey      
      
             SELECT @n_err = @@ERROR      
      
             IF @n_err <> 0      
             BEGIN      
                 CLOSE Orders_Pickdet_cur      
                 DEALLOCATE Orders_Pickdet_cur      
                SELECT @n_Continue = 3      
                SELECT @n_Err = 63508      
                SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Failed to Update PickDetail. (ispOrderBatching)'      
                GOTO Quit      
             END      
      
               FETCH NEXT FROM Orders_Pickdet_cur INTO @c_Pickdetailkey, @c_BatchNo      
          END      
          CLOSE Orders_Pickdet_cur      
          DEALLOCATE Orders_Pickdet_cur      
      
      
         --NJOW04 Start      
         -- tlting01      
         SET @n_RowRef = 0      
         DECLARE PackTask_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
              SELECT PT.RowRef      
            FROM PACKTASK PT with (NOLOCK)      
            JOIN #BatchResultTable R ON PT.OrderKey = R.OrderKey      
      
          OPEN PackTask_cur      
      
          FETCH NEXT FROM PackTask_cur INTO @n_RowRef      
      
          WHILE @@FETCH_STATUS = 0      
          BEGIN      
             UPDATE PACKTASK WITH (ROWLOCK)      
             SET TaskBatchNo = @c_BatchCode,      
                 OrderMode = @c_OrderMode,      
                 EditDate   = GETDATE(),      
                 DevicePosition = '', --NJOW07      
                 ReplenishmentGroup = '' --NJOW07      
             WHERE RowRef = @n_RowRef      
      
             SELECT @n_err = @@ERROR      
      
             IF @n_err <> 0      
             BEGIN      
                 CLOSE PackTask_cur      
                DEALLOCATE PackTask_cur      
                SELECT @n_Continue = 3      
                SELECT @n_Err = 63509      
                SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Failed to Update PackTask. (ispOrderBatching)'      
                GOTO Quit      
             END      
      
               FETCH NEXT FROM PackTask_cur INTO @n_RowRef      
          END      
          CLOSE PackTask_cur      
          DEALLOCATE PackTask_cur      
          -- tlting 01 end      
      
         INSERT INTO PACKTASK (Orderkey, TaskBatchNo, OrderMode)      
         SELECT BT.Orderkey, @c_BatchCode, @c_OrderMode      
         FROM #BatchResultTable BT      
         LEFT JOIN PACKTASK PT (NOLOCK) ON BT.Orderkey = PT.Orderkey      
         WHERE ISNULL(PT.Orderkey,'') = ''      
         GROUP BY BT.Orderkey      
         ORDER BY BT.Orderkey      
      
         IF @@ERROR <> 0      
         BEGIN      
            SELECT @n_Continue = 3      
            SELECT @n_Err = 63510      
            SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Failed to Insert PackTask. (ispOrderBatching)'      
            GOTO Quit      
         END      
         --NJOW04 End      
      
         WHILE @@TRANCOUNT > 0      
            COMMIT TRAN;      
      
         TRUNCATE TABLE #BatchResultTable  -- Performance Tune Truncate Instead of Delete      
      END      
      
      FETCH NEXT FROM C_PICKZONE INTO @c_PickZone      
   END      
   CLOSE C_PICKZONE      
   DEALLOCATE C_PICKZONE      
      
 -- Show Error when no result found (Chee01)      
   IF @b_Found = 0      
      AND @c_CallSource NOT IN('RPT','RPTREGEN') --NJOW04   
   BEGIN      
      SELECT @n_Continue = 3      
      SELECT @n_Err = 63511      
      SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': No result within PickZone/LoadPlan. (ispOrderBatching)'      
      GOTO Quit      
   END      
      
      
Quit:      
   SET @c_PickZones = @c_ZoneList                  --(Wan01) RETURN ZoneList to PickZone      
   WHILE @@TRANCOUNT < @n_StartTCnt      
      BEGIN TRAN;      
      
   IF @n_Continue=3  -- Error Occured - Process And Return      
   BEGIN      
      SELECT @b_Success = 0      
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt      
      BEGIN      
         ROLLBACK TRAN      
      END      
      ELSE      
      BEGIN      
         WHILE @@TRANCOUNT > @n_StartTCnt      
         BEGIN      
            COMMIT TRAN      
         END      
      END      
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispOrderBatching'      
        --RAISERROR @n_Err @c_ErrMsg      
        RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012      
      RETURN      
   END      
   ELSE      
   BEGIN      
      SELECT @b_Success = 1      
      WHILE @@TRANCOUNT > @n_StartTCnt      
      BEGIN      
         COMMIT TRAN      
      END      
      RETURN      
   END      
END -- Procedure   
GO