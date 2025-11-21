SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/  
/* Stored Procedure: ispTransferAllocation                                 */  
/* Creation Date: 22-APR-2014                                              */  
/* Copyright: IDS                                                          */  
/* Written by: YTWan                                                       */  
/*                                                                         */  
/* Purpose: SOS#304838 - ANF - Allocation strategy for Transfer            */  
/*        : Assumption: fromsku = tosku                                    */  
/* Called By: Job Scheduler                                                */  
/*                                                                         */  
/*                                                                         */  
/* PVCS Version: 2.4                                                       */  
/*                                                                         */  
/* Version: 5.4                                                            */  
/*                                                                         */  
/* Data Modifications:                                                     */  
/*                                                                         */  
/* Updates:                                                                */  
/* Date         Author  Ver   Purposes                                     */  
/* 04-SEP-2014  YTWan   1.1   Enhancement & fixed.(Wan01)                  */  
/* 10-SEP-2014  YTWan   1.2   Fixed. (Wan02)                               */  
/* 12-SEP-2014  YTWan   1.3   Fixed. Update to Transmitflag to in progress */  
/*                            (Wan03)                                      */  
/* 16-SEP-2014  Chee    1.4   Fixed. Error if failed to find DPP location  */  
/*                            for Bulk allocation, change alert message,   */  
/*                            Send email if error                          */  
/*                            Rerun error transferkey (Chee01)             */  
/* 25-SPE-2014  YTWan   1.5   IF there is qty in 'HOLD_001', do not auto   */  
/*                            finalize.(Wan03)                             */  
/* 02-DEC-2014  Leong   1.6   SOS# 326708 - Revise locking loc.            */  
/* 23-DEC-2014  Leong   1.6   SOS# 328454 - Revise @tError table.          */  
/* 09-APR-2015  CSCHONG 1.7   New lottable 06 to 15 (CS01)                 */  
/* 21-APR-2015  YTWan   1.7   SOS#338521 - Enhancement on Transfer         */  
/*                            Allocation (Re-allocate). (Wan05)            */  
/* 11-Jun-2015  Ung     1.8   SOS337296 DPP PendingMoveIn booking by ID    */  
/* 15-SEP-2016  NJOW01  1.9   WMS-318 Taskdetail.systemqty put 0           */  
/* 18-MAY-2018  NJOW02  2.0   WMS-5028 change task toloc calculation       */  
/* 30-OCT-2018  NJOW03  2.1   Fix condition to avoid HK china logic        */  
/* 01-JUL-2019  WLCHOOI 2.2   WMS-9279 Add new stage loc                   */  
/*                            Update Taskdetailkey back to RFPutaway       */  
/*                            (CN) (WL01)                                  */
/* 15-Oct-2020  WLChooi 2.3   Remove Traceinfo Insertion (WL02)            */ 
/* 04-NOV-2020  Wan06   2.4   WMS-15612 - ANF - CR on Transfer Allocation  */  
/* 22-02-2021   Wan07   2.5   WMS-16094 - [CN] ANFQHW_WMS_TransferAllocation*/
/*                            - Add @c_Facility when call Sub SP           */
/***************************************************************************/  
  
CREATE PROC [dbo].[ispTransferAllocation](  
   @c_FromStorerkey  NVARCHAR(10) = ''    --(Wan05)  
,  @c_TransferKey    NVARCHAR(10) = ''          --(Wan05) Std pass by Dynamic RCM Menu  
,  @b_Success        INT          = 1   OUTPUT  --(Wan05) Std pass by Dynamic RCM Menu  
,  @n_Err            INT          = 0   OUTPUT  --(Wan05) Std pass by Dynamic RCM Menu  
,  @c_ErrMsg         NVARCHAR(250)= ''  OUTPUT  --(Wan05) Std pass by Dynamic RCM Menu  
,  @c_Code           NVARCHAR(30) = ''          --(Wan05) Std pass by Dynamic RCM Menu  
,  @c_Facility       NVARCHAR(5)  = ''          --(Wan06)   
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @b_Debug              INT  
         , @n_Cnt                INT  
         , @n_Continue           INT  
         , @n_StartTCount        INT  
--         , @b_Success            INT    --(Wan05)  
--         , @n_Err                INT    --(Wan05)  
--         , @c_ErrMsg             NVARCHAR(250)--(Wan05)   
  
   DECLARE @c_Transmitlogkey     NVARCHAR(10)  
--         , @c_TransferKey        NVARCHAR(12) --(Wan05)  
         , @c_ReAllocTrfkey NVARCHAR(10)   --(Wan05)  
         , @c_TransferType       NVARCHAR(10)  
         , @c_TransferStatus     NVARCHAR(10)  
         , @c_Transmitflag       NVARCHAR(10)  
         , @c_TransmitBatch      NVARCHAR(10)   --(Wan01)  
         , @c_TransferLineNumber NVARCHAR(5)  
         , @c_NewTransferLineNo  NVARCHAR(5)  
  
         , @c_FromFacility       NVARCHAR(5)  
         , @c_FromSku            NVARCHAR(15)  
         , @c_FromLot            NVARCHAR(10)  
         , @c_FromLoc            NVARCHAR(10)  
         , @c_FromID             NVARCHAR(18)  
         , @c_FromPackkey        NVARCHAR(10)  
         , @c_FromUOM            NVARCHAR(10)  
         , @c_ToPackkey          NVARCHAR(10)  
         , @c_ToUOM              NVARCHAR(10)  
         , @c_ToStorerkey        NVARCHAR(15)  
         , @c_ToSku              NVARCHAR(20)  
         , @c_ToID               NVARCHAR(18)  
         , @c_Lottable01         NVARCHAR(18)  
         , @c_FromLottable02     NVARCHAR(18)  
         , @c_ToLottable02       NVARCHAR(18)  
         , @c_Lottable03         NVARCHAR(18)  
         , @dt_Lottable04        DATETIME  
         , @dt_Lottable05        DATETIME  
         , @c_Lottable06         NVARCHAR(30)           --(CS01)  
         , @c_Lottable07         NVARCHAR(30)           --(CS01)  
         , @c_Lottable08         NVARCHAR(30)           --(CS01)  
         , @c_Lottable09         NVARCHAR(30)           --(CS01)  
         , @c_Lottable10         NVARCHAR(30)           --(CS01)  
         , @c_Lottable11         NVARCHAR(30)           --(CS01)  
         , @c_Lottable12         NVARCHAR(30)           --(CS01)  
         , @dt_Lottable13        DATETIME               --(CS01)  
         , @dt_Lottable14        DATETIME               --(CS01)  
         , @dt_Lottable15        DATETIME               --(CS01)  
         , @c_UCCNo              NVARCHAR(20)  
  
         , @n_FromQty            INT  
         , @n_ToQty              INT  
         , @n_QtyRequired        INT  
         , @n_QtyAvail           INT  
         , @n_QtyToTake          INT  
         , @n_QtyToMove          INT  
         , @n_OpenQty            INT  
  
         , @c_PrepackIndicator   NVARCHAR(30)  
  
         , @c_UserID             NVARCHAR(30)  
         , @dt_today             DATETIME  
  
         , @c_TaskDetailKey      NVARCHAR(10)  
         , @c_Areakey            NVARCHAR(10)  
         , @c_MoveToLoc          NVARCHAR(10)  
         , @c_FinalToLoc         NVARCHAR(10)  
         , @c_LogicalLoc         NVARCHAR(10)  
         , @c_LogicalMoveToLoc   NVARCHAR(10)  
         , @c_SourceKey          NVARCHAR(30)  
  
         , @c_PostFinalizeTransferSP   NVARCHAR(10)  
         , @c_AutoFinalizeShortTrf     NVARCHAR(10)  
         , @c_AlertMessage             NVARCHAR(255)  
  
         -- (Chee01)  
         , @cRecipients            NVARCHAR(MAX)  
         , @cBody                  NVARCHAR(MAX)  
         , @cSubject               NVARCHAR(255)  
         , @c_Country              NVARCHAR(10) --NJOW02  
         --, @c_Putawayzone          NVARCHAR(10) --NJOW02  
         , @n_PABookingKey         INT = 0 --WL01  
         , @dt_TimeOut             DATETIME --WL01  
         , @b_DummyLLI             INT = 0  --WL01  

         , @c_TransferAlloc_SP      NVARCHAR(30)   = ''  --(Wan06)
         , @c_SQL                   NVARCHAR(2000) = ''  --(Wan06)
         , @c_SQLParms              NVARCHAR(2000) = ''  --(Wan06)

   --(Wan06) Call Transfer Allocation Custom SP if setup - START
   IF @c_Facility IS NULL SET @c_Facility = ''

   IF @c_TransferKey <> ''
   BEGIN
      SELECT @c_Facility = TF.Facility
      FROM TRANSFER TF WITH (NOLOCK)
      WHERE TF.TransferKey = @c_TransferKey
   END

   SELECT @c_TransferAlloc_SP = dbo.fnc_GetRight(@c_Facility, @c_FromStorerkey, '', 'TransferAlloc_SP')

   IF @c_TransferAlloc_SP NOT IN ('0', '', 'ispTransferAllocation')
   BEGIN
      IF EXISTS (SELECT 1 FROM Sys.Objects WHERE Name = @c_TransferAlloc_SP AND Type = 'P')
      BEGIN
         
         SET @b_Success = 1
         SET @c_SQL = N'EXEC ' + @c_TransferAlloc_SP
               +'  @c_FromStorerkey = @c_FromStorerkey'
               +', @c_TransferKey   = @c_TransferKey'   
               +', @b_Success       = @b_Success        OUTPUT'
               +', @n_Err           = @n_Err            OUTPUT'
               +', @c_ErrMsg        = @c_ErrMsg         OUTPUT'
               +', @c_Code          = @c_Code'
               +', @c_Facility      = @c_Facility'

         SET @c_SQLParms= N' @c_FromStorerkey  NVARCHAR(10)'    
                        +',  @c_TransferKey    NVARCHAR(10)'         
                        +',  @b_Success        INT             OUTPUT'
                        +',  @n_Err            INT             OUTPUT'
                        +',  @c_ErrMsg         NVARCHAR(250)   OUTPUT'
                        +',  @c_Code           NVARCHAR(30)'  
                        +',  @c_Facility       NVARCHAR(30)'                          
        
         EXEC sp_ExecuteSQL  @c_SQL
                           , @c_SQLParms
                           , @c_FromStorerkey  
                           , @c_TransferKey     
                           , @b_Success        OUTPUT 
                           , @n_Err            OUTPUT
                           , @c_ErrMsg         OUTPUT
                           , @c_Code 
                           , @c_Facility         

         RETURN
      END
   END
   -- --(Wan06) Call Transfer Allocation Custom SP if setup - END
  
   -- SOS# 328454 (Start)  
   -- -- (Chee01)  
   -- DECLARE @tError TABLE(  
   --    ErrMsg  NVARCHAR(250)  
   -- )  
   IF ISNULL(OBJECT_ID('tempdb..#Error'),'') <> ''  
   BEGIN  
      DROP TABLE #Error  
   END  
   CREATE TABLE #Error ( ErrMsg NVARCHAR(250) NULL )  
   -- SOS# 328454 (End)  
  
   SET @b_Debug = 0  
   SET @n_Continue = 1  
   SET @n_StartTCount = @@TRANCOUNT  
  
   SET @c_UserID = SUSER_NAME()  
   SET @dt_today = GETDATE()  
  
   --NJOW02  
   SELECT @c_Country = NSQLValue  
   FROM NSQLCONFIG (NOLOCK)  
   WHERE Configkey = 'Country'  
  
   --(Wan04) - START  
   WHILE @@TRANCOUNT > 0  
   BEGIN  
      COMMIT TRAN  
   END  
  
   --(Wan05) - START  
  
   SET @c_ReAllocTrfkey = @c_Transferkey  
  
   SET @c_Transferkey = ''  
   IF @c_ReAllocTrfkey <> ''  
   BEGIN  
      --SET @c_ErrMsg = 'Transfer Re-allocated'  
      IF EXISTS ( SELECT 1  
                  FROM TRANSFER WITH (NOLOCK)   
                  WHERE Transferkey = @c_ReAllocTrfkey  
                  AND Status NOT IN ('0', '3')  
                )  
      BEGIN  
         SET @n_continue = 3      
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
         SET @n_err    = 81000   -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
         SET @c_errmsg = 'Transfer is not allowed to re-allocate. (ispTransferAllocation)'  
         GOTO QUIT_SP             
      END  
  
      BEGIN TRAN  
      UPDATE TRANSMITLOG3 WITH (ROWLOCK)  
      SET Trafficcop = NULL  
         ,Transmitflag = '0'  
         ,Transmitbatch = '0'  
      FROM TRANSMITLOG3 TL3    
      JOIN TRANSFER     TF  WITH (NOLOCK) ON (TL3.Key1 = TF.TransferKey)  
                                          AND(TL3.Key3 = TF.FromStorerkey)  
      WHERE TL3.TABLENAME = 'ANFTranAdd'  
      AND TF.Transferkey = @c_ReAllocTrfkey  
      AND TL3.Transmitflag  <= '9'  
      AND TF.Status < '9'  
  
      SET @n_err = @@ERROR    
  
      IF @n_err <> 0       
      BEGIN    
         SET @n_continue = 3      
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
         SET @n_err = 81001   -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UPDATE TRANSMITLOG3 Failed. (ispTransferAllocation)'   
                      + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
  
         ROLLBACK TRAN    
         GOTO QUIT_SP    
      END  
  
      SELECT @c_FromStorerkey = TF.FromStorerkey  
      FROM TRANSFER TF WITH (NOLOCK)  
      WHERE TF.Transferkey = @c_ReAllocTrfkey  
   END  
   --(Wan05) - END  
     
   SET @c_AutoFinalizeShortTrf = '0'  
   SELECT @c_AutoFinalizeShortTrf = ISNULL(RTRIM(SValue),'')  
   FROM STORERCONFIG WITH (NOLOCK)  
   WHERE Storerkey = @c_FromStorerkey  
   AND Configkey = 'AutoFinalizeShortTrf'  
  
   DECLARE CUR_ANFTRAN CURSOR LOCAL FORWARD_ONLY STATIC READ_ONLY FOR  
   SELECT Transmitlogkey= TL3.Transmitlogkey  
        , Transferkey   = TL3.Key1  
        , TransferType  = TF.Type  
        , Facility      = TF.Facility  
   FROM TRANSMITLOG3 TL3 WITH (NOLOCK)  
   JOIN TRANSFER     TF  WITH (NOLOCK) ON (TL3.Key1 = TF.TransferKey)  
                                       AND(TL3.Key3 = TF.FromStorerkey)  
   WHERE TL3.TABLENAME = 'ANFTranAdd'  
   AND TL3.Key3 = @c_FromStorerkey  
   AND TL3.Key1 = CASE WHEN @c_ReAllocTrfkey = '' THEN TL3.Key1 ELSE @c_ReAllocTrfkey END  --(Wan05)  
   -- Rerun error transferkey (Chee01)  
--   AND TL3.Transmitflag  < '5'  
--   AND TL3.transmitbatch < '4'  
   AND TL3.Transmitflag  <= '5'  
   AND TF.Status < '9'   
   ORDER BY TL3.Transmitlogkey  
  
   OPEN CUR_ANFTRAN  
  
   FETCH NEXT FROM CUR_ANFTRAN INTO @c_Transmitlogkey  
                                 ,  @c_Transferkey  
                                 ,  @c_TransferType  
                                 ,  @c_FromFacility  
  
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
      SET @n_Continue = 1              --(Wan01)  
      SET @b_Success= 1  
      SET @n_Err    = 0  
      SET @c_ErrMsg = ''  
  
      BEGIN TRAN  
      IF @c_TransferType NOT Like '%DTC%'  
      BEGIN  
         SET @c_Transmitflag = 'IGNOR'  
         SET @c_TransmitBatch= '0'  --(Wan01)  
         GOTO NEXT_TRF  
      END  
  
      SET @c_TransferStatus = '3'  
      SET @c_Transmitflag   = '9'   --(Wan01)  
      SET @c_TransmitBatch  = '4'   --(Wan01)  
  
      DECLARE CUR_TFRDET CURSOR LOCAL FORWARD_ONLY STATIC READ_ONLY FOR  
      SELECT TransferLineNumber = TD.TransferLineNumber  
           , FromSku    = TD.FromSku  
           , FromQty    = TD.FromQty  
           , FromLottable02 = ISNULL(RTRIM(TD.Lottable02),'')  
           , ToStorereky = TD.ToStorerkey  
           , ToSku       = TD.ToSku  
           , ToLottable02 = ISNULL(RTRIM(TD.ToLottable02),'')  
      FROM TRANSFERDETAIL TD  WITH (NOLOCK)  
      JOIN SKU            SKU WITH (NOLOCK) ON (TD.ToStorerkey = SKU.Storerkey) AND (TD.ToSku = SKU.Sku)  
      WHERE TD.Transferkey = @c_Transferkey  
      --AND   TD.[Status] < '9'     --(Wan05)  
      AND   TD.[Status] = '0'       --(Wan05)  
      AND   TD.FromLot  = ''        --(Wan05)    
      AND   TD.Fromid   <> 'HOLD_001' --(Wan05)   
      AND   TD.FromQty  > 0           --(Wan05)   
  
      OPEN CUR_TFRDET  
  
      FETCH NEXT FROM CUR_TFRDET INTO  @c_TransferLineNumber  
                                    ,  @c_FromSku  
                                    ,  @n_FromQty  
                                    ,  @c_FromLottable02  
                                    ,  @c_ToStorerkey  
                                    ,  @c_ToSku  
                                    ,  @c_ToLottable02  
  
      WHILE @@FETCH_STATUS <> -1  
      BEGIN  
         SET @n_QtyRequired = @n_FromQty  
         SET @c_TransferStatus = '9'  
  
         SELECT @c_FromPackkey = PACK.Packkey  
               ,@c_FromUOM     = PACK.PackUOM3  
         FROM SKU  WITH (NOLOCK)  
         JOIN PACK WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)  
         WHERE SKU.Storerkey = @c_FromStorerkey  
         AND   SKU.Sku       = @c_FromSku  
  
         SELECT @c_ToPackkey = PACK.Packkey  
               ,@c_ToUOM     = PACK.PackUOM3  
               ,@c_PrepackIndicator = ISNULL(RTRIM(SKU.PrepackIndicator),'')  
         FROM SKU WITH (NOLOCK)  
         JOIN PACK WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)  
         WHERE SKU.Storerkey = @c_ToStorerkey  
         AND   SKU.Sku       = @c_ToSku  
  
         WHILE @n_FromQty > 0  
         BEGIN  
            SET @n_QtyToTake = 0  
            SET @n_QtyAvail=0  
            SET @c_FromLot = ''  
            SET @c_FromLoc = ''  
            SET @c_FromLoc = ''  
            SET @c_Lottable01 = ''  
            SET @c_Lottable03 = ''  
            SET @dt_Lottable04 = NULL  
            SET @dt_Lottable05 = NULL  
            SET @c_LogicalLoc  = ''  
            SET @c_UCCNo       = ''       --(Wan01)  
  
            /*CS01 Start*/  
            SET @c_Lottable06 = ''  
            SET @c_Lottable07 = ''  
            SET @c_Lottable08 = ''  
            SET @c_Lottable09 = ''  
            SET @c_Lottable10 = ''  
            SET @c_Lottable11 = ''  
            SET @c_Lottable12 = ''  
            SET @dt_Lottable13 = NULL  
            SET @dt_Lottable14 = NULL  
            SET @dt_Lottable15 = NULL  
            /*CS01 End*/  
  
            SET @c_TransferStatus = '0'  
            --IF EXISTS ( SELECT 1 FROM STORERCONFIG WITH (NOLOCK)  
            --            WHERE Storerkey = @c_FromStorerkey AND Configkey = 'AutoFinalizeShortTrf'  
            --            AND SValue= '1' )  
            IF @c_AutoFinalizeShortTrf = '1'  
            BEGIN  
               SET @c_TransferStatus = '9'    --- Auto Finalize Short inventory  
            END  
  
            SELECT TOP 1  
                   @c_FromLot = LLI.Lot  
                  ,@c_FromLoc = LLI.Loc  
                  ,@c_FromID  = LLI.ID  
                  -- Do not allocate from partial allocated UCC - (START)  
                  ,@n_QtyAvail   = CASE WHEN ISNULL(RTRIM(UCC.Status),'') = 1 THEN UCC.Qty ELSE (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) END  
                  ,@c_UCCNo      = CASE WHEN ISNULL(RTRIM(UCC.Status),'') = 1 THEN ISNULL(RTRIM(UCC.UCCNo),'') ELSE '' END  
                  -- Do not allocate from partial allocated UCC - ( END)  
                  ,@c_Lottable01 = ISNULL(RTRIM(LA.Lottable01),'')  
                  ,@c_Lottable03 = ISNULL(RTRIM(LA.Lottable03),'')  
             ,@dt_Lottable04= LA.Lottable04  
                  ,@dt_Lottable05= LA.Lottable05  
                  /*CS01 Start*/  
                  ,@c_Lottable06 = ISNULL(RTRIM(LA.Lottable06),'')  
                  ,@c_Lottable07 = ISNULL(RTRIM(LA.Lottable07),'')  
                  ,@c_Lottable08 = ISNULL(RTRIM(LA.Lottable08),'')  
                  ,@c_Lottable09 = ISNULL(RTRIM(LA.Lottable09),'')  
                  ,@c_Lottable10 = ISNULL(RTRIM(LA.Lottable10),'')  
                  ,@c_Lottable11 = ISNULL(RTRIM(LA.Lottable11),'')  
                  ,@c_Lottable12 = ISNULL(RTRIM(LA.Lottable12),'')  
                  ,@dt_Lottable13= LA.Lottable13  
                  ,@dt_Lottable14= LA.Lottable14  
                  ,@dt_Lottable15= LA.Lottable15  
                  /*CS01 end*/  
                  ,@c_LogicalLoc = ISNULL(RTRIM(LOC.LogicalLocation),'')  
  
            FROM LOT          LOT WITH (NOLOCK)  
            JOIN LOTATTRIBUTE LA  WITH (NOLOCK) ON (LOT.Lot = LA.Lot)  
            JOIN LOTxLOCxID   LLI WITH (NOLOCK) ON (LOT.Lot = LLI.Lot)  
            JOIN LOC          LOC WITH (NOLOCK) ON (LLI.Loc = LOC.LOC)  
            JOIN ID           ID  WITH (NOLOCK) ON (LLI.ID  = ID.ID)  
  
            LEFT JOIN UCC     UCC WITH (NOLOCK) ON (LLI.Lot = UCC.Lot)  
                                                AND(LLI.Loc = UCC.Loc)  
                                                AND(LLI.ID  = UCC.ID)  
                                              --  AND(UCC.Status= '1')        -- Do not allocate from partial allocated UCC  
            LEFT JOIN (SELECT LOTATTRIBUTE.Storerkey  
                                    , LOTATTRIBUTE.Sku  
                                    , LOC.LocationType  
                                    , LocQtyAvail = SUM(LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked )  
                                FROM LOTATTRIBUTE  WITH (NOLOCK)  
                                JOIN LOTxLOCxID    WITH (NOLOCK)  ON (LOTATTRIBUTE.Lot = LOTxLOCxID.Lot)  
                                JOIN LOC           WITH (NOLOCK)  ON (LOTxLOCxID.Loc = LOC.Loc)  
                               WHERE LOTATTRIBUTE.Storerkey = @c_FromStorerkey  
                                AND   LOTATTRIBUTE.Sku       = @c_FromSku  
                                AND   LOTATTRIBUTE.Lottable02= @c_fromLottable02  
                                AND   LOC.Facility           = @c_fromFacility  
                                AND   LocationType           = 'DYNPPICK'  
                                GROUP BY LOTATTRIBUTE.Storerkey  
                                       , LOTATTRIBUTE.Sku  
                                       , LOC.LocationType ) AS LINV  
                                ON (LINV.Storerkey = LOT.Storerkey)  
                                AND(LINV.Sku = LOT.Sku)  
                                AND(LINV.LocationType = LOC.LocationType)  
            WHERE LOT.Storerkey = @c_FromStorerkey  
            AND   LOT.Sku       = @c_FromSku  
            AND   LOC.Facility  = @c_FromFacility  
            AND   LA.Lottable02 = @c_FromLottable02  
            AND   LOT.Qty - LOT.QtyAllocated - LOT.QtyPicked - LOT.QtyPreAllocated > 0  
            AND   LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked > 0  
            AND   LOT.Status = 'OK'  
            AND   LOC.Status = 'OK'  
            AND   LOC.LocationFlag NOT IN ( 'HOLD', 'DAMAGE' )  
            AND   ID.Status  = 'OK'  
            -- Do not allocate from partial allocated UCC - (START)  
            AND   (UCC.Status IN ( '1','6') OR UCCNo IS NULL)  
            ORDER BY CASE WHEN LOC.LocationType = 'DYNPPICK' AND ISNULL(LINV.LocQtyAvail,0) >= @n_FromQty THEN 10  
                          WHEN LOC.LocationType <>'DYNPPICK' AND ISNULL(RTRIM(UCC.Status),'') = 1 AND UCC.Qty >=@n_FromQty THEN 20  
                          WHEN LOC.LocationType <>'DYNPPICK' AND ISNULL(RTRIM(UCC.Status),'') = 1 AND UCC.Qty < @n_FromQty THEN 30  
                          ELSE 40 END  
                  ,  CASE WHEN ISNULL(RTRIM(UCC.Status),'') = 1 AND UCC.Qty >=@n_FromQty  
                          THEN UCC.Qty  
                          WHEN ISNULL(RTRIM(UCC.Status),'') = 1 AND UCC.Qty < @n_FromQty  
                          THEN UCC.Qty * -1  
                          ELSE (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) END  
--                  ,  ISNULL(UCC.Qty, LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked)  
             -- Do not allocate from partial allocated UCC - (END)  
  
            IF @c_FromLot = ''  
            BEGIN  
               GOTO NEXT_TRFDET  
            END  
  
            IF @n_QtyRequired >= @n_QtyAvail  
            BEGIN  
               SET @n_QtyToTake = @n_QtyAvail  
            END  
            ELSE  
            BEGIN  
               SET @n_QtyToTake = @n_QtyRequired  
            END  
  
            SET @n_QtyRequired = @n_QtyRequired - @n_QtyToTake  
  
            SET @c_TransferStatus = CASE WHEN @c_UCCNo = '' THEN '9' ELSE '3' END   --(Wan05)  
            SET @n_QtyToMove = CASE WHEN @c_UCCNo = '' THEN @n_QtyToTake ELSE @n_QtyAvail END  
            SET @c_Toid = @c_Fromid  
  
            IF @n_QtyToTake > 0  
            BEGIN  
               -- Find MoveToLoc (START)  
               SET @c_MoveToLoc = ''  
               SET @c_FinalToLoc= ''  
                    
               SELECT @c_MoveToLoc = ISNULL(RTRIM(Short),'')  
               FROM CODELKUP WITH (NOLOCK)  
               WHERE ListName = 'WCSROUTE'  
               AND   Code = @c_PrepackIndicator  
  
               SET @c_FinalToLoc = @c_MoveToLoc  
                 
               --NJOW02 -S                    
               IF EXISTS(SELECT 1 FROM CODELKUP (NOLOCK) WHERE Listname = 'ANFPUTZONE') AND ISNULL(@c_FinalToLoc,'') = ''  
               BEGIN                      
                  SELECT TOP 1 @c_FinalToLoc = LOC.Loc  
                  FROM LOTXLOCXID LLI (NOLOCK)    
                  JOIN SKU (NOLOCK) ON LLI.Storerkey = SKU.Storerkey AND LLI.Sku = SKU.Sku  
                  JOIN CODELKUP CL (NOLOCK) ON SKU.Putawayzone = CL.Short  
                  JOIN LOC (NOLOCK) ON  CL.Long = LOC.Putawayzone AND LLI.Loc = LOC.Loc  
                  WHERE LLI.Storerkey = @c_FromStorerkey  
                  AND LLI.Sku = @c_FromSku  
                  AND CL.Listname = 'ANFPUTZONE'  
                  AND LOC.LocationType = 'DYNPPICK'  
                  AND LOC.Facility = @c_fromFacility  
                  GROUP BY CL.Code, LOC.LogicalLocation, LOC.Loc  
                  HAVING SUM((LLI.Qty + LLI.PendingMoveIN + LLI.QtyExpected) - LLI.QtyPicked) > 0  
                  ORDER BY CL.Code, LOC.LogicalLocation DESC, LOC.Loc DESC  
                    
                  IF ISNULL(@c_FinalToLoc,'') = ''  
                  BEGIN  
                     SELECT TOP 1 @c_FinalToLoc = LOC.Loc  
                     FROM SKU (NOLOCK)   
                     JOIN CODELKUP CL (NOLOCK) ON SKU.Putawayzone = CL.Short  
                     JOIN LOC (NOLOCK) ON  CL.Long = LOC.Putawayzone   
                     LEFT JOIN LOTXLOCXID LLI (NOLOCK) ON LOC.Loc = LLI.Loc    
                     WHERE SKU.Storerkey = @c_FromStorerkey  
                     AND SKU.Sku = @c_FromSku  
                     AND CL.Listname = 'ANFPUTZONE'  
                     AND LOC.LocationType = 'DYNPPICK'  
                     AND LOC.Facility = @c_fromFacility  
                     GROUP BY CL.Code, LOC.LogicalLocation, LOC.Loc  
                     HAVING SUM((ISNULL(LLI.Qty,0) + ISNULL(LLI.PendingMoveIN,0) + ISNULL(LLI.QtyExpected,0)) - ISNULL(LLI.QtyPicked,0)) = 0  
                     ORDER BY CL.Code, LOC.LogicalLocation, LOC.Loc  
                  END     
                    
                  IF ISNULL(@c_FinalToLoc,'') <> ''    
                     SET @c_MoveToLoc = @c_FinalToLoc             
               END --NJOW02 -E  
  
               IF @c_PrepackIndicator <> 'Y' AND LEN(@c_UCCNo) > 0  
               BEGIN  
                  /*  
                  --NJOW02 S  
                SELECT @c_Putawayzone = Putawayzone  
                  FROM SKU (NOLOCK)  
                  WHERE SKU.Storerkey = @c_FromStorerkey  
                  AND SKU.Sku = @c_FromSku                     
                    
                  IF ISNULL(@c_FinalToLoc,'') = ''  
                  BEGIN  
                     SELECT TOP 1 @c_FinalToLoc = LLI.Loc  
                     FROM LOTXLOCXID LLI (NOLOCK)  
                     JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc  
                     WHERE LLI.Storerkey = @c_FromStorerkey  
                     AND LLI.Sku = @c_FromSku  
                     AND LOC.LocationType = 'DYNPPICK'  
                     AND (LLI.Qty + LLI.PendingMoveIn) > 0  
                     AND LOC.Facility = @c_FromFacility  
                     --AND LOC.PutawayZone = @c_Putawayzone  
                     AND LOC.PickZone IN('1','2','3')  
                     AND LOC.Status = 'OK'  
                     AND LOC.PutawayZone IN ('AF01M','AF01F','AF02M','AF02F','AF02AF','AF03M','AF03F','HO03F')  
                     AND LOC.LocationCategory = 'MEZZANINE'  
                     ORDER BY LOC.LogicalLocation, LOC.Loc  
                  END  
                    
                  IF ISNULL(@c_FinalToLoc,'') = ''  
                  BEGIN                     
                     SELECT TOP 1 @c_FinalToLoc = LOC.Loc   
                     FROM LOC (NOLOCK)   
                     LEFT JOIN (SELECT LLI.Loc, SUM(LLI.Qty + LLI.PendingMoveIn) AS QtyAvailable   
                                FROM LOTXLOCXID LLI (NOLOCK)  
                                JOIN LOC (NOLOCK) ON LLI.Loc = LLI.Loc                                  
                                WHERE LLI.Storerkey = @c_FromStorerkey  
                                AND LLI.Qty + LLI.PendingMoveIn > 0  
                                AND LOC.Putawayzone = @c_Putawayzone                                 
                                AND LOC.Facility = @c_FromFacility  
                                GROUP BY LLI.Loc) Inv ON LOC.Loc = Inv.Loc  
                     WHERE LOC.Facility = @c_FromFacility  
                     AND LOC.Putawayzone = @c_Putawayzone  
                     AND ISNULL(Inv.QtyAvailable,0) = 0             
                     AND LOC.LocationType = 'DYNPPICK'   
                     AND LOC.PickZone IN('1','2','3')  
                     AND LOC.Status = 'OK'  
                     AND LOC.PutawayZone IN ('AF01M','AF01F','AF02M','AF02F','AF02AF','AF03M','AF03F','HO03F')  
                     AND LOC.LocationCategory = 'MEZZANINE'  
                     ORDER BY LOC.LogicalLocation, LOC.Loc   
                  END  
                  --NJOW02 E  
                  */                                            
  
                  IF ISNULL(@c_Country,'') <> 'CN'  
                    OR NOT EXISTS(SELECT 1 FROM CODELKUP (NOLOCK) WHERE Listname = 'ANFPUTZONE') --NJOW02 NJOW03  
                  BEGIN                                     
                     EXEC @n_Err = [dbo].[nspRDTPASTD]  
                                   @c_userid          = @c_UserID  
                                 , @c_Storerkey       = @c_FromStorerkey  
                                 , @c_lot             = @c_FromLot  
                                 , @c_sku             = @c_FromSku  
                                 , @c_id              = @c_FromID  
                                 , @c_fromloc         = @c_FromLoc  
                                 , @n_qty             = @n_QtyToMove  
                                 , @c_uom             = '' -- not used  
                                 , @c_packkey         = '' -- optional, if pass-in SKU  
                                 , @n_putawaycapacity = 0  
                                 , @c_final_toloc     = @c_FinalToLoc OUTPUT  
                       
                     IF @n_Err <> 0  
                     BEGIN  
                        SET @n_Continue = 3  
                        SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)  
                        SET @n_Err = 81025  
                     SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Error Executing Putaway Strategy nspRDTPASTD (ispTransferAllocation)'  
                                     + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
                        GOTO NEXT_TRF  
                     END  
                  END                       
  
                  -- Error if failed to find DPP location for Bulk allocation (Chee01)  
                  IF ISNULL(@c_FinalToLoc, '') = ''  
                  BEGIN  
                     SET @n_Continue = 3  
                     SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)  
                     SET @n_Err = 81021  
                     SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Failed to find DPP location for Bulk allocation. (ispTransferAllocation)'  
                                  + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
                     GOTO NEXT_TRF  
                  END  
  
                  IF @c_MoveToLoc = ''  
                  BEGIN  
                     SET @c_MoveToLoc = @c_FinalToLoc  
                  END  
  
                  --WL01 START   
                  IF(@n_QtyToTake = @n_QtyToMove) AND (ISNULL(@c_Country,'') = 'CN') --If Transfer qty = Taskdetail.qty (UCC.qty) - This logic only apply to CN  
                  BEGIN  
                     IF EXISTS (SELECT 1 FROM LOC (NOLOCK) WHERE LOC = 'TRBKST')  
                     BEGIN  
                        SET @c_FinalToLoc = 'TRBKST'    
                        SET @c_MoveToLoc = @c_FinalToLoc  
                     END  
                     ELSE  
                     BEGIN  
                        SET @n_Continue = 3  
                        SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)  
                        SET @n_Err = 81075  
                        SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Location : TRBKST Not Found in LOC Table (ispTransferAllocation)'  
                                     + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
                        GOTO NEXT_TRF  
                     END   
                  END  
                  --WL01 END  
                  SET @dt_TimeOut = GETDATE()  
                  
                  --WL02 START
                  --INSERT INTO TRACEINFO (Tracename, [TimeOut], Col1, Col2, Col3, Col4, Col5)  
                  --SELECT 'ispTransferAllocation', @dt_TimeOut, @c_Country,@c_FinalToLoc,'','',''  
                  --WL02 END
                  
                  -- SOS# 326708 (Start)  
                  --IF ISNULL(@c_Country,'') <> 'CN' AND     --WL01  
                  IF @c_UCCNo <> '' AND EXISTS ( SELECT 1  
                                                 FROM LOC WITH (NOLOCK)  
                                                 WHERE Loc = @c_FinalToLoc  
                                                 AND LocationType = 'DYNPPICK'  
                                                 )  
                  BEGIN  
                     DECLARE @cToID NVARCHAR(18)                
                     SET @cToID = RIGHT( RTRIM( @c_UCCNo), 18)     
                       
                     --WL01 Start  
                     IF ISNULL(@c_Country,'') = 'CN'  
                     BEGIN  
                        SET @b_DummyLLI = 0  
  
                        --Copy from getting taskdetail.toid  
                        SELECT @cToID = CASE WHEN LocationType ='DYNPPICK' AND @c_UCCNO <> ''  
                                        THEN '' ELSE @c_FromID END  
                        FROM LOC  WITH (NOLOCK)  
                        WHERE Loc = @c_FinalToLoc  
                          
                        IF NOT EXISTS (SELECT 1 FROM LOTXLOCXID (NOLOCK)  
                                       WHERE LOT = @c_FromLot  
                                       AND LOC = @c_FromLoc  
                                       AND ID = @cToID )  
                        BEGIN --Add dummy lotxlocxid with id = '', will delete later  
                           INSERT INTO LotxLocxID (LOT, LOC, ID, SKU, STORERKEY, Qty, QtyAllocated, QtyExpected, QtyPicked, QtyPickInProcess, QtyReplen, PendingMoveIN, ArchiveQty)  
                           SELECT TOP 1 LOT, LOC, @cToID, SKU, STORERKEY, Qty, QtyAllocated, QtyExpected, QtyPicked, QtyPickInProcess, QtyReplen, PendingMoveIN, ArchiveQty  
                           FROM LOTXLOCXID (NOLOCK)  
                           WHERE LOT = @c_FromLot  
                           AND LOC = @c_FromLoc  
                           AND ID =  @c_FromID  
                           AND STORERKEY = @c_FromStorerkey  
                           AND SKU = @c_FromSku  
  
                           SET @b_DummyLLI = 1  
                        END  
  
                        EXEC  rdt.rdt_Putaway_PendingMoveIn  
                                                 @cUserName     = @c_UserID  
                                                ,@cType         = 'LOCK'  
                                                ,@cFromLoc      = @c_FromLoc  
                                                ,@cFromID       = @cToID  
                                                ,@cSuggestedLOC = @c_FinalToLoc  
                                                ,@cStorerKey    = @c_FromStorerkey  
                                                ,@nErrNo        = @n_Err     OUTPUT  
                                                ,@cErrMsg       = @c_ErrMsg  OUTPUT  
                                                ,@cSKU          = @c_FromSku  
                                                ,@nPutawayQTY   = @n_QtyToMove  
                                                ,@cUCCNo        = @c_UCCNo  
                                                ,@cFromLOT      = @c_FromLot  
                                                ,@cToID         = @cToID  
                                                ,@nPABookingKey = @n_PABookingKey OUTPUT 
                                                   
                        --WL02 START
                        --INSERT INTO TRACEINFO (Tracename, [TimeOut], Step2, Step3, Step4, Step5, Col1, Col2, Col3, Col4, Col5)  
                        --SELECT 'ispTransferAllocation', @dt_TimeOut, '2', @c_UCCNo, CAST(@n_PABookingKey AS NVARCHAR(20)), @c_FromID, @c_FromLot, @c_FinalToLoc, @cToID, @c_FromSku, CAST(@n_QtyToMove AS NVARCHAR(10))  
                        --WL02 END
                        
                        --(Wan01) - START  
                        IF @n_Err <> 0  
                        BEGIN  
                           SET @n_Continue = 3  
                           SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)  
                           SET @n_Err = 81055  
                           SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Error Executing rdt_Putaway_PendingMoveIn (ispTransferAllocation)'  
                                        + ' for transferkey: ' + @c_Transferkey  
                                        + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
  
                           IF EXISTS (SELECT 1 FROM LOTXLOCXID (NOLOCK)  
                                       WHERE LOT = @c_FromLot  
                                       AND LOC = @c_FromLoc  
                                       AND ID = @cToID )  
                           BEGIN  
                              IF @b_DummyLLI = 1  
                              BEGIN  
                                 UPDATE LotxLocxID WITH (ROWLOCK)  
                                 SET Qty = 0,  
                                     QtyAllocated = 0,  
                                     QtyPicked = 0,  
                                     TrafficCop = NULL,  
                                     EditDate = GETDATE(),  
                                     EditWho = Suser_Sname()  
                                 WHERE LOT = @c_FromLot  
                                 AND LOC = @c_FromLoc  
                                 AND ID =  @cToID  
                                 AND STORERKEY = @c_FromStorerkey  
                                 AND SKU = @c_FromSku  
  
                                 DELETE FROM LOTXLOCXID  
                                 WHERE LOT = @c_FromLot  
                                 AND LOC = @c_FromLoc  
                             AND ID =  @cToID  
                                 AND STORERKEY = @c_FromStorerkey  
                                 AND SKU = @c_FromSku  
                              END  
                           END  
  
                           GOTO NEXT_TRF  
                        END  
  
                        IF EXISTS (SELECT 1 FROM LOTXLOCXID (NOLOCK)  
                                       WHERE LOT = @c_FromLot  
                                       AND LOC = @c_FromLoc  
                                       AND ID = @cToID )  
                        BEGIN  
                           IF @b_DummyLLI = 1  
                           BEGIN  
                              UPDATE LotxLocxID WITH (ROWLOCK)  
                              SET Qty = 0,  
                                  QtyAllocated = 0,  
                                  QtyPicked = 0,  
                                  TrafficCop = NULL,  
                                  EditDate = GETDATE(),  
                                  EditWho = Suser_Sname()  
                              WHERE LOT = @c_FromLot  
                              AND LOC = @c_FromLoc  
                              AND ID =  @cToID  
                              AND STORERKEY = @c_FromStorerkey  
                              AND SKU = @c_FromSku  
  
                              DELETE FROM LOTXLOCXID  
                              WHERE LOT = @c_FromLot  
                              AND LOC = @c_FromLoc  
                              AND ID =  @cToID  
                              AND STORERKEY = @c_FromStorerkey  
                              AND SKU = @c_FromSku  
                           END  
                        END  
  
                     END                 
                     ELSE                       --WL01 End    
                     BEGIN   
                        EXEC  rdt.rdt_Putaway_PendingMoveIn  
                                                 @cUserName    = @c_UserID  
                                                ,@cType        = 'LOCK'  
                                                ,@cFromLoc     = @c_FromLoc  
                                                ,@cFromID      = @c_FromID  
                                                ,@cSuggestedLOC= @c_FinalToLoc  
                                                ,@cStorerKey   = @c_FromStorerkey  
                                                ,@nErrNo       = @n_Err     OUTPUT  
                                                ,@cErrMsg      = @c_ErrMsg  OUTPUT  
                                                ,@cSKU         = @c_FromSku  
                                                ,@nPutawayQTY  = @n_QtyToMove  
                                                ,@cUCCNo       = @c_UCCNo  
                                                ,@cFromLOT     = @c_FromLot  
                                                ,@cToID        = @cToID  
                        --(Wan01) - START  
                        IF @n_Err <> 0  
                        BEGIN  
                           SET @n_Continue = 3  
                           SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)  
                           SET @n_Err = 81055  
                           SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Error Executing rdt_Putaway_PendingMoveIn (ispTransferAllocation)'  
                                        + ' for transferkey: ' + @c_Transferkey  
                                        + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
                           GOTO NEXT_TRF  
                        END  
                     END  
 --(Wan01) - END  
                  END  
                  -- SOS# 326708 (End)  
  
                  --Move up  
                  --WL01 START   
                  --IF(@n_QtyToTake = @n_QtyToMove) AND (ISNULL(@c_Country,'') = 'CN') --If Transfer qty = Taskdetail.qty (UCC.qty) - This logic only apply to CN  
                  --BEGIN  
                  --   IF EXISTS (SELECT 1 FROM LOC (NOLOCK) WHERE LOC = 'TRBKST')  
                  --   BEGIN  
                  --      SET @c_FinalToLoc = 'TRBKST'    
                  --      SET @c_MoveToLoc = @c_FinalToLoc  
                  --   END  
                  --   ELSE  
                  --   BEGIN  
                  --      SET @n_Continue = 3  
                  --      SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)  
                  --      SET @n_Err = 81075  
                  --      SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Location : TRBKST Not Found in LOC Table (ispTransferAllocation)'  
                  --                   + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
                  --      GOTO NEXT_TRF  
                  --   END   
                  --END  
                  --WL01 END  
               END  
               -- Find MoveToLoc (END)  
      
               -- Move UCC Inventory from BULK to HOLD ID 'HOLD_001' (START)  
               IF LEN(@c_UCCNo) > 0  
               BEGIN  
                  SET @b_Success = 1  
                  EXEC dbo.nspItrnAddMove  
                        @n_ItrnSysId      = NULL  
                     ,  @c_StorerKey      = @c_FromStorerkey  
                     ,  @c_Sku            = @c_FromSku  
                     ,  @c_Lot            = @c_FromLot  
                     ,  @c_FromLoc        = @c_FromLoc  
                     ,  @c_FromID         = @c_FromID  
                     ,  @c_ToLoc          = @c_FromLoc  
                     ,  @c_ToID           = 'HOLD_001'  
                     ,  @c_Status         = 'HOLD'  
                     ,  @c_lottable01     = ''  
                     ,  @c_lottable02     = ''  
                     ,  @c_lottable03     = ''  
                     ,  @d_lottable04     = ''  
                     ,  @d_lottable05     = ''  
                     ,  @c_lottable06     = ''         --(CS01)  
                     ,  @c_lottable07     = ''         --(CS01)  
                     ,  @c_lottable08     = ''         --(CS01)  
                     ,  @c_lottable09     = ''         --(CS01)  
                     ,  @c_lottable10     = ''         --(CS01)  
                     ,  @c_lottable11     = ''         --(CS01)  
                     ,  @c_lottable12     = ''         --(CS01)  
                     ,  @d_lottable13     = ''         --(CS01)  
                     ,  @d_lottable14     = ''         --(CS01)  
                     ,  @d_lottable15     = ''         --(CS01)  
                     ,  @n_casecnt        = 0.00  
                     ,  @n_innerpack      = 0.00  
                     ,  @n_qty            = @n_QtyToMove --@n_QtyToTake  
                     ,  @n_pallet         = 0.00  
                     ,  @f_cube           = 0.00  
                     ,  @f_grosswgt       = 0.00  
                     ,  @f_netwgt         = 0.00  
                     ,  @f_otherunit1     = 0.00  
                     ,  @f_otherunit2     = 0.00  
                     ,  @c_SourceKey      = @c_Transferkey  
                     ,  @c_SourceType     = 'ispTransferAllocation'  
                     ,  @c_PackKey        = @c_FromPackkey  
                     ,  @c_UOM            = @c_FromUOM  
                     ,  @b_UOMCalc        = 0  
                     ,  @d_EffectiveDate  = @dt_today  
                     ,  @c_itrnkey        = ''  
                     ,  @b_Success        = @b_Success      OUTPUT  
                     ,  @n_err            = @n_err          OUTPUT  
                     ,  @c_errmsg         = @c_errmsg       OUTPUT  
  
                  IF NOT @b_Success = 1  
                  BEGIN  
                     SET @n_Continue = 3  
                     SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)  
                     SET @n_Err = 81015  
                     SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Error Executing Move To HOLD ID - nspItrnAddMove (ispTransferAllocation)'  
                                  + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
                     GOTO NEXT_TRF  
                  END  
  
                  UPDATE UCC WITH (ROWLOCK)  
                  SET ID = 'HOLD_001'  
                  WHERE UCCNo = @c_UCCNo  
  
                  SET @n_err = @@ERROR  
  
                  IF @n_err <> 0  
                  BEGIN  
                     SET @n_continue = 3  
                     SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)  
                     SET @n_err = 81020  -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                     SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update UCC Failed. (ispTransferAllocation)'  
                                  + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
                     GOTO NEXT_TRF  
                  END  
  
                  SET @c_FromID = 'HOLD_001'  
                  SET @c_toid = ''  
               END  
               -- Move UCC Inventory to HOLD ID 'HOLD_001' (END)  
               -- Not to create Task for item from DPP (1) allocated non prepack sku ( 2) Not finalized Prepack Item (START)  
               ELSE IF @c_PrepackIndicator <> 'Y' OR @c_TransferStatus = '0'  
               BEGIN  
                  SET @c_MoveToLoc = ''  
               END  
               -- Not to create Task for item from DPP (1) allocated non prepack sku ( 2) Not finalized Prepack Item (END)  
  
               IF @n_QtyRequired <= 0  
               BEGIN  
                  UPDATE TRANSFERDETAIL WITH (ROWLOCK)  
                  SET [Status] = @c_TransferStatus  
                     ,FromLot  = @c_FromLot  
                     ,FromLoc  = @c_FromLoc  
                     ,FromID   = @c_FromID  
                     ,FromQty  = @n_QtyToTake     --@n_FromQty  
                     ,Lottable01 = @c_Lottable01  
                     ,Lottable03 = @c_Lottable03  
                     ,Lottable04 = @dt_Lottable04  
                     ,Lottable05 = @dt_Lottable05  
                     ,Lottable06 = @c_Lottable06      -- (CS01)  
                     ,Lottable07 = @c_Lottable07      -- (CS01)      
                     ,Lottable08 = @c_Lottable08      -- (CS01)  
                     ,Lottable09 = @c_Lottable09      -- (CS01)  
                     ,Lottable10 = @c_Lottable10      -- (CS01)  
                     ,Lottable11 = @c_Lottable11      -- (CS01)  
                     ,Lottable12 = @c_Lottable12      -- (CS01)  
                     ,Lottable13 = @dt_Lottable13     -- (CS01)  
                     ,Lottable14 = @dt_Lottable14     -- (CS01)  
                     ,Lottable15 = @dt_Lottable15     -- (CS01)  
                     ,ToLoc      = @c_FromLoc  
                     ,ToID       = @c_FromID  
                     ,ToQty      = @n_QtyToTake   --@n_FromQty  
                     ,ToLottable01 = @c_Lottable01  
                     ,ToLottable03 = @c_Lottable03  
                     ,ToLottable04 = @dt_Lottable04  
                     ,ToLottable05 = @dt_Lottable05  
                     ,ToLottable06 = @c_Lottable06    -- (CS01)  
                     ,ToLottable07 = @c_Lottable07    -- (CS01)      
                     ,ToLottable08 = @c_Lottable08    -- (CS01)  
                     ,ToLottable09 = @c_Lottable09    -- (CS01)  
                     ,ToLottable10 = @c_Lottable10    -- (CS01)  
                     ,ToLottable11 = @c_Lottable11    -- (CS01)  
                     ,ToLottable12 = @c_Lottable12    -- (CS01)  
                     ,ToLottable13 = @dt_Lottable13   -- (CS01)  
                     ,ToLottable14 = @dt_Lottable14   -- (CS01)  
                     ,ToLottable15 = @dt_Lottable15   -- (CS01)  
                     ,UserDefine01 = @c_UCCNo  
                  WHERE Transferkey = @c_Transferkey  
                  AND TransferLineNumber = @c_TransferLineNumber  
  
                  SET @n_err = @@ERROR  
  
                  IF @n_err <> 0  
                  BEGIN  
                     SET @n_continue = 3  
                     SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)  
                     SET @n_err = 81005   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                     SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UPDATE TRANSFERDETAIL Failed. (ispTransferAllocation)'  
                                  + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
                     GOTO NEXT_TRF  
                  END  
  
                  SET @c_NewTransferLineNo = @c_TransferLineNumber  
               END  
               ELSE  
               BEGIN  
                  SELECT @c_NewTransferLineNo = RIGHT('00000' + CONVERT(VARCHAR(5), MAX(CONVERT(INT, TransferLineNumber)) + 1),5)  
                  FROM TRANSFERDETAIL WITH (NOLOCK)  
                  WHERE Transferkey = @c_Transferkey  
  
                  INSERT INTO TRANSFERDETAIL  
                     (  TransferKey  
                     ,  TransferLineNumber  
                     ,  FromStorerkey  
                     ,  FromSku  
                     ,  FromLot  
                     ,  FromLoc  
                     ,  FromID  
                     ,  FromPackkey  
                     ,  FromUOM  
                     ,  Lottable01  
                     ,  Lottable02  
                     ,  Lottable03  
                     ,  Lottable04  
                     ,  Lottable05  
                     ,  Lottable06         -- (CS01)  
                     ,  Lottable07         -- (CS01)  
                     ,  Lottable08         -- (CS01)  
                     ,  Lottable09         -- (CS01)  
                     ,  Lottable10         -- (CS01)  
                     ,  Lottable11         -- (CS01)  
                     ,  Lottable12         -- (CS01)  
                     ,  Lottable13         -- (CS01)  
                     ,  Lottable14         -- (CS01)  
                     ,  Lottable15         -- (CS01)  
                     ,  FromQty  
                     ,  ToStorerkey  
                     ,  ToSku  
                     ,  ToLoc  
                     ,  ToID  
                     ,  ToPackkey  
                     ,  ToUOM  
                     ,  ToLottable01  
                     ,  ToLottable02  
                     ,  ToLottable03  
                     ,  ToLottable04  
                     ,  ToLottable05  
                     ,  ToLottable06      -- (CS01)             
                     ,  ToLottable07      -- (CS01)             
                     ,  ToLottable08      -- (CS01)             
                     ,  ToLottable09      -- (CS01)             
                     ,  ToLottable10      -- (CS01)             
                     ,  ToLottable11      -- (CS01)             
                     ,  ToLottable12      -- (CS01)             
                     ,  ToLottable13      -- (CS01)             
                     ,  ToLottable14      -- (CS01)             
                     ,  ToLottable15      -- (CS01)             
                     ,  ToQty  
                     ,  [Status]  
                     ,  UserDefine01  
                     )  
                  VALUES  
                     (  @c_TransferKey  
                     ,  @c_NewTransferLineNo  
                     ,  @c_FromStorerkey  
                     ,  @c_FromSku  
                     ,  @c_FromLot  
                     ,  @c_FromLoc  
                     ,  @c_FromID  
                     ,  @c_FromPackkey  
                     ,  @c_FromUOM  
                     ,  @c_Lottable01  
                     ,  @c_FromLottable02  
                     ,  @c_Lottable03  
                     ,  @dt_Lottable04  
                     ,  @dt_Lottable05  
                     ,  @c_Lottable06      -- (CS01)              
                     ,  @c_Lottable07      -- (CS01)              
                     ,  @c_Lottable08      -- (CS01)              
                     ,  @c_Lottable09      -- (CS01)              
                     ,  @c_Lottable10      -- (CS01)              
                     ,  @c_Lottable11      -- (CS01)           
                     ,  @c_Lottable12      -- (CS01)              
                     ,  @dt_Lottable13     -- (CS01)              
                     ,  @dt_Lottable14     -- (CS01)              
                     ,  @dt_Lottable15     -- (CS01)              
                     ,  @n_QtyToTake   --@n_QtyAvail  
                     ,  @c_ToStorerkey  
                     ,  @c_ToSku  
                     ,  @c_FromLoc  
                     ,  @c_FromID  
                     ,  @c_ToPackkey  
                     ,  @c_ToUOM  
                     ,  @c_Lottable01  
                     ,  @c_ToLottable02  
                     ,  @c_Lottable03  
                     ,  @dt_Lottable04  
                     ,  @dt_Lottable05  
                     ,  @c_Lottable06      -- (CS01)              
                     ,  @c_Lottable07      -- (CS01)              
                     ,  @c_Lottable08      -- (CS01)              
                     ,  @c_Lottable09      -- (CS01)              
                     ,  @c_Lottable10      -- (CS01)              
                     ,  @c_Lottable11      -- (CS01)              
                     ,  @c_Lottable12      -- (CS01)              
                     ,  @dt_Lottable13     -- (CS01)              
                     ,  @dt_Lottable14     -- (CS01)              
                     ,  @dt_Lottable15     -- (CS01)   
                     ,  @n_QtyToTake   --@n_QtyAvail  
                     ,  @c_TransferStatus  
                     ,  @c_UCCNo  
                     )  
                  SET @n_err = @@ERROR  
  
                  IF @n_err <> 0  
                  BEGIN  
                     SET @n_continue = 3  
                     SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)  
                     SET @n_err = 81010   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                     SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': INSERT TRANSFERDETAIL Failed. (ispTransferAllocation)'  
                                  + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
                     GOTO NEXT_TRF  
                  END  
               END  
  
               SET @c_Sourcekey = @c_Transferkey + @c_NewTransferLineNo  
  
               --Create Move Task for  
               --1) BULK to VAS, 2) DPP to VAS, 3) BULK to DPP (CN) 4) BULK to STAGING (HK)  
               IF LEN(@c_MoveToLoc) > 0 AND  
                  ((EXISTS(SELECT 1 FROM CODELKUP (NOLOCK)  
                         WHERE Code = @c_FromFacility  
                         AND Listname = 'ANFFAC'   
                         AND UDF05 = 'Y') AND  
                  EXISTS(SELECT 1   
                         FROM LOC (NOLOCK)  
                         WHERE Loc = @c_FromLoc   
                         AND LocationCategory  = 'SELECTIVE')) OR ISNULL(@c_Country,'') <> 'CN')--NJOW02  
               BEGIN  
                  IF @c_PrepackIndicator = 'Y' AND @c_TransferStatus = '9' -- DPP to VAS  
                  BEGIN  
                     SELECT @c_FromLot = Lot  
                     FROM ITRN WITH (NOLOCK)  
                     WHERE Sourcetype IN ('ntrTransferDetailAdd', 'ntrTransferDetailUpdate')  
                     AND SourceKey = @c_TransferKey + @c_NewTransferLineNo  
                     AND Trantype = 'DP'  
                  END  
  
                  -- SOS# 326708 (Start)  
                  -- IF @c_UCCNo <> '' AND EXISTS ( SELECT 1  
                  --                                FROM LOC WITH (NOLOCK)  
                  --                                WHERE Loc = @c_FinalToLoc  
                  --                                AND LocationType = 'DYNPPICK'  
                  --                              )  
                  -- BEGIN  
                  --    EXEC  rdt.rdt_Putaway_PendingMoveIn  
                  --                             @cUserName    = @c_UserID  
                  --                            ,@cType        = 'LOCK'  
                  --                      ,@cFromLoc     = @c_FromLoc  
                  --                            ,@cFromID      = @c_FromID  
                  --                            ,@cSuggestedLOC= @c_FinalToLoc  
                  --                            ,@cStorerKey   = @c_FromStorerkey  
                  --                            ,@nErrNo       = @n_Err     OUTPUT  
                  --                            ,@cErrMsg      = @c_ErrMsg  OUTPUT  
                  --                            ,@cSKU         = @c_FromSku  
                  --                            ,@nPutawayQTY  = @n_QtyToMove  
                  --                            ,@cUCCNo       = @c_UCCNo  
                  --                            ,@cFromLOT     = @c_FromLot  
                  --                            ,@cToID        = ''  
                  --    --(Wan01) - START  
                  --    IF @n_Err <> 0  
                  --    BEGIN  
                  --       SET @n_Continue = 3  
                  --       SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)  
                  --       SET @n_Err = 81055  
                  --       SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Error Executing rdt_Putaway_PendingMoveIn (ispTransferAllocation)'  
                  --                    + ' for transferkey: ' + @c_Transferkey  
                  --                    + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
                  --       GOTO NEXT_TRF  
                  --    END  
                  --    --(Wan01) - END  
                  -- END  
                  -- SOS# 326708 (End)  
  
                  SET @b_success = 1  
                  EXECUTE   nspg_getkey  
                        'TaskDetailKey'  
                          , 10  
                          , @c_TaskdetailKey OUTPUT  
                          , @b_success       OUTPUT  
                          , @n_err           OUTPUT  
                          , @c_errmsg        OUTPUT  
  
                  IF NOT @b_success = 1  
                  BEGIN  
                     SET @n_continue = 3  
                     SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)  
                     SET @n_err = 81040   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                     SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert TASKDETAIL Failed. (ispTransferAllocation)'  
                                  + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
                     GOTO NEXT_TRF  
                  END  
  
                  IF @b_success = 1  
                  BEGIN  
                     SET @c_LogicalMoveToLoc = ''  
                     SET @c_Areakey = ''  
  
                     SELECT @c_LogicalMoveToLoc = ISNULL(RTRIM(LOC.LogicalLocation),'')  
                           ,@c_ToID             = CASE WHEN LocationType ='DYNPPICK' AND @c_UCCNO <> ''  
                                                       THEN '' ELSE @c_FromID END  
                     FROM LOC  WITH (NOLOCK)  
                     WHERE Loc = @c_MoveToLoc  
  
                     SELECT TOP 1  
                            @c_Areakey  = ISNULL(AD.AreaKey,'')  
                     FROM LOC  WITH (NOLOCK)  
                     LEFT JOIN AREADETAIL AD WITH (NOLOCK) ON (LOC.Putawayzone = AD.Putawayzone)  
                     WHERE Loc = @c_FromLoc  
  
                     INSERT INTO TASKDETAIL  
                        (  
                           TaskDetailKey  
                        ,  TaskType  
                        ,  Storerkey  
                        ,  Sku  
                        ,  UOM  
                        ,  UOMQty  
                        ,  Qty  
                        ,  SystemQty  
                        ,  Lot  
                        ,  FromLoc  
                        ,  FromID  
                        ,  ToLoc  
                        ,  ToID  
                        ,  CaseID  
                        ,  PickMethod  
,  SourceType  
                        ,  SourceKey  
                        ,  Priority  
                        ,  SourcePriority  
                        ,  [Status]  
                        ,  Areakey  
                        ,  LogicalFromLoc  
                        ,  LogicalToLoc  
                        ,  Message01  
                        ,  Message02  
                        )  
                     VALUES  
                        (  
                           @c_Taskdetailkey  
                        ,  'RPF'                --Tasktype  
                        ,  @c_FromStorerkey  
                        ,  @c_FromSku  
                        ,  @c_FromUOM           --UOM,  
                        ,  @n_QtyToMove  
                        ,  @n_QtyToMove  
                        ,  0                    --systemqty  --NJOW01  
                        ,  @c_FromLot  
                        ,  @c_Fromloc  
                        ,  @c_FromID            -- from id  
                        ,  @c_MoveToLoc  
                        ,  @c_ToID              -- to id  
                        ,  @c_UCCNo  
                        ,  'PP'  
                        ,  'ispTransferAllocation' --Sourcetype  
                        ,  @c_Sourcekey  
                        ,  '5'                  -- Priority  
                        ,  '9'                  -- Sourcepriority  
                        ,  'S'                  -- 11-AUG-2014 CR  
                        ,  @c_Areakey  
                        ,  @c_LogicalLoc        --Logical from loc  
                        ,  @c_LogicalMoveToLoc  --Logical to loc  
                        ,  'TRANSFER'  
                        ,  @c_FinalToLoc  
                        )  
  
                     SET @n_err = @@ERROR  
  
                     IF @n_err <> 0  
                     BEGIN  
  
                        SET @n_continue = 3  
                        SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)  
                        SET @n_err = 81045   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                        SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert TASKDETAIL Failed. (ispTransferAllocation)'  
                                     + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
  
                        GOTO NEXT_TRF  
                     END  
  
                     --WL01 Start  
                     --Update Taskdetailkey back to RFPutaway  
                     IF ISNULL(@c_Country,'') = 'CN'  
                     BEGIN  
                        UPDATE RFPutaway WITH (ROWLOCK)  
                        SET Taskdetailkey = @c_Taskdetailkey  
                        WHERE RowRef = @n_PABookingKey  
                        AND PABookingKey = @n_PABookingKey  
  
                        SET @n_err = @@ERROR  
  
                        IF @n_Err <> 0  
                        BEGIN  
                           SET @n_Continue = 3  
                           SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)  
                           SET @n_Err = 81055  
                           SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Error Updating RFPutaway Table (ispTransferAllocation)'  
                                        + ' for transferkey: ' + @c_Transferkey  
                                        + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
                           GOTO NEXT_TRF  
                        END  
                     END  
                     --WL01 End  
  
                  END  
               END  
            END  
  
            SET @n_FromQty = @n_FromQty - @n_QtyToTake  
         END  
  
         NEXT_TRFDET:  
         IF @c_TransferStatus = '9' AND @n_QtyRequired > 0  
         BEGIN  
            --Allow Auto Finalize if there is no Qty Available( No more Lot, loc, id, lottables on hold )  
            --(Wan03) 1. Put back to original to include auto finalize if no inventory record in Lotxlocxid &  
            -- do not finalize if there are Lot, loc, id, lottables on hold  
            --        2. If ID = 'HOLD_001', do not auto finalize.  
            --  IF EXISTS ( SELECT 1 FROM LOTxLOCxID LLI WITH (NOLOCK)  
            --              JOIN LOTATTRIBUTE LA ON (LLI.Lot = LA.Lot)  
            --              WHERE LLI.Storerkey = @c_FromStorerkey  
            --              AND LLI.Sku = @c_FromSku  
            --              AND LLI.ID <> 'HOLD_001'  
            --              AND LA.Lottable02 = @c_fromLottable02  
            --              GROUP BY LLI.Storerkey  
            --                    ,  LLI.Sku  
            --              HAVING SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) <= 0  
            IF EXISTS ( SELECT 1  
                        FROM SKU WITH (NOLOCK)  
                        LEFT JOIN LOTxLOCxID  LLI WITH (NOLOCK) ON (SKU.Storerkey = LLI.Storerkey)  
                        AND(SKU.Sku = LLI.Sku)  
                        LEFT JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON (LLI.Lot = LA.Lot)  
                        WHERE SKU.Storerkey = @c_FromStorerkey  
                        AND SKU.Sku = @c_FromSku  
                        AND ( LA.Lottable02 = @c_fromLottable02  
                         OR   LLI.Storerkey IS NULL )  
                        GROUP BY SKU.Storerkey  
                              ,  SKU.Sku  
                        HAVING SUM(ISNULL(LLI.Qty,0) - ISNULL(LLI.QtyAllocated,0) - ISNULL(LLI.QtyPicked,0)) <= 0  
                      )  
            BEGIN  
               SET @n_FromQty = 0  
            END  
            ELSE  
            BEGIN  
               SET  @c_TransferStatus = '0'  
            END  
            --(Wan03)  
         END  
  
         UPDATE TRANSFERDETAIL WITH (ROWLOCK)  
         SET FromQty  = @n_FromQty  
            ,ToQty    = @n_FromQty  
            ,[Status] = @c_TransferStatus  
            ,EditWho  = @c_UserID  
            ,EditDate = @dt_Today  
            ,Trafficcop = NULL  
         WHERE Transferkey = @c_Transferkey  
         AND TransferLineNumber = @c_TransferLineNumber  
         AND (FromLot = '' OR FromLot IS NULL)  
  
         SET @n_err = @@ERROR  
  
         IF @n_err <> 0  
         BEGIN  
            SET @n_continue = 3  
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)  
            SET @n_err = 81050   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UPDATE TRANSFERDETAIL Failed. (ispTransferAllocation)'  
                         + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
            GOTO NEXT_TRF  
         END  
  
         FETCH NEXT FROM CUR_TFRDET INTO  @c_TransferLineNumber  
                                     --  ,  @c_FromStorerkey  
                                       ,  @c_FromSku  
                                       ,  @n_FromQty  
                                       ,  @c_FromLottable02  
                                       ,  @c_ToStorerkey  
                                       ,  @c_ToSku  
                                       ,  @c_ToLottable02  
      END  
      CLOSE CUR_TFRDET  
      DEALLOCATE CUR_TFRDET  
  
      IF @c_Transmitflag <> 'IGNOR'  
      BEGIN  
         SET @n_OpenQty = 0  
         SELECT @c_TransferStatus = CASE WHEN MIN(Status) = '9' THEN '9' ELSE '3' END  
               ,@n_OpenQty = ISNULL(SUM(CASE WHEN Status = '9' THEN 0 ELSE FromQty END),0)  
         FROM TRANSFERDETAIL WITH (NOLOCK)  
         WHERE TransferKey = @c_Transferkey  
  
         IF @c_TransferStatus = '9'  
         BEGIN  
            --(Wan03)  - Update to Transmitflag to in progress (START)  
            UPDATE TRANSMITLOG3 WITH (ROWLOCK)  
            SET Transmitflag = '3'  
            WHERE Transmitlogkey = @c_Transmitlogkey  
  
            IF @n_err <> 0  
            BEGIN  
               SET @n_continue = 3  
               SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)  
               SET @n_err = 81067   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UPDATE TRANSMITLOG3 Failed. (ispTransferAllocation)'  
                            + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
               GOTO NEXT_TRF  
            END  
            --(Wan03)  - Update to Transmitflag to in progress  (END)  
  
            SET @b_Success = 0  
            SET @n_err     = 0  
            SET @c_errmsg  = ''  
            SET @c_PostFinalizeTransferSP = ''  
  
            EXEC nspGetRight  
                  @c_Facility  = NULL  
                , @c_StorerKey = @c_FromStorerKey  
                , @c_sku       = NULL  
                , @c_ConfigKey = 'PostFinalizeTranferSP'  
                , @b_Success   = @b_Success                  OUTPUT  
                , @c_authority = @c_PostFinalizeTransferSP   OUTPUT  
                , @n_err       = @n_err                      OUTPUT  
                , @c_errmsg    = @c_errmsg                   OUTPUT  
  
            IF EXISTS (SELECT 1 FROM sys.objects o WHERE NAME = @c_PostFinalizeTransferSP AND TYPE = 'P')  
            BEGIN  
               SET @b_Success = 0  
               EXECUTE dbo.ispPostFinalizeTransferWrapper  
                       @c_TransferKey             = @c_TransferKey  
                     , @c_PostFinalizeTransferSP  = @c_PostFinalizeTransferSP  
                     , @b_Success = @b_Success     OUTPUT  
                     , @n_Err     = @n_err         OUTPUT  
                     , @c_ErrMsg  = @c_errmsg      OUTPUT  
                     , @b_debug   = 0  
  
               IF @n_err <> 0  
               BEGIN  
                  SET @n_Continue= 3  
                  SET @b_Success = 0  
                  SET @n_err  = 81060  
                  SET @c_errmsg = 'Execute ispPostFinalizeTransferWrapper Failed. (ispTransferAllocation)'  
                                + '(' + @c_errmsg + ')'  
                  GOTO NEXT_TRF  
               END  
            END  
  
            UPDATE TRANSFER WITH (ROWLOCK)  
            SET [Status] = CASE WHEN @n_OpenQty = 0 THEN Status ELSE @c_TransferStatus END-- Trigger will update status = '9' when openqty = 0  
             ,  OpenQty  = @n_OpenQty  
            WHERE Transferkey = @c_Transferkey  
         END  
         ELSE  
         BEGIN  
            UPDATE TRANSFER WITH (ROWLOCK)  
            SET [Status] = @c_TransferStatus  
               ,OpenQty  = @n_OpenQty  
               ,EditWho  = @c_UserID  
               ,EditDate = @dt_today  
               ,Trafficcop = NULL  
            WHERE Transferkey = @c_Transferkey  
         END  
  
         SET @n_err = @@ERROR  
  
         IF @n_err <> 0  
         BEGIN  
            SET @n_continue = 3  
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)  
            SET @n_err = 81065   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UPDATE TRANSFER Failed. (ispTransferAllocation)'  
                         + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
            GOTO NEXT_TRF  
         END  
  
         IF @n_QtyRequired > 0  
         BEGIN  
            SET @c_AlertMessage = 'There are requried qty not allocated. TransferKey : ' + @c_TransferKey  
  
            EXEC nspLogAlert  
                  @c_modulename       = 'ispTransferAllocation'  
                , @c_AlertMessage     = @c_AlertMessage  
                , @n_Severity         = '5'  
                , @b_success          = @b_success    OUTPUT  
                , @n_err              = @n_Err        OUTPUT  
                , @c_errmsg           = @c_ErrMsg     OUTPUT  
                , @c_Activity         = 'Finalize Transfer'  
                , @c_Storerkey        = @c_FromStorerkey  
                , @c_SKU              = ''  
                , @c_UOM              = ''  
                , @c_UOMQty           = ''  
                , @c_Qty              = 0  
                , @c_Lot              = ''  
       , @c_Loc              = ''  
                , @c_ID               = ''  
                , @c_TaskDetailKey    = ''  
                , @c_UCCNo            = ''  
         END  
      END  
  
      NEXT_TRF:  
  
      IF CURSOR_STATUS('LOCAL' , 'CUR_INV') in (0 , 1)  
      BEGIN  
         CLOSE CUR_INV  
         DEALLOCATE CUR_INV  
      END  
  
      IF CURSOR_STATUS('LOCAL' , 'CUR_TFRDET') in (0 , 1)  
      BEGIN  
         CLOSE CUR_TFRDET  
         DEALLOCATE CUR_TFRDET  
      END  
  
      IF @n_continue = 3  -- Error Occured  
      BEGIN  
         SET @b_success = 0  
  
         --IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCount --(Wan04)  
         IF @@TRANCOUNT >= 1                                   --(Wan04)  
         BEGIN  
            ROLLBACK TRAN  
         END  
  
         --(Wan01) - START  
         SET @c_AlertMessage = 'There are Error on Transfer allocation. TransferKey : ' + @c_TransferKey +  
                               ' - ' + @c_ErrMsg -- (Chee01)  
         BEGIN TRAN  
  
         -- (Chee01)  
         INSERT INTO #Error (ErrMsg) VALUES (@c_AlertMessage)  
  
         EXEC nspLogAlert  
               @c_modulename       = 'ispTransferAllocation'  
             , @c_AlertMessage     = @c_AlertMessage  
             , @n_Severity         = '5'  
             , @b_success          = @b_success    OUTPUT  
             , @n_err              = @n_Err        OUTPUT  
             , @c_errmsg           = @c_ErrMsg     OUTPUT  
             , @c_Activity         = 'Finalize Transfer'  
             , @c_Storerkey        = @c_FromStorerkey  
             , @c_SKU              = ''  
             , @c_UOM              = ''  
             , @c_UOMQty           = ''  
             , @c_Qty              = 0  
             , @c_Lot              = ''  
             , @c_Loc              = ''  
             , @c_ID               = ''  
             , @c_TaskDetailKey    = ''  
             , @c_UCCNo            = ''  
         COMMIT TRAN  
         SET @c_Transmitflag = '5'  
         --(Wan01) - END  
      END  
      ELSE  
      BEGIN  
         --WHILE @@TRANCOUNT > @n_StartTCount --(Wan05)  
         --BEGIN                              --(Wan05)  
            COMMIT TRAN  
         --END                                --(Wan05)  
         SET @b_success = 1  
      END  
  
      --(Wan01) - Move down  
      --IF @n_continue = 1 OR @n_continue = 2  
      --BEGIN  
      BEGIN TRAN  
         UPDATE TRANSMITLOG3 WITH (ROWLOCK)  
         SET Transmitflag = @c_Transmitflag  
            ,TransmitBatch= @c_TransmitBatch       --(Wan01)  
         WHERE Transmitlogkey = @c_Transmitlogkey  
  
         SET @n_err = @@ERROR  
  
         IF @n_err <> 0  
         BEGIN  
            SET @n_continue = 3  
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)  
            SET @n_err = 81070   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UPDATE TRANSMITLOG3 Failed. (ispTransferAllocation)'  
                         + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
           --  GOTO NEXT_TRF  
            ROLLBACK TRAN  
         END  
      COMMIT TRAN  
      --END  
      --(Wan01) - Move down  
  
      FETCH NEXT FROM CUR_ANFTRAN INTO @c_Transmitlogkey  
                                    ,  @c_Transferkey  
                                    ,  @c_TransferType  
                                    ,  @c_FromFacility  
   END  
   CLOSE CUR_ANFTRAN  
   DEALLOCATE CUR_ANFTRAN  
  
  
   QUIT_SP:  
   IF CURSOR_STATUS('LOCAL' , 'CUR_ANFTRAN') in (0 , 1)  
   BEGIN  
      CLOSE CUR_ANFTRAN  
      DEALLOCATE CUR_ANFTRAN  
   END  
  
   -- Send Email Alert if got error (Chee01)  
   IF EXISTS(SELECT 1 FROM #Error)  
   BEGIN  
      SELECT @cRecipients = CASE WHEN ISNULL(UDF01,'') <> '' THEN RTRIM(UDF01) + ';' ELSE '' END  
                          + CASE WHEN ISNULL(UDF02,'') <> '' THEN RTRIM(UDF02) + ';' ELSE '' END  
                          + CASE WHEN ISNULL(UDF03,'') <> '' THEN RTRIM(UDF03) + ';' ELSE '' END  
                          + CASE WHEN ISNULL(UDF04,'') <> '' THEN RTRIM(UDF04) + ';' ELSE '' END  
                          + CASE WHEN ISNULL(UDF05,'') <> '' THEN RTRIM(UDF05) + ';' ELSE '' END  
      FROM CODELKUP WITH (NOLOCK)  
      WHERE ListName = 'EmailAlert'  
      AND   Code = 'ispTransferAllocation'  
      AND StorerKey = @c_FromStorerkey  
  
      IF ISNULL(@cRecipients, '') <> ''  
      BEGIN  
         SET @cSubject = 'ANF Transfer Allocation Alert - ' + REPLACE(CONVERT(NVARCHAR(19), GETDATE(), 126),'T',' ')  
         SET @cBody = '<table border="1" cellspacing="0" cellpadding="5">' +  
             '<tr bgcolor=silver><th>Error</th></tr>' + CHAR(13) +  
             CAST ( ( SELECT td = ISNULL(ErrMsg,'')  
                      FROM #Error  
                 FOR XML PATH('tr'), TYPE  
             ) AS NVARCHAR(MAX) ) + '</table>' ;  
  
        EXEC msdb.dbo.sp_send_dbmail  
            @recipients      = @cRecipients,  
            @copy_recipients = NULL,  
            @subject         = @cSubject,  
            @body            = @cBody,  
            @body_format     = 'HTML' ;  
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @n_err = 81071  
            SET @c_Errmsg = 'Error executing sp_send_dbmail. (ispTransferAllocation)'  
                          + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@n_err,0)) + ' )'  
         END  
      END -- IF ISNULL(@cRecipients, '') <> ''  
   END -- IF EXISTS(SELECT 1 FROM #Error)  
  
   --(Wan05) - START  
   IF @c_ReAllocTrfkey <> '' AND @n_continue IN ('1', '2')  
   BEGIN  
      SET @b_success =  1  
      SET @c_ErrMsg = 'Transfer Re-allocated'  
  
      WHILE @@TRANCOUNT > 0   
      BEGIN  
         COMMIT TRAN  
      END  
   END   
   --(Wan05) - END  
     
   --(Wan04) - START  
   WHILE @@TRANCOUNT < @n_StartTCount  
   BEGIN  
      BEGIN TRAN  
   END  
   --(Wan04) - END  
  
   RETURN  
END  

GO