SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
    
/************************************************************************/    
/* Trigger: ispFinalizeTransfer                                         */    
/* Creation Date: 21-Jul-2009                                           */    
/* Copyright: IDS                                                       */    
/* Written by:                                                          */    
/*                                                                      */    
/* Purpose: Finalize Transfer                                           */    
/*                                                                      */    
/* Called By: n_cst_transfer.Event ue_finalizeall                       */    
/*                                                                      */    
/* PVCS Version: 2.7                                                    */    
/*                                                                      */    
/* Version: 6.0                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author    Ver Purposes                                  */    
/* 21-Jul-2009  SHONG     1.0 Initial Version                           */    
/* 27-Apr-2010  AQS-KC    1.1 SOS#170283 Maintain hold on inventory if  */    
/*                            original lot was on hold (KC01)           */    
/* 19-Apr-2012  SHONG     1.2 Added New ConfigKey to AllowUCCTransfer   */    
/* 19-Jun-2012  ChewKP    1.3 SOS#247832 (ChewKP01)                     */    
/* 11-Sep-2012  ChewKP    1.4 SOS#255683 Update UCC Status when transfer*/    
/*                            to LoseUCC Location (ChewKP02)            */    
/* 30-JUL-2012  YTWan     1.5 SOS#251326:Add Commingle Lottables        */    
/*                        1.6 validation to Exceed and RDT (Wan01)      */    
/* 02-APR-2013  YTWan     1.7 SOS#251326: Allow place to loc that had   */    
/*                            been picked (Wan02)                       */    
/* 24-Sep-2013  YTWan     1.8 SOS#290122-Add Sku to UCC Checking.       */    
/*                            (for Multisku)(Wan03)                     */    
/* 08-OCT-2013  NJOW01    1.8 291413-Extended Validation                */    
/* 11-OCT-2013  NJOW02    1.9 291946-Combine Validation using codelkup  */    
/* 20-APR-2014  YTWan     2.1 SOS#304838 - ANF - Allocation strategy for*/    
/*                            Transfer (Wan04)                          */    
/* 20-APR-2014  YTWan     2.2 SOS#314107 - ANF RetailDTC Finalize       */    
/*                            Transfer with zero qty transfer (Wan05)   */    
/* 28-May-2014  TKLIM     2.3 Added Lottables 06-15                     */    
/* 06-May-2015  TLTING    2.4 Performance Tune                          */    
/* 18-MAY-2015  YTWan     2.5 SOS#341733 - ToryBurch HK SAP - Allow     */    
/*                            CommingleSKU with NoMixLottablevalidation */    
/*                            to Exceed and RDT (Wan06)                 */    
/* 01-JUN-2015  YTWan     2.6 SOS#343525 - UA NoMixLottable validation  */    
/*                            CR(Wan07)                                 */    
/* 02-Feb-2015  YTWan     2.7 SOS#315474 - Project Merlion - Exceed GTM */    
/*                            Kiosk Module (Wan08)                      */    
/* 14-Mar-2016  CSCHONG   2.8 Add new config to call Transfer finalize  */    
/*                            lottable rules SOS#364463 (CS01)          */    
/* 23-May-2016  Leong     2.9 IN00051925 - Check suspended sku to       */    
/*                            prevent rollback issue in itrn trigger.   */    
/* 24-Jul-2018  NJOW03    3.0 WMS-5839 CN-IKEA Pre-finalize             */    
/************************************************************************/    
    
CREATE PROC [dbo].[ispFinalizeTransfer_DEBUG]   
   @c_Transferkey    NVARCHAR(10),    
   @b_Success        int = 0  OUTPUT,    
   @n_err            int = 0  OUTPUT,    
   @c_errmsg         NVARCHAR(215) = '' OUTPUT    
,  @c_TransferLineNumber NVARCHAR(5) = ''    --(Wan08)    
AS    
BEGIN    
   SET NOCOUNT ON     
       
   DECLARE @nStartTranCount            int    
         , @nContinue                  int    
         , @cUCCTracking               NVARCHAR(1)    
         , @cFromStorerKey             NVARCHAR(15)    
         , @cToStorerKey               NVARCHAR(15)    
         , @cTransferLineNumber        NVARCHAR(5)    
         , @cToLOT                     NVARCHAR(10)    
         , @cFromLOT                   NVARCHAR(10)    
         , @cUCCStatus                 NVARCHAR(10)    
         , @cFromLOC                   NVARCHAR(10)    
         , @cToLOC                     NVARCHAR(10)    
         , @cFromSKU                   NVARCHAR(20)    
         , @cToSKU                     NVARCHAR(20)    
         , @cExternKey                 NVARCHAR(20)    
         , @cFromUCC                   NVARCHAR(20)    
         , @cToUCC                     NVARCHAR(20)    
         , @cFromID                    NVARCHAR(18)    
         , @cToID                      NVARCHAR(18)    
         , @nToQty                     int    
         , @nFromQty                   int    
         /* KC01 - start */    
         , @c_RemainHoldOnTransfer     NVARCHAR(1)    
         , @c_FromLotStatus            NVARCHAR(5)    
         , @n_HoldBy                   int    
    
         , @c_FromLottable01           NVARCHAR(18)    
         , @c_FromLottable02           NVARCHAR(18)    
         , @c_FromLottable03           NVARCHAR(18)    
         , @d_FromLottable04           DATETIME    
         , @d_FromLottable05           DATETIME    
         , @c_FromLottable06           NVARCHAR(30)    
         , @c_FromLottable07           NVARCHAR(30)    
         , @c_FromLottable08           NVARCHAR(30)    
         , @c_FromLottable09           NVARCHAR(30)    
         , @c_FromLottable10           NVARCHAR(30)    
         , @c_FromLottable11           NVARCHAR(30)    
         , @c_FromLottable12           NVARCHAR(30)    
         , @d_FromLottable13           DATETIME    
         , @d_FromLottable14           DATETIME    
         , @d_FromLottable15           DATETIME    
    
         , @c_ToLottable01             NVARCHAR(18)    
         , @c_ToLottable02             NVARCHAR(18)    
         , @c_ToLottable03             NVARCHAR(18)    
         , @d_ToLottable04             DATETIME    
         , @d_ToLottable05             DATETIME    
         , @c_ToLottable06             NVARCHAR(30)    
         , @c_ToLottable07             NVARCHAR(30)    
         , @c_ToLottable08             NVARCHAR(30)    
         , @c_ToLottable09             NVARCHAR(30)    
         , @c_ToLottable10             NVARCHAR(30)    
         , @c_ToLottable11             NVARCHAR(30)    
         , @c_ToLottable12             NVARCHAR(30)    
         , @d_ToLottable13             DATETIME    
         , @d_ToLottable14             DATETIME    
         , @d_ToLottable15             DATETIME    
    
         , @c_HoldLot                  NVARCHAR(10)    
         , @c_HoldLottable01           NVARCHAR(18)    
         , @c_HoldLottable02           NVARCHAR(18)    
         , @c_HoldLottable03           NVARCHAR(18)    
         , @d_HoldLottable04           DATETIME    
         , @d_HoldLottable05           DATETIME    
         , @c_HoldLottable06           NVARCHAR(30)    
         , @c_HoldLottable07           NVARCHAR(30)    
         , @c_HoldLottable08           NVARCHAR(30)    
         , @c_HoldLottable09           NVARCHAR(30)    
         , @c_HoldLottable10           NVARCHAR(30)    
         , @c_HoldLottable11           NVARCHAR(30)    
         , @c_HoldLottable12           NVARCHAR(30)    
         , @d_HoldLottable13           DATETIME    
         , @d_HoldLottable14           DATETIME    
         , @d_HoldLottable15           DATETIME    
    
         , @c_Remark                   NVARCHAR(255)    
         , @c_AllowTransferUCC         NVARCHAR(10)    
         , @c_Facility                 NVARCHAR(5)    
         /* KC01 - end */    
         , @c_FromSkuStatus            NVARCHAR(10) -- IN00051925    
         , @c_ToSkuStatus              NVARCHAR(10) -- IN00051925    
    
   --XXXXXXX--    
   SET @nStartTranCount = @@TRANCOUNT    
   SET @nContinue = 1    
    
   --(Wan01) - START    
   DECLARE @c_IDStorerkey              NVARCHAR(15)    
         , @c_IDSku                    NVARCHAR(20)    
         , @c_IDLottable01             NVARCHAR(18)    
         , @c_IDLottable02             NVARCHAR(18)    
         , @c_IDLottable03             NVARCHAR(18)    
         , @d_IDLottable04             DATETIME    
         , @c_IDLottable06             NVARCHAR(30)    
         , @c_IDLottable07             NVARCHAR(30)    
         , @c_IDLottable08             NVARCHAR(30)    
         , @c_IDLottable09             NVARCHAR(30)    
         , @c_IDLottable10             NVARCHAR(30)    
         , @c_IDLottable11             NVARCHAR(30)    
         , @c_IDLottable12             NVARCHAR(30)    
         , @d_IDLottable13             DATETIME    
         , @d_IDLottable14             DATETIME    
         , @d_IDLottable15             DATETIME    
    
         , @c_NoMixLottable01          NVARCHAR(1)    
         , @c_NoMixLottable02          NVARCHAR(1)    
         , @c_NoMixLottable03          NVARCHAR(1)    
         , @c_NoMixLottable04          NVARCHAR(1)    
         , @c_NoMixLottable06          NVARCHAR(1)    
         , @c_NoMixLottable07          NVARCHAR(1)    
         , @c_NoMixLottable08          NVARCHAR(1)    
         , @c_NoMixLottable09          NVARCHAR(1)    
         , @c_NoMixLottable10          NVARCHAR(1)    
         , @c_NoMixLottable11          NVARCHAR(1)    
         , @c_NoMixLottable12          NVARCHAR(1)    
         , @c_NoMixLottable13          NVARCHAR(1)    
         , @c_NoMixLottable14          NVARCHAR(1)    
         , @c_NoMixLottable15          NVARCHAR(1)    
    
         , @c_CommingleSku             NVARCHAR(1)       --(Wan06)    
         , @c_ChkLocByCommingleSkuFlag NVARCHAR(10)      --(Wan06)    
         , @c_TrfKey                   NVARCHAR(10)      --(Wan07)    
         , @c_TrfLineNo                NVARCHAR(5)       --(Wan07)    
         , @c_FromStorerkey            NVARCHAR(15)      --(Wan07)    
         , @c_FromSku                  NVARCHAR(20)      --(Wan07)    
         , @c_FromLoc                  NVARCHAR(10)      --(Wan07)    
         , @n_FromQty                  INT               --(Wan07)    
         , @c_ToStorerkey              NVARCHAR(15)      --(Wan07)    
         , @c_ToSku                    NVARCHAR(20)      --(Wan07)    
         , @c_ToLoc                    NVARCHAR(10)      --(Wan07)    
         , @n_ToQty                    INT               --(Wan07)    
    
  /*CS01 Start*/    
 DECLARE    @c_Lottable01                  NVARCHAR(18),    
            @c_Lottable02                  NVARCHAR(18),    
            @c_Lottable03                  NVARCHAR(18),    
            @d_Lottable04                  DATETIME,    
            @d_Lottable05                  DATETIME ,    
            @c_Lottable06                  NVARCHAR(30),    
            @c_Lottable07                  NVARCHAR(30),    
            @c_Lottable08                  NVARCHAR(30),    
            @c_Lottable09                  NVARCHAR(30),    
            @c_Lottable10                  NVARCHAR(30),    
            @c_Lottable11                  NVARCHAR(30),    
            @c_Lottable12                  NVARCHAR(30),    
            @d_Lottable13                  DATETIME,    
            @d_Lottable14                  DATETIME,    
            @d_Lottable15                  DATETIME,    
            @c_Lottable01Value             NVARCHAR(18),    
  @c_Lottable02Value             NVARCHAR(18),    
            @c_Lottable03Value             NVARCHAR(18),    
            @d_Lottable04Value             DATETIME,    
            @d_Lottable05Value             DATETIME,    
            @c_Lottable06Value             NVARCHAR(30),    
            @c_Lottable07Value             NVARCHAR(30),    
            @c_Lottable08Value             NVARCHAR(30),    
            @c_Lottable09Value   NVARCHAR(30),    
            @c_Lottable10Value             NVARCHAR(30),    
            @c_Lottable11Value             NVARCHAR(30),    
            @c_Lottable12Value             NVARCHAR(30),    
            @d_Lottable13Value             DATETIME,    
            @d_Lottable14Value             DATETIME,    
            @d_Lottable15Value             DATETIME,    
            @c_LottableLabel01             NVARCHAR(20),    
            @c_LottableLabel02             NVARCHAR(20),    
            @c_LottableLabel03             NVARCHAR(20),    
            @c_LottableLabel04             NVARCHAR(20),    
            @c_LottableLabel05             NVARCHAR(20),    
            @c_LottableLabel06             NVARCHAR(30),    
            @c_LottableLabel07             NVARCHAR(30),    
            @c_LottableLabel08             NVARCHAR(30),    
            @c_LottableLabel09             NVARCHAR(30),    
            @c_LottableLabel10             NVARCHAR(30),    
            @c_LottableLabel11             NVARCHAR(30),    
            @c_LottableLabel12             NVARCHAR(30),    
            @c_LottableLabel13             NVARCHAR(30),    
            @c_LottableLabel14             NVARCHAR(30),    
            @c_LottableLabel15             NVARCHAR(30),    
            @c_LottableLabel               NVARCHAR(20),    
            @nLottableRules                INT,    
            @c_UDF01                       NVARCHAR(60),    
            @c_Value                       NVARCHAR(60),    
            @c_Sourcekey                   NVARCHAR(15),    
            @c_Sourcetype                  NVARCHAR(20),    
            @n_count                       INT,    
            @c_listname                    NVARCHAR(10),    
            @c_sp_name                     NVARCHAR(50),    
          --  @c_SQL                         NVARCHAR(2000),    
            @c_SQLParm                     NVARCHAR(2000),    
            @n_ErrNo                       int,    
            @c_sku                         NVARCHAR(20)    
/*CS01 End*/    
      SET @c_IDStorerkey      = ''    
      SET @c_IDSku            = ''    
      SET @c_IDLottable01     = ''    
      SET @c_IDLottable02     = ''    
      SET @c_IDLottable03     = ''    
      SET @c_IDLottable06     = ''    
      SET @c_IDLottable07     = ''    
      SET @c_IDLottable08     = ''    
      SET @c_IDLottable09     = ''    
      SET @c_IDLottable10     = ''    
      SET @c_IDLottable11     = ''    
      SET @c_IDLottable12     = ''    
    
      SET @c_NoMixLottable01  = '0'    
      SET @c_NoMixLottable02  = '0'    
      SET @c_NoMixLottable03  = '0'    
      SET @c_NoMixLottable04  = '0'    
      SET @c_NoMixLottable06  = '0'    
      SET @c_NoMixLottable07  = '0'    
      SET @c_NoMixLottable08  = '0'    
      SET @c_NoMixLottable09  = '0'    
      SET @c_NoMixLottable10  = '0'    
      SET @c_NoMixLottable11  = '0'    
      SET @c_NoMixLottable12  = '0'    
      SET @c_NoMixLottable13  = '0'    
      SET @c_NoMixLottable14  = '0'    
      SET @c_NoMixLottable15  = '0'    
   --(Wan01) - END    
   SET @c_CommingleSku      = '1'                      --(Wan06)    
   SET @c_ChkLocByCommingleSkuFlag = '0'               --(Wan06)    
   SET @c_TrfKey            = ''                       --(Wan07)    
   SET @c_TrfLineNo         = ''                       --(Wan07)    
   SET @nLottableRules      = 0                        --(CS01)    
    
   DECLARE @c_LoseUCC NVARCHAR(1) -- (ChewKP02)    
         , @c_SQL NVARCHAR(2000) --NJOW01    
         , @c_PostFinalizeTransferSP   NVARCHAR(10)     --(Wan04)    
         , @c_AllowTRFZeroQty          NVARCHAR(10)            --(Wan05)    
         , @c_PreFinalizeTransferSP    NVARCHAR(10)            --NJOW03    
    
   --1 XXXXXXX--    
   BEGIN TRAN    
    
   SELECT @cFromStorerKey = FromStorerKey,    
          @c_Facility     = Facility    
   FROM   TRANSFER WITH (NOLOCK)    
   WHERE  TransferKey = @c_TransferKey    
    
   EXECUTE dbo.nspGetRight    
         '',    
         @cFromStorerKey, -- Storer    
         '',              -- Sku    
         'UCCTracking',   -- ConfigKey    
         @b_success              OUTPUT,    
         @cUCCTracking         OUTPUT,    
         @n_err                  OUTPUT,    
         @c_errmsg               OUTPUT    
    
   IF @b_success <> 1    
   BEGIN    
      SELECT @nContinue = 3    
      SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62900    
      SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(RTrim(@n_err),0))    
                    + ' Retrieve of Right (ScanInLog) Failed (ispFinalizeTransfer) ( '    
                    + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(RTRIM(@c_errmsg)),'') + ' ) '    
   END    
    
   SET @c_AllowTransferUCC = '0'    
   EXECUTE dbo.nspGetRight    
         @c_Facility,        -- Facility    
         @cFromStorerKey,    -- Storer    
         '',                 -- Sku    
         'AllowUCCTransfer', -- ConfigKey -- (ChewKP01)    
         @b_success              OUTPUT,    
         @c_AllowTransferUCC     OUTPUT,    
         @n_err                  OUTPUT,    
         @c_errmsg               OUTPUT    
    
   IF @b_success <> 1    
   BEGIN    
      SELECT @nContinue = 3    
      SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62900    
      SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(RTrim(@n_err),0))    
                    + ' Retrieve of Right (ScanInLog) Failed (ispFinalizeTransfer) ( '    
                    + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(RTRIM(@c_errmsg)),'') + ' ) '    
   End    
    
    
    
   /* KC01 - start */    
   EXECUTE dbo.nspGetRight    
         '',    
         @cFromStorerKey, -- Storer    
         '',              -- Sku    
         'RemainHoldOnTransfer',   -- ConfigKey    
         @b_success                 OUTPUT,    
         @c_RemainHoldOnTransfer    OUTPUT,    
         @n_err                     OUTPUT,    
         @c_errmsg                  OUTPUT    
    
   IF @b_success <> 1    
   BEGIN    
      SELECT @nContinue = 3    
      SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62900    
      SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(RTrim(@n_err),0))    
                    + ' Retrieve of Right (RemainHoldOnTransfer) Failed (ispFinalizeTransfer) ( '    
                    + ' SQLSvr MESSAGE=' + ISNULL(LTrim(RTrim(@c_errmsg)),'') + ' ) '    
   End    
   /* KC01 - end */    
    
   --(Wan05) - START    
   SET @c_AllowTRFZeroQty = '0'    
   Execute dbo.nspGetRight    
         @c_Facility        -- Facility    
        ,@cFromStorerKey    -- Storer    
        ,''                 -- Sku    
        ,'AllowTransferZeroQty' -- ConfigKey -- (ChewKP01)    
        ,@b_success              OUTPUT    
        ,@c_AllowTRFZeroQty      OUTPUT    
        ,@n_err                  OUTPUT    
        ,@c_errmsg               OUTPUT    
    
   IF @b_success <> 1    
   BEGIN    
      SELECT @nContinue = 3    
      SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62900    
      SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(RTrim(@n_err),0))    
                    + ' Retrieve of Right (AllowTransferZeroQty) Failed (ispFinalizeTransfer) ( '    
                    + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '    
   End    
   --(Wan05) - END    
    
   --(Wan06) - START    
   IF @nContinue=1 or @nContinue=2    
   BEGIN    
      SET @b_success = 0    
      Execute nspGetRight    
              @c_facility    
            , @cFromStorerKey             -- Storer    
            , ''                          -- Sku    
     , 'ChkLocByCommingleSkuFlag'  -- ConfigKey    
            , @b_success                  OUTPUT    
            , @c_ChkLocByCommingleSkuFlag OUTPUT    
            , @n_err                      OUTPUT    
            , @c_errmsg                   OUTPUT    
    
      IF @b_success <> 1    
      BEGIN    
         SET @nContinue = 3    
         SET @n_err = 62901    
         SET @c_errmsg =  'NSQL' + CONVERT(CHAR(5), ISNULL(RTrim(@n_err),0))    
                       + ' Retrieve of Right (ChkLocByCommingleSkuFlag) Failed (ispFinalizeTransfer) ( '    
                       + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '    
         GOTO Quit_Proc    
      END    
   END    
   --(Wan06) - END    
   --(CS01)  -Start    
     IF EXISTS (SELECT 1 FROM dbo.StorerConfig WITH (NOLOCK)    
              WHERE StorerKey = @cFromStorerKey    
              AND   ConfigKey = 'TransferFinalizeLottableRules'    
              AND   sValue = '1')    
      BEGIN    
        SET @nLottableRules = 1    
      END    
      ELSE    
      BEGIN    
        SET @nLottableRules = 0    
      END    
   --(CS01) - End    
    
   IF @nContinue = 1 OR @nContinue = 2    
   BEGIN    
      CREATE TABLE  #tTransferDet    
       ( Rowref      int not NULL Identity(1,1) Primary Key,    
         LOT NVARCHAR(10), LOC NVARCHAR(10), ID NVARCHAR(18), Qty int)    
    
      --Declare @tTransferDet Table (LOT NVARCHAR(10), LOC NVARCHAR(10), ID NVARCHAR(18), Qty int)    
    
      INSERT INTO #tTransferDet (LOT, LOC, ID, Qty)    
      SELECT FromLOT, FromLOC, FromID, SUM(FromQTY)    
      FROM   TransferDetail WITH (NOLOCK)    
      Where  TransferKey = @c_Transferkey    
      AND    TransferLineNumber = CASE WHEN @c_TransferLineNumber = '' THEN TransferLineNumber  --(Wan08)    
                                       ELSE @c_TransferLineNumber END                           --(Wan08)    
      AND    Status < '9'                    --(Wan04)    
      GROUP BY FromLOT, FromLOC, FromID   
      
      SELECT  @c_Transferkey '@c_Transferkey' , @c_TransferLineNumber '@c_TransferLineNumber' 
    
      IF EXISTS(SELECT 1 FROM LOTxLOCxID LLI WITH (NOLOCK)    
                JOIN #tTransferDet TD ON TD.LOT = LLI.LOT AND    
                     TD.LOC = LLI.LOC AND TD.ID = LLI.ID    
               --(Wan05) - START    
               --WHERE TD.Qty > ( LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked))    
               WHERE (@c_AllowTRFZeroQty = '0' AND TD.Qty > ( LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked))    
               OR (@c_AllowTRFZeroQty = '1' AND TD.Qty > 0 AND TD.Qty > ( LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked )) )    
               --(Wan05) - END    
      BEGIN    
         SET @nContinue = 3    
         SET @n_err = 80000    
         SET @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+':Quantity Withdrawal More Then Quantity Avaliable (ispFinalizeTransfer)'    
         GOTO Quit_Proc    
      END    
   END    
    
   ---NJOW01 Start    
     IF @nContinue = 1 OR @nContinue = 2    
   BEGIN    
      DECLARE @cTRFValidationRules  NVARCHAR(30)    
    
      SELECT @cTRFValidationRules = SC.sValue    
      FROM STORERCONFIG SC (NOLOCK)    
      JOIN CODELKUP CL (NOLOCK) ON SC.sValue = CL.Listname    
      WHERE SC.StorerKey = @cFromStorerKey    
      AND SC.Configkey = 'TRFExtendedValidation'    
    
      IF ISNULL(@cTRFValidationRules,'') <> ''    
      BEGIN    
            EXEC isp_TRF_ExtendedValidation @cTransferKey = @c_Transferkey,    
                                             @cTRFValidationRules=@cTRFValidationRules,    
                                             @nSuccess=@b_Success OUTPUT, @cErrorMsg=@c_ErrMsg OUTPUT    
                                          , @c_TransferLineNumber = @c_TransferLineNumber       --(Wan08)    
    
            IF @b_Success <> 1    
            BEGIN    
               SELECT @nContinue = 3    
               SELECT @n_err = 80020    
               GOTO Quit_Proc    
            END    
      END    
      ELSE    
      BEGIN    
            SELECT @cTRFValidationRules = SC.sValue    
            FROM STORERCONFIG SC (NOLOCK)    
            WHERE SC.StorerKey = @cFromStorerKey    
            AND SC.Configkey = 'TRFExtendedValidation'    
    
            IF EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@cTRFValidationRules) AND type = 'P')    
            BEGIN    
               SET @c_SQL = 'EXEC ' + @cTRFValidationRules + ' @c_TransferKey, @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT '    
                                    + ',@c_TransferLineNumber'                      --(Wan08)    
    
               EXEC sp_EXECUTEsql @c_SQL,    
                    N'@c_TransferKey NVARCHAR(10), @b_Success Int OUTPUT, @n_Err Int OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT    
                     ,@c_TransferLineNumber NVARCHAR(5)' ,                          --(Wan08)    
                    @c_TransferKey,    
                    @b_Success OUTPUT,    
                    @n_Err OUTPUT,    
                    @c_ErrMsg OUTPUT    
                  , @c_TransferLineNumber      --(Wan08)    
    
               IF @b_Success <> 1    
               BEGIN    
           SELECT @nContinue = 3    
                  SELECT @n_err = 80030    
                  GOTO Quit_Proc    
               END    
            END    
      END    
   END --    IF @n_Continue = 1 OR @n_Continue = 2    
   ---NJOW01 End    
    
   --NJOW02 Start    
   DECLARE @cListname NVARCHAR(10)    
    
   SELECT @cListname = MAX(SC.sValue)    
   FROM STORERCONFIG SC (NOLOCK)    
   JOIN CODELKUP CL (NOLOCK) ON SC.Svalue = CL.Listname    
   WHERE SC.StorerKey = @cFromStorerKey    
   AND SC.Configkey = 'TRFCombineValidation_LN'    
    
   IF ISNULL(@cListname,'') <> ''    
   BEGIN    
        SET @cTransferLineNumber = ''    
    
      SELECT @cTransferLineNumber = MIN(TD.TransferLineNumber)    
      FROM TRANSFER T (NOLOCK)    
      JOIN TRANSFERDETAIL TD (NOLOCK) ON T.Transferkey = TD.Transferkey    
      JOIN LOC L1 (NOLOCK) ON TD.FromLoc = L1.Loc    
      JOIN LOC L2 (NOLOCK) ON TD.ToLoc = L2.Loc    
      LEFT JOIN CODELKUP CL (NOLOCK) ON T.Type = LEFT(CL.Code,3)    
                                     AND T.FromStorerkey = CL.Storerkey    
                                     AND T.Facility = CL.Short    
                                     AND T.ToFacility = CL.UDF02    
                                     AND TD.Lottable01 = CL.UDF01    
                                     AND TD.ToLottable01 = CL.UDF04    
                                     AND L1.HostWHCode = CL.Long    
                                     AND L2.HostWHCode = CL.UDF03    
                                     AND CL.Listname = @cListname    
      WHERE T.Transferkey = @c_TransferKey    
      AND   TD.TransferLineNumber = CASE WHEN @c_TransferLineNumber = '' THEN TD.TransferLineNumber   --(Wan08)    
                                         ELSE @c_TransferLineNumber END                               --(Wan08)    
      AND CL.Code IS NULL    
    
      IF ISNULL(@cTransferLineNumber,'') <> ''    
      BEGIN    
         SET @nContinue = 3    
         SET @n_err = 80031    
         SET @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+':Invalid Combination in Line# ' + RTRIM(@cTransferLineNumber) +' (ispFinalizeTransfer)'    
         GOTO Quit_Proc    
      END    
   END    
   --NJOW02 End    
    
   --NJOW03 - START    
   SET @b_Success = 0    
   SET @c_PreFinalizeTransferSP = ''    
   EXEC nspGetRight    
         @c_Facility  = @c_Facility    
       , @c_StorerKey = @cFromStorerKey    
       , @c_sku       = NULL    
       , @c_ConfigKey = 'PreFinalizeTranferSP'    
       , @b_Success   = @b_Success                  OUTPUT    
       , @c_authority = @c_PreFinalizeTransferSP    OUTPUT    
       , @n_err       = @n_err                      OUTPUT    
       , @c_errmsg    = @c_errmsg                   OUTPUT    
    
   IF EXISTS (SELECT 1 FROM sys.objects o WHERE NAME = @c_PreFinalizeTransferSP AND TYPE = 'P')    
   BEGIN    
      SET @b_Success = 0    
      EXECUTE dbo.ispPreFinalizeTransferWrapper    
              @c_TransferKey             = @c_TransferKey    
            , @c_PreFinalizeTransferSP  = @c_PreFinalizeTransferSP    
            , @b_Success = @b_Success     OUTPUT    
            , @n_Err     = @n_err         OUTPUT    
            , @c_ErrMsg  = @c_errmsg      OUTPUT    
            , @b_debug   = 0    
            , @c_TransferLineNumber = @c_TransferLineNumber                      --(Wan08)    
    
      IF @n_err <> 0    
      BEGIN    
         SET @nContinue= 3    
         SET @b_Success = 0    
         SET @n_err  = 60071    
         SET @c_errmsg = 'Execute ispPreFinalizeTransferWrapper Failed.'    
                       + '(' + @c_errmsg + ')'    
      END    
   END    
   --NJOW03 - End       
    
   --(Wan07) - START    
   CREATE TABLE #TMP_TFD    
      (  TransferKey          NVARCHAR(10) DEFAULT ('')    
      ,  TransferlineNumber   NVARCHAR(5)  DEFAULT ('')    
      ,  FromStorerkey        NVARCHAR(15) DEFAULT ('')    
      ,  FromSku              NVARCHAR(20) DEFAULT ('')    
      ,  FromLoc              NVARCHAR(10) DEFAULT ('')    
      ,  ToStorerkey          NVARCHAR(15) DEFAULT ('')    
      ,  ToSku                NVARCHAR(20) DEFAULT ('')    
      ,  ToLoc                NVARCHAR(10) DEFAULT ('')    
      )    
   CREATE INDEX IX_TMP_TFD_TRF on #TMP_TFD ( FromLoc )    
    
   CREATE TABLE #TMP_LLI    
      (  Storerkey            NVARCHAR(15) DEFAULT ('')    
      ,  Sku                  NVARCHAR(20) DEFAULT ('')    
      ,  Loc                  NVARCHAR(10) DEFAULT ('')    
      ,  Qty                  INT          DEFAULT (0)    
      ,  QtyAllocated         INT          DEFAULT (0)    
      ,  QtyPicked            INT          DEFAULT (0)    
      ,  Lottable01           NVARCHAR(18) DEFAULT ('')    
      ,  Lottable02           NVARCHAR(18) DEFAULT ('')    
      ,  Lottable03           NVARCHAR(18) DEFAULT ('')    
      ,  Lottable04           DATETIME     DEFAULT ('')    
      ,  Lottable05           DATETIME     DEFAULT ('19000101')    
      ,  Lottable06           NVARCHAR(30) DEFAULT ('19000101')    
      ,  Lottable07           NVARCHAR(30) DEFAULT ('')    
      ,  Lottable08           NVARCHAR(30) DEFAULT ('')    
      ,  Lottable09           NVARCHAR(30) DEFAULT ('')    
      ,  Lottable10           NVARCHAR(30) DEFAULT ('')    
      ,  Lottable11           NVARCHAR(30) DEFAULT ('')    
      ,  Lottable12           NVARCHAR(30) DEFAULT ('')    
      ,  Lottable13           DATETIME     DEFAULT ('19000101')    
      ,  Lottable14           DATETIME     DEFAULT ('19000101')    
      ,  Lottable15           DATETIME     DEFAULT ('19000101')    
      )    
    
   CREATE INDEX IX_TMP_TFD_skuxloc on #TMP_LLI ( Storerkey, Sku, Loc )    
   INSERT INTO #TMP_TFD    
      (  TransferKey    
      ,  TransferlineNumber    
      ,  FromStorerkey    
      ,  FromSku    
      ,  FromLoc    
      ,  ToStorerkey    
      ,  ToSku    
      ,  ToLoc    
      )    
   SELECT  TransferKey    
         , TransferlineNumber    
         , FromStorerkey    
         , FromSku    
         , FromLoc    
         , ToStorerkey    
         , ToSku    
         , ToLoc    
   FROM TRANSFERDETAIL TD WITH (NOLOCK)    
   JOIN LOC            TL WITH (NOLOCK) ON (TD.ToLoc = TL.Loc)    
   WHERE TD.TransferKey = @c_Transferkey    
   AND   TD.TransferLineNumber = CASE WHEN @c_TransferLineNumber = '' THEN TD.TransferLineNumber   --(Wan08)    
                                      ELSE @c_TransferLineNumber END                               --(Wan08)    
   AND   TD.Status  < '9'    
   AND   ( (TL.CommingleSku IN ('0', 'N') AND @c_ChkLocByCommingleSkuFlag = '1')    
   OR      (TL.NoMixLottable01 IN ('1', 'Y'))    
   OR      (TL.NoMixLottable02 IN ('1', 'Y'))    
   OR      (TL.NoMixLottable03 IN ('1', 'Y'))    
   OR      (TL.NoMixLottable04 IN ('1', 'Y'))    
   OR      (TL.NoMixLottable06 IN ('1', 'Y'))    
   OR      (TL.NoMixLottable07 IN ('1', 'Y'))    
   OR      (TL.NoMixLottable08 IN ('1', 'Y'))    
   OR      (TL.NoMixLottable09 IN ('1', 'Y'))    
   OR      (TL.NoMixLottable10 IN ('1', 'Y'))    
   OR      (TL.NoMixLottable11 IN ('1', 'Y'))    
   OR      (TL.NoMixLottable12 IN ('1', 'Y'))    
   OR      (TL.NoMixLottable13 IN ('1', 'Y'))    
   OR      (TL.NoMixLottable14 IN ('1', 'Y'))    
   OR      (TL.NoMixLottable15 IN ('1', 'Y')) )    
    
   IF EXISTS ( SELECT 1    
               FROM #TMP_TFD )    
   BEGIN    
    
      -- Insert FromLoc Inventory    
      INSERT INTO #TMP_LLI    
         (  Storerkey    
         ,  Sku    
         ,  Loc    
         ,  Qty    
         ,  QtyAllocated    
         ,  QtyPicked    
         ,  Lottable01    
         ,  Lottable02    
         ,  Lottable03    
         ,  Lottable04    
         ,  Lottable05    
         ,  Lottable06    
         ,  Lottable07    
         ,  Lottable08    
         ,  Lottable09    
         ,  Lottable10    
         ,  Lottable11    
         ,  Lottable12    
         ,  Lottable13    
         ,  Lottable14    
         ,  Lottable15    
         )    
      SELECT   LLI.Storerkey    
            ,  LLI.Sku    
            ,  LLI.Loc    
            ,  SUM(LLI.Qty)    
            ,  SUM(LLI.QtyAllocated)    
            ,  SUM(LLI.QtyPicked)    
            ,  LA.Lottable01    
            ,  LA.Lottable02    
            ,  LA.Lottable03    
            ,  CASE WHEN LA.Lottable04 IS NULL THEN '19000101' ELSE LA.Lottable04 END    
            ,  CASE WHEN LA.Lottable05 IS NULL THEN '19000101' ELSE LA.Lottable05 END    
            ,  LA.Lottable06    
            ,  LA.Lottable07    
            ,  LA.Lottable08    
            ,  LA.Lottable09    
            ,  LA.Lottable10    
            ,  LA.Lottable11    
            ,  LA.Lottable12    
            ,  CASE WHEN LA.Lottable13 IS NULL THEN '19000101' ELSE LA.Lottable13 END    
            ,  CASE WHEN LA.Lottable14 IS NULL THEN '19000101' ELSE LA.Lottable14 END    
            ,  CASE WHEN LA.Lottable15 IS NULL THEN '19000101' ELSE LA.Lottable15 END    
      FROM LOTxLOCxID   LLI WITH (NOLOCK)    
      JOIN LOTATTRIBUTE LA  WITH (NOLOCK) ON (LLI.Lot = LA.Lot)    
      WHERE EXISTS (SELECT 1    
                    FROM #TMP_TFD TD WITH (NOLOCK)    
                    WHERE TD.FromLoc = LLI.Loc)    
      AND LLI.Qty > 0    
      GROUP BY LLI.Storerkey    
            ,  LLI.Sku    
            ,  LLI.Loc    
            ,  LA.Lottable01    
            ,  LA.Lottable02    
            ,  LA.Lottable03    
            ,  CASE WHEN LA.Lottable04 IS NULL THEN '19000101' ELSE LA.Lottable04 END    
            ,  CASE WHEN LA.Lottable05 IS NULL THEN '19000101' ELSE LA.Lottable05 END    
            ,  LA.Lottable06    
            ,  LA.Lottable07    
            ,  LA.Lottable08    
            ,  LA.Lottable09    
            ,  LA.Lottable10    
            ,  LA.Lottable11    
            ,  LA.Lottable12    
            ,  CASE WHEN LA.Lottable13 IS NULL THEN '19000101' ELSE LA.Lottable13 END    
            ,  CASE WHEN LA.Lottable14 IS NULL THEN '19000101' ELSE LA.Lottable14 END    
            ,  CASE WHEN LA.Lottable15 IS NULL THEN '19000101' ELSE LA.Lottable15 END    
    
      -- Insert ToLoc Inventory    
      INSERT INTO #TMP_LLI    
         (  Storerkey    
         ,  Sku    
         ,  Loc    
         ,  Qty    
         ,  QtyAllocated    
         ,  QtyPicked    
         ,  Lottable01    
         ,  Lottable02    
         ,  Lottable03    
         ,  Lottable04    
         ,  Lottable05    
         ,  Lottable06    
         ,  Lottable07    
         ,  Lottable08    
         ,  Lottable09    
         ,  Lottable10    
         ,  Lottable11    
         ,  Lottable12    
         ,  Lottable13    
         ,  Lottable14    
         ,  Lottable15    
         )    
      SELECT LLI.Storerkey    
            ,LLI.Sku    
            ,LLI.Loc    
            ,SUM(LLI.Qty)    
            ,SUM(LLI.QtyAllocated)    
            ,SUM(LLI.QtyPicked)    
            ,LA.Lottable01    
            ,LA.Lottable02    
            ,LA.Lottable03    
            ,CASE WHEN LA.Lottable04 IS NULL THEN '19000101' ELSE LA.Lottable04 END    
           ,CASE WHEN LA.Lottable05 IS NULL THEN '19000101' ELSE LA.Lottable05 END    
            ,LA.Lottable06    
            ,LA.Lottable07    
            ,LA.Lottable08    
            ,LA.Lottable09    
            ,LA.Lottable10    
            ,LA.Lottable11    
            ,LA.Lottable12    
            ,CASE WHEN LA.Lottable13 IS NULL THEN '19000101' ELSE LA.Lottable13 END    
            ,CASE WHEN LA.Lottable14 IS NULL THEN '19000101' ELSE LA.Lottable14 END    
            ,CASE WHEN LA.Lottable15 IS NULL THEN '19000101' ELSE LA.Lottable15 END    
      FROM LOTxLOCxID   LLI WITH (NOLOCK)    
      JOIN LOTATTRIBUTE LA  WITH (NOLOCK) ON (LLI.Lot = LA.Lot)    
      WHERE EXISTS (SELECT 1    
                    FROM #TMP_TFD TD WITH (NOLOCK)    
                    WHERE TD.ToLoc = LLI.Loc)    
      AND LLI.Qty > 0    
      GROUP BY LLI.Storerkey    
            ,  LLI.Sku    
            ,  LLI.Loc    
            ,  LA.Lottable01    
            ,  LA.Lottable02    
            ,  LA.Lottable03    
            ,  CASE WHEN LA.Lottable04 IS NULL THEN '19000101' ELSE LA.Lottable04 END    
            ,  CASE WHEN LA.Lottable05 IS NULL THEN '19000101' ELSE LA.Lottable05 END    
            ,  LA.Lottable06    
            ,  LA.Lottable07    
            ,  LA.Lottable08    
            ,  LA.Lottable09    
            ,  LA.Lottable10    
            ,  LA.Lottable11    
            ,  LA.Lottable12    
            ,  CASE WHEN LA.Lottable13 IS NULL THEN '19000101' ELSE LA.Lottable13 END    
            ,  CASE WHEN LA.Lottable14 IS NULL THEN '19000101' ELSE LA.Lottable14 END    
            ,  CASE WHEN LA.Lottable15 IS NULL THEN '19000101' ELSE LA.Lottable15 END    
   END    
    
   DECLARE CUR_TFD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   SELECT Transferkey    
         ,TransferLineNumber    
   FROM #TMP_TFD    
    
   OPEN CUR_TFD    
    
   FETCH NEXT FROM CUR_TFD INTO @c_TrfKey    
                              , @c_TrfLineNo    
    
   WHILE @@FETCH_STATUS <> -1    
   BEGIN    
      SELECT @c_FromStorerkey  = FromStorerkey    
            ,@c_FromSku        = FromSku    
            ,@c_FromLoc        = FromLoc    
            ,@n_FromQty        = FromQty    
            ,@c_FromLottable01 = Lottable01    
            ,@c_FromLottable02 = Lottable02    
            ,@c_FromLottable03 = Lottable03    
            ,@d_FromLottable04 = CASE WHEN Lottable04 IS NULL THEN '19000101' ELSE Lottable04 END    
            ,@d_FromLottable05 = CASE WHEN Lottable05 IS NULL THEN '19000101' ELSE Lottable05 END    
            ,@c_FromLottable06 = Lottable06    
            ,@c_FromLottable07 = Lottable07    
            ,@c_FromLottable08 = Lottable08    
            ,@c_FromLottable09 = Lottable09    
            ,@c_FromLottable10 = Lottable10    
            ,@c_FromLottable11 = Lottable11    
            ,@c_FromLottable12 = Lottable12    
            ,@d_FromLottable13 = CASE WHEN Lottable13 IS NULL THEN '19000101' ELSE Lottable13 END    
            ,@d_FromLottable14 = CASE WHEN Lottable14 IS NULL THEN '19000101' ELSE Lottable14 END    
            ,@d_FromLottable15 = CASE WHEN Lottable15 IS NULL THEN '19000101' ELSE Lottable15 END    
            ,@c_ToStorerkey    = ToStorerkey    
            ,@c_ToSku          = ToSku    
            ,@c_ToLoc          = ToLoc    
            ,@n_ToQty          = ToQty    
            ,@c_ToLottable01   = ToLottable01    
            ,@c_ToLottable02   = ToLottable02    
            ,@c_ToLottable03   = ToLottable03    
            ,@d_ToLottable04   = CASE WHEN ToLottable04 IS NULL THEN '19000101' ELSE ToLottable04 END    
            ,@d_ToLottable05   = CASE WHEN ToLottable05 IS NULL THEN '19000101' ELSE ToLottable05 END    
            ,@c_ToLottable06   = ToLottable06    
            ,@c_ToLottable07   = ToLottable07    
            ,@c_ToLottable08   = ToLottable08    
            ,@c_ToLottable09   = ToLottable09    
            ,@c_ToLottable10   = ToLottable10    
            ,@c_ToLottable11   = ToLottable11    
            ,@c_ToLottable12   = ToLottable12    
            ,@d_ToLottable13   = CASE WHEN ToLottable13 IS NULL THEN '19000101' ELSE ToLottable13 END    
            ,@d_ToLottable14   = CASE WHEN ToLottable14 IS NULL THEN '19000101' ELSE ToLottable14 END    
            ,@d_ToLottable15   = CASE WHEN ToLottable15 IS NULL THEN '19000101' ELSE ToLottable15 END    
      FROM TRANSFERDETAIL WITH (NOLOCK)    
      WHERE TransferKey = @c_TrfKey    
      AND   TransferLineNumber = @c_TrfLineNo    
    
    
      -- WithDraw    
      UPDATE #TMP_LLI    
         SET Qty = Qty - @n_FromQty    
      WHERE Storerkey = @c_FromStorerkey    
      AND   Sku = @c_FromSku    
      AND   Loc = @c_FromLoc    
      AND   Lottable01 = @c_FromLottable01    
      AND   Lottable02 = @c_FromLottable02    
      AND   Lottable03 = @c_FromLottable03    
      AND   Lottable04 = @d_FromLottable04    
      AND   Lottable05 = @d_FromLottable05    
      AND   Lottable06 = @c_FromLottable06    
      AND   Lottable07 = @c_FromLottable07    
      AND   Lottable08 = @c_FromLottable08    
      AND   Lottable09 = @c_FromLottable09    
      AND   Lottable10 = @c_FromLottable10    
      AND   Lottable11 = @c_FromLottable11    
      AND   Lottable12 = @c_FromLottable12    
      AND   Lottable13 = @d_FromLottable13    
      AND   Lottable14 = @d_FromLottable14    
      AND   Lottable15 = @d_FromLottable15    
    
    
      --Deposit    
      UPDATE #TMP_LLI    
         SET Qty = Qty + @n_ToQty    
      WHERE Storerkey  = @c_ToStorerkey    
      AND   Sku        = @c_ToSku    
      AND   Loc        = @c_ToLoc    
      AND   Lottable01 = @c_ToLottable01    
      AND   Lottable02 = @c_ToLottable02    
      AND   Lottable03 = @c_ToLottable03    
      AND   Lottable04 = @d_ToLottable04    
      AND   Lottable05 = @d_ToLottable05    
      AND   Lottable06 = @c_ToLottable06    
      AND   Lottable07 = @c_ToLottable07    
      AND   Lottable08 = @c_ToLottable08    
      AND   Lottable09 = @c_ToLottable09    
      AND   Lottable10 = @c_ToLottable10    
      AND   Lottable11 = @c_ToLottable11    
      AND   Lottable12 = @c_ToLottable12    
      AND   Lottable13 = @d_ToLottable13    
      AND   Lottable14 = @d_ToLottable14    
      AND   Lottable15 = @d_ToLottable15    
    
      IF @@ROWCOUNT = 0    
      BEGIN    
          INSERT INTO #TMP_LLI    
            (  Storerkey    
            ,  Sku    
            ,  Loc    
            ,  Qty    
            ,  Lottable01    
            ,  Lottable02    
            ,  Lottable03    
            ,  Lottable04    
            ,  Lottable05    
            ,  Lottable06    
            ,  Lottable07    
            ,  Lottable08    
            ,  Lottable09    
            ,  Lottable10    
            ,  Lottable11    
            ,  Lottable12    
            ,  Lottable13    
            ,  Lottable14    
            ,  Lottable15    
            )    
         VALUES    
            (  @c_ToStorerkey    
            ,  @c_ToSku    
            ,  @c_ToLoc    
            ,  @n_ToQty    
            ,  @c_ToLottable01    
            ,  @c_ToLottable02    
            ,  @c_ToLottable03    
            ,  @d_ToLottable04    
            ,  @d_ToLottable05    
            ,  @c_ToLottable06    
            ,  @c_ToLottable07    
            ,  @c_ToLottable08    
            ,  @c_ToLottable09    
            ,  @c_ToLottable10    
            ,  @c_ToLottable11    
            ,  @c_ToLottable12    
            ,  @d_ToLottable13    
            ,  @d_ToLottable14    
            ,  @d_ToLottable15    
            )    
      END    
    
      FETCH NEXT FROM CUR_TFD INTO @c_TrfKey    
                                 , @c_TrfLineNo    
   END    
   CLOSE CUR_TFD    
   DEALLOCATE CUR_TFD    
   --(Wan07) - END    
    
   -- 2 XXXXXXX--    
   WHILE @@TRANCOUNT > 0     
      COMMIT TRAN          
          
   IF @nContinue = 1 OR @nContinue = 2    
   BEGIN    
      DECLARE CUR_TRANSFERDET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
         SELECT TransferLineNumber, FromStorerKey, FromSKU,    
          FromLOT,     FromLOC,            FromID,        FromQty,    
                ToStorerKey, ToSKU,              ToLOT,         ToLOC,    
                ToID,        ToQty,              UserDefine01,  UserDefine02,    
                /* KC01 - start */    
                Lottable01,   Lottable02,    Lottable03,    Lottable04,    Lottable05,    
                Lottable06,   Lottable07,    Lottable08,    Lottable09,    Lottable10,    
                Lottable11,   Lottable12,    Lottable13,    Lottable14,    Lottable15,    
                ToLottable01, ToLottable02,  ToLottable03,  ToLottable04,  ToLottable05,    
                ToLottable06, ToLottable07,  ToLottable08,  ToLottable09,  ToLottable10,    
                ToLottable11, ToLottable12,  ToLottable13,  ToLottable14,  ToLottable15    
                /* KC01 - end */    
         FROM   TRANSFERDETAIL WITH (NOLOCK)    
         WHERE  TransferKey = @c_TransferKey    
         AND    TransferLineNumber = CASE WHEN @c_TransferLineNumber = '' THEN TransferLineNumber  --(Wan08)    
                                          ELSE @c_TransferLineNumber END                           --(Wan08)    
         AND    Status <> '9'    
    
    
      OPEN CUR_TRANSFERDET    
    
      FETCH NEXT FROM CUR_TRANSFERDET INTO @cTransferLineNumber, @cFromStorerKey,    
               @cFromSKU,     @cFromLOT,     @cFromLOC,       @cFromID,        @nFromQty,    
               @cToStorerKey, @cToSKU,       @cToLOT,         @cToLOC,    
               @cToID,        @nToQty,       @cFromUCC,       @cToUCC,    
               /* KC01 - start */    
               @c_FromLottable01,   @c_FromLottable02,   @c_FromLottable03,   @d_FromLottable04,   @d_FromLottable05,    
               @c_FromLottable06,   @c_FromLottable07,   @c_FromLottable08,   @c_FromLottable09,   @c_FromLottable10,    
               @c_FromLottable11,   @c_FromLottable12,   @d_FromLottable13,   @d_FromLottable14,   @d_FromLottable15,    
            @c_ToLottable01,     @c_ToLottable02,     @c_ToLottable03,     @d_ToLottable04,     @d_ToLottable05,    
               @c_ToLottable06,     @c_ToLottable07,     @c_ToLottable08,     @c_ToLottable09,     @c_ToLottable10,    
               @c_ToLottable11,     @c_ToLottable12,     @d_ToLottable13,     @d_ToLottable14,     @d_ToLottable15    
               /* KC01 - end */    
    
      WHILE @@FETCH_STATUS <> -1    
      BEGIN    
         -- 2 XXXXXXX--    
         BEGIN TRAN    
    
         -- IN00051925 (Start)    
         SET @c_FromSkuStatus = ''    
         SELECT @c_FromSkuStatus = SkuStatus    
         FROM SKU WITH (NOLOCK)    
         WHERE StorerKey = @cFromStorerKey    
         AND Sku = @cFromSKU    
    
         IF @c_FromSkuStatus = 'SUSPENDED'    
         BEGIN    
            SELECT @nContinue = 3, @n_err = 81005    
            SELECT @c_errmsg = 'NSQL'+ CONVERT(CHAR(5), ISNULL(@n_err,0)) +    
                               ': FromStorer=' + @cFromStorerKey + ', FromSku=' + ISNULL(RTRIM(@cFromSKU),'') +    
                               ' is suspended. Line#: ' + @cTransferLineNumber + ' (ispFinalizeTransfer)'    
            GOTO Quit_Proc    
         END    
    
         SET @c_ToSkuStatus = ''    
         SELECT @c_ToSkuStatus = SkuStatus    
         FROM SKU WITH (NOLOCK)    
         WHERE StorerKey = @cToStorerKey    
         AND Sku = @cToSKU    
    
         IF @c_ToSkuStatus = 'SUSPENDED'    
         BEGIN    
            SELECT @nContinue = 3, @n_err = 81010    
            SELECT @c_errmsg = 'NSQL'+ CONVERT(CHAR(5), ISNULL(@n_err,0)) +    
                               ': ToStorer=' + @cToStorerKey + ', ToSku=' + ISNULL(RTRIM(@cToSKU),'') +    
                               ' is suspended. Line#: ' + @cTransferLineNumber + ' (ispFinalizeTransfer)'    
            GOTO Quit_Proc    
         END    
         -- IN00051925 (End)    
    
         --(CS01) -START    
         IF @nLottableRules = 1    
         BEGIN  --@nLottableRules = 1    
            SELECT    
               @c_Lottable01Value = Lottable01,    
               @c_Lottable02Value = Lottable02,    
               @c_Lottable03Value = Lottable03,    
               @d_Lottable04Value = Lottable04,    
               @d_Lottable05Value = Lottable05,    
               @c_Lottable06Value = Lottable06,    
               @c_Lottable07Value = Lottable07,    
               @c_Lottable08Value = Lottable08,    
               @c_Lottable09Value = Lottable09,    
               @c_Lottable10Value = Lottable10,    
               @c_Lottable11Value = Lottable11,    
               @c_Lottable12Value = Lottable12,    
               @d_Lottable13Value = Lottable13,    
               @d_Lottable14Value = Lottable14,    
               @d_Lottable15Value = Lottable15,    
               @c_sku             = FromSKU    
            FROM dbo.TransferDetail WITH (NOLOCK)    
            WHERE  TransferKey = @c_TransferKey    
            AND    TransferLineNumber = @cTransferLineNumber    
    
            SELECT    
               @c_Lottable01  = @c_Lottable01Value,    
               @c_Lottable02  = @c_Lottable02Value,    
               @c_Lottable03  = @c_Lottable03Value,    
               @d_Lottable04  = @d_Lottable04Value,    
               @d_Lottable05  = @d_Lottable05Value,    
               @c_Lottable06  = @c_Lottable06Value,    
               @c_Lottable07  = @c_Lottable07Value,    
               @c_Lottable08  = @c_Lottable08Value,    
               @c_Lottable09  = @c_Lottable09Value,    
               @c_Lottable10  = @c_Lottable10Value,    
               @c_Lottable11  = @c_Lottable11Value,    
               @c_Lottable12  = @c_Lottable12Value,    
               @d_Lottable13  = @d_Lottable13Value,    
               @d_Lottable14  = @d_Lottable14Value,    
               @d_Lottable15  = @d_Lottable15Value    
    
    
            SELECT @c_LottableLabel01 = Lottable01Label,    
                   @c_LottableLabel02 = Lottable02Label,    
                   @c_LottableLabel03 = Lottable03Label,    
                   @c_LottableLabel04 = Lottable04Label,    
                   @c_LottableLabel05 = Lottable05Label,    
                   @c_LottableLabel06 = Lottable06Label,    
                   @c_LottableLabel07 = Lottable07Label,    
                   @c_LottableLabel08 = Lottable08Label,    
                   @c_LottableLabel09 = Lottable09Label,    
                   @c_LottableLabel10 = Lottable10Label,    
                   @c_LottableLabel11 = Lottable11Label,    
                   @c_LottableLabel12 = Lottable12Label,    
                   @c_LottableLabel13 = Lottable13Label,    
                   @c_LottableLabel14 = Lottable14Label,    
                   @c_LottableLabel15 = Lottable15Label    
            FROM dbo.SKU WITH (NOLOCK)    
            WHERE StorerKey = @cFromStorerKey    
            AND   SKU = @c_sku    
    
            SELECT @n_count = 1, @c_Sourcetype = 'TRANSFERFINALIZE'    
    
            WHILE @n_count <= 15 AND @ncontinue IN(1,2)    --TK01 increase max @n_count to 15    
            BEGIN  --While    
                 SET @c_Sourcekey = RTRIM(@c_TransferKey) --+ RTRIM(@c_ReceiptLineNo) --NJOW07    
    
                 SELECT @c_ListName = 'LOTTABLE0' + CAST(@n_count AS NVARCHAR(2))           --(CS02)    
    
                 SELECT @c_LottableLabel = CASE WHEN @n_count = 1 THEN  @c_LottableLabel01    
                                               WHEN @n_count =  2 THEN  @c_LottableLabel02    
                                               WHEN @n_count =  3 THEN  @c_LottableLabel03    
                                               WHEN @n_count =  4 THEN  @c_LottableLabel04    
                                               WHEN @n_count =  5 THEN  @c_LottableLabel05    
                                               WHEN @n_count =  6 THEN  @c_LottableLabel06    
                                               WHEN @n_count =  7 THEN  @c_LottableLabel07    
                                               WHEN @n_count =  8 THEN  @c_LottableLabel08    
                                               WHEN @n_count =  9 THEN  @c_LottableLabel09    
                                               WHEN @n_count = 10 THEN  @c_LottableLabel10    
                                               WHEN @n_count = 11 THEN  @c_LottableLabel11    
                                               WHEN @n_count = 12 THEN  @c_LottableLabel12    
                                               WHEN @n_count = 13 THEN  @c_LottableLabel13    
                                               WHEN @n_count = 14 THEN  @c_LottableLabel14    
                                               WHEN @n_count = 15 THEN  @c_LottableLabel15    
                                               ELSE ''    
                                          END    
    
               SELECT @c_sp_name = LONG,    
                      @c_UDF01 = UDF01    
               FROM CODELKUP (NOLOCK)    
               WHERE LISTNAME = @c_ListName    
               AND CODE = @c_Lottablelabel    
               AND (Storerkey = @cFromStorerKey OR ISNULL(Storerkey,'')='')    
               ORDER BY Storerkey DESC    
    
               IF ISNULL(@c_sp_name,'') <> ''    
               BEGIN  --ISNULL(@c_sp_name,'') <> ''    
                 --NJOW07    
                 IF ISNULL(@c_UDF01,'') <> ''    
                 BEGIN  --ISNULL(@c_UDF01,'') <> ''    
                    IF EXISTS (SELECT 1    
                                FROM   INFORMATION_SCHEMA.COLUMNS    
                                WHERE  TABLE_NAME = 'TRANSFER'    
                                AND    COLUMN_NAME = @c_UDF01)    
                     BEGIN    
                        SET @c_Value = ''    
                        SET @c_SQL = 'SELECT @c_Value = ' + RTRIM(@c_UDF01) + ' FROM TRANSFER (NOLOCK) WHERE transferkey = @c_transferkey'    
                        SET @c_SQLParm = '@c_Value NVARCHAR(60) OUTPUT, @c_transferkey NVARCHAR(10)'    
    
                       EXEC sp_executesql @c_SQL,    
                          @c_SQLParm,    
                          @c_Value OUTPUT,    
                          @c_transferkey    
    
                        IF ISNULL(@c_Value,'') <> ''    
                           SET @c_Sourcekey = @c_Value    
                    END    
                 END   --ISNULL(@c_UDF01,'') <> ''    
    
                  IF NOT EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_sp_name) AND type = 'P')    
                  BEGIN    
                      SELECT @ncontinue = 3    
                      SELECT @c_ErrMsg = CONVERT(char(250),@n_err), @n_err=62090    
                      SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': Lottable Rule Listname '+ RTRIM(@c_listname)+' - Stored Proc name invalid ('+RTRIM(ISNULL(@c_sp_name,''))+') (ispFinalizeTransfer)'    
                      ROLLBACK TRAN    
                  END    
    
                  SET @c_SQL = 'EXEC ' + @c_sp_name +    
                                 + ' @cFromStorerKey, @c_sku, '    
                                 + ' @c_Lottable01Value, @c_Lottable02Value, @c_Lottable03Value, @d_Lottable04Value, @d_Lottable05Value,'    
                                 + ' @c_Lottable06Value, @c_Lottable07Value, @c_Lottable08Value, @c_Lottable09Value, @c_Lottable10Value,'    
                                 + ' @c_Lottable11Value, @c_Lottable12Value, @d_Lottable13Value, @d_Lottable14Value, @d_Lottable15Value,'    
                                 + ' @c_Lottable01 OUTPUT, @c_Lottable02 OUTPUT , @c_Lottable03 OUTPUT, @d_Lottable04 OUTPUT, @d_Lottable05 OUTPUT,'    
                                 + ' @c_Lottable06 OUTPUT, @c_Lottable07 OUTPUT , @c_Lottable08 OUTPUT, @c_Lottable09 OUTPUT, @c_Lottable10 OUTPUT,'    
                                 + ' @c_Lottable11 OUTPUT, @c_Lottable12 OUTPUT , @d_Lottable13 OUTPUT, @d_Lottable14 OUTPUT, @d_Lottable15 OUTPUT,'    
                                 + ' @b_Success OUTPUT, @n_ErrNo OUTPUT, @c_ErrMsg OUTPUT, @c_Sourcekey, @c_SourceType, @c_LottableLabel'    
    
                   SET @c_SQLParm = '@cFromStorerKey NVARCHAR(15), @c_sku NVARCHAR(20), '    
                                 + '@c_Lottable01Value NVARCHAR(18),    @c_Lottable02Value NVARCHAR(18),    @c_Lottable03Value NVARCHAR(18),    @d_Lottable04Value DATETIME,        @d_Lottable05Value DATETIME,'    
                                 + '@c_Lottable06Value NVARCHAR(30),    @c_Lottable07Value NVARCHAR(30),    @c_Lottable08Value NVARCHAR(30),    @c_Lottable09Value NVARCHAR(30),    @c_Lottable10Value NVARCHAR(30),'    
                                 + '@c_Lottable11Value NVARCHAR(30),    @c_Lottable12Value NVARCHAR(30),    @d_Lottable13Value DATETIME,        @d_Lottable14Value DATETIME,        @d_Lottable15Value DATETIME,'    
                                 + '@c_Lottable01 NVARCHAR(18) OUTPUT,  @c_Lottable02 NVARCHAR(18) OUTPUT,  @c_Lottable03 NVARCHAR(18) OUTPUT,  @d_Lottable04 DATETIME OUTPUT,      @d_Lottable05 DATETIME OUTPUT,'    
                                 + '@c_Lottable06 NVARCHAR(30) OUTPUT,  @c_Lottable07 NVARCHAR(30) OUTPUT,  @c_Lottable08 NVARCHAR(30) OUTPUT,  @c_Lottable09 NVARCHAR(30) OUTPUT,  @c_Lottable10 NVARCHAR(30) OUTPUT,'    
                                 + '@c_Lottable11 NVARCHAR(30) OUTPUT,  @c_Lottable12 NVARCHAR(30) OUTPUT,  @d_Lottable13 DATETIME OUTPUT,      @d_Lottable14 DATETIME OUTPUT,      @d_Lottable15 DATETIME OUTPUT,'    
                                 + '@b_Success INT OUTPUT, @n_ErrNo INT OUTPUT,'    
                                 + '@c_ErrMsg NVARCHAR(250) OUTPUT, @c_Sourcekey NVARCHAR(15), @c_SourceType NVARCHAR(20), @c_LottableLabel NVARCHAR(20)'    
    
              EXEC sp_EXECUTEsql @c_SQL,    
                        @c_SQLParm,    
                        @cFromStorerKey    ,    
                        @c_sku             ,    
                        @c_Lottable01Value ,    
                        @c_Lottable02Value ,    
                        @c_Lottable03Value ,    
                        @d_Lottable04Value ,    
                        @d_Lottable05Value ,    
                        @c_Lottable06Value ,    
                        @c_Lottable07Value ,    
                        @c_Lottable08Value ,    
                        @c_Lottable09Value ,    
                        @c_Lottable10Value ,    
                        @c_Lottable11Value ,    
  @c_Lottable12Value ,    
                        @d_Lottable13Value ,    
                        @d_Lottable14Value ,    
                        @d_Lottable15Value ,    
                        @c_Lottable01    OUTPUT,    
                        @c_Lottable02    OUTPUT,    
                        @c_Lottable03    OUTPUT,    
                        @d_Lottable04    OUTPUT,    
                        @d_Lottable05    OUTPUT,    
                        @c_Lottable06    OUTPUT,    
                        @c_Lottable07    OUTPUT,    
                        @c_Lottable08    OUTPUT,    
                        @c_Lottable09    OUTPUT,    
                        @c_Lottable10    OUTPUT,    
                        @c_Lottable11    OUTPUT,    
                        @c_Lottable12    OUTPUT,    
                        @d_Lottable13    OUTPUT,    
                        @d_Lottable14    OUTPUT,    
                        @d_Lottable15    OUTPUT,    
                        @b_Success       OUTPUT,    
                        @n_ErrNo         OUTPUT,    
                        @c_Errmsg        OUTPUT,    
                        @c_Sourcekey,    
                        @c_SourceType,    
                        @c_LottableLabel    
    
                  IF @n_ErrNo <> 0    
                  BEGIN    
                     SELECT @ncontinue = 3    
                     SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_ErrNo)+': Finalize Transfer Fail. (''ispFinalizeTransfer'')' + ' ( ' + ' SQLSvr MESSAGE=' + RTrim(@c_ErrMsg) + ' ) '    
                     ROLLBACK TRAN    
                  END    
    
              UPDATE TRANSFERDETAIL WITH (ROWLOCK)    
                     SET ToLottable01 = CASE WHEN ISNULL(@c_Lottable01, '')  = '' THEN ToLottable01 ELSE @c_Lottable01 END,    
                         ToLottable02 = CASE WHEN ISNULL(@c_Lottable02, '')  = '' THEN ToLottable02 ELSE @c_Lottable02 END,    
                         ToLottable03 = CASE WHEN ISNULL(@c_Lottable03, '')  = '' THEN ToLottable03 ELSE @c_Lottable03 END,    
                         ToLottable04 = CASE WHEN ISNULL(@d_Lottable04, '')  = '' THEN ToLottable04 ELSE @d_Lottable04 END,    
                         ToLottable05 = CASE WHEN ISNULL(@d_Lottable05, '')  = '' THEN ToLottable05 ELSE @d_Lottable05 END,    
                         ToLottable06 = CASE WHEN ISNULL(@c_Lottable06, '')  = '' THEN ToLottable06 ELSE @c_Lottable06 END,    
                         ToLottable07 = CASE WHEN ISNULL(@c_Lottable07, '')  = '' THEN ToLottable07 ELSE @c_Lottable07 END,    
                         ToLottable08 = CASE WHEN ISNULL(@c_Lottable08, '')  = '' THEN ToLottable08 ELSE @c_Lottable08 END,    
                         ToLottable09 = CASE WHEN ISNULL(@c_Lottable09, '')  = '' THEN ToLottable09 ELSE @c_Lottable09 END,    
                         ToLottable10 = CASE WHEN ISNULL(@c_Lottable10, '')  = '' THEN ToLottable10 ELSE @c_Lottable10 END,    
                         ToLottable11 = CASE WHEN ISNULL(@c_Lottable11, '')  = '' THEN ToLottable11 ELSE @c_Lottable11 END,    
                         ToLottable12 = CASE WHEN ISNULL(@c_Lottable12, '')  = '' THEN ToLottable12 ELSE @c_Lottable12 END,    
                         ToLottable13 = CASE WHEN ISNULL(@d_Lottable13, '')  = '' THEN ToLottable13 ELSE @d_Lottable13 END,    
                         ToLottable14 = CASE WHEN ISNULL(@d_Lottable14, '')  = '' THEN ToLottable14 ELSE @d_Lottable14 END,    
                         ToLottable15 = CASE WHEN ISNULL(@d_Lottable15, '')  = '' THEN ToLottable15 ELSE @d_Lottable15 END,    
                         EditDate = GETDATE(),    
                         EditWho = SUSER_SNAME(),    
                         TrafficCop = NULL    
                   WHERE  TransferKey = @c_TransferKey    
                   AND    TransferLineNumber = @cTransferLineNumber    
    
   --                SELECT * FROM transferdetail (NOLOCK)    
   --                WHERE  TransferKey = @c_TransferKey    
   --                AND    TransferLineNumber = @cTransferLineNumber    
    
                  SELECT @n_err = @@ERROR    
                  IF @n_err <> 0    
                BEGIN    
                     SELECT @ncontinue = 3    
                     SELECT @c_ErrMsg = CONVERT(char(250),@n_err), @n_err=62100    
                     SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': Finalize Transfer Fail. (''ispFinalizeTransfer'')' + ' ( ' + ' SQLSvr MESSAGE=' + RTrim(@c_ErrMsg) + ' ) '    
                     ROLLBACK TRAN    
                  END    
               END    
    
               SET @n_count = @n_count + 1    
            END --While    
         END    
         --(CS01) -End    
    
         --(Wan05) - START    
         IF @c_AllowTRFZeroQty = '1' AND @nFromQty = 0 AND @nToQty = 0    
         BEGIN    
            UPDATE TRANSFERDETAIL WITH (ROWLOCK)    
            SET STATUS = '9'    
              , Trafficcop = NULL    
              , EditDate = GETDATE()    
              , EditWho = SUSER_SNAME()    
            WHERE  TransferKey = @c_TransferKey    
            AND    TransferLineNumber = @cTransferLineNumber    
            AND    Status <> '9'    
    
            IF @@ERROR <> 0    
            BEGIN    
               SET @nContinue = 3    
               SET @n_err = 80010    
               SET @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': Finalize ispFinalizeTransfer Fail. (''ispFinalizeTransfer'')'    
                            + ' ( ' + ' SQLSvr MESSAGE=' + RTrim(@c_ErrMsg) + ' ) '    
               GOTO Quit_Proc    
            END    
    
            UPDATE TRANSFER WITH (ROWLOCK)    
            SET OpenQty = OpenQty - @nFromQty    
 , EditDate = GETDATE()    
              , EditWho = SUSER_SNAME()    
            WHERE TransferKey = @c_TransferKey    
    
            IF @@ERROR <> 0    
            BEGIN    
               SET @nContinue = 3    
               SET @n_err = 80011    
               SET @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': Finalize ispFinalizeTransfer Fail. (''ispFinalizeTransfer'')'    
                            + ' ( ' + ' SQLSvr MESSAGE=' + RTrim(@c_ErrMsg) + ' ) '    
               GOTO Quit_Proc    
            END    
    
            GOTO NEXT_TRFDET    
         END    
         --(Wan05) - END    
    
         --(Wan01) - START    
         IF RTRIM(@cToLOT) <> ''    
         BEGIN    
            SELECT @c_IDStorerkey  = RTRIM(LA.Storerkey)    
                  ,@c_IDSku        = RTRIM(LA.Sku)    
                  ,@c_IDLottable01 = RTRIM(LA.Lottable01)    
                  ,@c_IDLottable02 = RTRIM(LA.Lottable02)    
                  ,@c_IDLottable03 = RTRIM(LA.Lottable03)    
                  ,@d_IDLottable04 = ISNULL(LA.Lottable04, CONVERT(DATETIME,'19000101'))    
                  ,@c_IDLottable06 = RTRIM(LA.Lottable06)    
                  ,@c_IDLottable07 = RTRIM(LA.Lottable07)    
                  ,@c_IDLottable08 = RTRIM(LA.Lottable08)    
                  ,@c_IDLottable09 = RTRIM(LA.Lottable09)    
                  ,@c_IDLottable10 = RTRIM(LA.Lottable10)    
                  ,@c_IDLottable11 = RTRIM(LA.Lottable11)    
                  ,@c_IDLottable12 = RTRIM(LA.Lottable12)    
                  ,@d_IDLottable13 = ISNULL(LA.Lottable13, CONVERT(DATETIME,'19000101'))    
                  ,@d_IDLottable14 = ISNULL(LA.Lottable14, CONVERT(DATETIME,'19000101'))    
                  ,@d_IDLottable15 = ISNULL(LA.Lottable15, CONVERT(DATETIME,'19000101'))    
            FROM LOTATTRIBUTE LA WITH (NOLOCK)    
            WHERE LA.Lot = @cToLOT    
         END    
         ELSE    
         BEGIN    
            SET @c_IDStorerkey  = @cToStorerkey    
            SET @c_IDSku        = @cToSKU    
            SET @c_IDLottable01 = @c_ToLottable01    
            SET @c_IDLottable02 = @c_ToLottable02    
            SET @c_IDLottable03 = @c_ToLottable03    
            SET @d_IDLottable04 = ISNULL(@d_ToLottable04, CONVERT(DATETIME,'19000101'))    
            SET @c_IDLottable06 = @c_ToLottable06    
            SET @c_IDLottable07 = @c_ToLottable07    
            SET @c_IDLottable08 = @c_ToLottable08    
            SET @c_IDLottable09 = @c_ToLottable09    
            SET @c_IDLottable10 = @c_ToLottable10    
            SET @c_IDLottable11 = @c_ToLottable11    
            SET @c_IDLottable12 = @c_ToLottable12    
            SET @d_IDLottable13 = ISNULL(@d_ToLottable13, CONVERT(DATETIME,'19000101'))    
            SET @d_IDLottable14 = ISNULL(@d_ToLottable14, CONVERT(DATETIME,'19000101'))    
            SET @d_IDLottable15 = ISNULL(@d_ToLottable15, CONVERT(DATETIME,'19000101'))    
         END    
    
         SELECT @c_NoMixLottable01 = CASE WHEN LOC.NoMixLottable01 IN ('1','Y') THEN '1' ELSE '0' END  --(Wan06)    
               ,@c_NoMixLottable02 = CASE WHEN LOC.NoMixLottable02 IN ('1','Y') THEN '1' ELSE '0' END  --(Wan06)    
               ,@c_NoMixLottable03 = CASE WHEN LOC.NoMixLottable03 IN ('1','Y') THEN '1' ELSE '0' END  --(Wan06)    
               ,@c_NoMixLottable04 = CASE WHEN LOC.NoMixLottable04 IN ('1','Y') THEN '1' ELSE '0' END  --(Wan06)    
               ,@c_NoMixLottable06 = CASE WHEN LOC.NoMixLottable06 IN ('1','Y') THEN '1' ELSE '0' END  --(Wan07)    
               ,@c_NoMixLottable07 = CASE WHEN LOC.NoMixLottable07 IN ('1','Y') THEN '1' ELSE '0' END  --(Wan07)    
               ,@c_NoMixLottable08 = CASE WHEN LOC.NoMixLottable08 IN ('1','Y') THEN '1' ELSE '0' END  --(Wan07)    
               ,@c_NoMixLottable09 = CASE WHEN LOC.NoMixLottable09 IN ('1','Y') THEN '1' ELSE '0' END  --(Wan07)    
               ,@c_NoMixLottable10 = CASE WHEN LOC.NoMixLottable10 IN ('1','Y') THEN '1' ELSE '0' END  --(Wan07)    
               ,@c_NoMixLottable11 = CASE WHEN LOC.NoMixLottable11 IN ('1','Y') THEN '1' ELSE '0' END  --(Wan07)    
               ,@c_NoMixLottable12 = CASE WHEN LOC.NoMixLottable12 IN ('1','Y') THEN '1' ELSE '0' END  --(Wan07)    
               ,@c_NoMixLottable13 = CASE WHEN LOC.NoMixLottable13 IN ('1','Y') THEN '1' ELSE '0' END  --(Wan07)    
               ,@c_NoMixLottable14 = CASE WHEN LOC.NoMixLottable14 IN ('1','Y') THEN '1' ELSE '0' END  --(Wan07)    
               ,@c_NoMixLottable15 = CASE WHEN LOC.NoMixLottable15 IN ('1','Y') THEN '1' ELSE '0' END  --(Wan07)    
               ,@c_CommingleSku    = CASE WHEN LOC.CommingleSku    IN ('1','Y') THEN '1' ELSE '0' END  --(Wan06)    
         FROM LOC WITH (NOLOCK)    
         WHERE LOC = @cToLOC    
    
        --(Wan06) - START    
         IF @c_ChkLocByCommingleSkuFlag = '0'    
         BEGIN    
            IF @c_NoMixLottable01 = '1' OR @c_NoMixLottable02 = '1' OR @c_NoMixLottable03 = '1' OR @c_NoMixLottable04 = '1'    
            OR @c_NoMixLottable06 = '1' OR @c_NoMixLottable07 = '1' OR @c_NoMixLottable08 = '1' OR @c_NoMixLottable09 = '1' OR @c_NoMixLottable10 = '1'--(Wan07)    
            OR @c_NoMixLottable11 = '1' OR @c_NoMixLottable12 = '1' OR @c_NoMixLottable13 = '1' OR @c_NoMixLottable14 = '1' OR @c_NoMixLottable15 = '1'--(Wan07)    
            BEGIN    
               SET @c_CommingleSku = '0'    
            END    
            ELSE    
            BEGIN    
               SET @c_CommingleSku = '1'    
            END    
         END    
    
           --(Wan06) - END    
    
         IF @c_CommingleSku = '0'                                    --(Wan06)    
         --IF @c_NoMixLottable01 = '1' OR @c_NoMixLottable02 = '1' OR @c_NoMixLottable03 = '1' OR @c_NoMixLottable04 = '1'                               --(Wan06)    
         --   OR @c_NoMixLottable06 = '1' OR @c_NoMixLottable07 = '1' OR @c_NoMixLottable08 = '1' OR @c_NoMixLottable09 = '1' OR @c_NoMixLottable10 = '1'--(Wan07)    
         --   OR @c_NoMixLottable11 = '1' OR @c_NoMixLottable12 = '1' OR @c_NoMixLottable13 = '1' OR @c_NoMixLottable14 = '1' OR @c_NoMixLottable15 = '1'--(Wan07)    
         BEGIN    
            --(Wan07) - START    
            IF EXISTS ( SELECT 1    
                        FROM #TMP_LLI LLI    
                        WHERE LLI.Loc = @cToLOC    
                        AND   LLI.Qty - LLI.QtyPicked > 0    
                        GROUP BY LLI.Loc    
                        HAVING COUNT(DISTINCT LLI.Sku) > 1    
                      )    
--            IF EXISTS (SELECT 1 FROM LOTxLOCxID LLI WITH (NOLOCK)    
--                       WHERE LLI.Loc = @cToLOC    
--                       AND  (LLI.Storerkey <> @c_IDStorerkey OR  LLI.Sku <> @c_IDSku)    
--                       AND   LLI.Qty - LLI.QtyPicked > 0)  --(Wan02)    
----                       AND   LLI.Qty > 0)     --(Wan02)    
            --(Wan07) - END    
            BEGIN    
               SET @nContinue = 3    
               SET @n_err = 80009    
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)    
                           +': Not Allow to transfer commingle sku to Location: ' + RTRIM(@cToLOC)    
                           + '. (ispFinalizeTransfer)'    
               GOTO Quit_Proc    
            END    
         END    
    
         IF @c_NoMixLottable01 = '1'    
         BEGIN    
--            IF EXISTS (SELECT 1 FROM LOTATTRIBUTE LA WITH (NOLOCK)    
--                       JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)    
--                       WHERE LLI.Loc = @cToLOC    
--                       AND   (LA.Storerkey = @c_IDStorerkey AND LA.Sku = @c_IDSku AND LA.Lottable01 <> @c_IDLottable01)    
--                       AND   LLI.Qty - LLI.QtyPicked > 0   --(Wan02)    
--                       AND   LLI.Qty > 0)                 --(Wan02)    
           --(Wan07) - START    
           IF EXISTS ( SELECT 1    
                       FROM #TMP_LLI LLI    
                       WHERE LLI.Loc = @cToLOC    
                       AND   LLI.Qty - LLI.QtyPicked > 0    
                       GROUP BY LLI.Storerkey, LLI.Sku    
                       HAVING COUNT(DISTINCT LLI.Lottable01) > 1    
                     )    
           --(Wan07) - END    
            BEGIN    
               SET @nContinue = 3    
               SET @n_err = 80005    
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)    
                           +': Not Allow to transfer to No Mix Lottable01 Location: ' +  RTRIM(@cToLOC) + '. (ispFinalizeTransfer)'    
               GOTO Quit_Proc    
            END    
         END    
    
         IF @c_NoMixLottable02 = '1'    
         BEGIN    
--            IF EXISTS (SELECT 1 FROM LOTATTRIBUTE LA WITH (NOLOCK)    
--                       JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)    
--                       WHERE LLI.Loc = @cToLOC    
--                       AND   (LA.Storerkey = @c_IDStorerkey AND LA.Sku = @c_IDSku AND LA.Lottable02 <> @c_IDLottable02)    
--                       AND   LLI.Qty - LLI.QtyPicked > 0    --(Wan02)    
--                       AND   LLI.Qty > 0)                 --(Wan02)    
           --(Wan07) - START    
           IF EXISTS ( SELECT 1    
                       FROM #TMP_LLI LLI    
                       WHERE LLI.Loc = @cToLOC    
                       AND   LLI.Qty - LLI.QtyPicked > 0    
                       GROUP BY LLI.Storerkey, LLI.Sku    
                       HAVING COUNT(DISTINCT LLI.Lottable02) > 1    
                     )    
           --(Wan07) - END    
            BEGIN    
               SET @nContinue = 3    
               SET @n_err = 80006    
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)    
                           +': Not Allow to transfer to No Mix Lottable02 Location: ' +  RTRIM(@cToLOC) + '. (ispFinalizeTransfer)'    
               GOTO Quit_Proc    
            END    
         END    
    
         IF @c_NoMixLottable03 = '1'    
         BEGIN    
--            IF EXISTS (SELECT 1 FROM LOTATTRIBUTE LA WITH (NOLOCK)    
--                       JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)    
--                      WHERE LLI.Loc = @cToLOC    
--                       AND   (LA.Storerkey = @c_IDStorerkey AND LA.Sku = @c_IDSku AND LA.Lottable03 <> @c_IDLottable03)    
--                       AND   LLI.Qty - LLI.QtyPicked > 0    --(Wan02)    
--                       AND   LLI.Qty > 0)                 --(Wan02)    
                       --(Wan06) - START    
           --(Wan07) - START    
           IF EXISTS ( SELECT 1    
                       FROM #TMP_LLI LLI    
                       WHERE LLI.Loc = @cToLOC    
                       AND   LLI.Qty - LLI.QtyPicked > 0    
                       GROUP BY LLI.Storerkey, LLI.Sku    
                       HAVING COUNT(DISTINCT LLI.Lottable03) > 1    
                     )    
           --(Wan07) - END    
            BEGIN    
               SET @nContinue = 3    
               SET @n_err = 80007    
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)    
                           +': Not Allow to transfer to No Mix Lottable03 Location: ' +  RTRIM(@cToLOC) + '. (ispFinalizeTransfer)'    
               GOTO Quit_Proc    
            END    
         END    
    
         IF @c_NoMixLottable04 = '1'    
         BEGIN    
--            IF EXISTS (SELECT 1 FROM LOTATTRIBUTE LA WITH (NOLOCK)    
--                       JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)    
--                       WHERE LLI.Loc = @cToLOC    
--                       AND   (LA.Storerkey = @c_IDStorerkey AND LA.Sku = @c_IDSku    
--                       AND    ISNULL(LA.Lottable04, CONVERT(DATETIME, '19000101')) <> @d_IDLottable04)    
--                       AND   LLI.Qty - LLI.QtyPicked > 0    --(Wan02)    
--                       AND   LLI.Qty > 0)                 --(Wan02)    
           --(Wan07) - START    
           IF EXISTS ( SELECT 1    
                       FROM #TMP_LLI LLI    
                       WHERE LLI.Loc = @cToLOC    
            AND   LLI.Qty - LLI.QtyPicked > 0    
                       GROUP BY LLI.Storerkey, LLI.Sku    
                       HAVING COUNT(DISTINCT LLI.Lottable04) > 1    
                     )    
           --(Wan07) - END    
            BEGIN    
               SET @nContinue = 3    
               SET @n_err = 80008    
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)    
                           +': Not Allow to transfer to No Mix Lottable04 Location: ' +  RTRIM(@cToLOC) + '. (ispFinalizeTransfer)'    
               GOTO Quit_Proc    
            END    
         END    
         --(Wan01) - END    
    
         --------------------------------------------------------------------------------------------------------------------------------------    
         --TK01 END    
         IF @c_NoMixLottable06 = '1'    
         BEGIN    
--            IF EXISTS (SELECT 1 FROM LOTATTRIBUTE LA WITH (NOLOCK)    
--                       JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)    
--                       WHERE LLI.Loc = @cToLOC    
--                       AND   (LA.Storerkey = @c_IDStorerkey AND LA.Sku = @c_IDSku AND LA.Lottable06 <> @c_IDLottable06)    
--                       AND   LLI.Qty - LLI.QtyPicked > 0    
           --(Wan07) - START    
           IF EXISTS ( SELECT 1    
                       FROM #TMP_LLI LLI    
                       WHERE LLI.Loc = @cToLOC    
                       AND   LLI.Qty - LLI.QtyPicked > 0    
                       GROUP BY LLI.Storerkey, LLI.Sku    
                       HAVING COUNT(DISTINCT LLI.Lottable06) > 1    
                     )    
           --(Wan07) - END    
            BEGIN    
               SET @nContinue = 3    
               SET @n_err = 80009    
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)    
                           +': Not Allow to transfer to No Mix Lottable06 Location: ' +  RTRIM(@cToLOC) + '. (ispFinalizeTransfer)'    
               GOTO Quit_Proc    
            END    
         END    
    
         IF @c_NoMixLottable07 = '1'    
         BEGIN    
--            IF EXISTS (SELECT 1 FROM LOTATTRIBUTE LA WITH (NOLOCK)    
--                       JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)    
--                       WHERE LLI.Loc = @cToLOC    
--                       AND   (LA.Storerkey = @c_IDStorerkey AND LA.Sku = @c_IDSku AND LA.Lottable07 <> @c_IDLottable07)    
--                       AND   LLI.Qty - LLI.QtyPicked > 0    
           --(Wan07) - START    
           IF EXISTS ( SELECT 1    
                       FROM #TMP_LLI LLI    
                       WHERE LLI.Loc = @cToLOC    
                       AND   LLI.Qty - LLI.QtyPicked > 0    
                       GROUP BY LLI.Storerkey, LLI.Sku    
                       HAVING COUNT(DISTINCT LLI.Lottable07) > 1    
                     )    
           --(Wan07) - END    
            BEGIN    
               SET @nContinue = 3    
               SET @n_err = 80010    
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)    
                           +': Not Allow to transfer to No Mix Lottable07 Location: ' +  RTRIM(@cToLOC) + '. (ispFinalizeTransfer)'    
               GOTO Quit_Proc    
            END    
         END    
    
         IF @c_NoMixLottable08 = '1'    
         BEGIN    
--            IF EXISTS (SELECT 1 FROM LOTATTRIBUTE LA WITH (NOLOCK)    
--                       JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)    
--                       WHERE LLI.Loc = @cToLOC    
--                       AND   (LA.Storerkey = @c_IDStorerkey AND LA.Sku = @c_IDSku AND LA.Lottable08 <> @c_IDLottable08)    
--                       AND   LLI.Qty - LLI.QtyPicked > 0    
           --(Wan07) - START    
           IF EXISTS ( SELECT 1    
                       FROM #TMP_LLI LLI    
                       WHERE LLI.Loc = @cToLOC    
                       AND   LLI.Qty - LLI.QtyPicked > 0    
                       GROUP BY LLI.Storerkey, LLI.Sku    
                       HAVING COUNT(DISTINCT LLI.Lottable08) > 1    
                     )    
           --(Wan07) - END    
            BEGIN    
               SET @nContinue = 3    
               SET @n_err = 80011    
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)    
                           +': Not Allow to transfer to No Mix Lottable08 Location: ' +  RTRIM(@cToLOC) + '. (ispFinalizeTransfer)'    
               GOTO Quit_Proc    
            END    
         END    
    
         IF @c_NoMixLottable09 = '1'    
         BEGIN    
--            IF EXISTS (SELECT 1 FROM LOTATTRIBUTE LA WITH (NOLOCK)    
--                       JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)    
--                       WHERE LLI.Loc = @cToLOC    
--                       AND   (LA.Storerkey = @c_IDStorerkey AND LA.Sku = @c_IDSku AND LA.Lottable09 <> @c_IDLottable09)    
--                       AND   LLI.Qty - LLI.QtyPicked > 0    
           --(Wan07) - START    
           IF EXISTS ( SELECT 1    
                       FROM #TMP_LLI LLI    
                       WHERE LLI.Loc = @cToLOC    
                       AND   LLI.Qty - LLI.QtyPicked > 0    
                       GROUP BY LLI.Storerkey, LLI.Sku    
                       HAVING COUNT(DISTINCT LLI.Lottable09) > 1    
                     )    
           --(Wan07) - END    
            BEGIN    
               SET @nContinue = 3    
               SET @n_err = 80012    
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)    
                           +': Not Allow to transfer to No Mix Lottable09 Location: ' +  RTRIM(@cToLOC) + '. (ispFinalizeTransfer)'    
               GOTO Quit_Proc    
            END    
         END    
    
         IF @c_NoMixLottable10 = '1'    
         BEGIN    
--            IF EXISTS (SELECT 1 FROM LOTATTRIBUTE LA WITH (NOLOCK)    
--                       JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)    
--                       WHERE LLI.Loc = @cToLOC    
--                       AND   (LA.Storerkey = @c_IDStorerkey AND LA.Sku = @c_IDSku AND LA.Lottable10 <> @c_IDLottable10)    
--                       AND   LLI.Qty - LLI.QtyPicked > 0    
           --(Wan07) - START    
           IF EXISTS ( SELECT 1    
                       FROM #TMP_LLI LLI    
                       WHERE LLI.Loc = @cToLOC    
                       AND   LLI.Qty - LLI.QtyPicked > 0    
                       GROUP BY LLI.Storerkey, LLI.Sku    
                       HAVING COUNT(DISTINCT LLI.Lottable10) > 1    
                     )    
           --(Wan07) - END    
            BEGIN    
               SET @nContinue = 3    
               SET @n_err = 80013    
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)    
                           +': Not Allow to transfer to No Mix Lottable10 Location: ' +  RTRIM(@cToLOC) + '. (ispFinalizeTransfer)'    
               GOTO Quit_Proc    
            END    
         END    
    
         IF @c_NoMixLottable11 = '1'    
         BEGIN    
--            IF EXISTS (SELECT 1 FROM LOTATTRIBUTE LA WITH (NOLOCK)    
--                       JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)    
--                       WHERE LLI.Loc = @cToLOC    
--                       AND   (LA.Storerkey = @c_IDStorerkey AND LA.Sku = @c_IDSku AND LA.Lottable11 <> @c_IDLottable11)    
--                       AND   LLI.Qty - LLI.QtyPicked > 0    
           --(Wan07) - START    
           IF EXISTS ( SELECT 1    
                       FROM #TMP_LLI LLI    
                       WHERE LLI.Loc = @cToLOC    
                       AND   LLI.Qty - LLI.QtyPicked > 0    
                       GROUP BY LLI.Storerkey, LLI.Sku    
                       HAVING COUNT(DISTINCT LLI.Lottable11) > 1    
                     )    
           --(Wan07) - END    
            BEGIN    
               SET @nContinue = 3    
               SET @n_err = 80014    
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)    
                           +': Not Allow to transfer to No Mix Lottable11 Location: ' +  RTRIM(@cToLOC) + '. (ispFinalizeTransfer)'    
               GOTO Quit_Proc    
            END    
         END    
    
         IF @c_NoMixLottable12 = '1'    
         BEGIN    
--            IF EXISTS (SELECT 1 FROM LOTATTRIBUTE LA WITH (NOLOCK)    
--                       JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)    
--                       WHERE LLI.Loc = @cToLOC    
--                       AND   (LA.Storerkey = @c_IDStorerkey AND LA.Sku = @c_IDSku AND LA.Lottable12 <> @c_IDLottable12)    
--                       AND   LLI.Qty - LLI.QtyPicked > 0    
           --(Wan07) - START    
           IF EXISTS ( SELECT 1    
                       FROM #TMP_LLI LLI    
                       WHERE LLI.Loc = @cToLOC    
                       AND   LLI.Qty - LLI.QtyPicked > 0    
                       GROUP BY LLI.Storerkey, LLI.Sku    
                       HAVING COUNT(DISTINCT LLI.Lottable12) > 1    
                     )    
           --(Wan07) - END    
            BEGIN    
               SET @nContinue = 3    
               SET @n_err = 80015    
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)    
                           +': Not Allow to transfer to No Mix Lottable12 Location: ' +  RTRIM(@cToLOC) + '. (ispFinalizeTransfer)'    
               GOTO Quit_Proc    
            END    
         END    
    
         IF @c_NoMixLottable13 = '1'    
         BEGIN    
--            IF EXISTS (SELECT 1 FROM LOTATTRIBUTE LA WITH (NOLOCK)    
--                       JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)    
--                       WHERE LLI.Loc = @cToLOC    
--                       AND   (LA.Storerkey = @c_IDStorerkey AND LA.Sku = @c_IDSku    
--                       AND    ISNULL(LA.Lottable13, CONVERT(DATETIME, '19000101')) <> @d_IDLottable13)    
--                       AND   LLI.Qty - LLI.QtyPicked > 0    
           --(Wan07) - START    
           IF EXISTS ( SELECT 1    
                       FROM #TMP_LLI LLI    
                       WHERE LLI.Loc = @cToLOC    
                       AND   LLI.Qty - LLI.QtyPicked > 0    
                       GROUP BY LLI.Storerkey, LLI.Sku    
                       HAVING COUNT(DISTINCT LLI.Lottable13) > 1    
                     )    
           --(Wan07) - END    
            BEGIN    
               SET @nContinue = 3    
               SET @n_err = 80016    
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)    
                           +': Not Allow to transfer to No Mix Lottable13 Location: ' +  RTRIM(@cToLOC) + '. (ispFinalizeTransfer)'    
               GOTO Quit_Proc    
            END    
         END    
    
         IF @c_NoMixLottable14 = '1'    
         BEGIN    
--            IF EXISTS (SELECT 1 FROM LOTATTRIBUTE LA WITH (NOLOCK)    
--                       JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)    
--                       WHERE LLI.Loc = @cToLOC    
--                       AND   (LA.Storerkey = @c_IDStorerkey AND LA.Sku = @c_IDSku    
--                       AND    ISNULL(LA.Lottable14, CONVERT(DATETIME, '19000101')) <> @d_IDLottable14)    
--                       AND   LLI.Qty - LLI.QtyPicked > 0    
           --(Wan07) - START    
           IF EXISTS ( SELECT 1    
                       FROM #TMP_LLI LLI    
                       WHERE LLI.Loc = @cToLOC    
                       AND   LLI.Qty - LLI.QtyPicked > 0    
                       GROUP BY LLI.Storerkey, LLI.Sku    
                      HAVING COUNT(DISTINCT LLI.Lottable14) > 1    
                     )    
           --(Wan07) - END    
            BEGIN    
               SET @nContinue = 3    
               SET @n_err = 80017    
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)    
                           +': Not Allow to transfer to No Mix Lottable14 Location: ' +  RTRIM(@cToLOC) + '. (ispFinalizeTransfer)'    
               GOTO Quit_Proc    
            END    
         END    
    
         IF @c_NoMixLottable15 = '1'    
         BEGIN    
--            IF EXISTS (SELECT 1 FROM LOTATTRIBUTE LA WITH (NOLOCK)    
--                       JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)    
--                       WHERE LLI.Loc = @cToLOC    
--                       AND   (LA.Storerkey = @c_IDStorerkey AND LA.Sku = @c_IDSku    
--                       AND    ISNULL(LA.Lottable15, CONVERT(DATETIME, '19000101')) <> @d_IDLottable15)    
--                       AND   LLI.Qty - LLI.QtyPicked > 0    
           --(Wan07) - START    
           IF EXISTS ( SELECT 1    
                       FROM #TMP_LLI LLI    
                       WHERE LLI.Loc = @cToLOC    
                       AND   LLI.Qty - LLI.QtyPicked > 0    
                       GROUP BY LLI.Storerkey, LLI.Sku    
                       HAVING COUNT(DISTINCT LLI.Lottable15) > 1    
                     )    
           --(Wan07) - END    
            BEGIN    
               SET @nContinue = 3    
               SET @n_err = 80018    
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)    
                           +': Not Allow to transfer to No Mix Lottable15 Location: ' +  RTRIM(@cToLOC) + '. (ispFinalizeTransfer)'    
               GOTO Quit_Proc    
            END    
         END    
         --TK01 END    
         --------------------------------------------------------------------------------------------------------------------------------------    
    
         SELECT @cTransferLineNumber '@cTransferLineNumber'   
  
         UPDATE TRANSFERDETAIL WITH (ROWLOCK)    
            SET STATUS = '9'    
         WHERE  TransferKey = @c_TransferKey    
         AND    TransferLineNumber = @cTransferLineNumber    
         AND    Status <> '9'    
    
         IF @@ERROR = 0    
         BEGIN    
            IF @cUCCTracking = '1' or @c_RemainHoldOnTransfer = '1' OR @c_AllowTransferUCC = '1'    
            BEGIN    
               SELECT TOP 1 @cToLOT = LOT    
               FROM ITRN (NOLOCK)    
               WHERE StorerKey = @cToStorerKey    
               AND Sku   = @cToSKU    
               AND ToLoc = @cToLOC    
               AND ToId  = @cToID    
               AND SourceKey = @c_Transferkey + @cTransferLineNumber    
               AND TranType = 'DP'    
               AND SourceType = 'ntrTransferDetailUpdate';    
            END    
    
            IF @cUCCTracking = '1' OR @c_AllowTransferUCC = '1'    
            BEGIN    
               -- (ChewKP02)    
               SET @c_LoseUCC = ''    
    
               SELECT @c_LoseUCC = ISNULL(LoseUCC,'')    
               FROM Loc WITH (NOLOCK)    
               WHERE Loc = @cToLOC    
               AND Facility = @c_Facility    
    
               SELECT TOP 1    
                  @cUCCStatus = [status],    
                  @cExternKey = externkey    
               FROM UCC (NOLOCK)    
               WHERE UCCNo = @cFromUCC    
               AND   StorerKey = @cFromStorerKey    
               AND   Sku       = @cFromSKU                        --(Wan03)    
    
               IF @cFromUCC = @cToUCC    
               BEGIN    
                  UPDATE UCC    
                  SET Sku = @cToSKU,    
                      Qty = @nToQty,    
                      SourceKey  = @c_Transferkey,    
                      SourceType = 'TF',    
                      Lot = @cToLOT,    
                      Loc = @cToLOC,    
                      ID  = @cToID,    
                      Status = CASE WHEN @c_LoseUCC = '1' THEN '6' -- (ChewKP02)    
                               ELSE Status    
                               END    
               WHERE UCCNo = @cFromUCC    
                  AND StorerKey = @cFromStorerKey    
                  AND Sku = @cFromSKU    
                  AND Lot = @cFromLOT    
                  AND Loc = @cFromLOC    
                  AND ID  = @cFromID    
    
                  SELECT @n_err = @@ERROR    
                  IF @n_err <> 0    
                  BEGIN    
                     SELECT @nContinue = 3    
                     SELECT @c_ErrMsg = CONVERT(char(250),@n_err), @n_err=80001    
                     SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': Update UCC Fail. (''ispFinalizeTransfer'')' + ' ( ' + ' SQLSvr MESSAGE=' + RTrim(@c_ErrMsg) + ' ) '    
                     GOTO Quit_Proc    
                  END    
               END -- IF @cFromUCC = @cToUCC    
               ELSE    
               BEGIN    
                  UPDATE UCC    
                  SET Qty = Qty - @nFromQty,    
                     SourceKey = @c_Transferkey,    
                     SourceType = 'TF',    
                     Status =  CASE WHEN @c_LoseUCC = '1' THEN '6' -- (ChewKP02)    
                                    WHEN Qty - @nFromQty = 0 THEN '6' -- (ChewKP02)    
                               ELSE Status    
                               END    
                  WHERE UCCNo = @cFromUCC    
                  AND StorerKey = @cFromStorerKey    
                  AND Sku = @cFromSKU    
                  AND Lot = @cFromLOT    
                  AND Loc = @cFromLOC    
                  AND ID  = @cFromID    
    
                  IF @@ERROR = 0    
                  BEGIN    
    
                     IF @c_LoseUCC <> '1' AND ISNULL(@cToUCC,'') <> '' -- (ChewKP02)    
                     BEGIN    
                        SET @cExternKey = ISNULL(@cExternKey,'')    
    
                        INSERT UCC (UccNo, ExternKey, StorerKey, Sku, Lot, Loc, Id, Qty, Status, SourceKey, SourceType)    
                           VALUES (@cToUCC, @cExternKey, @cToStorerKey, @cToSKU, @cToLOT, @cToLOC, @cToID, @nToQty,    
                                   @cUCCStatus, @c_Transferkey, 'TT')    
                        SELECT @n_err = @@ERROR    
                        IF @n_err <> 0    
                        BEGIN    
                           SELECT @nContinue = 3    
                           SELECT @c_ErrMsg = CONVERT(char(250),@n_err), @n_err=80002    
                           SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Into UCC Fail. (''ispFinalizeTransfer'')' + ' ( ' + ' SQLSvr MESSAGE=' + RTrim(@c_ErrMsg) + ' ) '    
                           GOTO Quit_Proc    
                        END    
                     ENd    
                  END    
                  ELSE -- @@error <> 0    
                  BEGIN    
                     SELECT @nContinue = 3    
                     SELECT @c_ErrMsg = CONVERT(char(250),@n_err), @n_err=80003    
                     SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': Update UCC Fail. (''ispFinalizeTransfer'')' + ' ( ' + ' SQLSvr MESSAGE=' + RTrim(@c_ErrMsg) + ' ) '    
                     GOTO Quit_Proc    
                  END    
               END    
            END -- @cUCCTracking = 1    
    
            /* KC01 - start */    
            IF @c_RemainHoldOnTransfer = '1'    
            BEGIN    
               IF RTRIM(@cFromLot) <> RTRIM(@cToLot)    
               BEGIN    
                  SELECT @c_FromLotStatus = [status]    
                  FROM LOT (NOLOCK)    
                  WHERE LOT = @cFromLot    
                  AND   StorerKey = @cFromStorerKey    
                  AND   Sku = @cFromSku    
    
                  IF RTRIM(@c_FromLotStatus) = 'HOLD'    
                  BEGIN    
                     -- determine if lot is held by Lottables    
                     -- if inventory held by Lottable, there will be 1 invhold record for the Lottable, and 1 invhold record    
                     -- for each lot having that specific Lottable    
                     DECLARE CUR_INVHOLD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
                        SELECT  CASE WHEN LEN(RTRIM(Lottable01)) > 0 THEN 1    
                                     WHEN LEN(RTRIM(Lottable02)) > 0 THEN 2    
                                     WHEN LEN(RTRIM(Lottable03)) > 0 THEN 3    
                                     WHEN Lottable04 IS NOT NULL AND CONVERT(char(8), Lottable04, 112) <> '19000101' THEN 4    
                                     WHEN Lottable05 IS NOT NULL AND CONVERT(char(8), Lottable05, 112) <> '19000101' THEN 5    
                                     WHEN LEN(RTRIM(Lottable06)) > 0 THEN 6    
                                     WHEN LEN(RTRIM(Lottable07)) > 0 THEN 7    
                                     WHEN LEN(RTRIM(Lottable08)) > 0 THEN 8    
                                     WHEN LEN(RTRIM(Lottable09)) > 0 THEN 9    
                                     WHEN LEN(RTRIM(Lottable10)) > 0 THEN 10    
                                     WHEN LEN(RTRIM(Lottable11)) > 0 THEN 11    
                                     WHEN LEN(RTRIM(Lottable12)) > 0 THEN 12    
                                     WHEN Lottable13 IS NOT NULL AND CONVERT(char(8), Lottable13, 112) <> '19000101' THEN 13    
                                     WHEN Lottable14 IS NOT NULL AND CONVERT(char(8), Lottable14, 112) <> '19000101' THEN 14    
                                     WHEN Lottable15 IS NOT NULL AND CONVERT(char(8), Lottable15, 112) <> '19000101' THEN 15    
                                     ELSE 0 END    
                        FROM Inventoryhold with (NOLOCK)    
                        WHERE Hold = '1'    
                        AND Storerkey = @cFromStorerKey    
                        AND Sku = @cFromSku    
                        AND ((Lottable01 = @c_FromLottable01 AND ISNULL(RTRIM(@c_FromLottable01),'') <> '')    
                        OR (Lottable02 = @c_FromLottable02 AND ISNULL(RTRIM(@c_FromLottable02),'') <> '')    
                        OR (Lottable03 = @c_FromLottable03 AND ISNULL(RTRIM(@c_FromLottable03),'') <> '')    
                        OR (Lottable04 = @d_FromLottable04 AND @d_FromLottable04 IS NOT NULL AND CONVERT(char(8), @d_FromLottable04, 112) <> '19000101')    
                        OR (Lottable05 = @d_FromLottable05 AND @d_FromLottable05 IS NOT NULL AND CONVERT(char(8), @d_FromLottable05, 112) <> '19000101')    
                        OR (Lottable06 = @c_FromLottable06 AND ISNULL(RTRIM(@c_FromLottable06),'') <> '')    
                        OR (Lottable07 = @c_FromLottable07 AND ISNULL(RTRIM(@c_FromLottable07),'') <> '')    
                        OR (Lottable08 = @c_FromLottable08 AND ISNULL(RTRIM(@c_FromLottable08),'') <> '')    
                        OR (Lottable09 = @c_FromLottable09 AND ISNULL(RTRIM(@c_FromLottable09),'') <> '')    
                        OR (Lottable10 = @c_FromLottable10 AND ISNULL(RTRIM(@c_FromLottable10),'') <> '')    
                        OR (Lottable11 = @c_FromLottable11 AND ISNULL(RTRIM(@c_FromLottable11),'') <> '')    
                        OR (Lottable12 = @c_FromLottable12 AND ISNULL(RTRIM(@c_FromLottable12),'') <> '')    
                        OR (Lottable13 = @d_FromLottable13 AND @d_FromLottable13 IS NOT NULL AND CONVERT(char(8), @d_FromLottable13, 112) <> '19000101')    
                        OR (Lottable14 = @d_FromLottable14 AND @d_FromLottable14 IS NOT NULL AND CONVERT(char(8), @d_FromLottable14, 112) <> '19000101')    
                        OR (Lottable15 = @d_FromLottable15 AND @d_FromLottable15 IS NOT NULL AND CONVERT(char(8), @d_FromLottable15, 112) <> '19000101')    
                        )    
    
                     OPEN CUR_INVHOLD    
    
                     FETCH NEXT FROM CUR_INVHOLD INTO @n_HoldBy    
                     WHILE @@FETCH_STATUS <> -1    
                     BEGIN    
                        SET @c_Holdlot = ''    
                        SET @c_HoldLottable01 = ''    
                        SET @c_HoldLottable02 = ''    
                        SET @c_HoldLottable03 = ''    
                        SET @d_HoldLottable04 = NULL    
                        SET @d_HoldLottable05 = NULL    
                        SET @c_HoldLottable06 = ''    
                        SET @c_HoldLottable07 = ''    
                        SET @c_HoldLottable08 = ''    
                        SET @c_HoldLottable09 = ''    
                        SET @c_HoldLottable10 = ''    
                   SET @c_HoldLottable11 = ''    
                SET @c_HoldLottable12 = ''    
                        SET @d_HoldLottable13 = NULL    
                        SET @d_HoldLottable14 = NULL    
                        SET @d_HoldLottable15 = NULL    
    
                        IF @n_Holdby = 1    
                        BEGIN    
                           IF RTRIM(@c_FromLottable01) <> RTRIM(@c_ToLottable01)    
                              SET @c_HoldLottable01 = @c_ToLottable01    
                           ELSE    
                              SET @c_HoldLot = @cToLot    
                        END    
                        ELSE IF @n_Holdby = 2    
                        BEGIN    
                           IF RTRIM(@c_FromLottable02) <> RTRIM(@c_ToLottable02)    
                              SET @c_HoldLottable02 = @c_ToLottable02    
                           ELSE    
                              SET @c_HoldLot = @cToLot    
                        END    
                        ELSE IF @n_Holdby = 3    
                        BEGIN    
                           IF RTRIM(@c_FromLottable03) <> RTRIM(@c_ToLottable03)    
                              SET @c_HoldLottable03 = @c_ToLottable03    
                           ELSE    
                              SET @c_HoldLot = @cToLot    
                        END    
                        ELSE IF @n_Holdby = 4    
                        BEGIN    
                           IF RTRIM(@d_FromLottable04) <> RTRIM(@d_ToLottable04)    
                              SET @d_HoldLottable04 = @d_ToLottable04    
                           ELSE    
                              SET @c_HoldLot = @cToLot    
                        END    
                        ELSE IF @n_Holdby = 5    
                        BEGIN    
                           IF RTRIM(@d_FromLottable05) <> RTRIM(@d_ToLottable05)    
                              SET @d_HoldLottable05 = @d_ToLottable05    
                           ELSE    
                              SET @c_HoldLot = @cToLot    
                        END    
                        ELSE IF @n_Holdby = 6    
                        BEGIN    
                           IF RTRIM(@c_FromLottable06) <> RTRIM(@c_ToLottable06)    
                              SET @c_HoldLottable06 = @c_ToLottable06    
                           ELSE    
                              SET @c_HoldLot = @cToLot    
                        END    
                        ELSE IF @n_Holdby = 7    
                        BEGIN    
                           IF RTRIM(@c_FromLottable07) <> RTRIM(@c_ToLottable07)    
                              SET @c_HoldLottable07 = @c_ToLottable07    
                           ELSE    
                              SET @c_HoldLot = @cToLot    
                        END    
                        ELSE IF @n_Holdby = 8    
                        BEGIN    
                           IF RTRIM(@c_FromLottable08) <> RTRIM(@c_ToLottable08)    
                              SET @c_HoldLottable08 = @c_ToLottable08    
                           ELSE    
                              SET @c_HoldLot = @cToLot    
                        END    
                        ELSE IF @n_Holdby = 9    
                        BEGIN    
                           IF RTRIM(@c_FromLottable09) <> RTRIM(@c_ToLottable09)    
                              SET @c_HoldLottable09 = @c_ToLottable09    
                           ELSE    
                              SET @c_HoldLot = @cToLot    
                        END    
                        ELSE IF @n_Holdby = 10    
                        BEGIN    
                           IF RTRIM(@c_FromLottable10) <> RTRIM(@c_ToLottable10)    
                              SET @c_HoldLottable10 = @c_ToLottable10    
                           ELSE    
                              SET @c_HoldLot = @cToLot    
                        END    
                        ELSE IF @n_Holdby = 11    
                        BEGIN    
                           IF RTRIM(@c_FromLottable11) <> RTRIM(@c_ToLottable11)    
                              SET @c_HoldLottable11 = @c_ToLottable11    
        ELSE    
                              SET @c_HoldLot = @cToLot    
                        END    
                        ELSE IF @n_Holdby = 12    
                        BEGIN    
                           IF RTRIM(@c_FromLottable12) <> RTRIM(@c_ToLottable12)    
                              SET @c_HoldLottable12 = @c_ToLottable03    
                           ELSE    
                              SET @c_HoldLot = @cToLot    
                        END    
                        ELSE IF @n_Holdby = 13    
                        BEGIN    
                           IF RTRIM(@d_FromLottable13) <> RTRIM(@d_ToLottable13)    
                              SET @d_HoldLottable13 = @d_ToLottable13    
                           ELSE    
                              SET @c_HoldLot = @cToLot    
                        END    
                        ELSE IF @n_Holdby = 14    
                        BEGIN    
                           IF RTRIM(@d_FromLottable14) <> RTRIM(@d_ToLottable14)    
                              SET @d_HoldLottable14 = @d_ToLottable14    
                           ELSE    
                              SET @c_HoldLot = @cToLot    
                        END    
                        ELSE IF @n_Holdby = 15    
                        BEGIN    
                           IF RTRIM(@d_FromLottable15) <> RTRIM(@d_ToLottable15)    
                              SET @d_HoldLottable15 = @d_ToLottable15    
                           ELSE    
                              SET @c_HoldLot = @cToLot    
                        END    
                        ELSE  -- definitely required to hold by lot since not held by any of the Lottables    
                        BEGIN    
                           SET @c_HoldLot = @cToLot    
                        END    
    
                        SET @c_Remark = 'AUTO HOLD from Inv Transfer'    
                        SET @b_success = 1    
                        EXEC nspInventoryHoldWrapper    
                              @c_HoldLot,             -- lot    
                              '',                     -- loc    
                              '',                     -- id    
                              @cToStorerKey,          -- storerkey    
                              @cToSKU,                -- sku    
                              @c_HoldLottable01,      -- Lottable01    
                              @c_HoldLottable02,      -- Lottable02    
                              @c_HoldLottable03,      -- Lottable03    
                              @d_HoldLottable04,      -- Lottable04    
                              @d_HoldLottable05,      -- Lottable05    
                              @c_HoldLottable06,      -- Lottable06    
                              @c_HoldLottable07,      -- Lottable07    
                              @c_HoldLottable08,      -- Lottable08    
                              @c_HoldLottable09,      -- Lottable09    
                              @c_HoldLottable10,      -- Lottable10    
                              @c_HoldLottable11,      -- Lottable11    
                              @c_HoldLottable12,      -- Lottable12    
                              @d_HoldLottable13,      -- Lottable13    
                              @d_HoldLottable14,      -- Lottable14    
                              @d_HoldLottable15,      -- Lottable15    
                              'QC',                   -- status    
                              '1',                    -- hold    
                              @b_success OUTPUT,    
                              @n_err OUTPUT,    
                              @c_errmsg OUTPUT,    
                              @c_Remark          -- remark    
    
                        IF @b_success = 0    
                        BEGIN    
                           SELECT @nContinue = 3    
                           SELECT @c_ErrMsg = CONVERT(char(250),@n_err), @n_err=80099    
                           SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': Update Inventoryhold Fail. (''ispFinalizeTransfer'')' + ' ( ' + ' SQLSvr MESSAGE=' + RTrim(@c_ErrMsg) + ' ) '    
   GOTO Quit_Proc    
                        END    
    
                        FETCH NEXT FROM CUR_INVHOLD INTO @n_HoldBy    
                     END -- While    
                     CLOSE CUR_INVHOLD    
                     DEALLOCATE CUR_INVHOLD    
    
                  END -- @c_FromLotStatus = 'HOLD'    
                  ELSE --@c_FromlotStatus = 'OK'    
                  BEGIN    
                     -- determine if new Lottables currently on hold in InventoryHold    
                     -- if yes, need to put the new lot on hold    
                     SET @n_holdby = 0    
                     SELECT  @n_holdby = ISNULL(CASE WHEN LEN(RTRIM(Lottable01)) > 0 THEN 1    
                                          WHEN LEN(RTRIM(Lottable02)) > 0 THEN 2    
                                          WHEN LEN(RTRIM(Lottable03)) > 0 THEN 3    
                                          WHEN Lottable04 IS NOT NULL AND CONVERT(char(8), Lottable04, 112) <> '19000101' THEN 4    
                                          WHEN Lottable05 IS NOT NULL AND CONVERT(char(8), Lottable05, 112) <> '19000101' THEN 5    
                                          WHEN LEN(RTRIM(Lottable06)) > 0 THEN 6    
                                          WHEN LEN(RTRIM(Lottable07)) > 0 THEN 7    
                                          WHEN LEN(RTRIM(Lottable08)) > 0 THEN 8    
                                          WHEN LEN(RTRIM(Lottable09)) > 0 THEN 9    
                                          WHEN LEN(RTRIM(Lottable10)) > 0 THEN 10    
                                          WHEN LEN(RTRIM(Lottable11)) > 0 THEN 11    
                                          WHEN LEN(RTRIM(Lottable12)) > 0 THEN 12    
                                          WHEN Lottable13 IS NOT NULL AND CONVERT(char(8), Lottable13, 112) <> '19000101' THEN 13    
                                          WHEN Lottable14 IS NOT NULL AND CONVERT(char(8), Lottable14, 112) <> '19000101' THEN 14    
                                          WHEN Lottable15 IS NOT NULL AND CONVERT(char(8), Lottable15, 112) <> '19000101' THEN 15    
                                          ELSE 0 END, 0)    
                     FROM Inventoryhold with (NOLOCK)    
                     WHERE Hold = '1'    
                     AND Storerkey = @cToStorerKey    
                     AND Sku = @cToSku    
                     AND ((Lottable01 = @c_ToLottable01 AND ISNULL(RTRIM(@c_ToLottable01),'') <> '')    
                     OR (Lottable02 = @c_ToLottable02 AND ISNULL(RTRIM(@c_ToLottable02),'') <> '')    
                     OR (Lottable03 = @c_ToLottable03 AND ISNULL(RTRIM(@c_ToLottable03),'') <> '')    
                     OR (Lottable04 = @d_ToLottable04 AND @d_ToLottable04 IS NOT NULL AND CONVERT(char(8), @d_ToLottable04, 112) <> '19000101')    
                     OR (Lottable05 = @d_ToLottable05 AND @d_ToLottable05 IS NOT NULL AND CONVERT(char(8), @d_ToLottable05, 112) <> '19000101')    
                     OR (Lottable06 = @c_ToLottable06 AND ISNULL(RTRIM(@c_ToLottable06),'') <> '')    
                     OR (Lottable07 = @c_ToLottable07 AND ISNULL(RTRIM(@c_ToLottable07),'') <> '')    
                     OR (Lottable08 = @c_ToLottable08 AND ISNULL(RTRIM(@c_ToLottable08),'') <> '')    
                     OR (Lottable09 = @c_ToLottable09 AND ISNULL(RTRIM(@c_ToLottable09),'') <> '')    
                     OR (Lottable10 = @c_ToLottable10 AND ISNULL(RTRIM(@c_ToLottable10),'') <> '')    
                     OR (Lottable11 = @c_ToLottable11 AND ISNULL(RTRIM(@c_ToLottable11),'') <> '')    
                     OR (Lottable12 = @c_ToLottable12 AND ISNULL(RTRIM(@c_ToLottable12),'') <> '')    
                     OR (Lottable13 = @d_ToLottable13 AND @d_ToLottable13 IS NOT NULL AND CONVERT(char(8), @d_ToLottable13, 112) <> '19000101')    
                     OR (Lottable14 = @d_ToLottable14 AND @d_ToLottable14 IS NOT NULL AND CONVERT(char(8), @d_ToLottable14, 112) <> '19000101')    
                     OR (Lottable15 = @d_ToLottable15 AND @d_ToLottable15 IS NOT NULL AND CONVERT(char(8), @d_ToLottable15, 112) <> '19000101')    
                     )    
    
                     IF @n_holdby <> 0    
                     BEGIN    
                        SET @c_Remark = 'AUTO HOLD from Inv Transfer'    
                        SET @b_success = 1    
                        EXEC nspInventoryHoldWrapper    
                              @cToLot,       -- lot    
                              '',               -- loc    
                              '',               -- id    
                              @cToStorerKey,    -- storerkey    
                              @cToSKU,          -- sku    
                              '',-- Lottable01    
                              '',-- Lottable02    
                              '',-- Lottable03    
                              '',-- Lottable04    
                              '',-- Lottable05    
                              '',-- Lottable06    
                              '',-- Lottable07    
                              '',-- Lottable08    
                              '',-- Lottable09    
                              '',-- Lottable10    
                              '',-- Lottable11    
                              '',-- Lottable12    
                              '',-- Lottable13    
                              '',-- Lottable14    
                              '',-- Lottable15    
                              'QC',             -- status    
                              '1',              -- hold    
                              @b_success OUTPUT,    
                              @n_err OUTPUT,    
                              @c_errmsg OUTPUT,    
                              @c_Remark          -- remark    
    
                        IF @b_success = 0    
                        BEGIN    
                           SELECT @nContinue = 3    
                           SELECT @c_ErrMsg = CONVERT(char(250),@n_err), @n_err=80098    
                           SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': Update Inventoryhold Fail. (''ispFinalizeTransfer'')' + ' ( ' + ' SQLSvr MESSAGE=' + RTrim(@c_ErrMsg) + ' ) '    
                           GOTO Quit_Proc    
                        END    
    
                     END  -- @n_holdby <> 0    
                  END   --@c_fromlotStatus = 'OK'    
               END -- @cFromLot <> @cTolot    
            END -- @c_RemainHoldOnTransfer    
            /* KC01 - end */    
         END    
         ELSE    
         BEGIN    
            SELECT @nContinue = 3    
            SELECT @c_ErrMsg = CONVERT(char(250),@n_err), @n_err=80004    
            SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': Finalize ispFinalizeTransfer Fail. (''ispFinalizeTransfer'')' + ' ( ' + ' SQLSvr MESSAGE=' + RTrim(@c_ErrMsg) + ' ) '    
            GOTO Quit_Proc    
         END    
    
         --XXXXXXX--    
         --WHILE @@TRANCOUNT > 0    
         COMMIT TRAN    
    
         NEXT_TRFDET:               --(Wan05)    
         FETCH NEXT FROM CUR_TRANSFERDET INTO @cTransferLineNumber, @cFromStorerKey,    
               @cFromSKU,     @cFromLOT,     @cFromLOC,       @cFromID,        @nFromQty,    
               @cToStorerKey, @cToSKU,       @cToLOT,         @cToLOC,    
               @cToID,        @nToQty,       @cFromUCC,       @cToUCC,    
               /* KC01 - start */    
               @c_FromLottable01,   @c_FromLottable02,   @c_FromLottable03,   @d_FromLottable04,   @d_FromLottable05,    
               @c_FromLottable06,   @c_FromLottable07,   @c_FromLottable08,   @c_FromLottable09,   @c_FromLottable10,    
               @c_FromLottable11,   @c_FromLottable12,   @d_FromLottable13,   @d_FromLottable14,   @d_FromLottable15,    
               @c_ToLottable01,     @c_ToLottable02,     @c_ToLottable03,     @d_ToLottable04,     @d_ToLottable05,    
               @c_ToLottable06,     @c_ToLottable07,     @c_ToLottable08,     @c_ToLottable09,     @c_ToLottable10,    
               @c_ToLottable11,     @c_ToLottable12,     @d_ToLottable13,     @d_ToLottable14,     @d_ToLottable15    
               /* KC01 - end */    
    
      END -- While    
      CLOSE CUR_TRANSFERDET    
      DEALLOCATE CUR_TRANSFERDET    
   END    
    
   --3 XXXXXXX--    
   WHILE @@TRANCOUNT < @nStartTranCount    
      BEGIN TRAN    
    
 --(Wan04) - START    
    IF NOT EXISTS (SELECT 1    
                  FROM TRANSFERDETAIL WITH (NOLOCK)    
                  WHERE Transferkey = @c_Transferkey    
                  AND   TransferLineNumber = CASE WHEN @c_TransferLineNumber = ''   --(Wan08)    
                                                  THEN TransferLineNumber           --(Wan08)    
                                                  ELSE @c_TransferLineNumber END    --(Wan08)    
                  AND [Status] <> '9' )    
   BEGIN    
      SET @b_Success = 0    
      SET @c_PostFinalizeTransferSP = ''    
      EXEC nspGetRight    
            @c_Facility  = NULL    
          , @c_StorerKey = @cFromStorerKey    
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
               , @c_TransferLineNumber = @c_TransferLineNumber                      --(Wan08)    
    
         IF @n_err <> 0    
         BEGIN    
            SET @nContinue= 3    
            SET @b_Success = 0    
            SET @n_err  = 60071    
            SET @c_errmsg = 'Execute ispPostFinalizeTransferWrapper Failed.'    
                          + '(' + @c_errmsg + ')'    
         END    
      END    
   END    
   --(Wan04) - End    
   Quit_Proc:    
   IF @nContinue=3  -- Error Occured - Process And Return    
   BEGIN    
      SELECT @b_Success = 0    
      --IF @@TRANCOUNT = 1 and @@TRANCOUNT > @nStartTranCount    
      IF @@TRANCOUNT > 0     
      BEGIN    
         ROLLBACK TRAN    
      END    
      ELSE    
      BEGIN    
         WHILE @@TRANCOUNT > @nStartTranCount    
         BEGIN    
            COMMIT TRAN    
         END    
      END    
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispFinalizeTransfer'    
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012    
      RETURN    
   END    
   ELSE    
   BEGIN    
      SELECT @b_Success = 1    
      WHILE @@TRANCOUNT > @nStartTranCount    
      BEGIN    
         COMMIT TRAN    
      END    
      RETURN    
   END    
END -- procedure 

GO