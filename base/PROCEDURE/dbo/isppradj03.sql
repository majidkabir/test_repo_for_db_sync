SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: ispPRADJ03                                              */
/* Creation Date: 09-Jun-2021                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-17117 - MY ADIDAS WMS Automatically select Adjustment   */
/*        : Type and Split                                              */
/*                                                                      */
/* Called By: ispPreFinalizeADJWrapper                                  */
/*          :                                                           */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[ispPRADJ03] 
            @c_AdjustmentKey  NVARCHAR(10)
         ,  @b_Success        INT = 1  OUTPUT 
         ,  @n_err            INT = 0  OUTPUT 
         ,  @c_errmsg         NVARCHAR(215) = '' OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE                      
           @n_StartTCnt         INT
         , @n_Continue          INT 
         , @c_AdjLineNumber     NVARCHAR(5)
         , @c_Storerkey         NVARCHAR(15)
         , @c_Sku               NVARCHAR(20)
         , @c_Facility          NVARCHAR(10)
         , @c_Remarks           NVARCHAR(200)
         , @c_FromToWhse        NVARCHAR(6)
         , @c_UserDefine02      NVARCHAR(20)

         , @n_AdjQty            INT
         , @c_Lot               NVARCHAR(10)
         , @c_Lottable01        NVARCHAR(18)    
         , @c_Lottable02        NVARCHAR(18)   
         , @c_Lottable03        NVARCHAR(18)    
         , @dt_Lottable04       DATETIME       
         , @dt_Lottable05       DATETIME       
         , @c_Lottable06        NVARCHAR(30)   
         , @c_Lottable07        NVARCHAR(30)    
         , @c_Lottable08        NVARCHAR(30)    
         , @c_Lottable09        NVARCHAR(30)   
         , @c_Lottable10        NVARCHAR(30)   
         , @c_Lottable11        NVARCHAR(30)   
         , @c_Lottable12        NVARCHAR(30)    
         , @dt_Lottable13       DATETIME       
         , @dt_Lottable14       DATETIME       
         , @dt_Lottable15       DATETIME  
         , @c_AdjType           NVARCHAR(50)
         , @c_Channel           NVARCHAR(20)
         , @c_UpdateAdjType     NVARCHAR(1) = 'N'
         , @c_GenNewAdj         NVARCHAR(1) = 'N'
         , @c_NewAdjKey         NVARCHAR(10)
         , @c_NewAdjLine        NVARCHAR(10)
         , @c_GetAdjKey         NVARCHAR(10)

         , @c_GetAdjLineNo      NVARCHAR(5)
         , @c_GetAdjChannel     NVARCHAR(50)
         , @c_GetOldAdjKey      NVARCHAR(10)
         , @c_GetOldAdjLineNo   NVARCHAR(50)
         , @n_GetAdjQty         INT
         , @n_ActualAdjQty      INT
         , @n_Cnt               INT
         , @b_debug             INT = 0

   DECLARE @n_B2B_Exclude_Qty   INT = 0
         , @n_B2B_Channel_Qty   INT = 0
         , @n_B2B_AvailQty      INT = 0
         , @n_B2C_Exclude_Qty   INT = 0
         , @n_B2C_Channel_Qty   INT = 0
         , @n_B2C_AvailQty      INT = 0
                                
         , @n_B2B_QtyAdj        INT = 0
         , @n_B2C_QtyAdj        INT = 0

   CREATE TABLE #TMP_HostWHCode (
         Long         NVARCHAR(50)
       , HostWHCode   NVARCHAR(50)
   )

   CREATE TABLE #TMP_NewAdj (
         RowID        INT NOT NULL IDENTITY(1,1) PRIMARY KEY
       , AdjKey       NVARCHAR(10) NULL
       , OldAdjKey    NVARCHAR(10)
       , OldAdjLineNo NVARCHAR(5)
       , AdjType      NVARCHAR(50)
       , AdjQty       INT
       , AdjChannel   NVARCHAR(20)
   )

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @c_errmsg   = ''

   IF @n_err > 0
   BEGIN
      SET @b_debug = @n_err
      SET @n_err   = 0
   END
 
   IF EXISTS( SELECT 1
              FROM ADJUSTMENT WITH (NOLOCK)
              WHERE Adjustmentkey = @c_Adjustmentkey
              AND AdjustmentType = 'NIF'
            )
   BEGIN
      GOTO QUIT_SP
   END

   IF EXISTS( SELECT 1
              FROM ADJUSTMENT WITH (NOLOCK)
              WHERE Adjustmentkey = @c_Adjustmentkey
              AND AdjustmentType <> 'AA'
            )
   BEGIN
      GOTO QUIT_SP
   END

   SELECT @c_Storerkey    = StorerKey
        , @c_Facility     = Facility
        , @c_Remarks      = Remarks
        , @c_FromToWhse   = FromToWhse
        , @c_UserDefine02 = UserDefine02
   FROM ADJUSTMENT (NOLOCK)
   WHERE AdjustmentKey = @c_AdjustmentKey

   INSERT INTO #TMP_HostWHCode (Long, HostWHCode)
   SELECT DISTINCT CL.Long, CL.Code
   FROM CODELKUP CL (NOLOCK)
   WHERE CL.Storerkey = @c_Storerkey
   AND CL.LISTNAME = 'adStkSts'
   AND CL.Long IN ('B','I')

   IF @@TRANCOUNT = 0
      BEGIN TRAN 

   CREATE TABLE #TMP_INV (
      SKU               NVARCHAR(20)
    , B2BAvailQty       INT 
    , B2CAvailQty       INT
    , B2BQtyAdjusted    INT DEFAULT(0)
    , B2CQtyAdjusted    INT DEFAULT(0)
   )
       
   DECLARE CUR_SKU CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   SELECT DISTINCT SKU
   FROM ADJUSTMENTDETAIL AD (NOLOCK)
   WHERE Adjustmentkey = @c_AdjustmentKey

   OPEN CUR_SKU
   
   FETCH NEXT FROM CUR_SKU INTO @c_SKU

   WHILE @@FETCH_STATUS <> -1  
   BEGIN
      --B2B Inventory - START
      --BL & QI--
      SELECT @n_B2B_Exclude_Qty = SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.QtyReplen + LLI.PendingMoveIN)
      FROM LOTXLOCXID LLI (NOLOCK) 
      JOIN LOC L (NOLOCK) ON L.Loc = LLI.LOC
      JOIN #TMP_HostWHCode TH ON TH.HostWHCode = L.HOSTWHCODE AND TH.Long IN  ('B','I') 
      WHERE LLI.StorerKey = @c_Storerkey AND LLI.SKU = @c_Sku
      
      IF ISNULL(@n_B2B_Exclude_Qty,0) = 0
         SET @n_B2B_Exclude_Qty = 0

      --Channel Qty--
      SELECT @n_B2B_Channel_Qty = SUM(CI.Qty - CI.QtyAllocated - CI.QtyOnHold)
      FROM dbo.ChannelInv CI (NOLOCK)
      WHERE CI.StorerKey = @c_Storerkey AND CI.SKU = @c_Sku
      AND CI.Channel = 'ADIDAS'

      --AvailableQty--
      SET @n_B2B_AvailQty = @n_B2B_Channel_Qty - @n_B2B_Exclude_Qty
      --B2B Inventory - END

      --B2C Inventory - START
      --BL & QI--
      SELECT @n_B2C_Exclude_Qty = SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.QtyReplen + LLI.PendingMoveIN)
      FROM LOTXLOCXID LLI (NOLOCK) 
      JOIN LOC L (NOLOCK) ON L.Loc = LLI.LOC
      WHERE LLI.StorerKey = @c_Storerkey AND LLI.SKU = @c_Sku
      AND L.HOSTWHCODE IN ('aBL','aQI')

      IF ISNULL(@n_B2C_Exclude_Qty,0) = 0
         SET @n_B2C_Exclude_Qty = 0
      
      --Channel Qty--
      SELECT @n_B2C_Channel_Qty = SUM(CI.Qty - CI.QtyAllocated - CI.QtyOnHold)
      FROM dbo.ChannelInv CI (NOLOCK)
      WHERE CI.StorerKey = @c_Storerkey AND CI.SKU = @c_Sku
      AND CI.Channel = 'aCommerce'

      --AvailableQty--
      SET @n_B2C_AvailQty = @n_B2C_Channel_Qty - @n_B2C_Exclude_Qty
      --B2C Inventory - END

      INSERT INTO #TMP_INV (SKU, B2BAvailQty, B2CAvailQty, B2BQtyAdjusted, B2CQtyAdjusted)
      SELECT @c_SKU, @n_B2B_AvailQty, @n_B2C_AvailQty, 0, 0

      FETCH NEXT FROM CUR_SKU INTO @c_SKU
   END
   CLOSE CUR_SKU
   DEALLOCATE CUR_SKU

   IF @b_debug = 1
   BEGIN
      SELECT * FROM #TMP_INV
   END

   SET @c_SKU = ''
   SET @n_B2B_QtyAdj = 0
   SET @n_B2C_QtyAdj = 0

   DECLARE CUR_ADLINE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   SELECT AdjustmentLineNumber
        , Lot
        , Lottable01 
        , Lottable02 
        , Lottable03 
        , Lottable04
        , Lottable05
        , Lottable06 
        , Lottable07 
        , Lottable08 
        , Lottable09 
        , Lottable10 
        , Lottable11 
        , Lottable12 
        , Lottable13
        , Lottable14
        , Lottable15
        , ADJUSTMENTDETAIL.SKU
        , Qty
        , Channel
        , (TI.B2BAvailQty - TI.B2BQtyAdjusted)
        , (TI.B2CAvailQty - TI.B2CQtyAdjusted)
   FROM ADJUSTMENTDETAIL WITH (NOLOCK)
   JOIN #TMP_INV TI ON TI.SKU = ADJUSTMENTDETAIL.Sku
   WHERE Adjustmentkey = @c_AdjustmentKey
 
   OPEN CUR_ADLINE
   
   FETCH NEXT FROM CUR_ADLINE INTO @c_AdjLineNumber
                                 , @c_Lot
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
                                 , @c_Sku
                                 , @n_AdjQty
                                 , @c_Channel
                                 , @n_B2B_AvailQty
                                 , @n_B2C_AvailQty

   WHILE @@FETCH_STATUS <> -1  
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_Sku          AS Sku
              , @n_AdjQty       AS AdjQty
              , @c_Channel      AS Channel
              , @n_B2B_AvailQty AS B2B_AvailQty
              , @n_B2C_AvailQty AS B2C_AvailQty
      END

      IF @n_AdjQty >= 0
      BEGIN
         SET @c_AdjType       = 'ADS'
         SET @c_UpdateAdjType = 'Y'
         
         --IF ISNULL(@c_Channel,'') = ''
         --BEGIN
         UPDATE dbo.ADJUSTMENTDETAIL WITH (ROWLOCK)
         SET Channel    = 'ADIDAS'
           , TrafficCop = NULL
           , EditDate   = GETDATE()
           , EditWho    = SUSER_SNAME()
         WHERE AdjustmentKey = @c_AdjustmentKey
         AND AdjustmentLineNumber = @c_AdjLineNumber

         SET @n_err = @@ERROR

         IF @n_Err <> 0 
         BEGIN
            SET @n_continue = 3
            SET @n_Err      = 72810
            SET @c_errmsg   = 'NSQL'+CONVERT(char(5),@n_err)+': UPDATE AdjustmentDetail Fail. (ispPRADJ03)'
            GOTO QUIT_SP
         END
         --END
      END
      ELSE   --@n_AdjQty < 0   --Negative Adjustment
      BEGIN
         IF @n_AdjQty < 0
         BEGIN 
            SET @n_ActualAdjQty = @n_AdjQty
            SET @n_AdjQty = @n_AdjQty * -1
         END

         IF @n_AdjQty < @n_B2B_AvailQty
         BEGIN
            SET @c_AdjType       = 'ADS'
            SET @c_UpdateAdjType = 'Y'

            UPDATE #TMP_INV
            SET B2BQtyAdjusted = B2BQtyAdjusted + @n_AdjQty
            WHERE SKU = @c_Sku

            --IF ISNULL(@c_Channel,'') = ''
            --BEGIN
            UPDATE dbo.ADJUSTMENTDETAIL WITH (ROWLOCK)
            SET Channel    = 'ADIDAS'
              , TrafficCop = NULL
              , EditDate   = GETDATE()
              , EditWho    = SUSER_SNAME()
            WHERE AdjustmentKey = @c_AdjustmentKey
            AND AdjustmentLineNumber = @c_AdjLineNumber
            
            SET @n_err = @@ERROR
            
            IF @n_Err <> 0 
            BEGIN
               SET @n_continue = 3
               SET @n_Err      = 72825
               SET @c_errmsg   = 'NSQL'+CONVERT(char(5),@n_err)+': UPDATE AdjustmentDetail Fail. (ispPRADJ03)'
               GOTO QUIT_SP
            END
            --END
         END
         ELSE IF @n_B2B_AvailQty > 0 AND @n_B2C_AvailQty >= (@n_AdjQty - @n_B2B_AvailQty)
         BEGIN
            SET @c_AdjType       = 'ADS'
            SET @c_UpdateAdjType = 'Y'

            UPDATE #TMP_INV
            SET B2BQtyAdjusted = B2BQtyAdjusted + @n_B2B_AvailQty
            WHERE SKU = @c_Sku

            UPDATE dbo.ADJUSTMENTDETAIL WITH (ROWLOCK)
            SET Channel    = 'ADIDAS'
              , TrafficCop = NULL
              , EditDate   = GETDATE()
              , EditWho    = SUSER_SNAME()
              , ArchiveCop = NULL
              , Qty        = (@n_B2B_AvailQty * -1)   --Make it negative value
            WHERE AdjustmentKey = @c_AdjustmentKey
            AND AdjustmentLineNumber = @c_AdjLineNumber
            
            SET @n_err = @@ERROR
            
            IF @n_Err <> 0 
            BEGIN
               SET @n_continue = 3
               SET @n_Err      = 72815
               SET @c_errmsg   = 'NSQL'+CONVERT(char(5),@n_err)+': UPDATE AdjustmentDetail Fail. (ispPRADJ03)'
               GOTO QUIT_SP
            END

            --Generate New Adjustment Key
            INSERT INTO #TMP_NewAdj (AdjKey, OldAdjKey, OldAdjLineNo, AdjType, AdjQty, AdjChannel)
            SELECT '', @c_AdjustmentKey, @c_AdjLineNumber, 'ACM', (@n_B2B_AvailQty - @n_AdjQty), 'aCommerce'

            UPDATE #TMP_INV
            SET B2CQtyAdjusted = B2CQtyAdjusted + ((@n_B2B_AvailQty - @n_AdjQty) * -1)
            WHERE SKU = @c_Sku

            SET @c_GenNewAdj = 'Y'
         END
         ELSE IF @n_AdjQty <= @n_B2C_AvailQty AND @n_B2B_AvailQty <= 0
         BEGIN
            SET @c_AdjType       = 'ACM'
            SET @c_UpdateAdjType = 'Y'
            
            UPDATE #TMP_INV
            SET B2CQtyAdjusted = B2CQtyAdjusted + @n_AdjQty
            WHERE SKU = @c_Sku
         
            --IF ISNULL(@c_Channel,'') = ''
            --BEGIN
            UPDATE dbo.ADJUSTMENTDETAIL WITH (ROWLOCK)
            SET Channel    = 'aCommerce'
              , TrafficCop = NULL
              , EditDate   = GETDATE()
              , EditWho    = SUSER_SNAME()
              , ReasonCode = 'SEL'
            WHERE AdjustmentKey = @c_AdjustmentKey
            AND AdjustmentLineNumber = @c_AdjLineNumber
         
            SET @n_err = @@ERROR
         
            IF @n_Err <> 0 
            BEGIN
               SET @n_continue = 3
               SET @n_Err      = 72820
               SET @c_errmsg   = 'NSQL'+CONVERT(char(5),@n_err)+': UPDATE AdjustmentDetail Fail. (ispPRADJ03)'
               GOTO QUIT_SP
            END
            --END
         END
         ELSE
         BEGIN
            SET @n_continue = 3
            SET @n_Err      = 72830
            SET @c_errmsg   = 'NSQL'+CONVERT(char(5),@n_err)+': Insufficient Quantity! (ispPRADJ03)'
            GOTO QUIT_SP
         END
      END

NEXT_LINE:
      FETCH NEXT FROM CUR_ADLINE INTO @c_AdjLineNumber
                                    , @c_Lot
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
                                    , @c_Sku
                                    , @n_AdjQty
                                    , @c_Channel
                                    , @n_B2B_AvailQty
                                    , @n_B2C_AvailQty

   END
   CLOSE CUR_ADLINE
   DEALLOCATE CUR_ADLINE

   IF @b_debug = 1
   BEGIN
      SELECT * FROM #TMP_INV

      SELECT * FROM #TMP_NewAdj TNA
   END

   IF @n_Continue IN (1,2) AND @c_UpdateAdjType = 'Y'
   BEGIN
      UPDATE ADJUSTMENT WITH (ROWLOCK)
      SET AdjustmentType = @c_AdjType
      WHERE AdjustmentKey = @c_AdjustmentKey

      SET @n_err = @@ERROR

      IF @n_Err <> 0 
      BEGIN
         SET @n_continue = 3
         SET @n_Err      = 72835
         SET @c_errmsg   = 'NSQL'+CONVERT(char(5),@n_err)+': UPDATE Adjustment Fail. (ispPRADJ03)'
         GOTO QUIT_SP
      END
   END
   
   IF @n_Continue IN (1,2) AND @c_GenNewAdj = 'Y'
   BEGIN
      SET @c_NewAdjKey  = ''
      SET @c_NewAdjLine = ''

      EXECUTE nspg_GetKey 
              @KeyName     = 'ADJUSTMENT'
            , @fieldlength = 10
            , @keystring   = @c_NewAdjKey       OUTPUT
            , @b_success   = @b_success         OUTPUT
            , @n_err       = @n_err             OUTPUT
            , @c_errmsg    = @c_errmsg          OUTPUT
            , @b_resultset = 0
            , @n_batch     = 1
      
      IF @b_success <> 1
      BEGIN
         SET @n_continue = 3                                                                                              
         SET @n_err = 72840                                                                                               
         SET @c_errmsg='NSQL'+ CONVERT(CHAR(5),@n_err)+': Error Executing nspg_GetKey. (ispPRADJ03)' 
                        + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ).'                                  
         GOTO QUIT_SP        
      END

      SET @c_AdjustmentKey = RIGHT('0000000000' + @c_NewAdjKey,10)

      UPDATE #TMP_NewAdj 
      SET AdjKey = @c_AdjustmentKey

      INSERT INTO ADJUSTMENT
         (  AdjustmentKey
         ,  AdjustmentType
         ,  StorerKey
         ,  Facility
         ,  CustomerRefNo
         ,  Remarks
         ,  FromToWhse
         ,  UserDefine02
         )
      SELECT TOP 1
            #TMP_NewAdj.AdjKey
         ,  #TMP_NewAdj.AdjType
         ,  @c_Storerkey
         ,  @c_Facility
         ,  #TMP_NewAdj.OldAdjKey
         ,  @c_Remarks     
         ,  @c_FromToWhse  
         ,  @c_UserDefine02
      FROM #TMP_NewAdj

      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @n_err = 72845  
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Insert into ADJUSTMENT Table. (ispPRADJ03)' 
                        + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
         GOTO QUIT_SP
      END

      DECLARE CUR_ADJ CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT RowID, AdjQty, OldAdjKey, OldAdjLineNo, AdjChannel
      FROM   #TMP_NewAdj  
      ORDER BY RowID

      OPEN CUR_ADJ
   
      FETCH NEXT FROM CUR_ADJ INTO @c_GetAdjLineNo, @n_GetAdjQty, @c_GetOldAdjKey, @c_GetOldAdjLineNo, @c_GetAdjChannel
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         INSERT INTO ADJUSTMENTDETAIL
            (  Adjustmentkey
            ,  AdjustmentLineNumber
            ,  StorerKey
            ,  Sku
            ,  Packkey
            ,  UOM
            ,  Lot
            ,  Loc
            ,  Id
            ,  Qty
            ,  ReasonCode
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
            ,  Channel
            )
         SELECT
               @c_AdjustmentKey
            ,  RIGHT('00000' + CAST(@c_GetAdjLineNo AS NVARCHAR(5)), 5)
            ,  StorerKey
            ,  Sku
            ,  Packkey
            ,  UOM
            ,  Lot
            ,  Loc
            ,  Id
            ,  @n_GetAdjQty
            ,  'SEL'
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
            ,  @c_GetAdjChannel
         FROM ADJUSTMENTDETAIL (NOLOCK)
         WHERE Adjustmentkey = @c_GetOldAdjKey  
         AND AdjustmentLineNumber = @c_GetOldAdjLineNo
                 
         SET @n_err = @@ERROR

         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @n_err = 72850  
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Insert into ADJUSTMENTDETAIL Table. (ispPRADJ03)' 
                           + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
            GOTO QUIT_SP
         END
         
         WHILE @@TRANCOUNT > 0 
         BEGIN
            COMMIT TRAN
         END    
         
         --Finalize the new adjustment key
         EXECUTE isp_FinalizeADJ
                  @c_ADJKey   = @c_AdjustmentKey
               ,  @b_Success  = @b_Success OUTPUT 
               ,  @n_err      = @n_err     OUTPUT 
               ,  @c_errmsg   = @c_errmsg  OUTPUT   
         
         IF @n_err <> 0  
         BEGIN 
            SET @n_continue= 3 
            SET @n_err  = 72855
            SET @c_errmsg = 'NSQL'+ CONVERT(CHAR(5),@n_err)+': Execute isp_FinalizeADJ Failed. (ispPRADJ03)'
            GOTO QUIT_SP 
         END
         
         SET @n_Cnt = 0
         
         SELECT @n_Cnt = 1
         FROM ADJUSTMENTDETAIL WITH (NOLOCK)
         WHERE AdjustmentKey = @c_AdjustmentKey
         AND FinalizedFlag <> 'Y'
         
         IF @n_Cnt = 1
         BEGIN          
            UPDATE ADJUSTMENT WITH (ROWLOCK)
            SET FinalizedFlag = 'Y'
               ,TrafficCop = NULL  
            WHERE AdjustmentKey = @c_AdjustmentKey
         
            IF @n_err <> 0  
            BEGIN 
               SET @n_continue= 3 
               SET @n_err  = 72860
               SET @c_errmsg = 'NSQL'+ CONVERT(CHAR(5),@n_err)+': Execute isp_FinalizeADJ Failed. (ispPRADJ03)'
               GOTO QUIT_SP 
            END
         END

         FETCH NEXT FROM CUR_ADJ INTO @c_GetAdjLineNo, @n_GetAdjQty, @c_GetOldAdjKey, @c_GetOldAdjLineNo, @c_GetAdjChannel
      END 
      CLOSE CUR_ADJ
      DEALLOCATE CUR_ADJ
   END
 
QUIT_SP:
   IF CURSOR_STATUS( 'LOCAL', 'CUR_ADLINE') in (0 , 1)  
   BEGIN
      CLOSE CUR_ADLINE
      DEALLOCATE CUR_ADLINE
   END
   
   IF OBJECT_ID('tempdb..#TMP_HostWHCode') IS NOT NULL
      DROP TABLE #TMP_HostWHCode

   IF OBJECT_ID('tempdb..#TMP_NewAdj') IS NOT NULL
      DROP TABLE #TMP_NewAdj

   IF OBJECT_ID('tempdb..#TMP_INV') IS NOT NULL
      DROP TABLE #TMP_INV

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispPRADJ03'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure

GO