SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_AutoFinalizeABC                                     */
/* Creation Date: 01-FEB-2017                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-1615 - CN&SG Logitech ABC function for Cycle Count      */
/*        :                                                             */
/* Called By: isp_ABCProcessing_DMart                                   */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver  Purposes                                   */
/* 05-JAN-2018 Wan01    1.1  Fixed to filter finalizeflag ='N'          */ 
/* 08-MAY-2018 Wan02    1.1  Finalize Sku as C for sku w/o outbound qty */ 
/************************************************************************/
CREATE PROC [dbo].[isp_AutoFinalizeABC]
           @c_Storerkey          NVARCHAR(15)
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
           @n_StartTCnt       INT
         , @n_Continue        INT 

         , @n_SerialKey       BIGINT

         , @c_Sku                   NVARCHAR(20)   --(Wan02)
         , @c_SkuABC                NVARCHAR(10)   --(Wan02)
         , @c_SkuABCEA              NVARCHAR(10)   --(Wan02)
         , @c_SkuABCCS              NVARCHAR(10)   --(Wan02)
         , @c_SkuABCPL              NVARCHAR(10)   --(Wan02)
         , @c_ConfigKey             NVARCHAR(30)   --(Wan02)
         , @c_ABCUpd4SkuWOShipment  NVARCHAR(30)   --(Wan02)
         , @c_SkuNewABC             NVARCHAR(30)   --(Wan02)

         , @CUR_Sku                 CURSOR         --(Wan02)   

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   BEGIN TRAN

   DECLARE CUR_ABC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT SerialKey
   FROM   ABCANALYSIS WITH (NOLOCK)
   WHERE  Storerkey = @c_Storerkey
   AND    FinalizedFlag = 'N'             -- (Wan01) 
   ORDER BY Sku
         ,  NewABC DESC

   OPEN CUR_ABC
   
   FETCH NEXT FROM CUR_ABC INTO @n_SerialKey

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      UPDATE ABCANALYSIS WITH (ROWLOCK)
      SET FinalizedFlag = 'Y'
         ,EditWho = SUSER_NAME()
         ,EditDate= GETDATE()
      WHERE SerialKey = @n_SerialKey

      SET @n_err = @@ERROR 
      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @c_errmsg = CONVERT(CHAR(250),@n_err)
         SET @n_err=80010   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table ABCANALYSIS. (isp_AutoFinalizeABC)' 
                      + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
         GOTO QUIT_SP
      END
      FETCH NEXT FROM CUR_ABC INTO @n_SerialKey
   END
   CLOSE CUR_ABC
   DEALLOCATE CUR_ABC 

   --(Wan02) - START
   SET @c_ConfigKey = 'ABCUpd4SkuWOShipment'
   EXEC nspGetRight  
         ''           
      ,  @c_StorerKey             
      ,  ''       
      ,  @c_ConfigKey             
      ,  @b_Success  = @b_Success               OUTPUT   
      ,  @c_authority= @c_ABCUpd4SkuWOShipment  OUTPUT  
      ,  @n_err      = @n_err                   OUTPUT  
      ,  @c_errmsg   = @c_errmsg                OUTPUT

   IF @b_Success <> 1 
   BEGIN 
      SET @n_continue = 3
      SET @c_errmsg = CONVERT(CHAR(250),@n_err)
      SET @n_err=80020   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Executing nspGetRight. (isp_AutoFinalizeABC)' 
      GOTO QUIT_SP
   END

   IF @c_ABCUpd4SkuWOShipment = '1'  
   BEGIN
      SET @c_SkuNewABC = 'D'

      IF EXISTS (SELECT 1
                  FROM STORER WITH (NOLOCK)
                  WHERE Storerkey = @c_Storerkey
                  AND   CalcZeroMoveAsC = 'Y'
                 )
      BEGIN
         SET @c_SkuNewABC = 'C'
      END

      SET @CUR_SKU = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT SKU.Sku
         ,  SKU.ABC                                 
         ,  SKU.ABCEA         
         ,  SKU.ABCCS           
         ,  SKU.ABCPL 
      FROM   SKU WITH (NOLOCK)
      WHERE  SKU.Storerkey = @c_Storerkey
      AND NOT EXISTS (  SELECT 1 
                        FROM   ABCANALYSIS ANLYS WITH (NOLOCK)
                        WHERE  ANLYS.Storerkey = SKU.Storerkey
                        AND    ANLYS.Sku = SKU.Sku
                     )
      ORDER BY Sku

      OPEN @CUR_SKU
   
      FETCH NEXT FROM @CUR_SKU INTO @c_Sku
                                 ,  @c_SkuABC 
                                 ,  @c_SkuABCEA         
                                 ,  @c_SkuABCCS           
                                 ,  @c_SkuABCPL

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF (@c_SkuABC   <> @c_SkuNewABC) OR
            (@c_SkuABCEA <> @c_SkuNewABC) OR
            (@c_SkuABCCS <> @c_SkuNewABC) OR
            (@c_SkuABCPL <> @c_SkuNewABC) 
         BEGIN
            UPDATE SKU WITH (ROWLOCK)
            SET ABC     = @c_SkuNewABC
               ,ABCEA   = @c_SkuNewABC 
               ,ABCCS   = @c_SkuNewABC
               ,ABCPL   = @c_SkuNewABC
               ,EditWho = SUSER_NAME()
               ,EditDate= GETDATE()
            WHERE Storerkey = @c_Storerkey
            AND   Sku = @c_Sku

            SET @n_err = @@ERROR 
            IF @n_err <> 0
            BEGIN
               SET @n_continue = 3
               SET @c_errmsg = CONVERT(CHAR(250),@n_err)
               SET @n_err=80030   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table SKU. (isp_AutoFinalizeABC)' 
                            + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
               GOTO QUIT_SP
            END
         END

         FETCH NEXT FROM @CUR_SKU INTO @c_Sku 
                                    ,  @c_SkuABC                                 
                                    ,  @c_SkuABCEA         
                                    ,  @c_SkuABCCS           
                                    ,  @c_SkuABCPL
      END
      CLOSE @CUR_SKU
      DEALLOCATE @CUR_SKU 
   END
   --(Wan02) - END
QUIT_SP:

   IF CURSOR_STATUS( 'LOCAL', 'CUR_ABC') in (0 , 1)  
   BEGIN
      CLOSE CUR_ABC
      DEALLOCATE CUR_ABC
   END

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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_PO2ASNMAP01'
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