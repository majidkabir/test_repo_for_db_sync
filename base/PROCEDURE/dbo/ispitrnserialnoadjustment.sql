SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: ispITrnSerialNoAdjustment                          */  
/* Creation Date: 23-May-2017                                           */  
/* Copyright: Maersk Logistics                                          */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: WMS-1884 Serial Number adjustment transaction               */ 
/*                                                                      */  
/* Called By: isp_FinalizeADJ                                           */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author   Rev   Purposes                                  */ 
/* 2024-08-05  Wan01    1.1   LFWM-4397 - RG [GIT] Serial Number Solution*/
/*                            - Adjustment by Serial Number             */
/************************************************************************/  
CREATE   PROCEDURE dbo.ispITrnSerialNoAdjustment (
     @c_ItrnKey      NVARCHAR(10) = ''                                              --(Wan01)
   , @c_TranType     NVARCHAR(10) = 'AJ'
   , @c_StorerKey    NVARCHAR(15)
   , @c_SKU          NVARCHAR(20)
   , @c_SerialNo     NVARCHAR(30)
   , @n_QTY          INT = 1
   , @c_SourceKey    NVARCHAR(20)
   , @c_SourceType   NVARCHAR(30)
   , @b_Success      INT            OUTPUT  
   , @n_Err          INT            OUTPUT  
   , @c_ErrMsg       NVARCHAR(250)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue        INT,
           --@c_ITrnKey        NVARCHAR(10),                                        --(Wan01)
           @n_Add             INT = 0,                                              --(Wan01)
           @n_StartTranCount  INT  
           
         , @c_Lot             NVARCHAR(10) = ''                                     --(Wan01)  
         , @c_Loc             NVARCHAR(10) = ''                                     --(Wan01)
         , @c_ID              NVARCHAR(18) = ''                                     --(Wan01)
         , @c_lottable01      NVARCHAR(18) = ''                                     --(Wan01)
         , @c_lottable02      NVARCHAR(18) = ''                                     --(Wan01)
         , @c_lottable03      NVARCHAR(18) = ''                                     --(Wan01)
         , @d_lottable04      DATETIME     = NULL                                   --(Wan01)
         , @d_lottable05      DATETIME     = NULL                                   --(Wan01)
         , @c_lottable06      NVARCHAR(30) = ''                                     --(Wan01)
         , @c_lottable07      NVARCHAR(30) = ''                                     --(Wan01)
         , @c_lottable08      NVARCHAR(30) = ''                                     --(Wan01)
         , @c_lottable09      NVARCHAR(30) = ''                                     --(Wan01)
         , @c_lottable10      NVARCHAR(30) = ''                                     --(Wan01)
         , @c_lottable11      NVARCHAR(30) = ''                                     --(Wan01)
         , @c_lottable12      NVARCHAR(30) = ''                                     --(Wan01)
         , @d_lottable13      DATETIME     = NULL                                   --(Wan01)
         , @d_lottable14      DATETIME     = NULL                                   --(Wan01)
         , @d_lottable15      DATETIME     = NULL                                   --(Wan01)
         , @c_Status          NVARCHAR(10) = ''                                     --(Wan01)
         , @c_UCCNo           NVARCHAR(20) = ''                                     --(Wan01)
   
   SELECT  @n_Err = 0, @c_ErrMsg = '', @b_Success = 1, @n_continue = 1, @n_StartTranCount = @@TRANCOUNT 

   SET @c_ItrnKey = ISNULL(@c_ItrnKey,'')                                           --(Wan01) - START      
   IF @c_ItrnKey = ''                                                                
   BEGIN
      SELECT @c_ITrnKey = ITrnKey
      FROM ITrn WITH (NOLOCK)
      WHERE TranType = @c_TranType
      AND StorerKey = @c_StorerKey
      AND SKU = @c_SKU
      AND SourceKey = @c_SourceKey
      
      IF @@ROWCOUNT <> 1
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 109351
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': ITrn adjustment record not found (ispITrnSerialNoAdjustment)' 
         GOTO QUIT_SP
      END
   END 

   IF @c_SourceType Like 'ntrAdjustmentDetail%'
   BEGIN
      SET @n_Add = 1
   END
   ELSE
   BEGIN
      SET @n_Add = 1
      IF EXISTS ( SELECT 1 
                  FROM ITrnSerialNo WITH (NOLOCK)
                  WHERE SourceType = @c_SourceType
                  AND ITrnKey = @c_ITrnKey
                )
      BEGIN 
         SET @n_Add = 0
      END
   END

   IF @n_Add = 1           
   BEGIN                                                                                           --(Wan01)         
      SELECT 
           @c_Lot    = Lot                                                        
         , @c_ID     = ISNULL(ID,'')
         , @c_Status = [Status]
         , @c_UCCNo  = ISNULL(UCCNo,'')
      FROM SERIALNO WITH (NOLOCK)
      WHERE Storerkey  = @c_Storerkey
      AND   SerialNo   = @c_SerialNo

      IF @c_Lot <> ''
      BEGIN
         SELECT  @c_lottable01 = la.lottable01
               , @c_lottable02 = la.lottable02
               , @c_lottable03 = la.lottable03
               , @d_lottable04 = la.lottable04
               , @d_lottable05 = la.lottable05
               , @c_lottable06 = la.lottable06
               , @c_lottable07 = la.lottable07
               , @c_lottable08 = la.lottable08
               , @c_lottable09 = la.lottable09
               , @c_lottable10 = la.lottable10
               , @c_lottable11 = la.lottable11
               , @c_lottable12 = la.lottable12
               , @d_lottable13 = la.lottable13
               , @d_lottable14 = la.lottable14
               , @d_lottable15 = la.lottable15
         FROM LOTATTRIBUTE la (NOLOCK)
         WHERE la.Lot = @c_lot
      END

      INSERT INTO ITrnSerialNo (ITrnKey, TranType, StorerKey, SKU, SerialNo, QTY, SourceKey, SourceType
                               ,Lot, Loc, ID
                               ,Lottable01, Lottable02, Lottable03, Lottable04, Lottable05
                               ,Lottable06, Lottable07, Lottable08, Lottable09, Lottable10
                               ,Lottable11, Lottable12, Lottable13, Lottable14, Lottable15
                               ,Channel, Channel_ID, UCCNo
                               --,[Status]
                               )
      VALUES (@c_ITrnKey, @c_TranType, @c_StorerKey, @c_SKU, @c_SerialNo, @n_QTY, @c_SourceKey, @c_SourceType
            ,@c_Lot, @c_Loc, @c_ID
            ,@c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05
            ,@c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10
            ,@c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15
            ,'', 0, @c_UCCNo
            --,@c_Status
             )
 
      SET @n_err = @@ERROR 
   
      IF @n_err  <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 109352
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert ITrnSerialNo failed (ispITrnSerialNoAdjustment)' + ' ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         GOTO QUIT_SP
      END
   END                                                                              --(Wan01) - END                                                                                          --(Wan01)     
QUIT_SP:

   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTranCount
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispITrnSerialNoAdjustment'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      
      WHILE @@TRANCOUNT > @n_StartTranCount  
      BEGIN  
         COMMIT TRAN  
      END  
      RETURN
   END 
END

GO