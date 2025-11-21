SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_ItrnUCCShip01                                       */
/* Creation Date: 2020-06-10                                            */
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
CREATE PROC [dbo].[isp_ItrnUCCShip01]
           @c_ItrnKey   NVARCHAR(10) 
         , @c_SourceKey NVARCHAR(10)   
         , @c_Lot       NVARCHAR(10)
         , @c_ToLoc     NVARCHAR(10)
         , @c_ToID      NVARCHAR(18)
         , @n_Qty       INT
         , @b_Success   INT            OUTPUT
         , @n_Err       INT            OUTPUT
         , @c_ErrMsg    NVARCHAR(255)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 

         , @n_UCC_RowRef      INT          = 0
         , @c_loseUCC         NVARCHAR(1)  = ''
         , @c_UCCNo           NVARCHAR(20) = ''
         , @c_Storerkey       NVARCHAR(15) = ''
         , @c_Sku             NVARCHAR(20) = ''
         , @c_FromStatus      NVARCHAR(10) = ''

         , @CUR_UCC           CURSOR       

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   SELECT @c_loseUCC = LoseUCC
   FROM Loc WITH (NOLOCK)
   WHERE Loc = @c_ToLoc

   IF @c_loseUCC = '1'
   BEGIN
      GOTO QUIT_SP
   END

   SET @c_UCCNo = '' 
   SELECT TOP 1 @c_UCCNo = PD.DropID
   FROM PICKDETAIL PD WITH (NOLOCK)
   WHERE PD.PickDetailKey = @c_SourceKey
   AND PD.UOM = '2'
 
   IF @c_UCCNo = ''
   BEGIN
      GOTO QUIT_SP
   END

   SET @CUR_UCC = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT UCCNo
         ,Storerkey
         ,Sku 
         ,[Status]
   FROM   UCC WITH (NOLOCK)
   WHERE  UCCNo = @c_UCCNo
   AND    Lot   = @c_Lot
   AND    Loc   = @c_ToLoc
   AND    ID    = @c_ToId
   ORDER BY UCC_RowRef
   
   OPEN @CUR_UCC
   
   FETCH NEXT FROM @CUR_UCC INTO @c_UCCNo
                              ,  @c_Storerkey
                              ,  @c_Sku
                              ,  @c_FromStatus
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
         ,  @c_FromStatus
         )

      SET @n_err = @@ERROR

      IF @n_err <> 0 
      BEGIN 
         SET @n_continue = 3 
         SET @c_errmsg = CONVERT(CHAR(5), @n_err)
         SET @n_err=69010 
         SET @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ': Insert failed into table ItrnUCC. (isp_ItrnUCCAdd) '
                       + '( SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
         GOTO QUIT_SP               
      END
      
      FETCH NEXT FROM @CUR_UCC INTO @c_UCCNo
                                 ,  @c_Storerkey
                                 ,  @c_Sku
                                 ,  @c_FromStatus
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_ItrnUCCShip01'
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