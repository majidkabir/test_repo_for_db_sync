SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_ItrnUCCAdd                                          */
/* Creation Date: 2020-05-29                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-13117 - [CN] Sephora_WMS_ITRN_Add_UCC_CR                */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_ItrnUCCAdd]
           @c_Storerkey          NVARCHAR(15)
         , @c_UCCNo              NVARCHAR(20) 
         , @c_Sku                NVARCHAR(20)
         , @c_UCCStatus          NVARCHAR(10) 
         , @c_SourceKey          NVARCHAR(20)    
         , @c_ItrnSourceType     NVARCHAR(30)
         , @c_ToStorerkey        NVARCHAR(15)=''
         , @c_ToUCCNo            NVARCHAR(20)=''
         , @c_ToSku              NVARCHAR(20)=''
         , @c_ToUCCStatus        NVARCHAR(10)='' 
         , @b_Success            INT            OUTPUT
         , @n_Err                INT            OUTPUT
         , @c_ErrMsg             NVARCHAR(255)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT         = @@TRANCOUNT
         , @n_Continue        INT         = 1

         , @n_UCC_RowRef      INT         = '0'
         --, @c_UCCNo           NVARCHAR(20)   
         --, @c_Sku             NVARCHAR(20)
         , @c_ItrnKey         NVARCHAR(10)= ''
         , @c_ItrnType        NVARCHAR(10)= ''
         , @c_FromStatus      NVARCHAR(10)= '0'
         , @c_ToStatus        NVARCHAR(10)= '0'

         , @n_Qty             INT         = 0

         , @c_Facility        NVARCHAR(5) = ''
         , @c_DocKey          NVARCHAR(10)= ''
         , @c_DocLineNo       NVARCHAR(5) = '' 

         , @c_FromItrnKey     NVARCHAR(10)= ''
         , @c_FromLot         NVARCHAR(10)= ''
         , @c_FromLoc         NVARCHAR(10)= ''
         , @c_FromID          NVARCHAR(18)= ''
         , @n_FromQty         INT         = 0
         , @c_ToItrnKey       NVARCHAR(10)= ''
         , @c_ToLot           NVARCHAR(10)= ''
         , @c_ToLoc           NVARCHAR(10)= ''
         , @c_ToID            NVARCHAR(18)= ''
         , @n_ToQty           INT         = 0

         , @c_ItrnUCC         NVARCHAR(30)= '0'
         , @c_ItrnUCCShip_SP  NVARCHAR(30)= ''
         , @CUR_UCC           CURSOR

   SET @n_err      = 0
   SET @c_errmsg   = ''

   IF (@c_UCCNo = '' OR @c_UCCNo IS NULL) AND 
      @c_ItrnSourceType NOT IN ('ntrPickDetailAdd','ntrPickDetailUpdate')
   BEGIN
      GOTO QUIT_SP
   END 
    
   IF @c_Sourcekey <> ''
   BEGIN
      SET @c_DocKey = SUBSTRING(@c_Sourcekey,1,10)

      IF LEN(@c_Sourcekey) > 10
      BEGIN
         SET @c_DocLineNo = SUBSTRING(@c_Sourcekey,11,5)
      END
   END

   IF @c_ItrnSourceType = 'ntrReceiptDetailUpdate'
   BEGIN
      SELECT @c_Facility = Facility
      FROM RECEIPT WITH (NOLOCK)
      WHERE ReceiptKey = @c_DocKey
      AND   Storerkey  = @c_Storerkey
   END
   ELSE IF @c_ItrnSourceType IN ('ntrAdjustmentDetailAdd', 'ntrAdjustmentDetailUpdate')
   BEGIN
      SELECT @c_Facility = Facility
      FROM ADJUSTMENT WITH (NOLOCK)
      WHERE Adjustmentkey = @c_DocKey
      AND   Storerkey  = @c_Storerkey
   END
   ELSE IF @c_ItrnSourceType = 'ntrTransferDetailUpdate'
   BEGIN
      SELECT @c_Facility = Facility
      FROM TRANSFER WITH (NOLOCK)
      WHERE Transferkey = @c_DocKey
      AND   FromStorerkey  = @c_Storerkey
   END
   ELSE IF @c_ItrnSourceType IN ('ntrPickDetailAdd','ntrPickDetailUpdate')
   BEGIN
      SELECT TOP 1 @c_Facility = OH.Facility
      FROM PICKDETAIL PD WITH (NOLOCK)
      JOIN ORDERS     OH WITH (NOLOCK) ON PD.Orderkey = OH.Orderkey
      WHERE PD.PickDetailKey = @c_DocKey
      AND   PD.Storerkey     = @c_Storerkey
   END

   SET @c_ITRNUCC = '0'
   If @n_continue = 1 or @n_continue = 2
   Begin
      SET @b_success = 0
      SET @c_ITRNUCC = ''
      Execute nspGetRight2 
         @c_facility = @c_facility
      ,  @c_StorerKey= @c_StorerKey                   -- Storer
      ,  @c_Sku      = ''                             -- Sku
      ,  @c_ConfigKey= 'ITRNUCC'                      -- ConfigKey
      ,  @b_success  = @b_success         OUTPUT
      ,  @c_authority= @c_ITRNUCC         OUTPUT
      ,  @n_err      = @n_err             OUTPUT
      ,  @c_ErrMsg   = @c_ErrMsg          OUTPUT
      ,  @c_Option1  = @c_ItrnUCCShip_SP  OUTPUT    

      If @b_success <> 1
      Begin
         Select @n_continue = 3, @n_err = 61961, @c_ErrMsg = 'isp_ItrnUCCAdd:' + ISNULL(RTRIM(@c_ErrMsg),'')
      End
   END  

   IF @c_ItrnUCC = '0'
   BEGIN
      GOTO QUIT_SP
   END

   SELECT TOP 1 
          @c_ToItrnKey = ItrnKey
         ,@c_ToLot = Lot
         ,@c_ToLoc = ToLoc
         ,@c_ToID  = ToID
         ,@n_ToQty = Qty
   FROM ITRN WITH (NOLOCK)
   WHERE SourceType = @c_ItrnSourceType
   AND   SourceKey  = @c_SourceKey
   AND   TranType   IN ('DP','AJ','WD')
   ORDER BY TranType 

   IF @c_ItrnSourceType IN ('ntrPickDetailAdd','ntrPickDetailUpdate')
   BEGIN
      IF EXISTS ( SELECT 1 FROM sys.objects (NOLOCK) WHERE  object_id = OBJECT_ID(@c_ItrnUCCShip_SP) 
                  AND schema_id('dbo') = schema_id
                  AND [Type] = 'P')
      BEGIN
         EXEC @c_ItrnUCCShip_SP
               @c_ItrnKey  = @c_ItrnKey
            ,  @c_SourceKey= @c_Sourcekey
            ,  @c_Lot      = @c_ToLot
            ,  @c_ToLoc    = @c_ToLoc
            ,  @c_ToID     = @c_ToID
            ,  @n_Qty      = @n_Qty 
            ,  @b_Success  = @b_Success OUTPUT
            ,  @n_Err      = @n_Err     OUTPUT
            ,  @c_ErrMsg   = @c_ErrMsg  OUTPUT 
            
         IF @b_Success <> 1 
         BEGIN 
            SET @n_continue = 3 
            SET @c_errmsg = CONVERT(CHAR(5), @n_err)
            SET @n_err=80010 
            SET @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ': Error Executing Custom SP - ' + @c_ItrnUCCShip_SP + '. (isp_ItrnUCCAdd) '
                          + '( SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '             
         END
      END
      GOTO QUIT_SP
   END

   IF @c_ItrnSourceType = 'ntrReceiptDetailUpdate'
   BEGIN
      SET @CUR_UCC = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT UCC.UCCNo
            ,UCC.Sku
            ,ItrnKey = @c_ToItrnKey
            ,ItrnType= 'DP'
            ,FromStatus = @c_UCCStatus
            ,ToStatus   = UCC.[Status]
            ,Qty        = @n_ToQty
      FROM UCC WITH (NOLOCK)
      WHERE UCC.Storerkey  = @c_Storerkey
      AND   UCCNo   = @c_UCCNo
      AND   Sku     = @c_Sku
      AND   UCC.Lot = @c_ToLot
      AND   UCC.Loc = @c_ToLoc
      AND   UCC.ID  = @c_ToID  
      ORDER BY UCC.UCC_RowRef
   END
   ELSE IF @c_ItrnSourceType IN ('ntrAdjustmentDetailAdd', 'ntrAdjustmentDetailUpdate')
   BEGIN
      SET @CUR_UCC = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT UCC.UCCNo
            ,UCC.Sku
            ,ItrnKey = @c_ToItrnKey
            ,ItrnType= 'AJ'
            ,FromStatus = @c_UCCStatus
            ,ToStatus   = UCC.[Status]
            ,Qty        = @n_ToQty
      FROM UCC WITH (NOLOCK)
      WHERE UCC.Storerkey  = @c_Storerkey
      AND   UCCNo   = @c_UCCNo
      AND   Sku     = @c_Sku
      AND   UCC.Lot = @c_ToLot
      AND   UCC.Loc = @c_ToLoc
      AND   UCC.ID  = @c_ToID   
      ORDER BY UCC.UCC_RowRef
   END
   ELSE IF @c_ItrnSourceType = 'ntrTransferDetailUpdate'
   BEGIN
      SELECT TOP 1 
             @c_FromItrnKey = ItrnKey
            ,@c_FromLot = Lot
            ,@c_FromLoc = ToLoc
            ,@c_FromID  = ToID
            ,@n_FromQty = Qty
      FROM ITRN WITH (NOLOCK)
      WHERE SourceType = @c_ItrnSourceType
      AND   SourceKey  = @c_SourceKey
      AND   TranType = 'WD'
      ORDER BY TranType DESC

      SET @CUR_UCC = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT UCC.UCCNo
            ,UCC.Sku
            ,ItrnKey = @c_FromItrnKey
            ,ItrnType= 'WD'
            ,FromStatus = @c_UCCStatus
            ,ToStatus   = UCC.[Status]
            ,Qty        = @n_FromQty
      FROM UCC WITH (NOLOCK)
      WHERE UCC.Storerkey = @c_Storerkey
      AND   UCC.UCCNo = @c_UCCNo
      AND   UCC.Sku = @c_Sku
      AND   UCC.Lot = @c_FromLot
      AND   UCC.Loc = @c_FromLoc
      AND   UCC.ID  = @c_FromID
      UNION ALL
      SELECT UCC.UCCNo
            ,UCC.Sku
            ,ItrnKey = @c_ToItrnKey
            ,ItrnType= 'DP'
            ,FromStatus = @c_ToUCCStatus
            ,ToStatus   = UCC.[Status]
            ,Qty        = @n_ToQty
      FROM UCC WITH (NOLOCK)
      WHERE UCC.Storerkey = @c_ToStorerkey
      AND   UCC.UCCNo = @c_ToUCCNo
      AND   UCC.Sku = @c_ToSku
      AND   UCC.Lot = @c_ToLot
      AND   UCC.Loc = @c_ToLoc
      AND   UCC.ID  = @c_ToID
      ORDER BY ItrnType DESC
   END

   OPEN @CUR_UCC
   
   FETCH NEXT FROM @CUR_UCC INTO @c_UCCNo
                              ,  @c_Sku
                              ,  @c_ItrnKey
                              ,  @c_ItrnType
                              ,  @c_FromStatus
                              ,  @c_ToStatus
                              ,  @n_Qty
    
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      INSERT INTO ITRNUCC  
         (  
            ItrnKey
         ,  Storerkey      
         ,  UCCNo
         ,  Sku
         ,  Qty
         ,  FromStatus
         ,  ToStatus
         )
      VALUES 
         (  
            @c_ItrnKey
         ,  @c_Storerkey      
         ,  @c_UCCNo
         ,  @c_Sku
         ,  @n_Qty
         ,  @c_FromStatus
         ,  @c_ToStatus
         )

      SET @n_err = @@ERROR

      IF @n_err <> 0 
      BEGIN 
         SET @n_continue = 3 
         SET @c_errmsg = CONVERT(CHAR(5), @n_err)
         SET @n_err=80020 
         SET @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ': Insert failed into table ItrnUCC. (isp_ItrnUCCAdd) '
                       + '( SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
         GOTO QUIT_SP               
      END 
      
      FETCH NEXT FROM @CUR_UCC INTO @c_UCCNo
                                 ,  @c_Sku
                                 ,  @c_ItrnKey
                                 ,  @c_ItrnType
                                 ,  @c_FromStatus
                                 ,  @c_ToStatus
                                 ,  @n_Qty
   END
   CLOSE @CUR_UCC
   DEALLOCATE @CUR_UCC  

QUIT_SP:

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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_ItrnUCCAdd'
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