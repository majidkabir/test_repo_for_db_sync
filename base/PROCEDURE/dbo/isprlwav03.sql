SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/**************************************************************************/      
/* Stored Procedure: ispRLWAV03                                           */      
/* Creation Date: 15-Jun-2015                                             */      
/* Copyright: LF                                                          */      
/* Written by:                                                            */      
/*                                                                        */      
/* Purpose: SOS#342639 - CN/HK Under Armour (UA) - Rel Wave Replenishment */      
/*                                                                        */      
/* Called By: wave                                                        */      
/*                                                                        */      
/* PVCS Version: 1.0                                                      */      
/*                                                                        */      
/* Version: 5.4                                                           */      
/*                                                                        */      
/* Data Modifications:                                                    */      
/*                                                                        */      
/* Updates:                                                               */      
/* Date         Author   Ver  Purposes                                    */      
/* 19/08/2015   NJOW01   1.0  Add error checking at generate pickslip     */      
/* 20/08/2015   ChewKP01 1.1  Change DYPPICK Replen UOM > EA (ChewKP01)   */      
/* 01/09/2015   NJOW02   1.2  342639.Include find DPP location from       */      
/*                            skuconfig                                   */      
/* 10/10/2016   TLTING01 1.3  Performance tune                            */      
/* 11/10/2016   SHONG         Performance Tuning                          */      
/* 11/11/2016   ChewKP   1.5  Release with Error (ChewKP02)               */      
/* 12/11/2016   YTWan    1.6  Add TraceInfo (Wan01)                       */      
/* 13/11/2016   TLTING02 1.7  Blocking tune                               */      
/* 30/12/2016   Leong    1.8  IN00231782 - Additional PickHeader check.   */      
/* 09/01/2017   Leong    1.9  IN00237859 - Bug fix on delete replen.      */      
/* 16/08/2017   NJOW03   2.0  WMS-1995 Use pack.casecnt instead of lot10  */      
/*                            if AllocateGetCasecntFrLottable is turned   */      
/*                            off                                         */      
/* 29/09/2017   SPChin   2.1  IN00480760 - Bug Fixed                      */      
/* 27/10/2017   NJOW04   2.2  WMS-3290 - Add optional logic to send conso */      
/*                            carton to temporary sorting loc             */      
/* 02/02/2018   NJOW05   2.3  WMS-3290 Stamp lottable11 to refno for all  */      
/* 28/06/2018   NJOW06   2.4  WMS-5511 Change replenish stock sorting     */      
/* 27/09/2018   NJOW07   2.5  Fix always last error issue                 */      
/* 10/10/2018   NJOW08   2.6  Fix call nsp_ChangePickDetailByStorer and   */      
/*                            isp_ReplSwapInv after released to prevent   */      
/*                            time gap issue that might cuase the stock   */      
/*                            waiting to swap allocated by other wave     */      
/* 07/11/2018   NJOW09   2.7  Fix to allow cn continue replenish next loc */      
/*                            if can't find sufficent stock from bulk     */      
/* 09/11/2018    SWT01   2.8  Performance Tuning                          */      
/* 11/11/2018   NJOW10   2.9  D11 fix commit                              */      
/* 17/07/2019   NJOW11   3.0  WMS-9678 KR change find DPP logic and       */      
/*                            generate replen logic                       */      
/* 03/06/2020   CheeMun  3.1  INC1158387-group by codelkup udf01,udf02    */      
/* 13/08/2020   CHONGCS  3.2  WMS-14640 - add transmitlog3 trigger (CS01) */      
/* 14/09/2020   CHONGCS  3.3  WMS-14640 -add insert packtask trigger(CS02)*/      
/* 25/09/2020   CSCHONG  3.4  WMS-14640 - revised logic (CS03)            */      
/* 10/02/2022   LZG      3.5  JSM-50571 - Fixed transaction count error   */
/*                            when calling from SCE (ZG01)                */
/* 27/07/2023   NJOW12   3.6  WMS-23524 KR new logic to handle some orders*/ 
/* 27/07/2023   NJOW12   3.6  DEVOPS Combine Script                       */
/**************************************************************************/      
      
CREATE   PROCEDURE [dbo].[ispRLWAV03]      
  @c_wavekey      NVARCHAR(10)      
 ,@b_Success      int        OUTPUT      
 ,@n_err          int        OUTPUT      
 ,@c_errmsg       NVARCHAR(250)  OUTPUT      
 AS      
 BEGIN      
    SET NOCOUNT ON      
    SET QUOTED_IDENTIFIER OFF      
    SET ANSI_NULLS OFF      
    SET CONCAT_NULL_YIELDS_NULL OFF      
      
    DECLARE @n_continue int,      
            @n_starttcnt int, -- Holds the current transaction count      
            @n_debug int,      
            @n_cnt int ,      
            @n_currtrancnt INT,      
            @n_RecLine     int   --CS04      
      
    SELECT @n_debug = 0      
    IF @b_Success = 99      
    BEGIN      
       SET @n_debug = 1      
    END      
      
    SELECT @n_StartTCnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg='',@n_cnt=0      
      
    DECLARE @c_StorerKey                    NVARCHAR(15)      
           ,@c_Sku                          NVARCHAR(20)      
           ,@c_UOM                          NVARCHAR(10)      
           ,@c_Loc                          NVARCHAR(10)      
           ,@c_ToLoc                        NVARCHAR(10)      
           ,@c_ID                           NVARCHAR(18)      
           ,@c_Putawayzone                  NVARCHAR(10)      
           ,@c_Facility                     NVARCHAR(5)      
           ,@n_Qty                          INT      
           ,@n_UOMQty                       INT      
           ,@n_CaseCnt                      INT      
           ,@c_Lot                          NVARCHAR(10)      
           ,@c_Lottable01                   NVARCHAR(18) --Quality      
           ,@c_Lottable02                   NVARCHAR(18) --Inventory Category (ECOM & Non-ECOM)      
           ,@c_Lottable03                   NVARCHAR(18) --PO      
           ,@c_Lottable06                   NVARCHAR(30) --AFS (Reserved Segment)      
           ,@c_Lottable07                   NVARCHAR(30) --FIT (KIT)      
           ,@c_Lottable08                   NVARCHAR(30) --Country of Origin (COO)      
           ,@c_Lottable09                   NVARCHAR(30) --UA Status (QI, UN, BL)      
           ,@c_Lottable10                   NVARCHAR(30) --Carton Qty of each UCC      
           ,@c_Lottable11                   NVARCHAR(30) --CICO carton Ref No for multi sku      
           ,@c_PrevStorerkey                NVARCHAR(15)      
           ,@c_ReplenFullCaseToTMPLoc       NVARCHAR(10)      
           ,@c_ReplenishmentKey             NVARCHAR(10)      
           ,@c_Packkey                      NVARCHAR(10)      
           ,@c_PackUOM                      NVARCHAR(10)      
           ,@c_Remark                       NVARCHAR(255)      
           ,@c_CallSource                   NVARCHAR(30)      
           ,@c_NextDynPickLoc               NVARCHAR(10)      
           ,@c_Priority                     NVARCHAR(5)      
           ,@c_RefNo                        NVARCHAR(20)      
           ,@c_Pickdetailkey                NVARCHAR(10)      
           --,@c_NewPickdetailkey             NVARCHAR(10)      
           ,@c_LocationType                 NVARCHAR(10)      
           ,@c_ReplenNo                     NVARCHAR(10)      
           ,@c_Long                         NVARCHAR(250)  --Allocate priority      
           ,@c_Notes                        NVARCHAR(2000) --Lottable filtering delimited by comma. e.g. lottable07,lottable08      
           ,@c_Notes2                       NVARCHAR(250)  --0=not allow swap lot  1=allow swap lot      
           ,@c_PrevNotes                    NVARCHAR(2000)      
           ,@c_SQL                          NVARCHAR(4000)      
           ,@c_SQL2                         NVARCHAR(4000)      
           ,@c_SQLParam                     NVARCHAR(1000)      
           ,@c_ParameterName                NVARCHAR(30)      
           ,@c_Condition                    NVARCHAR(4000)      
           ,@n_QtyExpected                  INT      
           ,@n_QtyAvailable                 INT      
           ,@n_CaseAvailable                INT      
           ,@n_CaseRequire                  INT      
           ,@n_DPPQty                       INT      
           ,@n_PendingReplenQty             INT      
           ,@n_QtyReplenFrom                INT      
           ,@c_OrderKey                     NVARCHAR(10)      
           ,@c_Pickslipno                   NVARCHAR(10)      
           ,@c_Type                         NVARCHAR(10)      
           ,@c_PrevType                     NVARCHAR(10)      
           ,@c_UDF01                        NVARCHAR(60)      
           ,@c_UDF02                        NVARCHAR(60)      
           ,@c_NoMixLottableList            NVARCHAR(500)      
           ,@c_GenRefNo                     NVARCHAR(10)      
           ,@n_RowID                        BIGINT      
           ,@n_QtyBal                       INT      
           ,@n_CtnBal                       INT      
           ,@c_AllocateGetCasecntFrLottable NVARCHAR(10) --NJOW03      
           ,@c_Userdefine01_PTL             NVARCHAR(20) --NJOW04      
           ,@n_OrderCnt                     INT --NJOW04      
           ,@c_Option1                      NVARCHAR(50) --NJOW04      
           ,@c_Country                      NVARCHAR(30) --NJOW05      
           ,@c_AutoReplenSwapLot            NVARCHAR(10) --NJOW08      
           ,@c_SWLotOption1                 NVARCHAR(30) --NJOW08      
           ,@c_LotOrg                       NVARCHAR(10) --NJOW08      
           ,@n_QtyExpectedByOther           INT          --NJOW08      
           ,@c_logmsg                       NVARCHAR(2000) --NJOW08      
           ,@c_doctype                      NCHAR(1) --NJOW11      
           ,@c_trmlogkey                    NVARCHAR(10)    --CS01       
           ,@c_tablename                    NVARCHAR(30)    --CS01      
           ,@c_key01                        NVARCHAR(10)    --CS01        
           ,@c_key02                        NVARCHAR(30)    --CS01                    
           ,@c_key03                        NVARCHAR(20)    --CS01        
           ,@c_OHUDF03                      NVARCHAR(30)    --CS02      
           ,@c_Consigneekey                 NVARCHAR(45)    --CS02      
           ,@n_PQTY                         INT             --CS02      
           ,@n_seqno                        INT             --CS02       
           ,@c_GetOrderKey                  NVARCHAR(10)    --CS02                
           ,@c_GetStorerKey                 NVARCHAR(15)    --CS02       
           ,@n_PrePQTY                      INT             --CS02      
           ,@n_cntrec                       INT             --CS02      
           ,@c_getconsigneekey              NVARCHAR(45)    --CS02      
           ,@n_maxseqno                     int             --CS02       
           --,@n_TotalPickQty                 INT          --NJOW08      
      
   --(Wan01) - START      
   DECLARE @d_Trace_StartTime  DATETIME,      
           @d_Trace_EndTime    DATETIME,      
           @d_Trace_Step1      DATETIME,      
           @c_Trace_Step1      NVARCHAR(20),      
           @c_Step1_Time       NVARCHAR(20),      
           @d_Trace_Step2      DATETIME,      
           @c_Trace_Step2      NVARCHAR(20),      
           @c_Step2_Time       NVARCHAR(20),      
           @d_Trace_Step3      DATETIME,      
           @c_Trace_Step3      NVARCHAR(20),      
           @c_Step3_Time       NVARCHAR(20),      
           @c_UserName         NVARCHAR(20)      
      
   SET @d_Trace_StartTime = GETDATE()      
   SET @c_Trace_Step1 = ''      
   SET @c_Step1_Time  = ''      
   SET @c_Trace_Step2 = ''      
   SET @c_Step2_Time  = ''      
   SET @c_Trace_Step3 = ''      
   SET @c_Step3_Time  = ''      
   --(Wan01) - END      
      
   -----Wave Validation-----      
   IF @n_continue=1 or @n_continue=2      
   BEGIN      
      IF ISNULL(@c_wavekey,'') = ''      
      BEGIN      
         SELECT @n_continue = 3      
         SELECT @n_err = 81000      
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid Parameters Passed (ispRLWAV03)'      
      END      
   END      
     
   IF (@n_continue=1 or @n_continue=2) AND @n_debug = 0      
   BEGIN      
      IF EXISTS (SELECT 1      
                 FROM  REPLENISHMENT WITH (NOLOCK)      
                 WHERE Wavekey = @c_WaveKey      
                 AND Confirmed <> 'N')      
      BEGIN      
         SELECT @n_continue = 3      
         SELECT @n_err = 81010      
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Replenishment Has Been Started. Re-Generate Replenishment Is Not Allowed.(ispRLWAV03)'      
      END      
   END      
     
   IF @n_continue = 1 OR @n_continue = 2      
   BEGIN      
       IF EXISTS (SELECT 1      
                  FROM WAVEDETAIL WD(NOLOCK)      
                  JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey      
                  WHERE O.Status > '2'      
                  AND WD.Wavekey = @c_Wavekey)      
       BEGIN      
          SELECT @n_continue = 3      
          SELECT @n_err = 81020      
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Release Replenishment is not allowed. Some orders of this Wave are started picking (ispRLWAV03)'      
       END      
   END      
     
   IF @n_continue = 1 OR @n_continue = 2      
   BEGIN      
      IF EXISTS (SELECT 1      
                FROM WAVEDETAIL WD(NOLOCK)      
                JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey      
                WHERE O.Status = '0'      
                AND WD.Wavekey = @c_Wavekey)      
      BEGIN      
         SELECT @n_continue = 3      
         SELECT @n_err = 81025      
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Release Replenishment is not allowed. Some orders of this Wave are not allocated (ispRLWAV03)'      
      END      
   END      
     
   -- Commit Everything 1      
   SET @n_currtrancnt = @@TRANCOUNT      
   WHILE @n_currtrancnt > 0 
   BEGIN      
      COMMIT TRAN      
      SET @n_currtrancnt = @n_currtrancnt - 1      
   END      
     
   --WHILE @@TRANCOUNT > 0      
     --COMMIT TRAN      
     
   -----Initialization-----      
   IF @n_continue = 1 OR @n_continue = 2      
   BEGIN      
     -- SWT01 Start      
      --Remove qtyreplen for pending replenishment      
      --UPDATE LOTxLOCxID WITH (ROWLOCK)      
      --SET LOTxLOCxID.QtyReplen = LOTxLOCxID.QtyReplen - CASE WHEN LOTxLOCxID.QtyReplen > 0 THEN RP.Qty ELSE 0 END,      
      --    LOTxLOCxID.TrafficCop = NULL      
      --FROM (SELECT Storerkey, Sku, Lot, FromLoc, ID, SUM(QTY) AS Qty      
      --      FROM REPLENISHMENT (NOLOCK)      
      --      WHERE Wavekey = @c_Wavekey      
      --      AND Confirmed = 'N'      
      --      AND OriginalFromLoc = 'ispRLWAV03'      
      --      AND ReplenNo NOT IN('FCP','FCS') --full case replen no overallocaton, so no replenqty control --NJOW04      
      --      GROUP BY Storerkey, Sku, Lot, FromLoc, ID) AS RP      
      --JOIN LOTxLOCxID ON RP.Storerkey = LOTxLOCxID.Storerkey AND RP.Sku = LOTxLOCxID.Sku AND      
      --                   RP.Lot = LOTxLOCxID.Lot AND RP.FromLoc = LOTxLOCxID.Loc AND RP.Id = LOTxLOCxID.Id      
     
      DECLARE CUR_PENDING_REPLENISHMENT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
         SELECT Storerkey, Sku, Lot, FromLoc, ID, SUM(QTY) AS Qty      
         FROM REPLENISHMENT (NOLOCK)      
         WHERE Wavekey = @c_Wavekey      
         AND Confirmed = 'N'      
         AND OriginalFromLoc = 'ispRLWAV03'      
         AND ReplenNo NOT IN('FCP','FCS') --full case replen no overallocaton, so no replenqty control --NJOW04      
         GROUP BY Storerkey, Sku, Lot, FromLoc, ID      
     
      OPEN CUR_PENDING_REPLENISHMENT      
      FETCH NEXT FROM CUR_PENDING_REPLENISHMENT INTO @c_StorerKey, @c_Sku, @c_Lot, @c_Loc, @c_ID, @n_Qty      
            
      WHILE @@FETCH_STATUS = 0      
      BEGIN      
         BEGIN TRAN      
         
         UPDATE LOTxLOCxID WITH (ROWLOCK)      
                 SET LOTxLOCxID.QtyReplen = LOTxLOCxID.QtyReplen - CASE WHEN LOTxLOCxID.QtyReplen > 0 THEN @n_Qty ELSE 0 END,      
                     LOTxLOCxID.TrafficCop = NULL,      
                     EditWho = SUSER_SNAME(),      
                     EditDate = GETDATE()      
         WHERE Lot = @c_Lot      
         AND Loc = @c_Loc      
         AND ID = @c_ID      
     
         SELECT @n_err = @@ERROR      
         IF @n_err <> 0      
         BEGIN      
             SELECT @n_continue = 3      
             SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81030      
             SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update LOTxLOCxID Failed. (ispRLWAV03)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '      
             GOTO RETURN_SP      
         END      
         ELSE      
           COMMIT TRAN      
     
         FETCH NEXT FROM CUR_PENDING_REPLENISHMENT INTO @c_StorerKey, @c_Sku, @c_Lot, @c_Loc, @c_ID, @n_Qty      
      END      
      CLOSE CUR_PENDING_REPLENISHMENT      
      DEALLOCATE CUR_PENDING_REPLENISHMENT      
      -- SWT01 End      
      
      SET @n_currtrancnt = @@TRANCOUNT      
      WHILE @n_currtrancnt > @n_StartTCnt   -- ZG01     
      BEGIN      
         COMMIT TRAN      
         SET @n_currtrancnt = @n_currtrancnt - 1      
      END      
     
      --WHILE @@TRANCOUNT > 0      
         --COMMIT TRAN      
      
      BEGIN      
         --remove pending replenishment      
         -- TLTING02      
         SET @c_ReplenishmentKey = ''      
         DECLARE RepLine_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
         SELECT ReplenishmentKey      
         FROM Replenishment WITH (NOLOCK)      
         WHERE Wavekey = @c_WaveKey      
         AND Confirmed = 'N'      
         AND OriginalFromLoc = 'ispRLWAV03'      
      
         OPEN RepLine_cur      
         FETCH NEXT FROM RepLine_cur INTO @c_ReplenishmentKey      
         WHILE @@FETCH_STATUS = 0      
         BEGIN      
            BEGIN TRAN      
      
            DELETE Replenishment      
            WHERE ReplenishmentKey = @c_ReplenishmentKey -- IN00237859      
            SELECT @n_err = @@ERROR      
            IF @n_err <> 0      
            BEGIN      
               SELECT @n_continue = 3      
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81030      
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update LOTxLOCxID Failed. (ispRLWAV03)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '      
               GOTO RETURN_SP      
            END      
            ELSE      
              COMMIT TRAN      
      
            FETCH NEXT FROM RepLine_cur INTO @c_ReplenishmentKey      
         END      
         CLOSE RepLine_cur      
         DEALLOCATE RepLine_cur      
         SET @c_ReplenishmentKey = ''      
      END      
     
      --NJOW05      
      SELECT @c_Country = NSQLValue      
      FROM NSQLCONFIG(NOLOCK)      
      WHERE ConfigKey = 'COUNTRY'      
      
      --tlting01      
      SELECT TOP 1 @c_Storerkey = ORDERS.Storerkey,      
                   @c_Facility = ORDERS.Facility,      
                   @c_Userdefine01_PTL = W.wavetype, --NJOW04      
                   @c_DocType = ORDERS.DocType --NJOW11      
      FROM ORDERS(NOLOCK)      
      JOIN dbo.WAVEDETAIL WD WITH (NOLOCK) ON WD.OrderKey = ORDERS.OrderKey      
      JOIN dbo.WAVE W WITH (NOLOCK) ON WD.Wavekey = W.Wavekey --NJOW04      
      WHERE W.WaveKey = @c_Wavekey      
      
      SELECT TOP 1 @c_NoMixLottableList = NOTES      
      FROM CODELKUP (NOLOCK)      
      WHERE Storerkey = @c_StorerKey           AND Listname = 'LOCNOMIX'      
      AND Code = 'DYNPPICK'      
      
      IF ISNULL(@c_NoMixLottableList,'') = ''      
         SET @c_NoMixLottableList = 'LOTTABLE01, LOTTABLE06, LOTTABLE07, LOTTABLE08, LOTTABLE09'      
      
      SELECT @c_AllocateGetCasecntFrLottable = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'AllocateGetCasecntFrLottable')  --NJOW03      
      
      IF @n_debug = 1      
      BEGIN      
         PRINT '@c_AllocateGetCasecntFrLottable=' +RTRIM(@c_AllocateGetCasecntFrLottable)      
      END      
      
      --NJOW08      
      EXEC nspGetRight      
         @c_Facility  = NULL,      
         @c_StorerKey = @c_StorerKey,      
         @c_sku       = NULL,      
         @c_ConfigKey = 'AutoReplenSwapLot',      
         @b_Success   = @b_Success                  OUTPUT,      
         @c_authority = @c_AutoReplenSwapLot      OUTPUT,      
         @n_err       = @n_err                      OUTPUT,      
         @c_errmsg    = @c_errmsg                   OUTPUT,      
         @c_Option1   = @c_SWLotOption1             OUTPUT      
    END      
      
    --Create Temporary Tables      
    IF (@n_continue = 1 OR @n_continue = 2)      
    BEGIN      
       --Current wave assigned dynamic pick location      
       CREATE TABLE #DYNPICK_LOCASSIGNED (RowId BIGINT Identity(1,1) PRIMARY KEY, STORERKEY NVARCHAR(15) NULL      
                                          ,SKU NVARCHAR(20) NULL      
                                          ,TOLOC NVARCHAR(10) NULL      
                                          ,LOCATIONTYPE NVARCHAR(10) NULL      
                                          ,LOT NVARCHAR(10) NULL)      
       CREATE INDEX IDX_ASS1 ON #DYNPICK_LOCASSIGNED (TOLOC)      
       CREATE INDEX IDX_ASS2 ON #DYNPICK_LOCASSIGNED (STORERKEY,SKU,LOCATIONTYPE)      
      
       CREATE TABLE #DYNPICK_TASK (RowId BIGINT Identity(1,1) PRIMARY KEY, TOLOC NVARCHAR(10) NULL)      
      
       CREATE TABLE #DYNPICK_NON_EMPTY (RowId BIGINT Identity(1,1) PRIMARY KEY, LOC NVARCHAR(10) NULL)      
       CREATE INDEX IDX_EMPTY ON #DYNPICK_NON_EMPTY (LOC)      
      
       CREATE TABLE #BULK_STOCK (RowId BIGINT Identity(1,1) PRIMARY KEY      
                                ,STORERKEY NVARCHAR(15) NULL      
                                ,SKU NVARCHAR(20) NULL      
                                ,LOT NVARCHAR(10) NULL      
                                ,LOC NVARCHAR(10) NULL      
                                ,ID  NVARCHAR(18) NULL      
                                ,Qty INT NULL      
                                ,LooseCaseQty INT NULL      
                                ,Casecnt INT NULL      
                                ,Lottable02 NVARCHAR(10) NULL      
                                ,Lottable10 NVARCHAR(10) NULL      
                                ,Seq NVARCHAR(5) NULL) --NJOW08      
      
       CREATE TABLE #COMBINE_CARTON (RowId BIGINT Identity(1,1) PRIMARY KEY, LOC NVARCHAR(10) NULL      
                                    ,Casecnt INT NULL      
                                    ,CaseAvailable INT NULL      
                                    ,UsedFlag NVARCHAR(1) NULL)      
      
       --NJOW02      
       CREATE TABLE #SKUCONFIG_DPP (RowId BIGINT Identity(1,1) PRIMARY KEY, LOC NVARCHAR(10) NULL)      
       CREATE INDEX IDX_SKUCONFIG ON #SKUCONFIG_DPP (LOC)      
    END      
      
    -----Generate Temporary Ref Data-----      
    IF (@n_continue = 1 OR @n_continue = 2)      
    BEGIN      
        --Dynamic pick loc have qty and pending move in      
        INSERT INTO #DYNPICK_NON_EMPTY (LOC)      
        SELECT LLI.LOC      
        FROM   LOTxLOCxID LLI (NOLOCK)      
        JOIN   LOC L (NOLOCK) ON LLI.LOC = L.LOC      
        WHERE  L.LocationType = 'DYNPPICK'      
        AND    L.Facility = @c_Facility      
        GROUP BY LLI.LOC      
        HAVING SUM((LLI.Qty + LLI.PendingMoveIN + LLI.QtyExpected) - LLI.QtyPicked ) > 0      
      
        --location have pending Replenishment tasks      
        INSERT INTO #DYNPICK_TASK (TOLOC)      
        SELECT RP.TOLOC      
        FROM   REPLENISHMENT RP (NOLOCK)      
        JOIN   LOC L (NOLOCK) ON  RP.TOLOC = L.LOC      
        WHERE  L.LocationType = 'DYNPPICK'      
        AND    RP.Confirmed = 'N'      
        AND    RP.OriginalFromLoc = 'ispRLWAV03'      
        AND    L.Facility = @c_Facility      
        GROUP BY RP.TOLOC      
        HAVING SUM(RP.Qty) > 0      
      
        --DPP location setup at skuconfig NJOW02      
        INSERT INTO #SKUCONFIG_DPP      
        SELECT DISTINCT LOC.Loc      
        FROM SKUCONFIG SC (NOLOCK)      
        JOIN LOC (NOLOCK) ON SC.Data = LOC.Loc      
        WHERE SC.Storerkey = @c_Storerkey      
        AND SC.Configtype = 'DefaultDPP'      
        AND LOC.Facility = @c_Facility      
    END      
      
    SET @n_currtrancnt = @@TRANCOUNT      
    WHILE @n_currtrancnt > @n_StartTCnt     -- ZG01     
    BEGIN      
       COMMIT TRAN      
       SET @n_currtrancnt = @n_currtrancnt - 1      
    END      
      
    --WHILE @@TRANCOUNT > 0      
       --COMMIT TRAN      
      
    -----Generate Pickslip-----      
    IF (@n_continue = 1 OR @n_continue = 2)      
    BEGIN      
       SET @c_Trace_Step1 = 'Gen.PickSlip'      --(Wan01)      
       SET @d_Trace_Step1  = GETDATE()          --(Wan01)      
      
       DECLARE CUR_WaveOrder CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
           SELECT DISTINCT ORDERS.OrderKey      
           FROM WAVEDETAIL WITH (NOLOCK)      
           JOIN ORDERS WITH (NOLOCK) ON  (WAVEDETAIL.OrderKey = ORDERS.OrderKey)      
           WHERE WAVEDETAIL.WaveKey = @c_WaveKey      
           AND ORDERS.Status <> '9'      
      
       OPEN CUR_WaveOrder      
      
       FETCH NEXT FROM CUR_WaveOrder INTO @c_OrderKey      
      
       WHILE @@FETCH_STATUS <> -1 AND (@n_continue = 1 OR @n_continue = 2)      
       BEGIN      
          SELECT @c_Pickslipno = ''      
          
          SELECT @c_Pickslipno = Pickheaderkey      
          FROM   PICKHEADER WITH (NOLOCK)      
          WHERE  Orderkey = @c_Orderkey      
          
          IF ISNULL(@c_PickslipNo ,'') = ''      
          BEGIN      
             BEGIN TRAN      
          
             SELECT @b_success = 0      
             EXECUTE nspg_getkey      
             'PICKSLIP'      
             , 9      
             , @c_PickSlipNo OUTPUT      
             , @b_success OUTPUT      
             , @n_err OUTPUT      
             , @c_errmsg OUTPUT      
          
             IF @b_success = 1      
             BEGIN      
                SELECT @c_PickSlipNo = 'P' + RTRIM(@c_PickSlipNo)      
                COMMIT TRAN      
             END      
             ELSE      
             BEGIN      
                 SELECT @n_continue = 3      
                 SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81033      
                 SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Get Pickslip# Failed. (ispRLWAV03)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '      
                 GOTO RETURN_SP      
                 --BREAK      
             END      
          
             BEGIN TRAN      
          
             INSERT PickHeader      
               (Pickheaderkey,Wavekey,Orderkey,zone,picktype)      
             VALUES      
               (@c_PickSlipNo,@c_Wavekey,@c_Orderkey,'3','0')      
          
             SELECT @n_err = @@ERROR      
             IF @n_err <> 0      
             BEGIN      
                 SELECT @n_continue = 3      
                 SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81035      
                 SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PickHeader Failed. (ispRLWAV03)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '      
                 GOTO RETURN_SP      
             END      
             ELSE      
               COMMIT TRAN            
          END -- ISNULL(@c_PickslipNo ,'') = ''      
          
          FETCH NEXT FROM CUR_WaveOrder INTO @c_OrderKey      
       END -- while  cursor      
       CLOSE CUR_WaveOrder      
       DEALLOCATE CUR_WaveOrder      
      
       IF EXISTS(SELECT 1 FROM WAVEDETAIL WD WITH (NOLOCK)      
                 LEFT JOIN PICKHEADER PH WITH (NOLOCK) ON WD.Orderkey = PH.Orderkey      
                 WHERE ISNULL(PH.Pickheaderkey,'') = ''      
                 AND WD.Wavekey = @c_Wavekey)      
       BEGIN      
          SELECT @n_continue = 3      
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81037      
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Found pickslip missing for the wave. (ispRLWAV03)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '      
          GOTO RETURN_SP      
       END      
      
       /*CS01 START*/      
       
       IF @c_Country IN('KR','KOR')       
       BEGIN                         
          SET @c_tablename = ''      
          SET @c_key01 = ''      
          SET @c_key02 = ''      
          SET @c_key03 = ''      
          
          SELECT DISTINCT @c_tablename= 'WVERCMLOG',      
                          @c_key01 = ORDERS.userdefine09,      
                          @c_key02 = WV.wavetype,      
                          @c_key03 = ORDERS.Storerkey      
                 --  @c_OHUDF03 = ORDERS.userdefine03,             --CS02      
                        --  @c_GetOrderkey = ORDERS.Orderkey                --CS02      
                         -- @c_GetStorerKey = ORDERS.StorerKey            --CS02      
          FROM WAVE WV WITH (NOLOCK)       
          JOIN WAVEDETAIL WITH (NOLOCK) ON WAVEDETAIL.Wavekey = WV.Wavekey      
          JOIN ORDERS WITH (NOLOCK) ON  (WAVEDETAIL.OrderKey = ORDERS.OrderKey)      
          WHERE WAVEDETAIL.WaveKey = @c_WaveKey      
            
          SELECT @n_Continue = 1, @b_success = 1      
           
          --EXEC dbo.ispGenTransmitLog3 @c_tablename, @c_key01, @c_key02, @c_key03, ''          
          --   , @b_success OUTPUT          
          --   , @n_err OUTPUT          
          --   , @c_errmsg OUTPUT          
          IF NOT EXISTS ( SELECT 1 FROM TransmitLog3 (NOLOCK) WHERE TableName = @c_TableName        
                            AND Key1 = @c_Key01 AND Key2 = @c_Key02 AND Key3 = @c_Key03)        
          BEGIN                      
             BEGIN TRAN      
             SELECT @b_success = 0      
             EXECUTE nspg_getkey        
               -- Change by June 15.Jun.2004        
               -- To standardize name use in generating transmitlog3..transmitlogkey        
               -- 'Transmitlog3Key'        
               'TransmitlogKey3'        
               , 10       
               , @c_trmlogkey OUTPUT        
               , @b_success   OUTPUT        
               , @n_err       OUTPUT        
               , @c_errmsg    OUTPUT        
                 
               --IF @b_success = 0        
               --SELECT @n_continue = 3, @n_err = 60098, @c_errmsg = 'isp_RCM_LP_KewillFlagship: ' + rtrim(@c_errmsg)        
               -- print @c_trmlogkey + ' @c_trmlogkey'         
            
             IF @b_success = 1      
             BEGIN      
                --SELECT @c_trmlogkey = 'P' + RTRIM(@c_PickSlipNo)      
                COMMIT TRAN      
             END      
             ELSE      
             BEGIN      
                SELECT @n_continue = 3      
                SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81033      
                SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Get transmitlogkey Failed. (ispRLWAV03)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '      
                GOTO RETURN_SP      
                --BREAK      
             END      
            
             --CS02    START      
             SET @n_seqno = 1      
                        
             --IF @c_key02 in ( 'PTL','DAS')   --CS03      
             BEGIN      
                BEGIN TRAN       
                IF NOT EXISTS (SELECT 1 FROM PackTask WITH (NOLOCK) WHERE Orderkey = @c_GetOrderkey AND TaskBatchNo = @c_wavekey)        
                BEGIN      
                     --IF  @c_OHUDF03 = 'NC'      
                     --BEGIN      
                         SET @n_seqno = 1      
                              
                         INSERT INTO PackTask ( DevicePosition,  TaskBatchNo,  Orderkey)       
                         SELECT  @n_seqno, @c_Wavekey,OH.Orderkey      
                         FROM ORDERS OH WITH (NOLOCK)      
                         WHERE OH.userdefine09 =  @c_Wavekey      
                         AND OH.userdefine03 = 'NC'       
                         ORDER BY OH.Orderkey      
                     --END      
                     --ELSE IF  @c_OHUDF03 = 'SC'      
                     --BEGIN      
                         SET @n_seqno = 2      
                              
                         INSERT INTO PackTask ( DevicePosition,  TaskBatchNo,  Orderkey)       
                         SELECT  @n_seqno, @c_Wavekey,OH.Orderkey      
                         FROM ORDERS OH WITH (NOLOCK)      
                         WHERE OH.userdefine09 =  @c_Wavekey      
                         AND OH.userdefine03 = 'SC'       
                         ORDER BY OH.Orderkey          
                     --END      
                     --ELSE      
                     --BEGIN      
                       SET @n_seqno = 3      
                       SET @n_PrePQTY = 0      
             
                       DECLARE C_ChkSeq CURSOR LOCAL FAST_FORWARD READ_ONLY FOR        
                       SELECT distinct OH.consigneekey, sum(PD.qty)      
                       FROM orders OH WITH (NOLOCK)       
                       JOIN pickdetail PD WITH (NOLOCK) on OH.orderkey = PD.orderkey and OH.storerkey = PD.storerkey      
                       WHERE OH.userdefine09 =  @c_Wavekey      
                       --AND OH.StorerKey = @c_GetStorerKey      
                       AND OH.userdefine03 NOT IN ('NC','SC') AND OH.Doctype = 'N'      
                       group by OH.consigneekey      
                       order by sum(PD.qty) desc      
             
                       OPEN C_ChkSeq         
                       FETCH NEXT FROM C_ChkSeq INTO @c_consigneekey,@n_pqty      
             
                       WHILE @@FETCH_STATUS=0            
                       BEGIN       
                          SET @n_cntrec = 0      
                          SELECT @n_cntrec = COUNT(OH.consigneekey)      
                          FROM orders OH WITH (NOLOCK)      
                          WHERE OH.userdefine09 = @c_Wavekey      
                          AND OH.consigneekey = @c_consigneekey      
             
                          IF @n_cntrec >1      
                          BEGIN      
                             SET @n_RecLine = 1   --CS04      
                  
                             DECLARE C_ChkOHSeq CURSOR LOCAL FAST_FORWARD READ_ONLY FOR        
                             SELECT distinct OH.consigneekey, oh.orderkey      
                             FROM orders OH WITH (NOLOCK)       
                             JOIN pickdetail PD WITH (NOLOCK) on OH.orderkey = PD.orderkey and OH.storerkey = PD.storerkey      
                             WHERE OH.userdefine09 =  @c_Wavekey      
                             AND OH.consigneekey = @c_consigneekey      
                             AND OH.userdefine03 NOT IN ('NC','SC') AND OH.Doctype = 'N'      
             
                             OPEN C_ChkOHSeq         
                             FETCH NEXT FROM C_ChkOHSeq INTO @c_getconsigneekey,@c_getorderkey      
             
                             WHILE @@FETCH_STATUS=0            
                             BEGIN        
                                /*CS04 START*/      
                                  SET @n_maxseqno = 0                 --CS04      
                                  SELECT TOP 1 @n_maxseqno = cast(deviceposition as int)      
                                  FROM  PackTask WITH (NOLOCK)      
                                  where TaskBatchNo =  @c_Wavekey      
                                  order by rowref desc       
                                
                                IF @n_RecLine = 1      
                                BEGIN      
                                     IF @n_maxseqno < @n_seqno      
                                     BEGIN      
                                      SET @n_seqno = @n_seqno       
                                     END      
                                     ELSE IF @n_maxseqno = @n_seqno      
                                     BEGIN      
                                       SET @n_seqno = @n_seqno  +1      
                                     END        
                                END       
                                /*CS04 END*/      
                                INSERT INTO PackTask ( DevicePosition,  TaskBatchNo,  Orderkey)       
                                VALUES ( CAST(@n_seqno as NVARCHAR(5)),  @c_Wavekey,  @c_GetOrderKey)        
                                
                                SET @n_RecLine = @n_RecLine + 1  --CS04      
                                             
                                FETCH NEXT FROM C_ChkOHSeq INTO @c_getconsigneekey,@c_getorderkey      
                             END                              
                             CLOSE C_ChkOHSeq        
                             DEALLOCATE C_ChkOHSeq       
             
                             --SET  @n_seqno = @n_seqno + 1    --CS04      
                          END       
                          ELSE      
                          BEGIN       
                             -- SET  @n_seqno = @n_seqno + 1       
                             SET @n_maxseqno = 0                 --CS04      
                             SELECT TOP 1 @n_maxseqno = cast(deviceposition as int)      
                             FROM  PackTask WITH (NOLOCK)      
                             where TaskBatchNo =  @c_Wavekey      
                             order by rowref desc       
                             
                             
                             IF @n_maxseqno < @n_seqno      
                             BEGIN      
                              SET @n_seqno = @n_seqno       
                             END      
                             ELSE IF @n_maxseqno = @n_seqno      
                             BEGIN      
                               SET @n_seqno = @n_seqno  +1      
                             END        
             
                             INSERT INTO PackTask ( DevicePosition,  TaskBatchNo,  Orderkey)       
                             --VALUES ( CAST(@n_seqno as NVARCHAR(5)),  @c_Wavekey,  @c_GetOrderKey)        
                             SELECT  @n_seqno, @c_Wavekey,OH.Orderkey      
                             FROM ORDERS OH WITH (NOLOCK)      
                             WHERE OH.userdefine09 =  @c_Wavekey      
                             AND OH.consigneekey = @c_consigneekey      
                             ORDER BY OH.Orderkey              
                          END       
              
                          FETCH NEXT FROM C_ChkSeq INTO @c_consigneekey,@n_pqty      
                       END                  
             
                       CLOSE C_ChkSeq        
                       DEALLOCATE C_ChkSeq                                     
                   --  END       
             
                      SELECT @n_err = @@ERROR      
                   --print '@n_err : ' + cast(@n_err as nvarchar(5))      
                   
                   IF @n_err <> 0      
                   BEGIN      
                     SELECT @n_continue = 3      
                     SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81054      
                     SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PackTask Failed. (ispRLWAV03)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '      
                     --  ROLLBACK TRAN                  
                     GOTO RETURN_SP      
                   END      
                   ELSE          
                      COMMIT TRAN                                 
                END      
                          
                --CS02 END      
                IF @c_key02 in ( 'PTL','DAS')      
                BEGIN      
                   BEGIN TRAN      
                
                   INSERT INTO Transmitlog3 (transmitlogkey, tablename, key1, key2, key3, transmitflag, TransmitBatch)        
                   VALUES (@c_trmlogkey, @c_TableName, @c_Key01, ISNULL(@c_Key02,''), @c_Key03, '0', '')        
                         
                   SELECT @n_err = @@ERROR      
                   --print '@n_err : ' + cast(@n_err as nvarchar(5))      
                   
                   IF @n_err <> 0      
                   BEGIN      
                      SELECT @n_continue = 3      
                      SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81053      
                      SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Transmitlog3 Failed. (ispRLWAV03)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '      
                      --  ROLLBACK TRAN      
                   
                      GOTO RETURN_SP      
                   END        
                   ELSE          
                      COMMIT TRAN      
                END --@c_key02 in ( 'PTL','DAS')             
             END --begin
          END  --TransmitLog3      
       END --CS03  @c_Country IN('KR','KOR')      
              /*CS01 END*/      
            
       SET @c_Step1_Time  = CONVERT (NVARCHAR(12), GETDATE() -  @d_Trace_Step1,114)    --(Wan01)      
    END      
         
    ------if userdefine04 = 'PTL' conslidate pickdetail to identify conso carton --NJOW04      
    /*IF (@n_continue = 1 OR @n_continue = 2) AND @c_Userdefine01_PTL = 'PTL'      
    BEGIN      
       EXEC isp_ConsolidatePickdetail      
            @c_Loadkey        = ''      
           ,@c_Wavekey        = @c_Wavekey      
           ,@c_UOM            = '2'  --UOM to Consolidate 1=Pallet  2=Carton      
           ,@c_GroupFieldList = 'ORDERS.Orderkey'  --field to determine the full pallet/carton is single order/consignee. e.g. ORDERS.Consigneekey,ORDERS.Userdefine03      
           ,@c_SQLCondition   = 'SKUXLOC.LocationType NOT IN (''CASE'',''PICK'') AND LOC.Locationtype NOT IN(''DYNPPICK'',''RPLTMP'',''PICK'',''CASE'')' --Additional condition to filter e.g. LOC.LocationType = 'BULK' AND LOC.LocationHandling = '1'      
           ,@b_Success        = @b_Success OUTPUT      
           ,@n_Err            = @n_Err     OUTPUT      
           ,@c_ErrMsg         = @c_ErrMsg  OUTPUT      
      
        IF @b_success <> '1'      
           SET @n_continue = 3      
    END*/      
      
    -----Generate Full Carton Replenishment and Assign DPP location to loose carton pickdetail-----      
    IF @n_continue = 1 OR @n_continue = 2      
    BEGIN      
       IF @n_debug = 1      
           PRINT '---Full Carton Replen & Assign DPP to Pickdetail------'      
      
       SET @c_Trace_Step2  = 'FullCartonReplen'          --(Wan01)      
       SET @d_Trace_Step2  = GETDATE()                   --(Wan01)      
      
       BEGIN TRAN      
      
       IF @c_Userdefine01_PTL in ('PTL','DAS') --NJOW04      
       BEGIN            
          IF @c_Userdefine01_PTL = 'DAS'      
          BEGIN            
             UPDATE LOADPLAN SET LOADPICKMETHOD = 'C' WHERE LOADKEY IN (      
             SELECT LOADKEY FROM ORDERS(NOLOCK) WHERE USERDEFINE09 = @c_Wavekey)  --CJ            
          END      
      
          DECLARE CUR_PICK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
             SELECT PD.Storerkey, PD.Sku, PD.Uom, PD.Loc, SKU.Putawayzone, SUM(PD.Qty),      
                    SKU.Packkey, PACK.PackUOM3, PD.Lot, PD.ID, SUM(PD.UOMQty), O.Facility,      
                    LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable06, LA.Lottable07,      
                    LA.Lottable08, LA.Lottable09, LA.Lottable10, LA.Lottable11,      
                    CASE WHEN PD.UOM = '2' AND @c_AllocateGetCasecntFrLottable = '10' THEN      
                           CASE WHEN PD.Qty % CAST(LA.Lottable10 AS INT) = 0 THEN PD.Pickdetailkey ELSE '' END      
                         WHEN PD.UOM = '2' AND @c_AllocateGetCasecntFrLottable <> '10' THEN      
                           CASE WHEN PD.Qty % CAST(PACK.Casecnt AS INT) = 0 THEN PD.Pickdetailkey ELSE '' END      
                    ELSE PD.Pickdetailkey END,      
                    LOC.LocationType,       
                    MAX(O.type),  --INC1158387       
                    CL.Long,      
                    PACK.CaseCnt, --NJOW03      
                 COUNT(DISTINCT O.Orderkey),       
                   ISNULL(CLK.UDF01,''), ISNULL(CLK.UDF02,'') --INC1158387         
             FROM WAVE W (NOLOCK)      
             JOIN WAVEDETAIL WD (NOLOCK) ON W.Wavekey = WD.Wavekey      
             JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey      
             JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey = PD.Orderkey      
             JOIN LOTxLOCxID LLI (NOLOCK) ON PD.Storerkey = LLI.Storerkey AND PD.Sku = LLI.Sku AND PD.Lot = LLI.Lot AND PD.Loc = LLI.Loc AND PD.Id = LLI.Id      
             JOIN LOTATTRIBUTE LA (NOLOCK) ON PD.Lot = LA.Lot      
             JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc      
             JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku      
             JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey      
             LEFT JOIN CODELKUP CL (NOLOCK) ON CL.Listname = 'REPLSWAP' AND LA.Lottable02 = CL.Short AND LLI.Storerkey = CL.Storerkey      
             OUTER APPLY (SELECT TOP 1 CL.UDF01, CL.UDF02 FROM CODELKUP CL(NOLOCK) WHERE CL.Listname = 'UASOTYPE' AND CL.Short = O.Type) AS CLK  --INC1158387      
             WHERE W.Wavekey = @c_Wavekey      
             --AND (LOC.Locationtype NOT IN('DYNPPICK','DYNPICKR','PICK','CASE')      
             --    OR (LOC.Locationtype = 'DYNPICKR' AND LII.QtyExpected > 0))      
             AND LOC.Locationtype NOT IN('DYNPPICK','RPLTMP','PICK','CASE')      
             AND NOT (O.Userdefine01 = 'RESERVE' AND O.Userdefine03 = 'PTO' AND @c_Country IN('KR','KOR')) --NJOW12                
             GROUP BY PD.Storerkey, PD.Sku, PD.Uom, PD.Loc, SKU.Putawayzone,      
                      SKU.Packkey, PACK.PackUOM3, PD.Lot, PD.ID, O.Facility,      
                      LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable06, LA.Lottable07,      
                      LA.Lottable08, LA.Lottable09, LA.Lottable10, LA.Lottable11,      
                      LOC.LocationType, CL.Long,      
                    PACK.CaseCnt,       
                      --O.Type,  --INC1158387      
                      CASE WHEN PD.UOM = '2' AND @c_AllocateGetCasecntFrLottable = '10' THEN      
                             CASE WHEN PD.Qty % CAST(LA.Lottable10 AS INT) = 0 THEN PD.Pickdetailkey ELSE '' END      
                           WHEN PD.UOM = '2' AND @c_AllocateGetCasecntFrLottable <> '10' THEN      
                             CASE WHEN PD.Qty % CAST(PACK.Casecnt AS INT) = 0 THEN PD.Pickdetailkey ELSE '' END      
                      ELSE PD.Pickdetailkey END,      
                      LOC.LocationGroup, LOC.LocLevel, LOC.LogicalLocation, --NJOW06      
                      ISNULL(CLK.UDF01,''), ISNULL(CLK.UDF02,'')  --INC1158387      
             ORDER BY PD.Storerkey,       
                      --O.Type,  --INC1158387      
                      PD.UOM,      
                      LOC.LocationGroup, LOC.LocLevel, LOC.LogicalLocation, PD.Loc --NJOW06      
          END      
       ELSE      
       BEGIN      
          DECLARE CUR_PICK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
             SELECT PD.Storerkey, PD.Sku, PD.Uom, PD.Loc, SKU.Putawayzone, PD.Qty,      
                    SKU.Packkey, PACK.PackUOM3, PD.Lot, PD.ID, PD.UOMQty, O.Facility,      
                    LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable06, LA.Lottable07,      
                    LA.Lottable08, LA.Lottable09, LA.Lottable10, LA.Lottable11, PD.Pickdetailkey,      
                    LOC.LocationType, O.type, CL.Long,      
                    PACK.CaseCnt, --NJOW03      
                    1 AS OrderCnt, --NJOW04      
                    ISNULL(CLK.UDF01,''), ISNULL(CLK.UDF02,'') --Fix       
             FROM WAVE W (NOLOCK)      
             JOIN WAVEDETAIL WD (NOLOCK) ON W.Wavekey = WD.Wavekey      
             JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey      
             JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey = PD.Orderkey      
             JOIN LOTxLOCxID LLI (NOLOCK) ON PD.Storerkey = LLI.Storerkey AND PD.Sku = LLI.Sku AND PD.Lot = LLI.Lot AND PD.Loc = LLI.Loc AND PD.Id = LLI.Id      
             JOIN LOTATTRIBUTE LA (NOLOCK) ON PD.Lot = LA.Lot      
             JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc      
             JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku      
             JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey      
             LEFT JOIN CODELKUP CL (NOLOCK) ON CL.Listname = 'REPLSWAP' AND LA.Lottable02 = CL.Short AND LLI.Storerkey = CL.Storerkey      
             OUTER APPLY (SELECT TOP 1 CL.UDF01, CL.UDF02 FROM CODELKUP CL(NOLOCK) WHERE CL.Listname = 'UASOTYPE' AND CL.Short = O.Type) AS CLK  --INC1158387                      
             WHERE W.Wavekey = @c_Wavekey      
             --AND (LOC.Locationtype NOT IN('DYNPPICK','DYNPICKR','PICK','CASE')      
             --    OR (LOC.Locationtype = 'DYNPICKR' AND LII.QtyExpected > 0))      
             AND LOC.Locationtype NOT IN('DYNPPICK','RPLTMP','PICK','CASE')      
             AND NOT (O.Userdefine01 = 'RESERVE' AND O.Userdefine03 = 'PTO' AND @c_Country IN('KR','KOR')) --NJOW12                             
             ORDER BY PD.Storerkey, O.Type, WD.Orderkey, PD.UOM,      
                      LOC.LocationGroup, LOC.LocLevel, LOC.LogicalLocation, PD.Loc --NJOW06      
       END      
      
       OPEN CUR_PICK      
      
       FETCH NEXT FROM CUR_PICK INTO @c_StorerKey, @c_Sku, @c_UOM, @c_Loc, @c_Putawayzone, @n_Qty, @c_Packkey, @c_PackUOM,      
                                     @c_Lot, @c_ID, @n_UOMQty, @c_Facility, @c_Lottable01, @c_Lottable02, @c_Lottable03, @c_Lottable06,      
                                     @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11,      
                                     @c_Pickdetailkey, @c_LocationType, @c_Type, @c_Long, @n_CaseCnt, @n_OrderCnt, --NJOW03 NJOW04      
                                     @c_UDF01, @C_UDF02 --INC1158387      
       SET @c_PrevStorerkey = ''      
       SET @c_PrevType = ''      
       WHILE @@FETCH_STATUS <> -1      
       BEGIN      
          SET @c_Remark = ''      
          SET @c_ToLoc = ''      
          SET @c_CallSource = ''      
          --SET @n_Casecnt = 0 --NJOW03      
          SET @c_Priority = '5'      
          SET @c_RefNo = ''      
          SET @c_ReplenNo = ''      
      
          IF @c_AllocateGetCasecntFrLottable IN ('01','02','03','06','07','08','09','10','11','12') --NJOW03      
          BEGIN      
             IF ISNUMERIC(@c_Lottable10) <> 1 OR ISNULL(@c_Lottable01,'') IN ('0','')      
             BEGIN      
                SELECT @n_continue = 3      
                SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81040      
                SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Found Lot With Invalid Lottable10 Value. (ispRLWAV03)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '      
                GOTO RETURN_SP      
             END      
             ELSE      
             BEGIN      
                SELECT @n_Casecnt = CAST(@c_Lottable10 AS INT)      
             END      
          END      
          ELSE      
          BEGIN      
             --NJOW03      
             IF @n_CaseCnt = 0      
             BEGIN      
                SELECT @n_continue = 3      
                SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81045      
                SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Found Sku with Zero Pack Casecnt. (ispRLWAV03)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '      
                GOTO RETURN_SP      
             END      
          END      
      
          IF ISNULL(@c_Long,'') >= '0' AND ISNULL(@c_Long,'') <= '9'      
             SET @c_Priority = @c_Long      
      
          IF @c_PrevStorerkey <> @c_Storerkey      
          BEGIN      
              EXEC nspGetRight      
                  @c_Facility  = NULL,      
                  @c_StorerKey = @c_StorerKey,      
                  @c_sku    = NULL,      
                  @c_ConfigKey = 'ReplenFullCaseToTMPLoc',      
                  @b_Success   = @b_Success                  OUTPUT,      
                  @c_authority = @c_ReplenFullCaseToTMPLoc   OUTPUT,      
                  @n_err       = @n_err                      OUTPUT,      
                  @c_errmsg    = @c_errmsg                   OUTPUT,      
                  @c_Option1   = @c_Option1                  OUTPUT  --NJOW02      
      
             IF @n_debug = 1      
             BEGIN      
                 PRINT '@c_ReplenFullCaseToTMPLoc=' +RTRIM(@c_ReplenFullCaseToTMPLoc)      
             END      
          END      
      
          /*  --INC1158387      
          IF @c_PrevType <> @c_Type      
          BEGIN      
              SELECT @c_UDF01 = ISNULL(UDF01,''), -- CICO indicator to stamp lottable11 to replenishment.refno      
                     @c_UDF02 = ISNULL(UDF02,'') --Full carton temp loc      
              FROM CODELKUP(NOLOCK)      
              WHERE Listname = 'UASOTYPE'      
              AND Short = @c_Type      
          END      
          */      
      
          IF ISNULL(@c_UDF02,'') = ''      
             SET @c_UDF02 = 'QC01'      
      
          IF @c_UDF01 = 'CICO' OR @c_Country IN('KR','KOR') --NJOW05      
             SET @c_Refno = @c_Lottable11      
      
          IF @n_debug = 1      
          BEGIN      
              PRINT '@c_UOM='+rtrim(@c_uom) + ' @c_pickdetailkey=' +RTRIM(@c_pickdetailkey) + ' @c_type=' +RTRIM(@c_type) + ' @c_lot=' +RTRIM(@c_lot)      
              PRINT '@c_Sku='+rtrim(@c_sku) + + ' @c_loc=' + RTRIM(@c_loc) + ' @c_locationtype=' + RTRIM(@c_locationtype) + ' @c_id=' +RTRIM(@c_id)      
              PRINT '@c_Lottable02='+rtrim(@c_lottable02) + ' @c_lottable10=' + RTRIM(@c_lottable10) + ' @c_lottable11=' + RTRIM(@c_lottable11)      
              PRINT '@n_qty='+RTRIM(CAST(@n_qty AS NVARCHAR)) + ' @n_uomqty=' + RTRIM(CAST(@n_uomqty AS NVARCHAR)) + ' @n_casecnt='+RTRIM(CAST(@n_casecnt AS NVARCHAR))      
          END      
      
          ---Replenish full carton from bulk to temp location      
          IF @c_UOM = '2' AND @c_ReplenFullCaseToTMPLoc = '1'      
             AND @c_LocationType NOT IN('DYNPPICK','RPLTMP','PICK','CASE')      
             AND @n_Qty % @n_Casecnt = 0 --NJOW03      
             AND @n_OrderCnt = 1 --NJOW04      
             AND NOT (@c_Country IN('KR','KOR') AND @c_DocType = 'E')  --NJOW11      
             --AND @c_LocationType NOT IN('DYNPPICK','PICK','CASE')      
          BEGIN      
             SET @c_Remark = 'FCP'      
             SET @c_ReplenNo = 'FCP'      
             SET @c_PackUOM = 'CA'      
             SET @c_CallSource = 'FULLCASEREPLEN'      
             --SET @n_cnt = @n_UOMQty      
             SET @n_Cnt = FLOOR(@n_Qty / @n_Casecnt)  --NJOW03      
             SET @n_Qty = @n_CaseCnt      
          
             UPDATE PICKDETAIL SET REPLENISHZONE = @c_ReplenNo  --CJ      
             WHERE PICKDETAILKEY =  @c_Pickdetailkey      
          
             SELECT @c_Toloc = Loc      
             FROM LOC (NOLOCK)      
             WHERE LocationType = 'RPLTMP'      
             AND Loc = @c_UDF02      
             --WHERE LocationType = 'DYNPICKR'      
             --ORDER BY LogicalLocation, Loc      
          
             IF ISNULL(@c_ToLoc,'')=''      
             BEGIN      
                 SELECT @n_continue = 3      
                 SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81050      
                 SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Replenishment Full Carton Tempory Location Not Setup(RPLTMP). (ispRLWAV03)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '      
                 GOTO RETURN_SP      
             END      
          
          
              IF @n_debug = 1      
              BEGIN      
                PRINT '     Full carton replenish to ' + @c_toloc      
              END      
          
             --Move full carton pickdetail to temp loc      
              --SET @c_CallSource = 'MOVEPICKDETAIL_FULLCARTON'      
             --GOTO MOVE_PICKDETAIL      
             --RTN_MOVE_PICKDETAIL_FULLCARTON:      
          
              --Create replenishment record. 1 carton per line      
              WHILE @n_cnt > 0      
              BEGIN      
                 GOTO INSERT_REPLEN      
                 RTN_INSERT_REPLEN_FULLCASE:      
                 SELECT @n_cnt = @n_cnt - 1      
              END      
          END --UOM = 2      
      
          ---Replenish conso carton from bulk to temp PLT sorting location --NJOW04      
          IF @c_UOM = '2' AND @c_Userdefine01_PTL in ('PTL','DAS')      
             AND @c_LocationType NOT IN('DYNPPICK','RPLTMP','PICK','CASE')      
             AND @n_OrderCnt > 1      
             AND NOT (@c_Country IN('KR','KOR') AND @c_DocType = 'E')  --NJOW11                      
          BEGIN      
             SET @c_Remark = 'FCS'      
             SET @c_ReplenNo = 'FCS'      
             SET @c_PackUOM = 'CA'      
             SET @c_CallSource = 'CONSOCASEREPLEN'      
             --SET @n_cnt = @n_UOMQty      
             SET @n_Cnt = FLOOR(@n_Qty / @n_Casecnt)  --NJOW03      
          
             SELECT TOP 1 @c_Toloc = LOC.Loc      
             FROM CODELKUP CL (NOLOCK)      
             JOIN LOC (NOLOCK) ON CL.Code = LOC.Loc      
             WHERE CL.Listname = 'PTLSORTLOC'      
             AND CL.Storerkey = @c_Storerkey      
          
             IF ISNULL(@c_ToLoc,'')=''      
             BEGIN      
                SELECT @n_continue = 3      
                SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81051      
                SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Replenishment Conso Carton to Tempory PTL Sorting Location Not Setup(PTLSORTLOC). (ispRLWAV03)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '      
                GOTO RETURN_SP      
             END      
          
             IF @n_debug = 1      
             BEGIN      
               PRINT '     Conso carton replenish to ' + @c_toloc      
             END      
          
             IF @n_Qty % @n_Casecnt = 0 AND @n_cnt > 0      
                SET @n_Qty = @n_CaseCnt      
             ELSE      
                SET @n_Cnt = 1      
          
              --Create replenishment record. 1 carton per line      
              WHILE @n_cnt > 0      
              BEGIN      
                 GOTO INSERT_REPLEN      
                 RTN_INSERT_REPLEN_CONSOCASE:      
                 SELECT @n_cnt = @n_cnt - 1      
              END      
          END --UOM = 2      
          
          ---Move loose carton pickdetail from bulk to DPP      
          IF (@c_UOM <> '2'  OR      
             (@c_UOM = '2' AND @n_Qty % @n_Casecnt <> 0 AND @c_option1 = 'CONSOCASETODPP' AND @c_Userdefine01_PTL not in ('PTL','DAS')))  --NJOW04      
              AND @c_LocationType NOT IN('DYNPPICK','PICK','CASE','RPLTMP')      
          BEGIN      
              --find available DPP location      
              SET @c_CallSource = 'ASSIGNDPPTOPICK'      
              GOTO FIND_DPP_LOC      
              RTN_ASSIGNDPPTOPICK:      
          
              IF @n_debug = 1      
              BEGIN      
                PRINT '     Found DPP Loc ' + @c_toloc      
              END      
          
              --Move pickdetail from bulk to DPP      
              SET @c_CallSource = 'MOVEPICKDETAIL_LOOSE'      
              GOTO MOVE_PICKDETAIL      
              RTN_MOVE_PICKDETAIL_LOOSE:      
          END -- UOM <> 2      
          
          SELECT @c_PrevStorerkey = @c_Storerkey      
          --SELECT @c_PrevType = @c_Type  --INC1158387      
      
          FETCH NEXT FROM CUR_PICK INTO @c_StorerKey, @c_Sku, @c_UOM, @c_Loc, @c_Putawayzone, @n_Qty, @c_Packkey, @c_PackUOM,      
                                         @c_Lot, @c_ID, @n_UOMQty, @c_Facility, @c_Lottable01, @c_Lottable02, @c_Lottable03, @c_Lottable06,      
                                         @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11,      
                                         @c_Pickdetailkey, @c_LocationType, @c_Type, @c_Long, @n_CaseCnt, @n_OrderCnt, --NJOW03 NJOW04      
                                         @c_UDF01, @C_UDF02 --INC1158387      
       END      
       CLOSE CUR_PICK      
       DEALLOCATE CUR_PICK      
      
       IF EXISTS(SELECT 1 FROM WAVEDETAIL WD (NOLOCK)      
                 JOIN PICKDETAIL PD (NOLOCK) ON WD.Orderkey = PD.Orderkey      
                 JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc      
                 WHERE WD.Wavekey = @c_Wavekey      
                 AND PD.UOM <> '2'      
                 AND LOC.LocationType NOT IN('DYNPPICK','RPLTMP','PICK','CASE'))      
       BEGIN      
          SELECT @n_continue = 3      
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81038      
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Found loose(UOM 7) pickdetail not at DPP for the wave. (ispRLWAV03)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '      
          GOTO RETURN_SP      
      END      
      
       SET @c_Step2_Time  = CONVERT (NVARCHAR(12), GETDATE() -  @d_Trace_Step2 ,114)         --(Wan01)      
    END      
      
      
    -----Generate Loose Carton Replenishment from Bulk to DPP      
    IF @n_continue = 1 OR @n_continue = 2      
    BEGIN      
       IF @n_debug = 1      
           PRINT '---Loose Carton Replenishment from Bulk to DPP------'      
      
       SET @c_Trace_Step3  = 'LooseCTNFrBULKToDPP'                                           --(Wan01)      
       SET @d_Trace_Step3  = GETDATE()                                                       --(Wan01)      
      -- tlting01      
      SELECT TOP 1 @c_Storerkey = ORDERS.Storerkey,      
                   @c_Facility = ORDERS.Facility      
      FROM ORDERS(NOLOCK)      
      JOIN dbo.WAVEDETAIL WD WITH (NOLOCK) ON WD.OrderKey = ORDERS.OrderKey      
      WHERE WD.WaveKey = @c_Wavekey      
      
       --Get DPP Replen expected and current stock      
       SELECT LLI.Storerkey, LLI.Sku, LLI.Lot, LLI.Loc, LLI.ID, LLI.Qty,      
              LLI.QtyAllocated, LLI.QtyPicked, LLI.QtyExpected, LOC.Facility, PACK.Packkey, PACK.PackUOM3, SKU.Putawayzone,      
              LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable06, LA.Lottable07,      
              LA.Lottable08, LA.Lottable09, LA.Lottable10, CL.Long, CL.Notes, CL.Notes2,      
              PACK.CaseCnt --NJOW03      
       INTO #TMP_DPP      
       FROM LOTxLOCxID LLI (NOLOCK)      
       JOIN LOTATTRIBUTE LA (NOLOCK) ON LLI.Lot = LA.Lot      
       JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc      
       JOIN SKU (NOLOCK) ON LLI.Storerkey = SKU.Storerkey AND LLI.Sku = SKU.Sku      
       JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey      
       LEFT JOIN CODELKUP CL (NOLOCK) ON CL.Listname = 'REPLSWAP' AND LA.Lottable02 = CL.Short AND LLI.Storerkey = CL.Storerkey      
       WHERE LOC.LocationType = 'DYNPPICK'      
       AND (LLI.QtyExpected > 0 OR (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) > 0 OR (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) < 0)      
       AND LLI.Storerkey = @c_Storerkey      
       AND LOC.Facility = @c_Facility      
      
       --performance tuning             
       CREATE INDEX IDX_DPP1 ON #TMP_DPP (STORERKEY, SKU, LOC)        
       CREATE INDEX IDX_DPPLOT1 ON #TMP_DPP (Lottable01)        
       CREATE INDEX IDX_DPPLOT2 ON #TMP_DPP (Lottable02)        
       CREATE INDEX IDX_DPPLOT3 ON #TMP_DPP (Lottable03)        
       CREATE INDEX IDX_DPPLOT6 ON #TMP_DPP (Lottable06)        
       CREATE INDEX IDX_DPPLOT7 ON #TMP_DPP (Lottable07)        
       CREATE INDEX IDX_DPPLOT8 ON #TMP_DPP (Lottable08)        
       CREATE INDEX IDX_DPPLOT9 ON #TMP_DPP (Lottable09)        
       CREATE INDEX IDX_DPPLOT10 ON #TMP_DPP (Lottable10)        
             
       -- Performance Tuning      
       SELECT DISTINCT PD.Storerkey, PD.Sku, PD.Loc      
       INTO #TMP_WAVEREP      
       FROM WAVEDETAIL AS WD WITH (NOLOCK)      
       JOIN PICKDETAIL PD (NOLOCK) ON WD.Orderkey = PD.Orderkey      
       JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc      
       WHERE WD.WaveKey = @c_Wavekey      
       AND LOC.LocationType IN ('DYNPPICK')      
      
       --DPP Replenishment      
       DECLARE CUR_DPP_REPLEN CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
        SELECT DPP.Storerkey, DPP.Sku, DPP.Loc, SUM(DPP.QtyExpected) AS QtyExpected,      
                 DPP.Packkey, DPP.PackUOM3, DPP.Putawayzone, DPP.Long, DPP.Notes, DPP.Notes2,      
                 CASE WHEN DPP.Notes2 = '1' AND CHARINDEX('lottable01',DPP.Notes,1) = 0 THEN '' ELSE DPP.Lottable01 END AS Lottable01,  --NJOW08      
                 CASE WHEN DPP.Notes2 = '1' THEN '' ELSE DPP.Lottable02 END AS Lottable02,      
                 CASE WHEN DPP.Notes2 = '1' AND CHARINDEX('lottable03',DPP.Notes,1) = 0 THEN '' ELSE  DPP.Lottable03 END AS Lottable03,  --NJOW08      
                 CASE WHEN DPP.Notes2 = '1' AND CHARINDEX('lottable06',DPP.Notes,1) = 0 THEN '' ELSE  DPP.Lottable06 END AS Lottable06,  --NJOW08      
                 CASE WHEN DPP.Notes2 = '1' AND CHARINDEX('lottable07',DPP.Notes,1) = 0 THEN '' ELSE  DPP.Lottable07 END AS Lottable07,  --NJOW08      
                 CASE WHEN DPP.Notes2 = '1' AND CHARINDEX('lottable08',DPP.Notes,1) = 0 THEN '' ELSE  DPP.Lottable08 END AS Lottable08,  --NJOW08      
                 CASE WHEN DPP.Notes2 = '1' AND CHARINDEX('lottable09',DPP.Notes,1) = 0 THEN '' ELSE  DPP.Lottable09 END AS Lottable09,  --NJOW08      
                 CASE WHEN ISNULL(DPP.Notes2,'') <> '1' THEN DPP.Lot ELSE '' END AS Lot, --if REPLSWAP not setup replen inventory by lot      
                 DPP.CaseCnt --NJOW03      
                 --CASE WHEN ISNULL(DPP.Notes2,'') = '' THEN DPP.Lot ELSE '' END AS Lot --if REPLSWAP not setup replen inventory by lot      
          FROM #TMP_DPP DPP      
          JOIN #TMP_WAVEREP WRP ON DPP.Storerkey = WRP.Storerkey AND DPP.Sku = WRP.Sku AND DPP.Loc = WRP.Loc --ensure only replen sku/loc belong to current wave      
          WHERE QtyExpected > 0      
          GROUP BY DPP.Storerkey, DPP.Sku, DPP.Loc, DPP.Long, DPP.Notes, DPP.Notes2, DPP.Packkey, DPP.PackUOM3, DPP.Putawayzone,      
                   CASE WHEN DPP.Notes2 = '1' AND CHARINDEX('lottable01',DPP.Notes,1) = 0 THEN '' ELSE  DPP.Lottable01 END,  --NJOW08      
                   CASE WHEN DPP.Notes2 = '1' THEN '' ELSE DPP.Lottable02 END, --If allow swap lot can ignore lottable02      
                   CASE WHEN DPP.Notes2 = '1' AND CHARINDEX('lottable03',DPP.Notes,1) = 0 THEN '' ELSE  DPP.Lottable03 END,  --NJOW08      
                   CASE WHEN DPP.Notes2 = '1' AND CHARINDEX('lottable06',DPP.Notes,1) = 0 THEN '' ELSE  DPP.Lottable06 END,  --NJOW08      
                   CASE WHEN DPP.Notes2 = '1' AND CHARINDEX('lottable07',DPP.Notes,1) = 0 THEN '' ELSE  DPP.Lottable07 END,  --NJOW08      
                   CASE WHEN DPP.Notes2 = '1' AND CHARINDEX('lottable08',DPP.Notes,1) = 0 THEN '' ELSE  DPP.Lottable08 END,  --NJOW08      
                   CASE WHEN DPP.Notes2 = '1' AND CHARINDEX('lottable09',DPP.Notes,1) = 0 THEN '' ELSE  DPP.Lottable09 END,  --NJOW08      
                   CASE WHEN ISNULL(DPP.Notes2,'') <> '1' THEN DPP.Lot ELSE '' END,      
                   DPP.CaseCnt --NJOW03      
                   --CASE WHEN ISNULL(DPP.Notes2,'') = '' THEN DPP.Lot ELSE '' END      
          ORDER BY DPP.Notes, DPP.Notes2, DPP.Sku, DPP.Loc      
      
       OPEN CUR_DPP_REPLEN      
      
       FETCH NEXT FROM CUR_DPP_REPLEN INTO @c_StorerKey, @c_Sku, @c_ToLoc, @n_QtyExpected,      
                                           @c_Packkey, @c_PackUOM, @c_Putawayzone, @c_Long, @c_Notes, @c_Notes2,      
                                           @c_Lottable01, @c_Lottable02, @c_Lottable03, @c_Lottable06,      
                                           @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lot, @n_CaseCnt --NJOW03      
      
      SET @c_PrevNotes = ''      
      SET @c_SQLParam = ''      
      WHILE @@FETCH_STATUS <> -1  --Loop expected replen from DPP      
      BEGIN      
         SET @c_Condition = ''      
         SET @c_SQL = ''      
         SET @c_SQL2 = ''      
         SET @c_Loc = ''      
         SET @c_Id = ''      
         SET @n_Qty = 0      
         SET @c_Remark = ''      
         SET @c_ReplenNo = ''      
         SET @c_CallSource = ''      
         SET @c_RefNo = ''      
         SET @c_Priority = '5'      
         --SET @n_Casecnt = 0   --NJOW03      
         SET @n_DPPQty = 0      
         SET @n_PendingReplenQty = 0      
         SET @c_LotOrg = @c_Lot      
      
         IF ISNULL(@c_Long,'') >= '0' AND ISNULL(@c_Long,'') <= '9'      
            SET @c_Priority = @c_Long      
      
         DELETE FROM #BULK_STOCK      
         DELETE FROM #COMBINE_CARTON      
      
         --NJOW03      
         IF @c_AllocateGetCasecntFrLottable NOT IN ('01','02','03','06','07','08','09','10','11','12') AND @n_CaseCnt = 0      
         BEGIN      
            SELECT @n_continue = 3      
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81039      
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Found Sku ' + RTRIM(@c_Sku) + ' with Zero Pack Casecnt. (ispRLWAV03)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '      
            GOTO RETURN_SP      
         END      
      
         --Get lottable filtering condition from codelkup      
         --IF @c_PrevNotes <> @c_Notes      
         --BEGIN      
            SET @c_SQLParam = ''      
      
            DECLARE Cur_Parameters CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
            SELECT DISTINCT ColValue AS LottableName      
            FROM dbo.fnc_DelimSplit(',',@c_Notes)      
            WHERE ISNULL(ColValue,'') <> ''      
      
            OPEN Cur_Parameters      
            FETCH NEXT FROM Cur_Parameters INTO @c_ParameterName      
            WHILE @@FETCH_STATUS <> -1      
            BEGIN      
               SET @c_SQLParam = RTRIM(@c_SQLParam) + ' ' +      
                  CASE @c_ParameterName      
                     WHEN 'Lottable01' THEN ' AND LOTATTRIBUTE.Lottable01 = N''' + LTRIM(RTRIM(ISNULL(@c_Lottable01,''))) + ''' '      
                    --WHEN 'Lottable02' THEN ' AND LOTATTRIBUTE.Lottable02 = N''' + LTRIM(RTRIM(ISNULL(@c_Lottable02,''))) + ''' '      
                     WHEN 'Lottable03' THEN ' AND LOTATTRIBUTE.Lottable03 = N''' + LTRIM(RTRIM(ISNULL(@c_Lottable03,''))) + ''' '      
                     WHEN 'Lottable06' THEN ' AND LOTATTRIBUTE.Lottable06 = N''' + LTRIM(RTRIM(ISNULL(@c_Lottable06,''))) + ''' '      
                     WHEN 'Lottable07' THEN ' AND LOTATTRIBUTE.Lottable07 = N''' + LTRIM(RTRIM(ISNULL(@c_Lottable07,''))) + ''' '      
                     WHEN 'Lottable08' THEN ' AND LOTATTRIBUTE.Lottable08 = N''' + LTRIM(RTRIM(ISNULL(@c_Lottable08,''))) + ''' '      
                     WHEN 'Lottable09' THEN ' AND LOTATTRIBUTE.Lottable09 = N''' + LTRIM(RTRIM(ISNULL(@c_Lottable09,''))) + ''' '      
                  END      
      
               FETCH NEXT FROM Cur_Parameters INTO @c_ParameterName      
            END      
            CLOSE Cur_Parameters      
            DEALLOCATE Cur_Parameters      
         --END      
      
         IF @n_debug = 1      
         BEGIN      
            PRINT '@c_Notes='+rtrim(@c_notes) + ' @c_notes2=' +RTRIM(@c_notes2)      
            PRINT '@c_Sku='+rtrim(@c_sku) + ' @c_Toloc=' + RTRIM(@c_toloc)      
            PRINT '@c_Lottable02='+rtrim(@c_lottable02) + ' @n_Qtyexpected='+RTRIM(CAST(@n_qtyexpected AS NVARCHAR)) + ' @c_Lot='+rtrim(@c_lot)      
         PRINT '@c_SQLParam='+rtrim(@c_SQLParam)      
         END      
      
         IF ISNULL(@c_Notes2,'') = '1'  --Allow swap lot      
         BEGIN      
            -- Find available qty from DPP with similar lottable but can be different lottable02      
            SELECT @c_SQL2 = ' SELECT @n_DPPQty = ISNULL(SUM(Qty - QtyAllocated - QtyPicked),0) ' +      
                           ' FROM #TMP_DPP LOTATTRIBUTE ' +      
                           ' WHERE SKU = @c_Sku ' +      
                           ' AND LOC = @c_ToLoc ' +      
                           ' AND Qty - QtyAllocated - QtyPicked > 0 ' +      
                           @c_SQLParam      
                           --' HAVING SUM(Qty - QtyAllocated - QtyPicked) > 0 '      
      
            EXEC sp_executesql @c_SQL2,      
               N'@n_DPPQty INT OUTPUT, @c_Sku NVARCHAR(20), @c_ToLoc NVARCHAR(10)',      
               @n_DPPQty OUTPUT,      
               @c_Sku,      
               @c_ToLoc      
      
            -- Find pending replen qty to DPP with similar lottable but can be different lottable02      
            SELECT @c_SQL2 =  ' SELECT @n_PendingReplenQty = ISNULL(SUM(RP.Qty),0) ' +      
                              ' FROM REPLENISHMENT RP (NOLOCK) ' +      
                              ' JOIN LOC L (NOLOCK) ON  RP.TOLOC = L.LOC ' +      
                              ' JOIN LOTATTRIBUTE (NOLOCK) ON RP.Lot = LOTATTRIBUTE.Lot ' +      
                           ' WHERE RP.Storerkey = @c_Storerkey ' +      
                           ' AND RP.SKU = @c_Sku ' +      
                           ' AND RP.Confirmed = ''N'' '+      
                           ' AND RP.OriginalFromLoc = ''ispRLWAV03'' ' +      
                           ' AND L.LocationType = ''DYNPPICK'' ' +      
                           ' AND RP.ToLoc = @c_Toloc ' +      
                           ' AND RP.qty > 0 ' +      
              ' AND RP.Wavekey <> @c_Wavekey ' + --NJOW08      
                           @c_SQLParam      
      
            EXEC sp_executesql @c_SQL2,      
                  N'@n_PendingReplenQty INT OUTPUT, @c_Storerkey NVARCHAR(15), @c_Sku NVARCHAR(20), @c_ToLoc NVARCHAR(10), @c_Wavekey NVARCHAR(10)',      
                  @n_PendingReplenQty OUTPUT,      
                  @c_Storerkey,      
                  @c_Sku,      
                  @c_Toloc,      
                  @c_Wavekey --NJOW08      
            
            --NJOW08 S      
            --deduct qty replen reserve for other pick and remain extra qty only      
            /*      
            SET @n_TotalPickQty = 0      
            
            
            SELECT @c_SQL2 = ' SELECT @n_TotalPickQty = SUM(PD.Qty)      
                               FROM PICKDETAIL PD (NOLOCK)      
                               JOIN LOTATTRIBUTE (NOLOCK) ON PD.Lot = LOTATTRIBUTE.Lot      
            JOIN WAVEDETAIL WD (NOLOCK) ON PD.Orderkey = WD.Orderkey      
                               WHERE WD.Wavekey = @c_Wavekey      
            AND PD.Loc = @c_ToLoc      
            AND PD.Storerkey = @c_Storerkey      
                               AND PD.Sku = @C_Sku      
                               AND PD.Status <> ''9'' ' +      
                               @c_SQLParam      
            
            EXEC sp_executesql @c_SQL2,      
                N'@n_TotalPickQty INT OUTPUT, @c_Storerkey NVARCHAR(15), @c_Sku NVARCHAR(20), @c_ToLoc NVARCHAR(10), @c_Wavekey NVARCHAR(10)',      
                  @n_TotalPickQty OUTPUT,      
                  @c_Storerkey,      
                  @c_Sku,      
                  @c_Toloc,      
                  @c_Wavekey      
            
            IF ISNULL(@n_TotalPickQty,0) < @n_QtyExpected AND ISNULL(@n_TotalPickQty,0) > 0  --if total pick qty of the wave is less than expected mean expected include other wave      
            BEGIN      
               SET @n_QtyExpectedByOther = @n_QtyExpected - @n_TotalPickQty      
               IF @n_PendingReplenQty > @n_QtyExpectedByOther      
                  SET @n_PendingReplenQty = @n_PendingReplenQty - @n_QtyExpectedByOther      
               ELSE      
                  SET @n_PendingReplenQty = 0      
            END      
            */      
            SET @n_QtyExpectedByOther = 0      
            
            SELECT @c_SQL2 = ' SELECT TOP 1 @n_QtyExpectedByOther = SUM(PD.Qty) - SL.Qty      
                               FROM PICKDETAIL PD (NOLOCK)      
                               JOIN SKUXLOC SL (NOLOCK) ON PD.Storerkey = SL.Storerkey AND PD.Sku = SL.Sku AND PD.Loc = SL.Loc      
                               JOIN LOTATTRIBUTE (NOLOCK) ON PD.Lot = LOTATTRIBUTE.Lot      
                               JOIN WAVEDETAIL WD (NOLOCK) ON PD.Orderkey = WD.Orderkey      
                               WHERE WD.Wavekey <> @c_Wavekey      
                               AND PD.Loc = @c_ToLoc      
                               AND PD.Storerkey = @c_Storerkey      
                               AND PD.Sku = @C_Sku      
                               AND PD.Status <> ''9'' ' + --RTRIM(ISNULL(@c_SQLParam,'')) +      
                               ' GROUP BY SL.Qty '      
            
            EXEC sp_executesql @c_SQL2,      
                  N'@n_QtyExpectedByOther INT OUTPUT, @c_Storerkey NVARCHAR(15), @c_Sku NVARCHAR(20), @c_ToLoc NVARCHAR(10), @c_Wavekey NVARCHAR(10)',      
                  @n_QtyExpectedByOther OUTPUT,      
                  @c_Storerkey,      
                  @c_Sku,      
                  @c_Toloc,      
                  @c_Wavekey      
            
            IF ISNULL(@n_QtyExpectedByOther,0) > 0      
            BEGIN      
               IF @n_PendingReplenQty > @n_QtyExpectedByOther      
                  SET @n_PendingReplenQty = @n_PendingReplenQty - @n_QtyExpectedByOther      
               ELSE      
                  SET @n_PendingReplenQty = 0      
            END      
            --NJOW08 E      
            
            --If have available qty from DPP with different lottable02 or pending replen then no need replen      
            SET @n_QtyExpected  = @n_QtyExpected - ISNULL(@n_DPPQty,0) - ISNULL(@n_PendingReplenQty,0)      
            
            IF @n_debug = 1      
            BEGIN      
               PRINT '@n_DPPQty='+RTRIM(CAST(@n_DPPQty AS NVARCHAR)) + ' @n_PendingReplenQty='+RTRIM(CAST(@n_PendingReplenQty AS NVARCHAR))      
               PRINT '@n_QtyExpected(final)='+RTRIM(CAST(@n_QtyExpected AS NVARCHAR))      
            END      
            
            IF @n_QtyExpected <= 0      
               GOTO NEXT_DPP_REPLEN      
      
            SET @c_Condition =  RTRIM(@c_Condition) + ' AND LOTATTRIBUTE.Lottable02 IN (SELECT Short FROM CODELKUP (NOLOCK) WHERE Listname = ''REPLSWAP'' AND Storerkey = N''' + RTRIM(@c_storerkey) + ''') '      
      
             IF @c_AllocateGetCasecntFrLottable IN ('01','02','03','06','07','08','09','10','11','12') --NJOW03      
             BEGIN      
                SET @c_Condition =  RTRIM(@c_Condition) + ' ORDER BY ISNULL(CL.Long,''ZZZ''), LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable05, LOTxLOCxID.Lot, '  +      
                                  ' CASE WHEN (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) % CAST(LOTATTRIBUTE.Lottable10 AS INT) = 0 THEN 0 ELSE 1 END,  ' +      
                                  ' LOTATTRIBUTE.Lottable10, LOTxLOCxID.Qty, LOTxLOCxID.Loc '      
             END      
             ELSE      
             BEGIN      
                --NJOW06      
                IF @c_Country = 'CN'      
                BEGIN      
                   SET @c_Condition =  RTRIM(@c_Condition) + ' ORDER BY LOC.LocationGroup, LOC.LocLevel, QTYAVAILABLE, LOC.LogicalLocation, LOTxLOCxID.Loc, ' +      
                                       ' ISNULL(CL.Long,''ZZZ''), LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable05, LOTxLOCxID.Lot, '  +      
                                       ' CASE WHEN (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) % CAST(PACK.CaseCnt AS INT) = 0 THEN 0 ELSE 1 END,  ' +      
                                       ' PACK.CaseCnt, LOTxLOCxID.Qty '      
                END      
                ELSE      
                BEGIN      
                   --NJOW03      
                   SET @c_Condition =  RTRIM(@c_Condition) + ' ORDER BY ISNULL(CL.Long,''ZZZ''), LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable05, LOTxLOCxID.Lot, '  +      
                                    ' CASE WHEN (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) % CAST(PACK.CaseCnt AS INT) = 0 THEN 0 ELSE 1 END,  ' +      
                                    ' PACK.CaseCnt, LOTxLOCxID.Qty, LOTxLOCxID.Loc '      
                END      
             END      
         END --ISNULL(@c_Notes2,'') = '1'    
         ELSE IF ISNULL(@c_Notes2,'') = '0'  --Not allow swap lot      
         BEGIN      
            SELECT @c_SQL2 =  ' SELECT @n_PendingReplenQty = ISNULL(SUM(RP.Qty),0) ' +      
                                 ' FROM REPLENISHMENT RP (NOLOCK) ' +      
                                 ' JOIN LOC L (NOLOCK) ON  RP.TOLOC = L.LOC ' +      
                                 ' JOIN LOTATTRIBUTE (NOLOCK) ON RP.Lot = LOTATTRIBUTE.Lot ' +      
                              ' WHERE RP.Storerkey = @c_Storerkey ' +      
                              ' AND RP.SKU = @c_Sku ' +      
                              ' AND RP.Confirmed = ''N'' '+      
                              ' AND RP.OriginalFromLoc = ''ispRLWAV03'' ' +      
                              ' AND L.LocationType = ''DYNPPICK'' ' +      
                              ' AND RP.ToLoc = @c_Toloc ' +      
                              ' AND RP.qty > 0 ' +      
                              ' AND RP.Lot = @c_Lot '      
                              --@c_SQLParam      
      
            EXEC sp_executesql @c_SQL2,      
                  N'@n_PendingReplenQty INT OUTPUT, @c_Storerkey NVARCHAR(15), @c_Sku NVARCHAR(20), @c_ToLoc NVARCHAR(10), @c_Lot NVARCHAR(10)',      
                  @n_PendingReplenQty OUTPUT,      
                  @c_Storerkey,      
                  @c_Sku,      
                  @c_Toloc,      
                  @c_Lot      
      
            --NJOW08 S      
            --deduct qty replen reserve for other pick and remain extra qty only      
            SET @n_QtyExpectedByOther = 0      
      
            SELECT @c_SQL2 = ' SELECT @n_QtyExpectedByOther = SUM(PD.Qty - LLI.Qty)      
                               FROM PICKDETAIL PD (NOLOCK)      
                               JOIN LOTXLOCXID LLI (NOLOCK) ON PD.Storerkey = LLI.Storerkey AND PD.Sku = LLI.Sku AND PD.Lot = LLI.Lot AND PD.Loc = LLI.Loc AND PD.Id = LLI.Id      
                               JOIN LOTATTRIBUTE (NOLOCK) ON PD.Lot = LOTATTRIBUTE.Lot      
                               JOIN WAVEDETAIL WD (NOLOCK) ON PD.Orderkey = WD.Orderkey      
                               WHERE WD.Wavekey <> @c_Wavekey      
                               AND PD.Loc = @c_ToLoc      
                               AND PD.Storerkey = @c_Storerkey      
                               AND PD.Sku = @C_Sku      
                               AND PD.Status <> ''9''      
                               AND PD.Lot = @c_Lot'      
      
            EXEC sp_executesql @c_SQL2,      
                  N'@n_QtyExpectedByOther INT OUTPUT, @c_Storerkey NVARCHAR(15), @c_Sku NVARCHAR(20), @c_ToLoc NVARCHAR(10), @c_Wavekey NVARCHAR(10), @c_Lot NVARCHAR(10)',      
                  @n_QtyExpectedByOther OUTPUT,      
                  @c_Storerkey,      
                  @c_Sku,      
                  @c_Toloc,      
                  @c_Wavekey,      
                  @c_Lot      
      
            IF ISNULL(@n_QtyExpectedByOther,0) > 0      
            BEGIN      
               IF @n_PendingReplenQty > @n_QtyExpectedByOther      
                  SET @n_PendingReplenQty = @n_PendingReplenQty - @n_QtyExpectedByOther      
               ELSE      
                  SET @n_PendingReplenQty = 0      
            END      
            --NJOW08 E      
      
            --If have available qty from pending replen then no need replen      
            SET @n_QtyExpected  = @n_QtyExpected - ISNULL(@n_PendingReplenQty,0)      
      
            IF @n_debug = 1      
            BEGIN      
                  PRINT '@n_PendingReplenQty='+RTRIM(CAST(@n_PendingReplenQty AS NVARCHAR))      
              PRINT '@n_QtyExpected(final)='+RTRIM(CAST(@n_QtyExpected AS NVARCHAR))      
            END      
      
            IF @n_QtyExpected <= 0      
               GOTO NEXT_DPP_REPLEN      
      
               -- include other lottable as low priority in case combine carton of multi lot      
               IF @c_AllocateGetCasecntFrLottable IN ('01','02','03','06','07','08','09','10','11','12') --NJOW03      
               BEGIN      
                  SET @c_Condition =  RTRIM(@c_Condition) + ' ORDER BY CASE WHEN LOTATTRIBUTE.Lottable02 = '''+LTRIM(RTRIM(ISNULL(@c_Lottable02,''))) +''' THEN 0 ELSE 1 END, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable05, LOTxLOCxID.Lot, '  +      
                                    ' CASE WHEN (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) % CAST(LOTATTRIBUTE.Lottable10 AS INT) = 0 THEN 0 ELSE 1 END,  ' +      
                                    ' LOTATTRIBUTE.Lottable10, LOTxLOCxID.Qty, LOTxLOCxID.Loc '      
               END      
               ELSE      
               BEGIN      
                  --NJOW06      
                  IF @c_Country = 'CN'      
                  BEGIN      
                     SET @c_Condition =  RTRIM(@c_Condition) + ' ORDER BY LOC.LocationGroup, LOC.LocLevel, QTYAVAILABLE, LOC.LogicalLocation, LOTxLOCxID.Loc, ' +      
                                       ' CASE WHEN LOTATTRIBUTE.Lottable02 = '''+LTRIM(RTRIM(ISNULL(@c_Lottable02,''))) +''' THEN 0 ELSE 1 END, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable05, LOTxLOCxID.Lot, '  +      
                                       ' CASE WHEN (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) % CAST(PACK.CaseCnt AS INT) = 0 THEN 0 ELSE 1 END,  ' +      
                                       ' PACK.CaseCnt, LOTxLOCxID.Qty '      
                  END      
                  ELSE      
                  BEGIN      
                     --NJOW03      
                     SET @c_Condition =  RTRIM(@c_Condition) + ' ORDER BY CASE WHEN LOTATTRIBUTE.Lottable02 = '''+LTRIM(RTRIM(ISNULL(@c_Lottable02,''))) +''' THEN 0 ELSE 1 END, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable05, LOTxLOCxID.Lot, '  +      
                                       ' CASE WHEN (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) % CAST(PACK.CaseCnt AS INT) = 0 THEN 0 ELSE 1 END,  ' +      
                                       ' PACK.CaseCnt, LOTxLOCxID.Qty, LOTxLOCxID.Loc '      
                  END      
               END      
         END      
         ELSE      
         BEGIN      
            -- Find pending replen qty to DPP with similar Lot      
            SELECT @c_SQL2 =  ' SELECT @n_PendingReplenQty = ISNULL(SUM(RP.Qty),0) ' +      
                              ' FROM REPLENISHMENT RP (NOLOCK) ' +      
                              ' JOIN LOC L (NOLOCK) ON  RP.TOLOC = L.LOC ' +      
                              ' JOIN LOTATTRIBUTE (NOLOCK) ON RP.Lot = LOTATTRIBUTE.Lot ' +      
                              ' WHERE RP.Storerkey = @c_Storerkey ' +      
                              ' AND RP.SKU = @c_Sku ' +      
                              ' AND RP.Confirmed = ''N'' '+      
                              ' AND RP.OriginalFromLoc = ''ispRLWAV03'' ' +      
                              ' AND L.LocationType = ''DYNPPICK'' ' +      
                              ' AND RP.ToLoc = @c_Toloc ' +      
                              ' AND RP.qty > 0 ' +      
                              ' AND RP.Lot = @c_Lot '      
                              --@c_SQLParam      
      
           EXEC sp_executesql @c_SQL2,      
               N'@n_PendingReplenQty INT OUTPUT, @c_Storerkey NVARCHAR(15), @c_Sku NVARCHAR(20), @c_ToLoc NVARCHAR(10), @c_Lot NVARCHAR(10)',      
               @n_PendingReplenQty OUTPUT,      
               @c_Storerkey,      
               @c_Sku,      
               @c_Toloc,      
               @c_Lot      
      
            --NJOW08 S      
            --deduct qty replen reserve for other pick and remain extra qty only      
            SET @n_QtyExpectedByOther = 0      
      
            SELECT @c_SQL2 = ' SELECT @n_QtyExpectedByOther = SUM(PD.Qty - LLI.Qty)      
                               FROM PICKDETAIL PD (NOLOCK)      
                               JOIN LOTXLOCXID LLI (NOLOCK) ON PD.Storerkey = LLI.Storerkey AND PD.Sku = LLI.Sku AND PD.Lot = LLI.Lot AND PD.Loc = LLI.Loc AND PD.Id = LLI.Id      
                               JOIN LOTATTRIBUTE (NOLOCK) ON PD.Lot = LOTATTRIBUTE.Lot      
                               JOIN WAVEDETAIL WD (NOLOCK) ON PD.Orderkey = WD.Orderkey      
                               WHERE WD.Wavekey <> @c_Wavekey      
                               AND PD.Loc = @c_ToLoc      
                               AND PD.Storerkey = @c_Storerkey      
                               AND PD.Sku = @C_Sku      
                               AND PD.Status <> ''9''      
                               AND PD.Lot = @c_Lot'      
      
            EXEC sp_executesql @c_SQL2,      
                  N'@n_QtyExpectedByOther INT OUTPUT, @c_Storerkey NVARCHAR(15), @c_Sku NVARCHAR(20), @c_ToLoc NVARCHAR(10), @c_Wavekey NVARCHAR(10), @c_Lot NVARCHAR(10)',      
                  @n_QtyExpectedByOther OUTPUT,      
                  @c_Storerkey,      
                  @c_Sku,      
                  @c_Toloc,      
                  @c_Wavekey,      
                  @c_Lot      
      
            IF ISNULL(@n_QtyExpectedByOther,0) > 0      
            BEGIN      
               IF @n_PendingReplenQty > @n_QtyExpectedByOther      
                  SET @n_PendingReplenQty = @n_PendingReplenQty - @n_QtyExpectedByOther      
               ELSE      
                  SET @n_PendingReplenQty = 0      
            END      
            --NJOW08 E      
      
         --If have available qty from pending replen then no need replen      
         SET @n_QtyExpected  = @n_QtyExpected - ISNULL(@n_PendingReplenQty,0)      
      
         IF @n_debug = 1      
         BEGIN      
            PRINT '@n_PendingReplenQty='+RTRIM(CAST(@n_PendingReplenQty AS NVARCHAR))      
            PRINT '@n_QtyExpected(final)='+RTRIM(CAST(@n_QtyExpected AS NVARCHAR))      
         END      
      
         IF @n_QtyExpected <= 0      
            GOTO NEXT_DPP_REPLEN      
      
            SET @c_Condition = ' AND LOTxLOCxID.Lot = N''' + LTRIM(RTRIM(ISNULL(@c_Lot,''))) + ''' '      
      
            IF @c_AllocateGetCasecntFrLottable IN ('01','02','03','06','07','08','09','10','11','12') --NJOW03      
            BEGIN      
               SET @c_Condition =  RTRIM(@c_Condition) + ' ORDER BY LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable05, LOTxLOCxID.Lot, '  +      
                                 ' CASE WHEN (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) % CAST(LOTATTRIBUTE.Lottable10 AS INT) = 0 THEN 0 ELSE 1 END,  ' +      
                                 ' LOTATTRIBUTE.Lottable10, LOTxLOCxID.Qty, LOTxLOCxID.Loc '      
            END      
            ELSE --IN00480760      
            BEGIN      
               --NJOW06      
               IF @c_Country = 'CN'      
               BEGIN      
                  SET @c_Condition =  RTRIM(@c_Condition) + ' ORDER BY LOC.LocationGroup, LOC.LocLevel, QTYAVAILABLE, LOC.LogicalLocation, LOTxLOCxID.Loc, '  +      
                                    ' LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable05, LOTxLOCxID.Lot, '  +      
                                    ' CASE WHEN (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) % CAST(PACK.CaseCnt AS INT) = 0 THEN 0 ELSE 1 END,  ' +      
                                    ' PACK.CaseCnt, LOTxLOCxID.Qty '      
               END      
               ELSE      
               BEGIN      
                 --NJOW03      
                  SET @c_Condition =  RTRIM(@c_Condition) + ' ORDER BY LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable05, LOTxLOCxID.Lot, '  +      
                       ' CASE WHEN (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) % CAST(PACK.CaseCnt AS INT) = 0 THEN 0 ELSE 1 END,  ' +      
                   ' PACK.CaseCnt, LOTxLOCxID.Qty, LOTxLOCxID.Loc '      
               END      
            END      
         END      
      
         SELECT @c_SQL =  ' SELECT LOTxLOCxID.STORERKEY, LOTxLOCxID.SKU, LOTxLOCxID.LOT, LOTxLOCxID.Loc, LOTxLOCxID.ID, ' +      
                        ' QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen), ' +      
                        ' LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable10, PACK.CaseCnt ' +      
                        ' FROM LOTATTRIBUTE (NOLOCK) ' +      
                        ' JOIN LOT (NOLOCK) ON LOT.LOT = LOTATTRIBUTE.LOT ' +      
                        ' JOIN LOTxLOCxID (NOLOCK) ON LOTxLOCxID.Lot = LOT.LOT AND LOTxLOCxID.LOT = LOTATTRIBUTE.LOT ' +      
                        ' JOIN SKUXLOC (NOLOCK) ON SKUXLOC.Storerkey = LOTxLOCxID.Storerkey AND SKUXLOC.Sku = LOTxLOCxID.Sku AND SKUXLOC.Loc = LOTxLOCxID.Loc ' +      
                        ' JOIN LOC (NOLOCK) ON LOTxLOCxID.LOC = LOC.LOC ' +      
                        ' JOIN ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID ' +      
                        ' JOIN SKU (NOLOCK) ON LOTXLOCXID.Storerkey = SKU.Storerkey AND LOTXLOCXID.Sku = SKU.Sku ' + --NJOW01      
                        ' JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey ' + --NJOW03      
                        ' LEFT JOIN CODELKUP CL (NOLOCK) ON CL.Listname = ''REPLSWAP'' AND LOTATTRIBUTE.Lottable02 = CL.Short AND LOTxLOCxID.Storerkey = CL.Storerkey ' +      
                        ' WHERE LOT.STORERKEY = N''' + RTRIM(@c_storerkey) + ''' ' +      
                        ' AND LOT.SKU = N''' + RTRIM(@c_SKU) + ''' ' +      
                        ' AND LOT.STATUS = ''OK'' ' +      
                        ' AND LOC.STATUS = ''OK'' AND ID.STATUS = ''OK''  ' +      
                        ' AND LOC.LocationFlag = ''NONE'' ' +      
                           ' AND LOC.Facility = N''' + RTRIM(@c_facility) + ''' ' +      
                        ' AND LOTATTRIBUTE.STORERKEY = N''' + RTRIM(@c_storerkey) + ''' ' +      
                        ' AND LOTATTRIBUTE.SKU = N''' + RTRIM(@c_SKU) + ''' ' +      
                        ' AND SKUXLOC.Locationtype NOT IN (''PICK'',''CASE'') ' +      
                        ' AND LOC.Locationtype NOT IN (''DYNPPICK'') ' +      
                        ' AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) > 0 ' +      
                        RTRIM(@c_SQLParam) +      
                        RTRIM(@c_Condition)      
      
         INSERT INTO #BULK_STOCK (Storerkey, Sku, Lot, Loc, ID, Qty, Lottable02, Lottable10, CaseCnt) --NJOW03      
         EXEC(@c_SQL)      
      
         IF @n_debug = 1      
            PRINT @c_SQL      
      
         IF @c_AllocateGetCasecntFrLottable IN ('01','02','03','06','07','08','09','10','11','12') --NJOW03      
         BEGIN      
            IF EXISTS(SELECT 1 FROM #BULK_STOCK WHERE ISNUMERIC(Lottable10) <> 1 OR ISNULL(Lottable10,'') IN ('0',''))      
            BEGIN      
               SELECT @n_continue = 3      
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81060      
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Found Lot With Invalid Lottable10 Value. (ispRLWAV03)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '      
               GOTO RETURN_SP      
            END      
      
            UPDATE #BULK_STOCK      
            SET LooseCaseQty = Qty % CAST(Lottable10 AS INT)      
               ,Casecnt = CAST(Lottable10 AS INT)      
               ,Seq = CASE WHEN Lot = @C_LotOrg AND ISNULL(@c_Notes2,'') = '0' THEN '1' ELSE '2' END  --NJOW08 if none swap lot, set require lot as frist priority      
         END      
         ELSE      
        BEGIN      
            --NJOW03      
            UPDATE #BULK_STOCK   
            SET LooseCaseQty = Qty % CaseCnt,      
                Seq = CASE WHEN Lot = @C_LotOrg AND ISNULL(@c_Notes2,'') = '0' THEN '1' ELSE '2' END  --NJOW08 if none swap lot, set require lot as frist priority      
         END      
      
         --IF ISNULL(@c_Notes2,'') = '1'  --Allow swap lot      
         IF ISNULL(@c_Notes2,'') <> ''  --if have ecom and retail (cn only)      
         BEGIN      
            INSERT INTO #COMBINE_CARTON      
            SELECT Loc, Casecnt,      
                  FLOOR(SUM(LooseCaseQty) / Casecnt) AS CaseAvailable,      
                  'N' AS Usedflag      
            FROM #BULK_STOCK      
            GROUP BY Loc, Casecnt      
            HAVING FLOOR(SUM(LooseCaseQty) / Casecnt) > 0      
         END      
      
         --Generate replenishment from bulk to DPP      
         IF ISNULL(@c_Notes2,'') = '0' --if not swap lot (retail) get all the single lot carton first      
         BEGIN      
            DECLARE Cur_BulkStock_1LotCtn CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
               SELECT B.Rowid, B.Lot, B.Loc, B.ID, B.Casecnt, B.Qty      
               FROM #BULK_STOCK B      
               JOIN LOTATTRIBUTE LA (NOLOCK) ON B.Lot = LA.Lot      
               --WHERE LA.Lottable02 = @c_Lottable02      
               WHERE LA.Lot = @c_LotOrg --NJOW08  only get require lot for full case for none swap lot      
               ORDER BY B.RowId      
      
            OPEN Cur_BulkStock_1LotCtn      
      
            FETCH NEXT FROM Cur_BulkStock_1LotCtn INTO @n_RowId, @c_Lot, @c_Loc, @c_ID, @n_Casecnt, @n_QtyAvailable      
            WHILE @@FETCH_STATUS <> -1 AND @n_QtyExpected > 0 AND @n_continue IN(1,2)      
            BEGIN      
               --find available DPP location      
               --SET @c_CallSource = 'ASSIGNDPPTOREPLEN'      
               --GOTO FIND_DPP_LOC      
               --RTN_ASSIGNDPPTOREPLEN:      
      
               SET @n_CaseAvailable = FLOOR(@n_QtyAvailable / (@n_Casecnt * 1.00))      
               SET @n_CaseRequire = CEILING(@n_QtyExpected / (@n_Casecnt * 1.00))      
      
               SET @n_Qty = @n_Casecnt      
      
               IF @n_CaseAvailable >= @n_CaseRequire      
               BEGIN      
                  SET @n_QtyExpected = 0      
                  SET @n_cnt = @n_CaseRequire      
               END      
               ELSE      
               BEGIN      
                  SET @n_QtyExpected = @n_QtyExpected - (@n_CaseAvailable * @n_Casecnt)      
                  SET @n_cnt = @n_CaseAvailable      
               END      
      
               IF @n_debug = 1      
               BEGIN      
                  PRINT 'Stock From Bulk (retail) single lot carton'      
                  PRINT '@c_Sku='+rtrim(@c_sku) + ' @c_Lot='+rtrim(@c_Lot) + ' @c_Loc=' + RTRIM(@c_loc) + ' @c_id=' +RTRIM(@c_id)      
                  PRINT '@n_Casecnt='+RTRIM(CAST(@n_casecnt AS NVARCHAR))  + ' @n_Qtyavailable='+RTRIM(CAST(@n_qtyavailable AS NVARCHAR))      
                  PRINT '@n_CaseAvailable='+RTRIM(CAST(@n_CaseAvailable AS NVARCHAR))  + ' @n_CaseRequire='+RTRIM(CAST(@n_CaseRequire AS NVARCHAR))      
                  PRINT '@n_cnt(case to take)='+RTRIM(CAST(@n_cnt AS NVARCHAR))      
               END      
      
               UPDATE #BULK_STOCK      
               SET Qty = Qty - (@n_cnt * @n_Casecnt)      
               WHERE Rowid = @n_RowId      
      
               --Create replenishment record. 1 carton per line      
               SET @c_CallSource = 'DPPLOOSEREPLEN_1LOTCTN'      
               SET @c_Remark = 'RPL'      
               SET @c_ReplenNo = 'RPL'      
               SET @c_PackUOM = 'EA' --ChewKP01      
               WHILE @n_cnt > 0      
               BEGIN      
                  GOTO INSERT_REPLEN      
                  RTN_INSERT_REPLEN_DPPLOOSE_1LOTCTN:      
                  SELECT @n_cnt = @n_cnt - 1      
               END      
   
               FETCH NEXT FROM Cur_BulkStock_1LotCtn INTO @n_Rowid, @c_Lot, @c_Loc, @c_ID, @n_Casecnt, @n_QtyAvailable      
            END      
            CLOSE Cur_BulkStock_1LotCtn      
            DEALLOCATE Cur_BulkStock_1LotCtn      
         END      
      
         DECLARE Cur_BulkStock CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
            SELECT Lot, Loc, ID, Casecnt,      
                  Qty      
            FROM #BULK_STOCK      
            WHERE Qty > 0      
            ORDER BY Seq, --NJOW08 if none swap lot, sort require lot as frist      
                     RowId      
      
         OPEN Cur_BulkStock      
      
         FETCH NEXT FROM Cur_BulkStock INTO @c_Lot, @c_Loc, @c_ID, @n_Casecnt, @n_QtyAvailable                 
         
         WHILE @@FETCH_STATUS <> -1 AND @n_QtyExpected > 0 AND @n_continue IN(1,2)      
         BEGIN      
               --find available DPP location      
               --SET @c_CallSource = 'ASSIGNDPPTOREPLEN'      
               --GOTO FIND_DPP_LOC      
               --RTN_ASSIGNDPPTOREPLEN:      
      
            SET @n_CaseAvailable = FLOOR(@n_QtyAvailable / (@n_Casecnt * 1.00))      
            SET @n_CaseRequire = CEILING(@n_QtyExpected / (@n_Casecnt * 1.00))      
      
            IF ISNULL(@c_Notes2,'') = '0' AND @c_LotOrg <> @c_Lot  --NJOW08 if none swap lot don't get full case of ohter lot      
            BEGIN      
               SET @n_cnt = 0      
            END      
            ELSE      
            BEGIN      
               SET @n_Qty = @n_Casecnt      
      
               IF @n_CaseAvailable >= @n_CaseRequire      
               BEGIN      
                  SET @n_QtyExpected = 0      
                  SET @n_cnt = @n_CaseRequire      
               END      
               ELSE      
               BEGIN      
                  SET @n_QtyExpected = @n_QtyExpected - (@n_CaseAvailable * @n_Casecnt)      
                  SET @n_cnt = @n_CaseAvailable      
               END      
            END      
      
            IF @n_debug = 1      
            BEGIN      
               PRINT 'Stock From Bulk (1)'      
               PRINT '@c_Sku='+rtrim(@c_sku) + ' @c_Lot='+rtrim(@c_Lot) + ' @c_Loc=' + RTRIM(@c_loc) + ' @c_id=' +RTRIM(@c_id)      
               PRINT '@n_Casecnt='+RTRIM(CAST(@n_casecnt AS NVARCHAR))  + ' @n_Qtyavailable='+RTRIM(CAST(@n_qtyavailable AS NVARCHAR))      
               PRINT '@n_CaseAvailable='+RTRIM(CAST(@n_CaseAvailable AS NVARCHAR))  + ' @n_CaseRequire='+RTRIM(CAST(@n_CaseRequire AS NVARCHAR))      
               PRINT '@n_cnt(case to take)='+RTRIM(CAST(@n_cnt AS NVARCHAR))      
            END      
      
         --Create replenishment record. 1 carton per line      
            SET @c_CallSource = 'DPPLOOSEREPLEN'      
            SET @c_Remark = 'RPL'      
            SET @c_ReplenNo = 'RPL'      
            SET @c_PackUOM = 'EA' --ChewKP01      
            WHILE @n_cnt > 0      
            BEGIN      
               GOTO INSERT_REPLEN      
               RTN_INSERT_REPLEN_DPPLOOSE:      
               SELECT @n_cnt = @n_cnt - 1      
            END      
      
            --replenish from combine lot carton of the location      
            --IF ISNULL(@c_Notes2,'') = '1' AND @n_QtyExpected > 0 --Allow swap lot      
            IF @n_QtyExpected > 0 AND ISNULL(@c_Notes2,'') <> '' --if have ecom and retail (cn only)      
            BEGIN      
               DECLARE Cur_CombineCarton CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
                  SELECT Loc, Casecnt, CaseAvailable      
                  FROM #COMBINE_CARTON      
                  WHERE Loc = @c_Loc      
                  AND UsedFlag = 'N'      
                  AND (EXISTS(SELECT 1      
                             FROM #BULK_STOCK      
                             WHERE Loc = #COMBINE_CARTON.Loc      
                             AND Casecnt = #COMBINE_CARTON.Casecnt      
                             AND LooseCaseQty > 0      
                             AND Lot = @c_LotOrg)      
                       OR ISNULL(@c_Notes2,'') <> '0')  --NJOW08 only get the combine carton consist of the require lot for none swap lot      
      
               OPEN Cur_CombineCarton      
      
               FETCH NEXT FROM Cur_CombineCarton INTO @c_Loc, @n_Casecnt, @n_CaseAvailable      
      
               WHILE @@FETCH_STATUS <> -1 AND @n_QtyExpected > 0 AND @n_continue IN(1,2)      
               BEGIN      
                  SET @n_CaseRequire = CEILING(@n_QtyExpected / (@n_Casecnt * 1.00))      
      
                  IF @n_CaseAvailable >= @n_CaseRequire      
                  BEGIN      
                     IF ISNULL(@c_Notes2,'') <> '0'  --NJOW08      
                        SET @n_QtyExpected = 0      
      
                     SET @n_cnt = @n_CaseRequire      
                  END      
                  ELSE      
                  BEGIN      
                     IF ISNULL(@c_Notes2,'') <> '0'  --NJOW08      
                        SET @n_QtyExpected = @n_QtyExpected - (@n_CaseAvailable * @n_Casecnt)      
      
                     SET @n_cnt = @n_CaseAvailable      
                  END      
      
               SET @n_QtyReplenFrom = @n_cnt * @n_Casecnt      
      
               IF @n_debug = 1      
               BEGIN      
                  PRINT 'Stock From Bulk (combine ctn)'      
                  PRINT '@c_Sku='+rtrim(@c_sku) + ' @c_Loc=' + RTRIM(@c_loc)      
                  PRINT '@n_Casecnt='+RTRIM(CAST(@n_casecnt AS NVARCHAR))  + ' @n_Qtyavailable='+RTRIM(CAST(@n_qtyavailable AS NVARCHAR))      
                  PRINT '@n_CaseAvailable='+RTRIM(CAST(@n_CaseAvailable AS NVARCHAR))  + ' @n_CaseRequire='+RTRIM(CAST(@n_CaseRequire AS NVARCHAR))      
                  PRINT 'n_QtyReplenFrom(Qty to take)='+RTRIM(CAST(@n_QtyReplenFrom AS NVARCHAR))      
               END      
      
               --Generate replenishment from combine carton (loc,id,casecnt)      
               DECLARE Cur_REPCombineCarton CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
                  SELECT Lot, ID, SUM(LooseCaseQty) AS Qty      
                     FROM #BULK_STOCK      
                     WHERE Loc = @c_Loc      
                     AND Casecnt = @n_Casecnt      
                     AND LooseCaseQty > 0      
                     GROUP BY Lot, ID, Seq      
                     ORDER BY Seq  --NJOW08  if none swap get the require lot first      
                             ,Lot      
      
                  OPEN Cur_REPCombineCarton      
      
                  FETCH NEXT FROM Cur_REPCombineCarton INTO @c_Lot, @c_Id, @n_Qty      
      
                  SET @n_CtnBal = 0      
                  WHILE @@FETCH_STATUS <> -1 AND @n_QtyReplenFrom > 0 AND @n_continue IN(1,2)      
                  BEGIN      
                     IF @n_QtyReplenFrom >= @n_Qty      
                     BEGIN      
                        SET @n_QtyReplenFrom = @n_QtyReplenFrom - @n_Qty      
                     END      
                     ELSE      
                     BEGIN      
                        SET @n_Qty = @n_QtyReplenFrom      
                        SET @n_QtyReplenFrom = 0      
                     END      
      
                     IF ISNULL(@c_Notes2,'') = '0'  --NJOW08  none swap lot only deduect qtyexpected from the require lot in the combine carton      
                     BEGIN      
                       IF @c_Lot = @c_LotOrg      
                          SET @n_QtyExpected = @n_QtyExpected - @n_Qty      
                     END      
      
                     --Multi lot carton with refno to indication a carton      
                     SET @n_QtyBal = @n_Qty      
                     WHILE @n_QtyBal > 0      
                     BEGIN      
                        IF @n_CtnBal <= 0      
                        BEGIN      
                           SET @n_CtnBal = @n_Casecnt      
                           EXECUTE nspg_getkey      
                           'GenRefNo'      
                           , 10      
                           , @c_GenRefNo OUTPUT      
                           , @b_success OUTPUT      
                           , @n_err OUTPUT      
                           , @c_errmsg OUTPUT      
                                 SET @c_Refno = @c_GenRefNo      
                        END      
      
                        IF @n_CtnBal <= @n_QtyBal      
                        BEGIN      
                           SET @n_Qty = @n_CtnBal      
                           SET @n_QtyBal = @n_QtyBal - @n_CtnBal      
                           SET @n_CtnBal = 0      
                        END      
                        ELSE      
                        BEGIN      
                           SET @n_Qty = @n_QtyBal      
                           SET @n_CtnBal = @n_CtnBal - @n_QtyBal      
                           SET @n_QtyBal = 0      
                        END      
      
      
                        --Create replenishment record. partial lot carton per line      
                        SET @c_CallSource = 'DPPCOMBINECTNREPLEN'      
                        SET @c_Remark = 'RPL'      
                        SET @c_ReplenNo = 'RPL-COMBCA'      
                        SET @c_PackUOM = 'EA' --ChewKP01      
                        GOTO INSERT_REPLEN      
                        RTN_INSERT_REPLEN_DPPCOMBINECTN:      
                     END      
      
                     --Create replenishment record. partial lot carton per line      
                     FETCH NEXT FROM Cur_REPCombineCarton INTO @c_Lot, @c_Id, @n_Qty      
                  END      
                  CLOSE Cur_REPCombineCarton      
                  DEALLOCATE Cur_REPCombineCarton      
      
                  SET @c_Refno = ''      
      
                  UPDATE #COMBINE_CARTON      
                  SET usedFlag = 'Y'      
                  WHERE Loc = @c_Loc      
                  --AND Id = @c_ID      
                  AND Casecnt = @n_Casecnt      
      
                  FETCH NEXT FROM Cur_CombineCarton INTO @c_Loc, @n_Casecnt, @n_CaseAvailable      
               END      
               CLOSE Cur_CombineCarton      
               DEALLOCATE Cur_CombineCarton      
            END      
      
            FETCH NEXT FROM Cur_BulkStock INTO @c_Lot, @c_Loc, @c_ID, @n_Casecnt, @n_QtyAvailable      
         END      
         CLOSE Cur_BulkStock      
         DEALLOCATE Cur_BulkStock      
      
         ------------------------------------------------      
         IF @n_QtyExpected > 0 AND EXISTS(SELECT 1 FROM #BULK_STOCK WHERE LooseCaseQty > 0)      
         BEGIN      
            DECLARE Cur_LooseCarton CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
            SELECT BS.Lot, BS.ID, SUM(BS.LooseCaseQty) AS Qty, BS.Loc      
            FROM #BULK_STOCK BS      
            LEFT JOIN (SELECT DISTINCT Loc FROM #COMBINE_CARTON) AS CC ON BS.Loc = CC.Loc      
            WHERE BS.LooseCaseQty > 0      
            AND (BS.Lot = @c_LotOrg OR ISNULL(@c_Notes2,'') <> '0')  --NJOW08   if none swap lot only get the loose carton of require lot      
            GROUP BY BS.Lot, BS.ID, BS.Loc, CC.Loc      
            ORDER BY CASE WHEN CC.Loc IS NULL THEN 1 ELSE 2 END, BS.Loc, BS.Lot      
      
            OPEN Cur_LooseCarton      
            FETCH NEXT FROM Cur_LooseCarton INTO @c_Lot, @c_Id, @n_Qty, @c_Loc      
      
            WHILE @@FETCH_STATUS <> -1 AND @n_QtyExpected > 0 AND @n_continue IN(1,2)      
            BEGIN      
               IF @n_QtyExpected >= @n_Qty      
               BEGIN      
                  SET @n_QtyExpected = @n_QtyExpected - @n_Qty      
               END      
               ELSE      
               BEGIN      
                  --SET @n_Qty = @n_QtyExpected      
                  SET @n_QtyExpected = 0      
               END      
      
               IF @n_debug = 1      
               BEGIN      
                  PRINT 'Stock From Bulk (Loose)'      
                  PRINT '@c_Sku='+rtrim(@c_sku) + ' @c_Lot='+rtrim(@c_Lot) + ' @c_Loc=' + RTRIM(@c_loc) + ' @c_id=' +RTRIM(@c_id)      
                  PRINT '@n_Casecnt='+RTRIM(CAST(@n_casecnt AS NVARCHAR))  + ' @n_Qty='+RTRIM(CAST(@n_Qty AS NVARCHAR))      
               END      
      
               --Create replenishment record. partial lot carton per line      
               SET @c_CallSource = 'DPPLOOSECTNREPLEN'      
               SET @c_Remark = 'RPL'      
               SET @c_ReplenNo = 'RPL-LOOSE'      
               SET @c_PackUOM = 'EA'      
               GOTO INSERT_REPLEN      
               RTN_INSERT_REPLEN_DPPLOOSECTN:      
      
               FETCH NEXT FROM Cur_LooseCarton INTO @c_Lot, @c_Id, @n_Qty, @c_Loc      
            END      
            CLOSE Cur_LooseCarton      
            DEALLOCATE Cur_LooseCarton      
         END      
      
         ------------------------------------------------      
         IF @n_QtyExpected > 0 AND @c_Country NOT IN('KR','KOR')--AND EXISTS(SELECT 1 FROM #BULK_STOCK WHERE LooseCaseQty > 0)      
         BEGIN      
            IF @c_Country = 'CN'      
            BEGIN      
               --NJOW09      
               SET @c_logmsg = 'Wave:' + @c_Wavekey + ' Replenishment Failed SKU:' + RTRIM(@c_Sku) + ' DPP Loc:' + RTRIM(@c_ToLoc)      
                  + '. Unable find full carton or no stock from bulk (ispRLWAV03)'      
      
              EXECUTE nsp_logerror 33333, @c_logmsg, "ispRLWAV03"      
           END      
           ELSE      
            BEGIN      
               SELECT @n_continue = 3      
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81070      
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Replenishment Failed SKU:' + RTRIM(@c_Sku) + ' DPP Loc:'      
             + RTRIM(@c_ToLoc) + '. Unable find full carton or no stock from bulk (ispRLWAV03)' + ' ( ' + ' SQLSvr MESSAGE='      
                     + RTRIM(@c_errmsg) + ' ) '      
               GOTO RETURN_SP      
            END      
         END      
      
         NEXT_DPP_REPLEN:      
      
         SET @c_PrevNotes = @c_Notes      
      
         FETCH NEXT FROM CUR_DPP_REPLEN INTO @c_StorerKey, @c_Sku, @c_ToLoc, @n_QtyExpected,      
                                             @c_Packkey, @c_PackUOM, @c_Putawayzone, @c_Long, @c_Notes, @c_Notes2,      
                                             @c_Lottable01, @c_Lottable02, @c_Lottable03, @c_Lottable06,      
                                             @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lot, @n_CaseCnt --NJOW03      
      END -- WHILE @@FETCH_STATUS <> -1      
      CLOSE CUR_DPP_REPLEN      
      DEALLOCATE CUR_DPP_REPLEN      
      
      SET @c_Step3_Time  = CONVERT (NVARCHAR(12), GETDATE() -  @d_Trace_Step3 ,114)                  --(Wan01)      
    END      
    
    --KR update for order with Reserver and PTO
    IF @n_continue = 1 OR @n_continue = 2 AND @c_Country IN('KR','KOR')  --NJOW12
    BEGIN
    	 IF EXISTS(SELECT 1 
    	           FROM WAVEDETAIL WD (NOLOCK)
    	           JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
    	           WHERE WD.Wavekey = @c_Wavekey
    	           AND O.Userdefine01 = 'RESERVE' 
    	           AND O.Userdefine03 = 'PTO')
    	 BEGIN          
          SET @n_currtrancnt = @@TRANCOUNT
          WHILE @n_currtrancnt > 0
          BEGIN
              COMMIT TRAN
              SET @n_currtrancnt = @n_currtrancnt - 1
          END          
          
          DECLARE CUR_RESERVEORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
             SELECT O.Orderkey, PD.Pickdetailkey
             FROM WAVEDETAIL WD (NOLOCK)
             JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
             JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey = PD.Orderkey
             WHERE WD.Wavekey = @c_Wavekey
             AND O.Userdefine01 = 'RESERVE' 
             AND O.Userdefine03 = 'PTO'

          OPEN CUR_RESERVEORD                           
                                        
          FETCH NEXT FROM CUR_RESERVEORD INTO @c_Orderkey, @c_Pickdetailkey
          
          WHILE @@FETCH_STATUS <> -1 AND @n_continue IN(1,2)
          BEGIN
          	 BEGIN TRAN
          	 	
          	 UPDATE PICKDETAIL WITH (ROWLOCK)
          	 SET DropId = @c_Orderkey,
          	     Status = CASE WHEN Status < '5' THEN '3' ELSE Status END
          	 WHERE Pickdetailkey = @c_Pickdetailkey

             SELECT @n_err = @@ERROR
             IF @n_err <> 0
             BEGIN
                 SELECT @n_continue = 3
                 SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81150
                 SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Failed. (ispRLWAV03)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
                 GOTO RETURN_SP
             END
             ELSE
               COMMIT TRAN          	           	     	
          	 
             FETCH NEXT FROM CUR_RESERVEORD INTO @c_Orderkey, @c_Pickdetailkey
          END
          CLOSE CUR_RESERVEORD
          DEALLOCATE CUR_RESERVEORD          
       END  	 
    END    
      
    IF @n_continue IN(1,2)  --NJOW07      
    BEGIN      
       IF ( SELECT COUNT(1) FROM PICKHEADER PH WITH (NOLOCK) -- IN00231782      
            WHERE PH.Wavekey = @c_Wavekey ) = 0      
       BEGIN      
          SELECT @n_continue = 3      
          SELECT @n_err = 81337      
          SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Missing pickslip for Wave ' + ISNULL(RTRIM(@c_Wavekey),'') + '. (ispRLWAV03)'      
          GOTO RETURN_SP      
       END      
    END      
      
    SET @n_currtrancnt = @@TRANCOUNT      
    WHILE @n_currtrancnt > @n_StartTCnt     -- ZG01     
    BEGIN      
       COMMIT TRAN      
       SET @n_currtrancnt = @n_currtrancnt - 1      
    END      
      
    --WHILE @@TRANCOUNT > 0      
       --COMMIT TRAN      
      
    --NJOW08      
    /*      
    IF @n_continue IN(1,2) AND @c_AutoReplenSwapLot = '1'      
    BEGIN      
       IF @c_SWLotOption1 = 'ReplSwapInv'      
       BEGIN      
          BEGIN TRY      
             EXEC isp_ReplSwapInv      
                  @c_Storerkey = @c_Storerkey,      
                  @c_ForcePicked = 'N',      
                  @c_callfrom  = 'RELEASETASK'      
           END TRY      
           BEGIN CATCH      
              SET @c_logmsg = 'Wave:' + @c_Wavekey + ' Swap Lot Error. ' + ERROR_MESSAGE()      
             execute nsp_logerror 33333, @c_logmsg, "ispRLWAV03"      
           END CATCH      
       END     
       ELSE      
       BEGIN      
          BEGIN TRY      
              EXEC nsp_ChangePickDetailByStorer      
                  @c_Storerkey = @c_Storerkey      
           END TRY      
           BEGIN CATCH      
              SET @c_logmsg = 'Wave:' + @c_Wavekey + ' Swap pickdet Error. ' + ERROR_MESSAGE()      
             execute nsp_logerror 33333, @c_logmsg, "ispRLWAV03"      
           END CATCH      
       END      
    END      
    */      
      
RETURN_SP:      
      
   SET @n_currtrancnt = @@TRANCOUNT      
   WHILE @n_currtrancnt > 0      
   BEGIN      
      COMMIT TRAN      
      SET @n_currtrancnt = @n_currtrancnt - 1      
   END      
      
   --WHILE @@TRANCOUNT > 0  --NJOW10      
      --COMMIT TRAN      
      
   --(Wan01) - START      
   SET @d_Trace_EndTime = GETDATE()      
   SET @c_UserName = SUSER_SNAME()      
      
   -- Do not intrace traceinfo in debug mode      
   IF @n_debug = 0      
   BEGIN      
      EXEC isp_InsertTraceInfo      
         @c_TraceCode = 'ReleaseWave03',      
         @c_TraceName = 'ispRLWAV03',      
         @c_starttime = @d_Trace_StartTime,      
         @c_endtime   = @d_Trace_EndTime,      
         @c_step1 = @c_Step1_Time,      
         @c_step2 = @c_Step2_Time,      
         @c_step3 = @c_Step3_Time,      
         @c_step4 = '',      
         @c_step5 = '',      
         @c_col1 = @c_Trace_Step1,      
         @c_col2 = @c_Trace_Step2,      
         @c_col3 = @c_Trace_Step3,      
         @c_col4 = @c_Wavekey,      
         @c_col5 = @c_UserName,      
         @b_Success = 1,      
         @n_Err = 0,      
         @c_ErrMsg = ''      
   END      
      
   SET @n_currtrancnt = @@TRANCOUNT      
   WHILE @n_currtrancnt > @n_StartTCnt   -- ZG01   
   BEGIN      
      BEGIN TRAN      
      SET @n_currtrancnt = @n_currtrancnt + 1      
   END      
     
   --WHILE @@TRANCOUNT < @n_starttcnt   --NJOW10      
      --BEGIN TRAN      
     
   --IF @@TRANCOUNT < @n_starttcnt      
   --   BEGIN TRAN      
     
   --(Wan01) - END      
   IF @n_continue=3  -- Error Occured - Process And Return      
   BEGIN      
      SELECT @b_success = 0      
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt      
      BEGIN      
         ROLLBACK TRAN      
      END      
      ELSE      
      BEGIN      
         SET @n_currtrancnt = @@TRANCOUNT      
         WHILE @n_currtrancnt > @n_StartTCnt      -- ZG01     
         BEGIN      
            COMMIT TRAN      
            SET @n_currtrancnt = @n_currtrancnt - 1      
         END      
     
         --WHILE @@TRANCOUNT > @n_starttcnt      
         --BEGIN      
         --   COMMIT TRAN      
         --END      
      END      
      execute nsp_logerror @n_err, @c_errmsg, "ispRLWAV03"      
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012      
      --RETURN    --(JH01)  
   END      
   ELSE      
   BEGIN      
      SELECT @b_success = 1      
      SET @n_currtrancnt = @@TRANCOUNT      
     
      WHILE @n_currtrancnt > @n_StartTCnt      -- ZG01    
      BEGIN      
         COMMIT TRAN      
         SET @n_currtrancnt = @n_currtrancnt - 1      
      END      
     
      --WHILE @@TRANCOUNT > @n_starttcnt      
      --BEGIN      
      --   COMMIT TRAN      
      --END      
      --RETURN    --(JH01)        
   END      
   --(JH01) start  
   WHILE @@TRANCOUNT < @n_starttcnt    
   BEGIN    
      BEGIN TRAN    
   END    
    
 RETURN       
 --(JH01) END        
INSERT_REPLEN:      
      
   SET @n_currtrancnt = @@TRANCOUNT      
   WHILE @n_currtrancnt > 0      
   BEGIN      
       COMMIT TRAN      
       SET @n_currtrancnt = @n_currtrancnt - 1      
   END      
      
   --WHILE @@TRANCOUNT > 0      
     -- COMMIT TRAN      
      
   EXECUTE nspg_getkey      
      'REPLENISHKEY'      
      , 10      
      , @c_ReplenishmentKey OUTPUT      
      , @b_success OUTPUT      
      , @n_err OUTPUT      
      , @c_errmsg OUTPUT      
      
   IF NOT @b_success = 1      
   BEGIN      
      SELECT @n_continue = 3      
   END      
      
   IF @b_success = 1      
   BEGIN      
      SET @n_currtrancnt = @@TRANCOUNT      
      WHILE @n_currtrancnt > 0      
      BEGIN      
         COMMIT TRAN      
         SET @n_currtrancnt = @n_currtrancnt - 1      
      END      
      
      --WHILE @@TRANCOUNT > 0      
        -- COMMIT TRAN      
      
      --NJOW05      
      IF @c_Country IN('KR','KOR') AND ISNULL(@c_RefNo,'') = ''      
      BEGIN      
         SELECT @c_RefNo = LOTTABLE11      
         FROM LOTATTRIBUTE (NOLOCK)      
         WHERE Lot = @c_Lot      
      END      
      
      BEGIN TRAN      
      
      INSERT INTO REPLENISHMENT (ReplenishmentKey, ReplenishmentGroup,      
                     StorerKey,      SKU,         FromLOC,         ToLOC,      
                     Lot,            Id,          Qty,             UOM,                         
                     PackKey,        Priority,    QtyMoved,        QtyInPickLOC,      
                     RefNo,          Confirmed,   ReplenNo,        Wavekey,      
                     Remark,         OriginalQty, OriginalFromLoc, ToID)      
                 VALUES (      
                     @c_ReplenishmentKey,         'DYNAMIC',      
                     @c_StorerKey,   @c_Sku,      @c_Loc,          @c_ToLoc,      
                     @c_Lot,         @c_Id,       @n_Qty,          @c_PackUOM,      
                     @c_Packkey,     @c_Priority, 0,               0,      
                     @c_RefNo,      'N',          @c_ReplenNo,     @c_WaveKey,      
                     @c_Remark,      @n_Qty,      'ispRLWAV03',    '')      
      
      SELECT @n_err = @@ERROR      
      IF @n_err <> 0      
      BEGIN      
         SELECT @n_continue = 3      
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81080      
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Replenishment Failed. (ispRLWAV03)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '      
         GOTO RETURN_SP      
      END      
      ELSE      
        COMMIT TRAN      
   END          
      
   IF (@n_continue = 1 OR @n_continue = 2) AND @c_CallSource NOT IN('FULLCASEREPLEN','CONSOCASEREPLEN') --NJOW04      
   BEGIN      
      BEGIN TRAN      
      
      UPDATE LOTxLOCxID WITH (ROWLOCK)      
      SET QtyReplen = QtyReplen + @n_Qty,      
          TrafficCop = NULL      
      WHERE Storerkey = @c_Storerkey      
      AND Sku = @c_Sku      
      AND Lot = @c_Lot      
      AND Loc = @c_Loc      
      AND ID = @c_Id      
      
      SELECT @n_err = @@ERROR      
      IF @n_err <> 0      
      BEGIN      
          SELECT @n_continue = 3      
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81090      
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update LOTxLOCxID Failed. (ispRLWAV03)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '      
          GOTO RETURN_SP      
      END      
      ELSE      
         COMMIT TRAN      
   END      
      
      
   IF @c_CallSource = 'FULLCASEREPLEN'      
       GOTO RTN_INSERT_REPLEN_FULLCASE      
   IF @c_CallSource = 'DPPLOOSEREPLEN'      
       GOTO RTN_INSERT_REPLEN_DPPLOOSE      
   IF @c_CallSource = 'DPPCOMBINECTNREPLEN'      
       GOTO RTN_INSERT_REPLEN_DPPCOMBINECTN      
   IF @c_CallSource = 'DPPLOOSEREPLEN_1LOTCTN'      
       GOTO RTN_INSERT_REPLEN_DPPLOOSE_1LOTCTN      
   IF @c_CallSource = 'DPPLOOSECTNREPLEN'      
       GOTO RTN_INSERT_REPLEN_DPPLOOSECTN      
   IF @c_CallSource = 'CONSOCASEREPLEN' --NJOW04      
       GOTO RTN_INSERT_REPLEN_CONSOCASE      
      
MOVE_PICKDETAIL:      
      
   IF @n_continue = 1 OR @n_continue = 2      
   BEGIN      
      SET @n_currtrancnt = @@TRANCOUNT      
      WHILE @n_currtrancnt > 0      
      BEGIN      
         COMMIT TRAN      
         SET @n_currtrancnt = @n_currtrancnt - 1      
      END      
      
      --WHILE @@TRANCOUNT > 0      
        --COMMIT TRAN      
      
      IF EXISTS (SELECT 1      
                 FROM PICKDETAIL (NOLOCK)      
                 LEFT JOIN LOTxLOCxID WITH (NOLOCK) ON (LOTxLOCxID.StorerKey = PICKDETAIL.Storerkey      
                 AND LOTxLOCxID.SKU = PICKDETAIL.Sku      
                 AND LOTxLOCxID.Lot = PICKDETAIL.Lot      
                 AND LOTxLOCxID.Id = ''      
                 AND LOTxLOCxID.Loc = @c_ToLoc)      
                 WHERE ISNULL(LOTxLOCxID.Loc,'') = ''      
                 AND PICKDETAIL.Pickdetailkey = @c_Pickdetailkey)      
      BEGIN      
         IF @n_debug = 1      
         BEGIN      
            PRINT 'Insert LOTxLOCxID'      
         END      
      
         BEGIN TRAN      
      
         INSERT LOTxLOCxID (StorerKey, Sku, Lot, Loc, Id, Qty)      
         SELECT PICKDETAIL.Storerkey, PICKDETAIL.Sku, PICKDETAIL.Lot, @c_Toloc, '', 0      
         FROM PICKDETAIL(NOLOCK)      
         LEFT JOIN LOTxLOCxID WITH (NOLOCK) ON (LOTxLOCxID.StorerKey = PICKDETAIL.Storerkey      
                                                AND LOTxLOCxID.SKU = PICKDETAIL.Sku      
                                                AND LOTxLOCxID.Lot = PICKDETAIL.Lot      
                                                AND LOTxLOCxID.Id = ''      
                                                AND LOTxLOCxID.Loc = @c_ToLoc)      
         WHERE ISNULL(LOTxLOCxID.Loc,'') = ''      
         AND PICKDETAIL.Pickdetailkey = @c_Pickdetailkey      
      
         SELECT @n_err = @@ERROR      
         IF @n_err <> 0      
         BEGIN      
            SELECT @n_continue = 3      
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81110      
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert LOTxLOCxID Failed. (ispRLWAV03)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '      
            GOTO RETURN_SP      
         END      
         ELSE      
            COMMIT TRAN      
      
      END      
      
      IF EXISTS (SELECT 1      
                 FROM PICKDETAIL (NOLOCK)      
                 LEFT JOIN SKUxLOC WITH (NOLOCK) ON (SKUxLOC.StorerKey = PICKDETAIL.Storerkey      
                                                    AND SKUxLOC.SKU = PICKDETAIL.Sku      
                                                    AND SKUxLOC.Loc = @c_ToLoc)      
                 WHERE ISNULL(SKUxLOC.Loc,'') = ''      
                 AND PICKDETAIL.Pickdetailkey = @c_Pickdetailkey)      
      BEGIN      
         IF @n_debug = 1      
         BEGIN      
             PRINT 'Insert SKUxLOC'      
         END      
      
         BEGIN TRAN      
      
         INSERT SKUXLOC (StorerKey, Sku, Loc, Qty)      
         SELECT PICKDETAIL.Storerkey, PICKDETAIL.Sku, @c_Toloc, 0      
         FROM PICKDETAIL (NOLOCK)      
         LEFT JOIN SKUxLOC WITH (NOLOCK) ON (SKUxLOC.StorerKey = PICKDETAIL.Storerkey      
                                             AND SKUxLOC.SKU = PICKDETAIL.Sku      
         AND SKUxLOC.Loc = @c_ToLoc)      
         WHERE ISNULL(SKUxLOC.Loc,'') = ''      
         AND PICKDETAIL.Pickdetailkey = @c_Pickdetailkey      
      
         SELECT @n_err = @@ERROR      
         IF @n_err <> 0      
         BEGIN      
             SELECT @n_continue = 3      
             SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81120      
             SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert SKUxLOC Failed. (ispRLWAV03)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '      
             GOTO RETURN_SP      
         END      
         ELSE      
          COMMIT TRAN      
      END      
      
      BEGIN TRAN      
      
      UPDATE PICKDETAIL WITH (ROWLOCK)      
      SET Notes = Loc,      
          Loc = @c_ToLoc,      
          Id = ''      
      WHERE Pickdetailkey = @c_Pickdetailkey      
      
      SELECT @n_err = @@ERROR      
      IF @n_err <> 0      
      BEGIN      
          SELECT @n_continue = 3      
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81130      
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Failed. (ispRLWAV03)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '      
          GOTO RETURN_SP      
      END      
      ELSE      
         COMMIT TRAN      
   END      
      
   SET @n_currtrancnt = @@TRANCOUNT      
   WHILE @n_currtrancnt > 0      
   BEGIN      
      COMMIT TRAN      
      SET @n_currtrancnt = @n_currtrancnt - 1      
   END      
      
   --WHILE @@TRANCOUNT > 0      
   --   COMMIT TRAN      
      
   IF @c_CallSource = 'MOVEPICKDETAIL_LOOSE'      
       GOTO RTN_MOVE_PICKDETAIL_LOOSE      
      
FIND_DPP_LOC:      
      
   SET @n_currtrancnt = @@TRANCOUNT      
   WHILE @n_currtrancnt > 0      
   BEGIN      
      COMMIT TRAN      
      SET @n_currtrancnt = @n_currtrancnt - 1      
   END      
      
   --WHILE @@TRANCOUNT > 0      
      --COMMIT TRAN      
      
   SET @c_NextDynPickLoc = ''      
      
    -- Assign loc with same sku qty already assigned in current replenishment      
   IF ISNULL(@c_NextDynPickLoc,'')=''      
   BEGIN      
      SELECT TOP 1 @c_NextDynPickLoc = DL.ToLoc      
      FROM #DYNPICK_LOCASSIGNED DL      
      JOIN LOTATTRIBUTE LA (NOLOCK) ON DL.Lot = LA.Lot      
      JOIN LOC (NOLOCK) ON LOC.Loc = DL.ToLoc      
      WHERE DL.Storerkey = @c_Storerkey      
      AND DL.Sku = @c_Sku      
      AND DL.LocationType = 'DYNPPICK'      
      AND LA.Lottable01 = CASE WHEN CHARINDEX('LOTTABLE01', @c_NoMixLottableList) > 0 THEN @c_Lottable01 ELSE LA.Lottable01 END      
      AND LA.Lottable02 = CASE WHEN CHARINDEX('LOTTABLE02', @c_NoMixLottableList) > 0 THEN @c_Lottable02 ELSE LA.Lottable02 END      
      AND LA.Lottable03 = CASE WHEN CHARINDEX('LOTTABLE03', @c_NoMixLottableList) > 0 THEN @c_Lottable03 ELSE LA.Lottable03 END      
      AND LA.Lottable06 = CASE WHEN CHARINDEX('LOTTABLE06', @c_NoMixLottableList) > 0 AND (ISNULL(LA.Lottable06,'') NOT IN ('ECOM','RETAIL')      
                                                                          OR ISNULL(@c_Lottable06,'') NOT IN ('ECOM','RETAIL'))      
                                                                                           THEN @c_Lottable06 ELSE LA.Lottable06 END      
      AND LA.Lottable07 = CASE WHEN CHARINDEX('LOTTABLE07', @c_NoMixLottableList) > 0 THEN @c_Lottable07 ELSE LA.Lottable07 END      
      AND LA.Lottable08 = CASE WHEN CHARINDEX('LOTTABLE08', @c_NoMixLottableList) > 0 THEN @c_Lottable08 ELSE LA.Lottable08 END      
      AND LA.Lottable09 = CASE WHEN CHARINDEX('LOTTABLE09', @c_NoMixLottableList) > 0 THEN @c_Lottable09 ELSE LA.Lottable09 END      
      AND LA.Lottable10 = CASE WHEN CHARINDEX('LOTTABLE10', @c_NoMixLottableList) > 0 THEN @c_Lottable10 ELSE LA.Lottable10 END      
      AND LA.Lottable11 = CASE WHEN CHARINDEX('LOTTABLE11', @c_NoMixLottableList) > 0 THEN @c_Lottable11 ELSE LA.Lottable11 END      
      --AND LA.Lottable01 = @c_Lottable01      
      --AND LA.Lottable06 = @c_Lottable06      
      --AND LA.Lottable07 = @c_Lottable07      
      --AND LA.Lottable08 = @c_Lottable08      
      --AND LA.Lottable09 = @c_Lottable09      
      ORDER BY DL.ToLoc      
      
      IF @n_debug = 1      
      BEGIN      
         SELECT '@c_NextDynPickLoc 1', @c_NextDynPickLoc      
      END      
   END      
      
   -- Assign loc with same sku already assigned in other replenishment within same zone      
   IF ISNULL(@c_NextDynPickLoc,'')=''      
   BEGIN      
      SELECT TOP 1 @c_NextDynPickLoc = L.LOC      
      FROM REPLENISHMENT RP (NOLOCK)      
      JOIN LOC L (NOLOCK) ON RP.TOLOC = L.LOC      
      JOIN LOTATTRIBUTE LA (NOLOCK) ON RP.Lot = LA.Lot      
      WHERE L.LocationType = 'DYNPPICK'      
      AND L.PutawayZone = @c_Putawayzone      
      AND L.Facility = @c_Facility      
      AND RP.Confirmed = 'N'      
      AND RP.Qty > 0      
      AND RP.OriginalFromLoc = 'ispRLWAV03'      
      AND RP.Storerkey = @c_Storerkey      
      AND RP.Sku = @c_Sku      
      AND LA.Lottable01 = CASE WHEN CHARINDEX('LOTTABLE01', @c_NoMixLottableList) > 0 THEN @c_Lottable01 ELSE LA.Lottable01 END      
      AND LA.Lottable02 = CASE WHEN CHARINDEX('LOTTABLE02', @c_NoMixLottableList) > 0 THEN @c_Lottable02 ELSE LA.Lottable02 END      
      AND LA.Lottable03 = CASE WHEN CHARINDEX('LOTTABLE03', @c_NoMixLottableList) > 0 THEN @c_Lottable03 ELSE LA.Lottable03 END      
      AND LA.Lottable06 = CASE WHEN CHARINDEX('LOTTABLE06', @c_NoMixLottableList) > 0 AND (ISNULL(LA.Lottable06,'') NOT IN ('ECOM','RETAIL')      
                                                                                           OR ISNULL(@c_Lottable06,'') NOT IN ('ECOM','RETAIL'))      
                                THEN @c_Lottable06 ELSE LA.Lottable06 END      
      AND LA.Lottable07 = CASE WHEN CHARINDEX('LOTTABLE07', @c_NoMixLottableList) > 0 THEN @c_Lottable07 ELSE LA.Lottable07 END      
      AND LA.Lottable08 = CASE WHEN CHARINDEX('LOTTABLE08', @c_NoMixLottableList) > 0 THEN @c_Lottable08 ELSE LA.Lottable08 END      
      AND LA.Lottable09 = CASE WHEN CHARINDEX('LOTTABLE09', @c_NoMixLottableList) > 0 THEN @c_Lottable09 ELSE LA.Lottable09 END      
      AND LA.Lottable10 = CASE WHEN CHARINDEX('LOTTABLE10', @c_NoMixLottableList) > 0 THEN @c_Lottable10 ELSE LA.Lottable10 END      
      AND LA.Lottable11 = CASE WHEN CHARINDEX('LOTTABLE11', @c_NoMixLottableList) > 0 THEN @c_Lottable11 ELSE LA.Lottable11 END      
      --AND LA.Lottable01 = @c_Lottable01      
      --AND LA.Lottable06 = @c_Lottable06      
      --AND LA.Lottable07 = @c_Lottable07      
      --AND LA.Lottable08 = @c_Lottable08      
      --AND LA.Lottable09 = @c_Lottable09      
      ORDER BY L.PALogicalLoc, L.LogicalLocation, L.Loc      
      
      IF @n_debug = 1      
      BEGIN      
         SELECT '@c_NextDynPickLoc 2', @c_NextDynPickLoc      
      END      
   END      
      
   -- find loc setup in skuconfig  NJOW02   --NJOW03 move the sequence 1 step up      
   IF ISNULL(@c_NextDynPickLoc,'')=''      
   BEGIN      
      IF @c_Country IN('KR','KOR')  --NJOW11      
      BEGIN      
         SELECT TOP 1 @c_NextDynPickLoc = L.LOC      
         FROM SKUCONFIG SC (NOLOCK)      
         JOIN LOC L (NOLOCK) ON SC.Data = L.LocationCategory      
         JOIN SKUXLOC SL (NOLOCK) ON SC.Storerkey = SL.Storerkey AND SC.Sku = SL.SKU AND L.Loc = SL.Loc      
         WHERE SC.Storerkey = @c_Storerkey      
         AND SC.Sku = @c_Sku      
         AND SC.Configtype = 'DefaultDPP'      
         AND L.Facility = @c_Facility      
         --AND L.Putawayzone = @c_Putawayzone      
         AND SL.Qty - SL.QtyPicked <> 0      
         AND L.LocationType = 'DYNPPICK'      
         ORDER BY L.PALogicalLoc, L.LogicalLocation, L.Loc  --NJOW03 add PALogicalLoc sorting               
               
         IF ISNULL(@c_NextDynPickLoc,'')=''      
         BEGIN      
            SELECT TOP 1 @c_NextDynPickLoc = L.LOC      
            FROM SKUCONFIG SC (NOLOCK)      
            JOIN LOC L (NOLOCK) ON SC.Data = L.LocationCategory      
            WHERE SC.Storerkey = @c_Storerkey      
            AND SC.Sku = @c_Sku      
            AND SC.Configtype = 'DefaultDPP'      
            AND L.Facility = @c_Facility      
            --AND L.Putawayzone = @c_Putawayzone      
            AND L.LocationType = 'DYNPPICK'      
            AND NOT EXISTS(      
                    SELECT 1      
                    FROM   #DYNPICK_NON_EMPTY E      
                    WHERE  E.LOC = L.LOC
                ) AND      
                NOT EXISTS(      
                    SELECT 1      
                    FROM   #DYNPICK_TASK AS ReplenLoc      
                    WHERE  ReplenLoc.TOLOC = L.LOC      
                ) AND      
                NOT EXISTS(      
                    SELECT 1      
                    FROM   #DYNPICK_LOCASSIGNED AS DynPick      
                    WHERE  DynPick.ToLoc = L.LOC      
                )       
            ORDER BY L.PALogicalLoc, L.LogicalLocation, L.Loc  --NJOW03 add PALogicalLoc sorting               
         END               
      END      
      ELSE      
      BEGIN      
         SELECT TOP 1 @c_NextDynPickLoc = L.LOC      
         FROM SKUCONFIG SC (NOLOCK)      
         JOIN LOC L (NOLOCK) ON SC.Data = L.Loc      
         WHERE SC.Storerkey = @c_Storerkey      
         AND SC.Sku = @c_Sku      
         AND SC.Configtype = 'DefaultDPP'      
         AND L.Facility = @c_Facility      
         AND L.Putawayzone = @c_Putawayzone      
         AND L.LocationType = 'DYNPPICK'      
         ORDER BY L.PALogicalLoc, L.LogicalLocation, L.Loc  --NJOW03 add PALogicalLoc sorting      
      END      
      
      IF @n_debug = 1      
      BEGIN      
         SELECT @c_NextDynPickLoc '@c_NextDynPickLoc 3', @c_Sku '@c_Sku', @c_Storerkey '@c_Storerkey', @c_Facility '@c_Facility', @c_Putawayzone '@c_Putawayzone'      
      END      
   END      
      
    -- Assign loc with same sku, Lottables and qty available / pending move in      
   IF ISNULL(@c_NextDynPickLoc,'')=''      
   BEGIN      
       SELECT TOP 1 @c_NextDynPickLoc = L.LOC      
       FROM LOTxLOCxID LLI (NOLOCK)      
       JOIN LOTATTRIBUTE LA (NOLOCK) ON LLI.Lot = LA.Lot      
       JOIN LOC L (NOLOCK) ON LLI.LOC = L.LOC      
       WHERE L.LocationType = 'DYNPPICK'      
       AND   L.PutawayZone = @c_Putawayzone      
       AND   L.Facility = @c_Facility      
       --AND  ((LLI.Qty + LLI.PendingMoveIN) - LLI.QtyPicked) > 0      
       AND (LLI.Qty + LLI.PendingMoveIN + LLI.QtyExpected) > 0      
       AND  LLI.Storerkey = @c_Storerkey      
       AND  LLI.Sku = @c_Sku      
       AND LA.Lottable01 = CASE WHEN CHARINDEX('LOTTABLE01', @c_NoMixLottableList) > 0 THEN @c_Lottable01 ELSE LA.Lottable01 END      
       AND LA.Lottable02 = CASE WHEN CHARINDEX('LOTTABLE02', @c_NoMixLottableList) > 0 THEN @c_Lottable02 ELSE LA.Lottable02 END      
       AND LA.Lottable03 = CASE WHEN CHARINDEX('LOTTABLE03', @c_NoMixLottableList) > 0 THEN @c_Lottable03 ELSE LA.Lottable03 END      
       AND LA.Lottable06 = CASE WHEN CHARINDEX('LOTTABLE06', @c_NoMixLottableList) > 0 AND (ISNULL(LA.Lottable06,'') NOT IN ('ECOM','RETAIL')      
                                                                                            OR ISNULL(@c_Lottable06,'') NOT IN ('ECOM','RETAIL'))      
                                                                                            THEN @c_Lottable06 ELSE LA.Lottable06 END      
       AND LA.Lottable07 = CASE WHEN CHARINDEX('LOTTABLE07', @c_NoMixLottableList) > 0 THEN @c_Lottable07 ELSE LA.Lottable07 END      
       AND LA.Lottable08 = CASE WHEN CHARINDEX('LOTTABLE08', @c_NoMixLottableList) > 0 THEN @c_Lottable08 ELSE LA.Lottable08 END      
       AND LA.Lottable09 = CASE WHEN CHARINDEX('LOTTABLE09', @c_NoMixLottableList) > 0 THEN @c_Lottable09 ELSE LA.Lottable09 END      
       AND LA.Lottable10 = CASE WHEN CHARINDEX('LOTTABLE10', @c_NoMixLottableList) > 0 THEN @c_Lottable10 ELSE LA.Lottable10 END      
       AND LA.Lottable11 = CASE WHEN CHARINDEX('LOTTABLE11', @c_NoMixLottableList) > 0 THEN @c_Lottable11 ELSE LA.Lottable11 END      
       --AND LA.Lottable01 = @c_Lottable01      
       --AND LA.Lottable06 = @c_Lottable06      
       --AND LA.Lottable07 = @c_Lottable07      
       --AND LA.Lottable08 = @c_Lottable08      
       --AND LA.Lottable09 = @c_Lottable09      
       ORDER BY L.PALogicalLoc, L.LogicalLocation, L.Loc      
      
      IF @n_debug = 1      
      BEGIN      
         SELECT '@c_NextDynPickLoc 4', @c_NextDynPickLoc      
      END      
   END      
      
   -- If no location with same sku found, then assign the empty location      
   IF ISNULL(@c_NextDynPickLoc,'')=''      
   BEGIN      
      SELECT TOP 1 @c_NextDynPickLoc = L.LOC      
      FROM   LOC L (NOLOCK)      
      WHERE  L.LocationType = 'DYNPPICK'      
      AND    L.Facility = @c_Facility      
      AND    L.PutawayZone = @c_Putawayzone      
      AND    NOT EXISTS(      
                 SELECT 1      
                 FROM   #DYNPICK_NON_EMPTY E      
                 WHERE  E.LOC = L.LOC      
             ) AND      
             NOT EXISTS(      
                 SELECT 1      
                 FROM   #DYNPICK_TASK AS ReplenLoc      
                 WHERE  ReplenLoc.TOLOC = L.LOC      
             ) AND      
             NOT EXISTS(      
                 SELECT 1      
                 FROM   #DYNPICK_LOCASSIGNED AS DynPick      
                 WHERE  DynPick.ToLoc = L.LOC      
             ) AND      
             NOT EXISTS(      
                 SELECT 1 --NJOW02      
                 FROM #SKUCONFIG_DPP      
           WHERE #SKUCONFIG_DPP.Loc = L.Loc)      
      ORDER BY L.PALogicalLoc, L.LogicalLocation, L.Loc      
      
      IF @n_debug = 1      
      BEGIN      
         SELECT '@c_NextDynPickLoc 5', @c_NextDynPickLoc      
      END      
   END      
      
   IF @n_debug = 1      
      SELECT '@c_NextDynPickLoc', @c_NextDynPickLoc      
      
   -- Terminate. Can't find any dynamic location      
   IF ISNULL(@c_NextDynPickLoc,'')=''      
   BEGIN      
      SELECT @n_continue = 3      
      SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81140      
      SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Dynamic Pick Location Not Setup / Not enough Dynamic Pick Location. (ispRLWAV03)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '      
      GOTO RETURN_SP      
   END      
      
   SELECT @c_ToLoc = @c_NextDynPickLoc      
      
   --Insert current location assigned      
   IF NOT EXISTS (SELECT 1 FROM #DYNPICK_LOCASSIGNED      
                  WHERE Storerkey = @c_Storerkey      
                  AND Sku = @c_Sku      
                  AND ToLoc = @c_ToLoc      
                  AND Lot = @c_Lot)      
   BEGIN      
      INSERT INTO #DYNPICK_LOCASSIGNED (Storerkey, Sku, ToLoc, LocationType, Lot)      
      VALUES (@c_Storerkey, @c_Sku, @c_Toloc, 'DYNPPICK', @c_Lot )      
   END      
      
   IF @c_CallSource = 'ASSIGNDPPTOPICK'      
      GOTO RTN_ASSIGNDPPTOPICK      
END --sp end 

GO