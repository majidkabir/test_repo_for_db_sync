SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Trigger: ispFinalizeReceipt                                          */  
/* Creation Date: 21-Nov-2008                                           */  
/* Copyright: IDS                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: Finalize Receipt                                            */  
/*                                                                      */  
/* Called By: n_cst_receipt.Event ue_finalizereceipt                    */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 6.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver Purposes                                  */  
/* 21-Nov-2008  Shong     1.0 Created - SOS122039 DeadLock When Finalize*/  
/* 31-Dec-2008  Shong     1.1 SOS#125406 Datatype Conversion Error      */  
/* 19-May-2009  TLTING    1.2 TraceInfo (tlting01)                      */  
/* 28-May-2009  James     1.5 SOS137640 Auto hold by lot if             */  
/*                            sku.receiptholdcode = 'HMCE'              */  
/* 15-Jan-2010  James     1.6 SOS159255 Prompt error msg when Lottable02*/  
/*                            <> ReceiptLineNumber (james01)            */  
/* 24-Feb-2010  TLTING    1.7 SOS162413 Default Toloc (TLTING02)        */  
/* 14-Jul-2010  Shong     Filter by QtyReceived > 0 and FinalizeFlag =  */  
/*                        'Y' (Shong01)                                 */  
/* 07-Jan-2011  NJOW01    SOS#201053 - Extented Validation for ASN using*/  
/*                        Codelkup                                      */  
/* 12-Sep-2011  TLTING    1.7 Turn OFF TraceInfo                        */  
/* 01-Feb-2012  James     SOS269538 - Add lottable wrapper  (james02)   */  
/* 16-May-2013  SPChin    1.8 SOS278355 - Add TraceInfo                 */    
/* 28-Mar-2013  NJOW02    Fix finalize error - set @n_errno=0           */  
/* 31-Mar-2013  Ung       SOS273757 Fix lottable var not init btw lines */  
/* 14-Mar-2013  Ung       SOS255639 Add ASNValidationRules SP (ung01)   */  
/* 17-Sep-2013  NJOW03    289028-Hold by lottable03 by userdefine08     */  
/*                        value. storerconfig: HoldLottable03ByUDF08    */  
/* 23-Dec-2013  YTWan     SOS#297738 - FBR297738_TH- WMS Auto Create    */  
/*                        Shipment Order after finalize ASN.(Wan01)     */  
/* 27-Oct-2013  Shong     Performance Tuning                            */  
/* 16-JAN-2014  YTWan     SOS#298639 - Washington - Finalize by         */  
/*                        Receipt Line (Wan02)                          */  
/* 28-May-2014  TKLIM     Added Lottables 06-15                         */  
/* 12-Feb-2014  NJOW04    302303 - lottable rule filter by storer       */  
/* 30-Apr-2014  James     Perfomance fix. Add filter listname (james03) */  
/* 05-May-2014  NJOW05    310313-Move GenLot2withASN_ASNLineNo          */  
/*                        validation after extendedvalidation           */  
/* 15-APR-2014  YTWan     SOS#308181 - CN_HM(ECOM)_update toid to       */  
/*                        userdefine01. (Wan03)                         */  
/* 30-SEP-2014  NJOW06    321837-Inv Hold for HMCE exclude Trade Return */  
/* 19-DEC-2014  CSCHONG   Fix bugs (CS01)                               */  
/* 29-DEC-2014  CSCHONG   Bugs fix (CS02)                               */  
/* 23-JAN-2-15  CSCHONG   Fix cursor not open bugs (CS03)               */  
/* 26-Feb-2015  NJOW07    327560-Lottable rule include udf01 feature    */  
/* 18-MAY-2015  YTWan     SOS#341733 - ToryBurch HK SAP - Allow         */  
/*                        CommingleSKU with NoMixLottablevalidation     */  
/*                        to Exceed and RDT (Wan04)                     */  
/* 01-JUN-2015  YTWan     SOS#343525 - UA ?NoMixLottable validation CR  */  
/*                        (Wan05)                                       */  
/* 12-AUG-2015  YTWan     SOS#349550 - [TW] CR  Modify Exceed Finalize  */  
/*                        by LINE(Wan06)                                */  
/* 18-Sep-2015  NJOW08    352845 - PreFinalizeReceiptSP by facility     */  
/* 21-Aug-2015  NJOW09    350966 - auto hold by id                      */  
/* 13-Jun-2016  Ung       SOS371091 Add RDT compatible error handling   */  
/* 01-Aug-2016  Ung       IN00110559 Enable trigger pass out error      */  
/* 02-Jan-2018  NJOW10    WMS-3763 Auto hold lottable based on inventory*/  
/*                        hold setup and storerconfig                   */  
/* 26-Jan-2018  CheeMun   INC0102829 -GOTO RollbackTran if hit error at */  
/*                        update ReceiptDetail (CM01)                   */  
/* 07-Jun-2018  James     WMS2605-Bug fix on @n_err reset to 0 (james04)*/
/* 22-APR-2019  WLCHOOI   WMS-8568 - New StorerConfig - ASNAutoCreateSO */
/*                                 ASN Auto Create Orders when finalized*/
/* 03-May-2019  WLCHOOI   WMS-8866 - ASNAUTOHOLD - Hold multiple        */
/*                                   combination of lottables (WL02)    */
/* 07-Jul-2020  WLChooi   WMS-14045 - Add Option5 for StorerConfig =    */ 
/*                        CloseASNStatus (WL03)                         */ 
/* 29-May-2020  Wan07     WMS-13117 - [CN] Sephora_WMS_ITRN_Add_UCC_CR  */
/* 02-Feb-2021  Ung       WMS-15663 Add RDT compatible message          */
/* 10-Feb-2023  NJOW11    WMS-21722 Allow check nomixlottable for all   */
/*                        commingle sku in a loc.                       */
/* 10-Feb-2023  NJOW11    DEVOPS Combine Script                         */
/************************************************************************/  
  
CREATE   PROC    [dbo].[ispFinalizeReceipt]  
               @c_ReceiptKey   NVARCHAR(10)  
,              @b_Success      int       = 1  OUTPUT  
,              @n_err          int       = 0  OUTPUT  
,              @c_ErrMsg       NVARCHAR(250) = '' OUTPUT  
,              @c_ReceiptLineNumber NVARCHAR(5) = ''  -- (Wan02)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE  
      @n_continue       int,  
      @n_StartTCnt      int,        -- Holds the current transaction count  
      @n_Err2           int,        -- For Additional Error Detection  
      @c_ReceiptLineNo  NVARCHAR(5), 
      @c_QtyReceived    int,  
      @c_ConfigKey      NVARCHAR(30),  
      @c_StorerKey      NVARCHAR(15),  
      @c_Facility       NVARCHAR(5)  
  
   DECLARE  
      @c_CloseASNStatus       NVARCHAR(1),  
      @c_CloseASNUponFinalize NVARCHAR(1),  
      @c_PalletCalculation    NVARCHAR(1)  
  
   DECLARE  
      @n_StockBalQty   int,  
      @n_PalletCnt     int  
  
   DECLARE  @c_InventoryHoldKey NVARCHAR(10),   --(james01)  
            @c_LOT              NVARCHAR(10),  
            @c_ID               NVARCHAR(18),  
            @c_LOC              NVARCHAR(10),  
            @c_SKU              NVARCHAR(20),  
            @c_Lottable01       NVARCHAR(18),  
            @c_Lottable02       NVARCHAR(18),  
            @c_Lottable03       NVARCHAR(18),  
            @d_Lottable04       DATETIME,  
            @d_Lottable05       DATETIME ,  
            @c_Lottable06       NVARCHAR(30),  
            @c_Lottable07       NVARCHAR(30),  
            @c_Lottable08       NVARCHAR(30),  
            @c_Lottable09       NVARCHAR(30),  
            @c_Lottable10       NVARCHAR(30),  
            @c_Lottable11       NVARCHAR(30),  
            @c_Lottable12       NVARCHAR(30),  
            @d_Lottable13       DATETIME,  
            @d_Lottable14       DATETIME,  
            @d_Lottable15       DATETIME,  
              
            @c_CodeLKUp          NVARCHAR(30),  
            @c_Reason            NVARCHAR(255),  
            @c_RCPTSTATStatus    NVARCHAR(1),  
            @c_busr5             NVARCHAR(30),  
            @c_ToLoc             NVARCHAR(10),  
            @c_ReceiptHoldCode   NVARCHAR(10) --NJOW03  
  
    DECLARE @c_debug  NVARCHAR(1)  
  
  DECLARE @c_Lottable01Value             NVARCHAR(18),  
           @c_Lottable02Value             NVARCHAR(18),  
           @c_Lottable03Value             NVARCHAR(18),  
           @d_Lottable04Value             DATETIME,  
           @d_Lottable05Value             DATETIME,  
           @c_Lottable06Value             NVARCHAR(30),  
           @c_Lottable07Value             NVARCHAR(30),  
           @c_Lottable08Value             NVARCHAR(30),  
           @c_Lottable09Value             NVARCHAR(30),  
           @c_Lottable10Value             NVARCHAR(30),  
           @c_Lottable11Value             NVARCHAR(30),  
           @c_Lottable12Value             NVARCHAR(30),  
           @d_Lottable13Value             DATETIME,  
           @d_Lottable14Value             DATETIME,  
           @d_Lottable15Value             DATETIME,  
           @n_ErrNo                       int,  
           @c_Sourcekey                   NVARCHAR(15),  
           @c_Sourcetype                  NVARCHAR(20),  
           @c_LottableLabel               NVARCHAR(20),  
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
           @c_LottableLabel13             NVARCHAR(30),     --(CS01)  
           @c_LottableLabel14             NVARCHAR(30),     --(CS01)  
           @c_LottableLabel15             NVARCHAR(30),     --(CS01)  
           @n_count                       INT,  
           @c_listname                    NVARCHAR(10),  
           @c_sp_name                     NVARCHAR(50),  
           @c_SQL                         NVARCHAR(4000),  
           @c_SQLParm                     NVARCHAR(2000),  
           @nLottableRules                INT  
  
        ,  @c_PostFinalizeReceiptSP     NVARCHAR(10)            --(Wan01)  
        ,  @c_FinalizeSplitReceiptLine  NVARCHAR(10)            --(Wan02)  
        ,  @c_NewReceiptLineNumber      NVARCHAR(5)             --(Wan02)  
        ,  @n_NewQtyExpected            INT                     --(Wan02)  
          
        ,  @c_PreFinalizeReceiptSP      NVARCHAR(10)            --(Wan03)  
        ,  @c_UDF01                     NVARCHAR(60) --NJOW07  
        ,  @c_Value                     NVARCHAR(60) --NJOW07  
        ,  @c_DocType                   NVARCHAR(10)            --(Wan06)     
        ,  @c_ASNHoldLottableByInvHold  NVARCHAR(10) --NJOW10  
        ,  @c_LottableField             NVARCHAR(20) --NJOW10  
        ,  @c_LottableValue             NVARCHAR(30) --NJOW10  
      
        ,  @c_Lottables                 NVARCHAR(10) --WL02
        
        , @c_UCCNo                     NVARCHAR(20) = ''       --(Wan07)
        , @c_UCCStatus                 NVARCHAR(20) = ''       --(Wan07)
        , @c_UCC                       NVARCHAR(30) = ''       --(Wan07)     
        , @c_UCCTracking               NVARCHAR(30) = ''       --(Wan07)
        , @c_AddUCCFromColUDF01        NVARCHAR(30) = ''       --(Wan07) 

        , @c_Option1                   NVARCHAR(100) = ''    --WL03
        , @c_Option2                   NVARCHAR(100) = ''    --WL03
        , @c_Option3                   NVARCHAR(100) = ''    --WL03
        , @c_Option4                   NVARCHAR(100) = ''    --WL03
        , @c_Option5                   NVARCHAR(4000) = ''   --WL03
        , @c_IncludeReceiptGroup       NVARCHAR(4000) = ''   --WL03
        , @c_ChkNoMixLottableForAllSku NVARCHAR(30) = '' -- NJOW11
  
   SET @c_debug = 0  
  
   SELECT @n_StartTCnt=@@TRANCOUNT, @n_continue=1, @b_Success=0,@n_err=0,@c_ErrMsg='',@n_Err2=0, @n_ErrNo=0  
   /* #INCLUDE <SPIAM1.SQL> */  
  
 -- TraceInfo (tlting01) - Start  
   DECLARE    @d_starttime    datetime,  
              @d_endtime      datetime,  
              @d_step1        datetime,  
              @d_step2        datetime,  
              @d_step3        datetime,  
              @d_step4        datetime,  
              @d_step5        datetime,  
              @c_col1         NVARCHAR(20),  
              @c_col2         NVARCHAR(20),  
              @c_col3         NVARCHAR(20),  
              @c_col4         NVARCHAR(20),  
              @c_col5         NVARCHAR(20),  
              @c_TraceName    NVARCHAR(80)  
                
   --(Wan04) - START  
   DECLARE @c_NoMixLottable01 NVARCHAR(1)  
      , @c_NoMixLottable02    NVARCHAR(1)  
      , @c_NoMixLottable03    NVARCHAR(1)  
      , @c_NoMixLottable04    NVARCHAR(1)  
      , @c_NoMixLottable06    NVARCHAR(1) --(Wan05)  
      , @c_NoMixLottable07    NVARCHAR(1) --(Wan05)  
      , @c_NoMixLottable08    NVARCHAR(1) --(Wan05)  
      , @c_NoMixLottable09    NVARCHAR(1) --(Wan05)  
      , @c_NoMixLottable10    NVARCHAR(1) --(Wan05)  
      , @c_NoMixLottable11    NVARCHAR(1) --(Wan05)  
      , @c_NoMixLottable12    NVARCHAR(1) --(Wan05)  
      , @c_NoMixLottable13    NVARCHAR(1) --(Wan05)  
      , @c_NoMixLottable14    NVARCHAR(1) --(Wan05)  
      , @c_NoMixLottable15    NVARCHAR(1) --(Wan05)  
  
      , @c_CommingleSku       NVARCHAR(1)                  
      , @c_ChkLocByCommingleSkuFlag  NVARCHAR(10)      
      , @c_ASNAutoCreateSO    NVARCHAR(10) --(WL01)   
  
   SET @c_NoMixLottable01  = '0'  
   SET @c_NoMixLottable02  = '0'  
   SET @c_NoMixLottable03  = '0'  
   SET @c_NoMixLottable04  = '0'  
   SET @c_NoMixLottable06  = '0'          --(Wan05)  
   SET @c_NoMixLottable07  = '0'          --(Wan05)  
   SET @c_NoMixLottable08  = '0'          --(Wan05)  
   SET @c_NoMixLottable09  = '0'          --(Wan05)  
   SET @c_NoMixLottable10  = '0'          --(Wan05)         
   SET @c_NoMixLottable11  = '0'          --(Wan05)  
   SET @c_NoMixLottable12  = '0'          --(Wan05)  
   SET @c_NoMixLottable13  = '0'          --(Wan05)  
   SET @c_NoMixLottable14  = '0'          --(Wan05)  
   SET @c_NoMixLottable15  = '0'          --(Wan05)  
  
   SET @c_CommingleSku      = '1'                        
   SET @c_ChkLocByCommingleSkuFlag = '0'  
   SET @c_ASNAutoCreateSO   = '0' --(WL01)                
   --(Wan04) - END                 
  
   SET @c_col5 = @c_ReceiptKey  
   SET @d_starttime = getdate()  
  
   SET @c_TraceName = 'ispFinalizeReceipt'  
-- TraceInfo (tlting01) - End  
  
   SELECT @c_StorerKey = StorerKey,  
   @c_Facility = Facility  
   ,       @c_DocType  = Doctype                                                 --(Wan06)  
   From Receipt WITH (NOLOCK)  
   WHERE ReceiptKey = @c_ReceiptKey   -- (james01)  
  
   SET @c_ReceiptLineNumber = ISNULL(RTRIM(@c_ReceiptLineNumber),'')             --(Wan02)  
  
   BEGIN TRAN  
  
   SET @d_step1 = GETDATE()  -- (tlting01)  
  
   -- SOS#201053  Extented Validation for ASN using Codelkup - NJOW01  
   IF @n_Continue = 1 OR @n_Continue = 2  
   BEGIN  
      DECLARE @cASNValidationRules  NVARCHAR(30)  
  
      SELECT @cASNValidationRules = SC.sValue  
      FROM STORERCONFIG SC (NOLOCK)  
      JOIN CODELKUP CL (NOLOCK) ON SC.sValue = CL.Listname  
      WHERE SC.StorerKey = @c_StorerKey  
      AND SC.Configkey = 'ASNExtendedValidation'  
  
      IF ISNULL(@cASNValidationRules,'') <> ''  
      BEGIN  
            EXEC isp_ASN_ExtendedValidation @cReceiptKey = @c_ReceiptKey,  
                                             @cASNValidationRules=@cASNValidationRules,  
                                             @nSuccess=@b_Success OUTPUT, @cErrorMsg=@c_ErrMsg OUTPUT  
                                          ,  @c_ReceiptLineNumber = @c_ReceiptLineNumber  --(Wan02)  
  
            IF @b_Success <> 1  
            BEGIN  
               SELECT @n_Continue = 3  
               SELECT @n_err = 163051  
               GOTO RollbackTran  
            END  
      END  
      ELSE     
      BEGIN -- (ung01)  
            SELECT @cASNValidationRules = SC.sValue      
            FROM STORERCONFIG SC (NOLOCK)   
            WHERE SC.StorerKey = @c_StorerKey   
            AND SC.Configkey = 'ASNExtendedValidation'      
              
            IF EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@cASNValidationRules) AND type = 'P')            
            BEGIN            
               SET @c_SQL = 'EXEC ' + @cASNValidationRules + ' @c_ReceiptKey, @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT '            
                          + ',@c_ReceiptLineNumber '                          --(Wan02)  
               EXEC sp_executesql @c_SQL,            
                    N'@c_ReceiptKey NVARCHAR(10), @b_Success Int OUTPUT, @n_Err Int OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT  
                     ,@c_ReceiptLineNumber NVARCHAR(5)',                      --(Wan02)           
                    @c_ReceiptKey,            
                    @b_Success OUTPUT,            
                    @n_Err OUTPUT,            
                    @c_ErrMsg OUTPUT,  
                    @c_ReceiptLineNumber                                      --(Wan02)           
  
               IF @b_Success <> 1       
               BEGIN      
                  SELECT @n_Continue = 3      
                  SELECT @n_err = 163052       
                  GOTO RollbackTran  
               END           
            END    
      END              
   END --    IF @n_Continue = 1 OR @n_Continue = 2  
  
   --(Wan03) - START   
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  
      SET @b_Success = 0  
      SET @c_PreFinalizeReceiptSP = ''  
      EXEC nspGetRight    
            @c_Facility  = @c_Facility --NJOW08  
          , @c_StorerKey = @c_StorerKey   
          , @c_sku       = NULL  
          , @c_ConfigKey = 'PreFinalizeReceiptSP'    
          , @b_Success   = @b_Success                  OUTPUT    
          , @c_authority = @c_PreFinalizeReceiptSP     OUTPUT     
          , @n_err       = @n_err                      OUTPUT     
          , @c_errmsg    = @c_errmsg                   OUTPUT    
  
      IF EXISTS (SELECT 1 FROM sys.objects o WHERE NAME = @c_PreFinalizeReceiptSP AND TYPE = 'P')  
      BEGIN  
         SET @b_Success = 0    
         EXECUTE dbo.ispPreFinalizeReceiptWrapper   
                 @c_ReceiptKey        = @c_ReceiptKey  
               , @c_ReceiptLineNumber = @c_ReceiptLineNumber                  
               , @c_PreFinalizeReceiptSP= @c_PreFinalizeReceiptSP  
               , @b_Success = @b_Success     OUTPUT    
               , @n_Err     = @n_err         OUTPUT     
               , @c_ErrMsg  = @c_errmsg      OUTPUT    
               , @b_debug   = 0   
  
         IF @n_err <> 0    
         BEGIN   
            SET @n_continue= 3   
            SET @b_Success = 0  
            SET @n_err  = 163053  
            SET @c_errmsg = 'Execute ispFinalizeReceipt Failed'  
            GOTO RollbackTran  
         END   
      END   
   END  
   --(Wan03) - End  
     
   -- (TLTING02) start  
    SELECT @c_RCPTSTATStatus = ''  
   SELECT @b_Success = 0  
   Execute nspGetRight  
         @c_Facility,         -- facility  
         @c_StorerKey,        -- Storerkey  
         NULL,                -- Sku  
         'RCPTSTAT',    -- Configkey  
         @b_Success        OUTPUT,  
         @c_RCPTSTATStatus OUTPUT,  
         @n_err2           OUTPUT,  
         @c_ErrMsg         OUTPUT  
  
   IF @b_Success <> 1  
   BEGIN  
      SELECT @n_err = 163054 -- @n_err2  
      SELECT @n_continue = 3, @c_ErrMsg = RTRIM(@c_ErrMsg) + ' ispFinalizeReceipt'  
   END  
  
   IF EXISTS (SELECT 1 FROM dbo.StorerConfig WITH (NOLOCK)  
              WHERE StorerKey = @c_StorerKey  
              AND   ConfigKey = 'ASNFinalizeLottableRules'  
              AND   sValue = '1')  
      SET @nLottableRules = 1  
   ELSE  
      SET @nLottableRules = 0  
  
   --(Wan02) - START  
   SELECT RD.ReceiptKey, RD.ReceiptLineNumber, RD.FinalizeFlag  
   INTO #TMP_PREFNLDET  
   FROM  ReceiptDetail RD (NOLOCK)  
   WHERE RD.ReceiptKey = @c_ReceiptKey  
   AND   RD.FinalizeFlag <> 'Y'  
   AND   ReceiptLineNumber = CASE WHEN @c_ReceiptLineNumber = ''                          
                                  THEN ReceiptLineNumber ELSE @c_ReceiptLineNumber END      
   ORDER BY RD.ReceiptLineNumber  
  
   SELECT @b_Success = 0  
   Execute nspGetRight  
         @c_Facility,           -- facility  
         @c_StorerKey,          -- Storerkey  
         NULL,                  -- Sku  
         'FinalizeSplitReceiptLine',-- Configkey  
         @b_Success                    OUTPUT,  
         @c_FinalizeSplitReceiptLine   OUTPUT,  
         @n_err2                       OUTPUT,  
         @c_ErrMsg                     OUTPUT  
   IF @b_Success <> 1  
   BEGIN  
      SET @n_err = 163055 -- @n_err2  
      SET @n_continue = 3  
      SET @c_ErrMsg = RTRIM(@c_ErrMsg) + ' ispFinalizeReceipt'  
      GOTO RollbackTran  
   END  
  
   --(Wan02) - END  
  
   --(Wan04) - START  
   IF @n_continue=1 or @n_continue=2  
   BEGIN  
      SET @b_success = 0  
      Execute nspGetRight   
              @c_facility   
            , @c_StorerKey               -- Storer  
            , @c_Sku                     -- Sku  
            , 'ChkLocByCommingleSkuFlag'  -- ConfigKey  
            , @b_success                  OUTPUT   
            , @c_ChkLocByCommingleSkuFlag OUTPUT   
            , @n_err                      OUTPUT   
            , @c_errmsg                   OUTPUT  
        
      IF @b_success <> 1  
      BEGIN  
         SET @n_continue = 3  
         SET @n_err = 163056  
         SET @c_errmsg = 'ispFinalizeReceipt:' + RTRIM(@c_errmsg)  
      END  
   END  
   --(Wan04) - END  
      
   --(Wan07) - START
   IF @n_continue=1 or @n_continue=2  
   BEGIN  
      SET @b_success = 0  
      Execute nspGetRight   
              @c_facility   
            , @c_StorerKey                -- Storer  
            , @c_Sku                      -- Sku  
            , 'UCC'                       -- ConfigKey  
            , @b_success                  OUTPUT   
            , @c_UCC                      OUTPUT   
            , @n_err                      OUTPUT   
            , @c_errmsg                   OUTPUT  
        
      IF @b_success <> 1  
      BEGIN  
         SET @n_continue = 3  
         SET @n_err = 163057 
         SET @c_errmsg = 'ispFinalizeReceipt:' + RTRIM(@c_errmsg)  
      END  
   END  

   IF @n_continue=1 or @n_continue=2  
   BEGIN  
      SET @b_success = 0  
      Execute nspGetRight   
              @c_facility   
            , @c_StorerKey                -- Storer  
            , @c_Sku                      -- Sku  
            , 'UCCTracking'               -- ConfigKey  
            , @b_success                  OUTPUT   
            , @c_UCCTracking              OUTPUT   
            , @n_err                      OUTPUT   
            , @c_errmsg                   OUTPUT  
        
      IF @b_success <> 1  
      BEGIN  
         SET @n_continue = 3  
         SET @n_err = 163058  
         SET @c_errmsg = 'ispFinalizeReceipt:' + RTRIM(@c_errmsg)  
      END  
   END  

   IF @n_continue=1 or @n_continue=2  
   BEGIN  
      SET @b_success = 0  
      Execute nspGetRight   
              @c_facility   
            , @c_StorerKey                -- Storer  
            , @c_Sku                      -- Sku  
            , 'AddUCCFromColUDF01'        -- ConfigKey  
            , @b_success                  OUTPUT   
            , @c_AddUCCFromColUDF01       OUTPUT   
            , @n_err                      OUTPUT   
            , @c_errmsg                   OUTPUT  
        
      IF @b_success <> 1  
      BEGIN  
         SET @n_continue = 3  
         SET @n_err = 163059  
         SET @c_errmsg = 'ispFinalizeReceipt:' + RTRIM(@c_errmsg)  
      END  
   END 
   --(Wan07) - END
     
   --NJOW11 S
  IF @n_continue=1 or @n_continue=2  
   BEGIN  
      SET @b_success = 0  
      Execute nspGetRight   
              @c_facility   
            , @c_StorerKey               -- Storer  
            , @c_Sku                     -- Sku  
            , 'ChkNoMixLottableForAllSku'  -- ConfigKey  
            , @b_success                   OUTPUT   
            , @c_ChkNoMixLottableForAllSku OUTPUT   
            , @n_err                       OUTPUT   
            , @c_errmsg                    OUTPUT  
        
      IF @b_success <> 1  
      BEGIN  
         SET @n_continue = 3  
         SET @n_err = 163060  
         SET @c_errmsg = 'ispFinalizeReceipt:' + RTRIM(@c_errmsg)  
      END  
   END        
   --NJOW11 E     
     
   DECLARE Cur_ReceiptDetail CURSOR FAST_FORWARD READ_ONLY FOR  
      SELECT RD.ReceiptLineNumber, RD.BeforeReceivedQty, RD.Sku  
            ,UCCNo = CASE WHEN @c_UCCTracking = '1' THEN RD.ExternLineNo               --(Wan07)
                    WHEN @c_AddUCCFromColUDF01 = '1' THEN RD.UserDefine01              --(Wan07)
                    ELSE ''                                                            --(Wan07)
                    END                                                                

      FROM  ReceiptDetail RD (NOLOCK)  
      WHERE RD.ReceiptKey = @c_ReceiptKey  
      AND   RD.FinalizeFlag <> 'Y'  
      AND   RD.BeforeReceivedQty > RD.QtyReceived  
      AND   ReceiptLineNumber = CASE WHEN @c_ReceiptLineNumber = ''                        --(Wan02)  
                                     THEN ReceiptLineNumber ELSE @c_ReceiptLineNumber END  --(Wan02)  
      ORDER BY RD.ReceiptLineNumber  
  
   OPEN Cur_ReceiptDetail  
  
   FETCH NEXT FROM Cur_ReceiptDetail INTO @c_ReceiptLineNo, @c_QtyReceived, @c_SKU, @c_UCCNo --(Wan07)  
  
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
      IF @c_RCPTSTATStatus = '1'  
      BEGIN  
         SET @c_busr5 = ''  
         SET @c_ToLoc = ''  
         SELECT @c_busr5 = ISNULL(RTRIM(SKU.BUSR5), '')  
         FROM SKU WITH (NOLOCK)  
         WHERE Storerkey = @c_StorerKey  
         AND SKU = @c_SKU  
  
         -- Code lookup for default loc by facility + busr5(vendor)  
         Select @c_ToLoc = ISNULL(RTRIM(Short ), '')  
         FROM Codelkup (NOLOCK)  
         WHERE Listname = 'RCPTSTAT'  
         AND   Code = LEFT(RTRIM(@c_Facility) + '_____', 5) + @c_busr5  
      END  
  
      IF @nLottableRules = 1  
      BEGIN  
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
            @d_Lottable15Value = Lottable15  
         FROM dbo.ReceiptDetail WITH (NOLOCK)  
         WHERE ReceiptKey = @c_ReceiptKey  
         AND ReceiptLineNumber = @c_ReceiptLineNo  
  
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
  
         --SOS278355 Start    
         INSERT INTO TraceInfo (TraceName, TimeIn, Step1, Step2, Step3, Step4, Step5    
                               , Col1, Col2, Col3, Col4, Col5)    
         SELECT 'ispGenLot1_TH01', GETDATE(), EditDate, EditWho, ReceiptKey, ReceiptLineNumber    
               , @c_Lottable01Value, @c_Lottable02Value, sUser_sName(), '*1*', '', ''    
         FROM dbo.ReceiptDetail WITH (NOLOCK)    
         WHERE ReceiptKey = @c_ReceiptKey    
         AND ReceiptLineNumber = @c_ReceiptLineNo    
         --SOS278355 End    
    
         --SET @c_Sourcekey = RTRIM(@c_ReceiptKey) + RTRIM(@c_ReceiptLineNo)  
          
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
         WHERE StorerKey = @c_Storerkey  
         AND   SKU = @c_Sku  
         
         SELECT @n_count = 1, @c_Sourcetype = 'RECEIPTFINALIZE'  
  
         WHILE @n_count <= 15 AND @n_continue IN(1,2)    --TK01 increase max @n_count to 15  
         BEGIN  
              SET @c_Sourcekey = RTRIM(@c_ReceiptKey) + RTRIM(@c_ReceiptLineNo) --NJOW07  
  
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
                   @c_UDF01 = UDF01 --NJOW07  
            FROM CODELKUP (NOLOCK)  
            WHERE LISTNAME = @c_ListName  
            AND CODE = @c_Lottablelabel  
            AND (Storerkey = @c_Storerkey OR ISNULL(Storerkey,'')='') --NJOW04  
            ORDER BY Storerkey DESC --NJOW04  
  
            IF ISNULL(@c_sp_name,'') <> ''  
            BEGIN  
              --NJOW07  
              IF ISNULL(@c_UDF01,'') <> ''  
              BEGIN  
                 IF EXISTS (SELECT 1  
                             FROM   INFORMATION_SCHEMA.COLUMNS   
                             WHERE  TABLE_NAME = 'RECEIPT'  
                             AND    COLUMN_NAME = @c_UDF01)  
                  BEGIN  
                     SET @c_Value = ''  
                    SET @c_SQL = 'SELECT @c_Value = ' + RTRIM(@c_UDF01) + ' FROM RECEIPT (NOLOCK) WHERE Receiptkey = @c_Receiptkey'  
                     SET @c_SQLParm = '@c_Value NVARCHAR(60) OUTPUT, @c_Receiptkey NVARCHAR(10)'  
                      
                    EXEC sp_executesql @c_SQL,  
                       @c_SQLParm,  
                       @c_Value OUTPUT,  
                       @c_Receiptkey  
                         
                     IF ISNULL(@c_Value,'') <> ''  
                        SET @c_Sourcekey = @c_Value  
                 END  
              END  
  
               IF NOT EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_sp_name) AND type = 'P')  
               BEGIN  
                   SELECT @n_continue = 3  
                   SELECT @c_ErrMsg = CONVERT(char(250),@n_err), @n_err = 163061  
                   SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': Lottable Rule Listname '+ RTRIM(@c_listname)+' - Stored Proc name invalid ('+RTRIM(ISNULL(@c_sp_name,''))+') (ispFinalizeReceipt)'  
                   GOTO RollbackTran  
               END  
  
               SET @c_SQL = 'EXEC ' + @c_sp_name +  
                              + ' @c_Storerkey, @c_Sku, '  
                              + ' @c_Lottable01Value, @c_Lottable02Value, @c_Lottable03Value, @d_Lottable04Value, @d_Lottable05Value,'  
                              + ' @c_Lottable06Value, @c_Lottable07Value, @c_Lottable08Value, @c_Lottable09Value, @c_Lottable10Value,'  
                              + ' @c_Lottable11Value, @c_Lottable12Value, @d_Lottable13Value, @d_Lottable14Value, @d_Lottable15Value,'  
                              + ' @c_Lottable01 OUTPUT, @c_Lottable02 OUTPUT , @c_Lottable03 OUTPUT, @d_Lottable04 OUTPUT, @d_Lottable05 OUTPUT,'  
                              + ' @c_Lottable06 OUTPUT, @c_Lottable07 OUTPUT , @c_Lottable08 OUTPUT, @c_Lottable09 OUTPUT, @c_Lottable10 OUTPUT,'  
                              + ' @c_Lottable11 OUTPUT, @c_Lottable12 OUTPUT , @d_Lottable13 OUTPUT, @d_Lottable14 OUTPUT, @d_Lottable15 OUTPUT,'  
                              + ' @b_Success OUTPUT, @n_ErrNo OUTPUT, @c_ErrMsg OUTPUT, @c_Sourcekey, @c_SourceType, @c_LottableLabel'  
  
                SET @c_SQLParm = '@c_Storerkey NVARCHAR(15), @c_Sku NVARCHAR(20), '  
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
                     @c_Storerkey       ,  
                     @c_Sku             ,  
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
                  SELECT @n_continue = 3  
                  SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_ErrNo)+': Finalize Receipt Fail. (''ispFinalizeReceipt'')' + ' ( ' + ' SQLSvr MESSAGE=' + RTrim(@c_ErrMsg) + ' ) '  
                  GOTO RollbackTran  
               END  
  
               --SOS278355 Start    
               INSERT INTO TraceInfo (TraceName, TimeIn, Step1, Step2, Step3, Step4, Step5    
                                      , Col1, Col2, Col3, Col4, Col5)    
               VALUES ('ispGenLot1_TH01', GETDATE(), '', '', @c_ReceiptKey, @c_ReceiptLineNo, @c_Lottable01    
                       , @c_Lottable02, sUser_sName(), '*2*', '', '')    
               --SOS278355 End     
  
           UPDATE RECEIPTDETAIL WITH (ROWLOCK)  
                  SET Lottable01 = CASE WHEN ISNULL(@c_Lottable01, '')  = '' THEN Lottable01 ELSE @c_Lottable01 END,  
                      Lottable02 = CASE WHEN ISNULL(@c_Lottable02, '')  = '' THEN Lottable02 ELSE @c_Lottable02 END,  
                      Lottable03 = CASE WHEN ISNULL(@c_Lottable03, '')  = '' THEN Lottable03 ELSE @c_Lottable03 END,  
                      Lottable04 = CASE WHEN ISNULL(@d_Lottable04, '')  = '' THEN Lottable04 ELSE @d_Lottable04 END,  
                      Lottable05 = CASE WHEN ISNULL(@d_Lottable05, '')  = '' THEN Lottable05 ELSE @d_Lottable05 END,  
                      Lottable06 = CASE WHEN ISNULL(@c_Lottable06, '')  = '' THEN Lottable06 ELSE @c_Lottable06 END,  
                      Lottable07 = CASE WHEN ISNULL(@c_Lottable07, '')  = '' THEN Lottable07 ELSE @c_Lottable07 END,  
                      Lottable08 = CASE WHEN ISNULL(@c_Lottable08, '')  = '' THEN Lottable08 ELSE @c_Lottable08 END,  
                      Lottable09 = CASE WHEN ISNULL(@c_Lottable09, '')  = '' THEN Lottable09 ELSE @c_Lottable09 END,  
                      Lottable10 = CASE WHEN ISNULL(@c_Lottable10, '')  = '' THEN Lottable10 ELSE @c_Lottable10 END,  
                      Lottable11 = CASE WHEN ISNULL(@c_Lottable11, '')  = '' THEN Lottable11 ELSE @c_Lottable11 END,  
                      Lottable12 = CASE WHEN ISNULL(@c_Lottable12, '')  = '' THEN Lottable12 ELSE @c_Lottable12 END,  
                      Lottable13 = CASE WHEN ISNULL(@d_Lottable13, '')  = '' THEN Lottable13 ELSE @d_Lottable13 END,  
                      Lottable14 = CASE WHEN ISNULL(@d_Lottable14, '')  = '' THEN Lottable14 ELSE @d_Lottable14 END,  
                      Lottable15 = CASE WHEN ISNULL(@d_Lottable15, '')  = '' THEN Lottable15 ELSE @d_Lottable15 END,  
                      EditDate = GETDATE(),   
                      EditWho = SUSER_SNAME(),   
                      TrafficCop = NULL   
               WHERE ReceiptKey = @c_ReceiptKey  
                 AND ReceiptLineNumber = @c_ReceiptLineNo  
  
               SELECT @n_err = @@ERROR  
               IF @n_err <> 0  
               BEGIN  
                  SELECT @n_continue = 3  
                  SELECT @c_ErrMsg = CONVERT(char(250),@n_err) --, @n_err=62100  
                  SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': Finalize Receipt Fail. (''ispFinalizeReceipt'')' + ' ( ' + ' SQLSvr MESSAGE=' + RTrim(@c_ErrMsg) + ' ) '  
                  GOTO RollbackTran  
               END  
            END  
  
            SET @n_count = @n_count + 1  
         END --While  
      END  
  
      --(Wan07) - START  Move Down - Update FinalizeFlag after NoMixLottables Validation
      --UPDATE RECEIPTDETAIL WITH (ROWLOCK)  
      --   SET QtyReceived = BeforeReceivedQty,  
      --       FinalizeFlag = 'Y',  
      --       SplitPalletFlag = 'n',  
      --       ToLoc = CASE WHEN @c_RCPTSTATStatus = '1' AND LEN(ISNULL(RTRIM(@c_ToLoc), '')) > 0  
      --               THEN ISNULL(RTRIM(ToLoc), '') + @c_ToLoc  
      --               ELSE ToLoc END,        -- tlting    
      --       EditDate = GETDATE(),   
      --       EditWho = SUSER_SNAME()    
      --WHERE ReceiptKey = @c_ReceiptKey  
      --  AND ReceiptLineNumber = @c_ReceiptLineNo  
  
      --SELECT @n_err = @@ERROR  
      --IF @n_err <> 0  
      --BEGIN  
      --   SELECT @n_continue = 3  
      --   SELECT @c_ErrMsg = CONVERT(char(250),@n_err) --, @n_err=62100  
      --   SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': Finalize Receipt Fail. (''ispFinalizeReceipt'')' + ' ( ' + ' SQLSvr MESSAGE=' + RTrim(@c_ErrMsg) + ' ) '  
      --   GOTO RollbackTran    -- CM01  
      --END  
      --(Wan07) - END  Move Down
      
      --(Wan04) - START  
      IF @n_continue=1 or @n_continue=2  
      BEGIN  
         SELECT @c_Lottable01 = RTRIM(RD.Lottable01)  
               ,@c_Lottable02 = RTRIM(RD.Lottable02)     
               ,@c_Lottable03 = RTRIM(RD.Lottable03)  
               ,@d_Lottable04 = ISNULL(RD.Lottable04, CONVERT(DATETIME,'19000101'))  
               ,@c_Lottable06 = RTRIM(RD.Lottable06)                                               --(Wan05)   
               ,@c_Lottable07 = RTRIM(RD.Lottable07)                                               --(Wan05)   
               ,@c_Lottable08 = RTRIM(RD.Lottable08)                                               --(Wan05)   
               ,@c_Lottable09 = RTRIM(RD.Lottable09)                                               --(Wan05)   
               ,@c_Lottable10 = RTRIM(RD.Lottable10)                                               --(Wan05)   
               ,@c_Lottable11 = RTRIM(RD.Lottable11)                                               --(Wan05)         
               ,@c_Lottable12 = RTRIM(RD.Lottable12)                                               --(Wan05)   
               ,@d_Lottable13 = ISNULL(RD.Lottable13, CONVERT(DATETIME,'19000101'))                --(Wan05)   
               ,@d_Lottable14 = ISNULL(RD.Lottable14, CONVERT(DATETIME,'19000101'))                --(Wan05)       
               ,@d_Lottable15 = ISNULL(RD.Lottable15, CONVERT(DATETIME,'19000101'))                --(Wan05)   
               ,@c_ToLoc      = RTRIM(RD.ToLoc)  
         FROM dbo.RECEIPTDETAIL RD WITH (NOLOCK)  
         WHERE RD.ReceiptKey = @c_ReceiptKey  
         AND RD.ReceiptLineNumber = @c_ReceiptLineNo  
  
         SELECT  @c_NoMixLottable01 = CASE WHEN LOC.NoMixLottable01 IN ('1','Y') THEN '1' ELSE '0' END                
               , @c_NoMixLottable02 = CASE WHEN LOC.NoMixLottable02 IN ('1','Y') THEN '1' ELSE '0' END                    
               , @c_NoMixLottable03 = CASE WHEN LOC.NoMixLottable03 IN ('1','Y') THEN '1' ELSE '0' END                      
               , @c_NoMixLottable04 = CASE WHEN LOC.NoMixLottable04 IN ('1','Y') THEN '1' ELSE '0' END   
               , @c_NoMixLottable06 = CASE WHEN LOC.NoMixLottable06 IN ('1','Y') THEN '1' ELSE '0' END  --(Wan05)     
               , @c_NoMixLottable07 = CASE WHEN LOC.NoMixLottable07 IN ('1','Y') THEN '1' ELSE '0' END  --(Wan05)     
               , @c_NoMixLottable08 = CASE WHEN LOC.NoMixLottable08 IN ('1','Y') THEN '1' ELSE '0' END  --(Wan05)     
               , @c_NoMixLottable09 = CASE WHEN LOC.NoMixLottable09 IN ('1','Y') THEN '1' ELSE '0' END  --(Wan05)     
               , @c_NoMixLottable10 = CASE WHEN LOC.NoMixLottable10 IN ('1','Y') THEN '1' ELSE '0' END  --(Wan05)     
               , @c_NoMixLottable11 = CASE WHEN LOC.NoMixLottable11 IN ('1','Y') THEN '1' ELSE '0' END  --(Wan05)     
               , @c_NoMixLottable12 = CASE WHEN LOC.NoMixLottable12 IN ('1','Y') THEN '1' ELSE '0' END  --(Wan05)     
               , @c_NoMixLottable13 = CASE WHEN LOC.NoMixLottable13 IN ('1','Y') THEN '1' ELSE '0' END  --(Wan05)     
               , @c_NoMixLottable14 = CASE WHEN LOC.NoMixLottable14 IN ('1','Y') THEN '1' ELSE '0' END  --(Wan05)     
               , @c_NoMixLottable15 = CASE WHEN LOC.NoMixLottable15 IN ('1','Y') THEN '1' ELSE '0' END  --(Wan05)       
               , @c_CommingleSku    = CASE WHEN LOC.CommingleSku    IN ('1','Y') THEN '1' ELSE '0' END                       
         FROM LOC WITH (NOLOCK)  
         WHERE LOC = @c_ToLoc  
  
         IF @c_ChkLocByCommingleSkuFlag = '0'  
         BEGIN  
            IF @c_NoMixLottable01 = '1' OR @c_NoMixLottable02 = '1' OR @c_NoMixLottable03 = '1' OR @c_NoMixLottable04 = '1'   
            OR @c_NoMixLottable06 = '1' OR @c_NoMixLottable07 = '1' OR @c_NoMixLottable08 = '1' OR @c_NoMixLottable09 = '1' OR @c_NoMixLottable10 = '1'--(Wan05)  
            OR @c_NoMixLottable11 = '1' OR @c_NoMixLottable12 = '1' OR @c_NoMixLottable13 = '1' OR @c_NoMixLottable14 = '1' OR @c_NoMixLottable15 = '1'--(Wan05)  
            BEGIN  
               SET @c_CommingleSku = '0'  
            END  
            ELSE  
            BEGIN  
               SET @c_CommingleSku = '1'  
            END   
         END  
  
         IF @c_CommingleSku = '0'                                
         BEGIN  
            IF EXISTS (SELECT 1 FROM LOTxLOCxID LLI WITH (NOLOCK)    
                       WHERE LLI.Loc = @c_ToLoc  
                       AND  (LLI.Storerkey <> @c_Storerkey OR  LLI.Sku <> @c_Sku)  
                       AND   LLI.Qty - LLI.QtyPicked > 0)      
            BEGIN  
               SET @n_Continue = 3  
               SET @n_err = 163062    
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)  
                           +': Not Allow to receive commingle sku to Location: ' + RTRIM(@c_ToLOC)   
                           + '. (ispFinalizeReceipt)'   
               GOTO RollbackTran  
             END  
         END  
  
         IF @c_NoMixLottable01 = '1'    
         BEGIN  
            IF EXISTS (SELECT 1 FROM LOTATTRIBUTE LA WITH (NOLOCK)  
                       JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)  
                       WHERE LLI.Loc = @c_ToLoc  
                       AND  (LA.Storerkey = @c_Storerkey AND (LA.Sku = @c_Sku OR @c_ChkNoMixLottableForAllSku = '1') AND LA.Lottable01 <> @c_Lottable01)  ---NJOW11
                       AND   LLI.Qty - LLI.QtyPicked > 0)      
            BEGIN  
               SET @n_continue = 3  
               SET @n_err = 163063    
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)  
                           +': Not Allow receive to No Mix Lottable01 Location: ' + RTRIM(@c_ToLoc) + '. (ispFinalizeReceipt)'    
               GOTO RollbackTran  
            END  
         END  
  
         IF @c_NoMixLottable02 = '1'    
         BEGIN  
            IF EXISTS (SELECT 1 FROM LOTATTRIBUTE LA WITH (NOLOCK)  
                       JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)  
                       WHERE LLI.Loc = @c_ToLoc  
                       AND  (LA.Storerkey = @c_Storerkey AND (LA.Sku = @c_Sku OR @c_ChkNoMixLottableForAllSku = '1') AND LA.Lottable02 <> @c_Lottable02)  --NJOW11
                       AND   LLI.Qty - LLI.QtyPicked > 0)      
            BEGIN  
               SET @n_continue = 3  
               SET @n_err = 163064  
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)  
                           +': Not Allow to receive to No Mix Lottable02 Location: ' + RTRIM(@c_ToLoc) + '. (ispFinalizeReceipt)'    
               GOTO RollbackTran  
            END  
         END  
  
         IF @c_NoMixLottable03 = '1'    
         BEGIN  
            IF EXISTS (SELECT 1 FROM LOTATTRIBUTE LA WITH (NOLOCK)  
                       JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)  
                       WHERE LLI.Loc = @c_ToLoc  
                       AND  (LA.Storerkey = @c_Storerkey AND (LA.Sku = @c_Sku OR @c_ChkNoMixLottableForAllSku = '1') AND LA.Lottable03 <> @c_Lottable03)  --NJOW11
                       AND   LLI.Qty - LLI.QtyPicked > 0)      
            BEGIN  
               SET @n_continue = 3  
               SET @n_err = 163065   
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)  
                           +': Not Allow to receive to No Mix Lottable03 Location: ' + RTRIM(@c_ToLoc) + '. (ispFinalizeReceipt)'  
               GOTO RollbackTran  
            END  
         END  
  
         IF @c_NoMixLottable04 = '1'    
         BEGIN  
            IF EXISTS (SELECT 1 FROM LOTATTRIBUTE LA WITH (NOLOCK)  
                       JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)  
                       WHERE LLI.Loc = @c_ToLoc  
                       AND  (LA.Storerkey = @c_Storerkey AND (LA.Sku = @c_Sku OR @c_ChkNoMixLottableForAllSku = '1')  --NJOW11
                       AND   ISNULL(LA.Lottable04, CONVERT(DATETIME, '19000101')) <> @d_Lottable04)  
                       AND   LLI.Qty - LLI.QtyPicked > 0)      
            BEGIN  
               SET @n_continue = 3  
               SET @n_err = 163066  
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)  
                           +': Not Allow to receive to No Mix Lottable04 Location: ' + RTRIM(@c_ToLoc) + '. (ispFinalizeReceipt)'  
               GOTO RollbackTran  
            END  
         END  
         --(Wan05) - START  
         IF @c_NoMixLottable06 = '1'    
         BEGIN  
            IF EXISTS (SELECT 1 FROM LOTATTRIBUTE LA WITH (NOLOCK)  
                       JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)  
                       WHERE LLI.Loc = @c_ToLoc  
                       AND  (LA.Storerkey = @c_Storerkey AND (LA.Sku = @c_Sku OR @c_ChkNoMixLottableForAllSku = '1') AND LA.Lottable06 <> @c_Lottable06)   --NJOW11
                       AND   LLI.Qty - LLI.QtyPicked > 0)       
            BEGIN  
               SET @n_continue = 3  
               SET @n_err = 163067  
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)  
                           +': Not Allow to receive to No Mix Lottable06 Location: ' + RTRIM(@c_ToLoc) + '. (ispFinalizeReceipt)'  
               GOTO RollbackTran  
            END  
         END  
         IF @c_NoMixLottable07 = '1'    
         BEGIN  
            IF EXISTS (SELECT 1 FROM LOTATTRIBUTE LA WITH (NOLOCK)  
                       JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)  
                       WHERE LLI.Loc = @c_ToLoc  
                       AND  (LA.Storerkey = @c_Storerkey AND (LA.Sku = @c_Sku OR @c_ChkNoMixLottableForAllSku = '1') AND LA.Lottable07 <> @c_Lottable07)  --NJOW11
                       AND   LLI.Qty - LLI.QtyPicked > 0)       
            BEGIN  
               SET @n_continue = 3  
               SET @n_err = 163068  
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)  
                           +': Not Allow to receive to No Mix Lottable07 Location: ' + RTRIM(@c_ToLoc) + '. (ispFinalizeReceipt)'  
               GOTO RollbackTran  
            END  
         END  
         IF @c_NoMixLottable08 = '1'    
         BEGIN  
            IF EXISTS (SELECT 1 FROM LOTATTRIBUTE LA WITH (NOLOCK)  
                       JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)  
                       WHERE LLI.Loc = @c_ToLoc  
                       AND  (LA.Storerkey = @c_Storerkey AND (LA.Sku = @c_Sku OR @c_ChkNoMixLottableForAllSku = '1') AND LA.Lottable08 <> @c_Lottable08)  --NJOW11
                       AND   LLI.Qty - LLI.QtyPicked > 0)       
            BEGIN  
               SET @n_continue = 3  
               SET @n_err = 163069  
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)  
                           +': Not Allow to receive to No Mix Lottable08 Location: ' + RTRIM(@c_ToLoc) + '. (ispFinalizeReceipt)'  
               GOTO RollbackTran  
            END  
         END  
         IF @c_NoMixLottable09 = '1'    
         BEGIN  
            IF EXISTS (SELECT 1 FROM LOTATTRIBUTE LA WITH (NOLOCK)  
                       JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)  
                  WHERE LLI.Loc = @c_ToLoc  
                       AND  (LA.Storerkey = @c_Storerkey AND (LA.Sku = @c_Sku OR @c_ChkNoMixLottableForAllSku = '1') AND LA.Lottable09 <> @c_Lottable09)   --NJOW11
                       AND   LLI.Qty - LLI.QtyPicked > 0)       
            BEGIN  
               SET @n_continue = 3  
               SET @n_err = 163070  
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)  
                           +': Not Allow to receive to No Mix Lottable09 Location: ' + RTRIM(@c_ToLoc) + '. (ispFinalizeReceipt)'  
               GOTO RollbackTran  
            END  
         END  
         IF @c_NoMixLottable10 = '1'    
         BEGIN  
            IF EXISTS (SELECT 1 FROM LOTATTRIBUTE LA WITH (NOLOCK)  
                       JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)  
                       WHERE LLI.Loc = @c_ToLoc  
                       AND  (LA.Storerkey = @c_Storerkey AND (LA.Sku = @c_Sku OR @c_ChkNoMixLottableForAllSku = '1') AND LA.Lottable10 <> @c_Lottable10)   --NJOW11
                       AND   LLI.Qty - LLI.QtyPicked > 0)      
            BEGIN  
               SET @n_continue = 3  
               SET @n_err = 163071  
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)  
                           +': Not Allow to receive to No Mix Lottable10 Location: ' + RTRIM(@c_ToLoc) + '. (ispFinalizeReceipt)'  
               GOTO RollbackTran  
            END  
         END  
         IF @c_NoMixLottable11 = '1'    
         BEGIN  
            IF EXISTS (SELECT 1 FROM LOTATTRIBUTE LA WITH (NOLOCK)  
                       JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)  
                       WHERE LLI.Loc = @c_ToLoc  
                       AND  (LA.Storerkey = @c_Storerkey AND (LA.Sku = @c_Sku OR @c_ChkNoMixLottableForAllSku = '1') AND LA.Lottable11 <> @c_Lottable11)  --NJOW11
                       AND   LLI.Qty - LLI.QtyPicked > 0)      
            BEGIN  
               SET @n_continue = 3  
               SET @n_err = 163072  
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)  
                           +': Not Allow to receive to No Mix Lottable11 Location: ' + RTRIM(@c_ToLoc) + '. (ispFinalizeReceipt)'  
               GOTO RollbackTran  
            END  
         END  
  
         IF @c_NoMixLottable12 = '1'    
         BEGIN  
            IF EXISTS (SELECT 1 FROM LOTATTRIBUTE LA WITH (NOLOCK)  
                       JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)  
                       WHERE LLI.Loc = @c_ToLoc  
                       AND  (LA.Storerkey = @c_Storerkey AND (LA.Sku = @c_Sku OR @c_ChkNoMixLottableForAllSku = '1') AND LA.Lottable12 <> @c_Lottable12)   --NJOW11
                       AND   LLI.Qty - LLI.QtyPicked > 0)       
            BEGIN  
               SET @n_continue = 3  
               SET @n_err = 163073  
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)  
                           +': Not Allow to receive to No Mix Lottable12 Location: ' + RTRIM(@c_ToLoc) + '. (ispFinalizeReceipt)'  
               GOTO RollbackTran  
            END  
         END  
         IF @c_NoMixLottable13 = '1'    
         BEGIN  
            IF EXISTS (SELECT 1 FROM LOTATTRIBUTE LA WITH (NOLOCK)  
                       JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)  
                       WHERE LLI.Loc = @c_ToLoc  
                       AND  (LA.Storerkey = @c_Storerkey AND (LA.Sku = @c_Sku OR @c_ChkNoMixLottableForAllSku = '1') --NJOW11
                       AND   ISNULL(LA.Lottable13, CONVERT(DATETIME, '19000101')) <> @d_Lottable13)  
                       AND   LLI.Qty - LLI.QtyPicked > 0)      
            BEGIN  
               SET @n_continue = 3  
               SET @n_err = 163074  
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)  
                           +': Not Allow to receive to No Mix Lottable13 Location: ' + RTRIM(@c_ToLoc) + '. (ispFinalizeReceipt)'  
               GOTO RollbackTran  
            END  
         END  
         IF @c_NoMixLottable14 = '1'    
         BEGIN  
            IF EXISTS (SELECT 1 FROM LOTATTRIBUTE LA WITH (NOLOCK)  
                       JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)  
                       WHERE LLI.Loc = @c_ToLoc  
                       AND  (LA.Storerkey = @c_Storerkey AND (LA.Sku = @c_Sku OR @c_ChkNoMixLottableForAllSku = '1') --NJOW11
                       AND   ISNULL(LA.Lottable14, CONVERT(DATETIME, '19000101')) <> @d_Lottable14)  
                       AND   LLI.Qty - LLI.QtyPicked > 0)      
            BEGIN  
               SET @n_continue = 3  
               SET @n_err = 163075  
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)  
                           +': Not Allow to receive to No Mix Lottable14 Location: ' + RTRIM(@c_ToLoc) + '. (ispFinalizeReceipt)'  
               GOTO RollbackTran  
            END  
         END  
         IF @c_NoMixLottable15 = '1'    
         BEGIN  
            IF EXISTS (SELECT 1 FROM LOTATTRIBUTE LA WITH (NOLOCK)  
                       JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)  
                       WHERE LLI.Loc = @c_ToLoc  
                       AND  (LA.Storerkey = @c_Storerkey AND (LA.Sku = @c_Sku OR @c_ChkNoMixLottableForAllSku = '1') --NJOW11
                       AND   ISNULL(LA.Lottable15, CONVERT(DATETIME, '19000101')) <> @d_Lottable15)  
                       AND   LLI.Qty - LLI.QtyPicked > 0)      
            BEGIN  
               SET @n_continue = 3  
               SET @n_err = 163076  
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)  
                           +': Not Allow to receive to No Mix Lottable15 Location: ' + RTRIM(@c_ToLoc) + '. (ispFinalizeReceipt)'  
               GOTO RollbackTran  
            END  
         END  
         --(Wan05) - END  
      END  
      --(Wan04) - END  
  
      --(Wan07) - START
      IF (@c_UCC = '1' OR @c_UCCTracking = '1' OR @c_AddUCCFromColUDF01 = '1')
      BEGIN
         SET @c_UCCStatus = ''
         SELECT TOP 1 @c_UCCStatus = UCC.[Status]
               ,  @c_UCCNo = CASE WHEN UCCNo = @c_UCCNo THEN @c_UCCNo ELSE UCCNo END
         FROM UCC WITH (NOLOCK)
         WHERE Storerkey = @c_Storerkey
         AND   Sku = @c_Sku
         AND   ReceiptKey= @c_ReceiptKey
         AND   ReceiptLineNumber = @c_ReceiptLineNo
         AND   [Status] < '2'
         ORDER BY CASE WHEN UCCNo = @c_UCCNo THEN 1 ELSE 9 END

         IF @@ROWCOUNT = 0 AND @c_UCCNo <> ''
         BEGIN
            SET @c_UCCStatus = ''
            SELECT TOP 1 @c_UCCStatus = UCC.[Status]
            FROM UCC WITH (NOLOCK)
            WHERE Storerkey = @c_Storerkey
            AND   UCCNo = @c_UCCNo
            AND   Sku = @c_Sku
            AND   [Status] = '1'
         END
      END

      UPDATE RECEIPTDETAIL WITH (ROWLOCK)  
         SET QtyReceived = BeforeReceivedQty,  
               FinalizeFlag = 'Y',  
               SplitPalletFlag = 'n',  
               ToLoc = CASE WHEN @c_RCPTSTATStatus = '1' AND LEN(ISNULL(RTRIM(@c_ToLoc), '')) > 0  
                     THEN ISNULL(RTRIM(ToLoc), '') + @c_ToLoc  
                     ELSE ToLoc END,        -- tlting    
               EditDate = GETDATE(),   
               EditWho = SUSER_SNAME()    
      WHERE ReceiptKey = @c_ReceiptKey  
         AND ReceiptLineNumber = @c_ReceiptLineNo  

      SET @n_err = @@ERROR  
      IF @n_err <> 0  
      BEGIN  
         SET @n_continue = 3  
         SET @c_ErrMsg = CONVERT(char(250),@n_err) --, @n_err=62100  
         SET @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': Finalize Receipt Fail. (ispFinalizeReceipt)' 
                        + ' ( ' + ' SQLSvr MESSAGE=' + RTrim(@c_ErrMsg) + ' ) '  
         GOTO RollbackTran    -- CM01  
      END  

      IF (@c_UCC = '1' OR @c_UCCTracking = '1' OR @c_AddUCCFromColUDF01 = '1') AND @c_UCCNo <> ''
      BEGIN
         SET @c_Sourcekey = RTRIM(@c_ReceiptKey) + RTRIM(@c_ReceiptLineNo)  

         EXEC isp_ItrnUCCAdd
              @c_Storerkey       = @c_StorerKey 
            , @c_UCCNo           = @c_UCCNo     
            , @c_Sku             = @c_Sku  
            , @c_UCCStatus       = @c_UCCStatus            
            , @c_SourceKey       = @c_Sourcekey         
            , @c_ItrnSourceType  = 'ntrReceiptDetailUpdate' 
            , @c_ToStorerkey     = '' 
            , @c_ToUCCNo         = ''     
            , @c_ToSku           = ''  
            , @c_ToUCCStatus     = ''                         
            , @b_Success         = @b_Success          OUTPUT
            , @n_Err             = @n_Err              OUTPUT
            , @c_ErrMsg          = @c_ErrMsg           OUTPUT

         IF @b_Success <> 1  
         BEGIN 
            SET @n_continue = 3    
            SET @n_err = 163077 
            SET @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': Add ITRN UCC Fail. (ispFinalizeReceipt)' 
                           + ' ( ' + ' SQLSvr MESSAGE=' + RTrim(@c_ErrMsg) + ' ) '  
            GOTO RollbackTran    -- CM01  
         END  
      END
      --(Wan07) - END

      --(Wan02) - START  
      IF @c_FinalizeSplitReceiptLine = '1'  
      BEGIN  
         SET @n_NewQtyExpected = 0  
         SELECT @n_NewQtyExpected = QtyExpected - QtyReceived  
         FROM RECEIPTDETAIL WITH (NOLOCK)  
         WHERE ReceiptKey = @c_ReceiptKey  
           AND ReceiptLineNumber = @c_ReceiptLineNo  
  
         IF @n_NewQtyExpected > 0   
         BEGIN  
            SET @c_NewReceiptLineNumber = '00001'  
            SELECT @c_NewReceiptLineNumber = RIGHT('00000' + CONVERT(VARCHAR(5), MAX(ReceiptLineNumber) + 1),5)  
            FROM   RECEIPTDETAIL WITH (NOLOCK)  
            WHERE ReceiptKey = @c_ReceiptKey   
      
            INSERT INTO RECEIPTDETAIL   
               (   Receiptkey  
                  ,ReceiptLineNumber  
                  ,ExternReceiptKey  
                  ,ExternLineNo  
                  ,Storerkey  
                  ,Sku  
                  ,AltSku  
                  ,Packkey  
                  ,UOM  
                  ,QtyExpected  
                  ,ToLot  
                  ,ToLoc  
                  ,ToID  
                  ,Lottable01  
                  ,Lottable02  
                  ,Lottable03  
                  ,Lottable04  
                  ,Lottable05  
                  ,Lottable06  
                  ,Lottable07  
                  ,Lottable08  
                  ,Lottable09  
                  ,Lottable10  
                  ,Lottable11  
                  ,Lottable12  
                  ,Lottable13  
                  ,Lottable14  
                  ,Lottable15  
                  ,EffectiveDate   
                  ,OtherUnit1  
                  ,OtherUnit2  
                  ,UnitPrice  
                  ,ExternPoKey  
                  ,POLineNumber  
                  ,UserDefine01  
                  ,UserDefine02  
                  ,UserDefine03  
                  ,UserDefine04  
                  ,UserDefine05  
                  ,UserDefine06  
                  ,UserDefine07  
                  ,UserDefine08  
                  ,UserDefine09  
                  ,UserDefine10  
               )  
            SELECT Receiptkey  
                  ,@c_NewReceiptLineNumber  
                  ,ExternReceiptKey  
                  ,ExternLineNo  
                  ,Storerkey  
                  ,Sku  
                  ,AltSku  
                  ,Packkey  
                  ,UOM  
                  ,@n_NewQtyExpected  
                  ,''  
                  ,ToLoc  
                  ,''  
                  ,Lottable01  
                  ,Lottable02  
                  ,Lottable03  
                  ,Lottable04  
                  ,Lottable05  
                  ,Lottable06  
                  ,Lottable07  
                  ,Lottable08  
                  ,Lottable09  
                  ,Lottable10  
                  ,Lottable11  
                  ,Lottable12  
                  ,Lottable13  
                  ,Lottable14  
                  ,Lottable15                    
                  ,EffectiveDate   
                  ,OtherUnit1  
                  ,OtherUnit2  
                  ,UnitPrice  
                  ,ExternPoKey  
                  ,POLineNumber  
                  ,UserDefine01  
                  ,UserDefine02  
                  ,UserDefine03  
                  ,UserDefine04  
                  ,UserDefine05  
                  ,UserDefine06  
                  ,UserDefine07  
                  ,UserDefine08  
                  ,UserDefine09  
                  ,UserDefine10  
            FROM RECEIPTDETAIL WITH (NOLOCK)  
            WHERE ReceiptKey = @c_ReceiptKey  
              AND ReceiptLineNumber = @c_ReceiptLineNo  
  
            SET @n_err = @@ERROR  
            IF @n_err <> 0  
            BEGIN  
               SET @n_continue = 3  
               SET @c_ErrMsg = CONVERT(char(250),@n_err)  
               -- SET @n_err=62103  
               SET @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': Finalize Receipt Fail. (''ispFinalizeReceipt'')' + ' ( ' + ' SQLSvr MESSAGE=' + RTrim(@c_ErrMsg) + ' ) '  
            END  
  
             UPDATE RECEIPTDETAIL WITH (ROWLOCK)  
               SET QtyExpected = QtyExpected - QtyReceived   
                  ,EditWho     = SUSER_NAME()  
                  ,EditDate    = GETDATE()  
                  ,Trafficcop  = NULL  
            WHERE ReceiptKey = @c_ReceiptKey  
              AND ReceiptLineNumber = @c_ReceiptLineNo  
  
            SET @n_err = @@ERROR  
            IF @n_err <> 0  
            BEGIN  
               SET @n_continue = 3  
               SET @c_ErrMsg = CONVERT(char(250),@n_err)  
               SET @n_err = 163078  
               SET @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': Finalize Receipt Fail. (''ispFinalizeReceipt'')' + ' ( ' + ' SQLSvr MESSAGE=' + RTrim(@c_ErrMsg) + ' ) '  
            END  
         END  
      END  
      --(Wan02) - END  
      FETCH NEXT FROM Cur_ReceiptDetail INTO @c_ReceiptLineNo, @c_QtyReceived, @c_SKU, @c_UCCNo --(Wan07) 

   END -- @@FETCH_STATUS <> -1  
  
   CLOSE Cur_ReceiptDetail  
   DEALLOCATE Cur_ReceiptDetail  
  
   -- TLTING02 end  
     
   -- (james01)   start --NJOW05  
   IF EXISTS (SELECT 1 FROM StorerConfig WITH (NOLOCK) WHERE StorerKey = @c_StorerKey  
              AND ConfigKey = 'GenLot2withASN_ASNLineNo' AND SValue = '1')  
   BEGIN  
      IF EXISTS (SELECT 1 FROM RECEIPTDETAIL WITH (NOLOCK)  
                 JOIN SKU WITH (NOLOCK) ON (RECEIPTDETAIL.SKU = SKU.Sku  
                                        AND RECEIPTDETAIL.StorerKey = SKU.StorerKey)  
                 WHERE SKU.LOTTABLE02LABEL = 'GETASN'  
                   AND ReceiptKey = @c_ReceiptKey  
                   AND SUBSTRING(Lottable02, 12, 5) <> ReceiptLineNumber  
                   AND ReceiptLineNumber = CASE WHEN @c_ReceiptLineNumber = ''                     --(Wan02)  
                                                THEN ReceiptLineNumber ELSE @c_ReceiptLineNumber   --(Wan02)  
                                                END)                                               --(Wan02)  
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @c_ErrMsg = CONVERT(char(250),@n_err), @n_err = 163079  
         SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': Finalize Receipt Fail. Lottable02 not tally with ReceiptLineNumber. (''ispFinalizeReceipt'')'  
         GOTO RollbackTran  
      END  
   END  
   -- (james01)   end     
  
   -- SOS137640 Auto hold by lot if sku.receiptholdcode = 'HMCE'   (james01)  
   -- Filter by QtyReceived > 0 and FinalizeFlag = 'Y' (Shong01)  
  
   DECLARE Cur_ReceiptDetail CURSOR FAST_FORWARD READ_ONLY FOR  
   SELECT RD.StorerKey, RD.SKU, RD.Lottable02, CL.CODE  
   FROM Receipt R WITH (NOLOCK)   
   JOIN ReceiptDetail RD WITH (NOLOCK) ON R.Receiptkey = RD.Receiptkey  
   JOIN SKU SKU (NOLOCK) ON (RD.STORERKEY = SKU.STORERKEY AND RD.SKU = SKU.SKU)  
   JOIN CODELKUP CL (NOLOCK) ON (SKU.RECEIPTHOLDCODE = CL.CODE)  
   --(Wan02) - START  
   JOIN #TMP_PREFNLDET TMP ON (RD.ReceiptKey = TMP.ReceiptKey AND RD.ReceiptLineNumber = TMP.ReceiptLineNumber)  
                           AND(TMP.FinalizeFlag = 'N')  
   --(Wan02) - END  
   WHERE R.ReceiptKey = @c_ReceiptKey  
      --AND CL.CODE = 'HMCE'  
      AND CONVERT(NVARCHAR(20), CL.Notes) IN ('LOT','AUTOHOLDLOTTABLE02') --NJOW09  
      AND RD.QtyReceived > 0  
      AND RD.FinalizeFlag = 'Y'  
      AND CL.ListName = 'INVHOLD'   -- (james03)  
      AND 1 = CASE WHEN R.DocType = 'R' AND ISNULL(CL.UDF02,'') = 'EXCL_RTN' THEN 2 ELSE 1 END  --NJOW06  
   ORDER BY RD.ReceiptLineNumber  
  
    OPEN Cur_ReceiptDetail         --(CS03)  
       
   FETCH NEXT FROM Cur_ReceiptDetail INTO @c_StorerKey, @c_SKU, @c_Lottable02, @c_CodeLKUp  
   WHILE @@FETCH_STATUS <> -1 AND ( @n_continue = 1 or @n_continue = 2)  
   BEGIN  
      --NJOW09 to remark  
      --IF NOT EXISTS (SELECT 1 FROM InventoryHold WITH (NOLOCK)  
      --   WHERE StorerKey = @c_storerkey  
      --      AND SKU = @c_sku  
      --      AND Lottable02 = @c_lottable02)  
      --BEGIN  
         SELECT @b_success = 1  
         SET @c_Reason = 'AUTO HOLD on RECEIPT for REASON = ' + ISNULL(RTRIM(@c_CodeLKUp), '')  
  
   EXEC nspInventoryHoldWrapper  
            '',               -- lot  
            '',               -- loc  
            '',               -- id  
            @c_StorerKey,     -- storerkey  
            @c_SKU,           -- sku  
            '',               -- lottable01  
            @c_Lottable02,    -- lottable01  
            '',               -- lottable01  
            NULL,             -- lottable01  
            NULL,             -- lottable01  
            '',  
            '',  
            '',  
            '',  
            '',  
            '',  
            '',  
            NULL,   
            NULL,   
            NULL,   
            @c_CodeLKUp,      -- status  
            '1',              -- hold  
            @b_success OUTPUT,  
            @n_err OUTPUT,  
            @c_errmsg OUTPUT,  
            @c_Reason   -- remark  
  
         IF @n_err <> 0  
         BEGIN  
            SELECT @n_continue = 3  
            SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': Finalize Receipt Fail. (''ispFinalizeReceipt'')' + ' ( ' + ' SQLSvr MESSAGE=' + RTrim(@c_ErrMsg) + ' ) '  
         END  
      --END  
      FETCH NEXT FROM Cur_ReceiptDetail INTO @c_StorerKey, @c_SKU, @c_Lottable02, @c_CodeLKUp  
   END -- @@FETCH_STATUS <> -1  
  
   CLOSE Cur_ReceiptDetail  
   DEALLOCATE Cur_ReceiptDetail  
  
--NJOW09  
   DECLARE Cur_ReceiptDetail CURSOR FAST_FORWARD READ_ONLY FOR  
   SELECT RD.StorerKey, RD.SKU, RD.ToId, CL.CODE  
   FROM Receipt R WITH (NOLOCK)   
   JOIN ReceiptDetail RD WITH (NOLOCK) ON R.Receiptkey = RD.Receiptkey  
   JOIN SKU SKU (NOLOCK) ON (RD.STORERKEY = SKU.STORERKEY AND RD.SKU = SKU.SKU)  
   JOIN CODELKUP CL (NOLOCK) ON (SKU.RECEIPTHOLDCODE = CL.CODE)  
   --(Wan02) - START  
   JOIN #TMP_PREFNLDET TMP ON (RD.ReceiptKey = TMP.ReceiptKey AND RD.ReceiptLineNumber = TMP.ReceiptLineNumber)  
                           AND(TMP.FinalizeFlag = 'N')  
   --(Wan02) - END  
   WHERE R.ReceiptKey = @c_ReceiptKey  
      --AND CL.CODE = 'HMCE'  
      AND CONVERT(NVARCHAR(20), CL.Notes) = 'AUTOHOLDID'  
      AND RD.QtyReceived > 0  
      AND RD.FinalizeFlag = 'Y'  
      AND CL.ListName = 'INVHOLD'   -- (james03)  
      AND 1 = CASE WHEN R.DocType = 'R' AND ISNULL(CL.UDF02,'') = 'EXCL_RTN' THEN 2 ELSE 1 END  --NJOW06  
   ORDER BY RD.ReceiptLineNumber  
  
   OPEN Cur_ReceiptDetail  
  
   FETCH NEXT FROM Cur_ReceiptDetail INTO @c_StorerKey, @c_SKU, @c_ID, @c_CodeLKUp  
   WHILE @@FETCH_STATUS <> -1 AND ( @n_continue = 1 or @n_continue = 2)  
   BEGIN  
         SELECT @b_success = 1  
         SET @c_Reason = 'AUTO HOLD(ID) on RECEIPT for REASON = ' + ISNULL(RTRIM(@c_CodeLKUp), '')  
  
   EXEC nspInventoryHoldWrapper  
            '',               -- lot  
            '',               -- loc  
            @c_Id,               -- id  
            @c_StorerKey,     -- storerkey  
            @c_SKU,           -- sku  
            '',               -- lottable01  
            '',    -- lottable01  
            '',               -- lottable01  
            NULL,             -- lottable01  
            NULL,             -- lottable01  
            '',  
            '',  
            '',  
            '',  
            '',  
            '',  
            '',  
            NULL,   
            NULL,   
            NULL,   
            @c_CodeLKUp,      -- status  
            '1',              -- hold  
            @b_success OUTPUT,  
            @n_err OUTPUT,  
            @c_errmsg OUTPUT,  
            @c_Reason   -- remark  
  
         IF @n_err <> 0  
         BEGIN  
            SELECT @n_continue = 3  
            SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': Finalize Receipt Fail. (''ispFinalizeReceipt'')' + ' ( ' + ' SQLSvr MESSAGE=' + RTrim(@c_ErrMsg) + ' ) '  
         END  
         FETCH NEXT FROM Cur_ReceiptDetail INTO @c_StorerKey, @c_SKU, @c_ID, @c_CodeLKUp  
   END -- @@FETCH_STATUS <> -1  
  
   CLOSE Cur_ReceiptDetail  
   DEALLOCATE Cur_ReceiptDetail  
  
--NJOW03  
 DECLARE Cur_ReceiptDetail CURSOR FAST_FORWARD READ_ONLY FOR  
      SELECT RD.StorerKey, RD.SKU, RD.Lottable03, CASE WHEN ISNULL(CL.UDF01,'')='' THEN SKU.RECEIPTHOLDCODE ELSE LEFT(CL.UDF01,10) END AS Receiptholdcode  
      FROM  ReceiptDetail RD WITH (NOLOCK)  
      JOIN SKU SKU (NOLOCK) ON (RD.STORERKEY = SKU.STORERKEY AND RD.SKU = SKU.SKU)  
      JOIN STORERCONFIG SC (NOLOCK) ON RD.Storerkey = SC.Storerkey AND SC.Configkey = 'HoldLottable03ByUDF08'   
                                    AND RD.Userdefine08 = SC.Svalue    
      JOIN #TMP_PREFNLDET TMP ON (RD.ReceiptKey = TMP.ReceiptKey AND RD.ReceiptLineNumber = TMP.ReceiptLineNumber)  
                              AND(TMP.FinalizeFlag = 'N')  
      LEFT JOIN CODELKUP CL (NOLOCK) ON (SKU.RECEIPTHOLDCODE = CL.CODE AND CL.ListName = 'INVHOLD' AND CONVERT(NVARCHAR(20), CL.Notes) = 'LOT')                                
      WHERE RD.ReceiptKey = @c_ReceiptKey  
         AND RD.QtyReceived > 0  
         AND RD.FinalizeFlag = 'Y'  
         AND ISNULL(RD.Userdefine08,'') <> ''  
         AND ISNULL(RD.Lottable03,'') <> ''  
         AND ISNULL(SKU.RECEIPTHOLDCODE,'') <> ''  
  ORDER BY RD.ReceiptLineNumber  
 OPEN Cur_ReceiptDetail  
   
 FETCH NEXT FROM Cur_ReceiptDetail INTO @c_StorerKey, @c_SKU, @c_Lottable03, @c_ReceiptHoldCode  
 WHILE @@FETCH_STATUS <> -1 AND ( @n_continue = 1 or @n_continue = 2)  
 BEGIN  
      IF NOT EXISTS (SELECT 1 FROM InventoryHold WITH (NOLOCK)  
         WHERE StorerKey = @c_storerkey  
            AND SKU = @c_sku  
            AND Lottable03 = @c_lottable03)  
      BEGIN  
         SELECT @b_success = 1  
         SET @c_Reason = 'AUTO HOLD on RECEIPT for QC for REASON = ' + ISNULL(RTRIM(@c_ReceiptHoldCode), '')  
  
         EXEC nspInventoryHoldWrapper  
            '',               -- lot  
            '',               -- loc  
            '',               -- id  
            @c_StorerKey,     -- storerkey  
            @c_SKU,           -- sku  
            '',               -- lottable01  
            '',               -- lottable02  
            @c_Lottable03,    -- lottable03  
            NULL,             -- lottable04  
            NULL,             -- lottable05  
            '',               --lottable06     --(CS02)    
            '',               --lottable07     --(CS02)   
            '',               --lottable08     --(CS02)   
            '',               --lottable09     --(CS02)   
            '',               --lottable10     --(CS02)   
            '',               --lottable11     --(CS02)  
            '',               --lottable12     --(CS02)  
            NULL,   --lottable13     --(CS02)  
            NULL,             --lottable14     --(CS02)  
            NULL,             --lottable15     --(CS02)  
            @c_ReceiptHoldCode,  -- status  
            '1',              -- hold  
            @b_success OUTPUT,  
            @n_err OUTPUT,  
            @c_errmsg OUTPUT,  
            @c_Reason   -- remark  
  
         IF @n_err <> 0  
         BEGIN  
            SELECT @n_continue = 3  
            SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': Finalize Receipt Fail. (''ispFinalizeReceipt'')' + ' ( ' + ' SQLSvr MESSAGE=' + RTrim(@c_ErrMsg) + ' ) '  
         END  
      END  
                    
      FETCH NEXT FROM Cur_ReceiptDetail INTO @c_StorerKey, @c_SKU, @c_Lottable03, @c_ReceiptHoldCode  
   END -- @@FETCH_STATUS <> -1  
  
   CLOSE Cur_ReceiptDetail  
   DEALLOCATE Cur_ReceiptDetail  

   IF @n_Continue = 1 OR @n_Continue = 2  --(james04)
   BEGIN
      --NJOW10  
      SET @b_Success = 0  
      SET @c_ASNHoldLottableByInvHold = ''  
        
      EXEC nspGetRight    
            @c_Facility  = @c_Facility   
          , @c_StorerKey = @c_StorerKey   
          , @c_sku       = NULL  
          , @c_ConfigKey = 'ASNHoldLottableByInvHold'    
          , @b_Success   = @b_Success                  OUTPUT    
          , @c_authority = @c_ASNHoldLottableByInvHold OUTPUT     
          , @n_err       = @n_err                      OUTPUT     
          , @c_errmsg    = @c_errmsg                   OUTPUT    
     
      IF @c_ASNHoldLottableByInvHold IN ('01','02','03','06','07','08','09','10','11','12')  
      BEGIN  
         SET @c_LottableField = 'LOTTABLE'  + LTRIM(RTRIM(@c_ASNHoldLottableByInvHold))          
      SET @c_LottableValue = ''  
        
      SELECT @c_SQL = N'DECLARE Cur_ReceiptDetail CURSOR FAST_FORWARD READ_ONLY FOR   
                          SELECT DISTINCT RECEIPTDETAIL.StorerKey, RECEIPTDETAIL.SKU, RECEIPTDETAIL.' + @c_LottableField +   
                     ' FROM RECEIPTDETAIL(NOLOCK)   
                          JOIN SKU (NOLOCK) ON (RECEIPTDETAIL.STORERKEY = SKU.STORERKEY AND RECEIPTDETAIL.SKU = SKU.SKU)  
                          JOIN #TMP_PREFNLDET TMP ON (RECEIPTDETAIL.ReceiptKey = TMP.ReceiptKey AND RECEIPTDETAIL.ReceiptLineNumber = TMP.ReceiptLineNumber)  
                                               AND(TMP.FinalizeFlag = ''N'')  
                       WHERE RECEIPTDETAIL.Receiptkey = @c_receiptkey  
                       AND RECEIPTDETAIL.QtyReceived > 0  
                          AND RECEIPTDETAIL.FinalizeFlag = ''Y''                       
                       AND ISNULL(RECEIPTDETAIL.' + @c_LottableField + ','''') <> '''' '    
     
      EXEC sp_executesql @c_SQL,   
             N'@c_receiptkey NVARCHAR(10)',                     
             @c_Receiptkey          
     
         OPEN Cur_ReceiptDetail   
                
        FETCH NEXT FROM Cur_ReceiptDetail INTO @c_StorerKey, @c_SKU, @c_LottableValue  
          
        WHILE @@FETCH_STATUS <> -1 AND ( @n_continue = 1 or @n_continue = 2)  
        BEGIN                
            SET @c_ReceiptHoldCode = ''  
           SET @c_SQL = ' SELECT @c_ReceiptHoldCode = Status   
                          FROM INVENTORYHOLD (NOLOCK)  
                          WHERE Storerkey = @c_Storerkey  
                          AND Sku = @c_Sku   
                          AND ' + @c_LottableField + ' = @c_LottableValue  
                          AND Hold = ''1'' '  
     
            EXEC sp_EXECUTEsql @c_SQL,   
                     N'@c_Storerkey NVARCHAR(15), @c_Sku NVARCHAR(20), @c_LottableValue NVARCHAR(30), @c_ReceiptHoldCode NVARCHAR(10) OUTPUT',                     
                      @c_Storerkey,  
                      @c_Sku,  
                      @c_LottableValue,  
                      @c_ReceiptHoldCode OUTPUT  
                        
            IF ISNULL(@c_ReceiptHoldCode,'') <> ''  
            BEGIN                          
               SELECT  
                  @c_Lottable01  = CASE WHEN @c_ASNHoldLottableByInvHold = '01' THEN @c_LottableValue ELSE '' END,  
                  @c_Lottable02  = CASE WHEN @c_ASNHoldLottableByInvHold = '02' THEN @c_LottableValue ELSE '' END,  
                  @c_Lottable03  = CASE WHEN @c_ASNHoldLottableByInvHold = '03' THEN @c_LottableValue ELSE '' END,  
                  @c_Lottable06  = CASE WHEN @c_ASNHoldLottableByInvHold = '06' THEN @c_LottableValue ELSE '' END,  
                  @c_Lottable07  = CASE WHEN @c_ASNHoldLottableByInvHold = '07' THEN @c_LottableValue ELSE '' END,  
                  @c_Lottable08  = CASE WHEN @c_ASNHoldLottableByInvHold = '08' THEN @c_LottableValue ELSE '' END,  
                  @c_Lottable09  = CASE WHEN @c_ASNHoldLottableByInvHold = '09' THEN @c_LottableValue ELSE '' END,  
                  @c_Lottable10  = CASE WHEN @c_ASNHoldLottableByInvHold = '10' THEN @c_LottableValue ELSE '' END,  
                  @c_Lottable11  = CASE WHEN @c_ASNHoldLottableByInvHold = '11' THEN @c_LottableValue ELSE '' END,  
                  @c_Lottable12  = CASE WHEN @c_ASNHoldLottableByInvHold = '12' THEN @c_LottableValue ELSE '' END  
     
                SET @c_Reason = 'AUTO HOLD on RECEIPT for REASON = ' + ISNULL(RTRIM(@c_ReceiptHoldCode), '')  
                  
             EXEC nspInventoryHoldWrapper  
                      '',               -- lot  
                      '',               -- loc  
                      '',               -- id  
                      @c_StorerKey,     -- storerkey  
                      @c_SKU,           -- sku  
                      @c_Lottable01,    -- lottable01  
                      @c_Lottable02,    -- lottable02  
                      @c_Lottable03,    -- lottable03  
                      NULL,             -- lottable04  
                      NULL,             -- lottable05  
                      @c_Lottable06,    -- lottable06  
                      @c_Lottable07,    -- lottable07  
                      @c_Lottable08,    -- lottable08  
                      @c_Lottable09,    -- lottable09  
                      @c_Lottable10,    -- lottable10  
                      @c_Lottable11,    -- lottable11  
                      @c_Lottable12,    -- lottable12  
                      NULL,             -- lottable13  
                      NULL,             -- lottable14  
                      NULL,             -- lottable15  
                      @c_ReceiptHoldCode,      -- status  
                      '1',              -- hold  
                      @b_success OUTPUT,  
                      @n_err OUTPUT,  
                      @c_errmsg OUTPUT,  
                      @c_Reason         -- remark  
                  
                IF @n_err <> 0  
                BEGIN  
                   SELECT @n_continue = 3  
                   SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': Finalize Receipt Fail. (''ispFinalizeReceipt'')' + ' ( ' + ' SQLSvr MESSAGE=' + RTrim(@c_ErrMsg) + ' ) '  
                END  
            END  
                                       
           FETCH NEXT FROM Cur_ReceiptDetail INTO @c_StorerKey, @c_SKU, @c_LottableValue  
        END  
        CLOSE Cur_ReceiptDetail  
        DEALLOCATE Cur_ReceiptDetail  
     END   
   END
   
   SET @d_step1 = GETDATE() - @d_step1 -- (tlting01)  
   SET @c_Col1 = 'Stp1-UPTRD'  
  
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  
      -- Check whether the All the Detail sucessfully finalize or not  
      -- (Wan06) - START  
      DECLARE @b_ReadyToCloseASN                INT  
            , @b_Finalized                      INT  
            , @c_CloseASNUponLastItemFinalized  NVARCHAR(10)  
      SET @b_ReadyToCloseASN = 1  
  
      SELECT @b_ReadyToCloseASN = 0   
      FROM  RECEIPTDETAIL RD WITH (NOLOCK)  
      WHERE RD.ReceiptKey = @c_ReceiptKey  
      AND   RD.FinalizeFlag <> 'Y'  
      AND   RD.BeforeReceivedQty > RD.QtyReceived   
  
      SET @b_Finalized = @b_ReadyToCloseASN  
  
      IF RTRIM(@c_ReceiptLineNumber) <> '' AND @c_ReceiptLineNumber IS NOT NULL    
      BEGIN  
         SET @b_Finalized = 0  
         SELECT @b_Finalized = 1  
         FROM RECEIPTDETAIL WITH (NOLOCK)  
         WHERE ReceiptKey = @c_ReceiptKey  
         AND ReceiptLineNumber = @c_ReceiptLineNumber  
         AND Finalizeflag = 'Y'  
   
         IF @b_ReadyToCloseASN = 1  
         BEGIN  
            SET @c_CloseASNUponLastItemFinalized = ''  
            SET @b_Success = 0  
            Execute nspGetRight  
                  @c_Facility            -- facility  
               ,  @c_StorerKey           -- Storerkey  
               ,  NULL                   -- Sku  
               ,  'CloseASNUponLastItemFinalized' --FNZRCPTLINESKIPAUTOCLOSE' -- Configkey  
               ,  @b_Success                       OUTPUT   
               ,  @c_CloseASNUponLastItemFinalized OUTPUT   
               ,  @n_err2                          OUTPUT   
               ,  @c_ErrMsg                        OUTPUT  
  
            IF @b_Success <> 1  
            BEGIN  
               SET @n_err = 163080 -- @n_err2  
               SET @n_continue = 3  
               SET @c_ErrMsg = RTRIM(@c_ErrMsg) + ' ispFinalizeReceipt'  
            END  
  
            IF (@n_continue = 1 OR @n_continue = 2)   
            BEGIN  
               SET @b_ReadyToCloseASN = 0  
               IF @c_CloseASNUponLastItemFinalized = '1' OR CHARINDEX(@c_Doctype, @c_CloseASNUponLastItemFinalized) > 0  
               BEGIN  
                  SET @b_ReadyToCloseASN = 1  
               END  
            END  
         END  
  
         IF (@n_continue = 1 OR @n_continue = 2) AND @b_ReadyToCloseASN = 1  
         BEGIN     
            SELECT @b_ReadyToCloseASN = 0  
            FROM RECEIPTDETAIL RD WITH (NOLOCK)  
            WHERE RD.Receiptkey = @c_ReceiptKey   
            GROUP BY RD.Storerkey, RD.Sku  
            HAVING   SUM(RD.QtyExpected) > SUM(RD.QtyReceived)  
         END  
      END  
  
      --IF NOT EXISTS(SELECT 1 FROM  ReceiptDetail RD WITH (NOLOCK)  
      --              WHERE RD.ReceiptKey = @c_ReceiptKey  
      --               --(Wan02) - START  
      --                AND ((RD.FinalizeFlag <> 'Y'  
      --                AND RD.BeforeReceivedQty > RD.QtyReceived   
      --                AND @c_ReceiptLineNumber = '')  
      --               OR (RD.FinalizeFlag <> 'Y'  
      --                AND RD.QtyReceived = 0  
      --                AND @c_ReceiptLineNumber <> '')))  
      --              --(Wan02) - END  
      IF (@n_continue = 1 OR @n_continue = 2) AND @b_ReadyToCloseASN = 1   
      -- (Wan06) - END  
      BEGIN  
         SET @d_step2 = GETDATE()  -- (tlting01)  
  
--         SELECT @c_StorerKey = StorerKey,  
--                @c_Facility  = Facility  
--         FROM   RECEIPT WITH (NOLOCK)  
--         WHERE  ReceiptKey = @c_ReceiptKey  
  
         SELECT @b_Success = 0  
         Execute nspGetRight  
               @c_Facility,         -- facility  
               @c_StorerKey,        -- Storerkey  
               NULL,                -- Sku  
               'CloseASNStatus',    -- Configkey  
               @b_Success        OUTPUT,  
               @c_CloseASNStatus OUTPUT,  
               @n_err2           OUTPUT,  
               @c_ErrMsg         OUTPUT,
               @c_Option1        OUTPUT,   --WL03 
               @c_Option2        OUTPUT,   --WL03
               @c_Option3        OUTPUT,   --WL03
               @c_Option4        OUTPUT,   --WL03
               @c_Option5        OUTPUT    --WL03
  
         IF @b_Success <> 1  
         BEGIN  
            SELECT @n_err = 163081 -- @n_err2  
            SELECT @n_continue = 3, @c_ErrMsg = RTRIM(@c_ErrMsg) + ' ispFinalizeReceipt'  
         END  

         --WL03 START
         IF ISNULL(@c_Option5,'') <> ''
         BEGIN
            SELECT @c_IncludeReceiptGroup = dbo.fnc_GetParamValueFromString('@c_IncludeReceiptGroup', @c_Option5, @c_IncludeReceiptGroup) 
         END

         IF @c_CloseASNStatus = '1' AND ISNULL(@c_IncludeReceiptGroup,'') <> ''
         BEGIN
            IF NOT EXISTS (SELECT 1 FROM RECEIPT (NOLOCK) WHERE Receiptkey = @c_Receiptkey AND ReceiptGroup IN (SELECT ColValue from dbo.fnc_delimsplit (',',@c_IncludeReceiptGroup)) )
            BEGIN
               SET @c_CloseASNStatus = '0'
            END
         END
         --WL03 END
  
         SELECT @b_Success = 0  
         Execute nspGetRight  
               @c_Facility,           -- facility  
               @c_StorerKey,          -- Storerkey  
               NULL,                  -- Sku  
               'CloseASNUponFinalize',-- Configkey  
               @b_Success              OUTPUT,  
               @c_CloseASNUponFinalize OUTPUT,  
               @n_err2                 OUTPUT,  
               @c_ErrMsg               OUTPUT  
         IF @b_Success <> 1  
         BEGIN  
            SELECT @n_err = 163082 -- @n_err2  
            SELECT @n_continue = 3, @c_ErrMsg = RTRIM(@c_ErrMsg) + ' ispFinalizeReceipt'  
         END  
  
         SELECT @b_Success = 0  
         Execute nspGetRight  
               @c_Facility,           -- facility  
               @c_StorerKey,          -- Storerkey  
               NULL,                  -- Sku  
               'PalletCalculation',   -- Configkey  
               @b_Success              OUTPUT,  
               @c_PalletCalculation    OUTPUT,  
               @n_err2                 OUTPUT,  
         @c_ErrMsg               OUTPUT  
         IF @b_Success <> 1  
         BEGIN  
            SELECT @n_err = 163083 -- @n_err2  
            SELECT @n_continue = 3, @c_ErrMsg = RTRIM(@c_ErrMsg) + ' ispFinalizeReceipt'  
         END  
  
         IF @c_PalletCalculation = '1'  
         BEGIN  
            SET @n_StockBalQty = 0  
  
            SELECT @n_PalletCnt = COUNT(DISTINCT LLL.Loc + ISNULL(RD.LOC, ''))  
            FROM   LOTxLOCxID LLL WITH (NOLOCK)  
            JOIN   LOC WITH (NOLOCK) ON LOC.Loc = LLL.Loc  
            LEFT OUTER JOIN ( SELECT DISTINCT ToLoc As LOC  
                              FROM   ReceiptDetail WITH (NOLOCK)  
                              WHERE  Receiptkey = @c_ReceiptKey  
                              AND    BeforeReceivedQty + QtyReceived > 0  
                             ) AS RD ON RD.LOC = LOC.LOC  
            WHERE  LLL.Storerkey = @c_StorerKey  
            AND    Loc.SectionKey = 'Location'  
            AND    LLL.Qty > 0  
  
            SET @n_PalletCnt = ISNULL(@n_PalletCnt, 0)  
  
            SET @n_StockBalQty = @n_StockBalQty + @n_PalletCnt  
  
            SELECT @n_PalletCnt = COUNT(DISTINCT LLL.ID + ISNULL(RD.ID, ''))  
            FROM   LOTxLOCxID LLL WITH (NOLOCK)  
            JOIN   LOC WITH (NOLOCK) ON LOC.Loc = LLL.Loc  
            LEFT OUTER JOIN (  
                     SELECT DISTINCT ToID As ID  
                     FROM   ReceiptDetail WITH (NOLOCK)  
                     JOIN   LOC WITH (NOLOCK) ON LOC.Loc = ReceiptDetail.ToLoc  
                     WHERE  Receiptkey = @c_ReceiptKey  
                     AND    Loc.SectionKey = 'Pallet'  
                     AND    BeforeReceivedQty + QtyReceived > 0  
                     AND    ID > ''  
                    ) AS RD ON RD.ID = LLL.ID  
            WHERE  LLL.Storerkey = @c_StorerKey  
            AND    Loc.SectionKey = 'Pallet'  
            AND    LLL.Qty > 0  
            AND    LLL.ID > ''  
  
            SET @n_PalletCnt = ISNULL(@n_PalletCnt, 0)  
  
            SET @n_StockBalQty = @n_StockBalQty + @n_PalletCnt  
         END -- @c_PalletCalculation = '1'  
  
  
         IF @c_CloseASNStatus = '1' OR @c_CloseASNUponFinalize = '1'  
         BEGIN  
  
            UPDATE RECEIPT WITH (ROWLOCK)  
               SET ASNStatus = CASE WHEN @c_CloseASNStatus = '1' THEN '9' ELSE ASNStatus END,  
                   Status    = CASE WHEN @c_CloseASNUponFinalize = '1' THEN '9' ELSE Status END,  
                   -- SOS#125406 Convert to varchar else will caused system error  
                   UserDefine02 = CASE WHEN @c_PalletCalculation = '1'  
                                            THEN CAST(@n_StockBalQty as NVARCHAR(30))  
                                       ELSE UserDefine02  
                                  END,   
                   EditDate = GETDATE(),  
                   EditWho = SUSER_SNAME()   
            WHERE ReceiptKey = @c_ReceiptKey  
            SET @n_err = @@ERROR  
            IF @n_err <> 0  
            BEGIN  
               SET @n_continue = 3  
               SET @c_ErrMsg = CONVERT(char(250),@n_err)  
               SET @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': Finalize Receipt Fail. (''ispFinalizeReceipt'')' + ' ( ' + ' SQLSvr MESSAGE=' + RTrim(@c_ErrMsg) + ' ) '  
            END  
  
         END  
         SET @d_step2 = GETDATE() - @d_step2 -- (tlting01)  
         SET @c_Col2 = 'Stp2-GetRight'  
           
         --(Wan01) - START   
         -- Move Call POSTFinalizeReceiptSP block to if @b_finalized = 1 below  
         /* (START)  
         IF @n_continue = 1 OR @n_continue = 2  
         BEGIN  
            SET @b_Success = 0  
            SET @c_PostFinalizeReceiptSP = ''  
            EXEC nspGetRight    
                  @c_Facility  = NULL   
                , @c_StorerKey = @c_StorerKey   
                , @c_sku       = NULL  
                , @c_ConfigKey = 'PostFinalizeReceiptSP'    
                , @b_Success   = @b_Success                  OUTPUT    
                , @c_authority = @c_PostFinalizeReceiptSP   OUTPUT     
                , @n_err       = @n_err                      OUTPUT     
                , @c_errmsg    = @c_errmsg                   OUTPUT    
     
            IF EXISTS (SELECT 1 FROM sys.objects o WHERE NAME = @c_PostFinalizeReceiptSP AND TYPE = 'P')  
            BEGIN  
               SET @b_Success = 0    
               EXECUTE dbo.ispPostFinalizeReceiptWrapper   
                       @c_ReceiptKey        = @c_ReceiptKey  
                     , @c_ReceiptLineNumber = @c_ReceiptLineNumber               --(Wan02)  
                     , @c_PostFinalizeReceiptSP   = @c_PostFinalizeReceiptSP  
                     , @b_Success = @b_Success     OUTPUT    
                     , @n_Err     = @n_err         OUTPUT     
                     , @c_ErrMsg  = @c_errmsg      OUTPUT    
                     , @b_debug   = 0   
     
               IF @n_err <> 0    
               BEGIN   
                  SET @n_continue= 3   
                  SET @b_Success = 0  
                  SET @n_err  = 60071  
                  SET @c_errmsg = 'Execute ispFinalizeReceipt Failed'  
               END   
            END   
         END (END)  
         */  
         --(Wan01) - End  
      END  
  
  
      IF (@n_continue = 1 OR @n_continue = 2) AND @b_Finalized = 1  
      BEGIN  
         SET @b_Success = 0  
         SET @c_PostFinalizeReceiptSP = ''  
         EXEC nspGetRight    
               @c_Facility  = @c_Facility --NJOW08   
             , @c_StorerKey = @c_StorerKey   
             , @c_sku       = NULL  
             , @c_ConfigKey = 'PostFinalizeReceiptSP'    
             , @b_Success   = @b_Success                  OUTPUT    
             , @c_authority = @c_PostFinalizeReceiptSP    OUTPUT     
             , @n_err       = @n_err                      OUTPUT     
             , @c_errmsg    = @c_errmsg                   OUTPUT    
  
         IF EXISTS (SELECT 1 FROM sys.objects o WHERE NAME = @c_PostFinalizeReceiptSP AND TYPE = 'P')  
         BEGIN  
            SET @b_Success = 0    
            EXECUTE dbo.ispPostFinalizeReceiptWrapper   
                    @c_ReceiptKey        = @c_ReceiptKey  
                  , @c_ReceiptLineNumber = @c_ReceiptLineNumber               --(Wan02)  
                  , @c_PostFinalizeReceiptSP   = @c_PostFinalizeReceiptSP  
                  , @b_Success = @b_Success     OUTPUT    
                  , @n_Err     = @n_err         OUTPUT     
                  , @c_ErrMsg  = @c_errmsg      OUTPUT    
                  , @b_debug   = 0   
  
            IF @n_err <> 0    
            BEGIN   
               SET @n_continue= 3   
               SET @b_Success = 0  
               SET @n_err  = 163084 
               SET @c_errmsg = 'Execute ispFinalizeReceipt Failed'  
            END   
         END   
      END
      
      --WL01 START
      IF (@n_continue = 1 OR @n_continue = 2) AND @b_Finalized = 1  
      BEGIN
         SET @b_Success         = 0
         SET @c_ASNAutoCreateSO = '0'
         
         Execute nspGetRight   
                 @c_facility   
               , @c_StorerKey               -- Storer  
               , NULL                       -- Sku  
               , 'ASNAutoCreateSO'          -- ConfigKey  
               , @b_success                  OUTPUT   
               , @c_ASNAutoCreateSO          OUTPUT   
               , @n_err                      OUTPUT   
               , @c_errmsg                   OUTPUT  
         
         IF @b_success <> 1  
         BEGIN  
            SET @n_continue = 3  
            SET @n_err = 163084  
            SET @c_errmsg = 'ispFinalizeReceipt:' + RTRIM(@c_errmsg)  
         END

         IF(@c_ASNAutoCreateSO IN ('1'))
         BEGIN 
            EXECUTE dbo.isp_ASNAutoCreateSO_Wrapper   
                    @c_ReceiptKey        = @c_ReceiptKey  
                  , @c_ReceiptLineNumber = @c_ReceiptLineNumber     
                  , @b_Success           = @b_Success    OUTPUT    
                  , @n_Err               = @n_err        OUTPUT     
                  , @c_ErrMsg            = @c_errmsg     OUTPUT    
                  , @b_debug             = 0   
  
            IF @n_err <> 0    
            BEGIN   
               SET @n_continue= 3   
               SET @b_Success = 0  
               SET @n_err  = 163085  
               SET @c_errmsg = 'Execute ispFinalizeReceipt Failed'  
            END
         END
      END  
      --WL01 END

      --WL02 Start
      DECLARE Cur_ReceiptDetail CURSOR FAST_FORWARD READ_ONLY FOR  
      SELECT RD.StorerKey  ,RD.SKU        ,CL.CODE       ,CL.UDF01
            ,RD.Lottable01 ,RD.Lottable02 ,RD.Lottable03 ,RD.Lottable04 ,RD.Lottable05
            ,RD.Lottable06 ,RD.Lottable07 ,RD.Lottable08 ,RD.Lottable09 ,RD.Lottable10
            ,RD.Lottable11 ,RD.Lottable12 ,RD.Lottable13 ,RD.Lottable14 ,RD.Lottable15
      FROM Receipt R WITH (NOLOCK)   
      JOIN ReceiptDetail RD WITH (NOLOCK) ON (R.Receiptkey = RD.Receiptkey)  
      JOIN SKU SKU (NOLOCK) ON (RD.STORERKEY = SKU.STORERKEY AND RD.SKU = SKU.SKU)  
      JOIN CODELKUP CL (NOLOCK) ON (SKU.RECEIPTHOLDCODE = CL.CODE AND CL.LISTNAME = 'ASNHOLDLOT' AND CL.Storerkey = RD.StorerKey)  
      JOIN #TMP_PREFNLDET TMP ON (RD.ReceiptKey = TMP.ReceiptKey AND RD.ReceiptLineNumber = TMP.ReceiptLineNumber)  
                             AND (TMP.FinalizeFlag = 'N')   
      WHERE R.ReceiptKey = @c_ReceiptKey
         AND (ISNULL(CL.UDF02,'') = '' OR R.Doctype IN (SELECT COLVALUE FROM dbo.fnc_DelimSplit(',',CL.UDF02) ) ) --IF UDF02 is blank, include all doctype
         AND RD.QtyReceived > 0  
         AND RD.FinalizeFlag = 'Y'  
      ORDER BY RD.ReceiptLineNumber  
      
      OPEN Cur_ReceiptDetail         
       
      FETCH NEXT FROM Cur_ReceiptDetail INTO @c_StorerKey      , @c_SKU            , @c_CodeLKUp       , @c_UDF01
                                           , @c_Lottable01Value, @c_Lottable02Value, @c_Lottable03Value, @d_Lottable04Value, @d_Lottable05Value
                                           , @c_Lottable06Value, @c_Lottable07Value, @c_Lottable08Value, @c_Lottable09Value, @c_Lottable10Value
                                           , @c_Lottable11Value, @c_Lottable12Value, @d_Lottable13Value, @d_Lottable14Value, @d_Lottable15Value

      WHILE @@FETCH_STATUS <> -1 AND ( @n_continue = 1 or @n_continue = 2)  
      BEGIN  
         SELECT @b_success = 1      
         SET @c_Reason = 'AUTO HOLD on RECEIPT for REASON = ' + ISNULL(RTRIM(@c_CodeLKUp), '')  

         SELECT @c_Lottable01 = NULL, @c_Lottable02 = NULL, @c_Lottable03 = NULL, @d_Lottable04 = NULL, @d_Lottable05 = NULL
              , @c_Lottable06 = NULL, @c_Lottable07 = NULL, @c_Lottable08 = NULL, @c_Lottable09 = NULL, @c_Lottable10 = NULL
              , @c_Lottable11 = NULL, @c_Lottable12 = NULL, @d_Lottable13 = NULL, @d_Lottable14 = NULL, @d_Lottable15 = NULL

         DECLARE Cur_UDF01 CURSOR FAST_FORWARD READ_ONLY FOR  
         SELECT COLVALUE FROM DBO.fnc_DelimSplit(',',@c_UDF01) WHERE COLVALUE LIKE '[0-1][0-9]'

         OPEN Cur_UDF01

         FETCH NEXT FROM Cur_UDF01 INTO @c_Lottables

         WHILE @@FETCH_STATUS <> -1
         BEGIN
            IF(@c_Lottables BETWEEN '01' AND '15')
            BEGIN
                    IF (@c_Lottables = '01') SET @c_Lottable01 = @c_Lottable01Value
               ELSE IF (@c_Lottables = '02') SET @c_Lottable02 = @c_Lottable02Value
               ELSE IF (@c_Lottables = '03') SET @c_Lottable03 = @c_Lottable03Value
               ELSE IF (@c_Lottables = '04') SET @d_Lottable04 = @d_Lottable04Value
               ELSE IF (@c_Lottables = '05') SET @d_Lottable05 = @d_Lottable05Value
               ELSE IF (@c_Lottables = '06') SET @c_Lottable06 = @c_Lottable06Value
               ELSE IF (@c_Lottables = '07') SET @c_Lottable07 = @c_Lottable07Value
               ELSE IF (@c_Lottables = '08') SET @c_Lottable08 = @c_Lottable08Value
               ELSE IF (@c_Lottables = '09') SET @c_Lottable09 = @c_Lottable09Value
               ELSE IF (@c_Lottables = '10') SET @c_Lottable10 = @c_Lottable10Value
               ELSE IF (@c_Lottables = '11') SET @c_Lottable11 = @c_Lottable11Value
               ELSE IF (@c_Lottables = '12') SET @c_Lottable12 = @c_Lottable12Value
               ELSE IF (@c_Lottables = '13') SET @d_Lottable13 = @d_Lottable13Value
               ELSE IF (@c_Lottables = '14') SET @d_Lottable14 = @d_Lottable14Value
               ELSE IF (@c_Lottables = '15') SET @d_Lottable15 = @d_Lottable15Value
            END
            FETCH NEXT FROM Cur_UDF01 INTO @c_Lottables
         END
         CLOSE Cur_UDF01
         DEALLOCATE Cur_UDF01
         
         EXEC nspInventoryHoldWrapper  
               '',               -- lot  
               '',               -- loc  
               '',               -- id  
               @c_StorerKey,     -- storerkey  
               @c_SKU,           -- sku  
               @c_Lottable01,    -- lottable01  
               @c_Lottable02,    -- lottable02  
               @c_Lottable03,    -- lottable03  
               @d_Lottable04,    -- lottable04  
               @d_Lottable05,    -- lottable05  
               @c_Lottable06,    -- lottable06  
               @c_Lottable07,    -- lottable07  
               @c_Lottable08,    -- lottable08  
               @c_Lottable09,    -- lottable09  
               @c_Lottable10,    -- lottable10  
               @c_Lottable11,    -- lottable11  
               @c_Lottable12,    -- lottable12  
               @d_Lottable13,    -- lottable13  
               @d_Lottable14,    -- lottable14   
               @d_Lottable15,    -- lottable15   
               @c_CodeLKUp,      -- status  
               '1',              -- hold  
               @b_success OUTPUT,  
               @n_err OUTPUT,  
               @c_errmsg OUTPUT,  
               @c_Reason   -- remark  
  
         IF @n_err <> 0  
         BEGIN  
            SELECT @n_continue = 3  
            SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': Finalize Receipt Fail. (''ispFinalizeReceipt'')' + ' ( ' + ' SQLSvr MESSAGE=' + RTrim(@c_ErrMsg) + ' ) '  
         END  

         FETCH NEXT FROM Cur_ReceiptDetail INTO @c_StorerKey      , @c_SKU            , @c_CodeLKUp       , @c_UDF01
                                              , @c_Lottable01Value, @c_Lottable02Value, @c_Lottable03Value, @d_Lottable04Value, @d_Lottable05Value
                                              , @c_Lottable06Value, @c_Lottable07Value, @c_Lottable08Value, @c_Lottable09Value, @c_Lottable10Value
                                              , @c_Lottable11Value, @c_Lottable12Value, @d_Lottable13Value, @d_Lottable14Value, @d_Lottable15Value
      END -- @@FETCH_STATUS <> -1  
  
      CLOSE Cur_ReceiptDetail  
      DEALLOCATE Cur_ReceiptDetail  
      --WL02 End
   END  
  
   -- TraceInfo (tlting01) - Start  
   IF @c_debug = '3'  
   BEGIN  
      SET @d_endtime = GETDATE()  
      INSERT INTO TraceInfo (TraceName, TimeIn, TimeOut, TotalTime,  
                             Step1, Step2, Step3, Step4, Step5,  
                             Col1, Col2, Col3, Col4, Col5)  
      VALUES  
         (RTRIM(@c_TraceName), @d_starttime, @d_endtime  
         ,CONVERT(CHAR(12),@d_endtime - @d_starttime ,114)  
         ,CONVERT(CHAR(12),@d_step1,114)  
         ,CONVERT(CHAR(12),@d_step2,114)  
         ,CONVERT(CHAR(12),@d_step3,114)  
         ,CONVERT(CHAR(12),@d_step4,114)  
         ,CONVERT(CHAR(12),@d_step5,114)  
         ,@c_Col1,@c_Col2,@c_Col3,@c_Col4,@c_Col5)  
  
         SET @d_step1 = NULL  
         SET @d_step2 = NULL  
         SET @d_step3 = NULL  
         SET @d_step4 = NULL  
         SET @d_step5 = NULL  
    END  
   -- TraceInfo (tlting01) - End  
  
   RollbackTran:  
   --(Wan04) - START  
   IF CURSOR_STATUS( 'GLOBAL', 'Cur_ReceiptDetail') in (0 , 1)    
   BEGIN  
      CLOSE Cur_ReceiptDetail  
      DEALLOCATE Cur_ReceiptDetail  
   END  
   --(Wan04) - END  
     
   /* #INCLUDE <SPIAM2.SQL> */  
   IF @n_continue=3  -- Error Occured - Process And Return  
   BEGIN  
      DECLARE @n_IsRDT INT  
      EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT  
     
      IF @n_IsRDT = 1  
      BEGIN  
         -- RDT cannot handle rollback (blank XML will generate). So we are not going to issue a rollback here  
         -- Instead we commit and raise an error back to parent, let the parent decide  
     
         -- Commit until the level we begin with  
         WHILE @@TRANCOUNT > @n_starttcnt  
            COMMIT TRAN  
     
         -- Raise error with severity = 10, instead of the default severity 16.  
         -- RDT cannot handle error with severity > 10, which stop the processing after executed this trigger  
         RAISERROR (@n_err, 10, 1) WITH SETERROR  
     
         -- The RAISERROR has to be last line, to ensure @@ERROR is not getting overwritten  
      END  
      ELSE  
      BEGIN     
         SELECT @b_Success = 0  
         IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_StartTCnt  
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
         EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispFinalizeReceipt'  
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
         RETURN  
      END  
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
END  

GO