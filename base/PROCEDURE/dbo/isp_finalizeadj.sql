SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER ON;
GO
/*******************************************************************************/
/* Stored Procedure: isp_FinalizeADJ                                           */
/* Creation Date:                                                              */
/* Copyright: Maersk Logistics                                                 */
/* Written by:  June                                                           */
/*                                                                             */
/* Purpose: To fix performance issue in finalizing ADJ.                        */
/*          Initial PB script will refresh the adj detail after each           */
/*          update. If there is 5000 adj lines, system will retrieve           */
/*          5000 times.                                                        */
/*                                                                             */
/* Called By: Policy object - nep_cst_policy_finalize_adj                      */
/*                                                                             */
/* PVCS Version: 2.2                                                           */
/*                                                                             */
/* Version: 6.0                                                                */
/*                                                                             */
/* Data Modifications:                                                         */
/*                                                                             */
/* Updates:                                                                    */
/* Date         Author       Ver.   Purposes                                   */
/* 24-Sep-2009  Leong        1.1    SOS#148847 - Update Adjustment EditDate and*/
/*                                               EditWho                       */
/* 31-Jan-2011  YTWan        1.2    Adjustment Status Control. (Wan01)         */
/* 21-Jan-2013  James        1.3    SOS257258 - When all Detail finalized then */
/*                                  Header need to finalize too    (james01)   */
/* 22-Apr-2013  James        1.4    Set UCC.status = '0' when qty = 0 (james02)*/
/* 16-May-2014  NJOW01       1.5    311354-add adjustment validation           */
/* 16-OCT-2015  YTWan        1.6    SOS#354468 - FrieslandHK- FC System Batch  */
/*                                  number (lottable02) builder (Wan02)        */
/* 14-Mar-2016  CSCHONG      1.7    Add new config to call Adj finalize        */
/*                                  lottable rules SOS#364463 (CS01)           */
/* 09-May-2017  NJOW02       1.8    WMS-1884 add post finalize call custom sp  */
/* 07-Jun-2017  SPChin       1.9    IN00366121 - Bug Fixed                     */
/* 28-May-2019  LZG          2.0    INC0690149-Handle Adjustment.FinalizedFlag */
/*                                  update in script instead of PB (ZG01)      */
/* 28-Aug-2019  NJOW03       2.1    Fix move validation up before check lot    */
/* 01-Jun-2020  Wan03        2.2    WMS-13117 - [CN] Sephora_WMS_ITRN_Add_UCC_CR*/
/* 01-AUG-2024  Wan04        2.3    LFWM-4397 - RG [GIT] Serial Number Solution*/
/*                                  - Adjustment by Serial Number              */
/* 12-NOV-2024  Satyam      2.4    UWP-23314 - Duplicate ID validation wrt     */
/*                                           locations                         */
/* 24-Nov-2024  NJOW04       2.5    WMS-23053 Skip check ucc qty if adj is     */
/*                                  created from CC UCC adj posting            */
/* 24-Nov-2024  NJOW04       2.5    DEVOPS Combine Script                      */
/* 03-JAN-2024  Wan05        2.6    LFWM-4405 - [GIT] Serial Number Solution-Post*/
/*                                  Cycle Count by Adjustment Serialnon - Fix  */
/*******************************************************************************/

CREATE   PROCEDURE [dbo].[isp_FinalizeADJ]
   @c_ADJKey NVARCHAR(10),
   @b_Success INT=1 OUTPUT,
   @n_err INT=0 OUTPUT,
   @c_errmsg NVARCHAR(255)='' OUTPUT
AS
BEGIN
   -- main
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
    
   DECLARE @n_continue INT
         ,@c_adjline NVARCHAR(5)
         ,@b_debug INT
         ,@c_Facility NVARCHAR(5) --(Wan02)
         ,@c_StorerKey NVARCHAR(15) --(Wan02)
         ,@c_PreFinalizeADJSP NVARCHAR(10) --(Wan02)
         ,@c_AllowUCCAdjustment NVARCHAR(10) --(Wan02)
         ,@c_Sku NVARCHAR(20) --(Wan02)
         ,@c_Lot NVARCHAR(10) --(Wan02)
         ,@c_NewLot NVARCHAR(10) --(Wan02)
         ,@c_Loc NVARCHAR(10) --(Wan02)
         ,@c_ID NVARCHAR(18) --(Wan02)
         ,@c_UCCNo NVARCHAR(20) --(Wan02)
         ,@c_lottable01Label NVARCHAR(20) --(Wan02)
         ,@c_Lottable01 NVARCHAR(18) --(Wan02)
         ,@c_Lottable02 NVARCHAR(18) --(Wan02)
         ,@c_Lottable03 NVARCHAR(18) --(Wan02)
         ,@dt_Lottable04 DATETIME --(Wan02)
         ,@dt_Lottable05 DATETIME --(Wan02)
         ,@c_Lottable06 NVARCHAR(30) --(Wan02)
         ,@c_Lottable07 NVARCHAR(30) --(Wan02)
         ,@c_Lottable08 NVARCHAR(30) --(Wan02)
         ,@c_Lottable09 NVARCHAR(30) --(Wan02)
         ,@c_Lottable10 NVARCHAR(30) --(Wan02)
         ,@c_Lottable11 NVARCHAR(30) --(Wan02)
         ,@c_Lottable12 NVARCHAR(30) --(Wan02)
         ,@dt_Lottable13 DATETIME --(Wan02)
         ,@dt_Lottable14 DATETIME --(Wan02)
         ,@dt_Lottable15 DATETIME --(Wan02)
         ,@n_Qty INT --(Wan02)
         ,@c_PostFinalizeADJSP NVARCHAR(10) --NJOW02
    
   /*CS01 Start*/
   DECLARE @c_Lottable01Value      NVARCHAR(18)
         ,@c_Lottable02Value      NVARCHAR(18)
         ,@c_Lottable03Value      NVARCHAR(18)
         ,@dt_Lottable04Value     DATETIME
         ,@dt_Lottable05Value     DATETIME
         ,@c_Lottable06Value      NVARCHAR(30)
         ,@c_Lottable07Value      NVARCHAR(30)
         ,@c_Lottable08Value      NVARCHAR(30)
         ,@c_Lottable09Value      NVARCHAR(30)
         ,@c_Lottable10Value      NVARCHAR(30)
         ,@c_Lottable11Value      NVARCHAR(30)
         ,@c_Lottable12Value      NVARCHAR(30)
         ,@dt_Lottable13Value     DATETIME
         ,@dt_Lottable14Value     DATETIME
         ,@dt_Lottable15Value     DATETIME
         ,@n_LottableRules        INT
         ,@c_UDF01                NVARCHAR(60)
         ,@c_Value                NVARCHAR(60)
         ,@c_Sourcekey            NVARCHAR(15)
         ,@c_Sourcetype           NVARCHAR(20)
         ,@n_count                INT
         ,@c_listname             NVARCHAR(10)
         ,@c_LottableLabel        NVARCHAR(20)
         ,@c_LottableLabel01      NVARCHAR(20)
         ,@c_LottableLabel02      NVARCHAR(20)
         ,@c_LottableLabel03      NVARCHAR(20)
         ,@c_LottableLabel04      NVARCHAR(20)
         ,@c_LottableLabel05      NVARCHAR(20)
         ,@c_LottableLabel06      NVARCHAR(30)
         ,@c_LottableLabel07      NVARCHAR(30)
         ,@c_LottableLabel08      NVARCHAR(30)
         ,@c_LottableLabel09      NVARCHAR(30)
         ,@c_LottableLabel10      NVARCHAR(30)
         ,@c_LottableLabel11      NVARCHAR(30)
         ,@c_LottableLabel12      NVARCHAR(30)
         ,@c_LottableLabel13      NVARCHAR(30)
         ,@c_LottableLabel14      NVARCHAR(30)
         ,@c_LottableLabel15      NVARCHAR(30)
         ,@c_sp_name              NVARCHAR(50)
         ,@c_SQL                  NVARCHAR(2000)
         ,@c_SQLParm              NVARCHAR(2000)
         ,@n_ErrNo                INT 
   /*CS01 End*/
    
   DECLARE @c_UCCStatus                NVARCHAR(10) = '' --(Wan03)
         , @c_SerialNoCapture          NVARCHAR(1)  = ''                            --(Wan04) 
         , @c_SerialNoKey              NVARCHAR(10) = ''                            --(Wan04)   
         , @c_SerialNo                 NVARCHAR(50) = ''                            --(Wan04)
         , @c_SerialNo_Lot             NVARCHAR(10) = ''                            --(Wan04)
         , @c_SerialNo_ID              NVARCHAR(18) = ''                            --(Wan04)
         , @c_SerialNo_Status          NVARCHAR(10) = ''                            --(Wan04)
         , @n_SerialNo_Cnt             INT          = 0                             --(Wan04)
         , @n_SerialNo_Qty             INT          = 0                             --(Wan04)         
         , @n_SerialNo_AdjQty          INT          = 0                             --(Wan04) 
         , @n_SerialNo_AdjCnt          INT          = 0                             --(Wan05)                      

         , @c_ASNFizUpdLotToSerialNo   NVARCHAR(10) = ''                            --(Wan04)

   SELECT @n_continue = 1
   SELECT @b_debug = 0
    
   -- (james01)
   DECLARE @n_IsRDT INT  
   EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT  
    
   IF @n_continue=1
      OR @n_continue=2
   BEGIN
      --(Wan01) - START
      --IF NOT EXISTS (SELECT 1 FROM ADJUSTMENTDETAIL (NOLOCK) WHERE Adjustmentkey = @c_ADJKey AND FinalizedFlag = 'N')
            IF NOT EXISTS (
                     SELECT 1
                     FROM   ADJUSTMENTDETAIL(NOLOCK)
                     WHERE  Adjustmentkey = @c_ADJKey
                              AND FinalizedFlag IN ('N' ,'S' ,'A')
                  ) AND EXISTS (
                     SELECT 1 
                     FROM   ADJUSTMENT (NOLOCK)               -- ZG01
                     WHERE  AdjustmentKey = @c_ADJKey    
                              AND FinalizedFlag = 'Y'
                  )
                  --(Wan01) - END
            BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 72800
                  SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5) ,@n_err)+
                        ': No more Adjustment Details to finalize. (isp_FinalizeADJ)'
      END
   END
    
   --(Wan02) - START 
   IF @n_continue=1
      OR @n_continue=2
   BEGIN
      SET @c_Facility = ''
      SET @c_Storerkey = ''
        
      SELECT @c_Facility = Facility
            ,@c_Storerkey      = Storerkey
      FROM   ADJUSTMENT(NOLOCK)
      WHERE  Adjustmentkey     = @c_ADJKey      
        
      SET @b_Success = 0
      SET @c_AllowUCCAdjustment = ''
      EXEC nspGetRight 
            @c_Facility=@c_Facility
         ,@c_StorerKey=@c_StorerKey
         ,@c_sku=NULL
         ,@c_ConfigKey='AllowUCCAdjustment'
         ,@b_Success=@b_Success OUTPUT
         ,@c_authority=@c_AllowUCCAdjustment OUTPUT
         ,@n_err=@n_err OUTPUT
         ,@c_errmsg=@c_errmsg OUTPUT  
        
      IF @b_Success<>1
      BEGIN
         SET @n_continue = 3 
         SET @n_err = 72805
         SET @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_Err)+
               ': Error Get StorerConfig AllowUCCAdjustment. (isp_FinalizeADJ)'
            +'( '+RTRIM(@c_errmsg)+' )'
      END
   END
    
   IF @n_Continue=1
      OR @n_Continue=2
   BEGIN
      SET @b_Success = 0
      SET @c_PreFinalizeADJSP = ''
      EXEC nspGetRight 
            @c_Facility=@c_Facility
         ,@c_StorerKey=@c_StorerKey
         ,@c_sku=NULL
         ,@c_ConfigKey='PreFinalizeADJSP'
         ,@b_Success=@b_Success OUTPUT
         ,@c_authority=@c_PreFinalizeADJSP OUTPUT
         ,@n_err=@n_err OUTPUT
         ,@c_errmsg=@c_errmsg OUTPUT  
        
      IF @b_Success<>1
      BEGIN
         SET @n_continue = 3 
         SET @n_err = 72815
         SET @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_Err)+
               ': Error Get StorerConfig PreFinalizeADJSP. (isp_FinalizeADJ)'
            +'( '+RTRIM(@c_errmsg)+' )'
      END
   END

   IF @n_Continue=1
      OR @n_Continue=2
   BEGIN
      IF EXISTS (
            SELECT 1
            FROM   sys.objects o
            WHERE  NAME         = @c_PreFinalizeADJSP
                     AND TYPE     = 'P'
         )
      BEGIN
         SET @b_Success = 0  
         EXECUTE dbo.ispPreFinalizeADJWrapper 
                  @c_AdjustmentKey=@c_ADJKey,
               @c_PreFinalizeADJSP=@c_PreFinalizeADJSP,
               @b_Success=@b_Success OUTPUT,
               @n_Err=@n_err OUTPUT,
               @c_ErrMsg=@c_errmsg OUTPUT  
            
         IF @n_err<>0
         BEGIN
               SET @n_continue = 3 
               SET @n_err = 72820
               SET @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_Err)+
                  ': Execute isp_FinalizeADJ Failed. (isp_FinalizeADJ)'
                  +'( '+RTRIM(@c_errmsg)+' )'
         END
      END
   END
   --(Wan02) - End
    
   -- NJOW01 NJOW03  
   IF @n_Continue=1  
      OR @n_Continue=2  
   BEGIN  
      DECLARE @cADJValidationRules NVARCHAR(30)--,  
            --@c_SQL                NVARCHAR(2000)   --(CS02)  
            --@c_Storerkey          NVARCHAR(15)    --(Wan02)  
          
      --      SELECT @c_Storerkey = Storerkey               --(Wan02)  
      --      FROM ADJUSTMENT (NOLOCK)                      --(Wan02)  
      --      WHERE Adjustmentkey = @c_ADJKey               --(Wan02)  
          
      SELECT @cADJValidationRules = SC.sValue  
      FROM   STORERCONFIG SC(NOLOCK)  
            JOIN CODELKUP CL(NOLOCK)  
                  ON  SC.sValue = CL.Listname  
      WHERE  SC.StorerKey = @c_StorerKey  
            AND SC.Configkey = 'ADJExtendedValidation'  
          
      IF ISNULL(@cADJValidationRules ,'')<>''  
      BEGIN  
         EXEC isp_ADJ_ExtendedValidation @cAdjustmentKey=@c_ADJKey  
               ,@cADJValidationRules=@cADJValidationRules  
               ,@nSuccess=@b_Success OUTPUT  
               ,@cErrorMsg=@c_ErrMsg OUTPUT  
              
         IF @b_Success<>1  
         BEGIN  
               SELECT @n_Continue = 3  
               SELECT @n_err = 72810  
         END  
      END  
      ELSE  
      BEGIN  
         SELECT @cADJValidationRules = SC.sValue  
         FROM   STORERCONFIG SC(NOLOCK)  
         WHERE  SC.StorerKey = @c_StorerKey  
                  AND SC.Configkey = 'ADJExtendedValidation'      
              
         IF EXISTS (  
                  SELECT 1  
                  FROM   dbo.sysobjects  
                  WHERE  NAME         = RTRIM(@cADJValidationRules)  
                        AND TYPE     = 'P'  
            )  
         BEGIN  
               SET @c_SQL = 'EXEC '+@cADJValidationRules+  
                  ' @c_AdjustmentKey, @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT '  
                  
               EXEC sp_executesql @c_SQL  
                  ,  
                  N'@c_AdjustmentKey NVARCHAR(10), @b_Success Int OUTPUT, @n_Err Int OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT'  
                  ,@c_ADJKey  
                  ,@b_Success OUTPUT  
                  ,@n_Err OUTPUT  
                  ,@c_ErrMsg OUTPUT  
                  
               IF @b_Success<>1  
               BEGIN  
                  SELECT @n_Continue = 3      
                  SELECT @n_err = 72811  
               END  
         END  
      END  
   END --    IF @n_Continue = 1 OR @n_Continue = 2  
    
   --(CS01)  -Start
   IF EXISTS (
         SELECT 1
         FROM   dbo.StorerConfig WITH (NOLOCK)
         WHERE  StorerKey         = @c_StorerKey
               AND ConfigKey     = 'AdjFinalizeLottableRules'
               AND sValue        = '1'
      )
   BEGIN
      SET @n_LottableRules = 1
   END
   ELSE
   BEGIN
      SET @n_LottableRules = 0
   END
   --(CS01) - End

   IF @n_Continue IN (1,2)                                                          --(Wan04) - START
   BEGIN
      SELECT @c_ASNFizUpdLotToSerialNo = fsgr.Authority FROM dbo.fnc_SelectGetRight(@c_Facility, @c_Storerkey, '', 'ASNFizUpdLotToSerialNo')AS fsgr
   END                                                                              --(Wan04) - END
    
   -- GetLot IF empty Lot (Move from PB)
   IF @n_Continue=1
      OR @n_Continue=2
   BEGIN
      DECLARE CUR_AJD CURSOR LOCAL FAST_FORWARD READ_ONLY 
      FOR
         SELECT AdjustmentLineNumber
               ,Storerkey
               ,Sku
               ,Lot
               ,Loc
               ,ID
               ,UCCNo
               ,Qty
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
               ,SerialNo                                                            --(Wan04)
         FROM   ADJUSTMENTDETAIL WITH (NOLOCK)
         WHERE  Adjustmentkey = @c_ADJKey
                  AND FinalizedFlag IN ('N' ,'S' ,'A')
         ORDER BY AdjustmentLineNumber
        
      OPEN CUR_AJD
        
      FETCH NEXT FROM CUR_AJD INTO @c_adjline
                                 , @c_Storerkey
                                 , @c_Sku
                                 , @c_Lot
                                 , @c_Loc
                                 , @c_ID
                                 , @c_UCCNo
                                 , @n_Qty
                                 , @c_Lottable01 
                                 , @c_Lottable02 
                                 , @c_Lottable03 
                                 , @dt_Lottable04 
                                 , @dt_Lottable05 
                                 , @c_Lottable06 
                                 , @c_Lottable07 
                                 , @c_Lottable08 
                                 , @c_Lottable09 
                                 , @c_Lottable10 
                                 , @c_Lottable11 
                                 , @c_Lottable12 
                                 , @dt_Lottable13 
                                 , @dt_Lottable14 
                                 , @dt_Lottable15
                                 , @c_SerialNo                                      --(Wan04)
        
      WHILE @@FETCH_STATUS<>-1
            AND (@n_Continue=1 OR @n_Continue=2)
      BEGIN
         IF @c_Lot<>''
            AND @c_Lot IS NOT NULL
         BEGIN
            SET @c_Lottable01Label = ''
            SELECT @c_Lottable01Label = ISNULL(Lottable01Label ,'')
            FROM   SKU WITH (NOLOCK)
            WHERE  Storerkey     = @c_Storerkey
                  AND Sku       = @c_Sku
                
            SET @c_NewLot = ''
            IF @c_Lottable01Label='HMCE'
               AND @n_Qty>0
            BEGIN
               SELECT @c_Lottable01 = ''
                     ,@c_Lottable02     = Lottable02
                     ,@c_Lottable03     = Lottable03
                     ,@dt_Lottable04 = Lottable04
                     ,@dt_Lottable05 = Lottable05
                     ,@c_Lottable06     = Lottable06
                     ,@c_Lottable07     = Lottable07
                     ,@c_Lottable08     = Lottable08
                     ,@c_Lottable09     = Lottable09
                     ,@c_Lottable10     = Lottable10
                     ,@c_Lottable11     = Lottable11
                     ,@c_Lottable12     = Lottable12
                     ,@dt_Lottable13 = Lottable13
                     ,@dt_Lottable14 = Lottable14
                     ,@dt_Lottable15 = Lottable15
               FROM   LOTATTRIBUTE WITH (NOLOCK)
               WHERE  Lot               = @c_Lot
                    
               SET @c_Lot = ''
            END
         END
            
         IF @c_Lot=''
            OR @c_Lot IS NULL
         BEGIN
            EXECUTE nsp_lotlookup
            @c_Storerkey=@c_Storerkey,
                  @c_Sku=@c_Sku,
                  @c_Lottable01=@c_Lottable01,
                  @c_Lottable02=@c_Lottable02,
                  @c_Lottable03=@c_Lottable03,
                  @c_Lottable04=@dt_Lottable04,
                  @c_Lottable05=@dt_Lottable05,
                  @c_Lottable06=@c_Lottable06,
                  @c_Lottable07=@c_Lottable07,
                  @c_Lottable08=@c_Lottable08,
                  @c_Lottable09=@c_Lottable09,
                  @c_Lottable10=@c_Lottable10,
                  @c_Lottable11=@c_Lottable11,
                  @c_Lottable12=@c_Lottable12,
                  @c_Lottable13=@dt_Lottable13,
                  @c_Lottable14=@dt_Lottable14,
                  @c_Lottable15=@dt_Lottable15,
                  @c_lot=@c_lot OUTPUT,
                  @b_Success=@b_Success OUTPUT,
                  @n_err=@n_err OUTPUT,
                  @c_errmsg=@c_errmsg OUTPUT
                
            IF @b_Success<>1
            BEGIN
               SET @n_Continue = 3
               SET @n_err = 72825
               SET @c_errmsg = 'NSQL'++CONVERT(CHAR(5) ,@n_err)+
                  ': Execute nsp_lotlookup Failed.(isp_FinalizeADJ)'
                  +'( '+RTRIM(@c_errmsg)+' )'
            END
            ELSE --IN00366121 Start
            BEGIN
               SET @c_NewLot = @c_lot                             
            END   --IN00366121 End               
         END
            
         IF @n_Continue=1 OR @n_Continue=2
         BEGIN
            IF @c_Lot='' OR @c_Lot IS NULL
            BEGIN
               EXECUTE dbo.nsp_lotgen 
                        @c_Storerkey=@c_Storerkey,
                        @c_Sku=@c_Sku,
                        @c_Lottable01=@c_Lottable01,
                        @c_Lottable02=@c_Lottable02,
                        @c_Lottable03=@c_Lottable03,
                        @c_Lottable04=@dt_Lottable04,
                        @c_Lottable05=@dt_Lottable05,
                        @c_Lottable06=@c_Lottable06,
                        @c_Lottable07=@c_Lottable07,
                        @c_Lottable08=@c_Lottable08,
                        @c_Lottable09=@c_Lottable09,
                        @c_Lottable10=@c_Lottable10,
                        @c_Lottable11=@c_Lottable11,
                        @c_Lottable12=@c_Lottable12,
                        @c_Lottable13=@dt_Lottable13,
                        @c_Lottable14=@dt_Lottable14,
                        @c_Lottable15=@dt_Lottable15,
                        @c_lot=@c_lot OUTPUT,
                        @b_Success=@b_Success OUTPUT,
                        @n_err=@n_err OUTPUT,
                        @c_errmsg=@c_errmsg OUTPUT
                    
               IF @b_Success<>1
               BEGIN
                  SET @n_Continue = 3
                  SET @n_err = 72830
                  SET @c_errmsg = 'NSQL'++CONVERT(CHAR(5) ,@n_err)+
                        ': Execute nsp_lotgen Failed. (isp_FinalizeADJ)'
                     +'( '+RTRIM(@c_errmsg)+' )'
               END
               ELSE
               BEGIN
                  IF @c_Lot='' OR @c_Lot IS NULL
                  BEGIN
                     SET @n_Continue = 3
                     SET @n_err = 72835
                     SET @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
                        ': Error Generating Lot Failed. (isp_FinalizeADJ)'
                  END
                        
                  SET @c_NewLot = @c_lot
               END
            END
         END
            
         IF @n_Continue=1 OR @n_Continue=2
         BEGIN
            IF (@c_Lottable01Label='HMCE' AND @n_Qty>0) OR @c_NewLot<>''
            BEGIN
               UPDATE ADJUSTMENTDETAIL WITH (ROWLOCK)
               SET    Lot = @c_Lot
                     ,Lottable01 = @c_Lottable01
                     ,Lottable02 = @c_Lottable02
                     ,Lottable03 = @c_Lottable03
                     ,Lottable04 = @dt_Lottable04
                     ,Lottable05 = @dt_Lottable05
                     ,Lottable06 = @c_Lottable06
                     ,Lottable07 = @c_Lottable07
                     ,Lottable08 = @c_Lottable08
                     ,Lottable09 = @c_Lottable09
                     ,Lottable10 = @c_Lottable10
                     ,Lottable11 = @c_Lottable11
                     ,Lottable12 = @c_Lottable12
                     ,Lottable13 = @dt_Lottable13
                     ,Lottable14 = @dt_Lottable14
                     ,Lottable15 = @dt_Lottable15
                     ,Trafficcop = NULL
                     ,EditDate = GETDATE()
                     ,EditWho = SUSER_NAME()
               WHERE  Adjustmentkey = @c_AdjKey
                     AND AdjustmentLineNumber = @c_adjline
                    
               SET @n_Err = @@ERROR
                    
               IF @n_Err<>0
               BEGIN
                  SET @n_continue = 3
                  SET @n_Err = 72840
                  SET @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
                        ': UPDATE Adjustmentdetail Fail. (ntrReceiptHeaderUpdate)'
                     +' ( SQLSvr MESSAGE='+RTRIM(@c_errmsg)+' ) '
               END
            END
         END
         
         IF @n_Continue IN (1, 2)                                                   
         BEGIN 
            SET @c_SerialNoCapture = ''
            SELECT @c_SerialNoCapture = s.SerialNoCapture FROM SKU s (NOLOCK)
            WHERE s.StorerKey = @c_StorerKey
            AND   s.Sku = @c_Sku
            AND   s.SerialNoCapture IN ('1','2','3')

            IF @c_SerialNo <> '' AND @c_SerialNoCapture = ''
            BEGIN
               SET @n_Continue = 3
               SET @n_Err = 72880
               SET @c_errmsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) 
                              + ': SerialNo is NOT required.'
                              + '. Line #: ' + @c_adjline
                           + '. (isp_FinalizeADJ) |' + @c_SerialNo
            END    
         END

         IF @n_Continue IN (1, 2) AND @c_SerialNoCapture IN ('1','2','3')                                             
         BEGIN
            IF @c_SerialNo = '' AND @c_ASNFizUpdLotToSerialNo = '1' AND
               @c_SerialNoCapture IN ('1','2') 
            BEGIN
               SET @n_Continue = 3
               SET @n_Err = 72870
               SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) 
                             + ': SerialNo is required'
                             + '. Line #: ' + @c_adjline
                             + '. (isp_FinalizeADJ)'
            END

            IF @n_Continue IN (1, 2) AND @c_SerialNo <> ''               
            BEGIN
               IF @n_Qty NOT IN (-1,1)
               BEGIN
                  SET @n_Continue = 3
                  SET @n_Err = 72871
                  SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) 
                                 + ': SerialNo adjust qty is either -1 OR 1'
                                 + '. SerialNo: ' + @c_SerialNo + ', Line #: ' + @c_adjline
                                 + '. (isp_FinalizeADJ)'
               END

               IF @c_ID = '' AND @c_ASNFizUpdLotToSerialNo = '1'
               BEGIN
                  SET @n_Continue = 3
                  SET @n_Err = 72872
                  SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) 
                                + ': ID is Required for SerialNo Adjusment'
                                + '. SerialNo: ' + @c_SerialNo + ', Line #: ' + @c_adjline
                                + '. (isp_FinalizeADJ)'
               END

               IF @n_Continue IN (1, 2) 
               BEGIN
                  SET @n_SerialNo_AdjCnt = 0                                        --(Wan05)
                  SET @n_SerialNo_AdjQty = 0
                  SELECT @n_SerialNo_AdjCnt = COUNT(1)                              --(Wan05)
                        ,@n_SerialNo_AdjQty = SUM(ad.Qty)
                  FROM ADJUSTMENTDETAIL ad (NOLOCK)
                  WHERE ad.AdjustmentKey = @c_ADJKey
                  AND ad.SerialNo = @c_SerialNo
                  GROUP BY ad.SerialNo

                  IF @n_SerialNo_AdjCnt > 2 OR                                      --(Wan05)
                    (@n_SerialNo_AdjCnt = 2 AND @n_SerialNo_AdjQty <> 0)            --(Wan05)
                  BEGIN 
                     SET @n_Continue = 3
                     SET @n_Err = 72873
                     SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) 
                                   + ': Multiple SerialNo adjustment entry found'
                                   + '. System only allow 2 records of serial no with Sum(Qty) = 0 to adjust'
                                   + '. SerialNo: ' + @c_SerialNo + ', Line #: ' + @c_adjline
                                   + '. (isp_FinalizeADJ)'
                  END

                  IF @n_Continue IN (1, 2) AND @n_SerialNo_AdjCnt = 2               --(Wan05)
                  BEGIN
                     SET @n_SerialNo_AdjQty = 0
                     SELECT TOP 1 @n_SerialNo_AdjQty = ad.Qty
                     FROM ADJUSTMENTDETAIL ad (NOLOCK)
                     WHERE ad.AdjustmentKey = @c_ADJKey
                     AND ad.SerialNo = @c_SerialNo
                     ORDER BY ad.AdjustmentLineNumber DESC
                  
                     IF @n_SerialNo_AdjQty = -1
                     BEGIN
                        SET @n_Continue = 3
                        SET @n_Err = 72874
                        SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) 
                                      + ': Duplicate SerialNo found'
                                      + '. (+) qty record sequence entry should after (-) qty'
                                      + '. SerialNo: ' + @c_SerialNo + ', Line #: ' + @c_adjline
                                      + '. (isp_FinalizeADJ)'
                     END
                  END
               END
  
               IF @n_Continue IN (1, 2) AND @c_Lot <> '' 
               BEGIN
                  SET @n_SerialNo_Cnt    = 0
                  SET @c_SerialNo_Lot = ''
                  SET @c_SerialNo_ID  = ''
                  SET @c_SerialNo_Status = '0'

                  SELECT @n_SerialNo_Cnt = 1
                        ,@c_SerialNo_Lot = sn.Lot
                        ,@c_SerialNo_ID  = sn.ID
                        ,@c_SerialNo_Status = sn.[Status]
                        ,@n_SerialNo_Qty = sn.Qty
                  FROM SerialNo sn (NOLOCK) 
                  WHERE sn.SerialNo = @c_SerialNo
                  AND   sn.Storerkey= @c_Storerkey
                  AND   sn.Sku = @c_Sku

                  IF @n_SerialNo_Cnt = 1 
                  BEGIN
                     IF @n_SerialNo_Qty <> 1
                     BEGIN
                        SET @n_Continue = 3
                        SET @n_Err = 72875
                        SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) 
                                       + ': Invalid Serialno qty found in SerialNo Table for adjustment'
                                       + '. SerialNo: ' + @c_SerialNo + ', Line #: ' + @c_adjline
                                       + '. (isp_FinalizeADJ)' 
                     END

                     IF @n_Continue IN (1, 2)  
                     BEGIN
                        IF @c_ASNFizUpdLotToSerialNo = '1' AND
                           @c_SerialNo_Status = '1' AND @n_Qty = -1 AND
                          (@c_SerialNo_Lot <> @c_Lot OR @c_SerialNo_ID <> @c_ID)
                        BEGIN
                           SET @c_SerialNo_Status = '9'
                        END

                        IF @c_SerialNo_Status IN ('CANC', '9')
                        BEGIN
                           SET @n_SerialNo_AdjCnt = 0                               --(Wan05)
                        END
                     END 
                  END

                  IF @n_Continue IN (1, 2) AND 
                     @n_Qty = 1 AND @n_SerialNo_AdjCnt = 1 AND @c_SerialNo_Status IN ('1','5','6') --(Wan05)
                  BEGIN
                     SET @n_Continue = 3
                     SET @n_Err = 72877
                     SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) 
                                    + ': Deposit SerialNo with qty Found'
                                    + '. SerialNo: ' + @c_SerialNo + ', Line #: ' + @c_adjline
                                    + '. (isp_FinalizeADJ)' 
                  END

                  IF @n_Continue IN (1, 2) AND 
                    @n_Qty = -1 AND @c_SerialNo_Status IN ('0','9','CANC')
                  BEGIN
                     SET @n_Continue = 3
                     SET @n_Err = 72878
                     SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) 
                                    + ': Withdraw SerialNo: ' + @c_SerialNo + ', Lot: ' + @c_lot
                                    + ', id : ' + @c_ID + ' Not Found'
                                    + '. Line #: ' + @c_adjline
                                    + '. (isp_FinalizeADJ)' 
                  END

                  IF @n_Continue IN (1, 2) AND 
                     @n_Qty = -1 AND @n_SerialNo_AdjCnt = 1 AND @c_SerialNo_Status IN ('5','6')    --(Wan05)
                  BEGIN
                     SET @n_Continue = 3
                     SET @n_Err = 72879
                     SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) 
                                    + ': Disallow Withdraw Picked/Packed SerialNo: ' + @c_SerialNo 
                                    + '. Line #: ' + @c_adjline
                                    + '. (isp_FinalizeADJ)' 
                  END
               END
            END
         END                                                                        --(Wan04) - END    

         IF @n_Continue=1
            OR @n_Continue=2
         BEGIN
            IF @n_Qty<1
            BEGIN
               IF EXISTS (
                     SELECT 1
                     FROM   LOTxLOCxID WITH (NOLOCK)
                     WHERE  Lot        = @c_Lot
                              AND Loc = @c_Loc
                              AND ID     = @c_ID
                              AND (Qty- QtyAllocated- QtyPicked)+@n_Qty 
                                 <0
                  )
               BEGIN
                  SET @n_continue = 3
                  SET @n_err = 72845
                  SET @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err) 
                     +
                        ': Qty to reduce is more than qty available for sku ' 
                     +RTRIM(@c_Sku)+
                     +' . (isp_FinalizeADJ)'
               END
                                                      
               IF (@n_Continue=1 OR @n_Continue=2)
                  AND ISNULL(RTRIM(@c_UCCNo) ,'')<>''
                  AND NOT EXISTS(SELECT 1 
                                 FROM ADJUSTMENT (NOLOCK)
                                 JOIN StockTakeSheetParameters (NOLOCK) ON ADJUSTMENT.CustomerRefNo = StockTakeSheetParameters.StockTakeKey 
                                 WHERE ADJUSTMENT.Adjustmentkey = @c_ADJKey) --NJOW04  UCC qty already deduction during CC UCC adj, so can't validate the qty                   
               BEGIN
                  IF EXISTS (
                           SELECT 1
                           FROM   UCC WITH (NOLOCK)
                           WHERE  Storerkey = @c_Storerkey
                                 AND Sku = @c_Sku
                                 AND UCCNo = @c_UCCNo
                                 AND Qty+@n_Qty<0
                                 AND STATUS = '1'
                     )
                  BEGIN
                     SET @n_continue = 3
                     SET @n_err = 72850
                     SET @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err) 
                        +
                        ': Qty to reduce is more than qty available for UCC ' 
                        +RTRIM(@c_UCCNo)+
                        +' . (isp_FinalizeADJ)'
                  END
               END
            END
         END
            
         IF (@n_Continue=1 OR @n_Continue=2)
         BEGIN
            IF @c_AllowUCCAdjustment='1'
               AND ISNULL(RTRIM(@c_UCCNo) ,'')=''
            BEGIN
               IF EXISTS (
                     SELECT 1
                     FROM   UCC WITH (NOLOCK)
                     WHERE  Lot        = @c_Lot
                              AND Loc = @c_Loc
                              AND ID     = @c_ID
                              AND EXISTS (
                                    SELECT 1
                                    FROM   LOC WITH (NOLOCK)
                                    WHERE  LOC.Loc = UCC.Loc
                                             AND LoseUCC<>'1'
                                 )
                  )
               BEGIN
                  SET @n_continue = 3
                  SET @n_err = 72855
                  SET @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err) 
                     +': Non UCC adjustment is not allow at line '+
                        RTRIM(@c_adjline)+
                     +' . (isp_FinalizeADJ)'
               END
            END
         END
            
         --Satyam - START
         IF (@n_continue=1 OR @n_continue=2)
         BEGIN
            IF @c_ASNFizUpdLotToSerialNo = '1' AND @c_SerialNoCapture IN ('1', '2')
                  BEGIN
                     IF EXISTS (SELECT 1
                              FROM AdjustmentDetail (NOLOCK)
                              WHERE 1 = 1
                                 AND AdjustmentKey = @c_ADJKey
                                 AND AdjustmentLineNumber = @c_adjline
                                 AND FinalizedFlag IN ('N', 'S', 'A')
                              GROUP BY ID
                              HAVING COUNT(DISTINCT Loc) > 1)
                           BEGIN
                              SELECT @n_continue = 3
                              SELECT @c_ErrMsg = 'Duplicate LOCs found in same ID' +
                                                ': Finalize Adjustment Fail. (''isp_FinalizeADJ'')' + ' ( ' + ' SQLSvr MESSAGE=' +
                                                RTRIM(@c_ErrMsg) + ' ) '
                           END
                     IF EXISTS (SELECT 1
                              FROM AdjustmentDetail AD (NOLOCK)
                              JOIN LotxLocxId LLI (NOLOCK) ON AD.ID = LLI.Id AND AD.StorerKey = LLI.StorerKey
                              WHERE AD.ID <> ''
                                 AND LLI.QTY - LLI.QtyPicked > 0
                                 AND AD.Loc <> LLI.Loc
                                 AND AD.AdjustmentKey = @c_ADJKey
                                 AND AdjustmentLineNumber = @c_adjline)
                           BEGIN
                              SELECT @n_continue = 3
                              SELECT @c_ErrMsg = 'Duplicate IDs found in different locations' +
                                                ': Finalize Adjustment Fail. (''isp_FinalizeADJ'')' + ' ( ' + ' SQLSvr MESSAGE=' +
                                                RTRIM(@c_ErrMsg) + ' ) '
                           END
                  END
         END
         --Satyam - END
         --(CS01) -START
         IF @n_LottableRules=1
         BEGIN
            --@nLottableRules = 1 
            BEGIN TRAN 
            SELECT @c_Lottable01Value = Lottable01
                  ,@c_Lottable02Value = Lottable02
                  ,@c_Lottable03Value = Lottable03
                  ,@dt_Lottable04Value = Lottable04
                  ,@dt_Lottable05Value = Lottable05
                  ,@c_Lottable06Value = Lottable06
                  ,@c_Lottable07Value = Lottable07
                  ,@c_Lottable08Value = Lottable08
                  ,@c_Lottable09Value = Lottable09
                  ,@c_Lottable10Value = Lottable10
                  ,@c_Lottable11Value = Lottable11
                  ,@c_Lottable12Value = Lottable12
                  ,@dt_Lottable13Value = Lottable13
                  ,@dt_Lottable14Value = Lottable14
                  ,@dt_Lottable15Value = Lottable15
            FROM   dbo.AdjustmentDetail WITH (NOLOCK)
            WHERE  Adjustmentkey = @c_ADJKey
                  AND AdjustmentLineNumber = @c_adjline
                
            SELECT @c_Lottable01 = @c_Lottable01Value
                  ,@c_Lottable02      = @c_Lottable02Value
                  ,@c_Lottable03      = @c_Lottable03Value
                  ,@dt_Lottable04     = @dt_Lottable04Value
                  ,@dt_Lottable05     = @dt_Lottable05Value
                  ,@c_Lottable06      = @c_Lottable06Value
                  ,@c_Lottable07      = @c_Lottable07Value
                  ,@c_Lottable08      = @c_Lottable08Value
                  ,@c_Lottable09      = @c_Lottable09Value
                  ,@c_Lottable10      = @c_Lottable10Value
                  ,@c_Lottable11      = @c_Lottable11Value
                  ,@c_Lottable12      = @c_Lottable12Value
                  ,@dt_Lottable13     = @dt_Lottable13Value
                  ,@dt_Lottable14     = @dt_Lottable14Value
                  ,@dt_Lottable15     = @dt_Lottable15Value  
                
            SELECT @c_LottableLabel01 = Lottable01Label
                  ,@c_LottableLabel02 = Lottable02Label
                  ,@c_LottableLabel03 = Lottable03Label
                  ,@c_LottableLabel04 = Lottable04Label
                  ,@c_LottableLabel05 = Lottable05Label
                  ,@c_LottableLabel06 = Lottable06Label
                  ,@c_LottableLabel07 = Lottable07Label
                  ,@c_LottableLabel08 = Lottable08Label
                  ,@c_LottableLabel09 = Lottable09Label
                  ,@c_LottableLabel10 = Lottable10Label
                  ,@c_LottableLabel11 = Lottable11Label
                  ,@c_LottableLabel12 = Lottable12Label
                  ,@c_LottableLabel13 = Lottable13Label
                  ,@c_LottableLabel14 = Lottable14Label
                  ,@c_LottableLabel15 = Lottable15Label
            FROM   dbo.SKU WITH (NOLOCK)
            WHERE  StorerKey     = @c_StorerKey
                  AND SKU       = @c_Sku  
                
            SELECT @n_count = 1
                  ,@c_Sourcetype = 'ADJFINALIZE'  
                
            WHILE @n_count<=15
                  AND @n_continue IN (1 ,2) --TK01 increase max @n_count to 15
            BEGIN
               --While
               SET @c_Sourcekey = RTRIM(@c_ADJKey) --+ RTRIM(@c_ReceiptLineNo) --NJOW07  
                    
               SELECT @c_ListName = 'LOTTABLE0'+CAST(@n_count AS NVARCHAR(2)) --(CS02)  
                    
               SELECT @c_LottableLabel = CASE 
                                             WHEN @n_count=1 THEN @c_LottableLabel01
                                             WHEN @n_count=2 THEN @c_LottableLabel02
                                             WHEN @n_count=3 THEN @c_LottableLabel03
                                             WHEN @n_count=4 THEN @c_LottableLabel04
                                             WHEN @n_count=5 THEN @c_LottableLabel05
                                             WHEN @n_count=6 THEN @c_LottableLabel06
                                             WHEN @n_count=7 THEN @c_LottableLabel07
                                             WHEN @n_count=8 THEN @c_LottableLabel08
                                             WHEN @n_count=9 THEN @c_LottableLabel09
                                             WHEN @n_count=10 THEN @c_LottableLabel10
                                             WHEN @n_count=11 THEN @c_LottableLabel11
                                             WHEN @n_count=12 THEN @c_LottableLabel12
                                             WHEN @n_count=13 THEN @c_LottableLabel13
                                             WHEN @n_count=14 THEN @c_LottableLabel14
                                             WHEN @n_count=15 THEN @c_LottableLabel15
                                             ELSE ''
                                          END  
                    
               SELECT @c_sp_name = LONG
                     ,@c_UDF01     = UDF01
               FROM   CODELKUP(NOLOCK)
               WHERE  LISTNAME     = @c_ListName
                     AND CODE     = @c_Lottablelabel
                     AND (Storerkey=@c_StorerKey OR ISNULL(Storerkey ,'')='')
               ORDER BY
                     Storerkey DESC 
                    
               IF ISNULL(@c_sp_name ,'')<>''
               BEGIN
                  --ISNULL(@c_sp_name,'') <> ''
                  --NJOW07  
                  IF ISNULL(@c_UDF01 ,'')<>''
                  BEGIN
                     --ISNULL(@c_UDF01,'') <> '' 
                     IF EXISTS (
                           SELECT 1
                           FROM   INFORMATION_SCHEMA.COLUMNS
                           WHERE  TABLE_NAME = 'ADJUSTMENT'
                                 AND COLUMN_NAME = @c_UDF01
                        )
                     BEGIN
                        SET @c_Value = ''  
                        SET @c_SQL = 'SELECT @c_Value = '+RTRIM(@c_UDF01) 
                           +
                           ' FROM ADJUSTMENT (NOLOCK) WHERE Adjustment = @c_ADJKey'
                                
                        SET @c_SQLParm = 
                           '@c_Value NVARCHAR(60) OUTPUT, @c_ADJKey NVARCHAR(10)'  
                                
                        EXEC sp_executesql @c_SQL
                           ,@c_SQLParm
                           ,@c_Value OUTPUT
                           ,@c_ADJKey  
                                
                        IF ISNULL(@c_Value ,'')<>''
                           SET @c_Sourcekey = @c_Value
                     END
                  END --ISNULL(@c_UDF01,'') <> '' 
                        
                  IF NOT EXISTS (
                           SELECT 1
                           FROM   dbo.sysobjects
                           WHERE  NAME = RTRIM(@c_sp_name)
                                 AND TYPE = 'P'
                     )
                  BEGIN
                     SELECT @n_continue = 3  
                     SELECT @c_ErrMsg = CONVERT(CHAR(250) ,@n_err)
                           ,@n_err = 62090
                            
                     SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)
                           +': Lottable Rule Listname '+RTRIM(@c_listname)
                           +' - Stored Proc name invalid ('+RTRIM(ISNULL(@c_sp_name ,''))
                           +') (ispFinalizeADJ)'
                            
                     ROLLBACK TRAN
                  END  
                        
                  SET @c_SQL = 'EXEC '+@c_sp_name+
                              +' @c_StorerKey, @c_Sku, ' 
                              +' @c_Lottable01Value, @c_Lottable02Value, @c_Lottable03Value, @dt_Lottable04Value, @dt_Lottable05Value,' 
                              +' @c_Lottable06Value, @c_Lottable07Value, @c_Lottable08Value, @c_Lottable09Value, @c_Lottable10Value,' 
                              +' @c_Lottable11Value, @c_Lottable12Value, @dt_Lottable13Value, @dt_Lottable14Value, @dt_Lottable15Value,' 
                              +' @c_Lottable01 OUTPUT, @c_Lottable02 OUTPUT , @c_Lottable03 OUTPUT, @dt_Lottable04 OUTPUT, @dt_Lottable05 OUTPUT,' 
                              +' @c_Lottable06 OUTPUT, @c_Lottable07 OUTPUT , @c_Lottable08 OUTPUT, @c_Lottable09 OUTPUT, @c_Lottable10 OUTPUT,' 
                              +' @c_Lottable11 OUTPUT, @c_Lottable12 OUTPUT , @dt_Lottable13 OUTPUT, @dt_Lottable14 OUTPUT, @dt_Lottable15 OUTPUT,' 
                              +' @b_Success OUTPUT, @n_ErrNo OUTPUT, @c_ErrMsg OUTPUT, @c_Sourcekey, @c_SourceType, @c_LottableLabel'  
                        
                  SET @c_SQLParm =' @c_StorerKey NVARCHAR(15), @c_Sku NVARCHAR(20), ' 
                     +'@c_Lottable01Value NVARCHAR(18),    @c_Lottable02Value NVARCHAR(18),    @c_Lottable03Value NVARCHAR(18),    @dt_Lottable04Value DATETIME,        @dt_Lottable05Value DATETIME,' 
                     +'@c_Lottable06Value NVARCHAR(30),    @c_Lottable07Value NVARCHAR(30),    @c_Lottable08Value NVARCHAR(30),    @c_Lottable09Value NVARCHAR(30),    @c_Lottable10Value NVARCHAR(30),' 
                     +'@c_Lottable11Value NVARCHAR(30),    @c_Lottable12Value NVARCHAR(30),    @dt_Lottable13Value DATETIME,        @dt_Lottable14Value DATETIME,        @dt_Lottable15Value DATETIME,' 
                     +'@c_Lottable01 NVARCHAR(18) OUTPUT,  @c_Lottable02 NVARCHAR(18) OUTPUT,  @c_Lottable03 NVARCHAR(18) OUTPUT,  @dt_Lottable04 DATETIME OUTPUT,     @dt_Lottable05 DATETIME OUTPUT,' 
                     +'@c_Lottable06 NVARCHAR(30) OUTPUT,  @c_Lottable07 NVARCHAR(30) OUTPUT,  @c_Lottable08 NVARCHAR(30) OUTPUT,  @c_Lottable09 NVARCHAR(30) OUTPUT,  @c_Lottable10 NVARCHAR(30) OUTPUT,' 
                     +'@c_Lottable11 NVARCHAR(30) OUTPUT,  @c_Lottable12 NVARCHAR(30) OUTPUT,  @dt_Lottable13 DATETIME OUTPUT,      @dt_Lottable14 DATETIME OUTPUT,      @dt_Lottable15 DATETIME OUTPUT,' 
                     +'@b_Success INT OUTPUT, @n_ErrNo INT OUTPUT,' 
                     +'@c_ErrMsg NVARCHAR(250) OUTPUT, @c_Sourcekey NVARCHAR(15), @c_SourceType NVARCHAR(20), @c_LottableLabel NVARCHAR(20)'  
                        
                  EXEC sp_EXECUTEsql @c_SQL
                        ,@c_SQLParm
                        ,@c_StorerKey
                        ,@c_Sku
                        ,@c_Lottable01Value
                        ,@c_Lottable02Value
                        ,@c_Lottable03Value
                        ,@dt_Lottable04Value
                        ,@dt_Lottable05Value
                        ,@c_Lottable06Value
                        ,@c_Lottable07Value
                        ,@c_Lottable08Value
                        ,@c_Lottable09Value
                        ,@c_Lottable10Value
                        ,@c_Lottable11Value
                        ,@c_Lottable12Value
                        ,@dt_Lottable13Value
                        ,@dt_Lottable14Value
                        ,@dt_Lottable15Value
                        ,@c_Lottable01 OUTPUT
                        ,@c_Lottable02 OUTPUT
                        ,@c_Lottable03 OUTPUT
                        ,@dt_Lottable04 OUTPUT
                        ,@dt_Lottable05 OUTPUT
                        ,@c_Lottable06 OUTPUT
                        ,@c_Lottable07 OUTPUT
                        ,@c_Lottable08 OUTPUT
                        ,@c_Lottable09 OUTPUT
                        ,@c_Lottable10 OUTPUT
                        ,@c_Lottable11 OUTPUT
                        ,@c_Lottable12 OUTPUT
                        ,@dt_Lottable13 OUTPUT
                        ,@dt_Lottable14 OUTPUT
                        ,@dt_Lottable15 OUTPUT
                        ,@b_Success OUTPUT
                        ,@n_ErrNo OUTPUT
                        ,@c_Errmsg OUTPUT
                        ,@c_Sourcekey
                        ,@c_SourceType
                        ,@c_LottableLabel  
                        
                  IF @n_ErrNo<>0
                  BEGIN
                     SELECT @n_continue = 3  
                     SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5) ,@n_ErrNo)
                           +
                           ': Finalize Transfer Fail. (''ispFinalizeTransfer'')' 
                           +' ( '+' SQLSvr MESSAGE='+RTRIM(@c_ErrMsg) 
                           +' ) '
                            
                     ROLLBACK TRAN
                  END 

                  IF @n_continue IN (1 ,2)                                          --(Wan04)        
                  BEGIN
                     UPDATE ADJUSTMENTDETAIL WITH (ROWLOCK)
                     SET    Lottable01 = CASE 
                                                WHEN ISNULL(@c_Lottable01 ,'') 
                                                   ='' THEN Lottable01
                                                ELSE @c_Lottable01
                                          END
                           ,Lottable02 = CASE 
                                                WHEN ISNULL(@c_Lottable02 ,'') 
                                                   ='' THEN Lottable02
                                                ELSE @c_Lottable02
                                          END
                           ,Lottable03 = CASE 
                                                WHEN ISNULL(@c_Lottable03 ,'') 
                                                   ='' THEN Lottable03
                                                ELSE @c_Lottable03
                                          END
                           ,Lottable04 = CASE 
                                                WHEN ISNULL(@dt_Lottable04 ,'') 
                                                   ='' THEN Lottable04
                                                ELSE @dt_Lottable04
                                          END
                           ,Lottable05 = CASE 
                                                WHEN ISNULL(@dt_Lottable05 ,'') 
                                                   ='' THEN Lottable05
                                                ELSE @dt_Lottable05
                                          END
                           ,Lottable06 = CASE 
                                                WHEN ISNULL(@c_Lottable06 ,'') 
                                                   ='' THEN Lottable06
                                                ELSE @c_Lottable06
                                          END
                           ,Lottable07 = CASE 
                                                WHEN ISNULL(@c_Lottable07 ,'') 
                                                   ='' THEN Lottable07
                                                ELSE @c_Lottable07
                                          END
                           ,Lottable08 = CASE 
                                                WHEN ISNULL(@c_Lottable08 ,'') 
                                                   ='' THEN Lottable08
                                                ELSE @c_Lottable08
                                          END
                           ,Lottable09 = CASE 
                                                WHEN ISNULL(@c_Lottable09 ,'') 
                                                   ='' THEN Lottable09
                                                ELSE @c_Lottable09
                                          END
                           ,Lottable10 = CASE 
                                                WHEN ISNULL(@c_Lottable10 ,'') 
                                                   ='' THEN Lottable10
                                                ELSE @c_Lottable10
                                          END
                           ,Lottable11 = CASE 
                                                WHEN ISNULL(@c_Lottable11 ,'') 
                                                   ='' THEN Lottable11
                                                ELSE @c_Lottable11
                                          END
                           ,Lottable12 = CASE 
                                                WHEN ISNULL(@c_Lottable12 ,'') 
                                                   ='' THEN Lottable12
                                                ELSE @c_Lottable12
                                          END
                           ,Lottable13 = CASE 
                                                WHEN ISNULL(@dt_Lottable13 ,'') 
                                                   ='' THEN Lottable13
                                                ELSE @dt_Lottable13
                                          END
                           ,Lottable14 = CASE 
                                                WHEN ISNULL(@dt_Lottable14 ,'') 
                                                   ='' THEN Lottable14
                                                ELSE @dt_Lottable14
                                          END
                           ,Lottable15 = CASE 
                                                WHEN ISNULL(@dt_Lottable15 ,'') 
                                                   ='' THEN Lottable15
                                                ELSE @dt_Lottable15
                                          END
                           ,EditDate = GETDATE()
                           ,EditWho = SUSER_SNAME()
                           ,TrafficCop = NULL
                     WHERE  Adjustmentkey = @c_ADJKey
                     AND AdjustmentLineNumber = @c_adjline
                        
                     --SELECT * FROM adjustmentdetail (NOLOCK)
                     --WHERE  Adjustmentkey = @c_ADJKey
                     --  AND    AdjustmentLineNumber = @c_adjline
                        
                     SELECT @n_err = @@ERROR  
                     IF @n_err<>0
                     BEGIN
                        SELECT @n_continue = 3  
                        SELECT @c_ErrMsg = CONVERT(CHAR(250) ,@n_err)
                              ,@n_err = 62100
                            
                        SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)
                              +': Finalize Adj Fail. (''ispFinalizeADJ'')' 
                              +' ( '+' SQLSvr MESSAGE='+RTRIM(@c_ErrMsg) 
                              +' ) '
                            
                        ROLLBACK TRAN
                     END
                  END
               END  

               WHILE @n_continue IN (1,2) AND @@TRANCOUNT > 0                       --(Wan04)  
               BEGIN
                  COMMIT TRAN
               END

               SET @n_count = @n_count+1
            END --While
         END
         --(CS01) -End
         FETCH NEXT FROM CUR_AJD INTO @c_adjline
                                    , @c_Storerkey
                                    , @c_Sku
                                    , @c_Lot
                                    , @c_Loc
                                    , @c_ID
                                    , @c_UCCNo
                                    , @n_Qty
                                    , @c_Lottable01 
                                    , @c_Lottable02 
                                    , @c_Lottable03 
                                    , @dt_Lottable04 
                                    , @dt_Lottable05 
                                    , @c_Lottable06 
                                    , @c_Lottable07 
                                    , @c_Lottable08 
                                    , @c_Lottable09 
                                    , @c_Lottable10 
                                    , @c_Lottable11 
                                    , @c_Lottable12 
                                    , @dt_Lottable13 
                                    , @dt_Lottable14 
                                    , @dt_Lottable15
                                    , @c_SerialNo                                   --(Wan04)
      END
      CLOSE CUR_AJD
      DEALLOCATE CUR_AJD
   END
   --(Wan02) - End
IF (@n_continue=1 OR @n_continue=2)
   BEGIN
      -- 01
      DECLARE adj_cur CURSOR LOCAL FAST_FORWARD READ_ONLY 
      FOR
         SELECT AdjustmentLineNumber
               ,Sku                                            --(Wan03)
               ,Lot                                            --(Wan03)
               ,Loc                                            --(Wan03)
               ,ID                                             --(Wan03)
               ,UCCNo                                          --(Wan03)
         FROM   AdjustmentDetail(NOLOCK)
         WHERE  Adjustmentkey = @c_ADJKey
                  --(Wan01) - START
                  --AND    FinalizedFlag = 'N'
                  AND FinalizedFlag IN ('N' ,'S' ,'A')
                     --(Wan01) - END
         ORDER BY
                  AdjustmentLineNumber
        
      OPEN adj_cur 
        
      FETCH NEXT FROM adj_cur INTO @c_adjline, @c_Sku, @c_Lot, @c_Loc, @c_ID, @c_UCCNo --(Wan03)
        
      WHILE @@FETCH_STATUS<>-1
      BEGIN
         BEGIN TRAN

         --(Wan03) - START
         IF @c_UCCNo <> ''
         BEGIN
            SET @c_UCCStatus = ''
            SELECT TOP 1 @c_UCCStatus = UCC.[Status]
            FROM UCC WITH (NOLOCK)
            WHERE UCC.Storerkey = @c_Storerkey
            AND   UCC.UCCNo = @c_UCCNo
            AND   UCC.Sku = @c_Sku
            AND   UCC.Lot = @c_Lot
            AND   UCC.Loc = @c_Loc
            AND   UCC.ID  = @c_ID
         END
         --(Wan03) - END

         UPDATE AdjustmentDetail WITH (ROWLOCK)
         SET    FinalizedFlag = 'Y'
         WHERE  AdjustmentKey = @c_ADJKey
                  AND AdjustmentLineNumber = @c_adjline
                  AND FinalizedFlag<>'Y'
            
         SELECT @n_err = @@ERROR
         IF @n_err<>0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(NVARCHAR(250) ,@n_err)
                  ,@n_err = 72806 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5) ,@n_err)+
                  ': Update Failed On Table AdjustmentDetail. (isp_FinalizeADJ)' 
                  +' ( '+' SQLSvr MESSAGE='+dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) 
                  +' ) '
                
            ROLLBACK TRAN
            BREAK
         END
         ELSE
         BEGIN
            WHILE @@TRANCOUNT>0
               COMMIT TRAN
         END
            
         -- (james02)
         UPDATE UCC WITH (ROWLOCK)
         SET    STATUS = '6'
         FROM   AdjustmentDetail AD (NOLOCK)
                  JOIN UCC UCC
                     ON  (AD.UCCNo=UCC.UCCNo AND AD.StorerKey=UCC.StorerKey)
         WHERE  AD.AdjustmentKey = @c_ADJKey
                  AND AD.AdjustmentLineNumber = @c_adjline
                  AND AD.FinalizedFlag = 'Y'
                  AND UCC.Status<>'6'
                  AND UCC.Qty<= 0
            
         SELECT @n_err = @@ERROR
         IF @n_err<>0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(NVARCHAR(250) ,@n_err)
                  ,@n_err = 72809 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5) ,@n_err)+
                  ': Update Failed On Table AdjustmentDetail. (isp_FinalizeADJ)'
                  +' ( '+' SQLSvr MESSAGE='+dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) 
                  +' ) '
                
            ROLLBACK TRAN
            BREAK
         END
         ELSE
         BEGIN
            WHILE @@TRANCOUNT>0
               COMMIT TRAN
         END

         --(Wan03) - START
         IF @c_UCCNo <> ''
         BEGIN
            SET @c_Sourcekey = RTRIM(@c_ADJKey) + RTRIM(@c_adjline)

            EXEC isp_ItrnUCCAdd
                     @c_Storerkey       = @c_StorerKey 
                  , @c_UCCNo           = @c_UCCNo     
                  , @c_Sku             = @c_Sku  
                  , @c_UCCStatus       = @c_UCCStatus            
                  , @c_SourceKey       = @c_Sourcekey         
                  , @c_ItrnSourceType  = 'ntrAdjustmentDetailUpdate' 
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
               SET @n_err = 72812 
               SET @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': Add ITRN UCC Fail. (isp_FinalizeADJ)' 
                              + ' ( ' + ' SQLSvr MESSAGE=' + RTrim(@c_ErrMsg) + ' ) '  
               ROLLBACK TRAN
               BREAK
            END
            ELSE
            BEGIN
               WHILE @@TRANCOUNT>0
                  COMMIT TRAN
            END
         END    
         --(Wan03) - END
            
         --***SOS#148847 Start
         UPDATE Adjustment WITH (ROWLOCK)
         SET    EditDate = GETDATE()
               ,EditWho = SUSER_SNAME()
               ,TrafficCop = NULL
         WHERE  AdjustmentKey = @c_ADJKey
            
         SELECT @n_err = @@ERROR
         IF @n_err<>0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(NVARCHAR(250) ,@n_err)
                  ,@n_err = 72807 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5) ,@n_err)+
                  ': Update Failed On Table Adjustment. (isp_FinalizeADJ)' 
                  +' ( '+' SQLSvr MESSAGE='+dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) 
                  +' ) '
                
            ROLLBACK TRAN
            BREAK
         END
         ELSE
         BEGIN
            WHILE @@TRANCOUNT>0
                  COMMIT TRAN
         END
         --***SOS#148847 End
            
         FETCH NEXT FROM adj_cur INTO @c_adjline, @c_Sku, @c_Lot, @c_Loc, @c_ID, @c_UCCNo --(Wan03)
      END 
      CLOSE adj_cur
      DEALLOCATE adj_cur
   END -- Continue
    
   --SOS257258 (james01)
   -- only if finalize thru rdt then need finalize both header & detail
   -- reason is finalize from exceed is calling this script too and trigger will fail if header is finalized from here
   IF (@n_continue=1 OR @n_continue=2)
      --AND @n_IsRDT=1                   -- ZG01
   BEGIN
      IF NOT EXISTS (
            SELECT 1
            FROM   dbo.AdjustmentDetail WITH (NOLOCK)
            WHERE  AdjustmentKey = @c_ADJKey
                     AND FinalizedFlag IN ('N' ,'S' ,'A')
         )
      BEGIN
         BEGIN TRAN
         UPDATE Adjustment WITH (ROWLOCK)
         SET    FinalizedFlag = 'Y'
         WHERE  AdjustmentKey = @c_ADJKey
                  AND FinalizedFlag<>'Y'
            
         SELECT @n_err = @@ERROR
         IF @n_err<>0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(NVARCHAR(250) ,@n_err)
                  ,@n_err = 72808 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5) ,@n_err)+
                  ': Update Failed On Table Adjustment. (isp_FinalizeADJ)' 
                  +' ( '+' SQLSvr MESSAGE='+dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) 
                  +' ) '
                
            ROLLBACK TRAN
         END
         ELSE
         BEGIN
            WHILE @@TRANCOUNT>0
                  COMMIT TRAN
         END
      END
   END
    
   --NJOW02 Start
   IF @n_Continue=1
      OR @n_Continue=2
   BEGIN
      SET @b_Success = 0
      SET @c_PostFinalizeADJSP = ''
      EXEC nspGetRight 
            @c_Facility=@c_Facility
         ,@c_StorerKey=@c_StorerKey
         ,@c_sku=NULL
         ,@c_ConfigKey='PostFinalizeADJSP'
         ,@b_Success=@b_Success OUTPUT
         ,@c_authority=@c_PostFinalizeADJSP OUTPUT
         ,@n_err=@n_err OUTPUT
         ,@c_errmsg=@c_errmsg OUTPUT  
        
      IF @b_Success<>1
      BEGIN
         SET @n_continue = 3 
         SET @n_err = 72855
         SET @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_Err)+
               ': Error Get StorerConfig PostFinalizeADJSP. (isp_FinalizeADJ)'
            +'( '+RTRIM(@c_errmsg)+' )'
      END
   END
    
   IF @n_Continue=1
      OR @n_Continue=2
   BEGIN
      IF EXISTS (
            SELECT 1
            FROM   sys.objects o
            WHERE  NAME         = @c_PostFinalizeADJSP
                     AND TYPE     = 'P'
         )
      BEGIN
         SET @b_Success = 0  
         EXECUTE dbo.ispPostFinalizeADJWrapper 
                  @c_AdjustmentKey=@c_ADJKey,
               @c_PostFinalizeADJSP=@c_PostFinalizeADJSP,
               @b_Success=@b_Success OUTPUT,
               @n_Err=@n_err OUTPUT,
               @c_ErrMsg=@c_errmsg OUTPUT  
            
         IF @n_err<>0
         BEGIN
               SET @n_continue = 3 
               SET @n_err = 72860
               SET @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_Err)+
                  ': Execute isp_FinalizeADJ Failed. (isp_FinalizeADJ)'
                  +'( '+RTRIM(@c_errmsg)+' )'
         END
      END
   END
   --NJOW02 End
    
   /* #INCLUDE <SPTPA01_2.SQL> */
   IF @n_continue=3 -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
      EXECUTE nsp_logerror @n_err,
            @c_errmsg,
            'isp_FinalizeADJ'
        
      RAISERROR (@c_errmsg ,16 ,1) 
      WITH SETERROR -- SQL2012
      RETURN
   END
END -- main

GO